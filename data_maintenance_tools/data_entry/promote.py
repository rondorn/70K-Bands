"""Promote testing festival data into production pointer targets."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from data_entry.http_util import fetch_url
from data_entry.pointer import fetch_pointer


class PromoteError(Exception):
    pass


@dataclass
class PromoteDiff:
    bands_testing: int = 0
    bands_production: int = 0
    events_testing: int = 0
    events_production: int = 0
    map_rows_testing: int = 0
    map_rows_production: int = 0
    messages: list[str] = field(default_factory=list)

    @property
    def summary_lines(self) -> list[str]:
        lines = [
            f"Bands: testing {self.bands_testing} → production {self.bands_production}",
            f"Schedule events: testing {self.events_testing} → production {self.events_production}",
            f"Description map rows: testing {self.map_rows_testing} → production {self.map_rows_production}",
        ]
        lines.extend(self.messages)
        return lines


def _current_urls(pointer_url: str) -> dict[str, str]:
    sections = fetch_pointer(pointer_url)
    current = sections.get("Current", {})
    if not current:
        raise PromoteError(f"Pointer has no Current section: {pointer_url}")
    return {
        "band_list_url": (current.get("artistUrl") or "").strip(),
        "schedule_url": (current.get("scheduleUrl") or "").strip(),
        "description_map_url": (current.get("descriptionMap") or "").strip(),
        "event_year": (current.get("eventYear") or "").strip(),
    }


def _count_csv_rows(text: str) -> int:
    lines = [ln for ln in (text or "").splitlines() if ln.strip()]
    return max(0, len(lines) - 1) if lines else 0


def preview_promote(cfg: dict[str, Any]) -> PromoteDiff:
    """Compare testing vs production file sizes/row counts without writing."""
    testing_url = (cfg.get("testing_pointer_url") or cfg.get("pointer_url") or "").strip()
    production_url = (cfg.get("production_pointer_url") or "").strip()
    if not testing_url:
        raise PromoteError("Testing pointer URL is not configured.")
    if not production_url:
        raise PromoteError("Production pointer URL is not configured.")

    test_urls = _current_urls(testing_url)
    prod_urls = _current_urls(production_url)
    diff = PromoteDiff()

    for key, attr_t, attr_p in (
        ("band_list_url", "bands_testing", "bands_production"),
        ("schedule_url", "events_testing", "events_production"),
        ("description_map_url", "map_rows_testing", "map_rows_production"),
    ):
        t_url = test_urls.get(key, "")
        p_url = prod_urls.get(key, "")
        if not t_url or not p_url:
            diff.messages.append(f"Missing URL for {key} on testing or production pointer.")
            continue
        try:
            t_text = fetch_url(t_url)
            p_text = fetch_url(p_url)
        except Exception as exc:
            diff.messages.append(f"Could not fetch {key}: {exc}")
            continue
        setattr(diff, attr_t, _count_csv_rows(t_text))
        setattr(diff, attr_p, _count_csv_rows(p_text))

    return diff


def promote_testing_to_production(cfg: dict[str, Any], paths: dict[str, str] | None = None) -> PromoteDiff:
    """
    Flush local staging to testing, then edit production files in place.

    Reads content from testing share URLs and writes that content into the
    existing production files (same production share links). Never deletes or
    recreates production files.
    """
    from data_entry.config_store import resolved_paths, uses_dropbox_api
    from data_entry.dropbox_storage import DropboxStorageError, upload_text
    from data_entry.lineup_staging import sync_lineup_to_dropbox
    from data_entry.network_cache import invalidate_festival_network_cache
    from data_entry.schedule_staging import sync_schedule_to_dropbox

    paths = paths or resolved_paths(cfg)
    testing_url = (cfg.get("testing_pointer_url") or cfg.get("pointer_url") or "").strip()
    production_url = (cfg.get("production_pointer_url") or "").strip()
    if not testing_url:
        raise PromoteError("Testing pointer URL is not configured.")
    if not production_url:
        raise PromoteError("Production pointer URL is not configured.")
    if testing_url == production_url:
        raise PromoteError("Testing and production pointers must be different URLs.")

    if uses_dropbox_api(cfg):
        try:
            sync_lineup_to_dropbox(cfg, paths)
        except ValueError:
            pass
        try:
            sync_schedule_to_dropbox(cfg, paths)
        except ValueError:
            pass

    test_urls = _current_urls(testing_url)
    prod_urls = _current_urls(production_url)
    diff = preview_promote(cfg)

    for key, label in (
        ("band_list_url", "lineup"),
        ("schedule_url", "schedule"),
        ("description_map_url", "description map"),
    ):
        src = test_urls.get(key, "")
        dest = prod_urls.get(key, "")
        if not src or not dest:
            raise PromoteError(f"Cannot promote {label}: missing URL on pointer.")
        if src == dest:
            diff.messages.append(
                f"{label}: testing and production share the same file — skipped copy."
            )
            continue
        try:
            text = fetch_url(src)
            upload_text(dest, text, cfg)
            diff.messages.append(f"Updated production {label} in place.")
        except (DropboxStorageError, Exception) as exc:
            raise PromoteError(f"Failed promoting {label}: {exc}") from exc

    invalidate_festival_network_cache(prod_urls)
    invalidate_festival_network_cache(test_urls)
    return diff

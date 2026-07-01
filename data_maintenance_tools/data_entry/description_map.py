"""Description map CSV (Band, URL, Date) and combined band/event name lists."""

from __future__ import annotations

import csv
from datetime import datetime
from pathlib import Path
from typing import Any

from data_entry.band_logic import lineup_band_names
from data_entry.config_store import description_map_reads_local
from data_entry.http_util import normalize_dropbox_url
from data_entry.network_cache import CacheMeta, invalidate_festival_network_cache
from data_entry.schedule_logic import NON_BAND_EVENT_TYPES, read_schedule_from_url

MAP_COLUMNS = ["Band", "URL", "Date"]
MAP_HEADER = "Band,URL,Date\n"


def cache_date_today() -> str:
    return datetime.now().strftime("%m-%d-%Y")


def normalize_map_url(url: str) -> str:
    return normalize_dropbox_url((url or "").strip())


def read_description_map(path: str | Path) -> list[dict[str, str]]:
    """Read description map from a local CSV file (write target only)."""
    path = Path(path)
    if not path.is_file():
        return []
    return _parse_description_map_csv(path.read_text(encoding="utf-8-sig"))


def read_description_map_from_url(
    url: str,
    cfg: dict[str, Any] | None = None,
    *,
    force_refresh: bool = False,
) -> list[dict[str, str]]:
    """Read description map from the published network URL (TTL-cached)."""
    url = (url or "").strip()
    if not url:
        return []
    from data_entry.config_store import resolved_paths
    from data_entry.network_cache import fetch_cached_text_or_empty

    paths = resolved_paths(cfg)
    csv_text, _meta = fetch_cached_text_or_empty(
        url, paths, force_refresh=force_refresh
    )
    if not csv_text:
        return []
    return _parse_description_map_csv(csv_text)


def _parse_description_map_csv(csv_text: str) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    reader = csv.DictReader(csv_text.splitlines())
    for row in reader:
        band = (row.get("Band") or "").strip()
        if not band or band.lower() == "band":
            continue
        rows.append(
            {
                "Band": band,
                "URL": (row.get("URL") or "").strip(),
                "Date": (row.get("Date") or "").strip(),
            }
        )
    return rows


def write_description_map(
    path: str | Path, rows: list[dict[str, str]], cfg: dict[str, Any] | None = None
) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=MAP_COLUMNS)
        writer.writeheader()
        for row in rows:
            writer.writerow(
                {
                    "Band": row.get("Band", ""),
                    "URL": row.get("URL", ""),
                    "Date": row.get("Date", ""),
                }
            )
    if cfg is not None:
        from data_entry.config_store import resolved_paths

        invalidate_festival_network_cache(resolved_paths(cfg))


def ensure_description_map_file(path: str | Path) -> None:
    path = Path(path)
    if not path.is_file() or path.stat().st_size == 0:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(MAP_HEADER, encoding="utf-8")


def find_band_index(rows: list[dict[str, str]], band: str) -> int | None:
    target = (band or "").strip()
    for idx, row in enumerate(rows):
        if row.get("Band", "").strip() == target:
            return idx
    return None


def description_label_options(
    cfg: dict[str, Any],
    paths: dict[str, str],
    *,
    force_refresh: bool = False,
) -> tuple[list[str], CacheMeta | None]:
    """
    Band/event names for description Write and Map entry dropdowns.

    Band names use the same local-vs-cached published logic as the schedule dropdown.
    Schedule special events and map entries are merged in (also TTL-cached when online).
    """
    names: set[str] = set()

    band_names, band_cache = lineup_band_names(cfg, paths, force_refresh=force_refresh)
    names.update(band_names)

    schedule_url = paths.get("schedule_url", "")
    if schedule_url:
        for event in read_schedule_from_url(
            schedule_url, cfg, force_refresh=force_refresh
        ):
            if event.event_type in NON_BAND_EVENT_TYPES:
                name = (event.band or "").strip()
                if name and name != " ":
                    names.add(name)

    map_path = paths.get("description_map_file", "")
    map_url = paths.get("description_map_url", "")
    if description_map_reads_local(cfg) and map_path:
        for row in read_description_map(map_path):
            name = (row.get("Band") or "").strip()
            if name:
                names.add(name)
    elif map_url:
        for row in read_description_map_from_url(
            map_url, cfg, force_refresh=force_refresh
        ):
            name = (row.get("Band") or "").strip()
            if name:
                names.add(name)

    return sorted(names, key=str.casefold), band_cache


def upsert_map_entry(
    path: str | Path,
    band: str,
    url: str,
    cache_date: str,
    *,
    confirm_update: bool = False,
    edit_index: int | None = None,
    cfg: dict[str, Any] | None = None,
) -> tuple[str, str | None]:
    """
    Add or update a map row.

    Returns (status, message) where status is one of:
    needs_confirm, added, updated, error
    """
    band = (band or "").strip()
    url = normalize_map_url(url)
    cache_date = (cache_date or "").strip() or cache_date_today()

    if not band:
        return "error", "Band or event name is required."
    if not url:
        return "error", "Dropbox URL is required."

    map_path = Path(path)
    ensure_description_map_file(map_path)
    rows = read_description_map(map_path)

    if edit_index is not None and 0 <= edit_index < len(rows):
        existing_at = find_band_index(rows, band)
        if existing_at is not None and existing_at != edit_index:
            return "error", f"'{band}' already exists in the description map."
        rows[edit_index] = {"Band": band, "URL": url, "Date": cache_date}
        write_description_map(map_path, rows, cfg)
        return "updated", f"{band} has been updated in the description map."

    existing_idx = find_band_index(rows, band)
    if existing_idx is not None:
        if not confirm_update:
            return "needs_confirm", f"'{band}' is already in the description map."
        rows[existing_idx] = {"Band": band, "URL": url, "Date": cache_date}
        write_description_map(map_path, rows, cfg)
        return "updated", f"{band} has been updated in the description map."

    rows.append({"Band": band, "URL": url, "Date": cache_date})
    write_description_map(map_path, rows, cfg)
    return "added", f"{band} has been added to the description map."


def remove_map_entry_at_index(path: str | Path, index: int) -> bool:
    rows = read_description_map(path)
    if index < 0 or index >= len(rows):
        return False
    del rows[index]
    write_description_map(path, rows)
    return True

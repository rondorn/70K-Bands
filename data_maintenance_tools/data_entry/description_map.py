"""Description map CSV (Band, URL, Date) and combined band/event name lists."""

from __future__ import annotations

import csv
from datetime import datetime
from pathlib import Path
from typing import Any

from data_entry.band_logic import lineup_band_names
from data_entry.http_util import normalize_dropbox_url
from data_entry.network_cache import CacheMeta, invalidate_festival_network_cache
from data_entry.schedule_logic import NON_BAND_EVENT_TYPES

MAP_COLUMNS = ["Band", "URL", "Date"]
MAP_HEADER = "Band,URL,Date\n"


def cache_date_today() -> str:
    return datetime.now().strftime("%m-%d-%Y")


def normalize_map_url(url: str) -> str:
    return normalize_dropbox_url((url or "").strip())


def read_description_map(path: str | Path, cfg: dict[str, Any] | None = None) -> list[dict[str, str]]:
    """Read description map from local CSV or published URL depending on storage mode."""
    from data_entry.config_store import uses_dropbox_api

    target = str(path or "").strip()
    if uses_dropbox_api(cfg or {}) or target.lower().startswith("http"):
        return read_description_map_from_url(target, cfg, force_refresh=True)
    from data_entry.csv_file_io import read_csv_text

    file_path = Path(path)
    if not file_path.is_file():
        return []
    return _parse_description_map_csv(read_csv_text(file_path))


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


def _description_map_csv_text(rows: list[dict[str, str]]) -> str:
    import io

    buffer = io.StringIO()
    writer = csv.DictWriter(buffer, fieldnames=MAP_COLUMNS, lineterminator="\n")
    writer.writeheader()
    for row in rows:
        writer.writerow(
            {
                "Band": row.get("Band", ""),
                "URL": row.get("URL", ""),
                "Date": row.get("Date", ""),
            }
        )
    return buffer.getvalue()


def write_description_map(
    target: str | Path, rows: list[dict[str, str]], cfg: dict[str, Any] | None = None
) -> None:
    from data_entry.config_store import resolved_paths, uses_dropbox_api
    from data_entry.dropbox_storage import DropboxStorageError, upload_text

    text = _description_map_csv_text(rows)
    if uses_dropbox_api(cfg or {}):
        url = str(target or "").strip()
        if not url:
            raise ValueError("Description map URL is not configured.")
        try:
            upload_text(url, text, cfg)
        except DropboxStorageError as exc:
            raise ValueError(str(exc)) from exc
    else:
        from data_entry.csv_file_io import write_csv_text

        path = Path(target)
        write_csv_text(path, text)
    if cfg is not None:
        invalidate_festival_network_cache(resolved_paths(cfg))


def ensure_description_map_file(target: str | Path, cfg: dict[str, Any] | None = None) -> None:
    from data_entry.config_store import uses_dropbox_api

    if uses_dropbox_api(cfg or {}):
        url = str(target or "").strip()
        if not url:
            return
        rows = read_description_map_from_url(url, cfg, force_refresh=True)
        if not rows:
            write_description_map(url, [], cfg)
        return
    path = Path(target)
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
    from data_entry.schedule_staging import schedule_working_target
    from data_entry.schedule_logic import read_schedule

    schedule_target = schedule_working_target(paths, cfg)
    if schedule_target:
        for event in read_schedule(
            schedule_target,
            cfg,
        ):
            if event.event_type in NON_BAND_EVENT_TYPES:
                name = (event.band or "").strip()
                if name and name != " ":
                    names.add(name)

    map_path = paths.get("description_map_file", "")
    map_url = paths.get("description_map_url", "")
    from data_entry.config_store import description_map_reads_local

    if description_map_reads_local(cfg) and map_path:
        for row in read_description_map(map_path, cfg):
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

    map_target = path
    ensure_description_map_file(map_target, cfg)
    rows = read_description_map(map_target, cfg)

    if edit_index is not None and 0 <= edit_index < len(rows):
        existing_at = find_band_index(rows, band)
        if existing_at is not None and existing_at != edit_index:
            return "error", f"'{band}' already exists in the description map."
        rows[edit_index] = {"Band": band, "URL": url, "Date": cache_date}
        write_description_map(map_target, rows, cfg)
        return "updated", f"{band} has been updated in the description map."

    existing_idx = find_band_index(rows, band)
    if existing_idx is not None:
        if not confirm_update:
            return "needs_confirm", f"'{band}' is already in the description map."
        rows[existing_idx] = {"Band": band, "URL": url, "Date": cache_date}
        write_description_map(map_target, rows, cfg)
        return "updated", f"{band} has been updated in the description map."

    rows.append({"Band": band, "URL": url, "Date": cache_date})
    write_description_map(map_target, rows, cfg)
    return "added", f"{band} has been added to the description map."


def remove_map_entry_at_index(
    path: str | Path, index: int, cfg: dict[str, Any] | None = None
) -> bool:
    rows = read_description_map(path, cfg)
    if index < 0 or index >= len(rows):
        return False
    del rows[index]
    write_description_map(path, rows, cfg)
    return True

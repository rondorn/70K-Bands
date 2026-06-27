"""Description map CSV (Band, URL, Date) and combined band/event name lists."""

from __future__ import annotations

import csv
from datetime import datetime
from pathlib import Path
from typing import Any

from data_entry.band_logic import read_lineup
from data_entry.http_util import normalize_dropbox_url
from data_entry.schedule_logic import NON_BAND_EVENT_TYPES, read_schedule

MAP_COLUMNS = ["Band", "URL", "Date"]
MAP_HEADER = "Band,URL,Date\n"


def cache_date_today() -> str:
    return datetime.now().strftime("%m-%d-%Y")


def normalize_map_url(url: str) -> str:
    return normalize_dropbox_url((url or "").strip())


def read_description_map(path: str | Path) -> list[dict[str, str]]:
    path = Path(path)
    if not path.is_file():
        return []
    rows: list[dict[str, str]] = []
    with path.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
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


def write_description_map(path: str | Path, rows: list[dict[str, str]]) -> None:
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


def description_label_options(cfg: dict[str, Any], paths: dict[str, str]) -> list[str]:
    names: set[str] = set()

    lineup_path = paths.get("lineup_file", "")
    if lineup_path:
        for row in read_lineup(lineup_path, cfg):
            name = (row.get("bandName") or "").strip()
            if name:
                names.add(name)

    schedule_path = paths.get("schedule_file", "")
    if schedule_path:
        for event in read_schedule(schedule_path):
            if event.event_type in NON_BAND_EVENT_TYPES:
                name = (event.band or "").strip()
                if name and name != " ":
                    names.add(name)

    map_path = paths.get("description_map_file", "")
    if map_path and Path(map_path).is_file():
        for row in read_description_map(map_path):
            name = (row.get("Band") or "").strip()
            if name:
                names.add(name)

    return sorted(names, key=str.casefold)


def upsert_map_entry(
    path: str | Path,
    band: str,
    url: str,
    cache_date: str,
    *,
    confirm_update: bool = False,
    edit_index: int | None = None,
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
        write_description_map(map_path, rows)
        return "updated", f"{band} has been updated in the description map."

    existing_idx = find_band_index(rows, band)
    if existing_idx is not None:
        if not confirm_update:
            return "needs_confirm", f"'{band}' is already in the description map."
        rows[existing_idx] = {"Band": band, "URL": url, "Date": cache_date}
        write_description_map(map_path, rows)
        return "updated", f"{band} has been updated in the description map."

    rows.append({"Band": band, "URL": url, "Date": cache_date})
    write_description_map(map_path, rows)
    return "added", f"{band} has been added to the description map."


def remove_map_entry_at_index(path: str | Path, index: int) -> bool:
    rows = read_description_map(path)
    if index < 0 or index >= len(rows):
        return False
    del rows[index]
    write_description_map(path, rows)
    return True

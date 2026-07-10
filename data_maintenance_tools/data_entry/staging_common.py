"""Shared helpers for local staging files and per-row sync status."""

from __future__ import annotations

import time
from pathlib import Path
from typing import Any

STAGING_DIR = ".staging"
SYNC_STATE_SYNCED = "synced"
SYNC_STATE_PENDING = "pending"
SYNC_STATE_ERROR = "error"
AUTO_SYNC_DEBOUNCE_SECONDS = 10


def synced_snapshot_path(staging_csv: Path) -> Path:
    return staging_csv.with_name(f"{staging_csv.stem}.synced.csv")


def write_synced_snapshot(staging_csv: Path) -> None:
    if staging_csv.is_file():
        snapshot = synced_snapshot_path(staging_csv)
        snapshot.parent.mkdir(parents=True, exist_ok=True)
        snapshot.write_text(staging_csv.read_text(encoding="utf-8"), encoding="utf-8")


def _age_label(timestamp: float) -> str:
    age = max(0, int(time.time() - timestamp))
    if age < 45:
        return "just now"
    minutes = age // 60
    if minutes < 60:
        return f"{minutes} min ago"
    hours = minutes // 60
    if hours < 24:
        return f"{hours} hr ago"
    return f"{hours // 24} day(s) ago"


def status_label_for_state(
    *,
    uses_staging: bool,
    state: str,
    pending_count: int,
    last_synced_at: float | None,
    last_error: str,
) -> str:
    if not uses_staging:
        return ""
    if state == SYNC_STATE_ERROR:
        return f"Sync failed — {last_error or 'unknown error'}"
    if pending_count > 0:
        noun = "change" if pending_count == 1 else "changes"
        return f"{pending_count} unsynced {noun} — will publish to Dropbox automatically"
    if last_synced_at:
        return f"All entries synced {_age_label(last_synced_at)}"
    return "All entries synced"


def band_row_fingerprint(row: dict[str, str], fields: list[str]) -> str:
    return "\x1f".join((row.get(field) or "").strip() for field in fields)


def pending_band_names(staging_csv: Path, fields: list[str]) -> set[str]:
    from data_entry.band_logic import _parse_lineup_csv

    if not staging_csv.is_file():
        return set()

    staging_rows = _parse_lineup_csv(staging_csv.read_text(encoding="utf-8"), fields)
    synced_path = synced_snapshot_path(staging_csv)
    synced_rows: list[dict[str, str]] = []
    if synced_path.is_file():
        synced_rows = _parse_lineup_csv(synced_path.read_text(encoding="utf-8"), fields)

    synced_by_name = {
        (row.get("bandName") or "").strip(): band_row_fingerprint(row, fields)
        for row in synced_rows
        if (row.get("bandName") or "").strip()
    }
    staging_names = {
        (row.get("bandName") or "").strip()
        for row in staging_rows
        if (row.get("bandName") or "").strip()
    }
    pending: set[str] = set()
    for row in staging_rows:
        name = (row.get("bandName") or "").strip()
        if not name:
            continue
        fingerprint = band_row_fingerprint(row, fields)
        if synced_by_name.get(name) != fingerprint:
            pending.add(name)
    # Deletions: in last sync but removed from working copy.
    pending.update(set(synced_by_name.keys()) - staging_names)
    return pending


def schedule_event_key(band: str, location: str, date: str, start_time: str) -> str:
    return "|".join(
        [
            (band or "").strip(),
            (location or "").strip(),
            (date or "").strip(),
            (start_time or "").strip(),
        ]
    )


def schedule_event_fingerprint(event: Any) -> str:
    row = event.as_row()
    return "\x1f".join(row.get(column, "") for column in row.keys())


def pending_schedule_keys(staging_csv: Path) -> set[str]:
    from data_entry.schedule_logic import _parse_schedule_csv

    if not staging_csv.is_file():
        return set()

    staging_events = _parse_schedule_csv(staging_csv.read_text(encoding="utf-8"))
    synced_path = synced_snapshot_path(staging_csv)
    synced_events: list = []
    if synced_path.is_file():
        synced_events = _parse_schedule_csv(synced_path.read_text(encoding="utf-8"))

    synced_by_key = {
        schedule_event_key(event.band, event.location, event.date, event.start_time): (
            schedule_event_fingerprint(event)
        )
        for event in synced_events
    }
    staging_keys = {
        schedule_event_key(event.band, event.location, event.date, event.start_time)
        for event in staging_events
    }
    pending: set[str] = set()
    for event in staging_events:
        key = schedule_event_key(event.band, event.location, event.date, event.start_time)
        if synced_by_key.get(key) != schedule_event_fingerprint(event):
            pending.add(key)
    # Deletions: in last sync but removed from working copy.
    pending.update(set(synced_by_key.keys()) - staging_keys)
    return pending


def staging_has_unsynced_changes(staging_csv: Path) -> bool:
    """True when working copy differs from the last synced snapshot."""
    if not staging_csv.is_file():
        return False
    synced_path = synced_snapshot_path(staging_csv)
    if not synced_path.is_file():
        return True
    return staging_csv.read_text(encoding="utf-8") != synced_path.read_text(encoding="utf-8")


def float_or_none(value: Any) -> float | None:
    if value is None or value == "":
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None

"""Local schedule staging and Dropbox sync for fast bulk entry."""

from __future__ import annotations

import json
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from data_entry.staging_common import (
    AUTO_SYNC_DEBOUNCE_SECONDS,
    STAGING_DIR,
    SYNC_STATE_ERROR,
    SYNC_STATE_PENDING,
    SYNC_STATE_SYNCED,
    float_or_none,
    pending_schedule_keys,
    status_label_for_state,
    write_synced_snapshot,
)


@dataclass(frozen=True)
class ScheduleSyncStatus:
    uses_staging: bool
    state: str
    staging_path: str
    published_url: str
    event_count: int
    pending_count: int
    last_saved_at: float | None
    last_synced_at: float | None
    last_error: str
    auto_sync_debounce_seconds: int

    @property
    def status_label(self) -> str:
        return status_label_for_state(
            uses_staging=self.uses_staging,
            state=self.state,
            pending_count=self.pending_count,
            last_synced_at=self.last_synced_at,
            last_error=self.last_error,
        )

    @property
    def has_pending(self) -> bool:
        return self.uses_staging and self.pending_count > 0

    @property
    def needs_auto_sync(self) -> bool:
        return self.uses_staging and (
            self.pending_count > 0 or self.state == SYNC_STATE_PENDING
        )


def _festival_key(cfg: dict[str, Any]) -> str:
    from data_entry.config_store import active_festival_id

    return active_festival_id() or "default"


def staging_csv_path(cfg: dict[str, Any] | None = None) -> Path:
    from data_entry.config_store import config_path, load_config

    cfg = cfg or load_config()
    festival_id = _festival_key(cfg)
    return config_path().parent / STAGING_DIR / f"{festival_id}_schedule.csv"


def staging_meta_path(cfg: dict[str, Any] | None = None) -> Path:
    csv_path = staging_csv_path(cfg)
    return csv_path.with_name(csv_path.stem + ".meta.json")


def is_staging_path(path: str | Path, cfg: dict[str, Any] | None = None) -> bool:
    try:
        return Path(path).resolve() == staging_csv_path(cfg).resolve()
    except OSError:
        return False


def _read_meta(cfg: dict[str, Any] | None = None) -> dict[str, Any]:
    path = staging_meta_path(cfg)
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {}
    return data if isinstance(data, dict) else {}


def _write_meta(cfg: dict[str, Any], **updates: Any) -> dict[str, Any]:
    data = _read_meta(cfg)
    data.update(updates)
    path = staging_meta_path(cfg)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    return data


def mark_staging_pending(cfg: dict[str, Any] | None = None) -> None:
    cfg = cfg or {}
    now = time.time()
    csv_path = staging_csv_path(cfg)
    mtime = csv_path.stat().st_mtime if csv_path.is_file() else now
    _write_meta(
        cfg,
        state=SYNC_STATE_PENDING,
        last_saved_at=now,
        staging_mtime=mtime,
        last_error="",
    )


def mark_staging_synced(cfg: dict[str, Any] | None = None) -> None:
    now = time.time()
    csv_path = staging_csv_path(cfg)
    mtime = csv_path.stat().st_mtime if csv_path.is_file() else now
    if csv_path.is_file():
        write_synced_snapshot(csv_path)
    _write_meta(
        cfg,
        state=SYNC_STATE_SYNCED,
        last_synced_at=now,
        last_saved_at=now,
        staging_mtime=mtime,
        last_error="",
    )


def mark_staging_error(cfg: dict[str, Any], message: str) -> None:
    _write_meta(
        cfg,
        state=SYNC_STATE_ERROR,
        last_error=(message or "Sync failed.").strip(),
    )


def ensure_schedule_staging(
    cfg: dict[str, Any], paths: dict[str, str]
) -> Path:
    """Create staging CSV from published schedule URL when missing."""
    from data_entry.config_store import uses_dropbox_api
    from data_entry.schedule_logic import (
        _schedule_csv_text,
        read_schedule_from_url,
    )

    if not uses_dropbox_api(cfg):
        raise ValueError("Schedule staging is only used in all-files-on-Dropbox mode.")

    path = staging_csv_path(cfg)
    if path.is_file():
        return path

    from data_entry.csv_file_io import write_csv_text

    path.parent.mkdir(parents=True, exist_ok=True)
    url = (paths.get("schedule_url") or "").strip()
    events = read_schedule_from_url(url, cfg, force_refresh=True) if url else []
    write_csv_text(path, _schedule_csv_text(events))
    mark_staging_synced(cfg)
    return path


def schedule_working_target(paths: dict[str, str], cfg: dict[str, Any]) -> str:
    """Path or URL used for schedule entry, view, and validation."""
    from data_entry.config_store import schedule_write_target, uses_dropbox_api

    if uses_dropbox_api(cfg):
        return str(ensure_schedule_staging(cfg, paths))
    return schedule_write_target(paths, cfg)


def schedule_published_target(paths: dict[str, str], cfg: dict[str, Any]) -> str:
    from data_entry.config_store import schedule_write_target

    return schedule_write_target(paths, cfg)


def sync_schedule_to_dropbox(
    cfg: dict[str, Any], paths: dict[str, str]
) -> ScheduleSyncStatus:
    """Upload staged CSV to the published Dropbox schedule URL."""
    from data_entry.config_store import uses_dropbox_api
    from data_entry.dropbox_storage import DropboxStorageError, upload_text
    from data_entry.network_cache import invalidate_cached_url

    if not uses_dropbox_api(cfg):
        return get_schedule_sync_status(cfg, paths)

    csv_path = ensure_schedule_staging(cfg, paths)
    url = (paths.get("schedule_url") or "").strip()
    if not url:
        raise ValueError("Schedule URL is not configured.")

    from data_entry.csv_file_io import read_csv_text

    text = read_csv_text(csv_path)
    try:
        upload_text(url, text, cfg)
    except DropboxStorageError as exc:
        mark_staging_error(cfg, str(exc))
        raise ValueError(str(exc)) from exc

    invalidate_cached_url(url, paths)
    mark_staging_synced(cfg)
    return get_schedule_sync_status(cfg, paths)


def reload_schedule_staging_from_published(
    cfg: dict[str, Any], paths: dict[str, str]
) -> None:
    """Discard local staging and replace with the current published schedule."""
    from data_entry.schedule_logic import (
        _schedule_csv_text,
        read_schedule_from_url,
    )

    url = (paths.get("schedule_url") or "").strip()
    if not url:
        raise ValueError("Schedule URL is not configured.")

    events = read_schedule_from_url(url, cfg, force_refresh=True)
    from data_entry.csv_file_io import write_csv_text

    path = staging_csv_path(cfg)
    path.parent.mkdir(parents=True, exist_ok=True)
    write_csv_text(path, _schedule_csv_text(events))
    mark_staging_synced(cfg)


def get_schedule_sync_status(
    cfg: dict[str, Any], paths: dict[str, str]
) -> ScheduleSyncStatus:
    from data_entry.config_store import uses_dropbox_api
    from data_entry.csv_file_io import read_csv_text
    from data_entry.schedule_logic import _parse_schedule_csv

    published_url = (paths.get("schedule_url") or "").strip()
    if not uses_dropbox_api(cfg):
        return ScheduleSyncStatus(
            uses_staging=False,
            state=SYNC_STATE_SYNCED,
            staging_path="",
            published_url=published_url,
            event_count=0,
            pending_count=0,
            last_saved_at=None,
            last_synced_at=None,
            last_error="",
            auto_sync_debounce_seconds=AUTO_SYNC_DEBOUNCE_SECONDS,
        )

    csv_path = staging_csv_path(cfg)
    meta = _read_meta(cfg)
    event_count = 0
    pending_count = 0
    if csv_path.is_file():
        try:
            event_count = len(_parse_schedule_csv(read_csv_text(csv_path)))
            pending_count = len(pending_schedule_keys(csv_path))
        except OSError:
            event_count = 0
            pending_count = 0

    state = str(meta.get("state") or SYNC_STATE_PENDING)
    if not csv_path.is_file():
        state = SYNC_STATE_SYNCED
    elif pending_count > 0:
        state = SYNC_STATE_PENDING
    elif str(meta.get("state") or "") == SYNC_STATE_PENDING:
        state = SYNC_STATE_PENDING
    elif state == SYNC_STATE_ERROR:
        pass
    else:
        state = SYNC_STATE_SYNCED

    return ScheduleSyncStatus(
        uses_staging=True,
        state=state,
        staging_path=str(csv_path),
        published_url=published_url,
        event_count=event_count,
        pending_count=pending_count,
        last_saved_at=float_or_none(meta.get("last_saved_at")),
        last_synced_at=float_or_none(meta.get("last_synced_at")),
        last_error=str(meta.get("last_error") or "").strip(),
        auto_sync_debounce_seconds=AUTO_SYNC_DEBOUNCE_SECONDS,
    )


def get_pending_schedule_event_keys(cfg: dict[str, Any], paths: dict[str, str]) -> set[str]:
    from data_entry.config_store import uses_dropbox_api

    if not uses_dropbox_api(cfg):
        return set()
    csv_path = staging_csv_path(cfg)
    if not csv_path.is_file():
        return set()
    return pending_schedule_keys(csv_path)

"""Local lineup staging and Dropbox sync for fast bulk band entry."""

from __future__ import annotations

import json
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
    pending_band_names,
    status_label_for_state,
    write_synced_snapshot,
)


@dataclass(frozen=True)
class LineupSyncStatus:
    uses_staging: bool
    state: str
    staging_path: str
    published_url: str
    band_count: int
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
    return config_path().parent / STAGING_DIR / f"{festival_id}_lineup.csv"


def staging_meta_path(cfg: dict[str, Any] | None = None) -> Path:
    csv_path = staging_csv_path(cfg)
    return csv_path.with_name(csv_path.stem + ".meta.json")


def is_lineup_staging_path(path: str | Path, cfg: dict[str, Any] | None = None) -> bool:
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


def mark_lineup_staging_pending(cfg: dict[str, Any] | None = None) -> None:
    import time

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


def mark_lineup_staging_synced(cfg: dict[str, Any] | None = None) -> None:
    import time

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


def mark_lineup_staging_error(cfg: dict[str, Any], message: str) -> None:
    _write_meta(
        cfg,
        state=SYNC_STATE_ERROR,
        last_error=(message or "Sync failed.").strip(),
    )


def ensure_lineup_staging(cfg: dict[str, Any], paths: dict[str, str]) -> Path:
    from data_entry.band_logic import _lineup_csv_text, read_lineup_from_url
    from data_entry.config_store import uses_dropbox_api

    if not uses_dropbox_api(cfg):
        raise ValueError("Lineup staging is only used in all-files-on-Dropbox mode.")

    path = staging_csv_path(cfg)
    if path.is_file():
        return path

    path.parent.mkdir(parents=True, exist_ok=True)
    url = (paths.get("band_list_url") or "").strip()
    rows = read_lineup_from_url(url, cfg, force_refresh=True) if url else []
    path.write_text(_lineup_csv_text(rows, cfg), encoding="utf-8")
    mark_lineup_staging_synced(cfg)
    return path


def lineup_working_target(paths: dict[str, str], cfg: dict[str, Any]) -> str:
    from data_entry.config_store import lineup_write_target, uses_dropbox_api

    if uses_dropbox_api(cfg):
        return str(ensure_lineup_staging(cfg, paths))
    return lineup_write_target(paths, cfg)


def sync_lineup_to_dropbox(cfg: dict[str, Any], paths: dict[str, str]) -> LineupSyncStatus:
    from data_entry.config_store import uses_dropbox_api
    from data_entry.dropbox_storage import DropboxStorageError, upload_text
    from data_entry.network_cache import invalidate_cached_url

    if not uses_dropbox_api(cfg):
        return get_lineup_sync_status(cfg, paths)

    csv_path = ensure_lineup_staging(cfg, paths)
    url = (paths.get("band_list_url") or "").strip()
    if not url:
        raise ValueError("Band list URL is not configured.")

    text = csv_path.read_text(encoding="utf-8")
    try:
        upload_text(url, text, cfg)
    except DropboxStorageError as exc:
        mark_lineup_staging_error(cfg, str(exc))
        raise ValueError(str(exc)) from exc

    invalidate_cached_url(url, paths)
    mark_lineup_staging_synced(cfg)
    return get_lineup_sync_status(cfg, paths)


def reload_lineup_staging_from_published(cfg: dict[str, Any], paths: dict[str, str]) -> None:
    from data_entry.band_logic import _lineup_csv_text, read_lineup_from_url

    url = (paths.get("band_list_url") or "").strip()
    if not url:
        raise ValueError("Band list URL is not configured.")

    rows = read_lineup_from_url(url, cfg, force_refresh=True)
    path = staging_csv_path(cfg)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(_lineup_csv_text(rows, cfg), encoding="utf-8")
    mark_lineup_staging_synced(cfg)


def get_lineup_sync_status(cfg: dict[str, Any], paths: dict[str, str]) -> LineupSyncStatus:
    from data_entry.band_logic import _parse_lineup_csv
    from data_entry.config_store import lineup_fields, uses_dropbox_api

    published_url = (paths.get("band_list_url") or "").strip()
    if not uses_dropbox_api(cfg):
        return LineupSyncStatus(
            uses_staging=False,
            state=SYNC_STATE_SYNCED,
            staging_path="",
            published_url=published_url,
            band_count=0,
            pending_count=0,
            last_saved_at=None,
            last_synced_at=None,
            last_error="",
            auto_sync_debounce_seconds=AUTO_SYNC_DEBOUNCE_SECONDS,
        )

    csv_path = staging_csv_path(cfg)
    meta = _read_meta(cfg)
    fields = lineup_fields(cfg)
    band_count = 0
    pending_count = 0
    if csv_path.is_file():
        try:
            band_count = len(
                _parse_lineup_csv(csv_path.read_text(encoding="utf-8"), fields)
            )
            pending_count = len(pending_band_names(csv_path, fields))
        except OSError:
            band_count = 0
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

    return LineupSyncStatus(
        uses_staging=True,
        state=state,
        staging_path=str(csv_path),
        published_url=published_url,
        band_count=band_count,
        pending_count=pending_count,
        last_saved_at=float_or_none(meta.get("last_saved_at")),
        last_synced_at=float_or_none(meta.get("last_synced_at")),
        last_error=str(meta.get("last_error") or "").strip(),
        auto_sync_debounce_seconds=AUTO_SYNC_DEBOUNCE_SECONDS,
    )


def get_pending_lineup_band_names(cfg: dict[str, Any], paths: dict[str, str]) -> set[str]:
    from data_entry.config_store import lineup_fields, uses_dropbox_api

    if not uses_dropbox_api(cfg):
        return set()
    csv_path = staging_csv_path(cfg)
    if not csv_path.is_file():
        return set()
    return pending_band_names(csv_path, lineup_fields(cfg))

"""Dropbox shared-link helpers for description notes and map entries."""

from __future__ import annotations

import os
import time
from pathlib import Path
from typing import Any

from data_entry.description_notes import note_filename
from data_entry.dropbox_oauth import (
    DropboxOAuthError,
    get_authenticated_client,
    oauth_connected,
)
from data_entry.http_util import normalize_dropbox_url


class DropboxLinkError(Exception):
    pass


def dropbox_sdk_available() -> bool:
    try:
        import dropbox  # noqa: F401

        return True
    except ImportError:
        return False


def dropbox_token_configured() -> bool:
    if os.environ.get("DROPBOX_ACCESS_TOKEN", "").strip():
        return True
    return oauth_connected()


def dropbox_integration_ready() -> tuple[bool, str]:
    if not dropbox_sdk_available():
        return False, "Install the dropbox package: pip install dropbox"
    if dropbox_token_configured():
        return True, ""
    return (
        False,
        "Connect Dropbox on the Config screen to publish description links automatically.",
    )


def detect_dropbox_root() -> Path | None:
    """Best-effort Dropbox folder location on the local machine."""
    home = Path.home()
    candidates: list[Path] = [home / "Dropbox"]
    cloud_storage = home / "Library" / "CloudStorage"
    if cloud_storage.is_dir():
        candidates.extend(sorted(cloud_storage.glob("Dropbox*")))
    for candidate in candidates:
        if candidate.is_dir():
            return candidate.resolve()
    return None


def resolve_dropbox_root(cfg: dict[str, Any] | None = None) -> Path | None:
    cfg = cfg or {}
    configured = str(cfg.get("dropbox_root", "") or "").strip()
    if configured:
        path = Path(configured).expanduser()
        if path.is_dir():
            return path.resolve()
        raise DropboxLinkError(f"Dropbox root is not a folder: {path}")
    return detect_dropbox_root()


def local_path_to_dropbox_api_path(local_path: Path, dropbox_root: Path) -> str:
    """Map a synced local file to a Dropbox API path (e.g. /Festival/notes/Band.txt)."""
    file_path = local_path.expanduser().resolve()
    root = dropbox_root.expanduser().resolve()
    try:
        relative = file_path.relative_to(root)
    except ValueError as exc:
        raise DropboxLinkError(
            f"{file_path} is not under Dropbox root {root}. "
            "Set Dropbox root on the Config screen or move notes into Dropbox."
        ) from exc
    return "/" + relative.as_posix()


def ensure_dropbox_raw_url(url: str) -> str:
    """Normalize Dropbox share links for direct download in the apps."""
    normalized = normalize_dropbox_url((url or "").strip())
    if not normalized:
        return ""
    lowered = normalized.lower()
    if "raw=1" in lowered or "dl=1" in lowered:
        return normalized
    separator = "&" if "?" in normalized else "?"
    return f"{normalized}{separator}raw=1"


def _get_dropbox_client(cfg: dict[str, Any] | None = None):
    ready, message = dropbox_integration_ready()
    if not ready:
        raise DropboxLinkError(message)
    try:
        return get_authenticated_client(cfg)
    except DropboxOAuthError as exc:
        raise DropboxLinkError(str(exc)) from exc


def _wait_for_remote_file(dbx, api_path: str, *, attempts: int = 6, delay_s: float = 1.5) -> None:
    from dropbox.exceptions import ApiError

    last_error: Exception | None = None
    for attempt in range(attempts):
        try:
            dbx.files_get_metadata(api_path)
            return
        except ApiError as exc:
            last_error = exc
            if attempt < attempts - 1:
                time.sleep(delay_s)
    raise DropboxLinkError(
        f"Dropbox has not finished syncing {api_path} yet. "
        "Wait a few seconds and try again."
    ) from last_error


def get_or_create_shared_link(dbx, api_path: str) -> str:
    from dropbox import sharing
    from dropbox.exceptions import ApiError

    settings = sharing.SharedLinkSettings(
        requested_visibility=sharing.RequestedVisibility.public
    )
    try:
        link = dbx.sharing_create_shared_link_with_settings(api_path, settings=settings)
        return link.url
    except ApiError:
        links = dbx.sharing_list_shared_links(path=api_path, direct_only=True)
        if links.links:
            return links.links[0].url
        raise DropboxLinkError(
            f"Could not create or find a shared link for {api_path}."
        ) from None


def share_link_for_local_file(local_path: Path, cfg: dict[str, Any] | None = None) -> str:
    """Return a public raw Dropbox URL for a local synced file."""
    path = Path(local_path).expanduser().resolve()
    if not path.is_file():
        raise DropboxLinkError(f"File not found: {path}")

    dropbox_root = resolve_dropbox_root(cfg)
    if dropbox_root is None:
        raise DropboxLinkError(
            "Could not find a Dropbox folder. Set Dropbox root on the Config screen."
        )

    api_path = local_path_to_dropbox_api_path(path, dropbox_root)
    dbx = _get_dropbox_client(cfg)
    _wait_for_remote_file(dbx, api_path)
    share_url = get_or_create_shared_link(dbx, api_path)
    return ensure_dropbox_raw_url(share_url)


def share_link_for_api_path(api_path: str, cfg: dict[str, Any] | None = None) -> str:
    """Return a public raw Dropbox URL for a file at a Dropbox API path."""
    dbx = _get_dropbox_client(cfg)
    share_url = get_or_create_shared_link(dbx, api_path)
    return ensure_dropbox_raw_url(share_url)


def share_link_for_label(
    notes_dir: str | Path,
    label: str,
    cfg: dict[str, Any] | None = None,
) -> str:
    """Return a share link for the description note file for a band/event label."""
    from data_entry.config_store import uses_dropbox_api

    if cfg is not None and uses_dropbox_api(cfg):
        from data_entry.dropbox_storage import note_api_path

        api_path = note_api_path(label, cfg)
        return share_link_for_api_path(api_path, cfg)

    directory = Path(notes_dir).expanduser().resolve()
    if not str(notes_dir or "").strip():
        raise DropboxLinkError("Notes directory is not configured.")
    note_path = directory / note_filename(label)
    return share_link_for_local_file(note_path, cfg)

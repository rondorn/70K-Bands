"""Create Dropbox festival folder layout, empty CSVs, and pointer files."""

from __future__ import annotations

import posixpath
from typing import Any

from data_entry.config_store import LINEUP_HEADER, SCHEDULE_HEADER
from data_entry.dropbox_oauth import DropboxOAuthError, get_authenticated_client
from data_entry.dropbox_storage import DropboxStorageError, _upload_error_message

MAP_HEADER = "Band,URL,Date\n"

LINEUP_NAME = "lineup.csv"
SCHEDULE_NAME = "schedule.csv"
MAP_NAME = "description_map.csv"
DESCRIPTIONS_DIR = "descriptions"
TESTING_POINTER_NAME = "testingPointer.txt"
PRODUCTION_POINTER_NAME = "productionPointer.txt"


class FestivalLayoutError(Exception):
    pass


def normalize_festival_folder(api_path: str) -> str:
    path = (api_path or "").strip().replace("\\", "/")
    if not path:
        raise FestivalLayoutError("Dropbox festival folder path is required.")
    if not path.startswith("/"):
        path = "/" + path
    return path.rstrip("/") or "/"


def _ensure_folder(dbx, api_path: str) -> None:
    from dropbox.exceptions import ApiError

    try:
        dbx.files_create_folder_v2(api_path)
    except ApiError as exc:
        if "conflict" not in str(exc).lower():
            raise FestivalLayoutError(f"Could not create folder {api_path}: {exc}") from exc


def _file_exists(dbx, api_path: str) -> bool:
    from dropbox.exceptions import ApiError

    try:
        dbx.files_get_metadata(api_path)
        return True
    except ApiError:
        return False


def _ensure_file_with_content(dbx, api_path: str, payload: bytes) -> None:
    """
    Create the file only if missing. If it already exists, leave content alone
    so an existing share link stays valid (edit-in-place rule).
    """
    if _file_exists(dbx, api_path):
        return
    _upload_bytes(dbx, api_path, payload)


def _upload_bytes(dbx, api_path: str, payload: bytes) -> None:
    """Write content to path (create or edit in place). Never delete first."""
    from dropbox.files import WriteMode
    from dropbox.exceptions import ApiError, AuthError, BadInputError

    try:
        dbx.files_upload(payload, api_path, mode=WriteMode.overwrite)
    except (ApiError, BadInputError, AuthError) as exc:
        raise FestivalLayoutError(_upload_error_message(exc, api_path)) from exc


def _create_share_link(dbx, api_path: str) -> str:
    """Return an existing share link if present; otherwise create one once."""
    from dropbox.exceptions import ApiError
    from dropbox.sharing import SharedLinkSettings, RequestedVisibility

    try:
        existing = dbx.sharing_list_shared_links(path=api_path, direct_only=True)
        links = getattr(existing, "links", None) or []
        if links:
            return getattr(links[0], "url", "") or ""
    except ApiError:
        pass

    try:
        link = dbx.sharing_create_shared_link_with_settings(
            api_path,
            settings=SharedLinkSettings(
                requested_visibility=RequestedVisibility.public
            ),
        )
        return getattr(link, "url", "") or ""
    except ApiError as exc:
        try:
            existing = dbx.sharing_list_shared_links(path=api_path, direct_only=True)
            links = getattr(existing, "links", None) or []
            if links:
                return getattr(links[0], "url", "") or ""
        except ApiError:
            pass
        raise FestivalLayoutError(
            f"Could not create share link for {api_path}: {exc}"
        ) from exc


def _raw_share_url(url: str) -> str:
    from data_entry.http_util import normalize_dropbox_url

    url = (url or "").strip()
    if "dl=0" in url:
        return url.replace("dl=0", "raw=1")
    if "raw=1" not in url and "?" in url:
        return url + ("&" if not url.endswith("?") and not url.endswith("&") else "") + "raw=1"
    if "raw=1" not in url and "?" not in url:
        return url + "?raw=1"
    return normalize_dropbox_url(url)


def build_pointer_text(
    *,
    event_year: str,
    band_list_url: str,
    schedule_url: str,
    description_map_url: str,
) -> str:
    year = str(event_year or "").strip() or "2027"
    lines = [
        f"Current::artistUrl::{band_list_url}",
        f"Current::scheduleUrl::{schedule_url}",
        f"Current::eventYear::{year}",
        f"Current::descriptionMap::{description_map_url}",
        f"{year}::scheduleUrl::{schedule_url}",
        "",
    ]
    return "\n".join(lines)


def create_festival_layout(
    festival_folder: str,
    *,
    event_year: str,
    cfg: dict[str, Any] | None = None,
    festival_name: str = "",
) -> dict[str, str]:
    """
    Bootstrap a brand-new festival folder without breaking stable links.

    - Creates missing CSVs / folders only when absent (does not wipe existing files).
    - Reuses existing share links when present.
    - Pointer files are preferably owned by the app maintainer; this helper is a
      bootstrap aid and will not replace content of existing linked data files.
    """
    root = normalize_festival_folder(festival_folder)
    try:
        dbx = get_authenticated_client(cfg)
    except DropboxOAuthError as exc:
        raise FestivalLayoutError(str(exc)) from exc

    _ensure_folder(dbx, root)
    _ensure_folder(dbx, posixpath.join(root, DESCRIPTIONS_DIR))

    lineup_path = posixpath.join(root, LINEUP_NAME)
    schedule_path = posixpath.join(root, SCHEDULE_NAME)
    map_path = posixpath.join(root, MAP_NAME)
    testing_pointer_path = posixpath.join(root, TESTING_POINTER_NAME)
    production_pointer_path = posixpath.join(root, PRODUCTION_POINTER_NAME)

    _ensure_file_with_content(dbx, lineup_path, LINEUP_HEADER.encode("utf-8"))
    _ensure_file_with_content(dbx, schedule_path, SCHEDULE_HEADER.encode("utf-8"))
    _ensure_file_with_content(dbx, map_path, MAP_HEADER.encode("utf-8"))

    band_url = _raw_share_url(_create_share_link(dbx, lineup_path))
    schedule_url = _raw_share_url(_create_share_link(dbx, schedule_path))
    map_url = _raw_share_url(_create_share_link(dbx, map_path))

    pointer_body = build_pointer_text(
        event_year=event_year,
        band_list_url=band_url,
        schedule_url=schedule_url,
        description_map_url=map_url,
    )
    # Pointers: create if missing; if present, leave content alone (maintainer-owned).
    _ensure_file_with_content(dbx, testing_pointer_path, pointer_body.encode("utf-8"))
    _ensure_file_with_content(
        dbx, production_pointer_path, pointer_body.encode("utf-8")
    )

    testing_pointer_url = _raw_share_url(_create_share_link(dbx, testing_pointer_path))
    production_pointer_url = _raw_share_url(
        _create_share_link(dbx, production_pointer_path)
    )

    _ = festival_name  # reserved for future pointer branding
    return {
        "dropbox_festival_folder": root,
        "band_list_url": band_url,
        "schedule_url": schedule_url,
        "description_map_url": map_url,
        "testing_pointer_url": testing_pointer_url,
        "production_pointer_url": production_pointer_url,
        "pointer_url": testing_pointer_url,
    }

"""Dropbox API read/write for remote-only festival data (no local sync)."""

from __future__ import annotations

import posixpath
import re
from typing import Any
from urllib.parse import parse_qs, urlencode, urlparse, urlunparse

from data_entry.dropbox_oauth import DropboxOAuthError, get_authenticated_client
from data_entry.http_util import normalize_dropbox_url

_PATH_CACHE: dict[str, str] = {}


class DropboxStorageError(Exception):
    pass


def is_dropbox_url(url: str) -> bool:
    lowered = (url or "").strip().lower()
    return "dropbox.com" in lowered or "dropboxusercontent.com" in lowered


def _metadata_share_url(url: str) -> str:
    """Share URL form suitable for sharing_get_shared_link_metadata."""
    url = (url or "").strip()
    if not url:
        return ""
    parsed = urlparse(url)
    query = parse_qs(parsed.query, keep_blank_values=True)
    for key in list(query):
        if key.lower() in {"raw", "dl"}:
            del query[key]
    if "dl" not in query and "raw" not in query:
        query["dl"] = ["0"]
    new_query = urlencode(query, doseq=True)
    return urlunparse(parsed._replace(query=new_query))


def resolve_api_path(share_url: str, cfg: dict[str, Any] | None = None) -> str:
    """Resolve a Dropbox share URL to an API path (e.g. /Festival/file.csv)."""
    share_url = (share_url or "").strip()
    if not share_url:
        raise DropboxStorageError("Dropbox URL is required.")
    if not is_dropbox_url(share_url):
        raise DropboxStorageError(
            "Remote writes require a Dropbox share URL. "
            "Set the network read URL on the Config screen."
        )

    cached = _PATH_CACHE.get(share_url)
    if cached:
        return cached

    try:
        dbx = get_authenticated_client(cfg)
    except DropboxOAuthError as exc:
        raise DropboxStorageError(str(exc)) from exc

    from dropbox.exceptions import ApiError

    meta_url = _metadata_share_url(share_url)
    try:
        meta = dbx.sharing_get_shared_link_metadata(meta_url)
    except ApiError as exc:
        raise DropboxStorageError(
            f"Could not resolve Dropbox path for {share_url}: {exc}"
        ) from exc

    api_path = (getattr(meta, "path_lower", None) or getattr(meta, "path_display", None) or "").strip()
    if not api_path:
        raise DropboxStorageError(
            "Dropbox did not return a file path for this link. "
            "Connect Dropbox with access to this folder and try again."
        )
    if not api_path.startswith("/"):
        api_path = "/" + api_path
    _PATH_CACHE[share_url] = api_path
    return api_path


def _upload_error_message(exc: Exception, api_path: str) -> str:
    text = str(exc)
    if "files.content.write" in text:
        return (
            "Dropbox cannot upload files yet: enable the "
            "'files.content.write' permission on the app's Permissions tab "
            "in the Dropbox developer console, then disconnect and reconnect "
            "Dropbox on the Config screen."
        )
    if "invalid_grant" in text.lower():
        return (
            "Dropbox authorization expired or was revoked. "
            "Disconnect and reconnect Dropbox on the Config screen."
        )
    return f"Dropbox upload failed for {api_path}: {exc}"


def upload_text(share_url: str, text: str, cfg: dict[str, Any] | None = None) -> None:
    """
    Edit an existing Dropbox file in place (same path, same share link).

    Resolves the share URL to its API path, then updates that file's content.
    Never deletes or recreates the file — that would mint a new share link and
    break pointers / attendee apps. (SDK WriteMode.overwrite = content update
    of the existing path, not file replacement.)
    """
    from dropbox.files import WriteMode
    from dropbox.exceptions import ApiError, AuthError, BadInputError

    api_path = resolve_api_path(share_url, cfg)
    try:
        dbx = get_authenticated_client(cfg)
    except DropboxOAuthError as exc:
        raise DropboxStorageError(str(exc)) from exc

    payload = text.encode("utf-8")
    try:
        # WriteMode.overwrite updates content at api_path; share links stay valid.
        dbx.files_upload(payload, api_path, mode=WriteMode.overwrite)
    except (ApiError, BadInputError, AuthError) as exc:
        raise DropboxStorageError(_upload_error_message(exc, api_path)) from exc


def notes_directory_api_path(cfg: dict[str, Any] | None = None) -> str:
    """API path for description .txt files (sibling descriptions/ folder under map CSV)."""
    from data_entry.config_store import resolved_paths

    cfg = cfg or {}
    paths = resolved_paths(cfg)
    map_url = (paths.get("description_map_url") or "").strip()
    if not map_url:
        raise DropboxStorageError("Description map URL is not configured.")
    map_path = resolve_api_path(map_url, cfg)
    parent = posixpath.dirname(map_path)
    return posixpath.join(parent, "descriptions")


def note_api_path(label: str, cfg: dict[str, Any] | None = None) -> str:
    from data_entry.description_notes import note_filename

    directory = notes_directory_api_path(cfg)
    return posixpath.join(directory, note_filename(label))


def ensure_notes_directory(cfg: dict[str, Any] | None = None) -> str:
    """Ensure the descriptions/ folder exists on Dropbox; return its API path."""
    api_path = notes_directory_api_path(cfg)
    from dropbox.exceptions import ApiError

    try:
        dbx = get_authenticated_client(cfg)
    except DropboxOAuthError as exc:
        raise DropboxStorageError(str(exc)) from exc

    try:
        dbx.files_create_folder_v2(api_path)
    except ApiError as exc:
        if "conflict" not in str(exc).lower():
            raise DropboxStorageError(
                f"Could not create descriptions folder at {api_path}: {exc}"
            ) from exc
    return api_path


def upload_note(label: str, content: str, cfg: dict[str, Any] | None = None) -> str:
    """
    Create or edit a description note in place at a stable API path.

    Returns the API path. First save may create the file; later saves update
    content only so any existing share link keeps working.
    """
    ensure_notes_directory(cfg)
    api_path = note_api_path(label, cfg)
    from dropbox.files import WriteMode
    from dropbox.exceptions import ApiError, AuthError, BadInputError

    text = (content or "").replace("\r\n", "\n").replace("\r", "\n")
    if not text.strip():
        raise DropboxStorageError("Note text is required.")
    if not text.endswith("\n"):
        text += "\n"

    try:
        dbx = get_authenticated_client(cfg)
    except DropboxOAuthError as exc:
        raise DropboxStorageError(str(exc)) from exc

    try:
        dbx.files_upload(text.encode("utf-8"), api_path, mode=WriteMode.overwrite)
    except (ApiError, BadInputError, AuthError) as exc:
        raise DropboxStorageError(_upload_error_message(exc, api_path)) from exc
    return api_path


def clear_path_cache() -> None:
    _PATH_CACHE.clear()

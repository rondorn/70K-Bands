from __future__ import annotations

import json
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

# Matches promoter_admin/lib/src/services/app_data_paths.dart and dropbox_auth.dart
_ADMIN_FOLDER = "OpenMetalFestAdmin"
_DROPBOX_APP_KEY = "ug24jfmymp185wi"
_K_ACCESS = "dbx_access_token"
_K_ACCESS_EXPIRES_AT_MS = "dbx_access_expires_at_ms"
_K_REFRESH = "dbx_refresh_token"
_EXPIRY_SKEW = timedelta(minutes=5)
_DEFAULT_TTL_SECONDS = 4 * 60 * 60


def admin_dropbox_auth_paths() -> list[Path]:
    """Known dropbox_auth.json locations written by promoter_admin."""
    home = Path.home()
    return [
        home / "Library/Application Support" / _ADMIN_FOLDER / "dropbox_auth.json",
        home
        / "Library/Mobile Documents"
        / "iCloud~com~rdorn~open-metal-fest-admin"
        / "Documents"
        / _ADMIN_FOLDER
        / "dropbox_auth.json",
    ]


def _existing_auth_files() -> list[Path]:
    return [path for path in admin_dropbox_auth_paths() if path.is_file()]


def _pick_auth_file(paths: list[Path]) -> Path | None:
    if not paths:
        return None
    if len(paths) == 1:
        return paths[0]
    return max(paths, key=lambda path: path.stat().st_mtime)


def _load_auth_data(path: Path) -> dict[str, str]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise ValueError(f"Invalid Dropbox auth JSON in {path}")
    return {str(key): "" if value is None else str(value) for key, value in raw.items()}


def _token_still_valid(access: str, expires_at_ms: str) -> bool:
    if not access:
        return False
    if not expires_at_ms:
        return True
    try:
        expires_at = datetime.fromtimestamp(int(expires_at_ms) / 1000, tz=timezone.utc)
    except ValueError:
        return True
    return datetime.now(tz=timezone.utc) < expires_at.astimezone(timezone.utc) - _EXPIRY_SKEW


def _refresh_access_token(refresh_token: str) -> tuple[str, int]:
    body = urllib.parse.urlencode(
        {
            "grant_type": "refresh_token",
            "refresh_token": refresh_token,
            "client_id": _DROPBOX_APP_KEY,
        }
    ).encode("utf-8")
    request = urllib.request.Request(
        "https://api.dropboxapi.com/oauth2/token",
        data=body,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Dropbox token refresh failed: {detail}") from exc

    access = str(payload.get("access_token") or "").strip()
    if not access:
        raise RuntimeError("Dropbox token refresh returned an empty access token.")
    expires_in = int(payload.get("expires_in") or _DEFAULT_TTL_SECONDS)
    return access, expires_in


def _persist_access_token(auth_files: list[Path], access: str, expires_in: int) -> None:
    expires_at = datetime.now(tz=timezone.utc) + timedelta(seconds=expires_in)
    expires_ms = str(int(expires_at.timestamp() * 1000))
    for path in auth_files:
        data = _load_auth_data(path)
        data[_K_ACCESS] = access
        data[_K_ACCESS_EXPIRES_AT_MS] = expires_ms
        contents = json.dumps(data, indent=2) + "\n"
        path.write_text(contents, encoding="utf-8")


def get_admin_dropbox_access_token() -> str:
    """
    Read Dropbox OAuth tokens saved by promoter_admin and refresh if needed.

    Returns an access token suitable for Dropbox API calls. Updates the admin
    auth file(s) when a refresh is performed so cron runs stay in sync with the app.
    """
    auth_files = _existing_auth_files()
    source = _pick_auth_file(auth_files)
    if source is None:
        raise RuntimeError(
            "Dropbox is not connected in promoter_admin. Open the admin app, "
            "connect Dropbox, then retry."
        )

    data = _load_auth_data(source)
    access = (data.get(_K_ACCESS) or "").strip()
    refresh = (data.get(_K_REFRESH) or "").strip()
    expires_at_ms = (data.get(_K_ACCESS_EXPIRES_AT_MS) or "").strip()

    if _token_still_valid(access, expires_at_ms):
        return access

    if not refresh:
        if access:
            return access
        raise RuntimeError(
            "Dropbox access token in promoter_admin is expired and no refresh "
            "token is stored. Reconnect Dropbox in the admin app."
        )

    access, expires_in = _refresh_access_token(refresh)
    _persist_access_token(auth_files, access, expires_in)
    return access

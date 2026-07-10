"""Dropbox OAuth token storage and authenticated API client."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

from data_entry.config_store import config_path

TOKEN_FILENAME = "dropbox_oauth.json"
CSRF_SESSION_KEY = "dropbox-auth-csrf-token"
PKCE_SESSION_KEY = "dropbox-auth-pkce-verifier"
# OpenMetalFestSuiteIntegration (production scoped app, PKCE — no app secret shipped).
DROPBOX_APP_KEY = "ug24jfmymp185wi"
# Scopes must be enabled on the app Permissions tab in the Dropbox developer console.
OAUTH_SCOPES = [
    "account_info.read",
    "files.content.write",
    "files.metadata.read",
    "sharing.read",
    "sharing.write",
]


class DropboxOAuthError(Exception):
    pass


def tokens_path() -> Path:
    return config_path().parent / TOKEN_FILENAME


def load_tokens() -> dict[str, str]:
    path = tokens_path()
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {}
    if not isinstance(data, dict):
        return {}
    return {str(k): str(v) for k, v in data.items() if v}


def save_tokens(data: dict[str, str]) -> None:
    path = tokens_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def clear_tokens() -> None:
    path = tokens_path()
    if path.is_file():
        path.unlink()


def oauth_app_key(cfg: dict[str, Any] | None = None) -> str:
    del cfg  # App key is built into the distributed app (Model A).
    return DROPBOX_APP_KEY


def oauth_app_secret() -> str:
    return os.environ.get("DROPBOX_APP_SECRET", "").strip()


def oauth_configured(cfg: dict[str, Any] | None = None) -> bool:
    return bool(oauth_app_key(cfg))


def oauth_connected() -> bool:
    tokens = load_tokens()
    return bool(tokens.get("refresh_token") or tokens.get("access_token"))


def oauth_account_label() -> str:
    tokens = load_tokens()
    return (
        tokens.get("account_email", "").strip()
        or tokens.get("account_name", "").strip()
        or tokens.get("account_id", "").strip()
    )


def build_oauth_flow(session: dict[str, Any], redirect_uri: str, cfg: dict[str, Any] | None = None):
    from dropbox.oauth import DropboxOAuth2Flow

    return DropboxOAuth2Flow(
        consumer_key=oauth_app_key(cfg),
        consumer_secret=oauth_app_secret() or None,
        redirect_uri=redirect_uri,
        session=session,
        csrf_token_session_key=CSRF_SESSION_KEY,
        token_access_type="offline",
        scope=OAUTH_SCOPES,
        use_pkce=True,
    )


def start_oauth_flow(session: dict[str, Any], redirect_uri: str, cfg: dict[str, Any] | None = None) -> str:
    """Begin OAuth; persist PKCE verifier in session for the callback."""
    auth_flow = build_oauth_flow(session, redirect_uri, cfg)
    authorize_url = auth_flow.start()
    if auth_flow.code_verifier:
        session[PKCE_SESSION_KEY] = auth_flow.code_verifier
    return authorize_url


def finish_oauth_flow(
    session: dict[str, Any],
    redirect_uri: str,
    query_params: dict[str, Any],
    cfg: dict[str, Any] | None = None,
):
    """Complete OAuth using the PKCE verifier saved during start."""
    auth_flow = build_oauth_flow(session, redirect_uri, cfg)
    code_verifier = session.pop(PKCE_SESSION_KEY, None)
    if not code_verifier:
        raise DropboxOAuthError(
            "Dropbox sign-in session expired. Click Connect Dropbox and try again."
        )
    auth_flow.code_verifier = code_verifier
    return auth_flow.finish(query_params)


def store_oauth_result(result: Any, cfg: dict[str, Any] | None = None) -> dict[str, str]:
    """Persist tokens and fetch account details for display."""
    from dropbox import Dropbox

    app_key = oauth_app_key(cfg)
    app_secret = oauth_app_secret()
    refresh_token = (result.refresh_token or "").strip()
    access_token = (result.access_token or "").strip()

    if not refresh_token and not access_token:
        raise DropboxOAuthError("Dropbox did not return an access or refresh token.")

    payload: dict[str, str] = {
        "app_key": app_key,
        "access_token": access_token,
        "refresh_token": refresh_token,
        "account_id": (result.account_id or "").strip(),
    }

    if access_token:
        dbx = Dropbox(access_token)
    elif refresh_token:
        dbx = Dropbox(
            oauth2_refresh_token=refresh_token,
            app_key=app_key,
            app_secret=app_secret or None,
        )
    else:
        dbx = None

    if dbx is not None:
        try:
            account = dbx.users_get_current_account()
            payload["account_email"] = (account.email or "").strip()
            payload["account_name"] = (account.name.display_name or "").strip()
            if not payload.get("account_id"):
                payload["account_id"] = (account.account_id or "").strip()
        except Exception:
            pass

    save_tokens(payload)
    return payload


def get_authenticated_client(cfg: dict[str, Any] | None = None):
    """Return a Dropbox client using OAuth tokens or DROPBOX_ACCESS_TOKEN fallback."""
    from dropbox import Dropbox

    env_token = os.environ.get("DROPBOX_ACCESS_TOKEN", "").strip()
    if env_token:
        return Dropbox(env_token)

    tokens = load_tokens()
    refresh_token = tokens.get("refresh_token", "").strip()
    access_token = tokens.get("access_token", "").strip()
    app_key = tokens.get("app_key", "").strip() or oauth_app_key(cfg)
    app_secret = oauth_app_secret()

    if refresh_token and app_key:
        return Dropbox(
            oauth2_refresh_token=refresh_token,
            app_key=app_key,
            app_secret=app_secret or None,
        )
    if access_token:
        return Dropbox(access_token)

    raise DropboxOAuthError(
        "Dropbox is not connected. Open Config and click Connect Dropbox."
    )


def dropbox_auth_status(cfg: dict[str, Any] | None = None) -> dict[str, Any]:
    """Status block for Config and description screens."""
    if os.environ.get("DROPBOX_ACCESS_TOKEN", "").strip():
        return {
            "dropbox_auth_connected": True,
            "dropbox_auth_label": "Connected via developer token (DROPBOX_ACCESS_TOKEN)",
            "dropbox_auth_can_connect": False,
            "dropbox_auth_can_disconnect": False,
        }

    connected = oauth_connected()
    label = oauth_account_label() if connected else ""
    message = ""
    if not connected:
        message = (
            "Click Connect Dropbox to sign in with your Dropbox account."
        )

    return {
        "dropbox_auth_connected": connected,
        "dropbox_auth_label": label,
        "dropbox_auth_message": message,
        "dropbox_auth_can_connect": not connected,
        "dropbox_auth_can_disconnect": connected,
    }

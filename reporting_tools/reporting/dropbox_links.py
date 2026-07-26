from __future__ import annotations

import os
from pathlib import Path
from typing import Dict


def _to_raw_url(url: str) -> str:
    u = url.strip()
    if "?" in u:
        if "raw=1" in u or "dl=1" in u:
            return u
        return u + "&raw=1"
    return u + "?raw=1"


def local_path_to_dropbox_api_path(local_path: Path) -> str:
    """Map ~/Dropbox/foo/bar.html → /foo/bar.html"""
    resolved = local_path.expanduser().resolve()
    parts = resolved.parts
    try:
        dropbox_idx = parts.index("Dropbox")
    except ValueError as exc:
        raise ValueError(
            f"Path is not under ~/Dropbox: {local_path}. "
            "Reports must live in a synced Dropbox folder."
        ) from exc
    rel = Path(*parts[dropbox_idx + 1 :])
    return "/" + rel.as_posix()


def get_dropbox_token(secrets: dict | None = None) -> str:
    token = os.environ.get("DROPBOX_ACCESS_TOKEN", "").strip()
    if token:
        return token
    if secrets:
        token = (secrets.get("dropbox_access_token") or "").strip()
    if token:
        return token

    from reporting.admin_dropbox_auth import get_admin_dropbox_access_token

    return get_admin_dropbox_access_token()


def get_or_create_shared_link(dbx, path_display: str) -> str:
    from dropbox import sharing

    try:
        link = dbx.sharing_create_shared_link_with_settings(
            path_display,
            settings=sharing.SharedLinkSettings(
                requested_visibility=sharing.RequestedVisibility.public
            ),
        )
        return _to_raw_url(link.url)
    except Exception as exc:
        links = dbx.sharing_list_shared_links(path=path_display, direct_only=True)
        if links.links:
            return _to_raw_url(links.links[0].url)
        raise exc


def shared_links_for_files(local_files: Dict[str, Path], token: str) -> Dict[str, str]:
    import dropbox

    dbx = dropbox.Dropbox(token)
    urls: Dict[str, str] = {}
    for key, path in local_files.items():
        if not path.is_file():
            raise FileNotFoundError(f"Report file not found for {key}: {path}")
        api_path = local_path_to_dropbox_api_path(path)
        print(f"  {path.name} → {api_path}")
        urls[key] = get_or_create_shared_link(dbx, api_path)
    return urls

"""Write plain-text description note files for the description map CSV."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any


def note_filename(label: str) -> str:
    slug = re.sub(r"[^a-zA-Z0-9]+", "-", (label or "").strip())
    slug = slug.strip("-")
    if not slug:
        raise ValueError("A band or event name is required for the note file name.")
    return f"{slug}.txt"


def descriptions_directory(paths: dict[str, str], cfg: dict[str, Any] | None = None) -> str:
    """
    Directory for description .txt files: a descriptions/ folder beside the map file.

    Dropbox mode: API path next to the published description map CSV.
    Local mode: filesystem path next to description_map_file.
    """
    from data_entry.config_store import load_config, uses_dropbox_api

    cfg = cfg or load_config()
    if uses_dropbox_api(cfg):
        from data_entry.dropbox_storage import notes_directory_api_path

        return notes_directory_api_path(cfg)

    map_file = (paths.get("description_map_file") or "").strip()
    if map_file:
        return str(Path(map_file).expanduser().resolve().parent / "descriptions")

    legacy = (paths.get("notes_directory") or "").strip()
    if legacy:
        return str(Path(legacy).expanduser().resolve())
    return ""


def descriptions_directory_configured(
    paths: dict[str, str], cfg: dict[str, Any] | None = None
) -> bool:
    from data_entry.config_store import load_config, uses_dropbox_api

    cfg = cfg or load_config()
    if uses_dropbox_api(cfg):
        return bool((paths.get("description_map_url") or "").strip())
    if (paths.get("description_map_file") or "").strip():
        return True
    return bool((paths.get("notes_directory") or "").strip())


def save_description_note(
    notes_dir: str | Path,
    label: str,
    content: str,
    cfg: dict[str, Any] | None = None,
    *,
    paths: dict[str, str] | None = None,
) -> Path:
    from data_entry.config_store import load_config, resolved_paths, uses_dropbox_api

    cfg = cfg or load_config()
    if uses_dropbox_api(cfg):
        from data_entry.dropbox_storage import DropboxStorageError, ensure_notes_directory, upload_note

        try:
            ensure_notes_directory(cfg)
            api_path = upload_note(label, content, cfg)
        except DropboxStorageError as exc:
            raise ValueError(str(exc)) from exc
        return Path(api_path)

    paths = paths or resolved_paths(cfg)
    directory_str = (str(notes_dir or "").strip() or descriptions_directory(paths, cfg))
    directory = Path(directory_str).expanduser().resolve()
    if not directory_str:
        raise ValueError(
            "Description map file is not configured; cannot determine descriptions folder."
        )
    directory.mkdir(parents=True, exist_ok=True)
    if not directory.is_dir():
        raise ValueError(f"Descriptions directory is not a folder: {directory}")

    filename = note_filename(label)
    path = directory / filename
    text = (content or "").replace("\r\n", "\n").replace("\r", "\n")
    if not text.strip():
        raise ValueError("Note text is required.")
    path.write_text(text if text.endswith("\n") else text + "\n", encoding="utf-8")
    return path

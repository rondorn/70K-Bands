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


def save_description_note(
    notes_dir: str | Path,
    label: str,
    content: str,
    cfg: dict[str, Any] | None = None,
) -> Path:
    from data_entry.config_store import uses_dropbox_api

    if cfg is not None and uses_dropbox_api(cfg):
        from data_entry.dropbox_storage import DropboxStorageError, upload_note

        try:
            api_path = upload_note(label, content, cfg)
        except DropboxStorageError as exc:
            raise ValueError(str(exc)) from exc
        return Path(api_path)

    directory = Path(notes_dir).expanduser().resolve()
    if not str(notes_dir or "").strip():
        raise ValueError("Notes directory is not configured.")
    directory.mkdir(parents=True, exist_ok=True)
    if not directory.is_dir():
        raise ValueError(f"Notes directory is not a folder: {directory}")

    filename = note_filename(label)
    path = directory / filename
    text = (content or "").replace("\r\n", "\n").replace("\r", "\n")
    if not text.strip():
        raise ValueError("Note text is required.")
    path.write_text(text if text.endswith("\n") else text + "\n", encoding="utf-8")
    return path

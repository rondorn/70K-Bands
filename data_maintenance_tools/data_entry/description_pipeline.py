"""Shared pipeline: description note file + Dropbox share link + map upsert."""

from __future__ import annotations

from typing import Any


def save_description_and_map(
    label: str,
    content: str,
    cfg: dict[str, Any],
    paths: dict[str, str] | None = None,
) -> tuple[str, str]:
    """
    Write a description note, publish a share link, and upsert the description map.

    Returns (share_url, note_filename).
    """
    from data_entry.config_store import description_map_write_target, resolved_paths
    from data_entry.description_map import upsert_map_entry
    from data_entry.description_notes import note_filename, save_description_note
    from data_entry.dropbox_links import share_link_for_label

    paths = paths or resolved_paths(cfg)
    label = (label or "").strip()
    content = (content or "").strip()
    if not label:
        raise ValueError("A band or event name is required.")
    if not content:
        raise ValueError("Description text is required.")

    saved = save_description_note("", label, content, cfg=cfg, paths=paths)
    share_url = share_link_for_label("", label, cfg, paths=paths)
    map_target = description_map_write_target(paths, cfg)
    if not map_target:
        raise ValueError("Description map is not configured.")
    upsert_map_entry(map_target, label, share_url, cfg=cfg)
    return share_url, getattr(saved, "name", None) or note_filename(label)

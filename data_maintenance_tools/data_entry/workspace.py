"""Festival Workspace API — promoter-facing operations over Dropbox + pointers."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from data_entry.pointer import introspect_pointer


@dataclass
class Workspace:
    """In-memory view of an open festival workspace (edits target testing)."""

    cfg: dict[str, Any]
    paths: dict[str, str]

    @property
    def testing_pointer_url(self) -> str:
        return (
            self.cfg.get("testing_pointer_url")
            or self.cfg.get("pointer_url")
            or ""
        ).strip()

    @property
    def production_pointer_url(self) -> str:
        return (self.cfg.get("production_pointer_url") or "").strip()


def apply_testing_pointer_to_config(cfg: dict[str, Any], *, force: bool = True) -> dict[str, Any]:
    """
    Load Current URLs from the testing pointer into config.

    When force=True (default), overwrite derived URL fields from the pointer.
    Also sets pointer_url to the testing pointer for legacy helpers.
    """
    from copy import deepcopy

    merged = deepcopy(cfg)
    testing = (
        merged.get("testing_pointer_url") or merged.get("pointer_url") or ""
    ).strip()
    production = (merged.get("production_pointer_url") or "").strip()
    if testing:
        merged["testing_pointer_url"] = testing
        merged["pointer_url"] = testing
    if production:
        merged["production_pointer_url"] = production
    if not testing:
        return merged

    hints = introspect_pointer(testing)
    if force or not str(merged.get("band_list_url", "")).strip():
        if hints.get("band_list_url"):
            merged["band_list_url"] = hints["band_list_url"]
    if force or not str(merged.get("schedule_url", "")).strip():
        if hints.get("schedule_url"):
            merged["schedule_url"] = hints["schedule_url"]
    if force or not str(merged.get("description_map_url", "")).strip():
        if hints.get("description_map_url"):
            merged["description_map_url"] = hints["description_map_url"]
    if hints.get("event_year") and (
        force or not str(merged.get("event_year", "")).strip()
    ):
        merged["event_year"] = hints["event_year"]

    for key in ("venues", "dates", "days", "event_types"):
        discovered = hints.get(key) or []
        if not discovered:
            continue
        if force or not _has_vocab(merged.get(key)):
            merged[key] = list(discovered)

    return merged


def _has_vocab(values: Any) -> bool:
    if not values:
        return False
    return any(str(v).strip() and str(v).strip() != " " for v in values)


def open_workspace(cfg: dict[str, Any]) -> Workspace:
    """Open workspace with paths resolved from the testing pointer."""
    from data_entry.config_store import resolved_paths

    refreshed = apply_testing_pointer_to_config(cfg, force=True)
    return Workspace(cfg=refreshed, paths=resolved_paths(refreshed))


def list_bands(workspace: Workspace) -> list[dict[str, str]]:
    from data_entry.band_logic import read_lineup
    from data_entry.lineup_staging import lineup_working_target

    target = lineup_working_target(workspace.paths, workspace.cfg)
    return read_lineup(target, workspace.cfg)


def upsert_band(
    workspace: Workspace,
    band: dict[str, str],
    *,
    description: str | None = None,
    replace_index: int | None = None,
) -> tuple[str, str]:
    """
    Write band to testing lineup working copy.

    Optional description triggers note + map side effect.
    Returns (message, description_share_url_or_empty).
    """
    from data_entry.band_logic import (
        append_band,
        read_lineup,
        replace_band_at_index,
        write_lineup,
    )
    from data_entry.description_pipeline import save_description_and_map
    from data_entry.lineup_staging import lineup_working_target

    target = lineup_working_target(workspace.paths, workspace.cfg)
    rows = read_lineup(target, workspace.cfg)
    name = (band.get("bandName") or "").strip()
    share_url = ""

    if replace_index is not None and 0 <= replace_index < len(rows):
        updated = replace_band_at_index(rows, replace_index, band)
        write_lineup(target, updated, workspace.cfg)
        message = f"{name} has been updated"
    else:
        append_band(band, target, workspace.cfg)
        message = "Band successfully added to the lineup."

    if (description or "").strip():
        share_url, filename = save_description_and_map(
            name, description or "", workspace.cfg, workspace.paths
        )
        message += f" Description saved ({filename})."

    return message, share_url


def list_schedule(workspace: Workspace):
    from data_entry.schedule_logic import read_schedule
    from data_entry.schedule_staging import schedule_working_target

    target = schedule_working_target(workspace.paths, workspace.cfg)
    return read_schedule(target, workspace.cfg)


def upsert_event(
    workspace: Workspace,
    event,
    *,
    description: str | None = None,
    replace_key: tuple[str, str, str, str] | None = None,
) -> tuple[str, str]:
    """
    Write schedule event to testing working copy.

    For special/unofficial events, optional description writes note+map and
    sets event.description_url before save.
    Returns (message, description_share_url_or_empty).
    """
    from data_entry.description_pipeline import save_description_and_map
    from data_entry.schedule_logic import (
        NON_BAND_EVENT_TYPES,
        append_schedule_event,
        replace_matching_event,
        write_schedule,
    )
    from data_entry.schedule_staging import schedule_working_target

    share_url = ""
    if (description or "").strip() and event.event_type in NON_BAND_EVENT_TYPES:
        share_url, _filename = save_description_and_map(
            event.band, description or "", workspace.cfg, workspace.paths
        )
        event.description_url = share_url

    target = schedule_working_target(workspace.paths, workspace.cfg)
    existing = list_schedule(workspace)

    if replace_key:
        orig_band, orig_venue, orig_date, orig_start = replace_key
        updated = replace_matching_event(
            existing, orig_band, orig_venue, orig_date, orig_start, event
        )
        write_schedule(target, updated, workspace.cfg)
        message = f"{event.band} has been updated"
    else:
        append_schedule_event(target, event, workspace.cfg)
        message = f"{event.band} has been added"

    if share_url:
        message += " Description saved and added to the map."

    return message, share_url


def promote(workspace: Workspace):
    from data_entry.promote import promote_testing_to_production

    return promote_testing_to_production(workspace.cfg, workspace.paths)


def preview_promote(workspace: Workspace):
    from data_entry.promote import preview_promote as _preview

    return _preview(workspace.cfg)


def create_festival(
    *,
    festival_folder: str,
    festival_name: str,
    event_year: str,
    cfg: dict[str, Any] | None = None,
    roles: list[str] | None = None,
) -> dict[str, Any]:
    """Bootstrap Dropbox layout and return a ready-to-save festival config."""
    from copy import deepcopy

    from data_entry.config_store import DEFAULT_CONFIG, STORAGE_DROPBOX, normalize_roles
    from data_entry.festival_layout import create_festival_layout

    layout = create_festival_layout(
        festival_folder,
        event_year=event_year,
        cfg=cfg,
        festival_name=festival_name,
    )
    new_cfg = deepcopy(DEFAULT_CONFIG)
    new_cfg.update(
        {
            "festival_name": festival_name,
            "event_year": event_year,
            "storage_mode": STORAGE_DROPBOX,
            "setup_complete": True,
            "roles": normalize_roles(roles)
            or ["band_list_admin", "schedule_admin", "description_admin"],
            **layout,
        }
    )
    return apply_testing_pointer_to_config(new_cfg, force=True)

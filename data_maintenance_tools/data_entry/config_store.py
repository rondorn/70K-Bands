"""Load and save festival_data_entry.json configuration."""

from __future__ import annotations

import json
import os
import re
from copy import deepcopy
from pathlib import Path
from typing import Any

CONFIG_FILENAME = "festival_data_entry.json"
REGISTRY_VERSION = 1

ROLE_BAND_LIST = "band_list_admin"
ROLE_SCHEDULE = "schedule_admin"
ROLE_DESCRIPTION = "description_admin"

ROLE_LABELS: dict[str, str] = {
    ROLE_BAND_LIST: "Band List Admin",
    ROLE_SCHEDULE: "Schedule Admin",
    ROLE_DESCRIPTION: "Description Admin",
}

# Flask endpoint -> roles that may access it (union when user has multiple roles).
ENDPOINT_ROLES: dict[str, frozenset[str]] = {
    "bands": frozenset({ROLE_BAND_LIST}),
    "band_entry": frozenset({ROLE_BAND_LIST}),
    "band_remove": frozenset({ROLE_BAND_LIST}),
    "band_view": frozenset({ROLE_BAND_LIST}),
    "band_discover": frozenset({ROLE_BAND_LIST}),
    "schedule_entry": frozenset({ROLE_SCHEDULE}),
    "schedule_remove": frozenset({ROLE_SCHEDULE}),
    "schedule_view": frozenset({ROLE_SCHEDULE}),
    "schedule_stats": frozenset({ROLE_SCHEDULE}),
    "schedule_refresh_band_list": frozenset({ROLE_SCHEDULE}),
    "descriptions_write": frozenset({ROLE_DESCRIPTION}),
    "descriptions_map": frozenset({ROLE_DESCRIPTION}),
    "descriptions_map_entry": frozenset({ROLE_DESCRIPTION}),
    "descriptions_map_remove": frozenset({ROLE_DESCRIPTION}),
    "descriptions_view": frozenset({ROLE_DESCRIPTION}),
    "descriptions_refresh_label_names": frozenset({ROLE_DESCRIPTION}),
}

ROLE_EXEMPT_ENDPOINTS = frozenset(
    {
        "static",
        "home",
        "config_page",
        "setup_wizard",
        "api_introspect",
        "api_choose_directory",
        "api_choose_file",
    }
)

DEFAULT_CONFIG: dict[str, Any] = {
    "festival_name": "",
    "pointer_url": "",
    "event_year": "",
    "roles": [],
    "setup_complete": False,
    "lineup_file": "",
    "schedule_file": "",
    "band_list_url": "",
    "schedule_url": "",
    "description_map_url": "",
    "description_map_file": "",
    "notes_directory": "",
    "venues": [" "],
    "dates": [" "],
    "days": [],
    "event_types": [
        "Show",
        "Meet and Greet",
        "Clinic",
        "Listening Party",
        "Special Event",
        "Unofficial Event",
    ],
}

SCHEDULE_HEADER = (
    "Band,Location,Date,Day,Start Time,End Time,Type,Description URL,Notes,ImageURL\n"
)
LINEUP_HEADER_BASE = (
    "bandName,officalSite,imageUrl,youtube,metalArchives,wikipedia,country,genre,noteworthy"
)
LINEUP_HEADER_WITH_PRIOR = LINEUP_HEADER_BASE + ",priorYears\n"
LINEUP_HEADER = LINEUP_HEADER_BASE + "\n"

_FESTIVAL_CONFIG_KEYS = frozenset(DEFAULT_CONFIG.keys())


def app_root() -> Path:
    env_root = (os.environ.get("FESTIVAL_DATA_ENTRY_ROOT") or "").strip()
    if env_root:
        return Path(env_root).resolve()
    env_config = (os.environ.get("FESTIVAL_DATA_ENTRY_CONFIG") or "").strip()
    if env_config:
        return Path(env_config).resolve().parent
    here = Path(__file__).resolve().parent.parent
    if (here / CONFIG_FILENAME).is_file():
        return here
    return here


def config_path() -> Path:
    env_config = (os.environ.get("FESTIVAL_DATA_ENTRY_CONFIG") or "").strip()
    if env_config:
        return Path(env_config).expanduser().resolve()
    return app_root() / CONFIG_FILENAME


def festival_id_from_name(name: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", (name or "").lower().strip())
    return slug.strip("-") or "festival"


def _normalize_festival_config(data: dict[str, Any]) -> dict[str, Any]:
    merged = deepcopy(DEFAULT_CONFIG)
    merged.update({k: v for k, v in data.items() if k in _FESTIVAL_CONFIG_KEYS})
    merged.pop("show_venues", None)
    merged.pop("include_prior_years_field", None)
    return merged


def _is_legacy_config(data: dict[str, Any]) -> bool:
    return "festivals" not in data and any(key in data for key in _FESTIVAL_CONFIG_KEYS)


def _is_registry(data: dict[str, Any]) -> bool:
    return isinstance(data.get("festivals"), dict)


def _unique_festival_id(name: str, existing: set[str]) -> str:
    base = festival_id_from_name(name) or "festival"
    if base not in existing:
        return base
    index = 2
    while f"{base}-{index}" in existing:
        index += 1
    return f"{base}-{index}"


def _allocate_new_festival_id(existing: set[str]) -> str:
    index = len(existing) + 1
    candidate = f"festival-{index}"
    while candidate in existing:
        index += 1
        candidate = f"festival-{index}"
    return candidate


def load_registry() -> dict[str, Any]:
    path = config_path()
    if not path.is_file():
        return {
            "version": REGISTRY_VERSION,
            "active_festival_id": "",
            "festivals": {},
            "last_browse_directory": "",
        }

    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a JSON object")

    if _is_legacy_config(data):
        raise ValueError(
            f"{path} uses an outdated flat configuration format. "
            "Delete or rename the file and run /setup to configure again."
        )

    if not _is_registry(data):
        raise ValueError(f"{path} is not a recognized festival configuration format")

    festivals = {
        str(fid): _normalize_festival_config(cfg)
        for fid, cfg in data.get("festivals", {}).items()
        if isinstance(cfg, dict)
    }
    active = str(data.get("active_festival_id", "") or "")
    if active not in festivals and festivals:
        active = next(iter(festivals))
    return {
        "version": REGISTRY_VERSION,
        "active_festival_id": active,
        "festivals": festivals,
        "last_browse_directory": str(data.get("last_browse_directory", "") or ""),
    }


def save_registry(registry: dict[str, Any]) -> None:
    path = config_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    festivals = registry.get("festivals", {})
    active = str(registry.get("active_festival_id", "") or "")
    if not active and festivals:
        active = next(iter(festivals))

    payload = {
        "version": REGISTRY_VERSION,
        "active_festival_id": active,
        "festivals": festivals,
    }
    last_browse = str(registry.get("last_browse_directory", "") or "").strip()
    if last_browse:
        payload["last_browse_directory"] = last_browse
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def get_last_browse_directory() -> str:
    return str(load_registry().get("last_browse_directory", "") or "").strip()


def set_last_browse_directory(path: str) -> None:
    """Remember the last folder used in a file/directory picker."""
    raw = (path or "").strip()
    if not raw:
        return
    candidate = Path(raw).expanduser()
    if candidate.is_file():
        candidate = candidate.parent
    if not candidate.is_dir():
        return
    registry = load_registry()
    registry["last_browse_directory"] = str(candidate.resolve())
    save_registry(registry)


def list_festivals(registry: dict[str, Any] | None = None) -> list[tuple[str, str]]:
    registry = registry or load_registry()
    items: list[tuple[str, str]] = []
    for festival_id, cfg in registry.get("festivals", {}).items():
        name = str(cfg.get("festival_name", "") or "").strip()
        items.append((festival_id, name or festival_id))
    items.sort(key=lambda item: item[1].lower())
    return items


def active_festival_id(registry: dict[str, Any] | None = None) -> str:
    registry = registry or load_registry()
    return str(registry.get("active_festival_id", "") or "")


def set_active_festival(festival_id: str) -> None:
    registry = load_registry()
    festival_id = (festival_id or "").strip()
    if festival_id not in registry.get("festivals", {}):
        raise ValueError(f"Unknown festival: {festival_id}")
    registry["active_festival_id"] = festival_id
    save_registry(registry)


def create_new_festival(save_current: dict[str, Any] | None = None) -> str:
    registry = load_registry()
    festivals: dict[str, dict[str, Any]] = registry.setdefault("festivals", {})

    if save_current:
        current_id = (save_current.get("_festival_id") or "").strip()
        current_cfg = {
            k: v for k, v in save_current.items() if k in _FESTIVAL_CONFIG_KEYS
        }
        if not current_id:
            current_id = _unique_festival_id(
                str(current_cfg.get("festival_name", "")), set(festivals)
            )
        festivals[current_id] = _normalize_festival_config(current_cfg)

    new_id = _allocate_new_festival_id(set(festivals))
    festivals[new_id] = deepcopy(DEFAULT_CONFIG)
    registry["active_festival_id"] = new_id
    save_registry(registry)
    return new_id


def resolve_path(path_value: str, base_dir: Path | None = None) -> str:
    raw = (path_value or "").strip()
    if not raw:
        return ""
    candidate = Path(raw).expanduser()
    if candidate.is_absolute():
        return str(candidate.resolve())
    root = base_dir or config_path().parent
    return str((root / candidate).resolve())


def load_config(festival_id: str | None = None) -> dict[str, Any]:
    registry = load_registry()
    festivals = registry.get("festivals", {})
    if not festivals:
        return deepcopy(DEFAULT_CONFIG)

    selected = (festival_id or registry.get("active_festival_id") or "").strip()
    if selected not in festivals:
        selected = next(iter(festivals))
    return deepcopy(festivals[selected])


def save_config(data: dict[str, Any], festival_id: str | None = None) -> str:
    registry = load_registry()
    festivals: dict[str, dict[str, Any]] = registry.setdefault("festivals", {})
    normalized = _normalize_festival_config(data)

    selected = (festival_id or "").strip()
    if not selected or selected not in festivals:
        selected = str(registry.get("active_festival_id", "") or "").strip()
    if not selected or selected not in festivals:
        selected = _unique_festival_id(str(normalized.get("festival_name", "")), set(festivals))

    festivals[selected] = normalized
    registry["active_festival_id"] = selected
    save_registry(registry)
    return selected


def lineup_fields() -> list[str]:
    return [
        "bandName",
        "officalSite",
        "imageUrl",
        "youtube",
        "metalArchives",
        "wikipedia",
        "country",
        "genre",
        "noteworthy",
        "priorYears",
        "city",
        "state",
    ]


def resolved_paths(cfg: dict[str, Any] | None = None) -> dict[str, str]:
    cfg = cfg or load_config()
    base = config_path().parent
    return {
        "lineup_file": resolve_path(str(cfg.get("lineup_file", "")), base),
        "schedule_file": resolve_path(str(cfg.get("schedule_file", "")), base),
        "band_list_url": str(cfg.get("band_list_url", "") or "").strip(),
        "schedule_url": str(cfg.get("schedule_url", "") or "").strip(),
        "pointer_url": str(cfg.get("pointer_url", "") or "").strip(),
        "notes_directory": resolve_path(str(cfg.get("notes_directory", "")), base),
        "description_map_file": resolve_path(str(cfg.get("description_map_file", "")), base),
        "description_map_url": str(cfg.get("description_map_url", "") or "").strip(),
    }


def read_sources(cfg: dict[str, Any] | None = None) -> dict[str, str]:
    """Network URLs used for read operations that are not served from a local write file."""
    paths = resolved_paths(cfg)
    return {
        "band_list_url": paths.get("band_list_url", ""),
        "schedule_url": paths.get("schedule_url", ""),
        "description_map_url": paths.get("description_map_url", ""),
    }


def band_list_reads_local(cfg: dict[str, Any] | None = None) -> bool:
    """
    Band List Admin with a local lineup path reads the band list from that file
    so new entries appear before the published URL is updated.
    """
    cfg = cfg or load_config()
    if ROLE_BAND_LIST not in normalize_roles(cfg.get("roles")):
        return False
    return bool(str(cfg.get("lineup_file", "") or "").strip())


def schedule_reads_local(cfg: dict[str, Any] | None = None) -> bool:
    """
    Schedule Admin with a local schedule path reads the schedule from that file
    so new entries appear before the published URL is updated.
    """
    cfg = cfg or load_config()
    if ROLE_SCHEDULE not in normalize_roles(cfg.get("roles")):
        return False
    return bool(str(cfg.get("schedule_file", "") or "").strip())


def description_map_reads_local(cfg: dict[str, Any] | None = None) -> bool:
    """
    Description Admin with a local map path reads the map from that file
    so new entries appear before the published URL is updated.
    """
    cfg = cfg or load_config()
    if ROLE_DESCRIPTION not in normalize_roles(cfg.get("roles")):
        return False
    return bool(str(cfg.get("description_map_file", "") or "").strip())


def needs_setup(registry: dict[str, Any] | None = None) -> bool:
    """True when no saved festival configuration exists yet or roles are not set."""
    path = config_path()
    if not path.is_file():
        return True
    registry = registry or load_registry()
    if not registry.get("festivals"):
        return True
    festivals = registry.get("festivals", {})
    active = str(registry.get("active_festival_id", "") or "")
    if active not in festivals and festivals:
        active = next(iter(festivals))
    if active not in festivals:
        return True
    return not normalize_roles(festivals[active].get("roles"))


def normalize_roles(roles: list[str] | None) -> list[str]:
    valid = {ROLE_BAND_LIST, ROLE_SCHEDULE, ROLE_DESCRIPTION}
    seen: list[str] = []
    for role in roles or []:
        value = str(role).strip()
        if value in valid and value not in seen:
            seen.append(value)
    return seen


def effective_roles(cfg: dict[str, Any] | None = None) -> set[str]:
    """Roles used for nav and access control."""
    cfg = cfg or load_config()
    return set(normalize_roles(cfg.get("roles")))


def role_nav_flags(cfg: dict[str, Any] | None = None) -> dict[str, bool]:
    roles = effective_roles(cfg)
    return {
        "role_band_list": ROLE_BAND_LIST in roles,
        "role_schedule": ROLE_SCHEDULE in roles,
        "role_description": ROLE_DESCRIPTION in roles,
    }


def default_landing_endpoint(cfg: dict[str, Any] | None = None) -> str:
    roles = effective_roles(cfg)
    if ROLE_SCHEDULE in roles:
        return "schedule_entry"
    if ROLE_BAND_LIST in roles:
        return "bands"
    if ROLE_DESCRIPTION in roles:
        return "descriptions_write"
    return "config_page"


def endpoint_allowed_for_roles(endpoint: str | None, cfg: dict[str, Any] | None = None) -> bool:
    if not endpoint or endpoint in ROLE_EXEMPT_ENDPOINTS:
        return True
    required = ENDPOINT_ROLES.get(endpoint)
    if required is None:
        return True
    return bool(effective_roles(cfg) & required)


def roles_from_form(form_roles: list[str] | None) -> list[str]:
    return normalize_roles(form_roles)


def fields_required_for_roles(roles: list[str]) -> dict[str, bool]:
    """Which config fields are required for the selected admin roles."""
    roles = normalize_roles(roles)
    return {
        "lineup_file": ROLE_BAND_LIST in roles,
        "schedule_file": ROLE_SCHEDULE in roles,
        "description_map_file": ROLE_DESCRIPTION in roles,
        "notes_directory": ROLE_DESCRIPTION in roles or ROLE_SCHEDULE in roles,
        "pointer_url": ROLE_SCHEDULE in roles,
        "venues": ROLE_SCHEDULE in roles,
        "dates": ROLE_SCHEDULE in roles,
        "days": ROLE_SCHEDULE in roles,
        "event_types": ROLE_SCHEDULE in roles,
    }


def validate_config_for_roles(
    cfg: dict[str, Any], *, require_local_paths: bool = True
) -> list[str]:
    """Return human-readable validation errors for role-specific requirements."""
    roles = normalize_roles(cfg.get("roles"))
    if not roles:
        return ["Select at least one admin role."]

    required = fields_required_for_roles(roles)
    errors: list[str] = []

    def _missing_text(field: str, label: str) -> None:
        value = cfg.get(field)
        if isinstance(value, list):
            non_blank = [str(v).strip() for v in value if str(v).strip() and str(v).strip() != " "]
            if not non_blank:
                errors.append(f"{label} is required for your selected role(s).")
            return
        if not str(value or "").strip():
            errors.append(f"{label} is required for your selected role(s).")

    if require_local_paths:
        if required["lineup_file"]:
            _missing_text("lineup_file", "Lineup file (local write path)")
        if required["schedule_file"]:
            _missing_text("schedule_file", "Schedule file (local write path)")
        if required["description_map_file"]:
            _missing_text("description_map_file", "Description map file (local write path)")
        if required["notes_directory"]:
            _missing_text("notes_directory", "Notes directory (local write path)")
    if required["pointer_url"]:
        _missing_text("pointer_url", "Pointer URL")
    if required["venues"]:
        _missing_text("venues", "Venues")
    if required["dates"]:
        _missing_text("dates", "Dates")
    if required["days"]:
        _missing_text("days", "Days")
    if required["event_types"]:
        _missing_text("event_types", "Event types")

    if not str(cfg.get("festival_name", "")).strip():
        errors.append("Festival name is required.")

    return errors


def ensure_data_files(cfg: dict[str, Any] | None = None) -> None:
    cfg = cfg or load_config()
    paths = resolved_paths(cfg)

    for key, header in (
        ("lineup_file", LINEUP_HEADER_WITH_PRIOR),
        ("schedule_file", SCHEDULE_HEADER),
    ):
        path_str = paths.get(key, "")
        if not path_str:
            continue
        path = Path(path_str)
        path.parent.mkdir(parents=True, exist_ok=True)
        if not path.is_file():
            path.write_text(header, encoding="utf-8")


def list_from_textarea(text: str) -> list[str]:
    items: list[str] = []
    for line in (text or "").splitlines():
        value = line.strip()
        if value and value not in items:
            items.append(value)
    return items or [" "]


def textarea_from_list(values: list[str]) -> str:
    return "\n".join(values or [])


def merge_pointer_hints(cfg: dict[str, Any], hints: dict[str, Any]) -> dict[str, Any]:
    """Apply pointer introspection without overwriting non-empty user values."""
    merged = deepcopy(cfg)
    if hints.get("event_year") and not str(merged.get("event_year", "")).strip():
        merged["event_year"] = hints["event_year"]
    if hints.get("band_list_url") and not str(merged.get("band_list_url", "")).strip():
        merged["band_list_url"] = hints["band_list_url"]
    if hints.get("schedule_url") and not str(merged.get("schedule_url", "")).strip():
        merged["schedule_url"] = hints["schedule_url"]
    if hints.get("description_map_url") and not str(
        merged.get("description_map_url", "")
    ).strip():
        merged["description_map_url"] = hints["description_map_url"]

    for key in ("venues", "dates", "days"):
        existing = merged.get(key) or []
        discovered = hints.get(key) or []
        combined: list[str] = []
        for value in existing + discovered:
            v = str(value).strip()
            if not v:
                continue
            if v not in combined:
                combined.append(v)
        if key in ("venues", "dates", "days") and " " not in combined:
            combined.insert(0, " ")
        merged[key] = combined or existing

    existing_types = merged.get("event_types") or []
    discovered_types = hints.get("event_types") or []
    if discovered_types:
        combined_types: list[str] = []
        for value in existing_types + discovered_types:
            v = str(value).strip()
            if v and v not in combined_types:
                combined_types.append(v)
        merged["event_types"] = combined_types or existing_types

    return merged

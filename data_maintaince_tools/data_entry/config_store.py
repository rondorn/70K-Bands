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

DEFAULT_CONFIG: dict[str, Any] = {
    "festival_name": "",
    "pointer_url": "",
    "event_year": "",
    "lineup_file": "./artistLineup.csv",
    "schedule_file": "./artistSchedule.csv",
    "band_list_url": "",
    "description_map_url": "",
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
    "include_prior_years_field": False,
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
        return {"version": REGISTRY_VERSION, "active_festival_id": "", "festivals": {}}

    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a JSON object")

    if _is_legacy_config(data):
        festival_id = _unique_festival_id(str(data.get("festival_name", "")), set())
        normalized = _normalize_festival_config(data)
        return {
            "version": REGISTRY_VERSION,
            "active_festival_id": festival_id,
            "festivals": {festival_id: normalized},
        }

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
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


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


def lineup_fields(include_prior: bool) -> list[str]:
    base = [
        "bandName",
        "officalSite",
        "imageUrl",
        "youtube",
        "metalArchives",
        "wikipedia",
        "country",
        "genre",
        "noteworthy",
    ]
    if include_prior:
        base.append("priorYears")
    return base


def resolved_paths(cfg: dict[str, Any] | None = None) -> dict[str, str]:
    cfg = cfg or load_config()
    base = config_path().parent
    return {
        "lineup_file": resolve_path(str(cfg.get("lineup_file", "")), base),
        "schedule_file": resolve_path(str(cfg.get("schedule_file", "")), base),
        "band_list_url": str(cfg.get("band_list_url", "") or "").strip(),
        "pointer_url": str(cfg.get("pointer_url", "") or "").strip(),
        "notes_directory": resolve_path(str(cfg.get("notes_directory", "")), base),
    }


def ensure_data_files(cfg: dict[str, Any] | None = None) -> None:
    cfg = cfg or load_config()
    paths = resolved_paths(cfg)
    include_prior = bool(cfg.get("include_prior_years_field"))

    for key, header in (
        ("lineup_file", LINEUP_HEADER_WITH_PRIOR if include_prior else LINEUP_HEADER),
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
    return merged

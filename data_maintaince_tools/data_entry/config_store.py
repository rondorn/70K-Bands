"""Load and save festival_data_entry.json configuration."""

from __future__ import annotations

import json
import os
from copy import deepcopy
from pathlib import Path
from typing import Any

CONFIG_FILENAME = "festival_data_entry.json"

DEFAULT_CONFIG: dict[str, Any] = {
    "festival_name": "",
    "pointer_url": "",
    "event_year": "",
    "lineup_file": "./artistLineup.csv",
    "schedule_file": "./artistSchedule.csv",
    "band_list_url": "",
    "venues": [" "],
    "dates": [" "],
    "days": [],
    "event_types": [
        "Show",
        "Meet and Greet",
        "Clinic",
        "Listening Party",
        "Special Event",
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


def resolve_path(path_value: str, base_dir: Path | None = None) -> str:
    raw = (path_value or "").strip()
    if not raw:
        return ""
    candidate = Path(raw).expanduser()
    if candidate.is_absolute():
        return str(candidate.resolve())
    root = base_dir or config_path().parent
    return str((root / candidate).resolve())


def load_config() -> dict[str, Any]:
    path = config_path()
    if not path.is_file():
        return deepcopy(DEFAULT_CONFIG)
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a JSON object")
    merged = deepcopy(DEFAULT_CONFIG)
    merged.update(data)
    merged.pop("show_venues", None)  # legacy; single venue list only
    return merged


def save_config(data: dict[str, Any]) -> None:
    path = config_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


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

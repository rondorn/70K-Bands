from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from reporting.auth import default_secrets_path, load_secrets, resolve_firebase_export
from reporting.models import FestivalConfig
from reporting.naming import with_event_year

PACKAGE_ROOT = Path(__file__).resolve().parent
TOOLS_ROOT = PACKAGE_ROOT.parent


def expand_path(value: str) -> Path:
    return Path(value).expanduser().resolve()


def default_config_path() -> Path:
    local = TOOLS_ROOT / "festivals.json"
    if local.exists():
        return local
    return TOOLS_ROOT / "festivals.example.json"


def load_raw_config(config_path: Path | None = None) -> dict[str, Any]:
    path = config_path or default_config_path()
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def resolve_festival(
    raw: dict[str, Any],
    festival_id: str,
    secrets: dict[str, Any] | None = None,
) -> FestivalConfig:
    festivals = raw.get("festivals", {})
    if festival_id not in festivals:
        known = ", ".join(sorted(festivals))
        raise ValueError(f"Unknown festival '{festival_id}'. Known festivals: {known}")

    entry = festivals[festival_id]
    output_dir = expand_path(entry["output_dir"])
    usage = entry.get("usage_history", {})
    reports = entry["reports"]
    csv_files = entry.get("csv_files", {})
    secrets = secrets if secrets is not None else load_secrets()

    firebase = resolve_firebase_export(festival_id, entry, secrets)

    return FestivalConfig(
        id=festival_id,
        name=entry.get("name", festival_id),
        pointer_url=entry["pointer_url"],
        pointer_path=expand_path(entry["pointer_path"]),
        public_data_dir=expand_path(entry["public_data_dir"]),
        data_dir=expand_path(entry["data_dir"]),
        output_dir=output_dir,
        firebase_export_url=firebase.url,
        firebase_service_account=firebase.service_account,
        json_backup_path=output_dir / entry["json_backup_filename"],
        reports_main=reports["main"],
        reports_full=reports["full"],
        reports_languages=dict(reports.get("languages", {})),
        min_votes=int(entry.get("min_votes", 50)),
        total_user_base_for_attendance=int(
            entry.get("total_user_base_for_attendance", 2920)
        ),
        daily_history_path=output_dir / usage.get("daily", "daily_usage_history.json"),
        monthly_history_path=output_dir / usage.get(
            "monthly", "monthly_usage_history.json"
        ),
        user_data_csv=expand_path(
            csv_files.get("user_data", str(output_dir / "userData.csv"))
        ),
        ranking_data_csv=expand_path(
            csv_files.get("ranking_data", str(output_dir / "rankingData.csv"))
        ),
        event_data_csv=expand_path(
            csv_files.get("event_data", str(output_dir / "eventData.csv"))
        ),
        firebase_use_adc=firebase.use_adc,
        firebase_project_id=firebase.project_id,
    )


def apply_event_year_to_reports(config: FestivalConfig) -> None:
    """Add event year from the production pointer to all report output filenames."""
    year = (config.event_year or "").strip()
    if not year:
        return
    config.reports_main = with_event_year(config.reports_main, year)
    config.reports_full = with_event_year(config.reports_full, year)
    config.reports_languages = {
        lang: with_event_year(name, year)
        for lang, name in config.reports_languages.items()
    }


def list_festival_ids(config_path: Path | None = None) -> list[str]:
    raw = load_raw_config(config_path)
    return sorted(raw.get("festivals", {}).keys())


def load_festivals(
    festival_ids: list[str] | None = None,
    config_path: Path | None = None,
    secrets_path: Path | None = None,
) -> list[FestivalConfig]:
    raw = load_raw_config(config_path)
    secrets = load_secrets(secrets_path or default_secrets_path())
    ids = festival_ids or list_festival_ids(config_path)
    return [resolve_festival(raw, festival_id, secrets) for festival_id in ids]

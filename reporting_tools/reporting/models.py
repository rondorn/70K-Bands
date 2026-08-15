from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass
class FestivalConfig:
    """Resolved festival configuration from festivals.json."""

    id: str
    name: str
    pointer_url: str
    pointer_path: Path
    public_data_dir: Path
    data_dir: Path
    output_dir: Path
    firebase_export_url: str
    firebase_service_account: Path | None
    json_backup_path: Path
    reports_main: str
    reports_full: str
    reports_languages: dict[str, str]
    min_votes: int
    total_user_base_for_attendance: int
    daily_history_path: Path
    monthly_history_path: Path
    user_data_csv: Path
    ranking_data_csv: Path
    event_data_csv: Path

    # Populated after pointer sync
    event_year: str = ""
    artist_lineup_path: Path | None = None
    artist_schedule_path: Path | None = None
    firebase_use_adc: bool = False
    firebase_project_id: str = ""


@dataclass
class UserRecord:
    num_bands_ranked: int
    num_shows_marked: int
    country: str
    language: str
    last_launch: str
    platform: str
    userid: str
    os_version: str
    app_version: str
    active_profiles: str

    def to_csv_row(self) -> dict[str, str]:
        return {
            "numBandsRanked": str(self.num_bands_ranked),
            "numShowsMarked": str(self.num_shows_marked),
            "country": self.country,
            "language": self.language,
            "last launch": self.last_launch,
            "platform": self.platform,
            "userid": self.userid,
            "osVersion": self.os_version,
            "70kVersion": self.app_version,
            "activeProfiles": self.active_profiles,
        }


@dataclass
class RankingRecord:
    band_name: str
    ranking: str
    unique_id: str
    user_id: str
    year: str

    def to_csv_row(self) -> dict[str, str]:
        return {
            "bandName": self.band_name,
            "ranking": self.ranking,
            "unuiqueID": self.unique_id,
            "userID": self.user_id,
            "year": self.year,
        }


@dataclass
class EventRecord:
    band_name: str
    event_type: str
    location: str
    start_time_hour: str
    start_time_min: str
    status: str
    unique_id: str
    user_id: str
    year: str

    def to_csv_row(self) -> dict[str, str]:
        return {
            "bandName": self.band_name,
            "eventType": self.event_type,
            "location": self.location,
            "startTimeHour": self.start_time_hour,
            "startTimeMin": self.start_time_min,
            "status": self.status,
            "unuiqueID": self.unique_id,
            "userID": self.user_id,
            "year": self.year,
        }


@dataclass
class BandCountRow:
    band_name: str
    must: int
    might: int
    wont: int


@dataclass
class FestivalDataset:
    """Organized in-memory data for a festival report run."""

    config: FestivalConfig
    firebase_json: dict[str, Any]
    users: list[UserRecord] = field(default_factory=list)
    rankings: list[RankingRecord] = field(default_factory=list)
    events: list[EventRecord] = field(default_factory=list)
    band_counts: list[BandCountRow] = field(default_factory=list)
    lineup_rows: list[dict[str, str]] = field(default_factory=list)
    schedule_rows: list[dict[str, str]] = field(default_factory=list)

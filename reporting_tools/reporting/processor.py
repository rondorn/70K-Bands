from __future__ import annotations

import csv
import re
from calendar import timegm
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

from reporting.models import (
    BandCountRow,
    EventRecord,
    FestivalConfig,
    FestivalDataset,
    RankingRecord,
    UserRecord,
)

PACKAGE_ROOT = Path(__file__).resolve().parent
COUNTRY_CODES_FILE = PACKAGE_ROOT / "data" / "country_codes.csv"
ACTIVE_USER_DAYS = 30
EVENT_CUTOFF = 1


def _as_str(value: object, default: str = "") -> str:
    if value is None:
        return default
    return str(value).strip()


def _normalize_date_digits(value: str | None) -> str:
    if value is None:
        return ""
    arabic_indic = "٠١٢٣٤٥٦٧٨٩"
    extended_arabic = "۰۱۲۳۴۵۶۷۸۹"
    result = str(value)
    for idx, digit in enumerate("0123456789"):
        result = result.replace(arabic_indic[idx], digit)
        result = result.replace(extended_arabic[idx], digit)
    return result


def _date_to_epoch(date_str: str) -> int | None:
    match = re.match(r"^(\d{4})-(\d{2})-(\d{2})$", date_str or "")
    if not match:
        return None
    year, month, day = (int(match.group(i)) for i in range(1, 4))
    try:
        return timegm((year, month, day, 0, 0, 0))
    except ValueError:
        return None


def _load_country_codes() -> dict[str, str]:
    codes: dict[str, str] = {}
    with COUNTRY_CODES_FILE.open(encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            code = (row.get("Code") or "").strip().upper()
            country = (row.get("Country") or "").strip()
            country = country.split(",")[0].strip().strip("'\"")
            country = " ".join(part.capitalize() for part in country.split())
            if code:
                codes[code] = country
    return codes


def _read_csv_rows(path: Path | None) -> list[dict[str, str]]:
    if not path or not path.exists():
        return []

    rows: list[dict[str, str]] = []
    with path.open(encoding="utf-8", errors="replace") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames:
            return []
        for row in reader:
            rows.append({k.strip(): (v or "").strip() for k, v in row.items()})
    return rows


def _build_valid_bands(
    lineup_rows: list[dict[str, str]],
    schedule_rows: list[dict[str, str]],
) -> set[str]:
    bands: set[str] = set()
    for row in lineup_rows:
        name = (row.get("bandName") or "").strip()
        if name:
            bands.add(name)
    if len(schedule_rows) > 1:
        for row in schedule_rows:
            name = (row.get("Band") or "").strip()
            if name:
                bands.add(name)
    return bands


def _normalize_event_key(value: str) -> str:
    return re.sub(r"[\s\-\\]", "", value or "")


def _build_valid_events(
    schedule_rows: list[dict[str, str]], event_year: str
) -> dict[str, str]:
    valid: dict[str, str] = {}
    for event in schedule_rows:
        name = (event.get("Band") or "").strip()
        location = (event.get("Location") or "").strip()
        start_time = (event.get("Start Time") or "").strip()
        event_type = (event.get("Type") or "").strip()
        if event_type == "Unofficial Event":
            event_type = "CruiserOrganized"
        if not (name and location and start_time):
            continue
        unique_id = (
            _normalize_event_key(name)
            + ":"
            + _normalize_event_key(location)
            + ":"
            + start_time
            + ":"
            + event_type
            + ":"
            + event_year
        )
        valid[unique_id] = unique_id
    return valid


def process_firebase_data(
    config: FestivalConfig, firebase_json: dict[str, Any]
) -> FestivalDataset:
    lineup_rows = _read_csv_rows(config.artist_lineup_path)
    schedule_rows = _read_csv_rows(config.artist_schedule_path)
    valid_bands = _build_valid_bands(lineup_rows, schedule_rows)
    valid_events = _build_valid_events(schedule_rows, config.event_year)
    country_codes = _load_country_codes()

    cutoff_epoch = int((datetime.now() - timedelta(days=ACTIVE_USER_DAYS)).timestamp())

    users: list[UserRecord] = []
    rankings: list[RankingRecord] = []
    events: list[EventRecord] = []
    band_vote_totals: dict[str, dict[str, int]] = {}
    counts_by_user_bands: dict[str, int] = {}
    counts_by_user_events: dict[str, int] = {}

    dedupe_rankings: set[str] = set()
    dedupe_events: set[str] = set()

    print(f"Processing Firebase data for {config.name}...")
    print(f"  Valid bands in lineup: {len(valid_bands)}")
    print(f"  Event year: {config.event_year}")

    band_data = firebase_json.get("bandData") or {}
    for user_id, years in band_data.items():
        if not isinstance(years, dict):
            continue
        for year, bands in years.items():
            if not year or not isinstance(bands, dict):
                continue
            for firebase_key, data in bands.items():
                if not isinstance(data, dict):
                    continue
                display_name = (data.get("bandName") or firebase_key).strip()
                if display_name not in valid_bands:
                    continue

                ranking = (data.get("ranking") or "").strip()
                unique_id = f"{user_id}-{year}-{display_name}"
                if unique_id in dedupe_rankings:
                    continue
                dedupe_rankings.add(unique_id)

                rankings.append(
                    RankingRecord(
                        band_name=display_name,
                        ranking=ranking,
                        unique_id=unique_id,
                        user_id=user_id,
                        year=str(year),
                    )
                )

                if ranking in ("Must", "Might"):
                    counts_by_user_bands[user_id] = (
                        counts_by_user_bands.get(user_id, 0) + 1
                    )

                bucket = band_vote_totals.setdefault(
                    display_name, {"Must": 0, "Might": 0, "Wont": 0}
                )
                if ranking in bucket:
                    bucket[ranking] += 1

    show_data = firebase_json.get("showData") or {}
    user_event_totals: dict[str, int] = {}

    for user_id, user_shows in show_data.items():
        if not isinstance(user_shows, dict):
            continue
        year_block = user_shows.get(config.event_year)
        if not isinstance(year_block, dict):
            continue
        user_event_totals[user_id] = len(year_block)

    for user_id, user_shows in show_data.items():
        if not isinstance(user_shows, dict):
            continue
        year_block = user_shows.get(config.event_year)
        if not isinstance(year_block, dict):
            continue
        if user_event_totals.get(user_id, 0) < EVENT_CUTOFF:
            continue

        for index, data in year_block.items():
            if not isinstance(data, dict):
                continue
            alt_index = _normalize_event_key(index)
            if alt_index not in valid_events:
                continue

            status = (data.get("status") or "").split(":")[0]
            if status not in ("sawAll", "sawSome"):
                continue

            unique_id = f"{user_id}-{index}"
            if unique_id in dedupe_events:
                continue
            dedupe_events.add(unique_id)

            events.append(
                EventRecord(
                    band_name=(data.get("bandName") or "").strip(),
                    event_type=(data.get("eventType") or "").strip(),
                    location=(data.get("location") or "").strip(),
                    start_time_hour=str(data.get("startTimeHour", "")),
                    start_time_min=str(data.get("startTimeMin", "")),
                    status=status,
                    unique_id=unique_id,
                    user_id=user_id,
                    year=config.event_year,
                )
            )
            counts_by_user_events[user_id] = (
                counts_by_user_events.get(user_id, 0) + 1
            )

    user_data = firebase_json.get("userData") or {}
    skipped_invalid_launch = 0

    for user_id, data in user_data.items():
        if not isinstance(data, dict):
            continue

        last_launch = _normalize_date_digits(data.get("lastLaunch"))
        if not last_launch:
            skipped_invalid_launch += 1
            continue

        date_part = last_launch[:10]
        epoch = _date_to_epoch(date_part)
        if epoch is None or epoch < cutoff_epoch:
            continue

        country_code = _as_str(data.get("country")).upper()
        country = country_codes.get(country_code, "Unknown")

        os_version = _as_str(data.get("osVersion"), "Unknown") or "Unknown"
        app_version = _as_str(data.get("70kVersion"), "Unknown") or "Unknown"

        users.append(
            UserRecord(
                num_bands_ranked=counts_by_user_bands.get(user_id, 0),
                num_shows_marked=counts_by_user_events.get(user_id, 0),
                country=country,
                language=_as_str(data.get("language")),
                last_launch=last_launch,
                platform=_as_str(data.get("platform")),
                userid=user_id,
                os_version=os_version,
                app_version=app_version,
                active_profiles=_as_str(data.get("activeProfiles")),
            )
        )

    band_counts = [
        BandCountRow(
            band_name=band,
            must=votes.get("Must", 0),
            might=votes.get("Might", 0),
            wont=votes.get("Wont", 0),
        )
        for band, votes in sorted(band_vote_totals.items())
    ]

    if skipped_invalid_launch:
        print(f"  Skipped {skipped_invalid_launch} users with invalid lastLaunch")

    print(f"  Active users (last {ACTIVE_USER_DAYS} days): {len(users)}")
    print(f"  Ranking rows: {len(rankings)}")
    print(f"  Event rows: {len(events)}")

    return FestivalDataset(
        config=config,
        firebase_json=firebase_json,
        users=users,
        rankings=rankings,
        events=events,
        band_counts=band_counts,
        lineup_rows=lineup_rows,
        schedule_rows=schedule_rows,
    )

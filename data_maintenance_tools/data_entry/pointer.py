"""Parse production pointer files and extract schedule metadata."""

from __future__ import annotations

import csv
import io
import re
from datetime import datetime
from typing import Any
from urllib.parse import unquote, urlparse

from data_entry.http_util import fetch_url, normalize_dropbox_url

DATE_RE = re.compile(r"^(\d{1,2})/(\d{1,2})/(\d{4})$")
DAY_NUM_RE = re.compile(r"^Day\s+(\d+)$", re.I)


def _parse_date_parts(value: str) -> tuple[int, int, int] | None:
    m = DATE_RE.match((value or "").strip())
    if not m:
        return None
    return int(m.group(1)), int(m.group(2)), int(m.group(3))


def format_date_short(month: int, day: int, year: int) -> str:
    """Format as m/d/yyyy without leading zeros on month or day."""
    return f"{month}/{day}/{year}"


def normalize_date(value: str, target_year: int | None = None) -> str | None:
    """Parse a date string and return shortest m/d/yyyy form, optionally shifting year."""
    parts = _parse_date_parts(value)
    if not parts:
        return None
    month, day, year = parts
    if target_year is not None:
        year = target_year
    return format_date_short(month, day, year)


def normalize_dates(values: set[str] | list[str], target_year: int) -> list[str]:
    """
    Collapse equivalent dates (e.g. 01/01/2027 and 1/1/2027) to shortest form,
    shift to target_year, and return chronologically sorted unique values.
    """
    by_datetime: dict[datetime, str] = {}
    unparsed: list[str] = []

    for value in values:
        parts = _parse_date_parts(value)
        if not parts:
            raw = (value or "").strip()
            if raw:
                unparsed.append(raw)
            continue
        month, day, _year = parts
        dt = datetime(target_year, month, day)
        by_datetime[dt] = format_date_short(month, day, target_year)

    ordered = [by_datetime[dt] for dt in sorted(by_datetime.keys())]
    for raw in sorted(set(unparsed)):
        if raw not in ordered:
            ordered.append(raw)
    return ordered


def order_days_from_schedule(
    schedule_rows: list[dict[str, str]], target_year: int
) -> list[str]:
    """
    Order day labels by the chronological dates they appear on in the schedule.
    Fixes Day 2 appearing before Day 1 when the source CSV order is wrong.
    """
    date_to_days: dict[datetime, list[str]] = {}
    orphan_days: list[str] = []

    for row in schedule_rows:
        day = (row.get("Day") or "").strip()
        if not day:
            continue
        parts = _parse_date_parts((row.get("Date") or "").strip())
        if not parts:
            if day not in orphan_days:
                orphan_days.append(day)
            continue
        month, day_num, _year = parts
        dt = datetime(target_year, month, day_num)
        bucket = date_to_days.setdefault(dt, [])
        if day not in bucket:
            bucket.append(day)

    def _label_sort_key(label: str) -> tuple[int, int | str]:
        match = DAY_NUM_RE.match(label)
        if match:
            return (1, int(match.group(1)))
        return (0, label.casefold())

    ordered: list[str] = []
    seen: set[str] = set()
    for dt in sorted(date_to_days.keys()):
        for label in sorted(date_to_days[dt], key=_label_sort_key):
            if label not in seen:
                seen.add(label)
                ordered.append(label)

    for label in orphan_days:
        if label not in seen:
            ordered.append(label)

    return ordered


def parse_pointer_text(text: str) -> dict[str, dict[str, str]]:
    sections: dict[str, dict[str, str]] = {}
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.count("::") < 2:
            continue
        section, key, value = line.split("::", 2)
        sections.setdefault(section, {})[key] = value
    return sections


def fetch_pointer(url: str) -> dict[str, dict[str, str]]:
    return parse_pointer_text(fetch_url(normalize_dropbox_url(url)))


def _parse_schedule_csv(text: str) -> list[dict[str, str]]:
    if not text.strip():
        return []
    reader = csv.DictReader(io.StringIO(text))
    if not reader.fieldnames:
        return []
    rows: list[dict[str, str]] = []
    for row in reader:
        rows.append({k: (v or "").strip() for k, v in row.items()})
    return rows


def _parse_event_types_list(raw: str) -> list[str]:
    """Parse event types from pointer metadata (comma- or pipe-separated)."""
    types: list[str] = []
    for part in re.split(r"[,|]", raw or ""):
        value = part.strip()
        if value and value not in types:
            types.append(value)
    return types


def _event_types_from_pointer_section(section: dict[str, str]) -> list[str]:
    for key in ("eventTypes", "event_types", "eventTypeList"):
        raw = str(section.get(key, "") or "").strip()
        if raw:
            return _parse_event_types_list(raw)
    return []


def extract_schedule_hints(schedule_rows: list[dict[str, str]]) -> dict[str, Any]:
    venues: set[str] = set()
    dates: set[str] = set()
    days: list[str] = []
    event_types: list[str] = []

    for row in schedule_rows:
        location = row.get("Location", "").strip()
        if location:
            venues.add(location)
        date = row.get("Date", "").strip()
        if date:
            dates.add(date)
        day = row.get("Day", "").strip()
        if day and day not in days:
            days.append(day)
        event_type = (row.get("Type") or "").strip()
        if event_type and event_type not in event_types:
            event_types.append(event_type)

    return {
        "venues": venues,
        "dates": dates,
        "days": days,
        "event_types": event_types,
    }


def _numeric_years(sections: dict[str, dict[str, str]]) -> list[str]:
    return sorted((name for name in sections if name.isdigit()), reverse=True)


def _current_event_year(sections: dict[str, dict[str, str]]) -> str:
    current = sections.get("Current", {})
    year = str(current.get("eventYear", "")).strip()
    if year.isdigit():
        return year
    numeric = _numeric_years(sections)
    return numeric[0] if numeric else ""


def _prior_year_section(sections: dict[str, dict[str, str]]) -> str:
    """
    Section to use for venue/date hints: the year immediately below Current::eventYear.
    """
    current_year = _current_event_year(sections)
    if current_year.isdigit():
        prior = str(int(current_year) - 1)
        if prior in sections:
            return prior
        for year in _numeric_years(sections):
            if int(year) < int(current_year):
                return year
    numeric = _numeric_years(sections)
    return numeric[0] if numeric else ""


def introspect_pointer(pointer_url: str, _max_years: int = 8) -> dict[str, Any]:
    """
    Fetch a pointer file and learn venues, dates, days, and event types from the schedule
    year below Current::eventYear. Band URLs and event year come from Current.
    """
    sections = fetch_pointer(pointer_url)
    current = sections.get("Current", {})
    if not current:
        raise ValueError("Pointer file has no Current section.")

    current_year = _current_event_year(sections)
    prior_section = _prior_year_section(sections)
    if not prior_section:
        raise ValueError(
            f"Pointer file has Current::eventYear {current_year or '(missing)'} "
            "but no prior year section was found for schedule data."
        )

    section = sections.get(prior_section, {})
    schedule_url = section.get("scheduleUrl", "").strip()
    if not schedule_url:
        raise ValueError(f"Section {prior_section} has no scheduleUrl in the pointer file.")

    try:
        csv_text = fetch_url(schedule_url)
    except Exception as exc:
        raise ValueError(
            f"Could not download schedule CSV from {prior_section} section: {exc}"
        ) from exc

    schedule_rows = _parse_schedule_csv(csv_text)
    hints = extract_schedule_hints(schedule_rows)
    venues = hints["venues"]
    dates = hints["dates"]
    event_types = hints["event_types"]
    if not venues and not dates and not event_types:
        raise ValueError(
            f"Schedule from {prior_section} section contained no venues, dates, days, "
            "or event types."
        )

    # Optional explicit list in pointer (Current or prior-year section) prepended.
    pointer_event_types = _event_types_from_pointer_section(current)
    if not pointer_event_types:
        pointer_event_types = _event_types_from_pointer_section(section)
    merged_event_types: list[str] = []
    for value in pointer_event_types + event_types:
        if value and value not in merged_event_types:
            merged_event_types.append(value)

    event_year = current.get("eventYear", "")
    if not event_year:
        event_year = current_year

    target_year = int(event_year) if str(event_year).isdigit() else int(current_year or 0)
    if not target_year:
        raise ValueError("Pointer file has no usable Current::eventYear for date normalization.")

    normalized_dates = normalize_dates(dates, target_year)
    ordered_days = order_days_from_schedule(schedule_rows, target_year)
    if not normalized_dates and not ordered_days and not venues and not merged_event_types:
        raise ValueError(
            f"Schedule from {prior_section} section contained no usable venues, dates, "
            "days, or event types after normalization."
        )

    day_options = ([" "] + ordered_days) if ordered_days else []

    return {
        "event_year": event_year,
        "band_list_url": current.get("artistUrl", ""),
        "description_map_url": current.get("descriptionMap", ""),
        "lineup_url": current.get("artistUrl", ""),
        "schedule_url": current.get("scheduleUrl", ""),
        "venues": [" "] + sorted(v for v in venues if v),
        "dates": [" "] + normalized_dates,
        "days": day_options,
        "event_types": merged_event_types,
        "years_found": [prior_section],
        "schedule_source_year": prior_section,
        "sections": list(sections.keys()),
    }


def filename_from_url(url: str) -> str:
    path = urlparse(url).path
    return unquote(path.rsplit("/", 1)[-1])

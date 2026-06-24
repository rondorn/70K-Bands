"""Parse production pointer files and extract schedule metadata."""

from __future__ import annotations

import csv
import io
import re
from datetime import datetime
from typing import Any
from urllib.parse import unquote, urlparse

from data_entry.http_util import fetch_url

DATE_RE = re.compile(r"^(\d{1,2})/(\d{1,2})/(\d{4})$")


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
    return parse_pointer_text(fetch_url(url))


def _sort_dates(values: set[str]) -> list[str]:
    parsed: list[tuple[datetime, str]] = []
    rest: list[str] = []
    for value in values:
        m = DATE_RE.match(value.strip())
        if m:
            month, day, year = map(int, m.groups())
            parsed.append((datetime(year, month, day), value.strip()))
        elif value.strip():
            rest.append(value.strip())
    parsed.sort(key=lambda item: item[0])
    ordered = [item[1] for item in parsed]
    for value in sorted(rest):
        if value not in ordered:
            ordered.append(value)
    return ordered


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


def extract_schedule_hints(schedule_rows: list[dict[str, str]]) -> dict[str, Any]:
    venues: set[str] = set()
    dates: set[str] = set()
    days: list[str] = []

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

    return {
        "venues": venues,
        "dates": dates,
        "days": days,
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
    Fetch a pointer file and learn venues, dates, and days from the schedule year
    below Current::eventYear. Band URLs and event year come from Current.
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

    hints = extract_schedule_hints(_parse_schedule_csv(csv_text))
    venues = hints["venues"]
    dates = hints["dates"]
    days = hints["days"]
    if not venues and not dates and not days:
        raise ValueError(
            f"Schedule from {prior_section} section contained no venues, dates, or days."
        )

    event_year = current.get("eventYear", "")
    if not event_year:
        event_year = current_year

    day_options = ([" "] + days) if days else []

    return {
        "event_year": event_year,
        "band_list_url": current.get("artistUrl", ""),
        "description_map_url": current.get("descriptionMap", ""),
        "lineup_url": current.get("artistUrl", ""),
        "schedule_url": current.get("scheduleUrl", ""),
        "venues": [" "] + sorted(v for v in venues if v),
        "dates": [" "] + _sort_dates(dates),
        "days": day_options,
        "years_found": [prior_section],
        "schedule_source_year": prior_section,
        "sections": list(sections.keys()),
    }


def filename_from_url(url: str) -> str:
    path = urlparse(url).path
    return unquote(path.rsplit("/", 1)[-1])

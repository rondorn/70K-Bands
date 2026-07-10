"""Schedule CSV validation and persistence (Python port of writeData.cgi)."""

from __future__ import annotations

import csv
import re
from calendar import monthrange
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

from data_entry.http_util import normalize_dropbox_url
from data_entry.network_cache import CacheMeta

SCHEDULE_COLUMNS = [
    "Band",
    "Location",
    "Date",
    "Day",
    "Start Time",
    "End Time",
    "Type",
    "Description URL",
    "Notes",
    "ImageURL",
]

HOUR_ARRAY = [f"{h:02d}" for h in range(24)]
MIN_ARRAY = [f"{m:02d}" for m in range(0, 60, 5)]
EVENT_LENGTH_ARRAY = ["45", "60", "90", " "]

NON_BAND_EVENT_TYPES = frozenset({"Special Event", "Unofficial Event"})


def _time_part_int(value: str) -> int:
    v = (value or "").strip()
    return int(v) if v.isdigit() else 0


def _format_time_part(value: str) -> str:
    v = (value or "").strip()
    if not v:
        return "00"
    if v.isdigit():
        return f"{int(v):02d}"
    return v


def _format_time_part_or_blank(value: str) -> str:
    v = (value or "").strip()
    if not v:
        return " "
    if v.isdigit():
        return f"{int(v):02d}"
    return v


@dataclass
class ScheduleEvent:
    band: str
    location: str
    date: str
    day: str
    start_time: str
    end_time: str
    event_type: str
    description_url: str = " "
    notes: str = " "
    image_url: str = " "

    def as_row(self) -> dict[str, str]:
        return {
            "Band": self.band,
            "Location": self.location,
            "Date": self.date,
            "Day": self.day,
            "Start Time": self.start_time,
            "End Time": self.end_time,
            "Type": self.event_type,
            "Description URL": self.description_url or " ",
            "Notes": self.notes or " ",
            "ImageURL": self.image_url or " ",
        }


def read_schedule(path: str | Path, cfg: dict[str, Any] | None = None) -> list[ScheduleEvent]:
    """Read schedule from a local CSV path or a published URL."""
    target = str(path or "").strip()
    if target.lower().startswith("http"):
        return read_schedule_from_url(target, cfg, force_refresh=False)
    file_path = Path(target)
    if file_path.is_file():
        return _parse_schedule_csv(file_path.read_text(encoding="utf-8"))
    return []


def read_schedule_from_url(
    url: str,
    cfg: dict[str, Any] | None = None,
    *,
    force_refresh: bool = False,
) -> list[ScheduleEvent]:
    """Read schedule from the published network URL (TTL-cached)."""
    url = (url or "").strip()
    if not url:
        return []
    from data_entry.config_store import resolved_paths
    from data_entry.network_cache import fetch_cached_text_or_empty

    paths = resolved_paths(cfg)
    csv_text, _meta = fetch_cached_text_or_empty(
        url, paths, force_refresh=force_refresh
    )
    if not csv_text:
        return []
    return _parse_schedule_csv(csv_text)


def _parse_schedule_csv(csv_text: str) -> list[ScheduleEvent]:
    events: list[ScheduleEvent] = []
    reader = csv.DictReader(csv_text.splitlines())
    for row in reader:
        if not (row.get("Band") or "").strip():
            continue
        events.append(
            ScheduleEvent(
                band=(row.get("Band") or "").strip(),
                location=(row.get("Location") or "").strip(),
                date=(row.get("Date") or "").strip(),
                day=(row.get("Day") or "").strip(),
                start_time=(row.get("Start Time") or "").strip(),
                end_time=(row.get("End Time") or "").strip(),
                event_type=(row.get("Type") or "").strip(),
                description_url=(row.get("Description URL") or " ").strip() or " ",
                notes=(row.get("Notes") or " ").strip() or " ",
                image_url=(row.get("ImageURL") or " ").strip() or " ",
            )
        )
    return events


def _schedule_csv_text(events: list[ScheduleEvent]) -> str:
    import io

    buffer = io.StringIO()
    writer = csv.DictWriter(buffer, fieldnames=SCHEDULE_COLUMNS)
    writer.writeheader()
    for event in events:
        writer.writerow(event.as_row())
    return buffer.getvalue()


def write_schedule(
    target: str | Path, events: list[ScheduleEvent], cfg: dict[str, Any] | None = None
) -> None:
    from data_entry.config_store import uses_dropbox_api
    from data_entry.dropbox_storage import DropboxStorageError, upload_text
    from data_entry.schedule_staging import is_staging_path, mark_staging_pending

    text = _schedule_csv_text(events)
    target_str = str(target or "").strip()
    if target_str.lower().startswith("http"):
        if not target_str:
            raise ValueError("Schedule URL is not configured.")
        try:
            upload_text(target_str, text, cfg)
        except DropboxStorageError as exc:
            raise ValueError(str(exc)) from exc
        if cfg is not None:
            _invalidate_published_cache(cfg)
        return

    path = Path(target_str)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    if cfg is not None and uses_dropbox_api(cfg) and is_staging_path(path, cfg):
        mark_staging_pending(cfg)
    elif cfg is not None:
        _invalidate_published_cache(cfg)


def append_schedule_event(
    target: str | Path, event: ScheduleEvent, cfg: dict[str, Any] | None = None
) -> None:
    url_or_path = str(target or "").strip()
    events = read_schedule(url_or_path, cfg)
    events.append(event)
    write_schedule(url_or_path, events, cfg)


def _parse_date(date_str: str) -> tuple[int, int, int]:
    parts = date_str.split("/")
    if len(parts) != 3:
        raise ValueError(f"Invalid date: {date_str}")
    month, day, year = int(parts[0]), int(parts[1]), int(parts[2])
    return month, day, year


def _epoch_seconds(
    date_str: str,
    hour: int,
    minute: int,
    start_hour: int | None = None,
) -> int:
    month, day, year = _parse_date(date_str)
    if hour == 24:
        hour = 0
        day += 1
        if day > monthrange(year, month)[1]:
            day = 1
            month += 1
    if start_hour is not None and start_hour > 12 and hour < 12:
        day += 1
        if day > monthrange(year, month)[1]:
            day = 1
            month += 1
    dt = datetime(year, month, day, hour, minute)
    return int(dt.timestamp())


def _parse_time_parts(time_str: str) -> tuple[int, int]:
    match = re.match(r"(\d+):(\d+)", (time_str or "").strip())
    if not match:
        raise ValueError(f"Invalid time: {time_str}")
    return int(match.group(1)), int(match.group(2))


def calculate_end_time(
    start_hour: str,
    start_min: str,
    end_hour: str,
    end_min: str,
    event_length: str,
) -> tuple[str, str]:
    length = (event_length or "").strip()
    if length and length != " " and length.isdigit():
        start_h = _time_part_int(start_hour)
        start_m = _time_part_int(start_min)
        total = start_h * 60 + start_m + int(length)
        end_h = (total // 60) % 24
        end_m = total % 60
        return f"{end_h:02d}", f"{end_m:02d}"
    return _format_time_part(end_hour), _format_time_part(end_min)


def value_cleanup(value: str) -> str:
    value = (value or "").strip()
    if not value:
        return " "
    if "http" in value.lower():
        return re.sub(r"\s+", "", value)
    return value


def build_event_from_form(form: dict[str, str], cfg: dict[str, Any]) -> ScheduleEvent:
    band = (form.get("BandName") or "").strip()
    event_type = (form.get("EventType") or "").strip()
    notes = value_cleanup(form.get("Notes", ""))
    if event_type in NON_BAND_EVENT_TYPES:
        band = notes
        notes = " "

    image_url = value_cleanup(form.get("ImageURL", ""))
    if event_type not in NON_BAND_EVENT_TYPES:
        image_url = " "
    elif image_url.strip() and image_url != " ":
        image_url = normalize_dropbox_url(image_url)

    end_h, end_m = calculate_end_time(
        form.get("StartHour", ""),
        form.get("StartMin", ""),
        form.get("EndHour", ""),
        form.get("EndMin", ""),
        form.get("EventLength", ""),
    )
    start_h = _format_time_part_or_blank(form.get("StartHour", ""))
    start_m = _format_time_part_or_blank(form.get("StartMin", ""))

    return ScheduleEvent(
        band=band,
        location=(form.get("Venue") or "").strip(),
        date=(form.get("Date") or "").strip(),
        day=(form.get("Day") or "").strip(),
        start_time=f"{start_h}:{start_m}",
        end_time=f"{end_h}:{end_m}",
        event_type=event_type,
        description_url=" ",
        notes=notes,
        image_url=image_url,
    )


def validate_event(
    event: ScheduleEvent,
    existing: list[ScheduleEvent],
    cfg: dict[str, Any],
    verify_bypass: bool = False,
    exclude: tuple[str, str, str, str] | None = None,
) -> list[str]:
    if verify_bypass:
        return []

    if exclude:
        orig_band, orig_location, orig_date, orig_start = exclude
        existing = [
            row
            for row in existing
            if not (
                row.band == orig_band
                and row.location == orig_location
                and row.date == orig_date
                and row.start_time == orig_start
            )
        ]

    errors: list[str] = []
    empty_checks = [
        (event.band, "Band Name must be assigned a value"),
        (event.event_type, "Event Type must be assigned a value"),
        (event.location, "The Venue must be assigned a value"),
        (event.date, "Date must be assigned a value"),
    ]
    for value, message in empty_checks:
        if not value or value == " ":
            errors.append(message)

    if not event.start_time or event.start_time == " :":
        errors.append("Complete Start Time information must be provided")
    if not event.end_time or event.end_time == " :":
        errors.append("Complete End Time information must be provided")

    counts: dict[str, dict[str, int]] = {}
    for row in existing:
        counts.setdefault(row.band, {})
        counts[row.band][row.event_type] = counts[row.band].get(row.event_type, 0) + 1

    band_counts = counts.get(event.band, {})
    if event.event_type == "Show":
        if band_counts.get("Show", 0) >= 2:
            errors.append(f"{event.band} already has 2 shows, you can not book a third")
    elif band_counts.get(event.event_type, 0) >= 1:
        errors.append(
            f"{event.band} already has a {event.event_type} booked, "
            f"you can not book a second {event.event_type}"
        )

    try:
        sh, sm = _parse_time_parts(event.start_time)
        eh, em = _parse_time_parts(event.end_time)
        start_epoch = _epoch_seconds(event.date, sh, sm)
        end_epoch = _epoch_seconds(event.date, eh, em, start_hour=sh)
    except ValueError as exc:
        errors.append(str(exc))
        return errors

    for row in existing:
        try:
            rsh, rsm = _parse_time_parts(row.start_time)
            reh, rem = _parse_time_parts(row.end_time)
            row_start = _epoch_seconds(row.date, rsh, rsm)
            row_end = _epoch_seconds(row.date, reh, rem, start_hour=rsh)
        except ValueError:
            continue

        if row.location == event.location:
            if start_epoch < row_end and end_epoch > row_start:
                errors.append(
                    f"{event.location} Already has a show booked for that timeslot "
                    "(overlaps with existing booking)"
                )
                break

        if row.band == event.band:
            if start_epoch < row_end and end_epoch > row_start:
                errors.append(
                    f"{event.band} Already has a show booked for that timeslot "
                    "(overlaps with existing booking)"
                )
                break

    if event.event_type == "Show":
        length = end_epoch - start_epoch
        if length < 1800:
            errors.append("Show is to short. Should be at least 30 min")
        elif length > 7200:
            errors.append("Show is to Long. Should not exceed 2 hours")

    return errors


def remove_matching_event(
    events: list[ScheduleEvent],
    band: str,
    location: str,
    date: str,
    start_time: str,
) -> list[ScheduleEvent]:
    kept: list[ScheduleEvent] = []
    removed = False
    for event in events:
        if (
            not removed
            and event.band == band
            and event.location == location
            and event.date == date
            and event.start_time == start_time
        ):
            removed = True
            continue
        kept.append(event)
    return kept


def replace_matching_event(
    events: list[ScheduleEvent],
    band: str,
    location: str,
    date: str,
    start_time: str,
    replacement: ScheduleEvent,
) -> list[ScheduleEvent]:
    updated: list[ScheduleEvent] = []
    replaced = False
    for event in events:
        if (
            not replaced
            and event.band == band
            and event.location == location
            and event.date == date
            and event.start_time == start_time
        ):
            updated.append(replacement)
            replaced = True
        else:
            updated.append(event)
    return updated


def _split_time_for_form(time_str: str) -> tuple[str, str]:
    match = re.match(r"(\S+):(\S+)", (time_str or "").strip())
    if not match:
        return " ", "  "
    hour = match.group(1).strip()
    minute = match.group(2).strip()
    if not hour or hour == " ":
        return " ", "  "
    hour_val = f"{int(hour):02d}" if hour.isdigit() else hour
    if not minute or minute == " ":
        return hour_val, "  "
    minute_val = f"{int(minute):02d}" if minute.isdigit() else minute
    return hour_val, minute_val


def event_to_form(event: ScheduleEvent) -> dict[str, str]:
    start_h, start_m = _split_time_for_form(event.start_time)
    end_h, end_m = _split_time_for_form(event.end_time)

    band_name = event.band
    notes = event.notes
    if event.event_type in NON_BAND_EVENT_TYPES:
        band_name = " "
        notes = event.band if event.band.strip() and event.band != " " else ""

    image_url = event.image_url if event.image_url.strip() and event.image_url != " " else ""
    notes_display = notes if notes.strip() and notes != " " else ""

    return {
        "BandName": band_name,
        "EventType": event.event_type,
        "Venue": event.location,
        "Date": event.date,
        "Day": event.day,
        "StartHour": start_h,
        "StartMin": start_m,
        "EndHour": end_h,
        "EndMin": end_m,
        "EventLength": " ",
        "Notes": notes_display,
        "DescriptionText": "",
        "ImageURL": image_url,
        "OrigBand": event.band,
        "OrigVenue": event.location,
        "OrigDate": event.date,
        "OrigStartTime": event.start_time,
    }


def _invalidate_published_cache(cfg: dict[str, Any]) -> None:
    from data_entry.config_store import resolved_paths
    from data_entry.network_cache import invalidate_festival_network_cache

    invalidate_festival_network_cache(resolved_paths(cfg))


def band_name_options(
    cfg: dict[str, Any],
    paths: dict[str, str],
    *,
    force_refresh: bool = False,
) -> tuple[list[str], CacheMeta | None]:
    from data_entry.band_logic import lineup_band_names

    names, meta = lineup_band_names(cfg, paths, force_refresh=force_refresh)
    return [" ", *sorted(set(names))], meta

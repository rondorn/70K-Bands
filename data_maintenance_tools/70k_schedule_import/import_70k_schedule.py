#!/usr/bin/env python3
"""Import 70K artist performances from a JSON API into a schedule CSV.

Downloads (or reads) artist JSON, maps venue names, and appends Show rows that
are not already present. Existing CSV content is never overwritten.

Unique key (case-agnostic band/location; normalized start time):
  band name + location + start time

Layout matches artistSchedule*.csv (no quoting):

  Band,Location,Date,Day,Start Time,End Time,Type,Description URL,Notes,ImageURL,ImageDate
  Xandria,Theater,01/29/2026,Day 1,18:15,19:00,Show,,,

Config (YAML) supplies default json_url and output_csv; CLI flags override them.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable, Optional

_SCRIPT_DIR = Path(__file__).resolve().parent
_DEFAULT_CONFIG = _SCRIPT_DIR / "config.yaml"

CSV_HEADER = (
    "Band,Location,Date,Day,Start Time,End Time,Type,"
    "Description URL,Notes,ImageURL,ImageDate"
)

# Column indexes in the unquoted schedule CSV layout.
_COL_BAND = 0
_COL_LOCATION = 1
_COL_START = 4

# JSON venue name (case-agnostic) -> app Location value. Order matches product list.
_JSON_TO_APP_LOCATION = (
    ("Pool Deck", "Pool"),
    ("Royal Theater", "Theater"),
    ("Studio B", "Rink"),
    ("Stars Lounge", "Lounge"),
    ("Bull & Bear", "Ale And Anchor Pub"),
    ("Boleros", "Boleros Lounge"),
    ("Playmaker Sports Bar", "Sports Bar"),
    ("Viking Crown Lounge", "Viking Crown"),
)

# Extra API spellings that should resolve to the same app locations.
_JSON_LOCATION_ALIASES = (
    ("Star Lounge", "Lounge"),  # singular variant seen in earlier docs
)

_LOCATION_BY_KEY = {
    src.casefold(): dst
    for src, dst in (_JSON_TO_APP_LOCATION + _JSON_LOCATION_ALIASES)
}


def _load_yaml_config(path: Path) -> dict[str, Any]:
    """Minimal YAML loader for flat string keys (no PyYAML required)."""
    if not path.is_file():
        return {}
    data: dict[str, Any] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        data[key] = value.strip()
    return data


def map_location(stage: str) -> str:
    """Map JSON stage/venue to app Location (case-agnostic).

    Accepts exact names and longer forms that start with a known name
    (e.g. \"Pool Deck Stage\" -> Pool).
    """
    raw = (stage or "").strip()
    if not raw:
        raise ValueError("Empty stage/venue")

    key = raw.casefold()
    if key in _LOCATION_BY_KEY:
        return _LOCATION_BY_KEY[key]

    # Longest known prefix (word-boundary): "pool deck stage" matches "pool deck"
    matches: list[tuple[str, str]] = []
    for src, dst in _JSON_TO_APP_LOCATION:
        src_key = src.casefold()
        if key == src_key or key.startswith(src_key + " ") or key.startswith(src_key + "-"):
            matches.append((src_key, dst))
    if matches:
        matches.sort(key=lambda item: len(item[0]), reverse=True)
        return matches[0][1]

    known = ", ".join(
        src for src, _ in (_JSON_TO_APP_LOCATION + _JSON_LOCATION_ALIASES)
    )
    raise ValueError(f"Unmapped stage {stage!r}. Known JSON venues: {known}")


def format_date(iso_date: str) -> str:
    """YYYY-MM-DD -> M/D/YYYY (no leading zeros; QR-friendly)."""
    dt = datetime.strptime(iso_date.strip(), "%Y-%m-%d")
    return f"{dt.month}/{dt.day}/{dt.year}"


def format_day(day_value: Any) -> str:
    """JSON day number -> 'Day N'."""
    if isinstance(day_value, str) and day_value.strip().casefold().startswith("day"):
        return day_value.strip()
    return f"Day {int(day_value)}"


def format_time(value: str) -> str:
    """Keep HH:MM; tolerate H:MM from the API."""
    text = (value or "").strip()
    if not text:
        raise ValueError("Empty time")
    match = re.fullmatch(r"(\d{1,2}):(\d{2})", text)
    if not match:
        raise ValueError(f"Bad time {value!r}")
    hour = int(match.group(1))
    minute = match.group(2)
    if hour > 23:
        raise ValueError(f"Bad time {value!r}")
    return f"{hour:02d}:{minute}"


def format_band_name(name: str) -> str:
    """Title-case band names: first char of each word upper, rest lower.

    Words are split on spaces; hyphenated parts are title-cased separately
    (e.g. VIO-LENCE -> Vio-Lence).
    """
    def cap_part(part: str) -> str:
        if not part:
            return part
        return part[0].upper() + part[1:].lower()

    words: list[str] = []
    for word in (name or "").strip().split():
        words.append("-".join(cap_part(piece) for piece in word.split("-")))
    return " ".join(words)


def fetch_json(url: str) -> Any:
    request = urllib.request.Request(
        url,
        headers={"Accept": "application/json", "User-Agent": "70k-schedule-import/1.0"},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        body = response.read()
    return json.loads(body.decode("utf-8"))


def load_artists(*, url: Optional[str], json_file: Optional[Path]) -> list[dict[str, Any]]:
    if json_file is not None:
        payload = json.loads(json_file.read_text(encoding="utf-8"))
    elif url:
        payload = fetch_json(url)
    else:
        raise SystemExit("Provide json_url in config, or --url / --json-file")

    if not isinstance(payload, list):
        raise SystemExit("JSON root must be an array of artists")
    return payload


def event_key(band: str, location: str, start_time: str) -> tuple[str, str, str]:
    """Unique key for an existing or discovered show row."""
    try:
        start = format_time(start_time)
    except ValueError:
        start = (start_time or "").strip()
    return (
        (band or "").strip().casefold(),
        (location or "").strip().casefold(),
        start,
    )


def parse_csv_fields(line: str) -> list[str]:
    """Split an unquoted schedule CSV line into fields."""
    return line.rstrip("\r\n").split(",")


def read_existing_keys(path: Path) -> set[tuple[str, str, str]]:
    """Load band+location+start keys already present in the CSV."""
    if not path.is_file():
        return set()

    keys: set[tuple[str, str, str]] = set()
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line == CSV_HEADER or line.startswith("Band,Location,"):
            continue
        fields = parse_csv_fields(line)
        if len(fields) <= _COL_START:
            continue
        keys.add(event_key(fields[_COL_BAND], fields[_COL_LOCATION], fields[_COL_START]))
    return keys


def performance_rows(
    artists: Iterable[dict[str, Any]],
) -> list[tuple[tuple[str, str, str], str]]:
    """Return (unique_key, csv_line) for each discovered Show performance."""
    rows: list[tuple[tuple[str, str, str], str]] = []
    errors: list[str] = []

    for artist in artists:
        raw_name = str(artist.get("name") or "").strip()
        if not raw_name:
            errors.append(f"Artist id={artist.get('id')!r} missing name")
            continue
        name = format_band_name(raw_name)

        performances = artist.get("performances") or []
        if not isinstance(performances, list):
            errors.append(f"{name}: performances must be a list")
            continue

        for index, perf in enumerate(performances):
            if not isinstance(perf, dict):
                errors.append(f"{name} performance[{index}]: not an object")
                continue
            try:
                location = map_location(str(perf.get("stage") or ""))
                date = format_date(str(perf.get("date") or ""))
                day = format_day(perf.get("day"))
                start = format_time(str(perf.get("start_time") or ""))
                end = format_time(str(perf.get("end_time") or ""))
            except (TypeError, ValueError) as exc:
                errors.append(f"{name} performance[{index}]: {exc}")
                continue

            # Exact show layout from sample: Type=Show, three trailing empty fields.
            line = f"{name},{location},{date},{day},{start},{end},Show,,,"
            rows.append((event_key(name, location, start), line))

    if errors:
        print("Import errors:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        raise SystemExit(1)
    return rows


def filter_new_rows(
    discovered: list[tuple[tuple[str, str, str], str]],
    existing_keys: set[tuple[str, str, str]],
) -> tuple[list[str], int]:
    """Keep only rows whose key is not already in the CSV (first wins)."""
    new_rows: list[str] = []
    seen = set(existing_keys)
    skipped = 0
    for key, line in discovered:
        if key in seen:
            skipped += 1
            continue
        seen.add(key)
        new_rows.append(line)
    return new_rows, skipped


def append_csv(path: Path, rows: list[str]) -> None:
    """Append rows to the schedule CSV; create with header if missing."""
    if not rows:
        return

    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.is_file():
        path.write_text(CSV_HEADER + "\n" + "\n".join(rows) + "\n", encoding="utf-8")
        return

    existing = path.read_text(encoding="utf-8")
    prefix = "" if existing.endswith("\n") or existing == "" else "\n"
    with path.open("a", encoding="utf-8") as handle:
        handle.write(prefix + "\n".join(rows) + "\n")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Import 70K JSON performances into a schedule CSV (Show rows only)."
    )
    parser.add_argument(
        "--config",
        type=Path,
        default=_DEFAULT_CONFIG,
        help=f"Config YAML (default: {_DEFAULT_CONFIG})",
    )
    parser.add_argument(
        "--url",
        "--json-url",
        dest="json_url",
        default=None,
        help="Override JSON API URL from config",
    )
    parser.add_argument(
        "--output",
        "--csv",
        dest="output_csv",
        default=None,
        help="Override output CSV path from config",
    )
    parser.add_argument(
        "--json-file",
        type=Path,
        default=None,
        help="Read artists JSON from a local file instead of downloading",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be appended; do not write the CSV",
    )
    return parser


def main(argv: Optional[list[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    config = _load_yaml_config(args.config)

    json_url = args.json_url or config.get("json_url") or ""
    output_csv = args.output_csv or config.get("output_csv") or ""
    if not output_csv:
        raise SystemExit("output_csv missing: set in config or pass --output")

    try:
        artists = load_artists(url=json_url or None, json_file=args.json_file)
    except urllib.error.URLError as exc:
        raise SystemExit(f"Failed to download JSON: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON: {exc}") from exc

    out_path = Path(output_csv).expanduser()
    existing_keys = read_existing_keys(out_path)
    discovered = performance_rows(artists)
    new_rows, skipped = filter_new_rows(discovered, existing_keys)

    print(f"Artists: {len(artists)}")
    print(f"Discovered shows: {len(discovered)}")
    print(f"Already present: {skipped}")
    print(f"New to append: {len(new_rows)}")
    print(f"Target CSV: {out_path}")

    if args.dry_run:
        for sample in new_rows[:20]:
            print(sample)
        if len(new_rows) > 20:
            print(f"... ({len(new_rows) - 20} more)")
        return 0

    if not new_rows:
        print("Nothing to append")
        return 0

    append_csv(out_path, new_rows)
    print(f"Appended {len(new_rows)} row(s) to {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

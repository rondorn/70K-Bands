#!/usr/bin/env python3
"""
Rewrite qa_schedule_march_2026_current_window.csv so QA show times are near "now"
(default: first show starts ~60 minutes from script run) for local notification testing.

Also optionally set eventYear in all qa-config/pointers/*.txt to the current calendar year
so attendance / year keys match real dates.

Usage (from repo root):

    python3 qa-config/scripts/regenerate_qa_schedule_times.py
    python3 qa-config/scripts/regenerate_qa_schedule_times.py --sync-event-year

After running: commit the CSV (and pointers if used), push to default branch, refresh the app.
If your public pointer still points at GitHub raw for scheduleUrl, QA picks up changes after push.
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CSV = REPO_ROOT / "qa-config" / "fixtures" / "qa_schedule_march_2026_current_window.csv"
POINTERS_DIR = REPO_ROOT / "qa-config" / "pointers"

HEADER = [
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

BANDS = [
    ("QA Alpha Band", "Pool"),
    ("QA Beta Band", "Lounge"),
    ("QA Gamma Band", "Theater"),
]


def _format_date(d: datetime) -> str:
    return d.strftime("%m/%d/%Y")


def _format_time(d: datetime) -> str:
    return d.strftime("%H:%M")


def build_rows(
    now: datetime,
    first_offset_minutes: int,
    gap_minutes: int,
    slot_minutes: int,
) -> list[list[str]]:
    generated_note = f"generated {now.isoformat(timespec='seconds')}"
    rows: list[list[str]] = [HEADER]
    t = now + timedelta(minutes=first_offset_minutes)
    day_label = "Day 1"
    for i, (band, loc) in enumerate(BANDS):
        start = t + timedelta(minutes=i * gap_minutes)
        end = start + timedelta(minutes=slot_minutes)
        note = generated_note if i == 0 else f"QA alert fixture slot {i + 1}"
        rows.append(
            [
                band,
                loc,
                _format_date(start),
                day_label,
                _format_time(start),
                _format_time(end),
                "Show",
                "",
                note,
                "",
            ]
        )
    return rows


def write_schedule_csv(path: Path, rows: list[list[str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        csv.writer(f).writerows(rows)


def sync_event_year_in_pointers(year: int) -> list[Path]:
    """Replace eventYear::YYYY in all pointer files."""
    pattern = re.compile(r"^(.*::eventYear::)(\d{4})(.*)$")
    touched: list[Path] = []
    for p in sorted(POINTERS_DIR.glob("*.txt")):
        lines = p.read_text(encoding="utf-8").splitlines()
        out: list[str] = []
        changed = False
        for line in lines:
            m = pattern.match(line)
            if m and m.group(2) != str(year):
                out.append(f"{m.group(1)}{year}{m.group(3)}")
                changed = True
            else:
                out.append(line)
        if changed:
            p.write_text("\n".join(out) + "\n", encoding="utf-8")
            touched.append(p)
    return touched


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Regenerate QA schedule CSV with show times ~1 hour ahead for alert testing."
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_CSV,
        help=f"Schedule CSV to write (default: {DEFAULT_CSV})",
    )
    parser.add_argument(
        "--timezone",
        default="",
        help="IANA zone e.g. America/New_York (default: system local)",
    )
    parser.add_argument(
        "--first-start-offset-minutes",
        type=int,
        default=60,
        help="Minutes from 'now' until first show start (default: 60)",
    )
    parser.add_argument(
        "--gap-minutes",
        type=int,
        default=15,
        help="Minutes between each band's start time (default: 15)",
    )
    parser.add_argument(
        "--slot-minutes",
        type=int,
        default=45,
        help="Each show length in minutes (default: 45)",
    )
    parser.add_argument(
        "--sync-event-year",
        action="store_true",
        help=f"Set eventYear in all {POINTERS_DIR}/*.txt to the current calendar year",
    )
    args = parser.parse_args()

    if args.timezone:
        now = datetime.now(tz=ZoneInfo(args.timezone))
    else:
        now = datetime.now().astimezone()

    rows = build_rows(
        now,
        args.first_start_offset_minutes,
        args.gap_minutes,
        args.slot_minutes,
    )
    write_schedule_csv(args.output, rows)
    print(f"Wrote {args.output} (first show ~{args.first_start_offset_minutes} min from script time).")
    for r in rows[1:]:
        print(f"  {r[0]} {r[2]} {r[4]}-{r[5]}")

    if args.sync_event_year:
        y = now.year
        touched = sync_event_year_in_pointers(y)
        if not touched:
            print("No pointer files needed eventYear updates.")
        else:
            print(f"sync-event-year -> {y} in:")
            for p in touched:
                print(f"  {p.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()

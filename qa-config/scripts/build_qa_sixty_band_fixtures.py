#!/usr/bin/env python3
"""
Build QA lineup (60 bands), schedule, and description map from production data
(2026 Dropbox + 2025/2024 jsdelivr), stratified 20+20+20 with fixed random seed.

Overwrites the canonical fixture files (same URLs the pointers have always used):
  - qa_lineup_three_bands.csv
  - qa_schedule_shows_only.csv
  - qa_schedule_march_2026_current_window.csv
  - qa_schedule_with_preparties.csv
  - qa_description_map_empty.csv
  - qa_description_map_with_notes.csv
"""

from __future__ import annotations

import csv
import io
import random
import re
import sys
import urllib.request
from datetime import date, timedelta
from pathlib import Path
SOURCES: dict[str, dict[str, str]] = {
    "2026": {
        "artist": "https://www.dropbox.com/scl/fi/u5azf0n9yrg2ap91p3zgi/artistLineup_2026.csv?rlkey=isli0nm3mexf4kxw7fpjn1a5g&raw=1",
        "schedule": "https://www.dropbox.com/scl/fi/r7cf8qd8w7di7refgrsjj/artistSchedule2026.csv?rlkey=y309oe7pbd8wdhl8ubz80s4b7&raw=1",
        "description": "https://www.dropbox.com/scl/fi/sud922ylb3se1bfrzqz90/descriptionMap2026.csv?rlkey=3ww5ozyhbjb53mvwgg58mcem9&raw=1",
    },
    "2025": {
        "artist": "https://cdn.jsdelivr.net/gh/rondorn/70K-Bands@master/dataFiles/artistLineup_2025.csv",
        "schedule": "https://www.dropbox.com/scl/fi/mjntfrok8u87aw91u9x4l/artistSchedule2025.csv?rlkey=kkxwzvm2fyd0c6swehnniyfi3&raw=1",
        "description": "https://cdn.jsdelivr.net/gh/rondorn/70K-Bands@master/dataFiles/descriptionMap2025.csv",
    },
    "2024": {
        "artist": "https://cdn.jsdelivr.net/gh/rondorn/70K-Bands@master/dataFiles/artistLineup2024.csv",
        "schedule": "https://cdn.jsdelivr.net/gh/rondorn/70K-Bands@master/dataFiles/artistSchedule2024.csv",
        "description": "https://cdn.jsdelivr.net/gh/rondorn/70K-Bands@master/dataFiles/descriptionMap2024.csv",
    },
}

# Real 2026 unofficial events; dates remapped to a March 2026 QA window (see QA walkthrough).
PREPARTY_FIXTURE_ROWS: list[dict[str, str]] = [
    {
        "Band": "Mon-Decades Of Metal",
        "Location": "Clevelander",
        "Date": "03/17/2026",
        "Day": "1/17",
        "Start Time": "15:00",
        "End Time": "02:00",
        "Type": "Unofficial Event",
        "Description URL": "",
        "Notes": "",
        "ImageURL": "https://www.dropbox.com/scl/fi/ilkh1c2820unllmpfoeo4/DecadesOfMetal.jpeg?rlkey=haa6p3qjdgeo3lo0hjf9owzxy&raw=1",
        "ImageDate": "12-7/2025",
    },
    {
        "Band": "Tue-Everglades Tour",
        "Location": "Clevelander",
        "Date": "03/18/2026",
        "Day": "1/18",
        "Start Time": "11:00",
        "End Time": "16:00",
        "Type": "Unofficial Event",
        "Description URL": "",
        "Notes": "",
        "ImageURL": "https://www.dropbox.com/scl/fi/b5tae9douacq8pzl5a8y8/MetalBeachParty.jpg?rlkey=hozqk6tjz28xhy2j0en8tiwxf&raw=1",
        "ImageDate": "12-7/2025",
    },
    {
        "Band": "Tue-Live Bands!",
        "Location": "Clevelander",
        "Date": "03/18/2026",
        "Day": "1/18",
        "Start Time": "18:00",
        "End Time": "02:00",
        "Type": "Unofficial Event",
        "Description URL": "",
        "Notes": "",
        "ImageURL": "https://www.dropbox.com/scl/fi/5tx47punynl17avztd8nz/Flyer2026-fixed.png?rlkey=gnn2z64onyuywvbcvoyl86251&raw=1",
        "ImageDate": "12-7/2025",
    },
    {
        "Band": "Wed-Metal Yoga",
        "Location": "South Beach",
        "Date": "03/19/2026",
        "Day": "1/19",
        "Start Time": "11:00",
        "End Time": "12:00",
        "Type": "Unofficial Event",
        "Description URL": "",
        "Notes": "",
        "ImageURL": "https://www.dropbox.com/scl/fi/4zwc2k9lyoe0rgw7xm39z/Yoga.JPG?rlkey=k5emqgnujfiv6ael46xbw624m&raw=1",
        "ImageDate": "12-7/2025",
    },
    {
        "Band": "Wed-Beach Party!",
        "Location": "South Beach",
        "Date": "03/19/2026",
        "Day": "1/19",
        "Start Time": "13:00",
        "End Time": "18:00",
        "Type": "Unofficial Event",
        "Description URL": "",
        "Notes": "",
        "ImageURL": "https://www.dropbox.com/scl/fi/327vurfj8tds0ntt2j79d/BeachPartyPic.jpeg?rlkey=dg9b7y3u6sa8hplelyi2btb5e&raw=1",
        "ImageDate": "12-7/2025",
    },
    {
        "Band": "Thu-Metal Bus to Port",
        "Location": "Clevelander",
        "Date": "03/20/2026",
        "Day": "Day 1",
        "Start Time": "9:30",
        "End Time": "12:45",
        "Type": "Unofficial Event",
        "Description URL": "",
        "Notes": "",
        "ImageURL": "https://www.dropbox.com/scl/fi/b1wcrjoc9xm1dy4kr0yyc/partyBus.png?rlkey=7shhq54xoiuo02jjccck4hpja&raw=1",
        "ImageDate": "12-7/2025",
    },
]

SCHEDULE_OUT_FIELDS = [
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
    "ImageDate",
]

ARTIST_FIELDS = [
    "bandName",
    "officalSite",
    "imageUrl",
    "youtube",
    "metalArchives",
    "wikipedia",
    "country",
    "genre",
    "noteworthy",
    "priorYears",
]

# Appended after the 60 production-sample rows so QR pointers (which use this file +
# qa_schedule_full_for_qr_share / partial) still resolve QA Alpha/Beta/Gamma.
QR_PLACEHOLDER_LINEUP: list[dict[str, str]] = [
    {
        "bandName": "QA Alpha Band",
        "officalSite": "example.com/alpha",
        "imageUrl": "",
        "youtube": "",
        "metalArchives": "",
        "wikipedia": "",
        "country": "United States",
        "genre": "Heavy Metal",
        "noteworthy": "",
        "priorYears": "Never",
    },
    {
        "bandName": "QA Beta Band",
        "officalSite": "example.com/beta",
        "imageUrl": "",
        "youtube": "",
        "metalArchives": "",
        "wikipedia": "",
        "country": "United States",
        "genre": "Heavy Metal",
        "noteworthy": "",
        "priorYears": "Never",
    },
    {
        "bandName": "QA Gamma Band",
        "officalSite": "example.com/gamma",
        "imageUrl": "",
        "youtube": "",
        "metalArchives": "",
        "wikipedia": "",
        "country": "United States",
        "genre": "Heavy Metal",
        "noteworthy": "",
        "priorYears": "Never",
    },
]

NOTES_QA_ALPHA_URL = (
    "https://raw.githubusercontent.com/rondorn/70K-Bands/master/"
    "qa-config/fixtures/notes_qa_alpha.txt"
)


def fetch_text(url: str) -> str:
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "70K-QA-Fixture-Builder/1.0"},
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        raw = resp.read()
    for enc in ("utf-8", "utf-8-sig", "latin-1"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", errors="replace")


def parse_csv(text: str) -> tuple[list[str], list[dict[str, str]]]:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    reader = csv.DictReader(io.StringIO(text))
    if not reader.fieldnames:
        return [], []
    fieldnames = [f.strip() for f in reader.fieldnames]
    rows: list[dict[str, str]] = []
    for row in reader:
        cleaned = {(k or "").strip(): (v or "").strip() for k, v in row.items()}
        rows.append(cleaned)
    return fieldnames, rows


def strip_scheme_for_band_csv_field(value: str) -> str:
    """Band CSVs must not include http(s):// for officalSite or imageUrl; apps prepend schemes."""
    u = value.strip()
    if not u:
        return ""
    lower = u.lower()
    if lower.startswith("https://"):
        return u[8:]
    if lower.startswith("http://"):
        return u[7:]
    return u


_DAY_RE = re.compile(r"day\s*(\d+)", re.I)


def parse_day_number(day_field: str) -> int:
    m = _DAY_RE.search(day_field or "")
    if m:
        return max(1, min(14, int(m.group(1))))
    return 1


def march_2026_date_for_cruise_day(day_num: int) -> str:
    """Align with qa_schedule_march_2026: Day 1 -> 03/20/2026."""
    base = date(2026, 3, 20)
    d = base + timedelta(days=day_num - 1)
    return f"{d.month:02d}/{d.day:02d}/2026"


def schedule_rows_for_bands(
    schedule_rows: list[dict[str, str]],
    band_names: set[str],
) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    for r in schedule_rows:
        band = (r.get("Band") or "").strip()
        if band not in band_names:
            continue
        typ = (r.get("Type") or "").strip().lower()
        if typ != "show":
            continue
        day_num = parse_day_number(r.get("Day") or "")
        new_date = march_2026_date_for_cruise_day(day_num)
        day_label = f"Day {day_num}"
        row_out = {
            "Band": band,
            "Location": r.get("Location", "").strip(),
            "Date": new_date,
            "Day": day_label,
            "Start Time": r.get("Start Time", "").strip(),
            "End Time": r.get("End Time", "").strip(),
            "Type": "Show",
            "Description URL": r.get("Description URL", "").strip(),
            "Notes": r.get("Notes", "").strip(),
            "ImageURL": r.get("ImageURL", "").strip(),
            "ImageDate": r.get("ImageDate", "").strip(),
        }
        out.append(row_out)
    out.sort(key=lambda x: (x["Date"], x["Start Time"], x["Band"]))
    return out


def bands_with_shows(schedule_rows: list[dict[str, str]]) -> set[str]:
    names: set[str] = set()
    for r in schedule_rows:
        if (r.get("Type") or "").strip().lower() != "show":
            continue
        b = (r.get("Band") or "").strip()
        if b:
            names.add(b)
    return names


def artist_by_name(artist_rows: list[dict[str, str]]) -> dict[str, dict[str, str]]:
    by: dict[str, dict[str, str]] = {}
    for r in artist_rows:
        name = (r.get("bandName") or "").strip()
        if name:
            by[name] = r
    return by


def pick_bands(
    year: str,
    artist_rows: list[dict[str, str]],
    schedule_rows: list[dict[str, str]],
    count: int,
    rng: random.Random,
) -> list[str]:
    shows = bands_with_shows(schedule_rows)
    artists = artist_by_name(artist_rows)
    eligible = sorted(shows & set(artists.keys()))
    if len(eligible) < count:
        print(
            f"Warning: {year} only has {len(eligible)} bands with Show+lineup; taking all.",
            file=sys.stderr,
        )
        return eligible
    return rng.sample(eligible, count)


def main() -> int:
    rng = random.Random(42)
    repo_root = Path(__file__).resolve().parents[2]
    fixtures = repo_root / "qa-config" / "fixtures"

    per_year = 20
    selected: dict[str, list[str]] = {}
    artist_rows_by_year: dict[str, list[dict[str, str]]] = {}
    schedule_by_year: dict[str, list[dict[str, str]]] = {}
    desc_by_year: dict[str, list[dict[str, str]]] = {}

    for year, urls in SOURCES.items():
        print(f"Fetching {year}…", file=sys.stderr)
        atext = fetch_text(urls["artist"])
        stext = fetch_text(urls["schedule"])
        dtext = fetch_text(urls["description"])
        _, artists = parse_csv(atext)
        _, sched = parse_csv(stext)
        _, desc = parse_csv(dtext)
        artist_rows_by_year[year] = artists
        schedule_by_year[year] = sched
        desc_by_year[year] = desc
        selected[year] = pick_bands(year, artists, sched, per_year, rng)

    all_bands = selected["2026"] + selected["2025"] + selected["2024"]
    assert len(all_bands) == 60

    lineup_rows: list[dict[str, str]] = []
    for year in ("2026", "2025", "2024"):
        artists_map = artist_by_name(artist_rows_by_year[year])
        for name in selected[year]:
            r = artists_map[name]
            lineup_rows.append(
                {
                    "bandName": r.get("bandName", "").strip(),
                    "officalSite": strip_scheme_for_band_csv_field(
                        r.get("officalSite", "")
                    ),
                    "imageUrl": strip_scheme_for_band_csv_field(r.get("imageUrl", "")),
                    "youtube": r.get("youtube", "").strip(),
                    "metalArchives": r.get("metalArchives", "").strip(),
                    "wikipedia": r.get("wikipedia", "").strip(),
                    "country": r.get("country", "").strip(),
                    "genre": r.get("genre", "").strip(),
                    "noteworthy": r.get("noteworthy", "").strip(),
                    "priorYears": r.get("priorYears", "").strip(),
                }
            )

    schedule_out: list[dict[str, str]] = []
    band_set = set(all_bands)
    for year in ("2026", "2025", "2024"):
        schedule_out.extend(
            schedule_rows_for_bands(schedule_by_year[year], band_set)
        )

    # Dedupe identical show lines (same band/time/location) if any
    seen: set[tuple[str, ...]] = set()
    deduped: list[dict[str, str]] = []
    for row in schedule_out:
        key = tuple(row[k] for k in ("Band", "Date", "Start Time", "Location"))
        if key in seen:
            continue
        seen.add(key)
        deduped.append(row)
    schedule_out = deduped

    desc_out: list[dict[str, str]] = []
    desc_seen: set[str] = set()
    for year in ("2026", "2025", "2024"):
        for row in desc_by_year[year]:
            band = (row.get("Band") or "").strip()
            if band not in band_set or band in desc_seen:
                continue
            url = (row.get("URL") or "").strip()
            if not url.startswith("http"):
                continue
            d = (row.get("Date") or "").strip() or "03-20-2026"
            desc_out.append({"Band": band, "URL": url, "Date": d})
            desc_seen.add(band)

    fixtures.mkdir(parents=True, exist_ok=True)

    lineup_out = lineup_rows + QR_PLACEHOLDER_LINEUP
    lineup_path = fixtures / "qa_lineup_three_bands.csv"
    with lineup_path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=ARTIST_FIELDS, lineterminator="\n")
        w.writeheader()
        w.writerows(lineup_out)

    sched_shows_path = fixtures / "qa_schedule_shows_only.csv"
    sched_window_path = fixtures / "qa_schedule_march_2026_current_window.csv"
    for sched_path in (sched_shows_path, sched_window_path):
        with sched_path.open("w", encoding="utf-8", newline="") as f:
            w = csv.DictWriter(f, fieldnames=SCHEDULE_OUT_FIELDS, lineterminator="\n")
            w.writeheader()
            w.writerows(schedule_out)

    pre_path = fixtures / "qa_schedule_with_preparties.csv"
    with pre_path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=SCHEDULE_OUT_FIELDS, lineterminator="\n")
        w.writeheader()
        w.writerows(PREPARTY_FIXTURE_ROWS + schedule_out)

    desc_fields = ["Band", "URL", "Date"]
    desc_empty = list(desc_out)
    qa_alpha_note = {
        "Band": "QA Alpha Band",
        "URL": NOTES_QA_ALPHA_URL,
        "Date": "03-20-2026",
    }
    desc_with_notes = list(desc_out) + [qa_alpha_note]

    desc_path_empty = fixtures / "qa_description_map_empty.csv"
    with desc_path_empty.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=desc_fields, lineterminator="\n")
        w.writeheader()
        w.writerows(desc_empty)

    desc_path_notes = fixtures / "qa_description_map_with_notes.csv"
    with desc_path_notes.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=desc_fields, lineterminator="\n")
        w.writeheader()
        w.writerows(desc_with_notes)

    print(
        f"Wrote {lineup_path} ({len(lineup_out)} bands = {len(lineup_rows)} sample + "
        f"{len(QR_PLACEHOLDER_LINEUP)} QR placeholders)\n"
        f"      {sched_shows_path} ({len(schedule_out)} show rows)\n"
        f"      {sched_window_path} (same shows, march 2026 window)\n"
        f"      {pre_path} ({len(PREPARTY_FIXTURE_ROWS) + len(schedule_out)} rows)\n"
        f"      {desc_path_empty.name} ({len(desc_empty)} rows), "
        f"{desc_path_notes.name} ({len(desc_with_notes)} rows)\n"
        f"Bands missing description text URL: "
        f"{sorted(band_set - desc_seen)}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

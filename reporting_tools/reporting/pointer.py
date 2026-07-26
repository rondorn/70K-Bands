from __future__ import annotations

from pathlib import Path
from typing import Dict
from urllib.parse import unquote, urlparse
from urllib.request import Request, urlopen

from reporting.models import FestivalConfig

CURRENT_DOWNLOAD_KEYS = (
    ("artistUrl", "artist lineup"),
    ("scheduleUrl", "artist schedule"),
)


def parse_pointer_text(text: str) -> Dict[str, Dict[str, str]]:
    sections: Dict[str, Dict[str, str]] = {}
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.count("::") < 2:
            continue
        section, key, value = line.split("::", 2)
        sections.setdefault(section, {})[key] = value
    return sections


def fetch_text(url: str, timeout_s: float = 60.0) -> str:
    req = Request(url, headers={"User-Agent": "festival-reporting/1.0"})
    with urlopen(req, timeout=timeout_s) as resp:
        return resp.read().decode("utf-8")


def filename_from_url(url: str) -> str:
    path = urlparse(url).path
    return unquote(path.rsplit("/", 1)[-1])


def local_path_for_url(url: str, data_dir: Path) -> Path:
    return data_dir / filename_from_url(url)


def extract_ranking_user_id(user_id: str, event_year: str | int) -> str:
    value = (user_id or "").strip()
    if not value:
        return ""

    year_candidates: list[str] = []
    if event_year:
        year_candidates.append(str(event_year))
    for legacy_year in ("2027", "2026", "2025"):
        if legacy_year not in year_candidates:
            year_candidates.append(legacy_year)

    for year in year_candidates:
        marker = f"-{year}-"
        if marker in value:
            return value.split(marker)[0]

    return value


def sync_pointer(config: FestivalConfig, dry_run: bool = False) -> FestivalConfig:
    print(f"=== {config.name} ({config.id}) — pointer sync ===")
    print(f"Pointer URL:  {config.pointer_url}")
    print(f"Pointer path: {config.pointer_path}")
    print(f"Public data:  {config.public_data_dir}")

    pointer_text = fetch_text(config.pointer_url)
    current = parse_pointer_text(pointer_text).get("Current", {})
    if not current:
        raise RuntimeError(f"Pointer for {config.id} is missing a Current:: section")

    if dry_run:
        print("Dry run — would download:")
        print(f"  pointer -> {config.pointer_path}")
        for key, label in CURRENT_DOWNLOAD_KEYS:
            url = (current.get(key) or "").strip()
            if not url:
                print(f"  (skip {label}: no Current::{key})")
                continue
            dest = local_path_for_url(url, config.public_data_dir)
            print(f"  {label}: {url}")
            print(f"           -> {dest}")
        config.event_year = (current.get("eventYear") or "").strip()
        return config

    config.pointer_path.parent.mkdir(parents=True, exist_ok=True)
    config.pointer_path.write_text(pointer_text, encoding="utf-8")
    print(f"Saved pointer: {config.pointer_path}")

    config.event_year = (current.get("eventYear") or "").strip()
    if not config.event_year:
        raise RuntimeError(f"Pointer for {config.id} is missing Current::eventYear")

    for key, label in CURRENT_DOWNLOAD_KEYS:
        url = (current.get(key) or "").strip()
        if not url:
            print(f"Skipping {label}: Current::{key} not set")
            continue

        dest = local_path_for_url(url, config.public_data_dir)
        print(f"Downloading {label}...")
        print(f"  from: {url}")
        print(f"    to: {dest}")
        file_text = fetch_text(url)
        if not file_text.strip():
            raise RuntimeError(f"Downloaded empty file from {url}")
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(file_text, encoding="utf-8")
        print(f"  saved ({dest.stat().st_size} bytes)")

        if key == "artistUrl":
            config.artist_lineup_path = dest
        elif key == "scheduleUrl":
            config.artist_schedule_path = dest

    print(f"Current event year: {config.event_year}")
    return config


def load_pointer_from_disk(config: FestivalConfig) -> FestivalConfig:
    if not config.pointer_path.exists():
        raise FileNotFoundError(f"Pointer file not found: {config.pointer_path}")

    sections = parse_pointer_text(config.pointer_path.read_text(encoding="utf-8"))
    current = sections.get("Current", {})
    config.event_year = (current.get("eventYear") or "").strip()
    if not config.event_year:
        raise RuntimeError(
            f"Pointer for {config.id} is missing Current::eventYear "
            f"in {config.pointer_path}"
        )

    artist_url = (current.get("artistUrl") or "").strip()
    schedule_url = (current.get("scheduleUrl") or "").strip()

    if artist_url:
        config.artist_lineup_path = local_path_for_url(artist_url, config.public_data_dir)
    if schedule_url:
        config.artist_schedule_path = local_path_for_url(
            schedule_url, config.public_data_dir
        )

    return config

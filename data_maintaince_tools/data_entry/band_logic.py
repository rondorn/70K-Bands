"""Band lineup CSV helpers."""

from __future__ import annotations

import csv
import hashlib
from pathlib import Path
from typing import Any
from urllib.parse import quote, urlparse

from data_entry.config_store import lineup_fields
from data_entry.http_util import fetch_url


def build_wikipedia_search_url(band_name: str) -> str:
    return f"https://en.wikipedia.org/wiki/Special:Search/{quote((band_name or '').strip())}"


def build_youtube_search_url(band_name: str, latest_album: str = "") -> str:
    """YouTube results search for an official music video (never a direct video/channel URL)."""
    band_part = quote((band_name or "").strip(), safe="")
    album = (latest_album or "").strip()
    suffix = band_part
    if album:
        suffix = f"{band_part}+{quote(album, safe='')}"
    return f"https://www.youtube.com/results?search_query=official+music+video+{suffix}"


def build_metal_archives_search_url(band_name: str) -> str:
    encoded = quote((band_name or "").strip())
    return (
        f"https://www.metal-archives.com/search?searchString={encoded}&type=band_name"
    )


def normalize_https_prefix(url: str) -> str:
    value = (url or "").strip()
    if value.lower().startswith("https://"):
        return value[8:]
    if value.lower().startswith("http://"):
        return value[7:]
    return value


def strip_image_url_numeric_query(url: str) -> str:
    import re

    return re.sub(r"\?\d+$", "", (url or "").strip())


def validate_url(url: str, expected_domain: str | None = None) -> tuple[bool, str]:
    if not (url or "").strip():
        return True, ""
    try:
        parsed = urlparse(url if "://" in url else f"https://{url}")
        if not parsed.scheme or not parsed.netloc:
            return False, f"Invalid URL format: {url}"
        if expected_domain and expected_domain not in parsed.netloc.lower():
            return False, f"URL should be from {expected_domain}: {url}"
        return True, ""
    except Exception as exc:
        return False, f"URL validation error: {exc}"


def validate_band_data(data: dict[str, str]) -> tuple[bool, list[str]]:
    errors: list[str] = []
    if not data.get("bandName", "").strip():
        errors.append("Band name is required")
    for field, domain in (
        ("youtube", "youtube.com"),
        ("metalArchives", "metal-archives.com"),
        ("wikipedia", "wikipedia.org"),
    ):
        if data.get(field):
            ok, msg = validate_url(
                data[field] if "://" in data[field] else f"https://{data[field]}",
                domain,
            )
            if not ok:
                errors.append(msg)
    for field in ("officalSite", "imageUrl"):
        if data.get(field):
            ok, msg = validate_url(
                data[field] if "://" in data[field] else f"https://{data[field]}"
            )
            if not ok:
                errors.append(msg)
    return len(errors) == 0, errors


def load_band_names(band_list_url: str, lineup_file: str) -> list[str]:
    cache_key = hashlib.md5(f"{band_list_url}|{lineup_file}".encode()).hexdigest()
    cache_dir = Path(lineup_file).parent / ".cache" if lineup_file else Path(".cache")
    cache_dir.mkdir(parents=True, exist_ok=True)
    cache_file = cache_dir / f"band_names_{cache_key}.txt"

    source_mtime = 0.0
    if lineup_file and Path(lineup_file).is_file():
        source_mtime = Path(lineup_file).stat().st_mtime
    if cache_file.is_file() and cache_file.stat().st_mtime >= source_mtime:
        return cache_file.read_text(encoding="utf-8").splitlines()

    names: list[str] = []
    csv_text = ""
    if band_list_url:
        try:
            csv_text = fetch_url(band_list_url)
        except Exception:
            csv_text = ""
    if not csv_text and lineup_file and Path(lineup_file).is_file():
        csv_text = Path(lineup_file).read_text(encoding="utf-8")

    if csv_text:
        reader = csv.DictReader(csv_text.splitlines())
        for row in reader:
            name = (row.get("bandName") or row.get("Band") or "").strip()
            if name and name.lower() != "bandname":
                names.append(name)

    names = sorted(set(names))
    cache_file.write_text("\n".join(names), encoding="utf-8")
    return names


def check_duplicate(band_name: str, csv_file: str) -> bool:
    path = Path(csv_file)
    if not path.is_file():
        return False
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            if (row.get("bandName") or "").strip().lower() == band_name.strip().lower():
                return True
    return False


def append_band(data: dict[str, str], csv_file: str, cfg: dict[str, Any]) -> None:
    fields = lineup_fields(bool(cfg.get("include_prior_years_field")))
    path = Path(csv_file)
    path.parent.mkdir(parents=True, exist_ok=True)
    write_header = not path.is_file() or path.stat().st_size == 0
    with path.open("a", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        if write_header:
            writer.writeheader()
        writer.writerow({field: data.get(field, "") for field in fields})

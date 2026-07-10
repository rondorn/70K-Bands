"""Band lineup CSV helpers."""

from __future__ import annotations

import csv
import re
from pathlib import Path
from typing import Any
from urllib.parse import quote, urlparse

from data_entry.config_store import lineup_fields
from data_entry.network_cache import (
    CacheMeta,
    fetch_cached_text_or_empty,
    invalidate_festival_network_cache,
)


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
    """Strip scheme for officalSite and imageUrl CSV storage."""
    value = (url or "").strip()
    if value.lower().startswith("https://"):
        return value[8:]
    if value.lower().startswith("http://"):
        return value[7:]
    return value


def ensure_https_prefix(url: str) -> str:
    """Ensure scheme for youtube, wikipedia, and metalArchives CSV storage."""
    value = (url or "").strip()
    if not value:
        return value
    if value.lower().startswith("https://"):
        return value
    if value.lower().startswith("http://"):
        return "https://" + value[7:]
    return f"https://{value}"


def strip_image_url_numeric_query(url: str) -> str:
    import re

    return re.sub(r"\?\d+$", "", (url or "").strip())


def normalize_genre_for_csv(genre: str) -> str:
    """Replace commas with slashes so genre fits unquoted CSV cells."""
    return re.sub(r",\s*", "/", (genre or "").strip())


def format_band_location(
    city: str = "", state: str = "", country: str = ""
) -> str:
    """Format optional city/state/country for band detail display."""
    city_value = (city or "").strip()
    state_value = (state or "").strip()
    country_value = (country or "").strip()

    if city_value and state_value and country_value:
        return f"{city_value}, {state_value} {country_value}"
    if city_value and country_value:
        return f"{city_value}, {country_value}"
    if country_value:
        return country_value
    if city_value and state_value:
        return f"{city_value}, {state_value}"
    if city_value:
        return city_value
    return ""


def normalize_band_row_for_csv(row: dict[str, str]) -> dict[str, str]:
    normalized = dict(row)
    if "genre" in normalized:
        normalized["genre"] = normalize_genre_for_csv(normalized.get("genre", ""))
    return normalized


def validate_url(url: str, expected_domain: str | None = None) -> tuple[bool, str]:
    """Validate a URL; values stored without https:// are accepted (scheme added for parsing only)."""
    if not (url or "").strip():
        return True, ""
    try:
        parsed = urlparse(url if "://" in url else f"https://{url}")
        if not parsed.netloc:
            return False, f"Invalid URL format: {url}"
        if expected_domain and expected_domain not in parsed.netloc.lower():
            return False, f"URL should be from {expected_domain}: {url}"
        return True, ""
    except Exception as exc:
        return False, f"URL validation error: {exc}"


def normalize_band_url_fields(data: dict[str, str]) -> dict[str, str]:
    """Apply per-field URL storage rules for lineup CSV."""
    out = dict(data)

    offical = (out.get("officalSite") or "").strip()
    if offical:
        out["officalSite"] = normalize_https_prefix(offical)

    image = (out.get("imageUrl") or "").strip()
    if image:
        out["imageUrl"] = normalize_https_prefix(strip_image_url_numeric_query(image))

    for field in ("youtube", "metalArchives", "wikipedia"):
        value = (out.get(field) or "").strip()
        if value:
            out[field] = ensure_https_prefix(value)

    return out


def apply_band_url_defaults(
    data: dict[str, str],
    band_name: str = "",
    latest_album: str = "",
) -> dict[str, str]:
    """Fill empty URL fields only; never overwrite values the user entered."""
    out = dict(data)
    name = (band_name or out.get("bandName") or "").strip()
    if not name:
        return out
    if not (out.get("youtube") or "").strip():
        out["youtube"] = build_youtube_search_url(name, latest_album)
    if not (out.get("wikipedia") or "").strip():
        out["wikipedia"] = build_wikipedia_search_url(name)
    if not (out.get("metalArchives") or "").strip():
        out["metalArchives"] = build_metal_archives_search_url(name)
    return out


def validate_band_data(
    data: dict[str, str],
    cfg: dict[str, Any] | None = None,
    lineup_file: str = "",
    band_list_url: str = "",
    exclude_index: int | None = None,
) -> tuple[bool, list[str]]:
    errors: list[str] = []
    cfg = cfg or {}

    field_labels = {
        "bandName": "Band name",
        "officalSite": "Official site",
        "imageUrl": "Image URL",
        "youtube": "YouTube",
        "country": "Country",
        "genre": "Genre",
        "metalArchives": "Metal Archives",
        "wikipedia": "Wikipedia",
    }
    required = ["bandName", "officalSite", "imageUrl", "youtube", "country", "genre"]

    for field in required:
        if not (data.get(field) or "").strip():
            errors.append(f"{field_labels[field]} is required")

    band_name = (data.get("bandName") or "").strip()
    read_url = (band_list_url or "").strip()
    if band_name and read_url:
        for idx, row in enumerate(read_lineup_from_url(read_url, cfg)):
            if exclude_index is not None and idx == exclude_index:
                continue
            if row.get("bandName", "").strip() == band_name:
                errors.append(
                    f"Band '{band_name}' already exists in the published lineup"
                )
                break
    elif band_name and lineup_file:
        for idx, row in enumerate(read_lineup(lineup_file, cfg)):
            if exclude_index is not None and idx == exclude_index:
                continue
            if row.get("bandName", "").strip() == band_name:
                errors.append(f"Band '{band_name}' already exists in the lineup file")
                break

    for field in ("officalSite", "imageUrl"):
        value = (data.get(field) or "").strip()
        if value:
            ok, msg = validate_url(value)
            if not ok:
                errors.append(f"{field_labels[field]}: {msg}")

    youtube = (data.get("youtube") or "").strip()
    if youtube:
        ok, msg = validate_url(youtube, "youtube.com")
        if not ok:
            errors.append(f"YouTube: {msg}")

    for field, domain in (
        ("metalArchives", "metal-archives.com"),
        ("wikipedia", "wikipedia.org"),
    ):
        value = (data.get(field) or "").strip()
        if value:
            ok, msg = validate_url(value, domain)
            if not ok:
                errors.append(f"{field_labels[field]}: {msg}")

    return len(errors) == 0, errors


def _invalidate_published_cache(cfg: dict[str, Any]) -> None:
    from data_entry.config_store import resolved_paths

    invalidate_festival_network_cache(resolved_paths(cfg))


def lineup_band_names(
    cfg: dict[str, Any],
    paths: dict[str, str],
    *,
    force_refresh: bool = False,
) -> tuple[list[str], CacheMeta | None]:
    """
    Band names for schedule dropdowns and similar UI.

    Band List Admin reads the local lineup file so new bands appear immediately.
    Everyone else reads the published URL through the TTL network cache.
    """
    from data_entry.config_store import band_list_reads_local

    if band_list_reads_local(cfg):
        rows = read_lineup(paths.get("lineup_file", ""), cfg)
        names = [
            row.get("bandName", "").strip()
            for row in rows
            if row.get("bandName", "").strip()
        ]
        return names, None

    url = (paths.get("band_list_url", "") or "").strip()
    if url:
        csv_text, meta = fetch_cached_text_or_empty(
            url, paths, force_refresh=force_refresh
        )
        rows = (
            _parse_lineup_csv(csv_text, lineup_fields()) if csv_text else []
        )
        names = [
            row.get("bandName", "").strip()
            for row in rows
            if row.get("bandName", "").strip()
        ]
        return names, meta

    if paths.get("lineup_file"):
        rows = read_lineup(paths.get("lineup_file", ""), cfg)
        names = [
            row.get("bandName", "").strip()
            for row in rows
            if row.get("bandName", "").strip()
        ]
        return names, None

    return [], None


def load_band_names(band_list_url: str, lineup_file: str = "") -> list[str]:
    """Load band names using path arguments only (no role-aware local read)."""
    paths = {"band_list_url": band_list_url, "lineup_file": lineup_file}
    names, _meta = lineup_band_names({}, paths)
    return names


def check_duplicate(
    band_name: str,
    csv_file: str,
    cfg: dict[str, Any],
    exclude_index: int | None = None,
) -> bool:
    rows = read_lineup(csv_file, cfg)
    for idx, row in enumerate(rows):
        if exclude_index is not None and idx == exclude_index:
            continue
        if row.get("bandName", "").strip() == band_name.strip():
            return True
    return False


def read_lineup(csv_file: str, cfg: dict[str, Any]) -> list[dict[str, str]]:
    """Read lineup rows from a local CSV file (write target only)."""
    fields = lineup_fields()
    path = Path(csv_file)
    if not path.is_file():
        return []
    return _parse_lineup_csv(path.read_text(encoding="utf-8"), fields)


def read_lineup_from_url(
    url: str,
    cfg: dict[str, Any],
    *,
    force_refresh: bool = False,
) -> list[dict[str, str]]:
    """Read lineup rows from the published network URL (TTL-cached)."""
    fields = lineup_fields()
    url = (url or "").strip()
    if not url:
        return []
    from data_entry.config_store import resolved_paths

    paths = resolved_paths(cfg)
    csv_text, _meta = fetch_cached_text_or_empty(
        url, paths, force_refresh=force_refresh
    )
    if not csv_text:
        return []
    return _parse_lineup_csv(csv_text, fields)


def _parse_lineup_csv(csv_text: str, fields: list[str]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    reader = csv.DictReader(csv_text.splitlines())
    for row in reader:
        name = (row.get("bandName") or "").strip()
        if not name or name.lower() == "bandname":
            continue
        rows.append({field: (row.get(field) or "").strip() for field in fields})
    return rows


def lineup_rows_for_display(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    indexed = [{"source_index": i, **row} for i, row in enumerate(rows)]
    indexed.sort(key=lambda row: (row.get("bandName") or "").casefold())
    return indexed


def write_lineup(
    csv_file: str, rows: list[dict[str, str]], cfg: dict[str, Any]
) -> None:
    fields = lineup_fields()
    path = Path(csv_file)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for row in rows:
            normalized = normalize_band_row_for_csv(row)
            writer.writerow({field: normalized.get(field, "") for field in fields})
    _invalidate_published_cache(cfg)


def remove_band_at_index(rows: list[dict[str, str]], index: int) -> list[dict[str, str]]:
    return [row for i, row in enumerate(rows) if i != index]


def replace_band_at_index(
    rows: list[dict[str, str]], index: int, replacement: dict[str, str]
) -> list[dict[str, str]]:
    updated = list(rows)
    if 0 <= index < len(updated):
        updated[index] = replacement
    return updated


def append_band(data: dict[str, str], csv_file: str, cfg: dict[str, Any]) -> None:
    fields = lineup_fields()
    path = Path(csv_file)
    path.parent.mkdir(parents=True, exist_ok=True)
    write_header = not path.is_file() or path.stat().st_size == 0
    with path.open("a", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        if write_header:
            writer.writeheader()
        normalized = normalize_band_row_for_csv(data)
        writer.writerow({field: normalized.get(field, "") for field in fields})
    _invalidate_published_cache(cfg)

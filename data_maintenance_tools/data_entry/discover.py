"""Unified band discovery: Metal Archives or MusicBrainz URL, with cross-source fill-in."""

from __future__ import annotations

import re
from typing import Any

from data_entry.band_logic import (
    build_wikipedia_search_url,
    build_youtube_search_url,
    normalize_genre_for_csv,
)
from data_entry.metal_archives import (
    MetalArchivesDiscoverError,
    discover_from_metal_archives,
)
from data_entry.musicbrainz import (
    MusicBrainzDiscoverError,
    discover_from_musicbrainz,
    discover_from_musicbrainz_url,
    is_musicbrainz_artist_url,
)

MA_BAND_URL_RE = re.compile(
    r"https?://(?:www\.)?metal-archives\.com/bands/",
    re.IGNORECASE,
)


def _is_metal_archives_url(url: str) -> bool:
    return bool(MA_BAND_URL_RE.search((url or "").strip()))


def discover_band(
    metal_archives_url: str = "",
    musicbrainz_url: str = "",
    band_name: str = "",
) -> dict[str, Any]:
    warnings: list[str] = []
    data: dict[str, str] = {}
    sources: list[str] = []

    ma_url = (metal_archives_url or "").strip()
    mb_url = (musicbrainz_url or "").strip()

    # If a MusicBrainz URL was pasted into the Metal Archives field, reroute it.
    if ma_url and is_musicbrainz_artist_url(ma_url) and not mb_url:
        mb_url = ma_url
        ma_url = ""

    if ma_url and not _is_metal_archives_url(ma_url):
        return {
            "ok": False,
            "error": "Metal Archives URL must be a band page on metal-archives.com.",
            "warnings": warnings,
        }

    if ma_url:
        try:
            ma_data, ma_warnings = discover_from_metal_archives(
                ma_url,
                fallback_band_name=band_name,
            )
            data.update({k: v for k, v in ma_data.items() if v})
            warnings.extend(ma_warnings)
            sources.append("metal_archives")
        except MetalArchivesDiscoverError as exc:
            warnings.append(str(exc))

    if mb_url:
        try:
            mb_data, mb_warnings = discover_from_musicbrainz_url(
                mb_url,
                fallback_band_name=band_name or data.get("bandName", ""),
            )
            _merge_missing(data, mb_data)
            warnings.extend(mb_warnings)
            sources.append("musicbrainz")
        except MusicBrainzDiscoverError as exc:
            warnings.append(str(exc))
    else:
        resolved_name = (data.get("bandName") or band_name or "").strip()
        needs_mb = not data.get("bandName") or (
            not data.get("country")
            and not data.get("genre")
            and not data.get("officalSite")
        )
        if needs_mb and resolved_name:
            mb_data, mb_warnings = discover_from_musicbrainz(resolved_name)
            _merge_missing(data, mb_data)
            warnings.extend(mb_warnings)
            if mb_data.get("bandName"):
                sources.append("musicbrainz")

    if not data.get("bandName") and band_name:
        data["bandName"] = band_name.strip()

    latest_album = data.get("latestAlbum", "").strip()
    name = data.get("bandName", "").strip()
    if name:
        if not data.get("wikipedia"):
            data["wikipedia"] = build_wikipedia_search_url(name)
        data["youtube"] = build_youtube_search_url(name, latest_album)

    if not data.get("bandName"):
        return {
            "ok": False,
            "error": "No band data found. Provide a Metal Archives URL, MusicBrainz URL, or band name.",
            "warnings": warnings,
        }

    data.pop("noteworthy", None)

    if data.get("genre"):
        data["genre"] = normalize_genre_for_csv(data["genre"])

    return {
        "ok": True,
        "data": data,
        "warnings": warnings,
        "source": "+".join(sources) if sources else "unknown",
    }


def _merge_missing(target: dict[str, str], incoming: dict[str, str]) -> None:
    for key, value in incoming.items():
        if value and not target.get(key):
            target[key] = value

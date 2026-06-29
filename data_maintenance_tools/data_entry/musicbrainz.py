"""MusicBrainz artist lookup by URL, MBID, or band name."""

from __future__ import annotations

import json
import re
import time
from typing import Any
from urllib.parse import quote
from urllib.request import Request, urlopen

from bs4 import BeautifulSoup

from data_entry.country_names import expand_country_code
from data_entry.http_util import USER_AGENT, fetch_url

MB_BASE = "https://musicbrainz.org/ws/2"
CAA_BASE = "https://coverartarchive.org/release-group"

MB_ARTIST_URL_RE = re.compile(
    r"https?://(?:www\.)?musicbrainz\.org/artist/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})",
    re.IGNORECASE,
)
MB_ID_RE = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
    re.IGNORECASE,
)

_last_request_at = 0.0


class MusicBrainzDiscoverError(Exception):
    pass


def is_musicbrainz_artist_url(url: str) -> bool:
    return bool(MB_ARTIST_URL_RE.search((url or "").strip()))


def parse_musicbrainz_artist_id(url_or_mbid: str) -> str:
    raw = (url_or_mbid or "").strip()
    match = MB_ARTIST_URL_RE.search(raw)
    if match:
        return match.group(1).lower()
    if MB_ID_RE.match(raw):
        return raw.lower()
    raise MusicBrainzDiscoverError(
        "MusicBrainz URL must be an artist page "
        "(e.g. https://musicbrainz.org/artist/f291ffa8-891c-46ae-ba5e-fd3c53db56f0)"
    )


def musicbrainz_artist_url(mbid: str) -> str:
    return f"https://musicbrainz.org/artist/{mbid}"


def _rate_limit() -> None:
    global _last_request_at
    elapsed = time.time() - _last_request_at
    if elapsed < 1.1:
        time.sleep(1.1 - elapsed)
    _last_request_at = time.time()


def _mb_get(path: str) -> dict[str, Any]:
    _rate_limit()
    url = f"{MB_BASE}{path}"
    req = Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    with urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def discover_from_musicbrainz_url(
    musicbrainz_url: str,
    fallback_band_name: str = "",
) -> tuple[dict[str, str], list[str]]:
    mbid = parse_musicbrainz_artist_id(musicbrainz_url)
    return _discover_from_artist_detail(mbid, fallback_band_name)


def discover_from_musicbrainz(band_name: str) -> tuple[dict[str, str], list[str]]:
    warnings: list[str] = []
    name = (band_name or "").strip()
    if not name:
        return {}, ["MusicBrainz lookup requires a band name."]

    query = quote(f'artist:"{name}"')
    search = _mb_get(f"/artist/?query={query}&fmt=json&limit=5")
    artists = search.get("artists") or []
    if not artists:
        return {}, [f"No MusicBrainz artist found for '{name}'."]

    mbid = artists[0].get("id", "")
    if not mbid:
        return {}, ["MusicBrainz search returned no artist ID."]

    data, detail_warnings = _discover_from_artist_detail(mbid, name)
    warnings.extend(detail_warnings)
    if len(artists) > 1:
        warnings.append(
            f"MusicBrainz returned {len(artists)} matches; using '{data.get('bandName', name)}'."
        )
    return data, warnings


def _discover_from_artist_detail(
    mbid: str,
    fallback_band_name: str = "",
) -> tuple[dict[str, str], list[str]]:
    warnings: list[str] = []
    detail = _mb_get(
        f"/artist/{mbid}?inc=url-rels+tags+genres+release-groups&fmt=json"
    )

    band_name = detail.get("name") or fallback_band_name.strip()
    if not band_name:
        raise MusicBrainzDiscoverError("Could not determine band name from MusicBrainz.")

    latest_album, album_warnings = _latest_studio_album(detail)
    warnings.extend(album_warnings)

    wikipedia = _url_for_types(detail, ("wikipedia",))
    if wikipedia and "wikipedia.org" not in wikipedia.lower():
        wikipedia = ""

    metal_archives = _url_for_types(detail, ("metal archives",))
    if not metal_archives:
        metal_archives = _url_containing(detail, "metal-archives.com")

    official_site = _url_for_types(detail, ("official homepage", "official site"))
    if not official_site:
        official_site = _url_for_types(detail, ("bandcamp",))

    image_url, image_warnings = _resolve_artist_image(detail)
    warnings.extend(image_warnings)

    data: dict[str, str] = {
        "bandName": band_name,
        "musicBrainz": musicbrainz_artist_url(mbid),
        "country": expand_country_code(detail.get("country") or ""),
        "genre": _format_genre(detail),
        "officalSite": _normalize_site_url(official_site),
        "wikipedia": wikipedia,
        "youtube": "",
        "metalArchives": metal_archives,
        "imageUrl": _normalize_site_url(image_url),
        "latestAlbum": latest_album,
    }

    if not data["country"]:
        warnings.append("Country not listed on MusicBrainz.")
    if not data["genre"]:
        warnings.append("Genre/tags not found on MusicBrainz.")
    if not data["officalSite"]:
        warnings.append("No official homepage or Bandcamp link on MusicBrainz.")
    if not data["wikipedia"]:
        warnings.append("No English Wikipedia link on MusicBrainz (Wikidata-only).")
    if not data["metalArchives"]:
        warnings.append("No Metal Archives link on MusicBrainz.")

    return data, warnings


def _capitalize_genre_label(value: str) -> str:
    value = (value or "").strip()
    if not value:
        return ""

    def title_word(word: str) -> str:
        word = word.strip()
        if not word:
            return word
        return word[:1].upper() + word[1:].lower()

    parts: list[str] = []
    for slash_segment in value.split("/"):
        parts.append(" ".join(title_word(word) for word in slash_segment.split() if word))
    return "/".join(parts)


def _format_genre(detail: dict[str, Any]) -> str:
    genres = detail.get("genres") or []
    if genres:
        ranked = sorted(genres, key=lambda g: g.get("count", 0), reverse=True)
        return " / ".join(
            _capitalize_genre_label(g["name"])
            for g in ranked[:3]
            if g.get("name")
        )
    tags = detail.get("tags") or []
    if tags:
        ranked = sorted(tags, key=lambda t: t.get("count", 0), reverse=True)
        return " / ".join(
            _capitalize_genre_label(t["name"])
            for t in ranked[:3]
            if t.get("name")
        )
    return ""


def _url_for_types(detail: dict[str, Any], preferred_types: tuple[str, ...]) -> str:
    relations = detail.get("relations") or []
    lowered = [t.lower() for t in preferred_types]
    for rel in relations:
        rel_type = (rel.get("type") or "").lower()
        resource = rel.get("url", {}).get("resource")
        if rel_type in lowered and resource:
            return resource.strip()
    return ""


def _url_containing(detail: dict[str, Any], needle: str) -> str:
    needle = needle.lower()
    for rel in detail.get("relations") or []:
        resource = (rel.get("url", {}).get("resource") or "").strip()
        if needle in resource.lower():
            return resource
    return ""


def _normalize_site_url(url: str) -> str:
    value = (url or "").strip()
    if value.lower().startswith("https://"):
        return value[8:]
    if value.lower().startswith("http://"):
        return value[7:]
    return value


def _latest_studio_album(detail: dict[str, Any]) -> tuple[str, list[str]]:
    warnings: list[str] = []
    release_groups = detail.get("release-groups") or []
    albums = [
        rg
        for rg in release_groups
        if rg.get("primary-type") == "Album"
        and "Compilation" not in (rg.get("secondary-types") or [])
        and "Live" not in (rg.get("secondary-types") or [])
    ]
    if not albums:
        albums = [rg for rg in release_groups if rg.get("primary-type") == "Album"]
    if not albums:
        return "", ["No album release groups found on MusicBrainz."]

    albums.sort(key=lambda rg: rg.get("first-release-date") or "", reverse=True)
    title = (albums[0].get("title") or "").strip()
    if not title:
        return "", ["Latest album title missing on MusicBrainz."]
    return title, warnings


def _cover_art_for_latest_album(detail: dict[str, Any]) -> str:
    release_groups = detail.get("release-groups") or []
    albums = [rg for rg in release_groups if rg.get("primary-type") == "Album"]
    if not albums:
        return ""
    albums.sort(key=lambda rg: rg.get("first-release-date") or "", reverse=True)
    rg_id = albums[0].get("id")
    if not rg_id:
        return ""

    try:
        _rate_limit()
        url = f"{CAA_BASE}/{rg_id}"
        req = Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
        with urlopen(req, timeout=20) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
    except Exception:
        return ""

    for image in payload.get("images") or []:
        if image.get("front"):
            return _normalize_site_url(
                image.get("image") or image.get("thumbnails", {}).get("large", "")
            )
    return ""


def _resolve_artist_image(detail: dict[str, Any]) -> tuple[str, list[str]]:
    """Bandcamp artist image first, then latest album cover from Cover Art Archive."""
    warnings: list[str] = []

    bandcamp_url = _url_for_types(detail, ("bandcamp",))
    if bandcamp_url:
        image, bandcamp_note = _bandcamp_image_from_page(bandcamp_url)
        if image:
            if bandcamp_note:
                warnings.append(bandcamp_note)
            return _normalize_site_url(image), warnings
        warnings.append(
            f"Bandcamp page found ({bandcamp_url}) but no logo/image could be loaded."
        )

    cover = _cover_art_for_latest_album(detail)
    if cover:
        if bandcamp_url:
            warnings.append("Using latest album cover from Cover Art Archive instead.")
        else:
            warnings.append(
                "No Bandcamp link on MusicBrainz; using latest album cover."
            )
        return cover, warnings

    warnings.append("No Bandcamp or album cover image found.")
    return "", warnings


def _bandcamp_image_from_page(page_url: str) -> tuple[str, str]:
    """
    Extract the band logo/header image from a Bandcamp artist page.

    Prefers the custom header logo over og:image (which is often a promo banner).
    Returns (image_url, note_for_user).
    """
    html = _fetch_bandcamp_html(page_url)
    if not html:
        return "", ""

    soup = BeautifulSoup(html, "html.parser")

    custom_img = soup.select_one("#customHeader img[src*='bcbits.com']")
    if custom_img and custom_img.get("src"):
        src = custom_img["src"].strip()
        if "blank.gif" not in src:
            return src, "Band image from Bandcamp header logo."

    icon = soup.find("link", rel="apple-touch-icon", href=re.compile(r"bcbits\.com"))
    if icon and icon.get("href"):
        return icon["href"].strip(), "Band image from Bandcamp (apple-touch-icon)."

    for key, attr in (
        ("og:image", "property"),
        ("og:image:url", "property"),
        ("twitter:image", "name"),
        ("twitter:image:src", "property"),
    ):
        tag = soup.find("meta", attrs={attr: key})
        if tag and tag.get("content"):
            return (
                tag["content"].strip(),
                "Band image from Bandcamp preview (og:image; may be promo art).",
            )

    return "", ""


def _fetch_bandcamp_html(page_url: str) -> str:
    try:
        html = fetch_url(page_url)
        if len(html) > 1000:
            return html
    except Exception:
        pass

    import shutil
    import subprocess

    if not shutil.which("curl"):
        return ""
    result = subprocess.run(
        ["curl", "-fsSL", "--max-time", "25", "-A", USER_AGENT, page_url],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode == 0 and len(result.stdout or "") > 1000:
        return result.stdout
    return ""


def _og_image_from_page(page_url: str) -> str:
    image, _ = _bandcamp_image_from_page(page_url)
    return image

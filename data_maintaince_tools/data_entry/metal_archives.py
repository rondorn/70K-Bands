"""Fetch band metadata from Encyclopedia Metallum (Metal Archives)."""

from __future__ import annotations

import re
import shutil
import subprocess
from html import unescape
from typing import Any

from bs4 import BeautifulSoup

from data_entry.http_util import USER_AGENT, fetch_url

BAND_URL_RE = re.compile(
    r"https?://(?:www\.)?metal-archives\.com/bands/[^/]+/(\d+)",
    re.IGNORECASE,
)


class MetalArchivesDiscoverError(Exception):
    pass


def _fetch_ma(url: str) -> str:
    try:
        html = fetch_url(url)
        if len(html) >= 500:
            return html
    except Exception:
        pass

    if not shutil.which("curl"):
        raise MetalArchivesDiscoverError(
            "Metal Archives returned a blocked or empty response."
        )

    result = subprocess.run(
        ["curl", "-sL", "--max-time", "25", "-A", USER_AGENT, url],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise MetalArchivesDiscoverError(
            f"curl failed (exit {result.returncode}): {(result.stderr or '').strip()}"
        )
    html = result.stdout or ""
    if len(html) < 500:
        raise MetalArchivesDiscoverError(
            "Metal Archives returned an empty or blocked response."
        )
    return html


def parse_band_id(metal_archives_url: str) -> str:
    match = BAND_URL_RE.search((metal_archives_url or "").strip())
    if not match:
        raise MetalArchivesDiscoverError(
            "Metal Archives URL must be a band page "
            "(e.g. https://www.metal-archives.com/bands/Vreid/27072)"
        )
    return match.group(1)


def _dd_text_for_label(soup: BeautifulSoup, label_prefix: str) -> str:
    for dt in soup.find_all("dt"):
        label = dt.get_text(strip=True)
        if label.startswith(label_prefix):
            dd = dt.find_next_sibling("dd")
            if dd:
                return dd.get_text(" ", strip=True)
    return ""


def _parse_band_page(html: str, band_url: str) -> dict[str, str]:
    soup = BeautifulSoup(html, "html.parser")
    band_name = ""
    h1 = soup.find("h1", class_="band_name")
    if h1:
        link = h1.find("a")
        band_name = (link or h1).get_text(strip=True)
    if not band_name:
        script_match = re.search(r'var bandName = "([^"]+)"', html)
        if script_match:
            band_name = script_match.group(1)

    country = _dd_text_for_label(soup, "Country of origin")
    genre = _dd_text_for_label(soup, "Genre")

    image_url = ""
    logo = soup.find("a", id="logo")
    if logo:
        img = logo.find("img")
        href = logo.get("href") or (img.get("src") if img else "")
        if href:
            image_url = href.split("?")[0]

    return {
        "bandName": band_name,
        "country": country,
        "genre": genre,
        "imageUrl": image_url,
        "metalArchives": band_url.strip(),
    }


def fetch_band_logo(metal_archives_url: str) -> str:
    """Return the MA band logo URL, or empty string if unavailable."""
    band_url = (metal_archives_url or "").strip()
    if not band_url or not BAND_URL_RE.search(band_url):
        return ""
    try:
        band_html = _fetch_ma(band_url)
        image_url = _parse_band_page(band_html, band_url).get("imageUrl", "")
        return normalize_image_url(image_url) if image_url else ""
    except Exception:
        return ""


def _parse_latest_full_length(html: str) -> str:
    soup = BeautifulSoup(html, "html.parser")
    latest_title = ""
    for row in soup.find_all("tr"):
        cells = row.find_all("td")
        if len(cells) < 2:
            continue
        if cells[1].get_text(strip=True) != "Full-length":
            continue
        link = cells[0].find("a", href=True)
        if link:
            latest_title = link.get_text(strip=True)
    return unescape(latest_title)


def _parse_first_official_link(html: str) -> str:
    soup = BeautifulSoup(html, "html.parser")
    in_official = False
    for row in soup.find_all("tr"):
        row_id = row.get("id") or ""
        if row_id.startswith("header_Official") and "merchandise" not in row_id.lower():
            in_official = True
            continue
        if row_id.startswith("header_") and in_official:
            break
        if not in_official:
            continue
        link = row.find("a", href=True)
        if link:
            return link["href"].strip()
    return ""


def normalize_official_site(url: str) -> str:
    value = (url or "").strip()
    if value.lower().startswith("https://"):
        return value[8:]
    if value.lower().startswith("http://"):
        return value[7:]
    return value


def normalize_image_url(url: str) -> str:
    value = re.sub(r"\?\d+$", "", (url or "").strip())
    if value.lower().startswith("https://"):
        return value[8:]
    if value.lower().startswith("http://"):
        return value[7:]
    return value


def discover_from_metal_archives(
    metal_archives_url: str,
    fallback_band_name: str = "",
) -> tuple[dict[str, str], list[str]]:
    warnings: list[str] = []
    band_id = parse_band_id(metal_archives_url)
    base = "https://www.metal-archives.com"
    band_url = metal_archives_url.strip()
    if not band_url.lower().startswith("http"):
        band_url = f"{base}/bands/_/{band_id}"

    data: dict[str, str] = {
        "bandName": "",
        "metalArchives": band_url,
        "latestAlbum": "",
        "officalSite": "",
        "imageUrl": "",
        "youtube": "",
        "wikipedia": "",
        "country": "",
        "genre": "",
    }

    try:
        band_html = _fetch_ma(band_url)
        page_data = _parse_band_page(band_html, band_url)
        data.update({k: v for k, v in page_data.items() if v})
    except Exception as exc:
        raise MetalArchivesDiscoverError(f"Failed to load band page: {exc}") from exc

    if not data["bandName"] and fallback_band_name:
        data["bandName"] = fallback_band_name.strip()
        warnings.append("Band name taken from form input (not found on MA page).")
    elif not data["bandName"]:
        warnings.append("Could not determine band name from Metal Archives.")

    try:
        discography_url = f"{base}/band/discography/id/{band_id}/tab/main"
        latest = _parse_latest_full_length(_fetch_ma(discography_url))
        if latest:
            data["latestAlbum"] = latest
        else:
            warnings.append("No full-length releases found in discography.")
    except Exception as exc:
        warnings.append(f"Discography fetch failed: {exc}")

    try:
        links_url = f"{base}/link/ajax-list/type/band/id/{band_id}"
        official = _parse_first_official_link(_fetch_ma(links_url))
        if official:
            data["officalSite"] = normalize_official_site(official)
        else:
            warnings.append("No official links found on Metal Archives.")
    except Exception as exc:
        warnings.append(f"Official links fetch failed: {exc}")

    if data.get("imageUrl"):
        data["imageUrl"] = normalize_image_url(data["imageUrl"])

    return data, warnings

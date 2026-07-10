"""Parse city and US state from Metal Archives and MusicBrainz location data."""

from __future__ import annotations

from typing import Any

US_STATE_NAME_TO_CODE: dict[str, str] = {
    "alabama": "AL",
    "alaska": "AK",
    "arizona": "AZ",
    "arkansas": "AR",
    "california": "CA",
    "colorado": "CO",
    "connecticut": "CT",
    "delaware": "DE",
    "district of columbia": "DC",
    "florida": "FL",
    "georgia": "GA",
    "hawaii": "HI",
    "idaho": "ID",
    "illinois": "IL",
    "indiana": "IN",
    "iowa": "IA",
    "kansas": "KS",
    "kentucky": "KY",
    "louisiana": "LA",
    "maine": "ME",
    "maryland": "MD",
    "massachusetts": "MA",
    "michigan": "MI",
    "minnesota": "MN",
    "mississippi": "MS",
    "missouri": "MO",
    "montana": "MT",
    "nebraska": "NE",
    "nevada": "NV",
    "new hampshire": "NH",
    "new jersey": "NJ",
    "new mexico": "NM",
    "new york": "NY",
    "north carolina": "NC",
    "north dakota": "ND",
    "ohio": "OH",
    "oklahoma": "OK",
    "oregon": "OR",
    "pennsylvania": "PA",
    "rhode island": "RI",
    "south carolina": "SC",
    "south dakota": "SD",
    "tennessee": "TN",
    "texas": "TX",
    "utah": "UT",
    "vermont": "VT",
    "virginia": "VA",
    "washington": "WA",
    "west virginia": "WV",
    "wisconsin": "WI",
    "wyoming": "WY",
}

_COUNTRY_TOKENS = frozenset(
    {
        "united states",
        "usa",
        "us",
        "u.s.",
        "u.s.a.",
        "united kingdom",
        "uk",
        "u.k.",
        "england",
        "scotland",
        "wales",
        "northern ireland",
    }
)


def state_name_to_code(value: str) -> str:
    """Convert a US state name or existing abbreviation to a two-letter code."""
    raw = _normalize_token(value)
    if not raw:
        return ""
    if len(raw) == 2 and raw.isalpha():
        return raw.upper()
    compact = raw.replace(".", "")
    if len(compact) == 2 and compact.isalpha():
        return compact.upper()
    return US_STATE_NAME_TO_CODE.get(raw.lower(), "")


def _normalize_token(value: str) -> str:
    return (value or "").strip().rstrip(".")


def _is_united_states(country: str) -> bool:
    normalized = (country or "").strip().lower()
    return normalized in {"united states", "usa", "us", "u.s.", "u.s.a."}


def _allow_us_state_in_location(country: str) -> bool:
    """Whether a comma-separated location may contain a US state name."""
    normalized = (country or "").strip().lower()
    if not normalized or _is_united_states(country):
        return True
    return False


def _state_from_segment(segment: str) -> str:
    return state_name_to_code(segment)


def parse_ma_location(location: str, country: str = "") -> tuple[str, str]:
    """
    Parse Metal Archives Location text into city and optional US state code.

    MA stores full US state names (e.g. "Atlanta, Georgia"). The state name is
    translated to a two-letter code whenever it is recognized.
    """
    location = (location or "").strip()
    if not location:
        return "", ""

    parts = [_normalize_token(part) for part in location.split(",") if _normalize_token(part)]
    if not parts:
        return "", ""

    if _allow_us_state_in_location(country):
        state_index = -1
        state_code = ""
        for index in range(len(parts) - 1, -1, -1):
            token = parts[index].lower()
            if token in _COUNTRY_TOKENS:
                continue
            code = _state_from_segment(parts[index])
            if code:
                state_code = code
                state_index = index
                break

        if state_code:
            city = ", ".join(parts[:state_index]).strip() if state_index > 0 else ""
            return city, state_code

        if len(parts) == 1:
            code = _state_from_segment(parts[0])
            if code:
                return "", code

    return parts[0], ""


def parse_musicbrainz_location(detail: dict[str, Any]) -> tuple[str, str]:
    """Extract city and US state code from a MusicBrainz artist record."""
    country_code = (detail.get("country") or "").strip().upper()
    begin_area = detail.get("begin-area") or {}
    area = detail.get("area") or {}

    city = (begin_area.get("name") or "").strip()
    state = ""

    area_type = (area.get("type") or "").strip().lower()
    area_name = (area.get("name") or "").strip()

    if country_code == "US":
        if area_type == "subdivision" and area_name:
            state = state_name_to_code(area_name)
        elif not city and area_type in {"city", "municipality", "town"} and area_name:
            city = area_name
    elif not city and area_name and area_type in {"city", "municipality", "town"}:
        city = area_name

    return city, state

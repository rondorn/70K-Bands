"""Map ISO country codes to long names (matches app countries.txt)."""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

_COUNTRIES_FILE = Path(__file__).with_name("countries.txt")

# MusicBrainz uses a few non-ISO codes outside countries.txt.
_MB_COUNTRY_OVERRIDES = {
    "XW": "Worldwide",
    "XU": "Unknown",
}


@lru_cache(maxsize=1)
def _code_to_name() -> dict[str, str]:
    mapping: dict[str, str] = dict(_MB_COUNTRY_OVERRIDES)
    if not _COUNTRIES_FILE.is_file():
        return mapping

    for line in _COUNTRIES_FILE.read_text(encoding="utf-8").splitlines():
        if "," not in line:
            continue
        long_name, code = line.rsplit(",", 1)
        long_name = long_name.strip()
        code = code.strip().upper()
        if long_name and code:
            mapping[code] = long_name
    return mapping


def expand_country_code(code: str) -> str:
    """Return spelled-out country name for a MusicBrainz ISO code (e.g. US -> United States)."""
    raw = (code or "").strip()
    if not raw:
        return ""
    if len(raw) > 3 or " " in raw:
        return raw
    return _code_to_name().get(raw.upper(), raw)

"""File-backed cache for published CSV/JSON network reads."""

from __future__ import annotations

import hashlib
import json
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from data_entry.http_util import fetch_url, normalize_dropbox_url

DEFAULT_TTL_SECONDS = 30 * 60


@dataclass(frozen=True)
class CacheMeta:
    from_cache: bool
    fetched_at: float | None
    age_seconds: int | None

    @property
    def age_label(self) -> str:
        if self.age_seconds is None:
            return "unknown age"
        if self.age_seconds < 45:
            return "just now"
        minutes = self.age_seconds // 60
        if minutes < 60:
            return f"{minutes} min ago"
        hours = minutes // 60
        if hours < 24:
            return f"{hours} hr ago"
        return f"{hours // 24} day(s) ago"


def cache_dir_for(paths: dict[str, str]) -> Path:
    from data_entry.config_store import config_path

    for key in ("lineup_file", "schedule_file", "description_map_file", "notes_directory"):
        raw = (paths.get(key) or "").strip()
        if raw:
            directory = Path(raw).parent / ".cache"
            directory.mkdir(parents=True, exist_ok=True)
            return directory
    directory = config_path().parent / ".cache"
    directory.mkdir(parents=True, exist_ok=True)
    return directory


def _normalized_url(url: str) -> str:
    return normalize_dropbox_url((url or "").strip())


def _cache_file(cache_dir: Path, url: str) -> Path:
    digest = hashlib.md5(_normalized_url(url).encode()).hexdigest()
    return cache_dir / f"url_{digest}.json"


def _read_entry(cache_file: Path) -> dict[str, Any] | None:
    if not cache_file.is_file():
        return None
    try:
        return json.loads(cache_file.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None


def get_cache_meta(url: str, paths: dict[str, str]) -> CacheMeta | None:
    url = _normalized_url(url)
    if not url:
        return None
    entry = _read_entry(_cache_file(cache_dir_for(paths), url))
    if not entry or "fetched_at" not in entry:
        return None
    fetched_at = float(entry["fetched_at"])
    age = max(0, int(time.time() - fetched_at))
    return CacheMeta(from_cache=True, fetched_at=fetched_at, age_seconds=age)


def invalidate_cached_url(url: str, paths: dict[str, str]) -> None:
    url = _normalized_url(url)
    if not url:
        return
    cache_file = _cache_file(cache_dir_for(paths), url)
    if cache_file.is_file():
        cache_file.unlink()


def invalidate_festival_network_cache(paths: dict[str, str]) -> None:
    for key in ("band_list_url", "schedule_url", "description_map_url"):
        invalidate_cached_url(paths.get(key, ""), paths)


def fetch_cached_text(
    url: str,
    paths: dict[str, str],
    *,
    force_refresh: bool = False,
    ttl_seconds: int = DEFAULT_TTL_SECONDS,
) -> tuple[str, CacheMeta]:
    """
    Return text for a published URL, using a TTL file cache when possible.

    Raises on fetch failure when no usable cache entry exists.
    """
    url = _normalized_url(url)
    if not url:
        raise ValueError("URL is required")

    cache_dir = cache_dir_for(paths)
    cache_file = _cache_file(cache_dir, url)
    now = time.time()

    if not force_refresh:
        entry = _read_entry(cache_file)
        if entry and "text" in entry and "fetched_at" in entry:
            fetched_at = float(entry["fetched_at"])
            age = now - fetched_at
            if age <= ttl_seconds:
                return str(entry["text"]), CacheMeta(
                    from_cache=True,
                    fetched_at=fetched_at,
                    age_seconds=max(0, int(age)),
                )

    text = fetch_url(url)
    fetched_at = time.time()
    cache_file.write_text(
        json.dumps({"url": url, "fetched_at": fetched_at, "text": text}),
        encoding="utf-8",
    )
    return text, CacheMeta(from_cache=False, fetched_at=fetched_at, age_seconds=0)


def fetch_cached_text_or_empty(
    url: str,
    paths: dict[str, str],
    *,
    force_refresh: bool = False,
    ttl_seconds: int = DEFAULT_TTL_SECONDS,
) -> tuple[str, CacheMeta | None]:
    url = _normalized_url(url)
    if not url:
        return "", None
    try:
        return fetch_cached_text(
            url, paths, force_refresh=force_refresh, ttl_seconds=ttl_seconds
        )
    except Exception:
        entry = _read_entry(_cache_file(cache_dir_for(paths), url))
        if entry and "text" in entry:
            fetched_at = float(entry.get("fetched_at", 0))
            age = max(0, int(time.time() - fetched_at)) if fetched_at else None
            return str(entry["text"]), CacheMeta(
                from_cache=True, fetched_at=fetched_at or None, age_seconds=age
            )
        return "", None

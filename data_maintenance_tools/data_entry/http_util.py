"""Cross-platform HTTP fetching for pointer and CSV URLs."""

from __future__ import annotations

import shutil
import subprocess
import sys
from urllib.error import URLError
from urllib.parse import unquote, urlparse
from urllib.request import Request, urlopen

USER_AGENT = "FestivalDataEntry/1.0 (+https://github.com/festival-data-entry)"
DEFAULT_TIMEOUT = 45


def normalize_dropbox_url(url: str) -> str:
    """Use Dropbox raw download when a share link has dl=0."""
    url = (url or "").strip()
    if "dl=0" in url:
        return url.replace("dl=0", "raw=1")
    return url


def fetch_url(url: str, timeout_s: float = DEFAULT_TIMEOUT) -> str:
    """Fetch URL text; tries urllib, then curl when available."""
    url = (url or "").strip()
    if not url:
        raise ValueError("URL is required")

    if url.startswith("file://"):
        from pathlib import Path

        parsed = urlparse(url)
        # Windows file URLs look like file:///C:/Users/... — naive [7:] breaks them.
        path_str = unquote(parsed.path or "")
        if len(path_str) >= 3 and path_str[0] == "/" and path_str[2] == ":":
            path_str = path_str[1:]
        path = Path(path_str)
        return path.read_text(encoding="utf-8-sig")

    req = Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urlopen(req, timeout=timeout_s) as resp:
            raw = resp.read()
            for encoding in ("utf-8-sig", "utf-8", "latin-1"):
                try:
                    return raw.decode(encoding)
                except UnicodeDecodeError:
                    continue
            return raw.decode("utf-8", errors="replace")
    except URLError:
        if shutil.which("curl"):
            return _fetch_curl(url, timeout_s)
        raise


def _fetch_curl(url: str, timeout_s: float) -> str:
    cmd = [
        "curl",
        "-fsSL",
        "--max-time",
        str(int(timeout_s)),
        "-A",
        USER_AGENT,
        url,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        raise URLError(f"curl failed: {stderr or result.returncode}")
    return result.stdout or ""

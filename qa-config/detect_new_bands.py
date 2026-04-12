#!/usr/bin/env python3
"""
Detect lineup band names from HTML and compare against a verified CSV list.

Primary target pattern:
    <span class="band-name">Band Name <span class="band-detail">...</span></span>

Behavior:
- Extracts band names from `span.band-name` while ignoring nested `span.band-detail`.
- Compares detected names against verified `bandName` column from CSV.
- Prints "new band detected" candidates (present in HTML, absent in CSV).
- Prints missing bands (present in CSV, absent in HTML) for validation/debugging.

Usage examples:
    python3 qa-config/detect_new_bands.py --url "https://example.com/lineup"
    python3 qa-config/detect_new_bands.py --html-file lineup.html
    python3 qa-config/detect_new_bands.py --url "https://example.com/lineup" \
      --csv "/Users/rdorn/Dropbox/MDF Public FIles/mdf_artistLineup_2026.csv"
"""

from __future__ import annotations

import argparse
import csv
import html
from html.parser import HTMLParser
import re
import sys
import unicodedata
import urllib.request
from pathlib import Path
from typing import Iterable


DEFAULT_CSV = Path("/Users/rdorn/Dropbox/MDF Public FIles/mdf_artistLineup_2026.csv")


def normalize_name(value: str) -> str:
    """Aggressive normalization so minor formatting differences do not break matching."""
    text = html.unescape(value or "").strip()
    text = unicodedata.normalize("NFKD", text)
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    text = text.casefold()
    text = re.sub(r"\s+", " ", text).strip()
    # Remove punctuation and separators for robust key matching (e.g., "T.O.O.H." == "tooh").
    text = re.sub(r"[^a-z0-9]+", "", text)
    return text


def canonical_display(value: str) -> str:
    """Light cleanup for human-readable output."""
    text = html.unescape(value or "")
    text = re.sub(r"\s+", " ", text).strip()
    return text


class BandNameHTMLParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.detected_names: list[str] = []
        self._capture_stack: list[bool] = []
        self._capture_depth = 0
        self._ignore_detail_depth = 0
        self._current_chunks: list[str] = []

    @staticmethod
    def _class_set(attrs: list[tuple[str, str | None]]) -> set[str]:
        classes = ""
        for key, value in attrs:
            if key == "class" and value:
                classes = value
                break
        return set(classes.split())

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        class_names = self._class_set(attrs)
        is_band_name_span = tag == "span" and "band-name" in class_names
        is_band_detail_span = tag == "span" and "band-detail" in class_names

        if is_band_name_span:
            self._capture_stack.append(True)
            self._capture_depth += 1
            if self._capture_depth == 1:
                self._current_chunks = []
            return

        self._capture_stack.append(False)
        if self._capture_depth > 0 and is_band_detail_span:
            self._ignore_detail_depth += 1

    def handle_endtag(self, tag: str) -> None:
        if not self._capture_stack:
            return

        was_capture_tag = self._capture_stack.pop()
        if was_capture_tag:
            if self._capture_depth > 0:
                self._capture_depth -= 1
            if self._capture_depth == 0:
                name = canonical_display(" ".join(self._current_chunks))
                if name:
                    self.detected_names.append(name)
                self._current_chunks = []
            return

        if self._capture_depth > 0 and tag == "span" and self._ignore_detail_depth > 0:
            self._ignore_detail_depth -= 1

    def handle_data(self, data: str) -> None:
        if self._capture_depth > 0 and self._ignore_detail_depth == 0:
            cleaned = canonical_display(data)
            if cleaned:
                self._current_chunks.append(cleaned)


def read_html_from_url(url: str) -> str:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (compatible; lineup-band-checker/1.0)"
        },
    )
    with urllib.request.urlopen(req, timeout=30) as response:
        return response.read().decode("utf-8", errors="replace")


def read_verified_bands(csv_path: Path) -> list[str]:
    if not csv_path.exists():
        raise FileNotFoundError(f"CSV file not found: {csv_path}")

    names: list[str] = []
    with csv_path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        if "bandName" not in (reader.fieldnames or []):
            raise ValueError("CSV is missing required column: bandName")
        for row in reader:
            raw = canonical_display(row.get("bandName", ""))
            if raw:
                names.append(raw)
    return names


def dedupe_preserve_order(values: Iterable[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for value in values:
        key = normalize_name(value)
        if not key or key in seen:
            continue
        seen.add(key)
        out.append(value)
    return out


def compare(detected: list[str], verified: list[str]) -> tuple[list[str], list[str]]:
    detected_by_key = {normalize_name(v): v for v in detected if normalize_name(v)}
    verified_by_key = {normalize_name(v): v for v in verified if normalize_name(v)}

    new_keys = sorted(set(detected_by_key) - set(verified_by_key))
    missing_keys = sorted(set(verified_by_key) - set(detected_by_key))

    new_bands = [detected_by_key[k] for k in new_keys]
    missing_bands = [verified_by_key[k] for k in missing_keys]
    return new_bands, missing_bands


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Detect and compare lineup band names from HTML."
    )
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--url", help="Web page URL containing lineup HTML.")
    source.add_argument("--html-file", type=Path, help="Path to local HTML file.")
    parser.add_argument(
        "--csv",
        type=Path,
        default=DEFAULT_CSV,
        help=f"Verified CSV path (default: {DEFAULT_CSV}).",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit non-zero when lists do not match exactly.",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()

    if args.url:
        html_source = read_html_from_url(args.url)
    else:
        html_path: Path = args.html_file
        if not html_path.exists():
            raise FileNotFoundError(f"HTML file not found: {html_path}")
        html_source = html_path.read_text(encoding="utf-8", errors="replace")

    parser = BandNameHTMLParser()
    parser.feed(html_source)

    detected = dedupe_preserve_order(parser.detected_names)
    verified = dedupe_preserve_order(read_verified_bands(args.csv))
    new_bands, missing_bands = compare(detected, verified)

    print(f"Detected bands from HTML: {len(detected)}")
    print(f"Verified bands from CSV:  {len(verified)}")

    if not new_bands and not missing_bands:
        print("MATCH: detected lineup equals verified lineup.")
        return 0

    if new_bands:
        print("\nNEW BANDS DETECTED (in HTML, not in verified CSV):")
        for name in new_bands:
            print(f"- {name}")

    if missing_bands:
        print("\nMISSING BANDS (in verified CSV, not in HTML):")
        for name in missing_bands:
            print(f"- {name}")

    if args.strict:
        return 2
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise

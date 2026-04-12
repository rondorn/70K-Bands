#!/usr/bin/env python3
"""
Build Google Play release-notes JSON for the default listing language only (en-US).

Matches manual production workflow: a single US English “What’s new” changelog.
No translation APIs.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Dict


def build_notes(english_text: str, locale: str) -> Dict[str, str]:
    return {locale: english_text}


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Write release_notes.json for default_language in apps_config.json only "
            "(typically en-US). No translation API."
        )
    )
    parser.add_argument(
        "text",
        nargs="?",
        help="Release notes in English (omit to read stdin)",
    )
    parser.add_argument(
        "--config",
        type=Path,
        default=Path("apps_config.json"),
        help="Path to apps_config.json",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("release_notes.json"),
        help="Output JSON path",
    )
    args = parser.parse_args()

    text = args.text
    if text is None:
        text = sys.stdin.read()
    text = text.strip()
    if not text:
        print("Error: release notes text is empty", file=sys.stderr)
        sys.exit(1)

    try:
        config = json.loads(args.config.read_text(encoding="utf-8"))
    except FileNotFoundError:
        print(f"Error: config not found: {args.config}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as exc:
        print(f"Error: invalid JSON in {args.config}: {exc}", file=sys.stderr)
        sys.exit(1)

    locale = config.get("default_language") or "en-US"
    out = build_notes(text, locale)
    args.output.write_text(
        json.dumps(out, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {args.output} (locale {locale} only)")


if __name__ == "__main__":
    main()

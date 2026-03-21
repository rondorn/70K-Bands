#!/usr/bin/env python3
"""
Create Dropbox shared links for every file under ~/Dropbox/qa-config (or --dropbox-prefix),
write qa-config/DROPBOX_GENERATED_URLS.md, and optionally rewrite pointer + description-map URLs in the repo.

Setup (one-time):
  1. https://www.dropbox.com/developers/apps → Create app → Scoped access → Full Dropbox
  2. Permissions: files.metadata.read, sharing.write
  3. Generate access token, then:

     export DROPBOX_ACCESS_TOKEN='...'
     python3 -m pip install -r qa-config/scripts/requirements-dropbox.txt
     python3 qa-config/scripts/publish_dropbox_links.py --write-pointers

Assumes synced folder layout: Dropbox/qa-config/...  →  API path /qa-config/...
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from typing import Dict, List

# Dropbox API path to the qa-config folder (under the user's Dropbox root).
DEFAULT_DROPBOX_PREFIX = "/qa-config"
GITHUB_FIXTURE_PREFIX = (
    "https://raw.githubusercontent.com/rondorn/70K-Bands/master/qa-config/fixtures/"
)


def _to_raw_url(url: str) -> str:
    u = url.strip()
    if "?" in u:
        if "raw=1" in u or "dl=1" in u:
            return u
        return u + "&raw=1"
    return u + "?raw=1"


def _list_file_entries_recursive(dbx, prefix: str):
    from dropbox.files import FileMetadata

    result = dbx.files_list_folder(prefix, recursive=True)
    files_list: List[FileMetadata] = []
    while True:
        for entry in result.entries:
            if isinstance(entry, FileMetadata):
                files_list.append(entry)
        if not result.has_more:
            break
        result = dbx.files_list_folder_continue(result.cursor)
    return sorted(files_list, key=lambda e: e.path_display.lower())


def _get_or_create_shared_link(dbx, path_display: str) -> str:
    from dropbox import files
    from dropbox.exceptions import ApiError

    try:
        link = dbx.sharing_create_shared_link_with_settings(
            path_display,
            settings=files.SharedLinkSettings(
                requested_visibility=files.RequestedVisibility.public
            ),
        )
        return link.url
    except ApiError:
        links = dbx.sharing_list_shared_links(path=path_display, direct_only=True)
        if links.links:
            return links.links[0].url
        raise


def collect_urls(
    token: str,
    dropbox_prefix: str,
) -> Dict[str, str]:
    import dropbox

    dbx = dropbox.Dropbox(token)
    entries = _list_file_entries_recursive(dbx, dropbox_prefix)
    rel_to_url: Dict[str, str] = {}
    prefix_norm = dropbox_prefix.rstrip("/")
    for entry in entries:
        display = entry.path_display
        url = _get_or_create_shared_link(dbx, display)
        rel = display[len(prefix_norm) :].lstrip("/")
        rel_to_url[rel] = _to_raw_url(url)
    return rel_to_url


def write_dropbox_urls_md(
    out_path: Path,
    rel_to_url: Dict[str, str],
    dropbox_prefix: str,
) -> None:
    pointers = sorted(k for k in rel_to_url if k.startswith("pointers/"))
    fixtures = sorted(k for k in rel_to_url if k.startswith("fixtures/"))
    docs = sorted(
        k
        for k in rel_to_url
        if k.endswith(".md") and not k.startswith(("pointers/", "fixtures/"))
    )

    lines: List[str] = [
        "# Generated Dropbox URLs for QA config",
        "",
        "Regenerate: **[DROPBOX_URLS.md](./DROPBOX_URLS.md)** (token + `publish_dropbox_links.py`).",
        "",
        f"Generated from Dropbox path `{dropbox_prefix}/`. "
        "Use **raw** links (`raw=1`) for Custom Pointer URL and for CSV/TXT downloads in the app.",
        "",
        "## Custom Pointer URL (per chapter)",
        "",
        "| Chapter / use | Paste this as Custom Pointer URL |",
        "|---------------|-----------------------------------|",
        "| Ch.1 bands only | "
        + rel_to_url.get("pointers/pointer_bands_only.txt", "*(missing file)*")
        + " |",
        "| Ch.2 + pre-parties | "
        + rel_to_url.get("pointers/pointer_bands_and_preparties.txt", "*(missing)*")
        + " |",
        "| Ch.3 March 2026 window | "
        + rel_to_url.get("pointers/pointer_schedule_march_2026_window.txt", "*(missing)*")
        + " |",
        "| Ch.5 QR receiver | "
        + rel_to_url.get("pointers/pointer_qr_partial_receiver.txt", "*(missing)*")
        + " |",
        "| Ch.5 QR donor | "
        + rel_to_url.get("pointers/pointer_qr_donor_full_schedule.txt", "*(missing)*")
        + " |",
        "| Ch.6–7 description notes | "
        + rel_to_url.get("pointers/pointer_description_notes.txt", "*(missing)*")
        + " |",
        "| Ch.8 auto schedule | "
        + rel_to_url.get("pointers/pointer_auto_schedule_wizard.txt", "*(missing)*")
        + " |",
        "| Optional: shows only | "
        + rel_to_url.get("pointers/pointer_schedule_shows_only.txt", "*(missing)*")
        + " |",
        "",
        "## All pointer files",
        "",
    ]
    for p in pointers:
        lines.append(f"- `{p}` → {rel_to_url[p]}")
    lines.extend(["", "## All fixture files", ""])
    for f in fixtures:
        lines.append(f"- `{f}` → {rel_to_url[f]}")
    if docs:
        lines.extend(["", "## Docs (reference only, not for the app)", ""])
        for d in docs:
            lines.append(f"- `{d}` → {rel_to_url[d]}")
    lines.append("")
    out_path.write_text("\n".join(lines), encoding="utf-8")


def patch_pointers_and_fixtures(
    repo_qa_config: Path,
    rel_to_url: Dict[str, str],
) -> None:
    pointers_dir = repo_qa_config / "pointers"
    for path in sorted(pointers_dir.glob("*.txt")):
        text = path.read_text(encoding="utf-8")
        new_text = text
        for rel, url in rel_to_url.items():
            if not rel.startswith("fixtures/"):
                continue
            fname = rel.split("/")[-1]
            old = GITHUB_FIXTURE_PREFIX + fname
            if old in new_text:
                new_text = new_text.replace(old, url)
        if new_text != text:
            path.write_text(new_text, encoding="utf-8")
            print(f"Patched {path.relative_to(repo_qa_config)}")

    desc_map = repo_qa_config / "fixtures" / "qa_description_map_with_notes.csv"
    if desc_map.is_file():
        import csv

        note_rel = "fixtures/notes_qa_alpha.txt"
        if note_rel in rel_to_url:
            rows_out: List[List[str]] = []
            with desc_map.open(newline="", encoding="utf-8") as f:
                reader = csv.reader(f)
                for row in reader:
                    if (
                        len(row) >= 3
                        and row[0].strip() == "QA Alpha Band"
                        and row[0].strip() != "Band"
                    ):
                        rows_out.append([row[0], rel_to_url[note_rel], row[2]])
                    else:
                        rows_out.append(row)
            with desc_map.open("w", newline="", encoding="utf-8") as f:
                csv.writer(f).writerows(rows_out)
            print(f"Patched {desc_map.relative_to(repo_qa_config)}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Publish Dropbox shared links for qa-config.")
    parser.add_argument(
        "--dropbox-prefix",
        default=DEFAULT_DROPBOX_PREFIX,
        help="Dropbox API path to qa-config folder (default: /qa-config)",
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
        help="Repository root containing qa-config/",
    )
    parser.add_argument(
        "--write-pointers",
        action="store_true",
        help="Rewrite qa-config/pointers/*.txt and qa_description_map_with_notes.csv to use Dropbox fixture URLs",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print actions only (still calls Dropbox API to list/create links)",
    )
    args = parser.parse_args()

    token = os.environ.get("DROPBOX_ACCESS_TOKEN", "").strip()
    if not token:
        print(
            "Set DROPBOX_ACCESS_TOKEN (Dropbox app with files.metadata.read + sharing.write).",
            file=sys.stderr,
        )
        sys.exit(1)

    repo_qa = args.repo_root / "qa-config"
    if not repo_qa.is_dir():
        print(f"Missing {repo_qa}", file=sys.stderr)
        sys.exit(1)

    rel_to_url = collect_urls(token, args.dropbox_prefix)
    if not rel_to_url:
        print(f"No files under {args.dropbox_prefix}", file=sys.stderr)
        sys.exit(1)

    out_md = repo_qa / "DROPBOX_GENERATED_URLS.md"
    if args.dry_run:
        print(f"Would write {out_md} ({len(rel_to_url)} files)")
    else:
        write_dropbox_urls_md(out_md, rel_to_url, args.dropbox_prefix)
        print(f"Wrote {out_md}")

    if args.write_pointers and not args.dry_run:
        patch_pointers_and_fixtures(repo_qa, rel_to_url)
    elif args.write_pointers:
        print("Dry-run: skip --write-pointers")

    print("\nNext: commit qa-config/DROPBOX_GENERATED_URLS.md and patched pointers if you use --write-pointers.")


if __name__ == "__main__":
    main()

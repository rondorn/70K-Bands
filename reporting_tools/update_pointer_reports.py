#!/usr/bin/env python3
"""
Publish report HTML Dropbox links into a production pointer file (Current section).

Reads festival config from festivals.json, creates or reuses Dropbox shared links
for generated report files, and updates Current::reportUrl* entries in the
pointer file you specify (or the festival's configured pointer_path).

Uses the Dropbox OAuth token saved by promoter_admin (~/Library/Application Support/
OpenMetalFestAdmin/dropbox_auth.json), with optional overrides via DROPBOX_ACCESS_TOKEN
or dropbox_access_token in festivals.secrets.json.
Dropbox app scopes: files.metadata.read, sharing.write
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

TOOLS_ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS_ROOT))

from reporting.auth import default_secrets_path, load_secrets
from reporting.config import default_config_path, load_festivals
from reporting.dropbox_links import get_dropbox_token, shared_links_for_files
from reporting.naming import with_event_year
from reporting.pointer import parse_pointer_text
from reporting.pointer_editor import list_report_url_keys, merge_current_report_urls


def build_report_file_map(config, event_year: str) -> dict[str, Path]:
    """Map pointer keys (reportUrl, reportUrl-en, …) to local HTML paths."""
    output_dir = config.output_dir
    reports = config.reports_languages
    main_name = with_event_year(config.reports_main, event_year)

    files: dict[str, Path] = {"reportUrl": output_dir / main_name}

    full_name = with_event_year(config.reports_full, event_year)
    files["reportUrlFull"] = output_dir / full_name

    for lang, filename in reports.items():
        year_name = with_event_year(filename, event_year)
        files[f"reportUrl-{lang}"] = output_dir / year_name

    return files


def resolve_pointer_path(config, pointer_arg: Path | None) -> Path:
    if pointer_arg:
        return pointer_arg.expanduser().resolve()
    return config.pointer_path


def update_pointer_reports(
    festival_id: str,
    *,
    pointer_path: Path | None = None,
    section: str = "Current",
    config_path: Path | None = None,
    secrets_path: Path | None = None,
    dry_run: bool = False,
) -> None:
    secrets = load_secrets(secrets_path or default_secrets_path())
    config = load_festivals([festival_id], config_path, secrets_path)[0]
    target_pointer = resolve_pointer_path(config, pointer_path)

    if not target_pointer.exists():
        raise FileNotFoundError(f"Pointer file not found: {target_pointer}")

    pointer_text = target_pointer.read_text(encoding="utf-8")
    sections = parse_pointer_text(pointer_text)
    event_year = (sections.get(section, {}).get("eventYear") or "").strip()
    if not event_year:
        raise RuntimeError(
            f"Could not determine event year from pointer {target_pointer} "
            f"(section {section})"
        )

    report_files = build_report_file_map(config, event_year)
    missing = [k for k, p in report_files.items() if not p.is_file()]
    if missing:
        details = "\n".join(f"  {k}: {report_files[k]}" for k in missing)
        raise FileNotFoundError(
            f"Report HTML not found for {festival_id}. Generate reports first:\n{details}"
        )

    print(f"Festival: {config.name} ({festival_id})")
    print(f"Event year: {event_year}")
    print(f"Pointer file: {target_pointer}")
    print(f"Section: {section}")
    print("Report files:")
    for key, path in sorted(report_files.items()):
        print(f"  {key}: {path.name}")

    token = get_dropbox_token(secrets)
    print("\nCreating/reusing Dropbox shared links...")
    url_by_key = shared_links_for_files(report_files, token)

    before = list_report_url_keys(pointer_text, section=section)
    updated = merge_current_report_urls(pointer_text, url_by_key, section=section)

    print(f"\n{section} reportUrl updates:")
    for key in sorted(url_by_key):
        old = before.get(key, "(new)")
        if old == url_by_key[key]:
            print(f"  {key}: unchanged")
        else:
            print(f"  {key}:")
            print(f"    was: {old}")
            print(f"    now: {url_by_key[key]}")

    if dry_run:
        print("\nDry run — pointer file not written.")
        return

    target_pointer.write_text(updated, encoding="utf-8")
    print(f"\nWrote pointer: {target_pointer}")
    if str(target_pointer).startswith(str(Path.home() / "Dropbox")):
        print("Dropbox desktop sync will upload the updated pointer automatically.")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Publish report Dropbox URLs into a pointer file Current section."
    )
    parser.add_argument(
        "--festivals",
        nargs="+",
        default=["70k"],
        metavar="ID",
        help="Festival id from festivals.json (default: 70k)",
    )
    parser.add_argument(
        "--pointer",
        type=Path,
        default=None,
        help="Pointer file to update (default: festival pointer_path from config)",
    )
    parser.add_argument(
        "--section",
        default="Current",
        help="Pointer section to update (default: Current)",
    )
    parser.add_argument("--config", type=Path, default=None)
    parser.add_argument("--secrets", type=Path, default=None)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show planned changes without writing the pointer file",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        for festival_id in args.festivals:
            update_pointer_reports(
                festival_id,
                pointer_path=args.pointer,
                section=args.section,
                config_path=args.config,
                secrets_path=args.secrets,
                dry_run=args.dry_run,
            )
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

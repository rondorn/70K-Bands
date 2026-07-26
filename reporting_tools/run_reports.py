#!/usr/bin/env python3
"""Generate festival usage and ranking HTML reports."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

TOOLS_ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS_ROOT))

from reporting.auth import (
    auth_status,
    default_secrets_path,
    setup_firebase_secrets,
    setup_google_adc,
)
from reporting.config import default_config_path, list_festival_ids, load_festivals
from reporting.pipeline import run_festival_pipeline


def add_report_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--config",
        type=Path,
        default=None,
        help="Path to festivals.json",
    )
    parser.add_argument(
        "--secrets",
        type=Path,
        default=None,
        help="Path to festivals.secrets.json",
    )
    parser.add_argument(
        "--festivals",
        nargs="+",
        metavar="ID",
        help="Festival ids to run",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Run all configured festivals",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Sync pointer only; skip Firebase and HTML",
    )
    parser.add_argument(
        "--skip-pointer",
        action="store_true",
        help="Skip production pointer and lineup/schedule download",
    )
    parser.add_argument(
        "--skip-firebase",
        action="store_true",
        help="Use existing JSON backup instead of downloading Firebase export",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List configured festival ids and exit",
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Download festival data, organize it, and generate HTML reports."
        )
    )
    subparsers = parser.add_subparsers(dest="command")

    run_parser = subparsers.add_parser(
        "run",
        help="Generate reports (default)",
    )
    add_report_args(run_parser)

    auth_parser = subparsers.add_parser(
        "auth",
        help="Set up credentials for unattended (cron) runs",
    )
    auth_sub = auth_parser.add_subparsers(dest="auth_command", required=True)

    setup = auth_sub.add_parser(
        "setup",
        help="Save Firebase database secrets to festivals.secrets.json",
    )
    setup.add_argument(
        "--festivals",
        nargs="+",
        metavar="ID",
        default=["70k"],
    )
    setup.add_argument("--config", type=Path, default=None)
    setup.add_argument("--secrets", type=Path, default=None)

    auth_sub.add_parser(
        "google",
        help="Run gcloud application-default login (optional Google OAuth ADC)",
    )

    status = auth_sub.add_parser("status", help="Show configured auth state")
    status.add_argument("--config", type=Path, default=None)
    status.add_argument("--secrets", type=Path, default=None)

    return parser


def run_reports(args: argparse.Namespace) -> int:
    config_path = args.config or default_config_path()
    secrets_path = args.secrets or default_secrets_path()

    if args.list:
        for festival_id in list_festival_ids(config_path):
            print(festival_id)
        return 0

    if args.all:
        festival_ids = list_festival_ids(config_path)
    elif args.festivals:
        festival_ids = args.festivals
    else:
        print("ERROR: specify --festivals, --all, or --list", file=sys.stderr)
        return 1

    try:
        configs = load_festivals(festival_ids, config_path, secrets_path)
    except (ValueError, FileNotFoundError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    print(f"Using config:  {config_path}")
    print(f"Using secrets: {secrets_path}")

    for config in configs:
        try:
            run_festival_pipeline(
                config,
                dry_run=args.dry_run,
                skip_pointer=args.skip_pointer,
                skip_firebase=args.skip_firebase,
            )
        except Exception as exc:
            print(f"ERROR running {config.id}: {exc}", file=sys.stderr)
            return 1

    return 0


def run_auth(args: argparse.Namespace) -> int:
    config_path = args.config or default_config_path()
    secrets_path = args.secrets or default_secrets_path()

    if args.auth_command == "setup":
        return setup_firebase_secrets(args.festivals, config_path, secrets_path)
    if args.auth_command == "google":
        return setup_google_adc()
    if args.auth_command == "status":
        return auth_status(config_path, secrets_path)
    print(f"Unknown auth command: {args.auth_command}", file=sys.stderr)
    return 1


def main() -> int:
    argv = sys.argv[1:]
    parser = build_parser()

    # Default subcommand: `run` when first arg is not auth/run
    if not argv or argv[0] not in {"run", "auth"}:
        argv = ["run", *argv]

    args = parser.parse_args(argv)

    if args.command == "auth":
        return run_auth(args)
    return run_reports(args)


if __name__ == "__main__":
    raise SystemExit(main())

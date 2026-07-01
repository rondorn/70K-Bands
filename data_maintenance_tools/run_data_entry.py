#!/usr/bin/env python3
"""
Run the festival-agnostic band and schedule data entry web app.

Configure via http://127.0.0.1:8080/config or festival_data_entry.json in this folder.
"""

from __future__ import annotations

import argparse
import os
import sys
import webbrowser
from pathlib import Path

TOOL_ROOT = Path(__file__).resolve().parent


def _bootstrap_path() -> None:
    os.chdir(TOOL_ROOT)
    os.environ["FESTIVAL_DATA_ENTRY_ROOT"] = str(TOOL_ROOT)
    if str(TOOL_ROOT) not in sys.path:
        sys.path.insert(0, str(TOOL_ROOT))


def main() -> None:
    _bootstrap_path()

    parser = argparse.ArgumentParser(description="Run festival data entry web app.")
    parser.add_argument("--port", type=int, default=8080, help="Port (default: 8080)")
    parser.add_argument(
        "--config",
        type=str,
        default="",
        help="Path to festival_data_entry.json (default: in this folder)",
    )
    parser.add_argument(
        "--open-browser",
        action="store_true",
        help="Open the configuration page in the default browser",
    )
    args = parser.parse_args()

    if args.config:
        os.environ["FESTIVAL_DATA_ENTRY_CONFIG"] = str(
            Path(args.config).expanduser().resolve()
        )

    try:
        from data_entry.config_store import config_path, ensure_data_files, load_config, needs_setup
        from data_entry.port_util import release_port
        from data_entry.app import create_app
    except ImportError as exc:
        print("Missing dependencies.", file=sys.stderr)
        print("", file=sys.stderr)
        print("First-time setup:", file=sys.stderr)
        print("  macOS/Linux:  ./setup.sh   then  ./run.sh", file=sys.stderr)
        print("  Windows:      setup.bat    then  run.bat", file=sys.stderr)
        print("", file=sys.stderr)
        print(f"Details: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc

    cfg = load_config()
    ensure_data_files(cfg)

    host = "127.0.0.1"
    port = args.port
    release_port(port)

    app = create_app()
    setup_path = "/setup" if needs_setup() else "/config"
    url = f"http://{host}:{port}{setup_path}"

    print(f"Serving on http://{host}:{port}")
    print(f"Config file: {config_path()}")
    if needs_setup():
        print("No festival configuration found — open /setup to run the wizard.")
    print("Pages:")
    print(f"  - Configuration:  http://{host}:{port}/config")
    print(f"  - Setup wizard:   http://{host}:{port}/setup")
    print(f"  - Schedule entry: http://{host}:{port}/schedule")
    print(f"  - Add band:       http://{host}:{port}/bands")
    print("")
    print("Press Ctrl+C to stop.")

    if args.open_browser:
        webbrowser.open(url)

    app.run(host=host, port=port, debug=False, use_reloader=False)


if __name__ == "__main__":
    main()

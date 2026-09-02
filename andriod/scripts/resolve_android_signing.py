#!/usr/bin/env python3
"""Resolve upload-keystore path and alias for an Android festival app.

Paths and aliases come from apps_config.json. An app that omits keystore_path /
key_alias uses default_keystore_path / default_key_alias (new apps). .env
ANDROID_KEYSTORE_PATH and ANDROID_KEY_ALIAS are used only if those defaults
are also omitted. Passwords stay in .env.
"""

from __future__ import annotations

import argparse
import json
import os
import sys


def resolve(config: dict, app_name: str, env: dict) -> tuple[str, str]:
    default_path = (
        str(config.get("default_keystore_path") or env.get("ANDROID_KEYSTORE_PATH") or "")
    ).strip()
    default_alias = (
        str(config.get("default_key_alias") or env.get("ANDROID_KEY_ALIAS") or "")
    ).strip()
    app = next((item for item in config.get("apps") or [] if item.get("name") == app_name), None)
    if app is None:
        raise SystemExit(f"Unknown app in apps_config.json: {app_name}")
    path = str(app.get("keystore_path") or default_path).strip()
    alias = str(app.get("key_alias") or default_alias).strip()
    path = os.path.expanduser(path)
    if not path or not alias:
        raise SystemExit(
            f"Missing keystore_path or key_alias for {app_name}. "
            "Set them on the app, or set default_keystore_path / default_key_alias."
        )
    return path, alias


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", default="apps_config.json")
    parser.add_argument("--name", required=True)
    parser.add_argument("--field", choices=["path", "alias", "both"], default="both")
    args = parser.parse_args()
    with open(args.config, encoding="utf-8") as handle:
        config = json.load(handle)
    path, alias = resolve(config, args.name, os.environ)
    if args.field == "path":
        print(path)
    elif args.field == "alias":
        print(alias)
    else:
        print(path)
        print(alias)


if __name__ == "__main__":
    main()

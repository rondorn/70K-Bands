from __future__ import annotations

import getpass
import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

TOOLS_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SECRETS_PATH = TOOLS_ROOT / "festivals.secrets.json"
ADC_PATH = Path.home() / ".config/gcloud/application_default_credentials.json"


def default_secrets_path() -> Path:
    local = TOOLS_ROOT / "festivals.secrets.json"
    if local.exists():
        return local
    return DEFAULT_SECRETS_PATH


def load_secrets(secrets_path: Path | None = None) -> dict[str, Any]:
    path = secrets_path or default_secrets_path()
    if not path.exists():
        return {"festivals": {}}
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def save_secrets(data: dict[str, Any], secrets_path: Path | None = None) -> Path:
    path = secrets_path or default_secrets_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    path.chmod(0o600)
    return path


def firebase_export_url(database_url: str, auth_secret: str, export_name: str) -> str:
    base = database_url.rstrip("/")
    return (
        f"{base}/.json?auth={auth_secret}"
        f"&download={export_name}&format=export&print=pretty"
    )


def resolve_firebase_export_url(
    festival_id: str,
    entry: dict[str, Any],
    secrets: dict[str, Any],
) -> str:
    if entry.get("firebase_export_url"):
        return entry["firebase_export_url"]

    secret_entry = secrets.get("festivals", {}).get(festival_id, {})
    auth_secret = (secret_entry.get("firebase_auth_secret") or "").strip()
    database_url = (entry.get("firebase_database_url") or "").strip()
    export_name = (entry.get("firebase_export_name") or f"{festival_id}-export.json").strip()

    if not database_url:
        raise ValueError(
            f"Festival '{festival_id}' needs firebase_database_url in festivals.json "
            f"or firebase_export_url in festivals.secrets.json"
        )
    if not auth_secret:
        raise ValueError(
            f"Festival '{festival_id}' is missing firebase_auth_secret in "
            f"{default_secrets_path()}. Run: python run_reports.py auth setup"
        )
    return firebase_export_url(database_url, auth_secret, export_name)


def gcloud_available() -> bool:
    return shutil.which("gcloud") is not None


def setup_google_adc() -> int:
    if not gcloud_available():
        print(
            "gcloud CLI not found. Install Google Cloud SDK, then run:\n"
            "  gcloud auth application-default login",
            file=sys.stderr,
        )
        return 1

    print("Opening browser for Google Application Default Credentials login...")
    print(f"Credentials will be stored at: {ADC_PATH}")
    result = subprocess.run(
        ["gcloud", "auth", "application-default", "login"],
        check=False,
    )
    if result.returncode != 0:
        print("Google ADC login failed.", file=sys.stderr)
        return result.returncode

    if ADC_PATH.exists():
        ADC_PATH.chmod(0o600)
        print(f"Saved ADC credentials: {ADC_PATH}")
    return 0


def setup_firebase_secrets(
    festival_ids: list[str],
    config_path: Path,
    secrets_path: Path | None = None,
) -> int:
    from reporting.config import load_raw_config

    raw = load_raw_config(config_path)
    festivals = raw.get("festivals", {})
    secrets = load_secrets(secrets_path)
    secrets.setdefault("festivals", {})

    for festival_id in festival_ids:
        if festival_id not in festivals:
            print(f"Skipping unknown festival '{festival_id}'", file=sys.stderr)
            continue

        entry = festivals[festival_id]
        existing = secrets["festivals"].get(festival_id, {}).get("firebase_auth_secret", "")
        prompt = (
            f"Firebase database secret for {entry.get('name', festival_id)} "
            f"({festival_id})"
        )
        if existing:
            prompt += " [press Enter to keep existing]"
        prompt += ": "

        value = getpass.getpass(prompt).strip()
        if not value and existing:
            print(f"  Keeping existing secret for {festival_id}")
            continue
        if not value:
            print(f"  No secret entered for {festival_id}; skipping.", file=sys.stderr)
            continue

        secrets["festivals"].setdefault(festival_id, {})["firebase_auth_secret"] = value
        print(f"  Saved Firebase secret for {festival_id}")

    out_path = save_secrets(secrets, secrets_path)
    print(f"Wrote secrets: {out_path}")
    return 0


def auth_status(config_path: Path, secrets_path: Path | None = None) -> int:
    from reporting.config import list_festival_ids, load_raw_config

    print("Auth status")
    print(f"  Config:   {config_path}")
    print(f"  Secrets:  {secrets_path or default_secrets_path()}")
    print(f"  Google ADC: {'present' if ADC_PATH.exists() else 'missing'} ({ADC_PATH})")

    raw = load_raw_config(config_path)
    secrets = load_secrets(secrets_path)
    for festival_id in list_festival_ids(config_path):
        entry = raw["festivals"][festival_id]
        has_inline_url = bool(entry.get("firebase_export_url"))
        has_secret = bool(
            secrets.get("festivals", {}).get(festival_id, {}).get("firebase_auth_secret")
        )
        has_db_url = bool(entry.get("firebase_database_url"))
        ok = has_inline_url or (has_secret and has_db_url)
        state = "ok" if ok else "missing firebase auth"
        print(f"  {festival_id}: {state}")
    return 0

from __future__ import annotations

import getpass
import json
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

TOOLS_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SECRETS_PATH = TOOLS_ROOT / "festivals.secrets.json"
ADC_PATH = Path.home() / ".config/gcloud/application_default_credentials.json"

_RTDB_SCOPES = [
    "https://www.googleapis.com/auth/userinfo.email",
    "https://www.googleapis.com/auth/firebase.database",
]

_ADC_LOGIN_SCOPES = ",".join(
    [
        "https://www.googleapis.com/auth/cloud-platform",
        "https://www.googleapis.com/auth/firebase.database",
        "https://www.googleapis.com/auth/userinfo.email",
    ]
)


@dataclass(frozen=True)
class FirebaseExportTarget:
    url: str
    service_account: Path | None = None
    use_adc: bool = False
    project_id: str = ""


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


def expand_secret_path(value: str) -> Path:
    return Path(value).expanduser().resolve()


def firebase_export_url(database_url: str, auth_secret: str, export_name: str) -> str:
    base = database_url.rstrip("/")
    return (
        f"{base}/.json?auth={auth_secret}"
        f"&download={export_name}&format=export&print=pretty"
    )


def firebase_export_url_without_auth(database_url: str, export_name: str) -> str:
    base = database_url.rstrip("/")
    return f"{base}/.json?download={export_name}&format=export&print=pretty"


def project_id_from_database_url(database_url: str) -> str:
    host = (urlparse(database_url).hostname or "").lower()
    if host.endswith(".firebasedatabase.app"):
        first = host.split(".")[0]
    elif host.endswith(".firebaseio.com"):
        first = host[: -len(".firebaseio.com")]
    else:
        return ""
    suffix = "-default-rtdb"
    if first.endswith(suffix):
        return first[: -len(suffix)]
    return first


def resolve_firebase_project_id(festival_id: str, entry: dict[str, Any]) -> str:
    explicit = (entry.get("firebase_project_id") or "").strip()
    if explicit:
        return explicit
    return project_id_from_database_url((entry.get("firebase_database_url") or "").strip())


def resolve_firebase_service_account(
    festival_id: str,
    secrets: dict[str, Any],
) -> Path | None:
    secret_entry = secrets.get("festivals", {}).get(festival_id, {})
    raw = (secret_entry.get("firebase_service_account") or "").strip()
    if not raw:
        return None
    path = expand_secret_path(raw)
    if not path.is_file():
        raise FileNotFoundError(
            f"Festival '{festival_id}' firebase_service_account not found: {path}"
        )
    return path


def resolve_firebase_export(
    festival_id: str,
    entry: dict[str, Any],
    secrets: dict[str, Any],
) -> FirebaseExportTarget:
    if entry.get("firebase_export_url"):
        return FirebaseExportTarget(url=entry["firebase_export_url"])

    secret_entry = secrets.get("festivals", {}).get(festival_id, {})
    auth_secret = (secret_entry.get("firebase_auth_secret") or "").strip()
    database_url = (entry.get("firebase_database_url") or "").strip()
    export_name = (entry.get("firebase_export_name") or f"{festival_id}-export.json").strip()
    service_account = resolve_firebase_service_account(festival_id, secrets)
    project_id = resolve_firebase_project_id(festival_id, entry)

    if not database_url:
        raise ValueError(
            f"Festival '{festival_id}' needs firebase_database_url in festivals.json "
            f"or firebase_export_url in festivals.secrets.json"
        )
    unauth_url = firebase_export_url_without_auth(database_url, export_name)
    if service_account is not None:
        return FirebaseExportTarget(
            url=unauth_url,
            service_account=service_account,
            project_id=project_id,
        )
    if ADC_PATH.exists():
        return FirebaseExportTarget(
            url=unauth_url,
            use_adc=True,
            project_id=project_id,
        )
    if not auth_secret:
        raise ValueError(
            f"Festival '{festival_id}' has no Google ADC at {ADC_PATH} and no "
            f"firebase_auth_secret / firebase_service_account in "
            f"{default_secrets_path()}. Run: python run_reports.py auth google"
        )
    return FirebaseExportTarget(
        url=firebase_export_url(database_url, auth_secret, export_name),
        project_id=project_id,
    )


def resolve_firebase_export_url(
    festival_id: str,
    entry: dict[str, Any],
    secrets: dict[str, Any],
) -> str:
    return resolve_firebase_export(festival_id, entry, secrets).url


def service_account_access_token(credentials_file: Path) -> str:
    try:
        from google.auth.transport.requests import Request
        from google.oauth2 import service_account
    except ImportError as exc:
        raise RuntimeError(
            "google-auth is required for firebase_service_account. "
            "Install with: pip install -r reporting_tools/requirements.txt"
        ) from exc

    credentials = service_account.Credentials.from_service_account_file(
        str(credentials_file),
        scopes=_RTDB_SCOPES,
    )
    credentials.refresh(Request())
    token = credentials.token
    if not token:
        raise RuntimeError(
            f"Service account {credentials_file} did not produce an access token"
        )
    return token


def adc_access_token(project_id: str | None = None) -> str:
    try:
        import google.auth
        from google.auth.transport.requests import Request
    except ImportError as exc:
        raise RuntimeError(
            "google-auth is required for Google ADC. "
            "Install with: pip install -r reporting_tools/requirements.txt"
        ) from exc

    kwargs: dict[str, Any] = {"scopes": list(_RTDB_SCOPES)}
    if project_id:
        kwargs["quota_project_id"] = project_id
    try:
        credentials, _ = google.auth.default(**kwargs)
    except Exception as exc:
        raise RuntimeError(
            f"Google ADC is missing or unusable ({ADC_PATH}). "
            "Run: python run_reports.py auth google"
        ) from exc
    credentials.refresh(Request())
    token = getattr(credentials, "token", None)
    if not token:
        raise RuntimeError(
            f"Google ADC at {ADC_PATH} did not produce an access token. "
            "Run: python run_reports.py auth google"
        )
    return token


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
    print("This login is used for all festival Firebase report downloads.")
    print(f"Credentials will be stored at: {ADC_PATH}")
    result = subprocess.run(
        [
            "gcloud",
            "auth",
            "application-default",
            "login",
            f"--scopes={_ADC_LOGIN_SCOPES}",
        ],
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
    service_account: Path | None = None,
) -> int:
    from reporting.config import load_raw_config

    raw = load_raw_config(config_path)
    festivals = raw.get("festivals", {})
    secrets = load_secrets(secrets_path)
    secrets.setdefault("festivals", {})

    if service_account is not None:
        if len(festival_ids) != 1:
            print(
                "ERROR: --service-account requires exactly one --festivals id",
                file=sys.stderr,
            )
            return 1
        path = service_account.expanduser().resolve()
        if not path.is_file():
            print(f"ERROR: service account file not found: {path}", file=sys.stderr)
            return 1
        festival_id = festival_ids[0]
        if festival_id not in festivals:
            print(f"Skipping unknown festival '{festival_id}'", file=sys.stderr)
            return 1
        stored = str(service_account).replace("\\", "/")
        secrets["festivals"].setdefault(festival_id, {})["firebase_service_account"] = stored
        print(f"  Saved Firebase service account for {festival_id}: {stored}")
        out_path = save_secrets(secrets, secrets_path)
        print(f"Wrote secrets: {out_path}")
        return 0

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
        secret_entry = secrets.get("festivals", {}).get(festival_id, {})
        has_inline_url = bool(entry.get("firebase_export_url"))
        has_secret = bool(secret_entry.get("firebase_auth_secret"))
        sa_raw = (secret_entry.get("firebase_service_account") or "").strip()
        sa_path = expand_secret_path(sa_raw) if sa_raw else None
        has_service_account = bool(sa_path and sa_path.is_file())
        has_db_url = bool(entry.get("firebase_database_url"))
        has_adc = ADC_PATH.exists()
        if has_service_account and has_db_url:
            state = f"ok (service account {sa_path})"
        elif has_adc and has_db_url:
            project_id = resolve_firebase_project_id(festival_id, entry)
            extra = f", project {project_id}" if project_id else ""
            state = f"ok (google ADC{extra})"
        elif has_secret and has_db_url:
            state = "ok (database secret)"
        elif has_inline_url:
            state = "ok (inline export url)"
        elif sa_raw:
            state = f"missing service account file ({sa_path})"
        else:
            state = f"missing firebase auth (run: python run_reports.py auth google)"
        print(f"  {festival_id}: {state}")
    return 0

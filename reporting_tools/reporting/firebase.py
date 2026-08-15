from __future__ import annotations

import json
from urllib.error import HTTPError
from urllib.parse import parse_qsl, urlencode, urlparse, urlunparse
from urllib.request import Request, urlopen

from reporting.auth import ADC_PATH, adc_access_token, service_account_access_token
from reporting.models import FestivalConfig

_USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36"
)


def _with_query(url: str, **params: str) -> str:
    parts = urlparse(url)
    query = dict(parse_qsl(parts.query, keep_blank_values=True))
    query.update(params)
    return urlunparse(parts._replace(query=urlencode(query)))


def _auth_label(config: FestivalConfig) -> str:
    if config.firebase_service_account:
        return f"service account {config.firebase_service_account}"
    if config.firebase_use_adc:
        return f"Google ADC ({ADC_PATH})"
    return "database secret"


def download_firebase_json(config: FestivalConfig) -> dict:
    print(f"Downloading Firebase export for {config.name}...")
    print(f"  auth: {_auth_label(config)}")
    url = config.firebase_export_url
    if config.firebase_service_account:
        token = service_account_access_token(config.firebase_service_account)
        url = _with_query(url, access_token=token)
    elif config.firebase_use_adc:
        token = adc_access_token(config.firebase_project_id or None)
        url = _with_query(url, access_token=token)

    req = Request(url, headers={"User-Agent": _USER_AGENT})
    try:
        with urlopen(req, timeout=120) as resp:
            raw = resp.read().decode("utf-8")
    except HTTPError as exc:
        if exc.code == 401:
            hint = (
                "Re-run: python run_reports.py auth google "
                "(your Google account must have access to this Firebase project)."
                if config.firebase_use_adc
                else "Check firebase_auth_secret or firebase_service_account in "
                "festivals.secrets.json"
            )
            raise RuntimeError(
                f"Firebase export unauthorized for {config.name} using "
                f"{_auth_label(config)}. {hint}"
            ) from exc
        raise

    data = json.loads(raw)

    config.json_backup_path.parent.mkdir(parents=True, exist_ok=True)
    config.json_backup_path.write_text(
        json.dumps(data, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    print(f"Saved JSON backup: {config.json_backup_path}")
    return data

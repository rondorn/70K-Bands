from __future__ import annotations

import json
from urllib.request import Request, urlopen

from reporting.models import FestivalConfig


def download_firebase_json(config: FestivalConfig) -> dict:
    print(f"Downloading Firebase export for {config.name}...")
    req = Request(
        config.firebase_export_url,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36"
            )
        },
    )
    with urlopen(req, timeout=120) as resp:
        raw = resp.read().decode("utf-8")

    data = json.loads(raw)

    config.json_backup_path.parent.mkdir(parents=True, exist_ok=True)
    config.json_backup_path.write_text(
        json.dumps(data, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    print(f"Saved JSON backup: {config.json_backup_path}")
    return data

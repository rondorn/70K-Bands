from __future__ import annotations

import csv
from pathlib import Path

from reporting.models import FestivalDataset

USER_HEADERS = [
    "numBandsRanked",
    "numShowsMarked",
    "country",
    "language",
    "last launch",
    "platform",
    "userid",
    "osVersion",
    "70kVersion",
    "activeProfiles",
]

RANKING_HEADERS = ["bandName", "ranking", "unuiqueID", "userID", "year"]

EVENT_HEADERS = [
    "bandName",
    "eventType",
    "location",
    "startTimeHour",
    "startTimeMin",
    "status",
    "unuiqueID",
    "userID",
    "year",
]


def _write_csv(path: Path, headers: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=headers, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def materialize_dataset_csvs(dataset: FestivalDataset) -> None:
    """Write organized in-memory data to CSV paths expected by the HTML generator."""
    config = dataset.config

    _write_csv(
        config.user_data_csv,
        USER_HEADERS,
        [user.to_csv_row() for user in dataset.users],
    )
    _write_csv(
        config.ranking_data_csv,
        RANKING_HEADERS,
        [row.to_csv_row() for row in dataset.rankings],
    )
    _write_csv(
        config.event_data_csv,
        EVENT_HEADERS,
        [row.to_csv_row() for row in dataset.events],
    )

    print(f"Wrote processed CSVs:")
    print(f"  {config.user_data_csv}")
    print(f"  {config.ranking_data_csv}")
    print(f"  {config.event_data_csv}")

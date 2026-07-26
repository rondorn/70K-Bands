from __future__ import annotations

import os
import sys
from pathlib import Path

from reporting.firebase import download_firebase_json
from reporting.models import FestivalConfig, FestivalDataset
from reporting.config import apply_event_year_to_reports
from reporting.pointer import load_pointer_from_disk, sync_pointer
from reporting.processor import process_firebase_data
from reporting.usage import update_usage_history
from reporting.workdir import materialize_dataset_csvs


def generate_html_reports(dataset: FestivalDataset) -> None:
    config = dataset.config
    tools_root = Path(__file__).resolve().parent.parent
    if str(tools_root) not in sys.path:
        sys.path.insert(0, str(tools_root))

    from reporting.reports import html_reports

    html_reports.set_festival_context(config)
    previous_cwd = Path.cwd()
    os.chdir(config.output_dir)
    try:
        html_reports.main(
            output_file=config.reports_main,
            source=config.id,
            min_votes=config.min_votes,
        )
        html_reports.main_full(source=config.id)
    finally:
        os.chdir(previous_cwd)


def run_festival_pipeline(
    config: FestivalConfig,
    *,
    dry_run: bool = False,
    skip_pointer: bool = False,
    skip_firebase: bool = False,
) -> FestivalDataset:
    print(f"\n{'=' * 60}")
    print(f"Running report pipeline: {config.name} ({config.id})")
    print(f"{'=' * 60}\n")

    if not skip_pointer:
        sync_pointer(config, dry_run=dry_run)
    else:
        load_pointer_from_disk(config)

    if not config.event_year:
        raise RuntimeError(
            f"Event year missing for {config.id}. "
            f"Check Current::eventYear in {config.pointer_path}"
        )
    apply_event_year_to_reports(config)
    if dry_run:
        print("Dry run complete — skipping Firebase download and report generation.")
        return FestivalDataset(config=config, firebase_json={})

    if skip_firebase and config.json_backup_path.exists():
        import json

        firebase_json = json.loads(config.json_backup_path.read_text(encoding="utf-8"))
        print(f"Using existing JSON backup: {config.json_backup_path}")
    else:
        firebase_json = download_firebase_json(config)

    dataset = process_firebase_data(config, firebase_json)
    materialize_dataset_csvs(dataset)
    update_usage_history(config, dataset.users)
    generate_html_reports(dataset)

    print(f"\nReports written to {config.output_dir}")
    print(f"  {config.reports_main}")
    print(f"  {config.reports_full}")
    return dataset

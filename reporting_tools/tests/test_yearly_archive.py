#!/usr/bin/env python3
from __future__ import annotations

import sys
import tempfile
import unittest
from datetime import datetime
from pathlib import Path

TOOLS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_ROOT))

from reporting.usage import (
    YEARLY_ROLLING_ACTIVE_DAYS,
    get_year_over_year_data,
    highest_rolling_active_for_month,
    load_app_data_archive,
    parse_archive_month,
    update_yearly_archive_from_launches,
    update_yearly_archives,
    write_app_data_archive,
    yearly_app_data_path,
)


class YearlyArchiveTests(unittest.TestCase):
    def test_parse_archive_month(self) -> None:
        self.assertEqual(parse_archive_month("January"), 1)
        self.assertEqual(parse_archive_month("Sep"), 9)
        self.assertEqual(parse_archive_month("10"), 10)
        self.assertEqual(parse_archive_month("2026-03"), 3)
        self.assertIsNone(parse_archive_month(""))
        self.assertIsNone(parse_archive_month("not-a-month"))

    def test_writes_year_folder_and_keeps_high_water_mark(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            output_dir = Path(tmp)
            update_yearly_archives(
                output_dir,
                {
                    "2025-12": {"max_users": 80},
                    "2026-01": {"max_users": 100},
                    "2026-02": {"max_users": 120},
                },
            )
            path_2026 = yearly_app_data_path(output_dir, 2026)
            self.assertTrue(path_2026.exists())
            self.assertEqual(path_2026.name, "2026_App_Data.csv")
            self.assertEqual(
                path_2026.read_text(encoding="utf-8").splitlines()[0],
                "Month,Highest Monthly Count",
            )
            self.assertEqual(load_app_data_archive(path_2026), {1: 100, 2: 120})

            update_yearly_archives(
                output_dir,
                {
                    "2026-01": {"max_users": 90},
                    "2026-02": {"max_users": 150},
                },
            )
            self.assertEqual(load_app_data_archive(path_2026), {1: 100, 2: 150})

    def test_year_over_year_table(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            output_dir = Path(tmp)
            write_app_data_archive(
                yearly_app_data_path(output_dir, 2025),
                {1: 100, 2: 200},
            )
            write_app_data_archive(
                yearly_app_data_path(output_dir, 2026),
                {1: 125, 2: 180},
            )
            headers, rows = get_year_over_year_data(output_dir)
            self.assertEqual(headers, ["Month", "2025", "2026", "YoY Change"])
            self.assertEqual(rows[0], ["January", "100", "125", "+25.0%"])
            self.assertEqual(rows[1], ["February", "200", "180", "-10.0%"])

    def test_highest_monthly_is_peak_trailing_window(self) -> None:
        # 97 users last launched Dec 10: in the 40-day window on Jan 12, gone by Jan 31.
        # 815 users last launched Jan 10: in the window on both Jan 12 and Jan 31.
        launches = [datetime(2025, 12, 10, 12, 0, 0)] * 97 + [
            datetime(2026, 1, 10, 12, 0, 0)
        ] * 815
        now = datetime(2026, 1, 31, 18, 0, 0)
        self.assertEqual(
            highest_rolling_active_for_month(
                launches, 2026, 1, YEARLY_ROLLING_ACTIVE_DAYS, now
            ),
            912,
        )

    def test_archive_stores_trailing_window_peak_not_same_day_total(self) -> None:
        launches = [datetime(2025, 12, 10, 12, 0, 0)] * 97 + [
            datetime(2026, 1, 10, 12, 0, 0)
        ] * 815
        now = datetime(2026, 1, 31, 18, 0, 0)
        with tempfile.TemporaryDirectory() as tmp:
            output_dir = Path(tmp)
            update_yearly_archive_from_launches(output_dir, launches, now=now)
            self.assertEqual(
                load_app_data_archive(yearly_app_data_path(output_dir, 2026)),
                {1: 912},
            )


if __name__ == "__main__":
    unittest.main()

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
    get_year_over_year_data,
    load_app_data_archive,
    parse_archive_month,
    update_yearly_archive_from_launches,
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

    def test_keeps_other_months_and_replaces_current_month_if_today_is_higher(self) -> None:
        now = datetime(2026, 1, 31, 18, 0, 0)
        launches = [datetime(2026, 1, 10, 12, 0, 0)] * 912
        with tempfile.TemporaryDirectory() as tmp:
            output_dir = Path(tmp)
            write_app_data_archive(
                yearly_app_data_path(output_dir, 2026),
                {1: 800, 2: 400},
            )
            update_yearly_archive_from_launches(output_dir, launches, now=now)
            self.assertEqual(
                load_app_data_archive(yearly_app_data_path(output_dir, 2026)),
                {1: 912, 2: 400},
            )

    def test_keeps_stored_current_month_if_today_is_smaller(self) -> None:
        now = datetime(2026, 1, 31, 18, 0, 0)
        launches = [datetime(2026, 1, 20, 12, 0, 0)] * 815
        with tempfile.TemporaryDirectory() as tmp:
            output_dir = Path(tmp)
            write_app_data_archive(
                yearly_app_data_path(output_dir, 2026),
                {1: 912, 3: 500},
            )
            update_yearly_archive_from_launches(output_dir, launches, now=now)
            self.assertEqual(
                load_app_data_archive(yearly_app_data_path(output_dir, 2026)),
                {1: 912, 3: 500},
            )

    def test_does_not_write_other_years(self) -> None:
        now = datetime(2026, 1, 15, 12, 0, 0)
        launches = [datetime(2026, 1, 10, 12, 0, 0)] * 100
        with tempfile.TemporaryDirectory() as tmp:
            output_dir = Path(tmp)
            write_app_data_archive(
                yearly_app_data_path(output_dir, 2025),
                {1: 700},
            )
            update_yearly_archive_from_launches(output_dir, launches, now=now)
            self.assertEqual(
                load_app_data_archive(yearly_app_data_path(output_dir, 2025)),
                {1: 700},
            )
            self.assertEqual(
                load_app_data_archive(yearly_app_data_path(output_dir, 2026)),
                {1: 100},
            )


if __name__ == "__main__":
    unittest.main()

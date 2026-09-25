#!/usr/bin/env python3
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

TOOLS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_ROOT))

from reporting.usage import (
    get_year_over_year_data,
    load_app_data_archive,
    parse_archive_month,
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


if __name__ == "__main__":
    unittest.main()

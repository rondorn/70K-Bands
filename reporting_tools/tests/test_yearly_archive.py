#!/usr/bin/env python3
from __future__ import annotations

import sys
import tempfile
import unittest
from datetime import datetime
from pathlib import Path

TOOLS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_ROOT))

from reporting.models import UserRecord
from reporting.usage import (
    count_active_users_for_report,
    get_year_over_year_data,
    load_app_data_archive,
    parse_archive_month,
    update_current_month_archive,
    update_yearly_archive_from_users,
    write_app_data_archive,
    yearly_app_data_path,
)


def _user(last_launch: str, userid: str, platform: str = "iOS") -> UserRecord:
    return UserRecord(
        num_bands_ranked=0,
        num_shows_marked=0,
        country="",
        language="",
        last_launch=last_launch,
        platform=platform,
        userid=userid,
        os_version="",
        app_version="",
        active_profiles="",
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
        with tempfile.TemporaryDirectory() as tmp:
            output_dir = Path(tmp)
            write_app_data_archive(
                yearly_app_data_path(output_dir, 2026),
                {1: 800, 2: 400},
            )
            update_current_month_archive(output_dir, 912, now)
            self.assertEqual(
                load_app_data_archive(yearly_app_data_path(output_dir, 2026)),
                {1: 912, 2: 400},
            )

    def test_keeps_stored_current_month_if_today_is_smaller(self) -> None:
        now = datetime(2026, 1, 31, 18, 0, 0)
        with tempfile.TemporaryDirectory() as tmp:
            output_dir = Path(tmp)
            write_app_data_archive(
                yearly_app_data_path(output_dir, 2026),
                {1: 912, 3: 500},
            )
            update_current_month_archive(output_dir, 815, now)
            self.assertEqual(
                load_app_data_archive(yearly_app_data_path(output_dir, 2026)),
                {1: 912, 3: 500},
            )

    def test_counts_utc_last_launch_after_local_now_like_platforms_tab(self) -> None:
        # lastLaunch is stored in UTC. 19:36 UTC is 12:36 PDT; a naive <= now
        # check would drop these users even though Platforms still counts them.
        now = datetime(2026, 9, 25, 12, 36, 0)
        users = [
            _user("2026-09-25 19:36:00", "utc-today"),
            _user("2026-09-20 08:00:00", "recent"),
            _user("2026-08-01 08:00:00", "too-old"),
        ]
        self.assertEqual(count_active_users_for_report(users, window_days=30, now=now), 2)

    def test_archive_uses_platforms_total_including_utc_afternoon_users(self) -> None:
        now = datetime(2026, 9, 25, 12, 36, 0)
        users = [_user("2026-09-25 19:36:00", f"user-{i}") for i in range(921)]
        with tempfile.TemporaryDirectory() as tmp:
            output_dir = Path(tmp)
            write_app_data_archive(
                yearly_app_data_path(output_dir, 2026),
                {9: 859},
            )
            update_yearly_archive_from_users(output_dir, users, now=now)
            self.assertEqual(
                load_app_data_archive(yearly_app_data_path(output_dir, 2026)),
                {9: 921},
            )


if __name__ == "__main__":
    unittest.main()

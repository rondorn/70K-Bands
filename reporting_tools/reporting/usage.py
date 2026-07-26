from __future__ import annotations

import csv
import json
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Tuple

from reporting.models import FestivalConfig, UserRecord

MAX_HISTORY_DAYS = 90
DISPLAY_DAYS = 30
MAX_HISTORY_MONTHS = 12
DISPLAY_MONTHS = 12


class DailyUsageTracker:
    def __init__(self, config: FestivalConfig, users: list[UserRecord] | None = None):
        self.config = config
        self.users = users or []
        self.history_file = config.daily_history_path
        self.history_data = self._load_history()

    def _load_history(self) -> Dict[str, int]:
        if self.history_file.exists():
            try:
                with self.history_file.open(encoding="utf-8") as handle:
                    return json.load(handle)
            except (json.JSONDecodeError, OSError) as exc:
                print(f"Warning: Could not load daily history: {exc}")
        return {}

    def _save_history(self) -> None:
        self.history_file.parent.mkdir(parents=True, exist_ok=True)
        with self.history_file.open("w", encoding="utf-8") as handle:
            json.dump(self.history_data, handle, indent=2)

    def _get_active_users_for_date(self, target_date: datetime) -> int:
        if not self.users:
            return self._get_active_users_for_date_from_csv(target_date)

        start = target_date.replace(hour=0, minute=0, second=0, microsecond=0)
        end = target_date.replace(hour=23, minute=59, second=59, microsecond=999999)
        count = 0
        for user in self.users:
            try:
                last_launch = datetime.strptime(user.last_launch, "%Y-%m-%d %H:%M:%S")
            except ValueError:
                continue
            if start <= last_launch <= end:
                count += 1
        return count

    def _get_active_users_for_date_from_csv(self, target_date: datetime) -> int:
        path = self.config.user_data_csv
        if not path.exists():
            return 0

        start = target_date.replace(hour=0, minute=0, second=0, microsecond=0)
        end = target_date.replace(hour=23, minute=59, second=59, microsecond=999999)
        count = 0
        with path.open(encoding="utf-8") as handle:
            reader = csv.DictReader(handle)
            reader.fieldnames = [fn.strip() for fn in reader.fieldnames or []]
            for row in reader:
                row = {k.strip(): v for k, v in row.items()}
                last_launch_str = row.get("last launch", "").strip()
                if not last_launch_str:
                    continue
                try:
                    last_launch = datetime.strptime(last_launch_str, "%Y-%m-%d %H:%M:%S")
                except ValueError:
                    continue
                if start <= last_launch <= end:
                    count += 1
        return count

    def update_daily_usage(self, target_date: datetime | None = None) -> None:
        if target_date is None:
            target_date = datetime.now() - timedelta(days=1)

        target_date_str = target_date.strftime("%Y-%m-%d")
        current_active = self._get_active_users_for_date(target_date)
        existing = self.history_data.get(target_date_str, 0)

        if current_active > existing:
            self.history_data[target_date_str] = current_active
            print(
                f"Updated daily usage for {target_date_str}: "
                f"{existing} -> {current_active}"
            )
        else:
            print(
                f"No daily update for {target_date_str}: "
                f"current={current_active}, existing={existing}"
            )

        self._clean_old_history()
        self._save_history()

    def ensure_recent_days(self, days_back: int = 7) -> None:
        today = datetime.now()
        for offset in range(days_back):
            target = today - timedelta(days=offset)
            key = target.strftime("%Y-%m-%d")
            if key not in self.history_data:
                self.history_data[key] = self._get_active_users_for_date(target)
        self._clean_old_history()
        self._save_history()

    def _clean_old_history(self) -> None:
        cutoff = (datetime.now() - timedelta(days=MAX_HISTORY_DAYS)).strftime("%Y-%m-%d")
        for key in [k for k in self.history_data if k < cutoff]:
            del self.history_data[key]

    def get_daily_usage_data(self) -> Tuple[List[str], List[List[str]]]:
        headers = ["Date", "Active Users"]
        sorted_dates = sorted(self.history_data.keys(), reverse=True)[:DISPLAY_DAYS]
        rows: list[list[str]] = []
        for date_str in sorted_dates:
            try:
                formatted = datetime.strptime(date_str, "%Y-%m-%d").strftime("%b %d")
            except ValueError:
                formatted = date_str
            rows.append([formatted, str(self.history_data[date_str])])
        return headers, rows

    def get_current_day_usage(self) -> int:
        return self._get_active_users_for_date(datetime.now())


class MonthlyUsageTracker:
    def __init__(self, config: FestivalConfig, users: list[UserRecord] | None = None):
        self.config = config
        self.users = users or []
        self.history_file = config.monthly_history_path
        self.history_data = self._load_history()

    def _load_history(self) -> Dict[str, Dict]:
        if self.history_file.exists():
            try:
                with self.history_file.open(encoding="utf-8") as handle:
                    return json.load(handle)
            except (json.JSONDecodeError, OSError) as exc:
                print(f"Warning: Could not load monthly history: {exc}")
        return {}

    def _save_history(self) -> None:
        self.history_file.parent.mkdir(parents=True, exist_ok=True)
        with self.history_file.open("w", encoding="utf-8") as handle:
            json.dump(self.history_data, handle, indent=2)

    def _platform_counts_for_date(self, target_date: datetime) -> tuple[int, dict[str, int]]:
        start = target_date.replace(hour=0, minute=0, second=0, microsecond=0)
        end = target_date.replace(hour=23, minute=59, second=59, microsecond=999999)
        platforms = {"iOS": 0, "Android": 0}
        total = 0

        source_users = self.users
        if not source_users and self.config.user_data_csv.exists():
            source_users = []
            with self.config.user_data_csv.open(encoding="utf-8") as handle:
                reader = csv.DictReader(handle)
                reader.fieldnames = [fn.strip() for fn in reader.fieldnames or []]
                for row in reader:
                    source_users.append(
                        UserRecord(
                            num_bands_ranked=0,
                            num_shows_marked=0,
                            country=row.get("country", ""),
                            language=row.get("language", ""),
                            last_launch=row.get("last launch", ""),
                            platform=row.get("platform", ""),
                            userid=row.get("userid", ""),
                            os_version=row.get("osVersion", ""),
                            app_version=row.get("70kVersion", ""),
                            active_profiles=row.get("activeProfiles", ""),
                        )
                    )

        for user in source_users:
            try:
                last_launch = datetime.strptime(user.last_launch, "%Y-%m-%d %H:%M:%S")
            except ValueError:
                continue
            if start <= last_launch <= end:
                total += 1
                platform = user.platform.strip()
                if platform in platforms:
                    platforms[platform] += 1
        return total, platforms

    def update_monthly_usage(self) -> None:
        month_key = datetime.now().strftime("%Y-%m")
        max_users = 0
        max_platforms = {"iOS": 0, "Android": 0}

        for offset in range(31):
            target = datetime.now() - timedelta(days=offset)
            if target.strftime("%Y-%m") != month_key:
                continue
            active, platforms = self._platform_counts_for_date(target)
            if active > max_users:
                max_users = active
                max_platforms = platforms

        existing = self.history_data.get(month_key, {})
        existing_max = existing.get("max_users", 0)
        if max_users >= existing_max:
            self.history_data[month_key] = {
                "max_users": max_users,
                "ios": max_platforms.get("iOS", 0),
                "android": max_platforms.get("Android", 0),
            }
            print(f"Updated monthly usage for {month_key}: max_users={max_users}")

        self._clean_old_history()
        self._save_history()

    def _clean_old_history(self) -> None:
        sorted_keys = sorted(self.history_data.keys(), reverse=True)
        for key in sorted_keys[MAX_HISTORY_MONTHS:]:
            del self.history_data[key]

    def get_monthly_usage_data(self) -> Tuple[List[str], List[List[str]]]:
        headers = ["Month", "iOS %", "Android %", "Total Users"]
        rows: list[list[str]] = []
        for month_key in sorted(self.history_data.keys(), reverse=True)[:DISPLAY_MONTHS]:
            entry = self.history_data[month_key]
            total = entry.get("max_users", 0)
            ios = entry.get("ios", 0)
            android = entry.get("android", 0)
            ios_pct = (ios / total * 100) if total else 0
            android_pct = (android / total * 100) if total else 0
            try:
                month_label = datetime.strptime(month_key, "%Y-%m").strftime("%b %Y")
            except ValueError:
                month_label = month_key
            rows.append(
                [
                    month_label,
                    f"{ios_pct:.1f}%",
                    f"{android_pct:.1f}%",
                    str(total),
                ]
            )
        return headers, rows


def update_usage_history(config: FestivalConfig, users: list[UserRecord]) -> None:
    print(f"Updating usage history for {config.name}...")
    daily = DailyUsageTracker(config, users)
    daily.ensure_recent_days(days_back=7)
    daily.update_daily_usage()

    monthly = MonthlyUsageTracker(config, users)
    monthly.update_monthly_usage()

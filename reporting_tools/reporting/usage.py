from __future__ import annotations

import calendar
import csv
import json
import re
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Dict, List, Tuple

from reporting.models import FestivalConfig, UserRecord

MAX_HISTORY_DAYS = 90
DISPLAY_DAYS = 30
MAX_HISTORY_MONTHS = 12
DISPLAY_MONTHS = 12
YEARLY_ROLLING_ACTIVE_DAYS = 40

APP_DATA_ARCHIVE_HEADERS = ["Month", "Highest Monthly Count"]
MONTH_NAMES = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
]
_MONTH_NAME_TO_NUM = {name.lower(): index for index, name in enumerate(MONTH_NAMES, start=1)}
_MONTH_ABBR_TO_NUM = {
    datetime(2000, month, 1).strftime("%b").lower(): month for month in range(1, 13)
}


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


def parse_last_launch(value: object) -> datetime | None:
    """Parse a Firebase or CSV last-launch value into a datetime."""
    from reporting.processor import _normalize_date_digits

    text = _normalize_date_digits("" if value is None else str(value))
    if not text:
        return None
    for size, fmt in ((19, "%Y-%m-%d %H:%M:%S"), (10, "%Y-%m-%d")):
        try:
            return datetime.strptime(text[:size], fmt)
        except ValueError:
            continue
    return None


def collect_last_launches(firebase_json: dict[str, Any] | None) -> list[datetime]:
    """All last-launch timestamps from the Firebase export, not the cutoff-filtered CSV."""
    launches: list[datetime] = []
    user_data = (firebase_json or {}).get("userData") or {}
    for _user_id, data in user_data.items():
        if not isinstance(data, dict):
            continue
        parsed = parse_last_launch(data.get("lastLaunch"))
        if parsed is not None:
            launches.append(parsed)
    return launches


def rolling_active_count(
    launches: list[datetime],
    as_of: datetime,
    window_days: int = YEARLY_ROLLING_ACTIVE_DAYS,
) -> int:
    """Users whose last launch is in the trailing window ending at as_of."""
    cutoff = as_of - timedelta(days=window_days)
    return sum(1 for launch in launches if cutoff <= launch <= as_of)


def highest_rolling_active_for_month(
    launches: list[datetime],
    year: int,
    month: int,
    window_days: int = YEARLY_ROLLING_ACTIVE_DAYS,
    now: datetime | None = None,
) -> int:
    """Peak trailing-window active-user total observed on any day of the month.

    Example: 912 users in the last 40 days on day 12, 815 on day 31 → 912.
    """
    now = now or datetime.now()
    last_day = calendar.monthrange(year, month)[1]
    highest = 0
    for day in range(1, last_day + 1):
        day_end = datetime(year, month, day, 23, 59, 59)
        if day_end.date() > now.date():
            break
        as_of = now if day_end.date() == now.date() else day_end
        highest = max(highest, rolling_active_count(launches, as_of, window_days))
    return highest


def yearly_app_data_path(output_dir: Path, year: int) -> Path:
    """Return `{output_dir}/{year}/{year}_App_Data.csv`."""
    return output_dir / str(year) / f"{year}_App_Data.csv"


def parse_archive_month(value: str) -> int | None:
    """Map a Month cell to 1-12. Accepts January, Jan, 01, 1, or 2026-01."""
    text = (value or "").strip()
    if not text:
        return None
    lowered = text.lower()
    if lowered in _MONTH_NAME_TO_NUM:
        return _MONTH_NAME_TO_NUM[lowered]
    first_token = re.split(r"[\s,/.-]+", lowered)[0]
    if first_token in _MONTH_NAME_TO_NUM:
        return _MONTH_NAME_TO_NUM[first_token]
    if first_token in _MONTH_ABBR_TO_NUM:
        return _MONTH_ABBR_TO_NUM[first_token]
    match = re.match(r"^(?:(\d{4})[-/])?(\d{1,2})$", text)
    if match:
        month = int(match.group(2))
        if 1 <= month <= 12:
            return month
    return None


def load_app_data_archive(path: Path) -> dict[int, int]:
    """Load Month -> highest count from a yearly archive CSV."""
    counts: dict[int, int] = {}
    if not path.exists():
        return counts
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        reader.fieldnames = [fn.strip() for fn in reader.fieldnames or []]
        for row in reader:
            row = {k.strip(): (v or "").strip() for k, v in row.items() if k}
            month = parse_archive_month(row.get("Month", ""))
            if month is None:
                continue
            raw_count = row.get("Highest Monthly Count", "").replace(",", "")
            try:
                count = int(raw_count)
            except ValueError:
                continue
            counts[month] = max(counts.get(month, 0), count)
    return counts


def write_app_data_archive(path: Path, counts: dict[int, int]) -> None:
    """Write months in calendar order. Only months with a recorded high are included."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(APP_DATA_ARCHIVE_HEADERS)
        for month in range(1, 13):
            if month not in counts:
                continue
            writer.writerow([MONTH_NAMES[month - 1], counts[month]])


def update_yearly_archives(
    output_dir: Path, monthly_history: Dict[str, Dict]
) -> list[Path]:
    """Merge month highs into `{year}/{year}_App_Data.csv`.

    Highest Monthly Count is a high-water mark: a later run never lowers a month.
    """
    by_year: dict[int, dict[int, int]] = {}
    for month_key, entry in monthly_history.items():
        try:
            parsed = datetime.strptime(month_key, "%Y-%m")
        except ValueError:
            continue
        count = int(entry.get("max_users", 0) or 0)
        if count <= 0:
            continue
        year_months = by_year.setdefault(parsed.year, {})
        year_months[parsed.month] = max(year_months.get(parsed.month, 0), count)

    written: list[Path] = []
    for year, months in sorted(by_year.items()):
        path = yearly_app_data_path(output_dir, year)
        merged = load_app_data_archive(path)
        for month, count in months.items():
            merged[month] = max(merged.get(month, 0), count)
        write_app_data_archive(path, merged)
        written.append(path)
        print(f"Updated yearly app data archive: {path}")
    return written


def discover_app_data_archives(output_dir: Path) -> list[tuple[int, Path]]:
    """Find `{year}/{year}_App_Data.csv` folders under output_dir."""
    archives: list[tuple[int, Path]] = []
    if not output_dir.exists():
        return archives
    for child in output_dir.iterdir():
        if not child.is_dir() or not child.name.isdigit() or len(child.name) != 4:
            continue
        year = int(child.name)
        path = yearly_app_data_path(output_dir, year)
        if path.exists():
            archives.append((year, path))
    return sorted(archives)


def format_yoy_change(previous: int | None, current: int | None) -> str:
    if previous is None or current is None or previous == 0:
        return ""
    percent = (current - previous) / previous * 100
    sign = "+" if percent > 0 else ""
    return f"{sign}{percent:.1f}%"


def get_year_over_year_data(output_dir: Path) -> Tuple[List[str], List[List[str]]]:
    """Build a month-by-year comparison table from yearly app-data archives."""
    archives = discover_app_data_archives(output_dir)
    if not archives:
        return ["Month"], [["No data available"]]

    years = [year for year, _ in archives]
    counts_by_year = {year: load_app_data_archive(path) for year, path in archives}
    headers = ["Month", *[str(year) for year in years]]
    if len(years) >= 2:
        headers.append("YoY Change")

    rows: list[list[str]] = []
    for month in range(1, 13):
        if not any(month in counts_by_year[year] for year in years):
            continue
        row = [MONTH_NAMES[month - 1]]
        for year in years:
            count = counts_by_year[year].get(month)
            row.append(str(count) if count is not None else "")
        if len(years) >= 2:
            row.append(
                format_yoy_change(
                    counts_by_year[years[-2]].get(month),
                    counts_by_year[years[-1]].get(month),
                )
            )
        rows.append(row)

    if not rows:
        return headers, [["No data available"] + [""] * (len(headers) - 1)]
    return headers, rows


def update_yearly_archive_from_launches(
    output_dir: Path,
    launches: list[datetime],
    *,
    window_days: int = YEARLY_ROLLING_ACTIVE_DAYS,
    now: datetime | None = None,
) -> list[Path]:
    """Archive this month's peak trailing-window active-user total."""
    now = now or datetime.now()
    high = highest_rolling_active_for_month(
        launches, now.year, now.month, window_days, now
    )
    if high <= 0:
        return []
    month_key = now.strftime("%Y-%m")
    print(
        f"Yearly archive {month_key}: peak {window_days}-day active users = {high}"
    )
    return update_yearly_archives(output_dir, {month_key: {"max_users": high}})


def update_usage_history(
    config: FestivalConfig,
    users: list[UserRecord],
    firebase_json: dict[str, Any] | None = None,
) -> None:
    print(f"Updating usage history for {config.name}...")
    daily = DailyUsageTracker(config, users)
    daily.ensure_recent_days(days_back=7)
    daily.update_daily_usage()

    monthly = MonthlyUsageTracker(config, users)
    monthly.update_monthly_usage()

    launches = collect_last_launches(firebase_json)
    if not launches:
        launches = [
            parsed
            for parsed in (parse_last_launch(user.last_launch) for user in users)
            if parsed is not None
        ]
    update_yearly_archive_from_launches(config.output_dir, launches)

from __future__ import annotations

from pathlib import Path


def with_event_year(filename: str, event_year: str) -> str:
    """Insert event year before extension: report_dashboard.html -> report_dashboard_2027.html"""
    year = (event_year or "").strip()
    if not year:
        return filename
    path = Path(filename)
    return f"{path.stem}_{year}{path.suffix}"


def dashboard_title(label: str, event_year: str) -> str:
    year = (event_year or "").strip()
    if year:
        return f"{label} {year}"
    return label

"""UTF-8 CSV file read/write with consistent LF line endings (cross-platform)."""

from __future__ import annotations

from pathlib import Path


def read_csv_text(path: Path) -> str:
    """Read a local CSV file; tolerates Excel UTF-8 BOM on Windows."""
    return path.read_text(encoding="utf-8-sig")


def write_csv_text(path: Path, text: str) -> None:
    """Write CSV text with LF line endings regardless of host OS."""
    path.parent.mkdir(parents=True, exist_ok=True)
    normalized = (text or "").replace("\r\n", "\n").replace("\r", "\n")
    with path.open("w", encoding="utf-8", newline="") as handle:
        handle.write(normalized)

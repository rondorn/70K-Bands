from __future__ import annotations

from typing import Dict, List, Tuple


def _is_pointer_data_line(line: str) -> bool:
    stripped = line.strip()
    return bool(stripped) and not stripped.startswith("#") and stripped.count("::") >= 2


def _parse_pointer_line(line: str) -> Tuple[str, str, str] | None:
    stripped = line.strip()
    if not _is_pointer_data_line(stripped):
        return None
    section, key, value = stripped.split("::", 2)
    return section, key, value


def merge_current_report_urls(
    pointer_text: str,
    url_by_key: Dict[str, str],
    section: str = "Current",
) -> str:
    """
    Update or add reportUrl entries in the given pointer section.

    Preserves comments, blank lines, and ordering of unrelated entries.
    Replaces existing Current::reportUrl* values and appends any missing keys
    at the end of that section's reportUrl block.
    """
    lines = pointer_text.splitlines()
    out_lines: List[str] = []
    seen_keys: set[str] = set()
    section_lines: List[int] = []
    report_line_indices: List[int] = []

    for idx, line in enumerate(lines):
        parsed = _parse_pointer_line(line)
        if parsed and parsed[0] == section:
            section_lines.append(idx)
            if parsed[1].startswith("reportUrl"):
                report_line_indices.append(idx)

    # Build output, updating reportUrl lines in the target section.
    for idx, line in enumerate(lines):
        parsed = _parse_pointer_line(line)
        if (
            parsed
            and parsed[0] == section
            and parsed[1].startswith("reportUrl")
            and parsed[1] in url_by_key
        ):
            seen_keys.add(parsed[1])
            out_lines.append(f"{section}::{parsed[1]}::{url_by_key[parsed[1]]}")
            continue
        out_lines.append(line)

    missing = [key for key in url_by_key if key not in seen_keys]
    if not missing:
        return "\n".join(out_lines) + ("\n" if pointer_text.endswith("\n") else "")

    insert_at = len(out_lines)
    if report_line_indices:
        # Insert after the last existing reportUrl line in the file.
        last_report_idx = report_line_indices[-1]
        insert_at = last_report_idx + 1
    elif section_lines:
        # Section exists but no report URLs yet — append after last section line.
        insert_at = section_lines[-1] + 1

    new_lines = [f"{section}::{key}::{url_by_key[key]}" for key in sorted(missing)]
    out_lines[insert_at:insert_at] = new_lines
    return "\n".join(out_lines) + ("\n" if pointer_text.endswith("\n") else "")


def list_report_url_keys(pointer_text: str, section: str = "Current") -> Dict[str, str]:
    result: Dict[str, str] = {}
    for line in pointer_text.splitlines():
        parsed = _parse_pointer_line(line)
        if parsed and parsed[0] == section and parsed[1].startswith("reportUrl"):
            result[parsed[1]] = parsed[2]
    return result

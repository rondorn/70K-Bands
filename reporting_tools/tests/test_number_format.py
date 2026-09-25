#!/usr/bin/env python3
from __future__ import annotations

import sys
import unittest
from pathlib import Path

TOOLS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_ROOT))

from reporting.reports.html_reports import format_number, format_table_cell


class NumberFormatTests(unittest.TestCase):
    def test_adds_thousands_separators(self) -> None:
        self.assertEqual(format_number("1187"), "1,187")
        self.assertEqual(format_number("921"), "921")
        self.assertEqual(format_number("1,187"), "1,187")
        self.assertEqual(format_number("1187%"), "1,187%")
        self.assertEqual(format_number("+25.0%"), "+25.0%")
        self.assertEqual(format_number("79.1%"), "79.1%")
        self.assertEqual(format_number("January"), "January")
        self.assertEqual(format_number(""), "")

    def test_table_cell_escapes_and_formats(self) -> None:
        self.assertEqual(format_table_cell("1187"), "1,187")
        self.assertEqual(format_table_cell("1187", "Count"), "1,187")
        self.assertEqual(format_table_cell("Band <Name>"), "Band &lt;Name&gt;")
        self.assertIn("rank-number", format_table_cell('<span class="rank-number">12</span>'))

    def test_does_not_comma_format_version_numbers(self) -> None:
        self.assertEqual(
            format_table_cell("20160801001", "iOS 70K Version"),
            "20160801001",
        )
        self.assertEqual(
            format_table_cell("20160801001", "Android 70K Version"),
            "20160801001",
        )
        self.assertEqual(
            format_table_cell("18", "iOS OS Version"),
            "18",
        )
        self.assertEqual(format_table_cell("1000", "Count"), "1,000")
        self.assertEqual(format_table_cell("1000", "User Count"), "1,000")


if __name__ == "__main__":
    unittest.main()

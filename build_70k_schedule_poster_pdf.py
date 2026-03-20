#!/usr/bin/env python3
"""
Build a cruise-ship poster PDF: instruction text + schedule QR(s) compatible with 70K Bands
iOS and Android (binary payload: type byte + 4-byte LE uncompressed size + zlib).

Compression mirrors ScheduleQRCompression.java (and iOS parity per app comments):
  - Dropbox URL → !DB!, strip trailing commas
  - 8-column shortened CSV (band/venue/type codes, date/day/time shortening)
  - UTF-8 → 4-byte LE uncompressed size + raw DEFLATE only (Java Deflater NOWRAP; not zlib wrapper)
  - QR: Nayuki binary encode + ECC MEDIUM (same as ScheduleQRShareActivity), via Python qrcodegen
  - Split into 2 QRs if payload > 2953 bytes (type 1 + type 2 chunks)

Band canonical order: artist CSV data rows in file order (bandName column or col 0),
matching in-app band import / QR lineIndex order.

Venues and event types are hard-coded to match FestivalConfig (70K) and the shared type list.

Usage (from repo root):
  pip3 install -r requirements-poster.txt
  python3 build_70k_schedule_poster_pdf.py -o ~/Desktop/70k_schedule_poster.pdf

Requires network to fetch pointer + CSVs (override with --artist-csv / --schedule-csv paths).
"""

from __future__ import annotations

import argparse
import csv
import io
import re
import struct
import sys
import urllib.request
import zlib
from pathlib import Path
from typing import List, Sequence

from PIL import Image
from reportlab.lib.pagesizes import letter
from reportlab.lib.units import inch
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas

import qrcodegen

# --- Hard-coded URLs (Dropbox; use dl=1 or raw=1 for direct file body) ---

PRODUCTION_POINTER_URL = (
    "https://www.dropbox.com/scl/fi/kd5gzo06yrrafgz81y0ao/productionPointer.txt"
    "?rlkey=gt1lpaf11nay0skb6fe5zv17g&dl=1"
)

# Overrides when pointer lacks keys (same as user-supplied production URLs)
FALLBACK_ARTIST_URL = (
    "https://www.dropbox.com/scl/fi/u5azf0n9yrg2ap91p3zgi/artistLineup_2026.csv"
    "?rlkey=isli0nm3mexf4kxw7fpjn1a5g&raw=1"
)
FALLBACK_SCHEDULE_URL = (
    "https://www.dropbox.com/scl/fi/r7cf8qd8w7di7refgrsjj/artistSchedule2026.csv"
    "?rlkey=y309oe7pbd8wdhl8ubz80s4b7&raw=1"
)

# 70K venue order — keep in sync with FestivalConfig.getAllVenueNames() (both apps)
VENUE_NAMES: List[str] = [
    "Pool",
    "Lounge",
    "Theater",
    "Rink",
    "Schooner Pub",
    "Arcade",
    "Sports Bar",
    "Viking Crown",
    "Boleros Lounge",
    "Solarium",
    "Ale And Anchor Pub",
    "Ale & Anchor Pub",
    "Bull And Bear Pub",
    "Bull & Bear Pub",
]

# Event type order for QR digit codes — keep in sync with Swift + Java EVENT_TYPE_ORDER
EVENT_TYPE_ORDER: List[str] = [
    "Show",
    "Meet and Greet",
    "Unofficial Event",
    "Special Event",
    "Clinic",
    "Cruiser Organized",
]

DROPBOX_PREFIX = "https://www.dropbox.com/"
DROPBOX_PLACEHOLDER = "!DB!"

SCHEDULE_QR_HEADER = "Band,Location,Date,Day,Start Time,End Time,Type,Notes"
MAX_BYTES_PER_BINARY_QR = 2953

TYPE_FULL = 0
TYPE_CHUNK1 = 1
TYPE_CHUNK2 = 2

TRAILING_COMMAS = re.compile(r",+$")

# In-app QR share: ~720 px symbol target, 4-module quiet zone, ≥6 px per module
QR_TARGET_PX = 720
QUIET_ZONE_MODULES = 4
MIN_PIXELS_PER_MODULE = 6


def compress_for_qr(source: bytes) -> bytes:
    """
    Match ScheduleQRCompression.java compressForQR:
    little-endian uint32 uncompressed length + raw DEFLATE (no zlib wrapper, no adler32).
    Android Inflater tries zlib first, then raw; iOS decode expects the same stream as in-app share.
    """
    co = zlib.compressobj(
        zlib.Z_DEFAULT_COMPRESSION,
        zlib.DEFLATED,
        -zlib.MAX_WBITS,
    )
    compressed = co.compress(source) + co.flush()
    return struct.pack("<I", len(source)) + compressed


def fetch_text(url: str, timeout: int = 60) -> str:
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "70K-Bands-poster-builder/1.0"},
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        raw = resp.read()
    return raw.decode("utf-8-sig")


def parse_pointer(text: str) -> dict[str, str]:
    """Parse lines like Current::artistUrl::https://..."""
    out: dict[str, str] = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("::")
        if len(parts) >= 3 and parts[0].strip().lower() == "current":
            key = parts[1].strip()
            val = "::".join(parts[2:]).strip()
            out[key] = val
    return out


def canonical_band_names_from_artist_csv(csv_text: str) -> list[str]:
    """Row order of band names; matches in-app canonical QR band list."""
    f = io.StringIO(csv_text)
    sample = csv_text[:4096]
    try:
        dialect = csv.Sniffer().sniff(sample)
    except csv.Error:
        dialect = csv.excel
    f.seek(0)
    reader = csv.DictReader(f, dialect=dialect)
    if reader.fieldnames:
        fn = [h.strip() for h in reader.fieldnames if h]
        key = None
        for candidate in ("bandName", "Band", "band"):
            for h in fn:
                if h.lower() == candidate.lower():
                    key = h
                    break
            if key:
                break
        if key:
            names: list[str] = []
            for row in reader:
                v = (row.get(key) or "").strip()
                if not v or v.lower() == "bandname":
                    continue
                names.append(v)
            if names:
                return names
    # Fallback: first column per line, skip header row containing bandName
    f.seek(0)
    names = []
    for line in csv_text.splitlines():
        if not line.strip():
            continue
        row = next(csv.reader([line]))
        if not row:
            continue
        name = row[0].strip()
        if "bandName" in name:
            continue
        if name:
            names.append(name)
    return names


def parse_csv_line(line: str) -> list[str]:
    return next(csv.reader([line]))


def escape_csv_field(s: str) -> str:
    if "," in s or "\n" in s or '"' in s:
        return '"' + s.replace('"', '""') + '"'
    return s


def build_csv_line(fields: Sequence[str]) -> str:
    return ",".join(escape_csv_field(f or "") for f in fields)


def preprocess_csv_for_compression(csv: str) -> str:
    out = csv.replace(DROPBOX_PREFIX, DROPBOX_PLACEHOLDER)
    lines = out.split("\n")
    return "\n".join(TRAILING_COMMAS.sub("", ln) for ln in lines)


def shorten_date_for_qr(date: str) -> str:
    date = date.strip()
    parts = date.split("/")
    if len(parts) != 3:
        return date
    try:
        m, d, y = int(parts[0].strip()), int(parts[1].strip()), int(parts[2].strip())
        if not (1 <= m <= 12 and 1 <= d <= 31 and 2000 <= y <= 2099):
            return date
        return f"{m}/{d}/{y % 100}"
    except ValueError:
        return date


def shorten_time_for_qr(time: str) -> str:
    time = time.strip()
    parts = time.split(":")
    if len(parts) != 2:
        return time
    try:
        h = int(parts[0].strip())
        if not (0 <= h <= 23):
            return time
        m = int(parts[1].strip())
        if not (0 <= m <= 59):
            return time
        if m == 0:
            return f"{h}:"
        if m == 15:
            return f"{h}:1"
        if m == 30:
            return f"{h}:2"
        if m == 45:
            return f"{h}:3"
        return time
    except ValueError:
        return time


def shorten_day_for_qr(day: str) -> str:
    trimmed = day.strip()
    if trimmed.startswith("Day ") and len(trimmed) > 4:
        suffix = trimmed[4:].strip()
        if suffix.isdigit():
            return suffix
    return day


def two_digit_code(index: int) -> str:
    n = index + 1
    if n < 1 or n > 99:
        return ""
    return f"{n:02d}"


def one_digit_code_for_type(index: int) -> str:
    if 0 <= index < 9:
        return str(index + 1)
    return ""


def compress_band_column(value: str, band_names: list[str]) -> str:
    trimmed = value.strip()
    for idx, name in enumerate(band_names):
        if trimmed.lower() == name.strip().lower():
            return two_digit_code(idx)
    return value


def compress_location_column(value: str, venue_names: list[str]) -> str:
    for idx, name in enumerate(venue_names):
        if value.lower() == name.lower():
            return two_digit_code(idx)
    return value


def compress_type_column(value: str, event_types: list[str]) -> str:
    for idx, name in enumerate(event_types):
        if value.lower() == name.lower():
            return one_digit_code_for_type(idx)
    return value


def strip_unofficial_cruiser_rows(csv: str) -> str:
    """ScheduleCSVExport.stripUnofficialCruiserRows — Type column index 6."""
    lines = csv.split("\n")
    if not lines:
        return csv
    out: list[str] = [lines[0]]
    unofficial = {"Unofficial Event", "Cruiser Organized"}
    for i in range(1, len(lines)):
        line = lines[i]
        if not line.strip():
            out.append(line)
            continue
        fields = parse_csv_line(line.strip())
        if len(fields) <= 6:
            out.append(line)
            continue
        if fields[6].strip() in unofficial:
            continue
        out.append(line)
    return "\n".join(out)


def compress_schedule_for_qr_data(
    csv_string: str,
    band_names: list[str],
    venue_names: list[str],
) -> bytes:
    preprocessed = preprocess_csv_for_compression(csv_string)
    lines = preprocessed.split("\n")
    out_lines: list[str] = []
    for i, line in enumerate(lines):
        trimmed = line.strip()
        if not trimmed:
            continue
        fields = parse_csv_line(trimmed)
        if len(fields) < 7:
            out_lines.append(line)
            continue
        # Match Java: i == 0 && "band".equalsIgnoreCase(fields[0]) — no trim on field[0]
        if i == 0 and fields and fields[0].casefold() == "band":
            out_lines.append(SCHEDULE_QR_HEADER)
            continue
        notes = fields[8] if len(fields) > 8 else ""
        new_fields = [
            compress_band_column(fields[0], band_names),
            compress_location_column(fields[1], venue_names),
            shorten_date_for_qr(fields[2]),
            shorten_day_for_qr(fields[3]),
            shorten_time_for_qr(fields[4]),
            shorten_time_for_qr(fields[5]),
            compress_type_column(fields[6], EVENT_TYPE_ORDER),
            notes,
        ]
        out_lines.append(build_csv_line(new_fields))
    compressed_csv = "\n".join(out_lines)
    csv_data = compressed_csv.encode("utf-8")
    return compress_for_qr(csv_data)


def wrap_type(t: int, body: bytes) -> bytes:
    return bytes([t & 0xFF]) + body


def compress_schedule_one_or_two_qrs(
    full_schedule_csv: str,
    band_names: list[str],
    venue_names: list[str],
) -> list[bytes]:
    single_body = compress_schedule_for_qr_data(
        full_schedule_csv, band_names, venue_names
    )
    full_payload = wrap_type(TYPE_FULL, single_body)
    if len(full_payload) <= MAX_BYTES_PER_BINARY_QR:
        return [full_payload]
    preprocessed = preprocess_csv_for_compression(full_schedule_csv)
    lines = preprocessed.split("\n")
    header_line: str | None = None
    data_lines: list[str] = []
    for line in lines:
        trimmed = line.strip()
        if not trimmed:
            continue
        fields = parse_csv_line(trimmed)
        if len(fields) >= 7 and fields[0].casefold() == "band":
            header_line = trimmed
            continue
        data_lines.append(trimmed)
    if header_line is None or len(data_lines) < 2:
        raise ValueError("Schedule needs at least 2 data rows for two-QR split.")
    mid = len(data_lines) // 2
    chunk1 = "\n".join([header_line] + data_lines[:mid])
    chunk2 = "\n".join(data_lines[mid:])
    p1 = compress_schedule_for_qr_data(chunk1, band_names, venue_names)
    p2 = compress_schedule_for_qr_data(chunk2, band_names, venue_names)
    out1 = wrap_type(TYPE_CHUNK1, p1)
    out2 = wrap_type(TYPE_CHUNK2, p2)
    if len(out1) > MAX_BYTES_PER_BINARY_QR or len(out2) > MAX_BYTES_PER_BINARY_QR:
        raise ValueError("Schedule too large for two QRs; shrink data or split manually.")
    return [out1, out2]


def encode_qr_payload_image(payload: bytes) -> Image.Image:
    """
    Nayuki QrCode.encodeBinary(payload, Ecc.MEDIUM) and rasterize like ScheduleQRShareActivity:
    integer module scale, 4-module quiet zone, min 6 px per module, ~720 px symbol target.
    """
    qr = qrcodegen.QrCode.encode_binary(payload, qrcodegen.QrCode.Ecc.MEDIUM)
    n = qr.get_size()
    scale = max(MIN_PIXELS_PER_MODULE, max(1, QR_TARGET_PX // n))
    symbol_px = n * scale
    border_px = QUIET_ZONE_MODULES * scale
    total = symbol_px + 2 * border_px
    img = Image.new("RGB", (total, total), (255, 255, 255))
    px = img.load()
    black = (0, 0, 0)
    white = (255, 255, 255)
    for y in range(n):
        for x in range(n):
            color = black if qr.get_module(x, y) else white
            x0 = border_px + x * scale
            y0 = border_px + y * scale
            for dy in range(scale):
                for dx in range(scale):
                    px[x0 + dx, y0 + dy] = color
    return img


def draw_poster_pdf(
    out_path: Path,
    qr_images: Sequence[Image.Image],
    print_dpi: int = 300,
) -> None:
    """
    Letter PDF optimized for ship-hallway viewing: large type, centered copy,
    QR centered in the remaining area below the instructions (not pinned to the bottom).
    """
    w_pt, h_pt = letter
    # Margins (pt): generous white frame
    m_top = 0.72 * inch
    m_bottom = 0.6 * inch
    m_side = 0.78 * inch
    content_w = w_pt - 2 * m_side

    title_pt = 21
    body_pt = 12.5
    label_pt = 11
    body_leading = 17
    gap_after_title = 18
    gap_intro_to_bullets = 16
    bullet_leading = 17
    gap_before_qr_zone = 32

    # ~0.45 em per char at Helvetica for wrap width estimate
    max_intro_chars = max(34, int(content_w / (body_pt * 0.45)))

    c = canvas.Canvas(str(out_path), pagesize=letter)
    # PDF y increases upward; start below top margin
    y = h_pt - m_top

    c.setFont("Helvetica-Bold", title_pt)
    y -= title_pt * 0.9
    c.drawCentredString(w_pt / 2, y, "70K Band Schedule QR Code")
    y -= gap_after_title

    c.setFont("Helvetica", body_pt)
    intro = (
        "If your phone needs the latest version of the schedule, and you do not have "
        "internet access, do the following:"
    )
    for line in _wrap_text(intro, max_intro_chars):
        c.drawCentredString(w_pt / 2, y, line)
        y -= body_leading
    y -= gap_intro_to_bullets

    bullets = (
        "Launch the 70K Bands App",
        "Click on the Gear icon to get to Preferences",
        'Click on the button "Scan QR Code Schedule"',
        "Scan the QR Code below",
    )
    for b in bullets:
        c.drawCentredString(w_pt / 2, y, "•  " + b)
        y -= bullet_leading

    y -= gap_before_qr_zone

    # Remaining vertical band: from y (upper, larger coordinate) down to bottom margin
    band_top_y = y
    band_bot_y = m_bottom
    available_h = band_top_y - band_bot_y
    max_w = content_w * 0.92
    max_h = available_h * 0.92

    if available_h < 100:
        max_h = max(80.0, available_h * 0.85)

    labels = (
        ("Scan this QR code.",)
        if len(qr_images) == 1
        else ("Scan first QR code (chunk 1).", "Scan second QR code (chunk 2).")
    )

    label_gap = 11
    stack_gap = 24

    def physical_size(im: Image.Image) -> tuple[float, float]:
        iw, ih = im.size
        return (iw * 72.0 / print_dpi, ih * 72.0 / print_dpi)

    # Stack (top → bottom on page): [label + QR] per chunk; center stack in remaining band
    n = len(qr_images)
    base_rw = [physical_size(im)[0] for im in qr_images]
    base_rh = [physical_size(im)[1] for im in qr_images]

    def stack_height(s: float) -> float:
        h = 0.0
        for i in range(n):
            if n > 1:
                h += label_pt * 1.12 + label_gap
            h += base_rh[i] * s
            if i < n - 1:
                h += stack_gap
        return h

    def stack_width(s: float) -> float:
        return max(rw * s for rw in base_rw)

    lo, hi = 0.01, 2.5
    scale_fit = 0.5
    for _ in range(48):
        mid = (lo + hi) / 2
        if stack_width(mid) <= max_w and stack_height(mid) <= max_h:
            scale_fit = mid
            lo = mid
        else:
            hi = mid

    stack_h = stack_height(scale_fit)
    center_y = band_bot_y + available_h / 2.0
    stack_top_y = center_y + stack_h / 2.0

    y_cursor = stack_top_y
    c.setFont("Helvetica-Bold", label_pt)
    for idx, im in enumerate(qr_images):
        if n > 1:
            y_cursor -= label_pt * 1.12
            c.drawCentredString(w_pt / 2, y_cursor, labels[idx])
            y_cursor -= label_gap
        y_cursor -= base_rh[idx] * scale_fit
        rw = base_rw[idx] * scale_fit
        rh = base_rh[idx] * scale_fit
        x0 = (w_pt - rw) / 2
        buf = io.BytesIO()
        im.save(buf, format="PNG")
        buf.seek(0)
        c.drawImage(
            ImageReader(buf),
            x0,
            y_cursor,
            width=rw,
            height=rh,
            mask="auto",
        )
        if idx < n - 1:
            y_cursor -= stack_gap

    c.save()


def _wrap_text(text: str, width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    cur: list[str] = []
    for w in words:
        test = (" ".join(cur + [w])) if cur else w
        if len(test) <= width:
            cur.append(w)
        else:
            if cur:
                lines.append(" ".join(cur))
            cur = [w]
    if cur:
        lines.append(" ".join(cur))
    return lines


def main() -> int:
    parser = argparse.ArgumentParser(description="Build 70K schedule QR poster PDF.")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=Path("70k_schedule_poster.pdf"),
        help="Output PDF path",
    )
    parser.add_argument("--artist-csv", type=Path, help="Local artist lineup CSV (skip download)")
    parser.add_argument("--schedule-csv", type=Path, help="Local schedule CSV (skip download)")
    parser.add_argument("--event-year", type=int, default=2026, help="Event year (logging only)")
    parser.add_argument("--print-dpi", type=int, default=300, help="Assumed print DPI for QR sizing")
    args = parser.parse_args()

    artist_url = FALLBACK_ARTIST_URL
    schedule_url = FALLBACK_SCHEDULE_URL
    try:
        ptr = fetch_text(PRODUCTION_POINTER_URL)
        kv = parse_pointer(ptr)
        artist_url = kv.get("artistUrl") or artist_url
        schedule_url = kv.get("scheduleUrl") or schedule_url
        print("Pointer loaded; artistUrl scheduleUrl resolved.", file=sys.stderr)
    except Exception as e:
        print(f"Pointer fetch failed ({e}); using fallback URLs.", file=sys.stderr)

    if args.artist_csv:
        artist_text = args.artist_csv.read_text(encoding="utf-8-sig")
    else:
        artist_text = fetch_text(artist_url)
    if args.schedule_csv:
        schedule_text = args.schedule_csv.read_text(encoding="utf-8-sig")
    else:
        schedule_text = fetch_text(schedule_url)

    band_names = canonical_band_names_from_artist_csv(artist_text)
    if not band_names:
        print("No band names parsed from artist CSV.", file=sys.stderr)
        return 1
    print(f"Canonical bands: {len(band_names)} (first: {band_names[0]!r})", file=sys.stderr)

    schedule_stripped = strip_unofficial_cruiser_rows(schedule_text)
    payloads = compress_schedule_one_or_two_qrs(
        schedule_stripped, band_names, VENUE_NAMES
    )
    print(
        f"QR payloads: {len(payloads)} (lengths: {[len(p) for p in payloads]})",
        file=sys.stderr,
    )

    qr_images = [encode_qr_payload_image(p) for p in payloads]
    draw_poster_pdf(args.output, qr_images, print_dpi=args.print_dpi)
    print(f"Wrote {args.output.resolve()}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""
Print-optimize a schedule PDF **without changing the QR symbol** (no re-encode, no crop).

The payload is compressed binary; mobile decoders need stable module sampling. This script:

  1. Extracts the **largest embedded raster** from page 1 (original PDF pixels), or renders
     the page if there is no embedded image.
  2. Adds a symmetric **white border** around the **entire** image (never crops to the QR).
  3. Upscales with **integer nearest-neighbor** only, capped so the result fits the printable
     area when mapped **1:1 at print_dpi** into PDF points (avoids viewer/printer interpolation
     that smears dense QRs).
  4. Embeds with **PyMuPDF** using a rectangle sized as ``pixels * (72 / print_dpi)`` so
     at ``print_dpi`` (e.g. 300) there is one printed dot per image pixel.

**Do not** re-encode the QR or use ReportLab image flowables that scale to arbitrary inches
(non-integer resampling breaks imports even when pyzbar still decodes).

Usage:
  python3 build_schedule_print_pdf.py [input.pdf] [output.pdf]
  python3 build_schedule_print_pdf.py in.pdf out.pdf --verify
"""

from __future__ import annotations

import argparse
import io
import sys
from pathlib import Path

import fitz  # PyMuPDF
from PIL import Image, ImageOps

try:
    from pyzbar.pyzbar import decode as zbar_decode
except ImportError:
    zbar_decode = None


def _largest_embedded_image(doc: fitz.Document, page_index: int = 0) -> Image.Image | None:
    page = doc[page_index]
    best: tuple[int, Image.Image] | None = None
    for item in page.get_images(full=True):
        xref = item[0]
        extracted = doc.extract_image(xref)
        raw = extracted.get("image")
        if not raw:
            continue
        im = Image.open(io.BytesIO(raw)).convert("RGB")
        area = im.width * im.height
        if best is None or area > best[0]:
            best = (area, im)
    return best[1] if best else None


def _page_raster_fallback(doc: fitz.Document, page_index: int = 0, dpi: int = 300) -> Image.Image:
    page = doc[page_index]
    pix = page.get_pixmap(dpi=dpi)
    return Image.open(io.BytesIO(pix.tobytes("png"))).convert("RGB")


def load_source_raster(doc: fitz.Document) -> Image.Image:
    im = _largest_embedded_image(doc)
    if im is not None:
        return im
    return _page_raster_fallback(doc)


def optimize_raster_for_print(
    im: Image.Image,
    border_px: int,
    inner_w_pt: float,
    inner_h_pt: float,
    print_dpi: int,
) -> Image.Image:
    """
    Full-raster border, then integer NEAREST upscale so output fits inside
    max_px_w x max_px_h (printable area at print_dpi).
    """
    rgb = im.convert("RGB")
    padded = ImageOps.expand(rgb, border=border_px, fill="white")
    w, h = padded.size
    max_px_w = int(inner_w_pt * print_dpi / 72)
    max_px_h = int(inner_h_pt * print_dpi / 72)
    k_w = max_px_w // w if w > 0 else 1
    k_h = max_px_h // h if h > 0 else 1
    k = max(1, min(k_w, k_h))
    return padded.resize((w * k, h * k), Image.NEAREST)


def raster_to_png_bytes(im: Image.Image) -> bytes:
    buf = io.BytesIO()
    im.save(buf, format="PNG", compress_level=9)
    return buf.getvalue()


def write_letter_pdf_1to1_dpi(png_bytes: bytes, out_path: Path, print_dpi: int) -> None:
    """
    Rect size in points = pixels * 72/print_dpi so a 300 dpi printer uses one dot per pixel.
    """
    im = Image.open(io.BytesIO(png_bytes))
    iw, ih = im.size
    rect_w = iw * 72.0 / print_dpi
    rect_h = ih * 72.0 / print_dpi
    page_w, page_h = 612, 792
    x0 = (page_w - rect_w) / 2
    y0 = (page_h - rect_h) / 2
    rect = fitz.Rect(x0, y0, x0 + rect_w, y0 + rect_h)

    doc = fitz.open()
    try:
        page = doc.new_page(width=page_w, height=page_h)
        page.insert_image(rect, stream=png_bytes)
        doc.save(str(out_path), deflate=True, garbage=4, clean=True)
    finally:
        doc.close()


def verify_zbar(label: str, im: Image.Image) -> None:
    if zbar_decode is None:
        return
    results = zbar_decode(im)
    if not results:
        print(f"[verify] {label}: no decode", file=sys.stderr)
        return
    print(f"[verify] {label}: payload {len(results[0].data)} bytes")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Print PDF: full raster, border, integer NEAREST upscale, 1:1 dpi embed."
    )
    parser.add_argument(
        "input_pdf",
        nargs="?",
        default="/Users/rdorn/Downloads/Sample Schedule.pdf",
        type=Path,
    )
    parser.add_argument(
        "output_pdf",
        nargs="?",
        default="/Users/rdorn/Downloads/Sample Schedule.pdf",
        type=Path,
    )
    parser.add_argument(
        "--output",
        "-o",
        type=Path,
        default=None,
    )
    parser.add_argument(
        "--border",
        type=int,
        default=32,
        help="White padding (pixels) around full page image before upscale",
    )
    parser.add_argument(
        "--margin-pt",
        type=float,
        default=36,
        help="Minimum margin on Letter page (points); caps max image pixels",
    )
    parser.add_argument(
        "--print-dpi",
        type=int,
        default=300,
        help="Target print dpi for 1:1 pixel↔dot mapping (use same in printer dialog)",
    )
    parser.add_argument(
        "--verify",
        action="store_true",
        help="pyzbar decode diagnostics on source / rendered output",
    )
    args = parser.parse_args()
    out = args.output or args.output_pdf

    page_w, page_h = 612, 792
    inner_w_pt = page_w - 2 * args.margin_pt
    inner_h_pt = page_h - 2 * args.margin_pt
    if inner_w_pt <= 0 or inner_h_pt <= 0:
        raise SystemExit("margin-pt too large for Letter page")

    doc = fitz.open(args.input_pdf)
    try:
        raster = load_source_raster(doc)
    finally:
        doc.close()

    if args.verify:
        verify_zbar("source_full_raster", raster)

    optimized = optimize_raster_for_print(
        raster,
        border_px=args.border,
        inner_w_pt=inner_w_pt,
        inner_h_pt=inner_h_pt,
        print_dpi=args.print_dpi,
    )
    png = raster_to_png_bytes(optimized)
    write_letter_pdf_1to1_dpi(png, out, args.print_dpi)

    if args.verify:
        doc2 = fitz.open(out)
        try:
            pix = doc2[0].get_pixmap(dpi=200)
            rim = Image.open(io.BytesIO(pix.tobytes("png"))).convert("RGB")
        finally:
            doc2.close()
        verify_zbar("output_render_200dpi", rim)

    rw = optimized.width * 72.0 / args.print_dpi
    rh = optimized.height * 72.0 / args.print_dpi
    print(
        f"Wrote {out} — full raster, border={args.border}px, "
        f"NEAREST {optimized.size[0]}x{optimized.size[1]} px, "
        f"PDF rect ~{rw:.1f}x{rh:.1f} pt @ {args.print_dpi} dpi mapping."
    )


if __name__ == "__main__":
    main()

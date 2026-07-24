# Schedule QR decode script

## Purpose

Decode the 3 schedule QR codes from the static screenshot **without** using the app or Vision. This gives us:

1. **Exact bytes** from the image (same as or comparable to what the scanner sees).
2. **Fixture files** for the unit test so we can iterate on decompression without running the app.

## Setup

**1. Install the zbar C library (required by pyzbar)**  
On macOS:

```bash
brew install zbar
```

If you get “Unable to find zbar shared library” when running the script, try:

```bash
mkdir -p ~/lib
ln -s $(brew --prefix zbar)/lib/libzbar.dylib ~/lib/libzbar.dylib
```

**2. Install Python packages**

```bash
pip install pyzbar pillow
```

## Run

```bash
# From repo root or swift/
python3 scripts/decode_schedule_qr_image.py

# Or pass the image path
python3 scripts/decode_schedule_qr_image.py 70000TonsBandsTests/Resources/ScheduleQRTestImage.png
```

## Output

- **qr_top.bin**, **qr_middle.bin**, **qr_bottom.bin** in the same directory as the image (e.g. `70000TonsBandsTests/Resources/`).
- Printed: length and first 16 bytes (hex) of each payload so you can compare with app logs.

If the script’s “first16” and lengths match the app (`782, 782, 563` and `40 30 8F 50...`), then Vision and pyzbar agree and the issue is only in our decompression recovery. If they differ, the pipeline (Vision vs pyzbar) differs.

## Use in tests

1. Run the script so the three `.bin` files exist under `70000TonsBandsTests/Resources/`.
2. Add **qr_top.bin**, **qr_middle.bin**, **qr_bottom.bin** to the **70K BandsTests** target’s **Copy Bundle Resources** (if not already there).
3. Run the test **testDecodeScheduleFromFixturePayloads**; it uses these bytes and calls `decompressAndMergeThreePayloads` (no Vision, no image).

Then fix decompression until that test passes.

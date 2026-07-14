# Data maintenance tools

Standalone scripts that are **not** part of the Open Metal Fest Admin app
(`../promoter_admin/`). Festival lineup, schedule, descriptions, and publish
workflows live in that Flutter app.

## What’s here

| Item | Purpose |
|------|---------|
| [`poster_generation/`](poster_generation/) | Build a 70K Bands cruise-ship schedule QR poster PDF (iOS/Android compatible payload) |

## Schedule QR poster

```bash
cd data_maintenance_tools/poster_generation
pip3 install -r requirements-poster.txt
python3 build_70k_schedule_poster_pdf.py -o ~/Desktop/70k_schedule_poster.pdf
```

Requires network to fetch pointer + CSVs (or pass `--artist-csv` / `--schedule-csv`).
See the script docstring for encoding details and options.

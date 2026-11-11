# 70K Schedule import

Downloads the 70K artists/schedule JSON API and **appends** new **Show** rows
to a schedule CSV (same layout as `artistSchedule*.csv`). Existing rows are
never overwritten.

## Setup

```bash
cd data_maintenance_tools/70k_schedule_import
cp config.example.yaml config.yaml   # if needed
# edit config.yaml: json_url + output_csv
```

No third-party packages required (stdlib only).

## Run

```bash
python3 import_70k_schedule.py
```

Overrides:

```bash
python3 import_70k_schedule.py \
  --url 'https://example.com/artists.json' \
  --output '/Users/rdorn/Dropbox/70K Public Data Files/artistSchedule2027.csv'

# Local JSON fixture (no download)
python3 import_70k_schedule.py --json-file ./sample.json --dry-run
```

## Behavior

- Each `performances[]` entry is considered as a `Type=Show` row
- Band names are title-cased (`ARCH ENEMY` → `Arch Enemy`)
- Rows are appended only when **band + location + start time** is not already
  in the CSV (case-agnostic band/location; start time normalized to `HH:MM`)
- Existing CSV content is preserved; the file is created with a header only if
  it does not exist yet
- `details` is ignored
- Venue mapping (case-agnostic; longer names like `Pool Deck Stage` match `Pool Deck`):

  | JSON stage | App Location |
  |---|---|
  | Pool Deck | Pool |
  | Royal Theater | Theater |
  | Studio B | Rink |
  | Stars Lounge (also Star Lounge) | Lounge |
  | Bull & Bear | Ale And Anchor Pub |
  | Boleros | Boleros Lounge |
  | Playmaker Sports Bar | Sports Bar |
  | Viking Crown Lounge | Viking Crown |

- Date `YYYY-MM-DD` → `M/D/YYYY` (no leading zeros); day `1` → `Day 1`
- Output matches sample show rows: no quotes, trailing `Show,,,`
- Unmapped stages or bad fields abort the run before appending

## Config keys

| Key | Meaning |
|---|---|
| `json_url` | HTTP(S) URL of the artists JSON array |
| `output_csv` | Path of the CSV to append to |

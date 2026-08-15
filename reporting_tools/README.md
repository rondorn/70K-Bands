# Festival Reporting Tools

Python replacement for the Dropbox `collectAllData.sh` workflow. One command downloads production data, organizes it, and writes HTML dashboards.

## Quick start

```bash
cd reporting_tools
cp festivals.example.json festivals.json
cp festivals.secrets.example.json festivals.secrets.json
# Edit festivals.json (paths, pointer URL, firebase_database_url)
# Firebase auth: python3 run_reports.py auth google  (uses ~/.config/gcloud ADC)
pip install -r requirements.txt
python3 run_reports.py auth google
python3 run_reports.py --festivals 70k
```

Reports are written with the **event year from the production pointer** in filenames and page titles, e.g. `report_dashboard_2027.html` and “Stats 2027”.

## Cron / unattended runs

One-time credential setup:

```bash
python3 run_reports.py auth google                  # gcloud ADC → all festival Firebase downloads
python3 run_reports.py auth status                  # verify setup
chmod +x run_from_cron.sh
```

Crontab example (daily 6 AM):

```bash
0 6 * * * /Users/rdorn/personalGit/70K-Bands/reporting_tools/run_from_cron.sh
```

Logs: `~/70k_reports.cron.log`

## What it does

For each selected festival, the pipeline:

1. **Syncs the production pointer** — downloads pointer + lineup/schedule CSVs; reads `Current::eventYear`.
2. **Downloads the Firebase JSON export** — saved as backup using Google Application Default Credentials (`~/.config/gcloud/application_default_credentials.json`), the same login alerts fall back to.
3. **Organizes data in memory** — users, rankings, events filtered against lineup/schedule.
4. **Updates usage history** — daily/monthly active-user JSON files.
5. **Generates HTML reports** — main, full, and localized dashboards with event year in titles and filenames.

## Configuration files — what is confidential?

Two files, both **gitignored** and meant to stay on your machine:

| File | Checked in? | Confidential? |
| --- | --- | --- |
| `festivals.example.json` | Yes | No — placeholders only |
| `festivals.secrets.example.json` | Yes | No — placeholders only |
| `festivals.json` | **No** | **Mostly yes** — see below |
| `festivals.secrets.json` | **No** | **Yes** — optional Dropbox token; optional Firebase overrides |

**`festivals.secrets.json` is clearly confidential** if it still holds a Dropbox token or leftover Firebase secrets. Firebase report downloads default to Google ADC, not this file.

**`festivals.json` is open to interpretation:**

- **Treat as confidential (recommended):** Dropbox pointer URLs include `rlkey` tokens that grant access to production festival files. Your machine-specific paths also reveal your Dropbox layout. Keeping `festivals.json` local avoids leaking production links if the repo is ever public or shared broadly.
- **Could be checked in:** If you replace pointer URLs with non-secret public CDN URLs and use only relative/generic paths, the non-secret parts (report names, vote thresholds, directory structure) are safe to share. Secrets still belong in `festivals.secrets.json`.

**Google OAuth (ADC):** Default Firebase auth for all festivals. Stored by `gcloud` at `~/.config/gcloud/application_default_credentials.json` (never in the repo). One login covers 70K, MDF, and MMF as long as that Google account is a member of each Firebase project. Run `python3 run_reports.py auth google` once (and again if a download returns 401). This is a user refresh token: it does not need weekly reauth, but Google can revoke it (password change, unused for months, or admin policy).

## Configuration fields

| Field | File | Purpose |
| --- | --- | --- |
| `pointer_url` | festivals.json | Production pointer download URL |
| `pointer_path` | festivals.json | Local copy of production pointer |
| `public_data_dir` | festivals.json | Downloaded lineup/schedule CSVs |
| `output_dir` | festivals.json | Reports, JSON backup, CSVs, history |
| `firebase_database_url` | festivals.json | Firebase RTDB base URL (no secret) |
| `firebase_auth_secret` | festivals.secrets.json | Optional fallback if ADC is missing |
| `firebase_service_account` | festivals.secrets.json | Optional per-festival JSON override |
| `dropbox_access_token` | festivals.secrets.json | Optional override; default is promoter_admin OAuth token |
| `reports` | festivals.json | Base HTML filenames (year appended automatically) |

Auth order for each festival: `firebase_service_account` if set, else Google ADC if `~/.config/gcloud/application_default_credentials.json` exists, else `firebase_auth_secret`. Existing 70K/MDF database secrets are left unused while ADC is present.

## CLI

```bash
python3 run_reports.py --festivals 70k          # generate reports
python3 run_reports.py --list                   # list festival ids
python3 run_reports.py auth google              # ADC login for all festivals
python3 run_reports.py auth status
python3 run_reports.py --skip-pointer --skip-firebase --festivals 70k   # fast re-run
```

### Publish report URLs to a pointer file

After generating reports, push Dropbox shared links into the pointer file’s `Current::reportUrl*` entries:

```bash
python3 update_pointer_reports.py --festivals 70k \
  --pointer ~/Dropbox/70K_Reports/productionPointer.txt
```

Uses the Dropbox token from promoter_admin (`OpenMetalFestAdmin/dropbox_auth.json`) and refreshes it automatically when expired. Override with `DROPBOX_ACCESS_TOKEN` or `dropbox_access_token` in `festivals.secrets.json` if needed.

The tool reads `festivals.json` for report filenames and `output_dir`, reads `eventYear` from the chosen pointer file, creates or reuses Dropbox shared links (`?raw=1`) for each report HTML, and updates existing `Current::reportUrl*` lines or adds missing ones. If the pointer lives under `~/Dropbox/`, Dropbox desktop sync uploads it automatically.

| Option | Description |
| --- | --- |
| `--pointer PATH` | Pointer file to update (default: `pointer_path` from config) |
| `--section NAME` | Pointer section (default: `Current`) |
| `--dry-run` | Show URL changes without writing the pointer |

Dropbox app scopes: `files.metadata.read`, `sharing.write` (same as `qa-config/scripts/publish_dropbox_links.py`).

### `run_reports.py` options

| Option | Description |
| --- | --- |
| `--festivals ID …` | Run specific festivals |
| `--dry-run` | Pointer sync only |
| `--skip-pointer` | Use cached pointer/lineup files |
| `--skip-firebase` | Use existing JSON backup |

## Directory layout

```
reporting_tools/
  run_reports.py
  update_pointer_reports.py     # publish report Dropbox URLs into pointer
  run_from_cron.sh
  festivals.example.json          # safe template (committed)
  festivals.secrets.example.json  # safe template (committed)
  festivals.json                  # local config (gitignored)
  festivals.secrets.json          # local secrets (gitignored)
  reporting/
    auth.py                       # credential setup
    config.py, pointer.py, pointer_editor.py, dropbox_links.py, …
    reports/html_reports.py
```

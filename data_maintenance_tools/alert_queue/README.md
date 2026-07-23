# Alert queue (Dropbox `.pending` → FCM)

Cron-friendly monitor that watches local Dropbox alert folders and sends
Firebase Cloud Messaging topic pushes.

| File | Role |
|------|------|
| `sendGoogleMessage.py` | Send one FCM topic message (CLI + library) |
| `monitorMessageQueue.py` | Scan festival folders for `*.pending`, send, rename |
| `message_queue.config.example.yaml` | Template |
| `message_queue.config.yaml` | Live config (local, gitignored) |

## Setup

```bash
cd data_maintenance_tools/alert_queue
./setup.sh
```

This creates `.venv`, installs Python deps, ensures `~/omf_fcm_credentials/`,
and writes a starter `message_queue.config.yaml` next to the scripts if missing.

Scripts auto-use `.venv` when present (`./monitorMessageQueue.py` is enough).
Recreate a broken venv with `./setup.sh --force`.

Then edit that config and place each festival’s Firebase Admin SDK JSON under
`~/omf_fcm_credentials/` (gitignored).

## Manual send

```bash
./sendGoogleMessage.py \
  --credentials ~/omf_fcm_credentials/mdf.json \
  --title "MDF Band Announcement" \
  --topic global \
  --message "Test alert" \
  --dry-run -v
```

## Monitor (cron)

```bash
# Dry-run once (default config: ./message_queue.config.yaml)
./monitorMessageQueue.py --dry-run -v

# Production (non-interactive)
./monitorMessageQueue.py --no-prompt
```

### Dropbox: keep alert folders offline (required on macOS)

If pending files are **cloud-only**, cron fails with
`Resource deadlock avoided`. Right-click each festival's `…_Alert_Files`
folder in Dropbox → **Make available offline**.

Each festival has its own root-level folder: `/{Festival name}_Alert_Files`
(created by promoter_admin). Point `dropbox_dir` in `message_queue.config.yaml`
at the local sync path for that folder only.

### Cron

```cron
*/5 * * * * /Users/YOU/alert_queue/run_from_cron.sh
```

Logs: `~/omf_message_queue.cron.log` and `~/omf_message_queue.log`.## Pending file contract

Admin writes plain-text files such as:

- `bandAnnouncements-YYYY-MM-DD-HH-MM-SS.pending`
- `customAlert-YYYY-MM-DD-HH-MM-SS.pending`

Monitor:

- success → `.completed`
- failure → `.error`

Errors are appended to `~/omf_message_queue.log` (or `log_file` in config).

## Auth notes

- **Preferred for cron:** per-festival service-account JSON (`credentials_file` /
  `credentials_tag`). Download from Firebase Console → Project settings →
  Service accounts. No browser prompt.
- **ADC / OAuth fallback:** if the tagged JSON is missing (or neither
  `credentials_file` nor a matching tag file is set), Application Default
  Credentials are used. Interactively, the tools prompt to run
  `gcloud auth application-default login` once; that writes a shared refresh
  token under `~/.config/gcloud/` — it does **not** create `mdf.json` /
  `google*Auth.json`. Set `project_id` per festival when using ADC across
  multiple Firebase apps.

## Flags

| Flag | Scripts | Meaning |
|------|---------|---------|
| `--dry-run` | both | Do not call FCM (monitor also leaves `.pending`) |
| `--no-prompt` | both | Never prompt for login (use in cron) |
| `-v` / `--verbose` | both | Extra stderr detail |
| `--festival ID` | monitor | Only process that festival id (repeatable) |
| `--credentials` | send | Service-account JSON path |
| `--title` / `--topic` / `--message` | send | Notification fields |

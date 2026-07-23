#!/usr/bin/env bash
# Cron launcher for monitorMessageQueue.py (sets HOME/PATH for ADC + Dropbox).
#
# Crontab:
#   */5 * * * * /Users/YOU/alert_queue/run_from_cron.sh
#
# If you see "Resource deadlock avoided", the Dropbox folder is likely
# cloud-only — Make available offline on each festival …_Alert_Files folder.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

# Account that owns this script (same user that ran ADC login / Dropbox).
export HOME="$(python3 -c 'import os,pwd; print(pwd.getpwuid(os.getuid()).pw_dir)')"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"
export LANG="${LANG:-en_US.UTF-8}"

VENV_PY="$ROOT/.venv/bin/python"
CRON_LOG="${HOME}/omf_message_queue.cron.log"

{
  echo "===== $(date -u '+%Y-%m-%d %H:%M:%S UTC') cron run ====="
  echo "ROOT=$ROOT"
  echo "HOME=$HOME USER=$(id -un)"
  ADC="${HOME}/.config/gcloud/application_default_credentials.json"
  if [[ -f "$ADC" ]]; then
    echo "ADC: present ($ADC)"
  else
    echo "ADC: MISSING ($ADC)"
    echo "     Run once in Terminal: gcloud auth application-default login"
  fi
  if [[ ! -x "$VENV_PY" ]]; then
    echo "error: missing $VENV_PY — run $ROOT/setup.sh"
    exit 1
  fi
  "$VENV_PY" "$ROOT/monitorMessageQueue.py" --no-prompt "$@"
  echo "exit=$?"
} >>"$CRON_LOG" 2>&1

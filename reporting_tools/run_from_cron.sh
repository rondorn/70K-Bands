#!/usr/bin/env bash
# Cron launcher for reporting_tools (sets HOME/PATH for Google ADC + Dropbox).
#
# Crontab example (daily at 6 AM):
#   0 6 * * * /Users/rdorn/personalGit/70K-Bands/reporting_tools/run_from_cron.sh
#
# First-time setup:
#   cd reporting_tools && ./setup.sh
#   python3 run_reports.py auth google

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

export HOME="$(python3 -c 'import os,pwd; print(pwd.getpwuid(os.getuid()).pw_dir)')"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"
export LANG="${LANG:-en_US.UTF-8}"

VENV_PY="$ROOT/.venv/bin/python"
CRON_LOG="${HOME}/70k_reports.cron.log"

{
  echo "===== $(date -u '+%Y-%m-%d %H:%M:%S UTC') cron run ====="
  echo "ROOT=$ROOT"
  echo "HOME=$HOME USER=$(id -un)"
  ADC="${HOME}/.config/gcloud/application_default_credentials.json"
  if [[ -f "$ADC" ]]; then
    echo "Google ADC: present ($ADC)"
  else
    echo "Google ADC: missing ($ADC) — optional unless using Google Cloud APIs directly"
  fi
  if [[ ! -f "$ROOT/festivals.secrets.json" ]]; then
    echo "error: missing festivals.secrets.json — run: python3 run_reports.py auth setup"
    exit 1
  fi
  PY="$VENV_PY"
  if [[ ! -x "$PY" ]]; then
    PY="python3"
  fi
  "$PY" "$ROOT/run_reports.py" --festivals 70k "$@"
  echo "exit=$?"
} >>"$CRON_LOG" 2>&1

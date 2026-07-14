#!/usr/bin/env bash
# Install prerequisites for alert_queue (FCM pending-file monitor).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

echo "==> alert_queue setup ($ROOT)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 not found. Install Python 3.9+ and re-run." >&2
  exit 1
fi

PY_VER="$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
PY_MAJOR="$(python3 -c 'import sys; print(sys.version_info[0])')"
PY_MINOR="$(python3 -c 'import sys; print(sys.version_info[1])')"
if [[ "$PY_MAJOR" -lt 3 || "$PY_MINOR" -lt 9 ]]; then
  echo "error: Python 3.9+ required (found $PY_VER)." >&2
  exit 1
fi
echo "    python3 $PY_VER"

if ! python3 -c 'import venv' >/dev/null 2>&1; then
  echo "error: Python venv module missing. On Debian/Ubuntu: apt install python3-venv" >&2
  exit 1
fi

VENV="$ROOT/.venv"
if [[ ! -d "$VENV" ]]; then
  echo "==> creating virtualenv at .venv"
  python3 -m venv "$VENV"
else
  echo "==> reusing existing .venv"
fi

# shellcheck disable=SC1091
source "$VENV/bin/activate"

echo "==> upgrading pip"
python -m pip install --upgrade pip wheel >/dev/null

echo "==> installing requirements.txt"
python -m pip install -r "$ROOT/requirements.txt"

echo "==> verifying imports"
python - <<'PY'
import firebase_admin
import google.auth
import yaml
print("ok: firebase_admin", firebase_admin.__version__ if hasattr(firebase_admin, "__version__") else "")
print("ok: google.auth")
print("ok: PyYAML")
PY

chmod +x "$ROOT/sendGoogleMessage.py" "$ROOT/monitorMessageQueue.py" "$ROOT/setup.sh"

CONFIG_EXAMPLE="$ROOT/message_queue.config.example.yaml"
CREDS_DIR="${HOME}/omf_fcm_credentials"
LIVE_CONFIG="$ROOT/message_queue.config.yaml"
LEGACY_CONFIG="${HOME}/omf/message_queue.config.yaml"

mkdir -p "$CREDS_DIR"
echo "==> ensured credentials dir: $CREDS_DIR"

if [[ ! -f "$LIVE_CONFIG" ]]; then
  if [[ -f "$LEGACY_CONFIG" ]]; then
    cp "$LEGACY_CONFIG" "$LIVE_CONFIG"
    echo "==> migrated config from $LEGACY_CONFIG"
    echo "    → $LIVE_CONFIG"
  else
    cp "$CONFIG_EXAMPLE" "$LIVE_CONFIG"
    echo "==> wrote starter config: $LIVE_CONFIG"
  fi
  echo "    edit this file before running the monitor"
else
  echo "==> keeping existing config: $LIVE_CONFIG"
fi

if command -v gcloud >/dev/null 2>&1; then
  echo "==> gcloud found ($(command -v gcloud))"
  echo "    optional ADC login (only if you are not using service-account JSON):"
  echo "      gcloud auth application-default login"
else
  echo "note: gcloud CLI not found."
  echo "      Service-account JSON per festival is enough for cron."
  echo "      ADC/OAuth fallback needs: https://cloud.google.com/sdk/docs/install"
fi

echo
echo "Setup complete."
echo "Activate later with:"
echo "  source $VENV/bin/activate"
echo
echo "Dry-run monitor:"
echo "  $VENV/bin/python $ROOT/monitorMessageQueue.py --config $LIVE_CONFIG --dry-run -v"
echo
echo "Cron (every 5 min, non-interactive):"
echo "  */5 * * * * $VENV/bin/python $ROOT/monitorMessageQueue.py --config $LIVE_CONFIG --no-prompt"

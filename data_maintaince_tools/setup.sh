#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 is required. Install from https://www.python.org/downloads/" >&2
  exit 1
fi

echo "Creating virtual environment in .venv ..."
python3 -m venv .venv

# shellcheck disable=SC1091
source .venv/bin/activate

python -m pip install --upgrade pip
pip install -r requirements.txt

if [ ! -f festival_data_entry.json ]; then
  cp festival_data_entry.example.json festival_data_entry.json
  echo "Created festival_data_entry.json from example."
fi

mkdir -p data

echo ""
echo "Setup complete."
echo "Start the app:  ./run.sh"
echo "Or:             ./run.sh --open-browser"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [ ! -d .venv ]; then
  echo "First-time setup required."
  ./setup.sh
fi

# shellcheck disable=SC1091
source .venv/bin/activate
exec python run_data_entry.py "$@"

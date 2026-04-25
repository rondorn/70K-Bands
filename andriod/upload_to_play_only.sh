#!/bin/bash
#
# Upload existing release AABs to Google Play only (no Gradle build).
# Use when debugging: "Google Api Error ... caller does not have permission"
#
# Prerequisites:
#   - .env with GOOGLE_PLAY_SERVICE_ACCOUNT_JSON
#   - AABs already at app/build/outputs/bundle/*Release/*.aab
#   - Service account invited in Play Console → Users and permissions (see .env.example)
#
# Usage:
#   ./upload_to_play_only.sh VERSION_CODE [track] [rollout]
#
# Examples:
#   ./upload_to_play_only.sh 302603500
#   ./upload_to_play_only.sh 302603500 internal 1.0
#   ./upload_to_play_only.sh 302603500 production 1.0
#
# release_notes.json in this directory is used if present; otherwise a minimal en-US stub is written.
#
# One-liner (from andriod/, after .env loaded — replace JSON path and values):
#   bundle exec fastlane upload_to_play_only version_code:302603500 release_notes_json:"$(cat release_notes.json)" track:internal rollout:1.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VERSION_CODE="${1:?Usage: $0 VERSION_CODE [track] [rollout — default internal / 1.0]}"
TRACK="${2:-internal}"
ROLLOUT="${3:-1.0}"

if [ ! -f ".env" ]; then
    echo "Error: .env not found. Copy from .env.example"
    exit 1
fi

set -a
# shellcheck source=/dev/null
source .env
set +a

if [ ! -f "$GOOGLE_PLAY_SERVICE_ACCOUNT_JSON" ]; then
    echo "Error: GOOGLE_PLAY_SERVICE_ACCOUNT_JSON file not found: $GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"
    exit 1
fi

if [ ! -f "release_notes.json" ]; then
    echo '{"en-US":"Upload test"}' > release_notes.json
    echo "Wrote minimal release_notes.json (edit or replace for real text)"
fi

# Single-line JSON avoids edge cases with newlines in shell → fastlane
RELEASE_NOTES_JSON="$(python3 -c "import json; print(json.dumps(json.load(open('release_notes.json'))))")"

if [ -f "Gemfile" ] && command -v bundle >/dev/null 2>&1; then
    FASTLANE=(bundle exec fastlane)
else
    FASTLANE=(fastlane)
fi

echo "Upload only — versionCode ${VERSION_CODE}, track ${TRACK}, rollout ${ROLLOUT}"
echo "AABs expected under app/build/outputs/bundle/"
echo ""

"${FASTLANE[@]}" upload_to_play_only \
    version_code:"$VERSION_CODE" \
    release_notes_json:"$RELEASE_NOTES_JSON" \
    track:"$TRACK" \
    rollout:"$ROLLOUT"

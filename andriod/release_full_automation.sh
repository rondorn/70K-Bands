#!/bin/bash
#
# Full Release Automation - Build, Upload, Release notes, Submit
#
# Usage:
#   ./release_full_automation.sh                  # all apps (70K, MDF, MMF)
#   ./release_full_automation.sh -70k             # only 70K Bands
#   ./release_full_automation.sh -mdf             # only MDF Bands
#   ./release_full_automation.sh -mmf             # only MMF Bands
#   ./release_full_automation.sh -70k -mdf        # exclude MMF while Play setup pending
#   ./release_full_automation.sh --serial         # build/upload one at a time
#
# This script:
# 1. Builds AAB files for selected app flavors (parallel by default)
# 2. Uploads to Google Play Console (serial — Play API / fastlane are not parallel-safe)
# 3. Writes en-US (default listing) changelog only — same as manual production
# 4. Updates metadata
# 5. Submits for review (or leaves as draft)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DO_70K=false
DO_MDF=false
DO_MMF=false
FESTIVAL_FILTER=false
PARALLEL=true
LOG_DIR="./build/release-logs"

usage() {
    echo "Build, upload, and release selected Android festival apps to Google Play."
    echo ""
    echo "Options:"
    echo "  (none)           Build and release all apps (70K, MDF, MMF)."
    echo "  -70k              Only 70K Bands."
    echo "  -mdf              Only MDF Bands."
    echo "  -mmf              Only MMF Bands."
    echo "  -70k -mdf -mmf    Combine festival flags to limit which apps run."
    echo "  --serial         Build one app at a time (uploads always run serially)."
    echo "  --help, -h       Show this help."
    echo ""
}

selected_apps_label() {
    local labels=()
    if [ "$DO_70K" = true ]; then
        labels+=("70K Bands")
    fi
    if [ "$DO_MDF" = true ]; then
        labels+=("MDF Bands")
    fi
    if [ "$DO_MMF" = true ]; then
        labels+=("MMF Bands")
    fi
    local result=""
    for label in "${labels[@]}"; do
        if [ -n "$result" ]; then
            result+=", "
        fi
        result+="$label"
    done
    echo "$result"
}

run_build_job() {
    local label="$1"
    local task="$2"
    local log_file="$LOG_DIR/${task}.log"

    mkdir -p "$LOG_DIR"
    echo -e "${BLUE}Building ${label} AAB…${NC} (log: ${log_file})"
    if ./gradlew "$task" "${GRADLE_SIGNING[@]}" >"$log_file" 2>&1; then
        echo -e "${GREEN}✓ ${label} built${NC}"
        return 0
    fi
    echo -e "${RED}✗ ${label} build failed — see ${log_file}${NC}"
    tail -n 40 "$log_file" || true
    return 1
}

run_build_jobs_parallel() {
    local -a pids=()
    local job label task

    for job in "$@"; do
        IFS='|' read -r label task <<< "$job"
        run_build_job "$label" "$task" &
        pids+=($!)
    done

    local failed=0
    local pid
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            failed=1
        fi
    done
    return $failed
}

run_build_jobs_serial() {
    local job label task
    local failed=0

    for job in "$@"; do
        IFS='|' read -r label task <<< "$job"
        run_build_job "$label" "$task" || failed=1
    done
    return $failed
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

while [ $# -gt 0 ]; do
    case "$1" in
        --help | -h)
            usage
            exit 0
            ;;
        --serial)
            PARALLEL=false
            ;;
        -70k)
            DO_70K=true
            FESTIVAL_FILTER=true
            ;;
        -mdf)
            DO_MDF=true
            FESTIVAL_FILTER=true
            ;;
        -mmf)
            DO_MMF=true
            FESTIVAL_FILTER=true
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
    shift
done

if [ "$FESTIVAL_FILTER" = false ]; then
    DO_70K=true
    DO_MDF=true
    DO_MMF=true
fi

if [ "$DO_70K" = false ] && [ "$DO_MDF" = false ] && [ "$DO_MMF" = false ]; then
    echo -e "${RED}Error: no apps selected. Use -70k, -mdf, and/or -mmf, or omit flags for all apps.${NC}"
    usage
    exit 1
fi

SELECTED_APPS="$(selected_apps_label)"
APP_NAMES_FOR_FASTLANE="$(selected_apps_label)"

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  Festival Apps Full Release ($SELECTED_APPS)"
echo "══════════════════════════════════════════════════════════"
echo ""

if [ ! -f ".env" ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please create .env file from .env.example"
    exit 1
fi

set -a
# shellcheck source=/dev/null
source .env
set +a

GRADLE_SIGNING=(
    -Pandroid.injected.signing.store.file="$ANDROID_KEYSTORE_PATH"
    -Pandroid.injected.signing.store.password="$ANDROID_STORE_PASSWORD"
    -Pandroid.injected.signing.key.alias="$ANDROID_KEY_ALIAS"
    -Pandroid.injected.signing.key.password="$ANDROID_KEY_PASSWORD"
)

if [ ! -f "$GOOGLE_PLAY_SERVICE_ACCOUNT_JSON" ]; then
    echo -e "${RED}Error: Google Play service account JSON not found${NC}"
    echo "Expected at: $GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"
    exit 1
fi

if [ ! -f "$ANDROID_KEYSTORE_PATH" ]; then
    echo -e "${RED}Error: Android keystore not found${NC}"
    echo "Expected at: $ANDROID_KEYSTORE_PATH"
    exit 1
fi

PREV_VALUES_FILE=".release_previous_values"
if [ -f "$PREV_VALUES_FILE" ]; then
    # shellcheck source=/dev/null
    source "$PREV_VALUES_FILE"
fi

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 1: Version Information${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

DEFAULT_VERSION_CODE=""
if [ -n "$PREV_VERSION_CODE" ] && [[ "$PREV_VERSION_CODE" =~ ^[0-9]+$ ]]; then
    DEFAULT_VERSION_CODE=$((PREV_VERSION_CODE + 1))
    echo -e "${BLUE}Suggested version code (previous ${PREV_VERSION_CODE} + 1):${NC} ${DEFAULT_VERSION_CODE}"
    echo ""
fi

if [ -n "$DEFAULT_VERSION_CODE" ]; then
    read -r -p "Enter the version code [${DEFAULT_VERSION_CODE}]: " VERSION_CODE
    VERSION_CODE="${VERSION_CODE:-$DEFAULT_VERSION_CODE}"
else
    read -r -p "Enter the version code (e.g., 302601240): " VERSION_CODE
fi

if [ -z "$VERSION_CODE" ]; then
    echo -e "${RED}Error: Version code required${NC}"
    exit 1
fi

if [ -n "$PREV_VERSION_NAME" ]; then
    read -r -p "Enter the version name [$PREV_VERSION_NAME]: " VERSION_NAME
    VERSION_NAME="${VERSION_NAME:-$PREV_VERSION_NAME}"
else
    read -r -p "Enter the version name (e.g., 26.18): " VERSION_NAME
fi

if [ -z "$VERSION_NAME" ]; then
    echo -e "${RED}Error: Version name required${NC}"
    exit 1
fi

echo -e "${BLUE}Will use version: ${VERSION_NAME} (code ${VERSION_CODE})${NC}"
echo ""

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 2: What's New${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ -n "$PREV_RELEASE_NOTES" ]; then
    echo "Previous release notes:"
    echo -e "${YELLOW}$PREV_RELEASE_NOTES${NC}"
    echo ""
    read -r -p "Use previous notes? (y/n): " USE_PREV_NOTES
    if [[ "$USE_PREV_NOTES" =~ ^[Yy]$ ]]; then
        RELEASE_NOTES="$PREV_RELEASE_NOTES"
        echo -e "${GREEN}✓ Using previous release notes${NC}"
    else
        echo ""
        echo "Enter new release notes in English (Ctrl+D when done):"
        echo ""
        RELEASE_NOTES=$(cat)
    fi
else
    echo "Enter release notes in English (Ctrl+D when done):"
    echo ""
    RELEASE_NOTES=$(cat)
fi

if [ -z "$RELEASE_NOTES" ]; then
    echo -e "${RED}Error: Release notes required${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Release notes captured${NC}"
echo ""

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 3: Release Track${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Release tracks:"
echo "  1) internal - Internal testing"
echo "  2) alpha - Closed testing"
echo "  3) beta - Open testing"
echo "  4) production - Production"
echo ""
read -r -p "Select track [4]: " TRACK_CHOICE
TRACK_CHOICE="${TRACK_CHOICE:-4}"

case $TRACK_CHOICE in
    1) RELEASE_TRACK="internal";;
    2) RELEASE_TRACK="alpha";;
    3) RELEASE_TRACK="beta";;
    4) RELEASE_TRACK="production";;
    *) RELEASE_TRACK="production";;
esac

echo -e "${BLUE}Using track: ${RELEASE_TRACK}${NC}"
echo ""

ROLLOUT_PERCENTAGE="1.0"
if [ "$RELEASE_TRACK" = "production" ]; then
    read -r -p "Rollout percentage (0.0-1.0) [1.0 = 100%]: " ROLLOUT_INPUT
    ROLLOUT_PERCENTAGE="${ROLLOUT_INPUT:-1.0}"
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 4: Updating Build Configuration${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

sed -i.bak "s/versionCode [0-9]*/versionCode $VERSION_CODE/" app/build.gradle
sed -i.bak "s/versionName \"[^\"]*\"/versionName \"$VERSION_NAME\"/" app/build.gradle
rm app/build.gradle.bak

echo -e "${GREEN}✓ Build configuration updated${NC}"
echo ""

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 5: Building Apps${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

./gradlew clean

build_jobs=()
if [ "$DO_70K" = true ]; then
    build_jobs+=("70K Bands|bundleBands70kRelease")
fi
if [ "$DO_MDF" = true ]; then
    build_jobs+=("MDF Bands|bundleMdfbandsRelease")
fi
if [ "$DO_MMF" = true ]; then
    build_jobs+=("MMF Bands|bundleMmfbandsRelease")
fi

if [ "$PARALLEL" = true ] && [ "${#build_jobs[@]}" -gt 1 ]; then
    echo -e "${BLUE}Building ${#build_jobs[@]} apps in parallel (use --serial to disable)${NC}"
    echo ""
    run_build_jobs_parallel "${build_jobs[@]}" || exit 1
else
    run_build_jobs_serial "${build_jobs[@]}" || exit 1
fi
echo ""

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 6: Release notes (default Play language)${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

python3 scripts/release_notes_en_only.py "$RELEASE_NOTES" --output release_notes.json

echo -e "${GREEN}✓ release_notes.json ready${NC}"
echo ""

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Release Summary${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Version Name:${NC}      $VERSION_NAME"
echo -e "${BLUE}Version Code:${NC}      $VERSION_CODE"
echo -e "${BLUE}Apps:${NC}              $SELECTED_APPS"
echo -e "${BLUE}Track:${NC}             $RELEASE_TRACK"
echo -e "${BLUE}Rollout:${NC}           $(echo "$ROLLOUT_PERCENTAGE * 100" | bc)%"
echo -e "${BLUE}Parallel builds:${NC} $PARALLEL"
echo -e "${BLUE}Release notes:${NC}"
echo "$RELEASE_NOTES"
echo ""
echo "This script will now:"
echo "  • Upload AAB files to Google Play Console"
echo "  • Write Play changelog for en-US only (default listing language)"
echo "  • Set to $RELEASE_TRACK track"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
read -r -p "Proceed? (y/n): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 7: Uploading to Google Play Console${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

RELEASE_NOTES_JSON="$(python3 -c "import json; print(json.dumps(json.load(open('release_notes.json'))))")"

if [ -f "Gemfile" ] && command -v bundle >/dev/null 2>&1; then
    FASTLANE=(bundle exec fastlane)
else
    FASTLANE=(fastlane)
fi

"${FASTLANE[@]}" release_all_apps \
    version_name:"$VERSION_NAME" \
    version_code:"$VERSION_CODE" \
    release_notes_json:"$RELEASE_NOTES_JSON" \
    track:"$RELEASE_TRACK" \
    rollout:"$ROLLOUT_PERCENTAGE" \
    app_names:"$APP_NAMES_FOR_FASTLANE"

cat > "$PREV_VALUES_FILE" << EOF
PREV_VERSION_CODE="$VERSION_CODE"
PREV_VERSION_NAME="$VERSION_NAME"
PREV_RELEASE_NOTES="$RELEASE_NOTES"
EOF

echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  All selected apps released successfully!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}What happened:${NC}"
echo "  ✓ Built and signed AAB files for: $SELECTED_APPS"
echo "  ✓ Uploaded to Google Play Console"
echo "  ✓ Release notes applied for en-US (default listing language)"
echo "  ✓ Metadata updated for selected apps"
echo "  ✓ Released to $RELEASE_TRACK track"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  • Check Google Play Console: https://play.google.com/console"
echo "  • Monitor rollout status"
if [ "$RELEASE_TRACK" != "production" ]; then
    echo "  • Promote to production when ready"
fi
echo ""

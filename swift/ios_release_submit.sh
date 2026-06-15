#!/bin/bash
#
# After binaries are in App Store Connect: translate “What’s New”, attach builds to the
# version, update metadata, optionally submit for review (fastlane deliver).
#
# Usage:
#   ./ios_release_submit.sh                  # all apps (70K, MDF, MMF)
#   ./ios_release_submit.sh -70k             # only 70K Bands
#   ./ios_release_submit.sh -mdf             # only MDF Bands
#   ./ios_release_submit.sh -mmf             # only MMF Bands
#   ./ios_release_submit.sh -70k -mdf        # 70K + MDF (exclude MMF while ASC setup pending)
#
# Run ./ios_archive_upload.sh first (or upload via Xcode). Wait until builds are “Complete”.

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

usage() {
    echo "Update App Store Connect metadata and optionally submit for review."
    echo ""
    echo "Options:"
    echo "  (none)           Process all apps (70K Bands, MDF Bands, MMF Bands)."
    echo "  -70k              Only 70K Bands."
    echo "  -mdf              Only MDF Bands."
    echo "  -mmf              Only MMF Bands."
    echo "  -70k -mdf -mmf    Combine festival flags to limit which apps run."
    echo "  --help, -h       Show this help."
    echo ""
    echo "Run ./ios_archive_upload.sh first with matching flags, then this script."
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

while [ $# -gt 0 ]; do
    case "$1" in
        --help | -h)
            usage
            exit 0
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
echo "  iOS — Release metadata & submit ($SELECTED_APPS)"
echo "══════════════════════════════════════════════════════════"
echo ""

if [ ! -f ".env" ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

set -a
# shellcheck source=/dev/null
source .env
set +a

command -v fastlane >/dev/null 2>&1 || {
    echo -e "${RED}Error: fastlane not installed (e.g. brew install fastlane)${NC}"
    exit 1
}

command -v python3 >/dev/null 2>&1 || {
    echo -e "${RED}Error: python3 not found${NC}"
    exit 1
}

python3 -c "import requests" 2>/dev/null || {
    echo -e "${YELLOW}Installing Python requests…${NC}"
    pip3 install requests
}

if [ ! -f "apps_config.json" ]; then
    echo -e "${RED}Error: apps_config.json not found${NC}"
    exit 1
fi

APP_COUNT=0
APP_LIST=""
while IFS= read -r line; do
    if [ "$APP_COUNT" -eq 0 ]; then
        APP_COUNT="$line"
    else
        APP_LIST="${APP_LIST}${line}"$'\n'
    fi
done < <(python3 -c "
import json
selected = [s.strip() for s in '''$SELECTED_APPS'''.split(',') if s.strip()]
with open('apps_config.json', 'r') as f:
    config = json.load(f)
apps = [app for app in config['apps'] if app.get('enabled', True) and app['name'] in selected]
print(len(apps))
for app in apps:
    print(f\"  • {app['name']}\")
")

echo -e "${BLUE}Apps:${NC}"
printf "%s" "$APP_LIST"
echo ""

PREV_VALUES_FILE=".release_previous_values"
if [ -f "$PREV_VALUES_FILE" ]; then
    # shellcheck source=/dev/null
    source "$PREV_VALUES_FILE"
fi

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Version (must match the uploaded build)${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Use the App Store version you uploaded and the BUILD number from App Store Connect → Activity."
echo ""

if [ -n "$PREV_VERSION" ]; then
    read -r -p "App Store version [$PREV_VERSION]: " VERSION
    VERSION="${VERSION:-$PREV_VERSION}"
else
    read -r -p "App Store version (e.g. 26.18): " VERSION
fi

if [ -z "$VERSION" ]; then
    echo -e "${RED}Error: version required${NC}"
    exit 1
fi

if [ -n "$PREV_BUILD_NUMBER" ]; then
    read -r -p "Build number (BUILD column in Activity) [$PREV_BUILD_NUMBER]: " BUILD_NUMBER
    BUILD_NUMBER="${BUILD_NUMBER:-$PREV_BUILD_NUMBER}"
else
    read -r -p "Build number (BUILD column in Activity): " BUILD_NUMBER
fi

if [ -z "$BUILD_NUMBER" ]; then
    echo -e "${RED}Error: build number required${NC}"
    exit 1
fi

echo -e "${BLUE}Using version ${VERSION} (build ${BUILD_NUMBER})${NC}"
echo ""

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}What’s New (English)${NC}"
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
    echo -e "${RED}Error: release notes required${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Submission${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
read -r -p "Submit selected apps for review after metadata update? (y/n): " SUBMIT_CHOICE

SUBMIT_FOR_REVIEW=false
if [[ "$SUBMIT_CHOICE" =~ ^[Yy]$ ]]; then
    SUBMIT_FOR_REVIEW=true
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Translating release notes${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

TRANSLATION_SERVICE="google"
if [ -n "$DEEPL_API_KEY" ]; then
    TRANSLATION_SERVICE="deepl"
fi

echo "Service: $TRANSLATION_SERVICE (locales from apps_config.json)"
echo ""

python3 translate_release_notes.py \
    "$RELEASE_NOTES" \
    --config apps_config.json \
    --service "$TRANSLATION_SERVICE" \
    --output release_notes.json

echo -e "${GREEN}✓ Wrote release_notes.json${NC}"
echo ""

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Confirm uploads${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Selected apps must show in App Store Connect → Activity for version ${VERSION} (processing complete)."
echo ""
read -r -p "Are the selected builds uploaded and processed? (y/n): " UPLOADED

if [[ ! "$UPLOADED" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Run ios_archive_upload.sh (or upload in Xcode), wait for processing, then run this script again.${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Version:${NC}  $VERSION"
echo -e "${BLUE}Build:${NC}    $BUILD_NUMBER"
echo -e "${BLUE}Apps:${NC}     $SELECTED_APPS"
echo -e "${BLUE}Submit:${NC}   $SUBMIT_FOR_REVIEW"
echo -e "${BLUE}Notes:${NC}"
echo "$RELEASE_NOTES"
echo ""
read -r -p "Update App Store Connect metadata (and submit if chosen)? (y/n): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}fastlane release_all_apps${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

RELEASE_NOTES_JSON=$(cat release_notes.json)

if [ -f "fastlane/Fastfile.metadata_only" ]; then
    cp fastlane/Fastfile fastlane/Fastfile.backup 2>/dev/null || true
    cp fastlane/Fastfile.metadata_only fastlane/Fastfile
fi

fastlane release_all_apps \
    version:"$VERSION" \
    build_number:"$BUILD_NUMBER" \
    release_notes_json:"$RELEASE_NOTES_JSON" \
    submit_for_review:"$SUBMIT_FOR_REVIEW" \
    automatic_release:"true" \
    app_names:"$APP_NAMES_FOR_FASTLANE"

if [ -f "fastlane/Fastfile.backup" ]; then
    mv fastlane/Fastfile.backup fastlane/Fastfile
fi

cat > "$PREV_VALUES_FILE" << EOF
PREV_VERSION="$VERSION"
PREV_BUILD_NUMBER="$BUILD_NUMBER"
PREV_RELEASE_NOTES="$RELEASE_NOTES"
EOF

echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Done${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}App Store Connect:${NC} https://appstoreconnect.apple.com"
echo ""

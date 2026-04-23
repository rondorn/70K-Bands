#!/bin/bash
#
# After binaries are in App Store Connect: translate “What’s New”, attach builds to the
# version, update metadata, optionally submit for review (fastlane deliver).
#
# Run ./ios_archive_upload.sh first (or upload via Xcode). Wait until builds are “Complete”.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  iOS — Release metadata & submit for review"
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

ENABLED_APPS=$(python3 -c "
import json
with open('apps_config.json', 'r') as f:
    config = json.load(f)
enabled = [app for app in config['apps'] if app.get('enabled', True)]
print(len(enabled))
for app in enabled:
    print(f\"  • {app['name']}\")
")

APP_COUNT=$(echo "$ENABLED_APPS" | head -n 1)
APP_LIST=$(echo "$ENABLED_APPS" | tail -n +2)

echo -e "${BLUE}Apps:${NC}"
echo "$APP_LIST"
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
read -r -p "Submit all enabled apps for review after metadata update? (y/n): " SUBMIT_CHOICE

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
echo "Both apps must show in App Store Connect → Activity for version ${VERSION} (processing complete)."
echo ""
read -r -p "Are both builds uploaded and processed? (y/n): " UPLOADED

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
echo -e "${BLUE}Apps:${NC}     $APP_COUNT"
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
    automatic_release:"true"

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

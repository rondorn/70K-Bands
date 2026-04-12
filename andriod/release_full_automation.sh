#!/bin/bash
#
# Full Release Automation - Build, Upload, Release notes, Submit
#
# This script:
# 1. Builds AAB files for both app flavors
# 2. Uploads to Google Play Console
# 3. Writes en-US (default listing) changelog only — same as manual production
# 4. Updates metadata
# 5. Submits for review (or leaves as draft)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  🎸 Festival Apps Full Release Automation (Android)"
echo "══════════════════════════════════════════════════════════"
echo ""

# Load environment
if [ ! -f ".env" ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please create .env file from .env.example"
    exit 1
fi

set -a
source .env
set +a

# Verify required files exist
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

# Load previous values if they exist
PREV_VALUES_FILE=".release_previous_values"
if [ -f "$PREV_VALUES_FILE" ]; then
    source "$PREV_VALUES_FILE"
fi

# Get version
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 1: Version Information${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Default version code = last release + 1 (Play requires monotonically increasing versionCode)
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

# Prompt for version name with default
if [ -n "$PREV_VERSION_NAME" ]; then
    read -p "Enter the version name [$PREV_VERSION_NAME]: " VERSION_NAME
    VERSION_NAME="${VERSION_NAME:-$PREV_VERSION_NAME}"
else
    read -p "Enter the version name (e.g., 26.18): " VERSION_NAME
fi

if [ -z "$VERSION_NAME" ]; then
    echo -e "${RED}Error: Version name required${NC}"
    exit 1
fi

echo -e "${BLUE}Will use version: ${VERSION_NAME} (code ${VERSION_CODE})${NC}"
echo ""

# Get release notes
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 2: What's New${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ -n "$PREV_RELEASE_NOTES" ]; then
    echo "Previous release notes:"
    echo -e "${YELLOW}$PREV_RELEASE_NOTES${NC}"
    echo ""
    read -p "Use previous notes? (y/n): " USE_PREV_NOTES
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

# Ask about track and rollout
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
read -p "Select track [4]: " TRACK_CHOICE
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

# Rollout percentage for production
ROLLOUT_PERCENTAGE="1.0"
if [ "$RELEASE_TRACK" = "production" ]; then
    read -p "Rollout percentage (0.0-1.0) [1.0 = 100%]: " ROLLOUT_INPUT
    ROLLOUT_PERCENTAGE="${ROLLOUT_INPUT:-1.0}"
fi

# Update build.gradle with version info
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 4: Updating Build Configuration${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Update version in build.gradle
sed -i.bak "s/versionCode [0-9]*/versionCode $VERSION_CODE/" app/build.gradle
sed -i.bak "s/versionName \"[^\"]*\"/versionName \"$VERSION_NAME\"/" app/build.gradle
rm app/build.gradle.bak

echo -e "${GREEN}✓ Build configuration updated${NC}"
echo ""

# Clean build directory
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 5: Building Apps${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

./gradlew clean

# Build 70K Bands
echo -e "${BLUE}Building 70K Bands AAB...${NC}"
echo ""

./gradlew bundleBands70kRelease \
    -Pandroid.injected.signing.store.file="$ANDROID_KEYSTORE_PATH" \
    -Pandroid.injected.signing.store.password="$ANDROID_STORE_PASSWORD" \
    -Pandroid.injected.signing.key.alias="$ANDROID_KEY_ALIAS" \
    -Pandroid.injected.signing.key.password="$ANDROID_KEY_PASSWORD"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build 70K Bands${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 70K Bands built${NC}"
echo ""

# Build MDF Bands
echo -e "${BLUE}Building MDF Bands AAB...${NC}"
echo ""

./gradlew bundleMdfbandsRelease \
    -Pandroid.injected.signing.store.file="$ANDROID_KEYSTORE_PATH" \
    -Pandroid.injected.signing.store.password="$ANDROID_STORE_PASSWORD" \
    -Pandroid.injected.signing.key.alias="$ANDROID_KEY_ALIAS" \
    -Pandroid.injected.signing.key.password="$ANDROID_KEY_PASSWORD"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build MDF Bands${NC}"
    exit 1
fi

echo -e "${GREEN}✓ MDF Bands built${NC}"
echo ""

# Release notes JSON for Play (default_language from apps_config.json — en-US only)
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 6: Release notes (default Play language)${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

python3 scripts/release_notes_en_only.py "$RELEASE_NOTES" --output release_notes.json

echo -e "${GREEN}✓ release_notes.json ready${NC}"
echo ""

# Show summary
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Release Summary${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Version Name:${NC}      $VERSION_NAME"
echo -e "${BLUE}Version Code:${NC}      $VERSION_CODE"
echo -e "${BLUE}Apps:${NC}              2 (70K Bands, MDF Bands)"
echo -e "${BLUE}Track:${NC}             $RELEASE_TRACK"
echo -e "${BLUE}Rollout:${NC}           $(echo "$ROLLOUT_PERCENTAGE * 100" | bc)%"
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
read -p "Proceed? (y/n): " CONFIRM

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

# Prefer Bundler when Gemfile is present (loads fastlane + plugins consistently)
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
    rollout:"$ROLLOUT_PERCENTAGE"

# Save values for next time
cat > "$PREV_VALUES_FILE" << EOF
PREV_VERSION_CODE="$VERSION_CODE"
PREV_VERSION_NAME="$VERSION_NAME"
PREV_RELEASE_NOTES="$RELEASE_NOTES"
EOF

echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  🎉 All apps released successfully!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}What happened:${NC}"
echo "  ✓ Built and signed AAB files for both apps"
echo "  ✓ Uploaded to Google Play Console"
echo "  ✓ Release notes applied for en-US (default listing language)"
echo "  ✓ Metadata updated for all apps"
echo "  ✓ Released to $RELEASE_TRACK track"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  • Check Google Play Console: https://play.google.com/console"
echo "  • Monitor rollout status"
if [ "$RELEASE_TRACK" != "production" ]; then
    echo "  • Promote to production when ready"
fi
echo ""

#!/bin/bash
#
# Archive 70K Bands + MDF Bands and upload binaries to App Store Connect (no metadata).
# Uses one number for both MARKETING_VERSION and CFBundleVersion (CURRENT_PROJECT_VERSION).
#
# Usage:
#   ./ios_archive_upload.sh                  # clean archive + upload (default)
#   ./ios_archive_upload.sh --archive-only # archive only; keeps build/*.xcarchive
#   ./ios_archive_upload.sh --upload-only  # export + upload using existing archives
#
# Prerequisites: swift/.env (see .env.example), Xcode, CocoaPods resolved, API key .p8 in fastlane/.
# Next step after uploads process: run ./ios_release_submit.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ARCHIVE_70K="./build/70KBands.xcarchive"
ARCHIVE_MDF="./build/MDFBands.xcarchive"

usage() {
    echo "Archive 70K Bands + MDF Bands and upload to App Store Connect (no metadata)."
    echo ""
    echo "Options:"
    echo "  (none)           Clean build/, archive both apps, export + upload."
    echo "  --archive-only   Archive only (no upload). Same clean + xcodebuild archive."
    echo "  -A               Short for --archive-only."
    echo "  --upload-only    Export + upload using existing archives (no rebuild)."
    echo "  -U               Short for --upload-only."
    echo "  --help, -h       Show this help."
    echo ""
    echo "Archives must exist at:"
    echo "  $ARCHIVE_70K"
    echo "  $ARCHIVE_MDF"
    echo ""
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

MODE="full"
while [ $# -gt 0 ]; do
    case "$1" in
        --archive-only | -A)
            MODE="archive-only"
            ;;
        --upload-only | -U)
            MODE="upload-only"
            ;;
        --help | -h)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
    shift
done

if [ "$MODE" = "archive-only" ] || [ "$MODE" = "full" ]; then
    TITLE_SUFFIX="(archive + upload)"
elif [ "$MODE" = "upload-only" ]; then
    TITLE_SUFFIX="(upload only)"
fi

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  iOS — Archive & upload (70K Bands + MDF Bands) $TITLE_SUFFIX"
echo "══════════════════════════════════════════════════════════"
echo ""

if [ ! -f ".env" ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Copy .env.example to .env and fill in credentials."
    exit 1
fi

set -a
# shellcheck source=/dev/null
source .env
set +a

if [ -z "$FASTLANE_TEAM_ID" ] && { [ "$MODE" = "full" ] || [ "$MODE" = "archive-only" ]; }; then
    echo -e "${RED}Error: FASTLANE_TEAM_ID not set in .env${NC}"
    exit 1
fi

if [ "$MODE" = "full" ] || [ "$MODE" = "upload-only" ]; then
    if [ -z "$FASTLANE_APP_STORE_CONNECT_API_KEY_ID" ] || [ -z "$FASTLANE_APP_STORE_CONNECT_API_ISSUER_ID" ]; then
        echo -e "${RED}Error: App Store Connect API key id / issuer id not set in .env${NC}"
        exit 1
    fi

    AUTH_KEY_PATH="${FASTLANE_APP_STORE_CONNECT_API_KEY_PATH:-$SCRIPT_DIR/fastlane/AuthKey_${FASTLANE_APP_STORE_CONNECT_API_KEY_ID}.p8}"
    if [ ! -f "$AUTH_KEY_PATH" ]; then
        echo -e "${RED}Error: API key file not found:${NC} $AUTH_KEY_PATH"
        echo "Set FASTLANE_APP_STORE_CONNECT_API_KEY_PATH in .env or place AuthKey_*.p8 under fastlane/."
        exit 1
    fi
    AUTH_KEY_DIR="$(cd "$(dirname "$AUTH_KEY_PATH")" && pwd)"
    AUTH_KEY_PATH="$AUTH_KEY_DIR/$(basename "$AUTH_KEY_PATH")"
fi

command -v xcodebuild >/dev/null 2>&1 || {
    echo -e "${RED}Error: xcodebuild not found (install Xcode CLI tools)${NC}"
    exit 1
}

PREV_VALUES_FILE=".release_previous_values"
PRESERVE_RELEASE_NOTES=""
if [ -f "$PREV_VALUES_FILE" ]; then
    # shellcheck source=/dev/null
    source "$PREV_VALUES_FILE"
    PRESERVE_RELEASE_NOTES="$PREV_RELEASE_NOTES"
fi

read_version_build_from_archive() {
    local plist="$1"
    VERSION=""
    BUILD_NUMBER=""
    if [ ! -f "$plist" ]; then
        return 1
    fi
    VERSION=$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleShortVersionString' "$plist" 2>/dev/null || true)
    BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleVersion' "$plist" 2>/dev/null || true)
    if [ -z "$VERSION" ] || [ -z "$BUILD_NUMBER" ]; then
        return 1
    fi
    return 0
}

if [ "$MODE" = "upload-only" ]; then
    if [ ! -d "$ARCHIVE_70K" ] || [ ! -d "$ARCHIVE_MDF" ]; then
        echo -e "${RED}Error: missing archive(s).${NC}"
        echo "Expected:"
        echo "  $ARCHIVE_70K"
        echo "  $ARCHIVE_MDF"
        echo "Run ./ios_archive_upload.sh or ./ios_archive_upload.sh --archive-only first."
        exit 1
    fi
    if ! read_version_build_from_archive "${ARCHIVE_70K}/Info.plist"; then
        echo -e "${RED}Error: could not read marketing version / build from ${ARCHIVE_70K}/Info.plist${NC}"
        exit 1
    fi
    echo -e "${BLUE}From 70K archive:${NC} CFBundleVersion / marketing ${BUILD_NUMBER}"
    echo ""
else
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Version (CFBundleVersion = marketing version)${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    DEFAULT_BUNDLE=""
    if [ -n "$PREV_BUILD_NUMBER" ] && [[ "$PREV_BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
        DEFAULT_BUNDLE=$((PREV_BUILD_NUMBER + 1))
    elif [ -n "$PREV_VERSION" ] && [[ "$PREV_VERSION" =~ ^[0-9]+$ ]]; then
        DEFAULT_BUNDLE=$((PREV_VERSION + 1))
    fi

    if [ -n "$DEFAULT_BUNDLE" ]; then
        echo -e "${BLUE}Suggested CFBundleVersion (last + 1):${NC} ${DEFAULT_BUNDLE}"
        echo ""
        read -r -p "CFBundleVersion (MARKETING_VERSION) [${DEFAULT_BUNDLE}]: " INPUT_BUNDLE
        BUNDLE_VERSION="${INPUT_BUNDLE:-$DEFAULT_BUNDLE}"
    else
        read -r -p "CFBundleVersion / marketing version (e.g. 20260124001): " BUNDLE_VERSION
    fi

    if [ -z "$BUNDLE_VERSION" ]; then
        echo -e "${RED}Error: CFBundleVersion required${NC}"
        exit 1
    fi

    VERSION="$BUNDLE_VERSION"
    BUILD_NUMBER="$BUNDLE_VERSION"

    echo -e "${BLUE}Using MARKETING_VERSION and CFBundleVersion:${NC} ${BUNDLE_VERSION}"
    echo ""
fi

if [ "$MODE" = "full" ]; then
    CONFIRM_MSG="Proceed with clean archive + upload for both apps? (y/n): "
elif [ "$MODE" = "archive-only" ]; then
    CONFIRM_MSG="Proceed with clean archive only (no upload)? (y/n): "
else
    CONFIRM_MSG="Re-upload existing archives to App Store Connect? (y/n): "
fi

read -r -p "$CONFIRM_MSG" CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Cancelled${NC}"
    exit 0
fi

if [ "$MODE" = "full" ] || [ "$MODE" = "archive-only" ]; then
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Building${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    rm -rf build/
    mkdir -p build

    echo -e "${BLUE}Archiving 70K Bands…${NC}"
    xcodebuild clean archive \
        -workspace "70K Bands.xcworkspace" \
        -scheme "70K Bands" \
        -configuration Release \
        -archivePath "$ARCHIVE_70K" \
        -destination "generic/platform=iOS" \
        CODE_SIGN_STYLE=Automatic \
        DEVELOPMENT_TEAM="$FASTLANE_TEAM_ID" \
        MARKETING_VERSION="$VERSION" \
        CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

    echo -e "${GREEN}✓ 70K Bands archived${NC}"
    echo ""

    echo -e "${BLUE}Archiving MDF Bands…${NC}"
    xcodebuild clean archive \
        -workspace "70K Bands.xcworkspace" \
        -scheme "MDF Bands" \
        -configuration Release \
        -archivePath "$ARCHIVE_MDF" \
        -destination "generic/platform=iOS" \
        CODE_SIGN_STYLE=Automatic \
        DEVELOPMENT_TEAM="$FASTLANE_TEAM_ID" \
        MARKETING_VERSION="$VERSION" \
        CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

    echo -e "${GREEN}✓ MDF Bands archived${NC}"
    echo ""
fi

if [ "$MODE" = "full" ] || [ "$MODE" = "upload-only" ]; then
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Export & upload to App Store Connect${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    echo -e "${BLUE}Uploading 70K Bands…${NC}"
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_70K" \
        -exportPath "./build/70KBands" \
        -exportOptionsPlist "./exportOptions.plist" \
        -authenticationKeyPath "$AUTH_KEY_PATH" \
        -authenticationKeyID "$FASTLANE_APP_STORE_CONNECT_API_KEY_ID" \
        -authenticationKeyIssuerID "$FASTLANE_APP_STORE_CONNECT_API_ISSUER_ID"

    echo -e "${GREEN}✓ 70K Bands uploaded${NC}"
    echo ""

    echo -e "${BLUE}Uploading MDF Bands…${NC}"
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_MDF" \
        -exportPath "./build/MDFBands" \
        -exportOptionsPlist "./exportOptions.plist" \
        -authenticationKeyPath "$AUTH_KEY_PATH" \
        -authenticationKeyID "$FASTLANE_APP_STORE_CONNECT_API_KEY_ID" \
        -authenticationKeyIssuerID "$FASTLANE_APP_STORE_CONNECT_API_ISSUER_ID"

    echo -e "${GREEN}✓ MDF Bands uploaded${NC}"
    echo ""
fi

cat > "$PREV_VALUES_FILE" << EOF
PREV_VERSION="$VERSION"
PREV_BUILD_NUMBER="$BUILD_NUMBER"
PREV_RELEASE_NOTES="$PRESERVE_RELEASE_NOTES"
EOF

echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
if [ "$MODE" = "archive-only" ]; then
    echo -e "${GREEN}  Archive finished (upload skipped)${NC}"
else
    echo -e "${GREEN}  Upload finished${NC}"
fi
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
echo ""

if [ "$MODE" = "archive-only" ]; then
    echo -e "${BLUE}Next:${NC}"
    echo "  • To upload without rebuilding: ./ios_archive_upload.sh --upload-only"
    echo "  • Or run without flags for a full clean archive + upload."
    echo ""
elif [ "$MODE" = "upload-only" ]; then
    echo -e "${BLUE}Next:${NC}"
    echo "  1. App Store Connect → Activity: wait until both builds show Complete."
    echo "  2. Run ./ios_release_submit.sh (version/build saved in .release_previous_values)."
    echo "  3. https://appstoreconnect.apple.com"
    echo ""
else
    echo -e "${BLUE}Next:${NC}"
    echo "  1. App Store Connect → Activity: wait until both builds show Complete."
    echo "  2. Run ./ios_release_submit.sh to attach builds, set “What’s New”, and optionally submit for review."
    echo "  3. https://appstoreconnect.apple.com"
    echo ""
fi

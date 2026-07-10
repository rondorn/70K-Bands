#!/bin/bash
#
# Archive 70K Bands, MDF Bands, and MMF Bands; upload binaries to App Store Connect (no metadata).
# Uses one number for both MARKETING_VERSION and CFBundleVersion (CURRENT_PROJECT_VERSION).
#
# Usage:
#   ./ios_archive_upload.sh                  # clean archive + upload all apps (default)
#   ./ios_archive_upload.sh -70k             # only 70K Bands
#   ./ios_archive_upload.sh -mdf             # only MDF Bands
#   ./ios_archive_upload.sh -mmf             # only MMF Bands
#   ./ios_archive_upload.sh -70k -mmf        # 70K + MMF only
#   ./ios_archive_upload.sh --archive-only   # archive only; keeps build/*.xcarchive
#   ./ios_archive_upload.sh --upload-only    # export + upload using existing archives
#   ./ios_archive_upload.sh --serial         # archive/upload one app at a time (debug)
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
ARCHIVE_MMF="./build/MMFBands.xcarchive"

DO_70K=false
DO_MDF=false
DO_MMF=false
FESTIVAL_FILTER=false
PARALLEL=true
LOG_DIR="./build/logs"

usage() {
    echo "Archive 70K Bands, MDF Bands, and MMF Bands; upload to App Store Connect (no metadata)."
    echo ""
    echo "Options:"
    echo "  (none)           Clean build/, archive all apps, export + upload."
    echo "  -70k              Only 70K Bands."
    echo "  -mdf              Only MDF Bands."
    echo "  -mmf              Only MMF Bands."
    echo "  -70k -mdf -mmf    Combine festival flags to limit which apps run."
    echo "  --archive-only   Archive only (no upload). Same clean + xcodebuild archive."
    echo "  -A               Short for --archive-only."
    echo "  --upload-only    Export + upload using existing archives (no rebuild)."
    echo "  -U               Short for --upload-only."
    echo "  --serial         Archive/upload apps one at a time (default is parallel)."
    echo "  --help, -h       Show this help."
    echo ""
    echo "Archives:"
    echo "  $ARCHIVE_70K"
    echo "  $ARCHIVE_MDF"
    echo "  $ARCHIVE_MMF"
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

MODE="full"
while [ $# -gt 0 ]; do
    case "$1" in
        --archive-only | -A)
            MODE="archive-only"
            ;;
        --upload-only | -U)
            MODE="upload-only"
            ;;
        --serial)
            PARALLEL=false
            ;;
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

if [ "$MODE" = "archive-only" ] || [ "$MODE" = "full" ]; then
    TITLE_SUFFIX="(archive + upload)"
elif [ "$MODE" = "upload-only" ]; then
    TITLE_SUFFIX="(upload only)"
fi

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  iOS — Archive & upload ($SELECTED_APPS) $TITLE_SUFFIX"
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

missing_archives_message() {
    echo -e "${RED}Error: missing archive(s).${NC}"
    echo "Expected:"
    if [ "$DO_70K" = true ]; then
        echo "  $ARCHIVE_70K"
    fi
    if [ "$DO_MDF" = true ]; then
        echo "  $ARCHIVE_MDF"
    fi
    if [ "$DO_MMF" = true ]; then
        echo "  $ARCHIVE_MMF"
    fi
    echo "Run ./ios_archive_upload.sh or ./ios_archive_upload.sh --archive-only first."
}

archive_app() {
    local label="$1"
    local scheme="$2"
    local archive_path="$3"
    local derived_data_path="./build/DerivedData-${scheme}"

    echo -e "${BLUE}Archiving ${label}…${NC}"
    xcodebuild archive \
        -workspace "70K Bands.xcworkspace" \
        -scheme "$scheme" \
        -configuration Release \
        -archivePath "$archive_path" \
        -derivedDataPath "$derived_data_path" \
        -destination "generic/platform=iOS" \
        CODE_SIGN_STYLE=Automatic \
        DEVELOPMENT_TEAM="$FASTLANE_TEAM_ID" \
        MARKETING_VERSION="$VERSION" \
        CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

    echo -e "${GREEN}✓ ${label} archived${NC}"
    echo ""
}

run_archive_job() {
    local label="$1"
    local scheme="$2"
    local archive_path="$3"
    local log_file="$LOG_DIR/${scheme}-archive.log"

    mkdir -p "$LOG_DIR"
    echo -e "${BLUE}Archiving ${label}…${NC} (log: ${log_file})"
    if archive_app "$label" "$scheme" "$archive_path" >"$log_file" 2>&1; then
        echo -e "${GREEN}✓ ${label} archived${NC}"
        return 0
    fi
    echo -e "${RED}✗ ${label} archive failed — see ${log_file}${NC}"
    tail -n 40 "$log_file" || true
    return 1
}

upload_app() {
    local label="$1"
    local archive_path="$2"
    local export_path="$3"
    local tmp_log
    tmp_log=$(mktemp)

    mkdir -p "$export_path"
    echo -e "${BLUE}Uploading ${label}…${NC}"

    set +e
    xcodebuild -exportArchive \
        -archivePath "$archive_path" \
        -exportPath "$export_path" \
        -exportOptionsPlist "./exportOptions.plist" \
        -authenticationKeyPath "$AUTH_KEY_PATH" \
        -authenticationKeyID "$FASTLANE_APP_STORE_CONNECT_API_KEY_ID" \
        -authenticationKeyIssuerID "$FASTLANE_APP_STORE_CONNECT_API_ISSUER_ID" \
        >"$tmp_log" 2>&1
    local status=$?
    set -e

    cat "$tmp_log"

    local failed=0
    if grep -q '\*\* EXPORT FAILED \*\*' "$tmp_log"; then
        failed=1
    elif [ "$status" -ne 0 ]; then
        failed=1
    elif ! grep -qE '\*\* EXPORT SUCCEEDED \*\*|Upload succeeded' "$tmp_log"; then
        failed=1
    fi

    rm -f "$tmp_log"

    if [ "$failed" -eq 1 ]; then
        echo -e "${RED}✗ ${label} export failed${NC}"
        return 1
    fi

    echo -e "${GREEN}✓ ${label} uploaded${NC}"
    echo ""
}

run_upload_job() {
    local label="$1"
    local archive_path="$2"
    local export_path="$3"
    local safe_label="${label// /-}"
    local log_file="$LOG_DIR/${safe_label}-upload.log"

    mkdir -p "$LOG_DIR"
    echo -e "${BLUE}Uploading ${label}…${NC} (log: ${log_file})"
    if upload_app "$label" "$archive_path" "$export_path" >"$log_file" 2>&1; then
        echo -e "${GREEN}✓ ${label} uploaded${NC}"
        return 0
    fi
    echo -e "${RED}✗ ${label} upload failed — see ${log_file}${NC}"
    tail -n 40 "$log_file" || true
    return 1
}

run_jobs_parallel() {
    local kind="$1"
    shift
    local -a pids=()
    local job label scheme archive_path export_path

    for job in "$@"; do
        if [ "$kind" = "archive" ]; then
            IFS='|' read -r label scheme archive_path <<< "$job"
            run_archive_job "$label" "$scheme" "$archive_path" &
        else
            IFS='|' read -r label archive_path export_path <<< "$job"
            run_upload_job "$label" "$archive_path" "$export_path" &
        fi
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

run_jobs_serial() {
    local kind="$1"
    shift
    local job label scheme archive_path export_path
    local failed=0

    for job in "$@"; do
        if [ "$kind" = "archive" ]; then
            IFS='|' read -r label scheme archive_path <<< "$job"
            run_archive_job "$label" "$scheme" "$archive_path" || failed=1
        else
            IFS='|' read -r label archive_path export_path <<< "$job"
            run_upload_job "$label" "$archive_path" "$export_path" || failed=1
        fi
    done
    return $failed
}

if [ "$MODE" = "upload-only" ]; then
    MISSING=false
    if [ "$DO_70K" = true ] && [ ! -d "$ARCHIVE_70K" ]; then
        MISSING=true
    fi
    if [ "$DO_MDF" = true ] && [ ! -d "$ARCHIVE_MDF" ]; then
        MISSING=true
    fi
    if [ "$DO_MMF" = true ] && [ ! -d "$ARCHIVE_MMF" ]; then
        MISSING=true
    fi
    if [ "$MISSING" = true ]; then
        missing_archives_message
        exit 1
    fi

    VERSION_SOURCE=""
    if [ "$DO_70K" = true ] && read_version_build_from_archive "${ARCHIVE_70K}/Info.plist"; then
        VERSION_SOURCE="70K archive"
    elif [ "$DO_MDF" = true ] && read_version_build_from_archive "${ARCHIVE_MDF}/Info.plist"; then
        VERSION_SOURCE="MDF archive"
    elif [ "$DO_MMF" = true ] && read_version_build_from_archive "${ARCHIVE_MMF}/Info.plist"; then
        VERSION_SOURCE="MMF archive"
    else
        echo -e "${RED}Error: could not read marketing version / build from selected archive(s)${NC}"
        exit 1
    fi
    echo -e "${BLUE}From ${VERSION_SOURCE}:${NC} CFBundleVersion / marketing ${BUILD_NUMBER}"
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
    CONFIRM_MSG="Proceed with clean archive + upload for ${SELECTED_APPS}? (y/n): "
elif [ "$MODE" = "archive-only" ]; then
    CONFIRM_MSG="Proceed with clean archive only for ${SELECTED_APPS} (no upload)? (y/n): "
else
    CONFIRM_MSG="Re-upload existing archives for ${SELECTED_APPS} to App Store Connect? (y/n): "
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

    archive_jobs=()
    if [ "$DO_70K" = true ]; then
        archive_jobs+=("70K Bands|70K Bands|$ARCHIVE_70K")
    fi
    if [ "$DO_MDF" = true ]; then
        archive_jobs+=("MDF Bands|MDF Bands|$ARCHIVE_MDF")
    fi
    if [ "$DO_MMF" = true ]; then
        archive_jobs+=("MMF Bands|MMF Bands|$ARCHIVE_MMF")
    fi

    if [ "$PARALLEL" = true ] && [ "${#archive_jobs[@]}" -gt 1 ]; then
        echo -e "${BLUE}Archiving ${#archive_jobs[@]} apps in parallel (use --serial to disable)${NC}"
        echo ""
        run_jobs_parallel archive "${archive_jobs[@]}" || exit 1
    else
        run_jobs_serial archive "${archive_jobs[@]}" || exit 1
    fi
fi

if [ "$MODE" = "full" ] || [ "$MODE" = "upload-only" ]; then
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Export & upload to App Store Connect${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    upload_jobs=()
    if [ "$DO_70K" = true ]; then
        upload_jobs+=("70K Bands|$ARCHIVE_70K|./build/70KBands")
    fi
    if [ "$DO_MDF" = true ]; then
        upload_jobs+=("MDF Bands|$ARCHIVE_MDF|./build/MDFBands")
    fi
    if [ "$DO_MMF" = true ]; then
        upload_jobs+=("MMF Bands|$ARCHIVE_MMF|./build/MMFBands")
    fi

    if [ "$PARALLEL" = true ] && [ "${#upload_jobs[@]}" -gt 1 ]; then
        echo -e "${BLUE}Uploading ${#upload_jobs[@]} apps in parallel (use --serial to disable)${NC}"
        echo ""
        run_jobs_parallel upload "${upload_jobs[@]}" || exit 1
    else
        run_jobs_serial upload "${upload_jobs[@]}" || exit 1
    fi
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
    echo "  1. App Store Connect → Activity: wait until selected builds show Complete."
    echo "  2. Run ./ios_release_submit.sh (version/build saved in .release_previous_values)."
    echo "  3. https://appstoreconnect.apple.com"
    echo ""
else
    echo -e "${BLUE}Next:${NC}"
    echo "  1. App Store Connect → Activity: wait until selected builds show Complete."
    echo "  2. Run ./ios_release_submit.sh to attach builds, set “What’s New”, and optionally submit for review."
    echo "  3. https://appstoreconnect.apple.com"
    echo ""
fi

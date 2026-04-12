#!/bin/bash
#
# Run QA walkthrough UI tests on the iOS Simulator.
#
# ---------------------------------------------------------------------------
# Command line (preferred)
# ---------------------------------------------------------------------------
#   ./scripts/ios_qa_ui_walkthrough.sh list              # names of runnable tests
#   ./scripts/ios_qa_ui_walkthrough.sh all               # pointer + four-links + ranking
#   ./scripts/ios_qa_ui_walkthrough.sh default             # pointer + four-links only (fast)
#   ./scripts/ios_qa_ui_walkthrough.sh ranking             # ranking test only
#   ./scripts/ios_qa_ui_walkthrough.sh <testMethodName>  # one test, e.g. testChapter1_NarrativeRankingThreeBands_StepwiseVerified
#
# With no arguments, legacy env vars still apply (QA_ONLY_RANKING_TEST, QA_RUN_RANKING_TEST);
# if those are unset, behaves like `default`.
#
# Other docs: `test-without-building` only skips recompilation — see comments in-repo.
#
# Environment (optional):
#   QA_UI_XCODEBUILD_MODE=test|test-without-building
#   QA_UI_ALLOW_TEST_WITHOUT_BUILDING, QA_UI_SKIP_UNINSTALL_BEFORE_TEST, QA_UI_UNINSTALL_BEFORE_TEST
#   SIMULATOR_ID, DESTINATION, SCHEME, WORKSPACE, CONFIGURATION, APP_BUNDLE_ID, FASTLANE_TEAM_ID
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWIFT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$SWIFT_ROOT"

SCHEME="${SCHEME:-70K Bands}"
WORKSPACE="${WORKSPACE:-70K Bands.xcworkspace}"
CONFIGURATION="${CONFIGURATION:-Debug}"
QA_UI_XCODEBUILD_MODE="${QA_UI_XCODEBUILD_MODE:-test-without-building}"

SIMULATOR_ID="${SIMULATOR_ID:-F90FB7D8-F56E-4BBA-9401-902DFF3FB280}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,id=${SIMULATOR_ID}}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.rdorn.-0000TonsBands}"

UITEST_TARGET="70K BandsUITests"
C1="QAWalkthroughChapter1UITests"
C1R="QAWalkthroughChapter1RankingUITests"

T_POINTER="testChapter1_PointerBandsOnly_ShowsFixtureBand"
T_FOUR="testChapter1_BandDetail_FourLinksOpenAndDismissWebSheet"
T_RANK="testChapter1_NarrativeRankingThreeBands_StepwiseVerified"

ONLY_POINTER=( -only-testing:"${UITEST_TARGET}/${C1}/${T_POINTER}" )
ONLY_FOUR=( -only-testing:"${UITEST_TARGET}/${C1}/${T_FOUR}" )
ONLY_RANK=( -only-testing:"${UITEST_TARGET}/${C1R}/${T_RANK}" )

usage() {
    sed -n '1,25p' "$0" | tail -n +2
    echo ""
    echo "Run:  $0 list | all | default | ranking | <testMethodName>"
    echo "Env:  QA_UI_XCODEBUILD_MODE, SIMULATOR_ID, … (see script header)"
}

list_tests() {
    echo "QA UI walkthrough — runnable tests (scheme: ${SCHEME})"
    echo ""
    echo "  Presets:"
    echo "    default    ${T_POINTER} + ${T_FOUR}"
    echo "    all        default + ${T_RANK}"
    echo "    ranking    ${T_RANK} only"
    echo ""
    echo "  Single test (full method name):"
    echo "    ${T_POINTER}"
    echo "    ${T_FOUR}"
    echo "    ${T_RANK}"
    echo ""
    echo "  xcodebuild -only-testing lines:"
    printf '    %s/%s/%s\n' "$UITEST_TARGET" "$C1" "$T_POINTER"
    printf '    %s/%s/%s\n' "$UITEST_TARGET" "$C1" "$T_FOUR"
    printf '    %s/%s/%s\n' "$UITEST_TARGET" "$C1R" "$T_RANK"
}

# Sets: ONLY_TESTING array, INCLUDES_RANKING (0|1)
resolve_command() {
    local raw="${1:-}"
    local cmd
    cmd="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
    INCLUDES_RANKING=0
    case "$cmd" in
        list)
            list_tests
            exit 0
            ;;
        -h|--help|help)
            usage
            exit 0
            ;;
        all)
            ONLY_TESTING=( "${ONLY_POINTER[@]}" "${ONLY_FOUR[@]}" "${ONLY_RANK[@]}" )
            INCLUDES_RANKING=1
            echo "Running all Ch.1 QA UI tests (pointer + four-links + ranking)."
            ;;
        default|smoke)
            ONLY_TESTING=( "${ONLY_POINTER[@]}" "${ONLY_FOUR[@]}" )
            echo "Running default QA UI tests (pointer + four-links)."
            ;;
        ranking|ranking-only)
            ONLY_TESTING=( "${ONLY_RANK[@]}" )
            INCLUDES_RANKING=1
            echo "Running ranking QA UI test only."
            ;;
        *)
            # Exact method name
            case "$raw" in
                "$T_POINTER")
                    ONLY_TESTING=( "${ONLY_POINTER[@]}" )
                    ;;
                "$T_FOUR")
                    ONLY_TESTING=( "${ONLY_FOUR[@]}" )
                    ;;
                "$T_RANK")
                    ONLY_TESTING=( "${ONLY_RANK[@]}" )
                    INCLUDES_RANKING=1
                    ;;
                *)
                    echo "Error: unknown test or preset: $raw"
                    echo "Run:  $0 list"
                    exit 1
                    ;;
            esac
            echo "Running single test: $raw"
            ;;
    esac
    return 0
}

command -v xcodebuild >/dev/null 2>&1 || {
    echo "Error: xcodebuild not found (install Xcode command-line tools)."
    exit 1
}

if [ ! -d "$WORKSPACE" ]; then
    echo "Error: workspace not found: $WORKSPACE"
    echo "From $SWIFT_ROOT run: pod install"
    exit 1
fi

if [ -f ".env" ]; then
    set -a
    # shellcheck source=/dev/null
    source .env
    set +a
fi

# ---- CLI + legacy env -----------------------------------------------------
if [ $# -ge 1 ]; then
    resolve_command "$1"
else
    if [ "${QA_ONLY_RANKING_TEST:-}" = "1" ]; then
        ONLY_TESTING=( "${ONLY_RANK[@]}" )
        INCLUDES_RANKING=1
        echo "Legacy QA_ONLY_RANKING_TEST=1: ranking only."
    elif [ "${QA_RUN_RANKING_TEST:-}" = "1" ]; then
        ONLY_TESTING=( "${ONLY_POINTER[@]}" "${ONLY_FOUR[@]}" "${ONLY_RANK[@]}" )
        INCLUDES_RANKING=1
        echo "Legacy QA_RUN_RANKING_TEST=1: all three tests."
    else
        resolve_command "default"
    fi
fi

if [ "$QA_UI_XCODEBUILD_MODE" != "test" ] && [ "$QA_UI_XCODEBUILD_MODE" != "test-without-building" ]; then
    echo "Error: QA_UI_XCODEBUILD_MODE must be 'test' or 'test-without-building' (got: $QA_UI_XCODEBUILD_MODE)"
    exit 1
fi

if [ "${QA_UI_ALLOW_TEST_WITHOUT_BUILDING:-}" != "1" ] &&
   [ "${QA_UI_XCODEBUILD_MODE}" = "test-without-building" ] &&
   [ "${INCLUDES_RANKING:-0}" = "1" ]; then
    echo ""
    echo "Overriding QA_UI_XCODEBUILD_MODE to **test** (full compile) so 70K Bands + 70K BandsUITests match your current sources."
    echo "If you intentionally want test-without-building: QA_UI_ALLOW_TEST_WITHOUT_BUILDING=1 $0 $*"
    echo ""
    QA_UI_XCODEBUILD_MODE=test
fi

echo "Booting simulator: ${SIMULATOR_ID}"
xcrun simctl boot "${SIMULATOR_ID}" 2>/dev/null || true

SHOULD_UNINSTALL=0
if [ "${QA_UI_UNINSTALL_BEFORE_TEST:-}" = "1" ]; then
    SHOULD_UNINSTALL=1
elif [ "${QA_UI_SKIP_UNINSTALL_BEFORE_TEST:-}" != "1" ] && [ "${INCLUDES_RANKING:-0}" = "1" ]; then
    SHOULD_UNINSTALL=1
fi
if [ "$SHOULD_UNINSTALL" = "1" ]; then
    echo "Uninstalling ${APP_BUNDLE_ID} from simulator ${SIMULATOR_ID} (clean slate for ranking / filters). Set QA_UI_SKIP_UNINSTALL_BEFORE_TEST=1 to skip."
    xcrun simctl uninstall "${SIMULATOR_ID}" "${APP_BUNDLE_ID}" 2>/dev/null || true
fi

echo "Note: UI tests launch a **new** app instance (XCTest); they do not attach to an app you started with Run in Xcode."

SIGN_ARGS=(CODE_SIGN_STYLE=Automatic)
if [ -n "${FASTLANE_TEAM_ID:-}" ]; then
    SIGN_ARGS+=(DEVELOPMENT_TEAM="$FASTLANE_TEAM_ID")
fi

if [ "$QA_UI_XCODEBUILD_MODE" = "test-without-building" ]; then
    echo "Running UI tests **without building** (workspace=${WORKSPACE}, scheme=${SCHEME}, configuration=${CONFIGURATION})."
    echo "If this fails, in Xcode use Product → Build For Testing, or run: QA_UI_XCODEBUILD_MODE=test $0 $*"
    xcodebuild test-without-building \
        -workspace "$WORKSPACE" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        "${SIGN_ARGS[@]}" \
        "${ONLY_TESTING[@]}"
else
    echo "Running UI tests **with full build** (workspace=${WORKSPACE}, scheme=${SCHEME}, configuration=${CONFIGURATION})…"
    xcodebuild test \
        -workspace "$WORKSPACE" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        "${SIGN_ARGS[@]}" \
        "${ONLY_TESTING[@]}"
fi

echo "Done."

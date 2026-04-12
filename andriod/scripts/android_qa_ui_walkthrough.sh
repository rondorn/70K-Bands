#!/bin/bash
#
# Run QA walkthrough **instrumented** UI tests on an Android emulator or device.
# Parallels `swift/scripts/ios_qa_ui_walkthrough.sh` (same presets, env names, and test *method* names).
# Implementation of the tests is separate (Espresso / Compose); method names should match iOS for parity.
#
# ---------------------------------------------------------------------------
# Command line (preferred)
# ---------------------------------------------------------------------------
#   ./scripts/android_qa_ui_walkthrough.sh list              # names + Gradle class#method hints
#   ./scripts/android_qa_ui_walkthrough.sh all               # pointer + four-links + ranking
#   ./scripts/android_qa_ui_walkthrough.sh default           # pointer + four-links only (fast)
#   ./scripts/android_qa_ui_walkthrough.sh ranking           # ranking test only
#   ./scripts/android_qa_ui_walkthrough.sh <testMethodName>  # one test, e.g. testChapter1_NarrativeRankingThreeBands_StepwiseVerified
#
# With no arguments, legacy env vars still apply (QA_ONLY_RANKING_TEST, QA_RUN_RANKING_TEST);
# if those are unset, behaves like `default`.
#
# Environment (optional — names aligned with iOS where possible):
#   QA_UI_GRADLE_MODE=test|test-without-building
#       test                      — full Gradle connected run (default; always compiles stale modules).
#       test-without-building     — same Gradle invocation; Android has no true “skip compile” for
#                                   instrumentation. Use for workflow parity / future adb-instrument hook.
#   QA_UI_ALLOW_TEST_WITHOUT_BUILDING  — reserved (iOS uses this to allow test-without-building with ranking).
#   QA_UI_SKIP_UNINSTALL_BEFORE_TEST, QA_UI_UNINSTALL_BEFORE_TEST
#   EMULATOR_AVD              — e.g. Pixel_8_API_35; if set (and ANDROID_SERIAL unset), script starts this AVD.
#   ANDROID_SERIAL            — adb device serial; if set, no emulator is started.
#   QA_UI_SKIP_AUTO_AVD       — if 1, do not pick the first AVD from `emulator -list-avds` when EMULATOR_AVD is unset.
#   ANDROID_FLAVOR            — product flavor (default: bands70k). Example: mdfbands
#   ANDROID_APP_ID            — applicationId for adb uninstall (default: com.Bands70k for bands70k)
#   GRADLE_PROJECT_DIR        — override repo root for Gradle (default: parent of scripts/)
#
# Android-specific:
#   ANDROID_UI_CHAPTER1_CLASS       — FQCN for Ch.1 non-ranking UI tests (pointer + four-links)
#   ANDROID_UI_CHAPTER1_RANK_CLASS  — FQCN for Ch.1 ranking UI test
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ANDROID_ROOT"

# Same Ch.1 pointer as iOS QA (qa-config/pointers/pointer_bands_only.txt) — passed to app under test via instrumentation args.
QA_CHAPTER1_POINTER_URL="${QA_CHAPTER1_POINTER_URL:-https://raw.githubusercontent.com/rondorn/70K-Bands/master/qa-config/pointers/pointer_bands_only.txt}"

GRADLE_PROJECT_DIR="${GRADLE_PROJECT_DIR:-$ANDROID_ROOT}"

QA_UI_GRADLE_MODE="${QA_UI_GRADLE_MODE:-test}"

ANDROID_FLAVOR="${ANDROID_FLAVOR:-bands70k}"
case "$ANDROID_FLAVOR" in
    mdfbands) DEFAULT_APP_ID="com.rdorn.mdfbands" ;;
    *)        DEFAULT_APP_ID="com.Bands70k" ;;
esac
ANDROID_APP_ID="${ANDROID_APP_ID:-$DEFAULT_APP_ID}"

# Match iOS test *method* identifiers; your Android @Test / @JvmName should use the same names.
T_POINTER="testChapter1_PointerBandsOnly_ShowsFixtureBand"
T_FOUR="testChapter1_BandDetail_FourLinksOpenAndDismissWebSheet"
T_RANK="testChapter1_NarrativeRankingThreeBands_StepwiseVerified"

# Placeholder FQCNs — replace when you add androidTest sources (package must exist on device).
ANDROID_UI_CHAPTER1_CLASS="${ANDROID_UI_CHAPTER1_CLASS:-com.Bands70k.qa.QAWalkthroughChapter1UITests}"
ANDROID_UI_CHAPTER1_RANK_CLASS="${ANDROID_UI_CHAPTER1_RANK_CLASS:-com.Bands70k.qa.QAWalkthroughChapter1RankingUITests}"

EMULATOR_AVD="${EMULATOR_AVD:-}"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
EMULATOR_BIN="${ANDROID_HOME}/emulator/emulator"
ADB="${ANDROID_HOME}/platform-tools/adb"

# Capitalize first letter for Gradle task: bands70k → Bands70k
flavor_for_task() {
    local f="$1"
    printf '%s%s' "$(printf '%s' "${f:0:1}" | tr '[:lower:]' '[:upper:]')" "${f:1}"
}

FLAVOR_TASK="$(flavor_for_task "$ANDROID_FLAVOR")"
CONNECTED_TASK=":app:connected${FLAVOR_TASK}DebugAndroidTest"

usage() {
    sed -n '1,35p' "$0" | tail -n +2
    echo ""
    echo "Run:  $0 list | all | default | ranking | <testMethodName>"
    echo "Env:  QA_UI_GRADLE_MODE, EMULATOR_AVD, ANDROID_SERIAL, ANDROID_FLAVOR, ANDROID_APP_ID, …"
}

list_tests() {
    echo "QA UI walkthrough — Android (Gradle task: ${CONNECTED_TASK})"
    echo ""
    echo "  Presets:"
    echo "    default    ${T_POINTER} + ${T_FOUR}"
    echo "    all        default + ${T_RANK}"
    echo "    ranking    ${T_RANK} only"
    echo ""
    echo "  Single test (same method name as iOS):"
    echo "    ${T_POINTER}"
    echo "    ${T_FOUR}"
    echo "    ${T_RANK}"
    echo ""
    echo "  Placeholder instrumentation classes (set ANDROID_UI_* to your real FQCNs):"
    echo "    ${ANDROID_UI_CHAPTER1_CLASS}"
    echo "    ${ANDROID_UI_CHAPTER1_RANK_CLASS}"
    echo ""
    echo "  Gradle -Pandroid.testInstrumentationRunnerArguments.class examples:"
    printf '    %s#%s\n' "$ANDROID_UI_CHAPTER1_CLASS" "$T_POINTER"
    printf '    %s#%s\n' "$ANDROID_UI_CHAPTER1_CLASS" "$T_FOUR"
    printf '    %s#%s\n' "$ANDROID_UI_CHAPTER1_RANK_CLASS" "$T_RANK"
}

# Sets: RUN_SPECS as lines "FQCN#method", INCLUDES_RANKING (0|1)
resolve_command() {
    local raw="${1:-}"
    local cmd
    cmd="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
    INCLUDES_RANKING=0
    RUN_SPECS=()
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
            RUN_SPECS=(
                "${ANDROID_UI_CHAPTER1_CLASS}#${T_POINTER}"
                "${ANDROID_UI_CHAPTER1_CLASS}#${T_FOUR}"
                "${ANDROID_UI_CHAPTER1_RANK_CLASS}#${T_RANK}"
            )
            INCLUDES_RANKING=1
            echo "Running all Ch.1 QA UI tests (pointer + four-links + ranking)."
            ;;
        default|smoke)
            RUN_SPECS=(
                "${ANDROID_UI_CHAPTER1_CLASS}#${T_POINTER}"
                "${ANDROID_UI_CHAPTER1_CLASS}#${T_FOUR}"
            )
            echo "Running default QA UI tests (pointer + four-links)."
            ;;
        ranking|ranking-only)
            RUN_SPECS=( "${ANDROID_UI_CHAPTER1_RANK_CLASS}#${T_RANK}" )
            INCLUDES_RANKING=1
            echo "Running ranking QA UI test only."
            ;;
        *)
            case "$raw" in
                "$T_POINTER")
                    RUN_SPECS=( "${ANDROID_UI_CHAPTER1_CLASS}#${T_POINTER}" )
                    ;;
                "$T_FOUR")
                    RUN_SPECS=( "${ANDROID_UI_CHAPTER1_CLASS}#${T_FOUR}" )
                    ;;
                "$T_RANK")
                    RUN_SPECS=( "${ANDROID_UI_CHAPTER1_RANK_CLASS}#${T_RANK}" )
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

command -v java >/dev/null 2>&1 || {
    echo "Error: java not found (required for Gradle)."
    exit 1
}

if [ ! -f "$GRADLE_PROJECT_DIR/gradlew" ]; then
    echo "Error: gradlew not found under $GRADLE_PROJECT_DIR"
    exit 1
fi

if [ -f "$ANDROID_ROOT/.env" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$ANDROID_ROOT/.env"
    set +a
fi

# ---- CLI + legacy env -----------------------------------------------------
if [ $# -ge 1 ]; then
    resolve_command "$1"
else
    if [ "${QA_ONLY_RANKING_TEST:-}" = "1" ]; then
        RUN_SPECS=( "${ANDROID_UI_CHAPTER1_RANK_CLASS}#${T_RANK}" )
        INCLUDES_RANKING=1
        echo "Legacy QA_ONLY_RANKING_TEST=1: ranking only."
    elif [ "${QA_RUN_RANKING_TEST:-}" = "1" ]; then
        RUN_SPECS=(
            "${ANDROID_UI_CHAPTER1_CLASS}#${T_POINTER}"
            "${ANDROID_UI_CHAPTER1_CLASS}#${T_FOUR}"
            "${ANDROID_UI_CHAPTER1_RANK_CLASS}#${T_RANK}"
        )
        INCLUDES_RANKING=1
        echo "Legacy QA_RUN_RANKING_TEST=1: all three tests."
    else
        resolve_command "default"
    fi
fi

if [ "$QA_UI_GRADLE_MODE" != "test" ] && [ "$QA_UI_GRADLE_MODE" != "test-without-building" ]; then
    echo "Error: QA_UI_GRADLE_MODE must be 'test' or 'test-without-building' (got: $QA_UI_GRADLE_MODE)"
    exit 1
fi

if [ "${QA_UI_ALLOW_TEST_WITHOUT_BUILDING:-}" != "1" ] &&
   [ "${QA_UI_GRADLE_MODE}" = "test-without-building" ] &&
   [ "${INCLUDES_RANKING:-0}" = "1" ]; then
    echo ""
    echo "Note: Overriding QA_UI_GRADLE_MODE to **test** for ranking runs (parity with iOS: full compile for app + androidTest)."
    echo "To force test-without-building anyway: QA_UI_ALLOW_TEST_WITHOUT_BUILDING=1 $0 $*"
    echo ""
    QA_UI_GRADLE_MODE=test
fi

if [ "$QA_UI_GRADLE_MODE" = "test-without-building" ]; then
    echo "Note: QA_UI_GRADLE_MODE=test-without-building — Gradle still resolves compilation; use after a recent successful build if desired."
fi

boot_or_select_device() {
    if ! command -v "$ADB" >/dev/null 2>&1; then
        echo "Error: adb not found at $ADB (set ANDROID_HOME, e.g. export ANDROID_HOME=\$HOME/Library/Android/sdk)."
        exit 1
    fi
    "$ADB" start-server >/dev/null 2>&1 || true

    if [ -n "${ANDROID_SERIAL:-}" ]; then
        echo "Using ANDROID_SERIAL=${ANDROID_SERIAL} (skip emulator boot)."
        export ANDROID_SERIAL
        return 0
    fi

    # Use an already-connected device (phone or running emulator) so we do not start a second emulator.
    local connected
    connected="$("$ADB" devices | awk '/\tdevice$/{print $1}' | head -1)"
    if [ -n "$connected" ]; then
        export ANDROID_SERIAL="$connected"
        echo "Using already-connected device: $connected (set ANDROID_SERIAL to override)."
        return 0
    fi

    if [ -z "${EMULATOR_AVD:-}" ] && [ "${QA_UI_SKIP_AUTO_AVD:-}" != "1" ]; then
        if [ ! -x "$EMULATOR_BIN" ]; then
            echo "Error: emulator binary not found at $EMULATOR_BIN — set ANDROID_HOME or EMULATOR_AVD + start a device manually."
            exit 1
        fi
        local first_avd
        first_avd="$("$EMULATOR_BIN" -list-avds 2>/dev/null | head -1)"
        if [ -n "$first_avd" ]; then
            EMULATOR_AVD="$first_avd"
            echo "No device online — auto-selected first AVD from 'emulator -list-avds': $EMULATOR_AVD"
            echo "(Set EMULATOR_AVD to choose another, or connect hardware and re-run.)"
        else
            echo "Error: no adb device and no AVDs (emulator -list-avds is empty). Create an AVD in Android Studio or connect a device."
            exit 1
        fi
    fi

    if [ -z "${EMULATOR_AVD:-}" ]; then
        echo "Error: no connected device and EMULATOR_AVD unset. Set EMULATOR_AVD, connect a device, or remove QA_UI_SKIP_AUTO_AVD=1."
        exit 1
    fi

    if [ ! -x "$EMULATOR_BIN" ]; then
        echo "Error: emulator not found at $EMULATOR_BIN (set ANDROID_HOME or install Android SDK emulator)."
        exit 1
    fi
    echo "Booting emulator AVD: ${EMULATOR_AVD}"
    # Do not hide stderr — useful when AVD name is wrong or SDK is incomplete.
    "$EMULATOR_BIN" -avd "$EMULATOR_AVD" -no-snapshot-save &
    local emupid=$!
    echo "Emulator process started (pid $emupid). Waiting for adb…"
    "$ADB" wait-for-device
    echo "Waiting for boot completed…"
    local boot=""
    for _ in $(seq 1 90); do
        boot="$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
        if [ "$boot" = "1" ]; then
            echo "Device ready."
            return 0
        fi
        sleep 2
    done
    echo "Error: timeout waiting for sys.boot_completed."
    exit 1
}

boot_or_select_device

SHOULD_UNINSTALL=0
if [ "${QA_UI_UNINSTALL_BEFORE_TEST:-}" = "1" ]; then
    SHOULD_UNINSTALL=1
elif [ "${QA_UI_SKIP_UNINSTALL_BEFORE_TEST:-}" != "1" ] && [ "${INCLUDES_RANKING:-0}" = "1" ]; then
    SHOULD_UNINSTALL=1
fi
if [ "$SHOULD_UNINSTALL" = "1" ]; then
    echo "Uninstalling ${ANDROID_APP_ID} from device (clean slate for ranking / filters). Set QA_UI_SKIP_UNINSTALL_BEFORE_TEST=1 to skip."
    if ! "$ADB" uninstall "$ANDROID_APP_ID" 2>/dev/null; then
        echo "(Uninstall skipped or app was not installed — OK for a clean emulator.)"
    fi
fi

echo "Note: Instrumentation tests install a fresh test APK and launch the app in a test process."

run_one_connected() {
    local class_method="$1"
    echo ""
    echo "——— Running: ${class_method} ———"
    ( cd "$GRADLE_PROJECT_DIR" && ./gradlew "${CONNECTED_TASK}" \
        -Pandroid.testInstrumentationRunnerArguments.UITESTING=1 \
        -Pandroid.testInstrumentationRunnerArguments.UITEST_CUSTOM_POINTER_URL="${QA_CHAPTER1_POINTER_URL}" \
        -Pandroid.testInstrumentationRunnerArguments.class="${class_method}" )
}

for spec in "${RUN_SPECS[@]}"; do
    run_one_connected "$spec"
done

echo "Done."

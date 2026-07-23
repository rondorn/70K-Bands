#!/bin/sh
# Xcode scheme pre-action: Flutter "prepare" with env from flutter_export_environment.sh.
# Scheme pre-actions do not inherit FLUTTER_ROOT from xcconfig, which causes
# "PhaseScriptExecution failed" when building from the Xcode app.
set -eu

PLATFORM="${1:-ios}"
SRCROOT="${SRCROOT:-}"

if [ -z "$SRCROOT" ]; then
  echo "error: SRCROOT is not set (expected ios/ or macos/)" >&2
  exit 1
fi

case "$PLATFORM" in
  ios)
    ENV_SH="${SRCROOT}/Flutter/flutter_export_environment.sh"
    GENERATED="${SRCROOT}/Flutter/Generated.xcconfig"
    ;;
  macos)
    ENV_SH="${SRCROOT}/Flutter/ephemeral/flutter_export_environment.sh"
    GENERATED="${SRCROOT}/Flutter/ephemeral/Flutter-Generated.xcconfig"
    ;;
  *)
    echo "usage: $0 ios|macos" >&2
    exit 1
    ;;
esac

read_xcconfig_var() {
  file="$1"
  key="$2"
  grep -E "^${key}=" "$file" | head -1 | cut -d= -f2- | tr -d '\r'
}

if [ -f "$ENV_SH" ]; then
  # shellcheck disable=SC1090
  . "$ENV_SH"
elif [ -f "$GENERATED" ]; then
  FLUTTER_ROOT="$(read_xcconfig_var "$GENERATED" FLUTTER_ROOT)"
  FLUTTER_APPLICATION_PATH="$(read_xcconfig_var "$GENERATED" FLUTTER_APPLICATION_PATH)"
  export FLUTTER_ROOT FLUTTER_APPLICATION_PATH
else
  echo "error: Flutter iOS/macOS config is missing." >&2
  echo "From promoter_admin run once: flutter pub get && flutter build ${PLATFORM} --config-only" >&2
  exit 1
fi

if [ -z "${FLUTTER_ROOT:-}" ] || [ ! -d "$FLUTTER_ROOT" ]; then
  echo "error: FLUTTER_ROOT is missing or invalid." >&2
  exit 1
fi

if [ -z "${FLUTTER_APPLICATION_PATH:-}" ] || [ ! -d "$FLUTTER_APPLICATION_PATH" ]; then
  echo "error: FLUTTER_APPLICATION_PATH is missing or invalid." >&2
  exit 1
fi

if [ -z "${FLUTTER_BUILD_MODE:-}" ] && [ -n "${CONFIGURATION:-}" ]; then
  export FLUTTER_BUILD_MODE="$CONFIGURATION"
fi

cd "$FLUTTER_APPLICATION_PATH"

case "$PLATFORM" in
  ios)
    /bin/sh "$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" prepare
    ;;
  macos)
    "$FLUTTER_ROOT/packages/flutter_tools/bin/macos_assemble.sh" prepare
    ;;
esac

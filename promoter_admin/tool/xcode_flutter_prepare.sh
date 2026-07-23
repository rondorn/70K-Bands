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
    ;;
  macos)
    ENV_SH="${SRCROOT}/Flutter/ephemeral/flutter_export_environment.sh"
    ;;
  *)
    echo "usage: $0 ios|macos" >&2
    exit 1
    ;;
esac

if [ ! -f "$ENV_SH" ]; then
  echo "error: $ENV_SH is missing." >&2
  echo "From promoter_admin run: flutter pub get" >&2
  echo "Then once: flutter build ios --config-only   (or macos --config-only)" >&2
  exit 1
fi

# shellcheck disable=SC1090
. "$ENV_SH"

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

#!/bin/sh
# Keep committed native/AppVersion.xcconfig in sync with pubspec.yaml.
#
# iOS/macOS Xcode builds include AppVersion.xcconfig AFTER gitignored Generated
# configs, so the committed file always wins — git pull is enough on any machine.
#
# Windows and Dart read pubspec.yaml directly at build time.
#
# Usage (from anywhere):
#   promoter_admin/tool/sync_native_version.sh           # write + verify
#   promoter_admin/tool/sync_native_version.sh --check   # verify only (CI)
#   promoter_admin/tool/sync_native_version.sh --full    # also refresh Generated configs

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_VERSION="native/AppVersion.xcconfig"
CHECK_ONLY=0
FULL=0

for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=1 ;;
    --full) FULL=1 ;;
    ios|macos|all) ;; # legacy args — ignored
    *)
      echo "usage: $0 [--check] [--full]" >&2
      exit 1
      ;;
  esac
done

read_pubspec_version() {
  line=$(grep -E '^version:' pubspec.yaml | head -1)
  ver=$(echo "$line" | sed 's/version:[[:space:]]*//')
  WANT_NAME=${ver%+*}
  WANT_NUMBER=${ver#*+}
  if [ -z "$WANT_NAME" ] || [ -z "$WANT_NUMBER" ] || [ "$WANT_NAME" = "$ver" ]; then
    echo "error: pubspec.yaml version must be name+number (e.g. 1.0.4+16), got: $line" >&2
    exit 1
  fi
}

read_app_version() {
  if [ ! -f "$APP_VERSION" ]; then
    HAVE_NAME=""
    HAVE_NUMBER=""
    return
  fi
  HAVE_NAME=$(grep -E '^FLUTTER_BUILD_NAME=' "$APP_VERSION" | head -1 | cut -d= -f2)
  HAVE_NUMBER=$(grep -E '^FLUTTER_BUILD_NUMBER=' "$APP_VERSION" | head -1 | cut -d= -f2)
}

write_app_version() {
  read_pubspec_version
  mkdir -p native
  cat > "$APP_VERSION" <<EOF
// Committed app version for iOS and macOS (shared across all build machines).
// Source of truth: pubspec.yaml — update via tool/sync_native_version.sh when bumping.
FLUTTER_BUILD_NAME=${WANT_NAME}
FLUTTER_BUILD_NUMBER=${WANT_NUMBER}
EOF
}

verify_app_version() {
  read_pubspec_version
  read_app_version
  if [ "$HAVE_NAME" != "$WANT_NAME" ] || [ "$HAVE_NUMBER" != "$WANT_NUMBER" ]; then
    echo "error: $APP_VERSION is ${HAVE_NAME:-?} (${HAVE_NUMBER:-?}) but pubspec.yaml is ${WANT_NAME} (${WANT_NUMBER})" >&2
    echo "Run: cd promoter_admin && ./tool/sync_native_version.sh" >&2
    exit 1
  fi
  echo "Version OK (all platforms): ${WANT_NAME} (${WANT_NUMBER})"
}

refresh_generated() {
  if ! command -v flutter >/dev/null 2>&1; then
    echo "error: flutter not found in PATH (--full requires Flutter)" >&2
    exit 1
  fi
  echo "Refreshing gitignored Flutter Generated configs…"
  flutter build ios --config-only
  flutter build macos --config-only
}

read_pubspec_version

if [ "$CHECK_ONLY" -eq 1 ]; then
  verify_app_version
  exit 0
fi

read_app_version
if [ ! -f "$APP_VERSION" ] || [ "$HAVE_NAME" != "$WANT_NAME" ] || [ "$HAVE_NUMBER" != "$WANT_NUMBER" ]; then
  echo "Updating $APP_VERSION → ${WANT_NAME} (${WANT_NUMBER}) from pubspec.yaml…"
  write_app_version
fi

verify_app_version

if [ "$FULL" -eq 1 ]; then
  refresh_generated
fi

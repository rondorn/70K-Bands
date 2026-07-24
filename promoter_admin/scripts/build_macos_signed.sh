#!/usr/bin/env bash
# Build a Developer ID–signed (and optionally notarized) macOS app for direct
# download. This is NOT App Store review — notarization is an automated scan.
#
# Usage (from repo, or from promoter_admin/):
#   ./scripts/build_macos_signed.sh
#   ./scripts/build_macos_signed.sh --skip-notarize   # signed only
#   ./scripts/build_macos_signed.sh --unsigned        # no codesign
#   ./scripts/build_macos_signed.sh --team-id OTHERID # override default team
#
# Default Apple Team ID: K35L7F3E4S (override with --team-id or APPLE_TEAM_ID).
#
# Environment (signing — pick one approach):
#   MACOS_CERTIFICATE_NAME   Preferred. Exact identity string, e.g.
#     "Developer ID Application: Your Name (K35L7F3E4S)"
#   Or omit and the script picks a "Developer ID Application" identity for the
#   team id (default K35L7F3E4S) from your login keychain.
#
# iCloud (required for synced preferences on the direct-download build):
#   macos/signing/Open_Metal_Fest_Admin_Developer_ID.provisionprofile
#   Override path with MACOS_PROVISIONING_PROFILE.
#
# Notarization credentials (auto-loaded from ../swift/.env — same as
# ios_release_submit.sh / ios_archive_upload.sh):
#   FASTLANE_APP_STORE_CONNECT_API_KEY_ID
#   FASTLANE_APP_STORE_CONNECT_API_ISSUER_ID
#   FASTLANE_APP_STORE_CONNECT_API_KEY_PATH  (e.g. ./fastlane/AuthKey_….p8)
# Or set APPLE_ID + APPLE_APP_SPECIFIC_PASSWORD instead.
#
# Output:
#   dist/omf-admin-macos-<version>_<build>.zip
#   dist/Open Metal Fest Admin.app  (also left unzipped for local testing)

set -euo pipefail

DEFAULT_APPLE_TEAM_ID='K35L7F3E4S'

SKIP_NOTARIZE=0
UNSIGNED=0
CLI_TEAM_ID=''

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-notarize) SKIP_NOTARIZE=1; shift ;;
    --unsigned) UNSIGNED=1; shift ;;
    --team-id)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "--team-id requires a value" >&2
        exit 1
      fi
      CLI_TEAM_ID="$2"
      shift 2
      ;;
    --team-id=*)
      CLI_TEAM_ID="${1#--team-id=}"
      shift
      ;;
    -h|--help)
      sed -n '2,35p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Priority: --team-id > APPLE_TEAM_ID env > default K35L7F3E4S
APPLE_TEAM_ID="${CLI_TEAM_ID:-${APPLE_TEAM_ID:-$DEFAULT_APPLE_TEAM_ID}}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
REPO_ROOT="$(cd "$ROOT/.." && pwd)"
SWIFT_DIR="$REPO_ROOT/swift"

load_swift_asc_credentials() {
  # Prefer already-exported APPLE_API_*; otherwise reuse swift/.env
  # (same keys as ios_archive_upload.sh / ios_release_submit.sh).
  local env_file="$SWIFT_DIR/.env"
  if [[ ! -f "$env_file" ]]; then
    return 0
  fi
  set -a
  # shellcheck source=/dev/null
  source "$env_file"
  set +a

  if [[ -z "${APPLE_API_KEY_ID:-}" && -n "${FASTLANE_APP_STORE_CONNECT_API_KEY_ID:-}" ]]; then
    APPLE_API_KEY_ID="$FASTLANE_APP_STORE_CONNECT_API_KEY_ID"
  fi
  if [[ -z "${APPLE_API_ISSUER:-}" && -n "${FASTLANE_APP_STORE_CONNECT_API_ISSUER_ID:-}" ]]; then
    APPLE_API_ISSUER="$FASTLANE_APP_STORE_CONNECT_API_ISSUER_ID"
  fi
  if [[ -z "${APPLE_API_KEY_PATH:-}" ]]; then
    local key_path="${FASTLANE_APP_STORE_CONNECT_API_KEY_PATH:-}"
    if [[ -z "$key_path" && -n "${FASTLANE_APP_STORE_CONNECT_API_KEY_ID:-}" ]]; then
      key_path="$SWIFT_DIR/fastlane/AuthKey_${FASTLANE_APP_STORE_CONNECT_API_KEY_ID}.p8"
    fi
    if [[ -n "$key_path" ]]; then
      if [[ "$key_path" != /* ]]; then
        key_path="$SWIFT_DIR/$key_path"
      fi
      if [[ -f "$key_path" ]]; then
        APPLE_API_KEY_PATH="$(cd "$(dirname "$key_path")" && pwd)/$(basename "$key_path")"
      else
        APPLE_API_KEY_PATH="$key_path"
      fi
    fi
  fi
}

load_swift_asc_credentials

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script only runs on macOS." >&2
  exit 1
fi

command -v flutter >/dev/null || {
  echo "flutter not found on PATH" >&2
  exit 1
}

FULL_VERSION="$(grep -E '^version:' pubspec.yaml | head -1 | sed 's/version:[[:space:]]*//')"
VERSION_NAME="${FULL_VERSION%%+*}"
VERSION_BUILD="${FULL_VERSION##*+}"
ZIP_NAME="omf-admin-macos-${VERSION_NAME}_${VERSION_BUILD}.zip"
APP_NAME="Open Metal Fest Admin.app"
# Developer ID + iCloud entitlements. Requires an embedded Developer ID
# provisioning profile whose certificate matches the signing identity.
ENTITLEMENTS="$ROOT/macos/Runner/ReleaseDistribution.entitlements"
DEFAULT_PROVISIONING_PROFILE="$ROOT/macos/signing/Open_Metal_Fest_Admin_Developer_ID.provisionprofile"
PROVISIONING_PROFILE="${MACOS_PROVISIONING_PROFILE:-$DEFAULT_PROVISIONING_PROFILE}"
DIST="$ROOT/dist"
APP_BUILD="$ROOT/build/macos/Build/Products/Release/$APP_NAME"
APP_OUT="$DIST/$APP_NAME"

echo "==> Apple Team ID: $APPLE_TEAM_ID"
if [[ -n "${APPLE_API_KEY_PATH:-}" ]]; then
  echo "==> Notary API key: $APPLE_API_KEY_PATH"
fi
echo "==> Building macOS release ($FULL_VERSION)"
flutter config --enable-macos-desktop >/dev/null
flutter pub get
flutter build macos --release

if [[ ! -d "$APP_BUILD" ]]; then
  echo "Built app not found at: $APP_BUILD" >&2
  find "$ROOT/build/macos" -name '*.app' -print >&2 || true
  exit 1
fi

# Strip AppleDouble (._*) / Finder junk that breaks framework seals and makes
# Gatekeeper report "app is damaged". Also disable resource-fork sidecars on copy.
strip_macos_bundle_junk() {
  local bundle="$1"
  find "$bundle" \( -name '._*' -o -name '.DS_Store' \) -delete 2>/dev/null || true
}

# Zip without AppleDouble / xattr sidecars. Plain `ditto -c -k` embeds ~100
# `._*` entries from extended attributes; unzip then materializes them as real
# files and Gatekeeper reports the app as damaged.
zip_app_bundle() {
  local app="$1"
  local zip_path="$2"
  strip_macos_bundle_junk "$app"
  export COPYFILE_DISABLE=1
  ditto -c -k --keepParent --norsrc --noextattr "$app" "$zip_path"
  local junk
  junk="$(unzip -l "$zip_path" | grep -c '\._' || true)"
  if [[ "$junk" -gt 0 ]]; then
    echo "ERROR: zip still contains $junk AppleDouble (._*) entries: $zip_path" >&2
    exit 1
  fi
}

mkdir -p "$DIST"
rm -rf "$APP_OUT"
export COPYFILE_DISABLE=1
ditto --norsrc --noextattr "$APP_BUILD" "$APP_OUT"
strip_macos_bundle_junk "$APP_OUT"
# Bundle root mtime often stays at the first build; bump so Finder isn't misleading.
touch "$APP_OUT"

if [[ "$UNSIGNED" -eq 1 ]]; then
  echo "==> Skipping codesign (--unsigned)"
else
  IDENTITY="${MACOS_CERTIFICATE_NAME:-}"
  if [[ -z "$IDENTITY" ]]; then
    IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
      | sed -n 's/.*"\(Developer ID Application: .*('"$APPLE_TEAM_ID"')\)"/\1/p' \
      | head -1 || true)"
  fi
  if [[ -z "$IDENTITY" ]]; then
    IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
      | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' \
      | head -1 || true)"
    if [[ -n "$IDENTITY" ]]; then
      echo "Warning: no Developer ID for team $APPLE_TEAM_ID; using: $IDENTITY" >&2
    fi
  fi
  if [[ -z "$IDENTITY" ]]; then
    echo "No Developer ID Application identity found." >&2
    echo "Install your cert in Keychain, or set MACOS_CERTIFICATE_NAME." >&2
    echo "Available identities:" >&2
    security find-identity -v -p codesigning >&2 || true
    exit 1
  fi
  echo "==> Codesigning with: $IDENTITY"

  if [[ ! -f "$PROVISIONING_PROFILE" ]]; then
    echo "Developer ID provisioning profile not found:" >&2
    echo "  $PROVISIONING_PROFILE" >&2
    echo "Place Open_Metal_Fest_Admin_Developer_ID.provisionprofile under" >&2
    echo "  macos/signing/  (see macos/signing/README.md)" >&2
    echo "Or set MACOS_PROVISIONING_PROFILE to the profile path." >&2
    exit 1
  fi
  echo "==> Embedding provisioning profile: $PROVISIONING_PROFILE"
  cp "$PROVISIONING_PROFILE" "$APP_OUT/Contents/embedded.provisionprofile"
  chmod 644 "$APP_OUT/Contents/embedded.provisionprofile"

  # Re-strip immediately before signing in case tooling reintroduced sidecars.
  strip_macos_bundle_junk "$APP_OUT"

  while IFS= read -r -d '' bin; do
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$bin" || true
  done < <(find "$APP_OUT/Contents/Frameworks" "$APP_OUT/Contents/MacOS" \
    \( -name '*.dylib' -o -name '*.so' -o -type f -perm +111 \) \
    -print0 2>/dev/null)

  while IFS= read -r -d '' fw; do
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$fw"
  done < <(find "$APP_OUT/Contents/Frameworks" -name '*.framework' -print0 2>/dev/null)

  codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$IDENTITY" "$APP_OUT"

  codesign --verify --deep --strict --verbose=2 "$APP_OUT"
  echo "    Codesign OK"
fi

if [[ "$UNSIGNED" -eq 0 && "$SKIP_NOTARIZE" -eq 0 ]]; then
  echo "==> Notarizing (automated Apple scan — not App Store review)"
  SUBMIT_ZIP="$(mktemp -t omf-admin-submit).zip"
  zip_app_bundle "$APP_OUT" "$SUBMIT_ZIP"

  if [[ -n "${APPLE_API_KEY_PATH:-}" && -n "${APPLE_API_KEY_ID:-}" && -n "${APPLE_API_ISSUER:-}" ]]; then
    if [[ ! -f "$APPLE_API_KEY_PATH" ]]; then
      echo "API key file not found: $APPLE_API_KEY_PATH" >&2
      echo "Expected the same AuthKey as swift/ios_release_submit.sh (see swift/.env)." >&2
      rm -f "$SUBMIT_ZIP"
      exit 1
    fi
    echo "    Using App Store Connect API key (same as ios_release_submit.sh)"
    xcrun notarytool submit "$SUBMIT_ZIP" \
      --key "$APPLE_API_KEY_PATH" \
      --key-id "$APPLE_API_KEY_ID" \
      --issuer "$APPLE_API_ISSUER" \
      --wait
  elif [[ -n "${APPLE_API_KEY_BASE64:-}" && -n "${APPLE_API_KEY_ID:-}" && -n "${APPLE_API_ISSUER:-}" ]]; then
    KEY_PATH="$(mktemp -t AuthKey).p8"
    echo "$APPLE_API_KEY_BASE64" | base64 --decode > "$KEY_PATH"
    xcrun notarytool submit "$SUBMIT_ZIP" \
      --key "$KEY_PATH" \
      --key-id "$APPLE_API_KEY_ID" \
      --issuer "$APPLE_API_ISSUER" \
      --wait
    rm -f "$KEY_PATH"
  elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
    xcrun notarytool submit "$SUBMIT_ZIP" \
      --apple-id "$APPLE_ID" \
      --password "$APPLE_APP_SPECIFIC_PASSWORD" \
      --team-id "$APPLE_TEAM_ID" \
      --wait
  else
    echo "Notary credentials not set — skipping notarization." >&2
    echo "Expected swift/.env with FASTLANE_APP_STORE_CONNECT_API_KEY_* (same as iOS release)," >&2
    echo "or APPLE_ID + APPLE_APP_SPECIFIC_PASSWORD." >&2
    echo "Or re-run with --skip-notarize for a signed-only build." >&2
    rm -f "$SUBMIT_ZIP"
    SKIP_NOTARIZE=1
  fi

  if [[ "$SKIP_NOTARIZE" -eq 0 ]]; then
    xcrun stapler staple "$APP_OUT"
    rm -f "$SUBMIT_ZIP"
    echo "    Notarized + stapled OK (team $APPLE_TEAM_ID)"
  fi
elif [[ "$SKIP_NOTARIZE" -eq 1 && "$UNSIGNED" -eq 0 ]]; then
  echo "==> Skipping notarization (--skip-notarize)"
fi

ZIP_PATH="$DIST/$ZIP_NAME"
rm -f "$ZIP_PATH"
zip_app_bundle "$APP_OUT" "$ZIP_PATH"

# Smoke-test: unzip must leave a codesign-valid app (catches AppleDouble regressions).
VERIFY_DIR="$(mktemp -d -t omf-admin-verify)"
unzip -q "$ZIP_PATH" -d "$VERIFY_DIR"
VERIFY_APP="$VERIFY_DIR/$APP_NAME"
if [[ ! -d "$VERIFY_APP" ]]; then
  echo "ERROR: unzipped app missing at $VERIFY_APP" >&2
  rm -rf "$VERIFY_DIR"
  exit 1
fi
if ! codesign --verify --deep --strict "$VERIFY_APP"; then
  echo "ERROR: app from zip failed codesign verify (often leftover ._ files)." >&2
  find "$VERIFY_APP" -name '._*' | head -20 >&2 || true
  rm -rf "$VERIFY_DIR"
  exit 1
fi
rm -rf "$VERIFY_DIR"
echo "    Zip OK (no AppleDouble; codesign verify passed after unzip)"

echo
echo "Done."
echo "  Team: $APPLE_TEAM_ID"
echo "  App:  $APP_OUT"
echo "  Zip:  $ZIP_PATH"
echo
if [[ "$UNSIGNED" -eq 1 ]]; then
  echo "Unsigned — recipients: Right-click → Open."
elif [[ "$SKIP_NOTARIZE" -eq 1 ]]; then
  echo "Signed but not notarized — Gatekeeper may still warn; Right-click → Open works."
else
  echo "Signed + notarized — ready for Dropbox / GitHub download."
fi

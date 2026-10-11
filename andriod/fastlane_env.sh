#!/bin/bash
#
# Pick a working fastlane invocation for release scripts.
#
# macOS /usr/bin/ruby (2.6) often cannot compile fastlane's native gems (sysrandom)
# on current SDKs. Prefer Homebrew Ruby's bundle when Gemfile deps are installed;
# otherwise fall back to a standalone `fastlane` (e.g. brew install fastlane).

resolve_fastlane_command() {
    FASTLANE=()

    if [ ! -f "Gemfile" ]; then
        if command -v fastlane >/dev/null 2>&1; then
            FASTLANE=(fastlane)
            return 0
        fi
        echo "Error: Gemfile missing and fastlane not found in PATH." >&2
        echo "Install with: brew install fastlane" >&2
        return 1
    fi

    local bundle_cmd=""
    for candidate in \
        "/opt/homebrew/opt/ruby/bin/bundle" \
        "/usr/local/opt/ruby/bin/bundle" \
        "$(command -v bundle 2>/dev/null)"; do
        [ -n "$candidate" ] && [ -x "$candidate" ] || continue
        if "$candidate" check >/dev/null 2>&1; then
            bundle_cmd="$candidate"
            break
        fi
    done

    if [ -n "$bundle_cmd" ]; then
        FASTLANE=("$bundle_cmd" exec fastlane)
        return 0
    fi

    # A fastlane on PATH can be a stale RubyGems stub for macOS system Ruby that crashes on this
    # Gemfile.lock's bundler version, so only accept a candidate that actually runs.
    local fastlane_cmd=""
    for candidate in \
        "/opt/homebrew/bin/fastlane" \
        "/usr/local/bin/fastlane" \
        "$(command -v fastlane 2>/dev/null)"; do
        [ -n "$candidate" ] && [ -x "$candidate" ] || continue
        if "$candidate" --version >/dev/null 2>&1; then
            fastlane_cmd="$candidate"
            break
        fi
    done

    if [ -n "$fastlane_cmd" ]; then
        echo "Note: Gemfile present but bundle gems not installed — using standalone fastlane ($fastlane_cmd)." >&2
        echo "      To use bundled gems: /opt/homebrew/opt/ruby/bin/bundle install" >&2
        FASTLANE=("$fastlane_cmd")
        return 0
    fi

    echo "Error: fastlane not available." >&2
    echo "  Option A (recommended): /opt/homebrew/opt/ruby/bin/bundle install" >&2
    echo "  Option B: brew install fastlane" >&2
    return 1
}

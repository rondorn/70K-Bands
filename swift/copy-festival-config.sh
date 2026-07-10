#!/bin/bash
# Copies the shared festival JSON for the current iOS target into the app bundle.
# Invoked from copy-firebase-config.sh (or as its own Run Script build phase).

set -e

FESTIVALS_DIR="${SRCROOT}/../config/festivals"
APP_DIR="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"

if [[ "${PRODUCT_NAME}" == *"RMF"* ]] || [[ "${TARGET_NAME}" == *"RMF"* ]] || [[ "${CONFIGURATION}" == *"RMF"* ]]; then
    FESTIVAL_KEY="rmf"
elif [[ "${PRODUCT_NAME}" == *"MMF"* ]] || [[ "${TARGET_NAME}" == *"MMF"* ]] || [[ "${CONFIGURATION}" == *"MMF"* ]]; then
    FESTIVAL_KEY="mmf"
elif [[ "${PRODUCT_NAME}" == *"MDF"* ]] || [[ "${TARGET_NAME}" == *"MDF"* ]] || [[ "${CONFIGURATION}" == *"MDF"* ]]; then
    FESTIVAL_KEY="mdf"
else
    FESTIVAL_KEY="70k"
fi

SOURCE_JSON="${FESTIVALS_DIR}/${FESTIVAL_KEY}.json"
REGISTRY_JSON="${FESTIVALS_DIR}/registry.json"

if [ ! -f "$SOURCE_JSON" ]; then
    echo "❌ Festival config missing: $SOURCE_JSON"
    exit 1
fi

mkdir -p "$APP_DIR"
cp "$SOURCE_JSON" "${APP_DIR}/festival.json"
cp "$REGISTRY_JSON" "${APP_DIR}/festival_registry.json"

if [[ "${FESTIVAL_KEY}" == "rmf" ]]; then
    OVERRIDE_STRINGS="${SRCROOT}/70000TonsBands/RMF-About-Overrides/en.lproj/Localizable.strings"
    TARGET_STRINGS="${APP_DIR}/en.lproj/Localizable.strings"
    if [[ -f "$OVERRIDE_STRINGS" && -f "$TARGET_STRINGS" ]]; then
        if ! python3 - "$OVERRIDE_STRINGS" "$TARGET_STRINGS" <<'PY'
import re, sys
override_path, target_path = sys.argv[1], sys.argv[2]

def parse_strings(text):
    entries = {}
    for key, value in re.findall(r'"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)";', text, re.S):
        entries[key] = value
    return entries

def render_strings(entries, original_text):
    lines = original_text.splitlines()
    out = []
    seen = set()
    key_re = re.compile(r'^"((?:\\.|[^"\\])*)"\s*=')
    for line in lines:
        m = key_re.match(line.strip())
        if m and m.group(1) in entries:
            key = m.group(1)
            out.append(f'"{key}" = "{entries[key]}";')
            seen.add(key)
        else:
            out.append(line)
    for key, value in entries.items():
        if key not in seen:
            out.append(f'"{key}" = "{value}";')
    return "\n".join(out) + ("\n" if out else "")

override = parse_strings(open(override_path, encoding="utf-8").read())
original = open(target_path, encoding="utf-8").read()
open(target_path, "w", encoding="utf-8").write(render_strings(override, original))
PY
        then
            echo "⚠️ Festival config: RMF About string merge skipped (non-fatal)"
        else
            echo "✅ Festival config: merged RMF About string overrides"
        fi
    fi
fi

echo "✅ Festival config: copied ${FESTIVAL_KEY}.json → festival.json"

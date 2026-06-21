#!/bin/bash
# Copies the shared festival JSON for the current iOS target into the app bundle.
# Invoked from copy-firebase-config.sh (or as its own Run Script build phase).

set -e

FESTIVALS_DIR="${SRCROOT}/../qa-config/festivals"
APP_DIR="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"

if [[ "${PRODUCT_NAME}" == *"MMF"* ]] || [[ "${TARGET_NAME}" == *"MMF"* ]] || [[ "${CONFIGURATION}" == *"MMF"* ]]; then
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

echo "✅ Festival config: copied ${FESTIVAL_KEY}.json → festival.json"

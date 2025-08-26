#!/bin/bash

# Build script to copy the correct GoogleService-Info.plist based on build configuration
# This script should be added as a "Run Script" build phase in Xcode

echo "🔥 Firebase Config Script: Starting for configuration: ${CONFIGURATION}"
echo "🔥 Firebase Config Script: Product name: ${PRODUCT_NAME}"
echo "🔥 Firebase Config Script: Target name: ${TARGET_NAME}"

# Define source files
FIREBASE_70K="${SRCROOT}/GoogleService-Info-70K.plist"
FIREBASE_MDF="${SRCROOT}/GoogleService-Info-MDF.plist"
FIREBASE_DEST="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"

echo "🔥 Firebase Config Script: Checking for source files..."
echo "🔥 Firebase Config Script: 70K file exists: $(test -f "$FIREBASE_70K" && echo "YES" || echo "NO")"
echo "🔥 Firebase Config Script: MDF file exists: $(test -f "$FIREBASE_MDF" && echo "YES" || echo "NO")"

# Determine which Firebase config to use based on build configuration or target name
if [[ "${PRODUCT_NAME}" == *"MDF"* ]] || [[ "${TARGET_NAME}" == *"MDF"* ]] || [[ "${CONFIGURATION}" == *"MDF"* ]]; then
    echo "🔥 Firebase Config Script: Detected MDF Bands build - using MDF Firebase config"
    SOURCE_FILE="$FIREBASE_MDF"
    FESTIVAL_TYPE="MDF"
elif [[ "${PRODUCT_NAME}" == *"70K"* ]] || [[ "${TARGET_NAME}" == *"70K"* ]] || [[ "${CONFIGURATION}" == *"70K"* ]]; then
    echo "🔥 Firebase Config Script: Detected 70K Bands build - using 70K Firebase config"
    SOURCE_FILE="$FIREBASE_70K"
    FESTIVAL_TYPE="70K"
else
    # Default to 70K if we can't determine
    echo "🔥 Firebase Config Script: Could not determine festival type, defaulting to 70K"
    SOURCE_FILE="$FIREBASE_70K"
    FESTIVAL_TYPE="70K (default)"
fi

echo "🔥 Firebase Config Script: Selected festival: $FESTIVAL_TYPE"
echo "🔥 Firebase Config Script: Source file: $SOURCE_FILE"
echo "🔥 Firebase Config Script: Destination: $FIREBASE_DEST"

# Check if source file exists
if [ ! -f "$SOURCE_FILE" ]; then
    echo "❌ Firebase Config Script: ERROR - Source file does not exist: $SOURCE_FILE"
    exit 1
fi

# Create destination directory if it doesn't exist
mkdir -p "$(dirname "$FIREBASE_DEST")"

# Copy the appropriate Firebase config file
cp "$SOURCE_FILE" "$FIREBASE_DEST"

if [ $? -eq 0 ]; then
    echo "✅ Firebase Config Script: Successfully copied Firebase config for $FESTIVAL_TYPE"
    echo "✅ Firebase Config Script: File copied to: $FIREBASE_DEST"
else
    echo "❌ Firebase Config Script: Failed to copy Firebase config"
    exit 1
fi

echo "🔥 Firebase Config Script: Completed successfully"

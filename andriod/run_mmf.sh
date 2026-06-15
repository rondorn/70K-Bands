#!/bin/bash
# Script to build and run MMF Bands app

echo "🤘 Building MMF Bands app..."
./gradlew assembleMmfbandsDebug

if [ $? -eq 0 ]; then
    echo "✅ Build successful! Installing on device/emulator..."
    adb install -r app/build/outputs/apk/mmfbands/debug/app-mmfbands-debug.apk

    if [ $? -eq 0 ]; then
        echo "🚀 Launching MMF Bands app..."
        adb shell am start -n com.rdorn.mmfbands/.showBands
        echo "✅ MMF Bands app launched!"
    else
        echo "❌ Installation failed"
    fi
else
    echo "❌ Build failed"
fi

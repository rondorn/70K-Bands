#!/bin/bash
# Script to build and run MDF Bands app

echo "🤘 Building MDF Bands app..."
./gradlew assembleMdfbandsDebug

if [ $? -eq 0 ]; then
    echo "✅ Build successful! Installing on device/emulator..."
    adb install -r app/build/outputs/apk/mdfbands/debug/app-mdfbands-debug.apk
    
    if [ $? -eq 0 ]; then
        echo "🚀 Launching MDF Bands app..."
        adb shell am start -n com.mdfbands/.showBands
        echo "✅ MDF Bands app launched!"
    else
        echo "❌ Installation failed"
    fi
else
    echo "❌ Build failed"
fi

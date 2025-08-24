#!/bin/bash
# Script to build and run 70K Bands app

echo "🎸 Building 70K Bands app..."
./gradlew assembleBands70kDebug

if [ $? -eq 0 ]; then
    echo "✅ Build successful! Installing on device/emulator..."
    adb install -r app/build/outputs/apk/bands70k/debug/app-bands70k-debug.apk
    
    if [ $? -eq 0 ]; then
        echo "🚀 Launching 70K Bands app..."
        adb shell am start -n com.Bands70k/.showBands
        echo "✅ 70K Bands app launched!"
    else
        echo "❌ Installation failed"
    fi
else
    echo "❌ Build failed"
fi

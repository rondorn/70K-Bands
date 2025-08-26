# Firebase Configuration Setup for Multi-Festival iOS App

This document explains how to set up Firebase configuration for both 70K Bands and MDF Bands variants of the iOS app.

## Problem
The app supports two festivals (70K Bands and MDF Bands) and each needs a different Firebase configuration:
- `GoogleService-Info-70K.plist` for 70K Bands
- `GoogleService-Info-MDF.plist` for MDF Bands

Firebase expects a file named `GoogleService-Info.plist` (without variant suffix), so we need to copy the correct file during build.

## Solution
A build script (`copy-firebase-config.sh`) automatically copies the correct Firebase configuration based on the build target.

## Setup Instructions

### Step 1: Verify Files Exist
Ensure these files are in the project root:
- ✅ `GoogleService-Info-70K.plist` 
- ✅ `GoogleService-Info-MDF.plist`
- ✅ `copy-firebase-config.sh`

### Step 2: Add Build Script to Xcode

1. **Open Xcode** and select your project
2. **Select the target** (either "70K Bands" or "MDF Bands")
3. **Go to Build Phases tab**
4. **Click the "+" button** and select "New Run Script Phase"
5. **Drag the new script phase** to be **BEFORE** the "Copy Bundle Resources" phase
6. **Name the script**: "Copy Firebase Config"
7. **Add this script**:
```bash
# Copy the correct GoogleService-Info.plist based on build configuration
${SRCROOT}/copy-firebase-config.sh
```

### Step 3: Repeat for Other Target
Repeat Step 2 for the other target (if you have separate targets for 70K and MDF).

### Step 4: Test the Setup

#### Test 70K Bands Build:
```bash
cd /path/to/project
xcodebuild -workspace "70K Bands.xcworkspace" -scheme "70K Bands" -destination 'platform=iOS Simulator,name=iPhone 16' build
```

#### Test MDF Bands Build:
```bash
cd /path/to/project  
xcodebuild -workspace "70K Bands.xcworkspace" -scheme "MDF Bands" -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## How It Works

The script detects the festival type by checking:
1. `PRODUCT_NAME` (e.g., "70K Bands" vs "MDF Bands")
2. `TARGET_NAME` 
3. `CONFIGURATION` name

Based on the detection, it copies the appropriate Firebase config file to the app bundle as `GoogleService-Info.plist`.

## Expected Build Output

You should see logs like:
```
🔥 Firebase Config Script: Starting for configuration: Debug
🔥 Firebase Config Script: Product name: 70K Bands
🔥 Firebase Config Script: Detected 70K Bands build - using 70K Firebase config
✅ Firebase Config Script: Successfully copied Firebase config for 70K
```

## Troubleshooting

### Firebase Still Can't Find Config
- Verify the script runs **before** "Copy Bundle Resources"
- Check build logs for script output
- Ensure script has execute permissions: `chmod +x copy-firebase-config.sh`

### Wrong Config Being Used
- Check that product names contain "70K" or "MDF" 
- Verify the source files exist and are named correctly
- Check script logs to see which detection logic triggered

### Script Fails
- Verify file paths in the script
- Check that source files exist
- Ensure script has proper permissions

## Files Created/Modified
- ✅ `copy-firebase-config.sh` - Build script
- ✅ `FIREBASE_SETUP_INSTRUCTIONS.md` - This document
- Build phases modified in Xcode project

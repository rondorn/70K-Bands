# iOS Multi-Festival Target Setup Instructions

## Overview
This guide will help you set up separate iOS targets for 70K Bands and MDF Bands while sharing the same codebase.

## Step 1: Duplicate the Existing Target

1. Open `70K Bands.xcworkspace` in Xcode
2. In the Project Navigator, select the project file (top-level "70K Bands")
3. In the main editor, you'll see the project settings with TARGETS listed
4. Right-click on the "70K Bands" target and select "Duplicate"
5. Rename the duplicated target to "MDF Bands"
6. Xcode will also create a duplicate scheme - rename it to "MDF Bands" as well

## Step 2: Configure MDF Bands Target Settings

### Basic Settings:
1. Select the "MDF Bands" target
2. In the "General" tab:
   - **Display Name**: `MDF Bands`
   - **Bundle Identifier**: `com.rdorn.mdfbands`
   - **Version**: Keep same as 70K target
   - **Deployment Target**: Keep same as 70K target

### Info.plist Configuration:
1. In the "Build Settings" tab, search for "Info.plist"
2. Change the "Info.plist File" path to point to `70000TonsBands/Info-MDF.plist`

### App Icons and Launch Screen:
1. You'll need to create separate app icon sets for MDF
2. In the "General" tab, under "App Icons and Launch Images":
   - Create a new App Icon set in Images.xcassets called "AppIcon-MDF"
   - Point the MDF target to use "AppIcon-MDF"

## Step 3: Configure Build Settings and Preprocessor Macros

### For 70K Bands Target:
1. Select "70K Bands" target
2. Go to "Build Settings" tab
3. Search for "Preprocessor Macros"
4. Under "Swift Compiler - Custom Flags" → "Active Compilation Conditions"
5. Add `FESTIVAL_70K` for both Debug and Release configurations

### For MDF Bands Target:
1. Select "MDF Bands" target  
2. Go to "Build Settings" tab
3. Search for "Preprocessor Macros"
4. Under "Swift Compiler - Custom Flags" → "Active Compilation Conditions"
5. Add `FESTIVAL_MDF` for both Debug and Release configurations

## Step 4: Configure Firebase Files

### For 70K Bands Target:
1. In "Build Phases" tab, expand "Copy Bundle Resources"
2. Ensure `GoogleService-Info-70K.plist` is included
3. Remove `GoogleService-Info-MDF.plist` if present

### For MDF Bands Target:
1. In "Build Phases" tab, expand "Copy Bundle Resources"  
2. Remove `GoogleService-Info-70K.plist` if present
3. Add `GoogleService-Info-MDF.plist`

**Note**: Each target uses its own specifically named Firebase config file. The app code will automatically load the correct file based on the festival configuration.

## Step 5: Update Schemes

### 70K Bands Scheme:
1. Edit the "70K Bands" scheme
2. Ensure it builds the "70K Bands" target
3. Set any environment variables if needed

### MDF Bands Scheme:
1. Edit the "MDF Bands" scheme  
2. Ensure it builds the "MDF Bands" target
3. Set any environment variables if needed

## Step 6: Test Configuration

1. Select the "70K Bands" scheme and build
   - Should compile with `FESTIVAL_70K` defined
   - Should use 70K-specific configuration values
   
2. Select the "MDF Bands" scheme and build
   - Should compile with `FESTIVAL_MDF` defined  
   - Should use MDF-specific configuration values

## Step 7: Verify Configuration

After setup, verify that:

1. **70K Bands** shows:
   - App name: "70K Bands"
   - Bundle ID: "com.rdorn.-0000TonsBands"
   - Uses 70K URLs and Firebase config

2. **MDF Bands** shows:
   - App name: "MDF Bands"  
   - Bundle ID: "com.rdorn.mdfbands"
   - Uses MDF URLs and Firebase config

## Files Created/Modified

The following files have been prepared for this setup:

- ✅ `FestivalConfig.swift` - Configuration system
- ✅ `Info-70K.plist` - 70K-specific Info.plist
- ✅ `Info-MDF.plist` - MDF-specific Info.plist (uses UILaunchScreen-MDF)
- ✅ `UILaunchScreen-MDF.xib` - MDF-specific launch screen with "MDF Bands!" title
- ✅ `mdf_logo.imageset` - Custom MDF Bands logo matching 70K style (228x37px)
- ✅ `GoogleService-Info-MDF.plist` - Placeholder MDF Firebase config
- ✅ Updated `Constants.swift` to use configuration system
- ✅ Updated `preferenceDefault.swift` to use configuration system
- ✅ Updated `AppDelegate.swift` to use configuration system
- ✅ Updated `imageHandler.swift` to use festival-specific logo fallbacks
- ✅ Updated `DetailViewModel.swift` to use festival-specific logo fallbacks

## Next Steps

1. Follow the Xcode target setup instructions above
2. Create MDF-specific app icons and launch screens
3. Replace the placeholder `GoogleService-Info-MDF.plist` with actual MDF Firebase configuration
4. Test both targets thoroughly
5. Set up separate provisioning profiles for each bundle identifier

## Troubleshooting

- If builds fail, check that the preprocessor macros are set correctly
- Ensure each target has the correct Info.plist file path
- Verify Firebase configuration files are correctly assigned to each target
- Check that bundle identifiers are unique for each target

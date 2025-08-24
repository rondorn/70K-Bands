# Android Multi-Festival Setup Summary

## Overview
The Android app has been successfully configured to support both 70K Bands and MDF Bands festivals using a single codebase with build variants.

## ✅ Completed Implementation

### 1. Build Variants Configuration
**File**: `app/build.gradle`
- **70K Bands variant**: `bands70k`
  - Application ID: `com.Bands70k`
  - Build config field: `FESTIVAL_TYPE = "70K"`
  - App name: "70K Bands"
- **MDF Bands variant**: `mdfbands`
  - Application ID: `com.mdfbands`
  - Build config field: `FESTIVAL_TYPE = "MDF"`
  - App name: "MDF Bands"

### 2. Festival Configuration System
**File**: `app/src/main/java/com/Bands70k/FestivalConfig.java`
- Centralized configuration class using singleton pattern
- Automatically detects festival type from `BuildConfig.FESTIVAL_TYPE`
- Provides festival-specific settings:
  - App names and package identifiers
  - Storage URLs and Firebase configs
  - Push notification topics
  - Default artist/schedule URLs
  - Logo and icon resource IDs
  - Notification channel settings

### 3. MDF-Specific Configuration
**MDF Settings in FestivalConfig**:
- Festival Name: "Maryland Death Fest"
- App Name: "MDF Bands"
- Package: "com.mdfbands"
- Storage URL: `https://www.dropbox.com/scl/fi/39jr2f37rhrdk14koj0pz/mdf_productionPointer.txt?rlkey=ij3llf5y1mxwpq2pmwbj03e6t&raw=1`
- Artist URL: `https://www.dropbox.com/scl/fi/6eg74y11n070airoewsfz/mdf_artistLineup_2026.csv?rlkey=35i20kxtc6pc6v673dnmp1465&raw=1`
- Schedule URL: `https://www.dropbox.com/scl/fi/3u1sr1312az0wd3dcpbfe/mdf_artistsSchedule2026_test.csv?rlkey=t96hj530o46q9fzz83ei7fllj&raw=1`
- Subscription Topics: `mdf_global`, `mdf_testing`, `mdf_unofficalEvents`
- Logo Resources: `mdf_logo`, `mdf_bands_icon`

### 4. Firebase Configuration
**Build Variant Specific**:
- `app/src/bands70k/google-services.json` - 70K Firebase config
- `app/src/mdfbands/google-services.json` - MDF Firebase config (placeholder)

### 5. Dynamic Preference Screen Title
**File**: `app/src/main/java/com/Bands70k/preferenceLayout.java`
- Uses `FestivalConfig.getInstance().appName` + localized "Preferences" string
- Results in:
  - 70K app: "70K Bands Preferences" / "70K Bands Préférences" etc.
  - MDF app: "MDF Bands Preferences" / "MDF Bands Préférences" etc.

### 6. Localized String Resources
**Updated Files**:
- `app/src/main/res/values/strings.xml` - Added `<string name="Preferences">Preferences</string>`
- `app/src/main/res/values-fr/strings.xml` - Added `<string name="Preferences">Préférences</string>`
- `app/src/main/res/values-de/strings.xml` - Added `<string name="Preferences">Einstellungen</string>`
- `app/src/main/res/values-es/strings.xml` - Added `<string name="Preferences">Preferencias</string>`
- `app/src/main/res/values-pt/strings.xml` - Added `<string name="Preferences">Preferências</string>`
- `app/src/main/res/values-da/strings.xml` - Added `<string name="Preferences">Præferencer</string>`

### 7. Visual Assets
**Existing MDF Assets**:
- `app/src/main/res/drawable/mdf_logo.png` - MDF event logo (fallback for band images)
- `app/src/main/res/drawable/mdf_bands_icon.png` - MDF app icon

### 8. Integration with Existing Systems
**Updated Files**:
- `staticVariables.java` - Uses `FestivalConfig` for URLs, notification channels, and subscription topics
- All URL lookups now use the festival-specific configuration
- Push notification system uses festival-specific topics
- Image fallback system uses festival-specific logos

## 🚀 How to Build

### Build 70K Bands App:
```bash
./gradlew assembleBands70kDebug
# or
./gradlew assembleBands70kRelease
```

### Build MDF Bands App:
```bash
./gradlew assembleMdfbandsDebug
# or
./gradlew assembleMdfbandsRelease
```

## 📱 App Behavior

### 70K Bands App:
- App name: "70K Bands"
- Package: `com.Bands70k`
- Uses 70K-specific URLs, Firebase config, and branding
- Preferences title: "70K Bands Preferences" (localized)
- Fallback logo: `bands_70k_icon`

### MDF Bands App:
- App name: "MDF Bands"  
- Package: `com.mdfbands`
- Uses MDF-specific URLs, Firebase config, and branding
- Preferences title: "MDF Bands Preferences" (localized)
- Fallback logo: `mdf_logo`

## 🔧 Configuration Management

The `FestivalConfig` class automatically detects which festival to configure based on the build variant:
- Uses `BuildConfig.FESTIVAL_TYPE` set by Gradle product flavors
- Provides a singleton instance accessible throughout the app
- Centralizes all festival-specific settings in one location
- Makes it easy to add new festivals or modify existing ones

## ✨ Key Benefits

1. **Single Codebase**: Both apps built from the same source code
2. **Easy Maintenance**: Core functionality updates apply to both apps
3. **Festival-Specific Branding**: Each app has its own identity
4. **Localization Support**: Preference titles properly localized
5. **Scalable Architecture**: Easy to add more festivals in the future
6. **Build Automation**: Gradle handles the complexity of variant-specific resources

## 🎯 Status: COMPLETE ✅

All Android multi-festival functionality has been implemented and is ready for use. The system mirrors the iOS implementation and provides the same level of festival-specific customization while maintaining a shared codebase.

# Hash-Based Caching Implementation for Android

## Overview

The Android app now implements a hash-based cache invalidation system similar to the iOS version. This system only processes downloaded files when their content has actually changed, improving performance and reducing unnecessary processing.

## Architecture

### CacheHashManager

A new singleton utility class (`CacheHashManager.java`) that handles:
- **Hash Calculation**: Uses SHA-256 to create unique fingerprints of file content
- **Hash Storage**: Stores hashes in SharedPreferences for persistence across app sessions
- **Change Detection**: Compares new file hashes against cached hashes
- **Temp File Processing**: Manages temporary files and only moves them to final location if content changed

### Key Features

1. **Temp File Strategy**: Downloads go to `.temp` files first
2. **Hash Comparison**: Only processes files if hash has changed
3. **Automatic Cleanup**: Removes temp files after processing
4. **Logging**: Comprehensive logging for debugging and monitoring

## Modified Components

### 1. BandInfo.DownloadBandFile()
- Downloads band data to `70kbandInfo.csv.temp`
- Compares hash against cached version
- Only processes if content changed
- Stores hash as `"bandInfo"` in SharedPreferences

### 2. scheduleInfo.DownloadScheduleFile()
- Downloads schedule data to `70kScheduleInfo.csv.temp` 
- Uses same hash comparison logic
- Stores hash as `"scheduleInfo"` in SharedPreferences

### 3. CombinedImageListHandler.saveCombinedImageList()
- Creates temp JSON file for image list metadata
- Only saves to final location if content changed
- Stores hash as `"combinedImageList"` in SharedPreferences

## Benefits

### Performance Improvements
- ✅ **Reduced File I/O**: Only writes files when content actually changes
- ✅ **Faster App Startup**: Skips unnecessary parsing of unchanged data
- ✅ **Bandwidth Savings**: Still downloads to check for changes, but avoids processing overhead
- ✅ **Battery Life**: Less CPU usage from unnecessary file processing

### Reliability
- ✅ **Atomic Operations**: Files are only moved to final location if processing succeeds
- ✅ **Crash Safety**: Temp files prevent corruption of cached data
- ✅ **Consistent State**: Cache and data files stay synchronized

## Usage Examples

### Checking if Data Changed
```java
CacheHashManager cacheManager = CacheHashManager.getInstance();
boolean dataChanged = cacheManager.hasFileChanged(tempFile, "bandInfo");
if (dataChanged) {
    // Process the new data
    processNewBandData();
}
```

### Processing Files Conditionally
```java
// This automatically handles hash comparison and file moving
boolean wasProcessed = cacheManager.processIfChanged(tempFile, finalFile, "dataType");
if (wasProcessed) {
    Log.i(TAG, "Data changed, processed new file");
} else {
    Log.i(TAG, "Data unchanged, using cached version");
}
```

## Hash Storage

Hashes are stored in SharedPreferences under the key `"CacheHashes"`:
- `"bandInfo"` - Hash of band data CSV
- `"scheduleInfo"` - Hash of schedule data CSV  
- `"combinedImageList"` - Hash of combined image list JSON

## Debugging

### Log Messages
The system provides detailed logging:
```
CacheHashManager: Calculated hash for 70kbandInfo.csv: a1b2c3d4...
CacheHashManager: Hash comparison for bandInfo: CHANGED
BandInfo: Band data has changed, processed new file
```

### Force Refresh
To force a refresh of all cached data:
```java
CacheHashManager.getInstance().clearAllHashes();
```

## Migration Notes

### Backward Compatibility
- ✅ First run after update will treat all files as "changed" (no cached hashes)
- ✅ Existing cached files continue to work normally
- ✅ No data migration required

### Testing
- Unit tests can use `staticVariables.inUnitTests = true` to bypass online checks
- Hash clearing methods available for test isolation
- Comprehensive error handling for network failures

## File Locations

### Temp Files (automatically cleaned up)
- `/70kBands/70kbandInfo.csv.temp`
- `/70kBands/70kScheduleInfo.csv.temp` 
- `/70kBands/cachedImages/combinedImageList.json.temp`

### Final Files (existing locations unchanged)
- `/70kBands/70kbandInfo.csv`
- `/70kBands/70kScheduleInfo.csv`
- `/70kBands/cachedImages/combinedImageList.json`

### Hash Storage
- SharedPreferences: `CacheHashes`

## Error Handling

The system gracefully handles:
- **Network failures**: Temp files are cleaned up, existing cache remains valid
- **File system errors**: Falls back to treating files as "changed"
- **Hash calculation errors**: Assumes content has changed for safety
- **Missing SharedPreferences**: Treats as first run, processes all files

This implementation provides the same benefits as the iOS version while maintaining the existing Android app architecture and user experience.

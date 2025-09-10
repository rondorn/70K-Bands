# Data Loading System - Complete Rework

## Overview

The data loading system has been completely reworked to implement a proper loading sequence with caching, background refresh, and immediate GUI updates. This document outlines the new architecture and how each component works.

## Loading Sequence

### 1. Constants.swift - Data Map Loading
**Priority**: First (must load before any other collector runs)

**On Install**:
- Loads data map of all datafile URLs immediately from URL
- Must complete before any other collector runs

**After Install**:
- Loads from local cache first
- Refreshes cache in background
- No blocking of other operations

**Implementation**: `ConstantsLoader.swift`

### 2. bandNamesHandler.swift - Band Names and Meta Data
**Priority**: Second (after constants)

**Trigger Points**:
- First launch
- Pull to refresh
- Returning from preference screen
- Push notifications
- Returning from details

**Behavior**:
- Immediately display cached data
- Start background refresh and write from URL into file cache
- Refresh GUI once completed

**Implementation**: Updated `bandNamesHandler.swift`

### 3. scheduleHandler.swift - Yearly Schedule
**Priority**: Third (after band names)

**Trigger Points**:
- First launch
- Pull to refresh
- Returning from preference screen
- Push notifications
- Returning from details

**Behavior**:
- Immediately display cached data
- Start background refresh and write from URL into file cache
- Refresh GUI once completed

**Implementation**: Updated `scheduleHandler.swift`

### 4. dataHandler.swift - User Band Preferences
**Priority**: Fourth (after schedule)

**Behavior**:
- Load and display user preferences for bands
- If user makes change to priority, display immediately in both details and main view controller list

**Implementation**: Updated `dataHandler.swift`

### 5. ShowsAttended.swift - User Event Preferences
**Priority**: Fifth (after user data)

**Behavior**:
- Load and display user preferences for events
- If user makes change to attendance, display immediately in both details and main view controller list

**Implementation**: Updated `ShowsAttended.swift`

### 6. localNotificationHandler.swift - Schedule Alerts
**Priority**: Sixth (after user data)

**Behavior**:
- Run whenever schedule, attendance, or priority changes
- Can narrow change to just the band or event that changed

**Implementation**: Updated `localNotificationHandler.swift`

### 7. CustomBandDescription.swift - Band Descriptions
**Priority**: Background (non-blocking)

**Behavior**:
- Do all collect when user puts app to background
- Otherwise, display description on demand
- Ensure Details GUI updated when note is available
- Use local note whenever possible using existing logic

**Implementation**: Updated `CustomBandDescription.swift`

### 8. imageHandler.swift - Band Images
**Priority**: Background (non-blocking)

**Behavior**:
- Do all collect when user puts app to background
- Otherwise, display image on demand
- Ensure Details GUI updated when image is available
- Use local image whenever possible using existing logic

**Implementation**: Updated `imageHandler.swift`

### 9. Firebase Handlers - Usage Stats
**Priority**: Exit activities (parallel)

**Behavior**:
- firebaseEventDataWrite.swift and firebaseBandDataWrite.swift
- Run in sequence to each other in parallel to other exit activities

**Implementation**: Integrated into `DataLoadingCoordinator`

## Key Components

### DataLoadingCoordinator
The main coordinator that manages the entire loading sequence:

```swift
// Start loading on app launch
DataLoadingCoordinator.shared.startLoadingOnLaunch {
    // GUI refresh callback
}

// Start loading on pull to refresh
DataLoadingCoordinator.shared.startLoadingOnPullToRefresh {
    // GUI refresh callback
}

// Start loading on return from details
DataLoadingCoordinator.shared.startLoadingOnReturnFromDetails {
    // GUI refresh callback
}
```

### ConstantsLoader
Handles the loading of the data map with proper caching:

```swift
// Load data map
ConstantsLoader.shared.loadDataMap { 
    // Completion callback
}

// Get pointer URL data
let url = ConstantsLoader.shared.getPointerUrlData(keyValue: "artistUrl")
```

## Caching Strategy

### Memory Cache
- Static caches in `cacheVariables`
- Immediate access for GUI updates
- Thread-safe access with queues

### Disk Cache
- Persistent storage for offline use
- Fallback when network unavailable
- Automatic cleanup and refresh

### Background Refresh
- Non-blocking updates
- GUI continues to work while refreshing
- Automatic retry on failure

## GUI Updates

### Immediate Display
- Cached data shown immediately
- No waiting for network operations
- Responsive user experience

### Background Refresh
- Data updated in background
- GUI refreshed when complete
- Notification-based updates

### Error Handling
- Graceful degradation to cached data
- User-friendly error messages
- Automatic retry mechanisms

## Trigger Points

### App Launch
```swift
DataLoadingCoordinator.shared.startLoadingOnLaunch {
    // Refresh GUI
}
```

### Pull to Refresh
```swift
DataLoadingCoordinator.shared.startLoadingOnPullToRefresh {
    // End refresh control and refresh GUI
}
```

### Return from Details
```swift
DataLoadingCoordinator.shared.startLoadingOnReturnFromDetails {
    // Refresh GUI
}
```

### Return from Preferences
```swift
DataLoadingCoordinator.shared.startLoadingOnReturnFromPreferences {
    // Refresh GUI
}
```

### Push Notifications
```swift
DataLoadingCoordinator.shared.startLoadingOnPushNotification {
    // Refresh GUI
}
```

### Data Changes
```swift
// When priority changes
DataLoadingCoordinator.shared.onBandPriorityChanged()

// When attendance changes
DataLoadingCoordinator.shared.onAttendanceChanged()
```

## Background Operations

### App Background
```swift
func applicationWillResignActive(_ application: UIApplication) {
    DataLoadingCoordinator.shared.startBackgroundDataLoading()
}
```

### App Exit
```swift
func applicationWillTerminate(_ application: UIApplication) {
    DataLoadingCoordinator.shared.handleAppExit()
}
```

## Error Handling

### Network Issues
- Use cached data when network unavailable
- Background retry when network restored
- User-friendly error messages

### Timeout Protection
- 30-second timeout for network operations
- Automatic fallback to cached data
- No hanging operations

### Year Change
- Automatic detection of year changes
- Clear caches for new year
- Restart loading for new year

## Performance Considerations

### Serial vs Parallel
- Critical data loads serially (constants, band names, schedule)
- User data loads in parallel (priorities, attendance)
- Background data loads non-blocking (descriptions, images)

### Memory Management
- Static caches for performance
- Automatic cleanup of old data
- Efficient memory usage

### Battery Optimization
- Background operations use low priority
- Network operations batched
- Smart refresh based on data age

## Migration from Old System

### Old Way (Problematic)
```swift
// ❌ Race conditions and blocking
bandNamesHandler.shared.getCachedData { ... }
scheduleHandler.shared.getCachedData()
ShowsAttended().getCachedData()
dataHandler().getCachedData()
```

### New Way (Serial and Safe)
```swift
// ✅ Proper sequence with caching
DataLoadingCoordinator.shared.startLoadingOnLaunch {
    // GUI refresh callback
}
```

## Benefits

### 1. No More Race Conditions
- Serial execution prevents conflicts
- Each step waits for previous step to complete

### 2. Proper Data Dependencies
- Constants load first (required for other data)
- Band names load after constants
- Schedule loads after band names

### 3. Immediate GUI Updates
- Cached data shown immediately
- Background refresh doesn't block GUI
- User sees data as it becomes available

### 4. Robust Error Handling
- Network issues don't crash the app
- Graceful degradation to cached data
- Automatic retry mechanisms

### 5. Year Change Safety
- Automatic detection of year changes
- Proper cache clearing and restart
- No data corruption

## Testing

### Unit Tests
- Test each component independently
- Mock network responses
- Test error conditions

### Integration Tests
- Test complete loading sequence
- Test year change scenarios
- Test background operations

### Performance Tests
- Measure loading times
- Test memory usage
- Test battery impact

## Future Enhancements

### 1. Progress Tracking
- Add progress callbacks for each step
- Show loading progress in UI
- Better user feedback

### 2. Selective Loading
- Allow loading only specific data types
- Skip steps that aren't needed
- Optimize for specific use cases

### 3. Smart Refresh
- Periodic background refresh
- Refresh based on data age
- User preference-based refresh

### 4. Offline Mode
- Better offline data handling
- Queue changes for when online
- Sync when network restored

This new system provides a robust, reliable foundation for data loading that eliminates race conditions and ensures data consistency across the app. 
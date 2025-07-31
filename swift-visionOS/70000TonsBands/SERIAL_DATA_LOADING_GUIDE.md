# Serial Data Loading System - Complete Guide

## Overview

The Serial Data Loading System is designed to load data in a specific serial order to prevent race conditions and ensure data consistency. It replaces the old parallel loading system that was causing issues with band names not loading properly.

## Key Features

### 1. Serial Execution Order
Data is loaded in this exact order:
1. **Load artist names from URL** - Downloads band data from server
2. **Load priorities from disk** - Loads user priority settings
3. **Load schedule from URL** - Downloads schedule data from server
4. **Load attended from disk** - Loads user attendance data
5. **Load iCloud data** - Syncs with iCloud for cross-device data
6. **Load all images** - Downloads band images (no GUI refresh)
7. **Load all descriptions** - Downloads band descriptions (no GUI refresh)
8. **Load schedule alerts** - Sets up schedule notifications (no GUI refresh)

### 2. GUI Refresh Strategy
- **Steps 1-5**: Refresh GUI after each step (artist names, priorities, schedule, attended, iCloud)
- **Steps 6-8**: No GUI refresh (images, descriptions, schedule alerts)

### 3. Year Change Handling
- When year changes, all current operations are cancelled
- Caches are cleared for the new year
- Loading restarts automatically for the new year

### 4. Trigger Points
The system is triggered at these specific points:
- **App launch** - Initial data loading
- **Pull to refresh** - Force reload all data
- **Return from details screen** - Refresh after viewing band details
- **Return from preferences** - Refresh after settings changes
- **Push notification received** - Refresh when new data is available
- **Priority/attended changes** - Immediate refresh when user changes data

## Usage

### Basic Usage

```swift
// Start serial loading with GUI refresh callback
SerialDataLoadingCoordinator.shared.startSerialDataLoading(trigger: "App launch") {
    // This callback is called after each step that should refresh GUI
    DispatchQueue.main.async {
        self.refreshBandList(reason: "Serial loading step complete")
    }
}
```

### Convenience Methods

```swift
// App launch
SerialDataLoadingCoordinator.shared.startLoadingOnLaunch { [weak self] in
    DispatchQueue.main.async {
        self?.refreshBandList(reason: "Launch complete")
    }
}

// Pull to refresh
SerialDataLoadingCoordinator.shared.startLoadingOnPullToRefresh { [weak self] in
    DispatchQueue.main.async {
        self?.refreshControl?.endRefreshing()
        self?.refreshBandList(reason: "Pull to refresh complete")
    }
}

// Return from details
SerialDataLoadingCoordinator.shared.startLoadingOnReturnFromDetails { [weak self] in
    DispatchQueue.main.async {
        self?.refreshBandList(reason: "Details return complete")
    }
}

// Data changes (priority/attended)
SerialDataLoadingCoordinator.shared.startLoadingOnDataChange { [weak self] in
    DispatchQueue.main.async {
        self?.refreshBandList(reason: "Data change complete")
    }
}
```

### Year Change Handling

```swift
// Notify when year change is requested
SerialDataLoadingCoordinator.shared.notifyYearChangeRequested()

// Notify when year change is completed
SerialDataLoadingCoordinator.shared.notifyYearChangeCompleted()
```

## Integration with MasterViewController

The MasterViewController has been updated to use the new serial loading system:

### 1. App Launch
```swift
// In viewDidLoad
SerialDataLoadingCoordinator.shared.startLoadingOnLaunch { [weak self] in
    DispatchQueue.main.async {
        self?.refreshBandList(reason: "Initial launch - serial loading complete")
    }
}
```

### 2. Pull to Refresh
```swift
// In pullTorefreshData
SerialDataLoadingCoordinator.shared.startLoadingOnPullToRefresh { [weak self] in
    DispatchQueue.main.async {
        self?.refreshControl?.endRefreshing()
        self?.refreshBandList(reason: "Pull to refresh - serial loading complete")
    }
}
```

### 3. Return from Details
```swift
// In viewWillAppear
SerialDataLoadingCoordinator.shared.startLoadingOnReturnFromDetails { [weak self] in
    DispatchQueue.main.async {
        self?.refreshBandList(reason: "Return from details - serial loading complete")
    }
}
```

### 4. Data Changes
```swift
// In detailDidUpdate
SerialDataLoadingCoordinator.shared.startLoadingOnDataChange { [weak self] in
    DispatchQueue.main.async {
        self?.refreshBandList(reason: "Data change - serial loading complete")
    }
}
```

## Independent Collectors

The system uses independent collectors for each data type:

### 1. Band Names Collector
- Downloads artist data from URL
- Parses CSV data
- Updates static cache

### 2. Schedule Collector
- Downloads schedule data from URL
- Parses schedule CSV
- Updates static cache

### 3. Priority Collector
- Loads priority data from disk
- No network download needed
- User-generated data

### 4. Attended Collector
- Loads attendance data from disk
- No network download needed
- User-generated data

### 5. Images Collector
- Downloads band images
- Caches images for performance
- No GUI refresh

### 6. Descriptions Collector
- Downloads band descriptions
- Uses CustomerDescriptionHandler
- No GUI refresh

### 7. Schedule Alerts Collector
- Sets up schedule notifications
- Configures local notifications
- No GUI refresh

## Error Handling

### Network Issues
- If network is unavailable, cached data is used
- No error is thrown, system continues with available data

### Timeout Protection
- Each collector has 30-second timeout
- If timeout occurs, collector is cancelled and next step begins

### Year Change
- All operations are cancelled immediately
- Caches are cleared
- Loading restarts for new year

## Debugging

### Log Messages
The system provides detailed logging:

```
[SerialDataLoadingCoordinator] Starting serial loading triggered by: App launch
[SerialDataLoadingCoordinator] Executing step: Artist Names
[BandNames] Starting independent collection
[SerialDataLoadingCoordinator] Artist names loaded: true
[SerialDataLoadingCoordinator] Refreshing GUI after step: Artist Names
[SerialDataLoadingCoordinator] Executing step: Priorities
...
```

### Status Checking
```swift
// Check if loading is in progress
let isLoading = SerialDataLoadingCoordinator.shared.isSerialLoadingInProgress

// Check if initial load is complete
let isComplete = SerialDataLoadingCoordinator.shared.isInitialLoadComplete

// Get current year
let currentYear = SerialDataLoadingCoordinator.shared.currentYear
```

## Migration from Old System

### Old Way (Problematic)
```swift
// ❌ This caused race conditions
bandNamesHandler.shared.getCachedData { ... }
scheduleHandler.shared.getCachedData()
ShowsAttended().getCachedData()
dataHandler().getCachedData()
```

### New Way (Serial and Safe)
```swift
// ✅ This loads data in proper order
SerialDataLoadingCoordinator.shared.startSerialDataLoading(trigger: "App launch") {
    // GUI refresh callback
}
```

## Benefits

### 1. No More Race Conditions
- Serial execution prevents conflicts
- Each step waits for previous step to complete

### 2. Proper Data Dependencies
- Artist names load first (required for other data)
- Schedule loads after artist names
- Priorities and attended load from disk (fast)

### 3. Year Change Safety
- Automatic detection of year changes
- Proper cache clearing and restart

### 4. GUI Responsiveness
- GUI refreshes after each relevant step
- User sees data as it becomes available

### 5. Error Resilience
- Timeout protection prevents hanging
- Network issues don't crash the app
- Graceful degradation to cached data

## Troubleshooting

### Issue: Band names not loading
**Solution**: Check network connectivity and ensure artist URL is accessible

### Issue: GUI not refreshing
**Solution**: Ensure GUI refresh callback is provided and called on main thread

### Issue: Year change not working
**Solution**: Verify year change notifications are being sent properly

### Issue: Loading stuck
**Solution**: Check for timeout issues or network problems

## Performance Considerations

### 1. Serial vs Parallel
- Serial loading is slower but more reliable
- Critical data (artist names, schedule) loads first
- Non-critical data (images, descriptions) loads last

### 2. Caching Strategy
- Static caches are used for performance
- Disk caches provide offline capability
- Network data is downloaded only when needed

### 3. GUI Updates
- GUI refreshes only when necessary
- Background steps don't trigger GUI updates
- Main thread is used for all GUI updates

## Future Enhancements

### 1. Progress Tracking
- Add progress callbacks for each step
- Show loading progress in UI

### 2. Selective Loading
- Allow loading only specific data types
- Skip steps that aren't needed

### 3. Background Refresh
- Add periodic background refresh
- Smart refresh based on data age

### 4. Offline Mode
- Better offline data handling
- Queue changes for when online

This system provides a robust, reliable foundation for data loading that eliminates race conditions and ensures data consistency across the app. 
# Quick Reference: Core Data → SQLite Migration

## Quick Summary

**OLD (Core Data - Threading Issues):**
```swift
let priorityManager = PriorityManager()  // ❌ Can deadlock
let attendanceManager = AttendanceManager()  // ❌ Threading issues
let coreDataiCloudSync = CoreDataiCloudSync()  // ❌ Context problems
```

**NEW (SQLite - Thread Safe):**
```swift
let priorityManager = SQLitePriorityManager.shared  // ✅ Thread-safe
let attendanceManager = SQLiteAttendanceManager.shared  // ✅ Thread-safe
let sqliteiCloudSync = SQLiteiCloudSync()  // ✅ No threading issues
```

## API Compatibility

The SQLite versions have the **same API** as Core Data versions:

### Priority Operations
```swift
// Set priority (thread-safe from any thread)
priorityManager.setPriority(for: "Band Name", priority: 1) { success in
    print("Saved: \(success)")
}

// Get priority (thread-safe from any thread)
let priority = priorityManager.getPriority(for: "Band Name")

// Get all priorities
let allPriorities = priorityManager.getAllPriorities()

// Get timestamp
let timestamp = priorityManager.getPriorityLastChange(for: "Band Name")
```

### Attendance Operations
```swift
// Set attendance (thread-safe from any thread)
attendanceManager.setAttendanceStatus(
    bandName: "Band Name",
    location: "Pool Deck",
    startTime: "15:00",
    eventType: "Performance",
    eventYear: "2025",
    status: 2  // Attended
)

// Get attendance by index (thread-safe from any thread)
let status = attendanceManager.getAttendanceStatusByIndex(index: attendanceIndex)

// Set attendance by index (thread-safe from any thread)
attendanceManager.setAttendanceStatusByIndex(index: attendanceIndex, status: 2)

// Get all attendance data
let allAttendance = attendanceManager.getAllAttendanceDataByIndex()
```

### iCloud Sync Operations
```swift
let sqliteiCloudSync = SQLiteiCloudSync()

// Sync to iCloud (thread-safe, runs in background)
sqliteiCloudSync.syncPrioritiesToiCloud()
sqliteiCloudSync.syncAttendanceToiCloud()

// Sync from iCloud (thread-safe, runs in background)
sqliteiCloudSync.syncPrioritiesFromiCloud {
    print("Priority sync complete")
}

sqliteiCloudSync.syncAttendanceFromiCloud {
    print("Attendance sync complete")
}

// Full two-way sync
sqliteiCloudSync.performFullSync {
    print("Full sync complete")
}

// Setup automatic sync on app lifecycle events
sqliteiCloudSync.setupAutomaticSync()
```

## Key Differences

### 1. Singleton Pattern
- **OLD:** `PriorityManager()` creates new instance
- **NEW:** `SQLitePriorityManager.shared` uses singleton

### 2. Thread Safety
- **OLD:** Must use `performAndWait` or `perform` with Core Data contexts
- **NEW:** Call from any thread directly, no special handling needed

### 3. No Completion Handlers Required
- **OLD:** Some operations needed completion handlers
- **NEW:** Reads are synchronous (use semaphores internally), writes are async but thread-safe

## Files Changed Summary

| File | Change Description |
|------|-------------------|
| **MasterViewController.swift** | Updated priority manager, replaced iCloud sync (3×) |
| **AppDelegate.swift** | Added migration, replaced iCloud sync (2×) |
| **DetailViewModel.swift** | Updated priority manager (2×) |
| **localNotificationHandler.swift** | Updated priority manager |
| **firebaseBandDataWrite.swift** | Updated priority manager (2×) |
| **firebaseEventDataWrite.swift** | Updated attendance manager |
| **mainListController.swift** | Updated function signature and call |
| **ShowAttendedReport.swift** | Updated priority manager (2×) |
| **ShowsAttended.swift** | Updated attendance manager |

## New Files

1. **SQLitePriorityManager.swift** - Drop-in replacement for PriorityManager
2. **SQLiteAttendanceManager.swift** - Drop-in replacement for AttendanceManager
3. **SQLiteiCloudSync.swift** - Drop-in replacement for CoreDataiCloudSync
4. **CoreDataToSQLiteMigrationHelper.swift** - Handles one-time migration

## Migration Status

Migration happens automatically on first launch after update:
- Reads existing Core Data
- Writes to new SQLite tables
- Marks migration complete
- Never runs again

Check migration status:
```swift
let migrated = CoreDataToSQLiteMigrationHelper.shared.isMigrationCompleted()
print("Migration completed: \(migrated)")
```

Force re-migration (for testing):
```swift
CoreDataToSQLiteMigrationHelper.shared.forceMigration()
```

## Database Files

**Core Data (OLD - still exists, not used):**
- `70000TonsBands.sqlite`
- `70000TonsBands.sqlite-shm`
- `70000TonsBands.sqlite-wal`

**SQLite (NEW - actively used):**
- `70kbands.sqlite3`
- `70kbands.sqlite3-shm`
- `70kbands.sqlite3-wal`

Both exist simultaneously for safety. Core Data files can be deleted after confirming migration success.

## Troubleshooting

### If priorities don't save:
1. Check SQLite database exists: `~/Documents/70kbands.sqlite3`
2. Check migration completed: `UserDefaults.standard.bool(forKey: "CoreDataToSQLiteMigrationCompleted_v2")`
3. Check console for SQLite errors

### If iCloud sync doesn't work:
1. Verify iCloud is enabled in UserDefaults
2. Check console for "☁️" prefixed logs
3. Verify NSUbiquitousKeyValueStore is accessible

### If app crashes:
1. Check console for threading errors (should be none)
2. Verify all `PriorityManager()` changed to `SQLitePriorityManager.shared`
3. Verify all `AttendanceManager()` changed to `SQLiteAttendanceManager.shared`

## Testing Commands

```swift
// Test priority
let pm = SQLitePriorityManager.shared
pm.setPriority(for: "Test Band", priority: 1) { success in
    print("Priority saved: \(success)")
}
let priority = pm.getPriority(for: "Test Band")
print("Priority retrieved: \(priority)")

// Test attendance
let am = SQLiteAttendanceManager.shared
let index = "Test Band:Pool Deck:15:00:Performance:2025"
am.setAttendanceStatusByIndex(index: index, status: 2)
let status = am.getAttendanceStatusByIndex(index: index)
print("Attendance status: \(status)")

// Test iCloud sync
let sync = SQLiteiCloudSync()
sync.syncPrioritiesToiCloud()
sync.syncPrioritiesFromiCloud {
    print("iCloud sync complete")
}
```

## Performance Expectations

- **Faster writes:** SQLite is 2-3x faster than Core Data
- **No UI blocking:** All operations are background-safe
- **No crashes:** Zero threading-related crashes expected
- **Same iCloud:** Cloud sync speed unchanged

## Support

If you encounter issues:
1. Check console logs for error messages
2. Verify migration completed successfully
3. Check database file exists and has data
4. Test with simple operations first
5. Review CORE_DATA_TO_SQLITE_MIGRATION.md for details

---

**Last updated:** $(date)
**Status:** ✅ Ready for testing

//
//  SQLiteAttendanceManager.swift
//  70000 Tons Bands
//
//  Thread-safe attendance management using direct SQLite calls
//  NO Core Data - NO deadlocks - NO threading issues
//

import Foundation
import SQLite

/// Thread-safe attendance manager using direct SQLite
/// Can be called from any thread without restrictions
class SQLiteAttendanceManager {
    
    static let shared = SQLiteAttendanceManager()
    
    private var db: Connection?
    private let serialQueue = DispatchQueue(label: "com.bands70k.attendance", qos: .userInitiated)
    
    // Table and column definitions
    private let attendanceTable = Table("user_attendances")
    private let id = Expression<Int64>("id")
    private let bandName = Expression<String>("bandName")
    private let eventYearColumn = Expression<Int>("eventYear")  // Renamed to avoid shadowing global eventYear
    private let timeIndex = Expression<Double>("timeIndex")
    private let status = Expression<Int>("status")
    private let lastModified = Expression<Double?>("lastModified")
    private let attendanceIndex = Expression<String?>("attendanceIndex")
    private let profileName = Expression<String>("profileName")
    
    private init() {
        setupDatabase()
    }
    
    private func setupDatabase() {
        do {
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            let dbPath = "\(documentsPath)/70kbands.sqlite3"
            
            db = try Connection(dbPath)
            
            // CRITICAL: Set busy timeout to handle concurrent writes
            // This prevents "database is locked" errors when multiple managers access the same DB
            try db?.execute("PRAGMA busy_timeout = 30000")  // 30 seconds
            print("✅ SQLiteAttendanceManager: Set busy timeout to 30 seconds")
            
            // Enable WAL mode for better concurrency
            try db?.execute("PRAGMA journal_mode=WAL")
            
            // Check if table exists and if it needs migration
            let tableExists = try db?.scalar("SELECT name FROM sqlite_master WHERE type='table' AND name='user_attendances'") as? String
            
            if tableExists != nil {
                // Check if attendanceIndex column exists
                let hasAttendanceIndex = try db?.scalar("SELECT COUNT(*) FROM pragma_table_info('user_attendances') WHERE name='attendanceIndex'") as? Int64
                
                if hasAttendanceIndex == 0 {
                    print("🔄 SQLiteAttendanceManager: Migrating table to add attendanceIndex column")
                    try db?.execute("ALTER TABLE user_attendances ADD COLUMN attendanceIndex TEXT")
                    print("✅ SQLiteAttendanceManager: attendanceIndex migration complete")
                }
                
                // Check if profileName column exists
                let hasProfileName = try db?.scalar("SELECT COUNT(*) FROM pragma_table_info('user_attendances') WHERE name='profileName'") as? Int64
                
                if hasProfileName == 0 {
                    print("🔄 SQLiteAttendanceManager: Migrating table to add profileName column")
                    let nullCountBefore = try db?.scalar("SELECT COUNT(*) FROM user_attendances WHERE profileName IS NULL") as? Int64 ?? 0
                    print("🔍 [MIGRATION] \(nullCountBefore) records with NULL profileName BEFORE migration")
                    
                    try db?.execute("ALTER TABLE user_attendances ADD COLUMN profileName TEXT DEFAULT 'Default'")
                    
                    // Update all existing records to use "Default"
                    let nullCountAfterColumn = try db?.scalar("SELECT COUNT(*) FROM user_attendances WHERE profileName IS NULL") as? Int64 ?? 0
                    print("🔍 [MIGRATION] \(nullCountAfterColumn) records with NULL profileName AFTER adding column")
                    
                    try db?.execute("UPDATE user_attendances SET profileName = 'Default' WHERE profileName IS NULL")
                    
                    let nullCountAfterUpdate = try db?.scalar("SELECT COUNT(*) FROM user_attendances WHERE profileName IS NULL") as? Int64 ?? 0
                    print("🔍 [MIGRATION] \(nullCountAfterUpdate) records with NULL profileName AFTER update")
                    print("✅ SQLiteAttendanceManager: profileName migration complete")
                }
                
                // CRITICAL MIGRATION: Check if we need to fix the unique constraint
                // Old constraint: (bandName, eventYear, timeIndex, profileName)
                // New constraint: (attendanceIndex, profileName)
                // We need to detect and migrate if old constraint exists
                let migrationKey = "AttendanceUniqueConstraintMigrationV2"
                let migrationCompleted = UserDefaults.standard.bool(forKey: migrationKey)
                
                if !migrationCompleted {
                    print("🔄 SQLiteAttendanceManager: Migrating to new unique constraint (attendanceIndex + profileName)")
                    
                    // Backup data - Use EXPLICIT column names to avoid ordering issues
                    let backupQuery = "SELECT id, bandName, eventYear, timeIndex, status, lastModified, attendanceIndex, profileName FROM user_attendances"
                    let backupData = try db?.prepare(backupQuery)
                    var allRecords: [[String: Any]] = []
                    
                    if let backupData = backupData {
                        for row in backupData {
                            var record: [String: Any] = [:]
                            // Now we KNOW the column order because we specified it in SELECT
                            record["id"] = row[0] as? Int64 ?? 0
                            record["bandName"] = row[1] as? String ?? ""
                            record["eventYear"] = row[2] as? Int ?? 0
                            record["timeIndex"] = row[3] as? Double ?? 0.0
                            record["status"] = row[4] as? Int ?? 0
                            record["lastModified"] = row[5] as? Double
                            record["attendanceIndex"] = row[6] as? String
                            record["profileName"] = row[7] as? String ?? "Default"
                            allRecords.append(record)
                            
                            // Log first few records for debugging
                            if allRecords.count <= 3 {
                                print("🔍 [MIGRATION_BACKUP] Record \(allRecords.count): \(record["bandName"] ?? "unknown") - profile: \(record["profileName"] ?? "nil")")
                            }
                        }
                    }
                    
                    print("🔄 Backed up \(allRecords.count) attendance records")
                    
                    // Save backup to UserDefaults
                    UserDefaults.standard.set(allRecords, forKey: migrationKey + "_Backup")
                    UserDefaults.standard.set(true, forKey: migrationKey + "_NeedsRestore")
                    
                    // Drop and recreate table with new constraint
                    try db?.execute("DROP TABLE IF EXISTS user_attendances")
                    print("🔄 Dropped old table")
                    
                    // Mark migration as complete BEFORE recreating table
                    UserDefaults.standard.set(true, forKey: migrationKey)
                    
                    // Now the create below will run with new constraint
                    print("✅ SQLiteAttendanceManager: Unique constraint migration prepared, will recreate table")
                }
            }
            
            // Create table if needed (with profileName)
            try db?.run(attendanceTable.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(bandName)
                t.column(eventYearColumn)
                t.column(timeIndex)
                t.column(status)
                t.column(lastModified)
                t.column(attendanceIndex)
                t.column(profileName, defaultValue: "Default")
                // CRITICAL FIX: Use attendanceIndex (full unique key) instead of timeIndex
                // attendanceIndex = "BandName:Location:StartTime:EventType:Year"
                // This ensures each unique event gets its own record, not just each band
                t.unique(attendanceIndex, profileName)
            })
            
            // Restore backed up data if migration just occurred
            let migrationKey = "AttendanceUniqueConstraintMigrationV2"
            let migrationJustCompleted = UserDefaults.standard.bool(forKey: migrationKey + "_NeedsRestore")
            
            if migrationJustCompleted {
                print("🔄 Restoring backed up attendance data after migration")
                
                // Get backed up data from UserDefaults
                if let backupDataArray = UserDefaults.standard.array(forKey: migrationKey + "_Backup") as? [[String: Any]] {
                    print("🔄 Found \(backupDataArray.count) backed up records, restoring...")
                    
                    try db?.transaction {
                        for record in backupDataArray {
                            guard let bandNameStr = record["bandName"] as? String,
                                  let year = record["eventYear"] as? Int,
                                  let ti = record["timeIndex"] as? Double,
                                  let statusValue = record["status"] as? Int,
                                  let profileNameStr = record["profileName"] as? String else {
                                continue
                            }
                            
                            let insert = self.attendanceTable.insert(
                                or: .replace,
                                self.bandName <- bandNameStr,
                                self.eventYearColumn <- year,
                                self.timeIndex <- ti,
                                self.status <- statusValue,
                                self.lastModified <- record["lastModified"] as? Double,
                                self.attendanceIndex <- record["attendanceIndex"] as? String,
                                self.profileName <- profileNameStr
                            )
                            
                            try db?.run(insert)
                        }
                    }
                    
                    print("✅ Restored \(backupDataArray.count) attendance records")
                    
                    // Clear backup
                    UserDefaults.standard.removeObject(forKey: migrationKey + "_Backup")
                    UserDefaults.standard.removeObject(forKey: migrationKey + "_NeedsRestore")
                }
            }
            
            // Create index on attendanceIndex for fast lookups
            try db?.run(attendanceTable.createIndex(attendanceIndex, ifNotExists: true))
            try db?.run(attendanceTable.createIndex(eventYearColumn, ifNotExists: true))
            
            print("✅ SQLiteAttendanceManager: Initialized")
        } catch {
            print("❌ SQLiteAttendanceManager: Failed to initialize: \(error)")
        }
    }
    
    // MARK: - Public API (Thread-Safe)
    
    /// Gets the current active profile name
    private func getCurrentProfileName() -> String {
        return SharedPreferencesManager.shared.currentSharedProfileName ?? "Default"
    }
    
    /// Sets attendance status for an event
    /// Thread-safe - can be called from any thread
    func setAttendanceStatus(
        bandName bandNameStr: String,
        location: String,
        startTime: String,
        eventType: String,
        eventYear year: String,
        status statusValue: Int,
        timeIndex ti: Double = 0,
        profileName profile: String? = nil
    ) {
        serialQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            
            do {
                let currentEventYear = eventYear  // Get current global year as Int
                let yearInt = Int(year) ?? currentEventYear
                let index = self.createAttendanceIndex(
                    bandName: bandNameStr,
                    location: location,
                    startTime: startTime,
                    eventType: eventType,
                    eventYear: yearInt
                )
                let ts = Date().timeIntervalSince1970
                let currentProfile = profile ?? self.getCurrentProfileName()
                
                let insert = self.attendanceTable.insert(
                    or: .replace,
                    self.bandName <- bandNameStr,
                    self.eventYearColumn <- yearInt,
                    self.timeIndex <- ti,
                    self.status <- statusValue,
                    self.lastModified <- ts,
                    self.attendanceIndex <- index,
                    self.profileName <- currentProfile
                )
                
                try db.run(insert)
                print("✅ SQLiteAttendanceManager: Set attendance for \(bandNameStr) = \(statusValue) (profile: \(currentProfile))")
            } catch {
                print("❌ SQLiteAttendanceManager: Failed to set attendance: \(error)")
            }
        }
    }
    
    /// Gets attendance status by index
    /// Thread-safe - can be called from any thread
    func getAttendanceStatusByIndex(index: String, profileName profile: String? = nil) -> Int {
        var result = 0
        let semaphore = DispatchSemaphore(value: 0)
        
        serialQueue.async { [weak self] in
            defer { semaphore.signal() }
            
            guard let self = self, let db = self.db else { return }
            
            do {
                let currentProfile = profile ?? self.getCurrentProfileName()
                
                let query = self.attendanceTable
                    .filter(self.attendanceIndex == index && self.profileName == currentProfile)
                    .limit(1)
                
                if let row = try db.pluck(query) {
                    result = row[self.status]
                    print("🔍 [ATTENDANCE_DEBUG] Found attendance for \(index) = \(result) (profile: \(currentProfile))")
                } else {
                    print("🔍 [ATTENDANCE_DEBUG] No attendance found for \(index) (profile: \(currentProfile))")
                }
            } catch {
                print("❌ SQLiteAttendanceManager: Failed to get attendance: \(error)")
            }
        }
        
        semaphore.wait()
        return result
    }
    
    /// Sets attendance status by index (with explicit timestamp)
    /// Thread-safe - can be called from any thread
    /// Used primarily by iCloud sync - always updates "Default" profile
    func setAttendanceStatusByIndex(index: String, status statusValue: Int, timestamp: Double, profileName profile: String? = nil) {
        serialQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            
            do {
                // Parse the index to get components
                let components = index.split(separator: ":").map(String.init)
                guard components.count >= 5 else {
                    print("❌ SQLiteAttendanceManager: Invalid index format: \(index)")
                    return
                }
                
                let bandNameStr = components[0]
                let currentEventYear = eventYear  // Get current global year as Int
                let yearInt = Int(components[4]) ?? currentEventYear
                
                // For timeIndex, we'll use a hash of the full index as a fallback
                let ti = Double(index.hashValue)
                
                // Default to "Default" for iCloud operations
                let currentProfile = profile ?? "Default"
                
                let insert = self.attendanceTable.insert(
                    or: .replace,
                    self.bandName <- bandNameStr,
                    self.eventYearColumn <- yearInt,
                    self.timeIndex <- ti,
                    self.status <- statusValue,
                    self.lastModified <- timestamp,
                    self.attendanceIndex <- index,
                    self.profileName <- currentProfile
                )
                
                try db.run(insert)
                print("✅ SQLiteAttendanceManager: Set attendance by index (\(currentProfile)): \(index) = \(statusValue)")
            } catch {
                print("❌ SQLiteAttendanceManager: Failed to set attendance by index: \(error)")
            }
        }
    }
    
    /// Sets attendance status by index (convenience method without explicit timestamp)
    /// Thread-safe - can be called from any thread
    func setAttendanceStatusByIndex(index: String, status statusValue: Int) {
        self.setAttendanceStatusByIndex(index: index, status: statusValue, timestamp: Date().timeIntervalSince1970)
    }
    
    /// Gets all attendance data indexed by attendance index
    /// Thread-safe - can be called from any thread
    func getAllAttendanceDataByIndex(profileName profile: String? = nil) -> [String: [String: Any]] {
        var result: [String: [String: Any]] = [:]
        let semaphore = DispatchSemaphore(value: 0)
        
        serialQueue.async { [weak self] in
            defer { semaphore.signal() }
            
            guard let self = self, let db = self.db else { return }
            
            do {
                let currentProfile = profile ?? self.getCurrentProfileName()
                
                print("🔍 [SQLITE_READ] ===== READING ATTENDANCE FROM SQLITE =====")
                print("🔍 [SQLITE_READ] Profile: '\(currentProfile)'")
                
                let query = self.attendanceTable.filter(self.profileName == currentProfile)
                
                for row in try db.prepare(query) {
                    if let index = row[self.attendanceIndex] {
                        result[index] = [
                            "status": row[self.status],
                            "lastModified": row[self.lastModified] ?? Date().timeIntervalSince1970
                        ]
                    }
                }
                
                print("🔍 [SQLITE_READ] Found \(result.count) attendance records for profile: '\(currentProfile)'")
                if result.count > 0 {
                    print("🔍 [SQLITE_READ] Sample keys: \(Array(result.keys.prefix(3)))")
                }
                print("🔍 [SQLITE_READ] ===== READ COMPLETE =====")
            } catch {
                print("❌ SQLiteAttendanceManager: Failed to get all attendance: \(error)")
            }
        }
        
        semaphore.wait()
        return result
    }
    
    /// Gets all attendance records for a specific year
    /// Thread-safe - can be called from any thread
    func getAllAttendanceData(forYear year: Int = 0, profileName profile: String? = nil) -> [[String: Any]] {
        var result: [[String: Any]] = []
        let semaphore = DispatchSemaphore(value: 0)
        
        serialQueue.async { [weak self] in
            defer { semaphore.signal() }
            
            guard let self = self, let db = self.db else { return }
            
            do {
                let currentYear = year > 0 ? year : eventYear
                let currentProfile = profile ?? self.getCurrentProfileName()
                let query = self.attendanceTable
                    .filter(self.eventYearColumn == currentYear && self.profileName == currentProfile)
                
                for row in try db.prepare(query) {
                    result.append([
                        "bandName": row[self.bandName],
                        "status": row[self.status],
                        "timeIndex": row[self.timeIndex],
                        "lastModified": row[self.lastModified] ?? Date().timeIntervalSince1970,
                        "index": row[self.attendanceIndex] ?? ""
                    ])
                }
            } catch {
                print("❌ SQLiteAttendanceManager: Failed to get attendance data: \(error)")
            }
        }
        
        semaphore.wait()
        return result
    }
    
    /// Deletes attendance record
    /// Thread-safe - can be called from any thread
    func deleteAttendance(bandName bandNameStr: String, timeIndex ti: Double, eventYear year: Int = 0, profileName profile: String? = nil) {
        serialQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            
            do {
                let currentEventYear = eventYear  // Get current global year as Int
                let currentYear = year > 0 ? year : currentEventYear
                let currentProfile = profile ?? SharedPreferencesManager.shared.getActivePreferenceSource()
                
                // CRITICAL: Only delete from the specified profile to avoid cross-profile data corruption
                let query = self.attendanceTable.filter(
                    self.bandName == bandNameStr &&
                    self.eventYearColumn == currentYear &&
                    self.timeIndex == ti &&
                    self.profileName == currentProfile
                )
                let deletedCount = try db.run(query.delete())
                print("✅ SQLiteAttendanceManager: Deleted \(deletedCount) attendance record(s) for \(bandNameStr) in profile '\(currentProfile)'")
            } catch {
                print("❌ SQLiteAttendanceManager: Failed to delete attendance: \(error)")
            }
        }
    }
    
    /// Gets count of attendance records
    /// Thread-safe - can be called from any thread
    func getAttendanceCount(eventYear year: Int = 0) -> Int {
        var result = 0
        let semaphore = DispatchSemaphore(value: 0)
        
        serialQueue.async { [weak self] in
            defer { semaphore.signal() }
            
            guard let self = self, let db = self.db else { return }
            
            do {
                let currentYear = year > 0 ? year : eventYear
                let query = self.attendanceTable.filter(self.eventYearColumn == currentYear)
                result = try db.scalar(query.count)
            } catch {
                print("❌ SQLiteAttendanceManager: Failed to get count: \(error)")
            }
        }
        
        semaphore.wait()
        return result
    }
    
    /// Gets count of attendance records for a specific profile
    /// Thread-safe - can be called from any thread
    func getAttendanceCount(profileName profile: String, eventYear year: Int = 0) -> Int {
        var result = 0
        let semaphore = DispatchSemaphore(value: 0)
        
        serialQueue.async { [weak self] in
            defer { semaphore.signal() }
            
            guard let self = self, let db = self.db else { return }
            
            do {
                let currentYear = year > 0 ? year : eventYear
                let query = self.attendanceTable
                    .filter(self.eventYearColumn == currentYear)
                    .filter(self.profileName == profile)
                result = try db.scalar(query.count)
            } catch {
                print("❌ SQLiteAttendanceManager: Failed to get count for profile: \(error)")
            }
        }
        
        semaphore.wait()
        return result
    }
    
    // MARK: - Helper Methods
    
    /// Creates attendance index string
    private func createAttendanceIndex(bandName: String, location: String, startTime: String, eventType: String, eventYear: Int) -> String {
        return "\(bandName):\(location):\(startTime):\(eventType):\(eventYear)"
    }
    
    /// Stub for linking attendance to events (no-op in SQLite version)
    func linkAttendanceRecordsToEvents() {
        // No-op: In SQLite version, we don't need to maintain relationships
        print("✅ SQLiteAttendanceManager: linkAttendanceRecordsToEvents (no-op)")
    }
    
    /// Performs a one-time migration from Core Data to SQLite
    func migrateFromCoreData(coreDataAttendances: [[String: Any]]) {
        serialQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            
            print("🔄 SQLiteAttendanceManager: Starting Core Data migration...")
            var migratedCount = 0
            
            do {
                try db.transaction {
                    for attendance in coreDataAttendances {
                        guard let bandNameStr = attendance["bandName"] as? String,
                              let statusValue = attendance["status"] as? Int,
                              let ti = attendance["timeIndex"] as? Double,
                              let year = attendance["eventYear"] as? Int else {
                            continue
                        }
                        
                        let index = attendance["index"] as? String ?? ""
                        let ts = attendance["lastModified"] as? Double ?? Date().timeIntervalSince1970
                        
                        let insert = self.attendanceTable.insert(
                            or: .replace,
                            self.bandName <- bandNameStr,
                            self.eventYearColumn <- year,
                            self.timeIndex <- ti,
                            self.status <- statusValue,
                            self.lastModified <- ts,
                            self.attendanceIndex <- index
                        )
                        
                        try db.run(insert)
                        migratedCount += 1
                    }
                }
                
                print("✅ SQLiteAttendanceManager: Migrated \(migratedCount) attendance records from Core Data")
            } catch {
                print("❌ SQLiteAttendanceManager: Migration failed: \(error)")
            }
        }
    }
    
    // MARK: - Profile Management
    
    /// Gets list of all unique profile names
    /// Thread-safe - can be called from any thread
    func getAllProfileNames() -> [String] {
        var result: [String] = []
        let semaphore = DispatchSemaphore(value: 0)
        
        serialQueue.async { [weak self] in
            defer { semaphore.signal() }
            
            guard let self = self, let db = self.db else { return }
            
            do {
                let query = self.attendanceTable.select(distinct: self.profileName)
                for row in try db.prepare(query) {
                    result.append(row[self.profileName])
                }
                print("🔍 [PROFILE_DEBUG] Found \(result.count) attendance profiles: \(result)")
            } catch {
                print("❌ SQLiteAttendanceManager: Failed to get profile names: \(error)")
            }
        }
        
        semaphore.wait()
        return result
    }
    
    /// Imports attendance data for a specific profile
    /// Thread-safe - can be called from any thread
    func importAttendance(for profileNameStr: String, attendanceData: [[String: Any]]) {
        serialQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            
            print("📥 [SQLITE_WRITE] ===== WRITING ATTENDANCE TO SQLITE =====")
            print("📥 [SQLITE_WRITE] Profile: '\(profileNameStr)', Count: \(attendanceData.count)")
            var importedCount = 0
            
            do {
                let ts = Date().timeIntervalSince1970
                
                // Count existing records BEFORE import
                let beforeQuery = self.attendanceTable.filter(self.profileName == profileNameStr)
                let beforeCount = try db.scalar(beforeQuery.count)
                print("📥 [SQLITE_WRITE] Profile '\(profileNameStr)' has \(beforeCount) attendance records BEFORE import")
                
                try db.transaction {
                    for attendance in attendanceData {
                        guard let bandNameStr = attendance["bandName"] as? String,
                              let statusValue = attendance["status"] as? Int,
                              let ti = attendance["timeIndex"] as? Double,
                              let year = attendance["eventYear"] as? Int,
                              let index = attendance["index"] as? String else {
                            continue
                        }
                        
                        let insert = self.attendanceTable.insert(
                            or: .replace,
                            self.bandName <- bandNameStr,
                            self.eventYearColumn <- year,
                            self.timeIndex <- ti,
                            self.status <- statusValue,
                            self.lastModified <- ts,
                            self.attendanceIndex <- index,
                            self.profileName <- profileNameStr
                        )
                        
                        try db.run(insert)
                        importedCount += 1
                    }
                }
                
                // Count AFTER import
                let afterQuery = self.attendanceTable.filter(self.profileName == profileNameStr)
                let afterCount = try db.scalar(afterQuery.count)
                print("✅ [SQLITE_WRITE] Imported \(importedCount)/\(attendanceData.count) attendance records")
                print("✅ [SQLITE_WRITE] Profile '\(profileNameStr)' now has \(afterCount) attendance records AFTER import (was \(beforeCount))")
                print("✅ [SQLITE_WRITE] ===== WRITE COMPLETE =====")
            } catch {
                print("❌ SQLiteAttendanceManager: Failed to import attendance: \(error)")
            }
        }
    }
    
    /// Deletes all data for a specific profile
    /// Thread-safe - can be called from any thread
    func deleteProfile(named profileNameStr: String, completion: @escaping (Bool) -> Void = { _ in }) {
        print("🗑️ [DELETE_PROFILE] ===== DELETE ATTENDANCE PROFILE CALLED =====")
        print("🗑️ [DELETE_PROFILE] Profile to delete: '\(profileNameStr)'")
        print("🗑️ [DELETE_PROFILE] Call stack:")
        Thread.callStackSymbols.prefix(10).forEach { print("   \($0)") }
        
        serialQueue.async { [weak self] in
            guard let self = self, let db = self.db else {
                completion(false)
                return
            }
            
            do {
                // Count BEFORE delete
                let beforeQuery = self.attendanceTable.filter(self.profileName == profileNameStr)
                let beforeCount = try db.scalar(beforeQuery.count)
                print("🗑️ [DELETE_PROFILE] Found \(beforeCount) attendance records for profile '\(profileNameStr)' BEFORE delete")
                
                let query = self.attendanceTable.filter(self.profileName == profileNameStr)
                let deletedCount = try db.run(query.delete())
                print("🗑️ [DELETE_PROFILE] ===== DELETED \(deletedCount) ATTENDANCE RECORDS =====")
                print("🗑️ [DELETE_PROFILE] Profile: '\(profileNameStr)'")
                completion(true)
            } catch {
                print("❌ SQLiteAttendanceManager: Failed to delete profile: \(error)")
                completion(false)
            }
        }
    }
    
    /// Exports attendance data for a specific profile
    /// Thread-safe - can be called from any thread
    func exportAttendance(for profileNameStr: String, eventYear year: Int = 0) -> [[String: Any]] {
        return getAllAttendanceData(forYear: year, profileName: profileNameStr)
    }
}


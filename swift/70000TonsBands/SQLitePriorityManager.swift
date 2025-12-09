//
//  SQLitePriorityManager.swift
//  70000 Tons Bands
//
//  Thread-safe priority management using direct SQLite calls
//  NO Core Data - NO deadlocks - NO threading issues
//

import Foundation
import SQLite

/// Thread-safe priority manager using direct SQLite
/// Can be called from any thread without restrictions
class SQLitePriorityManager {
    
    static let shared = SQLitePriorityManager()
    
    private var db: Connection?
    private let serialQueue = DispatchQueue(label: "com.bands70k.priority", qos: .userInitiated)
    
    // Table and column definitions
    private let prioritiesTable = Table("user_priorities")
    private let id = Expression<Int64>("id")
    private let bandName = Expression<String>("bandName")
    private let eventYearColumn = Expression<Int>("eventYear")  // Renamed to avoid shadowing global eventYear
    private let priority = Expression<Int>("priority")
    private let lastModified = Expression<Double?>("lastModified")
    private let deviceUID = Expression<String?>("deviceUID")
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
            print("✅ SQLitePriorityManager: Set busy timeout to 30 seconds")
            
            // Enable WAL mode for better concurrency
            try db?.execute("PRAGMA journal_mode=WAL")
            
            // Check if table exists and if it needs migration
            let tableExists = try db?.scalar("SELECT name FROM sqlite_master WHERE type='table' AND name='user_priorities'") as? String
            
            if tableExists != nil {
                // CRITICAL: Check if unique constraint includes profileName
                let schema = try db?.scalar("SELECT sql FROM sqlite_master WHERE type='table' AND name='user_priorities'") as? String
                let hasProfileInConstraint = schema?.contains("UNIQUE (\"bandName\", \"eventYear\", \"profileName\")") ?? false
                
                if !hasProfileInConstraint {
                    print("🚨 [MIGRATION] CRITICAL: Unique constraint missing profileName!")
                    print("🚨 [MIGRATION] Current schema: \(schema ?? "unknown")")
                    print("🔄 [MIGRATION] Must drop and recreate table with correct constraint...")
                    
                    // Check which columns exist in the old schema
                    let hasProfileNameColumn = schema?.contains("profileName") ?? false
                    let hasDeviceUIDColumn = schema?.contains("deviceUID") ?? false
                    
                    print("🔄 [MIGRATION] Schema check: profileName=\(hasProfileNameColumn), deviceUID=\(hasDeviceUIDColumn)")
                    
                    // Backup all data - use appropriate SELECT based on what columns exist
                    let selectSQL: String
                    if hasProfileNameColumn && hasDeviceUIDColumn {
                        selectSQL = "SELECT bandName, eventYear, priority, lastModified, deviceUID, profileName FROM user_priorities"
                    } else if hasProfileNameColumn {
                        selectSQL = "SELECT bandName, eventYear, priority, lastModified, profileName FROM user_priorities"
                    } else if hasDeviceUIDColumn {
                        selectSQL = "SELECT bandName, eventYear, priority, lastModified, deviceUID FROM user_priorities"
                    } else {
                        // Very old schema - only has basic columns
                        selectSQL = "SELECT bandName, eventYear, priority, lastModified FROM user_priorities"
                    }
                    
                    print("🔄 [MIGRATION] Using SQL: \(selectSQL)")
                    let backupData = try db?.prepare(selectSQL)
                    var allRecords: [[String: Any]] = []
                    
                    if let backupData = backupData {
                        for row in backupData {
                            var record: [String: Any] = [:]
                            record["bandName"] = row[0] as? String ?? ""
                            record["eventYear"] = row[1] as? Int ?? 0
                            record["priority"] = row[2] as? Int ?? 0
                            record["lastModified"] = row[3] as? Double
                            
                            // Handle different schema combinations
                            if hasProfileNameColumn && hasDeviceUIDColumn {
                                record["deviceUID"] = row[4] as? String
                                record["profileName"] = row[5] as? String ?? "Default"
                            } else if hasProfileNameColumn {
                                record["deviceUID"] = nil
                                record["profileName"] = row[4] as? String ?? "Default"
                            } else if hasDeviceUIDColumn {
                                record["deviceUID"] = row[4] as? String
                                record["profileName"] = "Default"
                            } else {
                                // Very old schema - no deviceUID or profileName
                                record["deviceUID"] = nil
                                record["profileName"] = "Default"
                            }
                            
                            allRecords.append(record)
                        }
                    }
                    
                    print("🔄 [MIGRATION] Backed up \(allRecords.count) priority records")
                    
                    // Save backup to UserDefaults
                    UserDefaults.standard.set(allRecords, forKey: "PriorityUniqueConstraintMigration_Backup")
                    
                    // Drop and recreate table
                    try db?.execute("DROP TABLE IF EXISTS user_priorities")
                    print("🔄 [MIGRATION] Dropped old table")
                    
                    // Mark migration as started
                    UserDefaults.standard.set(true, forKey: "PriorityUniqueConstraintMigration_Started")
                }
            }
            
            // Create table if needed (with profileName)
            try db?.run(prioritiesTable.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(bandName)
                t.column(eventYearColumn)
                t.column(priority)
                t.column(lastModified)
                t.column(deviceUID)
                t.column(profileName, defaultValue: "Default")
                t.unique(bandName, eventYearColumn, profileName)
            })
            
            // Restore backed up data if migration just occurred
            let migrationStarted = UserDefaults.standard.bool(forKey: "PriorityUniqueConstraintMigration_Started")
            
            if migrationStarted {
                print("🔄 [MIGRATION] Restoring backed up priority data after migration")
                
                // Get backed up data from UserDefaults
                if let backupDataArray = UserDefaults.standard.array(forKey: "PriorityUniqueConstraintMigration_Backup") as? [[String: Any]] {
                    print("🔄 [MIGRATION] Found \(backupDataArray.count) backed up records, restoring...")
                    
                    try db?.transaction {
                        for record in backupDataArray {
                            guard let bandNameStr = record["bandName"] as? String,
                                  let year = record["eventYear"] as? Int,
                                  let priorityValue = record["priority"] as? Int,
                                  let profileNameStr = record["profileName"] as? String else {
                                continue
                            }
                            
                            let insert = self.prioritiesTable.insert(
                                or: .replace,
                                self.bandName <- bandNameStr,
                                self.eventYearColumn <- year,
                                self.priority <- priorityValue,
                                self.lastModified <- record["lastModified"] as? Double,
                                self.deviceUID <- record["deviceUID"] as? String,
                                self.profileName <- profileNameStr
                            )
                            
                            try db?.run(insert)
                        }
                    }
                    
                    print("✅ [MIGRATION] Restored \(backupDataArray.count) priority records")
                    
                    // Verify restoration by counting records
                    let finalCount = try db?.scalar("SELECT COUNT(*) FROM user_priorities") as? Int64 ?? 0
                    print("🔍 [MIGRATION] Final verification: \(finalCount) priorities in database")
                    
                    if finalCount == backupDataArray.count {
                        print("✅ [MIGRATION] All \(backupDataArray.count) records successfully restored")
                    } else {
                        print("⚠️ [MIGRATION] Mismatch! Expected \(backupDataArray.count) but found \(finalCount)")
                    }
                    
                    // Clear backup and flags
                    UserDefaults.standard.removeObject(forKey: "PriorityUniqueConstraintMigration_Backup")
                    UserDefaults.standard.removeObject(forKey: "PriorityUniqueConstraintMigration_Started")
                    
                    print("✅ [MIGRATION] Priority table migration COMPLETE - safe for iCloud sync now")
                } else {
                    print("⚠️ [MIGRATION] No backup data found in UserDefaults!")
                }
            }
            
            // CRITICAL: Verify the unique constraint exists
            let schema = try db?.scalar("SELECT sql FROM sqlite_master WHERE type='table' AND name='user_priorities'") as? String
            print("🔍 [SCHEMA_DEBUG] user_priorities schema: \(schema ?? "unknown")")
            
            let indexes = try db?.prepare("SELECT name, sql FROM sqlite_master WHERE type='index' AND tbl_name='user_priorities'")
            if let indexes = indexes {
                for index in indexes {
                    print("🔍 [SCHEMA_DEBUG] Index: \(index[0] as? String ?? "unknown")")
                    print("🔍 [SCHEMA_DEBUG] SQL: \(index[1] as? String ?? "unknown")")
                }
            }
            
            print("✅ SQLitePriorityManager: Initialized")
        } catch {
            print("❌ SQLitePriorityManager: Failed to initialize: \(error)")
        }
    }
    
    // MARK: - Public API (Thread-Safe)
    
    /// Gets the current active profile name
    private func getCurrentProfileName() -> String {
        return SharedPreferencesManager.shared.currentSharedProfileName ?? "Default"
    }
    
    /// Sets priority for a band
    /// Thread-safe - can be called from any thread
    func setPriority(for bandNameStr: String, priority priorityValue: Int, eventYear year: Int = 0, timestamp: Double? = nil, profileName profile: String? = nil, completion: @escaping (Bool) -> Void = { _ in }) {
        serialQueue.async { [weak self] in
            guard let self = self, let db = self.db else {
                completion(false)
                return
            }
            
            do {
                let currentYear = year > 0 ? year : eventYear
                let ts = timestamp ?? Date().timeIntervalSince1970
                let uid = UIDevice.current.identifierForVendor?.uuidString
                let currentProfile = profile ?? self.getCurrentProfileName()
                
                // Use INSERT OR REPLACE for atomic operation
                let insert = self.prioritiesTable.insert(
                    or: .replace,
                    self.bandName <- bandNameStr,
                    self.eventYearColumn <- currentYear,
                    self.priority <- priorityValue,
                    self.lastModified <- ts,
                    self.deviceUID <- uid,
                    self.profileName <- currentProfile
                )
                
                try db.run(insert)
                print("✅ SQLitePriorityManager: Set priority for \(bandNameStr) = \(priorityValue) (profile: \(currentProfile))")
                
                // Call completion directly to avoid deadlock with semaphores
                completion(true)
            } catch {
                print("❌ SQLitePriorityManager: Failed to set priority: \(error)")
                // Call completion directly to avoid deadlock with semaphores
                completion(false)
            }
        }
    }
    
    /// Gets priority for a band
    /// Thread-safe - can be called from any thread
    func getPriority(for bandNameStr: String, eventYear year: Int = 0, profileName profile: String? = nil) -> Int {
        var result = 0
        let semaphore = DispatchSemaphore(value: 0)
        
        serialQueue.async { [weak self] in
            defer { semaphore.signal() }
            
            guard let self = self, let db = self.db else { return }
            
            do {
                let currentYear = year > 0 ? year : eventYear
                let currentProfile = profile ?? self.getCurrentProfileName()
                
                let query = self.prioritiesTable
                    .filter(self.bandName == bandNameStr && 
                           self.eventYearColumn == currentYear &&
                           self.profileName == currentProfile)
                    .limit(1)
                
                if let row = try db.pluck(query) {
                    result = row[self.priority]
                    print("🔍 [PRIORITY_DEBUG] Found priority for \(bandNameStr) = \(result) (profile: \(currentProfile))")
                } else {
                    print("🔍 [PRIORITY_DEBUG] No priority found for \(bandNameStr) (profile: \(currentProfile))")
                }
            } catch {
                print("❌ SQLitePriorityManager: Failed to get priority: \(error)")
            }
        }
        
        semaphore.wait()
        return result
    }
    
    /// Gets all priorities
    /// Thread-safe - can be called from any thread
    func getAllPriorities(eventYear year: Int = 0, profileName profile: String? = nil) -> [String: Int] {
        var result: [String: Int] = [:]
        let semaphore = DispatchSemaphore(value: 0)
        
        serialQueue.async { [weak self] in
            defer { semaphore.signal() }
            
            guard let self = self, let db = self.db else { return }
            
            do {
                let currentYear = year > 0 ? year : eventYear
                let currentProfile = profile ?? self.getCurrentProfileName()
                
                print("🔍 [SQLITE_READ] ===== READING PRIORITIES FROM SQLITE =====")
                print("🔍 [SQLITE_READ] Profile: '\(currentProfile)', Year: \(currentYear)")
                
                let query = self.prioritiesTable
                    .filter(self.eventYearColumn == currentYear && self.profileName == currentProfile)
                
                for row in try db.prepare(query) {
                    let name = row[self.bandName]
                    let priorityValue = row[self.priority]
                    result[name] = priorityValue
                }
                
                print("🔍 [SQLITE_READ] Found \(result.count) priorities for profile: '\(currentProfile)'")
                if result.count > 0 {
                    print("🔍 [SQLITE_READ] Sample: \(result.prefix(3))")
                }
                print("🔍 [SQLITE_READ] ===== READ COMPLETE =====")
            } catch {
                print("❌ SQLitePriorityManager: Failed to get all priorities: \(error)")
            }
        }
        
        semaphore.wait()
        return result
    }
    
    /// Gets priority timestamp
    /// Thread-safe - can be called from any thread
    func getPriorityLastChange(for bandNameStr: String, eventYear year: Int = 0) -> Double {
        var result: Double = 0
        let semaphore = DispatchSemaphore(value: 0)
        
        serialQueue.async { [weak self] in
            defer { semaphore.signal() }
            
            guard let self = self, let db = self.db else { return }
            
            do {
                let currentYear = year > 0 ? year : eventYear
                let query = self.prioritiesTable
                    .filter(self.bandName == bandNameStr && self.eventYearColumn == currentYear)
                    .limit(1)
                
                if let row = try db.pluck(query) {
                    result = row[self.lastModified] ?? 0
                }
            } catch {
                print("❌ SQLitePriorityManager: Failed to get timestamp: \(error)")
            }
        }
        
        semaphore.wait()
        return result
    }
    
    /// Updates priority from iCloud (only updates "Default" profile)
    /// Thread-safe - can be called from any thread
    func updatePriorityFromiCloud(bandName bandNameStr: String, priority priorityValue: Int, timestamp: Double, deviceUID uid: String, eventYear year: Int = 0) {
        serialQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            
            do {
                let currentYear = year > 0 ? year : eventYear
                
                // iCloud only syncs "Default" profile - never shared data
                let insert = self.prioritiesTable.insert(
                    or: .replace,
                    self.bandName <- bandNameStr,
                    self.eventYearColumn <- currentYear,
                    self.priority <- priorityValue,
                    self.lastModified <- timestamp,
                    self.deviceUID <- uid,
                    self.profileName <- "Default"
                )
                
                try db.run(insert)
                print("✅ SQLitePriorityManager: Updated from iCloud (Default): \(bandNameStr) = \(priorityValue)")
            } catch {
                print("❌ SQLitePriorityManager: Failed to update from iCloud: \(error)")
            }
        }
    }
    
    /// Deletes priority for a band (ONLY for current active profile)
    /// Thread-safe - can be called from any thread
    func deletePriority(for bandNameStr: String, eventYear year: Int = 0, profileName profile: String? = nil) {
        serialQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            
            do {
                let currentYear = year > 0 ? year : eventYear
                let currentProfile = profile ?? self.getCurrentProfileName()
                
                print("🗑️ [DELETE_PRIORITY] ===== DELETE PRIORITY CALLED =====")
                print("🗑️ [DELETE_PRIORITY] Band: '\(bandNameStr)', Profile: '\(currentProfile)', Year: \(currentYear)")
                print("🗑️ [DELETE_PRIORITY] Call stack:")
                Thread.callStackSymbols.prefix(10).forEach { print("   \($0)") }
                
                // CRITICAL: Only delete from the specified profile to avoid cross-profile data corruption
                let query = self.prioritiesTable.filter(
                    self.bandName == bandNameStr && 
                    self.eventYearColumn == currentYear &&
                    self.profileName == currentProfile
                )
                let deletedCount = try db.run(query.delete())
                print("✅ SQLitePriorityManager: Deleted \(deletedCount) priority record(s) for \(bandNameStr) in profile '\(currentProfile)'")
            } catch {
                print("❌ SQLitePriorityManager: Failed to delete priority: \(error)")
            }
        }
    }
    
    /// Gets count of all priorities
    /// Thread-safe - can be called from any thread
    func getPriorityCount(eventYear year: Int = 0) -> Int {
        var result = 0
        let semaphore = DispatchSemaphore(value: 0)
        
        serialQueue.async { [weak self] in
            defer { semaphore.signal() }
            
            guard let self = self, let db = self.db else { return }
            
            do {
                let currentYear = year > 0 ? year : eventYear
                let query = self.prioritiesTable.filter(self.eventYearColumn == currentYear)
                result = try db.scalar(query.count)
            } catch {
                print("❌ SQLitePriorityManager: Failed to get count: \(error)")
            }
        }
        
        semaphore.wait()
        return result
    }
    
    /// Gets count of priorities for a specific profile
    /// Thread-safe - can be called from any thread
    func getPriorityCount(profileName profile: String, eventYear year: Int = 0) -> Int {
        var result = 0
        let semaphore = DispatchSemaphore(value: 0)
        
        serialQueue.async { [weak self] in
            defer { semaphore.signal() }
            
            guard let self = self, let db = self.db else { return }
            
            do {
                let currentYear = year > 0 ? year : eventYear
                let query = self.prioritiesTable
                    .filter(self.eventYearColumn == currentYear)
                    .filter(self.profileName == profile)
                result = try db.scalar(query.count)
            } catch {
                print("❌ SQLitePriorityManager: Failed to get count for profile: \(error)")
            }
        }
        
        semaphore.wait()
        return result
    }
    
    /// Performs a one-time migration from Core Data to SQLite
    /// Should be called once on first launch after upgrading
    func migrateFromCoreData(coreDataPriorities: [String: Int], timestamps: [String: Double]) {
        serialQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            
            print("🔄 SQLitePriorityManager: Starting Core Data migration...")
            var migratedCount = 0
            
            do {
                try db.transaction {
                    for (bandName, priority) in coreDataPriorities {
                        let ts = timestamps[bandName] ?? Date().timeIntervalSince1970
                        let uid = UIDevice.current.identifierForVendor?.uuidString
                        
                        let insert = self.prioritiesTable.insert(
                            or: .replace,
                            self.bandName <- bandName,
                            self.eventYearColumn <- eventYear,
                            self.priority <- priority,
                            self.lastModified <- ts,
                            self.deviceUID <- uid
                        )
                        
                        try db.run(insert)
                        migratedCount += 1
                    }
                }
                
                print("✅ SQLitePriorityManager: Migrated \(migratedCount) priorities from Core Data")
            } catch {
                print("❌ SQLitePriorityManager: Migration failed: \(error)")
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
                let query = self.prioritiesTable.select(distinct: self.profileName)
                for row in try db.prepare(query) {
                    result.append(row[self.profileName])
                }
                print("🔍 [PROFILE_DEBUG] Found \(result.count) profiles: \(result)")
            } catch {
                print("❌ SQLitePriorityManager: Failed to get profile names: \(error)")
            }
        }
        
        semaphore.wait()
        return result
    }
    
    /// Imports priorities for a specific profile
    /// Thread-safe - can be called from any thread
    func importPriorities(for profileNameStr: String, priorities: [String: Int], eventYear year: Int = 0) {
        serialQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            
            print("📥 [SQLITE_WRITE] ===== WRITING PRIORITIES TO SQLITE =====")
            print("📥 [SQLITE_WRITE] Profile: '\(profileNameStr)', Count: \(priorities.count)")
            print("📥 [SQLITE_WRITE] ACTIVE profile during import: '\(SharedPreferencesManager.shared.getActivePreferenceSource())'")
            print("📥 [SQLITE_WRITE] Call stack:")
            Thread.callStackSymbols.prefix(10).forEach { print("   \($0)") }
            var importedCount = 0
            
            do {
                let currentYear = year > 0 ? year : eventYear
                let ts = Date().timeIntervalSince1970
                let uid = UIDevice.current.identifierForVendor?.uuidString
                
                print("📥 [SQLITE_WRITE] Year: \(currentYear)")
                
                // Count existing records BEFORE import
                let beforeQuery = self.prioritiesTable.filter(self.profileName == profileNameStr && self.eventYearColumn == currentYear)
                let beforeCount = try db.scalar(beforeQuery.count)
                print("📥 [SQLITE_WRITE] Profile '\(profileNameStr)' has \(beforeCount) records BEFORE import")
                
                // CRITICAL DIAGNOSTIC: Check Default profile too
                let defaultQuery = self.prioritiesTable.filter(self.profileName == "Default" && self.eventYearColumn == currentYear)
                let defaultCount = try db.scalar(defaultQuery.count)
                print("📥 [SQLITE_WRITE] Profile 'Default' has \(defaultCount) records BEFORE import (for comparison)")
                
                // CRITICAL: Log sample Default profile records BEFORE import
                if defaultCount > 0 {
                    var sampleBands: [(String, String)] = []
                    for row in try db.prepare(defaultQuery.limit(5)) {
                        let band = row[self.bandName]
                        let profile = row[self.profileName]
                        sampleBands.append((band, profile))
                    }
                    print("📥 [SQLITE_WRITE] Sample Default bands BEFORE import:")
                    for (band, profile) in sampleBands {
                        print("   - '\(band)' in profile '\(profile)'")
                    }
                }
                
                // CRITICAL: Check if any records have wrong profileName  
                let emptyProfileQuery = self.prioritiesTable.filter(self.eventYearColumn == currentYear && self.profileName == "")
                let emptyCount = try db.scalar(emptyProfileQuery.count)
                print("📥 [SQLITE_WRITE] Records with empty profileName: \(emptyCount)")
                
                // Check ALL distinct profileNames
                let distinctProfiles = try db.prepare("SELECT DISTINCT profileName FROM user_priorities WHERE eventYear = ?", currentYear)
                var allProfileNames: [String] = []
                for row in distinctProfiles {
                    if let pName = row[0] as? String {
                        allProfileNames.append(pName)
                    }
                }
                print("📥 [SQLITE_WRITE] All distinct profiles in DB BEFORE import: \(allProfileNames)")
                
                // CRITICAL DEBUG: Log first insert to see exact SQL
                var firstInsertLogged = false
                
                try db.transaction {
                    for (bandName, priority) in priorities {
                        let insert = self.prioritiesTable.insert(
                            or: .replace,
                            self.bandName <- bandName,
                            self.eventYearColumn <- currentYear,
                            self.priority <- priority,
                            self.lastModified <- ts,
                            self.deviceUID <- uid,
                            self.profileName <- profileNameStr
                        )
                        
                        // Log first insert to see values
                        if !firstInsertLogged {
                            print("🔍 [SQL_DEBUG] First insert values:")
                            print("   - band='\(bandName)'")
                            print("   - year=\(currentYear)")
                            print("   - priority=\(priority)")
                            print("   - profile='\(profileNameStr)'")
                            print("   - deviceUID='\(uid ?? "nil")'")
                            firstInsertLogged = true
                        }
                        
                        try db.run(insert)
                        importedCount += 1
                        
                        // Verify Default profile data after FIRST insert
                        if importedCount == 1 {
                            let defaultCheckQuery = self.prioritiesTable.filter(self.profileName == "Default" && self.eventYearColumn == currentYear)
                            let defaultCheckCount = try db.scalar(defaultCheckQuery.count)
                            print("🔍 [SQL_DEBUG] Default profile count after FIRST insert: \(defaultCheckCount) (should still be \(defaultCount))")
                            if defaultCheckCount != defaultCount {
                                print("🚨 [CRITICAL] Default data corrupted on FIRST insert!")
                                print("🚨 [CRITICAL] First band: '\(bandName)', profile: '\(profileNameStr)'")
                            }
                        }
                    }
                }
                
                // Count AFTER import
                let afterQuery = self.prioritiesTable.filter(self.profileName == profileNameStr && self.eventYearColumn == currentYear)
                let afterCount = try db.scalar(afterQuery.count)
                print("✅ [SQLITE_WRITE] Imported \(importedCount)/\(priorities.count) priorities")
                print("✅ [SQLITE_WRITE] Profile '\(profileNameStr)' now has \(afterCount) records AFTER import (was \(beforeCount))")
                
                // CRITICAL DIAGNOSTIC: Check Default profile again
                let defaultAfterQuery = self.prioritiesTable.filter(self.profileName == "Default" && self.eventYearColumn == currentYear)
                let defaultAfterCount = try db.scalar(defaultAfterQuery.count)
                print("✅ [SQLITE_WRITE] Profile 'Default' now has \(defaultAfterCount) records AFTER import (was \(defaultCount))")
                
                // Check total records across ALL profiles
                let allProfilesQuery = self.prioritiesTable.filter(self.eventYearColumn == currentYear)
                let totalCount = try db.scalar(allProfilesQuery.count)
                print("✅ [SQLITE_WRITE] TOTAL records across all profiles for year \(currentYear): \(totalCount)")
                
                if defaultAfterCount != defaultCount {
                    print("🚨 [CRITICAL] Default profile data changed during import! Before: \(defaultCount), After: \(defaultAfterCount)")
                    print("🚨 [CRITICAL] Data LOST: \(defaultCount - defaultAfterCount) records")
                    
                    // Log sample of what's left in Default (if anything)
                    if defaultAfterCount > 0 {
                        var sampleBands: [String] = []
                        for row in try db.prepare(defaultAfterQuery.limit(5)) {
                            sampleBands.append(row[self.bandName])
                        }
                        print("🚨 [CRITICAL] Remaining Default bands: \(sampleBands)")
                    }
                    
                    // Check if data moved to another profile
                    let allProfiles = try db.prepare("SELECT DISTINCT profileName FROM user_priorities WHERE eventYear = ?", currentYear)
                    var profileList: [String] = []
                    for row in allProfiles {
                        if let pName = row[0] as? String {
                            profileList.append(pName)
                        }
                    }
                    print("🚨 [CRITICAL] All profiles in DB: \(profileList)")
                }
                print("✅ [SQLITE_WRITE] ===== WRITE COMPLETE =====")
            } catch {
                print("❌ SQLitePriorityManager: Failed to import priorities: \(error)")
            }
        }
    }
    
    /// Deletes all data for a specific profile
    /// Thread-safe - can be called from any thread
    func deleteProfile(named profileNameStr: String, completion: @escaping (Bool) -> Void = { _ in }) {
        print("🗑️ [DELETE_PROFILE] ===== DELETE PROFILE CALLED =====")
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
                let beforeQuery = self.prioritiesTable.filter(self.profileName == profileNameStr)
                let beforeCount = try db.scalar(beforeQuery.count)
                print("🗑️ [DELETE_PROFILE] Found \(beforeCount) records for profile '\(profileNameStr)' BEFORE delete")
                
                let query = self.prioritiesTable.filter(self.profileName == profileNameStr)
                let deletedCount = try db.run(query.delete())
                print("🗑️ [DELETE_PROFILE] ===== DELETED \(deletedCount) PRIORITY RECORDS =====")
                print("🗑️ [DELETE_PROFILE] Profile: '\(profileNameStr)'")
                completion(true)
            } catch {
                print("❌ SQLitePriorityManager: Failed to delete profile: \(error)")
                completion(false)
            }
        }
    }
    
    /// Exports priorities for a specific profile
    /// Thread-safe - can be called from any thread
    func exportPriorities(for profileNameStr: String, eventYear year: Int = 0) -> [String: Int] {
        return getAllPriorities(eventYear: year, profileName: profileNameStr)
    }
}


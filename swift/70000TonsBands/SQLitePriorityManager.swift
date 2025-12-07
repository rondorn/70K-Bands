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
    
    private init() {
        setupDatabase()
    }
    
    private func setupDatabase() {
        do {
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            let dbPath = "\(documentsPath)/70kbands.sqlite3"
            
            db = try Connection(dbPath)
            
            // Enable WAL mode for better concurrency
            try db?.execute("PRAGMA journal_mode=WAL")
            
            // Check if table exists and if it needs migration
            let tableExists = try db?.scalar("SELECT name FROM sqlite_master WHERE type='table' AND name='user_priorities'") as? String
            
            if tableExists != nil {
                // Check if deviceUID column exists
                let hasDeviceUID = try db?.scalar("SELECT COUNT(*) FROM pragma_table_info('user_priorities') WHERE name='deviceUID'") as? Int64
                
                if hasDeviceUID == 0 {
                    print("🔄 SQLitePriorityManager: Migrating table to add deviceUID column")
                    try db?.execute("ALTER TABLE user_priorities ADD COLUMN deviceUID TEXT")
                    print("✅ SQLitePriorityManager: Migration complete")
                }
            }
            
            // Create table if needed
            try db?.run(prioritiesTable.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(bandName)
                t.column(eventYearColumn)
                t.column(priority)
                t.column(lastModified)
                t.column(deviceUID)
                t.unique(bandName, eventYearColumn)
            })
            
            print("✅ SQLitePriorityManager: Initialized")
        } catch {
            print("❌ SQLitePriorityManager: Failed to initialize: \(error)")
        }
    }
    
    // MARK: - Public API (Thread-Safe)
    
    /// Sets priority for a band
    /// Thread-safe - can be called from any thread
    func setPriority(for bandNameStr: String, priority priorityValue: Int, eventYear year: Int = 0, timestamp: Double? = nil, completion: @escaping (Bool) -> Void = { _ in }) {
        serialQueue.async { [weak self] in
            guard let self = self, let db = self.db else {
                completion(false)
                return
            }
            
            do {
                let currentYear = year > 0 ? year : eventYear
                let ts = timestamp ?? Date().timeIntervalSince1970
                let uid = UIDevice.current.identifierForVendor?.uuidString
                
                // Use INSERT OR REPLACE for atomic operation
                let insert = self.prioritiesTable.insert(
                    or: .replace,
                    self.bandName <- bandNameStr,
                    self.eventYearColumn <- currentYear,
                    self.priority <- priorityValue,
                    self.lastModified <- ts,
                    self.deviceUID <- uid
                )
                
                try db.run(insert)
                print("✅ SQLitePriorityManager: Set priority for \(bandNameStr) = \(priorityValue)")
                
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
    func getPriority(for bandNameStr: String, eventYear year: Int = 0) -> Int {
        var result = 0
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
                    result = row[self.priority]
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
    func getAllPriorities(eventYear year: Int = 0) -> [String: Int] {
        var result: [String: Int] = [:]
        let semaphore = DispatchSemaphore(value: 0)
        
        serialQueue.async { [weak self] in
            defer { semaphore.signal() }
            
            guard let self = self, let db = self.db else { return }
            
            do {
                let currentYear = year > 0 ? year : eventYear
                let query = self.prioritiesTable.filter(self.eventYearColumn == currentYear)
                
                for row in try db.prepare(query) {
                    let name = row[self.bandName]
                    let priorityValue = row[self.priority]
                    result[name] = priorityValue
                }
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
    
    /// Updates priority from iCloud
    /// Thread-safe - can be called from any thread
    func updatePriorityFromiCloud(bandName bandNameStr: String, priority priorityValue: Int, timestamp: Double, deviceUID uid: String, eventYear year: Int = 0) {
        serialQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            
            do {
                let currentYear = year > 0 ? year : eventYear
                
                let insert = self.prioritiesTable.insert(
                    or: .replace,
                    self.bandName <- bandNameStr,
                    self.eventYearColumn <- currentYear,
                    self.priority <- priorityValue,
                    self.lastModified <- timestamp,
                    self.deviceUID <- uid
                )
                
                try db.run(insert)
                print("✅ SQLitePriorityManager: Updated from iCloud: \(bandNameStr) = \(priorityValue)")
            } catch {
                print("❌ SQLitePriorityManager: Failed to update from iCloud: \(error)")
            }
        }
    }
    
    /// Deletes priority for a band
    /// Thread-safe - can be called from any thread
    func deletePriority(for bandNameStr: String, eventYear year: Int = 0) {
        serialQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            
            do {
                let currentYear = year > 0 ? year : eventYear
                let query = self.prioritiesTable.filter(self.bandName == bandNameStr && self.eventYearColumn == currentYear)
                try db.run(query.delete())
                print("✅ SQLitePriorityManager: Deleted priority for \(bandNameStr)")
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
}


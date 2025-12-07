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
            let tableExists = try db?.scalar("SELECT name FROM sqlite_master WHERE type='table' AND name='user_attendances'") as? String
            
            if tableExists != nil {
                // Check if attendanceIndex column exists
                let hasAttendanceIndex = try db?.scalar("SELECT COUNT(*) FROM pragma_table_info('user_attendances') WHERE name='attendanceIndex'") as? Int64
                
                if hasAttendanceIndex == 0 {
                    print("🔄 SQLiteAttendanceManager: Migrating table to add attendanceIndex column")
                    try db?.execute("ALTER TABLE user_attendances ADD COLUMN attendanceIndex TEXT")
                    print("✅ SQLiteAttendanceManager: Migration complete")
                }
            }
            
            // Create table if needed
            try db?.run(attendanceTable.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(bandName)
                t.column(eventYearColumn)
                t.column(timeIndex)
                t.column(status)
                t.column(lastModified)
                t.column(attendanceIndex)
                t.unique(bandName, eventYearColumn, timeIndex)
            })
            
            // Create index on attendanceIndex for fast lookups
            try db?.run(attendanceTable.createIndex(attendanceIndex, ifNotExists: true))
            try db?.run(attendanceTable.createIndex(eventYearColumn, ifNotExists: true))
            
            print("✅ SQLiteAttendanceManager: Initialized")
        } catch {
            print("❌ SQLiteAttendanceManager: Failed to initialize: \(error)")
        }
    }
    
    // MARK: - Public API (Thread-Safe)
    
    /// Sets attendance status for an event
    /// Thread-safe - can be called from any thread
    func setAttendanceStatus(
        bandName bandNameStr: String,
        location: String,
        startTime: String,
        eventType: String,
        eventYear year: String,
        status statusValue: Int,
        timeIndex ti: Double = 0
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
                
                let insert = self.attendanceTable.insert(
                    or: .replace,
                    self.bandName <- bandNameStr,
                    self.eventYearColumn <- yearInt,
                    self.timeIndex <- ti,
                    self.status <- statusValue,
                    self.lastModified <- ts,
                    self.attendanceIndex <- index
                )
                
                try db.run(insert)
                print("✅ SQLiteAttendanceManager: Set attendance for \(bandNameStr) = \(statusValue)")
            } catch {
                print("❌ SQLiteAttendanceManager: Failed to set attendance: \(error)")
            }
        }
    }
    
    /// Gets attendance status by index
    /// Thread-safe - can be called from any thread
    func getAttendanceStatusByIndex(index: String) -> Int {
        var result = 0
        let semaphore = DispatchSemaphore(value: 0)
        
        serialQueue.async { [weak self] in
            defer { semaphore.signal() }
            
            guard let self = self, let db = self.db else { return }
            
            do {
                let query = self.attendanceTable
                    .filter(self.attendanceIndex == index)
                    .limit(1)
                
                if let row = try db.pluck(query) {
                    result = row[self.status]
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
    func setAttendanceStatusByIndex(index: String, status statusValue: Int, timestamp: Double) {
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
                
                let insert = self.attendanceTable.insert(
                    or: .replace,
                    self.bandName <- bandNameStr,
                    self.eventYearColumn <- yearInt,
                    self.timeIndex <- ti,
                    self.status <- statusValue,
                    self.lastModified <- timestamp,
                    self.attendanceIndex <- index
                )
                
                try db.run(insert)
                print("✅ SQLiteAttendanceManager: Set attendance by index: \(index) = \(statusValue)")
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
    func getAllAttendanceDataByIndex() -> [String: [String: Any]] {
        var result: [String: [String: Any]] = [:]
        let semaphore = DispatchSemaphore(value: 0)
        
        serialQueue.async { [weak self] in
            defer { semaphore.signal() }
            
            guard let self = self, let db = self.db else { return }
            
            do {
                for row in try db.prepare(self.attendanceTable) {
                    if let index = row[self.attendanceIndex] {
                        result[index] = [
                            "status": row[self.status],
                            "lastModified": row[self.lastModified] ?? Date().timeIntervalSince1970
                        ]
                    }
                }
            } catch {
                print("❌ SQLiteAttendanceManager: Failed to get all attendance: \(error)")
            }
        }
        
        semaphore.wait()
        return result
    }
    
    /// Gets all attendance records for a specific year
    /// Thread-safe - can be called from any thread
    func getAllAttendanceData(forYear year: Int = 0) -> [[String: Any]] {
        var result: [[String: Any]] = []
        let semaphore = DispatchSemaphore(value: 0)
        
        serialQueue.async { [weak self] in
            defer { semaphore.signal() }
            
            guard let self = self, let db = self.db else { return }
            
            do {
                let currentYear = year > 0 ? year : eventYear
                let query = self.attendanceTable.filter(self.eventYearColumn == currentYear)
                
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
    func deleteAttendance(bandName bandNameStr: String, timeIndex ti: Double, eventYear year: Int = 0) {
        serialQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            
            do {
                let currentEventYear = eventYear  // Get current global year as Int
                let currentYear = year > 0 ? year : currentEventYear
                let query = self.attendanceTable.filter(
                    self.bandName == bandNameStr &&
                    self.eventYearColumn == currentYear &&
                    self.timeIndex == ti
                )
                try db.run(query.delete())
                print("✅ SQLiteAttendanceManager: Deleted attendance for \(bandNameStr)")
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
}


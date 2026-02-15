import Foundation

/// Manages event attendance using SQLite
/// This is now a wrapper around SQLiteAttendanceManager for backwards compatibility
class AttendanceManager {
    // Use SQLite as primary storage
    private let sqliteManager = SQLiteAttendanceManager.shared
    
    init() {
        // All data now uses SQLite directly - no migration needed
    }
    
    // MARK: - Attendance Management (SQLite-backed)
    
    /// Sets attendance status for an event using SQLite
    func setAttendanceStatus(
        bandName: String,
        location: String,
        startTime: String,
        eventType: String,
        eventYear: String,
        status: Int
    ) {
        print("🎪 Setting attendance for \(bandName) at \(location): \(status) [SQLite]")
        
        sqliteManager.setAttendanceStatus(
            bandName: bandName,
            location: location,
            startTime: startTime,
            eventType: eventType,
            eventYear: eventYear,
            status: status
        )
    }
    
    /// Gets attendance status for an event from SQLite
    func getAttendanceStatus(
        bandName: String,
        location: String,
        startTime: String,
        eventType: String,
        eventYear eventYearString: String
    ) -> Int {
        // Convert String eventYear to Int, use global eventYear var as fallback
        // Note: parameter is 'eventYearString' internally to avoid shadowing global 'eventYear'
        let yearInt = Int(eventYearString) ?? eventYear
        let index = "\(bandName):\(location):\(startTime):\(eventType):\(yearInt)"
        return sqliteManager.getAttendanceStatusByIndex(index: index)
    }
    
    /// Gets all attendance records from SQLite
    func getAllAttendanceData() -> [String: [String: Any]] {
        var result: [String: [String: Any]] = [:]
        let allData = sqliteManager.getAllAttendanceDataByIndex()
        
        for (index, data) in allData {
            result[index] = data
        }
        
        return result
    }
    
    /// Gets all attendance records indexed by attendance index from SQLite
    func getAllAttendanceDataByIndex() -> [String: [String: Any]] {
        return sqliteManager.getAllAttendanceDataByIndex()
    }
    
    /// Sets attendance status using index-based lookup from SQLite
    func setAttendanceStatusByIndex(index: String, status: Int, timestamp: Double? = nil) {
        print("🎪 Setting attendance by index: \(index) -> \(status) [SQLite]")
        
        if let ts = timestamp {
            sqliteManager.setAttendanceStatusByIndex(index: index, status: status, timestamp: ts)
        } else {
            sqliteManager.setAttendanceStatusByIndex(index: index, status: status)
        }
    }
    
    /// Gets attendance status using index-based lookup from SQLite
    /// Also respects shared preference source if one is active
    func getAttendanceStatusByIndex(index: String) -> Int {
        // Check if viewing shared preferences
        let sharingManager = SharedPreferencesManager.shared
        let activeSource = sharingManager.getActivePreferenceSource()
        
        if activeSource != "Default" {
            // Use shared preferences
            return sharingManager.getAttendanceFromActiveSource(for: index)
        }
        
        return sqliteManager.getAttendanceStatusByIndex(index: index)
    }
    
    /// Stub for linking attendance records to events (no-op in SQLite version)
    func linkAttendanceRecordsToEvents() {
        // No-op: SQLite doesn't need to maintain relationships
        sqliteManager.linkAttendanceRecordsToEvents()
    }
    
    /// Stub for ensuring index field (no-op in SQLite version)
    func ensureAllAttendanceRecordsHaveIndex() {
        // No-op: SQLite always has indices
        print("✅ AttendanceManager: ensureAllAttendanceRecordsHaveIndex (SQLite - no action needed)")
    }
    
    // MARK: - Migration Support
    
    /// Core Data migration removed - all data now uses SQLite directly
    private func migrateFromCoreDataIfNeeded() {
        // Core Data migration removed - all data now uses SQLite directly
        // Mark migration as complete to prevent future checks
        let migrationKey = "AttendanceCoreDataToSQLiteMigrationCompleted"
        UserDefaults.standard.set(true, forKey: migrationKey)
        UserDefaults.standard.synchronize()
    }
    
    /// Migrates existing attendance data from the old system (for legacy migration support)
    func migrateExistingAttendance(from oldAttendanceData: [String: [String: Any]]) {
        print("🔄 Starting attendance migration for \(oldAttendanceData.count) records [SQLite]...")
        
        var migratedCount = 0
        
        for (key, data) in oldAttendanceData {
            guard let status = data["status"] as? Int,
                  let eventYear = data["eventYear"] as? Int else {
                continue
            }
            
            // Parse the old key format to create index
            let components = key.split(separator: "|").map(String.init)
            guard components.count >= 4 else { continue }
            
            let bandName = components[0]
            let location = components[1]
            let startTime = components[2]
            let eventType = components[3]
            
            let index = "\(bandName):\(location):\(startTime):\(eventType):\(eventYear)"
            
            sqliteManager.setAttendanceStatusByIndex(index: index, status: status)
            migratedCount += 1
        }
        
        print("✅ Migrated \(migratedCount) attendance records [SQLite]")
    }
}

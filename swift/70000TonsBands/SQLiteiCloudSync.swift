//
//  SQLiteiCloudSync.swift
//  70000 Tons Bands
//
//  Thread-safe iCloud synchronization using SQLite
//  Replaces CoreDataiCloudSync - NO Core Data - NO threading issues
//

import Foundation
import UIKit

/// Handles iCloud synchronization for SQLite data
/// Thread-safe - can be called from any thread
class SQLiteiCloudSync {
    private let priorityManager: SQLitePriorityManager
    private let attendanceManager: SQLiteAttendanceManager
    
    init() {
        self.priorityManager = SQLitePriorityManager.shared
        self.attendanceManager = SQLiteAttendanceManager.shared
    }
    
    // MARK: - Priority Sync
    
    /// Reads all priority data from iCloud and updates SQLite
    /// Thread-safe - can be called from any thread
    func syncPrioritiesFromiCloud(completion: @escaping () -> Void) {
        // CRITICAL: Block iCloud operations during database migration
        let isMigrating = UserDefaults.standard.bool(forKey: "PriorityUniqueConstraintMigration_Started")
        guard !isMigrating else {
            print("🚫 [ICLOUD_BLOCK] Database migration in progress - BLOCKING iCloud priority sync")
            completion()
            return
        }
        
        // CRITICAL: Block iCloud operations during profile switches
        let isSwitching = UserDefaults.standard.bool(forKey: "ProfileSwitchInProgress")
        guard !isSwitching else {
            print("🚫 [ICLOUD_BLOCK] Profile switch in progress - BLOCKING iCloud priority sync")
            completion()
            return
        }
        
        // CRITICAL: Only sync when Default profile is active
        let activeProfile = SharedPreferencesManager.shared.getActivePreferenceSource()
        guard activeProfile == "Default" else {
            print("☁️ [ICLOUD_SKIP] Active profile is '\(activeProfile)' (not Default) - skipping iCloud sync")
            completion()
            return
        }
        
        // Check if iCloud is enabled
        let iCloudHandler = iCloudDataHandler()
        guard iCloudHandler.checkForIcloud() else {
            print("☁️ iCloud disabled - skipping priority sync from iCloud")
            completion()
            return
        }
        
        print("☁️ Starting iCloud priority sync to SQLite...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion()
                return
            }
            
            let iCloudStore = NSUbiquitousKeyValueStore.default
            let allKeys = iCloudStore.dictionaryRepresentation.keys
            
            var processedCount = 0
            var updatedCount = 0
            
            // Process all priority records
            for key in allKeys {
                if key.hasPrefix("bandName:") {
                    let bandName = String(key.dropFirst("bandName:".count))
                    if let value = iCloudStore.string(forKey: key), !value.isEmpty {
                        if self.processiCloudPriorityRecord(bandName: bandName, value: value) {
                            updatedCount += 1
                        }
                        processedCount += 1
                    }
                }
            }
            
            print("☁️ Found \(processedCount) priority records in iCloud")
            print("📊 Priority - Processed: \(processedCount), Updated: \(updatedCount)")
            
            if processedCount == 0 {
                print("⚠️ NO PRIORITY RECORDS FOUND IN iCLOUD!")
            }
            
            print("☁️ iCloud priority sync completed")
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    /// Writes all local priorities to iCloud
    /// Thread-safe - can be called from any thread
    /// - Parameter completion: Called on the main queue when the async push finishes (or immediately when skipped).
    func syncPrioritiesToiCloud(completion: (() -> Void)? = nil) {
        // CRITICAL: Block iCloud operations during database migration
        let isMigrating = UserDefaults.standard.bool(forKey: "PriorityUniqueConstraintMigration_Started")
        guard !isMigrating else {
            print("🚫 [ICLOUD_BLOCK] Database migration in progress - BLOCKING iCloud priority sync")
            DispatchQueue.main.async { completion?() }
            return
        }
        
        // CRITICAL: Block iCloud operations during profile switches
        let isSwitching = UserDefaults.standard.bool(forKey: "ProfileSwitchInProgress")
        guard !isSwitching else {
            print("🚫 [ICLOUD_BLOCK] Profile switch in progress - BLOCKING iCloud priority sync")
            DispatchQueue.main.async { completion?() }
            return
        }
        
        // CRITICAL: Only sync when Default profile is active
        let activeProfile = SharedPreferencesManager.shared.getActivePreferenceSource()
        guard activeProfile == "Default" else {
            print("☁️ [ICLOUD_SKIP] Active profile is '\(activeProfile)' (not Default) - skipping iCloud sync")
            DispatchQueue.main.async { completion?() }
            return
        }
        
        // Check if iCloud is enabled
        let iCloudHandler = iCloudDataHandler()
        guard iCloudHandler.checkForIcloud() else {
            print("☁️ iCloud disabled - skipping priority sync to iCloud")
            DispatchQueue.main.async { completion?() }
            return
        }
        
        print("☁️ Starting priority sync to iCloud (Default only)...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion?() }
                return
            }
            
            // Only sync "Default" profile to iCloud
            let allPriorities = self.priorityManager.getAllPriorities(profileName: "Default")
            
            guard !allPriorities.isEmpty else {
                print("📝 No priorities to sync to iCloud (Default)")
                DispatchQueue.main.async { completion?() }
                return
            }
            
            var writeCount = 0
            var skipCount = 0
            
            for (bandName, priority) in allPriorities {
                if self.writePriorityToiCloud(bandName: bandName, priority: priority) {
                    writeCount += 1
                } else {
                    skipCount += 1
                }
            }
            
            // Force synchronization
            NSUbiquitousKeyValueStore.default.synchronize()
            
            print("☁️ Priority sync to iCloud completed")
            print("📊 Written: \(writeCount), Skipped: \(skipCount)")
            DispatchQueue.main.async { completion?() }
        }
    }
    
    /// Writes a single priority record to iCloud
    /// Thread-safe - can be called from any thread
    /// CRITICAL: Only writes if Default profile is active
    /// - Parameters:
    ///   - bandName: The band name
    ///   - priority: The priority value
    /// - Returns: True if written, false if skipped (not Default profile or iCloud disabled)
    func writePriorityToiCloud(bandName: String, priority: Int) -> Bool {
        // CRITICAL: Only sync when Default profile is active
        let activeProfile = SharedPreferencesManager.shared.getActivePreferenceSource()
        guard activeProfile == "Default" else {
            print("☁️ [ICLOUD_SKIP] Active profile is '\(activeProfile)' (not Default) - skipping priority write")
            return false
        }
        
        // Check if iCloud is enabled
        let iCloudHandler = iCloudDataHandler()
        guard iCloudHandler.checkForIcloud() else {
            print("☁️ iCloud disabled - skipping priority write")
            return false
        }
        
        // CRITICAL: Block iCloud operations during database migration
        let isMigrating = UserDefaults.standard.bool(forKey: "PriorityUniqueConstraintMigration_Started")
        guard !isMigrating else {
            print("🚫 [ICLOUD_BLOCK] Database migration in progress - BLOCKING priority write")
            return false
        }
        
        // CRITICAL: Block iCloud operations during profile switches
        let isSwitching = UserDefaults.standard.bool(forKey: "ProfileSwitchInProgress")
        guard !isSwitching else {
            print("🚫 [ICLOUD_BLOCK] Profile switch in progress - BLOCKING priority write")
            return false
        }
        
        let timestamp = priorityManager.getPriorityLastChange(for: bandName)
        let currentUID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        
        // Check if we should write to iCloud (timestamp comparison)
        let key = "bandName:" + bandName
        let iCloudStore = NSUbiquitousKeyValueStore.default
        
        if let existingValue = iCloudStore.string(forKey: key), !existingValue.isEmpty {
            let parts = existingValue.split(separator: ":")
            if parts.count == 3, let iCloudTimestamp = Double(parts[2]) {
                // Only write if our data is newer
                if timestamp <= iCloudTimestamp {
                    return false
                }
            }
        }
        
        // Write to iCloud
        let timestampString = String(format: "%.0f", timestamp > 0 ? timestamp : Date().timeIntervalSince1970)
        let dataString = "\(priority):\(currentUID):\(timestampString)"
        
        print("☁️ Writing priority to iCloud: \(bandName) = \(dataString)")
        iCloudStore.set(dataString, forKey: key)
        
        return true
    }
    
    /// Writes a single attendance record to iCloud
    /// Thread-safe - can be called from any thread
    /// CRITICAL: Only writes if Default profile is active
    /// - Parameters:
    ///   - eventIndex: The event identifier (format: "bandName:location:startTime:eventType:eventYear")
    ///   - status: The attendance status (can be "status:timestamp" or just "status")
    /// - Returns: True if written, false if skipped (not Default profile or iCloud disabled)
    func writeAttendanceRecordToiCloud(eventIndex: String, status: String) -> Bool {
        // CRITICAL: Only sync when Default profile is active
        let activeProfile = SharedPreferencesManager.shared.getActivePreferenceSource()
        guard activeProfile == "Default" else {
            print("☁️ [ICLOUD_SKIP] Active profile is '\(activeProfile)' (not Default) - skipping attendance write")
            return false
        }
        
        // Check if iCloud is enabled
        let iCloudHandler = iCloudDataHandler()
        guard iCloudHandler.checkForIcloud() else {
            print("☁️ iCloud disabled - skipping attendance write")
            return false
        }
        
        // CRITICAL: Block iCloud operations during database migration
        let isMigrating = UserDefaults.standard.bool(forKey: "PriorityUniqueConstraintMigration_Started")
        guard !isMigrating else {
            print("🚫 [ICLOUD_BLOCK] Database migration in progress - BLOCKING attendance write")
            return false
        }
        
        // CRITICAL: Block iCloud operations during profile switches
        let isSwitching = UserDefaults.standard.bool(forKey: "ProfileSwitchInProgress")
        guard !isSwitching else {
            print("🚫 [ICLOUD_BLOCK] Profile switch in progress - BLOCKING attendance write")
            return false
        }
        
        // Parse status to extract status value and timestamp
        let statusParts = status.split(separator: ":")
        let statusString: String
        let timestamp: Double
        
        if statusParts.count == 2, let parsedTimestamp = Double(statusParts[1]) {
            // Status format: "status:timestamp"
            statusString = String(statusParts[0])
            timestamp = parsedTimestamp
        } else {
            // Status format: just "status" - use current time
            statusString = status
            timestamp = Date().timeIntervalSince1970
        }
        
        // Get current device UID
        guard let currentUid = UIDevice.current.identifierForVendor?.uuidString else {
            print("☁️ ERROR - Cannot get device UID, skipping attendance write")
            return false
        }
        
        // Create iCloud key and value
        let iCloudKey = "eventName:" + eventIndex
        let iCloudValue = "\(statusString):\(currentUid):\(String(format: "%.0f", timestamp))"
        
        let iCloudStore = NSUbiquitousKeyValueStore.default
        if let existingValue = iCloudStore.string(forKey: iCloudKey), !existingValue.isEmpty {
            let parts = existingValue.split(separator: ":")
            if parts.count >= 3, let iCloudTimestamp = Double(parts[2]), timestamp <= iCloudTimestamp {
                print("☁️ Skipping attendance write for \(eventIndex) - local timestamp not newer")
                return false
            }
        }
        
        print("☁️ Writing attendance to iCloud: \(eventIndex) = \(iCloudValue)")
        iCloudStore.set(iCloudValue, forKey: iCloudKey)
        iCloudStore.synchronize()
        
        return true
    }
    
    // MARK: - Attendance Sync
    
    /// Reads all attendance data from iCloud and updates SQLite
    /// Thread-safe - can be called from any thread
    func syncAttendanceFromiCloud(completion: @escaping () -> Void) {
        // CRITICAL: Block iCloud operations during database migration
        let isMigrating = UserDefaults.standard.bool(forKey: "PriorityUniqueConstraintMigration_Started")
        guard !isMigrating else {
            print("🚫 [ICLOUD_BLOCK] Database migration in progress - BLOCKING iCloud attendance sync")
            completion()
            return
        }
        
        // CRITICAL: Block iCloud operations during profile switches
        let isSwitching = UserDefaults.standard.bool(forKey: "ProfileSwitchInProgress")
        guard !isSwitching else {
            print("🚫 [ICLOUD_BLOCK] Profile switch in progress - BLOCKING iCloud attendance sync")
            completion()
            return
        }
        
        // CRITICAL: Only sync when Default profile is active
        let activeProfile = SharedPreferencesManager.shared.getActivePreferenceSource()
        guard activeProfile == "Default" else {
            print("☁️ [ICLOUD_SKIP] Active profile is '\(activeProfile)' (not Default) - skipping iCloud sync")
            completion()
            return
        }
        
        // Check if iCloud is enabled
        let iCloudHandler = iCloudDataHandler()
        guard iCloudHandler.checkForIcloud() else {
            print("☁️ iCloud disabled - skipping attendance sync from iCloud")
            completion()
            return
        }
        
        print("☁️ Starting iCloud attendance sync to SQLite...")
        print("🔍 [CLEAR_DEBUG] syncFromiCloud started (any iCloud key with no local row will be written to SQLite)")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion()
                return
            }
            
            let iCloudStore = NSUbiquitousKeyValueStore.default
            let allKeys = iCloudStore.dictionaryRepresentation.keys
            
            print("☁️ Found \(allKeys.count) total keys in iCloud")
            
            var processedCount = 0
            var updatedCount = 0
            var attendanceKeys: [String] = []
            
            // Process all attendance records
            for key in allKeys {
                if key.hasPrefix("eventName:") {
                    attendanceKeys.append(key)
                    if let value = iCloudStore.string(forKey: key), !value.isEmpty {
                        print("☁️ Processing attendance key: \(key) = \(value)")
                        if self.processiCloudAttendanceRecord(key: key, value: value) {
                            updatedCount += 1
                        }
                        processedCount += 1
                    }
                }
            }
            
            print("☁️ Found \(attendanceKeys.count) attendance keys in iCloud")
            print("📊 Attendance - Processed: \(processedCount), Updated: \(updatedCount)")
            if updatedCount > 0 {
                print("🔍 [CLEAR_DEBUG] syncFromiCloud wrote \(updatedCount) record(s) from iCloud into SQLite (if these are cleared-year keys, they were restored)")
            }
            
            if attendanceKeys.count == 0 {
                print("⚠️ NO ATTENDANCE KEYS FOUND IN iCLOUD!")
            }
            
            print("☁️ iCloud attendance sync completed")
            
            // Notify completion
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("iCloudAttendanceSyncCompleted"), object: nil)
                completion()
            }
        }
    }
    
    /// Removes from NSUbiquitousKeyValueStore all attendance keys for the given year.
    /// Call this immediately after clearing SQLite attendance for that year so syncFromiCloud cannot restore them.
    /// Uses same guards as other attendance sync (Default profile, iCloud enabled). Completion called on main queue.
    func removeAttendanceKeysForYearFromKVStore(forYear year: Int, completion: @escaping () -> Void) {
        let isMigrating = UserDefaults.standard.bool(forKey: "PriorityUniqueConstraintMigration_Started")
        guard !isMigrating else {
            DispatchQueue.main.async { completion() }
            return
        }
        let isSwitching = UserDefaults.standard.bool(forKey: "ProfileSwitchInProgress")
        guard !isSwitching else {
            DispatchQueue.main.async { completion() }
            return
        }
        let activeProfile = SharedPreferencesManager.shared.getActivePreferenceSource()
        guard activeProfile == "Default" else {
            DispatchQueue.main.async { completion() }
            return
        }
        let iCloudHandler = iCloudDataHandler()
        guard iCloudHandler.checkForIcloud() else {
            DispatchQueue.main.async { completion() }
            return
        }
        let eventNamePrefix = "eventName:"
        let yearSuffix = ":\(year)"
        DispatchQueue.global(qos: .userInitiated).async {
            let iCloudStore = NSUbiquitousKeyValueStore.default
            var removedCount = 0
            for key in iCloudStore.dictionaryRepresentation.keys {
                guard key.hasPrefix(eventNamePrefix) else { continue }
                let index = String(key.dropFirst(eventNamePrefix.count))
                if index.hasSuffix(yearSuffix) {
                    iCloudStore.removeObject(forKey: key)
                    removedCount += 1
                }
            }
            if removedCount > 0 {
                iCloudStore.synchronize()
                print("☁️ Removed \(removedCount) attendance keys for year \(year) from KV store (clear-all fix)")
            }
            DispatchQueue.main.async { completion() }
        }
    }
    
    /// Writes all local attendance data to iCloud and removes keys no longer in SQLite.
    /// Thread-safe - can be called from any thread.
    ///
    /// **Ordering:** Call only after `syncAttendanceFromiCloud` has finished merging remote rows into SQLite
    /// (e.g. on a fresh install). Otherwise the prune step deletes every `eventName:` key absent from the
    /// still-empty/sparse local DB and wipes iCloud attendance.
    ///
    /// - Parameter completion: Optional; called on main queue when done. Use after Clear All so UI refresh happens only after iCloud is updated (avoids syncFromiCloud restoring cleared data).
    func syncAttendanceToiCloud(completion: (() -> Void)? = nil) {
        // CRITICAL: Block iCloud operations during database migration
        let isMigrating = UserDefaults.standard.bool(forKey: "PriorityUniqueConstraintMigration_Started")
        guard !isMigrating else {
            print("🚫 [ICLOUD_BLOCK] Database migration in progress - BLOCKING iCloud attendance sync")
            DispatchQueue.main.async { completion?() }
            return
        }
        
        // CRITICAL: Block iCloud operations during profile switches
        let isSwitching = UserDefaults.standard.bool(forKey: "ProfileSwitchInProgress")
        guard !isSwitching else {
            print("🚫 [ICLOUD_BLOCK] Profile switch in progress - BLOCKING iCloud attendance sync")
            DispatchQueue.main.async { completion?() }
            return
        }
        
        // CRITICAL: Only sync when Default profile is active
        let activeProfile = SharedPreferencesManager.shared.getActivePreferenceSource()
        guard activeProfile == "Default" else {
            print("☁️ [ICLOUD_SKIP] Active profile is '\(activeProfile)' (not Default) - skipping iCloud sync")
            DispatchQueue.main.async { completion?() }
            return
        }
        
        // Check if iCloud is enabled
        let iCloudHandler = iCloudDataHandler()
        guard iCloudHandler.checkForIcloud() else {
            print("☁️ iCloud disabled - skipping attendance sync to iCloud")
            DispatchQueue.main.async { completion?() }
            return
        }
        
        print("☁️ Starting attendance sync to iCloud (Default only)...")
        print("🔍 [CLEAR_DEBUG] syncToiCloud async work queued (will read SQLite, remove stale iCloud keys, then call completion)")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion?() }
                return
            }
            
            // Only sync "Default" profile to iCloud
            let allAttendance = self.attendanceManager.getAllAttendanceDataByIndex(profileName: "Default")
            let iCloudStore = NSUbiquitousKeyValueStore.default
            
            var writtenCount = 0
            var skippedCount = 0
            
            let currentIndices = Set(allAttendance.keys)
            for (index, data) in allAttendance {
                guard let status = data["status"] as? Int,
                      let lastModified = data["lastModified"] as? Double else { continue }
                
                // Get current device UID
                guard let currentUid = UIDevice.current.identifierForVendor?.uuidString else { continue }
                
                let iCloudKey = "eventName:\(index)"
                let iCloudValue = "\(status):\(currentUid):\(String(format: "%.0f", lastModified))"
                
                if let existingValue = iCloudStore.string(forKey: iCloudKey), !existingValue.isEmpty {
                    let parts = existingValue.split(separator: ":")
                    if parts.count >= 3, let iCloudTimestamp = Double(parts[2]), lastModified <= iCloudTimestamp {
                        skippedCount += 1
                        continue
                    }
                }
                
                iCloudStore.set(iCloudValue, forKey: iCloudKey)
                writtenCount += 1
            }
            
            // Remove from iCloud any attendance keys that are no longer in SQLite (e.g. after Clear all attendance).
            // Otherwise syncAttendanceFromiCloud would restore them when the app next runs or becomes active.
            let eventNamePrefix = "eventName:"
            var removedCount = 0
            for key in iCloudStore.dictionaryRepresentation.keys {
                guard key.hasPrefix(eventNamePrefix) else { continue }
                let index = String(key.dropFirst(eventNamePrefix.count))
                if !currentIndices.contains(index) {
                    iCloudStore.removeObject(forKey: key)
                    removedCount += 1
                }
            }
            if removedCount > 0 {
                print("☁️ Removed \(removedCount) stale attendance keys from iCloud")
                print("🔍 [CLEAR_DEBUG] syncToiCloud removed \(removedCount) keys from iCloud (cleared-year keys no longer in iCloud)")
            }
            
            // Synchronize with iCloud
            iCloudStore.synchronize()
            
            print("☁️ Attendance sync to iCloud completed")
            print("📊 Written: \(writtenCount) records, Skipped (not newer): \(skippedCount)")
            DispatchQueue.main.async { completion?() }
        }
    }
    
    // MARK: - Private Helpers
    
    /// Processes a single iCloud attendance record and updates SQLite if needed
    private func processiCloudAttendanceRecord(key: String, value: String) -> Bool {
        print("☁️ Processing iCloud attendance record: \(key) = \(value)")
        
        // Parse the key to extract event details
        let keyComponents = key.components(separatedBy: ":")
        guard keyComponents.count >= 7,
              keyComponents[0] == "eventName" else {
            print("❌ Invalid iCloud attendance key format: \(key)")
            return false
        }
        
        let bandName = keyComponents[1]
        let location = keyComponents[2]
        let startTime = keyComponents[3] + ":" + keyComponents[4]
        let eventType = keyComponents[5]
        let eventYearString = keyComponents[6]
        
        // Create the attendance index
        let attendanceIndex = "\(bandName):\(location):\(startTime):\(eventType):\(eventYearString)"
        print("☁️ Created attendance index: \(attendanceIndex)")
        
        // Value: status:uid:timestamp (legacy builds may have a 4th field; ignored)
        let valueComponents = value.components(separatedBy: ":")
        guard valueComponents.count >= 3,
              let timestamp = Double(valueComponents[2]) else {
            print("❌ Invalid iCloud attendance value format: \(value)")
            return false
        }
        
        // Convert status string to numeric value
        let statusString = valueComponents[0]
        let status: Int
        switch statusString {
        case "sawAll":
            status = 2
        case "sawSome":
            status = 1
        case "sawNone":
            status = 3
        default:
            if let numericStatus = Int(statusString) {
                status = numericStatus
            } else {
                print("❌ Unknown status format: \(statusString)")
                return false
            }
        }
        
        print("☁️ Converted status: \(statusString) -> \(status)")
        
        let localStatus = attendanceManager.getAttendanceStatusByIndex(index: attendanceIndex)
        let localTimestamp = localAttendanceLastModified(for: attendanceIndex)
        print("☁️ Local attendance state for \(attendanceIndex): status=\(localStatus), timestamp=\(localTimestamp)")
        
        // Last-write-wins: apply iCloud only when iCloud is strictly newer.
        if localStatus != 0 && timestamp <= localTimestamp {
            print("☁️ Skipping attendance update for \(attendanceIndex) - iCloud not newer")
            return false
        }
        
        if localStatus == 0 {
            print("☁️ No local data exists, using iCloud data")
            print("🔍 [CLEAR_DEBUG] Restoring from iCloud -> SQLite index=\(attendanceIndex) year=\(eventYearString)")
        }
        
        print("☁️ Updating attendance record (Default): \(attendanceIndex) -> \(status)")
        attendanceManager.setAttendanceStatusByIndex(
            index: attendanceIndex,
            status: status,
            timestamp: timestamp,
            profileName: nil
        )
        
        print("✅ Updated attendance from iCloud: \(attendanceIndex) -> \(status)")
        return true
    }
    
    /// Gets local lastModified timestamp for one attendance index in Default profile.
    private func localAttendanceLastModified(for index: String) -> Double {
        let allAttendance = attendanceManager.getAllAttendanceDataByIndex(profileName: "Default")
        return allAttendance[index]?["lastModified"] as? Double ?? 0
    }
    
    /// Processes a single iCloud priority record and updates SQLite if needed
    private func processiCloudPriorityRecord(bandName: String, value: String) -> Bool {
        guard !value.isEmpty && value != "5" else {
            return false
        }
        
        let parts = value.split(separator: ":")
        
        // Handle format: priority:uid:timestamp (3 parts)
        guard parts.count == 3,
              let priority = Int(parts[0]),
              let timestamp = Double(parts[2]) else {
            print("☁️ Invalid format for \(bandName): \(value)")
            return false
        }
        
        let deviceUID = String(parts[1])
        let currentUID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        
        print("☁️ Processing \(bandName) - iCloud: \(priority):\(deviceUID):\(timestamp), currentUID: \(currentUID)")
        
        // Get local data to determine if we should restore from iCloud
        let localTimestamp = priorityManager.getPriorityLastChange(for: bandName)
        let currentPriority = priorityManager.getPriority(for: bandName)
        
        print("☁️ Local state for \(bandName): priority=\(currentPriority), timestamp=\(localTimestamp)")
        
        // RULE 1: Only skip if UID matches current device AND local data exists
        if deviceUID == currentUID && currentPriority != 0 {
            print("☁️ Skipping \(bandName) - same device UID and local data exists")
            return false
        }
        
        // RULE 2: If local data exists from different device, check timestamps
        if currentPriority != 0 && deviceUID != currentUID {
            if localTimestamp > 0 {
                guard timestamp > localTimestamp else {
                    print("☁️ Skipping \(bandName) - iCloud not newer")
                    return false
                }
            } else {
                print("☁️ Skipping \(bandName) - local data exists from different device")
                return false
            }
        }
        
        // RULE 3: If no local data exists, use iCloud data regardless of UID
        if currentPriority == 0 {
            print("☁️ No local data exists, using iCloud data")
        }
        
        // Update SQLite with iCloud data
        print("☁️ Updating \(bandName): \(currentPriority) -> \(priority)")
        priorityManager.updatePriorityFromiCloud(
            bandName: bandName,
            priority: priority,
            timestamp: timestamp,
            deviceUID: deviceUID
        )
        
        return true
    }
    
    // MARK: - Batch Operations
    
    /// Performs a complete two-way sync between SQLite and iCloud
    func performFullSync(completion: @escaping () -> Void) {
        // CRITICAL: Only sync when Default profile is active
        let activeProfile = SharedPreferencesManager.shared.getActivePreferenceSource()
        guard activeProfile == "Default" else {
            print("☁️ [ICLOUD_SKIP] Active profile is '\(activeProfile)' (not Default) - skipping iCloud sync")
            completion()
            return
        }
        
        // Check if iCloud is enabled
        let iCloudHandler = iCloudDataHandler()
        guard iCloudHandler.checkForIcloud() else {
            print("☁️ iCloud disabled - skipping full sync")
            completion()
            return
        }
        
        print("🔄 Starting full iCloud sync...")
        
        // First, read from iCloud to get latest changes
        syncPrioritiesFromiCloud { [weak self] in
            // Then write our local changes to iCloud
            self?.syncPrioritiesToiCloud()
            
            print("✅ Full iCloud sync completed")
            completion()
        }
    }
    
    /// Sets up automatic iCloud sync monitoring
    func setupAutomaticSync() {
        // Check if iCloud is enabled before setting up monitoring
        let iCloudHandler = iCloudDataHandler()
        guard iCloudHandler.checkForIcloud() else {
            print("☁️ iCloud disabled - skipping automatic sync setup")
            return
        }
        
        // Monitor iCloud changes
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] notification in
            // Double-check iCloud is still enabled when notification fires
            let iCloudHandler = iCloudDataHandler()
            guard iCloudHandler.checkForIcloud() else {
                print("☁️ iCloud disabled - ignoring external change notification")
                return
            }
            print("☁️ iCloud data changed externally, syncing...")
            self?.syncPrioritiesFromiCloud { }
        }
        
        // Monitor app lifecycle for sync opportunities
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Check if iCloud is still enabled when app becomes active
            let iCloudHandler = iCloudDataHandler()
            guard iCloudHandler.checkForIcloud() else {
                print("☁️ iCloud disabled - skipping app active sync")
                return
            }
            print("📱 App became active, checking iCloud sync...")
            self?.syncPrioritiesFromiCloud { }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📱 App will resign active, syncing to iCloud...")
            self?.syncPrioritiesToiCloud()
        }
        
        print("✅ Automatic iCloud sync monitoring enabled")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}


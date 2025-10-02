import Foundation
import CoreData
import UIKit

/// Handles iCloud synchronization for Core Data entities
/// Replaces the legacy iCloud sync system with Core Data integration
class CoreDataiCloudSync {
    private let priorityManager: PriorityManager
    private let attendanceManager: AttendanceManager
    private let coreDataManager: CoreDataManager
    
    init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        self.coreDataManager = coreDataManager
        self.priorityManager = PriorityManager(coreDataManager: coreDataManager)
        self.attendanceManager = AttendanceManager(coreDataManager: coreDataManager)
    }
    
    // MARK: - Priority Sync
    
    /// Reads all priority data from iCloud and updates Core Data
    /// Replaces iCloudDataHandler.readAllPriorityData
    func syncPrioritiesFromiCloud(completion: @escaping () -> Void) {
        print("☁️ Starting iCloud priority sync to Core Data...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { 
                completion()
                return 
            }
            
            let iCloudStore = NSUbiquitousKeyValueStore.default
            let allKeys = iCloudStore.dictionaryRepresentation.keys
            
            var processedCount = 0
            var updatedCount = 0
            
            // Collect all priority records to process
            var recordsToProcess: [(bandName: String, value: String)] = []
            for key in allKeys {
                if key.hasPrefix("bandName:") {
                    let bandName = String(key.dropFirst("bandName:".count))
                    if let value = iCloudStore.string(forKey: key), !value.isEmpty {
                        recordsToProcess.append((bandName: bandName, value: value))
                    }
                }
            }
            
            // Process all records on the main thread (Core Data requirement)
            DispatchQueue.main.async {
                for record in recordsToProcess {
                    if self.processiCloudPriorityRecord(bandName: record.bandName, value: record.value) {
                        updatedCount += 1
                    }
                    processedCount += 1
                }
                
                print("☁️ Found \(recordsToProcess.count) priority records in iCloud")
                print("📊 Priority - Processed: \(processedCount), Updated: \(updatedCount)")
                
                if recordsToProcess.count == 0 {
                    print("⚠️ NO PRIORITY RECORDS FOUND IN iCLOUD!")
                    print("⚠️ This suggests priority data was never written to iCloud")
                }
                
                print("☁️ iCloud priority sync completed")
                completion()
            }
        }
    }
    
    /// Writes all local priorities to iCloud
    /// Replaces iCloudDataHandler.writeAllPriorityData
    func syncPrioritiesToiCloud() {
        print("☁️ Starting priority sync to iCloud...")
        
        // Perform Core Data operations on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let allPriorities = self.priorityManager.getAllPriorities()
            
            guard !allPriorities.isEmpty else {
                print("📝 No priorities to sync to iCloud")
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
        }
    }
    
    /// Writes a single priority record to iCloud
    /// Replaces iCloudDataHandler.writeAPriorityRecord
    func writePriorityToiCloud(bandName: String, priority: Int) -> Bool {
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
                    print("⏭️ Skipping iCloud write for \(bandName) - not newer (\(timestamp) <= \(iCloudTimestamp))")
                    return false
                }
            }
        }
        
        // Write to iCloud
        let timestampString = String(format: "%.0f", timestamp > 0 ? timestamp : Date().timeIntervalSince1970)
        let dataString = "\(priority):\(currentUID):\(timestampString)"
        
        print("☁️ Writing to iCloud: \(bandName) = \(dataString)")
        iCloudStore.set(dataString, forKey: key)
        
        return true
    }
    
    /// Reads a single priority record from iCloud
    /// Replaces iCloudDataHandler.readAPriorityRecord
    func readPriorityFromiCloud(bandName: String) {
        let key = "bandName:" + bandName
        let iCloudStore = NSUbiquitousKeyValueStore.default
        
        if let value = iCloudStore.string(forKey: key), !value.isEmpty {
            _ = processiCloudPriorityRecord(bandName: bandName, value: value)
        } else {
            print("☁️ No iCloud data found for band: \(bandName)")
        }
    }
    
    // MARK: - Attendance Sync
    
    /// Reads all attendance data from iCloud and updates Core Data
    /// Replaces iCloudDataHandler.readCloudAttendedData
    func syncAttendanceFromiCloud(completion: @escaping () -> Void) {
        print("☁️ Starting iCloud attendance sync to Core Data...")
        
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
            
            // Collect all attendance records to process
            var recordsToProcess: [(key: String, value: String)] = []
            for key in allKeys {
                if key.hasPrefix("eventName:") {
                    attendanceKeys.append(key)
                    if let value = iCloudStore.string(forKey: key), !value.isEmpty {
                        recordsToProcess.append((key: key, value: value))
                    }
                }
            }
            
            // Process all records on the main thread (Core Data requirement)
            DispatchQueue.main.async {
                for record in recordsToProcess {
                    print("☁️ Processing attendance key: \(record.key) = \(record.value)")
                    if self.processiCloudAttendanceRecord(key: record.key, value: record.value) {
                        updatedCount += 1
                    }
                    processedCount += 1
                }
                
                print("☁️ Found \(attendanceKeys.count) attendance keys in iCloud")
                print("📊 Attendance - Processed: \(processedCount), Updated: \(updatedCount)")
                
                if attendanceKeys.count == 0 {
                    print("⚠️ NO ATTENDANCE KEYS FOUND IN iCLOUD!")
                    print("⚠️ This suggests attendance data was never written to iCloud")
                }
                
                print("☁️ iCloud attendance sync completed")
                
                // Link any unlinked attendance records to events on main thread
                print("🔗 Linking attendance records to events...")
                self.attendanceManager.linkAttendanceRecordsToEvents()
                print("🔗 Linking completed")
                
                // Notify completion
                NotificationCenter.default.post(name: Notification.Name("iCloudAttendanceSyncCompleted"), object: nil)
                print("☁️ Attendance sync completion handler called")
                completion()
            }
        }
    }
    
    /// Writes all local attendance data to iCloud
    /// Replaces iCloudDataHandler.writeAllScheduleData
    func syncAttendanceToiCloud() {
        print("☁️ Starting attendance sync to iCloud...")
        
        // Perform Core Data operations on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let allAttendance = self.attendanceManager.getAllAttendanceDataByIndex()
            let iCloudStore = NSUbiquitousKeyValueStore.default
            
            var writtenCount = 0
            
            for (index, data) in allAttendance {
                guard let status = data["status"] as? Int,
                      let lastModified = data["lastModified"] as? Double else { continue }
                
                // Get current device UID
                guard let currentUid = UIDevice.current.identifierForVendor?.uuidString else { continue }
                
                // Create iCloud key and value
                let iCloudKey = "eventName:\(index)"
                let iCloudValue = "\(status):\(currentUid):\(String(format: "%.0f", lastModified))"
                
                iCloudStore.set(iCloudValue, forKey: iCloudKey)
                writtenCount += 1
            }
            
            // Synchronize with iCloud
            iCloudStore.synchronize()
            
            print("☁️ Attendance sync to iCloud completed")
            print("📊 Written: \(writtenCount) records")
        }
    }
    
    // MARK: - Private Helpers
    
    /// Processes a single iCloud attendance record and updates Core Data if needed
    /// - Parameters:
    ///   - key: iCloud key (format: "eventName:bandName:location:startTime:eventType:eventYear")
    ///   - value: iCloud value string (format: status:uid:timestamp)
    /// - Returns: True if the record was updated, false otherwise
    private func processiCloudAttendanceRecord(key: String, value: String) -> Bool {
        print("☁️ Processing iCloud attendance record: \(key) = \(value)")
        
        // Parse the key to extract event details
        // Note: Time format "HH:MM" contains a colon, so we need to reconstruct it
        let keyComponents = key.components(separatedBy: ":")
        guard keyComponents.count >= 7,  // eventName + band + location + HH + MM + type + year
              keyComponents[0] == "eventName" else {
            print("❌ Invalid iCloud attendance key format: \(key) (components: \(keyComponents.count))")
            return false
        }
        
        let bandName = keyComponents[1]
        let location = keyComponents[2]
        let startTime = keyComponents[3] + ":" + keyComponents[4]  // Reconstruct "HH:MM"
        let eventType = keyComponents[5]
        let eventYearString = keyComponents[6]
        
        // Create the attendance index
        let attendanceIndex = "\(bandName):\(location):\(startTime):\(eventType):\(eventYearString)"
        print("☁️ Created attendance index: \(attendanceIndex)")
        
        // Parse the value (format: status:uid:timestamp)
        let valueComponents = value.components(separatedBy: ":")
        guard valueComponents.count >= 3,
              let timestamp = Double(valueComponents[2]) else {
            print("❌ Invalid iCloud attendance value format: \(value) (components: \(valueComponents.count))")
            return false
        }
        
        // Convert status string to numeric value
        let statusString = valueComponents[0]
        let status: Int
        switch statusString {
        case "sawAll":
            status = 2  // Attended
        case "sawSome":
            status = 1  // Will Attend Some
        case "sawNone":
            status = 3  // Won't Attend
        default:
            // Try to parse as integer
            if let numericStatus = Int(statusString) {
                status = numericStatus
            } else {
                print("❌ Unknown status format: \(statusString)")
                return false
            }
        }
        
        print("☁️ Converted status: \(statusString) -> \(status)")
        
        let uidValue = valueComponents[1]
        
        // Get current device UID
        guard let currentUid = UIDevice.current.identifierForVendor?.uuidString else {
            print("❌ Could not get current device UID")
            return false
        }
        
        print("☁️ Device UID: \(currentUid), iCloud UID: \(uidValue)")
        
        // RULE 1: Only skip if UID matches current device AND local data exists
        let localStatus = attendanceManager.getAttendanceStatusByIndex(index: attendanceIndex)
        print("☁️ Local status for index \(attendanceIndex): \(localStatus)")
        
        if uidValue == currentUid && localStatus != 0 {
            print("☁️ Skipping - same device UID and local data exists")
            return false
        }
        
        // RULE 2: If local data exists and UID is different, check timestamps
        if localStatus != 0 && uidValue != currentUid {
            // Local data exists from different device, check if we should update
            // For now, we'll be conservative and not overwrite existing local data
            // This could be enhanced to check timestamps if needed
            print("☁️ Skipping - local data exists from different device")
            return false
        }
        
        // RULE 3: If no local data exists, use iCloud data regardless of UID
        if localStatus == 0 {
            print("☁️ No local data exists, using iCloud data")
        }
        
        // Update the attendance record using index-based method
        print("☁️ Updating attendance record: \(attendanceIndex) -> \(status)")
        
        // Update directly - we're already on the correct thread
        attendanceManager.setAttendanceStatusByIndex(
            index: attendanceIndex,
            status: status,
            timestamp: timestamp
        )
        
        print("✅ Updated attendance from iCloud: \(attendanceIndex) -> \(status)")
        return true
    }
    
    /// Processes a single iCloud priority record and updates Core Data if needed
    /// - Parameters:
    ///   - bandName: Name of the band
    ///   - value: iCloud value string (format: priority:uid:timestamp)
    /// - Returns: True if the record was updated in Core Data
    private func processiCloudPriorityRecord(bandName: String, value: String) -> Bool {
        guard !value.isEmpty && value != "5" else {
            print("☁️ Skipping \(bandName) - empty or no data (\(value))")
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
            // Local data exists from different device
            if localTimestamp > 0 {
                guard timestamp > localTimestamp else {
                    print("☁️ Skipping \(bandName) - iCloud not newer (\(timestamp) <= \(localTimestamp))")
                    return false
                }
            } else {
                // Local data exists but no timestamp - be conservative
                print("☁️ Skipping \(bandName) - local data exists from different device, no timestamp comparison")
                return false
            }
        }
        
        // RULE 3: If no local data exists, use iCloud data regardless of UID
        if currentPriority == 0 {
            print("☁️ No local data exists, using iCloud data")
        }
        
        // Update Core Data with iCloud data
        print("☁️ Updating \(bandName): \(currentPriority) -> \(priority) (timestamp: \(timestamp))")
        priorityManager.updatePriorityFromiCloud(
            bandName: bandName,
            priority: priority,
            timestamp: timestamp,
            deviceUID: deviceUID
        )
        
        return true
    }
    
    // MARK: - Batch Operations
    
    /// Performs a complete two-way sync between Core Data and iCloud
    func performFullSync(completion: @escaping () -> Void) {
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
        // Monitor iCloud changes
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] notification in
            print("☁️ iCloud data changed externally, syncing...")
            self?.syncPrioritiesFromiCloud { }
        }
        
        // Monitor app lifecycle for sync opportunities
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
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

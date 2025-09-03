import Foundation
import CoreData

/// Handles iCloud synchronization for Core Data entities
/// Replaces the legacy iCloud sync system with Core Data integration
class CoreDataiCloudSync {
    private let priorityManager: PriorityManager
    private let coreDataManager: CoreDataManager
    
    init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        self.coreDataManager = coreDataManager
        self.priorityManager = PriorityManager(coreDataManager: coreDataManager)
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
            
            // Process all iCloud keys that start with "bandName:"
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
            
            print("☁️ iCloud priority sync completed")
            print("📊 Processed: \(processedCount), Updated: \(updatedCount)")
            
            // Notify completion on main thread
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("iCloudPrioritySyncCompleted"), object: nil)
                completion()
            }
        }
    }
    
    /// Writes all local priorities to iCloud
    /// Replaces iCloudDataHandler.writeAllPriorityData
    func syncPrioritiesToiCloud() {
        print("☁️ Starting priority sync to iCloud...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
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
    
    // MARK: - Private Helpers
    
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
        
        // RULE 1: Never overwrite local data if UID matches current device
        if deviceUID == currentUID {
            print("☁️ Skipping \(bandName) - UID matches current device")
            return false
        }
        
        // RULE 2: Only update if iCloud data is newer than local data
        let localTimestamp = priorityManager.getPriorityLastChange(for: bandName)
        let currentPriority = priorityManager.getPriority(for: bandName)
        
        if localTimestamp > 0 {
            guard timestamp > localTimestamp else {
                print("☁️ Skipping \(bandName) - iCloud not newer (\(timestamp) <= \(localTimestamp))")
                return false
            }
        } else if currentPriority != 0 {
            // Local data exists but no timestamp - be conservative
            print("☁️ Skipping \(bandName) - local data exists but no timestamp")
            return false
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

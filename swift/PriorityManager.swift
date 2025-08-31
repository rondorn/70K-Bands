import Foundation
import CoreData

/// Manages band priorities using Core Data
/// Replaces the old dictionary-based priority system with database storage
class PriorityManager {
    private let coreDataManager: CoreDataManager
    
    init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        self.coreDataManager = coreDataManager
    }
    
    // MARK: - Priority Management
    
    /// Sets priority for a band (replaces dataHandler.addPriorityData)
    /// - Parameters:
    ///   - bandName: Name of the band
    ///   - priority: Priority value (0=Unknown, 1=Must See, 2=Might See, 3=Won't See)
    ///   - timestamp: Optional timestamp, defaults to current time
    func setPriority(for bandName: String, priority: Int, timestamp: Double? = nil) {
        print("🎯 Setting priority for \(bandName) = \(priority)")
        
        // Get or create the band
        let band = coreDataManager.createOrUpdateBand(name: bandName)
        
        // Get or create the priority record
        let userPriority = getUserPriority(for: band) ?? createUserPriority(for: band)
        
        // Update the priority
        userPriority.priorityLevel = Int16(priority)
        userPriority.updatedAt = Date()
        // Note: deviceUID and lastModified fields need to be added to the Core Data model
        
        // Save to Core Data
        coreDataManager.saveContext()
        
        // Sync to iCloud (background thread)
        DispatchQueue.global(qos: .default).async {
            let iCloudHandler = iCloudDataHandler()
            iCloudHandler.writeAPriorityRecord(bandName: bandName, priority: priority)
        }
        
        print("✅ Priority saved for \(bandName): \(priority)")
    }
    
    /// Gets priority for a band (replaces dataHandler.getPriorityData)
    /// - Parameter bandName: Name of the band
    /// - Returns: Priority value (0 if not found)
    func getPriority(for bandName: String) -> Int {
        guard let band = coreDataManager.fetchBand(byName: bandName),
              let userPriority = getUserPriority(for: band) else {
            return 0
        }
        
        return Int(userPriority.priorityLevel)
    }
    
    /// Gets the last change timestamp for a band's priority
    /// - Parameter bandName: Name of the band
    /// - Returns: Timestamp of last change (0 if not found)
    func getPriorityLastChange(for bandName: String) -> Double {
        guard let band = coreDataManager.fetchBand(byName: bandName),
              let userPriority = getUserPriority(for: band) else {
            return 0.0
        }
        
        return userPriority.updatedAt?.timeIntervalSince1970 ?? 0.0
    }
    
    /// Gets all bands with their priorities (replaces dataHandler.readFile)
    /// - Returns: Dictionary of band names to priority values
    func getAllPriorities() -> [String: Int] {
        let request: NSFetchRequest<UserPriority> = UserPriority.fetchRequest()
        
        do {
            let priorities = try coreDataManager.context.fetch(request)
            var result: [String: Int] = [:]
            
            for priority in priorities {
                if let bandName = priority.band?.bandName {
                    result[bandName] = Int(priority.priorityLevel)
                }
            }
            
            print("📊 Loaded \(result.count) priorities from database")
            return result
        } catch {
            print("❌ Error fetching priorities: \(error)")
            return [:]
        }
    }
    
    /// Gets bands filtered by priority
    /// - Parameter priorities: Array of priority values to include
    /// - Returns: Array of band names matching the priorities
    func getBandsWithPriorities(_ priorities: [Int]) -> [String] {
        let request: NSFetchRequest<UserPriority> = UserPriority.fetchRequest()
        let priorityPredicates = priorities.map { NSPredicate(format: "priorityLevel == %d", $0) }
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: priorityPredicates)
        
        do {
            let userPriorities = try coreDataManager.context.fetch(request)
            return userPriorities.compactMap { $0.band?.bandName }
        } catch {
            print("❌ Error fetching bands with priorities \(priorities): \(error)")
            return []
        }
    }
    
    // MARK: - Migration Support
    
    /// Migrates existing priority data from the old system to Core Data
    /// - Parameter oldPriorityData: Dictionary from the old dataHandler.readFile()
    func migrateExistingPriorities(from oldPriorityData: [String: Int], timestamps: [String: Double] = [:]) {
        print("🔄 Starting priority migration for \(oldPriorityData.count) bands...")
        
        var migratedCount = 0
        var skippedCount = 0
        
        for (bandName, priority) in oldPriorityData {
            // Skip if priority already exists in database
            if getPriority(for: bandName) != 0 {
                print("⏭️ Skipping \(bandName) - already has priority in database")
                skippedCount += 1
                continue
            }
            
            // Get timestamp if available
            let timestamp = timestamps[bandName] ?? Date().timeIntervalSince1970
            
            // Migrate the priority
            setPriority(for: bandName, priority: priority, timestamp: timestamp)
            migratedCount += 1
            
            print("✅ Migrated \(bandName): priority \(priority)")
        }
        
        print("🎉 Priority migration complete!")
        print("📊 Migrated: \(migratedCount), Skipped: \(skippedCount)")
    }
    
    /// Clears all cached priority data (replaces dataHandler.clearCachedData)
    func clearAllPriorities() {
        let request: NSFetchRequest<NSFetchRequestResult> = UserPriority.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try coreDataManager.context.execute(deleteRequest)
            coreDataManager.saveContext()
            print("🗑️ Cleared all priority data")
        } catch {
            print("❌ Error clearing priorities: \(error)")
        }
    }
    
    // MARK: - iCloud Sync Integration
    
    /// Updates priority from iCloud data (replaces iCloud sync logic)
    /// - Parameters:
    ///   - bandName: Name of the band
    ///   - priority: Priority from iCloud
    ///   - timestamp: Timestamp from iCloud
    ///   - deviceUID: Device UID from iCloud
    func updatePriorityFromiCloud(bandName: String, priority: Int, timestamp: Double, deviceUID: String) {
        print("☁️ Processing iCloud priority update for \(bandName)")
        
        // Get current local data
        let currentPriority = getPriority(for: bandName)
        let localTimestamp = getPriorityLastChange(for: bandName)
        let currentUID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        
        // RULE 1: Never overwrite local data if UID matches current device
        if deviceUID == currentUID {
            print("⏭️ Skipping \(bandName) - UID matches current device")
            return
        }
        
        // RULE 2: Only update if iCloud data is newer
        if localTimestamp > 0 && timestamp <= localTimestamp {
            print("⏭️ Skipping \(bandName) - iCloud data not newer (\(timestamp) <= \(localTimestamp))")
            return
        }
        
        // RULE 3: Be conservative if local data exists but no timestamp
        if currentPriority != 0 && localTimestamp <= 0 {
            print("⏭️ Skipping \(bandName) - local data exists but no timestamp")
            return
        }
        
        // Update from iCloud
        print("☁️ Updating \(bandName): \(currentPriority) -> \(priority) (timestamp: \(timestamp))")
        setPriority(for: bandName, priority: priority, timestamp: timestamp)
    }
    
    // MARK: - Private Helpers
    
    private func getUserPriority(for band: Band) -> UserPriority? {
        let request: NSFetchRequest<UserPriority> = UserPriority.fetchRequest()
        request.predicate = NSPredicate(format: "band == %@", band)
        request.fetchLimit = 1
        
        do {
            return try coreDataManager.context.fetch(request).first
        } catch {
            print("❌ Error fetching user priority: \(error)")
            return nil
        }
    }
    
    private func createUserPriority(for band: Band) -> UserPriority {
        let userPriority = UserPriority(context: coreDataManager.context)
        userPriority.band = band
        userPriority.priorityLevel = 0
        userPriority.createdAt = Date()
        userPriority.updatedAt = Date()
        return userPriority
    }
}

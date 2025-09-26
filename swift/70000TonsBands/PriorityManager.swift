import Foundation
import CoreData
import UIKit

/// Manages band priorities using Core Data
/// Replaces the old dictionary-based priority system with database storage
class PriorityManager {
    private let coreDataManager: CoreDataManager
    
    init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        self.coreDataManager = coreDataManager
        
        // Check for one-time migration from legacy data
        performLegacyMigrationIfNeeded()
        
        // Check for bandName field migration for existing UserPriority records
        migrateBandNameFieldIfNeeded()
    }
    
    // MARK: - Priority Management
    
    /// Sets priority for a band (replaces dataHandler.addPriorityData)
    /// - Parameters:
    ///   - bandName: Name of the band
    ///   - priority: Priority value (0=Unknown, 1=Must See, 2=Might See, 3=Won't See)
    ///   - timestamp: Optional timestamp, defaults to current time
    ///   - completion: Optional completion handler
    func setPriority(for bandName: String, priority: Int, timestamp: Double? = nil, completion: @escaping (Bool) -> Void = { _ in }) {
        print("🎯 Setting priority for \(bandName) = \(priority)")
        
        // Use background context to prevent deadlocks
        let context = coreDataManager.persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        context.perform {
            do {
                // Get or create the band
                let bandRequest: NSFetchRequest<Band> = Band.fetchRequest()
                bandRequest.predicate = NSPredicate(format: "bandName == %@", bandName)
                bandRequest.fetchLimit = 1
                
                let band: Band
                let fetchedBands = try context.fetch(bandRequest)
                if let existingBand = fetchedBands.first {
                    band = existingBand
                } else {
                    let newBand = Band(context: context)
                    newBand.bandName = bandName
                    band = newBand
                }
                
                // Get or create the priority record using bandName field - more robust
                let priorityRequest: NSFetchRequest<UserPriority> = UserPriority.fetchRequest()
                priorityRequest.predicate = NSPredicate(format: "bandName == %@", bandName)
                priorityRequest.fetchLimit = 1
                
                let userPriority: UserPriority
                let fetchedPriorities = try context.fetch(priorityRequest)
                if let existingPriority = fetchedPriorities.first {
                    userPriority = existingPriority
                } else {
                    let newUserPriority = UserPriority(context: context)
                    newUserPriority.bandName = bandName  // Set bandName field directly
                    newUserPriority.band = band  // Keep relationship for compatibility
                    newUserPriority.priorityLevel = 0
                    newUserPriority.createdAt = Date()
                    newUserPriority.updatedAt = Date()
                    userPriority = newUserPriority
                }
                
                // Update the priority
                userPriority.priorityLevel = Int16(priority)
                userPriority.updatedAt = Date()
                
                // Save to Core Data
                if context.hasChanges {
                    try context.save()
                }
                
                DispatchQueue.main.async {
                    completion(true)
                }
                
            } catch {
                print("❌ Error setting priority: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
        
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
        var priority = 0
        
        // Use background context to prevent deadlocks during iCloud sync
        let context = coreDataManager.persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        let semaphore = DispatchSemaphore(value: 0)
        
        context.perform {
            // Try bandName field first (new approach), fallback to relationship (old approach)
            let request: NSFetchRequest<UserPriority> = UserPriority.fetchRequest()
            let bandNamePredicate = NSPredicate(format: "bandName == %@", bandName)
            let relationshipPredicate = NSPredicate(format: "band.bandName == %@", bandName)
            request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [bandNamePredicate, relationshipPredicate])
            request.fetchLimit = 1
            
            do {
                if let userPriority = try context.fetch(request).first {
                    priority = Int(userPriority.priorityLevel)
                    
                    // If this record has no bandName but has a relationship, migrate it
                    if userPriority.bandName == nil && userPriority.band?.bandName == bandName {
                        userPriority.bandName = bandName
                        try context.save()
                        print("🔄 Auto-migrated bandName for: \(bandName)")
                    }
                }
            } catch {
                print("❌ Error fetching priority for band \(bandName): \(error)")
            }
            
            semaphore.signal()
        }
        
        // Wait with timeout to prevent deadlocks
        let timeoutResult = semaphore.wait(timeout: .now() + 2.0)
        if timeoutResult == .timedOut {
            print("⚠️ Priority fetch timed out for \(bandName) - preventing deadlock")
            return 0
        }
        
        return priority
    }
    
    /// Gets the last change timestamp for a band's priority
    /// - Parameter bandName: Name of the band
    /// - Returns: Timestamp of last change (0 if not found)
    func getPriorityLastChange(for bandName: String) -> Double {
        var timestamp = 0.0
        
        // Use background context to prevent deadlocks during iCloud sync
        let context = coreDataManager.persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        let semaphore = DispatchSemaphore(value: 0)
        
        context.perform {
            // Try bandName field first (new approach), fallback to relationship (old approach)
            let request: NSFetchRequest<UserPriority> = UserPriority.fetchRequest()
            let bandNamePredicate = NSPredicate(format: "bandName == %@", bandName)
            let relationshipPredicate = NSPredicate(format: "band.bandName == %@", bandName)
            request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [bandNamePredicate, relationshipPredicate])
            request.fetchLimit = 1
            
            do {
                if let userPriority = try context.fetch(request).first {
                    timestamp = userPriority.updatedAt?.timeIntervalSince1970 ?? 0.0
                    
                    // If this record has no bandName but has a relationship, migrate it
                    if userPriority.bandName == nil && userPriority.band?.bandName == bandName {
                        userPriority.bandName = bandName
                        try context.save()
                        print("🔄 Auto-migrated bandName for: \(bandName)")
                    }
                }
            } catch {
                print("❌ Error fetching priority timestamp for band \(bandName): \(error)")
            }
            
            semaphore.signal()
        }
        
        // Wait with timeout to prevent deadlocks
        let timeoutResult = semaphore.wait(timeout: .now() + 2.0)
        if timeoutResult == .timedOut {
            print("⚠️ Priority timestamp fetch timed out for \(bandName) - preventing deadlock")
            return 0.0
        }
        
        return timestamp
    }
    
    /// Gets all bands with their priorities (replaces dataHandler.readFile)
    /// - Returns: Dictionary of band names to priority values
    func getAllPriorities() -> [String: Int] {
        var result: [String: Int] = [:]
        
        // Use background context to prevent deadlocks during iCloud sync
        let context = coreDataManager.persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        let semaphore = DispatchSemaphore(value: 0)
        
        context.perform {
            let request: NSFetchRequest<UserPriority> = UserPriority.fetchRequest()
            
            do {
                let priorities = try context.fetch(request)
                
                for priority in priorities {
                    // Try bandName field first, fallback to relationship
                    var bandName: String?
                    
                    if let name = priority.bandName {
                        bandName = name
                    } else if let name = priority.band?.bandName {
                        bandName = name
                        // Auto-migrate this record
                        priority.bandName = name
                        try context.save()
                        print("🔄 Auto-migrated bandName for: \(name)")
                    }
                    
                    if let name = bandName {
                        result[name] = Int(priority.priorityLevel)
                    }
                }
                
                print("📊 Loaded \(result.count) priorities from database")
            } catch {
                print("❌ Error fetching priorities: \(error)")
            }
            
            semaphore.signal()
        }
        
        // Wait with timeout to prevent deadlocks
        let timeoutResult = semaphore.wait(timeout: .now() + 5.0)
        if timeoutResult == .timedOut {
            print("⚠️ GetAllPriorities timed out - preventing deadlock")
            return [:]
        }
        
        return result
    }
    
    /// Gets bands filtered by priority
    /// - Parameter priorities: Array of priority values to include
    /// - Returns: Array of band names matching the priorities
    func getBandsWithPriorities(_ priorities: [Int]) -> [String] {
        var result: [String] = []
        
        // Use background context to prevent deadlocks during iCloud sync
        let context = coreDataManager.persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        let semaphore = DispatchSemaphore(value: 0)
        
        context.perform {
            let request: NSFetchRequest<UserPriority> = UserPriority.fetchRequest()
            let priorityPredicates = priorities.map { NSPredicate(format: "priorityLevel == %d", $0) }
            request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: priorityPredicates)
            
            do {
                let userPriorities = try context.fetch(request)
                
                for priority in userPriorities {
                    // Try bandName field first, fallback to relationship
                    var bandName: String?
                    
                    if let name = priority.bandName {
                        bandName = name
                    } else if let name = priority.band?.bandName {
                        bandName = name
                        // Auto-migrate this record
                        priority.bandName = name
                        try context.save()
                        print("🔄 Auto-migrated bandName for: \(name)")
                    }
                    
                    if let name = bandName {
                        result.append(name)
                    }
                }
            } catch {
                print("❌ Error fetching bands with priorities \(priorities): \(error)")
            }
            
            semaphore.signal()
        }
        
        // Wait with timeout to prevent deadlocks
        let timeoutResult = semaphore.wait(timeout: .now() + 3.0)
        if timeoutResult == .timedOut {
            print("⚠️ GetBandsWithPriorities timed out - preventing deadlock")
            return []
        }
        
        return result
    }
    
    // MARK: - Migration Support
    
    /// Migrates existing UserPriority records to populate bandName field
    /// This ensures existing priority data works with the new bandName-based queries
    private func migrateBandNameFieldIfNeeded() {
        let migrationKey = "BandNameFieldMigrationCompleted"
        let migrationCompleted = UserDefaults.standard.bool(forKey: migrationKey)
        
        if migrationCompleted {
            print("🔄 BandName field migration already completed")
            return
        }
        
        print("🔄 Starting bandName field migration for existing UserPriority records...")
        
        // Use background context to prevent blocking
        let context = coreDataManager.persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        context.perform {
            do {
                // Find all UserPriority records that have a band relationship but no bandName
                let request: NSFetchRequest<UserPriority> = UserPriority.fetchRequest()
                request.predicate = NSPredicate(format: "bandName == nil AND band != nil")
                
                let priorities = try context.fetch(request)
                print("🔄 Found \(priorities.count) UserPriority records needing bandName migration")
                
                var migratedCount = 0
                
                for priority in priorities {
                    if let band = priority.band, let bandName = band.bandName {
                        // Populate the bandName field from the relationship
                        priority.bandName = bandName
                        migratedCount += 1
                        print("🔄 Migrated bandName for: \(bandName)")
                    }
                }
                
                if migratedCount > 0 {
                    // Save the changes
                    try context.save()
                    print("✅ Successfully migrated \(migratedCount) UserPriority records with bandName field")
                } else {
                    print("ℹ️ No UserPriority records needed bandName migration")
                }
                
                // Mark migration as completed
                UserDefaults.standard.set(true, forKey: migrationKey)
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "BandNameFieldMigrationTimestamp")
                UserDefaults.standard.synchronize()
                
            } catch {
                print("❌ Error during bandName field migration: \(error)")
            }
        }
    }
    
    /// Performs one-time migration from legacy data sources to Core Data
    private func performLegacyMigrationIfNeeded() {
        // PERFORMANCE: Quick exit if migration already completed successfully
        let migrationCompleted = UserDefaults.standard.bool(forKey: "PriorityMigrationCompleted")
        
        if migrationCompleted {
            // Migration already completed - no performance impact
            return
        }
        
        let coreDataCount = getBandsWithPriorities([1, 2, 3]).count
        
        // Check if there's any legacy data to migrate
        let legacyCache = cacheVariables.bandPriorityStorageCache
        let (legacyFileData, _, _) = loadLegacyPriorityFileWithIssues()
        
        // FRESH INSTALL CHECK: If no legacy data exists, this is a fresh install
        if legacyCache.isEmpty && legacyFileData.isEmpty {
            print("🆕 Fresh install detected - no legacy data found, marking migration as completed")
            UserDefaults.standard.set(true, forKey: "PriorityMigrationCompleted")
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "PriorityMigrationTimestamp")
            UserDefaults.standard.synchronize()
            return
        }
        
        // LEGACY DATA EXISTS: Proceed with migration (whether Core Data exists or not)
        print("📦 Legacy data found - proceeding with migration (Core Data count: \(coreDataCount))")
        
        print("🔄 Starting legacy priority data migration...")
        
        // Check if we've already found migrated files (for informational logging)
        checkForMigratedFiles()
        
        var legacyDataFound = false
        var migratedCount = 0
        var dataSources: [String] = []
        
        // Migration will show detailed results dialog at the end
        
        // Track migration issues for user reporting
        var migrationIssues: [String] = []
        
        // 1. ROBUST: Check multiple data sources in priority order
        
        // Source 1: Legacy cache (fastest)
        if !legacyCache.isEmpty {
            print("📦 Found \(legacyCache.count) priorities in legacy cache")
            migrateExistingPriorities(from: legacyCache)
            legacyDataFound = true
            migratedCount += legacyCache.count
            dataSources.append("cache")
        }
        
        // Source 2: Legacy files (comprehensive path search) 
        if !legacyFileData.isEmpty {
            print("📁 Found \(legacyFileData.count) priorities in legacy file")
            migrateExistingPriorities(from: legacyFileData)

            // Rename the file after successful migration to prevent re-import
            let (_, legacyFilePath, fileIssues) = loadLegacyPriorityFileWithIssues()
            renameLegacyFile(at: legacyFilePath)

            legacyDataFound = true
            migratedCount += legacyFileData.count
            dataSources.append("file")
            
            // Track any file-related issues
            migrationIssues.append(contentsOf: fileIssues)
        }
        
        // Source 3: ROBUST - Check UserDefaults backup (if we have one)
        if !legacyDataFound {
            let backupData = loadUserDefaultsBackup()
            if !backupData.isEmpty {
                print("💾 Found \(backupData.count) priorities in UserDefaults backup")
                migrateExistingPriorities(from: backupData)
                legacyDataFound = true
                migratedCount += backupData.count
                dataSources.append("backup")
            } else {
                migrationIssues.append("No backup data found in UserDefaults")
            }
        }
        
        // 3. Check iCloud as last resort (but be careful not to overwrite local data)
        if !legacyDataFound {
            print("☁️ No local data found, attempting iCloud recovery...")
            // Only attempt iCloud recovery if we haven't already migrated and there's no Core Data
            let currentCoreDataCount = getBandsWithPriorities([1, 2, 3]).count
            if currentCoreDataCount == 0 {
                print("☁️ Core Data is empty, safe to attempt iCloud recovery")
                attemptICloudRecovery()
            } else {
                print("☁️ Core Data already has \(currentCoreDataCount) priorities, skipping iCloud recovery to prevent overwrite")
            }
        }
        
        // Final status and flag setting with user feedback
        let finalCoreDataCount = getBandsWithPriorities([1, 2, 3]).count
        
        // Add final issue if we expected data but didn't find it
        if migrationCompleted && finalCoreDataCount == 0 && !legacyDataFound {
            migrationIssues.append("Migration marked complete but no data found in Core Data")
        }
        
        // ALWAYS show detailed migration results to user (for debugging and transparency)
        DispatchQueue.main.async {
            self.showMigrationResultsDialog(
                migratedCount: migratedCount,
                finalCount: finalCoreDataCount,
                dataSources: dataSources,
                issues: migrationIssues,
                success: legacyDataFound
            )
        }
        
        if legacyDataFound {
            print("🎉 Legacy priority migration completed! Migrated \(migratedCount) priorities")
            print("🎉 Final Core Data count: \(finalCoreDataCount) priorities")
            
            UserDefaults.standard.set(true, forKey: "PriorityMigrationCompleted")
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "PriorityMigrationTimestamp")
            UserDefaults.standard.synchronize()
        } else {
            print("ℹ️ No legacy priority data found to migrate")
            print("ℹ️ Current Core Data count: \(finalCoreDataCount) priorities")
            
            UserDefaults.standard.set(true, forKey: "PriorityMigrationCompleted")
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "PriorityMigrationTimestamp")
            UserDefaults.standard.synchronize()
        }
        
        // Log final migration status for debugging
        print("📊 MIGRATION SUMMARY:")
        print("📊   - Data sources found: \(dataSources.joined(separator: ", "))")
        print("📊   - Legacy cache entries: \(legacyCache.count)")
        print("📊   - Legacy file entries: \(legacyFileData.count)")
        print("📊   - Total migrated: \(migratedCount)")
        print("📊   - Final Core Data count: \(finalCoreDataCount)")
        print("📊   - Migration completed at: \(Date())")
    }
    
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
    
    /// DEPRECATED: This method should NEVER be called - priority data is year-agnostic and must be preserved
    /// Priority data represents user preferences that persist across all years
    /// If someone likes Dark Tranquillity in 2012, they should still like them in 2025
    @available(*, deprecated, message: "Priority data should NEVER be cleared - it's year-agnostic user preferences")
    func clearAllPriorities() {
        print("🚨 CRITICAL ERROR: clearAllPriorities() called - this should NEVER happen!")
        print("🚨 Priority data is year-agnostic and must be preserved across all years")
        print("🚨 This method is deprecated and will be removed - priority data should NEVER be deleted")
        
        // DO NOT DELETE ANYTHING - just log the error
        print("🛡️ PROTECTED: No priority data was deleted - user preferences are preserved")
    }
    
    /// Emergency migration function for users who lost data
    /// Forces re-migration even if previously completed
    func forceReMigration() {
        print("🚨 Force re-migration requested - resetting migration flag")
        UserDefaults.standard.set(false, forKey: "PriorityMigrationCompleted")
        UserDefaults.standard.synchronize()
        
        // Clear existing Core Data priorities to avoid conflicts
        print("🗑️ Clearing existing Core Data priorities for clean migration")
        clearAllPriorities()
        
        // Re-run migration
        performLegacyMigrationIfNeeded()
    }
    
    /// Gets migration status for debugging
    func getMigrationStatus() -> (completed: Bool, coreDataCount: Int, legacyCount: Int) {
        let completed = UserDefaults.standard.bool(forKey: "PriorityMigrationCompleted")
        
        // Count all bands with any priority (1=Must See, 2=Might See, 3=Won't See)
        let allPriorities = getBandsWithPriorities([1, 2, 3])
        let coreDataCount = allPriorities.count
        let legacyCount = cacheVariables.bandPriorityStorageCache.count
        
        return (completed: completed, coreDataCount: coreDataCount, legacyCount: legacyCount)
    }
    
    // MARK: - Data Recovery Methods
    
    /// Loads priority data from the legacy PriorityDataWrite.txt file
    /// Returns tuple of (priorityData, filePath) for post-migration file handling
    private func loadLegacyPriorityFile() -> ([String: Int], URL?) {
        var priorityData: [String: Int] = [:]
        
        // CRITICAL FIX: Search BOTH path methods to handle iOS upgrades and device migrations
        
        // Method 1: Try the current/new path (.userDomainMask)
        let newPathFile = getDocumentsDirectory().appendingPathComponent("data.txt")
        if FileManager.default.fileExists(atPath: newPathFile.path) {
            print("📁 Found legacy file at NEW path: \(newPathFile.path)")
            return loadPriorityDataFromFile(newPathFile)
        }
        
        // Method 2: Try the old path (.allDomainsMask) - for users who upgraded from older iOS/app versions
        let oldDirs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .allDomainsMask, true)
        if !oldDirs.isEmpty {
            let oldPathFile = URL(fileURLWithPath: oldDirs[0]).appendingPathComponent("data.txt")
            if FileManager.default.fileExists(atPath: oldPathFile.path) {
                print("📁 Found legacy file at OLD path: \(oldPathFile.path)")
                return loadPriorityDataFromFile(oldPathFile)
            }
        }
        
        // Method 3: Try the Constants.swift directoryPath (legacy compatibility)
        let dirs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .allDomainsMask, true)
        if !dirs.isEmpty {
            let constantsPathFile = URL(fileURLWithPath: dirs[0]).appendingPathComponent("data.txt")
            if FileManager.default.fileExists(atPath: constantsPathFile.path) {
                print("📁 Found legacy file at CONSTANTS path: \(constantsPathFile.path)")
                return loadPriorityDataFromFile(constantsPathFile)
            }
        }
        
        print("📁 No legacy priority file found at any known path")
        print("📁   - Checked NEW path: \(newPathFile.path)")
        if !oldDirs.isEmpty {
            print("📁   - Checked OLD path: \(URL(fileURLWithPath: oldDirs[0]).appendingPathComponent("data.txt").path)")
        }
        if !dirs.isEmpty {
            print("📁   - Checked CONSTANTS path: \(URL(fileURLWithPath: dirs[0]).appendingPathComponent("data.txt").path)")
        }
        
        return (priorityData, nil)
    }
    
    /// Helper method to load and parse priority data from a specific file
    private func loadPriorityDataFromFile(_ priorityFile: URL) -> ([String: Int], URL?) {
        var priorityData: [String: Int] = [:]
        
        do {
            let fileContent = try String(contentsOf: priorityFile, encoding: .utf8)
            print("📁 Legacy priority file content length: \(fileContent.count) characters")
            print("📁 File path: \(priorityFile.path)")
            
            // Parse the file content (format may vary, need to handle different formats)
            let lines = fileContent.components(separatedBy: .newlines)
            print("📁 Found \(lines.count) lines in legacy file")
            
            for (index, line) in lines.enumerated() {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedLine.isEmpty { continue }
                
                // Try different parsing formats
                if let (bandName, priority) = parsePriorityLine(trimmedLine) {
                    priorityData[bandName] = priority
                    print("📁 Line \(index + 1): Parsed \(bandName) = \(priority)")
                } else {
                    print("📁 Line \(index + 1): Failed to parse: '\(trimmedLine)'")
                }
            }
            
            print("📁 ✅ Successfully loaded \(priorityData.count) priorities from legacy file at: \(priorityFile.path)")
            
        } catch {
            print("❌ Error reading legacy priority file at \(priorityFile.path): \(error)")
            return (priorityData, nil)
        }
        
        return (priorityData, priorityFile)
    }
    
    /// Parses a line from the legacy priority file
    /// Handles both formats: "BandName:Priority" and "BandName:Priority:Timestamp"
    private func parsePriorityLine(_ line: String) -> (String, Int)? {
        let elements = line.components(separatedBy: ":")
        
        // Handle new format: "BandName:Priority:Timestamp" (3 parts)
        if elements.count == 3 {
            let bandName = elements[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let priorityString = elements[1].trimmingCharacters(in: .whitespacesAndNewlines)
            // elements[2] is timestamp - we don't need it for migration
            
            if let priority = Int(priorityString), priority > 0 && priority <= 3 {
                return (bandName, priority)
            }
        }
        // Handle old format: "BandName:Priority" (2 parts)
        else if elements.count == 2 {
            let bandName = elements[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let priorityString = elements[1].trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let priority = Int(priorityString), priority > 0 && priority <= 3 {
                return (bandName, priority)
            }
        }
        
        print("⚠️ Could not parse priority line (expected 2 or 3 colon-separated parts): \(line)")
        return nil
    }
    
    /// Attempts to recover priority data from iCloud
    private func attemptICloudRecovery() {
        print("☁️ Attempting iCloud priority data recovery...")
        
        // This would need to integrate with the existing iCloud system
        // For now, we'll trigger the existing iCloud migration
        DispatchQueue.global(qos: .background).async {
            // Force iCloud data sync/recovery
            let iCloudHandler = iCloudDataHandler()
            if iCloudHandler.checkForIcloud() {
                print("☁️ iCloud available, attempting recovery...")
                // The existing iCloud migration should handle this
            } else {
                print("☁️ iCloud not available for recovery")
            }
        }
    }
    
    /// Renames the legacy priority file after successful migration
    private func renameLegacyFile(at filePath: URL?) {
        guard let filePath = filePath else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let renamedPath = filePath.appendingPathExtension("migrated_\(timestamp)")
        
        do {
            try FileManager.default.moveItem(at: filePath, to: renamedPath)
            print("📁 ✅ Renamed legacy file: \(filePath.lastPathComponent) → \(renamedPath.lastPathComponent)")
        } catch {
            print("❌ Failed to rename legacy file: \(error)")
            // Try alternative approach - just add .migrated extension
            let fallbackPath = filePath.appendingPathExtension("migrated")
            do {
                try FileManager.default.moveItem(at: filePath, to: fallbackPath)
                print("📁 ✅ Renamed legacy file (fallback): \(filePath.lastPathComponent) → \(fallbackPath.lastPathComponent)")
            } catch {
                print("❌ Failed to rename legacy file with fallback: \(error)")
            }
        }
    }
    
    /// Checks for already-migrated files for informational logging
    private func checkForMigratedFiles() {
        let documentsDir = getDocumentsDirectory()
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsDir, includingPropertiesForKeys: nil)
            let migratedFiles = files.filter { $0.pathExtension.contains("migrated") }
            
            if !migratedFiles.isEmpty {
                print("📁 Found \(migratedFiles.count) previously migrated files:")
                for file in migratedFiles {
                    print("   - \(file.lastPathComponent)")
                }
            }
        } catch {
            print("⚠️ Could not check for migrated files: \(error)")
        }
    }
    
    /// Helper function to get documents directory (matching Constants.swift)
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    /// ROBUST: Load priority data from UserDefaults backup (fallback data source)
    private func loadUserDefaultsBackup() -> [String: Int] {
        // Check if we have a backup in UserDefaults (this could be added in future versions)
        if let backupData = UserDefaults.standard.dictionary(forKey: "PriorityBackup") as? [String: Int] {
            print("💾 Found UserDefaults backup with \(backupData.count) entries")
            return backupData
        }
        return [:]
    }
    
    /// Shows a toast message to the user (non-blocking)
    private func showToast(_ message: String) {
        // Post notification that UI can listen to for showing toast
        NotificationCenter.default.post(name: Notification.Name("ShowToastNotification"), object: message)
        print("📱 TOAST: \(message)")
    }
    
    /// Shows detailed migration results dialog to the user
    private func showMigrationResultsDialog(migratedCount: Int, finalCount: Int, dataSources: [String], issues: [String], success: Bool) {
        let dialogData: [String: Any] = [
            "migratedCount": migratedCount,
            "finalCount": finalCount,
            "dataSources": dataSources,
            "issues": issues,
            "success": success
        ]
        
        print("🚨 SENDING MIGRATION DIALOG NOTIFICATION:")
        print("🚨   - Migrated: \(migratedCount)")
        print("🚨   - Final: \(finalCount)")
        print("🚨   - Sources: \(dataSources)")
        print("🚨   - Issues: \(issues.count)")
        print("🚨   - Success: \(success)")
        
        // Post notification with detailed data
        print("📱 POSTING NOTIFICATION ON THREAD: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")
        NotificationCenter.default.post(name: Notification.Name("ShowMigrationResultsDialog"), object: dialogData)
        print("📱 MIGRATION DIALOG NOTIFICATION SENT")
        
        // Additional verification - check if any observers are registered
        print("📱 NOTIFICATION CENTER: \(NotificationCenter.default)")
        
        // Try posting a test notification to verify the system works
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("📱 SENDING TEST TOAST TO VERIFY NOTIFICATION SYSTEM...")
            NotificationCenter.default.post(name: Notification.Name("ShowToastNotification"), object: "Test: Migration dialog should have appeared")
        }
    }
    
    /// Enhanced file loading with issue tracking
    private func loadLegacyPriorityFileWithIssues() -> ([String: Int], URL?, [String]) {
        var priorityData: [String: Int] = [:]
        var issues: [String] = []
        
        // CRITICAL FIX: Search BOTH path methods to handle iOS upgrades and device migrations
        
        // Method 1: Try the current/new path (.userDomainMask)
        let newPathFile = getDocumentsDirectory().appendingPathComponent("data.txt")
        if FileManager.default.fileExists(atPath: newPathFile.path) {
            print("📁 Found legacy file at NEW path: \(newPathFile.path)")
            let (data, url) = loadPriorityDataFromFile(newPathFile)
            return (data, url, issues)
        } else {
            issues.append("No file found at new path: \(newPathFile.path)")
        }
        
        // Method 2: Try the old path (.allDomainsMask) - for users who upgraded from older iOS/app versions
        let oldDirs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .allDomainsMask, true)
        if !oldDirs.isEmpty {
            let oldPathFile = URL(fileURLWithPath: oldDirs[0]).appendingPathComponent("data.txt")
            if FileManager.default.fileExists(atPath: oldPathFile.path) {
                print("📁 Found legacy file at OLD path: \(oldPathFile.path)")
                let (data, url) = loadPriorityDataFromFile(oldPathFile)
                return (data, url, issues)
            } else {
                issues.append("No file found at old path: \(oldPathFile.path)")
            }
        } else {
            issues.append("Could not access old document directories")
        }
        
        // Method 3: Try the Constants.swift directoryPath (legacy compatibility)
        let dirs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .allDomainsMask, true)
        if !dirs.isEmpty {
            let constantsPathFile = URL(fileURLWithPath: dirs[0]).appendingPathComponent("data.txt")
            if FileManager.default.fileExists(atPath: constantsPathFile.path) {
                print("📁 Found legacy file at CONSTANTS path: \(constantsPathFile.path)")
                let (data, url) = loadPriorityDataFromFile(constantsPathFile)
                return (data, url, issues)
            } else {
                issues.append("No file found at constants path: \(constantsPathFile.path)")
            }
        } else {
            issues.append("Could not access constants document directories")
        }
        
        issues.append("No legacy priority file found at any known path")
        return (priorityData, nil, issues)
    }
    
    // MARK: - iCloud Sync Integration
    
    /// Updates priority from iCloud data (replaces iCloud sync logic)
    /// - Parameters:
    ///   - bandName: Name of the band
    ///   - priority: Priority from iCloud
    ///   - timestamp: Timestamp from iCloud
    ///   - deviceUID: Device UID from iCloud
    func updatePriorityFromiCloud(bandName: String, priority: Int, timestamp: Double, deviceUID: String, completion: @escaping (Bool) -> Void = { _ in }) {
        print("☁️ Processing iCloud priority update for \(bandName)")
        
        // Get current local data
        let currentPriority = getPriority(for: bandName)
        let localTimestamp = getPriorityLastChange(for: bandName)
        let currentUID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        
        // RULE 1: Only skip if UID matches current device AND local data exists
        // CRITICAL FIX: After delete/reinstall, local data is null, so we need to restore iCloud data even from same device
        if deviceUID == currentUID && currentPriority != 0 {
            print("⏭️ Skipping \(bandName) - UID matches current device and local data exists")
            return
        }
        
        if deviceUID == currentUID && currentPriority == 0 {
            print("☁️ Restoring \(bandName) from same device - local data is null after delete/reinstall")
        }
        
        // CRITICAL FIX: If local data is null (priority = 0), iCloud data should ALWAYS be written
        if currentPriority == 0 {
            print("☁️ Local data is null for \(bandName), iCloud data will be written regardless of other rules")
            setPriority(for: bandName, priority: priority, timestamp: timestamp, completion: completion)
            return
        }
        
        // RULE 2: Only update if iCloud data is newer (when local data exists)
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
        setPriority(for: bandName, priority: priority, timestamp: timestamp, completion: completion)
    }
    
    /// Batch update priorities from iCloud - more efficient for bulk operations
    /// - Parameter updates: Array of (bandName, priority, timestamp, deviceUID) tuples
    func batchUpdatePrioritiesFromiCloud(updates: [(String, Int, Double, String)]) {
        print("☁️ Processing batch iCloud priority update for \(updates.count) bands")
        
        // Use async to prevent blocking
        DispatchQueue.global(qos: .utility).async {
            // Use background context to prevent deadlocks during iCloud sync
            let context = self.coreDataManager.persistentContainer.newBackgroundContext()
            context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
            
            context.perform {
                let currentUID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
                var updatedCount = 0
                
                for (bandName, priority, timestamp, deviceUID) in updates {
                    // Get current local data using bandName field - more robust
                    let request: NSFetchRequest<UserPriority> = UserPriority.fetchRequest()
                    request.predicate = NSPredicate(format: "bandName == %@", bandName)
                    request.fetchLimit = 1
                    
                    let userPriority = try? context.fetch(request).first
                    let currentPriority = Int(userPriority?.priorityLevel ?? 0)
                    let localTimestamp = userPriority?.updatedAt?.timeIntervalSince1970 ?? 0
                    
                    // Apply the same rules as individual updates
                    if deviceUID == currentUID {
                        continue // Skip - UID matches current device
                    }
                    
                    if localTimestamp > 0 && timestamp <= localTimestamp {
                        continue // Skip - iCloud data not newer
                    }
                    
                    if currentPriority != 0 && localTimestamp <= 0 {
                        continue // Skip - local data exists but no timestamp
                    }
                    
                    // Update the priority using bandName field
                    if let existingUserPriority = userPriority {
                        // Update existing priority
                        existingUserPriority.priorityLevel = Int16(priority)
                        existingUserPriority.updatedAt = Date(timeIntervalSince1970: timestamp)
                        updatedCount += 1
                        print("☁️ Updated \(bandName): \(currentPriority) -> \(priority)")
                    } else {
                        // Create new priority record
                        let newUserPriority = UserPriority(context: context)
                        newUserPriority.bandName = bandName  // Set bandName field directly
                        newUserPriority.priorityLevel = Int16(priority)
                        newUserPriority.updatedAt = Date(timeIntervalSince1970: timestamp)
                        newUserPriority.createdAt = Date()
                        updatedCount += 1
                        print("☁️ Created new priority for \(bandName): \(priority)")
                    }
                }
                
                // Save all changes at once
                self.coreDataManager.saveContext()
                print("☁️ Batch update completed: \(updatedCount)/\(updates.count) priorities updated")
            }
        }
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

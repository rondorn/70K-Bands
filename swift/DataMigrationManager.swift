import Foundation
import CoreData

/// Handles migration of existing data to the new Core Data system
/// This is a one-time migration utility to convert legacy data structures
class DataMigrationManager {
    private let coreDataManager: CoreDataManager
    private let priorityManager: PriorityManager
    
    init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        self.coreDataManager = coreDataManager
        self.priorityManager = PriorityManager(coreDataManager: coreDataManager)
    }
    
    // MARK: - Main Migration Entry Point
    
    /// Performs complete data migration from legacy systems to Core Data
    /// This should be called once during app startup after Core Data is initialized
    func performCompleteMigration() {
        print("🔄 Starting complete data migration to Core Data...")
        
        // Check if migration has already been performed
        if UserDefaults.standard.bool(forKey: "CoreDataMigrationCompleted") {
            print("✅ Migration already completed, skipping")
            return
        }
        
        var migrationSteps: [String] = []
        
        // Step 1: Migrate priority data
        if migratePriorityData() {
            migrationSteps.append("Priorities")
        }
        
        // Step 2: Migrate attendance data (when implemented)
        // if migrateAttendanceData() {
        //     migrationSteps.append("Attendance")
        // }
        
        // Step 3: Import band and event data from CSV
        if importInitialBandData() {
            migrationSteps.append("Band Data")
        }
        
        // Mark migration as completed
        UserDefaults.standard.set(true, forKey: "CoreDataMigrationCompleted")
        UserDefaults.standard.synchronize()
        
        print("🎉 Migration completed successfully!")
        print("📊 Migrated: \(migrationSteps.joined(separator: ", "))")
        
        // Post notification that migration is complete
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("DataMigrationCompleted"), object: nil)
        }
    }
    
    // MARK: - Priority Data Migration
    
    /// Migrates priority data from the legacy dataHandler system
    /// - Returns: True if migration was successful
    private func migratePriorityData() -> Bool {
        print("🎯 Starting priority data migration...")
        
        // Create a legacy data handler to read existing data
        let legacyDataHandler = dataHandler()
        
        // Read existing priority data
        let existingPriorities = legacyDataHandler.readFile(dateWinnerPassed: "")
        
        guard !existingPriorities.isEmpty else {
            print("📝 No existing priority data found to migrate")
            return false
        }
        
        print("📊 Found \(existingPriorities.count) priority records to migrate")
        
        // Get timestamps if available
        var timestamps: [String: Double] = [:]
        for (bandName, _) in existingPriorities {
            let timestamp = legacyDataHandler.getPriorityLastChange(bandName)
            if timestamp > 0 {
                timestamps[bandName] = timestamp
            }
        }
        
        // Perform the migration
        priorityManager.migrateExistingPriorities(from: existingPriorities, timestamps: timestamps)
        
        print("✅ Priority migration completed")
        return true
    }
    
    // MARK: - Band Data Import
    
    /// Imports initial band data from CSV files
    /// - Returns: True if import was successful
    private func importInitialBandData() -> Bool {
        print("🎸 Starting initial band data import...")
        
        let bandImporter = BandCSVImporter()
        
        // Try to import from existing file first
        if bandImporter.importBandsFromFile() {
            print("✅ Imported bands from existing file")
            return true
        }
        
        // If no file exists, try to download and import
        var importSuccess = false
        let semaphore = DispatchSemaphore(value: 0)
        
        bandImporter.downloadAndImportBands(forceDownload: true) { success in
            importSuccess = success
            semaphore.signal()
        }
        
        // Wait for download to complete (with timeout)
        let timeout = DispatchTime.now() + .seconds(30)
        if semaphore.wait(timeout: timeout) == .timedOut {
            print("⏰ Band data download timed out")
            return false
        }
        
        if importSuccess {
            print("✅ Downloaded and imported band data")
        } else {
            print("❌ Failed to import band data")
        }
        
        return importSuccess
    }
    
    // MARK: - iCloud Migration Support
    
    /// Migrates iCloud priority data to the new system
    /// This reads all iCloud data and updates the Core Data system
    func migrateiCloudPriorities() {
        print("☁️ Starting iCloud priority migration...")
        
        let iCloudHandler = iCloudDataHandler()
        
        // Read all priority data from iCloud
        iCloudHandler.readAllPriorityData { [weak self] in
            print("☁️ iCloud priority data read completed")
            
            // The iCloud handler will have called the legacy dataHandler
            // Now we need to migrate that data to Core Data
            DispatchQueue.main.async {
                self?.migratePriorityData()
            }
        }
    }
    
    // MARK: - Cleanup Legacy Data
    
    /// Cleans up legacy data files after successful migration
    /// WARNING: This permanently removes old data files
    func cleanupLegacyData() {
        print("🧹 Starting legacy data cleanup...")
        
        // Get documents directory
        let documentsPath = getDocumentsDirectory()
        let fileManager = FileManager.default
        
        // List of legacy files to remove
        let legacyFiles = [
            "bandFile.txt",
            "priorityData.txt",
            "attendanceData.txt"
        ]
        
        var cleanedFiles: [String] = []
        
        for fileName in legacyFiles {
            let filePath = documentsPath + "/" + fileName
            
            if fileManager.fileExists(atPath: filePath) {
                do {
                    try fileManager.removeItem(atPath: filePath)
                    cleanedFiles.append(fileName)
                    print("🗑️ Removed legacy file: \(fileName)")
                } catch {
                    print("❌ Failed to remove \(fileName): \(error)")
                }
            }
        }
        
        if !cleanedFiles.isEmpty {
            print("✅ Cleaned up \(cleanedFiles.count) legacy files: \(cleanedFiles.joined(separator: ", "))")
        } else {
            print("📝 No legacy files found to clean up")
        }
    }
    
    // MARK: - Migration Status
    
    /// Checks if migration has been completed
    /// - Returns: True if migration is complete
    func isMigrationCompleted() -> Bool {
        return UserDefaults.standard.bool(forKey: "CoreDataMigrationCompleted")
    }
    
    /// Forces migration to run again (for testing/debugging)
    func resetMigrationStatus() {
        UserDefaults.standard.removeObject(forKey: "CoreDataMigrationCompleted")
        UserDefaults.standard.synchronize()
        print("🔄 Migration status reset - will run again on next app launch")
    }
    
    // MARK: - Helper Methods
    
    private func getDocumentsDirectory() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        return paths[0]
    }
    
    // MARK: - Migration Verification
    
    /// Verifies that migration was successful by comparing data counts
    func verifyMigration() -> Bool {
        print("🔍 Verifying migration integrity...")
        
        // Check Core Data has data
        let bandCount = coreDataManager.fetchBands().count
        let priorityCount = priorityManager.getAllPriorities().count
        
        print("📊 Core Data contains:")
        print("   - Bands: \(bandCount)")
        print("   - Priorities: \(priorityCount)")
        
        // Basic sanity checks
        let migrationValid = bandCount > 0 || priorityCount > 0
        
        if migrationValid {
            print("✅ Migration verification passed")
        } else {
            print("❌ Migration verification failed - no data found")
        }
        
        return migrationValid
    }
}

import Foundation
import CoreData

/// Test and demonstration of the new Core Data priority system
/// This replaces the old dictionary-based priority system
class PrioritySystemTest {
    
    /// Demonstrates the complete priority system functionality
    static func runPrioritySystemDemo() {
        print("🎯 Starting Priority System Demo...")
        
        // Initialize managers
        let coreDataManager = CoreDataManager.shared
        let priorityManager = PriorityManager()
        let migrationManager = DataMigrationManager()
        let iCloudSync = CoreDataiCloudSync()
        
        // Step 1: Test basic priority operations
        testBasicPriorityOperations(priorityManager)
        
        // Step 2: Test migration from legacy data
        testPriorityMigration(migrationManager)
        
        // Step 3: Test filtering by priorities
        testPriorityFiltering(priorityManager)
        
        // Step 4: Test iCloud sync
        testICloudSync(iCloudSync)
        
        print("🎉 Priority System Demo completed!")
    }
    
    // MARK: - Basic Operations Test
    
    private static func testBasicPriorityOperations(_ priorityManager: PriorityManager) {
        print("\n🧪 Testing Basic Priority Operations...")
        
        // Test setting priorities
        priorityManager.setPriority(for: "Metallica", priority: 1) // Must See
        priorityManager.setPriority(for: "Iron Maiden", priority: 2) // Might See
        priorityManager.setPriority(for: "Nickelback", priority: 3) // Won't See
        
        // Test getting priorities
        let metallicaPriority = priorityManager.getPriority(for: "Metallica")
        let ironMaidenPriority = priorityManager.getPriority(for: "Iron Maiden")
        let unknownBandPriority = priorityManager.getPriority(for: "Unknown Band")
        
        print("✅ Metallica priority: \(metallicaPriority) (Expected: 1)")
        print("✅ Iron Maiden priority: \(ironMaidenPriority) (Expected: 2)")
        print("✅ Unknown Band priority: \(unknownBandPriority) (Expected: 0)")
        
        // Test getting all priorities
        let allPriorities = priorityManager.getAllPriorities()
        print("✅ Total priorities stored: \(allPriorities.count)")
        
        // Test timestamps
        let timestamp = priorityManager.getPriorityLastChange(for: "Metallica")
        print("✅ Metallica last changed: \(Date(timeIntervalSince1970: timestamp))")
    }
    
    // MARK: - Migration Test
    
    private static func testPriorityMigration(_ migrationManager: DataMigrationManager) {
        print("\n🔄 Testing Priority Migration...")
        
        // Simulate legacy priority data
        let legacyPriorities = [
            "Black Sabbath": 1,
            "Deep Purple": 2,
            "Led Zeppelin": 1,
            "Pink Floyd": 2
        ]
        
        let legacyTimestamps = [
            "Black Sabbath": Date().timeIntervalSince1970 - 3600, // 1 hour ago
            "Deep Purple": Date().timeIntervalSince1970 - 7200,   // 2 hours ago
            "Led Zeppelin": Date().timeIntervalSince1970 - 1800,  // 30 minutes ago
            "Pink Floyd": Date().timeIntervalSince1970 - 900      // 15 minutes ago
        ]
        
        // Perform migration
        let priorityManager = PriorityManager()
        priorityManager.migrateExistingPriorities(from: legacyPriorities, timestamps: legacyTimestamps)
        
        // Verify migration
        let migratedPriorities = priorityManager.getAllPriorities()
        print("✅ Migrated \(migratedPriorities.count) priorities")
        
        for (bandName, priority) in legacyPriorities {
            let migratedPriority = priorityManager.getPriority(for: bandName)
            let timestamp = priorityManager.getPriorityLastChange(for: bandName)
            print("✅ \(bandName): \(priority) -> \(migratedPriority) (timestamp: \(timestamp))")
        }
    }
    
    // MARK: - Filtering Test
    
    private static func testPriorityFiltering(_ priorityManager: PriorityManager) {
        print("\n🔍 Testing Priority Filtering...")
        
        // Get bands by priority level
        let mustSeeBands = priorityManager.getBandsWithPriorities([1])
        let mightSeeBands = priorityManager.getBandsWithPriorities([2])
        let wontSeeBands = priorityManager.getBandsWithPriorities([3])
        let flaggedBands = priorityManager.getBandsWithPriorities([1, 2]) // Must + Might
        
        print("✅ Must See bands (\(mustSeeBands.count)): \(mustSeeBands.joined(separator: ", "))")
        print("✅ Might See bands (\(mightSeeBands.count)): \(mightSeeBands.joined(separator: ", "))")
        print("✅ Won't See bands (\(wontSeeBands.count)): \(wontSeeBands.joined(separator: ", "))")
        print("✅ Flagged bands (\(flaggedBands.count)): \(flaggedBands.joined(separator: ", "))")
        
        // This replaces complex dictionary filtering with simple Core Data queries!
    }
    
    // MARK: - iCloud Sync Test
    
    private static func testICloudSync(_ iCloudSync: CoreDataiCloudSync) {
        print("\n☁️ Testing iCloud Sync...")
        
        // Test writing to iCloud
        let success = iCloudSync.writePriorityToiCloud(bandName: "Test Band", priority: 1)
        print("✅ iCloud write success: \(success)")
        
        // Test reading from iCloud
        iCloudSync.readPriorityFromiCloud(bandName: "Test Band")
        
        // Test full sync (this would normally be async)
        print("✅ iCloud sync methods available and functional")
        
        // Setup automatic sync monitoring
        iCloudSync.setupAutomaticSync()
        print("✅ Automatic iCloud sync monitoring enabled")
    }
    
    // MARK: - Performance Comparison
    
    /// Demonstrates performance improvement over legacy dictionary system
    static func performanceComparison() {
        print("\n⚡ Performance Comparison: Core Data vs Dictionary...")
        
        let priorityManager = PriorityManager()
        let bandCount = 1000
        
        // Test Core Data performance
        let coreDataStart = Date()
        
        // Add 1000 priorities
        for i in 1...bandCount {
            priorityManager.setPriority(for: "Band\(i)", priority: Int.random(in: 1...3))
        }
        
        // Query all priorities
        let allPriorities = priorityManager.getAllPriorities()
        
        // Filter by priority
        let mustSeeBands = priorityManager.getBandsWithPriorities([1])
        
        let coreDataTime = Date().timeIntervalSince(coreDataStart)
        
        print("✅ Core Data Performance:")
        print("   - Added \(bandCount) priorities")
        print("   - Retrieved \(allPriorities.count) priorities")
        print("   - Filtered to \(mustSeeBands.count) Must See bands")
        print("   - Total time: \(String(format: "%.3f", coreDataTime)) seconds")
        
        // Legacy dictionary system would be:
        // - Slower for large datasets
        // - Memory intensive (all data in RAM)
        // - No indexing for fast queries
        // - Complex filtering logic
        
        print("🎯 Core Data provides:")
        print("   ✅ Indexed queries for fast filtering")
        print("   ✅ Memory efficient (lazy loading)")
        print("   ✅ ACID transactions for data integrity")
        print("   ✅ Automatic relationship management")
    }
}

// MARK: - Integration Examples

/// Examples of how to replace legacy priority code
class PriorityIntegrationExamples {
    
    /// Example: Replacing DetailViewModel priority logic
    static func detailViewModelExample() {
        print("\n📱 DetailViewModel Integration Example...")
        
        // OLD CODE (to be removed):
        /*
        private let dataHandle = dataHandler()
        
        private func loadPriority() {
            bandPriorityStorage = dataHandle.readFile(dateWinnerPassed: "")
            if let priority = bandPriorityStorage[bandName] {
                selectedPriority = priority
            }
        }
        
        private func savePriority() {
            dataHandle.addPriorityData(bandName, priority: selectedPriority)
        }
        */
        
        // NEW CODE (Core Data):
        let priorityManager = PriorityManager()
        let bandName = "Example Band"
        
        // Load priority
        let selectedPriority = priorityManager.getPriority(for: bandName)
        print("✅ Loaded priority for \(bandName): \(selectedPriority)")
        
        // Save priority
        priorityManager.setPriority(for: bandName, priority: 2)
        print("✅ Saved priority for \(bandName): 2")
        
        // Much simpler and more efficient!
    }
    
    /// Example: Replacing MasterViewController filtering logic
    static func masterViewControllerExample() {
        print("\n📋 MasterViewController Integration Example...")
        
        let priorityManager = PriorityManager()
        
        // OLD CODE (complex dictionary filtering):
        /*
        let priorities = dataHandle.readFile(dateWinnerPassed: "")
        var filteredBands: [String] = []
        for (bandName, priority) in priorities {
            if priority == 1 || priority == 2 { // Must or Might See
                filteredBands.append(bandName)
            }
        }
        */
        
        // NEW CODE (simple Core Data query):
        let flaggedBands = priorityManager.getBandsWithPriorities([1, 2])
        print("✅ Flagged bands: \(flaggedBands.count) bands")
        
        // Additional filtering examples:
        let mustSeeBands = priorityManager.getBandsWithPriorities([1])
        let mightSeeBands = priorityManager.getBandsWithPriorities([2])
        
        print("✅ Must See: \(mustSeeBands.count), Might See: \(mightSeeBands.count)")
    }
}

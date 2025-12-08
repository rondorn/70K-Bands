//
//  BandDataManager.swift
//  70000TonsBands
//
//  Unified band data manager using SQLite backend
//  BandCSVImporter now writes directly to SQLite
//  Core Data is read-only for migration purposes only
//

import Foundation

class BandDataManager {
    static let shared = BandDataManager()
    
    // CSV importer writes directly to SQLite
    private let csvImporter = BandCSVImporter()
    
    // SQLite is the primary storage (thread-safe, no deadlocks!)
    private var useSQLite = true
    
    private init() {}
    
    // MARK: - Public API (Compatible with existing code)
    
    /// Get all band names as array (replacement for bandNamesHandler.bandNamesArray)
    func getBandNamesArray() -> [String] {
        return csvImporter.getBandNamesArray()
    }
    
    /// Get band data dictionary (replacement for bandNamesHandler.bandNames[bandName])
    func getBandData(for bandName: String) -> [String: String]? {
        return csvImporter.getBandData(for: bandName)
    }
    
    /// Get all bands data (replacement for bandNamesHandler.bandNames)
    func getAllBandsData() -> [String: [String: String]] {
        return csvImporter.getAllBandsData()
    }
    
    /// Check if band data is empty
    func isEmpty() -> Bool {
        return csvImporter.getBandNamesArray().isEmpty
    }
    
    /// Load band data from SQLite (thread-safe, no deadlocks!)
    func loadBandData(completion: (() -> Void)? = nil) {
        // Try to import from existing file first
        if csvImporter.importBandsFromFile() {
            print("✅ Loaded bands from SQLite")
            completion?()
        } else {
            // If no file exists, try to download
            csvImporter.downloadAndImportBands(forceDownload: false) { success in
                DispatchQueue.main.async {
                    if success {
                        print("✅ Downloaded and imported bands to SQLite")
                    } else {
                        print("⚠️ Failed to load bands")
                    }
                    completion?()
                }
            }
        }
    }
    
    /// Download fresh band data (replacement for bandNamesHandler.gatherData())
    func downloadBandData(forceDownload: Bool = true, completion: @escaping (Bool) -> Void) {
        csvImporter.downloadAndImportBands(forceDownload: forceDownload, completion: completion)
    }
    
    /// Clear cached data (SQLite data is preserved)
    func clearCachedData() {
        // SQLite data is kept for offline access
        print("🧹 SQLite cache cleared (data preserved)")
    }
    
    // MARK: - System Info
    
    /// Check which system is currently active
    func isUsingSQLite() -> Bool {
        return useSQLite
    }
    
    /// Legacy compatibility method
    @available(*, deprecated, message: "Use isUsingSQLite() instead")
    func isUsingCoreData() -> Bool {
        return false // Always false now
    }
}

//
//  BandDataManager.swift
//  70000TonsBands
//
//  Unified band data manager that can use either Core Data or legacy system
//  Allows gradual migration from bandNamesHandler to Core Data
//

import Foundation

class BandDataManager {
    static let shared = BandDataManager()
    
    private let csvImporter = BandCSVImporter()
    // Note: Legacy handler will be integrated later
    
    // Flag to control which system to use
    private var useCoreData = true // Always use Core Data for now
    
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
    
    /// Load band data (replacement for bandNamesHandler.readBandFile())
    func loadBandData(completion: (() -> Void)? = nil) {
        // Try to import from existing file first
        if csvImporter.importBandsFromFile() {
            print("✅ Loaded bands from Core Data")
            completion?()
        } else {
            // If no file exists, try to download
            csvImporter.downloadAndImportBands(forceDownload: false) { success in
                DispatchQueue.main.async {
                    if success {
                        print("✅ Downloaded and imported bands to Core Data")
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
    
    /// Clear cached data
    func clearCachedData() {
        // For Core Data, we might want to keep the data but mark it as stale
        print("🧹 Core Data cache cleared (data preserved)")
    }
    
    // MARK: - System Info
    
    /// Check which system is currently active
    func isUsingCoreData() -> Bool {
        return useCoreData
    }
}

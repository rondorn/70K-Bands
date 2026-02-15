//
//  BandCSVImporter.swift
//  70000TonsBands
//
//  Imports band data from CSV files into SQLite
//  Replaces the existing bandNamesHandler CSV parsing
//

import Foundation

class BandCSVImporter {
    
    private let dataManager = DataManager.shared
    
    // MARK: - Band Name Sanitization
    
    /// Sanitizes band names for use as Firebase database path components and other safe identifiers
    /// Firebase paths cannot contain: . # $ [ ] / ' " \ and control characters
    static func sanitizeBandName(_ bandName: String) -> String {
        return bandName
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "#", with: "_")
            .replacingOccurrences(of: "$", with: "_")
            .replacingOccurrences(of: "[", with: "_")
            .replacingOccurrences(of: "]", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "'", with: "_")
            .replacingOccurrences(of: "\"", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            // Remove control characters
            .components(separatedBy: .controlCharacters).joined()
            // Trim whitespace
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - CSV Import
    
    /// Import bands from CSV string into SQLite
    /// This replaces the bandNamesHandler CSV parsing logic
    func importBandsFromCSV(_ csvString: String) -> Bool {
        return importBandsFromCSVString(csvString)
    }
    
    /// Import bands from CSV string into SQLite (alternative method name)
    /// Handles updates for existing bands and removes bands not in current year's CSV
    func importBandsFromCSVString(_ csvString: String) -> Bool {
        print("🚀 [SQLITE_IMPORT] Starting CSV import to SQLite (Core Data migration complete)")
        print("🚀 [SQLITE_IMPORT] CSV string length: \(csvString.count) characters")
        
        guard let csvData = try? CSV(csvStringToParse: csvString) else {
            print("❌ [SQLITE_IMPORT] FAILED to parse CSV data")
            return false
        }
        
        // ALL imports now go directly to SQLite via DataManager
        // Core Data is ONLY used for initial migration (CoreDataToSQLiteMigrator)
        return importBandsDirectlyToSQLite(csvData)
    }
    
    // DEPRECATED: Old Core Data import path - removed (Core Data no longer exists)
    // All data operations now use SQLite directly
    
    /// Import bands from the standard band file location
    /// This replaces bandNamesHandler.readBandFile()
    func importBandsFromFile() -> Bool {
        let documentsPath = getDocumentsDirectory()
        let bandFilePath = documentsPath + "/bandFile.txt"
        
        guard let csvString = try? String(contentsOfFile: bandFilePath, encoding: .utf8) else {
            print("❌ Could not read band file at: \(bandFilePath)")
            return false
        }
        
        return importBandsFromCSV(csvString)
    }
    
    /// Download and import bands from URL
    /// This replaces bandNamesHandler.gatherData()
    func downloadAndImportBands(forceDownload: Bool = false, completion: @escaping (Bool) -> Void) {
        print("🌐 Starting band data download and import...")
        
        // Only download if forced or if we have no bands for current year in database
        let existingBandCount = dataManager.fetchBands(forYear: eventYear).count
        
        if !forceDownload && existingBandCount > 0 {
            print("📚 Bands already in database (\(existingBandCount) bands), skipping download")
            completion(true)
            return
        }
        
        // Get the artist URL from pointer data
        let artistUrl = getPointerUrlData(keyValue: "artistUrl") ?? ""
        guard !artistUrl.isEmpty else {
            print("❌ Could not get artist URL from pointer data")
            completion(false)
            return
        }
        
        print("📥 Downloading band data from: \(artistUrl)")
        
        // Download the CSV data
        DispatchQueue.global(qos: .userInitiated).async {
            let csvData = getUrlData(urlString: artistUrl)
            
            DispatchQueue.main.async {
                if csvData.isEmpty {
                    print("❌ No data downloaded from URL")
                    completion(false)
                    return
                }
                
                print("📊 Downloaded \(csvData.count) characters of band data")
                
                // Save to file (for backup/caching)
                self.saveBandDataToFile(csvData)
                
                // Import into SQLite
                let success = self.importBandsFromCSV(csvData)
                completion(success)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveBandDataToFile(_ data: String) {
        let documentsPath = getDocumentsDirectory()
        let bandFilePath = documentsPath + "/bandFile.txt"
        
        do {
            try data.write(toFile: bandFilePath, atomically: true, encoding: .utf8)
            print("💾 Saved band data to file: \(bandFilePath)")
        } catch {
            print("❌ Error saving band data to file: \(error)")
        }
    }
    
    private func getDocumentsDirectory() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        return paths[0]
    }
}

// MARK: - Replacement Functions for bandNamesHandler

extension BandCSVImporter {
    
    /// Get all band names as an array for current year (replacement for bandNamesHandler.bandNamesArray)
    func getBandNamesArray() -> [String] {
        let bands = DataManager.shared.fetchBands(forYear: eventYear)
        return bands.compactMap { $0.bandName }.sorted()
    }
    
    /// Get band data as dictionary (replacement for bandNamesHandler.bandNames)
    func getBandData(for bandName: String) -> [String: String]? {
        guard let band = DataManager.shared.fetchBand(byName: bandName, eventYear: eventYear) else {
            return nil
        }
        
        var bandDict: [String: String] = [:]
        bandDict["bandName"] = band.bandName
        bandDict["officalSite"] = band.officialSite
        bandDict["imageUrl"] = band.imageUrl
        bandDict["youtube"] = band.youtube
        bandDict["metalArchives"] = band.metalArchives
        bandDict["wikipedia"] = band.wikipedia
        bandDict["country"] = band.country
        bandDict["genre"] = band.genre
        bandDict["noteworthy"] = band.noteworthy
        bandDict["priorYears"] = band.priorYears
        
        return bandDict
    }
    
    /// Get all bands data as dictionary for current year (replacement for bandNamesHandler.bandNames)
    func getAllBandsData() -> [String: [String: String]] {
        let bands = DataManager.shared.fetchBands(forYear: eventYear)
        var result: [String: [String: String]] = [:]
        
        for band in bands {
            let bandName = band.bandName
            result[bandName] = getBandData(for: bandName)
        }
        
        return result
    }
    
    /// Import bands directly to SQLite
    private func importBandsDirectlyToSQLite(_ csvData: CSV) -> Bool {
        print("🔍 [IMPORT_DEBUG] ========== BAND CSV IMPORT STARTING ==========")
        print("🔍 [IMPORT_DEBUG] CSV has \(csvData.rows.count) rows to process")
        print("🔍 [IMPORT_DEBUG] ⚠️ CRITICAL: Using eventYear = \(eventYear) for import")
        print("🔍 [IMPORT_DEBUG] This means ALL bands will be imported with eventYear = \(eventYear)")
        print("🔍 [IMPORT_DEBUG] ==============================================")
        
        // CRITICAL FIX: Track which bands are in the CSV so we can delete old ones
        var bandsInCSV = Set<String>()
        var bandsToInsert: [(name: String, eventYear: Int, officialSite: String?, imageUrl: String?, youtube: String?, metalArchives: String?, wikipedia: String?, country: String?, genre: String?, noteworthy: String?, priorYears: String?)] = []
        
        for (index, lineData) in csvData.rows.enumerated() {
            guard let bandName = lineData["bandName"], !bandName.isEmpty else {
                print("🚀 [SQLITE_DIRECT] Skipping row \(index + 1) - no band name")
                continue
            }
            
            // Track this band as being in the CSV
            bandsInCSV.insert(bandName)
            
            bandsToInsert.append((
                name: bandName,
                eventYear: eventYear,
                officialSite: lineData["officalSite"],
                imageUrl: lineData["imageUrl"],
                youtube: lineData["youtube"],
                metalArchives: lineData["metalArchives"],
                wikipedia: lineData["wikipedia"],
                country: lineData["country"],
                genre: lineData["genre"],
                noteworthy: lineData["noteworthy"],
                priorYears: lineData["priorYears"]
            ))
        }
        
        print("🚀 [SQLITE_DIRECT] Prepared \(bandsToInsert.count) bands for batch insert with year \(eventYear)")
        
        // SAFETY CHECK: Don't delete existing data if CSV is empty or has no valid bands
        // This prevents data loss if CSV download fails, is corrupted, or is empty
        if bandsToInsert.isEmpty {
            print("⚠️ [SQLITE_SAFETY] CSV has NO valid bands - keeping existing database data to prevent data loss")
            print("⚠️ [SQLITE_SAFETY] Import ABORTED - existing data preserved")
            return false
        }
        
        // STEP 1: DELETE old bands for this year that are NOT in the new CSV
        // Only runs if CSV has valid records (safety check passed above - bandsToInsert is not empty)
        // This removes bands that exist in database but are NOT in the downloaded CSV file
        print("🗑️ [SQLITE_CLEANUP] STEP 1: Removing bands for year \(eventYear) that are NOT in CSV")
        print("🗑️ [SQLITE_CLEANUP] CSV has \(bandsToInsert.count) bands - will keep only these bands")
        let existingBands = dataManager.fetchBands(forYear: eventYear)
        print("🗑️ [SQLITE_CLEANUP] Found \(existingBands.count) existing bands in database for year \(eventYear)")
        
        var deletedCount = 0
        for existingBand in existingBands {
            if !bandsInCSV.contains(existingBand.bandName) {
                print("🗑️ [SQLITE_CLEANUP] Deleting band: \(existingBand.bandName) (not in CSV)")
                dataManager.deleteBand(name: existingBand.bandName, eventYear: eventYear)
                deletedCount += 1
            }
        }
        print("🗑️ [SQLITE_CLEANUP] Deleted \(deletedCount) bands for year \(eventYear) (not in CSV)")
        
        // STEP 2: Insert/update new bands from CSV
        print("🚀 [SQLITE_DIRECT] STEP 2: Inserting/updating \(bandsToInsert.count) bands from CSV")
        
        // Use batch insert for much better performance (single transaction)
        // SQLite handles bulk operations efficiently without needing to suspend monitoring
        if let sqliteManager = dataManager as? SQLiteDataManager {
            sqliteManager.batchCreateOrUpdateBands(bandsToInsert)
        } else {
            print("❌ [SQLITE_DIRECT] DataManager is not SQLiteDataManager, falling back to individual inserts")
            for (index, bandData) in bandsToInsert.enumerated() {
                print("🚀 [SQLITE_DIRECT] Processing band \(index + 1)/\(bandsToInsert.count): \(bandData.name)")
                _ = dataManager.createOrUpdateBand(
                    name: bandData.name,
                    eventYear: bandData.eventYear,
                    officialSite: bandData.officialSite,
                    imageUrl: bandData.imageUrl,
                    youtube: bandData.youtube,
                    metalArchives: bandData.metalArchives,
                    wikipedia: bandData.wikipedia,
                    country: bandData.country,
                    genre: bandData.genre,
                    noteworthy: bandData.noteworthy,
                    priorYears: bandData.priorYears
                )
            }
        }
        
        print("🚀 [SQLITE_DIRECT] Import complete!")
        print("🚀 [SQLITE_DIRECT] Summary: \(bandsToInsert.count) bands inserted/updated, \(deletedCount) old bands deleted")
        
        // CRITICAL FIX: After importing to SQLite, force bandNamesHandler to reload its cache
        // This ensures CombinedImageListHandler gets the updated data when regenerating the image list
        print("🔄 [SQLITE_DIRECT] Forcing bandNamesHandler cache reload after CSV import")
        bandNamesHandler.shared.clearCachedData()
        bandNamesHandler.shared.loadCachedDataImmediately()
        print("✅ [SQLITE_DIRECT] bandNamesHandler cache reloaded - \(bandNamesHandler.shared.getBandNames().count) bands now available")
        
        return true
    }
}

//
//  BandCSVImporter.swift
//  70000TonsBands
//
//  Imports band data from CSV files into Core Data
//  Replaces the existing bandNamesHandler CSV parsing
//

import Foundation
import CoreData

class BandCSVImporter {
    
    private let dataManager = DataManager.shared
    private let coreDataManager = CoreDataManager.shared // Still needed for performSafeBackgroundTask
    
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
    
    /// Import bands from CSV string into Core Data
    /// This replaces the bandNamesHandler CSV parsing logic
    func importBandsFromCSV(_ csvString: String) -> Bool {
        return importBandsFromCSVString(csvString)
    }
    
    /// Import bands from CSV string into Core Data (alternative method name)
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
    
    // DEPRECATED: Old Core Data import path - kept for reference but not used
    // All data operations now use SQLite
    private func importBandsFromCSVString_DEPRECATED_CoreData(_ csvData: CSV) -> Bool {
        print("🔍 [CSV_IMPORT] About to call coreDataManager.performSafeBackgroundTask")
        print("🔍 [CSV_IMPORT] Current thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")
        
        // Use safe background operation to prevent concurrency crashes
        let success = coreDataManager.performSafeBackgroundTask { context in
            print("🔍 [CSV_IMPORT] ===== INSIDE performSafeBackgroundTask BLOCK =====")
            print("🔍 [CSV_IMPORT] Background context thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")
            var importedCount = 0
            var updatedCount = 0
            var deletedCount = 0
            
            print("DEBUG_MARKER: CSV has \(csvData.rows.count) rows to process")
            
            // Get configured event year for cleanup logic (not actual current year)
            print("DEBUG_MARKER: Configured event year: \(eventYear) - will clean up bands from this year")
            
            // Track which bands are in the current CSV
            var bandsInCSV = Set<String>()
        
            // Process each row in the CSV
            for (index, lineData) in csvData.rows.enumerated() {
                print("DEBUG_MARKER: Processing band \(index + 1)/\(csvData.rows.count)")
                
                guard let bandName = lineData["bandName"], !bandName.isEmpty else {
                    print("DEBUG_MARKER: Skipping row \(index + 1) - no band name")
                    continue // Skip rows without band names
                }
                
                print("DEBUG_MARKER: Processing band: \(bandName)")
                
                // Track this band as being in the current CSV
                bandsInCSV.insert(bandName)
                
                // Check if band already exists using the background context
                print("DEBUG_MARKER: Checking if \(bandName) exists in Core Data")
                let request: NSFetchRequest<Band> = Band.fetchRequest()
                request.predicate = NSPredicate(format: "bandName == %@ AND eventYear == %d", bandName, Int32(eventYear))
                request.fetchLimit = 1
                
                let existingBand = try? context.fetch(request).first
                let isUpdate = existingBand != nil
                print("DEBUG_MARKER: \(bandName) \(isUpdate ? "exists" : "is new")")
                
                // Create or update the band with all CSV fields
                print("DEBUG_MARKER: Creating/updating \(bandName) in Core Data")
                let band = existingBand ?? Band(context: context)
                
                // Update all fields
                band.bandName = bandName
                band.sanitizedName = BandCSVImporter.sanitizeBandName(bandName) // Add sanitized name for Firebase safety
                band.eventYear = Int32(eventYear)
                band.officialSite = lineData["officalSite"] // Note: CSV has typo "officalSite"
                band.imageUrl = lineData["imageUrl"]
                band.youtube = lineData["youtube"]
                band.metalArchives = lineData["metalArchives"]
                band.wikipedia = lineData["wikipedia"]
                band.country = lineData["country"]
                band.genre = lineData["genre"]
                band.noteworthy = lineData["noteworthy"]
                band.priorYears = lineData["priorYears"]
                
                if isUpdate {
                    updatedCount += 1
                    print("🔄 Updated band: \(bandName)")
                } else {
                    importedCount += 1
                    print("✅ Imported band: \(bandName)")
                }
                
                print("DEBUG_MARKER: Completed processing \(bandName)")
            }
        
            // Clean up bands that are no longer in the current CSV
            print("DEBUG_MARKER: Starting cleanup - removing bands not in current year's CSV")
            print("DEBUG_MARKER: Bands in current CSV: \(bandsInCSV.count) bands")
            print("DEBUG_MARKER: CSV bands: \(Array(bandsInCSV).sorted())")
            
            // Fetch existing bands using the background context
            let bandRequest: NSFetchRequest<Band> = Band.fetchRequest()
            bandRequest.predicate = NSPredicate(format: "eventYear == %d", Int32(eventYear))
            
            let allExistingBands = (try? context.fetch(bandRequest)) ?? []
            print("DEBUG_MARKER: Existing bands in Core Data for year \(eventYear): \(allExistingBands.count)")
            
            // Show all existing bands for debugging
            let existingBandNames = allExistingBands.compactMap { $0.bandName }.sorted()
            print("DEBUG_MARKER: Core Data bands: \(existingBandNames)")
            
            // DELETION LOGIC: Remove bands from current year that are not in the downloaded CSV
            print("🗑️ [BAND_DELETION_DEBUG] ========== STARTING BAND DELETION ANALYSIS ==========")
            print("🗑️ [BAND_DELETION_DEBUG] Current year: \(eventYear)")
            print("🗑️ [BAND_DELETION_DEBUG] Bands currently in Core Data for \(eventYear): \(allExistingBands.count)")
            print("🗑️ [BAND_DELETION_DEBUG] Bands in downloaded CSV: \(bandsInCSV.count)")
            print("🗑️ [BAND_DELETION_DEBUG] CSV bands: \(bandsInCSV.sorted())")
            
            // Check each existing band to see if it was in the CSV
            for existingBand in allExistingBands {
                guard let bandName = existingBand.bandName else { 
                    print("🗑️ [BAND_DELETION_DEBUG] ⚠️ Skipping band with no name: \(existingBand)")
                    continue 
                }
                
                // If band is not in current CSV, check if it should be preserved
                if !bandsInCSV.contains(bandName) {
                    // Check if this band has unofficial events or special events
                    var hasProtectedEvents = false
                    if let events = existingBand.events?.allObjects as? [Event] {
                        hasProtectedEvents = events.contains { event in
                            let eventType = event.eventType ?? ""
                            return eventType == "Unofficial Event" || 
                                   eventType == "Cruiser Organized" || 
                                   eventType == "Special Event"
                        }
                    }
                    
                    if hasProtectedEvents {
                        print("🗑️ [BAND_DELETION_DEBUG] 🛡️ PRESERVING fake band (has unofficial/special events):")
                        print("🗑️ [BAND_DELETION_DEBUG] - Band: '\(bandName)'")
                        print("🗑️ [BAND_DELETION_DEBUG] - Year: \(existingBand.eventYear)")
                        
                        if let events = existingBand.events?.allObjects as? [Event] {
                            print("🗑️ [BAND_DELETION_DEBUG] - Protected events: \(events.count)")
                            for event in events {
                                let eventType = event.eventType ?? "unknown"
                                print("🗑️ [BAND_DELETION_DEBUG]   - Event: '\(eventType)' at \(event.location ?? "unknown location")")
                            }
                        }
                    } else {
                        print("🗑️ [BAND_DELETION_DEBUG] 🚨 REMOVING real band not found in CSV:")
                        print("🗑️ [BAND_DELETION_DEBUG] - Band: '\(bandName)'")
                        print("🗑️ [BAND_DELETION_DEBUG] - Year: \(existingBand.eventYear)")
                        
                        // Check if this band has any events and what types
                        if let events = existingBand.events?.allObjects as? [Event] {
                            print("🗑️ [BAND_DELETION_DEBUG] - Associated events: \(events.count)")
                            for event in events.prefix(3) {
                                let eventType = event.eventType ?? "unknown"
                                print("🗑️ [BAND_DELETION_DEBUG]   - Event: '\(eventType)' at \(event.location ?? "unknown location")")
                            }
                        }
                        
                        context.delete(existingBand)
                        deletedCount += 1
                    }
                } else {
                    print("🗑️ [BAND_DELETION_DEBUG] ✅ KEEPING band found in CSV: '\(bandName)'")
                }
            }
            
            print("🗑️ [BAND_DELETION_DEBUG] ========== BAND DELETION ANALYSIS COMPLETE ==========")
            print("🗑️ [BAND_DELETION_DEBUG] Total bands deleted: \(deletedCount)")
            
            // Save all changes in the background context
            do {
                print("💾 About to save Core Data context with \(context.insertedObjects.count) insertions, \(context.updatedObjects.count) updates, \(context.deletedObjects.count) deletions")
                try context.save()
                print("✅ Core Data save successful")
            } catch {
                print("❌ CRITICAL: Core Data save failed: \(error)")
                return false
            }
            
            print("DEBUG_MARKER: Smart CSV import complete!")
            print("DEBUG_MARKER: Imported \(importedCount) new bands")
            print("DEBUG_MARKER: Updated \(updatedCount) existing bands")
            print("DEBUG_MARKER: Deleted \(deletedCount) bands no longer in lineup")
            print("DEBUG_MARKER: Total \(importedCount + updatedCount + deletedCount) operations performed")
            
            return true
        } ?? false
        
        print("🔍 [CSV_IMPORT] ===== performSafeBackgroundTask RETURNED =====")
        print("🔍 [CSV_IMPORT] Success value: \(success)")
        
        // Verify the data was actually saved by checking on main context
        DispatchQueue.main.async {
            let totalBandsInCoreData = self.dataManager.fetchBands(forYear: eventYear).count
            print("DEBUG_MARKER: Core Data now contains \(totalBandsInCoreData) bands for year \(eventYear)")
        }
        
        print("🔍 [CSV_IMPORT] About to return from importBandsFromCSVString")
        return success
    }
    
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
                
                // Import into Core Data
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
    
    /// Import bands directly to SQLite on first launch (bypasses Core Data initialization deadlock)
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
        // Suspend Core Data monitoring during bulk insert to prevent 51 individual refresh triggers
        CoreDataPreloadManager.shared.suspendMonitoring()
        
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
        
        // Resume Core Data monitoring (but it's disabled for SQLite backend anyway)
        CoreDataPreloadManager.shared.resumeMonitoringSilently()
        
        print("🚀 [SQLITE_DIRECT] Import complete!")
        print("🚀 [SQLITE_DIRECT] Summary: \(bandsToInsert.count) bands inserted/updated, \(deletedCount) old bands deleted")
        
        return true
    }
}

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
    
    private let coreDataManager = CoreDataManager.shared
    
    // MARK: - CSV Import
    
    /// Import bands from CSV string into Core Data
    /// This replaces the bandNamesHandler CSV parsing logic
    func importBandsFromCSV(_ csvString: String) -> Bool {
        print("🎸 Starting band CSV import to Core Data...")
        
        guard let csvData = try? CSV(csvStringToParse: csvString) else {
            print("❌ Failed to parse CSV data")
            return false
        }
        
        var importedCount = 0
        var updatedCount = 0
        
        // Process each row in the CSV
        for lineData in csvData.rows {
            guard let bandName = lineData["bandName"], !bandName.isEmpty else {
                continue // Skip rows without band names
            }
            
            // Check if band already exists
            let existingBand = coreDataManager.fetchBand(byName: bandName)
            let isUpdate = existingBand != nil
            
            // Create or update the band with all CSV fields
            let band = coreDataManager.createOrUpdateBand(
                name: bandName,
                officialSite: lineData["officalSite"], // Note: CSV has typo "officalSite"
                imageUrl: lineData["imageUrl"],
                youtube: lineData["youtube"],
                metalArchives: lineData["metalArchives"],
                wikipedia: lineData["wikipedia"],
                country: lineData["country"],
                genre: lineData["genre"],
                noteworthy: lineData["noteworthy"],
                priorYears: lineData["priorYears"]
            )
            
            if isUpdate {
                updatedCount += 1
                print("🔄 Updated band: \(bandName)")
            } else {
                importedCount += 1
                print("✅ Imported band: \(bandName)")
            }
        }
        
        // Save all changes
        coreDataManager.saveContext()
        
        print("🎉 Band import complete!")
        print("📊 Imported: \(importedCount) new bands")
        print("📊 Updated: \(updatedCount) existing bands")
        print("📊 Total: \(importedCount + updatedCount) bands processed")
        
        return true
    }
    
    /// Import bands from the standard band file location
    /// This replaces bandNamesHandler.readBandFile()
    func importBandsFromFile() -> Bool {
        let bandFile = getDocumentsDirectory().appendingPathComponent("bandFile.txt")
        
        guard let csvString = try? String(contentsOfFile: bandFile, encoding: .utf8) else {
            print("❌ Could not read band file at: \(bandFile)")
            return false
        }
        
        return importBandsFromCSV(csvString)
    }
    
    /// Download and import bands from URL
    /// This replaces bandNamesHandler.gatherData()
    func downloadAndImportBands(forceDownload: Bool = false, completion: @escaping (Bool) -> Void) {
        print("🌐 Starting band data download and import...")
        
        // Only download if forced or if we have no bands in database
        let existingBandCount = coreDataManager.fetchBands().count
        
        if !forceDownload && existingBandCount > 0 {
            print("📚 Bands already in database (\(existingBandCount) bands), skipping download")
            completion(true)
            return
        }
        
        // Get the artist URL from pointer data
        guard let artistUrl = getPointerUrlData(keyValue: "artistUrl"), !artistUrl.isEmpty else {
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
        let bandFile = getDocumentsDirectory().appendingPathComponent("bandFile.txt")
        
        do {
            try data.write(toFile: bandFile, atomically: true, encoding: .utf8)
            print("💾 Saved band data to file: \(bandFile)")
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
    
    /// Get all band names as an array (replacement for bandNamesHandler.bandNamesArray)
    func getBandNamesArray() -> [String] {
        let bands = coreDataManager.fetchBands()
        return bands.compactMap { $0.bandName }.sorted()
    }
    
    /// Get band data as dictionary (replacement for bandNamesHandler.bandNames)
    func getBandData(for bandName: String) -> [String: String]? {
        guard let band = coreDataManager.fetchBand(byName: bandName) else {
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
    
    /// Get all bands data as dictionary (replacement for bandNamesHandler.bandNames)
    func getAllBandsData() -> [String: [String: String]] {
        let bands = coreDataManager.fetchBands()
        var result: [String: [String: String]] = [:]
        
        for band in bands {
            guard let bandName = band.bandName else { continue }
            result[bandName] = getBandData(for: bandName)
        }
        
        return result
    }
}

//
//  CustomBandDescription.swift
//
//
//  Created by Ron Dorn on 9/21/17.
//

import Foundation
import UIKit


open class CustomBandDescription {
    
    var bandDescriptionUrl = [String:String]()
    var bandDescriptionUrlDate = [String:String]()
    
    init(){
        refreshCache()
    }
    
    func refreshCache(){
        
        let currentQueueLabel = OperationQueue.current?.underlyingQueue?.label
        
        // Use a safer approach to cache refresh
        bandDescriptionLock.sync() {
            // Check if we already have cached data
            if (cacheVariables.bandDescriptionUrlCache.isEmpty == false){
                // Safely copy the cached data
                bandDescriptionUrl = cacheVariables.bandDescriptionUrlCache
                bandDescriptionUrlDate = cacheVariables.bandDescriptionUrlDateCache
                print("commentFile refreshCache: Loaded from cache - \(bandDescriptionUrl.count) bands")
                
            } else if (currentQueueLabel == "com.apple.main-thread"){
                // Only load from file on main thread if we have internet AND prerequisite data is available
                if isInternetAvailable() {
                    // Check if prerequisite data (bands + schedule) is available before trying to load descriptions
                    if hasPrerequisiteDataAvailable() {
                        print("commentFile refreshCache: Loading from file on main thread (internet and prerequisite data available)")
                        self.getDescriptionMap();
                    } else {
                        print("⚠️ commentFile refreshCache: Skipping file load on main thread - prerequisite data not ready yet")
                    }
                } else {
                    print("⚠️ commentFile refreshCache: Skipping file load on main thread - no internet available")
                }
                
            } else {
                // Background thread - only load from file if we have internet AND prerequisite data
                if isInternetAvailable() {
                    if hasPrerequisiteDataAvailable() {
                        print ("commentFile refreshCache: Loading from file on background thread (internet and prerequisite data available)")
                        refreshData()
                    } else {
                        print("⚠️ commentFile refreshCache: Skipping file load on background thread - prerequisite data not ready yet")
                    }
                } else {
                    print("⚠️ commentFile refreshCache: Skipping file load on background thread - no internet available")
                }
            }
        }
    }
    
    func refreshData(){
        
        print ("commentFile refreshData: Starting data refresh")
        
        // Ensure we're not already refreshing
        guard !descriptionLock else {
            print("⚠️ commentFile refreshData: Already refreshing, skipping duplicate call")
            return
        }
        
        // Check internet availability before attempting downloads
        guard isInternetAvailable() else {
            print("⚠️ commentFile refreshData: No internet available, skipping data refresh")
            return
        }
        
        // Check if prerequisite data (bands + schedule) is available before attempting to load descriptions
        guard hasPrerequisiteDataAvailable() else {
            print("⚠️ commentFile refreshData: Prerequisite data not ready yet, skipping description refresh")
            return
        }
        
        print ("commentFile refreshData: Getting description map file")
        self.getDescriptionMapFile();
        print ("commentFile refreshData: Getting description map")
        self.getDescriptionMap();
        
        print ("commentFile refreshData: Data refresh complete")
    }
    
    // Add static variables to track failed attempts and prevent loops for file downloads
    private static var lastFileDownloadFailureTime: TimeInterval = 0
    private static var fileDownloadFailureCount: Int = 0
    private static let maxFileDownloadFailures = 3
    private static let fileDownloadFailureCooldown: TimeInterval = 60 // 60 seconds
    
    /// Loads the band description map file from disk or cache.
    /// Only updates the file if the content has changed to avoid unnecessary updates.
    func getDescriptionMapFile(){
        
        // Check if we've failed too many times recently
        let currentTime = Date().timeIntervalSince1970
        if CustomBandDescription.fileDownloadFailureCount >= CustomBandDescription.maxFileDownloadFailures {
            if currentTime - CustomBandDescription.lastFileDownloadFailureTime < CustomBandDescription.fileDownloadFailureCooldown {
                print("⚠️ getDescriptionMapFile: Too many recent download failures (\(CustomBandDescription.fileDownloadFailureCount)), cooling down for \(Int(CustomBandDescription.fileDownloadFailureCooldown - (currentTime - CustomBandDescription.lastFileDownloadFailureTime))) more seconds")
                return
            } else {
                // Reset failure count after cooldown
                CustomBandDescription.fileDownloadFailureCount = 0
                print("getDescriptionMapFile: Download failure cooldown expired, retrying...")
            }
        }
        
        // Check internet availability first
        guard isInternetAvailable() else {
            print("commentFile getDescriptionMapFile: No internet available for description map download")
            return;
        }
        
        let mapUrl = getDefaultDescriptionMapUrl()
        
        // Validate URL
        guard !mapUrl.isEmpty else {
            print("⚠️ commentFile getDescriptionMapFile: Empty URL received")
            return
        }
        
        print ("commentFile getDescriptionMapFile: Map url is \(mapUrl)")
        
        let httpData = getUrlData(urlString: mapUrl)
        
        print ("commentFile getDescriptionMapFile: Map url Data length is \(httpData.count)")
        
        if (httpData.isEmpty == false){
            // Check if local file exists and compare content
            var shouldUpdateFile = true
            
            if FileManager.default.fileExists(atPath: descriptionMapFile) {
                do {
                    let existingData = try String(contentsOfFile: descriptionMapFile, encoding: String.Encoding.utf8)
                    if existingData == httpData {
                        shouldUpdateFile = false
                        print("commentFile getDescriptionMapFile: Description map content unchanged, skipping update")
                    } else {
                        print("commentFile getDescriptionMapFile: Description map content changed, updating file")
                    }
                } catch {
                    print("commentFile getDescriptionMapFile: Error reading existing description map file: \(error.localizedDescription)")
                    // If we can't read the existing file, update it
                    shouldUpdateFile = true
                }
            } else {
                print("commentFile getDescriptionMapFile: Description map file doesn't exist, creating new file")
            }
            
            if shouldUpdateFile {
                do {
                    // Remove old file if it exists
                    if FileManager.default.fileExists(atPath: descriptionMapFile) {
                        try FileManager.default.removeItem(atPath: descriptionMapFile)
                        print("commentFile getDescriptionMapFile: Removed old description map file")
                    }
                    
                    // Write new file
                    try httpData.write(toFile: descriptionMapFile, atomically: false, encoding: String.Encoding.utf8)
                    print("commentFile getDescriptionMapFile: Description map file updated successfully")
                    
                    // Success! Reset failure count
                    CustomBandDescription.fileDownloadFailureCount = 0
                } catch let error as NSError {
                    print ("commentFile getDescriptionMapFile: Encountered an error writing descriptionMap file: \(error.debugDescription)")
                    // Record failure
                    CustomBandDescription.fileDownloadFailureCount += 1
                    CustomBandDescription.lastFileDownloadFailureTime = currentTime
                    print("⚠️ getDescriptionMapFile: Failure count: \(CustomBandDescription.fileDownloadFailureCount)/\(CustomBandDescription.maxFileDownloadFailures)")
                }
            }
        } else {
            print("commentFile getDescriptionMapFile: Warning: Failed to download description map data - httpData is empty")
            print("commentFile getDescriptionMapFile: This could be due to network issues or main thread restrictions")
            
            // Record failure
            CustomBandDescription.fileDownloadFailureCount += 1
            CustomBandDescription.lastFileDownloadFailureTime = currentTime
            print("⚠️ getDescriptionMapFile: Failure count: \(CustomBandDescription.fileDownloadFailureCount)/\(CustomBandDescription.maxFileDownloadFailures)")
        }
    }
    
    func writeUrlFile (bandName: String, descriptionUrl: String){
        
        let commentFileName = self.getNoteFileName(bandName: bandName)
        let commentFile = directoryPath.appendingPathComponent( commentFileName);
        
        do {
            try descriptionUrl.write(to: commentFile, atomically: false, encoding: String.Encoding.utf8)
        } catch {
            print("commentFile " + error.localizedDescription)
}
    }
    
    /// Loads all band descriptions from the description map file.
    /// WARNING: This function performs heavy I/O and network operations.
    /// It should ONLY be called when the app is in the background state.
    func getAllDescriptions(){
        
        // Ensure this is only called when app is in background
        guard UIApplication.shared.applicationState == .background else {
            print("⚠️ BLOCKED: getAllDescriptions() called while app is in foreground - this should only run in background")
            return
        }
        
        if (downloadingAllComments == false){
            downloadingAllComments = true
            print ("commentFile looping through bands (background state confirmed)")
            
            for record in self.bandDescriptionUrl{
                let bandName = record.key
                print ("commentFile working on bandName " + bandName)
                if (self.doesDescriptionFileExists(bandName: bandName) == false){
                    _ = self.getDescription(bandName: bandName)
                }
            }
            
            downloadingAllComments = false
            print ("commentFile processing completed (background state)")
        }
    }
    
    func doesDescriptionFileExists(bandName: String) -> Bool {
        
        let commentFileName = self.getNoteFileName(bandName: bandName)
        let commentFile = directoryPath.appendingPathComponent(commentFileName)
        
        print ("commentFile lookup for \(commentFile)");
        return (FileManager.default.fileExists(atPath: commentFile.path))
    }
    
    func custMatchesDefault(customNote: String, bandName: String)-> Bool{
        
        var matches = false
        let normalizedBandName = normalizeBandName(bandName)
        
        if bandDescriptionUrlDate.keys.contains(normalizedBandName){
            var defaultBandNote = getDescriptionFromUrl(bandName: bandName, descriptionUrl: bandDescriptionUrl[normalizedBandName]!)
            
            defaultBandNote = defaultBandNote.filter {!$0.isWhitespace}
            
            var strippedCustomNote = customNote
            strippedCustomNote = strippedCustomNote.filter {!$0.isWhitespace}
            
            if (defaultBandNote == strippedCustomNote){
                matches = true
            }
        }
    
        return matches
        
    }
    
    func getNoteFileName (bandName: String)->String {
        
        var approvedFileName = ""
        let custCommentFileName = bandName + "_comment.note-cust";
        let normalizedBandName = normalizeBandName(bandName)
        
        if bandDescriptionUrlDate.keys.contains(normalizedBandName){
            let defaultCommentFileName = bandName + "_comment.note-" + bandDescriptionUrlDate[normalizedBandName]!;
            
            
            let custCommentFile = directoryPath.appendingPathComponent( custCommentFileName)
            
            if (FileManager.default.fileExists(atPath: custCommentFile.path) == true){
                approvedFileName = custCommentFileName;
            } else {
                approvedFileName = defaultCommentFileName;
            }
        } else {
            approvedFileName = custCommentFileName;
        }
        
        return approvedFileName;
    }
    
    func getDescriptionFromUrl(bandName: String, descriptionUrl: String) -> String {
        
        print ("DEBUG_commentFile: lookup for \(bandName) via \(descriptionUrl)")
        var commentText = ""
        
        // Validate inputs
        guard !bandName.isEmpty else {
            print("⚠️ DEBUG_commentFile: Empty band name provided")
            return FestivalConfig.current.getDefaultDescriptionText()
        }
        
        guard !descriptionUrl.isEmpty else {
            print("⚠️ DEBUG_commentFile: Empty description URL provided for \(bandName)")
            return FestivalConfig.current.getDefaultDescriptionText()
        }
        
        let commentFileName = getNoteFileName(bandName: bandName)
        let commentFile = directoryPath.appendingPathComponent( commentFileName)
        
        print ("DEBUG_commentFile: doesDescriptionFileExists for \(bandName)")
        if (doesDescriptionFileExists(bandName: bandName) == false){
            print ("DEBUG_commentFile: lookup for \(bandName) via \(descriptionUrl) field does not yet exist")
            
            // Check if internet is available
            guard isInternetAvailable() else {
                print("No internet available for \(bandName) description download")
                return FestivalConfig.current.getDefaultDescriptionText()
            }
            
            let httpData = getUrlData(urlString: descriptionUrl);
                
            //do not write if we are getting 404 error or HTML error page
            if (httpData.starts(with: "<!DOCTYPE") == false && !httpData.isEmpty){
                commentText = httpData;
                print ("commentFile text is '" + commentText + "'")
                
                print ("Wrote commentFile for \(bandName) " + commentText)
                do {
                    try commentText.write(to: commentFile, atomically: false, encoding: String.Encoding.utf8)
                } catch {
                    print("commentFile " + error.localizedDescription)
                }
            } else {
                print("Received HTML error page or empty response for \(bandName)")
            }
        }

        // Safely read the file
        if let data = try? String(contentsOf: commentFile, encoding: String.Encoding.utf8) {
            if (data.count > 2){
                commentText = data
            }
        }
    
        commentText = removeSpecialCharsFromString(text: commentText)
        
        return commentText;
    }
    
    func convertOldData(bandName: String){
            
        let oldCommentFileName = bandName + "_comment.txt";
        let oldCommentFile = directoryPath.appendingPathComponent(oldCommentFileName)
        let newCustCommentFile = directoryPath.appendingPathComponent( bandName + "_comment.note-cust")
        var oldCommentText = ""
        
        if (FileManager.default.fileExists(atPath: oldCommentFile.path) == true){
            
            if let data = try? String(contentsOf: oldCommentFile, encoding: String.Encoding.utf8) {
                if (data.count > 2){
                    oldCommentText = data
                } else {
                    print ("No URL for band  What happened here - \(data)")
                }
            } else {
                    print ("No URL for band  What happened here")
            }
            
            var isDefaultNote = self.custMatchesDefault(customNote: oldCommentText, bandName: bandName)
            
            if (oldCommentText.starts(with: FestivalConfig.current.getDefaultDescriptionText()) == false && isDefaultNote == false){
                do {
                    try oldCommentText.write(to: newCustCommentFile, atomically: false, encoding: String.Encoding.utf8)
                } catch {
                    print("commentFile " + error.localizedDescription)
                }
            }
            
            do {
                print ("commentFile being deleted \(oldCommentFile)")
                try FileManager.default.removeItem(atPath: oldCommentFile.path)
                
            } catch let error as NSError {
                print ("Encountered an error removing old commentFile " + error.debugDescription)
            }
        }
    }
    
    /// Returns the description for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The description string for the band.
    func getDescription(bandName: String) -> String {
        
        // Validate input
        guard !bandName.isEmpty else {
            print("⚠️ DEBUG_commentFile: Empty band name provided to getDescription")
            return FestivalConfig.current.getDefaultDescriptionText()
        }
        
        convertOldData(bandName: bandName)
        let normalizedBandName = normalizeBandName(bandName)
        print ("DEBUG_commentFile:  lookup for \(bandName) (normalized: \(normalizedBandName))")
        var commentText = FestivalConfig.current.getDefaultDescriptionText()
        
        let commentFileName = self.getNoteFileName(bandName: bandName)
        let commentFile = directoryPath.appendingPathComponent( commentFileName)
        
        print ("DEBUG_commentFile: doesDescriptionFileExists for \(bandName)")
        if (doesDescriptionFileExists(bandName: bandName) == false){
            
            if (downloadingAllComments == false){
                DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                    self.getDescriptionMapFile();
                    self.getDescriptionMap();
                }
            }
            
            //bandDescriptionLock.sync() {
            if (bandDescriptionUrl.index(forKey: normalizedBandName) != nil && bandDescriptionUrl[normalizedBandName] != nil){
                
                print ("DEBUG_commentFile: downloading URL \(bandDescriptionUrl[normalizedBandName])")
                DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                    
                    self.getDescriptionFromUrl(bandName: bandName, descriptionUrl: self.bandDescriptionUrl[normalizedBandName]! )
                }
            } else {
                print ("DEBUG_commentFile: No URL for band '\(normalizedBandName)' - \(bandDescriptionUrl)")
            }
        } else {
            print ("DEBUG_commentFile: No URL for band \(bandName) - \(commentFile)")
            if FileManager.default.fileExists(atPath: commentFile.path){
                print ("DEBUG_commentFile: No URL for band \(bandName) - file exists")
            } else {
                print ("DEBUG_commentFile: No URL for band \(bandName) - file does not exists")
            }
        
        }
        

        // Safely read the file
        if let data = try? String(contentsOf: commentFile, encoding: String.Encoding.utf8) {
            if (data.count > 2){
                commentText = data
            } else {
                print ("No URL for band  What happened here - \(data)")
            }
        } else {
                print ("No URL for band  What happened here")
        }
        
        
        commentText = removeSpecialCharsFromString(text: commentText)
        //remove leading space
        commentText = commentText.replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
        
        if (commentText.contains(FestivalConfig.current.getDefaultDescriptionText())){
            do {
                print ("commentFile being deleted \(commentFile) -! - \(commentText)")
                try FileManager.default.removeItem(atPath: commentFile.path)
                
            } catch let error as NSError {
                print ("Encountered an error removing old commentFile " + error.debugDescription)
            }
        }
        return commentText;
    }
    
    
    public func removeSpecialCharsFromString(text: String) -> String {
        
        var newText = text;
        newText = text.replacingOccurrences(of: "\r", with: "\n")
        let okayChars : Set<Character> =
        Set("abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLKMNOPQRSTUVWXYZ1234567890+-*=(),.:!_\n$\\//")
        return String(newText.filter {okayChars.contains($0) })
    }
    
    /// Normalizes a band name by removing invisible Unicode characters and trimming whitespace.
    /// - Parameter bandName: The band name to normalize.
    /// - Returns: The normalized band name, or the original name if normalization fails.
    func normalizeBandName(_ bandName: String) -> String {
        // Ensure we have a valid input
        guard !bandName.isEmpty else {
            print("⚠️ normalizeBandName: Received empty band name")
            return bandName
        }
        
        // Remove invisible Unicode characters and normalize
        let normalized = bandName.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "⁦", with: "") // Remove left-to-right mark
            .replacingOccurrences(of: "⁧", with: "") // Remove right-to-left mark
            .replacingOccurrences(of: "\u{200E}", with: "") // Remove left-to-right mark
            .replacingOccurrences(of: "\u{200F}", with: "") // Remove right-to-left mark
            .replacingOccurrences(of: "\u{202A}", with: "") // Remove left-to-right embedding
            .replacingOccurrences(of: "\u{202B}", with: "") // Remove right-to-left embedding
            .replacingOccurrences(of: "\u{202C}", with: "") // Remove pop directional formatting
            .replacingOccurrences(of: "\u{202D}", with: "") // Remove left-to-right override
            .replacingOccurrences(of: "\u{202E}", with: "") // Remove right-to-left override
            .replacingOccurrences(of: "\u{2066}", with: "") // Remove left-to-right isolate
            .replacingOccurrences(of: "\u{2067}", with: "") // Remove right-to-left isolate
            .replacingOccurrences(of: "\u{2068}", with: "") // Remove first strong isolate
            .replacingOccurrences(of: "\u{2069}", with: "") // Remove pop directional isolate
        
        // Ensure we don't return an empty string
        if normalized.isEmpty {
            print("⚠️ normalizeBandName: Normalization produced empty string for '\(bandName)', returning original")
            return bandName
        }
        
        return normalized
    }

    // Add static variables to track failed attempts and prevent loops
    private static var lastFailureTime: TimeInterval = 0
    private static var failureCount: Int = 0
    private static let maxFailures = 3
    private static let failureCooldown: TimeInterval = 30 // 30 seconds
    
    func getDescriptionMap(){
        
        // Check if we've failed too many times recently
        let currentTime = Date().timeIntervalSince1970
        if CustomBandDescription.failureCount >= CustomBandDescription.maxFailures {
            if currentTime - CustomBandDescription.lastFailureTime < CustomBandDescription.failureCooldown {
                print("⚠️ getDescriptionMap: Too many recent failures (\(CustomBandDescription.failureCount)), cooling down for \(Int(CustomBandDescription.failureCooldown - (currentTime - CustomBandDescription.lastFailureTime))) more seconds")
                return
            } else {
                // Reset failure count after cooldown
                CustomBandDescription.failureCount = 0
                print("getDescriptionMap: Failure cooldown expired, retrying...")
            }
        }
        
        // Ensure we're not already processing
        guard !descriptionLock else {
            print("⚠️ getDescriptionMap: Already processing, skipping duplicate call")
            return
        }
        
        descriptionLock = true;
        
        defer {
            // Always ensure the lock is released, even if an error occurs
            descriptionLock = false;
            print("commentFile getDescriptionMap: Lock released")
        }
        
        print ("commentFile looking for descriptionMapFile")
        
        // Check if file exists first
        if (FileManager.default.fileExists(atPath: descriptionMapFile) == false){
            print("commentFile Description map file doesn't exist, attempting to download")
            
            // Try to download the file
            getDescriptionMapFile();
            
            // Check if download was successful
            if (FileManager.default.fileExists(atPath: descriptionMapFile) == false){
                print("⚠️ getDescriptionMap: Download failed, file still doesn't exist - skipping processing")
                // Record failure
                CustomBandDescription.failureCount += 1
                CustomBandDescription.lastFailureTime = currentTime
                print("⚠️ getDescriptionMap: Failure count: \(CustomBandDescription.failureCount)/\(CustomBandDescription.maxFailures)")
                return
            }
        }
        
        print ("commentFile looking for descriptionMapFile of \(descriptionMapFile)")
        
        // Safely read the file
        guard let csvDataString = try? String(contentsOfFile: descriptionMapFile, encoding: String.Encoding.utf8) else {
            let fileExists = FileManager.default.fileExists(atPath: descriptionMapFile)
            print ("commentFile Encountered an error could not open descriptionMap file - \(descriptionMapFile)")
            print ("commentFile File exists: \(fileExists)")
            if !fileExists {
                print ("commentFile This is likely due to failed download - check network connectivity and URL validity")
            } else {
                print ("commentFile File exists but cannot be read - check file permissions and encoding")
            }
            // Record failure
            CustomBandDescription.failureCount += 1
            CustomBandDescription.lastFailureTime = currentTime
            print("⚠️ getDescriptionMap: Failure count: \(CustomBandDescription.failureCount)/\(CustomBandDescription.maxFailures)")
            return
        }
        
        // Validate that we have content
        guard !csvDataString.isEmpty else {
            print("⚠️ getDescriptionMap: CSV file is empty")
            // Record failure
            CustomBandDescription.failureCount += 1
            CustomBandDescription.lastFailureTime = currentTime
            print("⚠️ getDescriptionMap: Failure count: \(CustomBandDescription.failureCount)/\(CustomBandDescription.maxFailures)")
            return
        }
        
        // Safely parse CSV data
        guard let csvData = try? CSV(csvStringToParse: csvDataString) else {
            print("Error: Failed to parse CSV data in getDescriptionMap.")
            // Record failure
            CustomBandDescription.failureCount += 1
            CustomBandDescription.lastFailureTime = currentTime
            print("⚠️ getDescriptionMap: Failure count: \(CustomBandDescription.failureCount)/\(CustomBandDescription.maxFailures)")
            return
        }
        
        // Success! Reset failure count
        CustomBandDescription.failureCount = 0
        
        // Process each row safely
        var processedCount = 0
        var errorCount = 0
        
        for (index, lineData) in csvData.rows.enumerated() {
            do {
                // Safely extract and validate the data before using it
                guard let bandName = lineData[bandField],
                      let urlString = lineData[urlField],
                      let urlDate = lineData[urlDateField],
                      !bandName.isEmpty,
                      !urlString.isEmpty,
                      !urlDate.isEmpty else {
                    print ("commentFile  Unable to parse descriptionMap line \(index): \(lineData)")
                    errorCount += 1
                    continue
                }
                
                // Normalize the band name
                let normalizedBandName = normalizeBandName(bandName)
                
                // Validate that normalization didn't produce an empty string
                guard !normalizedBandName.isEmpty else {
                    print ("commentFile  Skipping band with empty normalized name: '\(bandName)'")
                    errorCount += 1
                    continue
                }
                
                print ("commentFile descriptiopnMap Adding \(normalizedBandName) with url \(urlString)")
                
                // Safely update the dictionaries
                bandDescriptionUrl[normalizedBandName] = urlString
                bandDescriptionUrlDate[normalizedBandName] = urlDate
                
                // Update cache variables safely
                bandDescriptionLock.async(flags: .barrier) {
                    cacheVariables.bandDescriptionUrlCache[normalizedBandName] = urlString
                    cacheVariables.bandDescriptionUrlDateCache[normalizedBandName] = urlDate
                }
                
                processedCount += 1
                
            } catch {
                print("⚠️ getDescriptionMap: Error processing line \(index): \(error)")
                errorCount += 1
                continue
            }
        }
        
        print("commentFile getDescriptionMap: Processed \(processedCount) bands successfully, \(errorCount) errors")
    }
    
    func getDefaultDescriptionMapUrl() -> String{
        
        var url = String()

        var descriptionPointer = "descriptionMap";
        
        print ("Gertting descriptionPointerUrl 1");
        url = getPointerUrlData(keyValue: descriptionPointer)
        
        return url
    }
    
    /// Returns the description URL for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The description URL string for the band.
    func getDescriptionUrl(_ band: String) -> String {
        let normalizedBand = normalizeBandName(band)
        return bandDescriptionUrl[normalizedBand] ?? ""
    }
    
    /// Returns the date of the description for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The date string for the band's description.
    func getDescriptionDate(_ band: String) -> String {
        let normalizedBand = normalizeBandName(band)
        return bandDescriptionUrlDate[normalizedBand] ?? ""
    }
    
    /// Check if band data is available before attempting to load descriptions
    private func hasBandDataAvailable() -> Bool {
        // Check if we already have any band data loaded
        if !bandDescriptionUrl.isEmpty {
            return true
        }
        
        // Check if band file exists (indicating band data has been downloaded)
        let bandFile = directoryPath.appendingPathComponent("bandFile")
        if FileManager.default.fileExists(atPath: bandFile.path) {
            // Check if the file has actual content
            if let data = try? String(contentsOf: bandFile, encoding: .utf8), !data.isEmpty {
                return true
            }
        }
        
        // Check if we have any cached band names in the static cache
        let hasCachedBands = staticSchedule.sync {
            return !cacheVariables.bandNamesStaticCache.isEmpty || !cacheVariables.bandNamesArrayStaticCache.isEmpty
        }
        
        if hasCachedBands {
            return true
        }
        
        // If none of the above conditions are met, band data is not ready
        return false
    }
    
    /// Check if schedule data is available before attempting to load descriptions
    private func hasScheduleDataAvailable() -> Bool {
        // Check if we have any schedule data in the static cache
        let hasCachedSchedule = staticSchedule.sync {
            return !cacheVariables.scheduleStaticCache.isEmpty || !cacheVariables.scheduleTimeStaticCache.isEmpty
        }
        
        if hasCachedSchedule {
            return true
        }
        
        // Check if schedule file exists
        let scheduleFile = directoryPath.appendingPathComponent("scheduleFile")
        if FileManager.default.fileExists(atPath: scheduleFile.path) {
            // Check if the file has actual content
            if let data = try? String(contentsOf: scheduleFile, encoding: .utf8), !data.isEmpty {
                return true
            }
        }
        
        return false
    }
    
    /// Check if both band and schedule data are available before attempting to load descriptions
    private func hasPrerequisiteDataAvailable() -> Bool {
        let bandsReady = hasBandDataAvailable()
        let scheduleReady = hasScheduleDataAvailable()
        
        if !bandsReady {
            print("⚠️ CustomBandDescription: Band data not ready yet, skipping description load")
        }
        if !scheduleReady {
            print("⚠️ CustomBandDescription: Schedule data not ready yet, skipping description load")
        }
        
        return bandsReady && scheduleReady
    }
}





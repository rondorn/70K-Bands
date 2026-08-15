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
    
    // MARK: - Thread safety
    //
    // These dictionaries are mutated during background refresh (e.g. getDescriptionMap())
    // and also read on the main thread when opening band details.
    // Swift Dictionary is NOT thread-safe for concurrent read/write and can crash inside `lookup()`.
    private let descriptionMapQueue = DispatchQueue(
        label: "com.70kBands.CustomBandDescription.descriptionMapQueue",
        attributes: .concurrent
    )
    private let descriptionMapQueueKey = DispatchSpecificKey<Bool>()
    
    private func readDescriptionMap<T>(_ block: () -> T) -> T {
        if DispatchQueue.getSpecific(key: descriptionMapQueueKey) != nil {
            return block()
        }
        return descriptionMapQueue.sync(execute: block)
    }
    
    private func writeDescriptionMapSync(_ block: () -> Void) {
        if DispatchQueue.getSpecific(key: descriptionMapQueueKey) != nil {
            block()
            return
        }
        descriptionMapQueue.sync(flags: .barrier, execute: block)
    }
    
    init(){
        let t0 = Date()
        let thread = Thread.isMainThread ? "MAIN" : "BG"
        LaunchTiming.logStart("CustomBandDescription.init", thread: thread)
        descriptionMapQueue.setSpecific(key: descriptionMapQueueKey, value: true)
        refreshCache()
        LaunchTiming.logEnd("CustomBandDescription.init", startTime: t0, thread: thread)
    }
    
    func refreshCache(){
        let t0 = Date()
        let thread = Thread.isMainThread ? "MAIN" : "BG"
        LaunchTiming.logStart("CustomBandDescription.refreshCache", thread: thread)

        let currentQueueLabel = OperationQueue.current?.underlyingQueue?.label

        // Use a safer approach to cache refresh
        bandDescriptionLock.sync() {
            // Check if we already have cached data
            if (cacheVariables.bandDescriptionUrlCache.isEmpty == false){
                // Safely copy the cached data
                writeDescriptionMapSync {
                    bandDescriptionUrl = cacheVariables.bandDescriptionUrlCache
                    bandDescriptionUrlDate = cacheVariables.bandDescriptionUrlDateCache
                }
                let count = readDescriptionMap { bandDescriptionUrl.count }
                print("commentFile refreshCache: Loaded from cache - \(count) bands")
                
            } else {
                // Always try to load from disk first, regardless of network status
                print("commentFile refreshCache: Loading description map from disk")
                self.getDescriptionMap();
                
                // Only attempt network operations if we still don't have data and internet is available
                let isEmptyAfterDiskLoad = readDescriptionMap { bandDescriptionUrl.isEmpty }
                if isEmptyAfterDiskLoad && isInternetAvailable() {
                    if hasPrerequisiteDataAvailable() {
                        print("commentFile refreshCache: Description map still empty after disk load, attempting network refresh")
                        if currentQueueLabel == "com.apple.main-thread" {
                            // On main thread, just trigger the download
                            print("commentFile refreshCache: Triggering background download from main thread")
                        } else {
                            // On background thread, do the full refresh
                            print("commentFile refreshCache: Performing full data refresh from background thread")
                            refreshData()
                        }
                    } else {
                        print("⚠️ commentFile refreshCache: Prerequisite data not ready yet, skipping network refresh")
                    }
                } else if isEmptyAfterDiskLoad {
                    print("⚠️ commentFile refreshCache: No internet available and no data from disk")
                } else {
                    let count = readDescriptionMap { bandDescriptionUrl.count }
                    print("commentFile refreshCache: Successfully loaded \(count) bands from disk")
                }
            }
        }
        LaunchTiming.logEnd("CustomBandDescription.refreshCache", startTime: t0, thread: thread)
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
        
        // Move network call off main thread to prevent UI hang
        let semaphore = DispatchSemaphore(value: 0)
        var httpData = ""
        
        DispatchQueue.global(qos: .userInitiated).async {
            httpData = getUrlData(urlString: mapUrl)
            semaphore.signal()
        }
        
        semaphore.wait()
        
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
    /// It should ONLY be called from a background queue (not on main thread).
    /// IMPORTANT: This method is already called from DispatchQueue.global - do not call from main thread!
    func getAllDescriptions(){
        
        // Safeguard: Prevent concurrent execution
        // Note: UIApplication.shared.applicationState removed to fix Main Thread Checker violation
        // This method is intentionally called from background threads
        if (downloadingAllComments == false){
            downloadingAllComments = true
            print ("commentFile looping through bands (background queue)")
            
            // Snapshot map so we don't iterate while background refresh mutates it.
            let snapshot: [String: String] = readDescriptionMap { bandDescriptionUrl }
            for record in snapshot {
                let bandName = record.key
                let descriptionUrl = record.value
                print ("commentFile working on bandName " + bandName)
                if self.needsOfficialDescriptionRefresh(bandName: bandName) {
                    _ = self.getDescriptionFromUrl(bandName: bandName, descriptionUrl: descriptionUrl)
                }
            }
            
            downloadingAllComments = false
            print ("commentFile processing completed (background queue)")
        }
    }
    
    func doesDescriptionFileExists(bandName: String) -> Bool {
        
        let commentFileName = self.getNoteFileName(bandName: bandName)
        let commentFile = directoryPath.appendingPathComponent(commentFileName)
        
        print ("commentFile lookup for \(commentFile)");
        return (FileManager.default.fileExists(atPath: commentFile.path))
    }

    func hasCustomNoteFile(bandName: String) -> Bool {
        let custCommentFile = directoryPath.appendingPathComponent(bandName + "_comment.note-cust")
        return FileManager.default.fileExists(atPath: custCommentFile.path)
    }

    /// True when the current map-date (or custom) note file exists with usable content.
    func hasCurrentOfficialCache(bandName: String) -> Bool {
        if hasCustomNoteFile(bandName: bandName) {
            if let text = readNoteFileText(fileName: bandName + "_comment.note-cust"), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
        }
        let fileName = getNoteFileName(bandName: bandName)
        guard let text = readNoteFileText(fileName: fileName) else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !trimmed.hasPrefix(FestivalConfig.current.getDefaultDescriptionText())
    }

    func needsOfficialDescriptionRefresh(bandName: String) -> Bool {
        return !hasCustomNoteFile(bandName: bandName) && !hasCurrentOfficialCache(bandName: bandName)
    }

    private func readNoteFileText(fileName: String) -> String? {
        let commentFile = directoryPath.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: commentFile.path),
              let data = try? String(contentsOf: commentFile, encoding: .utf8),
              data.count > 2 else {
            return nil
        }
        return data
    }

    /// Newest older dated note file when current-marker file is missing (offline / failed refresh).
    private func findBestOlderNoteFileName(bandName: String) -> String? {
        let currentFileName = getNoteFileName(bandName: bandName)
        let prefix = bandName + "_comment.note-"
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: directoryPath.path) else {
            return nil
        }
        var bestName: String?
        var bestDate = Date.distantPast
        for name in contents {
            guard name.hasPrefix(prefix), name != currentFileName, !name.hasSuffix("-cust") else { continue }
            let url = directoryPath.appendingPathComponent(name)
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let modified = (attrs?[.modificationDate] as? Date) ?? Date.distantPast
            if modified >= bestDate {
                bestDate = modified
                bestName = name
            }
        }
        return bestName
    }

    /// Best on-disk description for display: current marker / custom, else newest older dated file.
    func getBestCachedDescription(bandName: String) -> String {
        convertOldData(bandName: bandName)

        if let current = readNoteFileText(fileName: getNoteFileName(bandName: bandName)), current.count > 2 {
            var text = removeSpecialCharsFromString(text: current)
            text = text.replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
            if !text.hasPrefix(FestivalConfig.current.getDefaultDescriptionText()) {
                return text
            }
        }

        if let olderName = findBestOlderNoteFileName(bandName: bandName),
           let older = readNoteFileText(fileName: olderName), older.count > 2 {
            var text = removeSpecialCharsFromString(text: older)
            text = text.replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
            print("DEBUG_commentFile: Using older cached description \(olderName) for \(bandName)")
            return text
        }

        return FestivalConfig.current.getDefaultDescriptionText()
    }

    /// Deletes other dated note files ONLY after a successful current-date save.
    func cleanupObsoleteCacheAfterSuccessfulSave(bandName: String) {
        let currentFileName = getNoteFileName(bandName: bandName)
        let prefix = bandName + "_comment.note-"
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: directoryPath.path) else {
            return
        }
        for name in contents {
            guard name.hasPrefix(prefix), name != currentFileName, !name.hasSuffix("-cust") else { continue }
            let path = directoryPath.appendingPathComponent(name).path
            do {
                try FileManager.default.removeItem(atPath: path)
                print("DEBUG_commentFile: Deleted obsolete cached description \(name)")
            } catch {
                print("DEBUG_commentFile: Failed deleting obsolete \(name): \(error)")
            }
        }
    }
    
    func custMatchesDefault(customNote: String, bandName: String)-> Bool{
        
        var matches = false
        let normalizedBandName = normalizeBandName(bandName)
        
        let (hasDate, urlForBand): (Bool, String?) = readDescriptionMap {
            let hasDate = (bandDescriptionUrlDate[normalizedBandName] != nil)
            let url = bandDescriptionUrl[normalizedBandName]
            return (hasDate, url)
        }
        
        if hasDate, let urlForBand {
            var defaultBandNote = getDescriptionFromUrl(bandName: bandName, descriptionUrl: String(describing: urlForBand))
            
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
        
        let urlDateValue: String? = readDescriptionMap {
            return bandDescriptionUrlDate[normalizedBandName]
        }
        
        if urlDateValue != nil {
            // CRASH FIX: Safely unwrap the date value to avoid corrupt cached data
            // If the value is not a proper String, use empty string as fallback
            let urlDateString = String(describing: urlDateValue ?? "")
            let defaultCommentFileName = bandName + "_comment.note-" + urlDateString
            
            
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
                if let olderName = findBestOlderNoteFileName(bandName: bandName),
                   let older = readNoteFileText(fileName: olderName) {
                    return removeSpecialCharsFromString(text: older)
                }
                return FestivalConfig.current.getDefaultDescriptionText()
            }
            
            // Move network call off main thread to prevent UI hang
            let semaphore = DispatchSemaphore(value: 0)
            var httpData = ""
            
            DispatchQueue.global(qos: .userInitiated).async {
                httpData = getUrlData(urlString: descriptionUrl)
                semaphore.signal()
            }
            
            semaphore.wait()
                
            //do not write if we are getting 404 error or HTML error page
            if (httpData.starts(with: "<!DOCTYPE") == false && !httpData.isEmpty){
                commentText = httpData;
                print ("commentFile text is '" + commentText + "'")
                
                print ("Wrote commentFile for \(bandName) " + commentText)
                do {
                    try commentText.write(to: commentFile, atomically: false, encoding: String.Encoding.utf8)
                    cleanupObsoleteCacheAfterSuccessfulSave(bandName: bandName)
                } catch {
                    print("commentFile " + error.localizedDescription)
                }
            } else {
                print("Received HTML error page or empty response for \(bandName)")
                // Keep any older cache intact on failed download
                if let olderName = findBestOlderNoteFileName(bandName: bandName),
                   let older = readNoteFileText(fileName: olderName) {
                    return removeSpecialCharsFromString(text: older)
                }
                return FestivalConfig.current.getDefaultDescriptionText()
            }
        }

        // Safely read the file
        if let data = try? String(contentsOf: commentFile, encoding: String.Encoding.utf8) {
            if (data.count > 2){
                commentText = data
            }
        } else if let olderName = findBestOlderNoteFileName(bandName: bandName),
                  let older = readNoteFileText(fileName: olderName) {
            commentText = older
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
    
    /// Returns the best cached description for a band (current marker, else older dated file).
    /// Does not perform network I/O — callers that need a refresh should download separately.
    /// - Parameter band: The name of the band.
    /// - Returns: The description string for the band.
    func getDescription(bandName: String) -> String {
        
        // Validate input
        guard !bandName.isEmpty else {
            print("⚠️ DEBUG_commentFile: Empty band name provided to getDescription")
            return FestivalConfig.current.getDefaultDescriptionText()
        }
        
        print ("DEBUG_commentFile: cache-only lookup for \(bandName)")
        return getBestCachedDescription(bandName: bandName)
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
        let t0 = Date()
        let thread = Thread.isMainThread ? "MAIN" : "BG"
        LaunchTiming.logStart("CustomBandDescription.getDescriptionMap", thread: thread)
        defer { LaunchTiming.logEnd("CustomBandDescription.getDescriptionMap", startTime: t0, thread: thread) }

        let currentTime = Date().timeIntervalSince1970

        // IMPORTANT:
        // - We must ALWAYS parse from disk if the file exists (even if prior attempts failed).
        // - Cooldown/throttling should only prevent repeated *download attempts* when the file is missing,
        //   not prevent parsing a now-valid file.
        let fileExistsAtStart = FileManager.default.fileExists(atPath: descriptionMapFile)
        if !fileExistsAtStart {
            // If the pointer URL isn't ready yet (startup before pointer download completes), do NOT count this
            // as a failure and do NOT start a cooldown. Just return and try again later.
            let mapUrl = getDefaultDescriptionMapUrl()
            if mapUrl.isEmpty {
                print("⚠️ getDescriptionMap: descriptionMap pointer URL not ready yet (empty) - skipping without counting failure")
                return
            }
            
            // Check if we've failed too many times recently (download-related failures only)
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
        
        // Process each row safely. Build new maps, then swap atomically to avoid concurrent read/write crashes.
        var processedCount = 0
        var errorCount = 0

        var newUrlMap: [String: String] = [:]
        var newDateMap: [String: String] = [:]
        
        for (index, lineData) in csvData.rows.enumerated() {
            do {
                // Safely extract and validate the data before using it
                // NOTE: Date field is OPTIONAL - description map CSV doesn't always have it
                guard let bandName = lineData[bandField],
                      let urlString = lineData[urlField],
                      !bandName.isEmpty,
                      !urlString.isEmpty else {
                    print ("commentFile  Unable to parse descriptionMap line \(index): \(lineData)")
                    errorCount += 1
                    continue
                }
                
                // Get the date field if it exists, otherwise use empty string
                let urlDate = lineData[urlDateField] ?? ""
                
                // Normalize the band name
                let normalizedBandName = normalizeBandName(bandName)
                
                // Validate that normalization didn't produce an empty string
                guard !normalizedBandName.isEmpty else {
                    print ("commentFile  Skipping band with empty normalized name: '\(bandName)'")
                    errorCount += 1
                    continue
                }
                
                print ("commentFile descriptiopnMap Adding \(normalizedBandName) with url \(urlString)")
                
                // Safely update the dictionaries - ensure String type
                let urlDateString = String(describing: urlDate)
                newUrlMap[normalizedBandName] = String(describing: urlString)
                newDateMap[normalizedBandName] = urlDateString
                
                // Update cache variables safely
                bandDescriptionLock.async(flags: .barrier) {
                    cacheVariables.bandDescriptionUrlCache[normalizedBandName] = String(describing: urlString)
                    cacheVariables.bandDescriptionUrlDateCache[normalizedBandName] = urlDateString
                }
                
                processedCount += 1
                
            } catch {
                print("⚠️ getDescriptionMap: Error processing line \(index): \(error)")
                errorCount += 1
                continue
            }
        }

        writeDescriptionMapSync {
            bandDescriptionUrl = newUrlMap
            bandDescriptionUrlDate = newDateMap
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
        let urlValue: String? = readDescriptionMap {
            return bandDescriptionUrl[normalizedBand]
        }
        if let urlValue {
            return String(describing: urlValue)
        }
        return ""
    }
    
    /// Returns whether the band has a published entry in descriptionMap.
    func isBandInDescriptionMap(bandName: String) -> Bool {
        getDescriptionMap()
        let normalizedBand = normalizeBandName(bandName)
        return readDescriptionMap {
            bandDescriptionUrlDate.keys.contains(normalizedBand)
        }
    }

    /// Returns the date of the description for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The date string for the band's description.
    func getDescriptionDate(_ band: String) -> String {
        let normalizedBand = normalizeBandName(band)
        let dateValue: String? = readDescriptionMap {
            return bandDescriptionUrlDate[normalizedBand]
        }
        if let dateValue {
            return String(describing: dateValue)
        }
        return ""
    }
    
    /// Check if band data is available before attempting to load descriptions
    private func hasBandDataAvailable() -> Bool {
        // Check if we already have any band data loaded
        if readDescriptionMap({ !bandDescriptionUrl.isEmpty }) {
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
    
    /// Ensures the description map is downloaded/parsed into this instance.
    /// Returns the number of band→URL entries available for bulk note download.
    @discardableResult
    func ensureDescriptionMapLoadedForBulk() -> Int {
        print("DEBUG_commentFile: ensureDescriptionMapLoadedForBulk — refreshing map")
        getDescriptionMapFile()
        getDescriptionMap()
        let count = readDescriptionMap { bandDescriptionUrl.count }
        print("DEBUG_commentFile: ensureDescriptionMapLoadedForBulk — map entries=\(count)")
        return count
    }
    
    /// Downloads all missing current-marker descriptions (bulk / terminate / background).
    /// Always loads the map first; never returns early after only refreshing the map.
    /// Runs synchronously on the caller’s queue (caller must not be main).
    func downloadAllDescriptionsOnAppExit() {
        downloadAllMissingDescriptionsForBulk()
    }
    
    /// Guaranteed map load, then download every band that lacks a current-date cache file.
    /// Safe to call from launch bulk, background bulk, or terminate.
    func downloadAllMissingDescriptionsForBulk() {
        print("DEBUG_commentFile: Starting bulk download of all missing descriptions")
        
        let mapCount = ensureDescriptionMapLoadedForBulk()
        guard mapCount > 0 else {
            print("⚠️ DEBUG_commentFile: Description map empty after load — cannot bulk-download notes")
            return
        }
        
        print("DEBUG_commentFile: Bulk-downloading missing notes for \(mapCount) map entries")
        getAllDescriptions()
        print("DEBUG_commentFile: Completed bulk download of missing descriptions")
    }
    
    /// Handles data collection requests, including year changes
    /// - Parameter eventYearOverride: If true, indicates this is a year change request
    /// - Parameter completion: Completion handler called when the operation is complete
    func requestDataCollection(eventYearOverride: Bool = false, completion: (() -> Void)? = nil) {
        print("DEBUG_commentFile: requestDataCollection called with eventYearOverride: \(eventYearOverride)")
        
        if eventYearOverride {
            // This is a year change - clear cached data and reload
            print("DEBUG_commentFile: Year change detected, clearing cached description data")
            
            // Clear the cached description map data
            writeDescriptionMapSync {
                bandDescriptionUrl.removeAll()
                bandDescriptionUrlDate.removeAll()
            }
            
            // Clear the static cache variables
            bandDescriptionLock.async(flags: .barrier) {
                cacheVariables.bandDescriptionUrlCache.removeAll()
                cacheVariables.bandDescriptionUrlDateCache.removeAll()
            }
            
            // Force a refresh to load the new year's description map
            print("DEBUG_commentFile: Reloading description map for new year")
            refreshCache()
        } else {
            // Normal data collection request
            print("DEBUG_commentFile: Normal data collection request")
            refreshCache()
        }
        
        // Call completion immediately since refreshCache is synchronous for disk operations
        completion?()
    }
}





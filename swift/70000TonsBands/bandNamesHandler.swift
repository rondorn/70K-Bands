//
//  bandNames.swift
//  70000TonsApp
//
//  Created by Ron Dorn on 12/23/14.
//  Copyright (c) 2014 Ron Dorn. All rights reserved.
//

import Foundation
import CryptoKit

open class bandNamesHandler {
    
    // Singleton instance
    static let shared = bandNamesHandler()
    
    // These must only be accessed inside staticBandName queue
    var bandNames =  [String :[String : String]]()
    var bandNamesArray = [String]()
    
    private init(){
        print ("🔄 bandNamesHandler singleton initialized - Loading bandName Data")
        getCachedData()
    }
    
    /// Loads band name data from cache if available, otherwise loads from disk.
    /// Always shows cached/disk data immediately except on first launch or explicit refresh.
    /// Triggers background update if needed.
    func getCachedData(forceNetwork: Bool = false, completion: (() -> Void)? = nil) {
        print("Loading bandName Data cache")
        var needsNetworkFetch = false
        var showedData = false

        staticBandName.sync {
            if !self.bandNames.isEmpty {
                // Cache is available, show immediately
                print("Loading bandName Data cache, from cache")
                showedData = true
            } else if !cacheVariables.bandNamesStaticCache.isEmpty {
                // cacheVariables has data, load into memory and show immediately
                print("Loading bandName Data cache, from cacheVariables")
                staticBandName.async(flags: .barrier) {
                    self.bandNames = cacheVariables.bandNamesStaticCache
                    self.bandNamesArray = cacheVariables.bandNamesArrayStaticCache
                    DispatchQueue.main.async {
                        completion?()
                    }
                }
                showedData = true
            } else if FileManager.default.fileExists(atPath: bandFile) {
                // Disk file exists, load synchronously and show immediately
                print("Loading bandName Data cache, from disk")
                self.readBandFile()
                showedData = true
            } else {
                // No data at all, need to fetch from network (first launch or forced)
                needsNetworkFetch = true
            }
        }

        if showedData {
            // Show data immediately
            DispatchQueue.main.async {
                completion?()
            }
            // After showing, trigger background update if not just launched or forced
            if (!cacheVariables.justLaunched && !forceNetwork) {
                print("Triggering background update for band data")
                DispatchQueue.global(qos: .background).async {
                    self.gatherData(forceDownload: false)
                }
            } else if cacheVariables.justLaunched {
                print("First app launch - deferring background update to proper loading sequence")
            }
        } else if needsNetworkFetch || forceNetwork {
            // If we need to fetch from network (first launch or forced refresh), block UI and fetch
            if cacheVariables.justLaunched {
                print("First app launch detected - deferring network download to proper loading sequence")
                print("This prevents infinite retry loops when network is unavailable")
                // Don't automatically download on first launch - wait for proper sequence
                completion?()
                return
            } else {
                print("No cached/disk data, fetching from network (blocking UI)")
            }
            DispatchQueue.global(qos: .default).async {
                self.gatherData(forceDownload: false, completion: completion)
            }
        }
        print("Done Loading bandName Data cache")
    }
    
    /// Clears the static cache of band names.
    func clearCachedData(){
        staticBandName.async(flags: .barrier) {
        cacheVariables.bandNamesStaticCache = [String :[String : String]]()
        }
    }
    
    /// Calculates SHA256 checksum of a string
    private func calculateChecksum(_ data: String) -> String {
        let inputData = Data(data.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Gets the stored checksum for the current band data file
    private func getStoredChecksum() -> String? {
        let checksumFile = getDocumentsDirectory().appendingPathComponent("bandFile.checksum")
        return try? String(contentsOfFile: checksumFile, encoding: .utf8)
    }
    
    /// Stores the checksum for the band data file
    private func storeChecksum(_ checksum: String) {
        let checksumFile = getDocumentsDirectory().appendingPathComponent("bandFile.checksum")
        do {
            try checksum.write(toFile: checksumFile, atomically: true, encoding: .utf8)
            print("✅ Stored band data checksum: \(String(checksum.prefix(8)))...")
        } catch {
            print("❌ Error storing band data checksum: \(error)")
        }
    }
    
    /// Gathers band data from the internet if available, writes it to file, and populates the cache.
    /// Uses checksum comparison to avoid unnecessary cache rebuilds when data hasn't changed.
    /// Calls completion handler when done.
    /// - Parameter forceDownload: If true, forces download from network. If false, only reads from cache.
    func gatherData(forceDownload: Bool = false, completion: (() -> Void)? = nil) {
        // Prevent concurrent band data loading
        if isLoadingBandData {
            print("[YEAR_CHANGE_DEBUG] Band data loading already in progress, skipping duplicate request")
            completion?()
            return
        }
        
        isLoadingBandData = true
        var dataChanged = false
        var newDataValid = false
        
        // Only download from network if explicitly forced
        if forceDownload && isInternetAvailable() == true {
            eventYear = Int(getPointerUrlData(keyValue: "eventYear"))!
            print ("🔄 Loading bandName Data gatherData with checksum validation")
            var artistUrl = getPointerUrlData(keyValue: "artistUrl") ?? "http://dropbox.com"
            print ("📥 Downloading band data from " + artistUrl);
            let httpData = getUrlData(urlString: artistUrl)
            print ("📊 Downloaded band data size: \(httpData.count) characters");
            
            // Only proceed if data appears valid
            if (httpData.isEmpty == false && httpData.count > 100) { // Basic validation
                newDataValid = true
                
                // Calculate checksum of new data
                let newChecksum = calculateChecksum(httpData)
                let storedChecksum = getStoredChecksum()
                
                print ("🔍 New data checksum: \(String(newChecksum.prefix(8)))...")
                if let stored = storedChecksum {
                    print ("🔍 Stored checksum: \(String(stored.prefix(8)))...")
                } else {
                    print ("🔍 No stored checksum found (first run or missing)")
                }
                
                // Compare checksums to determine if data has changed
                if storedChecksum != newChecksum {
                    print("✅ Data has changed - updating cache and files")
                    dataChanged = true
                    
                    // Write new data to permanent location
                    writeBandFile(httpData)
                    
                    // Store new checksum
                    storeChecksum(newChecksum)
                    
                    print("📝 Successfully updated band data and stored new checksum")
                } else {
                    print("⏭️ Data unchanged - skipping cache rebuild (checksum match)")
                    dataChanged = false
                }
            } else {
                print ("❌ Internet is down or data is invalid, keeping existing data")
                newDataValid = false
                dataChanged = false
            }
        } else if !forceDownload {
            print("📖 gatherData called without forceDownload - only reading from cache")
        } else {
            print("📡 No internet available, keeping existing data")
            newDataValid = false
            dataChanged = false
        }
        
        // Always read the band file (either new or existing)
        readBandFile()
        var isEmpty = false
        staticBandName.sync {
            isEmpty = self.bandNames.isEmpty
        }
        
        // Enhanced retry logic for band data
        if isEmpty && forceDownload {
            print("Band file is empty and forceDownload is true. Attempting retry with enhanced logic.")
            let maxRetries = 3
            var retryCount = 0
            var success = false
            
            while retryCount < maxRetries && !success {
                retryCount += 1
                print("Band data retry attempt \(retryCount)/\(maxRetries)")
                
                if isInternetAvailable() == true {
                    eventYear = Int(getPointerUrlData(keyValue: "eventYear"))!
                    let artistUrl = getPointerUrlData(keyValue: "artistUrl") ?? "http://dropbox.com"
                    print ("Retrying: Getting band data from " + artistUrl + " (attempt \(retryCount))");
                    
                    // Add a small delay between retries
                    if retryCount > 1 {
                        Thread.sleep(forTimeInterval: 1.0)
                    }
                    
                    let httpData = getUrlData(urlString: artistUrl)
                    if (httpData.isEmpty == false && httpData.count > 100) {
                        writeBandFile(httpData);
                        readBandFile()
                        staticBandName.sync {
                            isEmpty = self.bandNames.isEmpty
                        }
                        if !isEmpty {
                            print("Band data loaded successfully on retry \(retryCount), setting justLaunched to false.")
                            cacheVariables.justLaunched = false
                            success = true
                            populateCache(completion: completion)
                            return
                        } else {
                            print("Retry \(retryCount) failed: Data downloaded but file is still empty.")
                        }
                    } else {
                        print("Retry \(retryCount) failed: Internet is down or data is empty/invalid.")
                    }
                } else {
                    print("Retry \(retryCount) failed: No internet connection.")
                }
                
                // Wait before next retry
                if retryCount < maxRetries {
                    Thread.sleep(forTimeInterval: 2.0)
                }
            }
            
            print("No band data available after \(maxRetries) retries. Giving up and calling completion.")
            completion?()
            return
        } else if isEmpty && !forceDownload {
            print("Band file is empty but forceDownload is false. Skipping retry logic.")
        }
        
        // If we have data (either new or existing), proceed
        if !isEmpty {
            print("Band data available (new or existing), setting justLaunched to false.")
            cacheVariables.justLaunched = false
            
            // Only rebuild cache if data actually changed
            if dataChanged {
                print("🔄 Data changed - rebuilding cache")
                populateCache(completion: completion)
                
                // Check if combined image list needs regeneration after artist data is loaded
                print("[CHECKSUM_DEBUG] Artist data changed, checking if combined image list needs regeneration")
                let scheduleHandle = scheduleHandler.shared
                if CombinedImageListHandler.shared.needsRegeneration(bandNameHandle: self, scheduleHandle: scheduleHandle) {
                    print("[CHECKSUM_DEBUG] Regenerating combined image list due to changed artist data")
                    CombinedImageListHandler.shared.generateCombinedImageList(
                        bandNameHandle: self,
                        scheduleHandle: scheduleHandle
                    ) {
                        print("[YEAR_CHANGE_DEBUG] Combined image list regenerated after artist data load")
                    }
                }
            } else {
                print("⏭️ Data unchanged - using existing cache")
                // Data hasn't changed, just call completion
                completion?()
            }
        } else if !cacheVariables.justLaunched {
            print("Skipping cache population: bandNames is empty and app is not just launched.")
            isLoadingBandData = false
            completion?()
        } else {
            print("No band data available and app just launched. Calling completion.")
            isLoadingBandData = false
            completion?()
        }
        
        // Reset loading flag at the end
        isLoadingBandData = false
    }

    /// Populates the static cache variables with the current bandNames dictionary.
    /// Posts a notification when the cache is ready and calls the completion handler.
    func populateCache(completion: (() -> Void)? = nil){
        print ("Starting population of acheVariables.bandNamesStaticCache")
        staticBandName.async(flags: .barrier) {
            cacheVariables.bandNamesStaticCache =  [String :[String : String]]()
            cacheVariables.bandNamesArrayStaticCache = [String]()
            // Read bandNames and bandNamesArray inside the queue
            for bandName in self.bandNames.keys {
                cacheVariables.bandNamesStaticCache[bandName] =  [String : String]()
                cacheVariables.bandNamesStaticCache[bandName] =  self.bandNames[bandName]
                print ("Adding Data to cacheVariables.bandNamesStaticCache = \(String(describing: cacheVariables.bandNamesStaticCache[bandName]))")
                cacheVariables.bandNamesArrayStaticCache.append(bandName)
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .bandNamesCacheReady, object: nil)
                
                // Safely check if combined image list needs refresh (delayed to avoid deadlock)
                CombinedImageListHandler.shared.checkAndRefreshWhenReady()
                
                completion?()
            }
        }
    }
    
    /// Writes the provided HTTP data string to the band file on disk.
    /// - Parameter httpData: The string data to write to file.
    func writeBandFile (_ httpData: String){
        
        print("write file " + bandFile);
        print (httpData);

        do {
           try httpData.write(toFile: bandFile, atomically: true,encoding: String.Encoding.utf8)
            print ("Just created file bandFile " + bandFile);
        } catch let error as NSError {
            print ("Encountered an error of creating file " + error.debugDescription)
        }
        
    }

    // Add at the top of the class (or where readingBandFile is declared):
    private let readingBandFileQueue = DispatchQueue(label: "com.yourapp.readingBandFileQueue")
    private var _readingBandFile: Bool = false
    var readingBandFile: Bool {
        get { return readingBandFileQueue.sync { _readingBandFile } }
        set { readingBandFileQueue.sync { _readingBandFile = newValue } }
    }

    // Add a recursion/loop guard
    // Change these from private static to static so they are accessible from MasterViewController
    static var readBandFileCallCount = 0
    static var lastReadBandFileCallTime: Date? = nil

    /// Reads the band file from disk and populates the bandNames and bandNamesArray dictionaries.
    /// Handles parsing of CSV data and extraction of band properties.
    func readBandFile (){
        let now = Date()
        if let last = Self.lastReadBandFileCallTime, now.timeIntervalSince(last) < 2 {
            Self.readBandFileCallCount += 1
        } else {
            Self.readBandFileCallCount = 1
        }
        Self.lastReadBandFileCallTime = now
        print("readBandFile called ( Self.readBandFileCallCount) at \(now)")
        if Self.readBandFileCallCount > 10 {
            print("Aborting: readBandFile called too many times in a short period. Possible infinite loop.")
            return
        }
        if readingBandFile == false{
            readingBandFile = true
            print ("Loading bandName Data readBandFile")
            print ("Reading content of file " + bandFile);
            if let csvDataString = try? String(contentsOfFile: bandFile, encoding: String.Encoding.utf8) {
                print("csvDataString has data", terminator: "");
                // Write access: must use barrier
                staticBandName.async(flags: .barrier) {
                    self.bandNames =  [String :[String : String]]()
                    self.bandNamesArray = [String]()
                    var csvData: CSV
                    if let csvData = try? CSV(csvStringToParse: csvDataString) {
                        for lineData in csvData.rows {
                            if (lineData["bandName"]?.isEmpty == false){
                                print ("Working on band " + lineData["bandName"]!)
                                let bandNameValue = lineData["bandName"]!
                                self.bandNames[bandNameValue] = [String : String]()
                                self.bandNames[bandNameValue]! ["bandName"] = bandNameValue
                                if (lineData.isEmpty == false){
                                    if (lineData["imageUrl"] != nil){
                                        self.bandNames[bandNameValue]! ["bandImageUrl"] = "http://" + lineData["imageUrl"]!;
                                    }
                                    if (lineData["officalSite"] != nil){
                                        if (lineData["bandName"] != nil){
                                            self.bandNames[bandNameValue]! ["officalUrls"] = "http://" + lineData["officalSite"]!;
                                        }
                                    }
                                    if (lineData["wikipedia"] != nil){
                                        self.bandNames[bandNameValue]! ["wikipediaLink"] = lineData["wikipedia"]!;
                                    }
                                    if (lineData["youtube"] != nil){
                                        self.bandNames[bandNameValue]! ["youtubeLinks"] = lineData["youtube"]!;
                                    }
                                    if (lineData["metalArchives"] != nil){
                                        self.bandNames[bandNameValue]! ["metalArchiveLinks"] = lineData["metalArchives"]!;
                                    }
                                    if (lineData["country"] != nil){
                                        self.bandNames[bandNameValue]! ["bandCountry"] = lineData["country"]!;
                                    }
                                    if (lineData["genre"] != nil){
                                        self.bandNames[bandNameValue]! ["bandGenre"] = lineData["genre"]!;
                                    }
                                    if (lineData["noteworthy"] != nil){
                                        self.bandNames[bandNameValue]! ["bandNoteWorthy"] = lineData["noteworthy"]!;
                                    }
                                    if (lineData["priorYears"] != nil){
                                        self.bandNames[bandNameValue]! ["priorYears"] = lineData["priorYears"]!;
                                    }
                                }
                                self.bandNamesArray.append(bandNameValue)
                            }
                        }
                    } else {
                        print("Error: Failed to parse CSV data in readBandFile.")
                    }
                }
            } else {
                // Handle missing bandFile gracefully - this is expected on first install
                if !FileManager.default.fileExists(atPath: bandFile) {
                    print("Band file does not exist yet - this is normal for first app launch. Will attempt to download from network.")
                } else {
                    print("Band file exists but could not be read - checking for file access issues")
                    do {
                        try NSString(contentsOfFile: bandFile, encoding: String.Encoding.utf8.rawValue)
                    } catch let error as NSError {
                        print("Error reading existing band file: \(error.localizedDescription)")
                    }
                }
            }
            readingBandFile = false
        }
        // After band names data is loaded and parsed:
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("BandNamesDataReady"), object: nil)
        }
    }

    /// Force read the band file and populate cache, bypassing the recursion/loop guard
    func forceReadBandFileAndPopulateCache(completion: (() -> Void)? = nil) {
        self._readingBandFile = true
        self.readBandFile()
        self._readingBandFile = false
        self.populateCache(completion: completion)
    }

    /// Returns a sorted array of all band names. Loads from cache if necessary.
    /// - Returns: An array of band name strings.
    func getBandNames () -> [String] {
        var result: [String] = []
        var needsCache = false
        staticBandName.sync {
            if self.bandNames.isEmpty {
                needsCache = true
            } else {
                result = Array(self.bandNames.keys).sorted()
            }
        }
        if needsCache {
            getCachedData()
            // After loading, try again to get the result
            staticBandName.sync {
                result = Array(self.bandNames.keys).sorted()
            }
        }
        print ("bandNamesArray data is \(result)")
        return result
    }

    /// Returns the image URL for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The image URL string.
    func getBandImageUrl(_ band: String) -> String {
        var result = ""
        staticBandName.sync {
            result = self.bandNames[band]?["bandImageUrl"] ?? ""
        }
        print ("🔗 URL lookup for band \(band): \(result.isEmpty ? "no URL available" : result)")
        return result
    }

    /// Returns the official website URL for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The official website URL string.
    func getofficalPage (_ band: String) -> String {
        var result = ""
        staticBandName.sync {
            result = self.bandNames[band]?["officalUrls"] ?? ""
        }
        print ("Getting officalSite for band \(band) will return \(result)")
        return result
    }

    /// Returns the Wikipedia page URL for a given band, localized to the user's language if possible.
    /// - Parameter bandName: The name of the band.
    /// - Returns: The Wikipedia URL string.
    func getWikipediaPage (_ bandName: String) -> String{
        var wikipediaUrl = ""
        staticBandName.sync {
            wikipediaUrl = self.bandNames[bandName]?["wikipediaLink"] ?? ""
        }
        if (wikipediaUrl.isEmpty == false){
            let language: String = Locale.current.languageCode!
            print ("Language is " + language);
            if (language != "en"){
                let replacement: String = language + ".wikipedia.org";
                wikipediaUrl = wikipediaUrl.replacingOccurrences(of: "en.wikipedia.org", with:replacement)
            }
        }
        return (wikipediaUrl)
    }
    
    /// Returns the YouTube page URL for a given band, localized to the user's language if possible.
    /// - Parameter bandName: The name of the band.
    /// - Returns: The YouTube URL string.
    func getYouTubePage (_ bandName: String) -> String{
        var youTubeUrl = ""
        staticBandName.sync {
            youTubeUrl = self.bandNames[bandName]?["youtubeLinks"] ?? ""
        }
        if (youTubeUrl.isEmpty == false){
            let language: String = Locale.preferredLanguages[0]
            if (language != "en"){
                youTubeUrl = youTubeUrl + "&hl=" + language
            }
        }
        return (youTubeUrl)
    }
    
    /// Returns the Metal Archives URL for a given band, or an empty string if not found.
    /// - Parameter bandName: The name of the band.
    /// - Returns: The Metal Archives URL string.
    func getMetalArchives (_ bandName: String) -> String {
        var result = ""
        staticBandName.sync {
            result = self.bandNames[bandName]?["metalArchiveLinks"] ?? ""
        }
        return result
    }
    
    /// Returns the country for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The country string.
    func getBandCountry (_ band: String) -> String {
        var result = ""
        staticBandName.sync {
            result = self.bandNames[band]?["bandCountry"] ?? ""
        }
        return result
    }
    
    /// Returns the genre for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The genre string.
    func getBandGenre (_ band: String) -> String {
        var result = ""
        staticBandName.sync {
            result = self.bandNames[band]?["bandGenre"] ?? ""
        }
        return result
    }

    /// Returns the 'noteworthy' field for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The noteworthy string.
    func getBandNoteWorthy (_ band: String) -> String {
        var result = ""
        staticBandName.sync {
            result = self.bandNames[band]?["bandNoteWorthy"] ?? ""
        }
        return result
    }

    /// Returns a comma-separated string of prior years for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The prior years string.
    func getPriorYears (_ band: String) -> String {
        var previousYears: String? = nil
        staticBandName.sync {
            previousYears = self.bandNames[band]?["priorYears"]
        }
        previousYears = previousYears?.replacingOccurrences(of: " ", with: ", ")
        return previousYears ?? ""
    }
}

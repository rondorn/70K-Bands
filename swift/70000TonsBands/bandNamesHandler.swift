//
//  bandNames.swift
//  70000TonsApp
//
//  Created by Ron Dorn on 12/23/14.
//  Copyright (c) 2014 Ron Dorn. All rights reserved.
//

import Foundation

open class bandNamesHandler {

    // MARK: - Singleton
    static let shared = bandNamesHandler()
    
    // MARK: - Static state tracking
    private static var isGatheringData = false
    private static var dataLoadingTriggered = false
    private static var lastDataLoadingTime: TimeInterval = 0
    private static let dataLoadingTimeout: TimeInterval = 60 // 60 seconds timeout
    private static var globalTimeoutWorkItem: DispatchWorkItem?
    private static var infiniteLoopDetected = false
    private static var infiniteLoopStartTime: TimeInterval = 0
    private static var circuitBreakerTripped = false
    private static var circuitBreakerTripTime: TimeInterval = 0
    
    var bandNames =  [String :[String : String]]()
    var bandNamesArray = [String]()
    
    // MARK: - Private Initializer
    private init(){
        print ("Loading bandName Data")
        getCachedData()
    }
    
    /// Loads band name data from cache if available, otherwise loads from disk or Dropbox.
    func getCachedData(completion: (() -> Void)? = nil){
        print("[BAND_DEBUG] getCachedData: START")
        
        // Add timeout to prevent infinite loops
        let timeoutWorkItem = DispatchWorkItem {
            print("[BAND_DEBUG] getCachedData: TIMEOUT - calling completion after 30s")
            // Reset static flags on timeout to prevent infinite loops
            bandNamesHandler.isGatheringData = false
            bandNamesHandler.dataLoadingTriggered = false
            completion?()
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: timeoutWorkItem)
        
        staticBandName.sync() {
            print("[BAND_DEBUG] getCachedData: Cache check - bandNamesStaticCache: \(cacheVariables.bandNamesStaticCache.count), bandNamesArrayStaticCache: \(cacheVariables.bandNamesArrayStaticCache.count)")
            if (cacheVariables.bandNamesStaticCache.isEmpty == false && cacheVariables.bandNamesArrayStaticCache.isEmpty == false ){
                print("[BAND_DEBUG] getCachedData: Loading from cache")
                bandNames = cacheVariables.bandNamesStaticCache
                bandNamesArray = cacheVariables.bandNamesArrayStaticCache
                print("[BAND_DEBUG] getCachedData: END (from cache) - bandNames: \(bandNames.count), bandNamesArray: \(bandNamesArray.count)")
                timeoutWorkItem.cancel()
                // Reset static flags when loading from cache
                bandNamesHandler.isGatheringData = false
                bandNamesHandler.dataLoadingTriggered = false
                bandNamesHandler.cancelGlobalTimeout()
                completion?()
            } else {
                DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                    print("[BAND_DEBUG] getCachedData: Loading from disk or dropbox")
                    self.gatherData(completion: {
                        timeoutWorkItem.cancel()
                        // Reset static flags when data loading completes
                        bandNamesHandler.isGatheringData = false
                        bandNamesHandler.dataLoadingTriggered = false
                        bandNamesHandler.cancelGlobalTimeout()
                        completion?()
                    })
                }
            }
        }
        print("[BAND_DEBUG] getCachedData: EXIT")
    }
    
    /// Clears the static cache of band names.
    func clearCachedData(){
        cacheVariables.bandNamesStaticCache = [String :[String : String]]()
    }
    
    /// Gathers band data from the internet if available, writes it to file, and populates the cache.
    /// Calls completion handler when done.
    func gatherData(completion: (() -> Void)? = nil) {
        print("[BAND_DEBUG] gatherData: START - isInternetAvailable: \(isInternetAvailable())")
        
        // Prevent multiple simultaneous calls to gatherData
        if bandNamesHandler.isGatheringData {
            print("[BAND_DEBUG] gatherData: Already gathering data, skipping duplicate call")
            completion?()
            return
        }
        bandNamesHandler.isGatheringData = true
        
        var didCallCompletion = false
        let timeoutWorkItem = DispatchWorkItem {
            if !didCallCompletion {
                print("[BAND_DEBUG] gatherData: TIMEOUT - calling completion fallback after 10s")
                didCallCompletion = true
                bandNamesHandler.isGatheringData = false
                bandNamesHandler.dataLoadingTriggered = false
                bandNamesHandler.cancelGlobalTimeout()
                completion?()
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 10, execute: timeoutWorkItem)
        if isInternetAvailable() == true {
            eventYear = Int(getPointerUrlData(keyValue: "eventYear"))!
            print ("[BAND_DEBUG] Loading bandName Data gatherData")
            var artistUrl = getPointerUrlData(keyValue: "artistUrl") ?? "http://dropbox.com"
            print ("[BAND_DEBUG] Getting band data from " + artistUrl);
            print ("[BAND_DEBUG] artistUrl is empty: \(artistUrl.isEmpty)");
            let httpData = getUrlData(urlString: artistUrl)
            print ("[BAND_DEBUG] Getting band data of length: \(httpData.count)");
            print ("[BAND_DEBUG] httpData preview: \(String(httpData.prefix(200)))");
            if (httpData.isEmpty == false) {
                writeBandFile(httpData);
            } else {
                print ("[BAND_DEBUG] Internet is down, prevented blanking out data")
                // Try to use local CSV file as fallback
                loadLocalCSVFallback()
            }
        } else {
            // No internet, try local CSV fallback
            print ("[BAND_DEBUG] No internet available, trying local CSV fallback")
            loadLocalCSVFallback()
        }
        readBandFile()
        // Defensive type check for bandNames
        if let bandNamesDict = bandNames as? [String: [String: String]] {
            if bandNamesDict.isEmpty && !cacheVariables.justLaunched {
                print("[BAND_DEBUG] gatherData: Skipping cache population: bandNames is empty and app is not just launched.")
                if !didCallCompletion {
                    didCallCompletion = true
                    timeoutWorkItem.cancel()
                    bandNamesHandler.isGatheringData = false
                    bandNamesHandler.cancelGlobalTimeout()
                    completion?()
                }
                print("[BAND_DEBUG] gatherData: END (empty bandNames)")
                return
            }
        } else {
            print("[BAND_DEBUG] ERROR: bandNames is not a dictionary! Actual type: \(type(of: bandNames)) Value: \(bandNames)")
            bandNames = [String: [String: String]]()
            if !didCallCompletion {
                didCallCompletion = true
                timeoutWorkItem.cancel()
                bandNamesHandler.isGatheringData = false
                bandNamesHandler.cancelGlobalTimeout()
                completion?()
            }
            print("[BAND_DEBUG] gatherData: END (bad type)")
            return
        }
        populateCache {
            if !didCallCompletion {
                didCallCompletion = true
                timeoutWorkItem.cancel()
                bandNamesHandler.isGatheringData = false
                bandNamesHandler.cancelGlobalTimeout()
                print("[BAND_DEBUG] gatherData: END (populateCache complete)")
                completion?()
            }
        }
    }

    /// Populates the static cache variables with the current bandNames dictionary.
    /// Posts a notification when the cache is ready and calls the completion handler.
    func populateCache(completion: (() -> Void)? = nil){
        print("[BAND_DEBUG] populateCache: START")
        staticBandName.async(flags: .barrier) {
            // Defensive: Check if bandNames is valid before proceeding
            guard self.bandNames is [String: [String: String]] else {
                print("[BAND_DEBUG] ERROR: bandNames is corrupted in populateCache, type: \(type(of: self.bandNames))")
                DispatchQueue.main.async {
                    print("[BAND_DEBUG] populateCache: END (error - corrupted bandNames)")
                    completion?()
                }
                return
            }
            
            // Defensive: Create a safe copy of the keys to iterate over
            let bandNamesKeys: [String]
            do {
                bandNamesKeys = Array(self.bandNames.keys)
            } catch {
                print("[BAND_DEBUG] ERROR: Failed to get bandNames keys: \(error)")
                DispatchQueue.main.async {
                    print("[BAND_DEBUG] populateCache: END (error - failed to get keys)")
                    completion?()
                }
                return
            }
            
            cacheVariables.bandNamesStaticCache =  [String :[String : String]]()
            cacheVariables.bandNamesArrayStaticCache = [String]()
            
            for bandName in bandNamesKeys {
                // Defensive: Check if the key still exists and is valid
                guard let bandDict = self.bandNames[bandName] as? [String: String] else {
                    print("[BAND_DEBUG] Warning: bandNames[\(bandName)] is not a [String: String]: \(String(describing: self.bandNames[bandName]))")
                    continue
                }
                
                // Defensive: Validate the band dictionary before adding
                if !bandDict.isEmpty {
                    cacheVariables.bandNamesStaticCache[bandName] = bandDict
                    cacheVariables.bandNamesArrayStaticCache.append(bandName)
                } else {
                    print("[BAND_DEBUG] Warning: Empty band dictionary for \(bandName)")
                }
            }
            
            DispatchQueue.main.async {
                print("[BAND_DEBUG] populateCache: END (cache ready) - cached \(cacheVariables.bandNamesArrayStaticCache.count) bands")
                NotificationCenter.default.post(name: .bandNamesCacheReady, object: nil)
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


    /// Loads band data from local CSV files as a fallback when network data is unavailable.
    /// Tries to find the appropriate CSV file based on the current event year.
    func loadLocalCSVFallback() {
        print("[BAND_DEBUG] loadLocalCSVFallback: START")
        
        // Get the current event year
        let currentYear = String(eventYear)
        print("[BAND_DEBUG] loadLocalCSVFallback: Current year = \(currentYear)")
        
        // Try to find the appropriate CSV file
        let possibleFiles = [
            "artistLineup\(currentYear).csv",
            "artistLineup_\(currentYear).csv",
            "artistLineup2024.csv", // Fallback to 2024 if current year not found
            "artistLineup_2024.csv"
        ]
        
        var csvData: String?
        
        // Get the bundle path for the CSV files
        if let bundlePath = Bundle.main.path(forResource: "dataFiles", ofType: nil) {
            for fileName in possibleFiles {
                let filePath = bundlePath + "/" + fileName
                print("[BAND_DEBUG] loadLocalCSVFallback: Trying file \(filePath)")
                
                if FileManager.default.fileExists(atPath: filePath) {
                    do {
                        csvData = try String(contentsOfFile: filePath, encoding: .utf8)
                        print("[BAND_DEBUG] loadLocalCSVFallback: Found and loaded \(fileName) with \(csvData?.count ?? 0) characters")
                        break
                    } catch {
                        print("[BAND_DEBUG] loadLocalCSVFallback: Error reading \(fileName): \(error)")
                    }
                } else {
                    print("[BAND_DEBUG] loadLocalCSVFallback: File does not exist: \(filePath)")
                }
            }
        }
        
        if let csvData = csvData {
            print("[BAND_DEBUG] loadLocalCSVFallback: Writing CSV data to band file")
            writeBandFile(csvData)
        } else {
            print("[BAND_DEBUG] loadLocalCSVFallback: No local CSV file found")
        }
        
        print("[BAND_DEBUG] loadLocalCSVFallback: END")
    }

    /// Reads the band file from disk and populates the bandNames and bandNamesArray dictionaries.
    /// Handles parsing of CSV data and extraction of band properties.
    func readBandFile (){
        
        if (readingBandFile == false){
            readingBandFile = true
            print ("[BAND_DEBUG] Loading bandName Data readBandFile")
            print ("[BAND_DEBUG] Reading content of file " + bandFile);
            print ("[BAND_DEBUG] File exists: \(FileManager.default.fileExists(atPath: bandFile))")
            
            var processedBands = 0
            
            // Defensive: Create a temporary dictionary to avoid corruption
            var tempBandNames = [String: [String: String]]()
            var tempBandNamesArray = [String]()
            
            if let csvDataString = try? String(contentsOfFile: bandFile, encoding: String.Encoding.utf8) {
                print("[BAND_DEBUG] csvDataString has data - length: \(csvDataString.count)", terminator: "");
                print("[BAND_DEBUG] csvDataString preview: \(String(csvDataString.prefix(200)))")
                
                //var unuiqueIndex = Dictionary<NSTimeInterval, Int>()
                var csvData: CSV
                
                //var error: NSErrorPointer = nil
                csvData = try! CSV(csvStringToParse: csvDataString)
                
                print("[BAND_DEBUG] Processing \(csvData.rows.count) rows from CSV")
                for lineData in csvData.rows {
                    
                    if (lineData["bandName"]?.isEmpty == false){
                        print ("[BAND_DEBUG] Working on band " + lineData["bandName"]!)
                        processedBands += 1
                        
                        guard let bandNameValue = lineData["bandName"], !bandNameValue.isEmpty else {
                            print("[BAND_DEBUG] Skipping band with empty or missing bandName")
                            continue
                        }
                        
                        // Initialize the band entry safely in temporary dictionary
                        tempBandNames[bandNameValue] = [String : String]()
                        
                        // Safely add the band name
                        tempBandNames[bandNameValue]?["bandName"] = bandNameValue
                        
                        if (lineData.isEmpty == false){
                            if let value = lineData["imageUrl"], !value.isEmpty {
                                tempBandNames[bandNameValue]?["bandImageUrl"] = "http://" + String(describing: value)
                            }
                            if let value = lineData["officalSite"], !value.isEmpty {
                                tempBandNames[bandNameValue]?["officalUrls"] = "http://" + String(describing: value)
                            }
                            if let value = lineData["wikipedia"], !value.isEmpty {
                                tempBandNames[bandNameValue]?["wikipediaLink"] = String(describing: value)
                            }
                            if let value = lineData["youtube"], !value.isEmpty {
                                tempBandNames[bandNameValue]?["youtubeLinks"] = String(describing: value)
                            }
                            if let value = lineData["metalArchives"], !value.isEmpty {
                                tempBandNames[bandNameValue]?["metalArchiveLinks"] = String(describing: value)
                            }
                            if let value = lineData["country"], !value.isEmpty {
                                tempBandNames[bandNameValue]?["bandCountry"] = String(describing: value)
                            }
                            if let value = lineData["genre"], !value.isEmpty {
                                tempBandNames[bandNameValue]?["bandGenre"] = String(describing: value)
                            }
                            if let value = lineData["noteworthy"], !value.isEmpty {
                                tempBandNames[bandNameValue]?["bandNoteWorthy"] = String(describing: value)
                            }
                            if let value = lineData["priorYears"], !value.isEmpty {
                                tempBandNames[bandNameValue]?["priorYears"] = String(describing: value)
                            }
                        }
                    }
                }
                
            } else {
                print ("Could not read file for some reason");
                do {
                    try NSString(contentsOfFile: bandFile, encoding: String.Encoding.utf8.rawValue)
                    
                } catch let error as NSError {
                    print ("Encountered an error on reading file" + error.debugDescription)
                }
            }
            
            // Defensive: Only update the main dictionaries if we have valid data
            if !tempBandNames.isEmpty {
                // Thread-safe update of the main dictionaries
                staticBandName.async(flags: .barrier) {
                    self.bandNames = tempBandNames
                    self.bandNamesArray = Array(tempBandNames.keys)
                }
            } else {
                print("[BAND_DEBUG] Warning: No valid band data to update")
            }
            
            print("[BAND_DEBUG] readBandFile: Processed \(processedBands) bands, final bandNames count: \(tempBandNames.count)")
            readingBandFile = false
        }
    }

    /// Returns a sorted array of all band names. Thread-safe version that uses cached data.
    /// - Returns: An array of band name strings.
    func getBandNames () -> [String] {
        
        // Use thread-safe cache access
        return staticBandName.sync {
            print("[BAND_DEBUG] getBandNames: Called - cache count: \(cacheVariables.bandNamesArrayStaticCache.count), instance count: \(bandNames.count)")
            
            // Return cached data if available
            if !cacheVariables.bandNamesArrayStaticCache.isEmpty {
                print("[BAND_DEBUG] getBandNames: Returning cached data with \(cacheVariables.bandNamesArrayStaticCache.count) bands")
                return cacheVariables.bandNamesArrayStaticCache.sorted()
            }
            
            // If no cached data, return current instance data (non-blocking)
            if !bandNames.isEmpty {
                let bandNamesArray = Array(bandNames.keys).sorted()
                print("[BAND_DEBUG] getBandNames: Returning instance data with \(bandNamesArray.count) bands")
                return bandNamesArray
            }
            
            // Prevent infinite loop: if we're already loading data, just return empty array
            if readingBandFile {
                print("[BAND_DEBUG] getBandNames: Data loading in progress, returning empty array to prevent infinite loop")
                return []
            }
            
            // Prevent infinite loop: check if we've already triggered data loading
            if bandNamesHandler.dataLoadingTriggered {
                print("[BAND_DEBUG] getBandNames: Data loading already triggered, returning empty array to prevent infinite loop")
                return []
            }
            
            // Prevent infinite loop: check if we're already gathering data
            if bandNamesHandler.isGatheringData {
                print("[BAND_DEBUG] getBandNames: Data gathering already in progress, returning empty array to prevent infinite loop")
                return []
            }
            
            // Check for timeout: if data loading has been triggered but not completed for too long, reset flags
            let currentTime = Date().timeIntervalSince1970
            if bandNamesHandler.dataLoadingTriggered && (currentTime - bandNamesHandler.lastDataLoadingTime) > 10.0 { // Reduced timeout to 10 seconds
                print("[BAND_DEBUG] getBandNames: Data loading timeout detected, resetting flags")
                bandNamesHandler.isGatheringData = false
                bandNamesHandler.dataLoadingTriggered = false
                bandNamesHandler.circuitBreakerTripped = true
                bandNamesHandler.circuitBreakerTripTime = currentTime
            }
            
            // AGGRESSIVE INFINITE LOOP DETECTION
            if bandNamesHandler.infiniteLoopDetected {
                print("[BAND_DEBUG] getBandNames: INFINITE LOOP DETECTED - returning empty array immediately")
                return []
            }
            
            // EMERGENCY STOP - if we've been called more than 50 times in the last second, stop immediately
            var emergencyCallCount = 0
            var emergencyStartTime: TimeInterval = 0
            emergencyCallCount += 1
            if emergencyStartTime == 0 {
                emergencyStartTime = currentTime
            }
            if currentTime - emergencyStartTime < 1.0 && emergencyCallCount > 50 {
                print("[BAND_DEBUG] getBandNames: EMERGENCY STOP - too many calls in 1 second")
                bandNamesHandler.infiniteLoopDetected = true
                bandNamesHandler.circuitBreakerTripped = true
                bandNamesHandler.circuitBreakerTripTime = currentTime
                return []
            }
            if currentTime - emergencyStartTime > 5.0 {
                // Reset emergency counters after 5 seconds
                emergencyCallCount = 0
                emergencyStartTime = 0
            }
            
            // Check for rapid repeated calls (infinite loop pattern)
            if bandNamesHandler.dataLoadingTriggered {
                let timeSinceStart = currentTime - bandNamesHandler.infiniteLoopStartTime
                if timeSinceStart > 1.0 { // 1 second of rapid calls = infinite loop (very aggressive)
                    print("[BAND_DEBUG] getBandNames: INFINITE LOOP DETECTED after 1 second - stopping immediately")
                    bandNamesHandler.infiniteLoopDetected = true
                    bandNamesHandler.isGatheringData = false
                    bandNamesHandler.dataLoadingTriggered = false
                    bandNamesHandler.circuitBreakerTripped = true
                    bandNamesHandler.circuitBreakerTripTime = currentTime
                    return []
                }
            } else {
                bandNamesHandler.infiniteLoopStartTime = currentTime
            }
            
            // ADDITIONAL EMERGENCY STOP - if we've been called too many times in a short period
            var callCount = 0
            var lastCallTime: TimeInterval = 0
            callCount += 1
            if currentTime - lastCallTime < 0.1 && callCount > 10 { // More than 10 calls in 0.1 seconds
                print("[BAND_DEBUG] getBandNames: EMERGENCY STOP - too many rapid calls")
                bandNamesHandler.infiniteLoopDetected = true
                bandNamesHandler.isGatheringData = false
                bandNamesHandler.dataLoadingTriggered = false
                bandNamesHandler.circuitBreakerTripped = true
                bandNamesHandler.circuitBreakerTripTime = currentTime
                return []
            }
            lastCallTime = currentTime
            
            // CIRCUIT BREAKER PATTERN - if we've had too many failures, stop trying
            if bandNamesHandler.circuitBreakerTripped {
                let timeSinceTrip = currentTime - bandNamesHandler.circuitBreakerTripTime
                if timeSinceTrip < 60 { // 1 minute circuit breaker (reduced from 5 minutes)
                    print("[BAND_DEBUG] getBandNames: CIRCUIT BREAKER ACTIVE - returning empty array")
                    return []
                } else {
                    // Reset circuit breaker after 1 minute
                    bandNamesHandler.circuitBreakerTripped = false
                    bandNamesHandler.infiniteLoopDetected = false
                    print("[BAND_DEBUG] getBandNames: Circuit breaker reset")
                }
            }
            
            // No data available, trigger data loading
            print("[BAND_DEBUG] getBandNames: No data available, triggering data loading")
            bandNamesHandler.dataLoadingTriggered = true
            bandNamesHandler.lastDataLoadingTime = currentTime
            
            // Start global timeout to prevent infinite loops
            bandNamesHandler.startGlobalTimeout()
            
            // Trigger data loading asynchronously
            DispatchQueue.global().async {
                self.getCachedData {
                    bandNamesHandler.dataLoadingTriggered = false
                }
            }
            
            return []
        }
    }

    /// Returns a snapshot (copy) of the bandNames dictionary for thread-safe background use.
    /// Thread-safe version that uses cached data.
    func getBandNamesSnapshot() -> [String: [String: String]] {
        return staticBandName.sync {
            // Return cached data if available
            if !cacheVariables.bandNamesStaticCache.isEmpty {
                print("[BAND_DEBUG] getBandNamesSnapshot: Returning cached data with \(cacheVariables.bandNamesStaticCache.count) bands")
                return cacheVariables.bandNamesStaticCache
            }
            
            // Fall back to instance data
            print("[BAND_DEBUG] getBandNamesSnapshot: Returning instance data with \(bandNames.count) bands")
            return bandNames
        }
    }

    /// Returns the image URL for a given band, or an empty string if not found.
    /// Thread-safe version that uses cached data.
    /// - Parameter band: The name of the band.
    /// - Returns: The image URL string.
    func getBandImageUrl(_ band: String) -> String {
        
        return staticBandName.sync {
            // Try cached data first
            if let cachedBandData = cacheVariables.bandNamesStaticCache[band] {
                let imageUrl = cachedBandData["bandImageUrl"] ?? ""
                print("[BAND_DEBUG] getBandImageUrl: Returning cached data for \(band): \(imageUrl)")
                return imageUrl
            }
            
            // Fall back to instance data
            let imageUrl = bandNames[band]?["bandImageUrl"] ?? ""
            print("[BAND_DEBUG] getBandImageUrl: Returning instance data for \(band): \(imageUrl)")
            
            // If no image URL found, try case-insensitive lookup
            if imageUrl.isEmpty {
                print("[BAND_DEBUG] getBandImageUrl: No image URL found for '\(band)', trying case-insensitive lookup")
                
                // Try case-insensitive lookup in cached data
                for (cachedBand, cachedData) in cacheVariables.bandNamesStaticCache {
                    if cachedBand.localizedCaseInsensitiveCompare(band) == .orderedSame {
                        let caseInsensitiveImageUrl = cachedData["bandImageUrl"] ?? ""
                        print("[BAND_DEBUG] getBandImageUrl: Found case-insensitive match in cache: '\(cachedBand)' -> \(caseInsensitiveImageUrl)")
                        return caseInsensitiveImageUrl
                    }
                }
                
                // Try case-insensitive lookup in instance data
                for (instanceBand, instanceData) in bandNames {
                    if instanceBand.localizedCaseInsensitiveCompare(band) == .orderedSame {
                        let caseInsensitiveImageUrl = instanceData["bandImageUrl"] ?? ""
                        print("getBandImageUrl: Found case-insensitive match in instance: '\(instanceBand)' -> \(caseInsensitiveImageUrl)")
                        return caseInsensitiveImageUrl
                    }
                }
                
                // Debug: If still no image URL found, check what bands are available
                print("[BAND_DEBUG] getBandImageUrl: No image URL found for '\(band)' (case-sensitive or case-insensitive)")
                print("[BAND_DEBUG] getBandImageUrl: Available bands in cache: \(Array(cacheVariables.bandNamesStaticCache.keys))")
                print("[BAND_DEBUG] getBandImageUrl: Available bands in instance: \(Array(bandNames.keys))")
            }
            
            return imageUrl
        }
    }

    /// Returns the official website URL for a given band, or an empty string if not found.
    /// Thread-safe version that uses cached data.
    /// - Parameter band: The name of the band.
    /// - Returns: The official website URL string.
    func getofficalPage (_ band: String) -> String {
        
        return staticBandName.sync {
            // Try cached data first
            if let cachedBandData = cacheVariables.bandNamesStaticCache[band] {
                let officialUrl = cachedBandData["officalUrls"] ?? ""
                print("getofficalPage: Returning cached data for \(band): \(officialUrl)")
                return officialUrl
            }
            
            // Fall back to instance data
            let officialUrl = bandNames[band]?["officalUrls"] ?? ""
            print("getofficalPage: Returning instance data for \(band): \(officialUrl)")
            return officialUrl
        }
        
    }

    /// Returns the Wikipedia page URL for a given band, localized to the user's language if possible.
    /// Thread-safe version that uses cached data.
    /// - Parameter bandName: The name of the band.
    /// - Returns: The Wikipedia URL string.
    func getWikipediaPage (_ bandName: String) -> String{
        
        return staticBandName.sync {
            // Try cached data first
            var wikipediaUrl = ""
            if let cachedBandData = cacheVariables.bandNamesStaticCache[bandName] {
                wikipediaUrl = cachedBandData["wikipediaLink"] ?? ""
                print("getWikipediaPage: Returning cached data for \(bandName): \(wikipediaUrl)")
            } else {
                // Fall back to instance data
                wikipediaUrl = bandNames[bandName]?["wikipediaLink"] ?? ""
                print("getWikipediaPage: Returning instance data for \(bandName): \(wikipediaUrl)")
            }
            
            if (wikipediaUrl.isEmpty == false){
                let language: String = Locale.current.languageCode!
                
                print ("Language is " + language);
                if (language != "en"){
                    let replacement: String = language + ".wikipedia.org";
                    
                    wikipediaUrl = wikipediaUrl.replacingOccurrences(of: "en.wikipedia.org", with:replacement)
                }
            }
            
            return wikipediaUrl
        }
        
    }
    
    /// Returns the YouTube page URL for a given band, localized to the user's language if possible.
    /// Thread-safe version that uses cached data.
    /// - Parameter bandName: The name of the band.
    /// - Returns: The YouTube URL string.
    func getYouTubePage (_ bandName: String) -> String{
        
        return staticBandName.sync {
            // Try cached data first
            var youTubeUrl = ""
            if let cachedBandData = cacheVariables.bandNamesStaticCache[bandName] {
                youTubeUrl = cachedBandData["youtubeLinks"] ?? ""
                print("getYouTubePage: Returning cached data for \(bandName): \(youTubeUrl)")
            } else {
                // Fall back to instance data
                youTubeUrl = bandNames[bandName]?["youtubeLinks"] ?? ""
                print("getYouTubePage: Returning instance data for \(bandName): \(youTubeUrl)")
            }
            
            if (youTubeUrl.isEmpty == false){
                let language: String = Locale.preferredLanguages[0]
                
                if (language != "en"){
                    youTubeUrl = youTubeUrl + "&hl=" + language
                }
            }
            
            return youTubeUrl
        }
        
    }
    
    /// Returns the Metal Archives URL for a given band, or an empty string if not found.
    /// Thread-safe version that uses cached data.
    /// - Parameter bandName: The name of the band.
    /// - Returns: The Metal Archives URL string.
    func getMetalArchives (_ bandName: String) -> String {
        
        return staticBandName.sync {
            // Try cached data first
            if let cachedBandData = cacheVariables.bandNamesStaticCache[bandName] {
                let metalArchivesUrl = cachedBandData["metalArchiveLinks"] ?? ""
                print("getMetalArchives: Returning cached data for \(bandName): \(metalArchivesUrl)")
                return metalArchivesUrl
            }
            
            // Fall back to instance data
            let metalArchivesUrl = bandNames[bandName]?["metalArchiveLinks"] ?? ""
            print("getMetalArchives: Returning instance data for \(bandName): \(metalArchivesUrl)")
            return metalArchivesUrl
        }
    }
    
    /// Returns the country for a given band, or an empty string if not found.
    /// Thread-safe version that uses cached data.
    /// - Parameter band: The name of the band.
    /// - Returns: The country string.
    func getBandCountry (_ band: String) -> String {
        
        return staticBandName.sync {
            // Try cached data first
            if let cachedBandData = cacheVariables.bandNamesStaticCache[band] {
                let country = cachedBandData["bandCountry"] ?? ""
                print("getBandCountry: Returning cached data for \(band): \(country)")
                return country
            }
            
            // Fall back to instance data
            let country = bandNames[band]?["bandCountry"] ?? ""
            print("getBandCountry: Returning instance data for \(band): \(country)")
            return country
        }
    }
    
    /// Returns the genre for a given band, or an empty string if not found.
    /// Thread-safe version that uses cached data.
    /// - Parameter band: The name of the band.
    /// - Returns: The genre string.
    func getBandGenre (_ band: String) -> String {
        
        return staticBandName.sync {
            // Try cached data first
            if let cachedBandData = cacheVariables.bandNamesStaticCache[band] {
                let genre = cachedBandData["bandGenre"] ?? ""
                print("getBandGenre: Returning cached data for \(band): \(genre)")
                return genre
            }
            
            // Fall back to instance data
            let genre = bandNames[band]?["bandGenre"] ?? ""
            print("getBandGenre: Returning instance data for \(band): \(genre)")
            return genre
        }
    }

    /// Returns the 'noteworthy' field for a given band, or an empty string if not found.
    /// Thread-safe version that uses cached data.
    /// - Parameter band: The name of the band.
    /// - Returns: The noteworthy string.
    func getBandNoteWorthy (_ band: String) -> String {
        
        return staticBandName.sync {
            // Try cached data first
            if let cachedBandData = cacheVariables.bandNamesStaticCache[band] {
                let noteworthy = cachedBandData["bandNoteWorthy"] ?? ""
                print("getBandNoteWorthy: Returning cached data for \(band): \(noteworthy)")
                return noteworthy
            }
            
            // Fall back to instance data
            let noteworthy = bandNames[band]?["bandNoteWorthy"] ?? ""
            print("getBandNoteWorthy: Returning instance data for \(band): \(noteworthy)")
            return noteworthy
        }
    }

    /// Returns a comma-separated string of prior years for a given band, or an empty string if not found.
    /// Thread-safe version that uses cached data.
    /// - Parameter band: The name of the band.
    /// - Returns: The prior years string.
    func getPriorYears (_ band: String) -> String {
        
        return staticBandName.sync {
            // Try cached data first
            var previousYears: String?
            if let cachedBandData = cacheVariables.bandNamesStaticCache[band] {
                previousYears = cachedBandData["priorYears"]
                print("getPriorYears: Returning cached data for \(band): \(previousYears ?? "")")
            } else {
                // Fall back to instance data
                previousYears = bandNames[band]?["priorYears"]
                print("getPriorYears: Returning instance data for \(band): \(previousYears ?? "")")
            }
            
            previousYears = previousYears?.replacingOccurrences(of: " ", with: ", ")
            
            return previousYears ?? ""
        }
    }

    private enum DataCollectionState {
        case idle
        case running
        case queued
        case eventYearOverridePending
    }
    private var state: DataCollectionState = .idle
    private let dataCollectionQueue = DispatchQueue(label: "com.70kBands.bandNamesHandler.dataCollectionQueue")
    private var queuedRequest: (() -> Void)?
    private var eventYearOverrideRequested: Bool = false
    private var cancelRequested: Bool = false

    /// Request a band data collection. If eventYearOverride is true, aborts all others and runs immediately.
    func requestDataCollection(eventYearOverride: Bool = false, completion: (() -> Void)? = nil) {
        dataCollectionQueue.async { [weak self] in
            guard let self = self else { return }
            if eventYearOverride {
                // Cancel everything and run this immediately
                self.eventYearOverrideRequested = true
                self.cancelRequested = true
                self.queuedRequest = nil
                if self.state == .running {
                    self.state = .eventYearOverridePending
                } else {
                    self.state = .running
                    self._startDataCollection(eventYearOverride: true, completion: completion)
                }
            } else {
                if self.state == .idle {
                    self.state = .running
                    self._startDataCollection(eventYearOverride: false, completion: completion)
                } else if self.state == .running && self.queuedRequest == nil {
                    // Queue one more
                    self.queuedRequest = { [weak self] in self?.requestDataCollection(eventYearOverride: false, completion: completion) }
                    self.state = .queued
                } else {
                    // Already queued, ignore further requests
                }
            }
        }
    }

    private func _startDataCollection(eventYearOverride: Bool, completion: (() -> Void)? = nil) {
        cancelRequested = false
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self._gatherDataWithCancellation(eventYearOverride: eventYearOverride, completion: completion)
        }
    }

    private func _gatherDataWithCancellation(eventYearOverride: Bool, completion: (() -> Void)?) {
        defer {
            // Ensure completion is always called
            DispatchQueue.main.async {
                completion?()
            }
        }
        
        if isInternetAvailable() == true {
            do {
                let eventYearString = getPointerUrlData(keyValue: "eventYear")
                if let eventYearInt = Int(eventYearString ?? "0") {
                    eventYear = eventYearInt
                } else {
                    print("Warning: Invalid event year format: \(eventYearString ?? "nil")")
                }
                
                print ("Loading bandName Data gatherData (cancellable)")
                var artistUrl = getPointerUrlData(keyValue: "artistUrl") ?? "http://dropbox.com"
                print ("Getting band data from " + artistUrl);
                
                let httpData = getUrlData(urlString: artistUrl)
                if cancelRequested { self._dataCollectionDidFinish(); return }
                
                print ("Getting band data of " + httpData);
                if (httpData.isEmpty == false) {
                    writeBandFile(httpData);
                } else {
                    print ("Internet is down, prevented blanking out data")
                }
            } catch {
                print("Error during band names data collection: \(error)")
                self._dataCollectionDidFinish()
                return
            }
        }
        
        if cancelRequested { self._dataCollectionDidFinish(); return }
        
        do {
            readBandFile()
        } catch {
            print("Error reading band file: \(error)")
            self._dataCollectionDidFinish()
            return
        }
        
        if cancelRequested { self._dataCollectionDidFinish(); return }
        
        if bandNames.isEmpty && !cacheVariables.justLaunched {
            print("Skipping cache population: bandNames is empty and app is not just launched.")
            self._dataCollectionDidFinish();
            return
        }
        
        populateCache(completion: { [weak self] in
            if let self = self {
                self._dataCollectionDidFinish()
            }
        })
    }

    private func _dataCollectionDidFinish() {
        dataCollectionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Reset static flags to prevent infinite loops
            bandNamesHandler.isGatheringData = false
            bandNamesHandler.dataLoadingTriggered = false
            
            if self.eventYearOverrideRequested {
                self.eventYearOverrideRequested = false
                self.cancelRequested = false
                self.state = .idle
                self.requestDataCollection(eventYearOverride: true)
            } else if let next = self.queuedRequest {
                self.queuedRequest = nil
                self.state = .running
                next()
            } else {
                self.state = .idle
            }
        }
    }

    // MARK: - Global timeout mechanism
    private static func startGlobalTimeout() {
        // Cancel any existing timeout
        globalTimeoutWorkItem?.cancel()
        
        // Create new timeout
        globalTimeoutWorkItem = DispatchWorkItem {
            print("[BAND_DEBUG] Global timeout triggered - resetting all flags")
            bandNamesHandler.isGatheringData = false
            bandNamesHandler.dataLoadingTriggered = false
            bandNamesHandler.lastDataLoadingTime = 0
        }
        
        // Schedule timeout
        DispatchQueue.global().asyncAfter(deadline: .now() + dataLoadingTimeout, execute: globalTimeoutWorkItem!)
    }
    
    private static func cancelGlobalTimeout() {
        globalTimeoutWorkItem?.cancel()
        globalTimeoutWorkItem = nil
    }
}

//
//  bandNamesHandler.swift
//  70000TonsBands
//
//  Core Data-backed version of bandNamesHandler
//  Maintains 100% API compatibility while using database backend
//

import Foundation
import CryptoKit
import CoreData

open class bandNamesHandler {
    
    // Singleton instance
    static let shared = bandNamesHandler()
    
    // Core Data components
    private let coreDataManager = CoreDataManager.shared
    private let csvImporter = BandCSVImporter()
    
    // Cache for performance (mirrors original structure)
    private var bandNames = [String: [String: String]]()
    private var bandNamesArray = [String]()
    private var cacheLoaded = false
    
    // Threading and state management (same as original)
    private let readingBandFileQueue = DispatchQueue(label: "com.yourapp.readingBandFileQueue")
    private var _readingBandFile: Bool = false
    var readingBandFile: Bool {
        get { return readingBandFileQueue.sync { _readingBandFile } }
        set { readingBandFileQueue.sync { _readingBandFile = newValue } }
    }
    
    static var readBandFileCallCount = 0
    static var lastReadBandFileCallTime: Date? = nil
    
    private init() {
        print("🔄 bandNamesHandler (Core Data) singleton initialized - Loading from Core Data")
        getCachedData()
    }
    
    // MARK: - Core Data Cache Management
    
    /// Loads band data from Core Data into memory cache for fast access
    private func loadCacheFromCoreData() {
        guard !cacheLoaded else { return }
        
        staticBandName.async(flags: .barrier) {
            self.bandNames = [String: [String: String]]()
            self.bandNamesArray = [String]()
            
            let bands = self.coreDataManager.fetchBands()
            
            for band in bands {
                guard let bandName = band.bandName, !bandName.isEmpty else { continue }
                
                var bandData = [String: String]()
                bandData["bandName"] = bandName
                
                // Map Core Data fields to legacy dictionary format
                if let imageUrl = band.imageUrl, !imageUrl.isEmpty {
                    bandData["bandImageUrl"] = imageUrl.hasPrefix("http") ? imageUrl : "http://\(imageUrl)"
                }
                if let officialSite = band.officialSite, !officialSite.isEmpty {
                    bandData["officalUrls"] = officialSite.hasPrefix("http") ? officialSite : "http://\(officialSite)"
                }
                if let wikipedia = band.wikipedia, !wikipedia.isEmpty {
                    bandData["wikipediaLink"] = wikipedia
                }
                if let youtube = band.youtube, !youtube.isEmpty {
                    bandData["youtubeLinks"] = youtube
                }
                if let metalArchives = band.metalArchives, !metalArchives.isEmpty {
                    bandData["metalArchiveLinks"] = metalArchives
                }
                if let country = band.country, !country.isEmpty {
                    bandData["bandCountry"] = country
                }
                if let genre = band.genre, !genre.isEmpty {
                    bandData["bandGenre"] = genre
                }
                if let noteworthy = band.noteworthy, !noteworthy.isEmpty {
                    bandData["bandNoteWorthy"] = noteworthy
                }
                if let priorYears = band.priorYears, !priorYears.isEmpty {
                    bandData["priorYears"] = priorYears
                }
                
                self.bandNames[bandName] = bandData
                self.bandNamesArray.append(bandName)
            }
            
            self.cacheLoaded = true
            print("✅ Loaded \(self.bandNamesArray.count) bands from Core Data into cache")
        }
    }
    
    // MARK: - Original API Methods (100% Compatible)
    
    /// Loads band name data from cache if available, otherwise loads from Core Data.
    /// Always shows cached/Core Data data immediately except on first launch or explicit refresh.
    /// Triggers background update if needed.
    func getCachedData(forceNetwork: Bool = false, completion: (() -> Void)? = nil) {
        print("Loading bandName Data cache (Core Data backend)")
        var needsNetworkFetch = false
        var showedData = false

        // Load from Core Data if cache not loaded
        if !cacheLoaded {
            loadCacheFromCoreData()
        }

        staticBandName.sync {
            if !self.bandNames.isEmpty {
                // Cache is available, show immediately
                print("Loading bandName Data cache, from Core Data cache")
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
                print("No cached/Core Data data, fetching from network (blocking UI)")
            }
            DispatchQueue.global(qos: .default).async {
                self.gatherData(forceDownload: false, completion: completion)
            }
        }
        print("Done Loading bandName Data cache")
    }
    
    /// Clears the static cache of band names.
    func clearCachedData() {
        staticBandName.async(flags: .barrier) {
            cacheVariables.bandNamesStaticCache = [String: [String: String]]()
            self.cacheLoaded = false
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
    
    /// TEMPORARY: Clear stored checksum to force fresh import
    private func clearStoredChecksum() {
        let checksumFile = getDocumentsDirectory().appendingPathComponent("bandFile.checksum")
        do {
            if FileManager.default.fileExists(atPath: checksumFile) {
                try FileManager.default.removeItem(atPath: checksumFile)
                print("🗑️ Cleared stored checksum to force fresh import")
            }
        } catch {
            print("❌ Error clearing checksum: \(error)")
        }
    }
    
    /// Gathers band data from the internet if available, writes it to Core Data, and populates the cache.
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
            print("DEBUG_MARKER: Starting CSV download process (Core Data backend)")
            print("DEBUG_MARKER: Event year: \(eventYear)")
            
            let defaultUrl = defaultStorageUrl
            print("DEBUG_MARKER: Default storage URL: \(defaultUrl)")
            
            var artistUrl = getPointerUrlData(keyValue: "artistUrl") ?? "http://dropbox.com"
            print("DEBUG_MARKER: Artist URL from pointer: \(artistUrl)")
            print("DEBUG_MARKER: Downloading from URL: \(artistUrl)")
            
            let httpData = getUrlData(urlString: artistUrl)
            print("DEBUG_MARKER: Downloaded \(httpData.count) characters of CSV data")
            
            // Show first few lines of CSV for debugging
            let lines = httpData.components(separatedBy: .newlines)
            print("DEBUG_MARKER: CSV has \(lines.count) lines")
            if lines.count > 0 {
                print("DEBUG_MARKER: CSV header: \(lines[0])")
            }
            if lines.count > 1 {
                print("DEBUG_MARKER: CSV first data row: \(lines[1])")
            }
            if lines.count > 2 {
                print("DEBUG_MARKER: CSV second data row: \(lines[2])")
            }
            
            // Only proceed if data appears valid
            if (httpData.isEmpty == false && httpData.count > 100) { // Basic validation
                newDataValid = true
                
                // Calculate checksum of new data
                let newChecksum = calculateChecksum(httpData)
                var storedChecksum = getStoredChecksum()
                
                print("🔍 New data checksum: \(String(newChecksum.prefix(8)))...")
                if let stored = storedChecksum {
                    print("🔍 Stored checksum: \(String(stored.prefix(8)))...")
                } else {
                    print("🔍 No stored checksum found (first run or missing)")
                }
                
                // Smart import detection: Force import if we have large CSV but few bands
                let currentBandCount = CoreDataManager.shared.fetchBands().count
                if httpData.count > 10000 && currentBandCount < 20 {
                    print("DEBUG_MARKER: Smart import triggered - Downloaded \(httpData.count) chars but only \(currentBandCount) bands in Core Data")
                    clearStoredChecksum()
                    storedChecksum = getStoredChecksum() // Refresh after clearing
                }
                
                // Compare checksums to determine if data has changed
                if storedChecksum != newChecksum {
                    print("DEBUG_MARKER: Data has changed - importing to Core Data")
                    print("DEBUG_MARKER: Old checksum: \(storedChecksum?.prefix(8) ?? "none")")
                    print("DEBUG_MARKER: New checksum: \(newChecksum.prefix(8))")
                    dataChanged = true
                    
                    // Import new data to Core Data with smart update/delete logic
                    print("DEBUG_MARKER: Calling smart CSV import")
                    let importSuccess = csvImporter.importBandsFromCSVString(httpData)
                    print("DEBUG_MARKER: Smart CSV import result: \(importSuccess)")
                    
                    if importSuccess {
                        // Store new checksum only if import was successful
                        storeChecksum(newChecksum)
                        print("DEBUG_MARKER: Successfully updated Core Data and stored new checksum")
                    } else {
                        print("DEBUG_MARKER: Import failed - keeping old checksum")
                    }
                } else {
                    print("DEBUG_MARKER: Data unchanged - but running cleanup check")
                    print("DEBUG_MARKER: Checksum: \(newChecksum.prefix(8))")
                    dataChanged = false
                    
                    // Even if data hasn't changed, we should run cleanup to remove invalid bands
                    // This handles cases where test data or old bands exist in Core Data
                    let currentBandCount = CoreDataManager.shared.fetchBands().count
                    let csvLineCount = httpData.components(separatedBy: .newlines).count - 1 // Subtract header
                    
                    if currentBandCount != csvLineCount {
                        print("DEBUG_MARKER: Band count mismatch - Core Data: \(currentBandCount), CSV: \(csvLineCount)")
                        print("DEBUG_MARKER: Running cleanup to sync Core Data with CSV")
                        
                        let cleanupSuccess = csvImporter.importBandsFromCSVString(httpData)
                        print("DEBUG_MARKER: Cleanup import result: \(cleanupSuccess)")
                    } else {
                        print("DEBUG_MARKER: Band counts match - no cleanup needed")
                    }
                }
            } else {
                print("❌ Internet is down or data is invalid, keeping existing data")
                newDataValid = false
                dataChanged = false
            }
        } else if !forceDownload {
            print("📖 gatherData called without forceDownload - only reading from Core Data cache")
        } else {
            print("📡 No internet available, keeping existing data")
            newDataValid = false
            dataChanged = false
        }
        
        // Always read from Core Data (either new or existing)
        loadCacheFromCoreData()
        var isEmpty = false
        staticBandName.sync {
            isEmpty = self.bandNames.isEmpty
        }
        
        // Enhanced retry logic for band data
        if isEmpty && forceDownload {
            print("Core Data is empty and forceDownload is true. Attempting retry with enhanced logic.")
            let maxRetries = 3
            var retryCount = 0
            var success = false
            
            while retryCount < maxRetries && !success {
                retryCount += 1
                print("Band data retry attempt \(retryCount)/\(maxRetries)")
                
                if isInternetAvailable() == true {
                    eventYear = Int(getPointerUrlData(keyValue: "eventYear"))!
                    let artistUrl = getPointerUrlData(keyValue: "artistUrl") ?? "http://dropbox.com"
                    print("Retrying: Getting band data from " + artistUrl + " (attempt \(retryCount))");
                    
                    // Add a small delay between retries
                    if retryCount > 1 {
                        Thread.sleep(forTimeInterval: 1.0)
                    }
                    
                    let httpData = getUrlData(urlString: artistUrl)
                    if (httpData.isEmpty == false && httpData.count > 100) {
                        csvImporter.importBandsFromCSVString(httpData)
                        loadCacheFromCoreData()
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
                            print("Retry \(retryCount) failed: Data downloaded but Core Data is still empty.")
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
            print("Core Data is empty but forceDownload is false. Skipping retry logic.")
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
                let compatibleHandler = bandNamesHandler.shared
                if CombinedImageListHandler.shared.needsRegeneration(bandNameHandle: compatibleHandler, scheduleHandle: scheduleHandle) {
                    print("[CHECKSUM_DEBUG] Regenerating combined image list due to changed artist data")
                    CombinedImageListHandler.shared.generateCombinedImageList(
                        bandNameHandle: compatibleHandler,
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
    func populateCache(completion: (() -> Void)? = nil) {
        print("Starting population of cacheVariables.bandNamesStaticCache (Core Data backend)")
        staticBandName.async(flags: .barrier) {
            cacheVariables.bandNamesStaticCache = [String: [String: String]]()
            cacheVariables.bandNamesArrayStaticCache = [String]()
            // Read bandNames and bandNamesArray inside the queue
            for bandName in self.bandNames.keys {
                cacheVariables.bandNamesStaticCache[bandName] = [String: String]()
                cacheVariables.bandNamesStaticCache[bandName] = self.bandNames[bandName]
                print("Adding Data to cacheVariables.bandNamesStaticCache = \(String(describing: cacheVariables.bandNamesStaticCache[bandName]))")
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
    
    /// Writes the provided HTTP data string to Core Data instead of file.
    /// - Parameter httpData: The string data to import to Core Data.
    func writeBandFile(_ httpData: String) {
        print("write to Core Data instead of file");
        print(httpData);
        
        // Import to Core Data instead of writing to file
        csvImporter.importBandsFromCSVString(httpData)
        print("Just imported data to Core Data");
    }

    /// Reads the band data from Core Data and populates the bandNames and bandNamesArray dictionaries.
    /// Handles parsing of Core Data entities and extraction of band properties.
    func readBandFile() {
        let now = Date()
        if let last = Self.lastReadBandFileCallTime, now.timeIntervalSince(last) < 2 {
            Self.readBandFileCallCount += 1
        } else {
            Self.readBandFileCallCount = 1
        }
        Self.lastReadBandFileCallTime = now
        print("readBandFile called (\(Self.readBandFileCallCount)) at \(now) (Core Data backend)")
        if Self.readBandFileCallCount > 10 {
            print("Aborting: readBandFile called too many times in a short period. Possible infinite loop.")
            return
        }
        if readingBandFile == false {
            readingBandFile = true
            print("Loading bandName Data readBandFile (Core Data backend)")
            
            // Load from Core Data instead of file
            loadCacheFromCoreData()
            
            readingBandFile = false
        }
        // After band names data is loaded and parsed:
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("BandNamesDataReady"), object: nil)
        }
    }

    /// Force read the Core Data and populate cache, bypassing the recursion/loop guard
    func forceReadBandFileAndPopulateCache(completion: (() -> Void)? = nil) {
        self._readingBandFile = true
        self.readBandFile()
        self._readingBandFile = false
        self.populateCache(completion: completion)
    }

    /// Returns a sorted array of all band names. Loads from cache if necessary.
    /// - Returns: An array of band name strings.
    func getBandNames() -> [String] {
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
        print("bandNamesArray data is \(result) (Core Data backend)")
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
        print("🔗 URL lookup for band \(band): \(result.isEmpty ? "no URL available" : result) (Core Data)")
        return result
    }

    /// Returns the official website URL for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The official website URL string.
    func getofficalPage(_ band: String) -> String {
        var result = ""
        staticBandName.sync {
            result = self.bandNames[band]?["officalUrls"] ?? ""
        }
        print("Getting officalSite for band \(band) will return \(result) (Core Data)")
        return result
    }

    /// Returns the Wikipedia page URL for a given band, localized to the user's language if possible.
    /// - Parameter bandName: The name of the band.
    /// - Returns: The Wikipedia URL string.
    func getWikipediaPage(_ bandName: String) -> String {
        var wikipediaUrl = ""
        staticBandName.sync {
            wikipediaUrl = self.bandNames[bandName]?["wikipediaLink"] ?? ""
        }
        if (wikipediaUrl.isEmpty == false) {
            let language: String = Locale.current.languageCode!
            print("Language is " + language);
            if (language != "en") {
                let replacement: String = language + ".wikipedia.org";
                wikipediaUrl = wikipediaUrl.replacingOccurrences(of: "en.wikipedia.org", with: replacement)
            }
        }
        return (wikipediaUrl)
    }
    
    /// Returns the YouTube page URL for a given band, localized to the user's language if possible.
    /// - Parameter bandName: The name of the band.
    /// - Returns: The YouTube URL string.
    func getYouTubePage(_ bandName: String) -> String {
        var youTubeUrl = ""
        staticBandName.sync {
            youTubeUrl = self.bandNames[bandName]?["youtubeLinks"] ?? ""
        }
        if (youTubeUrl.isEmpty == false) {
            let language: String = Locale.preferredLanguages[0]
            if (language != "en") {
                youTubeUrl = youTubeUrl + "&hl=" + language
            }
        }
        return (youTubeUrl)
    }
    
    /// Returns the Metal Archives URL for a given band, or an empty string if not found.
    /// - Parameter bandName: The name of the band.
    /// - Returns: The Metal Archives URL string.
    func getMetalArchives(_ bandName: String) -> String {
        var result = ""
        staticBandName.sync {
            result = self.bandNames[bandName]?["metalArchiveLinks"] ?? ""
        }
        return result
    }
    
    /// Returns the country for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The country string.
    func getBandCountry(_ band: String) -> String {
        var result = ""
        staticBandName.sync {
            result = self.bandNames[band]?["bandCountry"] ?? ""
        }
        return result
    }
    
    /// Returns the genre for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The genre string.
    func getBandGenre(_ band: String) -> String {
        var result = ""
        staticBandName.sync {
            result = self.bandNames[band]?["bandGenre"] ?? ""
        }
        return result
    }

    /// Returns the 'noteworthy' field for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The noteworthy string.
    func getBandNoteWorthy(_ band: String) -> String {
        var result = ""
        staticBandName.sync {
            result = self.bandNames[band]?["bandNoteWorthy"] ?? ""
        }
        return result
    }

    /// Returns a comma-separated string of prior years for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The prior years string.
    func getPriorYears(_ band: String) -> String {
        var previousYears: String? = nil
        staticBandName.sync {
            previousYears = self.bandNames[band]?["priorYears"]
        }
        previousYears = previousYears?.replacingOccurrences(of: " ", with: ", ")
        return previousYears ?? ""
    }
}

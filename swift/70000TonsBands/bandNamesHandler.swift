//
//  bandNamesHandler.swift
//  70000TonsBands
//
//  SQLite-backed version of bandNamesHandler
//  Maintains 100% API compatibility while using SQLite database backend
//

import Foundation
import CryptoKit

open class bandNamesHandler {
    
    // Singleton instance
    static let shared = bandNamesHandler()
    
    // SQLite database components
    private let dataManager = DataManager.shared
    private let csvImporter = BandCSVImporter()
    
    // Cache for performance (mirrors original structure)
    private var bandNames = [String: [String: String]]()
    private var bandNamesArray = [String]()
    private var cacheLoaded = false
    private var cachedForYear: Int = -1  // Track which year the cache was loaded for
    
    // Queue for deferred operations during year changes
    private var deferredCacheLoads: [() -> Void] = []
    private var deferredBandLookups: [(bandName: String, field: String, completion: (String) -> Void)] = []
    private let deferredOperationsQueue = DispatchQueue(label: "com.yourapp.deferredOperations")
    
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
        // Initialize eventYear from global variable (defined in Constants.swift)
        // Load cached year before loading data
        loadCachedYearIfNeeded()
        print("🔄 bandNamesHandler (SQLite) singleton initialized - Loading from SQLite")
        
        // Listen for year change completion to process deferred operations
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleYearChangeCompleted),
            name: NSNotification.Name("YearChangeCompleted"),
            object: nil
        )
        
        getCachedData()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleYearChangeCompleted() {
        print("✅ [YEAR_CHANGE] Processing \(deferredCacheLoads.count) deferred cache loads and \(deferredBandLookups.count) deferred lookups")
        
        // RACE FIX: Wait for data to be ready before processing deferred operations
        // This prevents conflicts with handleReturnFromPreferencesAfterYearChange
        if !MasterViewController.isYearChangeDataReady() {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.handleYearChangeCompleted()
            }
            return
        }
        
        deferredOperationsQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Process deferred cache loads
            let cacheLoads = self.deferredCacheLoads
            self.deferredCacheLoads.removeAll()
            for loadOperation in cacheLoads {
                loadOperation()
            }
            
            // Process deferred band lookups
            let lookups = self.deferredBandLookups
            self.deferredBandLookups.removeAll()
            for lookup in lookups {
                if let bandData = self.dataManager.fetchBand(byName: lookup.bandName, eventYear: eventYear) {
                    let value: String
                    switch lookup.field {
                    case "imageUrl":
                        value = bandData.imageUrl ?? ""
                    case "officialSite":
                        value = bandData.officialSite ?? ""
                    case "wikipedia":
                        value = bandData.wikipedia ?? ""
                    case "youtube":
                        value = bandData.youtube ?? ""
                    case "metalArchives":
                        value = bandData.metalArchives ?? ""
                    case "country":
                        value = bandData.country ?? ""
                    case "genre":
                        value = bandData.genre ?? ""
                    case "noteworthy":
                        value = bandData.noteworthy ?? ""
                    case "priorYears":
                        value = bandData.priorYears ?? ""
                    default:
                        value = ""
                    }
                    lookup.completion(value)
                } else {
                    lookup.completion("")
                }
            }
            
            print("✅ [YEAR_CHANGE] Completed processing deferred operations")
        }
    }
    
    private func deferCacheLoadUntilYearChangeCompletes() {
        deferredOperationsQueue.async { [weak self] in
            guard let self = self else { return }
            self.deferredCacheLoads.append { [weak self] in
                self?.loadCacheFromCoreData()
            }
            print("⏳ [YEAR_CHANGE] Queued cache load for after year change completes")
        }
    }
    
    private func queueBandLookupForAfterYearChange(bandName: String, field: String, completion: @escaping (String) -> Void) {
        deferredOperationsQueue.async { [weak self] in
            guard let self = self else { return }
            self.deferredBandLookups.append((bandName: bandName, field: field, completion: completion))
            print("⏳ [YEAR_CHANGE] Queued \(field) lookup for '\(bandName)' for after year change completes")
        }
    }
    
    /// Loads the cached year from file if eventYear is still 0
    private func loadCachedYearIfNeeded() {
        guard eventYear == 0 else {
            print("📅 [BAND_INIT] eventYear already set to \(eventYear)")
            return
        }
        
        print("📅 [BAND_INIT] eventYear is 0, attempting to load cached year")
        
        // Try to load from cache file
        if FileManager.default.fileExists(atPath: eventYearFile) {
            do {
                let cachedYearString = try String(contentsOfFile: eventYearFile, encoding: .utf8)
                if let yearInt = Int(cachedYearString.trimmingCharacters(in: .whitespacesAndNewlines)), yearInt > 0 {
                    eventYear = yearInt
                    print("📅 [BAND_INIT] Loaded cached year: \(eventYear)")
                    return
                }
            } catch {
                print("📅 [BAND_INIT] Failed to read cached year file: \(error)")
            }
        }
        
        // If no cache or invalid, use current calendar year as fallback
        let currentYear = Calendar.current.component(.year, from: Date())
        eventYear = currentYear
        print("📅 [BAND_INIT] No cached year, using current year: \(eventYear)")
    }
    
    // MARK: - SQLite Cache Management
    
    /// Loads band data from SQLite into memory cache for fast access
    private func loadCacheFromCoreData() {
        
        // CRITICAL: If year change is in progress, defer this operation until it completes
        if MasterViewController.isYearChangeInProgress {
            print("⏳ [YEAR_CHANGE] Year change in progress - deferring cache load")
            deferCacheLoadUntilYearChangeCompletes()
            return
        }
        
        // RACE FIX: If year change just completed but data isn't ready yet, wait briefly
        // This prevents reading SQLite before data import completes (edge case)
        // Only check if year change is NOT in progress (already handled above) but data not ready
        if !MasterViewController.isYearChangeInProgress && !MasterViewController.isYearChangeDataReady() {
            // Year change flag cleared but data not ready - wait briefly
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.loadCacheFromCoreData()
            }
            return
        }
        
        guard !cacheLoaded else {
            return
        }
        
        print("🔄 Loading bands from SQLite...")
        
        // Use eventYear as-is (should be set correctly during app launch or year change)
        // eventYear is already thread-safe via lock in Constants.swift
        print("🔍 [LOAD_CACHE_DEBUG] loadCacheFromCoreData called")
        print("🔍 [LOAD_CACHE_DEBUG] Current eventYear = \(eventYear)")
        print("🔍 [LOAD_CACHE_DEBUG] cachedForYear = \(cachedForYear)")
        print("🔍 [LOAD_CACHE_DEBUG] cacheLoaded = \(cacheLoaded)")
        print("🔍 [LOAD_CACHE_DEBUG] isYearChangeInProgress = \(MasterViewController.isYearChangeInProgress)")
        print("🔍 [LOAD_CACHE_DEBUG] isYearChangeDataReady = \(MasterViewController.isYearChangeDataReady())")
        
        // CRITICAL FIX: Filter bands by the current event year
        print("🔍 [LOAD_CACHE_DEBUG] About to call fetchBands(forYear: \(eventYear))")
        let bands = self.dataManager.fetchBands(forYear: eventYear)
        print("🔍 [LOAD_CACHE_DEBUG] fetchBands returned \(bands.count) bands for year \(eventYear)")
        
        // CRITICAL: All dictionary modifications must be synchronized
        staticBandName.sync {
            // Clear data structures
            self.bandNames = [String: [String: String]]()
            self.bandNamesArray = [String]()
            
            for band in bands {
                let bandName = band.bandName
                guard !bandName.isEmpty else { continue }
                
                var bandData = [String: String]()
                bandData["bandName"] = bandName
                
                // Map SQLite fields to legacy dictionary format
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
            self.cachedForYear = eventYear
            let count = self.bandNamesArray.count
            print("✅ Loaded \(count) bands from SQLite into cache for year \(eventYear)")
        }
    }
    
    // MARK: - Original API Methods (100% Compatible)
    
    /// Loads band name data from cache if available, otherwise loads from SQLite.
    /// PERFORMANCE OPTIMIZED: Load data from cache immediately (no network calls)
    func loadCachedDataImmediately() {
        print("🚀 bandNamesHandler: Loading cached data immediately (no network calls)")
        
        // Use eventYear as-is (should be set correctly during app launch or year change)
        print("🔄 Using eventYear = \(eventYear) (set by proper resolution chain)")
        
        // Load from SQLite cache immediately
        loadCacheFromCoreData()
        
        var isEmpty = false
        staticBandName.sync {
            isEmpty = self.bandNames.isEmpty
        }
        
        if isEmpty {
            print("⚠️ bandNamesHandler: No cached data available")
        } else {
            var count = 0
            staticBandName.sync {
                count = self.bandNamesArray.count
            }
            print("✅ bandNamesHandler: Loaded \(count) cached bands immediately")
        }
    }
    
    /// Always shows cached/SQLite data immediately except on first launch or explicit refresh.
    /// Triggers background update if needed.
    func getCachedData(forceNetwork: Bool = false, completion: (() -> Void)? = nil) {
        print("Loading bandName Data cache (SQLite backend)")
        var needsNetworkFetch = false
        var showedData = false

        // Load from SQLite if cache not loaded
        if !cacheLoaded {
            loadCacheFromCoreData()
        }

        staticBandName.sync {
            if !self.bandNames.isEmpty {
                // Cache is available, show immediately
                print("Loading bandName Data cache, from SQLite cache")
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
            // PERFORMANCE FIX: Only trigger network downloads during appropriate operations
            if cacheVariables.justLaunched && cacheLoaded && !bandNames.isEmpty {
                print("First app launch detected - deferring network download to proper loading sequence")
                print("This prevents infinite retry loops when network is unavailable")
                // Don't automatically download on first launch - wait for proper sequence
                completion?()
                return
            } else if cacheVariables.justLaunched && (!cacheLoaded || bandNames.isEmpty) {
                print("🚨 EMERGENCY: First launch but no cached data - forcing network download")
                // DIAGNOSTIC: Using 30-second delay to test if this is truly a timing issue
                // If error -9816 still occurs after 30 seconds, it's NOT initialization delay
                // It's something specific about how we're calling the network
                DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + 30.0) {
                    print("⏳ EMERGENCY: Starting deferred band data download after 30-SECOND diagnostic delay")
                    self.gatherData(forceDownload: true, completion: completion)
                }
                return
            } else if forceNetwork {
                // Only download if explicitly forced (app launch, foreground, pull-to-refresh)
                print("Forced network fetch requested - proceeding with download")
                DispatchQueue.global(qos: .default).async {
                    self.gatherData(forceDownload: true, completion: completion)
                }
            } else {
                // Cache is empty but network not explicitly requested - skip automatic download
                print("No cached/SQLite data available, but network fetch not explicitly requested")
                print("Skipping automatic network download - network loading should only happen during app launch, foreground return, or pull-to-refresh")
                completion?()
            }
        }
        print("Done Loading bandName Data cache")
    }
    
    /// Clears the static cache of band names - Thread Safe
    func clearCachedData() {
        // Use barrier to ensure exclusive access during cache clearing
        staticBandName.async(flags: .barrier) {
            // Clear cache in a thread-safe manner
            cacheVariables.bandNamesStaticCache.removeAll()
            cacheVariables.bandNamesArrayStaticCache.removeAll()
            
            // Clear local cache
            self.bandNames.removeAll()
            self.bandNamesArray.removeAll()
            self.cacheLoaded = false
            self.cachedForYear = -1
            
            print("🧹 [CACHE_DEBUG] Band names cache cleared safely")
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
    
    /// Gathers band data from the internet if available, writes it to SQLite, and populates the cache.
    /// Uses checksum comparison to avoid unnecessary cache rebuilds when data hasn't changed.
    /// Calls completion handler when done.
    /// - Parameter forceDownload: If true, forces download from network. If false, only reads from cache.
    /// - Parameter isYearChangeOperation: If true, this operation can override existing operations
    func gatherData(forceDownload: Bool = false, isYearChangeOperation: Bool = false, completion: (() -> Void)? = nil) {
        print("🔧 [BAND_DEBUG] ========== BAND NAMES gatherData() STARTING ==========")
        print("🔧 [BAND_DEBUG] Current thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")
        print("🔧 [BAND_DEBUG] forceDownload: \(forceDownload), isYearChangeOperation: \(isYearChangeOperation)")
        print("🚀 [COMPLETION_DEBUG] gatherData called with completion: \(completion == nil ? "NIL" : "NOT NIL")")
        
        // Thread management: prevent concurrent operations unless it's a year change
        if isLoadingBandData {
            if isYearChangeOperation {
                print("🔄 [THREAD_MGMT] Year change operation detected - cancelling existing band data operation")
                // Force reset to allow year change to proceed
                isLoadingBandData = false
            } else {
                print("🚫 [THREAD_MGMT] Band data loading already in progress, killing Thread B")
                completion?()
                return
            }
        }
        
        isLoadingBandData = true
        var dataChanged = false
        var newDataValid = false
        
        // Only download from network if explicitly forced
        if forceDownload && isInternetAvailable() == true {
            // Use eventYear as-is (should be set correctly during app launch or year change)
            print("DEBUG_MARKER: Starting CSV download process (SQLite backend)")
            print("DEBUG_MARKER: Event year: \(eventYear)")
            
            let defaultUrl = defaultStorageUrl
            print("DEBUG_MARKER: Default storage URL: \(defaultUrl)")
            
            var artistUrl = getPointerUrlData(keyValue: "artistUrl") ?? "http://dropbox.com"
            print("DEBUG_MARKER: Artist URL from pointer: \(artistUrl)")
            print("DEBUG_MARKER: Artist URL pointer key: \(getArtistUrl())")
            print("DEBUG_MARKER: Downloading from URL: \(artistUrl)")
            
            // Ensure network call happens on background thread to prevent main thread blocking
            var httpData = ""
            if Thread.isMainThread {
                print("bandNamesHandler: Main thread detected, dispatching to background for network call")
                let semaphore = DispatchSemaphore(value: 0)
                DispatchQueue.global(qos: .userInitiated).async {
                    httpData = getUrlData(urlString: artistUrl)
                    semaphore.signal()
                }
                semaphore.wait()
            } else {
                httpData = getUrlData(urlString: artistUrl)
            }
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
                
                // Smart import detection: Force import if we have large CSV but few bands for current year
                let currentBandCount = DataManager.shared.fetchBands(forYear: eventYear).count
                if httpData.count > 10000 && currentBandCount < 20 {
                    print("DEBUG_MARKER: Smart import triggered - Downloaded \(httpData.count) chars but only \(currentBandCount) bands in SQLite")
                    clearStoredChecksum()
                    storedChecksum = getStoredChecksum() // Refresh after clearing
                }
                
                // Compare checksums to determine if data has changed
                if storedChecksum != newChecksum {
                    print("DEBUG_MARKER: Data has changed - importing to SQLite")
                    print("DEBUG_MARKER: Old checksum: \(storedChecksum?.prefix(8) ?? "none")")
                    print("DEBUG_MARKER: New checksum: \(newChecksum.prefix(8))")
                    dataChanged = true
                    
                    // Import new data to SQLite with smart update/delete logic
                    print("DEBUG_MARKER: Calling smart CSV import")
                    let importSuccess = csvImporter.importBandsFromCSVString(httpData)
                    print("DEBUG_MARKER: Smart CSV import result: \(importSuccess)")
                    
                    if importSuccess {
                        // Reset cache loaded flag to force reload of new data
                        self.cacheLoaded = false
                        print("DEBUG_MARKER: Reset cacheLoaded flag after successful CSV import")
                        // Store new checksum only if import was successful
                        storeChecksum(newChecksum)
                        print("DEBUG_MARKER: Successfully updated SQLite and stored new checksum")
                    } else {
                        print("DEBUG_MARKER: Import failed - keeping old checksum")
                    }
                } else {
                    print("DEBUG_MARKER: Data unchanged - but running cleanup check")
                    print("DEBUG_MARKER: Checksum: \(newChecksum.prefix(8))")
                    dataChanged = false
                    
                    // Even if data hasn't changed, we should run cleanup to remove invalid bands
                    // This handles cases where test data or old bands exist in SQLite
                    let currentBandCount = DataManager.shared.fetchBands(forYear: eventYear).count
                    let csvLineCount = httpData.components(separatedBy: .newlines).count - 1 // Subtract header
                    
                    if currentBandCount != csvLineCount {
                        print("DEBUG_MARKER: Band count mismatch - SQLite: \(currentBandCount), CSV: \(csvLineCount)")
                        print("DEBUG_MARKER: Running cleanup to sync SQLite with CSV")
                        
                        let cleanupSuccess = csvImporter.importBandsFromCSVString(httpData)
                        print("DEBUG_MARKER: Cleanup import result: \(cleanupSuccess)")
                        
                        if cleanupSuccess {
                            // Reset cache loaded flag to force reload of new data
                            self.cacheLoaded = false
                            print("DEBUG_MARKER: Reset cacheLoaded flag after cleanup import")
                        }
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
            print("📖 gatherData called without forceDownload - only reading from SQLite cache")
        } else {
            print("📡 No internet available, keeping existing data")
            newDataValid = false
            dataChanged = false
        }
        
        // Always read from SQLite (either new or existing)
        loadCacheFromCoreData()
        var isEmpty = false
        staticBandName.sync {
            isEmpty = self.bandNames.isEmpty
        }
        
        // IMPORTANT POLICY (per request):
        // - Band list should be downloaded ONCE at startup.
        // - Cached data should be used at all other times.
        // - Only exceptions for additional downloads: pull-to-refresh and foreground return.
        //
        // To enforce this, we DO NOT re-download the band list here if the cache still appears empty
        // after a forced download/import attempt. Instead we only retry *loading from SQLite* briefly.
        //
        // This prevents multiple redundant Dropbox downloads during startup caused by retry loops.
        if isEmpty && forceDownload {
            print("Band data cache is empty after forced download/import. Will retry SQLite visibility without additional network downloads.")
            
            // Give SQLite a moment to surface the newly imported rows (edge-case timing).
            // Retry quickly a few times without touching the network.
            let maxVisibilityRetries = 10
            for attempt in 1...maxVisibilityRetries {
                // Small backoff; keep total under ~2 seconds.
                Thread.sleep(forTimeInterval: 0.2)
                
                // Force cache reload attempt
                self.cacheLoaded = false
                loadCacheFromCoreData()
                staticBandName.sync {
                    isEmpty = self.bandNames.isEmpty
                }
                
                if !isEmpty {
                    print("✅ Band data became visible from SQLite after \(attempt) visibility retries (no extra downloads).")
                    break
                } else {
                    print("⚠️ Visibility retry \(attempt)/\(maxVisibilityRetries): band cache still empty (no extra downloads).")
                }
            }
        } else if isEmpty && !forceDownload {
            print("SQLite database is empty but forceDownload is false. Skipping retry logic.")
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
                // Run this on a background thread to avoid blocking the current thread
                DispatchQueue.global(qos: .utility).async {
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
                }
            } else {
                print("⏭️ Data unchanged - using existing cache")
                // Data hasn't changed, just call completion
                print("🚀 [COMPLETION_DEBUG] About to call completion handler (completion is \(completion == nil ? "NIL" : "NOT NIL"))")
                completion?()
                print("🚀 [COMPLETION_DEBUG] Completion handler called")
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
        print("🔧 [BAND_DEBUG] ========== BAND NAMES gatherData() COMPLETED ==========")
        print("🔧 [BAND_DEBUG] dataChanged: \(dataChanged), newDataValid: \(newDataValid)")
        isLoadingBandData = false
    }
    
    /// Backward-compatible gatherData method for protocol conformance
    /// Calls the main gatherData method with isYearChangeOperation: false
    func gatherData(forceDownload: Bool, completion: (() -> Void)?) {
        gatherData(forceDownload: forceDownload, isYearChangeOperation: false, completion: completion)
    }

    /// Populates the static cache variables with the current bandNames dictionary.
    /// Posts a notification when the cache is ready and calls the completion handler.
    func populateCache(completion: (() -> Void)? = nil) {
        print("Starting population of cacheVariables.bandNamesStaticCache (SQLite backend)")
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
    
    /// Writes the provided HTTP data string to SQLite instead of file.
    /// - Parameter httpData: The string data to import to SQLite.
    func writeBandFile(_ httpData: String) {
        print("write to SQLite instead of file");
        print(httpData);
        
        // Import to SQLite instead of writing to file
        csvImporter.importBandsFromCSVString(httpData)
        
        // Reset cache loaded flag to force reload of new data
        self.cacheLoaded = false
        print("DEBUG_MARKER: Reset cacheLoaded flag after writeBandFile CSV import")
        
        print("Just imported data to SQLite");
    }

    /// Reads the band data from SQLite and populates the bandNames and bandNamesArray dictionaries.
    /// Handles parsing of SQLite data and extraction of band properties.
    func readBandFile() {
        let now = Date()
        if let last = Self.lastReadBandFileCallTime, now.timeIntervalSince(last) < 2 {
            Self.readBandFileCallCount += 1
        } else {
            Self.readBandFileCallCount = 1
        }
        Self.lastReadBandFileCallTime = now
        print("readBandFile called (\(Self.readBandFileCallCount)) at \(now) (SQLite backend)")
        if Self.readBandFileCallCount > 10 {
            print("Aborting: readBandFile called too many times in a short period. Possible infinite loop.")
            return
        }
        if readingBandFile == false {
            readingBandFile = true
            print("Loading bandName Data readBandFile (SQLite backend)")
            
            // Load from SQLite instead of file
            loadCacheFromCoreData()
            
            readingBandFile = false
        }
        // After band names data is loaded and parsed:
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("BandNamesDataReady"), object: nil)
        }
    }

    /// Force read the SQLite database and populate cache, bypassing the recursion/loop guard
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
            // CRITICAL FIX: Check if cache is for the current year
            // If year has changed (e.g., from 0 to 2026), invalidate cache
            if self.cachedForYear != eventYear && self.cachedForYear != -1 {
                print("⚠️ [CACHE_INVALIDATION] Cache is for year \(self.cachedForYear) but current year is \(eventYear) - invalidating cache")
                self.cacheLoaded = false
                self.cachedForYear = -1
                self.bandNames = [:]
                self.bandNamesArray = []
                needsCache = true
            } else if self.bandNames.isEmpty {
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
        print("bandNamesArray data is \(result) (SQLite backend)")
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
        
        // OFFLINE MODE FIX: Fall back to SQLite if in-memory cache doesn't have data
        // CRITICAL: If year change is in progress, queue the lookup for after year change completes
        if result.isEmpty {
            if MasterViewController.isYearChangeInProgress {
                // Queue this lookup to happen after year change completes
                // Note: We return empty string now, but the lookup will complete later
                // The caller should retry after year change completes
                print("⏳ [YEAR_CHANGE] Queuing image URL lookup for '\(band)' - will complete after year change")
                queueBandLookupForAfterYearChange(bandName: band, field: "imageUrl") { imageUrl in
                    // This will be called after year change completes
                    // Update cache if we got a result
                    if !imageUrl.isEmpty {
                        var finalUrl = imageUrl.hasPrefix("http") ? imageUrl : "http://\(imageUrl)"
                        staticBandName.sync {
                            if self.bandNames[band] == nil {
                                self.bandNames[band] = [:]
                            }
                            self.bandNames[band]?["bandImageUrl"] = finalUrl
                        }
                        print("✅ [YEAR_CHANGE] Completed deferred lookup for '\(band)': \(finalUrl)")
                    }
                }
                // Return empty for now - will be populated after year change
            } else {
                // Safe to query SQLite now
                if let bandData = dataManager.fetchBand(byName: band, eventYear: eventYear) {
                    let imageUrl = bandData.imageUrl ?? ""
                    if !imageUrl.isEmpty {
                        result = imageUrl.hasPrefix("http") ? imageUrl : "http://\(imageUrl)"
                        print("🔧 OFFLINE MODE: Retrieved imageUrl '\(result)' from SQLite for band '\(band)'")
                    }
                }
            }
        }
        
        print("🔗 URL lookup for band \(band): \(result.isEmpty ? "no URL available" : result) (SQLite)")
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
        
        // OFFLINE MODE FIX: Fall back to SQLite if in-memory cache doesn't have data
        // CRITICAL: If year change is in progress, queue the lookup for after year change completes
        if result.isEmpty {
            if MasterViewController.isYearChangeInProgress {
                // Queue this lookup to happen after year change completes
                queueBandLookupForAfterYearChange(bandName: band, field: "officialSite") { officialSite in
                    if !officialSite.isEmpty {
                        var finalUrl = officialSite.hasPrefix("http") ? officialSite : "http://\(officialSite)"
                        staticBandName.sync {
                            if self.bandNames[band] == nil {
                                self.bandNames[band] = [:]
                            }
                            self.bandNames[band]?["officalUrls"] = finalUrl
                        }
                        print("✅ [YEAR_CHANGE] Completed deferred officialSite lookup for '\(band)'")
                    }
                }
                print("⏳ [YEAR_CHANGE] Queuing officialSite lookup for '\(band)' - will complete after year change")
            } else {
                // Safe to query SQLite now
                if let bandData = dataManager.fetchBand(byName: band, eventYear: eventYear) {
                    let officialSite = bandData.officialSite ?? ""
                    if !officialSite.isEmpty {
                        result = officialSite.hasPrefix("http") ? officialSite : "http://\(officialSite)"
                        print("🔧 OFFLINE MODE: Retrieved officialSite '\(result)' from SQLite for band '\(band)'")
                    }
                }
            }
        }
        
        print("Getting officalSite for band \(band) will return \(result) (SQLite)")
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
        
        // OFFLINE MODE FIX: Fall back to SQLite if in-memory cache doesn't have data
        // CRITICAL: If year change is in progress, queue the lookup for after year change completes
        if wikipediaUrl.isEmpty {
            if MasterViewController.isYearChangeInProgress {
                // Queue this lookup to happen after year change completes
                queueBandLookupForAfterYearChange(bandName: bandName, field: "wikipedia") { wikipedia in
                    if !wikipedia.isEmpty {
                        staticBandName.sync {
                            if self.bandNames[bandName] == nil {
                                self.bandNames[bandName] = [:]
                            }
                            self.bandNames[bandName]?["wikipediaLink"] = wikipedia
                        }
                        print("✅ [YEAR_CHANGE] Completed deferred wikipedia lookup for '\(bandName)'")
                    }
                }
                print("⏳ [YEAR_CHANGE] Queuing wikipedia lookup for '\(bandName)' - will complete after year change")
            } else {
                // Safe to query SQLite now
                if let bandData = dataManager.fetchBand(byName: bandName, eventYear: eventYear) {
                    wikipediaUrl = bandData.wikipedia ?? ""
                    print("🔧 OFFLINE MODE: Retrieved wikipedia '\(wikipediaUrl)' from SQLite for band '\(bandName)'")
                }
            }
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
        
        // OFFLINE MODE FIX: Fall back to SQLite if in-memory cache doesn't have data
        // CRITICAL: If year change is in progress, queue the lookup for after year change completes
        if youTubeUrl.isEmpty {
            if MasterViewController.isYearChangeInProgress {
                queueBandLookupForAfterYearChange(bandName: bandName, field: "youtube") { youtube in
                    if !youtube.isEmpty {
                        staticBandName.sync {
                            if self.bandNames[bandName] == nil {
                                self.bandNames[bandName] = [:]
                            }
                            self.bandNames[bandName]?["youtubeLinks"] = youtube
                        }
                        print("✅ [YEAR_CHANGE] Completed deferred youtube lookup for '\(bandName)'")
                    }
                }
                print("⏳ [YEAR_CHANGE] Queuing youtube lookup for '\(bandName)' - will complete after year change")
            } else {
                if let bandData = dataManager.fetchBand(byName: bandName, eventYear: eventYear) {
                    youTubeUrl = bandData.youtube ?? ""
                    print("🔧 OFFLINE MODE: Retrieved youtube '\(youTubeUrl)' from SQLite for band '\(bandName)'")
                }
            }
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
        
        // OFFLINE MODE FIX: Fall back to SQLite if in-memory cache doesn't have data
        // CRITICAL: If year change is in progress, queue the lookup for after year change completes
        if result.isEmpty {
            if MasterViewController.isYearChangeInProgress {
                queueBandLookupForAfterYearChange(bandName: bandName, field: "metalArchives") { metalArchives in
                    if !metalArchives.isEmpty {
                        staticBandName.sync {
                            if self.bandNames[bandName] == nil {
                                self.bandNames[bandName] = [:]
                            }
                            self.bandNames[bandName]?["metalArchiveLinks"] = metalArchives
                        }
                        print("✅ [YEAR_CHANGE] Completed deferred metalArchives lookup for '\(bandName)'")
                    }
                }
                print("⏳ [YEAR_CHANGE] Queuing metalArchives lookup for '\(bandName)' - will complete after year change")
            } else {
                if let bandData = dataManager.fetchBand(byName: bandName, eventYear: eventYear) {
                    result = bandData.metalArchives ?? ""
                    print("🔧 OFFLINE MODE: Retrieved metalArchives '\(result)' from SQLite for band '\(bandName)'")
                }
            }
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
        
        // OFFLINE MODE FIX: Fall back to SQLite if in-memory cache doesn't have data
        // CRITICAL: If year change is in progress, queue the lookup for after year change completes
        if result.isEmpty {
            if MasterViewController.isYearChangeInProgress {
                queueBandLookupForAfterYearChange(bandName: band, field: "country") { country in
                    if !country.isEmpty {
                        staticBandName.sync {
                            if self.bandNames[band] == nil {
                                self.bandNames[band] = [:]
                            }
                            self.bandNames[band]?["bandCountry"] = country
                        }
                        print("✅ [YEAR_CHANGE] Completed deferred country lookup for '\(band)'")
                    }
                }
                print("⏳ [YEAR_CHANGE] Queuing country lookup for '\(band)' - will complete after year change")
            } else {
                if let bandData = dataManager.fetchBand(byName: band, eventYear: eventYear) {
                    result = bandData.country ?? ""
                    print("🔧 OFFLINE MODE: Retrieved country '\(result)' from SQLite for band '\(band)'")
                }
            }
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
        
        // OFFLINE MODE FIX: Fall back to SQLite if in-memory cache doesn't have data
        // CRITICAL: If year change is in progress, queue the lookup for after year change completes
        if result.isEmpty {
            if MasterViewController.isYearChangeInProgress {
                queueBandLookupForAfterYearChange(bandName: band, field: "genre") { genre in
                    if !genre.isEmpty {
                        staticBandName.sync {
                            if self.bandNames[band] == nil {
                                self.bandNames[band] = [:]
                            }
                            self.bandNames[band]?["bandGenre"] = genre
                        }
                        print("✅ [YEAR_CHANGE] Completed deferred genre lookup for '\(band)'")
                    }
                }
                print("⏳ [YEAR_CHANGE] Queuing genre lookup for '\(band)' - will complete after year change")
            } else {
                if let bandData = dataManager.fetchBand(byName: band, eventYear: eventYear) {
                    result = bandData.genre ?? ""
                    print("🔧 OFFLINE MODE: Retrieved genre '\(result)' from SQLite for band '\(band)'")
                }
            }
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
        
        // OFFLINE MODE FIX: Fall back to SQLite if in-memory cache doesn't have data
        // CRITICAL: If year change is in progress, queue the lookup for after year change completes
        if result.isEmpty {
            if MasterViewController.isYearChangeInProgress {
                queueBandLookupForAfterYearChange(bandName: band, field: "noteworthy") { noteworthy in
                    if !noteworthy.isEmpty {
                        staticBandName.sync {
                            if self.bandNames[band] == nil {
                                self.bandNames[band] = [:]
                            }
                            self.bandNames[band]?["bandNoteWorthy"] = noteworthy
                        }
                        print("✅ [YEAR_CHANGE] Completed deferred noteworthy lookup for '\(band)'")
                    }
                }
                print("⏳ [YEAR_CHANGE] Queuing noteworthy lookup for '\(band)' - will complete after year change")
            } else {
                if let bandData = dataManager.fetchBand(byName: band, eventYear: eventYear) {
                    result = bandData.noteworthy ?? ""
                    print("🔧 OFFLINE MODE: Retrieved noteworthy '\(result)' from SQLite for band '\(band)'")
                }
            }
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
        
        // OFFLINE MODE FIX: Fall back to SQLite if in-memory cache doesn't have data
        // CRITICAL: If year change is in progress, queue the lookup for after year change completes
        if previousYears == nil || previousYears!.isEmpty {
            if MasterViewController.isYearChangeInProgress {
                queueBandLookupForAfterYearChange(bandName: band, field: "priorYears") { priorYears in
                    if !priorYears.isEmpty {
                        staticBandName.sync {
                            if self.bandNames[band] == nil {
                                self.bandNames[band] = [:]
                            }
                            self.bandNames[band]?["priorYears"] = priorYears
                        }
                        print("✅ [YEAR_CHANGE] Completed deferred priorYears lookup for '\(band)'")
                    }
                }
                print("⏳ [YEAR_CHANGE] Queuing priorYears lookup for '\(band)' - will complete after year change")
            } else {
                if let bandData = dataManager.fetchBand(byName: band, eventYear: eventYear) {
                    previousYears = bandData.priorYears
                    print("🔧 OFFLINE MODE: Retrieved priorYears '\(previousYears ?? "")' from SQLite for band '\(band)'")
                }
            }
        }
        
        previousYears = previousYears?.replacingOccurrences(of: " ", with: ", ")
        return previousYears ?? ""
    }
}

//
//  scheduleHandler_CoreData.swift
//  70000TonsBands
//
//  Core Data-backed version of scheduleHandler
//  Maintains 100% API compatibility while using database backend
//

import Foundation
import CryptoKit
import CoreData

open class scheduleHandler {
    
    // Singleton instance
    static let shared = scheduleHandler()
    
    // Core Data components
    private let coreDataManager = CoreDataManager.shared
    private let csvImporter = ScheduleCSVImporter()
    
    // Thread-safe queue for all scheduling data access
    private let scheduleHandlerQueue = DispatchQueue(label: "com.yourapp.scheduleHandlerQueue", attributes: .concurrent)
    private let scheduleHandlerQueueKey = DispatchSpecificKey<Bool>()
    
    // CRITICAL: Serial queue specifically for dictionary operations to prevent corruption
    private let dictionaryQueue = DispatchQueue(label: "com.yourapp.scheduleDictionaryQueue")
    
    // Cache for performance (mirrors original structure)
    private var _schedulingData: [String : [TimeInterval : [String : String]]] = [:]
    private var _schedulingDataByTime: [TimeInterval : [[String : String]]] = [:]  // CRITICAL FIX: Array of events per time
    private var cacheLoaded = false
    
    // Thread management to prevent concurrent operations
    private var isDataLoadingInProgress = false
    private var activeLoadingOperationId: UUID?
    private let dataLoadingLock = NSLock()
    
    // Thread-safe accessors (100% compatible with original)
    var schedulingData: [String : [TimeInterval : [String : String]]] {
        get {
            return scheduleHandlerQueue.sync { 
                if !cacheLoaded {
                    loadCacheFromCoreData()
                }
                return dictionaryQueue.sync { 
                    return _schedulingData 
                }
            }
        }
        set {
            dictionaryQueue.sync { 
                self._schedulingData = newValue 
                self.cacheLoaded = true
            }
        }
    }
    
    var schedulingDataByTime: [TimeInterval : [[String : String]]] {
        get {
            return scheduleHandlerQueue.sync { 
                if !cacheLoaded {
                    loadCacheFromCoreData()
                }
                return dictionaryQueue.sync { 
                    return _schedulingDataByTime 
                }
            }
        }
        set {
            dictionaryQueue.sync { 
                self._schedulingDataByTime = newValue 
                self.cacheLoaded = true
            }
        }
    }
    
    // Helper for thread-safe mutation (compatible with original)
    private func mutateSchedulingData(_ block: @escaping (inout [String : [TimeInterval : [String : String]]]) -> Void) {
        scheduleHandlerQueue.async(flags: .barrier) {
            if !self.cacheLoaded {
                self.loadCacheFromCoreData()
            }
            self.dictionaryQueue.sync {
                block(&self._schedulingData)
            }
        }
    }
    
    private func mutateSchedulingDataByTime(_ block: @escaping (inout [TimeInterval : [[String : String]]]) -> Void) {
        scheduleHandlerQueue.async(flags: .barrier) {
            if !self.cacheLoaded {
                self.loadCacheFromCoreData()
            }
            self.dictionaryQueue.sync {
                block(&self._schedulingDataByTime)
            }
        }
    }

    private init() {
        // Set up queue key for thread detection
        scheduleHandlerQueue.setSpecific(key: scheduleHandlerQueueKey, value: true)
        
        print("🔄 scheduleHandler (Core Data) singleton initialized - Deferring data load until preferences are loaded")
        // Don't call getCachedData() here - it will be called when first accessed
        // This prevents cleanup operations before user preferences are loaded
    }
    
    // MARK: - Core Data Cache Management
    
    /// Loads schedule data from Core Data into memory cache for fast access
    private func loadCacheFromCoreData() {
        guard !cacheLoaded else { 
            print("🔍 [SCHEDULE_DEBUG] loadCacheFromCoreData: Cache already loaded, returning early")
            return 
        }
        
        print("🔄 Loading schedule from Core Data...")
        print("🔍 [SCHEDULE_DEBUG] loadCacheFromCoreData: Starting load process")
        
        // CRITICAL: Load user preferences FIRST to ensure correct year resolution
        print("🔍 [SCHEDULE_DEBUG] loadCacheFromCoreData: Loading user preferences before year resolution")
        readFiltersFile()
        
        // CRITICAL: Update eventYear from pointer data like bandNamesHandler does
        print("🔍 [SCHEDULE_DEBUG] loadCacheFromCoreData: Getting pointer data for eventYear")
        let newEventYear = Int(getPointerUrlData(keyValue: "eventYear")) ?? eventYear
        if newEventYear != eventYear {
            print("🔄 Updating eventYear from \(eventYear) to \(newEventYear)")
            eventYear = newEventYear
        }
        
        // Thread-safe dictionary operations
        let isOnScheduleQueue = DispatchQueue.getSpecific(key: scheduleHandlerQueueKey) != nil
        print("🔍 [SCHEDULE_DEBUG] loadCacheFromCoreData: isOnScheduleQueue = \(isOnScheduleQueue)")
        
        // SIMPLIFIED: Since getCachedData() already calls this from within scheduleHandlerQueue.sync,
        // we can always call the internal method directly to avoid nested sync deadlock
        print("🔍 [SCHEDULE_DEBUG] loadCacheFromCoreData: Calling internal method directly (avoiding nested sync)")
        self.loadCacheFromCoreDataInternal()
    }
    
    private func loadCacheFromCoreDataInternal() {
        // Clean up problematic events (zero timeIndex and wrong year events)
        print("🧹 [CLEANUP] Running cleanup for problematic events")
        self.coreDataManager.cleanupProblematicEvents(currentYear: eventYear)
        
        let events = self.coreDataManager.fetchEvents(forYear: Int32(eventYear))
        print("🔄 Fetched \(events.count) events from Core Data for year \(eventYear)")
        
        // Debug: Check if there are any events at all in Core Data
        let allEvents = self.coreDataManager.fetchEvents()
        print("🔍 DEBUG: Total events in Core Data (all years): \(allEvents.count)")
        if allEvents.count > 0 {
            let eventYears = Set(allEvents.compactMap { $0.eventYear })
            print("🔍 DEBUG: Event years in Core Data: \(eventYears.sorted())")
            
            // Debug: Show event type distribution
            let eventTypes = allEvents.compactMap { $0.eventType }
            let typeDistribution = Dictionary(grouping: eventTypes, by: { $0 })
                .mapValues { $0.count }
            print("🔍 DEBUG: Event type distribution: \(typeDistribution)")
            
            // CRITICAL DEBUG: Check for problematic timeIndex values
            let zeroTimeIndexEvents = allEvents.filter { $0.timeIndex == 0.0 }
            print("🚨 [TIMEINDEX_AUDIT] Found \(zeroTimeIndexEvents.count) events with timeIndex = 0.0")
            
            if zeroTimeIndexEvents.count > 0 {
                print("🚨 [TIMEINDEX_AUDIT] Events with timeIndex = 0.0:")
                for event in zeroTimeIndexEvents.prefix(5) { // Show first 5
                    let bandName = event.band?.bandName ?? "Unknown"
                    let eventType = event.eventType ?? "Unknown"
                    let date = event.date ?? "Unknown"
                    let startTime = event.startTime ?? "Unknown"
                    print("🚨 [TIMEINDEX_AUDIT] - \(bandName): \(eventType) on \(date) at \(startTime)")
                }
            }
            
            // Check for events from wrong years
            let wrongYearEvents = allEvents.filter { $0.eventYear != Int32(eventYear) }
            print("🚨 [TIMEINDEX_AUDIT] Found \(wrongYearEvents.count) events from wrong years (current: \(eventYear))")
            
            if wrongYearEvents.count > 0 {
                let wrongYears = Set(wrongYearEvents.compactMap { $0.eventYear })
                print("🚨 [TIMEINDEX_AUDIT] Wrong years found: \(wrongYears.sorted())")
            }
        }
        
        // CRITICAL: Use serial queue for ALL dictionary operations to prevent corruption
        dictionaryQueue.sync {
            // Clear existing data safely
            self._schedulingData.removeAll()
            self._schedulingDataByTime.removeAll()
            
            print("🔍 [CORE_DATA_CONVERSION] Starting conversion of \(events.count) events to dictionary format")
            
            // Debug: Track timeIndex distribution
            var timeIndexCounts: [TimeInterval: Int] = [:]
            
            for event in events {
                // Debug: Check why Show events might be skipped
                if event.eventType == "Show" {
                    print("🔍 [SHOW_DEBUG] Processing Show event:")
                    print("🔍 [SHOW_DEBUG] - event.band = \(event.band?.description ?? "nil")")
                    print("🔍 [SHOW_DEBUG] - event.band?.bandName = \(event.band?.bandName ?? "nil")")
                    print("🔍 [SHOW_DEBUG] - event.location = \(event.location ?? "nil")")
                    print("🔍 [SHOW_DEBUG] - event.timeIndex = \(event.timeIndex)")
                }
                
                guard let band = event.band,
                      let bandName = band.bandName,
                      !bandName.isEmpty else { 
                    if event.eventType == "Show" {
                        print("🚨 [SHOW_DEBUG] SKIPPING Show event due to guard condition failure")
                    }
                    continue 
                }
                
                let timeIndex = event.timeIndex
                
                // Debug: Track timeIndex distribution
                timeIndexCounts[timeIndex, default: 0] += 1
                
                // Map Core Data fields to legacy dictionary format
                var eventData = [String : String]()
                eventData[bandField] = bandName
                eventData[locationField] = event.location ?? ""
                eventData[dateField] = event.date ?? ""
                eventData[dayField] = event.day ?? ""
                eventData[startTimeField] = event.startTime ?? ""
                eventData[endTimeField] = event.endTime ?? ""
                eventData[typeField] = event.eventType ?? ""
                eventData[notesField] = event.notes ?? ""
                eventData[descriptionUrlField] = event.descriptionUrl ?? ""
                eventData[imageUrlField] = event.eventImageUrl ?? ""
                // CRITICAL: Include the unique identifier in the event data
                eventData["identifier"] = event.identifier ?? "\(timeIndex):\(bandName)"
                
                // Initialize band data if needed (now thread-safe)
                if self._schedulingData[bandName] == nil {
                    self._schedulingData[bandName] = [TimeInterval : [String : String]]()
                }
                
                // Store in both data structures using safer non-optional approach
                self._schedulingData[bandName]![timeIndex] = eventData
                
                // CRITICAL FIX: Store events in array to prevent data loss when multiple events share same timeIndex
                if self._schedulingDataByTime[timeIndex] == nil {
                    self._schedulingDataByTime[timeIndex] = []
                }
                self._schedulingDataByTime[timeIndex]!.append(eventData)
                
                print("🔍 [CORE_DATA_CONVERSION] Converted event: '\(bandName)' - '\(eventData[typeField] ?? "unknown type")' at timeIndex \(timeIndex)")
                if eventData[typeField] == "Show" {
                    print("🔍 [SHOW_EVENT_DEBUG] ✅ LOADING Show event into cache for '\(bandName)' at '\(eventData[locationField] ?? "nil")' - timeIndex: \(timeIndex)")
                }
                print("🔍 [CORE_DATA_CONVERSION] Event data: \(eventData)")
                
                // Debug: Check if the data was actually stored correctly
                if let storedData = self._schedulingData[bandName]?[timeIndex] {
                    print("🔍 [CORE_DATA_CONVERSION] ✅ Successfully stored data for \(bandName) at \(timeIndex)")
                } else {
                    print("🔍 [CORE_DATA_CONVERSION] ❌ Failed to store data for \(bandName) at \(timeIndex)")
                }
            }
            
            // Debug: Show timeIndex distribution
            print("🔍 [CORE_DATA_CONVERSION] TimeIndex distribution:")
            let sortedTimeIndices = timeIndexCounts.keys.sorted()
            for timeIndex in sortedTimeIndices.prefix(10) { // Show first 10
                let count = timeIndexCounts[timeIndex]!
                let date = Date(timeIntervalSince1970: timeIndex)
                print("🔍 [CORE_DATA_CONVERSION] TimeIndex \(timeIndex) (\(date)): \(count) events")
            }
            if sortedTimeIndices.count > 10 {
                print("🔍 [CORE_DATA_CONVERSION] ... and \(sortedTimeIndices.count - 10) more time indices")
            }
            
            print("🔍 [CORE_DATA_CONVERSION] Conversion complete: \(self._schedulingData.count) bands, \(self._schedulingDataByTime.count) time slots")
            self.cacheLoaded = true
        }
        
        print("✅ Loaded \(events.count) events from Core Data into cache")
    }
    
    // MARK: - Original API Methods (100% Compatible)
    
    /// PERFORMANCE OPTIMIZED: Load schedule data from cache immediately (no network calls)
    func loadCachedDataImmediately() {
        print("🚀 scheduleHandler: Loading cached data immediately (no network calls)")
        
        // Ensure year is synchronized
        let newEventYear = ensureYearResolvedAtLaunch()
        if newEventYear != eventYear {
            print("🔄 scheduleHandler: Updating eventYear from \(eventYear) to \(newEventYear)")
            eventYear = newEventYear
        }
        
        // Load from Core Data cache immediately (thread-safe)
        var eventCount = 0
        scheduleHandlerQueue.sync {
            loadCacheFromCoreData()
            eventCount = dictionaryQueue.sync {
                return self._schedulingData.count
            }
        }
        if eventCount == 0 {
            print("⚠️ scheduleHandler: No cached schedule data available")
        } else {
            print("✅ scheduleHandler: Loaded \(eventCount) cached events immediately")
        }
    }
    
    func getCachedData() {
        print("Loading schedule data cache (Core Data backend)")
        print("🔍 DEBUG: Current eventYear = \(eventYear)")
        print("🔍 DEBUG: cacheLoaded = \(cacheLoaded)")
        print("🔍 [SCHEDULE_DEBUG] getCachedData: Starting method")
        var needsNetworkFetch = false
        var showedData = false

        // CRITICAL FIX: Check if we're already on the scheduleHandlerQueue to avoid deadlock
        let isOnScheduleQueue = DispatchQueue.getSpecific(key: scheduleHandlerQueueKey) != nil
        print("🔍 [SCHEDULE_DEBUG] getCachedData: isOnScheduleQueue = \(isOnScheduleQueue)")
        
        if isOnScheduleQueue {
            // Already on the queue - execute directly to avoid deadlock
            print("🔍 [SCHEDULE_DEBUG] getCachedData: Already on queue, executing directly")
            getCachedDataInternal(needsNetworkFetch: &needsNetworkFetch, showedData: &showedData)
        } else {
            // Not on queue - use sync as before
            print("🔍 [SCHEDULE_DEBUG] getCachedData: About to enter scheduleHandlerQueue.sync")
            scheduleHandlerQueue.sync {
                getCachedDataInternal(needsNetworkFetch: &needsNetworkFetch, showedData: &showedData)
            }
        }

        handlePostSyncOperations(needsNetworkFetch: needsNetworkFetch, showedData: showedData)
    }
    
    private func getCachedDataInternal(needsNetworkFetch: inout Bool, showedData: inout Bool) {
        print("🔍 [SCHEDULE_DEBUG] getCachedDataInternal: Starting")
        // Load from Core Data if cache not loaded (thread-safe)
        if !cacheLoaded {
            print("🔍 DEBUG: Cache not loaded, calling loadCacheFromCoreData()")
            print("🔍 [SCHEDULE_DEBUG] getCachedDataInternal: About to call loadCacheFromCoreData()")
            loadCacheFromCoreData()
            print("🔍 [SCHEDULE_DEBUG] getCachedDataInternal: Returned from loadCacheFromCoreData()")
        } else {
            print("🔍 DEBUG: Cache already loaded, skipping loadCacheFromCoreData()")
        }
        
        let hasData = dictionaryQueue.sync { return !self._schedulingData.isEmpty }
        if hasData {
            // Cache is available, show immediately
            print("Loading schedule data cache, from Core Data cache")
            showedData = true
        } else if !cacheVariables.scheduleStaticCache.isEmpty {
            // cacheVariables has data, load into memory and show immediately
            print("Loading schedule data cache, from cacheVariables")
            scheduleHandlerQueue.async(flags: .barrier) {
                self.dictionaryQueue.sync {
                    self._schedulingData = cacheVariables.scheduleStaticCache
                    self._schedulingDataByTime = cacheVariables.scheduleTimeStaticCache
                }
                self.cacheLoaded = true
            }
            showedData = true
        } else {
            // No data at all, need to fetch from network (first launch or forced)
            needsNetworkFetch = true
        }
        print("🔍 [SCHEDULE_DEBUG] getCachedDataInternal: Completed")
    }
    
    private func handlePostSyncOperations(needsNetworkFetch: Bool, showedData: Bool) {
        print("🔍 [SCHEDULE_DEBUG] handlePostSyncOperations: needsNetworkFetch=\(needsNetworkFetch), showedData=\(showedData)")

        if showedData {
            // Update static cache
            staticSchedule.sync {
                cacheVariables.scheduleStaticCache = self._schedulingData
                cacheVariables.scheduleTimeStaticCache = self._schedulingDataByTime
            }
        } else if needsNetworkFetch {
            // If we need to fetch from network, trigger download
            if cacheVariables.justLaunched {
                print("First app launch detected - deferring network download to proper loading sequence")
                print("This prevents infinite retry loops when network is unavailable")
            } else {
                print("No cached/Core Data data, fetching from network")
                DispatchQueue.main.async {
                    // CRITICAL FIX: When Core Data is empty, we need to force download
                    self.populateSchedule(forceDownload: true)
                }
            }
        }
        print("🔍 [SCHEDULE_DEBUG] getCachedData: Completing method")
        print("Done Loading schedule data cache")
    }
    
    func clearCache() {
        print("[YEAR_CHANGE_DEBUG] Clearing schedule cache for year \(eventYear)")
        print("🔍 [SCHEDULE_DEBUG] clearCache: Starting cache clear")
        scheduleHandlerQueue.async(flags: .barrier) {
            print("🔍 [SCHEDULE_DEBUG] clearCache: Inside barrier block")
            self.dictionaryQueue.sync {
                self._schedulingData = [:]
                self._schedulingDataByTime = [:]
            }
            self.cacheLoaded = false
            print("🔍 [SCHEDULE_DEBUG] clearCache: Cache cleared, cacheLoaded = false")
        }
        
        // Also clear the static cache
        staticSchedule.sync {
            cacheVariables.scheduleStaticCache = [:]
            cacheVariables.scheduleTimeStaticCache = [:]
        }
    }
    
    /// Calculates SHA256 checksum of a string
    private func calculateChecksum(_ data: String) -> String {
        let inputData = Data(data.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Gets the stored checksum for the current schedule data file
    private func getStoredChecksum() -> String? {
        let checksumFile = getDocumentsDirectory().appendingPathComponent("scheduleFile.checksum")
        return try? String(contentsOfFile: checksumFile, encoding: .utf8)
    }
    
    /// Stores the checksum for the schedule data file
    private func storeChecksum(_ checksum: String) {
        let checksumFile = getDocumentsDirectory().appendingPathComponent("scheduleFile.checksum")
        do {
            try checksum.write(toFile: checksumFile, atomically: true, encoding: .utf8)
            print("✅ Stored schedule data checksum: \(String(checksum.prefix(8)))...")
        } catch {
            print("❌ Error storing schedule data checksum: \(error)")
        }
    }
    
    func populateSchedule(forceDownload: Bool = false, isYearChangeOperation: Bool = false) {
        let operationId = UUID()
        
        // CRITICAL: Atomic check and set to prevent race conditions
        dataLoadingLock.lock()
        
        if isDataLoadingInProgress {
            if isYearChangeOperation {
                // Year change operations have priority - kill the existing operation
                print("🔄 [THREAD_MGMT] Year change operation detected - cancelling existing operation \(activeLoadingOperationId?.uuidString ?? "unknown")")
                print("🔄 [THREAD_MGMT] Starting new year change operation: \(operationId.uuidString)")
                // Force reset the loading state to allow year change to proceed
                isDataLoadingInProgress = false
                isLoadingSchedule = false
            } else {
                // Regular operation - kill Thread B if Thread A is already running
                print("🚫 [THREAD_MGMT] Data loading already in progress (Operation: \(activeLoadingOperationId?.uuidString ?? "unknown"))")
                print("🚫 [THREAD_MGMT] Killing Thread B operation: \(operationId.uuidString)")
                dataLoadingLock.unlock()
                return
            }
        }
        
        // Set up the new operation while still holding the lock
        isDataLoadingInProgress = true
        activeLoadingOperationId = operationId
        print("✅ [THREAD_MGMT] Starting data loading operation: \(operationId.uuidString), isYearChange: \(isYearChangeOperation)")
        
        // Release lock after setting up the operation
        dataLoadingLock.unlock()
        
        // Legacy compatibility
        if isLoadingSchedule && !isYearChangeOperation {
            print("[YEAR_CHANGE_DEBUG] Schedule loading already in progress, skipping duplicate request")
            isDataLoadingInProgress = false
            activeLoadingOperationId = nil
            return
        }
        
        // CRITICAL: Update eventYear from pointer data like bandNamesHandler does
        let newEventYear = Int(getPointerUrlData(keyValue: "eventYear")) ?? eventYear
        if newEventYear != eventYear {
            print("🔄 populateSchedule: Updating eventYear from \(eventYear) to \(newEventYear)")
            eventYear = newEventYear
        }
        
        print("[YEAR_CHANGE_DEBUG] Loading schedule data for year \(eventYear), forceDownload: \(forceDownload)")
        isLoadingSchedule = true
        
        // Ensure all loading flags are always reset, even if there are errors
        defer {
            dataLoadingLock.lock()
            isDataLoadingInProgress = false
            if activeLoadingOperationId == operationId {
                activeLoadingOperationId = nil
            }
            dataLoadingLock.unlock()
            
            isLoadingSchedule = false
            print("✅ [THREAD_MGMT] Operation completed: \(operationId.uuidString)")
            print("[YEAR_CHANGE_DEBUG] Schedule loading completed, all flags reset")
        }
        
        var dataChanged = false
        var newDataValid = false
        
        // Only download from network if explicitly forced
        if forceDownload && isInternetAvailable() == true {
            // Clear current data only when we're actually downloading new data
            print("🔍 [SCHEDULE_DEBUG] populateSchedule: Clearing cache before download")
            clearCache()
            print("DEBUG_MARKER: Starting CSV download process (Core Data backend)")
            print("DEBUG_MARKER: Event year: \(eventYear)")
            
            let scheduleUrl = getPointerUrlData(keyValue: "scheduleUrl") ?? ""
            print("DEBUG_MARKER: Schedule URL from pointer: \(scheduleUrl)")
            print("DEBUG_MARKER: Schedule URL pointer key: \(getScheduleUrl())")
            
            // Validate URL before attempting download
            guard !scheduleUrl.isEmpty && scheduleUrl != "Default" && scheduleUrl.hasPrefix("http") else {
                print("❌ scheduleHandler: Invalid schedule URL '\(scheduleUrl)', skipping download")
                return
            }
            
            print("DEBUG_MARKER: Downloading from URL: \(scheduleUrl)")
            
            // Ensure network call happens on background thread to prevent main thread blocking
            var httpData = ""
            if Thread.isMainThread {
                print("scheduleHandler: Main thread detected, dispatching to background for network call")
                let semaphore = DispatchSemaphore(value: 0)
                DispatchQueue.global(qos: .userInitiated).async {
                    httpData = getUrlData(urlString: scheduleUrl)
                    semaphore.signal()
                }
                semaphore.wait()
            } else {
                httpData = getUrlData(urlString: scheduleUrl)
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
            
            // Check if file has valid headers - this is a valid state even without data
            let hasValidHeaders = httpData.contains("Band,Location,Date,Day,Start Time,End Time,Type")
            if hasValidHeaders {
                scheduleReleased = true
                print("DEBUG_MARKER: Schedule file has valid headers - marking as released even if no data rows")
            }
            
            // Only proceed if data appears valid
            if (httpData.isEmpty == false && (httpData.count > 100 || hasValidHeaders)) {
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
                
                // Smart import detection: Force import if we have large CSV but few events
                let currentEventCount = coreDataManager.fetchEvents(forYear: Int32(eventYear)).count
                if httpData.count > 1000 && currentEventCount < 5 {
                    print("DEBUG_MARKER: Smart import triggered - Downloaded \(httpData.count) chars but only \(currentEventCount) events in Core Data")
                    storedChecksum = nil // Force import
                }
                
                // Compare checksums to determine if data has changed
                if storedChecksum != newChecksum {
                    print("DEBUG_MARKER: Data has changed - importing to Core Data")
                    print("DEBUG_MARKER: Old checksum: \(storedChecksum?.prefix(8) ?? "none")")
                    print("DEBUG_MARKER: New checksum: \(newChecksum.prefix(8))")
                    dataChanged = true
                    
                    // Import new data to Core Data with smart update/delete logic
                    print("DEBUG_MARKER: Calling smart CSV import")
                    let importSuccess = csvImporter.importEventsFromCSVString(httpData)
                    print("DEBUG_MARKER: Smart CSV import result: \(importSuccess)")
                    
                    if importSuccess {
                        // Store new checksum only if import was successful
                        storeChecksum(newChecksum)
                        print("DEBUG_MARKER: Successfully updated Core Data and stored new checksum")
                        
                        // Reload cache from Core Data
                        cacheLoaded = false
                        loadCacheFromCoreData()
                    } else {
                        print("DEBUG_MARKER: Import failed - keeping old checksum")
                    }
                } else {
                    print("DEBUG_MARKER: Data unchanged - checksum: \(newChecksum.prefix(8))")
                    dataChanged = false
                }
            } else {
                print("❌ Internet is down or data is invalid, keeping existing data")
                newDataValid = false
                dataChanged = false
            }
        } else if !forceDownload {
            print("📖 populateSchedule called without forceDownload - only reading from Core Data cache")
            loadCacheFromCoreData()
        } else {
            print("📡 No internet available, keeping existing data")
            newDataValid = false
            dataChanged = false
        }
        
        // Update static cache
        staticSchedule.sync {
            dictionaryQueue.sync {
                cacheVariables.scheduleStaticCache = self._schedulingData
                cacheVariables.scheduleTimeStaticCache = self._schedulingDataByTime
            }
        }
        
        // Safe access to dictionary counts through the serial queue
        let (bandCount, timeSlotCount) = dictionaryQueue.sync {
            return (self._schedulingData.count, self._schedulingDataByTime.count)
        }
        print("[YEAR_CHANGE_DEBUG] Schedule population completed for year \(eventYear): \(bandCount) bands, \(timeSlotCount) time slots")
        
        // Check if combined image list needs regeneration after schedule data is loaded
        if dataChanged {
            print("[YEAR_CHANGE_DEBUG] Schedule data downloaded from URL, checking if combined image list needs regeneration")
            DispatchQueue.global(qos: .utility).async {
                let bandNameHandle = bandNamesHandler.shared
                if CombinedImageListHandler.shared.needsRegeneration(bandNameHandle: bandNameHandle, scheduleHandle: self) {
                    print("[YEAR_CHANGE_DEBUG] Regenerating combined image list due to new schedule data")
                    CombinedImageListHandler.shared.generateCombinedImageList(
                        bandNameHandle: bandNameHandle,
                        scheduleHandle: self
                    ) {
                        print("[YEAR_CHANGE_DEBUG] Combined image list regenerated after schedule data load")
                    }
                }
            }
        }
    }
    
    // MARK: - Legacy API Methods (100% Compatible)
    
    func DownloadCsv() {
        let scheduleUrl = getPointerUrlData(keyValue: "scheduleUrl") ?? ""
        
        // Validate URL before attempting download
        guard !scheduleUrl.isEmpty && scheduleUrl != "Default" && scheduleUrl.hasPrefix("http") else {
            print("❌ scheduleHandler: Invalid schedule URL '\(scheduleUrl)', skipping download")
            return
        }
        
        print("Downloading Schedule URL " + scheduleUrl)
        
        // Ensure network call happens on background thread to prevent main thread blocking
        var httpData = ""
        if Thread.isMainThread {
            print("scheduleHandler: Main thread detected, dispatching to background for network call")
            let semaphore = DispatchSemaphore(value: 0)
            DispatchQueue.global(qos: .userInitiated).async {
                httpData = getUrlData(urlString: scheduleUrl)
                semaphore.signal()
            }
            semaphore.wait()
        } else {
            httpData = getUrlData(urlString: scheduleUrl)
        }
        
        if !httpData.isEmpty {
            // Import directly to Core Data instead of writing to file
            let importSuccess = csvImporter.importEventsFromCSVString(httpData)
            if importSuccess {
                // Reload cache from Core Data
                cacheLoaded = false
                loadCacheFromCoreData()
                print("Successfully downloaded and imported schedule data to Core Data")
            } else {
                print("Failed to import downloaded schedule data")
            }
        } else {
            print("Failed to download schedule data")
        }
    }
    
    func getDateIndex(_ dateString: String, timeString: String, band: String) -> TimeInterval {
        let fullTimeString: String = dateString + " " + timeString
        
        print("🔍 [TIMEINDEX_DEBUG] scheduleHandler.getDateIndex for '\(band)': '\(fullTimeString)'")
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        // PRIMARY FORMAT: Based on actual CSV format (M/d/yyyy HH:mm)
        let primaryFormats = [
            "M/d/yyyy HH:mm",         // Single digit month/day + 24-hour (MOST LIKELY)
            "MM/dd/yyyy HH:mm",       // Double digit + 24-hour
            "M/d/yyyy H:mm",          // Single digit + single hour
            "MM/dd/yyyy H:mm"         // Double digit + single hour
        ]
        
        for format in primaryFormats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: fullTimeString) {
                let timeInterval = date.timeIntervalSince1970
                print("🔍 [TIMEINDEX_DEBUG] scheduleHandler ✅ Format '\(format)' worked: \(date) -> \(timeInterval)")
                return timeInterval
            }
        }
        
        // FALLBACK FORMATS: For compatibility
        let fallbackFormats = [
            "M/d/yyyy h:mm a",        // 12-hour with AM/PM
            "MM/dd/yyyy h:mm a",      // 12-hour with AM/PM (padded)
            "yyyy-MM-dd HH:mm"        // ISO-like format
        ]
        
        for format in fallbackFormats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: fullTimeString) {
                let timeInterval = date.timeIntervalSince1970
                print("🔍 [TIMEINDEX_DEBUG] scheduleHandler ✅ Fallback format '\(format)' worked: \(timeInterval)")
                return timeInterval
            }
        }
        
        print("🚨 [TIMEINDEX_AUDIT] scheduleHandler: Failed to parse date '\(fullTimeString)' for band \(band)")
        return 0 // Keep legacy behavior for scheduleHandler
    }
    
    func getCurrentIndex(_ bandName: String) -> TimeInterval {
        let currentDate = Date()
        let events = coreDataManager.fetchEvents(forYear: Int32(eventYear))
        
        // Find the event for this band that's closest to current time
        var closestIndex: TimeInterval = 0
        var closestDifference: TimeInterval = TimeInterval.greatestFiniteMagnitude
        
        for event in events {
            guard let band = event.band, band.bandName == bandName else { continue }
            
            let eventDate = Date(timeIntervalSince1970: event.timeIndex)
            let difference = abs(eventDate.timeIntervalSince(currentDate))
            
            if difference < closestDifference {
                closestDifference = difference
                closestIndex = event.timeIndex
            }
        }
        
        return closestIndex
    }
    
    func setData(bandName: String, index: TimeInterval, variable: String, value: String) {
        scheduleHandlerQueue.async(flags: .barrier) {
            if !self.cacheLoaded {
                self.loadCacheFromCoreData()
            }
            
            // All dictionary operations now use the serial dictionary queue
            self.dictionaryQueue.sync {
                // Initialize structures if needed
                if self._schedulingData[bandName] == nil {
                    self._schedulingData[bandName] = [TimeInterval : [String : String]]()
                }
                
                // Safe nested dictionary access
                if self._schedulingData[bandName]?[index] == nil {
                    self._schedulingData[bandName]?[index] = [String : String]()
                }
                self._schedulingData[bandName]?[index]?[variable] = value
                
                // Also update the time-sorted data - find the event for this band and update it
                if let eventArrayIndex = self._schedulingDataByTime[index]?.firstIndex(where: { $0[bandField] == bandName }) {
                    self._schedulingDataByTime[index]?[eventArrayIndex][variable] = value
                } else {
                    // Event not found in time-sorted data, add it
                    var newEventData = [String : String]()
                    newEventData[bandField] = bandName
                    newEventData[variable] = value
                    if self._schedulingDataByTime[index] == nil {
                        self._schedulingDataByTime[index] = []
                    }
                    self._schedulingDataByTime[index]!.append(newEventData)
                }
            }
        }
    }
    
    func isSchedulingDataPresent(schedulingData: [String : [TimeInterval : [String : String]]], bandName: String) -> Bool {
        return schedulingData[bandName] != nil && !(schedulingData[bandName]?.isEmpty ?? true)
    }
    
    func getData(_ bandName: String, index: TimeInterval, variable: String) -> String {
        guard !variable.isEmpty else { return "" }
        return scheduleHandlerQueue.sync {
            if !self.cacheLoaded {
                self.loadCacheFromCoreData()
            }
            
            guard let bandDict = self.dictionaryQueue.sync(execute: { return self._schedulingData[bandName] }) else {
                return ""
            }
            guard let timeDict = bandDict[index] else {
                return ""
            }
            guard let value = timeDict[variable], !value.isEmpty else {
                return ""
            }
            return value
        }
    }
    
    func buildTimeSortedSchedulingData() {
        print("[YEAR_CHANGE_DEBUG] Building time-sorted scheduling data for year \(eventYear)")
        
        // CRITICAL FIX: Always execute synchronously to ensure data is available immediately
        // The original async dispatch was causing race conditions where determineBandOrScheduleList
        // would call this function but then immediately try to access empty data structures
        scheduleHandlerQueue.sync {
            if !self.cacheLoaded {
                self.loadCacheFromCoreData()
            }
            
            self.dictionaryQueue.sync {
                self._schedulingDataByTime = [TimeInterval : [[String : String]]]()
                
                for (bandName, timeData) in self._schedulingData {
                    for (timeIndex, eventData) in timeData {
                        // CRITICAL FIX: Store events in array to prevent data loss
                        if self._schedulingDataByTime[timeIndex] == nil {
                            self._schedulingDataByTime[timeIndex] = []
                        }
                        self._schedulingDataByTime[timeIndex]!.append(eventData)
                    }
                }
            }
            
            let timeSlotCount = self.dictionaryQueue.sync { return self._schedulingDataByTime.count }
            print("[YEAR_CHANGE_DEBUG] Built time-sorted data with \(timeSlotCount) time slots")
        }
    }
    
    func getTimeSortedSchedulingData() -> [TimeInterval : [[String : String]]] {
        let data = schedulingDataByTime
        let totalEvents = data.values.reduce(0) { $0 + $1.count }
        print("🔍 [SCHEDULE_DATA_DEBUG] getTimeSortedSchedulingData returning \(data.count) time slots with \(totalEvents) total events")
        return data
    }
    
    func getBandSortedSchedulingData() -> [String : [TimeInterval : [String : String]]] {
        let data = schedulingData
        print("🔍 [SCHEDULE_DATA_DEBUG] getBandSortedSchedulingData returning \(data.count) bands")
        if data.isEmpty {
            print("🔍 [SCHEDULE_DATA_DEBUG] ❌ EMPTY: No band data available!")
        } else {
            for (bandName, timeData) in data.prefix(3) {
                print("🔍 [SCHEDULE_DATA_DEBUG] Band '\(bandName)' has \(timeData.count) events")
            }
        }
        return data
    }
    
    func convertStringToNSDate(_ dateStr: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy h:mm a"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let date = dateFormatter.date(from: dateStr)
        return date ?? Date()
    }
    
    // MARK: - Data Collection API (for DataCollectionCoordinator compatibility)
    
    func gatherData(forceDownload: Bool = false, isYearChangeOperation: Bool = false, completion: (() -> Void)? = nil) {
        populateSchedule(forceDownload: forceDownload, isYearChangeOperation: isYearChangeOperation)
        completion?()
    }
    
    // MARK: - Band-Specific Event Queries
    
    /// Gets all events for a specific band directly from Core Data
    /// This method is intended for use by the details view to show all events for a band
    /// - Parameters:
    ///   - bandName: The name of the band to get events for
    ///   - includeExpired: If true, includes expired events. If false, only future events
    /// - Returns: Array of dictionaries with event data in the legacy format
    func getEventsForBand(_ bandName: String, includeExpired: Bool = true) -> [[String: String]] {
        print("🔍 [BAND_EVENTS_DEBUG] Getting events for band: '\(bandName)', includeExpired: \(includeExpired)")
        
        // Get events directly from Core Data
        let events = coreDataManager.fetchEventsForBand(bandName, forYear: Int32(eventYear))
        var eventDataArray: [[String: String]] = []
        
        let currentTime = Date().timeIntervalSince1970
        
        for event in events {
            guard let band = event.band,
                  let eventBandName = band.bandName,
                  eventBandName == bandName else { continue }
            
            // Check if event is expired and if we should include it
            if !includeExpired {
                let eventEndTime = event.timeIndex + 3600 // Assume 1 hour duration if no end time
                if eventEndTime <= currentTime {
                    print("🔍 [BAND_EVENTS_DEBUG] Skipping expired event: \(event.eventType ?? "unknown") at \(event.timeIndex)")
                    continue
                }
            }
            
            // Convert Core Data event to legacy dictionary format
            var eventData = [String: String]()
            eventData[bandField] = eventBandName
            eventData[locationField] = event.location ?? ""
            eventData[dateField] = event.date ?? ""
            eventData[dayField] = event.day ?? ""
            eventData[startTimeField] = event.startTime ?? ""
            eventData[endTimeField] = event.endTime ?? ""
            eventData[typeField] = event.eventType ?? ""
            eventData[notesField] = event.notes ?? ""
            eventData[descriptionUrlField] = event.descriptionUrl ?? ""
            eventData[imageUrlField] = event.eventImageUrl ?? ""
            // CRITICAL: Include the unique identifier in the event data
            eventData["identifier"] = event.identifier ?? "\(event.timeIndex):\(eventBandName)"
            
            eventDataArray.append(eventData)
            print("🔍 [BAND_EVENTS_DEBUG] Added event: \(event.eventType ?? "unknown") for \(eventBandName)")
        }
        
        print("🔍 [BAND_EVENTS_DEBUG] Returning \(eventDataArray.count) events for band '\(bandName)'")
        return eventDataArray
    }
}

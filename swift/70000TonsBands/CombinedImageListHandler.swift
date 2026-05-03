//
//  CombinedImageListHandler.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/2/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation

/// Stores image information including URL and optional expiration date
struct ImageInfo: Codable {
    let url: String
    let date: String?  // ImageDate for cache invalidation (schedule images only)
    
    init(url: String, date: String? = nil) {
        self.url = url
        self.date = date
    }
}

/// Handles the combined image list that merges artist and event images
/// Artists take priority over events when both have image URLs
class CombinedImageListHandler {
    
    // Thread-safe queue for image list access
    private let imageListQueue = DispatchQueue(label: "com.yourapp.combinedImageList", attributes: .concurrent)
    
    // Private backing store for the combined image list
    private var _combinedImageList: [String: ImageInfo] = [:]
    
    // Thread-safe accessor
    var combinedImageList: [String: ImageInfo] {
        get {
            return imageListQueue.sync { _combinedImageList }
        }
        set {
            imageListQueue.async(flags: .barrier) {
                self._combinedImageList = newValue
            }
        }
    }
    
    // File path for the combined image list cache
    private let combinedImageListFile = URL(fileURLWithPath: getDocumentsDirectory().appendingPathComponent("combinedImageList.json"))
    
    // Track if async generation is in progress to prevent multiple simultaneous generations
    private var isGenerating = false
    
    // Track if we've recently completed a forced synchronous refresh
    private var lastForcedRefreshTimestamp: Date?
    private let forcedRefreshCooldown: TimeInterval = 5.0 // 5 seconds between forced refreshes
    
    /// Singleton instance
    static let shared = CombinedImageListHandler()
    
    private init() {
        print("📋 [IMAGE_DEBUG] CombinedImageListHandler initializing...")
        loadCombinedImageList()
        print("📋 [IMAGE_DEBUG] CombinedImageListHandler initialized with \(combinedImageList.count) entries")
    }
    
    /// Normalizes image URLs by adding protocol prefix if missing
    /// This matches the behavior in bandNamesHandler.getBandImageUrl() and Android's getImageUrl()
    /// - Parameter url: The URL string to normalize
    /// - Returns: The normalized URL with https:// prefix if it was missing
    private func normalizeImageURL(_ url: String) -> String {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        // If URL doesn't start with http:// or https://, add https:// prefix
        if !trimmed.hasPrefix("http://") && !trimmed.hasPrefix("https://") {
            return "https://\(trimmed)"
        }
        return trimmed
    }
    
    /// Rejects scheme-only or malformed URLs (e.g. bare `https://`) that produce useless requests.
    private func isUsableNormalizedImageURL(_ normalized: String) -> Bool {
        guard let url = URL(string: normalized), let host = url.host, !host.isEmpty else {
            return false
        }
        return true
    }
    
    /// All bands rows for the year (not limited to `lineIndex` / in-memory lineup cache).
    private func mergeBandsTableImageURLs(into list: inout [String: ImageInfo], forYear year: Int) -> Int {
        let bands = DataManager.shared.fetchBands(forYear: year)
        var added = 0
        for band in bands {
            guard let raw = band.imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { continue }
            let withScheme = raw.hasPrefix("http") ? raw : "http://\(raw)"
            let normalized = normalizeImageURL(withScheme)
            guard isUsableNormalizedImageURL(normalized) else { continue }
            list[band.bandName] = ImageInfo(url: normalized, date: nil)
            added += 1
        }
        print("📋 [IMAGE_PIPELINE] SQLite bands table: \(added) usable image URLs from \(bands.count) band rows (year \(year))")
        return added
    }
    
    /// Single source of truth: bands table first, in-memory handler fills gaps, then schedule / SQLite events (only usable URLs).
    private func buildCombinedImageListDictionary(
        bandNameHandle: bandNamesHandler,
        scheduleHandle: scheduleHandler
    ) -> [String: ImageInfo] {
        var newCombinedList: [String: ImageInfo] = [:]
        
        let sqliteArtistURLs = mergeBandsTableImageURLs(into: &newCombinedList, forYear: eventYear)
        
        let bandNames = bandNameHandle.getBandNames()
        print("🧩 [IMAGE_PIPELINE] inputs | sqliteBandImageEntries=\(sqliteArtistURLs) inMemoryArtistNames=\(bandNames.count) scheduleBands=\(scheduleHandle.schedulingData.count)")
        print("📋 Collecting supplemental artist URLs from in-memory cache (no downloads)")
        
        for bandName in bandNames {
            guard newCombinedList[bandName] == nil else { continue }
            let imageUrl = bandNameHandle.getBandImageUrl(bandName)
            guard !imageUrl.isEmpty else { continue }
            let normalizedUrl = normalizeImageURL(imageUrl)
            guard isUsableNormalizedImageURL(normalizedUrl) else { continue }
            newCombinedList[bandName] = ImageInfo(url: normalizedUrl, date: nil)
            print("📋 Added in-memory artist image URL for \(bandName): \(normalizedUrl)")
        }
        
        let scheduleData = scheduleHandle.schedulingData
        print("📋 Collecting image URLs from \(scheduleData.count) schedule events (no downloads)")
        
        if scheduleData.isEmpty {
            print("Schedule data is empty - valid for headers-only or future year. Artist URLs came from DB / cache.")
        }
        
        for (bandName, events) in scheduleData {
            for (_, eventData) in events {
                if let imageUrl = eventData[imageUrlField], !imageUrl.isEmpty {
                    if newCombinedList[bandName] == nil {
                        let imageDate = eventData[imageUrlDateField] as? String
                        let normalizedUrl = normalizeImageURL(imageUrl)
                        guard isUsableNormalizedImageURL(normalizedUrl) else {
                            print("📋 Skipped unusable schedule ImageURL for \(bandName)")
                            continue
                        }
                        newCombinedList[bandName] = ImageInfo(url: normalizedUrl, date: imageDate)
                        if let date = imageDate, !date.isEmpty {
                            print("📋 Added event image URL for \(bandName) with date \(date): \(normalizedUrl)")
                        } else {
                            print("📋 Added event image URL for \(bandName) (no date): \(normalizedUrl)")
                        }
                    } else {
                        print("📋 Skipped event image URL for \(bandName) (artist already has URL): \(imageUrl)")
                    }
                } else if let descriptionUrl = eventData[descriptionUrlField], !descriptionUrl.isEmpty {
                    if newCombinedList[bandName] == nil {
                        let normalizedUrl = normalizeImageURL(descriptionUrl)
                        guard isUsableNormalizedImageURL(normalizedUrl) else {
                            print("📋 Skipped unusable schedule description URL for \(bandName)")
                            continue
                        }
                        newCombinedList[bandName] = ImageInfo(url: normalizedUrl, date: nil)
                        print("Added event description URL for \(bandName): \(normalizedUrl)")
                    } else {
                        print("📋 Skipped event description URL for \(bandName) (artist already has URL): \(descriptionUrl)")
                    }
                } else {
                    print("No image URL found for event: \(bandName)")
                }
            }
        }
        
        print("📋 Fetching events from SQLite (including those without bands)...")
        let sqliteEvents = SQLiteDataManager.shared.fetchEvents(forYear: eventYear)
        print("🧩 [IMAGE_PIPELINE] inputs | sqliteEvents=\(sqliteEvents.count)")
        print("📋 Found \(sqliteEvents.count) events in SQLite for year \(eventYear)")
        
        var processedEventNames = Set<String>()
        for event in sqliteEvents {
            let eventName = event.bandName
            guard !processedEventNames.contains(eventName) else { continue }
            processedEventNames.insert(eventName)
            guard newCombinedList[eventName] == nil else { continue }
            
            if let eventImageUrl = event.eventImageUrl, !eventImageUrl.isEmpty {
                let normalizedUrl = normalizeImageURL(eventImageUrl)
                guard isUsableNormalizedImageURL(normalizedUrl) else {
                    print("📋 Skipped unusable SQLite event image URL for '\(eventName)'")
                    continue
                }
                newCombinedList[eventName] = ImageInfo(url: normalizedUrl, date: nil)
                print("📋 Added SQLite event image URL for '\(eventName)': \(normalizedUrl)")
            } else if let descriptionUrl = event.descriptionUrl, !descriptionUrl.isEmpty {
                let normalizedUrl = normalizeImageURL(descriptionUrl)
                guard isUsableNormalizedImageURL(normalizedUrl) else {
                    print("📋 Skipped unusable SQLite event description URL for '\(eventName)'")
                    continue
                }
                newCombinedList[eventName] = ImageInfo(url: normalizedUrl, date: nil)
                print("📋 Added SQLite event description URL for '\(eventName)': \(normalizedUrl)")
            }
        }
        
        return newCombinedList
    }
    
    /// Generates the combined image list from artist and event data
    /// - Parameters:
    ///   - bandNameHandle: Handler for band/artist data
    ///   - scheduleHandle: Handler for schedule/event data
    ///   - completion: Completion handler called when the list is generated
    func generateCombinedImageList(bandNameHandle: bandNamesHandler, scheduleHandle: scheduleHandler, completion: @escaping () -> Void) {
        print("📋 [IMAGE_DEBUG] generateCombinedImageList called")
        print("🧩 [IMAGE_PIPELINE] generateCombinedImageList START | year=\(eventYear)")
        
        // NOTE: We no longer abort during year changes because:
        // 1. SQLite is thread-safe and won't cause deadlocks
        // 2. Generation is called as part of the official data refresh during year changes
        // 3. The cache is already cleared during year change start, so we won't use stale data
        // 4. We use the current eventYear which is updated early in the year change process
        
        print("📋 Generating combined image URL list (no downloads)...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let newCombinedList = self.buildCombinedImageListDictionary(
                bandNameHandle: bandNameHandle,
                scheduleHandle: scheduleHandle
            )
            
            // Update the combined list
            print("📋 [IMAGE_DEBUG] Updating combinedImageList with \(newCombinedList.count) entries")
            self.combinedImageList = newCombinedList
            
            // Save to disk
            self.saveCombinedImageList()
            
            print("✅ [IMAGE_DEBUG] Combined image URL list generated with \(newCombinedList.count) entries (no downloads performed)")
            print("🧩 [IMAGE_PIPELINE] generateCombinedImageList END | year=\(eventYear) combinedImageList=\(newCombinedList.count)")
            if newCombinedList.count > 0 {
                print("📋 [IMAGE_DEBUG] Sample entries: \(Array(newCombinedList.keys.prefix(5)))")
            }
            
            DispatchQueue.main.async {
                print("📋 [IMAGE_DEBUG] Calling completion handler for generateCombinedImageList")
                completion()
            }
        }
    }
    
    /// Gets the image URL for a given name (artist or event)
    /// - Parameter name: The name to look up
    /// - Returns: The image URL or empty string if not found
    func getImageUrl(for name: String) -> String {
        let currentList = combinedImageList
        
        // If the list is empty, trigger async generation but return immediately to avoid UI blocking
        if currentList.isEmpty {
            print("CombinedImageListHandler: Image list is empty for '\(name)', triggering async generation")
            
            // CRITICAL: Start async generation but return immediately to prevent UI blocking
            triggerAsyncGenerationIfNeeded()
            
            // Return empty immediately - UI should show placeholder until async generation completes
            print("CombinedImageListHandler: Returning empty URL for '\(name)' - async generation in progress")
            return ""
        }
        
        let url = currentList[name]?.url ?? ""
        print("CombinedImageListHandler: Getting image URL for '\(name)': \(url)")
        return url
    }
    
    /// Gets the complete image info (URL and date) for a given name
    /// - Parameter name: The name to look up
    /// - Returns: The ImageInfo or nil if not found
    func getImageInfo(for name: String) -> ImageInfo? {
        let currentList = combinedImageList
        
        print("🔍 [IMAGE_DEBUG] getImageInfo called for '\(name)'")
        print("🔍 [IMAGE_DEBUG] combinedImageList has \(currentList.count) total entries")
        
        if currentList.isEmpty {
            print("❌ [IMAGE_DEBUG] combinedImageList is EMPTY - triggering async generation")
            triggerAsyncGenerationIfNeeded()
            return nil
        }
        
        if let info = currentList[name] {
            print("✅ [IMAGE_DEBUG] Found imageInfo for '\(name)': URL='\(info.url)', date='\(info.date ?? "nil")'")
            return info
        } else {
            print("❌ [IMAGE_DEBUG] No imageInfo for '\(name)' in list with \(currentList.count) entries")
            print("🔍 [IMAGE_DEBUG] First 10 entries in list: \(Array(currentList.keys.prefix(10)).sorted())")
            return nil
        }
    }
    
    /// Triggers async generation of the image list if not already in progress
    private func triggerAsyncGenerationIfNeeded() {
        // Prevent multiple simultaneous generations
        guard !isGenerating else {
            print("⏸️ [IMAGE_DEBUG] triggerAsyncGenerationIfNeeded: Generation already in progress, skipping")
            return
        }
        
        // NOTE: We no longer abort during year changes for spontaneous generations because:
        // 1. SQLite is thread-safe and won't cause deadlocks
        // 2. The cache is cleared during year change, so we'll regenerate with new data
        // 3. If year change is in progress, we'll just use the new year's data
        
        isGenerating = true
        print("🚀 [IMAGE_DEBUG] triggerAsyncGenerationIfNeeded: Starting async image list generation")
        
        // Perform generation on background queue to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                print("❌ [IMAGE_DEBUG] Self is nil in async generation")
                return
            }
            
            let bandNameHandle = bandNamesHandler.shared
            let scheduleHandle = scheduleHandler.shared
            
            let bandNames = bandNameHandle.getBandNames()
            let scheduleCount = scheduleHandle.schedulingData.count
            let sqliteBandRows = DataManager.shared.fetchBands(forYear: eventYear).count
            print("🔍 [IMAGE_DEBUG] Async generation inputs: inMemoryBands=\(bandNames.count) scheduleBands=\(scheduleCount) sqliteBandRows=\(sqliteBandRows)")
            
            if bandNames.isEmpty && scheduleCount == 0 && sqliteBandRows == 0 {
                print("❌ [IMAGE_DEBUG] No band or schedule source data yet - scheduling retry")
                DispatchQueue.main.async {
                    self.isGenerating = false
                    self.checkAndRefreshWhenReady()
                }
                return
            }
            
            let newCombinedList = self.buildCombinedImageListDictionary(
                bandNameHandle: bandNameHandle,
                scheduleHandle: scheduleHandle
            )
            
            // Update the list and save it (on main queue for thread safety)
            DispatchQueue.main.async {
                print("✅ [IMAGE_DEBUG] Async generation complete - updating combinedImageList on main thread")
                print("📊 [IMAGE_DEBUG] New list has \(newCombinedList.count) entries")
                if newCombinedList.count > 0 {
                    print("📋 [IMAGE_DEBUG] First 10 entries: \(Array(newCombinedList.keys.prefix(10)).sorted())")
                }

                // CRITICAL LOOP FIX:
                // If generation produced an empty list, do NOT overwrite any existing list on disk,
                // and do NOT post ImageListUpdated (DetailViewModel will otherwise reload and re-trigger generation).
                if newCombinedList.isEmpty {
                    print("⚠️ [IMAGE_DEBUG] Async generation produced 0 entries - skipping update/notify and scheduling retry")
                    self.isGenerating = false
                    self.checkAndRefreshWhenReady()
                    return
                }
                
                self.combinedImageList = newCombinedList
                print("✅ [IMAGE_DEBUG] combinedImageList updated successfully")
                
                self.saveCombinedImageList()
                print("✅ [IMAGE_DEBUG] combinedImageList saved to disk")
                
                self.isGenerating = false
                
                print("✅ [IMAGE_DEBUG] Async generation completed with \(newCombinedList.count) entries")
                
                // Post notification that image list has been updated so UI can refresh
                NotificationCenter.default.post(name: Notification.Name("ImageListUpdated"), object: nil)
                print("📢 [IMAGE_DEBUG] Posted ImageListUpdated notification")
            }
        }
    }
    
    /// Checks if the combined list needs to be regenerated based on new data
    /// - Parameters:
    ///   - bandNameHandle: Handler for band/artist data
    ///   - scheduleHandle: Handler for schedule/event data
    /// - Returns: True if regeneration is needed, false otherwise
    func needsRegeneration(bandNameHandle: bandNamesHandler, scheduleHandle: scheduleHandler) -> Bool {
        let currentList = combinedImageList
        
        if currentList.isEmpty {
            print("📋 Combined image list is empty, regeneration needed for first launch")
            return true
        }
        
        let expectedList = buildCombinedImageListDictionary(
            bandNameHandle: bandNameHandle,
            scheduleHandle: scheduleHandle
        )
        
        if currentList.count != expectedList.count {
            print("📋 Image list count changed: \(currentList.count) -> \(expectedList.count)")
            return true
        }
        
        for (name, info) in expectedList {
            if currentList[name]?.url != info.url || currentList[name]?.date != info.date {
                print("📋 Image list entry changed for '\(name)': '\(currentList[name]?.url ?? "nil")' -> '\(info.url)'")
                return true
            }
        }
        
        for (name, _) in currentList {
            if expectedList[name] == nil {
                print("📋 Entry removed: '\(name)' no longer in expected list")
                return true
            }
        }
        
        print("📋 Combined image list is up to date, no regeneration needed")
        return false
    }
    
    /// Saves the combined image list to disk
    private func saveCombinedImageList() {
        do {
            print("📋 [IMAGE_DEBUG] Saving combined image list with \(combinedImageList.count) entries")
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(combinedImageList)
            try jsonData.write(to: combinedImageListFile)
            print("✅ [IMAGE_DEBUG] Combined image list saved to disk at: \(combinedImageListFile.path)")
            print("📋 [IMAGE_DEBUG] First 5 entries: \(Array(combinedImageList.keys.prefix(5)))")
        } catch {
            print("❌ [IMAGE_DEBUG] Error saving combined image list: \(error)")
        }
    }
    
    /// Loads the combined image list from disk
    private func loadCombinedImageList() {
        print("📋 [IMAGE_DEBUG] loadCombinedImageList called, checking file at: \(combinedImageListFile.path)")
        guard FileManager.default.fileExists(atPath: combinedImageListFile.path) else {
            print("❌ [IMAGE_DEBUG] No combined image list file found at: \(combinedImageListFile.path)")
            print("📋 [IMAGE_DEBUG] File will be generated on first use")
            return
        }
        
        print("✅ [IMAGE_DEBUG] Combined image list file exists, loading...")
        do {
            let jsonData = try Data(contentsOf: combinedImageListFile)
            print("📋 [IMAGE_DEBUG] Read \(jsonData.count) bytes from file")
            let decoder = JSONDecoder()
            
            // Try to decode as new format first
            if let loadedList = try? decoder.decode([String: ImageInfo].self, from: jsonData) {
                combinedImageList = loadedList
                print("✅ [IMAGE_DEBUG] Combined image list loaded from disk with \(loadedList.count) entries (new format)")
                if loadedList.count > 0 {
                    print("📋 [IMAGE_DEBUG] First 5 entries: \(Array(loadedList.keys.prefix(5)))")
                }
            }
            // Fall back to old format for backward compatibility
            else if let oldFormatList = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String] {
                print("⚠️ [IMAGE_DEBUG] Loading old format combined image list, converting to new format...")
                var convertedList: [String: ImageInfo] = [:]
                for (name, url) in oldFormatList {
                    convertedList[name] = ImageInfo(url: url, date: nil)
                }
                combinedImageList = convertedList
                // Save in new format immediately
                saveCombinedImageList()
                print("✅ [IMAGE_DEBUG] Combined image list converted and saved in new format with \(convertedList.count) entries")
            } else {
                print("❌ [IMAGE_DEBUG] Error: Could not decode combined image list in any known format")
            }
        } catch {
            print("❌ [IMAGE_DEBUG] Error loading combined image list: \(error)")
        }
    }
    
    /// Clears the combined image list cache
    func clearCache() {
        combinedImageList.removeAll()
        do {
            try FileManager.default.removeItem(at: combinedImageListFile)
            print("Combined image list cache cleared")
        } catch {
            print("Error clearing combined image list cache: \(error)")
        }
    }
    
    /// Manually triggers the combined image list generation
    /// - Parameters:
    ///   - bandNameHandle: Handler for band/artist data
    ///   - scheduleHandle: Handler for schedule/event data
    ///   - completion: Completion handler called when the list is generated
    func manualGenerateCombinedImageList(bandNameHandle: bandNamesHandler, scheduleHandle: scheduleHandler, completion: @escaping () -> Void) {
        print("CombinedImageListHandler: Manual generation triggered")
        generateCombinedImageList(bandNameHandle: bandNameHandle, scheduleHandle: scheduleHandle, completion: completion)
    }
    
    /// Prints the current combined image list for debugging
    func printCurrentList() {
        print("CombinedImageListHandler: Current list contains \(combinedImageList.count) entries:")
        for (name, url) in combinedImageList.sorted(by: { $0.key < $1.key }) {
            print("  '\(name)': \(url)")
        }
    }
    
    /// Checks and refreshes the combined image list if needed at app launch
    /// This should be called after both band and schedule data are loaded
    func checkAndRefreshOnLaunch() {
        print("CombinedImageListHandler: Checking if refresh needed on app launch...")
        
        // Perform this check asynchronously to avoid blocking the main data loading flow
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            let bandNameHandle = bandNamesHandler.shared
            let scheduleHandle = scheduleHandler.shared
            
            let bandNames = bandNameHandle.getBandNames()
            let scheduleCount = scheduleHandle.schedulingData.count
            let sqliteBandRows = DataManager.shared.fetchBands(forYear: eventYear).count
            if bandNames.isEmpty && scheduleCount == 0 && sqliteBandRows == 0 {
                print("CombinedImageListHandler: No band/schedule/SQLite source yet, skipping launch refresh")
                return
            }
            
            // Check if we need to regenerate the list
            if self.needsRegeneration(bandNameHandle: bandNameHandle, scheduleHandle: scheduleHandle) {
                print("CombinedImageListHandler: Refresh needed on launch, regenerating...")
                self.generateCombinedImageList(bandNameHandle: bandNameHandle, scheduleHandle: scheduleHandle) {
                    print("CombinedImageListHandler: Launch refresh completed")
                }
            } else {
                print("CombinedImageListHandler: No refresh needed on launch")
            }
        }
    }
    
    /// Safe version that checks if data is ready before refreshing
    /// Can be called from data loading completion handlers without risk of deadlock
    func checkAndRefreshWhenReady() {
        print("CombinedImageListHandler: Scheduling refresh check when data is ready...")
        
        // Delay the check slightly to ensure all data loading is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkAndRefreshOnLaunch()
        }
    }

    // MARK: - Post-refresh image generation (non-blocking)
    
    /// Trigger image-list regeneration in a way that never stalls critical UI pipelines.
    ///
    /// Rules:
    /// - If band data isn't ready yet (0 bands), return quickly and schedule a retry.
    /// - If band data is ready, kick off async generation (completion is informational only).
    ///
    /// This is intended to be called from:
    /// - year-change "post-ready" phase (after year-change flags cleared and caches loaded)
    /// - pull-to-refresh / foreground refresh AFTER data imports commit
    func triggerRefreshPostDataLoad(
        bandNameHandle: bandNamesHandler,
        scheduleHandle: scheduleHandler,
        context: String
    ) {
        let year = eventYear
        let bandCount = bandNameHandle.getBandNames().count
        let scheduleBandCount = scheduleHandle.schedulingData.count
        let sqliteBandRows = DataManager.shared.fetchBands(forYear: year).count
        let currentCombinedCount = combinedImageList.count
        
        print("🧩 [IMAGE_PIPELINE] triggerRefreshPostDataLoad | \(context) | year=\(year) bands=\(bandCount) scheduleBands=\(scheduleBandCount) sqliteBandRows=\(sqliteBandRows) combinedImageList=\(currentCombinedCount)")
        
        if bandCount == 0 && scheduleBandCount == 0 && sqliteBandRows == 0 {
            print("🧩 [IMAGE_PIPELINE] triggerRefreshPostDataLoad: no source data yet, scheduling retry")
            checkAndRefreshWhenReady()
            return
        }
        
        // Kick off async generation; do not block callers.
        generateCombinedImageList(bandNameHandle: bandNameHandle, scheduleHandle: scheduleHandle) {
            let updatedCount = self.combinedImageList.count
            print("🧩 [IMAGE_PIPELINE] triggerRefreshPostDataLoad: generation completed | year=\(year) combinedImageList=\(updatedCount)")
        }
    }
    
    /// Test method to manually generate and print the combined image list
    func testGenerateAndPrint() {
        print("CombinedImageListHandler: Testing generation...")
        let bandNameHandle = bandNamesHandler.shared
        let scheduleHandle = scheduleHandler.shared
        
        generateCombinedImageList(bandNameHandle: bandNameHandle, scheduleHandle: scheduleHandle) {
            print("CombinedImageListHandler: Generation completed, printing results...")
            self.printCurrentList()
        }
    }
    
    /// Forces a synchronous refresh of the combined image list if it's empty or stale
    /// 
    /// CRITICAL FIX FOR INTERMITTENT DEFAULT IMAGE ISSUE:
    /// This method ensures the combined image list is populated before falling back to default images.
    /// Previously, if the combinedImageList.json file failed to load or was empty at app launch,
    /// ALL images would show as default festival logos even though they were cached locally.
    /// This was because the code checked CombinedImageListHandler BEFORE checking local cache,
    /// and would return early with defaults if the list was empty.
    ///
    /// This method blocks until the list is generated (use sparingly, typically only when list is empty)
    /// Includes cooldown period to prevent rapid repeated refreshes and infinite loops.
    ///
    /// - Returns: True if refresh was performed, false if skipped (due to cooldown or already populated)
    @discardableResult
    func forceSynchronousRefreshIfNeeded() -> Bool {
        // Check if list is already populated - no need to force refresh
        let currentList = combinedImageList
        if !currentList.isEmpty {
            print("🔄 Force refresh skipped - list already has \(currentList.count) entries")
            return false
        }
        
        // Check cooldown to prevent rapid repeated refreshes
        if let lastRefresh = lastForcedRefreshTimestamp {
            let timeSinceLastRefresh = Date().timeIntervalSince(lastRefresh)
            if timeSinceLastRefresh < forcedRefreshCooldown {
                print("⏸️ Force refresh skipped - cooldown period (\(String(format: "%.1f", forcedRefreshCooldown - timeSinceLastRefresh))s remaining)")
                return false
            }
        }
        
        print("🔄 FORCE REFRESH: Combined image list is empty, forcing synchronous regeneration...")
        
        let bandNameHandle = bandNamesHandler.shared
        let scheduleHandle = scheduleHandler.shared
        
        let bandNames = bandNameHandle.getBandNames()
        if bandNames.isEmpty && scheduleHandle.schedulingData.isEmpty && DataManager.shared.fetchBands(forYear: eventYear).isEmpty {
            print("❌ FORCE REFRESH FAILED: No band or schedule source data")
            return false
        }
        
        // Use a semaphore to wait for async generation to complete
        let semaphore = DispatchSemaphore(value: 0)
        var refreshSucceeded = false
        
        // Start generation on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                semaphore.signal()
                return
            }
            
            let newCombinedList = self.buildCombinedImageListDictionary(
                bandNameHandle: bandNameHandle,
                scheduleHandle: scheduleHandle
            )
            
            // Update the list
            self.combinedImageList = newCombinedList
            self.saveCombinedImageList()
            self.lastForcedRefreshTimestamp = Date()
            
            refreshSucceeded = !newCombinedList.isEmpty
            
            print("✅ FORCE REFRESH COMPLETED: Generated \(newCombinedList.count) entries")
            
            // Post notification on main thread
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("ImageListUpdated"), object: nil)
            }
            
            semaphore.signal()
        }
        
        // Wait for completion (with timeout to prevent infinite blocking)
        let timeout = DispatchTime.now() + .seconds(10)
        let result = semaphore.wait(timeout: timeout)
        
        if result == .timedOut {
            print("⚠️ FORCE REFRESH TIMEOUT: Generation took longer than 10 seconds")
            return false
        }
        
        return refreshSucceeded
    }
} 
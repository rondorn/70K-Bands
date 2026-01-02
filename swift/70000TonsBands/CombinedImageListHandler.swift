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
    
    /// Generates the combined image list from artist and event data
    /// - Parameters:
    ///   - bandNameHandle: Handler for band/artist data
    ///   - scheduleHandle: Handler for schedule/event data
    ///   - completion: Completion handler called when the list is generated
    func generateCombinedImageList(bandNameHandle: bandNamesHandler, scheduleHandle: scheduleHandler, completion: @escaping () -> Void) {
        print("📋 [IMAGE_DEBUG] generateCombinedImageList called")
        
        // NOTE: We no longer abort during year changes because:
        // 1. SQLite is thread-safe and won't cause deadlocks
        // 2. Generation is called as part of the official data refresh during year changes
        // 3. The cache is already cleared during year change start, so we won't use stale data
        // 4. We use the current eventYear which is updated early in the year change process
        
        print("📋 Generating combined image URL list (no downloads)...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var newCombinedList: [String: ImageInfo] = [:]
            
            // Get all band names and their image URLs (URL lookup only, no downloads)
            let bandNames = bandNameHandle.getBandNames()
            print("📋 Collecting image URLs for \(bandNames.count) artists (no downloads)")
            for bandName in bandNames {
                let imageUrl = bandNameHandle.getBandImageUrl(bandName)
                if !imageUrl.isEmpty {
                    // Artist images don't have dates - use nil
                    // Note: getBandImageUrl() already normalizes URLs, but we'll ensure it's normalized here too
                    let normalizedUrl = self.normalizeImageURL(imageUrl)
                    newCombinedList[bandName] = ImageInfo(url: normalizedUrl, date: nil)
                    print("📋 Added artist image URL for \(bandName): \(normalizedUrl)")
                }
            }
            
            // Get all event names and their image URLs from schedule data
            let scheduleData = scheduleHandle.schedulingData
            print("📋 Collecting image URLs from \(scheduleData.count) schedule events (no downloads)")
            
            if scheduleData.isEmpty {
                print("Schedule data is empty - this is valid (headers only or future year). Proceeding with artist images only.")
            }
            
            for (bandName, events) in scheduleData {
                for (_, eventData) in events {
                    // Check for ImageURL first (higher priority), then Description URL
                    if let imageUrl = eventData[imageUrlField], !imageUrl.isEmpty {
                        // Only add if not already present (artist takes priority)
                        if newCombinedList[bandName] == nil {
                            // Get ImageDate if available for schedule images
                            let imageDate = eventData[imageUrlDateField] as? String
                            // Normalize URL to ensure it has protocol prefix
                            let normalizedUrl = self.normalizeImageURL(imageUrl)
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
                        // Only add if not already present (artist takes priority)
                        if newCombinedList[bandName] == nil {
                            // Description URLs don't have dates
                            // Normalize URL to ensure it has protocol prefix
                            let normalizedUrl = self.normalizeImageURL(descriptionUrl)
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
            
            // Fetch all events from SQLite (including "orphan" events like "All Star Jam" that don't have Band entities)
            // SQLite stores events independently by eventBandName, so all events are accessible
            print("📋 Fetching events from SQLite (including those without bands)...")
            let sqliteEvents = SQLiteDataManager.shared.fetchEvents(forYear: eventYear)
            print("📋 Found \(sqliteEvents.count) events in SQLite for year \(eventYear)")
            
            // Process SQLite events to extract unique band/event names and their image URLs
            var processedEventNames = Set<String>()
            for event in sqliteEvents {
                let eventName = event.bandName
                
                // Skip if we already processed this event name (avoid duplicates)
                guard !processedEventNames.contains(eventName) else { continue }
                processedEventNames.insert(eventName)
                
                // Only add if not already present (artist takes priority)
                guard newCombinedList[eventName] == nil else { continue }
                
                // Check for eventImageUrl first (higher priority), then descriptionUrl
                if let eventImageUrl = event.eventImageUrl, !eventImageUrl.isEmpty {
                    // SQLite doesn't store eventImageDate, so use nil
                    // Normalize URL to ensure it has protocol prefix
                    let normalizedUrl = self.normalizeImageURL(eventImageUrl)
                    newCombinedList[eventName] = ImageInfo(url: normalizedUrl, date: nil)
                    print("📋 Added SQLite event image URL for '\(eventName)': \(normalizedUrl)")
                } else if let descriptionUrl = event.descriptionUrl, !descriptionUrl.isEmpty {
                    // Description URLs don't have dates
                    // Normalize URL to ensure it has protocol prefix
                    let normalizedUrl = self.normalizeImageURL(descriptionUrl)
                    newCombinedList[eventName] = ImageInfo(url: normalizedUrl, date: nil)
                    print("📋 Added SQLite event description URL for '\(eventName)': \(normalizedUrl)")
                }
            }
            
            // Update the combined list
            print("📋 [IMAGE_DEBUG] Updating combinedImageList with \(newCombinedList.count) entries")
            self.combinedImageList = newCombinedList
            
            // Save to disk
            self.saveCombinedImageList()
            
            print("✅ [IMAGE_DEBUG] Combined image URL list generated with \(newCombinedList.count) entries (no downloads performed)")
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
            
            print("🔍 [IMAGE_DEBUG] Getting band names from bandNamesHandler...")
            // Check if we have data to work with
            let bandNames = bandNameHandle.getBandNames()
            print("🔍 [IMAGE_DEBUG] bandNamesHandler returned \(bandNames.count) bands")
            
            guard !bandNames.isEmpty else {
                print("❌ [IMAGE_DEBUG] No artist data available for async generation - handlers not ready")
                self.isGenerating = false
                return
            }
            
            print("✅ [IMAGE_DEBUG] Found \(bandNames.count) artists, generating list asynchronously")
            if bandNames.count > 0 {
                print("📋 [IMAGE_DEBUG] First 5 bands: \(bandNames.prefix(5))")
            }
            
            // Generate the combined list
            var newCombinedList: [String: ImageInfo] = [:]
            
            // Process band names
            for bandName in bandNames {
                let imageUrl = bandNameHandle.getBandImageUrl(bandName)
                if !imageUrl.isEmpty {
                    // Artist images don't have dates
                    // Normalize URL (band URLs may not have protocol prefix)
                    let normalizedUrl = self.normalizeImageURL(imageUrl)
                    newCombinedList[bandName] = ImageInfo(url: normalizedUrl, date: nil)
                }
            }
            
            // Process schedule data
            let scheduleData = scheduleHandle.schedulingData
            for (bandName, events) in scheduleData {
                for (_, eventData) in events {
                    // Check for ImageURL first (higher priority), then Description URL
                    if let imageUrl = eventData[imageUrlField], !imageUrl.isEmpty {
                        // Only add if not already present (artist takes priority)
                        if newCombinedList[bandName] == nil {
                            // Get ImageDate if available
                            let imageDate = eventData[imageUrlDateField] as? String
                            // Normalize URL (schedule URLs may already have https://, but ensure consistency)
                            let normalizedUrl = self.normalizeImageURL(imageUrl)
                            newCombinedList[bandName] = ImageInfo(url: normalizedUrl, date: imageDate)
                        }
                    } else if let descriptionUrl = eventData[descriptionUrlField], !descriptionUrl.isEmpty {
                        // Only add if not already present (artist takes priority)
                        if newCombinedList[bandName] == nil {
                            // Description URLs don't have dates
                            // Normalize URL to ensure it has protocol prefix
                            let normalizedUrl = self.normalizeImageURL(descriptionUrl)
                            newCombinedList[bandName] = ImageInfo(url: normalizedUrl, date: nil)
                        }
                    }
                }
            }
            
            // Fetch all events from SQLite (including "orphan" events like "All Star Jam")
            print("📋 [ASYNC] Fetching events from SQLite (including those without bands)...")
            let sqliteEvents = SQLiteDataManager.shared.fetchEvents(forYear: eventYear)
            print("📋 [ASYNC] Found \(sqliteEvents.count) events in SQLite for year \(eventYear)")
            
            // Process SQLite events to extract unique band/event names and their image URLs
            var processedEventNames = Set<String>()
            for event in sqliteEvents {
                let eventName = event.bandName
                
                // Skip if we already processed this event name (avoid duplicates)
                guard !processedEventNames.contains(eventName) else { continue }
                processedEventNames.insert(eventName)
                
                // Only add if not already present (artist takes priority)
                guard newCombinedList[eventName] == nil else { continue }
                
                // Check for eventImageUrl first (higher priority), then descriptionUrl
                if let eventImageUrl = event.eventImageUrl, !eventImageUrl.isEmpty {
                    // SQLite doesn't store eventImageDate, so use nil
                    // Normalize URL (schedule URLs may already have https://, but ensure consistency)
                    let normalizedUrl = self.normalizeImageURL(eventImageUrl)
                    newCombinedList[eventName] = ImageInfo(url: normalizedUrl, date: nil)
                    print("📋 [ASYNC] Added SQLite event image URL for '\(eventName)': \(normalizedUrl)")
                } else if let descriptionUrl = event.descriptionUrl, !descriptionUrl.isEmpty {
                    // Description URLs don't have dates
                    // Normalize URL to ensure it has protocol prefix
                    let normalizedUrl = self.normalizeImageURL(descriptionUrl)
                    newCombinedList[eventName] = ImageInfo(url: normalizedUrl, date: nil)
                    print("📋 [ASYNC] Added SQLite event description URL for '\(eventName)': \(normalizedUrl)")
                }
            }
            
            // Update the list and save it (on main queue for thread safety)
            DispatchQueue.main.async {
                print("✅ [IMAGE_DEBUG] Async generation complete - updating combinedImageList on main thread")
                print("📊 [IMAGE_DEBUG] New list has \(newCombinedList.count) entries")
                if newCombinedList.count > 0 {
                    print("📋 [IMAGE_DEBUG] First 10 entries: \(Array(newCombinedList.keys.prefix(10)).sorted())")
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
        
        // If the combined list is empty, we need to generate it (first launch case)
        if currentList.isEmpty {
            print("📋 Combined image list is empty, regeneration needed for first launch")
            return true
        }
        
        // Build what the new list should look like and compare
        var expectedList: [String: ImageInfo] = [:]
        var hasChanges = false
        
        // Get all band names and their image URLs
        let bandNames = bandNameHandle.getBandNames()
        print("📋 Checking \(bandNames.count) artists for image URL changes...")
        
        for bandName in bandNames {
            let imageUrl = bandNameHandle.getBandImageUrl(bandName)
            if !imageUrl.isEmpty {
                let expectedInfo = ImageInfo(url: imageUrl, date: nil)
                expectedList[bandName] = expectedInfo
                // Check if this is different from current list (compare URL only for artists)
                if currentList[bandName]?.url != imageUrl {
                    print("📋 Artist image URL changed for \(bandName): '\(currentList[bandName]?.url ?? "nil")' -> '\(imageUrl)'")
                    hasChanges = true
                }
            }
        }
        
        // Get all event names and their image URLs from schedule data
        let scheduleData = scheduleHandle.schedulingData
        print("📋 Checking \(scheduleData.count) schedule events for image URL changes...")
        
        for (bandName, events) in scheduleData {
            for (_, eventData) in events {
                // Check for ImageURL first (higher priority), then Description URL
                if let imageUrl = eventData[imageUrlField], !imageUrl.isEmpty {
                    // Only add if not already present (artist takes priority)
                    if expectedList[bandName] == nil {
                        // Get ImageDate if available
                        let imageDate = eventData[imageUrlDateField] as? String
                        let expectedInfo = ImageInfo(url: imageUrl, date: imageDate)
                        expectedList[bandName] = expectedInfo
                        // Check if URL or date changed
                        if currentList[bandName]?.url != imageUrl || currentList[bandName]?.date != imageDate {
                            print("📋 Event image changed for \(bandName): '\(currentList[bandName]?.url ?? "nil")' (date: '\(currentList[bandName]?.date ?? "nil")') -> '\(imageUrl)' (date: '\(imageDate ?? "nil")')")
                            hasChanges = true
                        }
                    }
                } else if let descriptionUrl = eventData[descriptionUrlField], !descriptionUrl.isEmpty {
                    // Only add if not already present (artist takes priority)
                    if expectedList[bandName] == nil {
                        let expectedInfo = ImageInfo(url: descriptionUrl, date: nil)
                        expectedList[bandName] = expectedInfo
                        if currentList[bandName]?.url != descriptionUrl {
                            print("📋 Event description URL changed for \(bandName): '\(currentList[bandName]?.url ?? "nil")' -> '\(descriptionUrl)'")
                            hasChanges = true
                        }
                    }
                }
            }
        }
        
        // Check events from SQLite (including "orphan" events like "All Star Jam")
        print("📋 Checking SQLite events (including those without bands) for image URL changes...")
        let sqliteEvents = SQLiteDataManager.shared.fetchEvents(forYear: eventYear)
        print("📋 Checking \(sqliteEvents.count) SQLite events for year \(eventYear)")
        
        var processedEventNames = Set<String>()
        for event in sqliteEvents {
            let eventName = event.bandName
            
            // Skip if we already processed this event name (avoid duplicates)
            guard !processedEventNames.contains(eventName) else { continue }
            processedEventNames.insert(eventName)
            
            // Only check if not already present (artist takes priority)
            guard expectedList[eventName] == nil else { continue }
            
            // Check for eventImageUrl first (higher priority), then descriptionUrl
            if let eventImageUrl = event.eventImageUrl, !eventImageUrl.isEmpty {
                // SQLite doesn't store eventImageDate, so use nil
                let expectedInfo = ImageInfo(url: eventImageUrl, date: nil)
                expectedList[eventName] = expectedInfo
                // Check if URL changed (date is always nil for SQLite events)
                if currentList[eventName]?.url != eventImageUrl {
                    print("📋 SQLite event image changed for '\(eventName)': '\(currentList[eventName]?.url ?? "nil")' -> '\(eventImageUrl)'")
                    hasChanges = true
                }
            } else if let descriptionUrl = event.descriptionUrl, !descriptionUrl.isEmpty {
                let expectedInfo = ImageInfo(url: descriptionUrl, date: nil)
                expectedList[eventName] = expectedInfo
                if currentList[eventName]?.url != descriptionUrl {
                    print("📋 SQLite event description URL changed for '\(eventName)': '\(currentList[eventName]?.url ?? "nil")' -> '\(descriptionUrl)'")
                    hasChanges = true
                }
            }
        }
        
        // Check if any entries were removed (bands/events no longer exist)
        for (bandName, _) in currentList {
            if expectedList[bandName] == nil {
                print("📋 Entry removed: \(bandName) no longer has image URL")
                hasChanges = true
            }
        }
        
        // Check if the counts are different (quick sanity check)
        if currentList.count != expectedList.count {
            print("📋 Image list count changed: \(currentList.count) -> \(expectedList.count)")
            hasChanges = true
        }
        
        if hasChanges {
            print("📋 Combined image list needs regeneration due to detected changes")
        } else {
            print("📋 Combined image list is up to date, no regeneration needed")
        }
        
        return hasChanges
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
            
            // Check if both handlers have data loaded before proceeding
            let bandNames = bandNameHandle.getBandNames()
            if bandNames.isEmpty {
                print("CombinedImageListHandler: Band data not ready yet, skipping launch refresh")
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
        
        // Check if we have source data
        let bandNames = bandNameHandle.getBandNames()
        if bandNames.isEmpty {
            print("❌ FORCE REFRESH FAILED: No band data available (handlers not ready)")
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
            
            var newCombinedList: [String: ImageInfo] = [:]
            
            // Process band names
            for bandName in bandNames {
                let imageUrl = bandNameHandle.getBandImageUrl(bandName)
                if !imageUrl.isEmpty {
                    // Normalize URL (band URLs may not have protocol prefix)
                    let normalizedUrl = self.normalizeImageURL(imageUrl)
                    newCombinedList[bandName] = ImageInfo(url: normalizedUrl, date: nil)
                }
            }
            
            // Process schedule data
            let scheduleData = scheduleHandle.schedulingData
            for (bandName, events) in scheduleData {
                for (_, eventData) in events {
                    if let imageUrl = eventData[imageUrlField], !imageUrl.isEmpty {
                        if newCombinedList[bandName] == nil {
                            let imageDate = eventData[imageUrlDateField] as? String
                            // Normalize URL (schedule URLs may already have https://, but ensure consistency)
                            let normalizedUrl = self.normalizeImageURL(imageUrl)
                            newCombinedList[bandName] = ImageInfo(url: normalizedUrl, date: imageDate)
                        }
                    } else if let descriptionUrl = eventData[descriptionUrlField], !descriptionUrl.isEmpty {
                        if newCombinedList[bandName] == nil {
                            // Normalize URL to ensure it has protocol prefix
                            let normalizedUrl = self.normalizeImageURL(descriptionUrl)
                            newCombinedList[bandName] = ImageInfo(url: normalizedUrl, date: nil)
                        }
                    }
                }
            }
            
            // Fetch events from SQLite (including "orphan" events like "All Star Jam")
            print("📋 [FORCE_REFRESH] Fetching events from SQLite...")
            let sqliteEvents = SQLiteDataManager.shared.fetchEvents(forYear: eventYear)
            print("📋 [FORCE_REFRESH] Found \(sqliteEvents.count) events in SQLite for year \(eventYear)")
            
            // Process SQLite events to extract unique band/event names and their image URLs
            var processedEventNames = Set<String>()
            for event in sqliteEvents {
                let eventName = event.bandName
                
                // Skip if we already processed this event name (avoid duplicates)
                guard !processedEventNames.contains(eventName) else { continue }
                processedEventNames.insert(eventName)
                
                // Only add if not already present (artist takes priority)
                guard newCombinedList[eventName] == nil else { continue }
                
                // Check for eventImageUrl first (higher priority), then descriptionUrl
                if let eventImageUrl = event.eventImageUrl, !eventImageUrl.isEmpty {
                    // SQLite doesn't store eventImageDate, so use nil
                    // Normalize URL (schedule URLs may already have https://, but ensure consistency)
                    let normalizedUrl = self.normalizeImageURL(eventImageUrl)
                    newCombinedList[eventName] = ImageInfo(url: normalizedUrl, date: nil)
                } else if let descriptionUrl = event.descriptionUrl, !descriptionUrl.isEmpty {
                    // Description URLs don't have dates
                    // Normalize URL to ensure it has protocol prefix
                    let normalizedUrl = self.normalizeImageURL(descriptionUrl)
                    newCombinedList[eventName] = ImageInfo(url: normalizedUrl, date: nil)
                }
            }
            
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
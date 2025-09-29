//
//  CombinedImageListHandler.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/2/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import CoreData

/// Handles the combined image list that merges artist and event images
/// Artists take priority over events when both have image URLs
class CombinedImageListHandler {
    
    // Thread-safe queue for image list access
    private let imageListQueue = DispatchQueue(label: "com.yourapp.combinedImageList", attributes: .concurrent)
    
    // Private backing store for the combined image list
    private var _combinedImageList: [String: String] = [:]
    
    // Thread-safe accessor
    var combinedImageList: [String: String] {
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
    
    /// Singleton instance
    static let shared = CombinedImageListHandler()
    
    private init() {
        loadCombinedImageList()
    }
    
    /// Generates the combined image list from artist and event data
    /// - Parameters:
    ///   - bandNameHandle: Handler for band/artist data
    ///   - scheduleHandle: Handler for schedule/event data
    ///   - completion: Completion handler called when the list is generated
    func generateCombinedImageList(bandNameHandle: bandNamesHandler, scheduleHandle: scheduleHandler, completion: @escaping () -> Void) {
        print("📋 Generating combined image URL list (no downloads)...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var newCombinedList: [String: String] = [:]
            
            // Get all band names and their image URLs (URL lookup only, no downloads)
            let bandNames = bandNameHandle.getBandNames()
            print("📋 Collecting image URLs for \(bandNames.count) artists (no downloads)")
            for bandName in bandNames {
                let imageUrl = bandNameHandle.getBandImageUrl(bandName)
                if !imageUrl.isEmpty {
                    newCombinedList[bandName] = imageUrl
                    print("📋 Added image URL for \(bandName): \(imageUrl)")
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
                            newCombinedList[bandName] = imageUrl
                            print("📋 Added event image URL for \(bandName): \(imageUrl)")
                        } else {
                            print("📋 Skipped event image URL for \(bandName) (artist already has URL): \(imageUrl)")
                        }
                    } else if let descriptionUrl = eventData[descriptionUrlField], !descriptionUrl.isEmpty {
                        // Only add if not already present (artist takes priority)
                        if newCombinedList[bandName] == nil {
                            newCombinedList[bandName] = descriptionUrl
                            print("Added event description URL for \(bandName): \(descriptionUrl)")
                        } else {
                            print("📋 Skipped event description URL for \(bandName) (artist already has URL): \(descriptionUrl)")
                        }
                    } else {
                        print("No image URL found for event: \(bandName)")
                    }
                }
            }
            
            // CRITICAL FIX: Also fetch events directly from Core Data that don't have associated bands
            // This includes events like "All Star Jam" that appear in the band list but don't have a Band entity
            print("📋 Fetching events directly from Core Data (including those without bands)...")
            let coreDataManager = CoreDataManager.shared
            let context = coreDataManager.persistentContainer.newBackgroundContext()
            
            let eventRequest: NSFetchRequest<Event> = Event.fetchRequest()
            // Filter for current year events only
            let currentYear = Int32(Calendar.current.component(.year, from: Date()))
            eventRequest.predicate = NSPredicate(format: "eventYear == %d", currentYear)
            
            do {
                let allEvents = try context.fetch(eventRequest)
                print("📋 Found \(allEvents.count) events in Core Data for year \(currentYear)")
                
                for event in allEvents {
                    // Get the event name from the identifier (which contains the band/event name)
                    guard let identifier = event.identifier else { continue }
                    
                    // Extract the event name from the identifier (format: "bandName_eventId")
                    let eventName = identifier.components(separatedBy: "_").first ?? identifier
                    
                    // Check if this event has an image URL
                    if let eventImageUrl = event.eventImageUrl, !eventImageUrl.isEmpty {
                        // Only add if not already present (artist takes priority)
                        if newCombinedList[eventName] == nil {
                            newCombinedList[eventName] = eventImageUrl
                            print("📋 Added Core Data event image URL for '\(eventName)': \(eventImageUrl)")
                        } else {
                            print("📋 Skipped Core Data event image URL for '\(eventName)' (already has URL): \(eventImageUrl)")
                        }
                    } else if let descriptionUrl = event.descriptionUrl, !descriptionUrl.isEmpty {
                        // Only add if not already present (artist takes priority)
                        if newCombinedList[eventName] == nil {
                            newCombinedList[eventName] = descriptionUrl
                            print("📋 Added Core Data event description URL for '\(eventName)': \(descriptionUrl)")
                        } else {
                            print("📋 Skipped Core Data event description URL for '\(eventName)' (already has URL): \(descriptionUrl)")
                        }
                    }
                }
            } catch {
                print("❌ Error fetching events from Core Data: \(error)")
            }
            
            // Update the combined list
            self.combinedImageList = newCombinedList
            
            // Save to disk
            self.saveCombinedImageList()
            
            print("📋 Combined image URL list generated with \(newCombinedList.count) entries (no downloads performed)")
            
            DispatchQueue.main.async {
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
        
        let url = currentList[name] ?? ""
        print("CombinedImageListHandler: Getting image URL for '\(name)': \(url)")
        return url
    }
    
    /// Triggers async generation of the image list if not already in progress
    private func triggerAsyncGenerationIfNeeded() {
        // Prevent multiple simultaneous generations
        guard !isGenerating else {
            print("CombinedImageListHandler: Async generation already in progress, skipping")
            return
        }
        
        isGenerating = true
        print("CombinedImageListHandler: Starting async image list generation")
        
        // Perform generation on background queue to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                return
            }
            
            let bandNameHandle = bandNamesHandler.shared
            let scheduleHandle = scheduleHandler.shared
            
            // Check if we have data to work with
            let bandNames = bandNameHandle.getBandNames()
            guard !bandNames.isEmpty else {
                print("CombinedImageListHandler: No artist data available for async generation")
                self.isGenerating = false
                return
            }
            
            print("CombinedImageListHandler: Found \(bandNames.count) artists, generating list asynchronously")
            
            // Generate the combined list
            var newCombinedList: [String: String] = [:]
            
            // Process band names
            for bandName in bandNames {
                let imageUrl = bandNameHandle.getBandImageUrl(bandName)
                if !imageUrl.isEmpty {
                    newCombinedList[bandName] = imageUrl
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
                            newCombinedList[bandName] = imageUrl
                        }
                    } else if let descriptionUrl = eventData[descriptionUrlField], !descriptionUrl.isEmpty {
                        // Only add if not already present (artist takes priority)
                        if newCombinedList[bandName] == nil {
                            newCombinedList[bandName] = descriptionUrl
                        }
                    }
                }
            }
            
            // CRITICAL FIX: Also fetch events directly from Core Data that don't have associated bands
            // This includes events like "All Star Jam" that appear in the band list but don't have a Band entity
            print("📋 [ASYNC] Fetching events directly from Core Data (including those without bands)...")
            let coreDataManager = CoreDataManager.shared
            let context = coreDataManager.persistentContainer.newBackgroundContext()
            
            let eventRequest: NSFetchRequest<Event> = Event.fetchRequest()
            // Filter for current year events only
            let currentYear = Int32(Calendar.current.component(.year, from: Date()))
            eventRequest.predicate = NSPredicate(format: "eventYear == %d", currentYear)
            
            do {
                let allEvents = try context.fetch(eventRequest)
                print("📋 [ASYNC] Found \(allEvents.count) events in Core Data for year \(currentYear)")
                
                for event in allEvents {
                    // Get the event name from the identifier (which contains the band/event name)
                    guard let identifier = event.identifier else { continue }
                    
                    // Extract the event name from the identifier (format: "bandName_eventId")
                    let eventName = identifier.components(separatedBy: "_").first ?? identifier
                    
                    // Check if this event has an image URL
                    if let eventImageUrl = event.eventImageUrl, !eventImageUrl.isEmpty {
                        // Only add if not already present (artist takes priority)
                        if newCombinedList[eventName] == nil {
                            newCombinedList[eventName] = eventImageUrl
                            print("📋 [ASYNC] Added Core Data event image URL for '\(eventName)': \(eventImageUrl)")
                        }
                    } else if let descriptionUrl = event.descriptionUrl, !descriptionUrl.isEmpty {
                        // Only add if not already present (artist takes priority)
                        if newCombinedList[eventName] == nil {
                            newCombinedList[eventName] = descriptionUrl
                            print("📋 [ASYNC] Added Core Data event description URL for '\(eventName)': \(descriptionUrl)")
                        }
                    }
                }
            } catch {
                print("❌ [ASYNC] Error fetching events from Core Data: \(error)")
            }
            
            // Update the list and save it (on main queue for thread safety)
            DispatchQueue.main.async {
                self.combinedImageList = newCombinedList
                self.saveCombinedImageList()
                self.isGenerating = false
                
                print("CombinedImageListHandler: Async generation completed with \(newCombinedList.count) entries")
                
                // Post notification that image list has been updated so UI can refresh
                NotificationCenter.default.post(name: Notification.Name("ImageListUpdated"), object: nil)
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
        var expectedList: [String: String] = [:]
        var hasChanges = false
        
        // Get all band names and their image URLs
        let bandNames = bandNameHandle.getBandNames()
        print("📋 Checking \(bandNames.count) artists for image URL changes...")
        
        for bandName in bandNames {
            let imageUrl = bandNameHandle.getBandImageUrl(bandName)
            if !imageUrl.isEmpty {
                expectedList[bandName] = imageUrl
                // Check if this is different from current list
                if currentList[bandName] != imageUrl {
                    print("📋 Artist image URL changed for \(bandName): '\(currentList[bandName] ?? "nil")' -> '\(imageUrl)'")
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
                        expectedList[bandName] = imageUrl
                        if currentList[bandName] != imageUrl {
                            print("📋 Event image URL changed for \(bandName): '\(currentList[bandName] ?? "nil")' -> '\(imageUrl)'")
                            hasChanges = true
                        }
                    }
                } else if let descriptionUrl = eventData[descriptionUrlField], !descriptionUrl.isEmpty {
                    // Only add if not already present (artist takes priority)
                    if expectedList[bandName] == nil {
                        expectedList[bandName] = descriptionUrl
                        if currentList[bandName] != descriptionUrl {
                            print("📋 Event description URL changed for \(bandName): '\(currentList[bandName] ?? "nil")' -> '\(descriptionUrl)'")
                            hasChanges = true
                        }
                    }
                }
            }
        }
        
        // CRITICAL FIX: Also check events directly from Core Data that don't have associated bands
        // This includes events like "All Star Jam" that appear in the band list but don't have a Band entity
        print("📋 Checking Core Data events (including those without bands) for image URL changes...")
        let coreDataManager = CoreDataManager.shared
        let context = coreDataManager.context
        
        let eventRequest: NSFetchRequest<Event> = Event.fetchRequest()
        // Filter for current year events only
        let currentYear = Int32(Calendar.current.component(.year, from: Date()))
        eventRequest.predicate = NSPredicate(format: "eventYear == %d", currentYear)
        
        do {
            let allEvents = try context.fetch(eventRequest)
            print("📋 Checking \(allEvents.count) Core Data events for year \(currentYear)")
            
            for event in allEvents {
                // Get the event name from the identifier (which contains the band/event name)
                guard let identifier = event.identifier else { continue }
                
                // Extract the event name from the identifier (format: "bandName_eventId")
                let eventName = identifier.components(separatedBy: "_").first ?? identifier
                
                // Check if this event has an image URL
                if let eventImageUrl = event.eventImageUrl, !eventImageUrl.isEmpty {
                    // Only add if not already present (artist takes priority)
                    if expectedList[eventName] == nil {
                        expectedList[eventName] = eventImageUrl
                        if currentList[eventName] != eventImageUrl {
                            print("📋 Core Data event image URL changed for '\(eventName)': '\(currentList[eventName] ?? "nil")' -> '\(eventImageUrl)'")
                            hasChanges = true
                        }
                    }
                } else if let descriptionUrl = event.descriptionUrl, !descriptionUrl.isEmpty {
                    // Only add if not already present (artist takes priority)
                    if expectedList[eventName] == nil {
                        expectedList[eventName] = descriptionUrl
                        if currentList[eventName] != descriptionUrl {
                            print("📋 Core Data event description URL changed for '\(eventName)': '\(currentList[eventName] ?? "nil")' -> '\(descriptionUrl)'")
                            hasChanges = true
                        }
                    }
                }
            }
        } catch {
            print("❌ Error fetching events from Core Data for regeneration check: \(error)")
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
            let jsonData = try JSONSerialization.data(withJSONObject: combinedImageList, options: .prettyPrinted)
            try jsonData.write(to: combinedImageListFile)
            print("Combined image list saved to disk")
        } catch {
            print("Error saving combined image list: \(error)")
        }
    }
    
    /// Loads the combined image list from disk
    private func loadCombinedImageList() {
        guard FileManager.default.fileExists(atPath: combinedImageListFile.path) else {
            print("No combined image list file found, will generate on first use")
            return
        }
        
        do {
            let jsonData = try Data(contentsOf: combinedImageListFile)
            if let loadedList = try JSONSerialization.jsonObject(with: jsonData) as? [String: String] {
                combinedImageList = loadedList
                print("Combined image list loaded from disk with \(loadedList.count) entries")
            }
        } catch {
            print("Error loading combined image list: \(error)")
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
} 
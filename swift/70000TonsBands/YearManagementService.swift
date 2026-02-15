//
//  YearManagementService.swift
//  70K Bands
//
//  Created by Refactoring
//  Copyright (c) 2026 Ron Dorn. All rights reserved.
//

import Foundation

/// Service class for managing year-related operations
/// Handles year resolution, year change detection, version tracking, and priority resolution
class YearManagementService {
    static let shared = YearManagementService()
    private init() {}
    
    // MARK: - Year Resolution
    
    /// Ensures the year is properly resolved at launch, with fallback mechanisms.
    /// LAUNCH OPTIMIZED: Never blocks, always returns cached data or sensible defaults immediately.
    /// This function should be called during app initialization to ensure a valid year is set.
    /// - Returns: The resolved year as an integer, or a default year if resolution fails.
    func ensureYearResolvedAtLaunch() -> Int {
        print("🚀 LAUNCH OPTIMIZATION: ensureYearResolvedAtLaunch starting NON-BLOCKING year resolution")
        
        // Step 1: Try to get year from memory cache first (fastest path)
        let cacheKey = "Current:eventYear" // or use getScheduleUrl() if needed
        var resolvedYear = ""
        
        storePointerLock.sync() {
            if let cachedValue = cacheVariables.storePointerData[cacheKey], !cachedValue.isEmpty {
                resolvedYear = cachedValue
                print("🚀 LAUNCH OPTIMIZATION: Found year in memory cache: \(resolvedYear)")
            }
        }
        
        // Step 2: If no memory cache, try cached file (still fast, no network)
        if resolvedYear.isEmpty {
            print("🚀 LAUNCH OPTIMIZATION: No memory cache, trying cached year file")
            do {
                if FileManager.default.fileExists(atPath: eventYearFile) {
                    resolvedYear = try String(contentsOfFile: eventYearFile, encoding: String.Encoding.utf8)
                    print("🚀 LAUNCH OPTIMIZATION: Found cached year file: \(resolvedYear)")
                    
                    // Cache in memory for next time
                    if !resolvedYear.isEmpty {
                        storePointerLock.sync() {
                            cacheVariables.storePointerData[cacheKey] = resolvedYear
                        }
                    }
                }
            } catch {
                print("🚀 LAUNCH OPTIMIZATION: Could not read cached year file")
            }
        }
        
        // Step 3: If still no data, use sensible default.
        // Pointer file will be downloaded during startup (AppDelegate) and/or pull-to-refresh.
        if resolvedYear.isEmpty {
            print("🚀 LAUNCH OPTIMIZATION: No cached year data - using default and triggering background update")
            resolvedYear = getDefaultPointerValue(for: "eventYear")
        } else {
            // We have cached year - check if user is on "Current" and if pointer file has newer year
            let yearPreference = getScheduleUrl() // Returns "Current" or specific year like "2025"
            if yearPreference == "Current" {
                print("🚀 LAUNCH OPTIMIZATION: User on 'Current', checking for year updates in background")
                DispatchQueue.global(qos: .utility).async {
                    // Wait for app to fully launch before checking
                    Thread.sleep(forTimeInterval: 5.0)
                    YearManagementService.shared.checkForYearChangeInPointerFile(cachedYear: resolvedYear)
                }
            } else {
                print("🚀 LAUNCH OPTIMIZATION: User on specific year '\(yearPreference)', not checking for updates")
            }
        }
        
        // Validate the year
        guard let yearInt = Int(resolvedYear), yearInt > 2000 && yearInt < 2030 else {
            print("🚀 LAUNCH OPTIMIZATION: Invalid year '\(resolvedYear)', using current year as fallback")
            let currentYear = Calendar.current.component(.year, from: Date())
            print("🚀 LAUNCH OPTIMIZATION: Using current year \(currentYear) (no hardcoded minimum)")
            return currentYear
        }
        
        print("🚀 LAUNCH OPTIMIZATION: Final resolved year (NON-BLOCKING): \(resolvedYear)")
        print("🎯 [MDF_DEBUG] Festival: \(FestivalConfig.current.festivalShortName)")
        print("🎯 [MDF_DEBUG] Non-blocking eventYear resolution returned: \(resolvedYear)")
        
        return Int(resolvedYear)!
    }
    
    /// Checks if the year in the pointer file has changed compared to cached year
    /// ONLY updates if user is on "Current" preference and pointer has newer year
    /// This respects user's explicit year choice from preferences
    /// - Parameter cachedYear: The currently cached year value
    func checkForYearChangeInPointerFile(cachedYear: String) {
        print("📅 Checking if pointer file 'Current' year has changed (cached: \(cachedYear))")
        
        // Only proceed if user preference is set to "Current"
        let yearPreference = getScheduleUrl()
        guard yearPreference == "Current" else {
            print("📅 User has explicit year selection '\(yearPreference)' - not auto-updating")
            return
        }
        
        // POLICY: Do not download pointer data here. Only use cached pointer data on disk.
        let cachedPointerFile = FilePaths.cachedPointerFile
        guard FileManager.default.fileExists(atPath: cachedPointerFile) else {
            print("📅 No cached pointer file on disk - skipping year check")
            return
        }
        
        let httpData: String
        do {
            httpData = try String(contentsOfFile: cachedPointerFile, encoding: .utf8)
        } catch {
            print("📅 Failed to read cached pointer file - skipping year check: \(error)")
            return
        }
        
        guard !httpData.isEmpty else {
            print("📅 Cached pointer file is empty - skipping year check")
            return
        }
        
        // Parse the pointer file to get Current::eventYear
        let dataArray = httpData.components(separatedBy: "\n")
        var pointerFileYear: String?
        
        for line in dataArray {
            // Look for line like "Current::eventYear::2026"
            if line.hasPrefix("Current::eventYear::") {
                let components = line.components(separatedBy: "::")
                if components.count >= 3 {
                    pointerFileYear = components[2].trimmingCharacters(in: .whitespacesAndNewlines)
                    print("📅 Found 'Current' year in pointer file: \(pointerFileYear ?? "nil")")
                    break
                }
            }
        }
        
        guard let newYearString = pointerFileYear, 
              !newYearString.isEmpty,
              let newYearInt = Int(newYearString),
              let cachedYearInt = Int(cachedYear) else {
            print("📅 Could not parse year from pointer file or cached year")
            return
        }
        
        // Only update if pointer file has NEWER year than cached year
        guard newYearInt > cachedYearInt else {
            print("📅 Pointer file year (\(newYearInt)) is not newer than cached (\(cachedYearInt)) - no update")
            return
        }
        
        // Pointer file has newer year and user is on "Current" - trigger year change!
        print("📅 ✅ Pointer file has NEWER year: \(newYearInt) > cached: \(cachedYearInt)")
        print("📅 User preference is 'Current' - triggering automatic year update...")
        
        // Update eventYear and trigger year change process
        DispatchQueue.main.async {
            print("📅 Updating eventYear from \(cachedYearInt) to \(newYearInt)")
            eventYear = newYearInt
            YearManagementService.shared.checkAndHandleYearChange(newYear: newYearString)
            
            print("📅 ✅ Automatically updated to year \(newYearInt) from pointer file")
            
            // Post notification that year was auto-updated
            NotificationCenter.default.post(
                name: Notification.Name("YearChangedAutomatically"),
                object: nil,
                userInfo: ["newYear": newYearInt, "oldYear": cachedYearInt]
            )
        }
    }
    
    /// Checks if the year has changed and handles the year change process if needed.
    /// This function can be called from both setupDefaults and when year changes are detected.
    /// - Parameter newYear: The new year string that was resolved.
    func checkAndHandleYearChange(newYear: String) {
        // Read the previously cached year
        var previousYear = ""
        do {
            if FileManager.default.fileExists(atPath: eventYearFile) {
                previousYear = try String(contentsOfFile: eventYearFile, encoding: String.Encoding.utf8)
            }
        } catch {
            print("checkAndHandleYearChange: Could not read previous year from cache")
        }
        
        // If year has changed, run the same process as year change in preferences
        if !previousYear.isEmpty && previousYear != newYear {
            print("checkAndHandleYearChange: Year changed from \(previousYear) to \(newYear), running year change process")
            
            // Clear caches and files like in preferences year change
            do {
                // Only remove files if they exist and are for the old year
                if FileManager.default.fileExists(atPath: scheduleFile) {
                    try FileManager.default.removeItem(atPath: scheduleFile)
                    print("checkAndHandleYearChange: Removed old schedule file")
                }
                if FileManager.default.fileExists(atPath: bandFile) {
                    try FileManager.default.removeItem(atPath: bandFile)
                    print("checkAndHandleYearChange: Removed old band file")
                }
            } catch {
                print("checkAndHandleYearChange: Some files were not removed (may not have existed)")
            }
            
            // Clear pointer data cache to ensure fresh data
            cacheVariables.storePointerData = [String:String]()
            
            // Clear all existing notifications
            let localNotification = localNoticationHandler()
            localNotification.clearNotifications()
            
            // Purge all caches
            bandNamesHandler.shared.clearCachedData()
            // LEGACY: Priority cache clearing now handled by PriorityManager if needed
            dataHandler().clearCachedData()
            
            // CRITICAL: Clear combined image list cache when year changes
            // This forces regeneration with the new year's data
            CombinedImageListHandler.shared.clearCache()
            print("checkAndHandleYearChange: Cleared CombinedImageListHandler cache")
            
            if let masterView = masterView {
                masterView.schedule.clearCache()
                
                // Clear MasterViewController's cached data arrays
                masterView.clearMasterViewCachedData()
            }
            
            // Clear static caches
            staticSchedule.sync {
                cacheVariables.scheduleStaticCache = [:]
                cacheVariables.scheduleTimeStaticCache = [:]
                cacheVariables.bandNamesStaticCache = [:]
            }
            
            print("checkAndHandleYearChange: Year change process completed for \(newYear)")
        }
    }
    
    // MARK: - URL Setup
    
    /// Sets up the current year URLs for artist and schedule data, writing a flag file if needed.
    func setupCurrentYearUrls() {
        let filePath = defaultUrlConverFlagUrl.path
        if(FileManager.default.fileExists(atPath: filePath)){
            print ("setupCurrentYearUrls: Followup run of setupCurrentYearUrls routine")
            let currentArtistUrl = getArtistUrl()
            let currentScheduleUrl = getScheduleUrl()
            
            print ("setupCurrentYearUrls: artistUrlDefault is \(currentArtistUrl)")
            print ("setupCurrentYearUrls: scheduleUrlDefault is \(currentScheduleUrl)")
        } else {
            print ("setupCurrentYearUrls: First run of setupCurrentYearUrls routine")
            // Note: URLs are now managed by FestivalConfig, not modified at runtime
            let flag = ""
            do {
                try flag.write(to: defaultUrlConverFlagUrl, atomically: false, encoding: .utf8)
            }
            catch {print ("setupCurrentYearUrls: First run of setupCurrentYearUrls routine Failed!")}
        }
        // Legacy code removed - URLs are now managed by FestivalConfig
    }
    
    // MARK: - Version Management
    
    /// Checks if the app version has changed and updates version info on disk if needed.
    func didVersionChangeFunction() {
        var oldVersion = ""
        
        do {
            if FileManager.default.fileExists(atPath: versionInfoFile) == false {
                try versionInformation.write(toFile: versionInfoFile, atomically: true,encoding: String.Encoding.utf8)
            } else {
                oldVersion = try String(contentsOfFile: versionInfoFile, encoding: String.Encoding.utf8)
            }
        } catch {
            print ("Could not read or write version information")
        }
        
        if (oldVersion != versionInformation){
            didVersionChange = true
            do {
                try versionInformation.write(toFile: versionInfoFile, atomically: true,encoding: String.Encoding.utf8)
            } catch {
                print ("Could not write version information")
            }
        }
    }
    
    // MARK: - Event Year Resolution from Pointer
    
    /// Resolves eventYear from pointer values dictionary
    /// Tries user preference first, then "Current", then "Default"
    /// - Parameters:
    ///   - pointerValues: Dictionary of pointer values parsed from pointer file
    ///   - pointerIndex: The user's year preference (e.g., "Current", "2025")
    /// - Returns: The resolved eventYear string, or empty string if not found
    func resolveEventYearFromPointer(pointerValues: [String:[String:String]], pointerIndex: String) -> String {
        // Try user's preference first
        if let userYearPreference = pointerValues[pointerIndex]?["eventYear"], !userYearPreference.isEmpty {
            return userYearPreference
        }
        
        // Fallback to "Current" if user preference not found
        if let currentYear = pointerValues["Current"]?["eventYear"], !currentYear.isEmpty {
            return currentYear
        }
        
        // Final fallback to "Default"
        if let defaultYear = pointerValues["Default"]?["eventYear"], !defaultYear.isEmpty {
            return defaultYear
        }
        
        // No eventYear found in pointer values
        return ""
    }
    
    // MARK: - Priority Resolution
    
    /// Resolves a priority number string to its human-readable name.
    /// - Parameter priority: The priority number as a string ("1", "2", "3")
    /// - Returns: The priority name ("Must", "Might", "Wont", or "Unknown")
    func resolvePriorityNumber(priority: String) -> String {
        var result = ""
        
        if (priority == "1"){
            result = "Must";
        
        } else if (priority == "2"){
            result = "Might";

        } else if (priority == "3"){
            result = "Wont";
            
        } else {
            result = "Unknown";
        }
        
        return result;
    }
    
    // MARK: - Setup Defaults
    
    /// Sets up default values and initializes the app state.
    /// This function should be called during app initialization.
    /// - Parameter runMigrationCheck: Whether to run migration checks (deprecated, kept for compatibility)
    func setupDefaults(runMigrationCheck: Bool = true) {
        // Migration system removed - all data now uses SQLite directly
        
        readFiltersFile()
        setupVenueLocations()
        
        //print ("Schedule URL is \(UserDefaults.standard.string(forKey: "scheduleUrl") ?? "")")
        
        print ("Trying to get the year  \(eventYear)")
        
        // CRITICAL: eventYear should NEVER be 0 except on very first install
        // Use robust year resolution that handles launch scenarios
        let resolvedYear = ensureYearResolvedAtLaunch()
        
        // SAFETY CHECK: If year is 0, use current calendar year as fallback
        if resolvedYear == 0 {
            print("❌ CRITICAL: eventYear resolved to 0 - using current year as fallback")
            let currentYear = Calendar.current.component(.year, from: Date())
            eventYear = currentYear
            print("📅 Set eventYear to current year: \(currentYear)")
        } else {
            eventYear = resolvedYear
            print("📅 Set eventYear to resolved year: \(resolvedYear)")
        }
        
        print("🎯 [MDF_DEBUG] GLOBAL eventYear RESOLUTION:")
        print("   Festival: \(FestivalConfig.current.festivalShortName)")
        print("   Resolved global eventYear = \(eventYear)")
        
        // Check if year has changed and handle accordingly
        let resolvedYearString = String(eventYear)
        checkAndHandleYearChange(newYear: resolvedYearString)

        // LAUNCH OPTIMIZATION: Don't block launch with scheduleUrl lookup - get it in background
        print ("🚀 LAUNCH OPTIMIZATION: eventYear is \(eventYear), scheduleURL will be resolved in background")
        
        // Trigger background update of schedule URL for next access (non-blocking)
        DispatchQueue.global(qos: .background).async {
            // CRITICAL: Increase delay to 3.5 seconds to ensure network stack is ready
            // On first launch, iOS needs ~3-4 seconds for ALL network endpoints to be ready
            // Early calls fail with error -9816 and timeout after 30 seconds
            Thread.sleep(forTimeInterval: 3.5)
            do {
                let scheduleUrl = getPointerUrlData(keyValue: "scheduleUrl")
                print("🚀 LAUNCH OPTIMIZATION: Background resolved scheduleURL = \(scheduleUrl)")
            } catch {
                print("🚀 LAUNCH OPTIMIZATION: Background scheduleURL resolution failed: \(error)")
            }
        }

        // All data now uses SQLite directly

        didVersionChangeFunction();
    }
}

// MARK: - Note on Global Accessors
// Global accessor functions for backward compatibility are defined in Constants.swift
// This ensures they are accessible throughout the codebase without requiring imports

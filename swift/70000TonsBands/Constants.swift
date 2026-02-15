//
//  Constants.swift
//  70K Bands
//
//  Created by Ron Dorn on 2/7/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import SystemConfiguration
import UIKit
import Network

// MARK: - Imports from Refactored Files
// These imports provide access to constants and utilities that were extracted from this file
// See: FilePaths.swift, EventTypes.swift, AppState.swift, UIConstants.swift, CSVFields.swift, VenueConstants.swift, iCloudConstants.swift

// MARK: - Network timeout policy (Android parity)
//
// Requirement:
// - 10s timeout when a network call is initiated from the GUI (main) thread
// - 60s timeout when running in the background
//
// Note: We still avoid *blocking* synchronous network work on the main thread wherever possible.
enum NetworkTimeoutPolicy {
    static let guiThreadTimeout: TimeInterval = 10.0
    static let backgroundTimeout: TimeInterval = 60.0

    static func timeoutIntervalForCurrentThread() -> TimeInterval {
        return Thread.isMainThread ? guiThreadTimeout : backgroundTimeout
    }
}

// MARK: - UI Menu
var filterMenu: UIMenu = UIMenu()

// MARK: - Firebase Cloud Messaging
var FCMnumber = ""

// MARK: - Legacy File Path Accessors (for backward compatibility)
// These are kept for backward compatibility during migration
// TODO: Update all references to use FilePaths directly
var showsAttendedFileName: String { FilePaths.showsAttendedFileName }
var directoryPath: URL { FilePaths.directoryPath }
var storageFile: URL { FilePaths.storageFile }
var dateFile: URL { FilePaths.dateFile }
var bandsFile: URL { FilePaths.bandsFile }
var lastFilters: URL { FilePaths.lastFilters }
var defaultUrlConverFlagString: String { FilePaths.defaultUrlConverFlagString }
var defaultUrlConverFlagUrl: URL { FilePaths.defaultUrlConverFlagUrl }
var showsAttended: URL { FilePaths.showsAttended }
let bandFile: String = FilePaths.bandFile
let countryFile: URL = FilePaths.countryFile
let lastiCloudDataWriteFile: URL = FilePaths.lastiCloudDataWriteFile
let lastPriorityDataWriteFile: URL = FilePaths.lastPriorityDataWriteFile
let lastScheduleDataWriteFile: URL = FilePaths.lastScheduleDataWriteFile
var schedulingDataCacheFile: URL { FilePaths.schedulingDataCacheFile }
var schedulingDataByTimeCacheFile: URL { FilePaths.schedulingDataByTimeCacheFile }
var bandNamesCacheFile: URL { FilePaths.bandNamesCacheFile }

// MARK: - Legacy Event Type Functions (for backward compatibility)
// TODO: Update all references to use EventTypes directly
func isCombinedEventBandName(_ bandName: String?) -> Bool {
    return EventTypes.isCombinedEventBandName(bandName)
}

func combinedEventBandParts(_ bandName: String?) -> [String]? {
    return EventTypes.combinedEventBandParts(bandName)
}

// MARK: - Dispatch Queues
let staticLastModifiedDate = DispatchQueue(label: "staticLastModifiedDate")
let staticSchedule = DispatchQueue(label: "staticSchedule")
let staticAttended = DispatchQueue(label: "staticAttended")
// TODO: OPTIMIZATION - Remove all sync blocks since SQLite.swift is thread-safe
// Keeping for now to avoid breaking existing code, but they're no longer needed
let staticBandName = DispatchQueue(label: "staticBandName")
let staticData = DispatchQueue(label: "staticData")
let storePointerLock = DispatchQueue(label: "storePointerLock")
let bandDescriptionLock = DispatchQueue(label: "bandDescriptionLock")
let eventYearArrayLock = DispatchQueue(label: "eventYearArrayLock") // Thread-safe access to eventYearArray

let scheduleQueue = DispatchQueue(label: "scheduleQueue")
let bandNameQueue = DispatchQueue(label: "bandNameQueue")
let bandPriorityQueue = DispatchQueue(label: "bandPriorityQueue")
let showsAttendedQueue = DispatchQueue(label: "showsAttendedQueue")

// MARK: - Time Zone
var localTimeZoneAbbreviation: String = TimeZone.current.abbreviation()!

// MARK: - Version Information
var versionInformation = Bundle.main.infoDictionary?["CFBundleVersion"] as! String

// MARK: - Link Containers
var wikipediaLink = [String: String]()
var youtubeLinks = [String: String]()
var metalArchiveLinks = [String: String]()
var bandCountry = [String: String]()
var bandGenre = [String: String]()
var bandNoteWorthy = [String: String]()

// MARK: - Legacy Event Type Accessors (for backward compatibility)
// TODO: Update all references to use EventTypes directly
var showType: String { EventTypes.show }
var meetAndGreetype: String { EventTypes.meetAndGreet }
var clinicType: String { EventTypes.clinic }
var listeningPartyType: String { EventTypes.listeningParty }
var specialEventType: String { EventTypes.specialEvent }
var unofficalEventTypeOld: String { EventTypes.unofficialEventOld }
var unofficalEventType: String { EventTypes.unofficialEvent }
var karaokeEventType: String { EventTypes.karaoke }

var eventYearArray = [String]();

//alert topics
let subscriptionTopic = FestivalConfig.current.subscriptionTopic
let subscriptionTopicTest = FestivalConfig.current.subscriptionTopicTest
let subscriptionUnofficalTopic = FestivalConfig.current.subscriptionUnofficalTopic

// MARK: - Legacy File Path Accessors (for backward compatibility)
// TODO: Update all references to use FilePaths directly
let scheduleFile: String = FilePaths.scheduleFile
let descriptionMapFile: String = FilePaths.descriptionMapFile
let eventYearFile: String = FilePaths.eventYearFile
let versionInfoFile: String = FilePaths.versionInfoFile
let eventYearsInfoFile: String = FilePaths.eventYearsInfoFile

// CRITICAL: eventYear should NEVER be 0 except temporarily on first install
// before pointer file is downloaded. Always use cache and update when needed.
private var _eventYear:Int = 0
private let eventYearLock = NSLock()

var eventYear:Int {
    get {
        eventYearLock.lock()
        defer { eventYearLock.unlock() }
        return _eventYear
    }
    set {
        // NEVER allow setting to 0 after initial setup
        guard newValue > 0 else {
            print("❌ CRITICAL: Attempted to set eventYear to invalid value: \(newValue)")
            eventYearLock.lock()
            let current = _eventYear
            eventYearLock.unlock()
            print("❌ Rejecting change - keeping current value: \(current)")
            return
        }
        
        eventYearLock.lock()
        let oldValue = _eventYear
        let needsUpdate = (oldValue != newValue)
        if needsUpdate {
            print("🔍 [EVENT_YEAR_CHANGE] eventYear changed: \(oldValue) → \(newValue)")
            print("🔍 [EVENT_YEAR_CHANGE] Call stack: \(Thread.callStackSymbols.prefix(3).joined(separator: " -> "))")
            _eventYear = newValue
        }
        eventYearLock.unlock()
        
        // Only do file I/O and cache updates if changed (outside of locks to prevent deadlock)
        if needsUpdate {
            // Save to cache file for next launch
            do {
                try String(newValue).write(toFile: eventYearFile, atomically: true, encoding: .utf8)
                print("✅ Cached eventYear \(newValue) to file")
            } catch {
                print("❌ Failed to cache eventYear to file: \(error)")
            }
            
            // Update memory cache (storePointerLock is separate from eventYearLock - no nesting!)
            storePointerLock.sync {
                cacheVariables.storePointerData["Current:eventYear"] = String(newValue)
                print("✅ Updated eventYear in memory cache")
            }
        }
    }
}

//defaults preferences
// artistUrlDefault and scheduleUrlDefault are now defined in preferenceDefault.swift using FestivalConfig

let defaultPrefsValue = "Default";

let testingSetting = "Testing"

// MARK: - Storage URLs
var defaultStorageUrl = FestivalConfig.current.defaultStorageUrl
let defaultStorageUrlTest = FestivalConfig.current.defaultStorageUrlTest
// IMPORTANT: Do not resolve pointer-derived URLs at global init time.
// This prevents accidental pointer downloads during module load.
var statsUrl: String {
    return getPointerUrlData(keyValue: "reportUrl")
}

// MARK: - Internet Availability
var internetAvailble = isInternetAvailable();

var masterView: MasterViewController!

var googleCloudID = "Nothing";
var currentPointerKey = ""

/// Resolves a priority string (e.g., "1", "2", "3") to a human-readable label ("Must", "Might", "Wont", or "Unknown").
/// - Parameter priority: The priority value as a string.
/// - Returns: A string representing the human-readable priority label.
// MARK: - Legacy Priority Resolution (moved to YearManagementService)
// Function moved to YearManagementService.swift - use global accessor below or YearManagementService.shared.resolvePriorityNumber()

/// Returns the path to the app's documents directory as an NSString.
/// - Returns: The documents directory path.
/// NOTE: This function is now a wrapper around FilePaths.getDocumentsDirectory()
/// TODO: Update all references to use FilePaths.getDocumentsDirectory() directly
func getDocumentsDirectory() -> NSString {
    return FilePaths.getDocumentsDirectory()
}

/// Retrieves pointer URL data for a given key, using cache if available, otherwise fetching and parsing remote data.
/// Handles special logic for the "eventYear" key with robust fallback mechanisms.
/// - Parameter keyValue: The key for which to retrieve pointer data.
/// - Returns: The pointer data as a string, or an empty string if not found.
func getPointerUrlData(keyValue: String) -> String {

    var dataString = String()
    
    // Apply language-specific key logic for reportUrl
    var actualKeyValue = keyValue
    if keyValue == "reportUrl" {
        actualKeyValue = getLanguageSpecificKey(keyValue: keyValue)
        print("🎯 [STATS_DEBUG] getPointerUrlData: Using language-specific key: \(actualKeyValue) for original key: \(keyValue)")
    }
    
    // Special debugging for stats/reportUrl requests
    if keyValue.hasPrefix("reportUrl") {
        print("🎯 [STATS_DEBUG] ========== STATS URL RESOLUTION DEBUG ==========")
        print("🎯 [STATS_DEBUG] Original keyValue: \(keyValue)")
        print("🎯 [STATS_DEBUG] Actual keyValue: \(actualKeyValue)")
        print("🎯 [STATS_DEBUG] User preference (artistUrl): \(getArtistUrl())")
        print("🎯 [STATS_DEBUG] User preference (scheduleUrl): \(getScheduleUrl())")
    }
    
    // Synchronize UserDefaults to ensure we read the latest value from Settings.bundle
    UserDefaults.standard.synchronize()
    
    // ONE-TIME FIX: Clear corrupted LastUsedPointerUrl if it exists but data is actually from Testing
    // This fixes the situation where Testing data is in DB but LastUsedPointerUrl says Production
    let needsCorruptionFix = !UserDefaults.standard.bool(forKey: "PointerUrlCorruptionFixed_v1")
    if needsCorruptionFix {
        print("🔧 [POINTER_DEBUG] 🚨 CORRUPTION FIX: Clearing LastUsedPointerUrl to force fresh state detection")
        UserDefaults.standard.removeObject(forKey: "LastUsedPointerUrl")
        UserDefaults.standard.set(true, forKey: "PointerUrlCorruptionFixed_v1")
        UserDefaults.standard.synchronize()
    }
    
    let pointerUrlPref = UserDefaults.standard.string(forKey: "PointerUrl") ?? "NOT_SET"
    print("🔧 [POINTER_DEBUG] PointerUrl preference = '\(pointerUrlPref)' (checking for '\(testingSetting)')")
    print("🔧 [POINTER_DEBUG] Current defaultStorageUrl = '\(defaultStorageUrl)'")
    
    // Check for custom pointer URL first
    let customPointerUrl = UserDefaults.standard.string(forKey: "CustomPointerUrl") ?? ""
    let usingCustomUrl = !customPointerUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    
    // Determine which pointer URL should be used based on current preference
    let targetPointerUrl: String
    if usingCustomUrl {
        targetPointerUrl = customPointerUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🔧 [POINTER_DEBUG] Using custom pointer URL: '\(targetPointerUrl)'")
    } else if (pointerUrlPref == testingSetting) {
        targetPointerUrl = FestivalConfig.current.defaultStorageUrlTest
        inTestEnvironment = true
    } else {
        targetPointerUrl = FestivalConfig.current.defaultStorageUrl
    }
    
    // CRITICAL: Track which pointer URL was ACTUALLY used to load current data
    // This is the only reliable way to detect when data needs to be refreshed
    let lastUsedPointerUrl = UserDefaults.standard.string(forKey: "LastUsedPointerUrl") ?? "NOT_SET"
    print("🔧 [POINTER_DEBUG] Last used pointer URL: '\(lastUsedPointerUrl)'")
    print("🔧 [POINTER_DEBUG] Target pointer URL: '\(targetPointerUrl)'")
    
    // Compare the actual pointer URL used to load data vs what we should be using now
    let needsCacheClearing = (lastUsedPointerUrl != targetPointerUrl)
    
    if needsCacheClearing {
        print("🔧 [POINTER_DEBUG] ⚠️ POINTER URL DATA MISMATCH DETECTED!")
        print("🔧 [POINTER_DEBUG] Current data loaded from: '\(lastUsedPointerUrl)'")
        print("🔧 [POINTER_DEBUG] Should be using: '\(targetPointerUrl)'")
        print("🔧 [POINTER_DEBUG] 🗑️ CLEARING ALL CACHES to force fresh download")
        
        // 1. Clear pointer cache
        cacheVariables.storePointerData = [String:String]()
        
        // 2. Delete cached pointer file
        let cachedPointerFile = FilePaths.cachedPointerFile
        if FileManager.default.fileExists(atPath: cachedPointerFile) {
            do {
                try FileManager.default.removeItem(atPath: cachedPointerFile)
                print("🔧 [POINTER_DEBUG] 🗑️ Deleted cached pointer file")
            } catch {
                print("🔧 [POINTER_DEBUG] ⚠️ Failed to delete cached pointer file: \(error)")
            }
        }
        
        // 3. Clear year-specific data (bands and events, but preserve user priorities/attendance)
        print("🔧 [POINTER_DEBUG] 🗑️ Clearing year-specific bands and events")
        // Delete all events for the year - SQLiteDataManager handles this internally
        // Note: Year-specific data clearing is handled automatically when new data is imported
        // User priorities and attendance are preserved in separate tables
        
        // 4. Delete band and schedule cache files to force re-download
        let bandFile = getDocumentsDirectory().appendingPathComponent("bandFile.txt")
        let scheduleFile = getDocumentsDirectory().appendingPathComponent("scheduleFile.txt")
        
        if FileManager.default.fileExists(atPath: bandFile) {
            do {
                try FileManager.default.removeItem(atPath: bandFile)
                print("🔧 [POINTER_DEBUG] 🗑️ Deleted cached band file")
            } catch {
                print("🔧 [POINTER_DEBUG] ⚠️ Failed to delete band file: \(error)")
            }
        }
        
        if FileManager.default.fileExists(atPath: scheduleFile) {
            do {
                try FileManager.default.removeItem(atPath: scheduleFile)
                print("🔧 [POINTER_DEBUG] 🗑️ Deleted cached schedule file")
            } catch {
                print("🔧 [POINTER_DEBUG] ⚠️ Failed to delete schedule file: \(error)")
            }
        }
        
        // 5. Clear all static caches
        print("🔧 [POINTER_DEBUG] 🗑️ Clearing static caches")
        cacheVariables.scheduleStaticCache = [:]
        cacheVariables.scheduleTimeStaticCache = [:]
        cacheVariables.bandNamesStaticCache = [:]
        cacheVariables.bandNamesArrayStaticCache = []
        cacheVariables.bandDescriptionUrlCache = [:]
        cacheVariables.bandDescriptionUrlDateCache = [:]
        cacheVariables.attendedStaticCache = [:]
        
        // 6. Set flag to force CSV re-download on next launch
        UserDefaults.standard.set(true, forKey: "ForceCSVDownload")
        UserDefaults.standard.synchronize()
        
        // 7. CRITICAL: Save the target URL (not preference) so we can detect when data doesn't match
        // This will be updated again after successful data download to reflect what was actually loaded
        UserDefaults.standard.set(targetPointerUrl, forKey: "LastUsedPointerUrl")
        UserDefaults.standard.synchronize()
        print("🔧 [POINTER_DEBUG] ✅ Saved target pointer URL for future comparison")
        print("🔧 [POINTER_DEBUG] ✅ All caches cleared - fresh data will be downloaded on next use")
    }
    
    // Apply the correct pointer URL
    defaultStorageUrl = targetPointerUrl
    if (pointerUrlPref == testingSetting){
        print("🔧 [POINTER_DEBUG] ✅ SWITCHED to TEST pointer: '\(defaultStorageUrl)'")
    } else {
        print("🔧 [POINTER_DEBUG] ✅ Using PRODUCTION pointer: '\(defaultStorageUrl)'")
    }
    #if targetEnvironment(simulator)
        inTestEnvironment = true;
    #endif
    
    // Use the user's preference as the pointer index (e.g., "Current", "2025", etc.)
    var pointerIndex = getScheduleUrl()
    
    // POINTER POLICY:
    // - The pointer file must be downloaded ONLY on app startup and on pull-to-refresh.
    // - All other lookups MUST use the cached pointer file on disk (cachedPointerData.txt)
    //   and/or in-memory cache (storePointerData).
    //
    // This function therefore NEVER downloads the pointer file from the network.
    let cacheKey = "\(pointerIndex):\(actualKeyValue)"
    storePointerLock.sync() {
        if let cachedValue = cacheVariables.storePointerData[cacheKey], !cachedValue.isEmpty {
            dataString = cachedValue
            print("getPointerUrlData: ✅ FAST CACHE HIT for \(cacheKey) = \(dataString)")
        }
    }
    if !dataString.isEmpty {
        print("getPointerUrlData: ✅ Returning cached data for \(actualKeyValue): \(dataString)")
        return dataString
    }
    
    print("getPointerUrlData: ⚠️ Cache miss for \(actualKeyValue) (\(cacheKey)) - reading cached pointer file from disk")
    var pointerValues : [String:[String:String]] = [String:[String:String]]()
    let cachedPointerFile = FilePaths.cachedPointerFile
    if FileManager.default.fileExists(atPath: cachedPointerFile) {
        do {
            let cachedData = try String(contentsOfFile: cachedPointerFile, encoding: .utf8)
            let dataArray = cachedData.components(separatedBy: "\n")
            pointerValues = readPointDataOptimized(
                dataArray: dataArray,
                pointerValues: pointerValues,
                pointerIndex: pointerIndex,
                targetKeyValue: actualKeyValue
            )
            dataString = (pointerValues[pointerIndex]?[actualKeyValue]) ?? ""
            if !dataString.isEmpty {
                storePointerLock.sync() {
                    cacheVariables.storePointerData[cacheKey] = dataString
                }
                print("getPointerUrlData: ✅ Cached disk-derived result for \(cacheKey) = \(dataString)")
                return dataString
            }
        } catch {
            print("getPointerUrlData: Failed to read cached pointer file: \(error)")
        }
    } else {
        print("getPointerUrlData: No cached pointer file on disk yet (expected on first launch before startup download completes)")
    }

    if (keyValue == "eventYear"){
            // Get the user's year preference (could be "Current", "2025", "2024", etc.)
            let userYearPreference = getArtistUrl()
            print("🎯 [YEAR_RESOLUTION_DEBUG] getPointerUrlData: User year preference: '\(userYearPreference)'")
            print("🎯 [YEAR_RESOLUTION_DEBUG] getPointerUrlData: userYearPreference.isYearString = \(userYearPreference.isYearString)")
            print("🎯 [YEAR_RESOLUTION_DEBUG] getPointerUrlData: About to resolve eventYear for preference '\(userYearPreference)'")
            print("🎯 [YEAR_RESOLUTION_DEBUG] Looking up '\(userYearPreference)' in pointer data")
            print("🎯 [YEAR_RESOLUTION_DEBUG] Available pointer keys: \(Array(pointerValues.keys))")
            print("getPointerUrlData: User year preference: \(userYearPreference)")
            
            // CRITICAL FIX: If user selected a specific year (like "2025"), use that directly
            // This handles cases where the pointer file might not have all year entries
            if userYearPreference.isYearString && userYearPreference != "Current" {
                print("🎯 [YEAR_RESOLUTION_DEBUG] ✅ User selected specific year \(userYearPreference), using it directly")
                dataString = userYearPreference
            } else {
                // For "Current" or other non-year preferences, look up in pointer data
                // The pointer file contains entries like:
                // Current::eventYear::2026
                // 2025::eventYear::2025
                // Default::eventYear::2026
                dataString = pointerValues[userYearPreference]?["eventYear"] ?? ""
                
                if !dataString.isEmpty {
                    print("🎯 [YEAR_RESOLUTION_DEBUG] ✅ Found eventYear \(dataString) for preference \(userYearPreference)")
                } else {
                    // Fallback to Current if user preference has no data
                    print("🎯 [YEAR_RESOLUTION_DEBUG] ❌ No eventYear found for preference \(userYearPreference), trying Current")
                    print("🎯 [YEAR_RESOLUTION_DEBUG] pointerValues[\(userYearPreference)] = \(pointerValues[userYearPreference] ?? [:])")
                    dataString = pointerValues["Current"]?["eventYear"] ?? ""
                    
                    if !dataString.isEmpty {
                        print("getPointerUrlData: Using Current eventYear: \(dataString)")
                    } else {
                        // Final fallback to Default
                        print("getPointerUrlData: No Current eventYear, trying Default")
                        dataString = pointerValues["Default"]?["eventYear"] ?? ""
                        
                        if !dataString.isEmpty {
                            print("getPointerUrlData: Using Default eventYear: \(dataString)")
                        } else {
            // Ultimate fallback - try cached file or use current calendar year
                            do {
                                if FileManager.default.fileExists(atPath: eventYearFile) {
                                    dataString = try String(contentsOfFile: eventYearFile, encoding: String.Encoding.utf8)
                                    print("getPointerUrlData: Using cached eventYear from file: \(dataString)")
                                } else {
                    let currentYear = Calendar.current.component(.year, from: Date())
                    dataString = String(currentYear)
                    print("getPointerUrlData: Using calendar fallback eventYear: \(dataString)")
                                }
                            } catch {
                let currentYear = Calendar.current.component(.year, from: Date())
                dataString = String(currentYear)
                print("getPointerUrlData: Error reading cached file, using calendar fallback: \(dataString)")
                            }
                        }
                    }
                }
            }
            
            if dataString == "Problem" {
               print ("This is BAD - no valid year found and no cached year available")
               // Don't exit, try to use a reasonable default
               let currentYear = Calendar.current.component(.year, from: Date())
               dataString = String(currentYear)
               print ("Using default year \(dataString) as fallback")
            }
            do {
                if (dataString.count == 4){
                    try dataString.write(toFile: eventYearFile, atomically: true,encoding: String.Encoding.utf8)
                    try cacheVariables.storePointerData[cacheKey] = dataString
                    print ("getPointerUrlData: Just created eventYear file using \(keyValue) = \(dataString)" + eventYearFile);
                } else {
                    try dataString = try String(contentsOfFile: eventYearFile, encoding: String.Encoding.utf8)
                    print ("getPointerUrlData: Just reading eventYear file  using \(keyValue) = \(dataString)" + eventYearFile + " and got \(dataString)");
                }
            } catch let error as NSError {
                print ("getPointerUrlData: Encountered an error of creating file eventYear  using \(keyValue) = \(dataString) File " + error.debugDescription)
            }
            
            // Cache the eventYear result in memory for future fast access
            if !dataString.isEmpty && dataString != "Problem" {
                storePointerLock.sync() {
                    cacheVariables.storePointerData[cacheKey] = dataString
                }
                print("getPointerUrlData: ✅ Cached eventYear result for \(cacheKey) = \(dataString)")
            }
        }
    
    print ("getPointerUrlData: Using Final value of " + actualKeyValue + " of " + dataString + " \(getArtistUrl())")
    
    loadUrlCounter = 0
    
    // If we still have no data (e.g., cached pointer not present yet), return sensible defaults.
    if dataString.isEmpty {
        return getDefaultPointerValue(for: actualKeyValue)
    }
    return dataString
}

/// Returns sensible default values for pointer data keys when network/cache is unavailable during launch
/// This prevents blocking the app launch while providing functional defaults
/// - Parameter keyValue: The key for which to provide a default value
/// - Returns: A sensible default value for the given key
func getDefaultPointerValue(for keyValue: String) -> String {
    print("🚀 LAUNCH OPTIMIZATION: Providing default value for \(keyValue)")
    
    switch keyValue {
    case "eventYear":
        // Use FestivalConfig default year or current year
        let currentYear = Calendar.current.component(.year, from: Date())
        print("🚀 LAUNCH OPTIMIZATION: Default eventYear = \(currentYear) (no hardcoded fallback)")
        return String(currentYear)
        
    case "scheduleUrl":
        // Use FestivalConfig default schedule URL
        let defaultUrl = FestivalConfig.current.scheduleUrlDefault
        print("🚀 LAUNCH OPTIMIZATION: Default scheduleUrl = \(defaultUrl)")
        return defaultUrl
        
    case "artistUrl":
        // Use FestivalConfig default artist URL  
        let defaultUrl = FestivalConfig.current.artistUrlDefault
        print("🚀 LAUNCH OPTIMIZATION: Default artistUrl = \(defaultUrl)")
        return defaultUrl
        
    case let key where key.hasPrefix("reportUrl"):
        // For reportUrl, we should NEVER use fallbacks - always get the correct URL from pointer data
        // If we reach here, it means the pointer resolution failed, which should not happen
        print("🚨 ERROR: reportUrl fallback should never be used! Key: \(key)")
        print("🚨 This indicates a critical failure in pointer data resolution")
        return ""
        
    default:
        // For unknown keys, return empty string - will be updated in background
        print("🚀 LAUNCH OPTIMIZATION: Unknown key \(keyValue), returning empty string")
        return ""
    }
}

/// Triggers a background update of pointer data without blocking current operation
/// This ensures next app launch will have fresh data available
func triggerBackgroundPointerUpdate() {
    print("🚀 LAUNCH OPTIMIZATION: Triggering background pointer update for next launch")
    
    DispatchQueue.global(qos: .background).async {
        // Only proceed if we have internet and this won't interfere with user activity
        guard isInternetAvailable() else {
            print("🚀 LAUNCH OPTIMIZATION: No internet for background pointer update")
            return
        }
        
        print("🚀 LAUNCH OPTIMIZATION: Starting background pointer data download")
        let httpData = getUrlData(urlString: defaultStorageUrl)
        
        if !httpData.isEmpty {
            // Cache the new data for next launch
            let cachedPointerFile = FilePaths.cachedPointerFile
            do {
                try httpData.write(toFile: cachedPointerFile, atomically: true, encoding: .utf8)
                print("🚀 LAUNCH OPTIMIZATION: Background pointer update completed and cached")
            } catch {
                print("🚀 LAUNCH OPTIMIZATION: Failed to cache background pointer update: \(error)")
            }
        }
    }
}

/// Gets the language-specific key for reportUrl based on user's language preference.
/// - Parameter keyValue: The original key value (should be "reportUrl").
/// - Returns: The language-specific key (e.g., "reportUrl-en", "reportUrl-es").
func getLanguageSpecificKey(keyValue: String) -> String {
    // Get the user's preferred language
    let userLanguage = Locale.current.languageCode ?? "en"
    
    // Define supported languages
    let supportedLanguages = ["da", "de", "en", "es", "fi", "fr", "pt"]
    
    // Determine the language to use (default to "en" if not supported)
    let languageToUse = supportedLanguages.contains(userLanguage) ? userLanguage : "en"
    
    // Create the language-specific key
    let languageSpecificKey = "\(keyValue)-\(languageToUse)"
    
    print("getLanguageSpecificKey: Original key: \(keyValue)")
    print("getLanguageSpecificKey: User language: \(userLanguage)")
    print("getLanguageSpecificKey: Language to use: \(languageToUse)")
    print("getLanguageSpecificKey: Language-specific key: \(languageSpecificKey)")
    
    return languageSpecificKey
}

/// Parses a pointer data record and updates the pointer values dictionary and cache as needed.
/// - Parameters:
///   - pointData: The raw pointer data string (delimited by ::).
///   - pointerValues: The current dictionary of pointer values.
///   - pointerIndex: The index to match for updating values.
/// - Returns: The updated pointer values dictionary.
func readPointData(pointData:String, pointerValues: [String:[String:String]], pointerIndex: String)->[String:[String:String]]{
    
    var newPointValues = pointerValues
    
    var valueArray = pointData.components(separatedBy: "::")
    
    if (valueArray.isEmpty == false && valueArray.count >= 3){
        let currentIndex = valueArray[0]
        
        if (currentIndex != "Default" && currentIndex != "lastYear"){
            // THREAD-SAFETY FIX: Synchronize access to prevent crashes from concurrent modification
            eventYearArrayLock.sync {
                if (eventYearArray.contains(currentIndex) == false){
                    eventYearArray.append(currentIndex)
                    // Only log when we actually add a new year, don't save to disk yet
                    print("eventYearsInfoFile: Added new year to array: \(currentIndex)")
                }
            }
        }
        
        if (currentIndex == pointerIndex){
            let currentKey = valueArray[1]
            let currentValue = valueArray[2]
            var tempHash = [String:String]()
            tempHash[currentKey] = currentValue
            print ("getPointerUrlData: Using in loop \(currentIndex) - \(currentKey) - getting \(currentValue)")
            newPointValues[currentIndex] = tempHash
            storePointerLock.async(flags: .barrier) {
                do {
                    try cacheVariables.storePointerData[currentKey] = currentValue;
                } catch let error as NSError {
                    print ("getPointerUrlData: looks like we don't have internet yet")
                }
            }
        }
    }
    
    return newPointValues
}

/// Optimized version of readPointData that processes only necessary data for the selected year
/// This prevents excessive loading of all historical years when only specific year data is needed
/// Respects user's year preference setting (pointerIndex can be "Current", "2025", "2024", etc.)
func readPointDataOptimized(dataArray: [String], pointerValues: [String:[String:String]], pointerIndex: String, targetKeyValue: String) -> [String:[String:String]] {
    
    var newPointValues = pointerValues
    var foundTargetData = false
    var processedSelectedYear = false
    
    // Define essential keys that we always need regardless of year
    let essentialKeys = ["eventYear", "artistUrl", "scheduleUrl", "descriptionMap", "reportUrl"]
    let isEssentialKey = essentialKeys.contains(targetKeyValue) || targetKeyValue.hasPrefix("reportUrl-")
    
    print("readPointDataOptimized: OPTIMIZED PROCESSING - Selected year: \(pointerIndex), targetKey: \(targetKeyValue), will SKIP all other years except for year collection")
    
    // Track which year indices we need to process
    var targetIndices = Set<String>()
    targetIndices.insert(pointerIndex) // Always process the selected year
    if isEssentialKey {
        targetIndices.insert("Default") // Process defaults for essential keys
    }
    
    for record in dataArray {
        // Skip empty records to prevent crashes
        guard !record.isEmpty && record.contains("::") else {
            continue
        }
        
        var valueArray = record.components(separatedBy: "::")
        
        if (valueArray.isEmpty == false && valueArray.count >= 3){
            let currentIndex = valueArray[0]
            
            // STEP 1: Always collect year information for the eventYearArray (need to know available years)
            // THREAD-SAFETY FIX: Synchronize access to prevent crashes from concurrent modification
            if (currentIndex != "Default" && currentIndex != "lastYear"){
                eventYearArrayLock.sync {
                    if (eventYearArray.contains(currentIndex) == false){
                        eventYearArray.append(currentIndex)
                        print("eventYearsInfoFile: Added new year to array: \(currentIndex)")
                    }
                }
            }
            
            // STEP 2: SKIP processing all data for years that are NOT the selected year preference
            // Only process data for the selected year (pointerIndex) and essential defaults
            if !targetIndices.contains(currentIndex) {
                // PERFORMANCE OPTIMIZATION: Skip processing data for this year - not needed for selected year
                continue // Skip this entire record - don't process any data for other years
            }
            
            // STEP 3: Process data only for the selected year preference and essential defaults
            let currentKey = valueArray[1]
            let currentValue = valueArray[2]
            
            // For Default entries, store under the selected year (pointerIndex)
            let storeIndex = (currentIndex == "Default") ? pointerIndex : currentIndex
            
            // Only store Default values if we don't already have this key for the selected year
            let shouldStore = (currentIndex != "Default") || (newPointValues[storeIndex]?[currentKey] == nil)
            
            if shouldStore {
                var tempHash = newPointValues[storeIndex] ?? [String:String]()
                tempHash[currentKey] = currentValue
                let sourceLabel = (currentIndex == "Default") ? "Default fallback" : "year-specific"
                print ("readPointDataOptimized: Storing \(sourceLabel) \(storeIndex) - \(currentKey) - \(currentValue)")
                newPointValues[storeIndex] = tempHash
                
                // Cache in memory for future use
                storePointerLock.async(flags: .barrier) {
                    do {
                        try cacheVariables.storePointerData[currentKey] = currentValue;
                    } catch let error as NSError {
                        print ("readPointDataOptimized: Error caching data: \(error)")
                    }
                }
                
                // Check if we found the specific data we're looking for
                if currentKey == targetKeyValue {
                    foundTargetData = true
                    print("readPointDataOptimized: Found target data: \(targetKeyValue) = \(currentValue)")
                }
            }
            
            if currentIndex == pointerIndex {
                processedSelectedYear = true
            }
        }
    }
    
    print("readPointDataOptimized: Completed processing for year '\(pointerIndex)'. Found target data: \(foundTargetData), Processed selected year: \(processedSelectedYear)")
    // THREAD-SAFETY FIX: Synchronize access when reading count
    let yearCount = eventYearArrayLock.sync { eventYearArray.count }
    print("readPointDataOptimized: Total years in eventYearArray: \(yearCount), but only processed data for: \(Array(targetIndices))")
    
    return newPointValues
}

/// Loads user defaults and venue locations, and sets the current event year from pointer data.
// MARK: - Legacy Setup Defaults (moved to YearManagementService)
// Function moved to YearManagementService.swift - use global accessor below or YearManagementService.shared.setupDefaults()

// MARK: - Legacy Year Change Handler (moved to YearManagementService)
// Function moved to YearManagementService.swift - use global accessor below or YearManagementService.shared.checkAndHandleYearChange()

// MARK: - Legacy Year Resolution (moved to YearManagementService)
// Function moved to YearManagementService.swift - use global accessor below or YearManagementService.shared.ensureYearResolvedAtLaunch()

// MARK: - Legacy Year Change Detection (moved to YearManagementService)
// Function moved to YearManagementService.swift - use global accessor below or YearManagementService.shared.checkForYearChangeInPointerFile()

// MARK: - Legacy URL Setup (moved to YearManagementService)
// Function moved to YearManagementService.swift - use global accessor below or YearManagementService.shared.setupCurrentYearUrls()

// MARK: - Legacy Version Change Detection (moved to YearManagementService)
// Function moved to YearManagementService.swift - use global accessor below or YearManagementService.shared.didVersionChangeFunction()

/// Converts an event type string to a localized version for display.
/// - Parameter eventType: The event type string to localize.
/// - Returns: The localized event type string.
/// NOTE: This function is now a wrapper around EventTypes.convertToLocalLanguage()
/// TODO: Update all references to use EventTypes.convertToLocalLanguage() directly
func convertEventTypeToLocalLanguage(eventType: String) -> String {
    return EventTypes.convertToLocalLanguage(eventType: eventType)
}

/// Checks if the device currently has internet access using the global NetworkStatusManager.
/// - Returns: True if internet is available, false otherwise.
func isInternetAvailable() -> Bool {
    return NetworkStatusManager.shared.isInternetAvailable
}

// Thread-safe queue for cache operations
let cacheVariablesQueue = DispatchQueue(label: "com.70kbands.cacheVariables", attributes: .concurrent)

struct cacheVariables {
    
    // Cache variables for performance optimization
    
    // Thread-safe cache access using concurrent queue with barriers for writes
    private static var _bandPriorityStorageCache = [String:Int]()
    private static var _scheduleStaticCache = [String : [TimeInterval : [String : String]]]()
    private static var _scheduleTimeStaticCache = [TimeInterval : [[String : String]]]()
    private static var _bandNamedStaticCache = [String :[String : String]]()
    private static var _attendedStaticCache = [String : String]()
    private static var _bandNamesStaticCache =  [String :[String : String]]()
    private static var _bandNamesArrayStaticCache = [String]()
    private static var _storePointerData = [String:String]()
    private static var _bandDescriptionUrlCache = [String:String]()
    private static var _bandDescriptionUrlDateCache = [String:String]()
    private static var _lastModifiedDate: Date? = nil
    private static var _justLaunched: Bool = true
    
    // Thread-safe getters and setters
    static var bandPriorityStorageCache: [String:Int] {
        get { return cacheVariablesQueue.sync { _bandPriorityStorageCache } }
        set { cacheVariablesQueue.async(flags: .barrier) { _bandPriorityStorageCache = newValue } }
    }
    
    static var scheduleStaticCache: [String : [TimeInterval : [String : String]]] {
        get { return cacheVariablesQueue.sync { _scheduleStaticCache } }
        set { cacheVariablesQueue.async(flags: .barrier) { _scheduleStaticCache = newValue } }
    }
    
    static var scheduleTimeStaticCache: [TimeInterval : [[String : String]]] {
        get { return cacheVariablesQueue.sync { _scheduleTimeStaticCache } }
        set { cacheVariablesQueue.async(flags: .barrier) { _scheduleTimeStaticCache = newValue } }
    }
    
    static var bandNamedStaticCache: [String :[String : String]] {
        get { return cacheVariablesQueue.sync { _bandNamedStaticCache } }
        set { cacheVariablesQueue.async(flags: .barrier) { _bandNamedStaticCache = newValue } }
    }
    
    static var attendedStaticCache: [String : String] {
        get { return cacheVariablesQueue.sync { _attendedStaticCache } }
        set { cacheVariablesQueue.async(flags: .barrier) { _attendedStaticCache = newValue } }
    }
    
    static var bandNamesStaticCache: [String :[String : String]] {
        get { return cacheVariablesQueue.sync { _bandNamesStaticCache } }
        set { cacheVariablesQueue.async(flags: .barrier) { _bandNamesStaticCache = newValue } }
    }
    
    static var bandNamesArrayStaticCache: [String] {
        get { return cacheVariablesQueue.sync { _bandNamesArrayStaticCache } }
        set { cacheVariablesQueue.async(flags: .barrier) { _bandNamesArrayStaticCache = newValue } }
    }
    
    static var storePointerData: [String:String] {
        get { return cacheVariablesQueue.sync { _storePointerData } }
        set { cacheVariablesQueue.async(flags: .barrier) { _storePointerData = newValue } }
    }
    
    static var bandDescriptionUrlCache: [String:String] {
        get { return cacheVariablesQueue.sync { _bandDescriptionUrlCache } }
        set { cacheVariablesQueue.async(flags: .barrier) { _bandDescriptionUrlCache = newValue } }
    }
    
    static var bandDescriptionUrlDateCache: [String:String] {
        get { return cacheVariablesQueue.sync { _bandDescriptionUrlDateCache } }
        set { cacheVariablesQueue.async(flags: .barrier) { _bandDescriptionUrlDateCache = newValue } }
    }
    
    static var lastModifiedDate: Date? {
        get { return cacheVariablesQueue.sync { _lastModifiedDate } }
        set { cacheVariablesQueue.async(flags: .barrier) { _lastModifiedDate = newValue } }
    }
    
    static var justLaunched: Bool {
        get { return cacheVariablesQueue.sync { _justLaunched } }
        set { cacheVariablesQueue.async(flags: .barrier) { _justLaunched = newValue } }
    }
}

extension Notification.Name {
    static let bandNamesCacheReady = Notification.Name("BandNamesCacheReady")
}

// MARK: - Legacy Year Management Functions (for backward compatibility)
// These functions delegate to YearManagementService.swift
// TODO: Update all references to use YearManagementService.shared directly
func ensureYearResolvedAtLaunch() -> Int {
    return YearManagementService.shared.ensureYearResolvedAtLaunch()
}

func checkForYearChangeInPointerFile(cachedYear: String) {
    YearManagementService.shared.checkForYearChangeInPointerFile(cachedYear: cachedYear)
}

func checkAndHandleYearChange(newYear: String) {
    YearManagementService.shared.checkAndHandleYearChange(newYear: newYear)
}

func setupCurrentYearUrls() {
    YearManagementService.shared.setupCurrentYearUrls()
}

func didVersionChangeFunction() {
    YearManagementService.shared.didVersionChangeFunction()
}

func resolvePriorityNumber(priority: String) -> String {
    return YearManagementService.shared.resolvePriorityNumber(priority: priority)
}

func setupDefaults(runMigrationCheck: Bool = true) {
    YearManagementService.shared.setupDefaults(runMigrationCheck: runMigrationCheck)
}

 

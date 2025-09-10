//
//  Constants.swift
//  70K Bands
//
//  Created by Ron Dorn on 2/7/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import CoreData
import SystemConfiguration
import UIKit
import Network
//prevent alerts from being re-added all the time
var alertTracker = [String]()

//file locations
var showsAttendedFileName = "showsAttended.data";

//icloud data types
var PRIORITY = "priority";  
var ATTENDED = "attended";
var NOTE = "note";

var filterMenu:UIMenu  = UIMenu()

var FCMnumber = "";
var refreshDataCounter = 0;
var defaultUrlConverFlagString = "defaultUrlConverFlag.txt"
var directoryPath = URL(fileURLWithPath:dirs[0])
var storageFile = directoryPath.appendingPathComponent( "data.txt")
var dateFile = directoryPath.appendingPathComponent( "date.txt")
var bandsFile = directoryPath.appendingPathComponent( "bands.txt")
var lastFilters = directoryPath.appendingPathComponent("lastFilters.txt")
var defaultUrlConverFlagUrl = directoryPath.appendingPathComponent(defaultUrlConverFlagString)
var showsAttended = directoryPath.appendingPathComponent(showsAttendedFileName)
let bandFile = getDocumentsDirectory().appendingPathComponent("bandFile")
let countryFile = directoryPath.appendingPathComponent("countryFile")

let lastiCloudDataWriteFile = directoryPath.appendingPathComponent("iCloudDataWrite.txt")
let lastPriorityDataWriteFile = directoryPath.appendingPathComponent("PriorityDataWrite.txt")
let lastScheduleDataWriteFile = directoryPath.appendingPathComponent("ScheduleDataWrite.txt")

var listCount = 0
var noEntriesFlag = false
var bandCounter = 0
var eventCounter = 0
var eventCounterUnoffical = 0
private var _iCloudDataisLoading = false
private var _iCloudScheduleDataisLoading = false
private let iCloudLoadingQueue = DispatchQueue(label: "com.yourapp.iCloudLoadingQueue")

var iCloudDataisLoading: Bool {
    get { iCloudLoadingQueue.sync { _iCloudDataisLoading } }
    set { iCloudLoadingQueue.sync { _iCloudDataisLoading = newValue } }
}

var iCloudScheduleDataisLoading: Bool {
    get { iCloudLoadingQueue.sync { _iCloudScheduleDataisLoading } }
    set { iCloudLoadingQueue.sync { _iCloudScheduleDataisLoading = newValue } }
}

var numberOfFilteredRecords = 0;
var readingBandFile = false;

var touchedThebottom = false;

var refreshAfterMenuIsGoneFlag = false
var isFilterMenuVisible = false

var currentBandList = [String]()

var downloadingAllComments = false
var downloadingAllImages = false
var bandSelected = String();
var eventSelectedIndex = String();

var timeIndexMap : [String:String] = [String:String]();

var inTestEnvironment = false;

var webMessageHelp = String();

var schedulingDataCacheFile = directoryPath.appendingPathComponent( "schedulingDataCacheFile")
var schedulingDataByTimeCacheFile = directoryPath.appendingPathComponent( "schedulingDataByTimeCacheFile")
var bandNamesCacheFile = directoryPath.appendingPathComponent( "bandNamesCacheFile")

let staticLastModifiedDate = DispatchQueue(label: "staticLastModifiedDate")
let staticSchedule = DispatchQueue(label: "staticSchedule")
let staticAttended = DispatchQueue(label: "staticAttended")
let staticBandName = DispatchQueue(label: "staticBandName")
let staticData = DispatchQueue(label: "staticData")
let storePointerLock = DispatchQueue(label: "storePointerLock")
let bandDescriptionLock = DispatchQueue(label: "bandDescriptionLock")

var iCloudCheck = false;
var internetCheckCache = ""
var internetCheckCacheDate = NSDate().timeIntervalSince1970

//prevent mutiple threads doing the same thing
var isAlertGenerationRunning = false
var isLoadingBandData = false
var isLoadingSchedule = false
var isLoadingCommentData = false
var isPerformingQuickLoad = false
var isReadingBandFile = false;
var isGetFilteredBands = false;

var refreshDataLock = false;

let scheduleQueue = DispatchQueue(label: "scheduleQueue")
let bandNameQueue = DispatchQueue(label: "bandNameQueue")
let bandPriorityQueue = DispatchQueue(label: "bandPriorityQueue")
let showsAttendedQueue = DispatchQueue(label: "showsAttendedQueue")

var localTimeZoneAbbreviation :String = TimeZone.current.abbreviation()!

var loadingiCloud = false;
var savingiCloud = false;

//CSV field names
var typeField = "Type"
var showField = "Show"
var bandField = "Band"
var locationField = "Location"
var dayField = "Day"
var dateField = "Date"
var startTimeField = "Start Time"
var endTimeField = "End Time"
var notesField = "Notes"
var urlField = "URL"
var urlDateField = "Date"
var descriptionUrlField = "Description URL"
var imageUrlField = "ImageURL"

var loadUrlCounter = 0

var versionInformation = Bundle.main.infoDictionary?["CFBundleVersion"] as! String
var didVersionChange = false

var lastRefreshEpicTime = Int(Date().timeIntervalSince1970)
var lastRefreshCount = 0

//link containers
var wikipediaLink = [String: String]()
var youtubeLinks = [String: String]()
var metalArchiveLinks = [String: String]()
var bandCountry = [String: String]()
var bandGenre = [String: String]()
var bandNoteWorthy = [String: String]()

//var band list placeHolder
var bandListIndexCache = 0

//number of unoffical events
var unofficalEventCount = 0

let chevronRight = UIImage(systemName: "chevron.right")
let chevronDown = UIImage(systemName: "chevron.down")

//valid event types
var showType = "Show"
var meetAndGreetype = "Meet and Greet"
var clinicType = "Clinic"
var listeningPartyType = "Listening Party"
var specialEventType = "Special Event"
var unofficalEventTypeOld = "Unofficial Event"
var unofficalEventType = "Cruiser Organized"
var karaokeEventType = "Karaoke";

var poolVenueText = "Pool"
var rinkVenueText = "Rink"
var loungeVenueText = "Lounge"
var theaterVenueText = "Theater"

var venueLocation = [String:String]()

//links to external site
var officalSiteButtonName = "Offical Web Site"
var wikipediaButtonName = "Wikipedia"
var youTubeButtonName = "YouTube"
var metalArchivesButtonName = "Metal Archives"

var descriptionLock = false;

let venuePoolKey:String = "Pool";
let venueTheaterKey:String = "Theater";
let venueLoungeKey:String = "Lounge";
let venueRinkKey:String = "Rink";

let sawAllColor = hexStringToUIColor(hex: "#67C10C")
let sawSomeColor = hexStringToUIColor(hex: "#F0D905")
let sawNoneColor = hexStringToUIColor(hex: "#5DADE2")
let sawAllStatus = "sawAll";
let sawSomeStatus = "sawSome";
let sawNoneStatus = "sawNone";

var eventYearArray = [String]();

//alert topics
let subscriptionTopic = FestivalConfig.current.subscriptionTopic
let subscriptionTopicTest = FestivalConfig.current.subscriptionTopicTest
let subscriptionUnofficalTopic = FestivalConfig.current.subscriptionUnofficalTopic

//file names
let dirs = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.allDomainsMask, true)

let scheduleFile = getDocumentsDirectory().appendingPathComponent("scheduleFile.txt")
let descriptionMapFile = getDocumentsDirectory().appendingPathComponent("descriptionMapFile.csv")

let eventYearFile = getDocumentsDirectory().appendingPathComponent("eventYearFile")
let versionInfoFile = getDocumentsDirectory().appendingPathComponent("versionInfoFile")
let eventYearsInfoFile = "eventYearsInfoFile"

var eventYear:Int = 0

//defaults preferences
// artistUrlDefault and scheduleUrlDefault are now defined in preferenceDefault.swift using FestivalConfig

let defaultPrefsValue = "Default";

let testingSetting = "Testing"

var userCountry = ""
var didNotFindMarkedEventsCount = 0
var defaultStorageUrl = FestivalConfig.current.defaultStorageUrl
let defaultStorageUrlTest = FestivalConfig.current.defaultStorageUrlTest
let statsUrl = getPointerUrlData(keyValue: "reportUrl")

//var defaultStorageUrl = "https://www.dropbox.com/s/f3raj8hkfbd81mp/productionPointer2024-Test.txt?raw=1"


var internetAvailble = isInternetAvailable();

var hasScheduleData = false;

var byPassCsvDownloadCheck = false
//var listOfVenues = [String]()
var scheduleReleased = false

var filterMenuNeedsUpdating = false;

var filteredBandCount = 0
var unfilteredBandCount = 0
var unfilteredEventCount = 0
var unfilteredCruiserEventCount = 0
var unfilteredCurrentEventCount = 0

var masterView: MasterViewController!

var googleCloudID = "Nothing";
var currentPointerKey = ""

/// Resolves a priority string (e.g., "1", "2", "3") to a human-readable label ("Must", "Might", "Wont", or "Unknown").
/// - Parameter priority: The priority value as a string.
/// - Returns: A string representing the human-readable priority label.
func resolvePriorityNumber (priority: String)->String {

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

/// Returns the path to the app's documents directory as an NSString.
/// - Returns: The documents directory path.
func getDocumentsDirectory() -> NSString {
    let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
    let documentsDirectory = paths[0]
    return documentsDirectory as NSString
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
    
    if (UserDefaults.standard.string(forKey: "PointerUrl") == testingSetting){
        defaultStorageUrl = FestivalConfig.current.defaultStorageUrlTest
        inTestEnvironment = true;
        
    }
    #if targetEnvironment(simulator)
        inTestEnvironment = true;
    #endif
    
    // Use the user's preference as the pointer index (e.g., "Current", "2025", etc.)
    var pointerIndex = getScheduleUrl()
    
    // IMPROVED CACHING: Check memory cache first with proper cache key
    // CRITICAL: Skip cache for eventYear lookups to avoid stale pointer issues
    let cacheKey = "\(pointerIndex):\(actualKeyValue)"
    if actualKeyValue != "eventYear" {
        storePointerLock.sync() {
            if let cachedValue = cacheVariables.storePointerData[cacheKey], !cachedValue.isEmpty {
                dataString = cachedValue
                print("getPointerUrlData: ✅ FAST CACHE HIT for \(cacheKey) = \(dataString)")
            }
        }
        
        // If we have valid cached data, return it immediately (no network call needed)
        if !dataString.isEmpty {
            print("getPointerUrlData: ✅ Returning cached data for \(actualKeyValue): \(dataString)")
            return dataString
        }
    } else {
        print("getPointerUrlData: ⚠️ Skipping cache for eventYear lookup to ensure fresh resolution")
    }
    
    print("getPointerUrlData: ⚠️ Cache miss for \(actualKeyValue), will need to load pointer data")
    var pointerValues : [String:[String:String]] = [String:[String:String]]()

    print ("Files were Done setting 2 \(pointerIndex)")
    // Only proceed with network/disk operations if cache miss
    if (dataString.isEmpty == true){
        // Check internet availability before attempting download
        if !isInternetAvailable() {
            print("getPointerUrlData: No internet available, using cached data for \(actualKeyValue)")
            
            // Try to use cached pointer data from disk as fallback
            let cachedPointerFile = getDocumentsDirectory().appendingPathComponent("cachedPointerData.txt")
            if FileManager.default.fileExists(atPath: cachedPointerFile) {
                do {
                    let cachedData = try String(contentsOfFile: cachedPointerFile, encoding: .utf8)
                    print("getPointerUrlData: Using cached pointer data from disk")
                    let dataArray = cachedData.components(separatedBy: "\n")
                    // Optimize: Process only necessary data for current year to avoid excessive loading
                    pointerValues = readPointDataOptimized(dataArray: dataArray, pointerValues: pointerValues, pointerIndex: pointerIndex, targetKeyValue: actualKeyValue)
                    
                    // Save eventYearArray to disk once after processing all cached records (synchronous to ensure year is written before further processing)
                    print("eventYearsInfoFile: Saving after processing cached pointer data")
                    let variableStoreHandle = variableStore()
                    variableStoreHandle.storeDataToDisk(data: eventYearArray, fileName: eventYearsInfoFile)
                    
                    dataString = (pointerValues[pointerIndex]?[actualKeyValue]) ?? ""
                    
                    // Cache the result in memory for future use with proper cache key
                    storePointerLock.sync() {
                        cacheVariables.storePointerData[cacheKey] = dataString
                    }
                } catch {
                    print("getPointerUrlData: Failed to read cached pointer data: \(error)")
                }
            }
            return dataString
        }
        
        // If we still don't have data and no internet, provide sensible defaults
        if dataString.isEmpty && !isInternetAvailable() {
            
            // LAUNCH OPTIMIZATION: Always return defaults immediately, no retries during launch
            print("🚀 LAUNCH OPTIMIZATION: No internet and no cache - returning default value for \(actualKeyValue)")
            return getDefaultPointerValue(for: actualKeyValue)
        }
        
        print ("getPointerUrlData: getting URL data of \(defaultStorageUrl) - \(actualKeyValue)")
        
        // MAIN THREAD PROTECTION: Never block main thread with network calls
        var httpData = ""
        if Thread.isMainThread {
            print("🚀 LAUNCH OPTIMIZATION: Main thread detected - returning default value to prevent blocking")
            print("🚀 LAUNCH OPTIMIZATION: Network update will happen in background for next time")
            // Start background update for next time
            DispatchQueue.global(qos: .utility).async {
                _ = getUrlData(urlString: defaultStorageUrl)
                print("🚀 LAUNCH OPTIMIZATION: Background pointer update completed")
            }
            // Return default value immediately instead of blocking
            return getDefaultPointerValue(for: actualKeyValue)
        } else {
            httpData = getUrlData(urlString: defaultStorageUrl)
        }
        
        print ("getPointerUrlData: httpData for pointers data = \(httpData)")
        if (httpData.isEmpty == false){
            
            let dataArray = httpData.components(separatedBy: "\n")
            // Safety check: Ensure we have valid data to process
            guard !dataArray.isEmpty else {
                print("getPointerUrlData: ⚠️ Data array is empty, skipping processing")
                return getDefaultPointerValue(for: keyValue)
            }
            
            // Optimize: Process only necessary data for current year to avoid excessive loading
            do {
                pointerValues = readPointDataOptimized(dataArray: dataArray, pointerValues: pointerValues, pointerIndex: pointerIndex, targetKeyValue: actualKeyValue)
            } catch {
                print("getPointerUrlData: ⚠️ Error processing pointer data: \(error)")
                return getDefaultPointerValue(for: keyValue)
            }
            
            // Save eventYearArray to disk once after processing all HTTP records (synchronous to ensure year is written before further processing)
            print("eventYearsInfoFile: Saving after processing HTTP pointer data")
            let variableStoreHandle = variableStore()
            variableStoreHandle.storeDataToDisk(data: eventYearArray, fileName: eventYearsInfoFile)
            
            dataString = (pointerValues[pointerIndex]?[actualKeyValue]) ?? ""
            
            // Cache the result in memory for future fast access
            if !dataString.isEmpty {
                storePointerLock.sync() {
                    cacheVariables.storePointerData[cacheKey] = dataString
                }
                print("getPointerUrlData: ✅ Cached result for \(cacheKey) = \(dataString)")
            }
            
            // Cache the pointer data to disk for future offline use
            let cachedPointerFile = getDocumentsDirectory().appendingPathComponent("cachedPointerData.txt")
            do {
                try httpData.write(toFile: cachedPointerFile, atomically: true, encoding: .utf8)
                print("getPointerUrlData: Cached pointer data to disk for offline use")
            } catch {
                print("getPointerUrlData: Failed to cache pointer data: \(error)")
            }

        } else {
            print ("getPointerUrlData: Why is \(actualKeyValue) empty - \(dataString)")
            
            // Try to use cached pointer data from disk as fallback
            let cachedPointerFile = getDocumentsDirectory().appendingPathComponent("cachedPointerData.txt")
            if FileManager.default.fileExists(atPath: cachedPointerFile) {
                do {
                    let cachedData = try String(contentsOfFile: cachedPointerFile, encoding: .utf8)
                    print("getPointerUrlData: Using cached pointer data from disk")
                    let dataArray = cachedData.components(separatedBy: "\n")
                    // Optimize: Process only necessary data for current year to avoid excessive loading
                    pointerValues = readPointDataOptimized(dataArray: dataArray, pointerValues: pointerValues, pointerIndex: pointerIndex, targetKeyValue: actualKeyValue)
                    
                    // Save eventYearArray to disk once after processing all fallback cached records (synchronous to ensure year is written before further processing)
                    print("eventYearsInfoFile: Saving after processing fallback cached pointer data")
                    let variableStoreHandle = variableStore()
                    variableStoreHandle.storeDataToDisk(data: eventYearArray, fileName: eventYearsInfoFile)
                    
                    dataString = (pointerValues[pointerIndex]?[actualKeyValue]) ?? ""
                    
                    // Cache the result in memory for future fast access
                    if !dataString.isEmpty {
                        storePointerLock.sync() {
                            cacheVariables.storePointerData[cacheKey] = dataString
                        }
                        print("getPointerUrlData: ✅ Cached fallback result for \(cacheKey) = \(dataString)")
                    }
                } catch {
                    print("getPointerUrlData: Failed to read cached pointer data: \(error)")
                }
            }
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
                            // Ultimate fallback - try cached file or use hardcoded default
                            do {
                                if FileManager.default.fileExists(atPath: eventYearFile) {
                                    dataString = try String(contentsOfFile: eventYearFile, encoding: String.Encoding.utf8)
                                    print("getPointerUrlData: Using cached eventYear from file: \(dataString)")
                                } else {
                                    dataString = "2026" // Hardcoded fallback
                                    print("getPointerUrlData: Using hardcoded fallback eventYear: \(dataString)")
                                }
                            } catch {
                                dataString = "2026" // Hardcoded fallback
                                print("getPointerUrlData: Error reading cached file, using hardcoded fallback: \(dataString)")
                            }
                        }
                    }
                }
            }
            
            if dataString == "Problem" {
               print ("This is BAD - no valid year found and no cached year available")
               // Don't exit, try to use a reasonable default
               dataString = "2026" // Use a reasonable default year
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

    }
    
    print ("getPointerUrlData: Using Final value of " + actualKeyValue + " of " + dataString + " \(getArtistUrl())")
    
    loadUrlCounter = 0
    
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
        let defaultYear = max(currentYear, 2024) // Ensure we don't go below 2024
        print("🚀 LAUNCH OPTIMIZATION: Default eventYear = \(defaultYear)")
        return String(defaultYear)
        
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
            let cachedPointerFile = getDocumentsDirectory().appendingPathComponent("cachedPointerData.txt")
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
            if (eventYearArray.contains(currentIndex) == false){
                eventYearArray.append(currentIndex)
                // Only log when we actually add a new year, don't save to disk yet
                print("eventYearsInfoFile: Added new year to array: \(currentIndex)")
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
            if (currentIndex != "Default" && currentIndex != "lastYear"){
                if (eventYearArray.contains(currentIndex) == false){
                    eventYearArray.append(currentIndex)
                    print("eventYearsInfoFile: Added new year to array: \(currentIndex)")
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
    print("readPointDataOptimized: Total years in eventYearArray: \(eventYearArray.count), but only processed data for: \(Array(targetIndices))")
    
    return newPointValues
}

/// Loads user defaults and venue locations, and sets the current event year from pointer data.
func setupDefaults() {
        
    readFiltersFile()
    setupVenueLocations()
    
    //print ("Schedule URL is \(UserDefaults.standard.string(forKey: "scheduleUrl") ?? "")")
    
    print ("Trying to get the year  \(eventYear)")
    
    // Use robust year resolution that handles launch scenarios
    eventYear = ensureYearResolvedAtLaunch()
    
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
        // Add safety delay to ensure app launch is complete before background operations
        Thread.sleep(forTimeInterval: 1.0)
        do {
            let scheduleUrl = getPointerUrlData(keyValue: "scheduleUrl")
            print("🚀 LAUNCH OPTIMIZATION: Background resolved scheduleURL = \(scheduleUrl)")
        } catch {
            print("🚀 LAUNCH OPTIMIZATION: Background scheduleURL resolution failed: \(error)")
        }
    }

    // Priority data migration to Core Data completed - utility removed

    didVersionChangeFunction();
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
    
    // Step 3: If still no data, use sensible default and trigger background update
    if resolvedYear.isEmpty {
        print("🚀 LAUNCH OPTIMIZATION: No cached year data - using default and triggering background update")
        resolvedYear = getDefaultPointerValue(for: "eventYear")
        
        // Trigger background pointer update for next time (non-blocking)
        triggerBackgroundPointerUpdate()
    }
    
    // Validate the year
    guard let yearInt = Int(resolvedYear), yearInt > 2000 && yearInt < 2030 else {
        print("🚀 LAUNCH OPTIMIZATION: Invalid year '\(resolvedYear)', using current year as fallback")
        let currentYear = Calendar.current.component(.year, from: Date())
        let fallbackYear = max(currentYear, 2024)
        return fallbackYear
    }
    
    print("🚀 LAUNCH OPTIMIZATION: Final resolved year (NON-BLOCKING): \(resolvedYear)")
    print("🎯 [MDF_DEBUG] Festival: \(FestivalConfig.current.festivalShortName)")
    print("🎯 [MDF_DEBUG] Non-blocking eventYear resolution returned: \(resolvedYear)")
    
    return Int(resolvedYear)!
}

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

/// Checks if the app version has changed and updates version info on disk if needed.
func didVersionChangeFunction(){

    var oldVersion = ""
    
    do {
        if FileManager.default.fileExists(atPath: versionInfoFile) == false {
            try versionInformation.write(toFile: versionInfoFile, atomically: true,encoding: String.Encoding.utf8)
        } else {
            try oldVersion = try String(contentsOfFile: eventYearFile, encoding: String.Encoding.utf8)
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


/// Populates the venueLocation dictionary with mappings from venue names to deck locations.
/// Now uses FestivalConfig instead of hardcoded values.
func setupVenueLocations(){
    
    // Clear any existing venue locations
    venueLocation.removeAll()
    
    // Populate from FestivalConfig
    let config = FestivalConfig.current
    for venue in config.venues {
        venueLocation[venue.name] = venue.location
    }
    
    // Legacy compatibility - also add by the old text constants
    venueLocation[poolVenueText] = config.getVenueLocation(for: "Pool")
    venueLocation[rinkVenueText] = config.getVenueLocation(for: "Rink")
    venueLocation[loungeVenueText] = config.getVenueLocation(for: "Lounge")
    venueLocation[theaterVenueText] = config.getVenueLocation(for: "Theater")
}

/// Converts an event type string to a localized version for display.
/// - Parameter eventType: The event type string to localize.
/// - Returns: The localized event type string.
func convertEventTypeToLocalLanguage(eventType: String)->String{
    
    var localEventType = eventType
    
    print ("Recieved an eventType of \(eventType)")
    if eventType == "Cruiser Organized" {
        localEventType = NSLocalizedString("Unofficial Events", comment: "")
        
    } else if eventType == "Listening Party" {
        localEventType = NSLocalizedString(eventType, comment: "")
    
    } else if eventType == "Clinic"{
        localEventType = NSLocalizedString(eventType, comment: "")
        
    } else if eventType == "Meet and Greet"{
        localEventType = NSLocalizedString(eventType, comment: "")
        
    } else if eventType == "Special Event"{
        localEventType = NSLocalizedString(eventType, comment: "")
        
    }
    
    print ("Recieved an eventType and returned \(localEventType)")
    return localEventType;
    
}

/// Checks if the device currently has internet access using the global NetworkStatusManager.
/// - Returns: True if internet is available, false otherwise.
func isInternetAvailable() -> Bool {
    return NetworkStatusManager.shared.isInternetAvailable
}

// Thread-safe queue for cache operations
let cacheVariablesQueue = DispatchQueue(label: "com.70kbands.cacheVariables", attributes: .concurrent)

struct cacheVariables {
    
    // LEGACY: These cache variables are still used by some components during Core Data transition
    // TODO: Remove once all schedule/priority operations are fully migrated to Core Data
    
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


 

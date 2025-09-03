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
        print("getPointerUrlData: Using language-specific key: \(actualKeyValue) for original key: \(keyValue)")
    }
    
    if (UserDefaults.standard.string(forKey: "PointerUrl") == testingSetting){
        defaultStorageUrl = FestivalConfig.current.defaultStorageUrlTest
        inTestEnvironment = true;
        
    }
    #if targetEnvironment(simulator)
        inTestEnvironment = true;
    #endif
    
    // CRITICAL FIX: Use the resolved eventYear for data lookup instead of "Current"
    // The pointer data is stored under the actual year (e.g., "2025") not under "Current"
    var pointerIndex = getScheduleUrl()
    
    // If we're looking for URLs (not eventYear itself), we need to use the resolved year
    if actualKeyValue != "eventYear" && eventYear > 0 {
        pointerIndex = String(eventYear)
        print("getPointerUrlData: Using resolved eventYear \(eventYear) as pointerIndex for \(actualKeyValue)")
    }
    
    // IMPROVED CACHING: Check memory cache first with proper cache key
    // Create a cache key that includes both the pointer index and the actual key
    let cacheKey = "\(pointerIndex):\(actualKeyValue)"
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
    
    print("getPointerUrlData: ⚠️ Cache miss for \(cacheKey), will need to load pointer data")
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
            
            sleep(3)
            
            loadUrlCounter = loadUrlCounter + 1
            
            if (loadUrlCounter < 5){
                dataString = getPointerUrlData(keyValue: keyValue)
            } else {
                print ("Can not load needed data, exiting")
                exit(1)
            }
            
            return dataString
        }
        
        print ("getPointerUrlData: getting URL data of \(defaultStorageUrl) - \(actualKeyValue)")
        
        // Ensure network call happens on background thread to prevent main thread blocking
        var httpData = ""
        if Thread.isMainThread {
            print("getPointerUrlData: Main thread detected, dispatching to background for network call")
            let semaphore = DispatchSemaphore(value: 0)
            DispatchQueue.global(qos: .userInitiated).async {
                httpData = getUrlData(urlString: defaultStorageUrl)
                semaphore.signal()
            }
            semaphore.wait()
        } else {
            httpData = getUrlData(urlString: defaultStorageUrl)
        }
        
        print ("getPointerUrlData: httpData for pointers data = \(httpData)")
        if (httpData.isEmpty == false){
            
            let dataArray = httpData.components(separatedBy: "\n")
            // Optimize: Process only necessary data for current year to avoid excessive loading
            pointerValues = readPointDataOptimized(dataArray: dataArray, pointerValues: pointerValues, pointerIndex: pointerIndex, targetKeyValue: actualKeyValue)
            
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
            print("getPointerUrlData: User year preference: \(userYearPreference)")
            
            // CRITICAL FIX: If user selected a specific year (like "2025"), use that directly
            // This handles cases where the pointer file might not have all year entries
            if userYearPreference.isYearString && userYearPreference != "Current" {
                print("getPointerUrlData: User selected specific year \(userYearPreference), using it directly")
                dataString = userYearPreference
            } else {
                // For "Current" or other non-year preferences, look up in pointer data
                // The pointer file contains entries like:
                // Current::eventYear::2026
                // 2025::eventYear::2025
                // Default::eventYear::2026
                dataString = pointerValues[userYearPreference]?["eventYear"] ?? ""
                
                if !dataString.isEmpty {
                    print("getPointerUrlData: Found eventYear \(dataString) for preference \(userYearPreference)")
                } else {
                    // Fallback to Current if user preference has no data
                    print("getPointerUrlData: No eventYear found for preference \(userYearPreference), trying Current")
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

    print ("eventYear is \(eventYear) scheduleURL is \(getPointerUrlData(keyValue: "scheduleUrl"))")

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
/// This function should be called during app initialization to ensure a valid year is set.
/// - Returns: The resolved year as an integer, or a default year if resolution fails.
func ensureYearResolvedAtLaunch() -> Int {
    print("ensureYearResolvedAtLaunch: Starting year resolution")
    
    // Always resolve from pointer data to respect user's current preference
    // The cached file might be outdated if user changed their year preference
    print("ensureYearResolvedAtLaunch: Resolving from pointer data to respect user preference")
    print("🎯 [MDF_DEBUG] Festival: \(FestivalConfig.current.festivalShortName)")
    print("🎯 [MDF_DEBUG] About to call getPointerUrlData for eventYear...")
    var resolvedYear = getPointerUrlData(keyValue: "eventYear")
    print("🎯 [MDF_DEBUG] getPointerUrlData returned eventYear: '\(resolvedYear)'")
    
    // If pointer data resolution failed, try cached file as fallback
    if resolvedYear.isEmpty {
        print("ensureYearResolvedAtLaunch: Pointer resolution failed, trying cached file")
        do {
            if FileManager.default.fileExists(atPath: eventYearFile) {
                resolvedYear = try String(contentsOfFile: eventYearFile, encoding: String.Encoding.utf8)
                print("ensureYearResolvedAtLaunch: Found cached year as fallback: \(resolvedYear)")
            }
        } catch {
            print("ensureYearResolvedAtLaunch: Could not read cached year")
        }
    }
    
    // Validate the year
    guard let yearInt = Int(resolvedYear), yearInt > 2000 && yearInt < 2030 else {
        print("ensureYearResolvedAtLaunch: Invalid year \(resolvedYear), using default")
        resolvedYear = "2026" // Default fallback
        return Int(resolvedYear)!
    }
    
    print("ensureYearResolvedAtLaunch: Final resolved year: \(resolvedYear)")
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
func setupVenueLocations(){
    
    venueLocation[poolVenueText] = "Deck 11"
    venueLocation[rinkVenueText] = "Deck 3"
    venueLocation[loungeVenueText] = "Deck 5"
    venueLocation[theaterVenueText] = "Deck 3/4"
    venueLocation["Sports Bar"] = "Deck 4"
    venueLocation["Viking Crown"] = "Deck 14"
    venueLocation["Boleros Lounge"] = "Deck 4"
    venueLocation["Solarium"] = "Deck 11"
    venueLocation["Ale And Anchor Pub"] = "Deck 5"
    venueLocation["Ale & Anchor Pub"] = "Deck 5"
    venueLocation["Bull And Bear Pub"] = "Deck 5"
    venueLocation["Bull & Bear Pub"] = "Deck 5"
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

struct cacheVariables {
    
    // LEGACY: These cache variables are still used by some components during Core Data transition
    // TODO: Remove once all schedule/priority operations are fully migrated to Core Data
    static var bandPriorityStorageCache = [String:Int]()
    static var scheduleStaticCache = [String : [TimeInterval : [String : String]]]()
    static var scheduleTimeStaticCache = [TimeInterval : [[String : String]]]()
    
    static var bandNamedStaticCache = [String :[String : String]]()
    static var attendedStaticCache = [String : String]()
    static var bandNamesStaticCache =  [String :[String : String]]()
    static var bandNamesArrayStaticCache = [String]()
    static var storePointerData = [String:String]()
    static var bandDescriptionUrlCache = [String:String]()
    static var bandDescriptionUrlDateCache = [String:String]()
    static var lastModifiedDate:Date? = nil;
    static var justLaunched: Bool = true
}

extension Notification.Name {
    static let bandNamesCacheReady = Notification.Name("BandNamesCacheReady")
}


 

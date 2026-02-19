//
//  Settings70k.swift
//  70K Bands
//
//  Created by Ron Dorn on 10/2/23.
//  Copyright © 2023 Ron Dorn. All rights reserved.
//

import Foundation

// MARK: - Dynamic Venue Filtering System
// Dictionary to store venue filter settings dynamically based on FestivalConfig
private var venueFilterSettings: [String: Bool] = [:]
// Thread-safe access queue for venue settings
private let venueSettingsQueue = DispatchQueue(label: "com.70kbands.venueSettings", attributes: .concurrent)

// Thread-safe queue for readFiltersFile operations
private let filtersFileQueue = DispatchQueue(label: "com.70kbands.filtersFile", qos: .userInitiated)

// Dynamic venue filter functions - Thread Safe
func getShowVenueEvents(venueName: String) -> Bool {
    return venueSettingsQueue.sync {
        // Initialize with true if not set (default to showing all venues)
        return venueFilterSettings[venueName.lowercased(), default: true]
    }
}

func setShowVenueEvents(venueName: String, show: Bool) {
    venueSettingsQueue.async(flags: .barrier) {
        venueFilterSettings[venueName.lowercased()] = show
    }
}

// Helper function to initialize venue filters from FestivalConfig - Thread Safe
func initializeVenueFilters() {
    let venues = FestivalConfig.current.getAllVenueNames()
    venueSettingsQueue.async(flags: .barrier) {
        for venue in venues {
            if venueFilterSettings[venue.lowercased()] == nil {
                venueFilterSettings[venue.lowercased()] = true // Default to showing all venues
            }
        }
    }
}

// Helper function to get all venue filter states - Thread Safe
func getAllVenueFilterStates() -> [String: Bool] {
    return venueSettingsQueue.sync {
        return venueFilterSettings
    }
}

// Helper function to set all configured venues to a specific state - Thread Safe
func setAllVenueFilters(show: Bool) {
    let venues = FestivalConfig.current.getAllVenueNames()
    venueSettingsQueue.async(flags: .barrier) {
        for venue in venues {
            venueFilterSettings[venue.lowercased()] = show
        }
    }
}

/// Set venue filter state for a specific list of venue names (e.g. configured + discovered). Use when clearing all filters so every venue in the menu is reset. Sync so refresh after clear sees updated state.
func setVenueFilters(venueNames: [String], show: Bool) {
    venueSettingsQueue.sync(flags: .barrier) {
        for name in venueNames {
            venueFilterSettings[name.lowercased()] = show
        }
    }
}

/// Ensure filter state exists for venue names (e.g. discovered from event data). Missing entries default to true. Thread-safe; sync so menu has state when built.
func ensureVenueFilterStates(venueNames: [String]) {
    venueSettingsQueue.sync(flags: .barrier) {
        for name in venueNames {
            let key = name.lowercased()
            if venueFilterSettings[key] == nil {
                venueFilterSettings[key] = true
            }
        }
    }
}

var mustSeeOn = true;
var mightSeeOn = true;
var wontSeeOn = true;
var unknownSeeOn = true;
var hideExpireScheduleData = true;
var showTheaterShows = true
var showPoolShows = true
var showRinkShows = true
var showLoungeShows = true
var showOtherShows = true
var showUnofficalEvents = true
var showSpecialEvents = true
var showMeetAndGreetEvents = true
var showScheduleView = true // true = Schedule (mixed), false = Bands Only

// New settings to control visibility of event type filters per festival
var meetAndGreetsEnabled = true
var specialEventsEnabled = true
var unofficalEventsEnabled = true
var showOnlyWillAttened = false;
var sortedBy = "time"

var mustSeeAlertValue = true
var mightSeeAlertValue = true
var onlyAlertForAttendedValue = false

var alertForShowsValue = true
var alertForSpecialValue = true
var alertForMandGValue = false
var alertForUnofficalEventsValue = true
var alertForClinicEvents = false
var alertForListeningEvents = false

var notesFontSizeLargeValue = false
var openYouTubeAppValue = true
var allLinksOpenInExternalBrowserValue = false

var minBeforeAlertValue = 10

var promptForAttended = true

var artistUrlPointer = "Current"
var scheduleUrlPointer  = "Current"

func setArtistUrl(_ value: String){
    print ("setupCurrentYearUrls: setting setArtistUrl to \(value)")
    artistUrlPointer = value
}
func getArtistUrl() -> String{
    print ("setupCurrentYearUrls: loading ArtistUrl of \(artistUrlPointer)")
    return artistUrlPointer
}

func setScheduleUrl(_ value: String){
    scheduleUrlPointer = value
}
func getScheduleUrl() -> String{
    return scheduleUrlPointer
}

func setPromptForAttended(_ value: Bool){
    promptForAttended = value
}
func getPromptForAttended()->Bool{
    return promptForAttended
}

func setMinBeforeAlertValue(_ value: Int){
    minBeforeAlertValue = value
}
func getMinBeforeAlertValue()->Int{
    return minBeforeAlertValue
}

func setNotesFontSizeLargeValue(_ value: Bool){
    notesFontSizeLargeValue = value
}
func getNotesFontSizeLargeValue()->Bool{
    return notesFontSizeLargeValue
}

func setOpenYouTubeAppValue(_ value: Bool){
    openYouTubeAppValue = value
}
func getOpenYouTubeAppValue()->Bool{
    return openYouTubeAppValue
}

func setAllLinksOpenInExternalBrowserValue(_ value: Bool){
    allLinksOpenInExternalBrowserValue = value
}
func getAllLinksOpenInExternalBrowserValue()->Bool{
    return allLinksOpenInExternalBrowserValue
}

func setAlertForListeningEvents(_ value: Bool){
    alertForListeningEvents = value
}
func getAlertForListeningEvents()->Bool{
    return alertForListeningEvents
}

func setAlertForClinicEvents(_ value: Bool){
    print("Setting alertForClinicEvents to be \(value)")
    alertForClinicEvents = value
}
func getAlertForClinicEvents()->Bool{
    return alertForClinicEvents
}

func setAlertForUnofficalEventsValue(_ value: Bool){
    alertForUnofficalEventsValue = value
}
func getAlertForUnofficalEventsValue()->Bool{
    return alertForUnofficalEventsValue
}

func setAlertForMandGValue(_ value: Bool){
    alertForMandGValue = value
}
func getAlertForMandGValue()->Bool{
    return alertForMandGValue
}

func setAlertForShowsValue(_ value: Bool){
    alertForShowsValue = value
}
func getAlertForShowsValue()->Bool{
    return alertForShowsValue
}

func setAlertForSpecialValue(_ value: Bool){
    alertForSpecialValue = value
}
func getAlertForSpecialValue()->Bool{
    return alertForSpecialValue
}

func setMustSeeAlertValue(_ value: Bool){
    mustSeeAlertValue = value
}
func getMustSeeAlertValue()->Bool{
    return mustSeeAlertValue
}

func setMightSeeAlertValue(_ value: Bool){
    mightSeeAlertValue = value
}
func getMightSeeAlertValue()->Bool{
    return mightSeeAlertValue
}

func setOnlyAlertForAttendedValue(_ value: Bool){
    onlyAlertForAttendedValue = value
}
func getOnlyAlertForAttendedValue()->Bool{
    return onlyAlertForAttendedValue
}

func setShowTheaterShows(_ value: Bool){
    showTheaterShows = value
    // Also update the dynamic system
    setShowVenueEvents(venueName: "Theater", show: value)
}
func getShowTheaterShows() -> Bool{
    // Use dynamic system if available, otherwise fall back to hardcoded
    let dynamicValue = getShowVenueEvents(venueName: "Theater")
    print("🔍 [SETTINGS_DEBUG] getShowTheaterShows() returning: \(dynamicValue)")
    return dynamicValue
}

func setShowPoolShows(_ value: Bool){
    showPoolShows = value
    // Also update the dynamic system
    setShowVenueEvents(venueName: "Pool", show: value)
}
func getShowPoolShows() -> Bool{
    // Use dynamic system if available, otherwise fall back to hardcoded
    let dynamicValue = getShowVenueEvents(venueName: "Pool")
    print("🔍 [SETTINGS_DEBUG] getShowPoolShows() returning: \(dynamicValue)")
    return dynamicValue
}

func setShowRinkShows(_ value: Bool){
    showRinkShows = value
    // Also update the dynamic system
    setShowVenueEvents(venueName: "Rink", show: value)
}
func getShowRinkShows() -> Bool{
    // Use dynamic system if available, otherwise fall back to hardcoded
    let dynamicValue = getShowVenueEvents(venueName: "Rink")
    print("🔍 [SETTINGS_DEBUG] getShowRinkShows() returning: \(dynamicValue)")
    return dynamicValue
}

func setShowLoungeShows(_ value: Bool){
    showLoungeShows = value
    // Also update the dynamic system
    setShowVenueEvents(venueName: "Lounge", show: value)
}
func getShowLoungeShows() -> Bool{
    // Use dynamic system if available, otherwise fall back to hardcoded
    let dynamicValue = getShowVenueEvents(venueName: "Lounge")
    return dynamicValue
}

func setShowOtherShows(_ value: Bool){
    showOtherShows = value
}
func getShowOtherShows() -> Bool{
    return showOtherShows
}

func setShowUnofficalEvents(_ value: Bool){
    print("🔧 [UNOFFICIAL_DEBUG] setShowUnofficalEvents called with value: \(value)")
    showUnofficalEvents = value
}
func getShowUnofficalEvents() -> Bool{
    print("🔧 [UNOFFICIAL_DEBUG] getShowUnofficalEvents returning: \(showUnofficalEvents)")
    return showUnofficalEvents
}

func setShowSpecialEvents(_ value: Bool){
    showSpecialEvents = value
}
func getShowSpecialEvents() -> Bool{
    return showSpecialEvents
}

func setShowMeetAndGreetEvents(_ value: Bool){
    showMeetAndGreetEvents = value
}
func getShowMeetAndGreetEvents() -> Bool{
    return showMeetAndGreetEvents
}

func setShowScheduleView(_ value: Bool){
    showScheduleView = value
}

func getShowScheduleView() -> Bool{
    return showScheduleView
}

// MARK: - Event Type Filter Visibility Settings
func setMeetAndGreetsEnabled(_ value: Bool){
    meetAndGreetsEnabled = value
}
func getMeetAndGreetsEnabled() -> Bool{
    return meetAndGreetsEnabled
}

func setSpecialEventsEnabled(_ value: Bool){
    specialEventsEnabled = value
}
func getSpecialEventsEnabled() -> Bool{
    return specialEventsEnabled
}

func setUnofficalEventsEnabled(_ value: Bool){
    unofficalEventsEnabled = value
}
func getUnofficalEventsEnabled() -> Bool{
    return unofficalEventsEnabled
}

// Track when user explicitly sets preferences to prevent readFiltersFile from overriding
private var lastUserPreferenceChangeTime: TimeInterval = 0

func setHideExpireScheduleData(_ value: Bool){
    // Check if this is called from readFiltersFile (which would be an override)
    let callStack = Thread.callStackSymbols.joined(separator: " ")
    let isFromReadFilters = callStack.contains("readFiltersFile")
    
    if isFromReadFilters {
        // This is readFiltersFile trying to override a user preference
        let timeSinceUserChange = Date().timeIntervalSince1970 - lastUserPreferenceChangeTime
        if timeSinceUserChange < 5.0 { // Within 5 seconds of user change
            // Block readFiltersFile from overriding recent user preference changes
            return
        }
    } else {
        // This is a direct user preference change - track the timestamp
        lastUserPreferenceChangeTime = Date().timeIntervalSince1970
    }
    
    hideExpireScheduleData = value
}
func getHideExpireScheduleData() -> Bool{
    return hideExpireScheduleData
}

func setHideScheduleButton(_ value: Bool){
    hideScheduleButton = value
}

func getHideScheduleButton() -> Bool{
    return hideScheduleButton
}

func setScheduleButton(_ value: Bool){
    hideScheduleButton = value
}
func getScheduleButton() -> Bool{
    return hideScheduleButton
}

func setMustSeeOn(_ value: Bool){
    mustSeeOn = value
}
func getMustSeeOn() -> Bool{
    return mustSeeOn
}
func setMightSeeOn(_ value: Bool){
    mightSeeOn = value
}

func getMightSeeOn() -> Bool{
    return mightSeeOn
}
func setWontSeeOn(_ value: Bool){
    wontSeeOn = value
}
func getWontSeeOn() -> Bool{
    return wontSeeOn
}

func setUnknownSeeOn(_ value: Bool){
    unknownSeeOn = value
}
func getUnknownSeeOn() -> Bool{
    return unknownSeeOn
}

func setShowOnlyWillAttened(_ value: Bool){
    showOnlyWillAttened = value
    print ("Setting showOnlyWillAttened to \(value)")
}
func getShowOnlyWillAttened() -> Bool{
    print ("Returning showOnlyWillAttened as \(showOnlyWillAttened)")
    return showOnlyWillAttened
}

func setSortedBy(_ value: String){
    sortedBy = value
}
func getSortedBy() -> String{
    print("🎯 SORT DEBUG - getSortedBy() returning: '\(sortedBy)'")
    return sortedBy
}

func writeFiltersFile(){
    
    // CRITICAL FIX: Use synchronous write to prevent race conditions where read happens before write completes
    // The async write was causing iPad preference reversion when rapid read/write cycles occurred
    var prefsString = String()
        
        print ("Status of getWontSeeOn save = \(getWontSeeOn())")
        prefsString = "mustSeeOn:" + boolToString(getMustSeeOn()) + ";"
        prefsString += "mightSeeOn:" + boolToString(getMightSeeOn()) + ";"
        prefsString += "wontSeeOn:" + boolToString(getWontSeeOn()) + ";"
        prefsString += "unknownSeeOn:" + boolToString(getUnknownSeeOn()) + ";"
        prefsString += "showOnlyWillAttened:" + boolToString(getShowOnlyWillAttened()) + ";"
        prefsString += "sortedBy:" + getSortedBy() + ";"
        prefsString += "currentTimeZone:" + localTimeZoneAbbreviation + ";"
        prefsString += "hideExpireScheduleData:" + boolToString(getHideExpireScheduleData()) + ";"
        
        prefsString += "showTheaterShows:" + boolToString(getShowTheaterShows()) + ";"
        prefsString += "showPoolShows:" + boolToString(getShowPoolShows()) + ";"
        prefsString += "showRinkShows:" + boolToString(getShowRinkShows()) + ";"
        prefsString += "showLoungeShows:" + boolToString(getShowLoungeShows()) + ";"
        prefsString += "showOtherShows:" + boolToString(getShowOtherShows()) + ";"
        
        // Save dynamic venue settings
        let dynamicVenueSettings = getAllVenueFilterStates()
        for (venueName, showState) in dynamicVenueSettings {
            prefsString += "venue_\(venueName.lowercased()):" + boolToString(showState) + ";"
        }
        prefsString += "showUnofficalEvents:" + boolToString(getShowUnofficalEvents()) + ";"
        prefsString += "showSpecialEvents:" + boolToString(getShowSpecialEvents()) + ";"
        prefsString += "showMeetAndGreetEvents:" + boolToString(getShowMeetAndGreetEvents()) + ";"
        prefsString += "showScheduleView:" + boolToString(getShowScheduleView()) + ";"
        
        // Event type filter visibility settings
        prefsString += "meetAndGreetsEnabled:" + boolToString(getMeetAndGreetsEnabled()) + ";"
        prefsString += "specialEventsEnabled:" + boolToString(getSpecialEventsEnabled()) + ";"
        prefsString += "unofficalEventsEnabled:" + boolToString(getUnofficalEventsEnabled()) + ";"

        prefsString += "mustSeeAlertValue:" + boolToString(getMustSeeAlertValue()) + ";"
        prefsString += "mightSeeAlertValue:" + boolToString(getMightSeeAlertValue()) + ";"
        prefsString += "onlyAlertForAttendedValue:" + boolToString(getOnlyAlertForAttendedValue()) + ";"

        prefsString += "alertForShowsValue:" + boolToString(getAlertForShowsValue()) + ";"
        prefsString += "alertForSpecialValue:" + boolToString(getAlertForSpecialValue()) + ";"
        prefsString += "alertForMandGValue:" + boolToString(getAlertForMandGValue()) + ";"
        prefsString += "alertForUnofficalEventsValue:" + boolToString(getAlertForUnofficalEventsValue()) + ";"
        prefsString += "alertForClinicEvents:" + boolToString(getAlertForClinicEvents()) + ";"
        prefsString += "alertForListeningEvents:" + boolToString(getAlertForListeningEvents()) + ";"
        
        prefsString += "notesFontSizeLargeValue:" + boolToString(getNotesFontSizeLargeValue()) + ";"
        prefsString += "openYouTubeAppValue:" + boolToString(getOpenYouTubeAppValue()) + ";"
        prefsString += "allLinksOpenInExternalBrowserValue:" + boolToString(getAllLinksOpenInExternalBrowserValue()) + ";"
        
        prefsString += "minBeforeAlertValue:" + String(getMinBeforeAlertValue()) + ";"

        prefsString += "promptForAttended:" + boolToString(getPromptForAttended()) + ";"
        
        prefsString += "artistUrl:" + getArtistUrl() + ";"
        prefsString += "scheduleUrl:" + getScheduleUrl() + ";"
        
        print ("Wrote prefs " + prefsString)
        do {
            try prefsString.write(to: lastFilters, atomically: true, encoding: String.Encoding.utf8)
            print ("saved sortedBy = " + getSortedBy())
        } catch {
            print ("Status of getWontSeeOn NOT saved \(error.localizedDescription)")
        }
        print ("Saving showOnlyWillAttened = \(getShowOnlyWillAttened())")
}


func readFiltersFile(){
    // Thread-safe execution to prevent crashes from multiple simultaneous calls
    filtersFileQueue.sync {
        readFiltersFileInternal()
    }
}

private func readFiltersFileInternal(){
    
    var tempCurrentTimeZone = "";
    
    // Always initialize venue filters from FestivalConfig (handles festival switching)
    initializeVenueFilters()
    
    if (FileManager.default.fileExists(atPath:lastFilters.relativePath) == false){
        establishDefaults()
        writeFiltersFile()
    }
    
    if let data = try? String(contentsOf:lastFilters, encoding: String.Encoding.utf8) {
        let dataArray = data.components(separatedBy: ";")
        for record in dataArray {
            var valueArray = record.components(separatedBy: ":")
            
            switch valueArray[0] {
                
            case "mustSeeOn":
                setMustSeeOn(stringToBool(valueArray[1]))
            
            case "mightSeeOn":
                setMightSeeOn(stringToBool(valueArray[1]))
           
            case "wontSeeOn":
                setWontSeeOn(stringToBool(valueArray[1]))
            
            case "unknownSeeOn":
                setUnknownSeeOn(stringToBool(valueArray[1]))
            
            case "showOnlyWillAttened":
                setShowOnlyWillAttened(stringToBool(valueArray[1]))
            
            case "currentTimeZone":
                tempCurrentTimeZone = valueArray[1]
            
            case "sortedBy":
                setSortedBy(valueArray[1])
            
            case "hideExpireScheduleData":
                setHideExpireScheduleData(stringToBool(valueArray[1]))

            case "showTheaterShows":
                setShowTheaterShows(stringToBool(valueArray[1]))
            
            case "showPoolShows":
                setShowPoolShows(stringToBool(valueArray[1]))

            case "showRinkShows":
                setShowRinkShows(stringToBool(valueArray[1]))
            
            case "showLoungeShows":
                setShowLoungeShows(stringToBool(valueArray[1]))
            
            case "showOtherShows":
                setShowOtherShows(stringToBool(valueArray[1]))
            
            case "showUnofficalEvents":
                print ("🔧 [UNOFFICIAL_DEBUG] Found showUnofficalEvents in file with value: \(valueArray[1])")
                setShowUnofficalEvents(stringToBool(valueArray[1]))
                print ("🔧 [UNOFFICIAL_DEBUG] After parsing from file, showUnofficalEvents = \(showUnofficalEvents)")
            
            case "showSpecialEvents":
                setShowSpecialEvents(stringToBool(valueArray[1]))
            
            case "showMeetAndGreetEvents":
                setShowMeetAndGreetEvents(stringToBool(valueArray[1]))
            case "showScheduleView":
                setShowScheduleView(stringToBool(valueArray[1]))
            
            case "meetAndGreetsEnabled":
                setMeetAndGreetsEnabled(stringToBool(valueArray[1]))
            
            case "specialEventsEnabled":
                setSpecialEventsEnabled(stringToBool(valueArray[1]))
            
            case "unofficalEventsEnabled":
                setUnofficalEventsEnabled(stringToBool(valueArray[1]))

            case "mustSeeAlertValue":
                setMustSeeAlertValue(stringToBool(valueArray[1]))
                
            case "mightSeeAlertValue":
                setMightSeeAlertValue(stringToBool(valueArray[1]))
                
            case "onlyAlertForAttendedValue":
                setOnlyAlertForAttendedValue(stringToBool(valueArray[1]))
                
            case "alertForShowsValue":
                setAlertForShowsValue(stringToBool(valueArray[1]))
                
            case "alertForSpecialValue":
                setAlertForSpecialValue(stringToBool(valueArray[1]))
                
            case "alertForMandGValue":
                setAlertForMandGValue(stringToBool(valueArray[1]))

            case "alertForListeningEvents":
                setAlertForListeningEvents(stringToBool(valueArray[1]))
                
            case "alertForClinicEvents":
                setAlertForClinicEvents(stringToBool(valueArray[1]))
                
            case "alertForUnofficalEventsValue":
                setAlertForUnofficalEventsValue(stringToBool(valueArray[1]))
                
            case "notesFontSizeLargeValue":
                setNotesFontSizeLargeValue(stringToBool(valueArray[1]))
            
            case "openYouTubeAppValue":
                setOpenYouTubeAppValue(stringToBool(valueArray[1]))
            
            case "allLinksOpenInExternalBrowserValue":
                setAllLinksOpenInExternalBrowserValue(stringToBool(valueArray[1]))
            
            case "promptForAttended":
                setPromptForAttended(stringToBool(valueArray[1]))
                
            case "minBeforeAlertValue":
                setMinBeforeAlertValue(Int(valueArray[1]) ?? 10)

            case "artistUrl":
                print("🎯 [FILTERS_DEBUG] Loading artistUrl from file: '\(valueArray[1])'")
                setArtistUrl(valueArray[1])
                
            case "scheduleUrl":
                print("🎯 [FILTERS_DEBUG] Loading scheduleUrl from file: '\(valueArray[1])'")
                setScheduleUrl(valueArray[1])
                
                default:
                    // Handle dynamic venue settings
                    if valueArray[0].hasPrefix("venue_") {
                        let venueName = String(valueArray[0].dropFirst(6)) // Remove "venue_" prefix
                        setShowVenueEvents(venueName: venueName, show: stringToBool(valueArray[1]))
                        print("🏟️ [VENUE_SETTINGS] Loaded venue '\(venueName)' = \(stringToBool(valueArray[1]))")
                    } else {
                        print("⚠️ [SETTINGS_DEBUG] Unknown setting key: \(valueArray[0])")
                    }
            }
        }
        // CRITICAL FIX: Force festival-specific event type filter defaults 
        // This prevents saved preferences from overriding festival-specific settings
        if getMeetAndGreetsEnabled() != FestivalConfig.current.meetAndGreetsEnabledDefault ||
           getSpecialEventsEnabled() != FestivalConfig.current.specialEventsEnabledDefault ||
           getUnofficalEventsEnabled() != FestivalConfig.current.unofficalEventsEnabledDefault {
            setMeetAndGreetsEnabled(FestivalConfig.current.meetAndGreetsEnabledDefault)
            setSpecialEventsEnabled(FestivalConfig.current.specialEventsEnabledDefault)
            setUnofficalEventsEnabled(FestivalConfig.current.unofficalEventsEnabledDefault)
            writeFiltersFile() // Save corrected values
        }
        
        print ("Loading setScheduleUrl = \(getScheduleUrl())")
        print ("Loading mustSeeOn = \(getMustSeeOn())")
    }
    
    if (tempCurrentTimeZone != localTimeZoneAbbreviation){
        alertTracker = [String]()
        let localNotification = localNoticationHandler()
        localNotification.clearNotifications()
        // DEFERRED NOTIFICATION SETUP: Don't call addNotifications() during app launch
        // This prevents deadlock during launch. Notifications will be set up after app is ready.
        print("🔔 [NOTIFICATION_DEFER] Deferring notification setup to prevent launch deadlock")
    }
}

func establishDefaults(){
    // Initialize dynamic venue filters from FestivalConfig
    initializeVenueFilters()
    
    setMustSeeOn(true)
    setMightSeeOn(true)
    setWontSeeOn(true)
    setUnknownSeeOn(true)
    setShowOnlyWillAttened(false)
    setSortedBy("time")
    setHideExpireScheduleData(true)
    setShowTheaterShows(true)
    setShowPoolShows(true)
    setShowRinkShows(true)
    setShowLoungeShows(true)
    setShowOtherShows(true)
    setShowUnofficalEvents(true)
    setShowSpecialEvents(true)
    setShowMeetAndGreetEvents(true)
    setShowScheduleView(true)
    
    // Set festival-specific defaults for event type filter visibility from FestivalConfig
    setMeetAndGreetsEnabled(FestivalConfig.current.meetAndGreetsEnabledDefault)
    setSpecialEventsEnabled(FestivalConfig.current.specialEventsEnabledDefault)
    setUnofficalEventsEnabled(FestivalConfig.current.unofficalEventsEnabledDefault)
    setMustSeeAlertValue(true)
    setMightSeeAlertValue(true)
    setOnlyAlertForAttendedValue(false)
    setAlertForShowsValue(true)
    setAlertForSpecialValue(true)
    setAlertForMandGValue(false)
    setAlertForListeningEvents(false)
    setAlertForClinicEvents(false)
    setAlertForUnofficalEventsValue(true)
    setNotesFontSizeLargeValue(false)
    setOpenYouTubeAppValue(true)
    setAllLinksOpenInExternalBrowserValue(false)
    setPromptForAttended(true)
    setMinBeforeAlertValue(10)
}


func boolToString(_ value: Bool) -> String{
    
    var result = String()
    
    if (value == true){
        result = "true"
    } else {
        result = "false"
    }
    
    return result
}

func stringToBool(_ value: String) -> Bool{
    
    var result = Bool()
    
    if (value == "true"){
        result = true
    } else {
        result = false
    }
    
    return result
}

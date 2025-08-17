//
//  PreferencesViewModel.swift
//  70K Bands
//
//  Created by Assistant on 12/19/24.
//  Copyright (c) 2024 Ron Dorn. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

class PreferencesViewModel: ObservableObject {
    
    // Static request IDs to manage data loading
    static var currentLoadRequestID: Int = 0
    static var currentBandDataRequestID: Int = 0
    static var currentScheduleDataRequestID: Int = 0
    
    // MARK: - Published Properties
    @Published var hideExpiredEvents: Bool = false {
        didSet { setHideExpireScheduleData(hideExpiredEvents) }
    }
    @Published var promptForAttended: Bool = false {
        didSet { setPromptForAttended(promptForAttended) }
    }
    
    // Alert Preferences
    @Published var alertOnMustSee: Bool = true {
        didSet { setMustSeeAlertValue(alertOnMustSee) }
    }
    @Published var alertOnMightSee: Bool = true {
        didSet { setMightSeeAlertValue(alertOnMightSee) }
    }
    @Published var alertOnlyForWillAttend: Bool = false {
        didSet { 
            setOnlyAlertForAttendedValue(alertOnlyForWillAttend)
            // Reset notifications when this changes
            let localNotification = localNoticationHandler()
            localNotification.clearNotifications()
            localNotification.addNotifications()
        }
    }
    @Published var minutesBeforeAlert: Int = 10 {
        didSet {
            let previousValue = oldValue
            
            // Check if the value actually changed
            if minutesBeforeAlert == previousValue {
                print("🚫 Minutes before alert unchanged: \(minutesBeforeAlert)")
                return
            }
            
            // Validate range 0-60
            if minutesBeforeAlert >= 0 && minutesBeforeAlert <= 60 {
                print("🎯 Minutes before alert changed: \(previousValue) -> \(minutesBeforeAlert)")
                setMinBeforeAlertValue(minutesBeforeAlert)
                // Reset notifications when minutes change
                let localNotification = localNoticationHandler()
                localNotification.clearNotifications()
                localNotification.addNotifications()
            } else {
                // Revert to previous valid value
                print("🚫 Invalid minutes value: \(minutesBeforeAlert), reverting to: \(previousValue)")
                minutesBeforeAlert = previousValue
                showValidationError = true
            }
        }
    }
    @Published var alertForShows: Bool = true {
        didSet { setAlertForShowsValue(alertForShows) }
    }
    @Published var alertForSpecialEvents: Bool = true {
        didSet { setAlertForSpecialValue(alertForSpecialEvents) }
    }
    @Published var alertForCruiserOrganized: Bool = false {
        didSet { setAlertForUnofficalEventsValue(alertForCruiserOrganized) }
    }
    @Published var alertForMeetAndGreet: Bool = false {
        didSet { setAlertForMandGValue(alertForMeetAndGreet) }
    }
    @Published var alertForClinics: Bool = false {
        didSet { setAlertForClinicEvents(alertForClinics) }
    }
    @Published var alertForAlbumListening: Bool = false {
        didSet { setAlertForListeningEvents(alertForAlbumListening) }
    }
    
    // Detail Screen
    @Published var noteFontSizeLarge: Bool = false {
        didSet { setNotesFontSizeLargeValue(noteFontSizeLarge) }
    }
    
    // Year Selection and UI State
    @Published var selectedYear: String = "Current"
    @Published var availableYears: [String] = ["Current"]
    @Published var showYearChangeConfirmation = false
    @Published var showBandEventChoice = false
    @Published var showNetworkError = false
    @Published var showValidationError = false
    @Published var isLoadingData = false
    
    // Info Display
    @Published var userId: String = ""
    @Published var buildInfo: String = ""
    
    // MARK: - Private Properties
    private var eventYearArray: [String] = []
    private var eventYearChangeAttempt: String = "Current"
    private var currentYearSetting: String = "Current"
    private var currentYearChangeTask: Task<Void, Never>? = nil
    
    // MARK: - Initialization
    init() {
        setupUserInfo()
        loadAvailableYears()
        loadCurrentPreferences()
        
        // Defer any heavy iCloud operations to avoid blocking the preferences UI
        DispatchQueue.global(qos: .background).async {
            // Any heavy data operations that might be needed can go here
            // This ensures the preferences screen opens immediately
        }
    }
    
    // MARK: - Public Methods
    func loadCurrentPreferences() {
        // Temporarily disable didSet observers by loading values directly
        let hideExpired = getHideExpireScheduleData()
        let promptAttended = getPromptForAttended()
        
        let mustSee = getMustSeeAlertValue()
        let mightSee = getMightSeeAlertValue()
        let onlyAttended = getOnlyAlertForAttendedValue()
        let minutes = getMinBeforeAlertValue()
        let shows = getAlertForShowsValue()
        let special = getAlertForSpecialValue()
        let cruiser = getAlertForUnofficalEventsValue()
        let meetGreet = getAlertForMandGValue()
        let clinics = getAlertForClinicEvents()
        let listening = getAlertForListeningEvents()
        
        let fontLarge = getNotesFontSizeLargeValue()
        
        currentYearSetting = getScheduleUrl()
        var displayYear = currentYearSetting
        if !displayYear.isYearString {
            displayYear = NSLocalizedString("Current", comment: "")
        }
        
        // Now set the values (this will trigger didSet but that's ok for initial load)
        hideExpiredEvents = hideExpired
        promptForAttended = promptAttended
        alertOnMustSee = mustSee
        alertOnMightSee = mightSee
        alertOnlyForWillAttend = onlyAttended
        minutesBeforeAlert = minutes
        alertForShows = shows
        alertForSpecialEvents = special
        alertForCruiserOrganized = cruiser
        alertForMeetAndGreet = meetGreet
        alertForClinics = clinics
        alertForAlbumListening = listening
        noteFontSizeLarge = fontLarge
        selectedYear = displayYear
    }
    
    func refreshDataAndNotifications() {
        // Final cleanup - reset notifications
        let localNotification = localNoticationHandler()
        localNotification.clearNotifications()
        localNotification.addNotifications()
        
        // Trigger data refresh in background
        DispatchQueue.global(qos: .background).async {
            masterView.bandNameHandle.gatherData()
            masterView.schedule.DownloadCsv()
            masterView.schedule.populateSchedule(forceDownload: false)
            
            DispatchQueue.main.async {
                masterView.refreshData(isUserInitiated: true)
            }
        }
    }
    
    func selectYear(_ year: String) {
        // Prevent selecting the same year as currently set
        guard year != selectedYear else {
            print("🚫 Year selection ignored: '\(year)' is already selected")
            return
        }
        
        print("🎯 Year selection: '\(year)' (previous: '\(selectedYear)')")
        
        // Find the original year value from eventYearArray that matches the display year
        let originalYear = findOriginalYear(for: year)
        eventYearChangeAttempt = originalYear
        showYearChangeConfirmation = true
    }
    
    func refreshAvailableYears() {
        // Force reload of years (similar to buildEventYearMenu logic)
        eventYearArray = []
        loadAvailableYears()
    }
    
    func confirmYearChange() {
        showYearChangeConfirmation = false
        isLoadingData = true
        
        // Cancel any ongoing year change task
        currentYearChangeTask?.cancel()
        print("🚫 Cancelled any previous year change task")
        
        // Start new year change task
        currentYearChangeTask = Task {
            await performYearChangeWithFullLogic()
            currentYearChangeTask = nil
        }
    }
    
    func selectBandList() {
        print("🎯 selectBandList: Data already loaded from year change - navigating immediately")
        showBandEventChoice = false
        
        // Force hide expired events for band list
        hideExpiredEvents = true
        setHideExpireScheduleData(true)
        
        // Refresh display and navigate back immediately (data already loaded during year change)
        NotificationCenter.default.post(name: Notification.Name(rawValue: "RefreshDisplay"), object: nil)
        masterView.refreshData(isUserInitiated: true)
        
        print("🎯 Band List selection complete - navigating back to main screen")
        navigateBackToMainScreen()
    }
    
    func selectEventList() {
        print("🎯 selectEventList: Data already loaded from year change - navigating immediately")
        showBandEventChoice = false
        
        // Show expired events for event list
        hideExpiredEvents = false
        setHideExpireScheduleData(false)
        
        // Refresh display and navigate back immediately (data already loaded during year change)
        NotificationCenter.default.post(name: Notification.Name(rawValue: "RefreshDisplay"), object: nil)
        masterView.refreshData(isUserInitiated: true)
        
        print("🎯 Event List selection complete - navigating back to main screen")
        navigateBackToMainScreen()
    }
    
    func dismissNetworkError() {
        showNetworkError = false
        isLoadingData = false
        // Reset year selection to current
        cancelYearChange()
    }
    
    func cancelYearChange() {
        showYearChangeConfirmation = false
        // Reset to current year setting
        var displayYear = currentYearSetting
        if !displayYear.isYearString {
            displayYear = NSLocalizedString("Current", comment: "")
        }
        selectedYear = displayYear
    }
    
    // MARK: - Private Methods
    private func setupUserInfo() {
        // Set up user ID
        if let uuid = UIDevice.current.identifierForVendor?.uuidString {
            userId = uuid
        } else {
            userId = "Unknown"
        }
        
        // Set up build info using the same format as original
        buildInfo = versionInformation
    }
    
    private func loadAvailableYears() {
        let variableStoreHandle = variableStore()
        print("🎯 Loading event years from file: \(eventYearsInfoFile)")
        
        // Load event years from disk
        if eventYearArray.isEmpty {
            eventYearArray = variableStoreHandle.readDataFromDiskArray(fileName: eventYearsInfoFile) ?? ["Current"]
            print("🎯 eventYearsInfoFile: file is loaded \(eventYearArray)")
        }
        
        // Map to display names, keeping original values for comparison
        availableYears = eventYearArray.map { eventElement in
            var yearChange = eventElement
            if !yearChange.isYearString {
                yearChange = NSLocalizedString("Current", comment: "")
            }
            print("🎯 Mapping year: \(eventElement) -> \(yearChange)")
            return yearChange
        }
        
        print("🎯 Final available years: \(availableYears)")
        print("🎯 Raw eventYearArray: \(eventYearArray)")
    }
    
    private func findOriginalYear(for displayYear: String) -> String {
        // Find the original eventYearArray value that corresponds to this display year
        for (index, eventElement) in eventYearArray.enumerated() {
            var yearChange = eventElement
            if !yearChange.isYearString {
                yearChange = NSLocalizedString("Current", comment: "")
            }
            if yearChange == displayYear {
                print("🎯 Found original year '\(eventElement)' for display year '\(displayYear)'")
                return eventElement
            }
        }
        print("🎯 Could not find original year for '\(displayYear)', defaulting to 'Current'")
        return "Current"
    }
    
    @MainActor
    private func performYearChangeWithFullLogic() async {
        print("🎯 Starting year change to: \(eventYearChangeAttempt)")
        
        // Check if task was cancelled before starting
        guard !Task.isCancelled else {
            print("🚫 Year change cancelled before starting")
            isLoadingData = false
            return
        }
        
        // STEP 1: Update year pointers IMMEDIATELY (very early in the process)
        print("🎯 STEP 1: Updating year pointers immediately for year \(eventYearChangeAttempt)")
        setArtistUrl(eventYearChangeAttempt)
        setScheduleUrl(eventYearChangeAttempt)
        writeFiltersFile()
        
        // Clear pointer cache and update global event year immediately
        cacheVariables.storePointerData = [String:String]()
        
        // CRITICAL: Update the eventYearFile FIRST to prevent reversion
        let targetEventYear = Int(getPointerUrlData(keyValue: "eventYear")) ?? 2024
        do {
            let yearString = String(targetEventYear)
            try yearString.write(toFile: eventYearFile, atomically: false, encoding: String.Encoding.utf8)
            print("🎯 Updated eventYearFile to \(yearString) BEFORE setupDefaults to prevent reversion")
        } catch {
            print("⚠️ Failed to update eventYearFile: \(error)")
        }
        
        // Now setup defaults will read the correct year
        setupCurrentYearUrls()
        setupDefaults()
        eventYear = targetEventYear
        
        print("🎯 Year pointers updated early - artistUrl: \(getArtistUrl()), scheduleUrl: \(getScheduleUrl()), eventYear: \(eventYear)")
        
        // VERIFICATION: Ensure the year hasn't been overridden
        let verifyEventYear = Int(getPointerUrlData(keyValue: "eventYear")) ?? 0
        if verifyEventYear != targetEventYear {
            print("⚠️ WARNING: Year was overridden! Expected \(targetEventYear), got \(verifyEventYear)")
            print("⚠️ Forcing year back to intended value")
            eventYear = targetEventYear
            // Re-write the file
            do {
                let yearString = String(targetEventYear)
                try yearString.write(toFile: eventYearFile, atomically: false, encoding: String.Encoding.utf8)
                print("🎯 Re-forced eventYearFile to \(yearString)")
            } catch {
                print("⚠️ Failed to re-write eventYearFile: \(error)")
            }
        } else {
            print("✅ Year verification passed: \(verifyEventYear)")
        }
        
        // Check cancellation after step 1
        guard !Task.isCancelled else {
            print("🚫 Year change cancelled after updating pointers")
            isLoadingData = false
            return
        }
        
        // STEP 2: Test internet connection
        let netTest = NetworkTesting()
        let internetAvailable = netTest.forgroundNetworkTest(callingGui: masterView)
        
        if !internetAvailable {
            print("🚫 No internet connection available, cannot switch years")
            isLoadingData = false
            showNetworkError = true
            return
        }
        
        // Check cancellation after network test
        guard !Task.isCancelled else {
            print("🚫 Year change cancelled after network test")
            isLoadingData = false
            return
        }
        
        // STEP 3: Increment request IDs to cancel ongoing requests
        PreferencesViewModel.currentLoadRequestID += 1
        PreferencesViewModel.currentBandDataRequestID += 1
        PreferencesViewModel.currentScheduleDataRequestID += 1
        let thisLoadRequestID = PreferencesViewModel.currentLoadRequestID
        
        // Remove old files
        do {
            try FileManager.default.removeItem(atPath: scheduleFile)
            try FileManager.default.removeItem(atPath: bandFile)
            try FileManager.default.removeItem(atPath: eventYearFile)
            print("🗑️ Old files removed")
        } catch {
            print("⚠️ Files were not removed: \(error)")
        }
        
        // Reset filter settings
        setMustSeeOn(true)
        setMightSeeOn(true)
        setWontSeeOn(true)
        setUnknownSeeOn(true)
        
        // Clear notifications
        let localNotification = localNoticationHandler()
        localNotification.clearNotifications()
        
        // Clear all caches (pointers already updated above)
        print("🎯 STEP 4: Clearing all caches and preparing for data refresh")
        
        // Clear static caches
        bandNamesHandler.shared.clearCachedData()
        dataHandler().clearCachedData()
        masterView.schedule.clearCache()
        
        // Clear MasterViewController's cached data arrays
        masterView.clearMasterViewCachedData()
        
        // Clear static caches to ensure fresh data
        staticSchedule.sync {
            cacheVariables.scheduleStaticCache = [:]
            cacheVariables.scheduleTimeStaticCache = [:]
            cacheVariables.bandNamesStaticCache = [:]
        }
        
        // STEP 5: Use centralized full data refresh to ensure complete data loading
        print("🎯 STEP 5: Using centralized performFullDataRefresh for comprehensive data loading")
        
        // Check cancellation before starting data refresh
        guard !Task.isCancelled else {
            print("🚫 Year change cancelled before data refresh")
            isLoadingData = false
            return
        }
        
        // Use a custom refresh approach that's cancellation-aware and immediate
        print("🎯 STEP 5: Starting immediate data refresh for year change")
        
        // Trigger immediate cache refresh on main screen (no delay)
        DispatchQueue.main.async {
            masterView.refreshBandList(reason: "Year change to \(self.eventYearChangeAttempt) - immediate cache refresh")
        }
        
        // Start background data loading immediately (no artificial delays)
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Check cancellation in background thread
                guard !Task.isCancelled else {
                    print("🚫 Year change cancelled during background data loading")
                    DispatchQueue.main.async {
                        self.isLoadingData = false
                    }
                    continuation.resume()
                    return
                }
                
                print("🎯 Starting immediate background data collection")
                
                // Clear ALL caches immediately - comprehensive clearing to prevent data mixing
                print("🧹 COMPREHENSIVE CACHE CLEARING - preventing data mixing between years")
                
                // Clear handler-specific caches
                masterView.bandNameHandle.clearCachedData()
                masterView.dataHandle.clearCachedData()
                masterView.schedule.clearCache()
                
                // Clear MasterViewController cached arrays
                masterView.clearMasterViewCachedData()
                
                // Clear ALL static cache variables that could contain year-specific data
                staticSchedule.sync {
                    cacheVariables.scheduleStaticCache = [:]
                    cacheVariables.scheduleTimeStaticCache = [:]
                    cacheVariables.bandNamesStaticCache = [:]
                    cacheVariables.bandNamesArrayStaticCache = []
                    cacheVariables.bandDescriptionUrlCache = [:]
                    cacheVariables.bandDescriptionUrlDateCache = [:]
                    cacheVariables.attendedStaticCache = [:]
                    cacheVariables.lastModifiedDate = nil
                    print("🧹 Cleared all static cache variables")
                }
                
                // Clear CustomBandDescription instance caches
                masterView.bandDescriptions.bandDescriptionUrl.removeAll()
                masterView.bandDescriptions.bandDescriptionUrlDate.removeAll()
                
                print("🧹 All caches cleared - ready for fresh \(self.eventYearChangeAttempt) data")
                
                // VERIFICATION: Log cache sizes to confirm they're cleared
                print("🔍 CACHE VERIFICATION:")
                print("🔍 - scheduleStaticCache count: \(cacheVariables.scheduleStaticCache.count)")
                print("🔍 - bandNamesStaticCache count: \(cacheVariables.bandNamesStaticCache.count)")
                print("🔍 - bandNamesArrayStaticCache count: \(cacheVariables.bandNamesArrayStaticCache.count)")
                print("🔍 - bandDescriptionUrlCache count: \(cacheVariables.bandDescriptionUrlCache.count)")
                print("🔍 - attendedStaticCache count: \(cacheVariables.attendedStaticCache.count)")
                print("🔍 - masterView.objects count: \(masterView.objects.count)")
                print("🔍 - masterView.bands count: \(masterView.bands.count)")
                
                // Use a dispatch group to track completion without artificial delays
                let dataLoadGroup = DispatchGroup()
                
                // Load iCloud data
                dataLoadGroup.enter()
                DispatchQueue.global(qos: .utility).async {
                    guard !Task.isCancelled else {
                        dataLoadGroup.leave()
                        return
                    }
                    let iCloudHandle = iCloudDataHandler()
                    iCloudHandle.readAllPriorityData()
                    iCloudHandle.readAllScheduleData()
                    dataLoadGroup.leave()
                }
                
                // Load schedule data
                dataLoadGroup.enter()
                DispatchQueue.global(qos: .utility).async {
                    guard !Task.isCancelled else {
                        dataLoadGroup.leave()
                        return
                    }
                    masterView.schedule.DownloadCsv()
                    masterView.schedule.populateSchedule(forceDownload: true)
                    dataLoadGroup.leave()
                }
                
                // Load band names data
                dataLoadGroup.enter()
                DispatchQueue.global(qos: .utility).async {
                    guard !Task.isCancelled else {
                        dataLoadGroup.leave()
                        return
                    }
                    masterView.bandNameHandle.gatherData()
                    dataLoadGroup.leave()
                }
                
                // Load descriptionMap data
                dataLoadGroup.enter()
                DispatchQueue.global(qos: .utility).async {
                    guard !Task.isCancelled else {
                        dataLoadGroup.leave()
                        return
                    }
                    masterView.bandDescriptions.getDescriptionMapFile()
                    masterView.bandDescriptions.getDescriptionMap()
                    dataLoadGroup.leave()
                }
                
                // Wait for all data to complete - NO ARTIFICIAL DELAYS
                dataLoadGroup.notify(queue: .main) {
                    print("🎯 STEP 6: All data loading completed immediately - no delays")
                    
                    // Final verification of URLs and data integrity
                    let currentArtistUrl = getArtistUrl()
                    let currentScheduleUrl = getScheduleUrl() 
                    let currentEventYear = eventYear
                    
                    print("🎯 URL Verification:")
                    print("🎯 - artistUrl: \(currentArtistUrl)")
                    print("🎯 - scheduleUrl: \(currentScheduleUrl)")  
                    print("🎯 - eventYear: \(currentEventYear)")
                    print("🎯 - target year: \(self.eventYearChangeAttempt)")
                    
                    // DATA INTEGRITY VERIFICATION: Check cache contents after loading
                    print("🔍 POST-LOAD CACHE VERIFICATION:")
                    print("🔍 - scheduleStaticCache count: \(cacheVariables.scheduleStaticCache.count)")
                    print("🔍 - bandNamesStaticCache count: \(cacheVariables.bandNamesStaticCache.count)")
                    print("🔍 - bandNamesArrayStaticCache count: \(cacheVariables.bandNamesArrayStaticCache.count)")
                    
                    // Sample a few band names to verify they're from the correct year
                    if !cacheVariables.bandNamesArrayStaticCache.isEmpty {
                        let sampleBands = Array(cacheVariables.bandNamesArrayStaticCache.prefix(3))
                        print("🔍 - Sample band names loaded: \(sampleBands)")
                    }
                    
                    // Verify schedule data contains expected year
                    if !cacheVariables.scheduleStaticCache.isEmpty {
                        let sampleScheduleKeys = Array(cacheVariables.scheduleStaticCache.keys.prefix(3))
                        print("🔍 - Sample schedule keys: \(sampleScheduleKeys)")
                    }
                    
                    print("✅ Data collection and verification completed for year change")
                    continuation.resume()
                }
            }
        }
        
        // OLD METHOD - commented out in favor of centralized approach above
        /*
        await withTaskGroup(of: Void.self) { group in
            // Band data loading
            group.addTask {
                PreferencesViewModel.currentBandDataRequestID += 1
                let thisBandRequestID = PreferencesViewModel.currentBandDataRequestID
                
                print("🎵 Starting band names data loading for year \(self.eventYearChangeAttempt) (request \(thisBandRequestID))")
                let bandNamesHandle = bandNamesHandler()
                bandNamesHandle.clearCachedData()
                
                await withCheckedContinuation { continuation in
                    bandNamesHandle.gatherData {
                        if thisBandRequestID == PreferencesViewModel.currentBandDataRequestID {
                            print("✅ Band names data loading completed for year \(self.eventYearChangeAttempt)")
                        } else {
                            print("❌ Band names data loading cancelled - outdated request")
                        }
                        continuation.resume()
                    }
                }
            }
            
            // Schedule data loading
            group.addTask {
                PreferencesViewModel.currentScheduleDataRequestID += 1
                let thisScheduleRequestID = PreferencesViewModel.currentScheduleDataRequestID
                
                print("📅 Starting schedule data loading for year \(self.eventYearChangeAttempt) (request \(thisScheduleRequestID))")
                let dataHandle = dataHandler()
                dataHandle.clearCachedData()
                dataHandle.readFile(dateWinnerPassed: "")
                masterView.schedule.clearCache()
                
                // Check if request is still current
                guard thisScheduleRequestID == PreferencesViewModel.currentScheduleDataRequestID else {
                    print("❌ Schedule data loading cancelled - outdated request")
                    return
                }
                
                // Download CSV
                masterView.schedule.DownloadCsv()
                
                // Wait for file to be written
                var attempts = 0
                while !FileManager.default.fileExists(atPath: scheduleFile) && attempts < 10 {
                    guard thisScheduleRequestID == PreferencesViewModel.currentScheduleDataRequestID else {
                        print("❌ Schedule data loading cancelled during file wait")
                        return
                    }
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                    attempts += 1
                    print("⏳ Waiting for schedule file (attempt \(attempts))")
                }
                
                // Final check before populating
                guard thisScheduleRequestID == PreferencesViewModel.currentScheduleDataRequestID else {
                    print("❌ Schedule data loading cancelled before population")
                    return
                }
                
                if FileManager.default.fileExists(atPath: scheduleFile) {
                    print("📄 Schedule file downloaded successfully, now populating")
                    masterView.schedule.populateSchedule(forceDownload: false)
                } else {
                    print("⚠️ Schedule file download failed, will retry")
                    masterView.schedule.populateSchedule(forceDownload: true)
                }
                
                print("✅ Schedule data loading completed for year \(self.eventYearChangeAttempt)")
            }
        }
        */
        
        // Check final cancellation before UI update
        guard !Task.isCancelled else {
            print("🚫 Year change cancelled before final UI update")
            await MainActor.run {
                isLoadingData = false
            }
            return
        }
        
        // STEP 7: Update UI on main thread and verify completion
        await MainActor.run {
            // Only update if this is still the latest request AND not cancelled
            guard thisLoadRequestID == PreferencesViewModel.currentLoadRequestID && !Task.isCancelled else {
                print("❌ Ignoring outdated/cancelled request \(thisLoadRequestID) vs current \(PreferencesViewModel.currentLoadRequestID), cancelled: \(Task.isCancelled)")
                isLoadingData = false
                return
            }
            
            print("🎯 STEP 7: Updating UI and finalizing year change")
            
            // Update current year setting and selected year display
            currentYearSetting = eventYearChangeAttempt
            var displayYear = eventYearChangeAttempt
            if !displayYear.isYearString {
                displayYear = NSLocalizedString("Current", comment: "")
            }
            selectedYear = displayYear
            
            // Final verification that all pointers are correct
            print("🎯 Final verification:")
            print("🎯 - currentYearSetting: \(currentYearSetting)")
            print("🎯 - selectedYear: \(selectedYear)")
            print("🎯 - eventYear: \(eventYear)")
            print("🎯 - artistUrl: \(getArtistUrl())")
            print("🎯 - scheduleUrl: \(getScheduleUrl())")
            
            // FINAL YEAR VERIFICATION: Make sure year hasn't reverted
            let finalEventYear = Int(getPointerUrlData(keyValue: "eventYear")) ?? 0
            let expectedYear = Int(eventYearChangeAttempt) ?? 0
            if finalEventYear != expectedYear {
                print("🚨 CRITICAL: Year reverted at end! Expected \(expectedYear), got \(finalEventYear)")
                print("🚨 This indicates a system conflict - check logs above")
            } else {
                print("✅ FINAL VERIFICATION PASSED: Year is correctly set to \(finalEventYear)")
            }
            
            print("✅ Year change completed to \(eventYearChangeAttempt) with verified data loading")
            
            // Handle different year types
            if eventYearChangeAttempt.isYearString && eventYearChangeAttempt != "Current" {
                // For specific years, show Band List vs Event List choice
                // Data is already fully loaded, so user can make choice immediately
                print("🎯 Year change data complete - showing Band/Event choice with all data ready")
                isLoadingData = false
                showBandEventChoice = true
            } else {
                // For "Current" year, automatically use Band List
                hideExpiredEvents = true
                setHideExpireScheduleData(true)
                
                // Ensure schedule data is loaded (same as Band/Event List choices)
                Task {
                    // Start timing to ensure minimum loading display time
                    let loadingStartTime = Date()
                    
                    await ensureScheduleDataLoaded()
                    
                    await MainActor.run {
                        // Refresh display
                        NotificationCenter.default.post(name: Notification.Name(rawValue: "RefreshDisplay"), object: nil)
                        masterView.refreshData(isUserInitiated: true)
                    }
                    
                    // Navigate immediately after data is loaded - no artificial delays
                    let loadingElapsed = Date().timeIntervalSince(loadingStartTime)
                    print("🎯 Current year: Loading took \(loadingElapsed)s, navigating immediately")
                    
                    DispatchQueue.main.async {
                        print("🎯 Current year data loaded - navigating immediately")
                        self.isLoadingData = false
                        self.navigateBackToMainScreen()
                    }
                }
            }
        }
    }
    
    /// Ensures schedule data is properly loaded - called by both Band List and Event List choices
    private func ensureScheduleDataLoaded() async {
        print("🎯 Ensuring schedule data is loaded for year \(eventYearChangeAttempt)")
        
        // Force schedule data loading (identical for both Band List and Event List)
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                // Ensure schedule data is downloaded and populated
                masterView.schedule.DownloadCsv()
                
                // Wait for schedule file to be written
                var attempts = 0
                while !FileManager.default.fileExists(atPath: scheduleFile) && attempts < 10 {
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                    attempts += 1
                    print("⏳ Waiting for schedule file (attempt \(attempts))")
                }
                
                if FileManager.default.fileExists(atPath: scheduleFile) {
                    print("📄 Schedule file available, populating schedule data")
                    masterView.schedule.populateSchedule(forceDownload: false)
                } else {
                    print("⚠️ Schedule file not found, forcing download")
                    masterView.schedule.populateSchedule(forceDownload: true)
                }
                
                print("✅ Schedule data loading completed")
            }
        }
    }

    private func navigateBackToMainScreen() {
        // Dismiss the preferences screen and return to main screen
        NotificationCenter.default.post(name: Notification.Name(rawValue: "DismissPreferencesScreen"), object: nil)
    }
}

// Extension for year validation
extension String {
    var isYearString: Bool {
        return self.range(of: "^\\d\\d\\d\\d$", options: .regularExpression) != nil
    }
}

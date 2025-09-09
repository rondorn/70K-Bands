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
    @Published var openYouTubeApp: Bool = true {
        didSet { setOpenYouTubeAppValue(openYouTubeApp) }
    }
    @Published var allLinksOpenInExternalBrowser: Bool = false {
        didSet { setAllLinksOpenInExternalBrowserValue(allLinksOpenInExternalBrowser) }
    }
    
    // Year Selection and UI State
    @Published var selectedYear: String = "Current"
    @Published var availableYears: [String] = ["Current"]
    @Published var showYearChangeConfirmation = false
    @Published var showYearChangeTimeoutWarning = false
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
        let youtubeApp = getOpenYouTubeAppValue()
        let allLinksExternal = getAllLinksOpenInExternalBrowserValue()
        
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
        openYouTubeApp = youtubeApp
        allLinksOpenInExternalBrowser = allLinksExternal
        selectedYear = displayYear
    }
    
    func refreshDataAndNotifications() {
        // Final cleanup - reset notifications
        let localNotification = localNoticationHandler()
        localNotification.clearNotifications()
        localNotification.addNotifications()
        
        // Trigger data refresh in background
        DispatchQueue.global(qos: .background).async {
            // CRITICAL: Use protected CSV download to prevent race conditions
            MasterViewController.backgroundRefreshLock.lock()
            let downloadAllowed = !MasterViewController.isCsvDownloadInProgress
            if downloadAllowed {
                MasterViewController.isCsvDownloadInProgress = true
            }
            MasterViewController.backgroundRefreshLock.unlock()
            
            if downloadAllowed {
                print("🔒 refreshDataAndNotifications: Starting protected DUAL CSV download (bands + schedule)")
                
                // CRITICAL FIX: Both operations must be protected as a single atomic unit
                // to prevent race conditions where band names import interferes with schedule import
                masterView.bandNameHandle.gatherData()
                masterView.schedule.DownloadCsv()
                masterView.schedule.populateSchedule(forceDownload: false)
                
                // Mark download as complete
                MasterViewController.backgroundRefreshLock.lock()
                MasterViewController.isCsvDownloadInProgress = false
                MasterViewController.backgroundRefreshLock.unlock()
                print("🔒 refreshDataAndNotifications: Protected DUAL CSV download completed")
            } else {
                print("🔒 refreshDataAndNotifications: ❌ DUAL CSV download blocked - already in progress")
            }
            
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
        
        // 🔧 FIX: Immediately write preferences to prevent iPad split-screen reversion
        print("🎛️ [PREFERENCES_SYNC] Writing Band List preference immediately to prevent reversion")
        writeFiltersFile()
        
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
        
        // 🔧 FIX: Immediately write preferences to prevent iPad split-screen reversion
        print("🎛️ [PREFERENCES_SYNC] Writing Event List preference immediately to prevent reversion")
        writeFiltersFile()
        
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
    
    func dismissTimeoutWarning() {
        showYearChangeTimeoutWarning = false
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
        
        // CRITICAL: Notify MasterViewController to kill all background operations
        MasterViewController.notifyYearChangeStarting()
        
        // Check if task was cancelled before starting
        guard !Task.isCancelled else {
            print("🚫 Year change cancelled before starting")
            MasterViewController.notifyYearChangeCompleted()
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
        
        // Setup URLs but do NOT call setupDefaults() during year changes (it would override eventYear)
        setupCurrentYearUrls()
        eventYear = targetEventYear
        print("🎯 Set eventYear = \(eventYear) during year change (skipped setupDefaults to avoid override)")
        
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
        print("🎯 STEP 2: Testing internet connection before year change")
        print("🎯 NOTE: This is a critical operation - using blocking network test")
        
        // Use a blocking network test specifically for year changes
        let netTest = NetworkTesting()
        
        // Perform a BLOCKING network test for year change (this is the ONLY place we allow GUI blocking)
        print("🎯 Performing BLOCKING network test for year change (will block GUI for up to 6 seconds)")
        let internetAvailable = netTest.forceFreshNetworkTestForYearChange()
        
        if !internetAvailable {
            print("🚫 ❌ NETWORK TEST FAILED - No internet connection available, cannot switch years")
            print("🚫 Network test failed - user will see 'yearChangeAborted' message")
            
            // CRITICAL: Revert year values back to previous state since network test failed
            await revertYearChangeDueToNetworkFailure()
            
            MasterViewController.notifyYearChangeCompleted()
            isLoadingData = false
            showNetworkError = true
            return
        }
        
        print("✅ ✅ NETWORK TEST PASSED - Internet connection verified - proceeding with year change")
        
        // Additional safety check: ensure masterView is initialized
        guard masterView != nil else {
            print("🚫 masterView is not initialized - cannot proceed with year change")
            
            // CRITICAL: Revert year values back to previous state since masterView is nil
            await revertYearChangeDueToNetworkFailure()
            
            MasterViewController.notifyYearChangeCompleted()
            isLoadingData = false
            showNetworkError = true
            return
        }
        
        // Check cancellation after network test and masterView check
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
        
        // CRITICAL: Clear year-specific Core Data (preserve user priorities)
        CoreDataManager.shared.clearYearSpecificData()
        
        // Clear static caches
        bandNamesHandler.shared.clearCachedData()
        // LEGACY: Priority cache clearing now handled by PriorityManager if needed
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
        print("🎯 STEP 5: Using centralized performBackgroundDataRefresh for comprehensive data loading")
        
        // Check cancellation before starting data refresh
        guard !Task.isCancelled else {
            print("🚫 Year change cancelled before data refresh")
            isLoadingData = false
            return
        }
        
        // Use the centralized data refresh method with completion handler
        print("🎯 STEP 5: Starting centralized data refresh for year change")
        
        // Create a completion handler that will signal when data refresh is complete
        let dataRefreshCompletion = { [weak self] in
            guard let self = self else { return }
            
            // Check if this year change was cancelled
            guard !Task.isCancelled else {
                print("🚫 Year change cancelled during data refresh completion")
                DispatchQueue.main.async {
                    self.isLoadingData = false
                }
                return
            }
            
            print("🎯 Centralized data refresh completed - now waiting for Core Data population")
            
            // CRITICAL FIX: Wait for Core Data to be fully populated before continuing
            // The data refresh completion only means CSV download is done, not Core Data import
            Task { @MainActor in
                await self.waitForCoreDataPopulationAndContinueYearChange()
            }
        }
        
        // Call the centralized data refresh method
        masterView.performBackgroundDataRefresh(
            reason: "Year change to \(eventYearChangeAttempt) - full data refresh",
            endRefreshControl: false,
            shouldScrollToTop: false,
            completion: dataRefreshCompletion
        )
        
        // Add timeout protection - if data refresh takes too long, dismiss anyway
        Task {
            try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 second timeout
            
            // Check if we're still loading and this year change hasn't completed
            if isLoadingData && currentYearSetting != eventYearChangeAttempt {
                print("⏰ Year change timeout reached - dismissing preference screen anyway")
                await MainActor.run {
                    isLoadingData = false
                    // Show a warning that data may be incomplete
                    showYearChangeTimeoutWarning = true
                    // Navigate back to main screen
                    navigateBackToMainScreen()
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
                // LEGACY: Priority cache clearing now handled by PriorityManager if needed
                let dataHandle = dataHandler()
                dataHandle.clearCachedData()
                dataHandle.readFile(dateWinnerPassed: "")
                masterView.schedule.clearCache()
                
                // Check if request is still current
                guard thisScheduleRequestID == PreferencesViewModel.currentScheduleDataRequestID else {
                    print("❌ Schedule data loading cancelled - outdated request")
                    return
                }
                
                // CRITICAL: Use protected CSV download to prevent race conditions
                print("🔒 performYearChangeWithFullLogic: Requesting protected CSV download")
                await self.performProtectedCsvDownload()
                
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
            print("🐛 [REVERT_DEBUG] Evaluating year type:")
            print("🐛 [REVERT_DEBUG] - eventYearChangeAttempt: '\(eventYearChangeAttempt)'")
            print("🐛 [REVERT_DEBUG] - isYearString: \(eventYearChangeAttempt.isYearString)")
            print("🐛 [REVERT_DEBUG] - != Current: \(eventYearChangeAttempt != "Current")")
            print("🐛 [REVERT_DEBUG] - Combined condition: \(eventYearChangeAttempt.isYearString && eventYearChangeAttempt != "Current")")
            
            if eventYearChangeAttempt.isYearString && eventYearChangeAttempt != "Current" {
                // For specific years, show Band List vs Event List choice
                // Data is already fully loaded, so user can make choice immediately
                print("🎯 Year change data complete - showing Band/Event choice with all data ready")
                isLoadingData = false
                showBandEventChoice = true
            } else {
                // For "Current" year - only auto-enable hideExpiredEvents if this is an actual year change TO Current
                let isActualYearChangeToCurrentBool = (currentYearSetting != eventYearChangeAttempt && eventYearChangeAttempt == "Current") || (!currentYearSetting.isYearString && eventYearChangeAttempt == "Current")
                print("🐛 [REVERT_DEBUG] Checking if this is a year change TO Current:")
                print("🐛 [REVERT_DEBUG] - currentYearSetting: '\(currentYearSetting)'")
                print("🐛 [REVERT_DEBUG] - eventYearChangeAttempt: '\(eventYearChangeAttempt)'")
                print("🐛 [REVERT_DEBUG] - isActualYearChangeToCurrentBool: \(isActualYearChangeToCurrentBool)")
                
                if isActualYearChangeToCurrentBool {
                    print("🐛 [REVERT_DEBUG] ⚠️ AUTOMATIC BAND LIST MODE TRIGGERED - This is a year change TO Current")
                    print("🐛 [REVERT_DEBUG] Current hideExpiredEvents before override: \(hideExpiredEvents)")
                    hideExpiredEvents = true
                    setHideExpireScheduleData(true)
                    print("🐛 [REVERT_DEBUG] hideExpiredEvents after override: \(hideExpiredEvents)")
                } else {
                    print("🐛 [REVERT_DEBUG] ✅ NOT a year change TO Current - preserving user preference")
                    print("🐛 [REVERT_DEBUG] User preference hideExpiredEvents: \(hideExpiredEvents)")
                }
                
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
    
    /// Reverts year change back to previous values when network test fails
    @MainActor
    private func revertYearChangeDueToNetworkFailure() async {
        print("🔄 REVERTING year change due to network failure")
        print("🔄 Reverting from attempted year: \(eventYearChangeAttempt)")
        print("🔄 Reverting back to previous year: \(currentYearSetting)")
        
        // Revert URLs and pointers back to previous year
        setArtistUrl(currentYearSetting)
        setScheduleUrl(currentYearSetting)
        writeFiltersFile()
        
        // Revert the eventYearFile back to previous year
        let previousEventYear = Int(currentYearSetting) ?? 2024
        do {
            let yearString = String(previousEventYear)
            try yearString.write(toFile: eventYearFile, atomically: false, encoding: String.Encoding.utf8)
            print("🔄 Reverted eventYearFile back to \(yearString)")
        } catch {
            print("⚠️ Failed to revert eventYearFile: \(error)")
        }
        
        // Revert global year variables
        eventYear = previousEventYear
        
        // Revert the UI display back to previous year
        var displayYear = currentYearSetting
        if !displayYear.isYearString {
            displayYear = NSLocalizedString("Current", comment: "")
        }
        selectedYear = displayYear
        
        // Re-setup defaults to ensure consistency
        setupCurrentYearUrls()
        setupDefaults()
        
        print("✅ Year change successfully reverted back to \(currentYearSetting)")
        print("🔄 UI should now show previous year: \(selectedYear)")
    }
    
    /// Ensures schedule data is properly loaded - called by both Band List and Event List choices
    private func ensureScheduleDataLoaded() async {
        print("🎯 Ensuring schedule data is loaded for year \(eventYearChangeAttempt)")
        
        // Force schedule data loading (identical for both Band List and Event List)
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                // CRITICAL: Use protected CSV download to prevent race conditions
                print("🔒 waitForCoreDataPopulation: Requesting protected CSV download")
                await self.performProtectedCsvDownload()
                
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

    /// Continues the year change process after the centralized data refresh completes
    @MainActor 
    private func waitForCoreDataPopulationAndContinueYearChange() async {
        print("🎯 STEP 5.5: Waiting for Core Data to be fully populated with new year's data")
        
        let targetYear = Int(eventYearChangeAttempt) ?? eventYear
        var attempts = 0
        let maxAttempts = 10
        let delaySeconds = 1.0
        
        while attempts < maxAttempts {
            attempts += 1
            
            // Check if this year change was cancelled
            guard !Task.isCancelled else {
                print("🚫 Year change cancelled while waiting for Core Data population")
                isLoadingData = false
                return
            }
            
            // Check Core Data for events in the target year
            let eventCount = CoreDataManager.shared.fetchEvents(forYear: Int32(targetYear)).count
            let bandCount = CoreDataManager.shared.fetchBands(forYear: Int32(targetYear)).count
            
            print("🎯 Core Data check (attempt \(attempts)/\(maxAttempts)): \(eventCount) events, \(bandCount) bands for year \(targetYear)")
            
            // We expect a reasonable number of events (more than 50 for most years)
            if eventCount > 50 && bandCount > 20 {
                print("✅ Core Data population confirmed - \(eventCount) events and \(bandCount) bands loaded")
                break
            }
            
            if attempts == maxAttempts {
                print("⚠️ Core Data population timeout - proceeding anyway with \(eventCount) events")
                break
            }
            
            print("🔄 Core Data still populating... waiting \(delaySeconds)s before next check")
            try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
        }
        
        // Additional small delay to ensure any final processing is complete
        print("🎯 Allowing additional 0.5s for final Core Data processing")
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        print("🎯 Core Data population wait complete - proceeding with year change completion")
        await continueYearChangeAfterDataRefresh()
    }
    
    @MainActor
    private func continueYearChangeAfterDataRefresh() async {
        print("🎯 STEP 6: Continuing year change after centralized data refresh completed")
        
        // Check if this year change was cancelled
        guard !Task.isCancelled else {
            print("🚫 Year change cancelled after data refresh")
            isLoadingData = false
            return
        }
        
        // STEP 7: Update UI on main thread and verify completion
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
        
        // CRITICAL: Refresh the main view to ensure all newly loaded data is displayed
        print("🔄 Triggering final main view refresh to display all loaded data")
        NotificationCenter.default.post(name: Notification.Name(rawValue: "RefreshDisplay"), object: nil)
        masterView.refreshBandList(reason: "Year change final refresh - ensure all data displayed")
        
        // CRITICAL: Notify that year change is complete
        MasterViewController.notifyYearChangeCompleted()
        
        // Handle different year types
        print("🐛 [REVERT_DEBUG] (Second location) Evaluating year type:")
        print("🐛 [REVERT_DEBUG] - eventYearChangeAttempt: '\(eventYearChangeAttempt)'")
        print("🐛 [REVERT_DEBUG] - isYearString: \(eventYearChangeAttempt.isYearString)")
        print("🐛 [REVERT_DEBUG] - != Current: \(eventYearChangeAttempt != "Current")")
        print("🐛 [REVERT_DEBUG] - Combined condition: \(eventYearChangeAttempt.isYearString && eventYearChangeAttempt != "Current")")
        
        if eventYearChangeAttempt.isYearString && eventYearChangeAttempt != "Current" {
            // For specific years, show Band List vs Event List choice
            // Data is already fully loaded, so user can make choice immediately
            print("🎯 Year change data complete - showing Band/Event choice with all data ready")
            isLoadingData = false
            showBandEventChoice = true
        } else {
            // For "Current" year - only auto-enable hideExpiredEvents if this is an actual year change TO Current
            let isActualYearChangeToCurrentBool = (currentYearSetting != eventYearChangeAttempt && eventYearChangeAttempt == "Current") || (!currentYearSetting.isYearString && eventYearChangeAttempt == "Current")
            print("🐛 [REVERT_DEBUG] (Second location) Checking if this is a year change TO Current:")
            print("🐛 [REVERT_DEBUG] - currentYearSetting: '\(currentYearSetting)'")
            print("🐛 [REVERT_DEBUG] - eventYearChangeAttempt: '\(eventYearChangeAttempt)'")
            print("🐛 [REVERT_DEBUG] - isActualYearChangeToCurrentBool: \(isActualYearChangeToCurrentBool)")
            
            if isActualYearChangeToCurrentBool {
                print("🐛 [REVERT_DEBUG] (Second location) ⚠️ AUTOMATIC BAND LIST MODE TRIGGERED - This is a year change TO Current")
                print("🐛 [REVERT_DEBUG] Current hideExpiredEvents before override: \(hideExpiredEvents)")
                hideExpiredEvents = true
                setHideExpireScheduleData(true)
                print("🐛 [REVERT_DEBUG] hideExpiredEvents after override: \(hideExpiredEvents)")
            } else {
                print("🐛 [REVERT_DEBUG] (Second location) ✅ NOT a year change TO Current - preserving user preference")
                print("🐛 [REVERT_DEBUG] User preference hideExpiredEvents: \(hideExpiredEvents)")
            }
            
            // Ensure schedule data is loaded (same as Band/Event List choices)
            Task {
                // Start timing to ensure minimum loading display time
                let loadingStartTime = Date()
                
                await ensureScheduleDataLoaded()
                
                await MainActor.run {
                    // Refresh display with comprehensive refresh
                    print("🔄 Current year: Triggering comprehensive display refresh")
                    NotificationCenter.default.post(name: Notification.Name(rawValue: "RefreshDisplay"), object: nil)
                    masterView.refreshBandList(reason: "Current year final refresh - ensure all data displayed")
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

    private func navigateBackToMainScreen() {
        // Dismiss the preferences screen and return to main screen
        // Use a different notification name to indicate year change occurred (no additional refresh needed)
        NotificationCenter.default.post(name: Notification.Name(rawValue: "DismissPreferencesScreenAfterYearChange"), object: nil)
    }
    
    /// Perform CSV download with proper race condition protection
    /// This ensures only one CSV download can happen at a time across the entire app
    private func performProtectedCsvDownload() async {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                // Use the same protection mechanism as MasterViewController
                MasterViewController.backgroundRefreshLock.lock()
                let downloadAllowed = !MasterViewController.isCsvDownloadInProgress
                if downloadAllowed {
                    MasterViewController.isCsvDownloadInProgress = true
                }
                MasterViewController.backgroundRefreshLock.unlock()
                
                if downloadAllowed {
                    print("🔒 PreferencesViewModel: Starting protected CSV download")
                    masterView.schedule.DownloadCsv()
                    
                    // Mark download as complete
                    MasterViewController.backgroundRefreshLock.lock()
                    MasterViewController.isCsvDownloadInProgress = false
                    MasterViewController.backgroundRefreshLock.unlock()
                    print("🔒 PreferencesViewModel: Protected CSV download completed")
                } else {
                    print("🔒 PreferencesViewModel: ❌ CSV download blocked - already in progress")
                }
                
                continuation.resume()
            }
        }
    }
}

// Extension for year validation
extension String {
    var isYearString: Bool {
        return self.range(of: "^\\d\\d\\d\\d$", options: .regularExpression) != nil
    }
}

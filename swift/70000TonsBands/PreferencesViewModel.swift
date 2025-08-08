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
            // Validate range 0-60
            if minutesBeforeAlert >= 0 && minutesBeforeAlert <= 60 {
                setMinBeforeAlertValue(minutesBeforeAlert)
                // Reset notifications when minutes change
                let localNotification = localNoticationHandler()
                localNotification.clearNotifications()
            } else {
                // Revert to previous valid value
                minutesBeforeAlert = getMinBeforeAlertValue()
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
    
    // MARK: - Initialization
    init() {
        setupUserInfo()
        loadAvailableYears()
        loadCurrentPreferences()
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
        
        Task {
            await performYearChangeWithFullLogic()
        }
    }
    
    func selectBandList() {
        showBandEventChoice = false
        isLoadingData = true
        
        // Force hide expired events for band list
        hideExpiredEvents = true
        setHideExpireScheduleData(true)
        
        // Refresh data and navigate back
        masterView.refreshData(isUserInitiated: true)
        
        // Navigate back after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.navigateBackToMainScreen()
        }
    }
    
    func selectEventList() {
        showBandEventChoice = false
        isLoadingData = true
        
        // Show expired events for event list
        hideExpiredEvents = false
        setHideExpireScheduleData(false)
        
        // Refresh data and navigate back
        masterView.refreshData(isUserInitiated: true)
        
        // Navigate back after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.navigateBackToMainScreen()
        }
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
        
        // Use the same logic as AlertPreferenesController
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
        
        // Test internet connection first
        let netTest = NetworkTesting()
        // Note: We can't easily pass a UIViewController from SwiftUI context
        let internetAvailable = netTest.forgroundNetworkTest(callingGui: masterView)
        
        if !internetAvailable {
            print("🚫 No internet connection available, cannot switch years")
            isLoadingData = false
            showNetworkError = true
            return
        }
        
        // Increment request IDs to cancel ongoing requests
        AlertPreferenesController.currentLoadRequestID += 1
        AlertPreferenesController.currentBandDataRequestID += 1
        AlertPreferenesController.currentScheduleDataRequestID += 1
        let thisLoadRequestID = AlertPreferenesController.currentLoadRequestID
        
        // Update URLs and clear caches
        print("🎯 Setting URLs for year \(eventYearChangeAttempt)")
        setArtistUrl(eventYearChangeAttempt)
        setScheduleUrl(eventYearChangeAttempt)
        writeFiltersFile()
        cacheVariables.storePointerData = [String:String]()
        
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
        
        // Clear all caches
        cacheVariables.storePointerData = [String:String]()
        setupCurrentYearUrls()
        setupDefaults()
        
        // Get event year after cache is cleared
        eventYear = Int(getPointerUrlData(keyValue: "eventYear"))!
        
        // Clear static caches
        bandNamesHandler().clearCachedData()
        dataHandler().clearCachedData()
        masterView.schedule.clearCache()
        
        // Clear static caches to ensure fresh data
        staticSchedule.sync {
            cacheVariables.scheduleStaticCache = [:]
            cacheVariables.scheduleTimeStaticCache = [:]
            cacheVariables.bandNamesStaticCache = [:]
        }
        
        // Load data in background
        await withTaskGroup(of: Void.self) { group in
            // Band data loading
            group.addTask {
                AlertPreferenesController.currentBandDataRequestID += 1
                let thisBandRequestID = AlertPreferenesController.currentBandDataRequestID
                
                print("🎵 Starting band names data loading for year \(self.eventYearChangeAttempt) (request \(thisBandRequestID))")
                let bandNamesHandle = bandNamesHandler()
                bandNamesHandle.clearCachedData()
                
                await withCheckedContinuation { continuation in
                    bandNamesHandle.gatherData {
                        if thisBandRequestID == AlertPreferenesController.currentBandDataRequestID {
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
                AlertPreferenesController.currentScheduleDataRequestID += 1
                let thisScheduleRequestID = AlertPreferenesController.currentScheduleDataRequestID
                
                print("📅 Starting schedule data loading for year \(self.eventYearChangeAttempt) (request \(thisScheduleRequestID))")
                let dataHandle = dataHandler()
                dataHandle.clearCachedData()
                dataHandle.readFile(dateWinnerPassed: "")
                masterView.schedule.clearCache()
                
                // Check if request is still current
                guard thisScheduleRequestID == AlertPreferenesController.currentScheduleDataRequestID else {
                    print("❌ Schedule data loading cancelled - outdated request")
                    return
                }
                
                // Download CSV
                masterView.schedule.DownloadCsv()
                
                // Wait for file to be written
                var attempts = 0
                while !FileManager.default.fileExists(atPath: scheduleFile) && attempts < 10 {
                    guard thisScheduleRequestID == AlertPreferenesController.currentScheduleDataRequestID else {
                        print("❌ Schedule data loading cancelled during file wait")
                        return
                    }
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                    attempts += 1
                    print("⏳ Waiting for schedule file (attempt \(attempts))")
                }
                
                // Final check before populating
                guard thisScheduleRequestID == AlertPreferenesController.currentScheduleDataRequestID else {
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
        
        // Update UI on main thread
        await MainActor.run {
            // Only update if this is still the latest request
            guard thisLoadRequestID == AlertPreferenesController.currentLoadRequestID else {
                print("❌ Ignoring outdated request \(thisLoadRequestID) vs current \(AlertPreferenesController.currentLoadRequestID)")
                return
            }
            
            // Update current year setting and selected year display
            currentYearSetting = eventYearChangeAttempt
            var displayYear = eventYearChangeAttempt
            if !displayYear.isYearString {
                displayYear = NSLocalizedString("Current", comment: "")
            }
            selectedYear = displayYear
            
            print("✅ Year change completed to \(eventYearChangeAttempt)")
            
            // Handle different year types
            if eventYearChangeAttempt.isYearString && eventYearChangeAttempt != "Current" {
                // For specific years, show Band List vs Event List choice
                isLoadingData = false
                showBandEventChoice = true
            } else {
                // For "Current" year, automatically use Band List
                hideExpiredEvents = true
                setHideExpireScheduleData(true)
                
                // Refresh display
                NotificationCenter.default.post(name: Notification.Name(rawValue: "RefreshDisplay"), object: nil)
                masterView.refreshData(isUserInitiated: true)
                
                // Navigate back after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    self.navigateBackToMainScreen()
                }
                
                isLoadingData = false
            }
        }
    }
    
    private func navigateBackToMainScreen() {
        // Dismiss the preferences screen and return to main screen
        NotificationCenter.default.post(name: Notification.Name(rawValue: "DismissPreferencesScreen"), object: nil)
    }
}

// Extension for year validation - using different name to avoid conflict with AlertPreferenesController
extension String {
    var isYearString: Bool {
        return self.range(of: "^\\d\\d\\d\\d$", options: .regularExpression) != nil
    }
}

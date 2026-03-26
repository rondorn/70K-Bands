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

/// Identifiable sheet item for QR scanner; used with .sheet(item:) so content is built once per presentation.
enum ScheduleQRScannerSheetItem: Identifiable {
    case scanner
    var id: String { "scheduleQRScanner" }
}

class PreferencesViewModel: ObservableObject {
    
    // Static request IDs to manage data loading
    static var currentLoadRequestID: Int = 0
    static var currentBandDataRequestID: Int = 0
    static var currentScheduleDataRequestID: Int = 0
    
    // MARK: - Published Properties
    @Published var hideExpiredEvents: Bool = false {
        didSet { 
            setHideExpireScheduleData(hideExpiredEvents)
            writeFiltersFile()  // Immediately persist to prevent reversion
        }
    }
    // Alert Preferences
    @Published var alertOnMustSee: Bool = true {
        didSet { 
            setMustSeeAlertValue(alertOnMustSee)
            writeFiltersFile()  // Immediately persist to prevent reversion
        }
    }
    @Published var alertOnMightSee: Bool = true {
        didSet { 
            setMightSeeAlertValue(alertOnMightSee)
            writeFiltersFile()  // Immediately persist to prevent reversion
        }
    }
    @Published var alertOnlyForWillAttend: Bool = false {
        didSet { 
            setOnlyAlertForAttendedValue(alertOnlyForWillAttend)
            writeFiltersFile()  // Immediately persist to prevent reversion
            LocalNotificationRebuildCoordinator.shared.requestRebuild(reason: "pref-alertOnlyForWillAttend", debounceSeconds: 0.8)
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
                writeFiltersFile()  // Immediately persist to prevent reversion
                LocalNotificationRebuildCoordinator.shared.requestRebuild(reason: "pref-minutesBeforeAlert", debounceSeconds: 0.8)
            } else {
                // Revert to previous valid value
                print("🚫 Invalid minutes value: \(minutesBeforeAlert), reverting to: \(previousValue)")
                minutesBeforeAlert = previousValue
                showValidationError = true
            }
        }
    }
    @Published var alertForShows: Bool = true {
        didSet { 
            setAlertForShowsValue(alertForShows)
            writeFiltersFile()  // Immediately persist to prevent reversion
        }
    }
    @Published var alertForSpecialEvents: Bool = true {
        didSet { 
            setAlertForSpecialValue(alertForSpecialEvents)
            writeFiltersFile()  // Immediately persist to prevent reversion
        }
    }
    @Published var alertForCruiserOrganized: Bool = false {
        didSet { 
            setAlertForUnofficalEventsValue(alertForCruiserOrganized)
            writeFiltersFile()  // Immediately persist to prevent reversion
        }
    }
    @Published var alertForMeetAndGreet: Bool = false {
        didSet { 
            setAlertForMandGValue(alertForMeetAndGreet)
            writeFiltersFile()  // Immediately persist to prevent reversion
        }
    }
    @Published var alertForClinics: Bool = false {
        didSet { 
            setAlertForClinicEvents(alertForClinics)
            writeFiltersFile()  // Immediately persist to prevent reversion
        }
    }
    @Published var alertForAlbumListening: Bool = false {
        didSet { 
            setAlertForListeningEvents(alertForAlbumListening)
            writeFiltersFile()  // Immediately persist to prevent reversion
        }
    }
    
    // Detail Screen
    @Published var noteFontSizeLarge: Bool = false {
        didSet { 
            setNotesFontSizeLargeValue(noteFontSizeLarge)
            writeFiltersFile()  // Immediately persist to prevent reversion
        }
    }
    @Published var openYouTubeApp: Bool = true {
        didSet { 
            setOpenYouTubeAppValue(openYouTubeApp)
            writeFiltersFile()  // Immediately persist to prevent reversion
        }
    }
    @Published var allLinksOpenInExternalBrowser: Bool = false {
        didSet { 
            setAllLinksOpenInExternalBrowserValue(allLinksOpenInExternalBrowser)
            writeFiltersFile()  // Immediately persist to prevent reversion
        }
    }
    
    // Year Selection and UI State
    @Published var selectedYear: String = "Current"
    @Published var availableYears: [String] = ["Current"]
    @Published var showYearChangeConfirmation = false
    @Published var showAutoChooseAttendanceWizard = false
    @Published var showReplaceAutoChoicesConfirmation = false
    @Published var showClearAllConfirmation = false
    @Published var clearAllCount = 0
    @Published var showYearChangeTimeoutWarning = false
    @Published var showBandEventChoice = false
    @Published var showNetworkError = false
    @Published var showDownloadError = false
    @Published var showValidationError = false
    @Published var isLoadingData = false
    /// Sheet item for QR scanner; use with .sheet(item:) so content is built once per presentation (avoids "already presenting" when parent re-renders).
    @Published var scheduleQRScannerSheetItem: ScheduleQRScannerSheetItem? = nil
    /// When non-nil, show an alert with the message (success or failure of QR schedule import).
    @Published var scheduleQRImportResult: (success: Bool, message: String)? = nil
    @Published var scheduleQRBandFileDownloading = false
    @Published var scheduleQRScanReadyAfterDownload = false

    // Info Display
    @Published var userId: String = ""
    @Published var buildInfo: String = ""
    
    // Advanced Preferences
    @Published var customPointerUrl: String = "" {
        didSet {
            // Only save if value actually changed to avoid unnecessary writes
            if oldValue != customPointerUrl {
                let trimmed = customPointerUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                UserDefaults.standard.set(trimmed.isEmpty ? nil : trimmed, forKey: "CustomPointerUrl")
                UserDefaults.standard.synchronize()
            }
        }
    }
    @Published var pointerUrl: String = "Production" {
        didSet {
            // Only save if value actually changed to avoid unnecessary writes
            if oldValue != pointerUrl {
                print("🔧 [POINTER_URL_CHANGE] Pointer URL changed from '\(oldValue)' to '\(pointerUrl)'")
                
                // Map display value back to Settings.bundle value
                let settingsValue = pointerUrl == "Production" ? "Prod" : pointerUrl
                UserDefaults.standard.set(settingsValue, forKey: "PointerUrl")
                UserDefaults.standard.synchronize()
                
                // Clear LastUsedPointerUrl to force getPointerUrlData to detect mismatch and clear caches
                UserDefaults.standard.removeObject(forKey: "LastUsedPointerUrl")
                UserDefaults.standard.synchronize()
                print("🔧 [POINTER_URL_CHANGE] Cleared LastUsedPointerUrl to force cache clearing")
                
                // Trigger pointer file download from new location
                // Use background queue to avoid blocking UI
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    guard let self = self else { return }
                    
                    // Ensure masterView is available
                    guard masterView != nil else {
                        print("🔧 [POINTER_URL_CHANGE] ⚠️ masterView not available, cannot download pointer file")
                        return
                    }
                    
                    print("🔧 [POINTER_URL_CHANGE] Triggering pointer file download from new location")
                    
                    // First, ensure defaultStorageUrl is set correctly by calling getPointerUrlData
                    // This will also clear caches if needed
                    _ = getPointerUrlData(keyValue: "eventYear")
                    
                    // Now download the pointer file from the new location
                    let success = masterView.downloadAndUpdatePointerFileSync()
                    
                    if success {
                        print("🔧 [POINTER_URL_CHANGE] ✅ Successfully downloaded pointer file from new location")
                        
                        // Update LastUsedPointerUrl to match what was downloaded
                        // Determine which pointer URL was actually used
                        UserDefaults.standard.synchronize()
                        let pointerUrlPref = UserDefaults.standard.string(forKey: "PointerUrl") ?? "Prod"
                        let testingSetting = "Testing"
                        let targetPointerUrl: String
                        if pointerUrlPref == testingSetting {
                            targetPointerUrl = FestivalConfig.current.defaultStorageUrlTest
                        } else {
                            targetPointerUrl = FestivalConfig.current.defaultStorageUrl
                        }
                        UserDefaults.standard.set(targetPointerUrl, forKey: "LastUsedPointerUrl")
                        UserDefaults.standard.synchronize()
                        print("🔧 [POINTER_URL_CHANGE] Updated LastUsedPointerUrl to '\(targetPointerUrl)'")
                        
                        // Post notification that pointer data was updated
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: Notification.Name("PointerDataUpdated"), object: nil)
                        }
                    } else {
                        print("🔧 [POINTER_URL_CHANGE] ⚠️ Failed to download pointer file from new location")
                    }
                }
            }
        }
    }
    @Published var pointerUrlOptions: [String] = ["Production", "Testing"]
    
    // MARK: - Private Properties
    private var eventYearArray: [String] = []
    private var eventYearChangeAttempt: String = "Current"
    private var currentYearSetting: String = "Current"
    private var currentYearChangeTask: Task<Void, Never>? = nil
    
    // MARK: - Initialization
    init() {
        setupUserInfo()
        // Show preferences UI immediately with default year; load years and prefs in background to avoid 10+ second delay when opening preferences.
        eventYearArray = ["Current"]
        availableYears = [NSLocalizedString("Current", comment: "")]
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePointerDataUpdated),
            name: Notification.Name("PointerDataUpdated"),
            object: nil
        )
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performDeferredPreferencesLoad()
        }
    }
    
    /// Runs file I/O on a background queue, then applies results and loads UserDefaults on main. Keeps preferences screen from blocking 10+ seconds on open.
    private func performDeferredPreferencesLoad() {
        let (years, displayYears) = computeAvailableYearsFromStorage()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !years.isEmpty {
                self.eventYearArray = years
                self.availableYears = displayYears
            }
            self.loadCurrentPreferences()
        }
    }
    
    /// Builds eventYearArray and availableYears from disk. Safe to call from any thread; returns values without touching self.
    private func computeAvailableYearsFromStorage() -> (eventYearArray: [String], availableYears: [String]) {
        let variableStoreHandle = variableStore()
        var eventArray: [String]
        if let yearsFromPointer = loadEventYearsFromCachedPointerFile(), !yearsFromPointer.isEmpty {
            eventArray = yearsFromPointer
            variableStoreHandle.storeDataToDisk(data: eventArray, fileName: eventYearsInfoFile)
        } else {
            eventArray = variableStoreHandle.readDataFromDiskArray(fileName: eventYearsInfoFile) ?? ["Current"]
        }
        let display = eventArray.map { elem in
            !elem.isYearString ? NSLocalizedString("Current", comment: "") : elem
        }
        return (eventArray, display)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    func loadCurrentPreferences() {
        // Temporarily disable didSet observers by loading values directly
        let hideExpired = getHideExpireScheduleData()
        // Note: promptForAttended preference removed - using long press menu instead
        
        let mustSee = getMustSeeAlertValue()
        let mightSee = getMightSeeAlertValue()
        let onlyAttended = getOnlyAlertForAttendedValue()
        let minutes = min(60, max(0, getMinBeforeAlertValue()))
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
        
        // Load advanced preferences from UserDefaults (synchronize() omitted - deprecated and can block main thread)
        let customPointerUrlValue = UserDefaults.standard.string(forKey: "CustomPointerUrl") ?? ""
        let pointerUrlValue = UserDefaults.standard.string(forKey: "PointerUrl") ?? "Prod"
        
        // Map pointer URL values (Settings.bundle uses "Prod"/"Testing", display uses "Production"/"Testing")
        let displayPointerUrl = pointerUrlValue == "Prod" ? "Production" : pointerUrlValue
        
        // Now set the values (this will trigger didSet but that's ok for initial load)
        hideExpiredEvents = hideExpired
        // Note: promptForAttended removed - using long press menu instead
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
        
        // Set advanced preferences - values will only save if they differ from defaults
        customPointerUrl = customPointerUrlValue
        pointerUrl = displayPointerUrl
    }
    
    func refreshDataAndNotifications() {
        // Preferences changes should NOT trigger fresh downloads.
        // Rule: Only foreground, pull-to-refresh, and explicit year-change should download data.
        // This method now only refreshes notifications and updates UI from cache.
        
        // Final cleanup - request a coalesced full notification rebuild
        LocalNotificationRebuildCoordinator.shared.requestRebuild(reason: "preferences-closed", debounceSeconds: 0.8)
        
        // Cache-only UI refresh (no network)
        DispatchQueue.main.async {
            masterView.refreshBandList(reason: "Preferences closed - cache-only refresh", skipDataLoading: true)
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
    
    /// Numeric year for the currently selected year (used for Auto Choose Attendance).
    var selectedYearAsInt: Int {
        selectedYear == "Current" ? eventYear : (Int(selectedYear) ?? eventYear)
    }
    
    /// Refreshes total attendance count for the selected year (Clear All button state).
    /// Runs the SQLite check on a background queue so the main thread is never blocked.
    func refreshAutoChosenDataState(completion: (() -> Void)? = nil) {
        guard FestivalConfig.current.aiSchedule else {
            clearAllCount = 0
            completion?()
            return
        }
        let year = selectedYearAsInt
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let am = AttendanceManager()
            let totalCount = am.countAllAttendance(forYear: year)
            DispatchQueue.main.async {
                self.clearAllCount = totalCount
                completion?()
            }
        }
    }
    
    /// Presents the Auto Choose Attendance wizard (triggered from preferences).
    /// If the selected year already has attendance or a prior AI run, shows a confirmation before opening the wizard.
    func triggerAutoChooseAttendanceWizard() {
        guard FestivalConfig.current.aiSchedule else { return }
        refreshAutoChosenDataState { [weak self] in
            guard let self = self else { return }
            let year = self.selectedYearAsInt
            let hasRunAIForYear = AIScheduleStorage.hasRunAI(for: year)
            if self.clearAllCount > 0 || hasRunAIForYear {
                self.showReplaceAutoChoicesConfirmation = true
            } else {
                self.showAutoChooseAttendanceWizard = true
            }
        }
    }
    
    /// User confirmed replacing an existing AI/attendance run. The wizard clears attendance when building; open it directly.
    func confirmReplaceAutoChoicesAndStartWizard() {
        showReplaceAutoChoicesConfirmation = false
        guard FestivalConfig.current.aiSchedule else { return }
        refreshAutoChosenDataState()
        NotificationCenter.default.post(name: Notification.Name("RefreshLandscapeSchedule"), object: nil)
        showAutoChooseAttendanceWizard = true
    }
    
    /// Prepares and shows confirmation to clear all attendance for the year (shows count).
    func requestClearAllAttendance() {
        guard FestivalConfig.current.aiSchedule else { return }
        clearAllCount = AttendanceManager().countAllAttendance(forYear: selectedYearAsInt)
        showClearAllConfirmation = true
    }
    
    /// User confirmed clearing all attendance. Sets every attendance record for the year to Not Attended (keeps records); sync pushes sawNone to iCloud.
    /// Also clears the "has run AI" flag and backup for this year so "Build my schedule automatically" does not show the replace confirmation.
    func confirmClearAllAttendance() {
        showClearAllConfirmation = false
        guard FestivalConfig.current.aiSchedule else { return }
        let year = selectedYearAsInt
        AttendanceManager().clearAllAttendance(forYear: year) { [weak self] in
            guard let self = self else { return }
            ShowsAttended.clearLegacyStoreForYear(year)
            AIScheduleStorage.setHasRunAI(for: year, value: false)
            AIScheduleStorage.clearBackup(year: year)
            SQLiteiCloudSync().syncAttendanceToiCloud(completion: { [weak self] in
                guard let self = self else { return }
                self.refreshAutoChosenDataState()
                NotificationCenter.default.post(name: Notification.Name("RefreshLandscapeSchedule"), object: nil)
            })
        }
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
        // IMPORTANT: Do NOT trigger fresh downloads here.
        // Year-change pipeline already downloaded/imported the selected year's data.
        masterView.refreshBandList(reason: "Year change selection: Band List (cache-only)", skipDataLoading: true)
        
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
        // IMPORTANT: Do NOT trigger fresh downloads here.
        // Year-change pipeline already downloaded/imported the selected year's data.
        masterView.refreshBandList(reason: "Year change selection: Event List (cache-only)", skipDataLoading: true)
        
        print("🎯 Event List selection complete - navigating back to main screen")
        navigateBackToMainScreen()
    }
    
    func dismissNetworkError() {
        showNetworkError = false
        isLoadingData = false
        // Reset year selection to current
        cancelYearChange()
    }
    
    func dismissDownloadError() {
        showDownloadError = false
        isLoadingData = false
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
        
        // Prefer building the list from the locally cached pointer file.
        // This ensures the year menu always reflects the pointer file contents.
        if eventYearArray.isEmpty {
            if let yearsFromPointer = loadEventYearsFromCachedPointerFile(), !yearsFromPointer.isEmpty {
                eventYearArray = yearsFromPointer
                print("🎯 Loaded event years from cached pointer file: \(eventYearArray)")
                
                // Persist for legacy callers/UI that still uses eventYearsInfoFile.
                variableStoreHandle.storeDataToDisk(data: eventYearArray, fileName: eventYearsInfoFile)
            } else {
                // Fallback: read the last saved list from disk.
                eventYearArray = variableStoreHandle.readDataFromDiskArray(fileName: eventYearsInfoFile) ?? ["Current"]
                print("🎯 eventYearsInfoFile: file is loaded \(eventYearArray)")
            }
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
    
    /// Builds the year list from the locally cached pointer file (`cachedPointerData.txt`).
    /// Pointer file is downloaded locally; the preferences UI should parse it from disk (no network).
    private func loadEventYearsFromCachedPointerFile() -> [String]? {
        let cachedPointerFile = getDocumentsDirectory().appendingPathComponent("cachedPointerData.txt")
        guard FileManager.default.fileExists(atPath: cachedPointerFile) else {
            print("🎯 cachedPointerData.txt does not exist yet - cannot build year list")
            return nil
        }
        
        let raw: String
        do {
            raw = try String(contentsOfFile: cachedPointerFile, encoding: .utf8)
        } catch {
            print("🎯 Failed to read cachedPointerData.txt: \(error)")
            return nil
        }
        
        if raw.isEmpty {
            print("🎯 cachedPointerData.txt is empty - cannot build year list")
            return nil
        }
        
        var years: [String] = []
        var seen = Set<String>()
        
        for line in raw.components(separatedBy: "\n") {
            guard line.contains("::") else { continue }
            let parts = line.components(separatedBy: "::")
            guard parts.count >= 3 else { continue }
            
            let index = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            if index.isEmpty { continue }
            
            // Skip non-year indices
            if index == "Default" || index == "lastYear" { continue }
            
            // Keep "Current" and numeric years only
            if index == "Current" || index.isYearString {
                if seen.insert(index).inserted {
                    years.append(index)
                }
            }
        }
        
        // Ensure "Current" is always first if present; otherwise insert it.
        if years.contains("Current") {
            years.removeAll(where: { $0 == "Current" })
            years.insert("Current", at: 0)
        } else {
            years.insert("Current", at: 0)
        }
        
        return years
    }
    
    @objc private func handlePointerDataUpdated() {
        print("🎯 PreferencesViewModel: PointerDataUpdated received - refreshing year list")
        DispatchQueue.main.async { [weak self] in
            self?.refreshAvailableYears()
        }
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
        // Use resolveYearToNumber to get the correct target year instead of stale pointer data
        let targetEventYear = resolveYearToNumber(eventYearChangeAttempt)
        do {
            let yearString = String(targetEventYear)
            try yearString.write(toFile: eventYearFile, atomically: false, encoding: String.Encoding.utf8)
            print("🎯 Updated eventYearFile to \(yearString) BEFORE setupDefaults to prevent reversion")
        } catch {
            print("⚠️ Failed to update eventYearFile: \(error)")
        }
        
        // Setup URLs but do NOT call setupDefaults() during year changes (it would override eventYear)
        setupCurrentYearUrls()
        let previousEventYear = eventYear
        eventYear = targetEventYear
        print("🔍 [YEAR_CHANGE_DEBUG] eventYear changed: \(previousEventYear) → \(eventYear)")
        print("🔍 [YEAR_CHANGE_DEBUG] Target year string: '\(eventYearChangeAttempt)' → resolved to: \(targetEventYear)")
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
            masterView.schedule.clearStoredScheduleChecksum()
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
        print("🔍 [YEAR_CHANGE_DEBUG] Current eventYear before clear: \(eventYear)")
        print("🔍 [YEAR_CHANGE_DEBUG] Target year (eventYearChangeAttempt): \(eventYearChangeAttempt)")
        print("🔍 [YEAR_CHANGE_DEBUG] Resolved target year: \(resolveYearToNumber(eventYearChangeAttempt))")
        
        // CRITICAL: Clear year-specific data (preserve user priorities)
        print("🔍 [YEAR_CHANGE_DEBUG] Year-specific data will be cleared when new data is imported")
        // SQLite data is cleared automatically when new data is imported
        
        // Clear static caches
        bandNamesHandler.shared.clearCachedData()
        // LEGACY: Priority cache clearing now handled by PriorityManager if needed
        dataHandler().clearCachedData()
        masterView.schedule.clearCache()
        
        // Clear MasterViewController's cached data arrays
        masterView.clearMasterViewCachedData()
        
        // Clear static caches to ensure fresh data - cacheVariables setters are thread-safe
        cacheVariables.scheduleStaticCache = [:]
        cacheVariables.scheduleTimeStaticCache = [:]
        cacheVariables.bandNamesStaticCache = [:]
        
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
            
            print("🎯 Centralized data refresh completed - data now in SQLite")
            
            // SQLite data is populated immediately during CSV import - no waiting needed
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
            let expectedYear = resolveYearToNumber(eventYearChangeAttempt)
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
            
            // REMOVED DUPLICATE CODE: This year-type handling now happens in continueYearChangeAfterDataRefresh()
            // The old code here was causing double data loads for "Current" year
            // Now we always proceed to continueYearChangeAfterDataRefresh() which handles both
            // specific years (Band/Event choice) and "Current" year (auto-dismiss with data load)
            print("🔄 [DOUBLE_LOAD_FIX] Proceeding to continueYearChangeAfterDataRefresh() for final handling")
            print("🔄 [DOUBLE_LOAD_FIX] This prevents duplicate data loading for Current year")
        }
    }
    
    /// Helper function to properly resolve year strings including "Current" to actual year numbers
    /// NEVER falls back to hardcoded years - always uses Current as ultimate fallback
    private func resolveYearToNumber(_ yearString: String) -> Int {
        print("🐛 [YEAR_DEBUG] resolveYearToNumber called with: '\(yearString)'")
        
        if yearString == "Current" || yearString == "Default" {
            // For "Current", use the pointer system to get the actual current year
            // This ensures we get 2026 even when eventYear is still 2025 during year changes
            let pointerValue = getPointerUrlData(keyValue: "eventYear")
            print("🐛 [YEAR_DEBUG] - getPointerUrlData('eventYear') returned: '\(pointerValue)'")
            
            if let currentYear = Int(pointerValue) {
                print("🐛 [YEAR_DEBUG] - resolved to year from pointer: \(currentYear)")
                return currentYear
            } else {
                // Fallback to global eventYear if pointer fails
                print("🐛 [YEAR_DEBUG] - pointer failed, using global eventYear: \(eventYear)")
                return eventYear
            }
        } else {
            // Direct numeric year - but if parsing fails, fall back to Current, not hardcoded year
            if let numericYear = Int(yearString) {
                print("🐛 [YEAR_DEBUG] - direct numeric year: \(numericYear)")
                return numericYear
            } else {
                print("⚠️ WARNING: Could not parse year '\(yearString)' - falling back to Current")
                return resolveYearToNumber("Current")
            }
        }
    }
    
    /// Reverts year change back to previous values when network test fails
    @MainActor
    private func revertYearChangeDueToNetworkFailure() async {
        print("🔄 REVERTING year change due to network failure")
        await performYearChangeRevert(reason: "network failure")
    }
    
    private func revertYearChangeDueToDownloadFailure() async {
        print("🔄 REVERTING year change due to download failure")
        await performYearChangeRevert(reason: "download failure")
    }
    
    @MainActor
    private func performYearChangeRevert(reason: String) async {
        print("🔄 REVERTING year change due to \(reason)")
        print("🔄 Reverting from attempted year: \(eventYearChangeAttempt)")
        print("🔄 Reverting back to previous year: \(currentYearSetting)")
        
        // Show error message to user
        showDownloadError = true
        
        // Revert URLs and pointers back to previous year
        setArtistUrl(currentYearSetting)
        setScheduleUrl(currentYearSetting)
        writeFiltersFile()
        
        // Revert the eventYearFile back to previous year
        let previousEventYear = resolveYearToNumber(currentYearSetting)
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
        
        // Clear caches and restore previous year's data
        print("🔄 Clearing caches and restoring previous year's data")
        
        // Clear the failed year's data from SQLite
        // SQLite data is cleared automatically when new data is imported
        
        // Trigger a refresh to reload the previous year's data
        if let masterView = masterView {
            masterView.performBackgroundDataRefresh(
                reason: "Restore previous year data after failed year change",
                endRefreshControl: false,
                shouldScrollToTop: false
            ) {
                print("🔄 Previous year data restoration completed")
            }
        }
        
        // Notify completion
        MasterViewController.notifyYearChangeCompleted()
        isLoadingData = false
        
        // Re-setup defaults to ensure consistency
        setupCurrentYearUrls()
        // IMPORTANT: Do NOT run any legacy migration as part of a year change (even on revert).
        setupDefaults(runMigrationCheck: false)
        
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
                print("🔒 [SCHEDULE_LOAD] Requesting protected CSV download")
                await self.performProtectedCsvDownload()
                
                // Wait for schedule file to be written
                var attempts = 0
                let maxFileWaitAttempts = 15 // Increased from 10
                while !FileManager.default.fileExists(atPath: scheduleFile) && attempts < maxFileWaitAttempts {
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                    attempts += 1
                    print("⏳ [SCHEDULE_LOAD] Waiting for schedule file (attempt \(attempts)/\(maxFileWaitAttempts))")
                }
                
                if FileManager.default.fileExists(atPath: scheduleFile) {
                    print("📄 [SCHEDULE_LOAD] Schedule file available, populating schedule data")
                    masterView.schedule.populateSchedule(forceDownload: false)
                } else {
                    print("⚠️ [SCHEDULE_LOAD] Schedule file not found after \(maxFileWaitAttempts) attempts, forcing download")
                    masterView.schedule.populateSchedule(forceDownload: true)
                }
                
                print("✅ [SCHEDULE_LOAD] Schedule data loading process completed")
            }
        }
    }

    /// Continues the year change process after the centralized data refresh completes
    @MainActor 
    private func waitForCoreDataPopulationAndContinueYearChange() async {
        print("🎯 STEP 5.5: Waiting for year-change completion signal before continuing")
        
        // The year-change pipeline (MasterViewController.performBackgroundDataRefresh) now:
        // - loads bands + schedule + descriptionMap
        // - marks data ready
        // - ends year-change mode
        // - calls the completion handler
        //
        // So here we only need to wait for the explicit readiness flags, without
        // repeatedly loading caches on the main thread.
        
        let timeoutSeconds: TimeInterval = 20.0
        let pollIntervalSeconds: TimeInterval = 0.2
        let start = Date()
        
        while Date().timeIntervalSince(start) < timeoutSeconds {
            guard !Task.isCancelled else {
                print("🚫 Year change cancelled while waiting for completion signal")
                isLoadingData = false
                return
            }
            
            let ready = MasterViewController.isYearChangeDataReady()
            let inProgress = MasterViewController.isYearChangeInProgress
            
            if ready && !inProgress {
                print("✅ [YEAR_CHANGE] Completion signal received (dataReady=\(ready), inProgress=\(inProgress))")
                await continueYearChangeAfterDataRefresh()
                return
            }
            
            try? await Task.sleep(nanoseconds: UInt64(pollIntervalSeconds * 1_000_000_000))
        }
        
        print("⏰ [YEAR_CHANGE] Timeout waiting for completion signal - proceeding to completion to avoid trapping user")
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
        let expectedYear = resolveYearToNumber(eventYearChangeAttempt)
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
        
        // REMOVED: Image list regeneration moved to MasterViewController's unified refresh
        // PreferencesViewModel no longer builds image list to prevent race condition
        // The performUnifiedDataRefresh() in handleReturnFromPreferencesAfterYearChange() 
        // will build the image list correctly after downloading new CSVs in Thread 3
        print("🖼️ [YEAR_CHANGE] Image list will be regenerated by MasterViewController's unified refresh")
        
        // CRITICAL: Notify that year change is complete (will be deferred if data not ready)
        // This prevents race conditions where handleReturnFromPreferencesAfterYearChange
        // tries to load data before it's ready
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
            
            // For "Current" year, data loading is handled by performInitialDataLoadAfterYearChange()
            // which is called when returning from preferences. We just need to navigate back.
            // The data refresh is already in progress from performBackgroundDataRefresh().
            print("🎯 [CURRENT_YEAR] Current year selected - data loading handled by return handler")
            isLoadingData = false
            navigateBackToMainScreen()
        }
    }

    private func navigateBackToMainScreen() {
        // Dismiss the preferences screen and return to main screen
        // Use a different notification name to indicate year change occurred (no additional refresh needed)
        NotificationCenter.default.post(name: Notification.Name(rawValue: "DismissPreferencesScreenAfterYearChange"), object: nil)
    }
    
    /// Handles scanned QR payload(s) from Vision (one or two QRs; two = top first, bottom second). Returns true to dismiss the scanner.
    func handleScannedPayload(_ payloads: [Data]) -> Bool {
        print("[QRScanner] ViewModel: handleScannedPayload called with \(payloads.count) payload(s)")
        importScheduleFromQRPayloads(payloads)
        return true
    }

    /// Import schedule from QR payloads. 1 or 2 = binary LZMA (BinaryQRScanner); 8/16/24 = plain UTF-8 chunks.
    func importScheduleFromQRPayloads(_ payloads: [Data]) {
        print("[QRScanner] ViewModel: importScheduleFromQRPayloads setting scheduleQRScannerSheetItem = nil")
        scheduleQRScannerSheetItem = nil
        let year = selectedYearAsInt
        do {
            guard !payloads.isEmpty, payloads.allSatisfy({ !$0.isEmpty }) else {
                scheduleQRImportResult = (false, "Invalid QR payload.")
                return
            }
            let csvString: String
            if payloads.count == 1 || payloads.count == 2 {
                print("[QRScan] calling decompressAndMergeOneOrTwoPayloads payloadCount=\(payloads.count)")
                csvString = try decompressAndMergeOneOrTwoPayloads(payloads, eventYear: year)
            } else if payloads.count == 8 || payloads.count == 16 || payloads.count == 24 {
                csvString = try mergePlainUTF8SchedulePayloads(payloads, eventYear: year)
            } else {
                scheduleQRImportResult = (false, NSLocalizedString("Scan 1 or 2 schedule QR codes (binary), or 8/16/24 (plain).", comment: "QR import wrong count"))
                return
            }
            // Band list is never modified by QR/schedule import; it comes only from band file. Decode uses this device's canonical list; sender and receiver must match.
            let currentCsvContent = try? String(contentsOfFile: scheduleFile, encoding: .utf8)
            let (validationSuccess, validationExample) = validateScheduleQRImport(currentCsvContent: currentCsvContent, newCsvContent: csvString)
            if !validationSuccess {
                let detail = validationExample ?? NSLocalizedString("QR import validation failed", comment: "Fallback when no example")
                let formatStr = NSLocalizedString("QR import validation failed", comment: "Validation failed message with example")
                let message = (formatStr as NSString).contains("%@") ? String(format: formatStr, detail) : "\(formatStr)\n\n\(detail)"
                print("[QRImport] Validation failed: \(detail)")
                scheduleQRImportResult = (false, message)
                return
            }

            // Preserve Unofficial Event and Cruiser Organized from existing schedule (QR payload excludes them to reduce size)
            let preserved = DataManager.shared.fetchEvents(forYear: year).filter { event in
                let t = event.eventType ?? ""
                return t == "Unofficial Event" || t == "Cruiser Organized"
            }
            let ok = masterView.schedule.importScheduleFromCSVString(csvString)
            if ok, !preserved.isEmpty {
                for event in preserved {
                    _ = DataManager.shared.createOrUpdateEvent(
                        bandName: event.bandName,
                        timeIndex: event.timeIndex,
                        endTimeIndex: event.endTimeIndex,
                        location: event.location,
                        date: event.date,
                        day: event.day,
                        startTime: event.startTime,
                        endTime: event.endTime,
                        eventType: event.eventType,
                        eventYear: event.eventYear,
                        notes: event.notes,
                        descriptionUrl: event.descriptionUrl,
                        eventImageUrl: event.eventImageUrl
                    )
                }
            }
            if ok {
                // So populateSchedule(forceDownload: true) won’t skip import when network file later differs
                masterView.schedule.updateStoredScheduleChecksum(toMatchCSV: csvString)
            }
            scheduleQRImportResult = (
                ok,
                ok ? NSLocalizedString("Schedule imported successfully.", comment: "QR schedule import success")
                   : NSLocalizedString("Schedule import failed.", comment: "QR schedule import failure")
            )
            if ok {
                masterView.refreshBandList(reason: "Schedule imported from QR", skipDataLoading: true)
            }
        } catch {
            print("[QRImport] Merge/import failed: \(error)")
            scheduleQRImportResult = (false, error.localizedDescription)
        }
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
                    print("🧵 [OPTION_D] Year change detected - forcing main thread import for safety")
                    print("🧵 [OPTION_D] User will see loading indicator on preferences screen")
                    masterView.schedule.DownloadCsv(forceMainThread: true)
                    
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

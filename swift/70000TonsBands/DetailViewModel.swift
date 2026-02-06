//
//  DetailViewModel.swift
//  70K Bands
//
//  Created by Assistant on 1/14/25.
//  Copyright (c) 2025 Ron Dorn. All rights reserved.
//

import Foundation
import SwiftUI
import Translation
import UIKit
import WebKit

// MARK: - Toast Manager

class ToastManager: ObservableObject {
    @Published var isShowing = false
    @Published var message = ""
    @Published var placeHigh = false
    
    func show(message: String, placeHigh: Bool = false) {
        print("DEBUG: ToastManager.show() called with message: '\(message)', placeHigh: \(placeHigh)")
        
        // Ensure UI updates happen on main thread
        DispatchQueue.main.async {
            self.message = message
            self.placeHigh = placeHigh
            
            print("DEBUG: Setting isShowing to true on main thread")
            withAnimation(.easeIn(duration: 0.3)) {
                self.isShowing = true
            }
            print("DEBUG: isShowing is now: \(self.isShowing)")
        }
    }
}

// MARK: - Data Models

struct ScheduleEvent: Identifiable {
    let id = UUID()
    let location: String
    let eventType: String
    let startTime: String
    let endTime: String
    let day: String
    let notes: String
    let venueColor: Color
    let attendedIcon: UIImage
    let eventTypeIcon: UIImage
    let timeIndex: TimeInterval
    
    // Additional properties for event handling
    let bandName: String
    let rawStartTime: String
    let originalEventType: String  // Original eventType for attendance tracking
    let rawLocation: String  // Original location without venue suffix for attendance tracking
    let imageUrl: String  // Image URL for this event (from schedule)
    let imageDate: String  // Image date for cache invalidation (from schedule)
}

// MARK: - DetailViewModel

class DetailViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var bandName: String
    @Published var bandImage: UIImage?
    @Published var isLoadingImage: Bool = false
    @Published var customNotes: String = ""
    @Published var isEditingNotes: Bool = false
    @Published var selectedPriority: Int = 0 {
        didSet {
            // Only save if we're not currently loading data
            if !isLoadingPriority {
                savePriority()
            }
        }
    }
    
    // Band details
    @Published var country: String = ""
    @Published var genre: String = ""
    @Published var lastOnCruise: String = ""
    @Published var noteWorthy: String = ""
    
    // Links
    @Published var officialUrl: String = ""
    @Published var wikipediaUrl: String = ""
    @Published var youtubeUrl: String = ""
    @Published var metalArchivesUrl: String = ""
    
    // Schedule events
    @Published var scheduleEvents: [ScheduleEvent] = []
    
    // Translation
    @Published var showTranslationButton: Bool = false
    @Published var isCurrentTextTranslated: Bool = false
    @Published var translateButtonText: String = ""
    @Published var restoreButtonText: String = ""
    
    // Store reference to prevent deallocation of translation controller
    private var currentTranslationController: Any?
    
    // Store reference to prevent deallocation of image handler during async downloads
    private var imageHandle: imageHandler = imageHandler()
    
    // Notes editing
    @Published var isNotesEditable: Bool = true
    
    // Navigation
    @Published var canNavigatePrevious: Bool = false
    @Published var canNavigateNext: Bool = false
    
    // Toast messaging
    @Published var toastManager = ToastManager()
    
    // Loading state for missing essential data
    @Published var isLoadingEssentialData: Bool = false
    
    // Swipe navigation state
    private var blockSwiping: Bool = false
    
    // Computed properties
    var hasAnyLinks: Bool {
        !officialUrl.isEmpty || !wikipediaUrl.isEmpty || !youtubeUrl.isEmpty || !metalArchivesUrl.isEmpty
    }
    
    var hasBandDetails: Bool {
        !country.isEmpty || !genre.isEmpty || !lastOnCruise.isEmpty || !noteWorthy.isEmpty
    }
    
    // Detects if essential data is missing (only for bands that should have this data)
    var isEssentialDataMissing: Bool {
        // Don't show loading if we're in landscape mode on iPhone - data is intentionally hidden
        let isLandscapeOnPhone = UIApplication.shared.statusBarOrientation != .portrait && UIDevice.current.userInterfaceIdiom != .pad
        if isLandscapeOnPhone {
            return false // Don't show loading in landscape - data is intentionally hidden
        }
        
        // Check if this is a single-event band (likely won't have full profile data)
        let eventCount = scheduleEvents.count
        let isSingleEventBand = eventCount == 1
        
        if isSingleEventBand {
            print("DEBUG: Single-event band '\(bandName)' with \(eventCount) event - skipping loading (profile data not expected)")
            return false // Don't show loading for single-event bands - they often don't have profile data
        }
        
        // Also check if we have events but no profile data - this could indicate a band that legitimately has no profile
        let hasEvents = eventCount > 0
        let hasNoProfileData = !hasAnyLinks && !hasBandDetails
        
        if hasEvents && hasNoProfileData && eventCount <= 2 {
            print("DEBUG: Band '\(bandName)' has \(eventCount) events but no profile data - likely doesn't have full band info")
            return false // Don't show loading for bands with few events and no existing profile data
        }
        
        // Only consider data missing if we have no links AND no band details AND not currently loading
        // This prevents showing loading for bands that legitimately don't have this data
        let missing = !hasAnyLinks && !hasBandDetails && !isLoadingEssentialData
        
        if missing {
            print("DEBUG: isEssentialDataMissing=true for '\(bandName)' (events: \(eventCount)) - hasAnyLinks: \(hasAnyLinks), hasBandDetails: \(hasBandDetails), isLoadingEssentialData: \(isLoadingEssentialData)")
        }
        
        return missing
    }
    
    var priorityImageName: String {
        return getPriorityGraphic(selectedPriority)
    }
    
    var noteFontSizeLarge: Bool {
        return getNotesFontSizeLargeValue()
    }
    
    // MARK: - Private Properties
    // LEGACY: dataHandler kept for compatibility but no longer used for priorities
    private let dataHandle = dataHandler()
    private let bandNameHandle = bandNamesHandler.shared
    private let schedule = scheduleHandler.shared
    private let attendedHandle = ShowsAttended()
    private let bandNotes = CustomBandDescription()

    private var englishDescriptionText: String = ""
    @Published var doNotSaveText: Bool = false
    
    // Track original priority to prevent unwanted saves
    private var originalPriority: Int? = nil
    
    // Flag to prevent didSet from triggering during data loading
    private var isLoadingPriority: Bool = false
    
    // Directory path for saving custom notes
    private var directoryPath: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath
    }
    
    // Add change tracking to avoid unnecessary saves
    private var originalNotes: String = ""
    private var hasNotesChanged: Bool = false
    
    // MARK: - Initialization
    
    init(bandName: String) {
        
        self.bandName = bandName
        loadBandData()
        
        // Listen for force refresh notifications
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ForceDetailRefresh"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let notificationBandName = userInfo["bandName"] as? String,
                  notificationBandName == self.bandName else { return }
            
            print("🔄 DetailViewModel received force refresh notification for band: \(notificationBandName)")
            print("🔄 DetailViewModel - current band: \(self.bandName), notification band: \(notificationBandName)")
            self.loadBandData()
        }
        
        // Listen for iCloud/remote data loading completion
        NotificationCenter.default.addObserver(
            forName: Notification.Name("RefreshDisplay"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            
            // If we're currently showing loading indicator, check if data is now available
            if self.isLoadingEssentialData {
                print("🔄 Received RefreshDisplay notification while loading data for '\(self.bandName)'")
                self.checkForDataAfterRefresh()
            }
        }
        
        // Listen for band names cache ready (more specific and faster than RefreshDisplay)
        NotificationCenter.default.addObserver(
            forName: .bandNamesCacheReady,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            
            // If we're currently showing loading indicator, check if data is now available
            if self.isLoadingEssentialData {
                print("🔄 Received bandNamesCacheReady notification while loading data for '\(self.bandName)'")
                self.checkForDataAfterRefresh()
            }
        }
        
        // Listen for image list updates to refresh band images when async generation completes
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ImageListUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            
            // Loop protection:
            // Only react if the image list now actually contains an entry for THIS band.
            // If the list is empty or doesn't contain this band, do nothing (prevents reload loops).
            let list = CombinedImageListHandler.shared.combinedImageList
            guard let _ = list[self.bandName] else {
                print("🖼️ DetailViewModel: ImageListUpdated received but no entry for '\(self.bandName)' (listCount=\(list.count)) - skipping reload")
                return
            }
            
            print("🖼️ DetailViewModel: Image list updated (has entry) - reloading band image for '\(self.bandName)'")
            self.loadBandImage()
        }
        
        // Listen for band description updates to refresh the display when new content is downloaded
        NotificationCenter.default.addObserver(
            forName: Notification.Name("BandDescriptionUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let notificationBandName = userInfo["bandName"] as? String,
                  notificationBandName == self.bandName else { return }
            
            print("📝 DetailViewModel received BandDescriptionUpdated notification for band: \(notificationBandName)")
            print("📝 DetailViewModel - current band: \(self.bandName), notification band: \(notificationBandName)")
            self.refreshBandDescription()
        }
        
        // Listen for description map ready to refresh band descriptions when the map becomes available
        NotificationCenter.default.addObserver(
            forName: Notification.Name("DescriptionMapReady"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            
            print("📝 DetailViewModel received DescriptionMapReady notification, refreshing band description for '\(self.bandName)'")
            self.refreshBandDescription()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .bandNamesCacheReady, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("ImageListUpdated"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("BandDescriptionUpdated"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("DescriptionMapReady"), object: nil)
    }
    
    // MARK: - Public Methods
    
    func loadBandData() {
        print("DEBUG: loadBandData() called for band: '\(bandName)'")
        
        // Ensure we're on the main thread for UI updates
        DispatchQueue.main.async {
            // IMPORTANT: Load schedule events BEFORE image so we have imageDate available
            self.loadScheduleEvents()
            self.loadBandImage()
            self.loadBandDetails()
            self.loadBandLinks()
            self.loadNotes()
            self.loadPriority()
            self.setupTranslationButton()
            self.updateNavigationState()
            
            // Check if essential data is still missing after initial load
            self.checkAndHandleMissingData()
            
            print("DEBUG: loadBandData() completed for band: '\(self.bandName)'")
        }
    }
    
    private func checkAndHandleMissingData() {
        print("DEBUG: checkAndHandleMissingData for '\(bandName)' - hasAnyLinks: \(hasAnyLinks), hasBandDetails: \(hasBandDetails)")
        print("DEBUG: Current data state - country: '\(country)', genre: '\(genre)', lastOnCruise: '\(lastOnCruise)'")
        print("DEBUG: Current links - official: '\(officialUrl)', wikipedia: '\(wikipediaUrl)', youtube: '\(youtubeUrl)', metalArchives: '\(metalArchivesUrl)'")
        
        if isEssentialDataMissing {
            print("DEBUG: ⚠️ Essential data missing for '\(bandName)', starting loading indicator and retry")
            isLoadingEssentialData = true
            
            // Retry loading data after a delay to allow background data loading to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.retryLoadingEssentialData()
            }
        } else {
            print("DEBUG: ✅ Essential data present for '\(bandName)', no loading needed")
        }
    }
    
    private func retryLoadingEssentialData() {
        print("DEBUG: 🔄 First retry loading essential data for '\(bandName)'")
        print("DEBUG: Before retry - country: '\(country)', genre: '\(genre)', lastOnCruise: '\(lastOnCruise)'")
        print("DEBUG: Before retry - links: official='\(officialUrl)', wiki='\(wikipediaUrl)', youtube='\(youtubeUrl)', metal='\(metalArchivesUrl)'")
        
        // First check if the bandNames dictionary has been populated at all
        let bandNamesCount = bandNameHandle.getBandNames().count
        print("DEBUG: BandNames dictionary contains \(bandNamesCount) bands")
        
        if bandNamesCount == 0 {
            print("DEBUG: ⚠️ BandNames dictionary is empty - data still loading from background")
            // Don't bother checking individual band data if the entire dictionary is empty
            // Continue retry - data is still loading
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.finalRetryLoadingEssentialData()
            }
            return
        }
        
        // Check if the underlying data source is available for this specific band
        let testCountry = bandNameHandle.getBandCountry(bandName)
        let testGenre = bandNameHandle.getBandGenre(bandName)
        let testPriorYears = bandNameHandle.getPriorYears(bandName)
        let testOfficial = bandNameHandle.getofficalPage(bandName)
        let testWiki = bandNameHandle.getWikipediaPage(bandName)
        let testYoutube = bandNameHandle.getYouTubePage(bandName)
        let testMetal = bandNameHandle.getMetalArchives(bandName)
        
        print("DEBUG: Direct data source check - country: '\(testCountry)', genre: '\(testGenre)', priorYears: '\(testPriorYears)'")
        print("DEBUG: Direct links check - official: '\(testOfficial)', wiki: '\(testWiki)', youtube: '\(testYoutube)', metal: '\(testMetal)'")
        
        // Check if data source has any data at all for this band
        let hasAnySourceData = !testCountry.isEmpty || !testGenre.isEmpty || !testPriorYears.isEmpty || 
                               !testOfficial.isEmpty || !testWiki.isEmpty || !testYoutube.isEmpty || !testMetal.isEmpty
        print("DEBUG: Data source has any data for '\(bandName)': \(hasAnySourceData)")
        
        // Reload the essential data
        loadBandDetails()
        loadBandLinks()
        
        print("DEBUG: After retry - country: '\(country)', genre: '\(genre)', lastOnCruise: '\(lastOnCruise)'")
        print("DEBUG: After retry - links: official='\(officialUrl)', wiki='\(wikipediaUrl)', youtube='\(youtubeUrl)', metal='\(metalArchivesUrl)'")
        
        // Check if we now have data
        if hasAnyLinks || hasBandDetails {
            print("DEBUG: ✅ Essential data loaded successfully on first retry for '\(bandName)'")
            isLoadingEssentialData = false
        } else if !hasAnySourceData {
            print("DEBUG: ❌ No source data available for '\(bandName)' - stopping loading (band may not exist in database)")
            isLoadingEssentialData = false
        } else {
            print("DEBUG: ⚠️ Source has data but first retry failed, scheduling final retry for '\(bandName)'")
            // Try one more time after a longer delay to give more time for data loading
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                self.finalRetryLoadingEssentialData()
            }
        }
    }
    
    private func finalRetryLoadingEssentialData() {
        print("DEBUG: 🔄 Final retry to load essential data for '\(bandName)'")
        
        // First check if the bandNames dictionary has been populated at all
        let bandNamesCount = bandNameHandle.getBandNames().count
        print("DEBUG: Final retry - BandNames dictionary contains \(bandNamesCount) bands")
        
        if bandNamesCount == 0 {
            print("DEBUG: ❌ BandNames dictionary still empty on final retry - background loading may have failed")
            isLoadingEssentialData = false
            return
        }
        
        // Check data source for this specific band
        let testCountry = bandNameHandle.getBandCountry(bandName)
        let testGenre = bandNameHandle.getBandGenre(bandName)
        let testPriorYears = bandNameHandle.getPriorYears(bandName)
        let testOfficial = bandNameHandle.getofficalPage(bandName)
        let testWiki = bandNameHandle.getWikipediaPage(bandName)
        let testYoutube = bandNameHandle.getYouTubePage(bandName)
        let testMetal = bandNameHandle.getMetalArchives(bandName)
        
        print("DEBUG: Final retry - direct source check: country='\(testCountry)', genre='\(testGenre)', priorYears='\(testPriorYears)'")
        print("DEBUG: Final retry - direct links check: official='\(testOfficial)', wiki='\(testWiki)', youtube='\(testYoutube)', metal='\(testMetal)'")
        
        let hasAnySourceData = !testCountry.isEmpty || !testGenre.isEmpty || !testPriorYears.isEmpty || 
                               !testOfficial.isEmpty || !testWiki.isEmpty || !testYoutube.isEmpty || !testMetal.isEmpty
        print("DEBUG: Final retry - data source has any data for '\(bandName)': \(hasAnySourceData)")
        
        // Final attempt to load data
        loadBandDetails()
        loadBandLinks()
        
        print("DEBUG: Final retry results - country: '\(country)', genre: '\(genre)', lastOnCruise: '\(lastOnCruise)'")
        print("DEBUG: Final retry results - links: official='\(officialUrl)', wiki='\(wikipediaUrl)', youtube='\(youtubeUrl)', metal='\(metalArchivesUrl)'")
        
        if hasAnyLinks || hasBandDetails {
            print("DEBUG: ✅ Essential data loaded on final retry for '\(bandName)'")
        } else if !hasAnySourceData {
            print("DEBUG: ❌ No source data available for '\(bandName)' - band may not exist in database")
        } else {
            print("DEBUG: ❌ Source has data but final retry failed for '\(bandName)' - possible loading issue")
        }
        
        // Stop loading regardless of outcome
        isLoadingEssentialData = false
    }
    
    private func checkForDataAfterRefresh() {
        print("DEBUG: 🔔 Checking for data after refresh notification for '\(bandName)'")
        
        // Check if the bandNames dictionary is now populated
        let bandNamesCount = bandNameHandle.getBandNames().count
        print("DEBUG: After notification - BandNames dictionary contains \(bandNamesCount) bands")
        
        if bandNamesCount == 0 {
            print("DEBUG: ⚠️ BandNames dictionary still empty after notification - waiting longer")
            return // Keep loading indicator, data still not ready
        }
        
        // Check data source directly first
        let testCountry = bandNameHandle.getBandCountry(bandName)
        let testGenre = bandNameHandle.getBandGenre(bandName)
        let testPriorYears = bandNameHandle.getPriorYears(bandName)
        let testOfficial = bandNameHandle.getofficalPage(bandName)
        
        print("DEBUG: After notification - direct source check: country='\(testCountry)', genre='\(testGenre)', priorYears='\(testPriorYears)', official='\(testOfficial)'")
        
        // Reload the essential data
        loadBandDetails()
        loadBandLinks()
        
        print("DEBUG: After notification reload - country: '\(country)', genre: '\(genre)', lastOnCruise: '\(lastOnCruise)'")
        print("DEBUG: After notification reload - links: official='\(officialUrl)', wiki='\(wikipediaUrl)', youtube='\(youtubeUrl)', metal='\(metalArchivesUrl)'")
        
        // Check if we now have data
        if hasAnyLinks || hasBandDetails {
            print("DEBUG: ✅ Essential data loaded after refresh notification for '\(bandName)'")
            isLoadingEssentialData = false
        } else {
            print("DEBUG: ⚠️ Data still missing after refresh notification for '\(bandName)'")
        }
    }
    
    func navigateToPrevious() {
        print("DEBUG: navigateToPrevious() called")
        swipeToNextRecord(direction: "Previous")
    }
    
    func navigateToNext() {
        print("DEBUG: navigateToNext() called") 
        swipeToNextRecord(direction: "Next")
    }
    
    // MARK: - Boundary Checking
    
    func isAtStart() -> Bool {
        return !canNavigateToPrevious()
    }
    
    func isAtEnd() -> Bool {
        return !canNavigateToNext()
    }
    
    private func canNavigateToPrevious() -> Bool {
        let currentIndex = findCurrentBandIndex()
        return currentIndex > 0
    }
    
    private func canNavigateToNext() -> Bool {
        let currentIndex = findCurrentBandIndex()
        let totalBands = currentBandList.count
        return currentIndex < totalBands - 1
    }
    
    private func findCurrentBandIndex() -> Int {
        for (index, bandIndex) in currentBandList.enumerated() {
            let bandFromIndex = getBandFromIndex(index: bandIndex)
            let bandNameFromIndex = bandNameFromIndex(index: bandFromIndex)
            if bandNameFromIndex == bandName {
                return index
            }
        }
        return -1
    }
    
    func toggleAttendedStatus(for event: ScheduleEvent) {
        print("DEBUG: toggleAttendedStatus called for band: \(event.bandName), location: \(event.location), rawLocation: \(event.rawLocation), startTime: \(event.rawStartTime), eventType: \(event.eventType), originalEventType: \(event.originalEventType)")
        
        // Use rawLocation (without venue suffix) for attendance tracking, like the original code
        let locationForAttendance = event.rawLocation
        
        // Get current status before change
        let currentStatus = attendedHandle.getShowAttendedStatus(
            band: event.bandName,
            location: locationForAttendance,
            startTime: event.rawStartTime,
            eventType: event.originalEventType,
            eventYearString: String(eventYear)
        )
        print("DEBUG: Current status before change: \(currentStatus)")
        
        // Toggle the status - log the exact parameters being sent
        let indexString = "\(event.bandName):\(locationForAttendance):\(event.rawStartTime):\(event.originalEventType):\(String(eventYear))"
        print("DEBUG: Calling addShowsAttended with index: '\(indexString)'")
        print("DEBUG: Parameters - band: '\(event.bandName)', location: '\(locationForAttendance)', startTime: '\(event.rawStartTime)', eventType: '\(event.originalEventType)', year: '\(String(eventYear))'")
        
        let newStatus = attendedHandle.addShowsAttended(
            band: event.bandName,
            location: locationForAttendance,
            startTime: event.rawStartTime,
            eventType: event.originalEventType,  // Use original eventType to avoid empty strings
            eventYearString: String(eventYear)
        )
        print("DEBUG: New status after toggle: \(newStatus)")
        
        // Wait a moment for async operations to complete, then verify
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let verifyStatus = self.attendedHandle.getShowAttendedStatus(
                band: event.bandName,
                location: locationForAttendance,
                startTime: event.rawStartTime,
                eventType: event.originalEventType,
                eventYearString: String(eventYear)
            )
            print("DEBUG: Verified status after save (delayed): \(verifyStatus)")
            
            // If status didn't change, there's a problem with the save
            if verifyStatus == currentStatus {
                print("DEBUG: ERROR - Status did not change! Save failed.")
                print("DEBUG: Expected: \(newStatus), Got: \(verifyStatus)")
            } else {
                print("DEBUG: SUCCESS - Status changed from \(currentStatus) to \(verifyStatus)")
            }
        }
        
        // Get user-friendly message
        let empty = UITextField()
        let message = attendedHandle.setShowsAttendedStatus(empty, status: newStatus)
        print("DEBUG: Toast message: \(message)")
        
        // Show toast message
        showToast(message: message)
        
        // Force refresh the schedule events to update icons immediately
        DispatchQueue.main.async {
            // Reload the band data to get fresh attendance status
            self.loadBandData()
        }
        
        // Post targeted notification for UI refresh (avoid full data reload)
        NotificationCenter.default.post(name: Notification.Name("DetailDidUpdate"), object: nil)
        // Only post RefreshDisplay if we're not just updating attendance status
        // NotificationCenter.default.post(name: Notification.Name(rawValue: "RefreshDisplay"), object: nil)
        
        print("DEBUG: toggleAttendedStatus completed successfully")
    }
    
    func translateText() {
        // Only allow translation if fully supported
        if #available(iOS 18.0, *) {
            guard BandDescriptionTranslator.shared.isTranslationSupported() else { 
                print("DEBUG: Translation not supported - ignoring translate request")
                return 
            }
            
            print("DEBUG: Starting SwiftUI translation helper for band: \(bandName)")
            
            let currentLangCode = BandDescriptionTranslator.shared.getCurrentLanguageCode()
            let textToTranslate = englishDescriptionText
            
            // Show localized loading toast
            let translatingMessage = BandDescriptionTranslator.shared.getTranslatingMessage(for: currentLangCode)
            toastManager.show(message: translatingMessage, placeHigh: false)
            
            // Use the master branch SwiftUI translation helper approach
            showSwiftUITranslationHelper(text: textToTranslate, targetLanguage: currentLangCode)
        } else {
            print("DEBUG: Translation not supported - iOS version < 18.0")
        }
    }
    
    @available(iOS 18.0, *)
    private func showSwiftUITranslationHelper(text: String, targetLanguage: String) {
        guard !text.isEmpty else {
            print("DEBUG: No text to translate")
            let currentLangCode = BandDescriptionTranslator.shared.getCurrentLanguageCode()
            let noTextMessage = BandDescriptionTranslator.shared.getTranslationFailedMessage(for: currentLangCode)
            toastManager.show(message: noTextMessage, placeHigh: false)
            return
        }
        
        print("DEBUG: Creating SwiftUI translation helper for band: \(bandName), target language: \(targetLanguage)")
        print("DEBUG: Text to translate length: \(text.count)")
        
        // Create the hidden SwiftUI translation helper using the UIHostingController directly
        let translationHelper = SwiftUITranslationHelper(
            sourceText: text,
            bandName: bandName,
            targetLanguage: targetLanguage
        ) { [weak self] success in
            print("DEBUG: Translation completion callback called with success: \(success)")
            DispatchQueue.main.async {
                if success {
                    print("DEBUG: Translation succeeded, loading from disk...")
                    // Load the translated text from disk and update UI
                    self?.loadTranslatedTextFromDisk(targetLanguage: targetLanguage)
                    
                    // Show localized success message
                    let successMessage = BandDescriptionTranslator.shared.getTranslatedSuccessMessage(for: targetLanguage)
                    self?.toastManager.show(message: successMessage, placeHigh: false)
                } else {
                    print("DEBUG: Translation failed")
                    // Show localized failure message
                    let failureMessage = BandDescriptionTranslator.shared.getTranslationFailedMessage(for: targetLanguage)
                    self?.toastManager.show(message: failureMessage, placeHigh: false)
                }
            }
        }
        
        // Create hosting controller and make it visible but tiny to ensure SwiftUI lifecycle
        let hostingController = UIHostingController(rootView: translationHelper)
        hostingController.view.backgroundColor = .clear
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        hostingController.view.alpha = 0.01 // Almost invisible but still rendered
        
        print("DEBUG: Created SwiftUI translation hosting controller for \(bandName)")
        
        // Try to add it to a window to ensure proper SwiftUI lifecycle
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.addSubview(hostingController.view)
            print("DEBUG: Added translation helper to window")
        }
        
        // Store reference to prevent deallocation
        self.currentTranslationController = hostingController
        
        print("DEBUG: Translation helper setup complete, waiting for translation to finish...")
        
        // Remove after a delay to allow translation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            print("DEBUG: Cleaning up translation controller after 30 seconds")
            if let controller = self?.currentTranslationController as? UIHostingController<SwiftUITranslationHelper> {
                controller.view.removeFromSuperview()
            }
            self?.currentTranslationController = nil
        }
    }
    

    
    @available(iOS 18.0, *)
    private func loadTranslatedTextFromDisk(targetLanguage: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Get the documents directory
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                
                // Create filename for translated text
                let normalizedBandName = BandDescriptionTranslator.shared.normalizeBandName(self.bandName)
                let fileName = "\(normalizedBandName)_comment.note-translated-\(targetLanguage.uppercased())"
                let fileURL = documentsPath.appendingPathComponent(fileName)
                
                // Load from disk
                let translatedText = try String(contentsOf: fileURL, encoding: .utf8)
                
                DispatchQueue.main.async {
                    // Update the text
                    self.customNotes = translatedText
                    
                    // Set user preference to show they want translated version for this band
                    BandDescriptionTranslator.shared.setUserPreferredLanguage(for: self.bandName, languageCode: targetLanguage)
                    
                    // Update button state to show "Restore to English"
                    self.updateTranslationButtonState()
                    
                    print("DEBUG: Successfully loaded translated text and updated button state")
                }
                
            } catch {
                print("DEBUG: Could not load translated text from disk: \(error)")
            }
        }
    }
    
    @available(iOS 18.0, *)
    private func loadTranslatedTextFromDiskWithFallback(targetLanguage: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Get the documents directory
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                
                // Create filename for translated text
                let normalizedBandName = BandDescriptionTranslator.shared.normalizeBandName(self.bandName)
                let fileName = "\(normalizedBandName)_comment.note-translated-\(targetLanguage.uppercased())"
                let fileURL = documentsPath.appendingPathComponent(fileName)
                
                // Load from disk
                let translatedText = try String(contentsOf: fileURL, encoding: .utf8)
                
                DispatchQueue.main.async {
                    // Update the text
                    self.customNotes = translatedText
                    
                    // Set user preference to show they want translated version for this band
                    BandDescriptionTranslator.shared.setUserPreferredLanguage(for: self.bandName, languageCode: targetLanguage)
                    
                    // Update button state to show "Restore to English"
                    self.updateTranslationButtonState()
                    
                    print("DEBUG: Successfully loaded cached translated text and updated button state")
                }
                
            } catch {
                print("DEBUG: No cached translation found, showing English: \(error)")
                DispatchQueue.main.async {
                    // No cached translation, show English and set preference back to English
                    self.customNotes = self.englishDescriptionText
                    BandDescriptionTranslator.shared.setUserPreferredLanguage(for: self.bandName, languageCode: "EN")
                    self.updateTranslationButtonState()
                }
            }
        }
    }
    

    

    

    
    func restoreToEnglish() {
        // Only allow restore if translation is supported
        if #available(iOS 18.0, *) {
            guard BandDescriptionTranslator.shared.isTranslationSupported() else { 
                print("DEBUG: Translation not supported - ignoring restore request")
                return 
            }
            
            print("DEBUG: Restoring to English for band: \(bandName)")
            
            // Set user preference back to English for this band
            BandDescriptionTranslator.shared.setUserPreferredLanguage(for: bandName, languageCode: "EN")
            
            // Restore to English text (use cached if available, otherwise current englishDescriptionText)
            if let cachedEnglish = BandDescriptionTranslator.shared.getEnglishDescription(for: bandName) {
                customNotes = cachedEnglish
            } else {
                customNotes = englishDescriptionText
            }
            
            // Update button state
            updateTranslationButtonState()
            
            // Show localized restore success message
            let currentLangCode = BandDescriptionTranslator.shared.getCurrentLanguageCode()
            let restoreMessage = BandDescriptionTranslator.shared.getRestoredToEnglishMessage(for: currentLangCode)
            toastManager.show(message: restoreMessage, placeHigh: false)
            
            print("DEBUG: Successfully restored to English for \(bandName)")
        } else {
            print("DEBUG: Translation not supported - iOS version < 18.0")
        }
    }
    
    func handleOrientationChange() {
        // Handle orientation change logic if needed
        loadBandDetails() // Refresh details display based on orientation
    }
    
    func saveNotes() {
        guard !bandName.isEmpty else { return }
        
        // Only save if notes have actually been modified
        guard notesHaveChanged() else {
            print("DEBUG: Notes unchanged for band: \(bandName) - skipping save")
            return
        }
        
        print("DEBUG: Saving notes for band: \(bandName)")
        
        let custCommentFile = directoryPath.appendingPathComponent("\(bandName)_comment.note-cust")
        
        // Check various conditions that prevent saving (matching original logic)
        if customNotes.starts(with: FestivalConfig.current.getDefaultDescriptionText()) {
            print("DEBUG: Removing default waiting message")
            removeBadNote(commentFile: custCommentFile)
            
        } else if doNotSaveText {
            print("DEBUG: Description contains link, edit not available")
            
        } else if customNotes.count < 2 {
            print("DEBUG: Removing note - less than 2 characters")
            removeBadNote(commentFile: custCommentFile)
            
        } else if bandNotes.custMatchesDefault(customNote: customNotes, bandName: bandName) {
            print("DEBUG: Description has not changed")
            
        } else if #available(iOS 18.0, *), isCurrentTextActuallyTranslated(currentText: customNotes) {
            print("DEBUG: Text is translated - NOT saving as custom English description")
            
        } else {
            // Save the custom notes
            let commentString = customNotes
            DispatchQueue.global(qos: .default).async {
                print("DEBUG: Writing custom note file: \(custCommentFile)")
                
                do {
                    try commentString.write(to: custCommentFile, atomically: false, encoding: .utf8)
                    print("DEBUG: Successfully saved custom notes for band: \(self.bandName)")
                } catch {
                    print("DEBUG: Error saving custom notes: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func saveNotesForBand(_ specificBandName: String) {
        guard !specificBandName.isEmpty else { return }
        
        // Only save if notes have actually been modified
        guard notesHaveChanged() else {
            print("DEBUG: Notes unchanged for band: \(specificBandName) - skipping save")
            return
        }
        
        print("DEBUG: Saving notes for specific band: \(specificBandName)")
        
        let custCommentFile = directoryPath.appendingPathComponent("\(specificBandName)_comment.note-cust")
        
        // Check various conditions that prevent saving (matching original logic)
        if customNotes.starts(with: FestivalConfig.current.getDefaultDescriptionText()) {
            print("DEBUG: Removing default waiting message for \(specificBandName)")
            removeBadNote(commentFile: custCommentFile)
            
        } else if doNotSaveText {
            print("DEBUG: Description contains link, edit not available for \(specificBandName)")
            
        } else if customNotes.count < 2 {
            print("DEBUG: Removing note - less than 2 characters for \(specificBandName)")
            removeBadNote(commentFile: custCommentFile)
            
        } else if bandNotes.custMatchesDefault(customNote: customNotes, bandName: specificBandName) {
            print("DEBUG: Description has not changed for \(specificBandName)")
            
        } else if #available(iOS 18.0, *), isCurrentTextActuallyTranslated(currentText: customNotes) {
            print("DEBUG: Text is translated - NOT saving as custom English description for \(specificBandName)")
            
        } else {
            // Save the custom notes
            let commentString = customNotes
            DispatchQueue.global(qos: .default).async {
                print("DEBUG: Writing custom note file for \(specificBandName): \(custCommentFile)")
                
                do {
                    try commentString.write(to: custCommentFile, atomically: false, encoding: .utf8)
                    print("DEBUG: Successfully saved custom notes for band: \(specificBandName)")
                } catch {
                    print("DEBUG: Error saving custom notes for \(specificBandName): \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func removeBadNote(commentFile: URL) {
        do {
            print("DEBUG: Removing bad note file: \(commentFile)")
            try FileManager.default.removeItem(at: commentFile)
            
            if FileManager.default.fileExists(atPath: commentFile.path) {
                print("DEBUG: ERROR - Note file was not deleted")
            } else {
                print("DEBUG: CONFIRMATION - Note file was deleted")
                // Reload notes after deletion
                loadNotes()
            }
        } catch {
            print("DEBUG: Error removing note file: \(error.localizedDescription)")
        }
    }
    
    private func getHostingController() -> UIViewController? {
        // Find the current UIHostingController in the view hierarchy
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        
        var currentController = window.rootViewController
        while let presentedController = currentController?.presentedViewController {
            currentController = presentedController
        }
        
        // Navigate through navigation controllers to find the hosting controller
        if let navController = currentController as? UINavigationController {
            return navController.topViewController
        }
        
        return currentController
    }
    
    func openInternalBrowser(url: String) {
        guard !url.isEmpty else { return }
        
        // Use the same pattern as the original app - set URL and navigate to WebViewController
        setUrl(url)
        
        // Get the current view controller to present the web view
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            // Find the storyboard and instantiate the web view controller
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let webViewController = storyboard.instantiateViewController(withIdentifier: "StatsWebViewController") as? WebViewController {
                
                let backItem = UIBarButtonItem()
                backItem.title = "Back"
                
                // Handle iPad split view vs iPhone navigation
                if UIDevice.current.userInterfaceIdiom == .pad {
                    if let splitViewController = rootViewController as? UISplitViewController,
                       let detailNavigationController = splitViewController.viewControllers.last as? UINavigationController {
                        detailNavigationController.topViewController?.navigationItem.backBarButtonItem = backItem
                        detailNavigationController.pushViewController(webViewController, animated: true)
                    }
                } else {
                    // iPhone - find the current navigation controller
                    if let navController = findNavigationController(from: rootViewController) {
                        navController.topViewController?.navigationItem.backBarButtonItem = backItem
                        navController.pushViewController(webViewController, animated: true)
                    }
                }
            }
        }
    }
    
    private func findNavigationController(from viewController: UIViewController) -> UINavigationController? {
        if let navController = viewController as? UINavigationController {
            return navController
        }
        
        for child in viewController.children {
            if let navController = findNavigationController(from: child) {
                return navController
            }
        }
        
        return viewController.navigationController
    }
    
    // MARK: - Private Methods
    
    private func loadInitialData() {
        // LEGACY: Priorities are now handled by PriorityManager via Core Data
        attendedHandle.loadShowsAttended()
    }
    
    private func loadBandImage() {
        print("🖼️ [IMAGE_DEBUG] ============================================")
        print("🖼️ [IMAGE_DEBUG] loadBandImage called for '\(bandName)'")
        print("🖼️ [IMAGE_DEBUG] Current time: \(Date())")
        print("🖼️ [IMAGE_DEBUG] ============================================")
        
        // Reset loading state at the start
        isLoadingImage = false
        
        // Get image info (URL + date) from combined handler
        print("🔍 [IMAGE_DEBUG] About to call CombinedImageListHandler.shared.getImageInfo for '\(bandName)'")
        var imageInfo = CombinedImageListHandler.shared.getImageInfo(for: bandName)
        print("🧩 [IMAGE_PIPELINE] DetailViewModel.getImageInfo result | year=\(eventYear) combinedImageList=\(CombinedImageListHandler.shared.combinedImageList.count) band='\(bandName)' found=\(imageInfo != nil)")
        
        // FALLBACK LOGIC: If image map is empty OR has invalid URL, try direct SQLite lookups
        let imageURLFromMap = imageInfo?.url ?? ""
        let isValidURL = !imageURLFromMap.isEmpty && 
                         imageURLFromMap != "http://" && 
                         imageURLFromMap != "https://" && 
                         imageURLFromMap.trimmingCharacters(in: .whitespaces).count > 0
        
        if imageInfo == nil || !isValidURL {
            if imageInfo == nil {
                print("❌ [IMAGE_DEBUG] No imageInfo found in map for '\(bandName)' - trying fallback lookups")
            } else {
                print("❌ [IMAGE_DEBUG] Invalid URL in map for '\(bandName)' (URL='\(imageURLFromMap)') - trying fallback lookups")
            }
            print("🧩 [IMAGE_PIPELINE] Fallback path | year=\(eventYear) combinedImageList=\(CombinedImageListHandler.shared.combinedImageList.count) band='\(bandName)'")
            
            // Try fallback: direct SQLite lookup
            if let fallbackURL = getImageURLFromSQLiteFallback(bandName: bandName) {
                print("✅ [IMAGE_FALLBACK] Found image URL via SQLite fallback: \(fallbackURL)")
                imageInfo = ImageInfo(url: fallbackURL, date: nil)
            } else {
                print("❌ [IMAGE_FALLBACK] All fallback methods failed for '\(bandName)' - showing default logo")
                print("🧩 [IMAGE_PIPELINE] DEFAULT LOGO | year=\(eventYear) combinedImageList=\(CombinedImageListHandler.shared.combinedImageList.count) band='\(bandName)'")
                DispatchQueue.main.async {
                    self.isLoadingImage = false
                    self.bandImage = self.getFestivalDefaultLogo()
                }
                return
            }
        }
        
        print("✅ [IMAGE_DEBUG] Found imageInfo for '\(bandName)'")
        guard let imageInfo = imageInfo else {
            // Should never reach here, but guard against it
            print("❌ [IMAGE_DEBUG] UNEXPECTED: imageInfo is nil after nil check")
            DispatchQueue.main.async {
                self.isLoadingImage = false
                self.bandImage = self.getFestivalDefaultLogo()
            }
            return
        }
        
        let imageURL = imageInfo.url
        let imageDate = imageInfo.date
        
        print("Loading image for \(bandName) from URL: \(imageURL)")
        if let date = imageDate, !date.isEmpty {
            print("📅 Image has expiration date: \(date) (cache invalidation enabled)")
        } else {
            print("📸 Image has no expiration date (standard caching)")
        }
        
        guard !imageURL.isEmpty && imageURL != "http://" && imageURL != "https://" else {
            print("❌ IMAGE_LOAD: Invalid/empty URL for '\(bandName)' - showing festival-specific placeholder (NOT cached)")
            print("   URL was: '\(imageURL)'")
            DispatchQueue.main.async {
                self.isLoadingImage = false
                self.bandImage = self.getFestivalDefaultLogo()
            }
            return
        }
        
        // Additional URL validation - check for placeholder/default URLs
        let lowercaseURL = imageURL.lowercased()
        let suspiciousPatterns = ["placeholder", "default", "logo", "coming-soon", "tba", "tbd"]
        for pattern in suspiciousPatterns {
            if lowercaseURL.contains(pattern) {
                print("⚠️ IMAGE_LOAD: Suspicious URL pattern '\(pattern)' detected for '\(bandName)' - may be placeholder")
                print("   URL: \(imageURL)")
            }
        }
        
        // Use stored imageHandle to prevent deallocation during async operations
        let scheduleImageDate = (imageDate != nil && !imageDate!.isEmpty) ? imageDate : nil
        
        // Check if cached image exists first (without returning placeholder)
        // Use versioned cache naming to distinguish old (low quality) from new (high quality) images
        let dirs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let directoryPath = URL(fileURLWithPath: dirs[0])
        let oldImageStore = directoryPath.appendingPathComponent(bandName + ".png")      // Old cache format
        
        // Determine cache filename based on whether this is a schedule image with a date
        let newImageStore: URL
        if let imageDate = scheduleImageDate {
            // Schedule image with date - use date-based filename for cache invalidation
            newImageStore = directoryPath.appendingPathComponent(bandName + "_schedule_" + imageDate + ".png")
            print("🗓️ Using date-based cache filename: \(bandName)_schedule_\(imageDate).png")
            print("🗓️ Full path: \(newImageStore.path)")
        } else {
            // Artist image or schedule image without date - use standard v2 format
            newImageStore = directoryPath.appendingPathComponent(bandName + "_v2.png")
            print("📸 Using standard cache filename: \(bandName)_v2.png")
        }
        
        // Check for new cache first
        print("🔍 Checking if cache file exists at: \(newImageStore.path)")
        let cacheExists = FileManager.default.fileExists(atPath: newImageStore.path)
        print("🔍 Cache exists: \(cacheExists)")
        
        if let newCachedImageData = UIImage(contentsOfFile: newImageStore.path) {
            // New cache exists - use it immediately
            print("✅ Using cached image for \(bandName) from: \(newImageStore.lastPathComponent)")
            DispatchQueue.main.async {
                self.isLoadingImage = false // Ensure loading state is cleared
                self.bandImage = newCachedImageData
            }
            return
        } else if scheduleImageDate != nil {
            // No cache with current date - clean up any old schedule images with different dates
            cleanupOldScheduleImages(bandName: bandName, currentDate: scheduleImageDate!, directoryPath: directoryPath)
        }
        
        // Check for old cache
        if FileManager.default.fileExists(atPath: oldImageStore.path) {
            print("⚠️ Found old cached image for \(bandName)")
            
            if isInternetAvailable() {
                // Internet available - delete old cache and re-download with new format
                print("🔄 Internet available - deleting old cache and re-downloading for \(bandName)")
                do {
                    try FileManager.default.removeItem(at: oldImageStore)
                    print("✅ Deleted old cached image for \(bandName)")
                } catch {
                    print("❌ Error deleting old cached image for \(bandName): \(error)")
                }
                // Fall through to download fresh image
            } else {
                // No internet - use old cache as fallback
                print("📡 No internet - using old cached image as fallback for \(bandName)")
                if let oldCachedImageData = UIImage(contentsOfFile: oldImageStore.path) {
                    DispatchQueue.main.async {
                        self.isLoadingImage = false // Ensure loading state is cleared
                        self.bandImage = oldCachedImageData
                    }
                    return
                }
            }
        }
        
        // No cache exists - attempt download without showing placeholder first
        if isInternetAvailable() {
            // Only download individual images if not currently doing bulk downloads
            if !self.imageHandle.downloadingAllImages {
                print("🔄 No cache found - attempting download for \(bandName)")
                print("🔄 Will download from: \(imageURL)")
                downloadAndCacheImage(imageURL: imageURL, imageHandle: self.imageHandle, scheduleImageDate: scheduleImageDate)
            } else {
                print("⏸️ Skipping individual image download for \(bandName) - bulk download in progress")
                // Don't show placeholder during bulk download - let it load when bulk completes
            }
        } else {
            // No internet and no cache - keep image area empty for now
            // Only show placeholder if user explicitly needs visual feedback
            print("📡 No internet and no cache for \(bandName) - keeping image area empty")
            // Don't set bandImage to anything - let it remain nil (empty)
        }
    }
    
    private func downloadAndCacheImage(imageURL: String, imageHandle: imageHandler, scheduleImageDate: String?) {
        // Keep image area empty during download - don't set bandImage to anything initially
        print("🔄 Starting download for \(bandName) - keeping image area empty")
        
        // Show loading indicator
        DispatchQueue.main.async {
            self.isLoadingImage = true
        }
        
        // Determine custom cache filename if this is a schedule image with a date
        let customFilename: String?
        if let imageDate = scheduleImageDate {
            customFilename = bandName + "_schedule_" + imageDate + ".png"
            print("🗓️ Using custom cache filename for download: \(customFilename!)")
        } else {
            customFilename = nil
        }
        
        imageHandle.downloadAndCacheImage(urlString: imageURL, bandName: bandName, cacheFilename: customFilename) { [weak self] processedImage in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Hide loading indicator
                self.isLoadingImage = false
                
                if let image = processedImage {
                    print("✅ IMAGE_LOAD: Download successful for '\(self.bandName)' - displaying real image")
                    self.bandImage = image
                } else {
                    print("❌ IMAGE_LOAD: Download FAILED for '\(self.bandName)' - showing festival placeholder (NOT cached)")
                    print("   Failed URL: \(imageURL)")
                    self.bandImage = self.getFestivalDefaultLogo()
                }
            }
        }
    }
    
    /// Cleans up old schedule images with different dates
    /// - Parameters:
    ///   - bandName: The name of the band
    ///   - currentDate: The current ImageDate from the schedule
    ///   - directoryPath: The documents directory URL
    private func cleanupOldScheduleImages(bandName: String, currentDate: String, directoryPath: URL) {
        print("🧹 Checking for old schedule images to clean up for \(bandName)")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directoryPath, includingPropertiesForKeys: nil)
            let prefix = bandName + "_schedule_"
            let currentFilename = bandName + "_schedule_" + currentDate + ".png"
            
            for file in files {
                let filename = file.lastPathComponent
                // Check if this is a schedule image for this band but with a different date
                if filename.hasPrefix(prefix) && filename != currentFilename && filename.hasSuffix(".png") {
                    print("🗑️ Deleting old schedule image: \(filename)")
                    try FileManager.default.removeItem(at: file)
                    print("✅ Successfully deleted old schedule image: \(filename)")
                }
            }
        } catch {
            print("⚠️ Error cleaning up old schedule images: \(error)")
        }
    }
    
    /// Returns the festival-specific default logo
    /// - Returns: UIImage of the festival logo, or a system default if loading fails
    private func getFestivalDefaultLogo() -> UIImage {
        // Use the festival-specific logo from configuration
        let logoName = FestivalConfig.current.logoUrl
        
        if let logo = UIImage(named: logoName) {
            print("Using festival logo: \(logoName)")
            return logo
        }
        
        // Fallback to default festival logo if festival logo not found
        if logoName != FestivalConfig.current.logoUrl, let fallbackLogo = UIImage(named: FestivalConfig.current.logoUrl) {
            print("Festival logo '\(logoName)' not found, using \(FestivalConfig.current.festivalShortName) fallback")
            return fallbackLogo
        }
        
        // Ultimate fallback - system image
        print("No bundled logos found, using system fallback")
        return UIImage(systemName: "music.note") ?? UIImage()
    }
    
    private func clearAllCachedImages() {
        // This method is now deprecated in favor of versioned cache naming
        // Old images are handled individually when encountered
        print("⚠️ clearAllCachedImages called but using versioned cache approach instead")
    }
    
    /// Fallback method to get image URL directly from SQLite when image map is empty or missing entry
    /// Tries in order: 1) Band table, 2) Event table, 3) Returns nil for default image
    private func getImageURLFromSQLiteFallback(bandName: String) -> String? {
        print("🔍 [IMAGE_FALLBACK] Step 1: Checking SQLite bands table for '\(bandName)'")
        
        // Helper function to validate URLs (checks for whitespace-only strings too)
        func isValidImageURL(_ url: String?) -> Bool {
            guard let url = url else { return false }
            let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && trimmed != "http://" && trimmed.count > 0
        }
        
        // Helper function to normalize URLs by adding protocol prefix if missing
        // This matches the behavior in bandNamesHandler.getBandImageUrl() and Android's getImageUrl()
        func normalizeImageURL(_ url: String) -> String {
            let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
            // If URL doesn't start with http:// or https://, add https:// prefix
            if !trimmed.hasPrefix("http://") && !trimmed.hasPrefix("https://") {
                let normalized = "https://\(trimmed)"
                print("🔧 [IMAGE_FALLBACK] Normalized URL: '\(url)' -> '\(normalized)'")
                return normalized
            }
            return trimmed
        }
        
        // Step 1: Try to get image URL from bands table
        let dataManager = DataManager.shared
        if let band = dataManager.fetchBand(byName: bandName, eventYear: eventYear) {
            if let imageUrl = band.imageUrl, isValidImageURL(imageUrl) {
                let normalizedUrl = normalizeImageURL(imageUrl)
                print("✅ [IMAGE_FALLBACK] Found image URL in bands table: \(imageUrl) -> normalized: \(normalizedUrl)")
                return normalizedUrl
            } else {
                print("⚠️ [IMAGE_FALLBACK] Band exists but has no valid image URL (imageUrl: '\(band.imageUrl ?? "nil")')")
            }
        } else {
            print("⚠️ [IMAGE_FALLBACK] Band not found in bands table")
        }
        
        // Step 2: Try to get image URL from events table (schedule images)
        print("🔍 [IMAGE_FALLBACK] Step 2: Checking SQLite events table for '\(bandName)'")
        let events = dataManager.fetchEventsForBand(bandName, forYear: eventYear)
        
        if !events.isEmpty {
            print("🔍 [IMAGE_FALLBACK] Found \(events.count) events for '\(bandName)'")
            
            // Try to find an event with an image URL
            for event in events {
                if let eventImageUrl = event.eventImageUrl, isValidImageURL(eventImageUrl) {
                    let normalizedUrl = normalizeImageURL(eventImageUrl)
                    print("✅ [IMAGE_FALLBACK] Found image URL in events table: \(eventImageUrl) -> normalized: \(normalizedUrl)")
                    return normalizedUrl
                }
            }
            
            print("⚠️ [IMAGE_FALLBACK] Events exist but none have valid image URLs (all empty/whitespace)")
        } else {
            print("⚠️ [IMAGE_FALLBACK] No events found for '\(bandName)'")
        }
        
        // Step 3: All fallbacks failed
        print("❌ [IMAGE_FALLBACK] No valid image URL found in any SQLite table")
        return nil
    }
    
    private func loadImageFromCache(imageURL: String, imageHandle: imageHandler) {
        let imageStore = URL(fileURLWithPath: getDocumentsDirectory().appendingPathComponent(bandName + "_v2.png"))
        
        if let imageData = UIImage(contentsOfFile: imageStore.path) {
            let processedImage = imageHandle.processImage(imageData, urlString: imageURL)
            DispatchQueue.main.async {
                self.isLoadingImage = false // Ensure loading state is cleared
                self.bandImage = processedImage
            }
        } else {
            DispatchQueue.main.async {
                self.isLoadingImage = false // Ensure loading state is cleared
                self.bandImage = self.getFestivalDefaultLogo()
            }
        }
    }
    
    private func loadBandDetails() {
        print("DEBUG: loadBandDetails() called for band: '\(bandName)'")
        
        let currentOrientation = UIApplication.shared.statusBarOrientation
        let deviceType = UIDevice.current.userInterfaceIdiom
        let isPortrait = currentOrientation == .portrait
        let isPad = deviceType == .pad
        let shouldShowData = isPortrait || isPad
        
        print("DEBUG: Device check - orientation: \(currentOrientation.rawValue), isPortrait: \(isPortrait), deviceType: \(deviceType.rawValue), isPad: \(isPad), shouldShowData: \(shouldShowData)")
        
        // Only show details in portrait or on iPad
        if shouldShowData {
            country = bandNameHandle.getBandCountry(bandName)
            genre = bandNameHandle.getBandGenre(bandName)
            lastOnCruise = bandNameHandle.getPriorYears(bandName)
            noteWorthy = bandNameHandle.getBandNoteWorthy(bandName)
            
            print("DEBUG: loadBandDetails() for '\(bandName)' - country: '\(country)', genre: '\(genre)', lastOnCruise: '\(lastOnCruise)', noteWorthy: '\(noteWorthy)'")
        } else {
            // Hide details in landscape on iPhone only (iPads always show data)
            country = ""
            genre = ""
            lastOnCruise = ""
            noteWorthy = ""
            print("DEBUG: loadBandDetails() for '\(bandName)' - hiding details (iPhone in landscape)")
        }
    }
    
    private func loadBandLinks() {
        print("DEBUG: loadBandLinks() called for band: '\(bandName)'")
        
        let officialPage = bandNameHandle.getofficalPage(bandName)
        if !officialPage.isEmpty && officialPage != "Unavailable" {
            officialUrl = officialPage
            wikipediaUrl = bandNameHandle.getWikipediaPage(bandName)
            youtubeUrl = bandNameHandle.getYouTubePage(bandName)
            metalArchivesUrl = bandNameHandle.getMetalArchives(bandName)
            
            print("DEBUG: loadBandLinks() for '\(bandName)' - official: '\(officialUrl)', wikipedia: '\(wikipediaUrl)', youtube: '\(youtubeUrl)', metalArchives: '\(metalArchivesUrl)'")
        } else {
            officialUrl = ""
            wikipediaUrl = ""
            youtubeUrl = ""
            metalArchivesUrl = ""
            
            print("DEBUG: loadBandLinks() for '\(bandName)' - no links available (official page: '\(officialPage)')")
        }
    }
    
    private func loadScheduleEvents() {
        print("DEBUG: loadScheduleEvents() called for band: \(bandName) - cache only")
        
        // PERFORMANCE FIX: Detail screen uses only already-cached schedule data
        var newScheduleEvents: [ScheduleEvent] = []
        
        // Check if schedule data is loaded WITHOUT triggering lazy loading
        let isScheduleCacheLoaded = schedule.cacheLoaded
        print("DEBUG: Schedule cache loaded: \(isScheduleCacheLoaded)")
        
        guard isScheduleCacheLoaded else {
            print("DEBUG: Schedule cache not loaded - showing empty schedule for detail screen")
            scheduleEvents = []
            return
        }
        
        // Now safe to access schedulingData
        let cachedSchedulingData = schedule.getBandSortedSchedulingData()
        print("DEBUG: Using cached schedule data with \(cachedSchedulingData.count) bands")
        
        if let bandSchedule = cachedSchedulingData[bandName], !bandSchedule.isEmpty {
            print("DEBUG: Found cached schedule for '\(bandName)' with \(bandSchedule.count) time slots")
            let sortedKeys = bandSchedule.keys.sorted()

            for timeIndex in sortedKeys {
                // Use cached data directly to avoid any lazy loading
                let eventData = bandSchedule[timeIndex] ?? [:]
                let location = eventData[locationField] ?? ""
                let day = monthDateRegionalFormatting(dateValue: eventData[dayField] ?? "")
                let startTime = eventData[startTimeField] ?? ""
                let endTime = eventData[endTimeField] ?? ""
                let eventType = eventData[typeField] ?? ""
                let notes = eventData[notesField] ?? ""
                let imageUrl = eventData[imageUrlField] ?? ""
                let imageDate = eventData[imageUrlDateField] ?? ""
                
                let formattedStartTime = formatTimeValue(timeValue: startTime)
                let formattedEndTime = formatTimeValue(timeValue: endTime)
                
                let venueColor = Color(getVenueColor(venue: location))
                
                // Get attended status and create appropriate icon (use raw location without venue suffix)
                let attendedStatus = attendedHandle.getShowAttendedStatus(
                    band: bandName,
                    location: location,  // Use raw location here (before venue suffix is added)
                    startTime: startTime,
                    eventType: eventType,
                    eventYearString: String(eventYear)
                )
                let attendedIcon: UIImage = {
                    switch attendedStatus {
                    case sawAllStatus:
                        return UIImage(named: "icon-seen") ?? UIImage()
                    case sawSomeStatus:
                        return UIImage(named: "icon-seen-partial") ?? UIImage()
                    case sawNoneStatus:
                        return UIImage() // No icon for "did not attend"
                    default:
                        return UIImage() // Default empty icon
                    }
                }()
                
                let eventTypeIcon = getEventTypeIcon(eventType: eventType, eventName: bandName)
                
                var dayText = ""
                if day.hasPrefix("Day ") {
                    dayText = day.replacingOccurrences(of: "Day ", with: "")
                } else {
                    dayText = day
                }
                
                let event = ScheduleEvent(
                    location: location + (venueLocation[location] != nil ? " " + venueLocation[location]! : ""),
                    eventType: eventType == showType ? "" : convertEventTypeToLocalLanguage(eventType: eventType),
                    startTime: formattedStartTime,
                    endTime: formattedEndTime,
                    day: dayText,
                    notes: notes,
                    venueColor: venueColor,
                    attendedIcon: attendedIcon,
                    eventTypeIcon: eventTypeIcon,
                    timeIndex: timeIndex,
                    bandName: bandName,
                    rawStartTime: startTime,
                    originalEventType: eventType,  // Keep original eventType for attendance tracking
                    rawLocation: location,  // Keep original location without venue suffix for attendance tracking
                    imageUrl: imageUrl,
                    imageDate: imageDate
                )
                
                newScheduleEvents.append(event)
            }
        } else {
            print("DEBUG: No cached schedule data found for band '\(bandName)'")
            if cachedSchedulingData.isEmpty {
                print("DEBUG: Schedule cache is empty - expected if main list hasn't loaded yet")
            }
        }
        
        print("DEBUG: Found \(newScheduleEvents.count) schedule events for '\(bandName)'")
        
        // Update UI directly (we're already on main thread)
        scheduleEvents = newScheduleEvents
    }
    
    private func loadNotes() {
        print("DEBUG: loadNotes() called for band: '\(bandName)'")
        
        let noteText = bandNotes.getDescription(bandName: bandName)
        englishDescriptionText = noteText
        customNotes = noteText
        // Store original notes for change tracking
        originalNotes = noteText
        hasNotesChanged = false
        
        print("DEBUG: Loaded notes for '\(self.bandName)': '\(noteText.prefix(50))...' (length: \(noteText.count))")
        
        // Check for links that make text non-editable (matching original logic)
        if customNotes.contains("!!!!https://") {
            doNotSaveText = true
            isNotesEditable = false
            customNotes = customNotes.replacingOccurrences(of: "!!!!https://", with: "https://")
            print("DEBUG: Notes contain links - set to read-only for '\(bandName)'")
        } else {
            doNotSaveText = false
            isNotesEditable = true
            print("DEBUG: Notes are editable for '\(bandName)'")
        }
        
        // Add noteworthy prefix if exists
        if !noteWorthy.isEmpty {
            customNotes = "\n" + customNotes
            englishDescriptionText = "\n" + englishDescriptionText
            print("DEBUG: Added noteworthy prefix for '\(bandName)'")
        }
        
        // Check if we need to download description
        let noteUrl = bandNotes.getDescriptionUrl(bandName)
        if shouldDownloadDescription(noteText: noteText, noteUrl: noteUrl) {
            print("DEBUG: Downloading description for '\(bandName)' from URL")
            downloadDescription(noteUrl: noteUrl)
        } else if #available(iOS 18.0, *) {
            if BandDescriptionTranslator.shared.isTranslationSupported() {
                print("DEBUG: Displaying description in current language for '\(bandName)'")
                displayDescriptionInCurrentLanguage()
            }
        }
        
        print("DEBUG: Final customNotes for '\(bandName)': '\(customNotes.prefix(50))...' (length: \(customNotes.count))")
    }
    
    private func shouldDownloadDescription(noteText: String, noteUrl: String) -> Bool {
        let needsDownload = noteText.isEmpty ||
                           noteText.starts(with: FestivalConfig.current.getDefaultDescriptionText()) ||
                           noteText.starts(with: "Comment text is not available yet. Please wait")
        
        return needsDownload && !noteUrl.isEmpty && isInternetAvailable()
    }
    
    private func downloadDescription(noteUrl: String) {
        guard let url = URL(string: noteUrl) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self,
                  error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data,
                  let descriptionText = String(data: data, encoding: .utf8),
                  !descriptionText.starts(with: "<!DOCTYPE") else { return }
            
            // Cache the downloaded description
            let commentFileName = self.bandNotes.getNoteFileName(bandName: self.bandName)
            let commentFile = self.directoryPath.appendingPathComponent(commentFileName)
            
            do {
                try descriptionText.write(to: commentFile, atomically: false, encoding: .utf8)
            } catch {
                print("Error caching description: \(error)")
            }
            
            DispatchQueue.main.async {
                let processedText = self.bandNotes.removeSpecialCharsFromString(text: descriptionText)
                self.englishDescriptionText = processedText
                self.customNotes = processedText
                
                if #available(iOS 18.0, *) {
                    if BandDescriptionTranslator.shared.isTranslationSupported() {
                        self.displayDescriptionInCurrentLanguage()
                    }
                }
            }
        }.resume()
    }
    
    private func displayDescriptionInCurrentLanguage() {
        // If translation is not supported, always show English and exit early
        if #available(iOS 18.0, *) {
            guard BandDescriptionTranslator.shared.isTranslationSupported() else {
                customNotes = englishDescriptionText
                return
            }
            
            // Store English version for future use
            BandDescriptionTranslator.shared.storeEnglishDescription(for: bandName, text: englishDescriptionText)
            
            // Get user's preferred language for this specific band (defaults to English)
            let userPreferredLang = BandDescriptionTranslator.shared.getUserPreferredLanguage(for: bandName)
            
            if userPreferredLang == "EN" {
                // User prefers English for this band
                customNotes = englishDescriptionText
                updateTranslationButtonState()
                return
            }
            
            // User prefers translated version - check if we have cached translation on disk
            loadTranslatedTextFromDiskWithFallback(targetLanguage: userPreferredLang)
        } else {
            // iOS < 18.0, always show English
            customNotes = englishDescriptionText
        }
    }
    
    private func loadPriority() {
        print("DEBUG: loadPriority() called for band: '\(bandName)' - cache only")
        
        // PERFORMANCE FIX: Detail screen should only read cached priority data, never save
        isLoadingPriority = true
        
        let priorityManager = SQLitePriorityManager.shared
        let priority = priorityManager.getPriority(for: bandName)
        
        if priority != 0 {
            selectedPriority = priority
            originalPriority = priority
            print("DEBUG: loadPriority() for '\(bandName)' - found priority: \(priority)")
        } else {
            selectedPriority = 0
            originalPriority = nil
            print("DEBUG: loadPriority() for '\(bandName)' - no priority found, setting to 0")
        }
        
        isLoadingPriority = false
    }
    
    private func savePriority() {
        print("DEBUG: savePriority() called for '\(bandName)' with priority: \(selectedPriority)")
        
        // Priority is now managed entirely by Core Data via PriorityManager
        
        // THREAD SAFETY FIX: Perform Core Data operations on background thread to prevent crashes
        let bandNameCopy = bandName
        let priorityCopy = selectedPriority
        
        DispatchQueue.global(qos: .utility).async {
            let priorityManager = SQLitePriorityManager.shared
            priorityManager.setPriority(for: bandNameCopy, priority: priorityCopy)
            print("DEBUG: savePriority() completed for '\(bandNameCopy)' with priority: \(priorityCopy)")
        }
        
        print("DEBUG: savePriority() - Saved priority \(selectedPriority) for band: '\(bandName)' (originalPriority: \(originalPriority?.description ?? "nil"))")
        
        // Post targeted notification for priority changes (avoid full data reload)
        NotificationCenter.default.post(name: Notification.Name("DetailDidUpdate"), object: nil)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            // Use lightweight refresh instead of heavy background update for priority changes
            masterView?.refreshBandListOnly(reason: "Detail view priority update")
        }
    }
    
    private func setupTranslationButton() {
        // Use comprehensive support check that handles iOS version, language, and feature availability
        if #available(iOS 18.0, *) {
            showTranslationButton = BandDescriptionTranslator.shared.isTranslationSupported()
        } else {
            showTranslationButton = false
        }
        
        if showTranslationButton {
            updateTranslationButtonState()
        }
    }
    
    private func updateTranslationButtonState() {
        // Only update button state if translation is supported
        if #available(iOS 18.0, *) {
            guard BandDescriptionTranslator.shared.isTranslationSupported() else { return }
            
            let currentLangCode = BandDescriptionTranslator.shared.getCurrentLanguageCode()
            
            // Check if the current text is actually translated by looking for translation headers
            isCurrentTextTranslated = isCurrentTextActuallyTranslated(currentText: customNotes)
            
            print("DEBUG: updateTranslationButtonState - isCurrentTextTranslated: \(isCurrentTextTranslated)")
            print("DEBUG: Current customNotes preview: '\(String(customNotes.prefix(100)))...'")
            
            if isCurrentTextTranslated {
                // Currently showing translated text - show restore button
                restoreButtonText = BandDescriptionTranslator.shared.getLocalizedRestoreButtonText(for: currentLangCode)
                translateButtonText = "" // Clear translate button text
                print("DEBUG: Button state: RESTORE - '\(restoreButtonText)'")
            } else {
                // Currently showing English text - show translate button
                translateButtonText = BandDescriptionTranslator.shared.getLocalizedTranslateButtonText(for: currentLangCode)
                restoreButtonText = "" // Clear restore button text
                print("DEBUG: Button state: TRANSLATE - '\(translateButtonText)'")
            }
        }
    }
    
    @available(iOS 18.0, *)
    private func isCurrentTextActuallyTranslated(currentText: String) -> Bool {
        guard !englishDescriptionText.isEmpty else { return false }
        guard !currentText.isEmpty else { return false }
        
        if currentText.trimmingCharacters(in: .whitespacesAndNewlines) ==
           englishDescriptionText.trimmingCharacters(in: .whitespacesAndNewlines) {
            return false
        }
        
        let translatedFromEnglishTexts = [
            "Translated from English",
            "Aus dem Englischen übersetzt",
            "Traduit de l'anglais",
            "Käännetty englannista",
            "Traduzido do inglês",
            "Traducido del inglés",
            "Oversat fra engelsk"
        ]
        
        for translatedText in translatedFromEnglishTexts {
            if currentText.contains(translatedText) {
                return true
            }
        }
        
        let legacyMarkers = ["[DE]", "[ES]", "[FR]", "[PT]", "[DA]", "[FI]", "🌐 Translation"]
        for marker in legacyMarkers {
            if currentText.contains(marker) {
                return true
            }
        }
        
        let currentLangCode = BandDescriptionTranslator.shared.getCurrentLanguageCode()
        if currentLangCode != "EN" &&
           BandDescriptionTranslator.shared.currentLanguagePreference != "EN" &&
           currentText.count > englishDescriptionText.count * Int(0.7) {
            return true
        }
        
        return false
    }
    
    private func updateNavigationState() {
        // Determine if we can navigate to previous/next bands
        print("DEBUG: updateNavigationState() - currentBandList count: \(currentBandList.count)")
        
        // If currentBandList is empty, try to get it from the current bands
        if currentBandList.isEmpty {
            print("DEBUG: currentBandList is empty, trying to populate from current context")
            // This should be set by the MasterViewController, but let's add a fallback
        }
        
        canNavigatePrevious = !currentBandList.isEmpty
        canNavigateNext = !currentBandList.isEmpty
        print("DEBUG: canNavigatePrevious: \(canNavigatePrevious), canNavigateNext: \(canNavigateNext)")
    }
    
    private func swipeToNextRecord(direction: String) {
        print("DEBUG: swipeToNextRecord() called with direction: \(direction)")
        print("DEBUG: currentBandList: \(currentBandList)")
        print("DEBUG: current bandName: \(bandName)")
        
        var loopThroughBandList = [String]()
        var previousInLoop = ""
        var bandNameNext = ""
        var timeView = true
        
        // Disable swiping if needed
        if blockSwiping {
            print("DEBUG: Swiping blocked, returning early")
            return
        }
        
        // Prevent rapid-fire swipes by temporarily blocking
        blockSwiping = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.blockSwiping = false
        }
        
        // Build universal list of bands for all view types
        print("Checking next bandName currentBandList is \(currentBandList)")
        for index in currentBandList {
            
            var bandInIndex = getBandFromIndex(index: index)
            
            // Disallow back to back duplicates
            if bandInIndex == previousInLoop {
                continue
            }
            previousInLoop = bandInIndex
            
            loopThroughBandList.append(bandInIndex)
            
            // Determine if time applies here
            let indexSplit = index.components(separatedBy: ":")
            if indexSplit.count == 1 {
                timeView = false
            }
        }
        
        // Find where in list
        var counter = 0
        let sizeBands = loopThroughBandList.count
        print("Checking next bandName list of bands is \(loopThroughBandList)")
        
        for index in loopThroughBandList {
            if bandName == bandNameFromIndex(index: index) {
                print("Checking next bandName Found match at \(counter) for \(bandName)")
                
                if direction == "Previous" {
                    let previousIndex = counter - 1
                    if previousIndex >= 0 {
                        let nextIndex = getBandFromIndex(index: loopThroughBandList[previousIndex])
                        eventSelectedIndex = timeIndexMap[nextIndex] ?? ""
                        let bandNameFromIndex = nextIndex.components(separatedBy: ":")
                        bandNameNext = bandNameFromIndex[1]
                        print("Checking next bandName Previous \(nextIndex) - \(eventSelectedIndex) - \(bandNameFromIndex) - \(bandNameNext)")
                    }
                } else {
                    let nextCounter = counter + 1
                    if nextCounter < sizeBands {
                        let nextIndex = getBandFromIndex(index: loopThroughBandList[nextCounter])
                        eventSelectedIndex = timeIndexMap[nextIndex] ?? ""
                        let bandNameFromIndex = nextIndex.components(separatedBy: ":")
                        bandNameNext = bandNameFromIndex[1]
                        print("Checking next bandName Next \(nextIndex) - \(eventSelectedIndex) - \(bandNameFromIndex) - \(bandNameNext)")
                    }
                }
                break
            }
            counter += 1
        }
        
        jumpToNextOrPreviousScreen(nextBandName: bandNameNext, direction: direction)
    }
    
    private func getBandFromIndex(index: String) -> String {
        var bandInIndex = ""
        let indexSplit = index.components(separatedBy: ":")
        
        if indexSplit.count == 1 {
            bandInIndex = "0:" + index
        } else if indexSplit[0].isNumeric {
            bandInIndex = indexSplit[0] + ":" + indexSplit[1]
        } else if indexSplit[1].isNumeric {
            bandInIndex = "0:" + indexSplit[0]
        } else if indexSplit[0].isDouble() {
            bandInIndex = indexSplit[0] + ":" + indexSplit[1]
        } else if indexSplit[1].isDouble() {
            bandInIndex = "0:" + indexSplit[0]
        }
        
        return bandInIndex
    }
    
    private func bandNameFromIndex(index: String) -> String {
        var bandName = index
        let indexSplit = index.components(separatedBy: ":")
        
        if indexSplit.count == 2 {
            bandName = indexSplit[1]
        }
        
        return bandName
    }
    
    private func jumpToNextOrPreviousScreen(nextBandName: String, direction: String) {
        var message = ""
        let translatedDirection = NSLocalizedString(direction, comment: "")
        
        print("DEBUG: jumpToNextOrPreviousScreen - from '\(bandName)' to '\(nextBandName)'")
        
        if nextBandName.isEmpty {
            if direction == "Next" {
                message = NSLocalizedString("EndofList", comment: "Message shown when at end of band list")
            } else {
                message = NSLocalizedString("AlreadyAtStart", comment: "Message shown when at start of band list")
            }
            print("DEBUG: Showing boundary message: '\(message)'")
            print("DEBUG: Localized string for EndofList: '\(NSLocalizedString("EndofList", comment: ""))'")
            print("DEBUG: Localized string for AlreadyAtStart: '\(NSLocalizedString("AlreadyAtStart", comment: ""))'")
            toastManager.show(message: message, placeHigh: false)
        } else {
            // Save notes for the current band before switching
            let currentBand = bandName
            print("DEBUG: Saving notes for current band '\(currentBand)' before switching to '\(nextBandName)'")
            saveNotesForBand(currentBand)
            
            message = translatedDirection + "-" + nextBandName
            print("DEBUG: Showing navigation message: \(message)")
            
            // Update to the new band (like original: immediate update)
            bandSelected = nextBandName
            bandName = nextBandName
            isLoadingImage = false // Reset image loading state for new band
            bandImage = nil // Clear previous band's image
            print("DEBUG: Updated bandName from '\(currentBand)' to '\(self.bandName)'")
            
            toastManager.show(message: message, placeHigh: false)
            
            // Complete reload like original viewDidLoad() + viewWillAppear()
            DispatchQueue.main.async {
                print("DEBUG: Loading data for new band: '\(self.bandName)'")
                self.loadBandData()
                
                // Force UI update to ensure notes are refreshed
                self.objectWillChange.send()
            }
            
            // Post targeted notification for notes changes (avoid full data reload)
            NotificationCenter.default.post(name: Notification.Name("DetailDidUpdate"), object: nil)
            // NotificationCenter.default.post(name: Notification.Name(rawValue: "RefreshDisplay"), object: nil)
        }
    }
    
    private func isInternetAvailable() -> Bool {
        return NetworkStatusManager.shared.isInternetAvailable
    }
    
    private func showToast(message: String) {
        toastManager.show(message: message, placeHigh: false)
    }
    
    // MARK: - Web Browser Methods
    
    /// Opens a URL in SwiftUI web view for detail links
    func openExternalBrowser(url: String) {
        guard !url.isEmpty else {
            print("ERROR: Attempted to open empty URL")
            return
        }
        
        print("DEBUG: Opening URL in SwiftUI web view: \(url)")
        
        // Check if user prefers to open all links in external browser
        let allLinksExternal = getAllLinksOpenInExternalBrowserValue()
        print("DEBUG: All Links Open In External Browser preference is: \(allLinksExternal)")
        
        // Get the hosting controller from the view hierarchy
        guard let hostingController = getHostingController() else {
            print("ERROR: Could not find hosting controller to present web view")
            return
        }
        
        // Create the appropriate SwiftUI web view based on URL
        guard let urlObject = URL(string: url) else {
            print("ERROR: Invalid URL: \(url)")
            return
        }
        
        let title: String
        if url.contains("metal-archives.com") || url.contains("metallum") {
            title = "Metal Archives"
        } else if url.contains("wikipedia.org") {
            title = "Wikipedia"
        } else if url.contains("youtube.com") || url.contains("youtu.be") {
            // Check if user prefers to open YouTube in the YouTube app
            let openInApp = getOpenYouTubeAppValue()
            print("DEBUG: YouTube URL detected: \(url)")
            print("DEBUG: Open YouTube App preference is: \(openInApp)")
            
            if openInApp {
                // Open YouTube URLs externally when preference is enabled
                // This allows the system to choose YouTube app or Safari
                print("DEBUG: Opening YouTube URL externally (system will choose YouTube app or Safari)")
                
                if UIApplication.shared.canOpenURL(urlObject) {
                    UIApplication.shared.open(urlObject, options: [:]) { success in
                        if success {
                            print("Successfully opened YouTube URL externally: \(url)")
                        } else {
                            print("Failed to open YouTube URL externally: \(url)")
                        }
                    }
                } else {
                    print("Cannot open YouTube URL externally: \(url)")
                }
                return // Exit early - don't use internal web view
            } else {
                print("DEBUG: YouTube app preference is disabled, using internal web view")
                title = "YouTube"
                // Fall through to internal web view
            }
        } else {
            title = "Official Website"
        }
        
        // Check if we should open in external browser based on preference
        if allLinksExternal && !url.contains("youtube.com") && !url.contains("youtu.be") {
            print("DEBUG: All Links Open In External Browser preference is enabled, opening in external browser: \(url)")
            if UIApplication.shared.canOpenURL(urlObject) {
                UIApplication.shared.open(urlObject, options: [:]) { success in
                    if success {
                        print("Successfully opened URL in external browser: \(url)")
                    } else {
                        print("Failed to open URL in external browser: \(url)")
                    }
                }
            } else {
                print("Cannot open URL in external browser: \(url)")
            }
            return // Exit early - don't use internal web view
        }
        
        // Present web view for non-YouTube URLs or when YouTube app preference is disabled
        // or when allLinksOpenInExternalBrowser is false
        presentWebView(url: urlObject, title: title, hostingController: hostingController)
    }
    
    /// Helper function to present web view
    private func presentWebView(url: URL, title: String, hostingController: UIViewController) {
        // Create SwiftUI web view directly
        let swiftUIWebView = SwiftUIWebView(url: url, title: title)
        
        // Present the SwiftUI web view
        let hostingWebViewController = UIHostingController(rootView: swiftUIWebView)
        hostingWebViewController.modalPresentationStyle = UIModalPresentationStyle.pageSheet
        
        // Ensure dark navigation bar appearance on the hosting controller
        hostingWebViewController.overrideUserInterfaceStyle = .dark
        
        hostingController.present(hostingWebViewController, animated: true)
        
        print("Successfully presented SwiftUI web view for: \(url.absoluteString)")
    }
    
    /// Opens URL in external browser (Safari) - used for hyperlinks in notes
    func openInExternalBrowser(url: String) {
        guard !url.isEmpty else {
            print("ERROR: Attempted to open empty URL")
            return
        }
        
        print("DEBUG: Opening URL in external browser: \(url)")
        
        guard let urlObject = URL(string: url) else {
            print("ERROR: Invalid URL: \(url)")
            return
        }
        
        if UIApplication.shared.canOpenURL(urlObject) {
            UIApplication.shared.open(urlObject, options: [:]) { success in
                if success {
                    print("Successfully opened URL in external browser: \(url)")
                } else {
                    print("Failed to open URL in external browser: \(url)")
                }
            }
        } else {
            print("Cannot open URL: \(url)")
        }
    }
    
    /// Opens stats report in SwiftUI web view with proper caching behavior
    func openStatsReport(languageCode: String = "en") {
        print("DEBUG: Opening stats report for language: \(languageCode)")
        
        // Get the hosting controller from the view hierarchy
        guard let hostingController = getHostingController() else {
            print("ERROR: Could not find hosting controller to present stats")
            return
        }
        
        // Get the cache file path for stats
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("ERROR: Could not access documents directory")
            return
        }
        
        let cacheFileName = "stats_report_\(languageCode).html"
        let cacheFileURL = documentsPath.appendingPathComponent(cacheFileName)
        
        // STEP 1: Display cached version immediately if available
        let hasCachedContent = FileManager.default.fileExists(atPath: cacheFileURL.path)
        
        if hasCachedContent {
            print("📄 Displaying cached stats report immediately")
            presentStatsWebView(url: cacheFileURL.absoluteString, title: "Stats Report")
        } else {
            print("📄 No cached stats available, will show content after download")
        }
        
        // STEP 2: Download latest version in background
        downloadLatestStatsReport(languageCode: languageCode, cacheFileURL: cacheFileURL, hasCachedContent: hasCachedContent)
    }
    
    /// Downloads the latest stats report and refreshes the display
    private func downloadLatestStatsReport(languageCode: String, cacheFileURL: URL, hasCachedContent: Bool) {
        // Get the remote stats URL based on language
        let statsUrlKey = languageCode == "en" ? "reportUrl" : "reportUrl-\(languageCode)"
        let remoteStatsUrl = getPointerUrlData(keyValue: statsUrlKey)
        
        guard !remoteStatsUrl.isEmpty, let url = URL(string: remoteStatsUrl) else {
            print("⚠️ No valid stats URL found for language: \(languageCode)")
            if !hasCachedContent {
                showToast(message: "Stats not available for \(languageCode.uppercased())")
            }
            return
        }
        
        print("🔄 Downloading latest stats from: \(remoteStatsUrl)")
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Failed to download stats: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    if !hasCachedContent {
                        self.showToast(message: "Failed to load stats")
                    }
                }
                return
            }
            
            guard let data = data else {
                print("❌ No data received for stats")
                return
            }
            
            // STEP 3: Save to cache and refresh display
            do {
                try data.write(to: cacheFileURL)
                print("✅ Stats cache updated successfully")
                
                DispatchQueue.main.async {
                    if hasCachedContent {
                        // Refresh existing web view
                        self.refreshCurrentStatsWebView(with: cacheFileURL)
                    } else {
                        // Show web view for the first time
                        self.presentStatsWebView(url: cacheFileURL.absoluteString, title: "Stats Report")
                    }
                }
            } catch {
                print("❌ Failed to save stats cache: \(error.localizedDescription)")
            }
        }
        
        task.resume()
    }
    
    /// Presents the stats web view
    private func presentStatsWebView(url: String, title: String) {
        guard let hostingController = getHostingController() else {
            print("ERROR: Could not find hosting controller to present stats")
            return
        }
        
        guard let fileURL = URL(string: url) else {
            print("ERROR: Invalid stats URL: \(url)")
            return
        }
        
        let statsWebView = SwiftUIWebView(url: fileURL, title: title)
        let hostingWebViewController = UIHostingController(rootView: statsWebView)
        hostingWebViewController.modalPresentationStyle = UIModalPresentationStyle.pageSheet
        hostingWebViewController.overrideUserInterfaceStyle = .dark
        
        hostingController.present(hostingWebViewController, animated: true)
        print("✅ Successfully presented SwiftUI stats web view")
    }
    
    /// Refreshes the currently displayed stats web view
    private func refreshCurrentStatsWebView(with fileURL: URL) {
        // Find the currently presented web view and refresh it
        guard let hostingController = getHostingController(),
              let presentedController = hostingController.presentedViewController as? UIHostingController<SwiftUIWebView> else {
            print("⚠️ No current stats web view found to refresh")
            return
        }
        
        print("🔄 Refreshing current stats web view with updated content")
        
        // Create a new SwiftUI view with the updated URL
        let refreshedWebView = SwiftUIWebView(url: fileURL, title: "Stats Report")
        presentedController.rootView = refreshedWebView
    }
    
    /// Called when the user modifies the notes to track changes
    func notesDidChange() {
        hasNotesChanged = true
    }
    
    /// Check if notes have been modified since they were loaded
    private func notesHaveChanged() -> Bool {
        return hasNotesChanged && customNotes != originalNotes
    }
    
    /// Refreshes the band description when a background download completes
    private func refreshBandDescription() {
        print("DEBUG: refreshBandDescription() called for band: '\(bandName)'")
        
        // Reload the notes from the updated file
        let noteText = bandNotes.getDescription(bandName: bandName)
        englishDescriptionText = noteText
        customNotes = noteText
        
        print("DEBUG: Refreshed description for '\(bandName)': '\(noteText.prefix(50))...' (length: \(noteText.count))")
        
        // Check for links that make text non-editable (matching original logic)
        if customNotes.contains("!!!!https://") {
            doNotSaveText = true
            isNotesEditable = false
            customNotes = customNotes.replacingOccurrences(of: "!!!!https://", with: "https://")
            print("DEBUG: Refreshed notes contain links - set to read-only for '\(bandName)'")
        } else {
            doNotSaveText = false
            isNotesEditable = true
            print("DEBUG: Refreshed notes are editable for '\(bandName)'")
        }
        
        // Add noteworthy prefix if exists
        if !noteWorthy.isEmpty {
            customNotes = "\n" + customNotes
            englishDescriptionText = "\n" + englishDescriptionText
            print("DEBUG: Refreshed notes have noteworthy prefix for '\(bandName)'")
        }
        
        // Handle translation if supported
        if #available(iOS 18.0, *) {
            if BandDescriptionTranslator.shared.isTranslationSupported() {
                print("DEBUG: Displaying refreshed description in current language for '\(bandName)'")
                displayDescriptionInCurrentLanguage()
            }
        }
        
        print("DEBUG: Final refreshed customNotes for '\(bandName)': '\(noteText.prefix(50))...' (length: \(noteText.count))")
    }
}

// MARK: - String Extensions
extension String {
    var isNumeric: Bool {
        return Double(self) != nil
    }
    
    func isDouble() -> Bool {
        return Double(self) != nil
    }
}

// MARK: - SwiftUI Web View
struct SwiftUIWebView: View {
    let url: URL
    let title: String
    @State private var webView: WKWebView = WKWebView()
    @State private var isLoading: Bool = true
    @State private var progress: Double = 0.0
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @Environment(\.presentationMode) var presentationMode
    
    init(url: URL, title: String) {
        self.url = url
        self.title = title
        
        // Set navigation bar appearance immediately on init
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.black
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor.white
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress Bar
                if isLoading && progress < 1.0 {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(.green)
                        .frame(height: 2)
                }
                
                // WebView
                WebViewRepresentable(
                    webView: webView,
                    url: url,
                    isLoading: $isLoading,
                    progress: $progress,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward
                )
                .equatable() // Prevent unnecessary updates
                .background(Color.black)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                    .font(.system(size: 17, weight: .semibold))
                    .background(Color.clear)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Back button
                        Button(action: {
                            webView.goBack()
                        }) {
                            Image(systemName: "chevron.backward")
                                .foregroundColor(canGoBack ? .white : .gray)
                                .font(.system(size: 16, weight: .medium))
                        }
                        .disabled(!canGoBack)
                        
                        // Forward button
                        Button(action: {
                            webView.goForward()
                        }) {
                            Image(systemName: "chevron.forward")
                                .foregroundColor(canGoForward ? .white : .gray)
                                .font(.system(size: 16, weight: .medium))
                        }
                        .disabled(!canGoForward)
                        
                        // Reload button
                        Button(action: {
                            webView.reload()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }
}

// MARK: - WebKit UIViewRepresentable
struct WebViewRepresentable: UIViewRepresentable, Equatable {
    let webView: WKWebView
    let url: URL
    @Binding var isLoading: Bool
    @Binding var progress: Double
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    
    // Equatable implementation to prevent unnecessary updates
    static func == (lhs: WebViewRepresentable, rhs: WebViewRepresentable) -> Bool {
        return lhs.url == rhs.url // Only update if URL actually changes
    }
    
    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.backgroundColor = .black
        webView.backgroundColor = .black
        
        // Configure user agent for better compatibility
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        
        // Add observers for loading state and progress
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.isLoading), options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.canGoBack), options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.canGoForward), options: .new, context: nil)
        
        // Create request with proper headers
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        // Load the URL once
        print("DEBUG: Loading URL in WKWebView: \(url.absoluteString)")
        webView.load(request)
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Don't reload - the URL is loaded once in makeUIView
        // Reloading here causes infinite loops
        print("DEBUG: SwiftUI called updateUIView (but not reloading)")
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewRepresentable
        
        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }
        
        deinit {
            // Clean up observers
            parent.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.isLoading))
            parent.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
            parent.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack))
            parent.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward))
        }
        
        // Observe changes in WKWebView properties
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            DispatchQueue.main.async {
                if keyPath == #keyPath(WKWebView.isLoading) {
                    self.parent.isLoading = self.parent.webView.isLoading
                } else if keyPath == #keyPath(WKWebView.estimatedProgress) {
                    self.parent.progress = self.parent.webView.estimatedProgress
                } else if keyPath == #keyPath(WKWebView.canGoBack) {
                    self.parent.canGoBack = self.parent.webView.canGoBack
                } else if keyPath == #keyPath(WKWebView.canGoForward) {
                    self.parent.canGoForward = self.parent.webView.canGoForward
                }
            }
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.progress = 0.0
            }
            print("DEBUG: WebView started loading: \(webView.url?.absoluteString ?? "unknown")")
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.progress = 1.0
            }
            print("DEBUG: WebView finished loading: \(webView.url?.absoluteString ?? "unknown")")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
            print("ERROR: WebView provisional navigation failed: \(error.localizedDescription)")
            print("ERROR: Failed URL: \(webView.url?.absoluteString ?? "unknown")")
            if let nsError = error as NSError? {
                print("ERROR: Error code: \(nsError.code), domain: \(nsError.domain)")
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
            print("ERROR: WebView navigation failed: \(error.localizedDescription)")
            print("ERROR: Failed URL: \(webView.url?.absoluteString ?? "unknown")")
            if let nsError = error as NSError? {
                print("ERROR: Error code: \(nsError.code), domain: \(nsError.domain)")
            }
        }
    }
}


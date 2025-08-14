//
//  DetailViewModel.swift
//  70K Bands
//
//  Created by Assistant on 1/14/25.
//  Copyright (c) 2025 Ron Dorn. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

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
}

// MARK: - DetailViewModel

class DetailViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var bandName: String
    @Published var bandImage: UIImage?
    @Published var customNotes: String = ""
    @Published var isEditingNotes: Bool = false
    @Published var selectedPriority: Int = 0 {
        didSet {
            savePriority()
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
    @Published var showTranslationUI: Bool = false
    
    // Notes editing
    @Published var isNotesEditable: Bool = true
    
    // Navigation
    @Published var canNavigatePrevious: Bool = false
    @Published var canNavigateNext: Bool = false
    
    // Toast messaging
    @Published var toastManager = ToastManager()
    
    // Swipe navigation state
    private var blockSwiping: Bool = false
    
    // Computed properties
    var hasAnyLinks: Bool {
        !officialUrl.isEmpty || !wikipediaUrl.isEmpty || !youtubeUrl.isEmpty || !metalArchivesUrl.isEmpty
    }
    
    var hasBandDetails: Bool {
        !country.isEmpty || !genre.isEmpty || !lastOnCruise.isEmpty || !noteWorthy.isEmpty
    }
    
    var priorityImageName: String {
        return getPriorityGraphic(selectedPriority)
    }
    
    var noteFontSizeLarge: Bool {
        return getNotesFontSizeLargeValue()
    }
    
    // MARK: - Private Properties
    private let dataHandle = dataHandler()
    private let bandNameHandle = bandNamesHandler()
    private let schedule = scheduleHandler()
    private let attendedHandle = ShowsAttended()
    private let bandNotes = CustomBandDescription()
    private var bandPriorityStorage: [String: Int] = [:]
    private var englishDescriptionText: String = ""
    private var doNotSaveText: Bool = false
    
    // Directory path for saving custom notes
    private var directoryPath: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath
    }
    
    // MARK: - Initialization
    
    init(bandName: String) {
        self.bandName = bandName
        loadInitialData()
        
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
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name("ForceDetailRefresh"), object: nil)
    }
    
    // MARK: - Public Methods
    
    func loadBandData() {
        print("DEBUG: loadBandData() called for band: '\(bandName)'")
        
        // Ensure we're on the main thread for UI updates
        DispatchQueue.main.async {
            self.loadBandImage()
            self.loadBandDetails()
            self.loadBandLinks()
            self.loadScheduleEvents()
            self.loadNotes()
            self.loadPriority()
            self.setupTranslationButton()
            self.updateNavigationState()
            
            print("DEBUG: loadBandData() completed for band: '\(self.bandName)'")
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
        
        // Post notifications for UI refresh (same as original DetailViewController)
        NotificationCenter.default.post(name: Notification.Name(rawValue: "RefreshDisplay"), object: nil)
        NotificationCenter.default.post(name: Notification.Name("DetailDidUpdate"), object: nil)
        
        print("DEBUG: toggleAttendedStatus completed successfully")
    }
    
    func translateText() {
        guard #available(iOS 18.0, *) else { return }
        
        print("DEBUG: Starting native SwiftUI translation for band: \(bandName)")
        
        // Set flag to show translation UI
        showTranslationUI = true
    }
    
    func onTranslationComplete(translatedText: String) {
        print("DEBUG: Translation completed with text length: \(translatedText.count)")
        
        // Update the notes with translated text
        customNotes = translatedText
        
        // Mark as translated and update language preference
        if #available(iOS 18.0, *) {
            let currentLangCode = BandDescriptionTranslator.shared.getCurrentLanguageCode()
            BandDescriptionTranslator.shared.currentLanguagePreference = currentLangCode
            BandDescriptionTranslator.shared.markBandAsTranslated(bandName)
        }
        
        // Update button state
        updateTranslationButtonState()
        
        // Hide translation UI
        showTranslationUI = false
        
        // Show success toast
        toastManager.show(message: "✅ Translation completed", placeHigh: false)
    }
    
    func restoreToEnglish() {
        guard #available(iOS 18.0, *) else { return }
        
        print("DEBUG: Restoring to English for band: \(bandName)")
        
        // Get the current language code to know which cache to delete
        let currentLanguageCode = BandDescriptionTranslator.shared.getCurrentLanguageCode()
        
        // Show loading toast
        toastManager.show(message: "🔄 Restoring to English...", placeHigh: false)
        
        // Use the comprehensive restore method
        BandDescriptionTranslator.shared.restoreToEnglish(
            for: bandName,
            currentLanguage: currentLanguageCode,
            bandNotes: bandNotes
        ) { [weak self] englishText in
            guard let self = self else { return }
            
            // Reset language preference to English FIRST
            BandDescriptionTranslator.shared.currentLanguagePreference = "EN"
            
            if let englishText = englishText {
                // Update both the display text and stored English text
                self.customNotes = englishText
                self.englishDescriptionText = englishText
                
                print("DEBUG: Successfully restored to English for \(self.bandName)")
                self.toastManager.show(message: "✅ Restored to English", placeHigh: false)
            } else {
                // Fallback to existing English text if download failed
                self.customNotes = self.englishDescriptionText
                print("DEBUG: Fallback to existing English text for \(self.bandName)")
                self.toastManager.show(message: "⚠️ Restored to cached English", placeHigh: false)
            }
            
            // Force a button refresh
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updateTranslationButtonState()
            }
        }
    }
    
    func handleOrientationChange() {
        // Handle orientation change logic if needed
        loadBandDetails() // Refresh details display based on orientation
    }
    
    func saveNotes() {
        guard !bandName.isEmpty else { return }
        
        print("DEBUG: Saving notes for band: \(bandName)")
        
        let custCommentFile = directoryPath.appendingPathComponent("\(bandName)_comment.note-cust")
        
        // Check various conditions that prevent saving (matching original logic)
        if customNotes.starts(with: "Comment text is not available yet") {
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
        
        print("DEBUG: Saving notes for specific band: \(specificBandName)")
        
        let custCommentFile = directoryPath.appendingPathComponent("\(specificBandName)_comment.note-cust")
        
        // Check various conditions that prevent saving (matching original logic)
        if customNotes.starts(with: "Comment text is not available yet") {
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
        bandPriorityStorage = dataHandle.readFile(dateWinnerPassed: "")
        attendedHandle.loadShowsAttended()
    }
    
    private func loadBandImage() {
        let imageURL = CombinedImageListHandler.shared.getImageUrl(for: bandName)
        print("Loading image for \(bandName) from URL: \(imageURL)")
        
        guard !imageURL.isEmpty && imageURL != "http://" else {
            DispatchQueue.main.async {
                self.bandImage = UIImage(named: "70000TonsLogo")
            }
            return
        }
        
        let imageHandle = imageHandler()
        
        if isInternetAvailable() {
            let cachedImage = imageHandle.displayImage(urlString: imageURL, bandName: bandName)
            DispatchQueue.main.async {
                self.bandImage = cachedImage
            }
            
            if cachedImage == UIImage(named: "70000TonsLogo") {
                downloadAndCacheImage(imageURL: imageURL, imageHandle: imageHandle)
            }
        } else {
            loadImageFromCache(imageURL: imageURL, imageHandle: imageHandle)
        }
    }
    
    private func downloadAndCacheImage(imageURL: String, imageHandle: imageHandler) {
        imageHandle.downloadAndCacheImage(urlString: imageURL, bandName: bandName) { [weak self] processedImage in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let image = processedImage {
                    self.bandImage = image
                } else {
                    self.bandImage = UIImage(named: "70000TonsLogo")
                }
            }
        }
    }
    
    private func loadImageFromCache(imageURL: String, imageHandle: imageHandler) {
        let imageStore = URL(fileURLWithPath: getDocumentsDirectory().appendingPathComponent(bandName + ".png"))
        
        if let imageData = UIImage(contentsOfFile: imageStore.path) {
            let processedImage = imageHandle.processImage(imageData, urlString: imageURL)
            DispatchQueue.main.async {
                self.bandImage = processedImage
            }
        } else {
            DispatchQueue.main.async {
                self.bandImage = UIImage(named: "70000TonsLogo")
            }
        }
    }
    
    private func loadBandDetails() {
        print("DEBUG: loadBandDetails() called for band: '\(bandName)'")
        
        // Only show details in portrait or on iPad
        if UIApplication.shared.statusBarOrientation == .portrait || UIDevice.current.userInterfaceIdiom == .pad {
            country = bandNameHandle.getBandCountry(bandName)
            genre = bandNameHandle.getBandGenre(bandName)
            lastOnCruise = bandNameHandle.getPriorYears(bandName)
            noteWorthy = bandNameHandle.getBandNoteWorthy(bandName)
            
            print("DEBUG: loadBandDetails() for '\(bandName)' - country: '\(country)', genre: '\(genre)', lastOnCruise: '\(lastOnCruise)', noteWorthy: '\(noteWorthy)'")
        } else {
            // Hide details in landscape on iPhone
            country = ""
            genre = ""
            lastOnCruise = ""
            noteWorthy = ""
            print("DEBUG: loadBandDetails() for '\(bandName)' - hiding details in landscape")
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
        print("DEBUG: loadScheduleEvents() called for band: \(bandName)")
        print("DEBUG: loadScheduleEvents() - reloading attended data first")
        attendedHandle.loadShowsAttended()  // Force reload of attended data
        scheduleEvents = []
        
        schedule.getCachedData()
        
        if let bandSchedule = schedule.schedulingData[bandName], !bandSchedule.isEmpty {
            let sortedKeys = bandSchedule.keys.sorted()
            
            for timeIndex in sortedKeys {
                let location = schedule.getData(bandName, index: timeIndex, variable: locationField)
                let day = monthDateRegionalFormatting(dateValue: schedule.getData(bandName, index: timeIndex, variable: dayField))
                let startTime = schedule.getData(bandName, index: timeIndex, variable: startTimeField)
                let endTime = schedule.getData(bandName, index: timeIndex, variable: endTimeField)
                let eventType = schedule.getData(bandName, index: timeIndex, variable: typeField)
                let notes = schedule.getData(bandName, index: timeIndex, variable: notesField)
                
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
                print("DEBUG: loadScheduleEvents() - attended status for \(bandName) at \(location): '\(attendedStatus)'")
                
                let attendedIcon: UIImage = {
                    switch attendedStatus {
                    case sawAllStatus:
                        let icon = UIImage(named: "icon-seen") ?? UIImage()
                        print("DEBUG: sawAllStatus - using icon-seen, got: \(icon)")
                        return icon
                    case sawSomeStatus:
                        let icon = UIImage(named: "icon-seen-partial") ?? UIImage()
                        print("DEBUG: sawSomeStatus - trying icon-seen-partial, got: \(icon)")
                        return icon
                    case sawNoneStatus:
                        print("DEBUG: sawNoneStatus - returning empty icon")
                        return UIImage() // No icon for "did not attend"
                    default:
                        print("DEBUG: Unknown status '\(attendedStatus)' - returning empty icon")
                        return UIImage() // Default empty icon
                    }
                }()
                
                print("DEBUG: Final attended status for \(bandName) at \(location): '\(attendedStatus)' -> icon size: \(attendedIcon.size)")
                let eventTypeIcon = getEventTypeIcon(eventType: eventType, eventName: bandName)
                
                var dayText = ""
                if day == "Day 1" {
                    dayText = "1"
                } else if day == "Day 2" {
                    dayText = "2"
                } else if day == "Day 3" {
                    dayText = "3"
                } else if day == "Day 4" {
                    dayText = "4"
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
                    rawLocation: location  // Keep original location without venue suffix for attendance tracking
                )
                
                scheduleEvents.append(event)
            }
        }
    }
    
    private func loadNotes() {
        print("DEBUG: loadNotes() called for band: '\(bandName)'")
        
        let noteText = bandNotes.getDescription(bandName: bandName)
        englishDescriptionText = noteText
        customNotes = noteText
        
        print("DEBUG: Loaded notes for '\(bandName)': '\(noteText.prefix(50))...' (length: \(noteText.count))")
        
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
                           noteText.starts(with: "Comment text is not available yet") ||
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
            let commentFile = directoryPath.appendingPathComponent(commentFileName)
            
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
        guard #available(iOS 18.0, *) else { return }
        
        let currentLanguageCode = BandDescriptionTranslator.shared.getCurrentLanguageCode()
        
        if currentLanguageCode != "EN" &&
           BandDescriptionTranslator.shared.hasTranslatedCacheFile(for: bandName, targetLanguage: currentLanguageCode) {
            
            BandDescriptionTranslator.shared.loadTranslatedTextFromDisk(for: bandName, targetLanguage: currentLanguageCode) { [weak self] translatedText in
                if let translatedText = translatedText {
                    self?.customNotes = translatedText
                    BandDescriptionTranslator.shared.currentLanguagePreference = currentLanguageCode
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self?.updateTranslationButtonState()
                    }
                } else {
                    self?.customNotes = self?.englishDescriptionText ?? ""
                    BandDescriptionTranslator.shared.currentLanguagePreference = "EN"
                }
            }
        } else {
            customNotes = englishDescriptionText
            BandDescriptionTranslator.shared.currentLanguagePreference = "EN"
        }
    }
    
    private func loadPriority() {
        print("DEBUG: loadPriority() called for band: '\(bandName)'")
        
        // Always reload priority data from the global data source to get latest changes
        bandPriorityStorage = dataHandle.readFile(dateWinnerPassed: "")
        
        if let priority = bandPriorityStorage[bandName] {
            selectedPriority = priority
            print("DEBUG: loadPriority() for '\(bandName)' - found priority: \(priority)")
        } else {
            selectedPriority = 0
            bandPriorityStorage[bandName] = 0
            print("DEBUG: loadPriority() for '\(bandName)' - no priority found, defaulting to 0")
        }
    }
    
    private func savePriority() {
        bandPriorityStorage[bandName] = selectedPriority
        dataHandle.addPriorityData(bandName, priority: selectedPriority)
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: "RefreshDisplay"), object: nil)
        NotificationCenter.default.post(name: Notification.Name("DetailDidUpdate"), object: nil)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            masterView?.refreshDataWithBackgroundUpdate(reason: "Detail view priority update")
        }
    }
    
    private func setupTranslationButton() {
        guard #available(iOS 18.0, *) else {
            showTranslationButton = false
            return
        }
        
        guard BandDescriptionTranslator.shared.isTranslationSupported() else {
            showTranslationButton = false
            return
        }
        
        let currentLangCode = BandDescriptionTranslator.shared.getCurrentLanguageCode()
        showTranslationButton = currentLangCode != "EN"
        
        if showTranslationButton {
            updateTranslationButtonState()
        }
    }
    
    private func updateTranslationButtonState() {
        guard #available(iOS 18.0, *) else { return }
        
        let currentLangCode = BandDescriptionTranslator.shared.getCurrentLanguageCode()
        let currentText = customNotes
        
        isCurrentTextTranslated = isCurrentTextActuallyTranslated(currentText: currentText) ||
                                  (currentLangCode != "EN" && BandDescriptionTranslator.shared.hasTranslatedCacheFile(for: bandName, targetLanguage: currentLangCode))
        
        if isCurrentTextTranslated {
            restoreButtonText = BandDescriptionTranslator.shared.getLocalizedRestoreButtonText(for: currentLangCode)
        } else {
            translateButtonText = BandDescriptionTranslator.shared.getLocalizedTranslateButtonText(for: currentLangCode)
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
            "Vertaald uit het Engels",
            "Traduit de l'anglais",
            "Käännetty englannista",
            "Traduzido do inglês",
            "Traducido del inglés"
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
                message = "End of List" // Use simple message for now
            } else {
                message = "Already at Start" // Use simple message for now
            }
            print("DEBUG: Showing boundary message: \(message)")
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
            print("DEBUG: Updated bandName from '\(currentBand)' to '\(self.bandName)'")
            
            toastManager.show(message: message, placeHigh: false)
            
            // Complete reload like original viewDidLoad() + viewWillAppear()
            DispatchQueue.main.async {
                print("DEBUG: Loading data for new band: '\(self.bandName)'")
                self.loadBandData()
                
                // Force UI update to ensure notes are refreshed
                self.objectWillChange.send()
            }
            
            // Post notifications for UI refresh
            NotificationCenter.default.post(name: Notification.Name(rawValue: "RefreshDisplay"), object: nil)
            NotificationCenter.default.post(name: Notification.Name("DetailDidUpdate"), object: nil)
        }
    }
    
    private func isInternetAvailable() -> Bool {
        return NetworkStatusManager.shared.isInternetAvailable
    }
    
    private func showToast(message: String) {
        toastManager.show(message: message, placeHigh: false)
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

//
//  DetailViewModel.swift
//  70000TonsBands
//
//  Created by Assistant on 12/19/24.
//  Copyright (c) 2024 Ron Dorn. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

class DetailViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var priority: Int = 0
    @Published var bandLogo: UIImage?
    @Published var country: String = ""
    @Published var genre: String = ""
    @Published var lastOnCruise: String = ""
    @Published var noteWorthy: String = ""
    @Published var events: [BandEvent] = []
    @Published var customNotes: String = ""
    @Published var displayedNotes: String = ""
    @Published var hasTranslation: Bool = false
    @Published var isShowingTranslation: Bool = false
    
    // Link URLs
    @Published var officialURL: String = ""
    @Published var wikipediaURL: String = ""
    @Published var youtubeURL: String = ""
    @Published var metalArchivesURL: String = ""
    
    // MARK: - Private Properties
    private let bandName: String
    private let schedule = scheduleHandler()
    private let dataHandle = dataHandler()
    private let bandNameHandle = bandNamesHandler()
    private let attendedHandle = ShowsAttended()
    private let bandNotes = CustomBandDescription()
    @available(iOS 18.0, *)
    private var bandDescriptionTranslator: BandDescriptionTranslator? {
        return BandDescriptionTranslator.shared
    }
    
    private var englishNotes: String = ""
    private var translatedNotes: String = ""
    
    // MARK: - Computed Properties
    var hasAnyLinks: Bool {
        return !officialURL.isEmpty || !wikipediaURL.isEmpty || !youtubeURL.isEmpty || !metalArchivesURL.isEmpty
    }
    
    // MARK: - Initialization
    init(bandName: String) {
        self.bandName = bandName
    }
    
    // MARK: - Public Methods
    func loadData() {
        Task {
            await loadBandData()
        }
    }
    
    func updatePriority(_ newPriority: Int) {
        priority = newPriority
        // Use the dataHandler to set band priority
        dataHandle.addPriorityData(bandName, priority: newPriority)
        
        // Save to iCloud
        let iCloudHandle = iCloudDataHandler()
        iCloudHandle.writeAllPriorityData()
        
        // Update notifications
        let localNotification = localNoticationHandler()
        localNotification.clearNotifications()
        localNotification.addNotifications()
    }
    
    func saveCustomNotes(_ notes: String) {
        customNotes = notes
        englishNotes = notes
        displayedNotes = notes
        
        // Save to disk using the same method as DetailViewController
        let documentsPath = getDocumentsDirectory()
        let commentFileName = bandNotes.getNoteFileName(bandName: bandName)
        let custCommentFilePath = documentsPath.appendingPathComponent(commentFileName)
        let custCommentFile = URL(fileURLWithPath: custCommentFilePath as String)
        
        do {
            try notes.write(to: custCommentFile, atomically: false, encoding: String.Encoding.utf8)
        } catch {
            print("Error saving custom notes: \(error.localizedDescription)")
        }
        
        // Clear translation state
        translatedNotes = ""
        hasTranslation = false
        isShowingTranslation = false
    }
    
    func translateNotes() {
        guard !customNotes.isEmpty else { return }
        
        // Use the existing translation system if available
        if #available(iOS 18.0, *) {
            // For now, just mark that translation is available
            // The actual translation would use the showTranslationOverlay method
            translatedNotes = "Translation available - use overlay to translate"
            hasTranslation = true
        }
    }
    
    func toggleTranslation() {
        guard hasTranslation else { return }
        
        isShowingTranslation.toggle()
        displayedNotes = isShowingTranslation ? translatedNotes : englishNotes
    }
    
    func shareData() {
        var shareText = "Band: \(bandName)\n\n"
        
        // Add priority
        switch priority {
        case 1: shareText += "Priority: Must See ⭐\n"
        case 2: shareText += "Priority: Might See ⭐\n"
        case 3: shareText += "Priority: Won't See ❌\n"
        default: shareText += "Priority: Unknown\n"
        }
        
        // Add band info
        if !country.isEmpty {
            shareText += "Country: \(country)\n"
        }
        if !genre.isEmpty {
            shareText += "Genre: \(genre)\n"
        }
        
        // Add events
        if !events.isEmpty {
            shareText += "\nEvents:\n"
            for event in events {
                shareText += "• \(event.location)"
                if let startTime = event.startTime {
                    shareText += " - \(DateFormatter.timeFormatter.string(from: startTime))"
                }
                shareText += "\n"
            }
        }
        
        // Add custom notes
        if !customNotes.isEmpty {
            shareText += "\nNotes: \(customNotes)\n"
        }
        
        shareText += "\nShared from 70K Bands App"
        
        // Present share sheet
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            if let rootVC = window.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
    }
    
    // MARK: - Private Methods
    private func loadBandData() async {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                // Load priority
                let currentPriority = self.dataHandle.getPriorityData(self.bandName)
                
                // Load band information
                let bandInfo = self.dataHandle.getBandInfo(bandName: self.bandName)
                
                // Load events
                let bandEvents = self.loadBandEvents()
                
                // Load custom notes
                let notes = self.bandNotes.getDescription(bandName: self.bandName)
                
                // Load band logo
                let logo = self.loadBandLogo()
                
                // Load URLs
                let urls = self.loadBandURLs()
                
                DispatchQueue.main.async {
                    self.priority = currentPriority
                    self.country = bandInfo.country
                    self.genre = bandInfo.genre
                    self.lastOnCruise = bandInfo.lastOnCruise
                    self.noteWorthy = bandInfo.noteWorthy
                    self.events = bandEvents
                    self.customNotes = notes
                    self.englishNotes = notes
                    self.displayedNotes = notes
                    self.bandLogo = logo
                    self.officialURL = urls.official
                    self.wikipediaURL = urls.wikipedia
                    self.youtubeURL = urls.youtube
                    self.metalArchivesURL = urls.metalArchives
                    
                    // Translation checking would be implemented here if needed
                    // For now, translation is handled through the translateNotes() method
                    
                    continuation.resume()
                }
            }
        }
    }
    
    private func loadBandEvents() -> [BandEvent] {
        let scheduleData = schedule.getBandSchedule(bandName: bandName)
        var events: [BandEvent] = []
        
        for eventData in scheduleData {
            // Parse event data (this would need to match the existing data structure)
            let event = BandEvent(
                location: eventData.location ?? "",
                eventType: eventData.eventType ?? "",
                notes: eventData.notes ?? "",
                startTime: eventData.startTime,
                endTime: eventData.endTime,
                day: eventData.day ?? "",
                locationColor: eventData.locationColor ?? UIColor.blue,
                isAttended: false // For now, set to false - would need to implement proper event tracking
            )
            events.append(event)
        }
        
        return events
    }
    
    private func loadBandLogo() -> UIImage? {
        // Try to load band logo from cache or download
        let imageHandle = imageHandler()
        // Use the existing displayImage method which handles caching
        return imageHandle.displayImage(urlString: "", bandName: bandName)
    }
    
    private func loadBandURLs() -> (official: String, wikipedia: String, youtube: String, metalArchives: String) {
        // Load URLs from the data handler
        let bandInfo = dataHandle.getBandInfo(bandName: bandName)
        
        return (
            official: bandInfo.officialURL ?? "",
            wikipedia: bandInfo.wikipediaURL ?? "",
            youtube: bandInfo.youtubeURL ?? "",
            metalArchives: bandInfo.metalArchivesURL ?? ""
        )
    }
}

// MARK: - Supporting Types

extension dataHandler {
    func getBandInfo(bandName: String) -> BandInfo {
        // This would integrate with the existing data handler
        // For now, return empty data structure
        return BandInfo(
            country: getCountryForBand(bandName: bandName) ?? "",
            genre: getGenreForBand(bandName: bandName) ?? "",
            lastOnCruise: getLastOnCruiseForBand(bandName: bandName) ?? "",
            noteWorthy: getNoteWorthyForBand(bandName: bandName) ?? "",
            officialURL: getOfficialURLForBand(bandName: bandName),
            wikipediaURL: getWikipediaURLForBand(bandName: bandName),
            youtubeURL: getYouTubeURLForBand(bandName: bandName),
            metalArchivesURL: getMetalArchivesURLForBand(bandName: bandName)
        )
    }
    
    // These methods would need to be implemented to match existing data access patterns
    private func getCountryForBand(bandName: String) -> String? {
        // Implementation would access existing data structures
        return nil
    }
    
    private func getGenreForBand(bandName: String) -> String? {
        // Implementation would access existing data structures
        return nil
    }
    
    private func getLastOnCruiseForBand(bandName: String) -> String? {
        // Implementation would access existing data structures
        return nil
    }
    
    private func getNoteWorthyForBand(bandName: String) -> String? {
        // Implementation would access existing data structures
        return nil
    }
    
    private func getOfficialURLForBand(bandName: String) -> String? {
        // Implementation would access existing data structures
        return nil
    }
    
    private func getWikipediaURLForBand(bandName: String) -> String? {
        // Implementation would access existing data structures
        return nil
    }
    
    private func getYouTubeURLForBand(bandName: String) -> String? {
        // Implementation would access existing data structures
        return nil
    }
    
    private func getMetalArchivesURLForBand(bandName: String) -> String? {
        // Implementation would access existing data structures
        return nil
    }
}

struct BandInfo {
    let country: String
    let genre: String
    let lastOnCruise: String
    let noteWorthy: String
    let officialURL: String?
    let wikipediaURL: String?
    let youtubeURL: String?
    let metalArchivesURL: String?
}

// MARK: - Schedule Data Extensions

extension scheduleHandler {
    func getBandSchedule(bandName: String) -> [ScheduleEvent] {
        // This would integrate with the existing schedule handler
        // Return schedule events for the band
        return []
    }
    
    func getEventStartTime(_ event: ScheduleEvent) -> Date? {
        // Return the start time for an event
        return event.startTime
    }
}

struct ScheduleEvent {
    let eventId: String?
    let location: String?
    let eventType: String?
    let notes: String?
    let startTime: Date?
    let endTime: Date?
    let day: String?
    let locationColor: UIColor?
}

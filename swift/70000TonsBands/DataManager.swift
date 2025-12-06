//
//  DataManager.swift
//  70000 Tons Bands
//
//  Created by Data Abstraction Layer
//  Provides a unified interface for all data persistence operations.
//  When switching from Core Data to SQLite, only this file needs to change.
//

import Foundation
import CoreData

/// Protocol defining all data operations for the app
/// This abstraction allows swapping persistence backends without touching business logic
protocol DataManagerProtocol {
    // MARK: - Band Operations
    func fetchBands(forYear year: Int) -> [Band]
    func fetchBands() -> [Band]
    func fetchBand(byName name: String, eventYear year: Int) -> Band?
    func createOrUpdateBand(name: String, eventYear: Int, officialSite: String?, imageUrl: String?, youtube: String?, metalArchives: String?, wikipedia: String?, country: String?, genre: String?, noteworthy: String?, priorYears: String?) -> Band
    func deleteBand(_ band: Band)
    
    // MARK: - Event Operations
    func fetchEvents(forYear year: Int) -> [Event]
    func fetchEvents() -> [Event]
    func fetchEventsForBand(_ bandName: String, forYear year: Int) -> [Event]
    func createOrUpdateEvent(band: Band, timeIndex: Double, endTimeIndex: Double, location: String, date: String?, day: String?, startTime: String?, endTime: String?, eventType: String?, eventYear: Int, notes: String?, descriptionUrl: String?, eventImageUrl: String?) -> Event
    func deleteEvent(_ event: Event)
    func cleanupProblematicEvents(currentYear year: Int)
    
    // MARK: - User Priority Operations
    func fetchUserPriorities() -> [UserPriority]
    
    // MARK: - User Attendance Operations
    func fetchUserAttendances() -> [UserAttendance]
}

/// Core Data implementation of DataManagerProtocol
/// When switching to SQLite, create a new SQLiteDataManager class and swap it in the shared instance
class CoreDataDataManager: DataManagerProtocol {
    
    static let shared = CoreDataDataManager()
    private let coreDataManager = CoreDataManager.shared
    
    private init() {
        print("📊 DataManager: Using Core Data backend")
    }
    
    // MARK: - Band Operations
    
    func fetchBands(forYear year: Int) -> [Band] {
        return coreDataManager.fetchBands(forYear: Int32(year))
    }
    
    func fetchBands() -> [Band] {
        return coreDataManager.fetchBands()
    }
    
    func fetchBand(byName name: String, eventYear year: Int) -> Band? {
        return coreDataManager.fetchBand(byName: name, eventYear: Int32(year))
    }
    
    func createOrUpdateBand(name: String, eventYear: Int, officialSite: String?, imageUrl: String?, youtube: String?, metalArchives: String?, wikipedia: String?, country: String?, genre: String?, noteworthy: String?, priorYears: String?) -> Band {
        return coreDataManager.createOrUpdateBand(
            name: name,
            eventYear: Int32(eventYear),
            officialSite: officialSite,
            imageUrl: imageUrl,
            youtube: youtube,
            metalArchives: metalArchives,
            wikipedia: wikipedia,
            country: country,
            genre: genre,
            noteworthy: noteworthy,
            priorYears: priorYears
        )
    }
    
    func deleteBand(_ band: Band) {
        coreDataManager.deleteBand(band)
    }
    
    // MARK: - Event Operations
    
    func fetchEvents(forYear year: Int) -> [Event] {
        return coreDataManager.fetchEvents(forYear: Int32(year))
    }
    
    func fetchEvents() -> [Event] {
        return coreDataManager.fetchEvents()
    }
    
    func fetchEventsForBand(_ bandName: String, forYear year: Int) -> [Event] {
        return coreDataManager.fetchEventsForBand(bandName, forYear: Int32(year))
    }
    
    func createOrUpdateEvent(band: Band, timeIndex: Double, endTimeIndex: Double, location: String, date: String?, day: String?, startTime: String?, endTime: String?, eventType: String?, eventYear: Int, notes: String?, descriptionUrl: String?, eventImageUrl: String?) -> Event {
        return coreDataManager.createOrUpdateEvent(
            band: band,
            timeIndex: timeIndex,
            endTimeIndex: endTimeIndex,
            location: location,
            date: date,
            day: day,
            startTime: startTime,
            endTime: endTime,
            eventType: eventType,
            eventYear: Int32(eventYear),
            notes: notes,
            descriptionUrl: descriptionUrl,
            eventImageUrl: eventImageUrl
        )
    }
    
    func deleteEvent(_ event: Event) {
        coreDataManager.deleteEvent(event)
    }
    
    func cleanupProblematicEvents(currentYear year: Int) {
        coreDataManager.cleanupProblematicEvents(currentYear: year)
    }
    
    // MARK: - User Priority Operations
    
    func fetchUserPriorities() -> [UserPriority] {
        return coreDataManager.fetchUserPriorities()
    }
    
    // MARK: - User Attendance Operations
    
    func fetchUserAttendances() -> [UserAttendance] {
        return coreDataManager.fetchUserAttendances()
    }
}

/// Public singleton access point
/// To switch from Core Data to SQLite: change CoreDataDataManager to SQLiteDataManager here
class DataManager {
    static let shared: DataManagerProtocol = CoreDataDataManager.shared
    
    private init() {}
}


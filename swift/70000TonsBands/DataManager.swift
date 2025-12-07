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
/// NOTE: Returns plain Swift structs (BandData, EventData, etc.) instead of Core Data objects
protocol DataManagerProtocol {
    // MARK: - Band Operations
    func fetchBands(forYear year: Int) -> [BandData]
    func fetchBands() -> [BandData]
    func fetchBand(byName name: String, eventYear year: Int) -> BandData?
    func createOrUpdateBand(name: String, eventYear: Int, officialSite: String?, imageUrl: String?, youtube: String?, metalArchives: String?, wikipedia: String?, country: String?, genre: String?, noteworthy: String?, priorYears: String?) -> BandData
    func deleteBand(name: String, eventYear: Int)
    
    // MARK: - Event Operations
    func fetchEvents(forYear year: Int) -> [EventData]
    func fetchEvents() -> [EventData]
    func fetchEventsForBand(_ bandName: String, forYear year: Int) -> [EventData]
    func fetchEvents(forYear year: Int, location: String?, eventType: String?) -> [EventData]  // For filtering by location/type
    func createOrUpdateEvent(bandName: String, timeIndex: Double, endTimeIndex: Double, location: String, date: String?, day: String?, startTime: String?, endTime: String?, eventType: String?, eventYear: Int, notes: String?, descriptionUrl: String?, eventImageUrl: String?) -> EventData
    func deleteEvent(bandName: String, timeIndex: Double, eventYear: Int)
    func cleanupProblematicEvents(currentYear year: Int)
    
    // MARK: - User Priority Operations
    func fetchUserPriorities() -> [UserPriorityData]
    func createOrUpdateUserPriority(bandName: String, eventYear: Int, priorityLevel: Int) -> UserPriorityData
    func deleteUserPriority(bandName: String, eventYear: Int)
    
    // MARK: - User Attendance Operations
    func fetchUserAttendances() -> [UserAttendanceData]
    func createOrUpdateUserAttendance(bandName: String, eventYear: Int, timeIndex: Double, attendanceStatus: Int) -> UserAttendanceData
    func deleteUserAttendance(bandName: String, eventYear: Int, timeIndex: Double)
}

/// Core Data implementation of DataManagerProtocol
/// Used ONLY for migration - converts Core Data objects to plain structs
/// All external code works with structs, not Core Data objects
class CoreDataDataManager: DataManagerProtocol {
    
    static let shared = CoreDataDataManager()
    private let coreDataManager = CoreDataManager.shared
    
    private init() {
        print("📊 DataManager: Using Core Data backend (MIGRATION ONLY)")
    }
    
    // MARK: - Band Operations
    
    func fetchBands(forYear year: Int) -> [BandData] {
        let bands = coreDataManager.fetchBands(forYear: Int32(year))
        return bands.map { BandData(from: $0) }
    }
    
    func fetchBands() -> [BandData] {
        let bands = coreDataManager.fetchBands()
        return bands.map { BandData(from: $0) }
    }
    
    func fetchBand(byName name: String, eventYear year: Int) -> BandData? {
        guard let band = coreDataManager.fetchBand(byName: name, eventYear: Int32(year)) else {
            return nil
        }
        return BandData(from: band)
    }
    
    func createOrUpdateBand(name: String, eventYear: Int, officialSite: String?, imageUrl: String?, youtube: String?, metalArchives: String?, wikipedia: String?, country: String?, genre: String?, noteworthy: String?, priorYears: String?) -> BandData {
        let band = coreDataManager.createOrUpdateBand(
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
        return BandData(from: band)
    }
    
    func deleteBand(name: String, eventYear: Int) {
        if let band = coreDataManager.fetchBand(byName: name, eventYear: Int32(eventYear)) {
            coreDataManager.deleteBand(band)
        }
    }
    
    // MARK: - Event Operations
    
    func fetchEvents(forYear year: Int) -> [EventData] {
        let events = coreDataManager.fetchEvents(forYear: Int32(year))
        return events.map { EventData(from: $0) }
    }
    
    func fetchEvents() -> [EventData] {
        let events = coreDataManager.fetchEvents()
        return events.map { EventData(from: $0) }
    }
    
    func fetchEventsForBand(_ bandName: String, forYear year: Int) -> [EventData] {
        let events = coreDataManager.fetchEventsForBand(bandName, forYear: Int32(year))
        return events.map { EventData(from: $0) }
    }
    
    func fetchEvents(forYear year: Int, location: String?, eventType: String?) -> [EventData] {
        var predicates: [NSPredicate] = []
        if let location = location {
            predicates.append(NSPredicate(format: "location == %@", location))
        }
        if let eventType = eventType {
            predicates.append(NSPredicate(format: "eventType == %@", eventType))
        }
        let compound = predicates.isEmpty ? NSPredicate(value: true) : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        let events = coreDataManager.fetchEvents(forYear: Int32(year), predicate: compound)
        return events.map { EventData(from: $0) }
    }
    
    func createOrUpdateEvent(bandName: String, timeIndex: Double, endTimeIndex: Double, location: String, date: String?, day: String?, startTime: String?, endTime: String?, eventType: String?, eventYear: Int, notes: String?, descriptionUrl: String?, eventImageUrl: String?) -> EventData {
        // For Core Data, we need to fetch/create the Band object
        let band = coreDataManager.createOrUpdateBand(
            name: bandName,
            eventYear: Int32(eventYear),
            officialSite: nil,
            imageUrl: nil,
            youtube: nil,
            metalArchives: nil,
            wikipedia: nil,
            country: nil,
            genre: nil,
            noteworthy: nil,
            priorYears: nil
        )
        let event = coreDataManager.createOrUpdateEvent(
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
        return EventData(from: event)
    }
    
    func deleteEvent(bandName: String, timeIndex: Double, eventYear: Int) {
        let events = coreDataManager.fetchEventsForBand(bandName, forYear: Int32(eventYear))
        if let event = events.first(where: { $0.timeIndex == timeIndex }) {
            coreDataManager.deleteEvent(event)
        }
    }
    
    func cleanupProblematicEvents(currentYear year: Int) {
        coreDataManager.cleanupProblematicEvents(currentYear: year)
    }
    
    // MARK: - User Priority Operations
    
    func fetchUserPriorities() -> [UserPriorityData] {
        let priorities = coreDataManager.fetchUserPriorities()
        return priorities.map { UserPriorityData(from: $0) }
    }
    
    func createOrUpdateUserPriority(bandName: String, eventYear: Int, priorityLevel: Int) -> UserPriorityData {
        // Core Data method not implemented yet - would need to add to CoreDataManager
        return UserPriorityData(bandName: bandName, eventYear: eventYear, priorityLevel: priorityLevel)
    }
    
    func deleteUserPriority(bandName: String, eventYear: Int) {
        // Core Data method not implemented yet - would need to add to CoreDataManager
    }
    
    // MARK: - User Attendance Operations
    
    func fetchUserAttendances() -> [UserAttendanceData] {
        let attendances = coreDataManager.fetchUserAttendances()
        return attendances.map { UserAttendanceData(from: $0) }
    }
    
    func createOrUpdateUserAttendance(bandName: String, eventYear: Int, timeIndex: Double, attendanceStatus: Int) -> UserAttendanceData {
        // Core Data method not implemented yet - would need to add to CoreDataManager
        return UserAttendanceData(bandName: bandName, eventYear: eventYear, timeIndex: timeIndex, attendanceStatus: attendanceStatus)
    }
    
    func deleteUserAttendance(bandName: String, eventYear: Int, timeIndex: Double) {
        // Core Data method not implemented yet - would need to add to CoreDataManager
    }
}

/// Public singleton access point
/// To switch from Core Data to SQLite: change CoreDataDataManager to SQLiteDataManager here
class DataManager {
    static let shared: DataManagerProtocol = SQLiteDataManager.shared
    
    private init() {}
}


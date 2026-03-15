//
//  DataManager.swift
//  70000 Tons Bands
//
//  Created by Data Abstraction Layer
//  Provides a unified interface for all data persistence operations.
//  When switching from Core Data to SQLite, only this file needs to change.
//

import Foundation

/// Protocol defining all data operations for the app
/// This abstraction allows swapping persistence backends without touching business logic
/// NOTE: Returns plain Swift structs (BandData, EventData, etc.) instead of Core Data objects
protocol DataManagerProtocol {
    // MARK: - Band Operations
    func fetchBands(forYear year: Int) -> [BandData]
    func fetchBands() -> [BandData]
    func fetchBand(byName name: String, eventYear year: Int) -> BandData?
    /// Only band list import (full artist CSV) should pass lineIndex; schedule/event import must not. Pass nil to leave lineIndex unchanged or set to nil.
    func createOrUpdateBand(name: String, eventYear: Int, officialSite: String?, imageUrl: String?, youtube: String?, metalArchives: String?, wikipedia: String?, country: String?, genre: String?, noteworthy: String?, priorYears: String?, lineIndex: Int?) -> BandData
    func createBandIfNotExists(name: String, eventYear: Int) -> Bool
    func deleteBand(name: String, eventYear: Int)
    /// Band names in canonical (artist CSV) order for QR encode/decode. lineIndex only; no fallback.
    func fetchBandNamesInCanonicalOrder(forYear year: Int) -> [String]
    /// Ensures only bands in the artist list have lineIndex set. Clears lineIndex for any band in this year not in the set (e.g. schedule-only entries).
    func clearLineIndexForBandsNotIn(eventYear year: Int, bandNamesInArtistList: Set<String>)
    
    // MARK: - Event Operations
    func fetchEvents(forYear year: Int) -> [EventData]
    func fetchEvents() -> [EventData]
    func fetchEventsForBand(_ bandName: String, forYear year: Int) -> [EventData]
    func fetchEvents(forYear year: Int, location: String?, eventType: String?) -> [EventData]  // For filtering by location/type
    func createOrUpdateEvent(bandName: String, timeIndex: Double, endTimeIndex: Double, location: String, date: String?, day: String?, startTime: String?, endTime: String?, eventType: String?, eventYear: Int, notes: String?, descriptionUrl: String?, eventImageUrl: String?) -> EventData
    func deleteEvent(bandName: String, timeIndex: Double, eventYear: Int)
    /// Replaces all events for the given year with the provided list (atomic: delete then insert in one transaction). Returns true only if the transaction committed; use this so checksum is not stored when DB write failed (e.g. locked).
    func replaceEvents(forYear year: Int, events: [EventData]) -> Bool
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

// Core Data implementation removed - all data now uses SQLite directly

/// Public singleton access point
/// To switch from Core Data to SQLite: change CoreDataDataManager to SQLiteDataManager here
class DataManager {
    static let shared: DataManagerProtocol = SQLiteDataManager.shared
    
    private init() {}
}


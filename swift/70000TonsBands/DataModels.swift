//
//  DataModels.swift
//  70000 Tons Bands
//
//  Plain Swift structs for data transfer
//  These replace Core Data NSManagedObject instances for thread-safe data handling
//

import Foundation
import CoreData

/// Band data model - thread-safe struct (no Core Data dependencies)
public struct BandData: Codable, Equatable, Hashable {
    let bandName: String
    let eventYear: Int
    let officialSite: String?
    let imageUrl: String?
    let youtube: String?
    let metalArchives: String?
    let wikipedia: String?
    let country: String?
    let genre: String?
    let noteworthy: String?
    let priorYears: String?
    
    public init(bandName: String, eventYear: Int, officialSite: String? = nil, imageUrl: String? = nil, 
         youtube: String? = nil, metalArchives: String? = nil, wikipedia: String? = nil,
         country: String? = nil, genre: String? = nil, noteworthy: String? = nil, priorYears: String? = nil) {
        self.bandName = bandName
        self.eventYear = eventYear
        self.officialSite = officialSite
        self.imageUrl = imageUrl
        self.youtube = youtube
        self.metalArchives = metalArchives
        self.wikipedia = wikipedia
        self.country = country
        self.genre = genre
        self.noteworthy = noteworthy
        self.priorYears = priorYears
    }
}

/// Event data model - thread-safe struct (no Core Data dependencies)
public struct EventData: Codable, Equatable, Hashable {
    let bandName: String
    let eventYear: Int
    let timeIndex: Double
    let endTimeIndex: Double
    let location: String
    let date: String?
    let day: String?
    let startTime: String?
    let endTime: String?
    let eventType: String?
    let notes: String?
    let descriptionUrl: String?
    let eventImageUrl: String?
    
    public init(bandName: String, eventYear: Int, timeIndex: Double, endTimeIndex: Double,
         location: String, date: String? = nil, day: String? = nil, startTime: String? = nil,
         endTime: String? = nil, eventType: String? = nil, notes: String? = nil,
         descriptionUrl: String? = nil, eventImageUrl: String? = nil) {
        self.bandName = bandName
        self.eventYear = eventYear
        self.timeIndex = timeIndex
        self.endTimeIndex = endTimeIndex
        self.location = location
        self.date = date
        self.day = day
        self.startTime = startTime
        self.endTime = endTime
        self.eventType = eventType
        self.notes = notes
        self.descriptionUrl = descriptionUrl
        self.eventImageUrl = eventImageUrl
    }
}

/// User priority data model - thread-safe struct (no Core Data dependencies)
public struct UserPriorityData: Codable, Equatable, Hashable {
    let bandName: String
    let eventYear: Int
    let priorityLevel: Int
    let updatedAt: Date?
    
    public init(bandName: String, eventYear: Int, priorityLevel: Int, updatedAt: Date? = nil) {
        self.bandName = bandName
        self.eventYear = eventYear
        self.priorityLevel = priorityLevel
        self.updatedAt = updatedAt
    }
}

/// User attendance data model - thread-safe struct (no Core Data dependencies)
public struct UserAttendanceData: Codable, Equatable, Hashable {
    let bandName: String
    let eventYear: Int
    let timeIndex: Double
    let attendanceStatus: Int
    let updatedAt: Date?
    
    public init(bandName: String, eventYear: Int, timeIndex: Double, attendanceStatus: Int, updatedAt: Date? = nil) {
        self.bandName = bandName
        self.eventYear = eventYear
        self.timeIndex = timeIndex
        self.attendanceStatus = attendanceStatus
        self.updatedAt = updatedAt
    }
}

// MARK: - Conversion Extensions (for backward compatibility during migration)

public extension BandData {
    /// Convert to legacy Core Data Band object (for compatibility with existing code)
    func toLegacyBand(context: NSManagedObjectContext) -> Band {
        let band = Band(context: context)
        band.bandName = self.bandName
        band.eventYear = Int32(self.eventYear)
        band.officialSite = self.officialSite
        band.imageUrl = self.imageUrl
        band.youtube = self.youtube
        band.metalArchives = self.metalArchives
        band.wikipedia = self.wikipedia
        band.country = self.country
        band.genre = self.genre
        band.noteworthy = self.noteworthy
        band.priorYears = self.priorYears
        return band
    }
    
    /// Create from legacy Core Data Band object
    init(from band: Band) {
        self.bandName = band.bandName ?? ""
        self.eventYear = Int(band.eventYear)
        self.officialSite = band.officialSite
        self.imageUrl = band.imageUrl
        self.youtube = band.youtube
        self.metalArchives = band.metalArchives
        self.wikipedia = band.wikipedia
        self.country = band.country
        self.genre = band.genre
        self.noteworthy = band.noteworthy
        self.priorYears = band.priorYears
    }
}

public extension EventData {
    /// Convert to legacy Core Data Event object (for compatibility with existing code)
    /// Note: This creates a detached Event object without a Band relationship
    func toLegacyEvent(context: NSManagedObjectContext) -> Event {
        let event = Event(context: context)
        // Note: Event has a 'band' relationship, not a direct 'bandName' property
        // For full conversion, you'd need to fetch/create the Band object
        event.eventYear = Int32(self.eventYear)
        event.timeIndex = self.timeIndex
        event.endTimeIndex = self.endTimeIndex
        event.location = self.location
        event.date = self.date
        event.day = self.day
        event.startTime = self.startTime
        event.endTime = self.endTime
        event.eventType = self.eventType
        event.notes = self.notes
        event.descriptionUrl = self.descriptionUrl
        event.eventImageUrl = self.eventImageUrl
        return event
    }
    
    /// Create from legacy Core Data Event object
    init(from event: Event) {
        self.bandName = event.band?.bandName ?? ""
        self.eventYear = Int(event.eventYear)
        self.timeIndex = event.timeIndex
        self.endTimeIndex = event.endTimeIndex
        self.location = event.location ?? ""
        self.date = event.date
        self.day = event.day
        self.startTime = event.startTime
        self.endTime = event.endTime
        self.eventType = event.eventType
        self.notes = event.notes
        self.descriptionUrl = event.descriptionUrl
        self.eventImageUrl = event.eventImageUrl
    }
}

public extension UserPriorityData {
    /// Convert to legacy Core Data UserPriority object (for compatibility with existing code)
    func toLegacyUserPriority(context: NSManagedObjectContext) -> UserPriority {
        let priority = UserPriority(context: context)
        priority.bandName = self.bandName
        priority.eventYear = Int32(self.eventYear)
        priority.priorityLevel = Int16(self.priorityLevel)
        priority.updatedAt = self.updatedAt
        return priority
    }
    
    /// Create from legacy Core Data UserPriority object
    init(from priority: UserPriority) {
        self.bandName = priority.bandName ?? ""
        self.eventYear = Int(priority.eventYear)
        self.priorityLevel = Int(priority.priorityLevel)
        self.updatedAt = priority.updatedAt
    }
}

public extension UserAttendanceData {
    /// Convert to legacy Core Data UserAttendance object (for compatibility with existing code)
    /// Note: This creates a detached UserAttendance object without an Event relationship
    func toLegacyUserAttendance(context: NSManagedObjectContext) -> UserAttendance {
        let attendance = UserAttendance(context: context)
        // Note: UserAttendance has an 'event' relationship, not direct 'bandName' or 'timeIndex' properties
        // For full conversion, you'd need to fetch/create the Event object
        attendance.eventYear = Int32(self.eventYear)
        attendance.attendanceStatus = Int16(self.attendanceStatus)
        attendance.updatedAt = self.updatedAt
        return attendance
    }
    
    /// Create from legacy Core Data UserAttendance object
    init(from attendance: UserAttendance) {
        self.bandName = attendance.event?.band?.bandName ?? ""
        self.eventYear = Int(attendance.eventYear)
        self.timeIndex = attendance.event?.timeIndex ?? 0.0
        self.attendanceStatus = Int(attendance.attendanceStatus)
        self.updatedAt = attendance.updatedAt
    }
}


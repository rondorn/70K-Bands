//
//  DataModels.swift
//  70000 Tons Bands
//
//  Plain Swift structs for data transfer
//  These replace Core Data NSManagedObject instances for thread-safe data handling
//

import Foundation

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

// Core Data conversion extensions removed - all data now uses SQLite directly


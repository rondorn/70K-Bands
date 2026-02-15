//
//  EventTypes.swift
//  70K Bands
//
//  Created by Refactoring
//  Copyright (c) 2026 Ron Dorn. All rights reserved.
//

import Foundation

/// Event type constants and utilities
struct EventTypes {
    
    // MARK: - Event Type Strings
    static let show = "Show"
    static let meetAndGreet = "Meet and Greet"
    static let clinic = "Clinic"
    static let listeningParty = "Listening Party"
    static let specialEvent = "Special Event"
    static let unofficialEventOld = "Unofficial Event"
    static let unofficialEvent = "Cruiser Organized"
    static let karaoke = "Karaoke"
    
    // MARK: - Combined Event Delimiter
    /// ASCII Record Separator – never appears in user-visible event names.
    /// Used so "/" in descriptions is not treated as combined.
    static let combinedEventDelimiter = "\u{001E}"
    
    /// Checks if a band name represents a combined event
    static func isCombinedEventBandName(_ bandName: String?) -> Bool {
        guard let name = bandName else { return false }
        return name.contains(combinedEventDelimiter)
    }
    
    /// Splits a combined event band name into its parts
    static func combinedEventBandParts(_ bandName: String?) -> [String]? {
        guard let name = bandName, name.contains(combinedEventDelimiter) else { return nil }
        let parts = name.components(separatedBy: combinedEventDelimiter)
        return parts.count >= 2 ? parts : nil
    }
    
    /// Converts an event type string to a localized version for display.
    /// - Parameter eventType: The event type string to localize.
    /// - Returns: The localized event type string.
    static func convertToLocalLanguage(eventType: String) -> String {
        var localEventType = eventType
        
        print("Received an eventType of \(eventType)")
        
        if eventType == unofficialEvent {
            localEventType = NSLocalizedString("Unofficial Events", comment: "")
        } else if eventType == listeningParty {
            localEventType = NSLocalizedString(eventType, comment: "")
        } else if eventType == clinic {
            localEventType = NSLocalizedString(eventType, comment: "")
        } else if eventType == meetAndGreet {
            localEventType = NSLocalizedString(eventType, comment: "")
        } else if eventType == specialEvent {
            localEventType = NSLocalizedString(eventType, comment: "")
        }
        
        print("Received an eventType and returned \(localEventType)")
        return localEventType
    }
}

// MARK: - Global Accessors (for backward compatibility)
let combinedEventDelimiter: String = EventTypes.combinedEventDelimiter

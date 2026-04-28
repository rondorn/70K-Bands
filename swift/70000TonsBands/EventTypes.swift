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
    // MARK: - Canonical Event Types (locked keys)
    static let canonicalShow = "Show"
    static let canonicalUnofficialEvent = "Unofficial Event"
    static let canonicalSpecialEvent = "Special Event"
    static let canonicalMeetAndGreet = "Meet and Greet"
    static let canonicalClinic = "Clinic"
    
    // MARK: - Event Type Strings
    static let show = canonicalShow
    static let meetAndGreet = canonicalMeetAndGreet
    static let clinic = canonicalClinic
    static let listeningParty = "Listening Party"
    static let specialEvent = canonicalSpecialEvent
    static let unofficialEventOld = canonicalUnofficialEvent
    // Backward-compat value still used in persisted data and legacy matching.
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
        let canonical = normalize(eventType)
        return FestivalConfig.current.getEventTypeDisplayName(canonicalEventType: canonical, languageCode: currentLanguageCode())
    }

    static func normalize(_ eventType: String?) -> String {
        guard let raw = eventType?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return canonicalShow
        }
        if raw.caseInsensitiveCompare(canonicalShow) == .orderedSame { return canonicalShow }
        if raw.caseInsensitiveCompare(canonicalSpecialEvent) == .orderedSame { return canonicalSpecialEvent }
        if raw.caseInsensitiveCompare(canonicalMeetAndGreet) == .orderedSame { return canonicalMeetAndGreet }
        if raw.caseInsensitiveCompare(canonicalClinic) == .orderedSame { return canonicalClinic }
        if raw.caseInsensitiveCompare(unofficialEvent) == .orderedSame || raw.caseInsensitiveCompare(canonicalUnofficialEvent) == .orderedSame {
            return canonicalUnofficialEvent
        }
        return raw
    }

    static func isShow(_ eventType: String?) -> Bool { normalize(eventType) == canonicalShow }
    static func isUnofficial(_ eventType: String?) -> Bool { normalize(eventType) == canonicalUnofficialEvent }
    static func isSpecial(_ eventType: String?) -> Bool { normalize(eventType) == canonicalSpecialEvent }
    static func isMeetAndGreet(_ eventType: String?) -> Bool { normalize(eventType) == canonicalMeetAndGreet }
    static func isClinic(_ eventType: String?) -> Bool { normalize(eventType) == canonicalClinic }
    static func isFilterableNonShow(_ eventType: String?) -> Bool {
        let canonical = normalize(eventType)
        return canonical == canonicalUnofficialEvent
            || canonical == canonicalSpecialEvent
            || canonical == canonicalMeetAndGreet
            || canonical == canonicalClinic
    }

    static func currentLanguageCode() -> String {
        let code = Locale.current.languageCode?.lowercased() ?? "en"
        let supported = Set(["en", "de", "es", "fr", "pt", "da", "fi"])
        return supported.contains(code) ? code : "en"
    }

    static func eventTypesInScheduleExcludingShow(forDay dayLabel: String? = nil) -> [String] {
        let allEvents = DataManager.shared.fetchEvents(forYear: eventYear)
        let dayEvents = dayLabel == nil ? allEvents : allEvents.filter { $0.day == dayLabel }
        let used = Set(dayEvents.map { normalize($0.eventType) }.filter { isFilterableNonShow($0) })
        let order = [canonicalUnofficialEvent, canonicalSpecialEvent, canonicalMeetAndGreet, canonicalClinic]
        return order.filter { used.contains($0) }
    }

    static func isVisibleByPreference(_ eventType: String?) -> Bool {
        let canonical = normalize(eventType)
        if canonical == canonicalShow { return true }
        if canonical == canonicalMeetAndGreet { return getShowMeetAndGreetEvents() }
        if canonical == canonicalSpecialEvent { return getShowSpecialEvents() }
        if canonical == canonicalClinic { return getShowClinicEvents() }
        if canonical == canonicalUnofficialEvent { return getShowUnofficalEvents() }
        return true
    }

    static func setVisibleByPreference(_ eventType: String?, _ visible: Bool) {
        let canonical = normalize(eventType)
        if canonical == canonicalMeetAndGreet { setShowMeetAndGreetEvents(visible) }
        else if canonical == canonicalSpecialEvent { setShowSpecialEvents(visible) }
        else if canonical == canonicalClinic { setShowClinicEvents(visible) }
        else if canonical == canonicalUnofficialEvent { setShowUnofficalEvents(visible) }
    }

    static func filterRowText(_ eventType: String?) -> String {
        return FestivalConfig.current.getEventTypeFilterDisplayName(
            canonicalEventType: normalize(eventType),
            languageCode: currentLanguageCode()
        )
    }

    static func iconNames(for eventType: String?) -> (on: String, off: String) {
        let canonical = normalize(eventType)
        if canonical == canonicalUnofficialEvent { return (unofficalEventTypeIcon, unofficalEventTypeIconAlt) }
        if canonical == canonicalSpecialEvent { return (specialEventTypeIcon, specialEventTypeIconAlt) }
        if canonical == canonicalMeetAndGreet { return (meetAndGreetIcon, meetAndGreetIconAlt) }
        if canonical == canonicalClinic { return (clinicEventTypeIcon, clinicEventTypeIconAlt) }
        return ("", "")
    }
}

// MARK: - Global Accessors (for backward compatibility)
let combinedEventDelimiter: String = EventTypes.combinedEventDelimiter

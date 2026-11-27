//
//  SortFilterMenuController.swift
//  70K Bands
//
//  Created by Ron Dorn on 6/11/16.
//  Copyright © 2016 Ron Dorn. All rights reserved.
//
//  Filter menu helpers used by CommonFilterSheetView.
//  The DropDown menu UI was replaced by the consolidated CommonFilterSheetView.
//

import Foundation
import UIKit

// Helper function to check if there are any events in the database (regardless of filters/view mode)
func hasAnyEvents() -> Bool {
    let allEvents = DataManager.shared.fetchEvents(forYear: eventYear)
    return allEvents.count > 0
}

// Helper function to check if there are any expired events
func hasExpiredEvents() -> Bool {
    let currentTime = Date().timeIntervalSinceReferenceDate
    let allEvents = DataManager.shared.fetchEvents(forYear: eventYear)
    
    // Check if any event has expired (endTimeIndex + 10 min buffer < currentTime)
    return allEvents.contains { event in
        var endTimeIndex = event.endTimeIndex
        // Detect midnight crossing - add 24 hours if needed
        if event.timeIndex > endTimeIndex {
            endTimeIndex += 86400
        }
        // Add 10-minute buffer (600 seconds) before considering expired
        return endTimeIndex + 600 < currentTime
    }
}

/// Venues that appear in the list view (have at least one event this year). Used for the portrait "Location Filters" section.
/// Includes: (1) configured venues (FestivalConfig) that have at least one matching event, and (2) discovered venues — event locations that don't match any configured venue (so they can be toggled in the menu and filtered correctly).
func getVenueNamesInUseForList() -> [String] {
    let allEvents = DataManager.shared.fetchEvents(forYear: eventYear)
    let allLocations = allEvents.map { $0.location }
    let configuredVenueNames = FestivalConfig.current.getAllVenueNames()

    // Configured venues that have at least one event (prefix match)
    let configuredInUse = configuredVenueNames.filter { venueName in
        allLocations.contains { $0.lowercased().hasPrefix(venueName.lowercased()) }
    }

    // Discovered venues: event locations that do NOT prefix-match any configured venue
    var discovered = Set<String>()
    for location in allLocations {
        let matchesConfigured = configuredVenueNames.contains { venueName in
            location.lowercased().hasPrefix(venueName.lowercased())
        }
        if !matchesConfigured {
            discovered.insert(location)
        }
    }
    let discoveredSorted = discovered.sorted()

    // Ensure discovered venues have a filter state (default on) so toggles and list filtering work
    ensureVenueFilterStates(venueNames: discoveredSorted)

    return configuredInUse + discoveredSorted
}

/// Returns the venue name with any parenthesized part removed, for menu display only. Filtering still uses the full location name.
func venueDisplayName(for venueName: String) -> String {
    venueName.components(separatedBy: " (").first?.trimmingCharacters(in: .whitespaces) ?? venueName
}

/// Days filter bucket for bands/events with no Day value. Shown only when other Day labels exist and at least one record has no day.
let dayFilterUnknownLabel = "Unknown"

/// Whether a schedule event counts as expired for Day filter discovery / matching (10‑min buffer).
func isEventExpiredForDayFilter(_ event: EventData) -> Bool {
    let currentTime = Date().timeIntervalSinceReferenceDate
    var endTimeIndex = event.endTimeIndex
    if event.timeIndex > endTimeIndex {
        endTimeIndex += 86400
    }
    return endTimeIndex + 600 <= currentTime
}

private func dayNumberFromFilterLabel(_ label: String) -> Int? {
    let t = label.trimmingCharacters(in: .whitespacesAndNewlines)
    if t.lowercased().hasPrefix("day ") {
        return Int(t.dropFirst(4).trimmingCharacters(in: .whitespacesAndNewlines))
    }
    return nil
}

func isDayFilterUnknownLabel(_ label: String) -> Bool {
    label.trimmingCharacters(in: .whitespacesAndNewlines)
        .caseInsensitiveCompare(dayFilterUnknownLabel) == .orderedSame
}

/// Stable order: Pre first, then Day N numeric, then alpha, Unknown last.
func sortDayFilterLabels(_ labels: [String]) -> [String] {
    labels.sorted { a, b in
        let aUnknown = isDayFilterUnknownLabel(a)
        let bUnknown = isDayFilterUnknownLabel(b)
        if aUnknown != bUnknown { return !aUnknown && bUnknown }
        let aLower = a.lowercased()
        let bLower = b.lowercased()
        let aPre = aLower == "pre" || aLower.hasPrefix("pre ") || aLower.hasPrefix("pre-")
        let bPre = bLower == "pre" || bLower.hasPrefix("pre ") || bLower.hasPrefix("pre-")
        if aPre != bPre { return aPre && !bPre }
        let aNum = dayNumberFromFilterLabel(a)
        let bNum = dayNumberFromFilterLabel(b)
        if let an = aNum, let bn = bNum { return an < bn }
        if aNum != nil { return true }
        if bNum != nil { return false }
        return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
    }
}

/// Day labels for the Days filter section: schedule event days (respecting Hide Expired) union artist Day tokens for bands with no schedule.
/// Appends Unknown when other day labels exist and at least one record has no Day.
func getDayNamesInUseForList() -> [String] {
    var days = Set<String>()
    var hasUnknownDayRecords = false
    let hideExpired = getHideExpireScheduleData()
    let allEvents = DataManager.shared.fetchEvents(forYear: eventYear)
    var bandsWithSchedule = Set<String>()

    for event in allEvents {
        bandsWithSchedule.insert(event.bandName)
        if hideExpired && isEventExpiredForDayFilter(event) {
            continue
        }
        if let raw = event.day?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            days.insert(raw)
        } else {
            hasUnknownDayRecords = true
        }
    }

    let bands = DataManager.shared.fetchBands(forYear: eventYear).filter { $0.lineIndex != nil }
    for band in bands {
        if bandsWithSchedule.contains(band.bandName) {
            continue
        }
        let tokens = parseDayTokens(band.day)
        if tokens.isEmpty {
            hasUnknownDayRecords = true
        } else {
            for token in tokens {
                days.insert(token)
            }
        }
    }

    var result = sortDayFilterLabels(Array(days))
    if !result.isEmpty && hasUnknownDayRecords {
        result.append(dayFilterUnknownLabel)
    }
    return result
}

/// Whether a band-only row passes the Days filter (per-record: schedule days if present, else artist Day tokens).
/// Missing Day is gated by the Unknown toggle (default on).
func bandPassesDayFilter(bandName: String, artistDay: String?) -> Bool {
    let events = DataManager.shared.fetchEventsForBand(bandName, forYear: eventYear)
    let hideExpired = getHideExpireScheduleData()

    if !events.isEmpty {
        let relevantEvents = events.filter { !hideExpired || !isEventExpiredForDayFilter($0) }
        // Schedule owned this band, but Hide Expired left nothing — treat as Unknown day.
        if relevantEvents.isEmpty {
            return getShowDayEvents(dayName: dayFilterUnknownLabel)
        }
        return relevantEvents.contains { event in
            guard let d = event.day?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty else {
                return getShowDayEvents(dayName: dayFilterUnknownLabel)
            }
            return getShowDayEvents(dayName: d)
        }
    }

    let tokens = parseDayTokens(artistDay)
    if tokens.isEmpty {
        return getShowDayEvents(dayName: dayFilterUnknownLabel)
    }
    return tokens.contains { getShowDayEvents(dayName: $0) }
}

/// Whether a schedule event row passes the Days filter. Missing Day uses the Unknown toggle.
func eventPassesDayFilter(_ event: EventData) -> Bool {
    guard let d = event.day?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty else {
        return getShowDayEvents(dayName: dayFilterUnknownLabel)
    }
    return getShowDayEvents(dayName: d)
}

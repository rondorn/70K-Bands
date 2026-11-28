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

private func isDayFilterNamedPreLabel(_ label: String) -> Bool {
    let lower = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return lower == "pre" || lower.hasPrefix("pre ") || lower.hasPrefix("pre-")
}

private func isDayFilterNamedPostLabel(_ label: String) -> Bool {
    let lower = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return lower == "post" || lower.hasPrefix("post ") || lower.hasPrefix("post-")
}

/// Parse filter labels like `1/27` / `01/27` into a date (year = eventYear).
private func parseDayFilterDateLabel(_ label: String) -> Date? {
    let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    let formats = ["M/d", "MM/dd", "M/dd", "MM/d"]
    let calendar = Calendar.current
    let year = eventYear > 0 ? eventYear : calendar.component(.year, from: Date())
    for format in formats {
        formatter.dateFormat = format
        guard let partial = formatter.date(from: trimmed) else { continue }
        var components = calendar.dateComponents([.month, .day], from: partial)
        components.year = year
        if let full = calendar.date(from: components) {
            return full
        }
    }
    return nil
}

/// Date-like labels: no gap → all Pre. Gap of ≥2 calendar days between sorted dates →
/// earlier cluster Pre, later cluster(s) Post.
private func classifyDateFilterLabelsAsPreOrPost(_ labels: [String]) -> [String: Bool] {
    // true = Pre side, false = Post side
    struct DatedLabel {
        let label: String
        let date: Date
    }
    var dated: [DatedLabel] = []
    for label in labels {
        if isDayFilterNamedPreLabel(label) || isDayFilterNamedPostLabel(label) || isDayFilterUnknownLabel(label) {
            continue
        }
        if dayNumberFromFilterLabel(label) != nil {
            continue
        }
        if let date = parseDayFilterDateLabel(label) {
            dated.append(DatedLabel(label: label, date: date))
        }
    }
    guard !dated.isEmpty else { return [:] }
    dated.sort { $0.date < $1.date }

    let calendar = Calendar.current
    var splitIndex: Int? = nil
    for i in 1..<dated.count {
        let diff = calendar.dateComponents([.day], from: dated[i - 1].date, to: dated[i].date).day ?? 0
        if diff >= 2 {
            splitIndex = i
            break
        }
    }

    var result: [String: Bool] = [:]
    if let split = splitIndex {
        for i in 0..<dated.count {
            result[dated[i].label] = i < split
        }
    } else {
        for item in dated {
            result[item.label] = true // no gap → all Pre
        }
    }
    return result
}

private enum DayFilterSortBucket: Int {
    case namedPre = 0
    case datePre = 1
    case dayN = 2
    case other = 3
    case datePost = 4
    case namedPost = 5
    case unknown = 6
}

/// Order: named Pre → date Pre → Day N → other → date Post → named Post → Unknown.
func sortDayFilterLabels(_ labels: [String]) -> [String] {
    let dateSide = classifyDateFilterLabelsAsPreOrPost(labels)
    let dateByLabel: [String: Date] = {
        var map: [String: Date] = [:]
        for label in labels {
            if let d = parseDayFilterDateLabel(label) {
                map[label] = d
            }
        }
        return map
    }()

    func bucket(for label: String) -> DayFilterSortBucket {
        if isDayFilterUnknownLabel(label) { return .unknown }
        if isDayFilterNamedPreLabel(label) { return .namedPre }
        if isDayFilterNamedPostLabel(label) { return .namedPost }
        if dayNumberFromFilterLabel(label) != nil { return .dayN }
        if let isPre = dateSide[label] {
            return isPre ? .datePre : .datePost
        }
        return .other
    }

    return labels.sorted { a, b in
        let ba = bucket(for: a)
        let bb = bucket(for: b)
        if ba != bb { return ba.rawValue < bb.rawValue }
        switch ba {
        case .dayN:
            let an = dayNumberFromFilterLabel(a) ?? 0
            let bn = dayNumberFromFilterLabel(b) ?? 0
            if an != bn { return an < bn }
        case .datePre, .datePost:
            if let da = dateByLabel[a], let db = dateByLabel[b], da != db {
                return da < db
            }
        default:
            break
        }
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

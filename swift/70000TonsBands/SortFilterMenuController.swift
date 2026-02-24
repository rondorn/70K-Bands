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

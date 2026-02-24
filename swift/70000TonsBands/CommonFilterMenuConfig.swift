//
//  CommonFilterMenuConfig.swift
//  70K Bands
//
//  Common filter menu configuration for both portrait and calendar views
//

import Foundation
import SwiftUI

enum FilterMenuType {
    case portrait  // Portrait view: includes Show Expired Events and Sort By Time
    case calendar  // Calendar view: no Show Expired Events, no Sort By Time
}

/// Represents a filter menu section
enum FilterMenuSection: Hashable {
    case clearFilters
    case expiredEvents
    case bandRanking
    case flaggedEvents
    case sortBy
    case eventTypes
    case locations
}

/// Configuration for building filter menus
struct FilterMenuConfig {
    let menuType: FilterMenuType
    let showExpiredEvents: Bool
    let showFlaggedEvents: Bool
    let showSortBy: Bool
    let showEventTypes: Bool
    let showBandRanking: Bool
    let showLocations: Bool
    
    /// Returns the sections in the correct order for the menu type
    var orderedSections: [FilterMenuSection] {
        switch menuType {
        case .portrait:
            // Portrait order: Same as Calendar (Show Flagged Events Only -> Event Types -> Band Ranking -> Locations)
            // plus Hide Expired Events and Sort By Time at the end
            var sections: [FilterMenuSection] = [.clearFilters]
            if showFlaggedEvents { sections.append(.flaggedEvents) }
            if showEventTypes { sections.append(.eventTypes) }
            if showBandRanking { sections.append(.bandRanking) }
            if showLocations { sections.append(.locations) }
            if showExpiredEvents { sections.append(.expiredEvents) }
            if showSortBy { sections.append(.sortBy) }
            return sections
        case .calendar:
            // Calendar order: Clear Filters -> Show Flagged Events Only -> Event Types -> Band Ranking -> Locations
            var sections: [FilterMenuSection] = [.clearFilters]
            if showFlaggedEvents { sections.append(.flaggedEvents) }
            if showEventTypes { sections.append(.eventTypes) }
            if showBandRanking { sections.append(.bandRanking) }
            if showLocations { sections.append(.locations) }
            return sections
        }
    }
    
    /// Creates a configuration for portrait view
    static func portrait() -> FilterMenuConfig {
        let hasScheduledEvents = (eventCount > 0 && eventCounterUnoffical != eventCount)
        let showScheduleView = getShowScheduleView()
        let showScheduleFilters = hasScheduledEvents && showScheduleView
        
        return FilterMenuConfig(
            menuType: .portrait,
            showExpiredEvents: hasAnyEvents() && hasExpiredEvents(),
            showFlaggedEvents: showScheduleFilters && attendingCount > 0,
            showSortBy: showScheduleFilters,
            showEventTypes: showScheduleFilters && (getMeetAndGreetsEnabled() || getSpecialEventsEnabled() || getUnofficalEventsEnabled()),
            showBandRanking: true,
            showLocations: showScheduleFilters
        )
    }
    
    /// Creates a configuration for calendar view
    static func calendar(forDay dayLabel: String) -> FilterMenuConfig {
        return FilterMenuConfig(
            menuType: .calendar,
            showExpiredEvents: false, // Calendar view doesn't show expired events filter
            showFlaggedEvents: hasFlaggedEvents(forDay: dayLabel),
            showSortBy: false, // Calendar view doesn't show sort by filter
            showEventTypes: hasFilterableEventTypes(forDay: dayLabel),
            showBandRanking: hasRankedBands(forDay: dayLabel),
            showLocations: true // Always show locations if venues exist
        )
    }
}

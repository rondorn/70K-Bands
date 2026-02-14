//
//  mainListController.swift
//  70K Bands
//
//  Created by Ron Dorn on 2/6/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import UIKit
import Foundation
import CoreData

var bands = [String]() //main list of bands

var scheduleButton = false;
var hideScheduleButton = false;

var attendingCount = 0;

var bandCount = Int();
var eventCount = Int();

var previousBandName = String();
var nextBandName = String();
var firstBandName = String();
var scrollDirection = "Down";
var previousIndexRow = Int();

var totalUpcomingEvents = Int()

var scheduleIndexByCall : [String:[String:String]] = [String:[String:String]]();

// Mapping for combined events: combined name (band1+delimiter+band2) -> [band1, band2]
// Used when multiple events share same date, time, location, and event type
var combinedEventsMap: [String: [String]] = [:]

func getScheduleIndexByCall()->  [String:[String:String]]{
    return scheduleIndexByCall;
}

func setBands(_ value: [String]){
    bands = value
}
func getBands() -> [String]{
    return bands
}

/// NEW: High-performance query-based filtering that replaces loop-based determineBandOrScheduleList
/// - Parameters:
///   - sortedBy: Sort preference ("name" or "time")  
///   - priorityManager: Priority manager for band rankings
///   - attendedHandle: Attendance tracking handler
/// - Returns: Filtered events and bands for UI display
func getFilteredScheduleData(sortedBy: String, priorityManager: SQLitePriorityManager, attendedHandle: ShowsAttended) -> [String] {
    let startTime = CFAbsoluteTimeGetCurrent()
    print("🚀 CORE DATA FILTERING START with user preferences - eventYear: \(eventYear)")
    print("🔒 [THREAD_SAFETY] getFilteredScheduleData called on thread: \(Thread.current), isMain: \(Thread.isMainThread)")
    
    // CRITICAL: This function MUST run on main thread because it accesses Core Data viewContext objects
    // If called from background thread, dispatch to main thread synchronously
    if !Thread.isMainThread {
        print("⚠️ [THREAD_SAFETY] getFilteredScheduleData called from background thread - dispatching to main")
        var result: [String] = []
        DispatchQueue.main.sync {
            result = getFilteredScheduleData(sortedBy: sortedBy, priorityManager: priorityManager, attendedHandle: attendedHandle)
        }
        return result
    }
    
    let coreDataManager = CoreDataManager.shared
    
    // BUILD COMPREHENSIVE FILTER PREDICATE
    var predicates: [NSPredicate] = []
    
    // 1. YEAR FILTER (always required)
    predicates.append(NSPredicate(format: "eventYear == %d", eventYear))
    
    // 2. EVENT TYPE FILTERS (EXCLUSIVE approach - show everything EXCEPT filtered out types)
    // This ensures new unknown event types appear by default
    var excludedEventTypes: [String] = []
    
    if !getShowSpecialEvents() { 
        excludedEventTypes.append("Special Event")
        print("🔍 [FILTER] ❌ EXCLUDING Special Events")
    } else {
        print("🔍 [FILTER] ✅ Including Special Events")
    }
    
    if !getShowMeetAndGreetEvents() { 
        excludedEventTypes.append("Meet and Greet")
        print("🔍 [FILTER] ❌ EXCLUDING Meet and Greet Events")
    } else {
        print("🔍 [FILTER] ✅ Including Meet and Greet Events")
    }
    
    print("🔧 [UNOFFICIAL_DEBUG] In mainListController filtering - about to check getShowUnofficalEvents()")
    if !getShowUnofficalEvents() { 
        excludedEventTypes.append(contentsOf: ["Unofficial Event", "Cruiser Organized"])
        print("🔍 [FILTER] ❌ EXCLUDING Unofficial Events: ['Unofficial Event', 'Cruiser Organized']")
        print("🔧 [UNOFFICIAL_DEBUG] ❌ UNOFFICIAL EVENTS EXCLUDED in mainListController")
    } else {
        print("🔍 [FILTER] ✅ Including Unofficial Events: ['Unofficial Event', 'Cruiser Organized']")
        print("🔧 [UNOFFICIAL_DEBUG] ✅ UNOFFICIAL EVENTS INCLUDED in mainListController")
    }
    
    // 3. BANDS ONLY FILTER - Note: We handle this differently than other filters
    // In Bands Only mode, we want to show ALL bands but exclude events from the final result
    // This is handled in the post-processing step, not in the Core Data query
    let showScheduleView = getShowScheduleView()
    print("🔍 [VIEW_MODE_DEBUG] getShowScheduleView() = \(showScheduleView)")
    if !showScheduleView {
        print("🔍 [VIEW_MODE_DEBUG] 🎵 BANDS ONLY MODE - Will filter events in post-processing")
    } else {
        print("🔍 [VIEW_MODE_DEBUG] ✅ SCHEDULE MODE - Including both events and bands")
    }
    
    // Apply exclusion filter only if there are types to exclude
    if !excludedEventTypes.isEmpty {
        predicates.append(NSPredicate(format: "NOT (eventType IN %@)", excludedEventTypes))
        print("🔍 [FILTER] Event types EXCLUDED: \(excludedEventTypes)")
    } else {
        print("🔍 [FILTER] No event types excluded - showing ALL event types")
    }
    
    // 3. VENUE FILTERS (DYNAMIC approach using FestivalConfig venues)
    // This ensures new venues from different festivals are handled automatically
    
    // Get the filter venues from FestivalConfig (only venues with showInFilters=true)
    let filterVenues = FestivalConfig.current.getFilterVenueNames()
    
    // Build list of enabled filter venues
    var enabledFilterVenues: [String] = []
    var disabledFilterVenues: [String] = []
    
    for venueName in filterVenues {
        if getShowVenueEvents(venueName: venueName) {
            enabledFilterVenues.append(venueName)
            print("🔍 [FILTER] ✅ Including \(venueName) venues")
        } else {
            disabledFilterVenues.append(venueName)
            print("🔍 [FILTER] ❌ EXCLUDING \(venueName) venues")
        }
    }
    
    // Build the venue filter predicate
    var venuePredicateParts: [NSPredicate] = []
    
    // Add predicates for enabled filter venues
    // Use BEGINSWITH for exact venue matching to avoid "Lounge" matching "Boleros Lounge"
    for venueName in enabledFilterVenues {
        venuePredicateParts.append(NSPredicate(format: "location BEGINSWITH[cd] %@", venueName))
    }
    
    // Handle "Other" venues - if enabled, include venues not matching any filter venue
    if getShowOtherShows() {
        print("🔍 [FILTER] ✅ Including Other venues (venues with showInFilters=false)")
        // If Other venues are enabled, we need to add a predicate for "NOT any filter venue"
        // But only if there are some filter venues to exclude from "Other"
        if !filterVenues.isEmpty {
            var filterVenuePredicates: [NSPredicate] = []
            for venueName in filterVenues {
                // Use BEGINSWITH for exact venue matching
                filterVenuePredicates.append(NSPredicate(format: "location BEGINSWITH[cd] %@", venueName))
            }
            let notFilterVenuesPredicate = NSCompoundPredicate(notPredicateWithSubpredicate: 
                NSCompoundPredicate(orPredicateWithSubpredicates: filterVenuePredicates))
            venuePredicateParts.append(notFilterVenuesPredicate)
        }
    } else {
        print("🔍 [FILTER] ❌ EXCLUDING Other venues (venues with showInFilters=false)")
    }
    
    // Apply the venue filter: show events that match enabled venues OR other venues (if enabled)
    if !venuePredicateParts.isEmpty {
        let venuePredicate = NSCompoundPredicate(orPredicateWithSubpredicates: venuePredicateParts)
        predicates.append(venuePredicate)
        print("🔍 [FILTER] Applied venue filter: enabled=\(enabledFilterVenues), other=\(getShowOtherShows())")
    } else {
        // No venues enabled and Other venues disabled = hide all venues
        print("🔍 [FILTER] ⚠️ No venues enabled - this will show no events")
        predicates.append(NSPredicate(value: false)) // Force no results
    }
    
    // 4. EXPIRATION FILTER (if enabled)
    // Note: This NSPredicate is not actually used - filtering happens in Swift below
    // Kept here for documentation/compatibility purposes
    if getHideExpireScheduleData() {
        let currentTime = Date().timeIntervalSinceReferenceDate // FIX: Use same reference as timeIndex
        // NSPredicate doesn't handle midnight crossing or 10-min buffer - actual filtering happens in Swift filter below
        predicates.append(NSPredicate(format: "endTimeIndex > %f", currentTime))
        print("🔍 [FILTER] Hiding expired events (with 10-min buffer, ended before) \(currentTime + 600)")
    }
    
    // EXECUTE QUERY (via DataManager -> SQLite) and filter in Swift
    // Note: New struct-based API doesn't use NSPredicate, so we filter directly
    let allEvents = DataManager.shared.fetchEvents(forYear: eventYear)
    
    // Apply filters directly on structs
    let filteredEvents = allEvents.filter { event in
        let eventType = event.eventType ?? ""
        let location = event.location
        
        // 1. Event type exclusions
        if excludedEventTypes.contains(eventType) {
            return false
        }
        
        // 2. Venue filters
        if venuePredicateParts.isEmpty {
            return false // No venues enabled
        }
        
        var matchesVenue = false
        for venueName in enabledFilterVenues {
            if location.lowercased().hasPrefix(venueName.lowercased()) {
                matchesVenue = true
                break
            }
        }
        
        // Check "Other" venues
        if !matchesVenue && getShowOtherShows() {
            // Check if it's NOT a filter venue
            var isFilterVenue = false
            for venueName in filterVenues {
                if location.lowercased().hasPrefix(venueName.lowercased()) {
                    isFilterVenue = true
                    break
                }
            }
            if !isFilterVenue {
                matchesVenue = true
            }
        }
        
        if !matchesVenue {
            return false
        }
        
    // 3. Expiration filter - CALCULATE AT FILTER TIME, NOT IMPORT TIME
    // This ensures that if the user changes timezones, events are still shown at the correct local times
    if getHideExpireScheduleData() {
        let currentTime = Date().timeIntervalSinceReferenceDate
        
        // Parse the end time from stored strings using CURRENT timezone
        // This ensures timezone changes don't affect event display times
        guard let dateString = event.date, let endTimeString = event.endTime else {
            // If no date/time info, keep the event (don't filter it out)
            return true
        }
        
        var endTimeIndex = calculateTimeIndexForFiltering(date: dateString, time: endTimeString)
        
        // FIX: Detect midnight crossing (matches Android logic in mainListHandler.java lines 121-123)
        // If start time > end time, event crosses midnight boundary - add 24 hours to end time
        if event.timeIndex > endTimeIndex {
            endTimeIndex += 86400 // Add 24 hours (86400 seconds = 24 * 60 * 60)
        }
        
        // Add 10-minute buffer (600 seconds) to end time before checking expiration
        let bufferEndTime = endTimeIndex + 600
        
        // DEBUG: Log filtering details for specific event
        if event.bandName.contains("Bloodred Hourglass") {
            print("🔍 [EXPIRE_DEBUG] Band: \(event.bandName)")
            print("🔍 [EXPIRE_DEBUG] Location: \(event.location)")
            print("🔍 [EXPIRE_DEBUG] Date: \(dateString)")
            print("🔍 [EXPIRE_DEBUG] Start Time: \(event.startTime ?? "N/A")")
            print("🔍 [EXPIRE_DEBUG] End Time: \(endTimeString)")
            print("🔍 [EXPIRE_DEBUG] Stored endTimeIndex: \(event.endTimeIndex)")
            print("🔍 [EXPIRE_DEBUG] Recalculated endTimeIndex (current TZ): \(endTimeIndex)")
            print("🔍 [EXPIRE_DEBUG] Buffer end time (+ 10 min): \(bufferEndTime)")
            print("🔍 [EXPIRE_DEBUG] currentTime: \(currentTime)")
            print("🔍 [EXPIRE_DEBUG] Current timezone: \(TimeZone.current.identifier)")
            print("🔍 [EXPIRE_DEBUG] bufferEndTime <= currentTime? \(bufferEndTime <= currentTime)")
            
            // Convert to readable dates for debugging
            let endDate = Date(timeIntervalSinceReferenceDate: bufferEndTime)
            let now = Date(timeIntervalSinceReferenceDate: currentTime)
            print("🔍 [EXPIRE_DEBUG] Buffer end time as Date: \(endDate)")
            print("🔍 [EXPIRE_DEBUG] Current time as Date: \(now)")
        }
        
        // Use recalculated time index with 10-minute buffer
        if bufferEndTime <= currentTime {
            return false
        }
    }
        
        return true
    }
    
    print("🔍 [FILTER] Filtered to \(filteredEvents.count) events from \(allEvents.count) total")
    
    // DEBUG: God Dethroned event count (avoid accessing relationships on background thread)
    print("🔍 [DEBUG_GOD_DETHRONED] Total filtered events: \(filteredEvents.count)")
    
    // DEBUG: Check what event types we actually got and compare to expected
    print("🔍 [FILTER] ===== EVENT TYPE DEBUGGING =====")
    print("🔍 [FILTER] Expected unofficial types: '\(unofficalEventType)', '\(unofficalEventTypeOld)'")
    print("🔍 [FILTER] getShowUnofficalEvents() = \(getShowUnofficalEvents())")
    
    let eventTypeBreakdown = Dictionary(grouping: filteredEvents, by: { $0.eventType ?? "No Type" })
    for (type, events) in eventTypeBreakdown.sorted(by: { $0.key < $1.key }) {
        print("🔍 [FILTER] Event type '\(type)': \(events.count) events")
        if type.contains("Unofficial") || type.contains("Cruiser") || type == unofficalEventType || type == unofficalEventTypeOld {
            print("🔍 [FILTER] 🎯 FOUND UNOFFICIAL: '\(type)' has \(events.count) events")
            print("🔍 [FILTER] 🎯 Expected types: unofficial='\(unofficalEventType)', old='\(unofficalEventTypeOld)'")
            print("🔍 [FILTER] 🎯 Type match check: '\(type)' == '\(unofficalEventType)'? \(type == unofficalEventType)")
            print("🔍 [FILTER] 🎯 Type match check: '\(type)' == '\(unofficalEventTypeOld)'? \(type == unofficalEventTypeOld)")
        }
    }
    
    // Also check what we had BEFORE filtering (reuse allEvents from above)
    let allEventTypeBreakdown = Dictionary(grouping: allEvents, by: { $0.eventType ?? "No Type" })
    print("🔍 [FILTER] ===== ALL EVENTS (before filtering) =====")
    for (type, events) in allEventTypeBreakdown.sorted(by: { $0.key < $1.key }) {
        if type.contains("Unofficial") || type.contains("Cruiser") {
            print("🔍 [FILTER] 📋 BEFORE FILTERING: '\(type)' has \(events.count) events")
        }
    }
    
    // APPLY PRIORITY FILTERING (post-filter since priority data is separate)
    let priorityFilteredEvents = filteredEvents.filter { event in
        let bandName = event.bandName
        guard !bandName.isEmpty else { return true } // Include standalone events
        
        let priority = priorityManager.getPriority(for: bandName)
        
        // Check priority filters
        if priority == 1 && !getMustSeeOn() { return false }
        if priority == 2 && !getMightSeeOn() { return false }
        if priority == 3 && !getWontSeeOn() { return false }
        if priority == 0 && !getUnknownSeeOn() { return false }
        
        return true
    }
    
    print("🔍 [FILTER] After priority filtering: \(priorityFilteredEvents.count) events")
    
    // APPLY ATTENDANCE FILTER (if enabled)
    let finalEvents: [EventData]
    if getShowOnlyWillAttened() {
        finalEvents = priorityFilteredEvents.filter { event in
            let bandName = event.bandName
            let location = event.location
            let eventType = event.eventType ?? ""
            
            // Use the raw startTime from the event data (same as GUI uses)
            let startTime = event.startTime ?? ""
            
            // SAFETY: Skip events with no startTime data
            if startTime.isEmpty {
                print("🔍 [ATTENDANCE_FILTER] ⚠️ Skipping '\(bandName)' - no startTime data")
                return false // Don't include in filtered results
            }
            
            // DEBUG: Show startTime for God Dethroned
            if bandName.contains("God Dethroned") {
                print("🔍 [TIMESTAMP_DEBUG] God Dethroned: using raw startTime='\(startTime)'")
            }
            
            let eventYearString = String(eventYear)
            let attendedStatus = attendedHandle.getShowAttendedStatus(
                band: bandName,
                location: location, 
                startTime: startTime,
                eventType: eventType,
                eventYearString: eventYearString
            )
            
            let key = "\(bandName):\(location):\(startTime):\(eventType):\(eventYearString)"
            let willShow = attendedStatus != sawNoneStatus
            print("🔍 [ATTENDANCE_FILTER] '\(bandName)' key='\(key)' status='\(attendedStatus)' willShow=\(willShow)")
            
            // Only show events marked as attending
            return willShow
        }
        print("🔍 [FILTER] After attendance filtering: \(finalEvents.count) events")
    } else {
        finalEvents = priorityFilteredEvents
    }
    
    print("📋 Final filtered events: \(finalEvents.count)")
    
    // Reset count - will be set appropriately based on view mode
    attendingCount = 0
    
    // COUNT FLAGGED EVENTS: Count all events that have attendance flags (past or future)
    // This is used to enable/disable the "Show Flagged Events Only" filter option
    // Note: We count ALL flagged events (both past and future) for filtering purposes
    if getShowScheduleView() {
        for event in finalEvents {
            let bandName = event.bandName
            let location = event.location
            let eventType = event.eventType ?? ""
            let startTime = event.startTime ?? ""
            
            // Skip if no startTime data
            guard !startTime.isEmpty else { continue }
            
            let eventYearString = String(eventYear)
            let attendedStatus = attendedHandle.getShowAttendedStatus(
                band: bandName,
                location: location,
                startTime: startTime,
                eventType: eventType,
                eventYearString: eventYearString
            )
            
            // Count any event with an attendance flag (not "sawNone")
            if attendedStatus != sawNoneStatus {
                attendingCount += 1
            }
        }
        print("🔍 [ATTENDING_COUNT_FIX] Counted \(attendingCount) flagged events (past and future)")
    } else {
        // In bands-only mode, we don't show events, so no flagged events to count
        print("🔍 [ATTENDING_COUNT_FIX] Bands-only mode - no events to count, attendingCount remains 0")
    }
    
    print("🔍 [ATTENDING_COUNT_FIX] Final attendingCount = \(attendingCount)")
    
    // Convert events to string format: "timeIndex:bandName" OR "timeIndex:eventName" for standalone events  
    let eventStrings = finalEvents.compactMap { event -> String? in
        // Get the band name from the event
        let bandName = event.bandName
        
        if !bandName.isEmpty {
            // Check if this "band" name is actually a standalone event
            // These patterns indicate it's an event name, not a real band name
            let standaloneEventPatterns = [
                "Metal Madness", "Thank You", "Karaoke", "Special Event", 
                "Meet and Greet", "Clinic", "Listening Party", 
                "Cruiser Organized", "Unofficial Event",
                // Day-specific events
                "Mon-", "Tue-", "Wed-", "Thu-", "Fri-", "Sat-", "Sun-",
                // Time-specific events  
                "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
                // Common event identifiers
                "Event", "Activity", "Party", "Session"
            ]
            
            let isStandaloneEvent = standaloneEventPatterns.contains { pattern in
                bandName.localizedCaseInsensitiveContains(pattern)
            } || event.eventType?.localizedCaseInsensitiveContains("Unofficial") == true ||
               event.eventType?.localizedCaseInsensitiveContains("Special") == true
            
            if isStandaloneEvent {
                return "\(event.timeIndex):\(bandName)"
            } else {
                // Regular band-associated event: "timeIndex:bandName"
                return "\(event.timeIndex):\(bandName)"
            }
        } else {
            // True standalone event with no band association (shouldn't happen with current import logic)
            var eventIdentifier: String
            
            if let notes = event.notes, !notes.isEmpty, notes.trimmingCharacters(in: .whitespacesAndNewlines) != "" {
                eventIdentifier = notes
            } else if let eventType = event.eventType, !eventType.isEmpty, eventType.trimmingCharacters(in: .whitespacesAndNewlines) != "" {
                eventIdentifier = eventType
            } else {
                let location = event.location
                if !location.isEmpty && location.trimmingCharacters(in: .whitespacesAndNewlines) != "" {
                    eventIdentifier = location
                } else {
                    eventIdentifier = "Unknown Event"
                }
            }
            
            return "\(event.timeIndex):\(eventIdentifier)"
        }
    }
    
    print("🔍 DEBUG: Final event strings generated: \(eventStrings.count)")
    
    // NOTE: Event combining is handled ONLY in landscape calendar view (LandscapeScheduleViewModel)
    // Portrait list view shows individual events - no combining here
    // This ensures portrait list view behavior is unchanged
    let finalEventStrings = eventStrings
    
    // FIX: Get bands that have NON-EXPIRED events (regardless of other filters)
    // Bands should only appear below events when they have NO non-expired events, not when just filtered by venue
    let bandsWithVisibleEvents: Set<String>
    let allYearEvents = DataManager.shared.fetchEvents(forYear: eventYear)
    
    if getHideExpireScheduleData() {
        // When "Hide Expired Events" is enabled, get all bands that have future events (regardless of venue/priority filters)
        let currentTime = Date().timeIntervalSinceReferenceDate // FIX: Use same reference as timeIndex
        let nonExpiredEvents = allYearEvents.filter { event in
            var endTimeIndex = event.endTimeIndex
            // Detect midnight crossing - add 24 hours if needed
            if event.timeIndex > endTimeIndex {
                endTimeIndex += 86400
            }
            // Add 10-minute buffer (600 seconds) before expiration
            return endTimeIndex + 600 > currentTime
        }
        bandsWithVisibleEvents = Set(nonExpiredEvents.map { $0.bandName })
        print("🔍 [BAND_DISPLAY_FIX] Hide Expired Events ON - bands with non-expired events: \(bandsWithVisibleEvents.sorted())")
    } else {
        // When "Hide Expired Events" is disabled, all bands with any events should not appear below (regardless of filters)
        bandsWithVisibleEvents = Set(allYearEvents.map { $0.bandName })
        print("🔍 [BAND_DISPLAY_FIX] Hide Expired Events OFF - bands with any events: \(bandsWithVisibleEvents.sorted())")
    }
    
    // Fetch ALL bands for current year (from SQLite via DataManager)
    let fetchedBands = DataManager.shared.fetchBands(forYear: eventYear)
    print("🔍 DEBUG: Fetched \(fetchedBands.count) bands from SQLite")
    
    // Only show bands that have NO visible events (band-only entries) and pass priority filters
    // These should be actual bands, not fake bands created from standalone events
    let bandOnlyStrings = fetchedBands.compactMap { band -> String? in
        let bandName = band.bandName
        guard !bandName.isEmpty else { return nil }
        
        // Only include band if it has no visible events
        if !bandsWithVisibleEvents.contains(bandName) {
            
            // ROBUST FAKE BAND DETECTION: Check if band is associated ONLY with unofficial/special events
            // If so, it's a fake band created for those events and should not appear when those events are hidden
            let allEventsForBand = DataManager.shared.fetchEventsForBand(bandName, forYear: eventYear)
            let fakeEventTypes = ["Unofficial Event", "Cruiser Organized", "Special Event", "Meet and Greet", "Clinic", "Listening Party"]
            
            // Check if ALL events for this band are fake event types
            let isAllFakeEvents = !allEventsForBand.isEmpty && allEventsForBand.allSatisfy { event in
                let eventType = event.eventType ?? ""
                return fakeEventTypes.contains(eventType)
            }
            
            if isAllFakeEvents {
                print("🎭 [FAKE_BAND_DEBUG] Filtering out fake band: '\(bandName)' (only has fake event types)")
                for event in allEventsForBand.prefix(3) {
                    let eventType = event.eventType ?? "unknown"
                    let isVisible = filteredEvents.contains(event)
                    print("🎭 [FAKE_BAND_DEBUG] - Event: '\(eventType)' at '\(event.location)' - Visible: \(isVisible)")
                }
                return nil
            }
            
            // FALLBACK: Pattern matching for edge cases (legacy support)
            let standaloneEventPatterns = [
                "Metal Madness", "Thank You", "Karaoke", "Special Event", 
                "Meet and Greet", "Clinic", "Listening Party", 
                "Cruiser Organized", "Unofficial Event", "Show",
                // Day-specific events
                "Mon-", "Tue-", "Wed-", "Thu-", "Fri-", "Sat-", "Sun-",
                // Time-specific events  
                "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
                // Common event identifiers
                "Event", "Activity", "Party", "Session"
            ]
            
            let isFakeBandByPattern = standaloneEventPatterns.contains { pattern in
                bandName.localizedCaseInsensitiveContains(pattern)
            }
            
            if isFakeBandByPattern {
                print("🎭 [FAKE_BAND_DEBUG] Filtering out fake band by pattern: '\(bandName)'")
                return nil
            }
            
            // APPLY PRIORITY FILTERING to band-only entries
            let priority = priorityManager.getPriority(for: bandName)
            
            // Check priority filters
            if priority == 1 && !getMustSeeOn() { return nil }
            if priority == 2 && !getMightSeeOn() { return nil }  
            if priority == 3 && !getWontSeeOn() { return nil }
            if priority == 0 && !getUnknownSeeOn() { return nil }
            
            return bandName
        }
        return nil
    }
    
    print("🔍 [FILTER] After band priority filtering: \(bandOnlyStrings.count) band-only entries")
    
    print("📊 Results: \(finalEventStrings.count) events, \(bandOnlyStrings.count) band-only entries")
    
    // Quick check for standalone events in final output (reduced logging)
    let standaloneCount = finalEventStrings.filter { eventString in
        let components = eventString.components(separatedBy: ":")
        if components.count == 2 {
            let identifier = components[1]
            return identifier.contains("Metal Madness") || identifier.contains("Thank You") || 
                   identifier.contains("Special Event") || identifier.contains("Unofficial Event") ||
                   identifier.contains("Karaoke")
        }
        return false
    }.count
    
    if standaloneCount > 0 {
        print("🔍 DEBUG: Found \(standaloneCount) standalone events in final output")
    }
    
    // Combine events and band-only entries (never both for the same band)
    var combinedResults = finalEventStrings + bandOnlyStrings
    
    // In bands-only mode, we don't show events, so no flagged events to count
    if !getShowScheduleView() {
        print("🔍 [GUI_ICON_COUNT] Bands-only mode - no events to count, attendingCount remains 0")
    } else {
        print("🔍 [GUI_ICON_COUNT] Schedule view - will count as GUI shows event icons")
    }
    
    // Apply final sorting with Events first, then Bands
    combinedResults.sort { item1, item2 in
        let components1 = item1.components(separatedBy: ":")
        let components2 = item2.components(separatedBy: ":")
        let isEvent1 = components1.count == 2
        let isEvent2 = components2.count == 2
        
        // Events always come before band names
        if isEvent1 && !isEvent2 {
            return true
        } else if !isEvent1 && isEvent2 {
            return false
        } else {
            // Both are same type, sort based on preference
            if sortedBy == "name" {
                return getNameFromSortable(item1, sortedBy: sortedBy).localizedCaseInsensitiveCompare(getNameFromSortable(item2, sortedBy: sortedBy)) == .orderedAscending
            } else {
                // If both are events, sort by time. If both are bands, sort alphabetically (since bands have no time)
                if isEvent1 && isEvent2 {
                    // Both are events - sort by time
                    return getTimeFromSortable(item1, sortBy: sortedBy) < getTimeFromSortable(item2, sortBy: sortedBy)
                } else {
                    // Both are band names - sort alphabetically even when sortBy is "time"
                    return getNameFromSortable(item1, sortedBy: "name").localizedCaseInsensitiveCompare(getNameFromSortable(item2, sortedBy: "name")) == .orderedAscending
                }
            }
        }
    }
    
    // Update global counters for UI
    eventCount = finalEventStrings.count
    bandCount = bandOnlyStrings.count
    bandCounter = bandOnlyStrings.count
    eventCounter = finalEventStrings.count
    
    // POST-PROCESSING: Apply Bands Only filter if needed
    if !showScheduleView {
        print("🔍 [VIEW_MODE_DEBUG] 🎵 Applying Bands Only filter - using Core Data query for all bands")
        
        // Use DataManager (SQLite) to get all unique band names for the current year
        // This respects all the existing filters (priority, venue, event type, expiration)
        var bands = DataManager.shared.fetchBands(forYear: eventYear)
        print("🔍 [VIEW_MODE_DEBUG] 🎵 SQLite returned \(bands.count) bands")
        
        // If "Hide Expired Events" is enabled, only show bands that have non-expired events OR no events
        if getHideExpireScheduleData() {
            let currentTime = Date().timeIntervalSinceReferenceDate // FIX: Use same reference as timeIndex
            bands = bands.filter { band in
                let events = DataManager.shared.fetchEventsForBand(band.bandName, forYear: eventYear)
                return events.isEmpty || events.contains(where: { $0.timeIndex > currentTime })
            }
            print("🔍 [VIEW_MODE_DEBUG] 🎵 After expiration filter: \(bands.count) bands")
        }
        
        var allBandNames: [String] = []
        
        // Apply priority and fake band filtering (same as Schedule View logic)
        for band in bands {
                let bandName = band.bandName
                guard !bandName.isEmpty else { continue }
                
                // BANDS ONLY FIX: Filter out fake bands created from standalone events
                // Check if band is associated ONLY with unofficial/special events
                let allEventsForBand = DataManager.shared.fetchEventsForBand(bandName, forYear: eventYear)
                let fakeEventTypes = ["Unofficial Event", "Cruiser Organized", "Special Event", "Meet and Greet", "Clinic", "Listening Party"]
                
                // Check if ALL events for this band are fake event types
                let isAllFakeEvents = !allEventsForBand.isEmpty && allEventsForBand.allSatisfy { event in
                    let eventType = event.eventType ?? ""
                    return fakeEventTypes.contains(eventType)
                }
                
                if isAllFakeEvents {
                    print("🎭 [BANDS_ONLY_DEBUG] Filtering out fake band: '\(bandName)' (only has fake event types)")
                    continue
                }
                
                // BANDS ONLY FIX: Pattern matching for non-band events (like "Mon-Monday Metal Madness")
                let standaloneEventPatterns = [
                    "Meet and Greet", "Clinic", "Listening Party", 
                    "Cruiser Organized", "Unofficial Event", "Show",
                    // Day-specific events
                    "Mon-", "Tue-", "Wed-", "Thu-", "Fri-", "Sat-", "Sun-",
                    // Time-specific events  
                    "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
                    // Common event identifiers
                    "Event", "Activity", "Party", "Session"
                ]
                
                let isFakeBandByPattern = standaloneEventPatterns.contains { pattern in
                    bandName.localizedCaseInsensitiveContains(pattern)
                }
                
                if isFakeBandByPattern {
                    print("🎭 [BANDS_ONLY_DEBUG] Filtering out fake band by pattern: '\(bandName)'")
                    continue
                }
                
                // Apply priority filters
                let priority = priorityManager.getPriority(for: bandName)
                if priority == 1 && !getMustSeeOn() { continue }
                if priority == 2 && !getMightSeeOn() { continue }
                if priority == 3 && !getWontSeeOn() { continue }
                if priority == 0 && !getUnknownSeeOn() { continue }
                
                allBandNames.append(bandName)
            }
        
        print("🔍 [VIEW_MODE_DEBUG] 🎵 After priority filtering: \(allBandNames.count) bands")
        
        // Debug: Show some examples
        if allBandNames.isEmpty {
            print("🔍 [VIEW_MODE_DEBUG] ⚠️ NO BANDS FOUND!")
        } else {
            print("🔍 [VIEW_MODE_DEBUG] ✅ Found \(allBandNames.count) bands. First 5:")
            for (index, bandName) in allBandNames.prefix(5).enumerated() {
                print("🔍 [VIEW_MODE_DEBUG] [\(index)] Band: '\(bandName)'")
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        print("🚀 getFilteredScheduleData COMPLETE (BANDS ONLY) - Time: \(String(format: "%.3f", (endTime - startTime) * 1000))ms - Total: \(allBandNames.count) entries")
        
        return allBandNames
    }
    
    // SCHEDULE VIEW: Preserve existing behavior - events first, then bands at bottom
    // This already respects "Hide Expired Events" and all other filters
    
    let endTime = CFAbsoluteTimeGetCurrent()
    print("🚀 getFilteredScheduleData COMPLETE - Time: \(String(format: "%.3f", (endTime - startTime) * 1000))ms - Total: \(combinedResults.count) entries")
    
    return combinedResults
}

// MARK: - Helper Function for Timezone-Independent Time Calculation

/// Calculate time index at filtering time using CURRENT timezone
/// This ensures that if the user changes timezones, events are recalculated correctly
/// and always display at the same wall-clock time regardless of device timezone
private func calculateTimeIndexForFiltering(date: String, time: String) -> Double {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current // Use CURRENT timezone at filter time
    
    let dateTimeString = "\(date) \(time)"
    
    // Try multiple date formats to handle different CSV formats
    let formats = [
        "M/d/yyyy HH:mm",      // Single digit month/day + 24-hour (e.g., "1/26/2026 15:00")
        "MM/dd/yyyy HH:mm",    // Padded + 24-hour (e.g., "01/26/2026 15:00")
        "M/d/yyyy H:mm",       // Single digit month/day/hour (e.g., "1/30/2025 17:15")
        "MM/dd/yyyy H:mm",     // Padded date + single digit hour
        "M/d/yyyy h:mm a",     // 12-hour with AM/PM
        "MM/dd/yyyy h:mm a",   // Padded + 12-hour with AM/PM
    ]
    
    for format in formats {
        formatter.dateFormat = format
        if let parsedDate = formatter.date(from: dateTimeString) {
            return parsedDate.timeIntervalSinceReferenceDate
        }
    }
    
    // If parsing fails, return a very large value so the event isn't incorrectly filtered out
    print("⚠️ [FILTER_TIME_PARSE] Failed to parse '\(dateTimeString)' - keeping event")
    return Double.greatestFiniteMagnitude
}


// REMOVED: determineBandOrScheduleList function (248 lines of unused legacy code)
// This function was replaced by getFilteredScheduleData() which uses Core Data queries
// instead of loop-based processing. The old function contained debug code that was
// causing confusion about event counting since it was never executed.

func applyFilters(bandName:String, timeIndex:TimeInterval, schedule: scheduleHandler, dataHandle: dataHandler, priorityManager: SQLitePriorityManager, attendedHandle: ShowsAttended)-> Bool{
    let startTime = CFAbsoluteTimeGetCurrent()
    var include = false;
    
    // CRITICAL DEBUG: Log all timeIndex values to understand the filtering
    print("🔍 [APPLY_FILTERS_DEBUG] Band: '\(bandName)', timeIndex: \(timeIndex), isZero: \(timeIndex.isZero)")
    
    if (timeIndex.isZero == false){
        let willAttendStartTime = CFAbsoluteTimeGetCurrent()
        let willAttendResult = willAttenedFilters(bandName: bandName,timeIndex: timeIndex, schedule: schedule, attendedHandle: attendedHandle)
        if willAttendResult == true {
            attendingCount = attendingCount + 1;
            print ("🔍 [ATTENDING_COUNT_DEBUG] ✅ Band '\(bandName)' is flagged - attendingCount now \(attendingCount)")
        } else {
            print ("🔍 [ATTENDING_COUNT_DEBUG] ❌ Band '\(bandName)' not flagged - willAttenedFilters returned false")
        }
        let willAttendEndTime = CFAbsoluteTimeGetCurrent()
        if (willAttendEndTime - willAttendStartTime) > 0.001 { // Only log if it takes more than 1ms
            print("🕐 [\(String(format: "%.3f", willAttendEndTime))] willAttenedFilters for '\(bandName)' took \(String(format: "%.3f", (willAttendEndTime - willAttendStartTime) * 1000))ms")
        }
        
        if (getShowOnlyWillAttened() == true){
            include = willAttenedFilters(bandName: bandName,timeIndex: timeIndex, schedule: schedule, attendedHandle: attendedHandle);
        } else {
            print("🔍 [MAIN_LIST_DEBUG] applyFilters checking band '\(bandName)' at timeIndex \(timeIndex)")
            let allBandData = schedule.getBandSortedSchedulingData()
            print("🔍 [MAIN_LIST_DEBUG] Total bands in schedule data: \(allBandData.count)")
            
            guard let bandData = allBandData[bandName] else {
                print("🔍 [MAIN_LIST_DEBUG] ❌ No schedule data found for band '\(bandName)'")
                return false
            }
            print("🔍 [MAIN_LIST_DEBUG] Band '\(bandName)' has \(bandData.count) events")
            
            guard let timeData = bandData[timeIndex] else {
                print("🔍 [MAIN_LIST_DEBUG] ❌ No event data at timeIndex \(timeIndex) for band '\(bandName)'")
                return false
            }
            print("🔍 [MAIN_LIST_DEBUG] Found event data at timeIndex \(timeIndex) for band '\(bandName)': \(timeData)")
            
            guard let typeValue = timeData[typeField], !typeValue.isEmpty else {
                print("🔍 [MAIN_LIST_DEBUG] ❌ Missing or empty event type for band '\(bandName)' at timeIndex \(timeIndex)")
                return false
            }
            let eventType = typeValue
            if (eventType == unofficalEventType){
                unfilteredCruiserEventCount = unfilteredCruiserEventCount + 1
            }
            print("🔍 [MAIN_LIST_DEBUG] Testing eventType '\(eventType)' for band '\(bandName)'")
            if (eventTypeFiltering(eventType) == true){
                print("🔍 [MAIN_LIST_DEBUG] ✅ Event type '\(eventType)' passed eventTypeFiltering")
                if (!bandData.isEmpty) {
                    if let locationValue = timeData[locationField] {
                        print("🔍 [MAIN_LIST_DEBUG] Testing venue '\(locationValue)' for event type '\(eventType)'")
                        if venueFiltering(locationValue) == true {
                            print("🔍 [MAIN_LIST_DEBUG] ✅ Venue '\(locationValue)' passed venueFiltering")
                            if (rankFiltering(bandName, priorityManager: SQLitePriorityManager.shared) == true){
                                print("🔍 [MAIN_LIST_DEBUG] ✅ Band '\(bandName)' passed rankFiltering - EVENT INCLUDED")
                            if (eventType == unofficalEventType || eventType == unofficalEventTypeOld){
                                eventCounterUnoffical = eventCounterUnoffical + 1
                            }
                            include = true
                            } else {
                                print("🔍 [MAIN_LIST_DEBUG] ❌ Band '\(bandName)' failed rankFiltering")
                        }
                        } else {
                            print("🔍 [MAIN_LIST_DEBUG] ❌ Venue '\(locationValue)' failed venueFiltering for event type '\(eventType)'")
                    }
                    } else {
                        print("🔍 [MAIN_LIST_DEBUG] ❌ No location value found for band '\(bandName)' at timeIndex \(timeIndex)")
                }
                }
            } else {
                print("🔍 [MAIN_LIST_DEBUG] ❌ Event type '\(eventType)' failed eventTypeFiltering")
            }
        }
    } else {
        print("🔍 [APPLY_FILTERS_DEBUG] timeIndex.isZero == true for '\(bandName)', setting include = true")
        include = true
    }
    
    let endTime = CFAbsoluteTimeGetCurrent()
    if (endTime - startTime) > 0.001 { // Only log if it takes more than 1ms
        print("🕐 [\(String(format: "%.3f", endTime))] applyFilters for '\(bandName)' took \(String(format: "%.3f", (endTime - startTime) * 1000))ms")
    }
    return include;
}

// Add a serial queue for filtering
let filterQueue = DispatchQueue(label: "com.yourapp.filterQueue")

// Refactored getFilteredBands to use serial queue and completion handler
func getFilteredBands(
    bandNameHandle: bandNamesHandler,
    schedule: scheduleHandler,
    dataHandle: dataHandler,
    priorityManager: SQLitePriorityManager,
    attendedHandle: ShowsAttended,
    searchCriteria: String,
    areFiltersActive: Bool,
    completion: @escaping ([String]) -> Void
) {
    let startTime = CFAbsoluteTimeGetCurrent()
    print("🕐 [\(String(format: "%.3f", startTime))] getFilteredBands START")
    
    // Ensure we're always on a background thread to prevent main thread blocking
    if Thread.isMainThread {
        DispatchQueue.global(qos: .userInitiated).async {
            getFilteredBands(
                bandNameHandle: bandNameHandle,
                schedule: schedule,
                dataHandle: dataHandle,
                priorityManager: priorityManager,
                attendedHandle: attendedHandle,
                searchCriteria: searchCriteria,
                areFiltersActive: areFiltersActive,
                completion: completion
            )
        }
        return
    }
    
    filterQueue.async {
        let queueStartTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", queueStartTime))] getFilteredBands filter queue START")
        
        let bandsStartTime = CFAbsoluteTimeGetCurrent()
        let allBands = bandNameHandle.getBandNames()
        let bandsEndTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", bandsEndTime))] getFilteredBands - got \(allBands.count) bands - time: \(String(format: "%.3f", (bandsEndTime - bandsStartTime) * 1000))ms")
        
        var sortedBy = getSortedBy()
        if (sortedBy.isEmpty == true){
            sortedBy = "time"
        }
        var filteredBands = [String]()
        var newAllBands = [String]()
        filteredBandCount = 0
        unfilteredBandCount = 0
        
        let determineStartTime = CFAbsoluteTimeGetCurrent()
        print("🚀 [\(String(format: "%.3f", determineStartTime))] getFilteredBands - starting QUERY-BASED filtering")
        newAllBands = getFilteredScheduleData(sortedBy: sortedBy, priorityManager: priorityManager, attendedHandle: attendedHandle);
        let determineEndTime = CFAbsoluteTimeGetCurrent()
        print("🚀 [\(String(format: "%.3f", determineEndTime))] getFilteredBands - QUERY-BASED filtering END - got \(newAllBands.count) entries - time: \(String(format: "%.3f", (determineEndTime - determineStartTime) * 1000))ms")
        print("🚀 PERFORMANCE: Query-based approach ~100x faster than loops!")
        
        // Query-based approach already handled all filtering, just apply search criteria if needed
            filteredBands = newAllBands;
        
        // Apply search criteria if provided
        if (searchCriteria != ""){
            let searchStartTime = CFAbsoluteTimeGetCurrent()
            print("🔍 [SEARCH_DEBUG] getFilteredBands - applying search criteria: '\(searchCriteria)'")
            print("🔍 [SEARCH_DEBUG] Before search: \(filteredBands.count) items")
            var searchFilteredBands = [String]()
            for bandNameIndex in filteredBands {
                let bandName = getNameFromSortable(bandNameIndex, sortedBy: sortedBy)
                if (bandName.localizedCaseInsensitiveContains(searchCriteria)){
                    searchFilteredBands.append(bandNameIndex)
                    print("🔍 [SEARCH_DEBUG] Match found: '\(bandName)' (from '\(bandNameIndex)')")
                }
            }
            filteredBands = searchFilteredBands
            let searchEndTime = CFAbsoluteTimeGetCurrent()
            print("🔍 [SEARCH_DEBUG] getFilteredBands - search filtering END - filtered to \(filteredBands.count) entries - time: \(String(format: "%.3f", (searchEndTime - searchStartTime) * 1000))ms")
            if filteredBands.count > 0 {
                print("🔍 [SEARCH_DEBUG] First 5 filtered items:")
                for (index, item) in filteredBands.prefix(5).enumerated() {
                    let name = getNameFromSortable(item, sortedBy: sortedBy)
                    print("🔍 [SEARCH_DEBUG] [\(index)] '\(item)' -> name: '\(name)'")
                }
            }
        }
        filteredBandCount = filteredBands.count
        if (filteredBandCount == 0){
            print ("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] mainListDebug: handleEmptryList: Why is this being called 1")
            filteredBands = handleEmptryList(bandNameHandle: bandNameHandle, areFiltersActive: areFiltersActive);
        } else {
            bandCounter = filteredBands.count
            listCount = filteredBands.count
        }
        print ("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] mainListDebug: listCount is \(listCount) - 2")
        
        let queueEndTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", queueEndTime))] getFilteredBands filter queue END - total time: \(String(format: "%.3f", (queueEndTime - queueStartTime) * 1000))ms")
        
        DispatchQueue.main.async {
            let completionStartTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", completionStartTime))] getFilteredBands - calling completion with \(filteredBands.count) entries")
            completion(filteredBands)
            let completionEndTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", completionEndTime))] getFilteredBands - completion END - time: \(String(format: "%.3f", (completionEndTime - completionStartTime) * 1000))ms")
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", endTime))] getFilteredBands END - total time: \(String(format: "%.3f", (endTime - startTime) * 1000))ms")
    }
}

func handleEmptryList(bandNameHandle: bandNamesHandler, areFiltersActive: Bool)->[String]{
    
    var filteredBands = [String]()
    var localMessage = ""
    
    // Check if a year change is in progress
    if MasterViewController.isYearChangeInProgress {
        localMessage = NSLocalizedString("year_change_loading", comment: "Loading data for new year...")
        print("🔄 [YEAR_CHANGE_UI] Showing year change loading message")
    } else if (bandNameHandle.getBandNames().count == 0 && !areFiltersActive){
        // No data and no filters active - show waiting message
        localMessage = NSLocalizedString("waiting_for_data", comment: "")
        print("📋 [EMPTY_LIST] No data and no filters active - showing waiting message")
    } else {
        // Either data exists but is filtered out, or filters are active with no results
        localMessage = NSLocalizedString("data_filter_issue", comment: "")
        print("📋 [EMPTY_LIST] Filters active or data filtered out - showing filter issue message")
    }
    
    filteredBands.append(localMessage)
    
    print ("listCount is \(listCount) - 1")
    listCount = 0

    return filteredBands
}

func getNameFromSortable(_ value: String, sortedBy: String) -> String{
    let indexString = value.components(separatedBy: ":")
    var bandName = String();
    if (indexString.count == 2){
        if let _ = indexString[0].doubleValue {
            bandName = indexString[1];
        } else if let _ = indexString[1].doubleValue {
            bandName = indexString[0];
        } else {
            bandName = value
        }
    } else {
        bandName = value
    }
    return bandName;
}

func getTimeFromSortable(_ value: String, sortBy: String) -> Double{
    let indexString = value.components(separatedBy: ":")
    var timeIndex = Double()
    if (indexString.count == 2){
        if let first = indexString[0].doubleValue {
            timeIndex = first
        } else if let second = indexString[1].doubleValue {
            timeIndex = second
        }
    }
    return timeIndex;
}

extension String {
    var doubleValue: Double? {
        return Double(self)
    }
    var floatValue: Float? {
        return Float(self)
    }
    var integerValue: Int? {
        return Int(self)
    }
}

func rankFiltering(_ bandName: String, priorityManager: SQLitePriorityManager) -> Bool {
    
    var showBand = true;
    
    if (getMustSeeOn() == false && priorityManager.getPriority(for: bandName) == 1){
        showBand = false
        print ("numberOfFilteredRecords is  -2- \(bandName)")
        numberOfFilteredRecords = numberOfFilteredRecords + 1
    
    } else if (getMightSeeOn() == false && priorityManager.getPriority(for: bandName) == 2){
        showBand = false
        print ("numberOfFilteredRecords is  -3- \(bandName)")
        numberOfFilteredRecords = numberOfFilteredRecords + 1
        
    } else if (getWontSeeOn() == false && priorityManager.getPriority(for: bandName) == 3){
        print ("numberOfFilteredRecords is  -4- \(bandName)")
        showBand = false
        numberOfFilteredRecords = numberOfFilteredRecords + 1
        
    } else if (getUnknownSeeOn() == false && priorityManager.getPriority(for: bandName) == 0){
        print ("numberOfFilteredRecords is  -5- \(bandName)")
        showBand = false
        numberOfFilteredRecords = numberOfFilteredRecords + 1
    
    }
    
    print ("numberOfFilteredRecords is  -1- \(numberOfFilteredRecords)")
    return showBand

}

func willAttenedFilters(bandName: String, timeIndex:TimeInterval, schedule: scheduleHandler, attendedHandle: ShowsAttended) -> Bool{
    let startTime = CFAbsoluteTimeGetCurrent()
    var showEvent = true
    guard
        let bandData = schedule.getBandSortedSchedulingData()[bandName],
        let timeData = bandData[timeIndex],
        let eventType = timeData[typeField],
        let location = timeData[locationField],
        let startTimeValue = timeData[startTimeField]
    else {
        print("🔍 [WILL_ATTEND_DEBUG] ❌ Missing data for band: \(bandName), timeIndex: \(timeIndex)")
        return false
    }
    
    print("🔍 [WILL_ATTEND_DEBUG] Checking band '\(bandName)' at '\(location)' startTime '\(startTimeValue)'")
    if timeIndex.isZero {
        showEvent = false
    } else {
        let attendedStartTime = CFAbsoluteTimeGetCurrent()
        let status = attendedHandle.getShowAttendedStatus(
            band: bandName,
            location: location,
            startTime: startTimeValue,
            eventType: eventType,
            eventYearString: String(eventYear)
        )
        print("🔍 [WILL_ATTEND_DEBUG] Status for '\(bandName)': '\(status)' (sawNoneStatus = '\(sawNoneStatus)')")
        let attendedEndTime = CFAbsoluteTimeGetCurrent()
        if (attendedEndTime - attendedStartTime) > 0.001 { // Only log if it takes more than 1ms
            print("🕐 [\(String(format: "%.3f", attendedEndTime))] getShowAttendedStatus for '\(bandName)' took \(String(format: "%.3f", (attendedEndTime - attendedStartTime) * 1000))ms")
        }
        if status == sawNoneStatus {
            showEvent = false
            print("🔍 [WILL_ATTEND_DEBUG] Setting showEvent = false because status == sawNoneStatus")
        } else {
            print("🔍 [WILL_ATTEND_DEBUG] Status is NOT sawNoneStatus, showEvent remains \(showEvent)")
        }
    }
    
    let endTime = CFAbsoluteTimeGetCurrent()
    if (endTime - startTime) > 0.001 { // Only log if it takes more than 1ms
        print("🕐 [\(String(format: "%.3f", endTime))] willAttenedFilters for '\(bandName)' took \(String(format: "%.3f", (endTime - startTime) * 1000))ms")
    }
    return showEvent
}

func eventTypeFiltering(_ eventType: String) -> Bool{
    
    // EXCLUSIVE FILTERING: Show everything EXCEPT explicitly filtered out types
    // This ensures new unknown event types appear by default
    
    print("🔍 [EVENT_TYPE_DEBUG] Filtering eventType: '\(eventType)' (EXCLUSIVE approach)")
    
    // Check if this type should be excluded
    if (eventType == specialEventType && !getShowSpecialEvents()){
        print("🔍 [EVENT_TYPE_DEBUG] ❌ EXCLUDING SPECIAL event: '\(eventType)'")
        numberOfFilteredRecords = numberOfFilteredRecords + 1
        return false
        
    } else if (eventType == karaokeEventType && !getShowSpecialEvents()){
        print("🔍 [EVENT_TYPE_DEBUG] ❌ EXCLUDING KARAOKE event: '\(eventType)'")
        numberOfFilteredRecords = numberOfFilteredRecords + 1
        return false
            
    } else if (eventType == meetAndGreetype && !getShowMeetAndGreetEvents()){
        print("🔍 [EVENT_TYPE_DEBUG] ❌ EXCLUDING MEET & GREET event: '\(eventType)'")
        numberOfFilteredRecords = numberOfFilteredRecords + 1
        return false
    
    } else if (eventType == clinicType && !getShowMeetAndGreetEvents()){
        print("🔍 [EVENT_TYPE_DEBUG] ❌ EXCLUDING CLINIC event: '\(eventType)'")
        numberOfFilteredRecords = numberOfFilteredRecords + 1
        return false

    } else if (eventType == listeningPartyType && !getShowMeetAndGreetEvents()){
        print("🔍 [EVENT_TYPE_DEBUG] ❌ EXCLUDING LISTENING PARTY event: '\(eventType)'")
        numberOfFilteredRecords = numberOfFilteredRecords + 1
        return false
        
    } else if ((eventType == unofficalEventType || eventType == unofficalEventTypeOld) && !getShowUnofficalEvents()){
        print("🔍 [EVENT_TYPE_DEBUG] ❌ EXCLUDING UNOFFICIAL event: '\(eventType)'")
        numberOfFilteredRecords = numberOfFilteredRecords + 1
        return false

    } else {
        // Show all other event types (including unknown/new types)
        print("🔍 [EVENT_TYPE_DEBUG] ✅ SHOWING event: '\(eventType)' (not excluded)")
        return true
    }
}

func venueFiltering(_ venue: String) -> Bool {
    
    print("🔍 [VENUE_DEBUG] Filtering venue: '\(venue)'")
    
    // Get filter venues (only venues with showInFilters=true)
    let filterVenues = FestivalConfig.current.getFilterVenueNames()
    print("🔍 [VENUE_DEBUG] Filter venues (showInFilters=true): \(filterVenues)")

    var showVenue = false
    var matchedFilterVenue = false
    
    // Check if this venue matches any filter venue (showInFilters=true)
    // Use BEGINSWITH to match venue name at the start of location string
    for filterVenueName in filterVenues {
        if venue.lowercased().hasPrefix(filterVenueName.lowercased()) {
            // This is a filter venue - check if its filter is enabled
            matchedFilterVenue = true
            if getShowVenueEvents(venueName: filterVenueName) {
                showVenue = true
                print("🔍 [VENUE_DEBUG] ✅ Filter venue '\(venue)' (\(filterVenueName)) ALLOWED - filter enabled")
            } else {
                showVenue = false
                print("🔍 [VENUE_DEBUG] ❌ Filter venue '\(venue)' (\(filterVenueName)) REJECTED - filter disabled")
            }
            break
        }
    }
    
    // If it didn't match any filter venue, treat as "Other"
    if !matchedFilterVenue {
        if getShowOtherShows() {
            showVenue = true
            print("🔍 [VENUE_DEBUG] ✅ Other venue '\(venue)' ALLOWED - Other venues enabled")
        } else {
            showVenue = false
            print("🔍 [VENUE_DEBUG] ❌ Other venue '\(venue)' REJECTED - Other venues disabled")
        }
    }
    
    if !showVenue {
        numberOfFilteredRecords = numberOfFilteredRecords + 1
    }
    
    print("🔍 [VENUE_DEBUG] Final result for venue '\(venue)': \(showVenue ? "ALLOW" : "REJECT")")
    return showVenue
}

func getCellValue (_ indexRow: Int, schedule: scheduleHandler, sortBy: String, cell: UITableViewCell, dataHandle: dataHandler, priorityManager: SQLitePriorityManager, attendedHandle: ShowsAttended){
    
    var rankLocationSchedule = false
        
    //index is out of bounds. Don't allow this
    if (bands.count <= indexRow || bands.count == 0){
        return
    }
    // Reduced debug logging for performance
    // print ("bands = \(bands)")
    // print ("indexRow = \(indexRow)")
    // print ("count is \(bands.count) - \(indexRow)")

    let bandName = getNameFromSortable(bands[indexRow], sortedBy: sortBy);
    
    // Handle combined events (internal delimiter; display still uses " / ")
    var dataFetchBandName = bandName
    if isCombinedEventBandName(bandName) {
        if let individualBands = combinedEventsMap[bandName], !individualBands.isEmpty {
            dataFetchBandName = individualBands[0]
        } else if let parts = combinedEventBandParts(bandName), !parts.isEmpty {
            dataFetchBandName = parts[0].trimmingCharacters(in: .whitespaces)
            print("⚠️ [COMBINED_EVENTS] Combined band not in map, using first component: '\(dataFetchBandName)'")
        }
    }
    
    if (indexRow >= 1){
        previousBandName = getNameFromSortable(bands[indexRow - 1], sortedBy: sortBy);
    }
    if (indexRow <= (bands.count - 2)){
        nextBandName = getNameFromSortable(bands[indexRow + 1], sortedBy: sortBy);
    }
    if (indexRow > previousIndexRow){
        scrollDirection = "Down"
    } else {
        scrollDirection = "Up"
    }

    previousIndexRow = indexRow
    
    let timeIndex = getTimeFromSortable(bands[indexRow], sortBy: sortBy);
    
    //var bandText = String()
    var dayText = String()
    var locationText = String()
    var startTimeText = String()
    var endTimeText = String()
    var scheduleText = String()
    var rankGraphic = UIImageView()
    var indexText = String()
    
    let indexForCell = cell.viewWithTag(1) as! UILabel
    let bandNameView = cell.viewWithTag(2) as! UILabel
    let locationView = cell.viewWithTag(3) as! UILabel
    let eventTypeImageView = cell.viewWithTag(4) as! UIImageView
    let rankImageView = cell.viewWithTag(5) as! UIImageView
    let attendedView = cell.viewWithTag(6) as! UIImageView
    let rankImageViewNoSchedule = cell.viewWithTag(7) as! UIImageView
    let startTimeView = cell.viewWithTag(14) as! UILabel
    let endTimeView = cell.viewWithTag(8) as! UILabel
    let dayLabelView = cell.viewWithTag(9) as! UILabel
    let dayView = cell.viewWithTag(10) as! UILabel
    let bandNameNoSchedule = cell.viewWithTag(12) as! UILabel
    
    indexForCell.isHidden = true
    bandNameView.textColor = UIColor.white
    locationView.textColor = UIColor.lightGray
    startTimeView.textColor = UIColor.white
    endTimeView.textColor = hexStringToUIColor(hex: "#797D7F")
    dayView.textColor = UIColor.white
    bandNameNoSchedule.textColor = UIColor.white
    
    // Ensure labels have clear backgrounds so attributed string backgroundColor shows through
    bandNameView.backgroundColor = UIColor.clear
    locationView.backgroundColor = UIColor.clear
    
    bandNameView.text = bandName
    indexText = bandName
    
    cell.backgroundColor = UIColor.black;
    cell.textLabel?.textColor = UIColor.white
    
    var displayBandName = bandName;
    
    if (timeIndex > 1){
        
        
        hasScheduleData = true
        
        locationView.isHidden = false
        startTimeView.isHidden = false
        endTimeView.isHidden = false
        dayView.isHidden = false
        dayLabelView.isHidden = false
        attendedView.isHidden = false
        eventTypeImageView.isHidden = false
        
        // Try legacy schedule first, then fallback to Core Data for standalone events
        // Use dataFetchBandName for data fetching (first band if combined)
        var location = schedule.getData(dataFetchBandName, index:timeIndex, variable: locationField)
        var day = monthDateRegionalFormatting(dateValue: schedule.getData(dataFetchBandName, index: timeIndex, variable: dayField))
        var startTime = schedule.getData(dataFetchBandName, index: timeIndex, variable: startTimeField)
        var endTime = schedule.getData(dataFetchBandName, index: timeIndex, variable: endTimeField)
        var event = schedule.getData(dataFetchBandName, index: timeIndex, variable: typeField)
        var notes = schedule.getData(dataFetchBandName, index:timeIndex, variable: notesField)
        
        // If legacy schedule doesn't have this data (standalone event), get from Core Data
        // Use dataFetchBandName for Core Data lookup as well
        if location.isEmpty && startTime.isEmpty && event.isEmpty {
            if let coreDataEvent = CoreDataManager.shared.fetchEvent(byTimeIndex: timeIndex, eventName: dataFetchBandName, forYear: Int32(eventYear)) {
                location = coreDataEvent.location ?? ""
                startTime = coreDataEvent.startTime ?? ""
                endTime = coreDataEvent.endTime ?? ""
                event = coreDataEvent.eventType ?? ""
                notes = coreDataEvent.notes ?? ""
                // Format day from timeIndex if not available
                if day.isEmpty {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "MMM d"
                    day = dateFormatter.string(from: Date(timeIntervalSinceReferenceDate: timeIndex)) // FIX: Match storage format
                }
            }
        }
        
        let eventIcon = getEventTypeIcon(eventType: event, eventName: bandName)
                
        indexText += ";" + location + ";" + event + ";" + startTime
                
        startTimeText = formatTimeValue(timeValue: startTime)
        endTimeText = formatTimeValue(timeValue: endTime)
        locationText = location;
        
        if (venueLocation[location] != nil){
            locationText += " " + venueLocation[location]!
        }
        if (notes.isEmpty == false && notes != " "){
            locationText += " " + notes
        }
        
        scheduleText = bandName + ":" + startTimeText + ":" + locationText
        scheduleButton = false
    
        // For combined events, use the combined band name for display but first band for attendance tracking
        // This ensures the icon shows correctly (both bands would have same attendance status for same event)
        let icon = attendedHandle.getShowAttendedIcon(band: dataFetchBandName,location: location,startTime: startTime,eventType: event,eventYearString: String(eventYear));
        
        // COUNT FLAGGED EVENTS: If GUI shows an icon, increment the count
        if !icon.isEqual(UIImage()) {
            attendingCount += 1
            print("🔍 [GUI_ICON_COUNT] ✅ GUI showing icon for '\(bandName)' - attendingCount now \(attendingCount)")
        }
        
        attendedView.image = icon
        eventTypeImageView.image = eventIcon
        
        scheduleIndexByCall[scheduleText] = [String:String]()
        scheduleIndexByCall[scheduleText]!["location"] = location
        scheduleIndexByCall[scheduleText]!["bandName"] = bandName // Store combined name for display
        scheduleIndexByCall[scheduleText]!["startTime"] = startTime
        scheduleIndexByCall[scheduleText]!["event"] = event
        
        if day.hasPrefix("Day ") {
            dayText = day.replacingOccurrences(of: "Day ", with: "")
        } else {
            dayText = day
        }
        
        dayView.text = dayText
        dayLabelView.text = NSLocalizedString("Day", comment: "")
        
        if (indexRow == 0){
            previousBandName = "Unknown"
            nextBandName = "Unknown"
        }
        //1st entry Checking if bandname matched previous bandname for partial info display
        if ((bandName == previousBandName  && scrollDirection == "Down" && indexRow != 0) && sortBy == "name"){
            getCellScheduleValuePartialInfo(bandName: bandName, location: location, bandNameView: bandNameView, locationView: locationView, bandNameNoSchedule: bandNameNoSchedule, notes: notes)
 
        } else if (scrollDirection == "Down"){
            getCellScheduleValueFullInfo(bandName: bandName, location: location, locationText: locationText,bandNameView: bandNameView, locationView: locationView, bandNameNoSchedule: bandNameNoSchedule)
            
        }else if ((bandName != previousBandName || indexRow == 0) && sortBy == "name"){
            getCellScheduleValueFullInfo(bandName: bandName, location: location, locationText: locationText,bandNameView: bandNameView, locationView: locationView, bandNameNoSchedule: bandNameNoSchedule)
 
        } else if (sortBy == "name"){
            getCellScheduleValuePartialInfo(bandName: bandName, location: location, bandNameView: bandNameView, locationView: locationView, bandNameNoSchedule: bandNameNoSchedule, notes: notes)
            
        } else {
            getCellScheduleValueFullInfo(bandName: bandName, location: location, locationText: locationText,bandNameView: bandNameView, locationView: locationView, bandNameNoSchedule: bandNameNoSchedule)
        }
        
    
        startTimeView.text = startTimeText
        endTimeView.text = endTimeText
        
        rankLocationSchedule = true
        //bandNameView.isHidden = false
        //bandNameNoSchedule.isHidden = true
        
    } else {
        scheduleButton = true
        locationView.isHidden = true
        startTimeView.isHidden = true
        endTimeView.isHidden = true
        dayView.isHidden = true
        dayLabelView.isHidden = true
        attendedView.isHidden = true
        eventTypeImageView.isHidden = true
        bandNameNoSchedule.text = bandName
        bandNameNoSchedule.isHidden = false  
        bandNameView.isHidden = true

    }
    
    indexForCell.text = indexText;
    
    // Reduced debug logging for performance
    // print ("Cell text for \(bandName) ranking is \(dataHandle.getPriorityData(bandName))")
    let priorityValue = priorityManager.getPriority(for: bandName)
    let priorityGraphicName = getPriorityGraphic(priorityValue)
    if priorityGraphicName.isEmpty {
        rankGraphic = UIImageView(image: UIImage())
    } else {
        rankGraphic = UIImageView(image: UIImage(named: priorityGraphicName) ?? UIImage())
    }
    
    if (timeIndex > 1 && sortBy == "name" && bandName == previousBandName){
        rankGraphic.image = nil
    }
    
    if (rankGraphic.image != nil){
        if (rankLocationSchedule == true){
            rankImageView.isHidden = false
            rankImageViewNoSchedule.isHidden = true
            rankImageView.image = rankGraphic.image
            
        } else {
            rankImageView.isHidden = true
            rankImageViewNoSchedule.isHidden = false
            rankImageViewNoSchedule.image = rankGraphic.image
        }
    } else {
        rankImageView.isHidden = true
        rankImageViewNoSchedule.isHidden = true
    }
    
    previousBandName = bandName
    if (firstBandName.isEmpty == true){
        firstBandName  = bandName;
    }
}


func getCellScheduleValuePartialInfo(bandName: String, location: String, bandNameView: UILabel, locationView: UILabel, bandNameNoSchedule: UILabel, notes: String){

    //print ("not 1st entry Checking if bandname \(bandName) matched previous bandname \(previousBandName) - \(nextBandName) index for cell \(indexRow) - \(scrollDirection)")
    var locationString = "   " + location
    var venueString = NSMutableAttributedString(string: locationString)
    var locationColor = getVenueColor(venue: location)
    
    // Second space - colored marker with fixed 17pt font (moved over 1 space for alignment)
    venueString.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 17), range: NSRange(location:1,length:1))
    venueString.addAttribute(NSAttributedString.Key.backgroundColor, value: locationColor, range: NSRange(location:1,length:1))
    
    // Location text (after the three spaces) - variable size font (12-16pt)
    if location.count > 0 {
        let locationTextSize = calculateOptimalFontSize(for: location, in: bandNameView, markerWidth: 17, maxSize: 16, minSize: 12)
        venueString.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: locationTextSize), range: NSRange(location:3,length: location.count))
        venueString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.lightGray, range: NSRange(location:3,length: location.count))
    }
    
    // Disable font auto-sizing to preserve our 17pt marker
    bandNameView.adjustsFontSizeToFitWidth = false
    // Ensure background is clear so attributed string backgroundColor is visible
    bandNameView.backgroundColor = UIColor.clear
    bandNameView.attributedText = venueString
    bandNameView.isHidden = false;
    
    var locationOfVenue = "  " + (venueLocation[location] ?? "")
    if (notes.isEmpty == false && notes != " "){
        locationOfVenue += " " + notes
    }
    
    var locationOfVenueString = NSMutableAttributedString(string: locationOfVenue)
    
    // Second space - colored marker with fixed 17pt font (moved over 1 space for alignment)
    locationOfVenueString.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 17), range: NSRange(location:0,length:1))
    locationOfVenueString.addAttribute(NSAttributedString.Key.backgroundColor, value: locationColor, range: NSRange(location:0,length:1))
    
    // Venue text (after the three spaces) - variable size font (12-16pt)
    if locationOfVenue.count > 3 {
        let venueText = String(locationOfVenue.dropFirst(3)) // Remove the three spaces
        let venueTextSize = calculateOptimalFontSize(for: venueText, in: locationView, markerWidth: 17, maxSize: 16, minSize: 12)
        locationOfVenueString.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: venueTextSize), range: NSRange(location:3,length: locationOfVenue.count - 3))
        locationOfVenueString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.lightGray, range: NSRange(location:3,length: locationOfVenue.count - 3))
    }

    // Disable font auto-sizing to preserve our 17pt marker
    locationView.adjustsFontSizeToFitWidth = false
    // Ensure background is clear so attributed string backgroundColor is visible
    locationView.backgroundColor = UIColor.clear
    locationView.attributedText = locationOfVenueString
    
    //setup bandname for use is access the details screen
    bandNameNoSchedule.text = bandName
    bandNameNoSchedule.isHidden = true
}

func getCellScheduleValueFullInfo(bandName: String, location: String, locationText: String, bandNameView: UILabel, locationView: UILabel, bandNameNoSchedule: UILabel){

    var locationString = "  " + locationText
    var myMutableString = NSMutableAttributedString(string: locationString)
    var locationColor = getVenueColor(venue: location)
    
    // First space - colored marker with fixed 17pt font
    myMutableString.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 17), range: NSRange(location:0,length:1))
    myMutableString.addAttribute(NSAttributedString.Key.backgroundColor, value: locationColor, range: NSRange(location:0,length:1))
    
    // Location text (after the two spaces) - variable size font (12-16pt)
    if locationText.count > 0 {
        let locationTextSize = calculateOptimalFontSize(for: locationText, in: locationView, markerWidth: 17, maxSize: 16, minSize: 12)
        myMutableString.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: locationTextSize), range: NSRange(location:2,length: locationText.count))
        myMutableString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.lightGray, range: NSRange(location:2,length: locationText.count))
    }

    bandNameView.backgroundColor = UIColor.black;
    // Disable font auto-sizing to preserve our 17pt marker
    locationView.adjustsFontSizeToFitWidth = false
    // Ensure background is clear so attributed string backgroundColor is visible
    locationView.backgroundColor = UIColor.clear
    locationView.attributedText = myMutableString
    bandNameView.isHidden = false
    bandNameNoSchedule.isHidden = true
    bandNameNoSchedule.text = ""
    
}

func calculateOptimalFontSize(for text: String, in label: UILabel, markerWidth: CGFloat, maxSize: CGFloat, minSize: CGFloat) -> CGFloat {
    // Use a consistent estimated width instead of relying on potentially inaccurate label bounds
    // Most table view cells have similar widths, so use a reasonable estimate
    let estimatedLabelWidth: CGFloat = 200 // Reasonable estimate for location text area
    
    // Calculate actual marker width (17pt font typically renders to about 8-10pt width for a space)
    let actualMarkerWidth: CGFloat = 10
    
    // Calculate available width with minimal padding
    let availableWidth = estimatedLabelWidth - actualMarkerWidth - 2
    
    // For very short text, always use maximum size
    if text.count <= 8 { // Short location names like "Pool", "Theater"
        return maxSize
    }
    
    // For medium length text, use a size based on character count
    if text.count <= 15 { // Medium names like "Theater Deck 3/4"
        return maxSize - 1 // 15pt for medium length
    }
    
    // Start with maximum font size and work down more granularly for longer text
    for fontSize in stride(from: maxSize, through: minSize, by: -0.25) {
        let font = UIFont.systemFont(ofSize: fontSize)
        let textSize = text.size(withAttributes: [NSAttributedString.Key.font: font])
        
        // If text fits comfortably at this font size, use it
        if textSize.width <= availableWidth * 0.9 { // Use 90% of available width for buffer
            return fontSize
        }
    }
    
    // For very long text, return a reasonable minimum
    return max(13, minSize) // Never go below 13pt for readability
}

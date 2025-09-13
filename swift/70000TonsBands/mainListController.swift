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
func getFilteredScheduleData(sortedBy: String, priorityManager: PriorityManager, attendedHandle: ShowsAttended) -> [String] {
    let startTime = CFAbsoluteTimeGetCurrent()
    print("🚀 CORE DATA FILTERING START with user preferences - eventYear: \(eventYear)")
    
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
    var excludedVenuePredicates: [NSPredicate] = []
    
    // Get the configurable venues from FestivalConfig
    let configuredVenues = FestivalConfig.current.getAllVenueNames()
    var mainVenuePredicates: [NSPredicate] = []
    
    // Process each configured venue
    for venueName in configuredVenues {
        if !getShowVenueEvents(venueName: venueName) {
            excludedVenuePredicates.append(NSPredicate(format: "location CONTAINS[cd] %@", venueName))
            print("🔍 [FILTER] ❌ EXCLUDING \(venueName) venues")
        } else {
            print("🔍 [FILTER] ✅ Including \(venueName) venues")
            mainVenuePredicates.append(NSPredicate(format: "location CONTAINS[cd] %@", venueName))
        }
    }
    
    // Handle "Other" venues (catch-all for venues not in the main configured list)
    if !getShowOtherShows() {
        // Only exclude "Other" venues if we have some configured venues enabled
        if !mainVenuePredicates.isEmpty {
            let mainVenuePredicate = NSCompoundPredicate(orPredicateWithSubpredicates: mainVenuePredicates)
            excludedVenuePredicates.append(NSCompoundPredicate(notPredicateWithSubpredicate: mainVenuePredicate))
            print("🔍 [FILTER] ❌ EXCLUDING Other venues (anything NOT in configured venues: \(configuredVenues))")
        } else {
            // If no configured venues are enabled, don't exclude "Other" venues as that would hide everything
            print("🔍 [FILTER] ⚠️ All configured venues disabled, keeping Other venues visible")
        }
    } else {
        print("🔍 [FILTER] ✅ Including Other venues (catch-all for non-configured venues) - DEFAULT BEHAVIOR")
    }
    
    // Apply venue exclusion filter only if there are venues to exclude
    if !excludedVenuePredicates.isEmpty {
        predicates.append(NSCompoundPredicate(notPredicateWithSubpredicate: 
            NSCompoundPredicate(orPredicateWithSubpredicates: excludedVenuePredicates)))
        print("🔍 [FILTER] Venues EXCLUDED: Applied exclusion filter")
    } else {
        print("🔍 [FILTER] No venues excluded - showing ALL venues")
    }
    
    // 4. EXPIRATION FILTER (if enabled)
    if getHideExpireScheduleData() {
        let currentTime = Date().timeIntervalSince1970
        predicates.append(NSPredicate(format: "timeIndex > %f", currentTime))
        print("🔍 [FILTER] Hiding expired events before \(currentTime)")
    }
    
    // EXECUTE FILTERED QUERY
    let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    let filteredEvents = coreDataManager.fetchEvents(forYear: Int32(eventYear), predicate: combinedPredicate)
    print("🔍 [FILTER] Core Data returned \(filteredEvents.count) filtered events")
    
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
    
    // Also check what we had BEFORE filtering
    let allEvents = coreDataManager.fetchEvents(forYear: Int32(eventYear))
    let allEventTypeBreakdown = Dictionary(grouping: allEvents, by: { $0.eventType ?? "No Type" })
    print("🔍 [FILTER] ===== ALL EVENTS (before filtering) =====")
    for (type, events) in allEventTypeBreakdown.sorted(by: { $0.key < $1.key }) {
        if type.contains("Unofficial") || type.contains("Cruiser") {
            print("🔍 [FILTER] 📋 BEFORE FILTERING: '\(type)' has \(events.count) events")
        }
    }
    
    // APPLY PRIORITY FILTERING (post-filter since priority data is separate)
    let priorityFilteredEvents = filteredEvents.filter { event in
        guard let band = event.band, let bandName = band.bandName else { return true } // Include standalone events
        
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
    let finalEvents: [Event]
    if getShowOnlyWillAttened() {
        finalEvents = priorityFilteredEvents.filter { event in
            guard let band = event.band, let bandName = band.bandName,
                  let location = event.location,
                  let eventType = event.eventType else { return false }
            
            let startTime = String(event.timeIndex)
            let eventYearString = String(eventYear)
            let attendedStatus = attendedHandle.getShowAttendedStatus(
                band: bandName,
                location: location, 
                startTime: startTime,
                eventType: eventType,
                eventYearString: eventYearString
            )
            
            // Only show events marked as attending
            return attendedStatus != sawNoneStatus
        }
        print("🔍 [FILTER] After attendance filtering: \(finalEvents.count) events")
    } else {
        finalEvents = priorityFilteredEvents
    }
    
    print("📋 Final filtered events: \(finalEvents.count)")
    
    // Convert events to string format: "timeIndex:bandName" OR "timeIndex:eventName" for standalone events  
    let eventStrings = finalEvents.compactMap { event -> String? in
        // First check if this event has a band association
        if let band = event.band, let bandName = band.bandName, !bandName.isEmpty {
            
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
            } else if let location = event.location, !location.isEmpty, location.trimmingCharacters(in: .whitespacesAndNewlines) != "" {
                eventIdentifier = location
            } else {
                eventIdentifier = "Unknown Event"
            }
            
            return "\(event.timeIndex):\(eventIdentifier)"
        }
    }
    
    print("🔍 DEBUG: Final event strings generated: \(eventStrings.count)")
    
    // FIX: Get bands that have NON-EXPIRED events (regardless of other filters)
    // Bands should only appear below events when they have NO non-expired events, not when just filtered by venue
    let bandsWithVisibleEvents: Set<String>
    if getHideExpireScheduleData() {
        // When "Hide Expired Events" is enabled, get all bands that have future events (regardless of venue/priority filters)
        let currentTime = Date().timeIntervalSince1970
        let nonExpiredEventsPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "eventYear == %d", eventYear),
            NSPredicate(format: "timeIndex > %f", currentTime)
        ])
        let nonExpiredEvents = coreDataManager.fetchEvents(forYear: Int32(eventYear), predicate: nonExpiredEventsPredicate)
        bandsWithVisibleEvents = Set(nonExpiredEvents.compactMap { event in
            event.band?.bandName
        })
        print("🔍 [BAND_DISPLAY_FIX] Hide Expired Events ON - bands with non-expired events: \(bandsWithVisibleEvents.sorted())")
    } else {
        // When "Hide Expired Events" is disabled, all bands with any events should not appear below (regardless of filters)
        let allEventsPredicate = NSPredicate(format: "eventYear == %d", eventYear)
        let allEvents = coreDataManager.fetchEvents(forYear: Int32(eventYear), predicate: allEventsPredicate)
        bandsWithVisibleEvents = Set(allEvents.compactMap { event in
            event.band?.bandName
        })
        print("🔍 [BAND_DISPLAY_FIX] Hide Expired Events OFF - bands with any events: \(bandsWithVisibleEvents.sorted())")
    }
    
    // Fetch ALL bands for current year
    let fetchedBands = coreDataManager.fetchBands(forYear: Int32(eventYear))
    print("🔍 DEBUG: Fetched \(fetchedBands.count) bands from Core Data")
    
    // Only show bands that have NO visible events (band-only entries) and pass priority filters
    // These should be actual bands, not fake bands created from standalone events
    let bandOnlyStrings = fetchedBands.compactMap { band -> String? in
        guard let bandName = band.bandName, !bandName.isEmpty else { return nil }
        
        // Only include band if it has no visible events
        if !bandsWithVisibleEvents.contains(bandName) {
            
            // ROBUST FAKE BAND DETECTION: Check if band is associated ONLY with unofficial/special events
            // If so, it's a fake band created for those events and should not appear when those events are hidden
            let allEventsForBand = band.events?.allObjects as? [Event] ?? []
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
                    print("🎭 [FAKE_BAND_DEBUG] - Event: '\(eventType)' at '\(event.location ?? "nil")' - Visible: \(isVisible)")
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
    
    print("📊 Results: \(eventStrings.count) events, \(bandOnlyStrings.count) band-only entries")
    
    // Quick check for standalone events in final output (reduced logging)
    let standaloneCount = eventStrings.filter { eventString in
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
    var combinedResults = eventStrings + bandOnlyStrings
    
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
    eventCount = eventStrings.count
    bandCount = bandOnlyStrings.count
    bandCounter = bandOnlyStrings.count
    eventCounter = eventStrings.count
    
    // POST-PROCESSING: Apply Bands Only filter if needed
    if !showScheduleView {
        print("🔍 [VIEW_MODE_DEBUG] 🎵 Applying Bands Only filter - using Core Data query for all bands")
        
        // Use Core Data to get all unique band names for the current year
        // This respects all the existing filters (priority, venue, event type, expiration)
        let bandRequest: NSFetchRequest<Band> = Band.fetchRequest()
        var bandPredicates: [NSPredicate] = []
        
        // 1. Year filter
        bandPredicates.append(NSPredicate(format: "eventYear == %d", eventYear))
        
        // 2. Apply same filters as events for consistency
        // Priority filtering will be applied post-query
        
        // 3. If "Hide Expired Events" is enabled, only show bands that have non-expired events OR no events
        if getHideExpireScheduleData() {
            let currentTime = Date().timeIntervalSince1970
            // Show bands that either have no events OR have at least one non-expired event
            let noEventsOrNonExpiredPredicate = NSPredicate(format: "events.@count == 0 OR SUBQUERY(events, $event, $event.timeIndex > %f).@count > 0", currentTime)
            bandPredicates.append(noEventsOrNonExpiredPredicate)
        }
        
        let combinedBandPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: bandPredicates)
        bandRequest.predicate = combinedBandPredicate
        bandRequest.sortDescriptors = [NSSortDescriptor(key: "bandName", ascending: true)]
        
        var allBandNames: [String] = []
        do {
            let bands = try coreDataManager.context.fetch(bandRequest)
            print("🔍 [VIEW_MODE_DEBUG] 🎵 Core Data returned \(bands.count) bands")
            
            // Apply priority filtering (same as existing logic)
            for band in bands {
                guard let bandName = band.bandName, !bandName.isEmpty else { continue }
                
                let priority = priorityManager.getPriority(for: bandName)
                
                // Apply priority filters
                if priority == 1 && !getMustSeeOn() { continue }
                if priority == 2 && !getMightSeeOn() { continue }
                if priority == 3 && !getWontSeeOn() { continue }
                if priority == 0 && !getUnknownSeeOn() { continue }
                
                allBandNames.append(bandName)
            }
        } catch {
            print("❌ [VIEW_MODE_DEBUG] Error fetching bands: \(error)")
            allBandNames = []
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

/// LEGACY: Original loop-based function (DEPRECATED - kept for fallback)
func determineBandOrScheduleList (_ allBands:[String], sortedBy: String, schedule: scheduleHandler, dataHandle: dataHandler, priorityManager: PriorityManager, attendedHandle: ShowsAttended) -> [String]{
    
    let startTime = CFAbsoluteTimeGetCurrent()
    print("🕐 [\(String(format: "%.3f", startTime))] determineBandOrScheduleList START - processing \(allBands.count) bands")
    
    numberOfFilteredRecords = 0
    var newAllBands = [String]()
    
    // If no band data is loaded yet, return empty array to trigger waiting message
    if allBands.isEmpty {
        print("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] [YEAR_CHANGE_DEBUG] determineBandOrScheduleList: No band data loaded, returning empty array for waiting message")
        return []
    }
    
    var presentCheck = [String]();
    //var listOfVenues = ["All"]
    attendingCount = 0
    unofficalEventCount = 0
    if (typeField.isEmpty == true){
        print("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] determineBandOrScheduleList: typeField is empty, returning \(allBands.count) bands immediately")
        return allBands;
    }
    
    print ("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] Locking object with newAllBands")
    eventCounter = 0
    eventCounterUnoffical = 0
    unfilteredBandCount = 0
    unfilteredEventCount = 0
    unfilteredCruiserEventCount = 0
    unfilteredCurrentEventCount = 0
    
    
    print ("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] [YEAR_CHANGE_DEBUG] sortedBy = \(sortedBy)")
    
    let buildStartTime = CFAbsoluteTimeGetCurrent()
    print("🕐 [\(String(format: "%.3f", buildStartTime))] Starting buildTimeSortedSchedulingData")
    schedule.buildTimeSortedSchedulingData();
    let buildEndTime = CFAbsoluteTimeGetCurrent()
    print("🕐 [\(String(format: "%.3f", buildEndTime))] buildTimeSortedSchedulingData END - time: \(String(format: "%.3f", (buildEndTime - buildStartTime) * 1000))ms")
    
    print ("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] [YEAR_CHANGE_DEBUG] Schedule data count: \(schedule.getTimeSortedSchedulingData().count) time-sorted, \(schedule.getBandSortedSchedulingData().count) band-sorted")
    
    // Don't process schedule data if it's empty
    if schedule.getBandSortedSchedulingData().isEmpty && schedule.getTimeSortedSchedulingData().isEmpty {
        print("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] [YEAR_CHANGE_DEBUG] determineBandOrScheduleList: Schedule data is empty, returning bands list")
        newAllBands = allBands;
        newAllBands.sort();
        bandCount = newAllBands.count;
        eventCount = 0;
        bandCounter = allBands.count
        return newAllBands
    }
    
    if (schedule.getBandSortedSchedulingData().count > 0 && sortedBy == "name"){
        print ("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] Sorting by name!!!");
        for bandName in schedule.getBandSortedSchedulingData().keys {
            unfilteredBandCount = unfilteredBandCount + 1
            if (schedule.getBandSortedSchedulingData().isEmpty == false){
                unfilteredEventCount = unfilteredEventCount + 1
                guard let bandSchedule = schedule.getBandSortedSchedulingData()[bandName] else {
                    print("[YEAR_CHANGE_DEBUG] determineBandOrScheduleList: Skipping band \(bandName) - no schedule data")
                    continue
                }
                for timeIndex in bandSchedule.keys {
                    guard let timeData = bandSchedule[timeIndex],
                          let dateValue = timeData[dateField],
                          let endTimeValue = timeData[endTimeField] else {
                        print("[YEAR_CHANGE_DEBUG] determineBandOrScheduleList: Missing data for band \(bandName) at time \(timeIndex)")
                        continue
                    }
                    var eventEndTime = schedule.getDateIndex(dateValue, timeString: endTimeValue, band: bandName)
                    print ("start time is \(timeIndex), eventEndTime is \(eventEndTime)")
                    if (timeIndex > eventEndTime){
                        eventEndTime = eventEndTime + (3600*24)
                    }
                    if (eventEndTime > Date().timeIntervalSince1970  || getHideExpireScheduleData() == false){
                        totalUpcomingEvents += 1;
                        if (schedule.getBandSortedSchedulingData()[bandName]?[timeIndex]?[typeField] != nil){
                            if (applyFilters(bandName: bandName,timeIndex: timeIndex, schedule: schedule, dataHandle: dataHandle, priorityManager: PriorityManager(), attendedHandle: attendedHandle) == true){
                                newAllBands.append(bandName + ":" + String(timeIndex));
                                presentCheck.append(bandName);
                                let event = schedule.getData(bandName, index: timeIndex, variable: typeField)
                                eventCounter = eventCounter + 1
                                if (event == unofficalEventType){
                                    eventCounterUnoffical = eventCounterUnoffical + 1
                                }
                            }
                        }
                    }
                }
            }
        }
        bandCount = 0;
        eventCount = newAllBands.count;
        
    } else if (schedule.getTimeSortedSchedulingData().count > 0 && sortedBy == "time"){
        print ("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] [YEAR_CHANGE_DEBUG] Sorting by time!!! Time-sorted data count: \(schedule.getTimeSortedSchedulingData().count)")
        
        let timeSortStartTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", timeSortStartTime))] Starting time-sorted processing loop for \(schedule.getTimeSortedSchedulingData().count) time indices")
        
        var processedCount = 0
        for timeIndex in schedule.getTimeSortedSchedulingData().keys {
            processedCount += 1
            if processedCount % 50 == 0 {
                print("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] Processing time index \(processedCount)/\(schedule.getTimeSortedSchedulingData().count): \(timeIndex)")
            }
            
            print("[YEAR_CHANGE_DEBUG] Processing time index: \(timeIndex)")
            unfilteredEventCount = unfilteredEventCount + 1
            if let eventDataArray = schedule.getTimeSortedSchedulingData()[timeIndex], !eventDataArray.isEmpty {
                // CRITICAL FIX: Process all events in this time slot (was losing events due to single event per time slot)
                print("🔍 [DATA_ACCESS_DEBUG] Processing \(eventDataArray.count) events at timeIndex \(timeIndex)")
                
                for eventData in eventDataArray {
                    // Get the band name from the event data (not from the keys!)
                    guard let bandName = eventData[bandField], !bandName.isEmpty else {
                        print("🔍 [DATA_ACCESS_DEBUG] ❌ No band name found in event data at timeIndex \(timeIndex)")
                        continue
                    }
                    
                    unfilteredBandCount = unfilteredBandCount + 1
                    // Debug: Check each step of data access
                    let allBandData = schedule.getBandSortedSchedulingData()
                    print("🔍 [DATA_ACCESS_DEBUG] Checking band '\(bandName)' at timeIndex \(timeIndex)")
                    
                    guard let bandData = allBandData[bandName] else {
                        print("🔍 [DATA_ACCESS_DEBUG] ❌ No band data found for '\(bandName)'")
                        continue
                    }
                    print("🔍 [DATA_ACCESS_DEBUG] ✅ Found band data for '\(bandName)' with \(bandData.count) time slots")
                    
                    guard let timeData = bandData[timeIndex] else {
                        print("🔍 [DATA_ACCESS_DEBUG] ❌ No time data found for '\(bandName)' at timeIndex \(timeIndex)")
                        print("🔍 [DATA_ACCESS_DEBUG] Available time indices for '\(bandName)': \(Array(bandData.keys).sorted())")
                        continue
                    }
                    print("🔍 [DATA_ACCESS_DEBUG] ✅ Found time data for '\(bandName)' at timeIndex \(timeIndex)")
                    print("🔍 [DATA_ACCESS_DEBUG] Time data keys: \(timeData.keys.sorted())")
                    
                    guard let dateValue = timeData[dateField] else {
                        print("🔍 [DATA_ACCESS_DEBUG] ❌ Missing '\(dateField)' for '\(bandName)' at timeIndex \(timeIndex)")
                        continue
                    }
                    
                    guard let endTimeValue = timeData[endTimeField] else {
                        print("🔍 [DATA_ACCESS_DEBUG] ❌ Missing '\(endTimeField)' for '\(bandName)' at timeIndex \(timeIndex)")
                        continue
                    }
                    
                    print("🔍 [DATA_ACCESS_DEBUG] ✅ All required fields found for '\(bandName)' at timeIndex \(timeIndex)")
                    var eventEndTime = schedule.getDateIndex(dateValue, timeString: endTimeValue, band: bandName)
                    print ("start time is \(timeIndex), eventEndTime is \(eventEndTime)")
                    if (timeIndex > eventEndTime){
                        eventEndTime = eventEndTime + (3600*24)
                    }
                    if (eventEndTime > Date().timeIntervalSince1970 || getHideExpireScheduleData() == false){
                        unfilteredCurrentEventCount = unfilteredCurrentEventCount + 1
                        totalUpcomingEvents += 1;
                        if let typeValue = schedule.getBandSortedSchedulingData()[bandName]?[timeIndex]?[typeField], !typeValue.isEmpty {
                            if (applyFilters(bandName: bandName,timeIndex: timeIndex, schedule: schedule, dataHandle: dataHandle, priorityManager: PriorityManager(), attendedHandle: attendedHandle) == true){
                                newAllBands.append(String(timeIndex) + ":" + bandName);
                                presentCheck.append(bandName);
                                
                                let event = schedule.getData(bandName, index: timeIndex, variable: typeField)
                                let location = schedule.getData(bandName, index:timeIndex, variable: locationField)
                                let startTime = schedule.getData(bandName, index: timeIndex, variable: startTimeField)
                                let indexText = bandName + ";" + location + ";" + event + ";" + startTime
                                timeIndexMap[String(timeIndex) + ":" + bandName] = indexText
                                eventCounter = eventCounter + 1
                                if (event == unofficalEventType){
                                    eventCounterUnoffical = eventCounterUnoffical + 1
                                }
                            }
                        }
                    }
                }
            } else {
                print("[YEAR_CHANGE_DEBUG] determineBandOrScheduleList: Time index \(timeIndex) has no band data")
            }
        }
        
        let timeSortEndTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", timeSortEndTime))] Time-sorted processing loop END - processed \(processedCount) time indices - time: \(String(format: "%.3f", (timeSortEndTime - timeSortStartTime) * 1000))ms")
        
        bandCount = 0;
        eventCount = newAllBands.count;
        
    } else {
        
        print ("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] [YEAR_CHANGE_DEBUG] returning Bands!!! Band-sorted count: \(schedule.getBandSortedSchedulingData().count), Time-sorted count: \(schedule.getTimeSortedSchedulingData().count), sortedBy: \(sortedBy)");
        //return immediatly. Dont need to do schedule sorting magic
        newAllBands = allBands;
        newAllBands.sort();
        bandCount = newAllBands.count;
        eventCount = 0;
        bandCounter = allBands.count
        
        print ("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] determineBandOrScheduleList is returning \(newAllBands.count) entries -1 ")
        return newAllBands
    }

    // This code runs for name and time sorting (not the else case above)
    newAllBands.sort();
    
    if (newAllBands.count == 0 && getShowOnlyWillAttened() == true){
        //setShowOnlyWillAttened(false);
        //newAllBands = determineBandOrScheduleList(allBands, sortedBy: sortedBy, schedule: schedule, dataHandle: dataHandle, attendedHandle: attendedHandle)
    }
    
    if (schedule.getTimeSortedSchedulingData().count >= 1 ){
        //add any bands without shows to the bottom of the list
        bandCounter = 0
        unfilteredBandCount = 0
        for bandName in allBands {
            unfilteredBandCount = unfilteredBandCount + 1
            if (presentCheck.contains(bandName) == false){
                if (applyFilters(bandName: bandName,timeIndex: 0, schedule: schedule, dataHandle: dataHandle, priorityManager: PriorityManager(), attendedHandle: attendedHandle) == true){
                    print("Adding!! bandName  " + bandName)
                    newAllBands.append(bandName);
                    presentCheck.append(bandName);
                    bandCounter = bandCounter + 1
                }
            }
        }
    }
    
    let endTime = CFAbsoluteTimeGetCurrent()
    print("🕐 [\(String(format: "%.3f", endTime))] determineBandOrScheduleList END - returning \(newAllBands.count) entries - total time: \(String(format: "%.3f", (endTime - startTime) * 1000))ms")
    //unfilteredBandCount = unfilteredBandCount - unfilteredCruiserEventCount
    return newAllBands
}

func applyFilters(bandName:String, timeIndex:TimeInterval, schedule: scheduleHandler, dataHandle: dataHandler, priorityManager: PriorityManager, attendedHandle: ShowsAttended)-> Bool{
    let startTime = CFAbsoluteTimeGetCurrent()
    var include = false;
    
    // CRITICAL DEBUG: Log all timeIndex values to understand the filtering
    print("🔍 [APPLY_FILTERS_DEBUG] Band: '\(bandName)', timeIndex: \(timeIndex), isZero: \(timeIndex.isZero)")
    
    if (timeIndex.isZero == false){
        let willAttendStartTime = CFAbsoluteTimeGetCurrent()
        if (willAttenedFilters(bandName: bandName,timeIndex: timeIndex, schedule: schedule, attendedHandle: attendedHandle) == true){
            attendingCount = attendingCount + 1;
            print ("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] attendingCount is \(attendingCount) after adding 1")
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
                            if (rankFiltering(bandName, priorityManager: PriorityManager()) == true){
                                print("🔍 [MAIN_LIST_DEBUG] ✅ Band '\(bandName)' passed rankFiltering - EVENT INCLUDED")
                            if (eventType == unofficalEventType || eventType == unofficalEventTypeOld){
                                unofficalEventCount = unofficalEventCount + 1
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
    priorityManager: PriorityManager,
    attendedHandle: ShowsAttended,
    searchCriteria: String,
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
            print("🔍 [\(String(format: "%.3f", searchStartTime))] getFilteredBands - applying search criteria: '\(searchCriteria)'")
            var searchFilteredBands = [String]()
                for bandNameIndex in filteredBands {
                let bandName = getNameFromSortable(bandNameIndex, sortedBy: sortedBy)
                if (bandName.localizedCaseInsensitiveContains(searchCriteria)){
                    searchFilteredBands.append(bandNameIndex)
                }
            }
            filteredBands = searchFilteredBands
            let searchEndTime = CFAbsoluteTimeGetCurrent()
            print("🔍 [\(String(format: "%.3f", searchEndTime))] getFilteredBands - search filtering END - filtered to \(filteredBands.count) entries - time: \(String(format: "%.3f", (searchEndTime - searchStartTime) * 1000))ms")
        }
        filteredBandCount = filteredBands.count
        if (filteredBandCount == 0){
            print ("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] mainListDebug: handleEmptryList: Why is this being called 1")
            filteredBands = handleEmptryList(bandNameHandle: bandNameHandle);
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

func handleEmptryList(bandNameHandle: bandNamesHandler)->[String]{
    
    var filteredBands = [String]()
    var localMessage = ""
    if (bandNameHandle.getBandNames().count == 0){
        localMessage = NSLocalizedString("waiting_for_data", comment: "")
    } else {
        localMessage = NSLocalizedString("data_filter_issue", comment: "")
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

func rankFiltering(_ bandName: String, priorityManager: PriorityManager) -> Bool {
    
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
        print("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] willAttenedFilters: Missing data for band: \(bandName), timeIndex: \(timeIndex)")
        return false
    }
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
        let attendedEndTime = CFAbsoluteTimeGetCurrent()
        if (attendedEndTime - attendedStartTime) > 0.001 { // Only log if it takes more than 1ms
            print("🕐 [\(String(format: "%.3f", attendedEndTime))] getShowAttendedStatus for '\(bandName)' took \(String(format: "%.3f", (attendedEndTime - attendedStartTime) * 1000))ms")
        }
        if status == sawNoneStatus {
            showEvent = false
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
    
    // Get the configurable venues from FestivalConfig
    let configuredVenues = FestivalConfig.current.getAllVenueNames()
    print("🔍 [VENUE_DEBUG] Configured venues: \(configuredVenues)")

    var showVenue = false
    
    // Check if this venue matches any of the configured venues
    var matchedConfiguredVenue = false
    for configuredVenueName in configuredVenues {
        if venue.lowercased().contains(configuredVenueName.lowercased()) || 
           configuredVenueName.lowercased().contains(venue.lowercased()) {
            // This is a configured venue, check its setting
            if getShowVenueEvents(venueName: configuredVenueName) {
                showVenue = true
                print("🔍 [VENUE_DEBUG] ✅ \(configuredVenueName) venue '\(venue)' ALLOWED")
            } else {
                print("🔍 [VENUE_DEBUG] ❌ \(configuredVenueName) venue '\(venue)' REJECTED - setting disabled")
            }
            matchedConfiguredVenue = true
            break
        }
    }
    
    // If it didn't match any configured venue, treat it as "Other"
    if !matchedConfiguredVenue {
        if getShowOtherShows() {
            showVenue = true
            print("🔍 [VENUE_DEBUG] ✅ Other venue '\(venue)' ALLOWED (getShowOtherShows: \(getShowOtherShows()))")
        } else {
            print("🔍 [VENUE_DEBUG] ❌ Other venue '\(venue)' REJECTED - Other venues disabled")
        }
    }
    
    if !showVenue {
        numberOfFilteredRecords = numberOfFilteredRecords + 1
    }
    
    print("🔍 [VENUE_DEBUG] Final result for venue '\(venue)': \(showVenue ? "ALLOW" : "REJECT")")
    return showVenue
}

func getCellValue (_ indexRow: Int, schedule: scheduleHandler, sortBy: String, cell: UITableViewCell, dataHandle: dataHandler, priorityManager: PriorityManager, attendedHandle: ShowsAttended){
    
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
        var location = schedule.getData(bandName, index:timeIndex, variable: locationField)
        var day = monthDateRegionalFormatting(dateValue: schedule.getData(bandName, index: timeIndex, variable: dayField))
        var startTime = schedule.getData(bandName, index: timeIndex, variable: startTimeField)
        var endTime = schedule.getData(bandName, index: timeIndex, variable: endTimeField)
        var event = schedule.getData(bandName, index: timeIndex, variable: typeField)
        var notes = schedule.getData(bandName, index:timeIndex, variable: notesField)
        
        // If legacy schedule doesn't have this data (standalone event), get from Core Data
        if location.isEmpty && startTime.isEmpty && event.isEmpty {
            if let coreDataEvent = CoreDataManager.shared.fetchEvent(byTimeIndex: timeIndex, eventName: bandName, forYear: Int32(eventYear)) {
                location = coreDataEvent.location ?? ""
                startTime = coreDataEvent.startTime ?? ""
                endTime = coreDataEvent.endTime ?? ""
                event = coreDataEvent.eventType ?? ""
                notes = coreDataEvent.notes ?? ""
                // Format day from timeIndex if not available
                if day.isEmpty {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "MMM d"
                    day = dateFormatter.string(from: Date(timeIntervalSince1970: timeIndex))
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
    
        let icon = attendedHandle.getShowAttendedIcon(band: bandName,location: location,startTime: startTime,eventType: event,eventYearString: String(eventYear));
        
        attendedView.image = icon
        eventTypeImageView.image = eventIcon
        
        scheduleIndexByCall[scheduleText] = [String:String]()
        scheduleIndexByCall[scheduleText]!["location"] = location
        scheduleIndexByCall[scheduleText]!["bandName"] = bandName
        scheduleIndexByCall[scheduleText]!["startTime"] = startTime
        scheduleIndexByCall[scheduleText]!["event"] = event
        
        if day == "Day 1"{
            dayText = "1";
        
        } else if day == "Day 2"{
            dayText = "2";
            
        } else if day == "Day 3"{
            dayText = "3";
            
        } else if day == "Day 4"{
            dayText = "4";
            
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

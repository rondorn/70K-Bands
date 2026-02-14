//
//  LandscapeScheduleViewModel.swift
//  70K Bands
//
//  Created by Cursor on 2/5/26.
//  Copyright (c) 2026 Ron Dorn. All rights reserved.
//

import Foundation
import SwiftUI

class LandscapeScheduleViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading: Bool = true
    @Published var currentDayIndex: Int = 0
    @Published var days: [DayScheduleData] = []
    @Published var totalEventCount: Int = 0
    
    // MARK: - Computed Properties
    
    var currentDayData: DayScheduleData? {
        guard currentDayIndex >= 0 && currentDayIndex < days.count else { return nil }
        return days[currentDayIndex]
    }
    
    var currentDayEventCount: Int {
        return currentDayData?.venues.reduce(0) { $0 + $1.events.count } ?? 0
    }
    
    var canNavigateToPreviousDay: Bool {
        return currentDayIndex > 0
    }
    
    var canNavigateToNextDay: Bool {
        return currentDayIndex < days.count - 1
    }
    
    // MARK: - Private Properties
    
    private let eventManager = EventManager()
    private var priorityManager: SQLitePriorityManager
    private var attendedHandle: ShowsAttended
    private var initialDay: String?
    private var hideExpiredEvents: Bool
    
    // MARK: - Initialization
    
    init(priorityManager: SQLitePriorityManager, attendedHandle: ShowsAttended, initialDay: String? = nil, hideExpiredEvents: Bool = false) {
        self.priorityManager = priorityManager
        self.attendedHandle = attendedHandle
        self.initialDay = initialDay
        self.hideExpiredEvents = hideExpiredEvents
    }
    
    // MARK: - Public Methods
    
    func loadScheduleData() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            print("🔍 [LANDSCAPE_SCHEDULE] Loading schedule data for year \(eventYear)")
            
            // Get ALL events for the current year (don't filter here - we want to show expired events dimmed)
            let allEvents = self.eventManager.getEvents(forYear: eventYear)
            print("🔍 [LANDSCAPE_SCHEDULE] Total events for year \(eventYear): \(allEvents.count)")
            
            // Process events into days
            var processedDays = self.processEventsIntodays(allEvents)
            
            // If hideExpiredEvents is true, filter out days with ONLY expired events
            if self.hideExpiredEvents {
                let beforeFiltering = processedDays.count
                processedDays = processedDays.filter { dayData in
                    // Keep the day if it has at least one non-expired event
                    let hasActiveEvent = dayData.venues.contains { venue in
                        venue.events.contains { event in
                            !event.isExpired
                        }
                    }
                    if !hasActiveEvent {
                        print("🔍 [LANDSCAPE_SCHEDULE] Filtering out day '\(dayData.dayLabel)' - all events expired")
                    }
                    return hasActiveEvent
                }
                print("🔍 [LANDSCAPE_SCHEDULE] Filtered days: \(beforeFiltering) → \(processedDays.count) (hideExpiredEvents: true)")
            } else {
                print("🔍 [LANDSCAPE_SCHEDULE] Showing all \(processedDays.count) days (hideExpiredEvents: false)")
            }
            
            DispatchQueue.main.async {
                self.days = processedDays
                self.totalEventCount = allEvents.count
                
                if processedDays.isEmpty {
                    print("⚠️ [LANDSCAPE_SCHEDULE] No days available after processing/filtering")
                    self.isLoading = false
                    return
                }
                
                // Set initial day index based on initialDay parameter
                if let initialDay = self.initialDay {
                    if let dayIndex = processedDays.firstIndex(where: { $0.dayLabel == initialDay }) {
                        self.currentDayIndex = dayIndex
                        print("✅ [LANDSCAPE_SCHEDULE] Starting on day: \(initialDay) (index \(dayIndex))")
                    } else {
                        print("⚠️ [LANDSCAPE_SCHEDULE] Could not find day: \(initialDay), defaulting to index 0")
                        self.currentDayIndex = 0
                    }
                }
                
                self.isLoading = false
                
                print("✅ [LANDSCAPE_SCHEDULE] Loaded \(self.days.count) days with \(self.totalEventCount) total events")
                
                // Log details about what we loaded
                for (index, day) in processedDays.enumerated() {
                    let eventCount = day.venues.reduce(0) { $0 + $1.events.count }
                    let nonExpiredCount = day.venues.reduce(0) { $0 + $1.events.filter { !$0.isExpired }.count }
                    print("  Day \(index): \(day.dayLabel) - \(eventCount) events (\(nonExpiredCount) non-expired)")
                }
            }
        }
    }
    
    func navigateToPreviousDay() {
        guard canNavigateToPreviousDay else { return }
        objectWillChange.send()
        currentDayIndex -= 1
    }
    
    func navigateToNextDay() {
        guard canNavigateToNextDay else { return }
        objectWillChange.send()
        currentDayIndex += 1
    }
    
    func updateAttendanceForEvent(bandName: String, location: String, startTime: String, eventType: String) {
        print("🔄 [LANDSCAPE_SCHEDULE] Updating attendance for \(bandName) (\(eventType)) at \(location) \(startTime)")
        
        // Normalize event type for database query
        // Event data contains "Unofficial Event" but database keys use "Cruiser Organized"
        let normalizedEventType = (eventType == "Unofficial Event") ? "Cruiser Organized" : eventType
        
        print("🔍 [LANDSCAPE_SCHEDULE] Normalized event type: \(eventType) -> \(normalizedEventType)")
        
        // Get fresh attendance status
        let newStatus = attendedHandle.getShowAttendedStatus(
            band: bandName,
            location: location,
            startTime: startTime,
            eventType: normalizedEventType,
            eventYearString: String(eventYear)
        )
        
        // Update the days array in place
        for dayIndex in 0..<days.count {
            var updatedVenues: [VenueColumn] = []
            
            for venue in days[dayIndex].venues {
                var updatedEvents: [ScheduleBlock] = []
                
                for event in venue.events {
                    if event.bandName == bandName && event.location == location && event.startTimeString == startTime && event.eventType == eventType {
                        // Create updated event with new attendance status
                        let updatedEvent = ScheduleBlock(
                            bandName: event.bandName,
                            startTime: event.startTime,
                            endTime: event.endTime,
                            startTimeString: event.startTimeString,
                            eventType: event.eventType,
                            location: event.location,
                            day: event.day,
                            timeIndex: event.timeIndex,
                            priority: event.priority,
                            attendedStatus: newStatus,
                            isExpired: event.isExpired
                        )
                        updatedEvents.append(updatedEvent)
                        print("✅ [LANDSCAPE_SCHEDULE] Updated event \(bandName) (\(eventType)): \(event.attendedStatus) -> \(newStatus)")
                    } else {
                        updatedEvents.append(event)
                    }
                }
                
                let updatedVenue = VenueColumn(name: venue.name, color: venue.color, events: updatedEvents)
                updatedVenues.append(updatedVenue)
            }
            
            days[dayIndex] = DayScheduleData(
                dayLabel: days[dayIndex].dayLabel,
                venues: updatedVenues,
                timeSlots: days[dayIndex].timeSlots,
                startTime: days[dayIndex].startTime,
                endTime: days[dayIndex].endTime,
                baseTimeIndex: days[dayIndex].baseTimeIndex
            )
        }
    }
    
    func refreshEventData(bandName: String) {
        print("🔄 [LANDSCAPE_SCHEDULE] Refreshing all events for band: \(bandName)")
        
        // Trigger update notification before modifying
        objectWillChange.send()
        
        // Find all events for this band and update their priority and attendance
        for dayIndex in 0..<days.count {
            var updatedVenues: [VenueColumn] = []
            
            for venue in days[dayIndex].venues {
                var updatedEvents: [ScheduleBlock] = []
                
                for event in venue.events {
                    if event.bandName == bandName {
                        // Normalize event type for database query
                        let normalizedEventType = (event.eventType == "Unofficial Event") ? "Cruiser Organized" : event.eventType
                        
                        // Get fresh priority
                        let newPriority = priorityManager.getPriority(for: bandName)
                        
                        // Get fresh attendance status
                        let newStatus = attendedHandle.getShowAttendedStatus(
                            band: bandName,
                            location: event.location,
                            startTime: event.startTimeString,
                            eventType: normalizedEventType,
                            eventYearString: String(eventYear)
                        )
                        
                        // Create updated event with fresh data
                        let updatedEvent = ScheduleBlock(
                            bandName: event.bandName,
                            startTime: event.startTime,
                            endTime: event.endTime,
                            startTimeString: event.startTimeString,
                            eventType: event.eventType,
                            location: event.location,
                            day: event.day,
                            timeIndex: event.timeIndex,
                            priority: newPriority,
                            attendedStatus: newStatus,
                            isExpired: event.isExpired
                        )
                        updatedEvents.append(updatedEvent)
                        print("✅ [LANDSCAPE_SCHEDULE] Refreshed \(bandName) at \(event.location) \(event.startTimeString): priority=\(newPriority), attended=\(newStatus)")
                    } else {
                        updatedEvents.append(event)
                    }
                }
                
                let updatedVenue = VenueColumn(name: venue.name, color: venue.color, events: updatedEvents)
                updatedVenues.append(updatedVenue)
            }
            
            days[dayIndex] = DayScheduleData(
                dayLabel: days[dayIndex].dayLabel,
                venues: updatedVenues,
                timeSlots: days[dayIndex].timeSlots,
                startTime: days[dayIndex].startTime,
                endTime: days[dayIndex].endTime,
                baseTimeIndex: days[dayIndex].baseTimeIndex
            )
        }
        
        // Trigger update notification after modifying
        objectWillChange.send()
    }
    
    func refreshData() {
        print("🔄 [LANDSCAPE_SCHEDULE] Refreshing data due to filter change")
        loadScheduleData()
    }
    
    // MARK: - Private Methods
    
    /// Parse a time string (e.g., "13:00", "18:15", "9:30") as minutes since midnight
    /// For events crossing midnight (early morning hours like 02:00), adds 24 hours
    private func parseTimeToMinutes(_ timeStr: String?) -> Int {
        guard let timeStr = timeStr, !timeStr.isEmpty else {
            return 0
        }
        
        // Parse the time string (format: "HH:mm" or "H:mm")
        let components = timeStr.split(separator: ":").map { String($0) }
        guard components.count == 2,
              let hours = Int(components[0]),
              let minutes = Int(components[1]) else {
            return 0
        }
        
        return hours * 60 + minutes
    }
    
    /// Convert minutes since midnight to a Date on Jan 1, 2000 (arbitrary base date)
    /// Supports times > 1440 minutes (24 hours) for events crossing midnight
    private func minutesToDate(_ minutes: Int) -> Date {
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.year = 2000
        dateComponents.month = 1
        dateComponents.day = 1
        dateComponents.hour = 0
        dateComponents.minute = 0
        dateComponents.second = 0
        
        guard let baseDate = calendar.date(from: dateComponents) else {
            return Date()
        }
        
        // Add the minutes as an interval (handles times > 24 hours correctly)
        return baseDate.addingTimeInterval(TimeInterval(minutes * 60))
    }
    
    private func processEventsIntodays(_ events: [EventData]) -> [DayScheduleData] {
        var dayGroups: [String: [ScheduleBlock]] = [:]
        
        // DETECT AND COMBINE DUPLICATE EVENTS FOR LANDSCAPE CALENDAR VIEW
        // Events that share same date, start time, end time, location, and event type (only band name differs)
        // This only applies to landscape calendar view, NOT portrait list view
        var eventGroups: [String: [EventData]] = [:]
        for event in events {
            let date = event.date ?? ""
            let startTime = event.startTime ?? ""
            let endTime = event.endTime ?? ""
            let location = event.location
            let eventType = event.eventType ?? ""
            
            // Create a unique key for grouping
            let groupKey = "\(date)|\(startTime)|\(endTime)|\(location)|\(eventType)"
            
            if eventGroups[groupKey] == nil {
                eventGroups[groupKey] = []
            }
            eventGroups[groupKey]?.append(event)
        }
        
        // Create mapping for combined events: event key -> combined band name
        var eventToCombinedName: [String: String] = [:] // "timeIndex:bandName" -> combined name (band1+delimiter+band2)
        var eventsToSkip = Set<String>() // Events to skip (second event of a pair)
        
        for (_, groupEvents) in eventGroups {
            // Only combine if exactly 2 events with different band names
            if groupEvents.count == 2 {
                let band1 = groupEvents[0].bandName
                let band2 = groupEvents[1].bandName
                
                // Ensure they're different bands and both are non-empty
                if band1 != band2 && !band1.isEmpty && !band2.isEmpty {
                    // Sort band names alphabetically for consistent display. Use internal delimiter so "/" in event names is not treated as combined.
                    let sortedBands = [band1, band2].sorted()
                    let combinedBandName = "\(sortedBands[0])\(combinedEventDelimiter)\(sortedBands[1])"
                    
                    // Store mapping for both events
                    eventToCombinedName["\(groupEvents[0].timeIndex):\(band1)"] = combinedBandName
                    eventToCombinedName["\(groupEvents[1].timeIndex):\(band2)"] = combinedBandName
                    
                    // Mark second event to skip (we'll only process the first with combined name)
                    eventsToSkip.insert("\(groupEvents[1].timeIndex):\(band2)")
                    
                    // Store mapping for later use (for tap handling)
                    combinedEventsMap[combinedBandName] = sortedBands
                    
                    print("🔗 [LANDSCAPE_COMBINED] Combined events: '\(band1)' + '\(band2)' -> '\(combinedBandName)'")
                }
            }
        }
        
        // Group events by day (including combined events)
        for event in events {
            guard let day = event.day else {
                continue
            }
            
            // Skip second event of a combined pair
            let eventKey = "\(event.timeIndex):\(event.bandName)"
            if eventsToSkip.contains(eventKey) {
                continue
            }
            
            // Check if this event should use a combined name
            let displayBandName = eventToCombinedName[eventKey] ?? event.bandName
            
            // Parse start and end times as minutes since midnight
            let startMinutes = parseTimeToMinutes(event.startTime)
            var endMinutes = parseTimeToMinutes(event.endTime)
            
            // Handle events that cross midnight (end time before start time)
            // For example: 23:00 (1380 min) to 02:00 (120 min) should become 23:00 to 26:00 (1560 min)
            if endMinutes < startMinutes {
                endMinutes += (24 * 60)  // Add 24 hours to end time
            }
            
            // Convert to Date objects on the same base date (Jan 1, 2000)
            let startDate = minutesToDate(startMinutes)
            let endDate = minutesToDate(endMinutes)
            
            // Get priority and attended status
            let priority = priorityManager.getPriority(for: event.bandName, eventYear: event.eventYear)
            
            // Format time for attended status lookup - USE THE ORIGINAL startTime STRING from event data
            // The database stores times in the format from CSV (like "17:30", "03:00", etc.)
            let startTimeStr = event.startTime ?? ""
            let attendedStatus = attendedHandle.getShowAttendedStatus(
                band: event.bandName,
                location: event.location,
                startTime: startTimeStr,
                eventType: event.eventType ?? "Performance",
                eventYearString: String(event.eventYear)
            )
            
            // Mark events as expired when hideExpiredEvents is enabled (for dimming)
            // Use the same logic as portrait view: endTimeIndex > currentTime (using reference date)
            let isExpired: Bool
            if self.hideExpiredEvents {
                let currentTime = Date().timeIntervalSinceReferenceDate
                isExpired = event.endTimeIndex <= currentTime
                if isExpired {
                    print("🔍 [EXPIRED_CHECK] \(event.bandName): endTimeIndex=\(event.endTimeIndex), current=\(currentTime) - EXPIRED")
                }
            } else {
                isExpired = false
            }
            
            let scheduleBlock = ScheduleBlock(
                bandName: displayBandName, // Use combined name if this is a duplicate event
                startTime: startDate,
                endTime: endDate,
                startTimeString: startTimeStr,
                eventType: event.eventType ?? "Performance",
                location: event.location,
                day: day,
                timeIndex: event.timeIndex,
                priority: priority,
                attendedStatus: attendedStatus,
                isExpired: isExpired
            )
            
            // Group by day
            if dayGroups[day] == nil {
                dayGroups[day] = []
            }
            dayGroups[day]?.append(scheduleBlock)
        }
        
        // Convert day groups into DayScheduleData
        var dayScheduleData: [(data: DayScheduleData, earliestTimeIndex: TimeInterval)] = []
        
        for (dayLabel, events) in dayGroups {
            // Sort events by their original timeIndex (preserves actual chronological order)
            // This ensures events on Jan 29 at 10am come before Jan 30 at midnight
            let sortedEvents = events.sorted { $0.timeIndex < $1.timeIndex }
            
            guard !sortedEvents.isEmpty else { continue }
            
            // Store the earliest original timeIndex for sorting days chronologically
            let earliestTimeIndex = sortedEvents.first!.timeIndex
            
            // Determine time range for the day based on actual chronological order
            // Use the first event's timeIndex as the baseline
            let firstEventTimeIndex = sortedEvents.first!.timeIndex
            let startTime = sortedEvents.first!.startTime
            
            // Find the event with the latest end timeIndex
            let lastEventEndTimeIndex = sortedEvents.map { $0.timeIndex + ($0.endTime.timeIntervalSince($0.startTime)) }.max() ?? (firstEventTimeIndex + 3600)
            
            // Calculate the timeline duration in seconds
            let timelineDuration = lastEventEndTimeIndex - firstEventTimeIndex
            
            // Create end time by adding the duration to start time
            let endTime = startTime.addingTimeInterval(timelineDuration)
            
            // Get unique venues for this day
            let venuesForDay = getUniqueVenues(from: sortedEvents)
            
            // Generate time slots
            let timeSlots = generateTimeSlots(from: startTime, to: endTime)
            
            // Organize events by venue
            let venueColumns = organizeEventsByVenue(events: sortedEvents, venues: venuesForDay)
            
            let dayData = DayScheduleData(
                dayLabel: dayLabel,
                venues: venueColumns,
                timeSlots: timeSlots,
                startTime: startTime,
                endTime: endTime,
                baseTimeIndex: earliestTimeIndex
            )
            
            dayScheduleData.append((data: dayData, earliestTimeIndex: earliestTimeIndex))
        }
        
        // Sort days by their earliest original timeIndex (preserves chronological order)
        // This ensures "Day 1" at 3am comes before "Day 2" at 10am if Day 1 is chronologically first
        dayScheduleData.sort { $0.earliestTimeIndex < $1.earliestTimeIndex }
        
        // Extract just the DayScheduleData (remove the sorting helper)
        return dayScheduleData.map { $0.data }
    }
    
    private func getUniqueVenues(from events: [ScheduleBlock]) -> [String] {
        let uniqueVenues = Set(events.map { $0.location })
        
        // Get venue order from FestivalConfig
        let configuredVenueNames = FestivalConfig.current.getAllVenueNames()
        
        // Split venues into two groups:
        // 1. Venues that are in the config (maintain config order)
        // 2. Venues not in config (alphabetically sorted)
        var configuredVenues: [String] = []
        var unconfiguredVenues: [String] = []
        
        for venueName in uniqueVenues {
            // Check if this venue exists in config (EXACT match, case-insensitive)
            let matchesConfig = configuredVenueNames.contains { configName in
                venueName.localizedCaseInsensitiveCompare(configName) == .orderedSame
            }
            
            if matchesConfig {
                configuredVenues.append(venueName)
            } else {
                unconfiguredVenues.append(venueName)
            }
        }
        
        // Sort configured venues by their order in FestivalConfig
        configuredVenues.sort { venue1, venue2 in
            let index1 = configuredVenueNames.firstIndex { configName in
                venue1.localizedCaseInsensitiveCompare(configName) == .orderedSame
            } ?? Int.max
            
            let index2 = configuredVenueNames.firstIndex { configName in
                venue2.localizedCaseInsensitiveCompare(configName) == .orderedSame
            } ?? Int.max
            
            return index1 < index2
        }
        
        // Sort unconfigured venues alphabetically
        unconfiguredVenues.sort()
        
        // Return configured venues first, then unconfigured
        return configuredVenues + unconfiguredVenues
    }
    
    private func organizeEventsByVenue(events: [ScheduleBlock], venues: [String]) -> [VenueColumn] {
        var venueColumns: [VenueColumn] = []
        
        for venueName in venues {
            let eventsForVenue = events.filter { $0.location == venueName }
            
            let venueColor = FestivalConfig.current.getVenueSwiftUIColor(for: venueName)
            
            let venueColumn = VenueColumn(
                name: venueName,
                color: venueColor,
                events: eventsForVenue
            )
            
            venueColumns.append(venueColumn)
        }
        
        return venueColumns
    }
    
    private func generateTimeSlots(from startTime: Date, to endTime: Date) -> [TimeSlot] {
        var timeSlots: [TimeSlot] = []
        let calendar = Calendar.current
        
        // Round start time down to the nearest hour
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: startTime)
        guard var currentTime = calendar.date(from: components) else { 
            return [] 
        }
        
        // If the rounded time is after the start time, go back an hour
        if currentTime > startTime {
            currentTime = calendar.date(byAdding: .hour, value: -1, to: currentTime) ?? currentTime
        }
        
        let hourFormatter = DateFormatter()
        hourFormatter.dateFormat = "h:mma"
        
        let quarterFormatter = DateFormatter()
        quarterFormatter.dateFormat = ":mm"
        
        // Generate time slots every 15 minutes
        while currentTime <= endTime {
            let minute = calendar.component(.minute, from: currentTime)
            let label: String
            
            if minute == 0 {
                // On the hour, show full time
                label = hourFormatter.string(from: currentTime).lowercased()
            } else {
                // Quarter hours, show just minutes
                label = quarterFormatter.string(from: currentTime)
            }
            
            let timeSlot = TimeSlot(time: currentTime, label: label)
            timeSlots.append(timeSlot)
            
            // Move to next 15-minute interval
            currentTime = calendar.date(byAdding: .minute, value: 15, to: currentTime) ?? currentTime
        }
        
        return timeSlots
    }
    
    private func parseDayLabel(_ dayLabel: String) -> Date? {
        // Try to parse date formats like "1/27", "01/27", etc.
        let dateFormatter = DateFormatter()
        
        // Try different formats
        let formats = ["M/d", "MM/dd", "M/dd", "MM/d"]
        
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dayLabel) {
                // Add the current year since the format doesn't include it
                let calendar = Calendar.current
                let currentYear = calendar.component(.year, from: Date())
                var components = calendar.dateComponents([.month, .day], from: date)
                components.year = currentYear
                
                if let fullDate = calendar.date(from: components) {
                    return fullDate
                }
            }
        }
        
        // If it's not a date format (e.g., "Day 1", "Day 2"), return nil
        return nil
    }
}

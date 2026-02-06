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
            
            // If hiding expired events, filter out days with ONLY expired events
            if self.hideExpiredEvents {
                processedDays = processedDays.filter { dayData in
                    // Keep the day if it has at least one non-expired event
                    let hasNonExpiredEvent = dayData.venues.contains { venue in
                        venue.events.contains { event in
                            !event.isExpired
                        }
                    }
                    if !hasNonExpiredEvent {
                        print("🔍 [LANDSCAPE_SCHEDULE] Filtering out day '\(dayData.dayLabel)' - all events expired")
                    }
                    return hasNonExpiredEvent
                }
                print("🔍 [LANDSCAPE_SCHEDULE] After filtering expired days: \(processedDays.count) days remaining (hideExpiredEvents: true)")
            } else {
                print("🔍 [LANDSCAPE_SCHEDULE] Not filtering expired days: \(processedDays.count) days total (hideExpiredEvents: false)")
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
        currentDayIndex -= 1
    }
    
    func navigateToNextDay() {
        guard canNavigateToNextDay else { return }
        currentDayIndex += 1
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
        
        // Group events by day
        for event in events {
            guard let day = event.day else {
                continue
            }
            
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
            
            // Determine if event is expired when hideExpiredEvents is enabled
            let isExpired: Bool
            if self.hideExpiredEvents {
                // Parse event date (e.g., "01/29/2026")
                let dateStr = event.date ?? ""
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MM/dd/yyyy"
                
                if let eventDate = dateFormatter.date(from: dateStr) {
                    // Parse end time string (e.g., "17:00", "02:00")
                    let endTimeStr = event.endTime ?? ""
                    let endTimeComponents = endTimeStr.split(separator: ":").compactMap { Int($0) }
                    
                    if endTimeComponents.count == 2 {
                        let endHour = endTimeComponents[0]
                        let endMinute = endTimeComponents[1]
                        
                        // Create the actual end date+time
                        let calendar = Calendar.current
                        var eventEndDateTime = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: eventDate) ?? eventDate
                        
                        // If end time is before start time, it crosses midnight - add a day
                        let endMinutesTotal = endHour * 60 + endMinute
                        if endMinutesTotal < startMinutes {
                            eventEndDateTime = calendar.date(byAdding: .day, value: 1, to: eventEndDateTime) ?? eventEndDateTime
                        }
                        
                        // Add 10 minute buffer
                        let bufferSeconds: TimeInterval = 600
                        let now = Date()
                        isExpired = now.timeIntervalSince(eventEndDateTime) > bufferSeconds
                        
                        if isExpired {
                            print("🔍 [EXPIRED_CHECK] \(event.bandName): ended at \(eventEndDateTime), current=\(now) - EXPIRED")
                        }
                    } else {
                        isExpired = false
                    }
                } else {
                    // Can't parse date, assume not expired
                    isExpired = false
                }
            } else {
                isExpired = false
            }
            
            let scheduleBlock = ScheduleBlock(
                bandName: event.bandName,
                startTime: startDate,
                endTime: endDate,
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

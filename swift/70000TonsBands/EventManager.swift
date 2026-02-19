import Foundation

/// Manages all event operations using SQLite (via DataManager)
/// Replaces the legacy scheduleHandler dictionary system with database operations
class EventManager {
    private let csvImporter: EventCSVImporter
    private let dataManager = DataManager.shared
    
    init() {
        print("📊 [MDF_DEBUG] EventManager.init() called")
        print("📊 [MDF_DEBUG] Festival: \(FestivalConfig.current.festivalShortName)")
        self.csvImporter = EventCSVImporter()  // Uses DataManager.shared (SQLite) internally
        print("📊 [MDF_DEBUG] EventManager.init() completed - csvImporter created")
    }
    
    // MARK: - Event Data Access (Replaces scheduleHandler methods)
    
    /// Get all events for a band (replaces schedulingData[bandName])
    /// - Parameter bandName: Name of the band
    /// - Returns: Array of events sorted by time
    func getEvents(for bandName: String) -> [EventData] {
        return csvImporter.getEvents(for: bandName)
    }
    
    /// Get events by time index (replaces schedulingDataByTime[timeIndex])
    /// - Parameter timeIndex: Time index to search for
    /// - Returns: Array of events at that time
    func getEvents(byTimeIndex timeIndex: TimeInterval) -> [EventData] {
        return csvImporter.getEvents(byTimeIndex: timeIndex)
    }
    
    /// Get specific event data field (replaces getData method)
    /// - Parameters:
    ///   - bandName: Name of the band
    ///   - timeIndex: Time index of the event
    ///   - field: Field name to retrieve
    /// - Returns: Field value as string
    func getEventData(bandName: String, timeIndex: TimeInterval, field: String) -> String {
        return csvImporter.getEventData(bandName: bandName, timeIndex: timeIndex, field: field)
    }
    
    /// Get all events for current year (replaces full schedule access)
    /// - Returns: All events for current eventYear sorted by time
    func getAllEvents() -> [EventData] {
        print("🔍 [MDF_DEBUG] getAllEvents() called")
        print("🔍 [MDF_DEBUG] Festival: \(FestivalConfig.current.festivalShortName)")
        print("🔍 [MDF_DEBUG] Current eventYear: \(eventYear)")
        
        let results = getEvents(forYear: eventYear)
        print("🔍 [MDF_DEBUG] Found \(results.count) events in SQLite for year \(eventYear)")
        
        if results.count > 0 {
            print("🔍 [MDF_DEBUG] First few events:")
            for (index, event) in results.prefix(3).enumerated() {
                print("   \(index + 1). \(event.bandName) at \(event.location) on \(event.date ?? "Unknown")")
            }
        }
        
        return results
    }
    
    // MARK: - Advanced Filtering and Queries
    
    /// Get events by year
    /// - Parameter year: Event year to filter by
    /// - Returns: Events for the specified year
    func getEvents(forYear year: Int) -> [EventData] {
        let events = dataManager.fetchEvents(forYear: year)
        return events.sorted { $0.timeIndex < $1.timeIndex }
    }
    
    /// Get events by location (filtered by current year)
    /// - Parameter location: Location to filter by
    /// - Returns: Events at the specified location for current eventYear
    func getEvents(atLocation location: String) -> [EventData] {
        let events = dataManager.fetchEvents(forYear: eventYear, location: location, eventType: nil)
        return events.sorted { $0.timeIndex < $1.timeIndex }
    }
    
    /// Get events by type (filtered by current year)
    /// - Parameter eventType: Event type to filter by
    /// - Returns: Events of the specified type for current eventYear
    func getEvents(ofType eventType: String) -> [EventData] {
        let events = dataManager.fetchEvents(forYear: eventYear, location: nil, eventType: eventType)
        return events.sorted { $0.timeIndex < $1.timeIndex }
    }
    
    /// Get events by day (filtered by current year)
    /// - Parameter day: Day to filter by
    /// - Returns: Events on the specified day for current eventYear
    func getEvents(onDay day: String) -> [EventData] {
        let allEvents = dataManager.fetchEvents(forYear: eventYear)
        return allEvents.filter { $0.day == day }.sorted { $0.timeIndex < $1.timeIndex }
    }
    
    /// Get events within time range (filtered by current year)
    /// - Parameters:
    ///   - startTime: Start time interval
    ///   - endTime: End time interval
    /// - Returns: Events within the time range for current eventYear
    func getEvents(from startTime: TimeInterval, to endTime: TimeInterval) -> [EventData] {
        let allEvents = dataManager.fetchEvents(forYear: eventYear)
        return allEvents.filter { $0.timeIndex >= startTime && $0.timeIndex <= endTime }
            .sorted { $0.timeIndex < $1.timeIndex }
    }
    
    /// Get upcoming events (replaces hasUpcomingShows logic, filtered by current year)
    /// - Parameter bandName: Name of the band
    /// - Returns: Future events for the band in current eventYear
    func getUpcomingEvents(for bandName: String) -> [EventData] {
        let currentTime = Date().timeIntervalSinceReferenceDate
        let events = dataManager.fetchEventsForBand(bandName, forYear: eventYear)
        return events.filter { $0.timeIndex > currentTime }.sorted { $0.timeIndex < $1.timeIndex }
    }
    
    /// Get past events (filtered by current year)
    /// - Parameter bandName: Name of the band
    /// - Returns: Past events for the band in current eventYear
    func getPastEvents(for bandName: String) -> [EventData] {
        let currentTime = Date().timeIntervalSinceReferenceDate
        let events = dataManager.fetchEventsForBand(bandName, forYear: eventYear)
        return events.filter { $0.timeIndex <= currentTime }.sorted { $0.timeIndex > $1.timeIndex }
    }
    
    // MARK: - Complex Filtering (Replaces MasterViewController filtering logic)
    
    /// High-performance query-based filtering that replaces loop-based applyFilters logic
    /// - Parameters:
    ///   - year: Event year to filter by
    ///   - sortBy: Sorting preference ("name" or "time")
    ///   - priorityManager: Priority manager for band rankings
    ///   - attendedHandle: Attendance tracking handler
    /// - Returns: Filtered events and bands formatted for UI
    func getFilteredEventsAndBands(
        year: Int,
        sortBy: String,
        priorityManager: SQLitePriorityManager,
        attendedHandle: ShowsAttended
    ) -> (events: [String], bands: [String], eventCount: Int, bandCount: Int) {
        
        print("🚀 QUERY-BASED FILTERING START - Year: \(year), Sort: \(sortBy)")
        
        // DEBUG: Check what years we have in the database
        let allEvents = dataManager.fetchEvents()
        print("🔍 DEBUG: Total events in database: \(allEvents.count)")
        let eventYears = Dictionary(grouping: allEvents, by: { $0.eventYear })
        for (eventYear, events) in eventYears.sorted(by: { $0.key < $1.key }) {
            print("🔍 DEBUG: Year \(eventYear) has \(events.count) events")
        }
        
        // Check if events have year 0 (which means they weren't properly imported)
        let zeroYearEvents = allEvents.filter { $0.eventYear == 0 }
        if !zeroYearEvents.isEmpty {
            print("🚨 ERROR: Found \(zeroYearEvents.count) events with eventYear = 0 (improperly imported)")
        }
        
        // Check for duplicate events (same band, time, location)
        let currentYearEvents = allEvents.filter { $0.eventYear == year }
        var duplicateGroups: [String: [EventData]] = [:]
        
        for event in currentYearEvents {
            let key = "\(event.bandName)|\(event.timeIndex)|\(event.location)"
            if duplicateGroups[key] == nil {
                duplicateGroups[key] = []
            }
            duplicateGroups[key]!.append(event)
        }
        
        let duplicates = duplicateGroups.filter { $1.count > 1 }
        if !duplicates.isEmpty {
            print("🚨 DUPLICATE EVENTS FOUND: \(duplicates.count) sets of duplicates")
            for (key, events) in duplicates.prefix(5) {
                print("🚨 - \(key): \(events.count) duplicates")
            }
            let totalDuplicates = duplicates.values.reduce(0) { $0 + ($1.count - 1) }
            print("🚨 TOTAL DUPLICATE EVENTS: \(totalDuplicates) (should be removed)")
            print("🚨 UNIQUE EVENTS: \(currentYearEvents.count - totalDuplicates) (this should be ~250)")
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 1. YEAR FILTERING - Get events for the specified year
        var filteredEvents = dataManager.fetchEvents(forYear: year)
        print("🎯 [MDF_DEBUG] YEAR FILTERING:")
        print("   Filtering for eventYear == \(year)")
        print("   Global eventYear variable: \(eventYear)")
        print("   Found \(filteredEvents.count) events for year \(year)")
        
        // 2. EVENT TYPE FILTERING (EXCLUSIVE approach - show everything EXCEPT filtered out types)
        var excludedEventTypes: [String] = []
        print("🔍 DEBUG: Event type filter settings (EXCLUSIVE approach):")
        print("🔍 DEBUG: getShowSpecialEvents() = \(getShowSpecialEvents())")
        print("🔍 DEBUG: getShowMeetAndGreetEvents() = \(getShowMeetAndGreetEvents())")
        print("🔍 DEBUG: getShowUnofficalEvents() = \(getShowUnofficalEvents())")
        
        if !getShowSpecialEvents() {
            excludedEventTypes.append("Special Event")
            excludedEventTypes.append("Karaoke")
        }
        if !getShowMeetAndGreetEvents() {
            excludedEventTypes.append("Meet and Greet")
            excludedEventTypes.append("Clinic")
            excludedEventTypes.append("Listening Party")
        }
        if !getShowUnofficalEvents() {
            excludedEventTypes.append("Cruiser Organized")
            excludedEventTypes.append("Unofficial Event")
        }
        print("🔍 DEBUG: Final excludedEventTypes: \(excludedEventTypes)")
        
        if !excludedEventTypes.isEmpty {
            filteredEvents = filteredEvents.filter { event in
                guard let eventType = event.eventType else { return true } // Include events with no type
                return !excludedEventTypes.contains(eventType)
            }
        } else {
            print("🔍 DEBUG: No event types excluded - showing ALL event types")
        }
        
        // 3. VENUE FILTERING (per-venue state: configured prefix match or discovered = full location; same as list/calendar)
        let filterVenues = FestivalConfig.current.getAllVenueNames()
        filteredEvents = filteredEvents.filter { event in
            let location = event.location
            var venueNameToCheck: String?
            for venueName in filterVenues {
                if location.lowercased().hasPrefix(venueName.lowercased()) {
                    venueNameToCheck = venueName
                    break
                }
            }
            if venueNameToCheck == nil {
                venueNameToCheck = location
            }
            guard let name = venueNameToCheck else { return false }
            return getShowVenueEvents(venueName: name)
        }
        
        // 4. TIME FILTERING (upcoming events only if hideExpiredScheduleData is enabled)
        if getHideExpireScheduleData() {
            let currentTime = Date().timeIntervalSinceReferenceDate
            filteredEvents = filteredEvents.filter { event in
                var endTimeIndex = event.endTimeIndex
                // FIX: Detect midnight crossing (matches Android logic)
                if event.timeIndex > endTimeIndex {
                    endTimeIndex += 86400 // Add 24 hours
                }
                // Add 10-minute buffer (600 seconds) before expiration
                return endTimeIndex + 600 > currentTime
            }
            print("🔍 DEBUG: Filtering expired events (endTimeIndex + 600 > \(currentTime))")
        }
        
        // 5. SORTING
        if sortBy == "name" {
            filteredEvents.sort { $0.bandName < $1.bandName }
        } else {
            filteredEvents.sort { $0.timeIndex < $1.timeIndex }
        }
        
        print("🚀 QUERY RESULT: Found \(filteredEvents.count) events from database")
        
        // 6. PRIORITY FILTERING (post-query filtering for priority since it's in separate system)
        var eventStrings: [String] = []
        var bandNames: Set<String> = Set()
        
        for event in filteredEvents {
            let bandName = event.bandName
            
            // Apply priority filtering (replaces rankFiltering function)
            let priority = priorityManager.getPriority(for: bandName)
            var includeBand = true
            
            if !getMustSeeOn() && priority == 1 {
                includeBand = false
            } else if !getMightSeeOn() && priority == 2 {
                includeBand = false
            } else if !getWontSeeOn() && priority == 3 {
                includeBand = false
            } else if !getUnknownSeeOn() && priority == 0 {
                includeBand = false
            }
            
            if includeBand {
                // Format for UI compatibility
                let eventString = "\(event.timeIndex):\(bandName)"
                eventStrings.append(eventString)
                bandNames.insert(bandName)
            }
        }
        
        // 7. Get bands without events (replaces band-only logic)
        let allBands = dataManager.fetchBands(forYear: year)
        var allBandNames = allBands.map { $0.bandName }
        
        // Find bands without events and apply same priority filtering
        var bandOnlyStrings: [String] = []
        for bandName in allBandNames {
            if !bandNames.contains(bandName) {
                // Apply priority filtering
                let priority = priorityManager.getPriority(for: bandName)
                var includeBand = true
                
                if !getMustSeeOn() && priority == 1 {
                    includeBand = false
                } else if !getMightSeeOn() && priority == 2 {
                    includeBand = false
                } else if !getWontSeeOn() && priority == 3 {
                    includeBand = false
                } else if !getUnknownSeeOn() && priority == 0 {
                    includeBand = false
                }
                
                if includeBand {
                    bandOnlyStrings.append(bandName)
                }
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        print("🚀 QUERY-BASED FILTERING COMPLETE - Time: \(String(format: "%.3f", (endTime - startTime) * 1000))ms")
        print("🚀 RESULTS: \(eventStrings.count) events, \(bandOnlyStrings.count) bands")
        
        return (
            events: eventStrings,
            bands: bandOnlyStrings, 
            eventCount: eventStrings.count,
            bandCount: bandOnlyStrings.count
        )
    }
    
    /// Get events with complex filtering criteria (legacy method, enhanced)
    /// - Parameters:
    ///   - bandNames: Optional array of band names to include
    ///   - locations: Optional array of locations to include
    ///   - eventTypes: Optional array of event types to include
    ///   - days: Optional array of days to include
    ///   - year: Optional year to filter by
    /// - Returns: Filtered events
    func getFilteredEvents(
        bandNames: [String]? = nil,
        locations: [String]? = nil,
        eventTypes: [String]? = nil,
        days: [String]? = nil,
        year: Int? = nil
    ) -> [EventData] {
        let targetYear = year ?? eventYear
        var events = dataManager.fetchEvents(forYear: targetYear)
        
        // Band name filtering
        if let bandNames = bandNames, !bandNames.isEmpty {
            let bandNameSet = Set(bandNames)
            events = events.filter { bandNameSet.contains($0.bandName) }
        }
        
        // Location filtering (EXACT match only, case-insensitive)
        if let locations = locations, !locations.isEmpty {
            events = events.filter { event in
                locations.contains { location in
                    event.location.localizedCaseInsensitiveCompare(location) == .orderedSame
                }
            }
        }
        
        // Event type filtering
        if let eventTypes = eventTypes, !eventTypes.isEmpty {
            let eventTypeSet = Set(eventTypes)
            events = events.filter { event in
                guard let eventType = event.eventType else { return false }
                return eventTypeSet.contains(eventType)
            }
        }
        
        // Day filtering
        if let days = days, !days.isEmpty {
            let daySet = Set(days)
            events = events.filter { event in
                guard let day = event.day else { return false }
                return daySet.contains(day)
            }
        }
        
        // Sort by timeIndex
        return events.sorted { $0.timeIndex < $1.timeIndex }
    }
    
    // MARK: - Statistics and Counts
    
    /// Get event count for a band
    /// - Parameter bandName: Name of the band
    /// - Returns: Number of events for the band
    func getEventCount(for bandName: String) -> Int {
        return dataManager.fetchEventsForBand(bandName, forYear: eventYear).count
    }
    
    /// Get total event count
    /// - Returns: Total number of events in database
    func getTotalEventCount() -> Int {
        return dataManager.fetchEvents().count
    }
    
    /// Get unique locations
    /// - Returns: Array of unique location names
    func getUniqueLocations() -> [String] {
        let allEvents = dataManager.fetchEvents()
        let locations = Set(allEvents.map { $0.location })
        return Array(locations).sorted()
    }
    
    /// Get unique event types
    /// - Returns: Array of unique event type names
    func getUniqueEventTypes() -> [String] {
        let allEvents = dataManager.fetchEvents()
        let eventTypes = Set(allEvents.compactMap { $0.eventType })
        return Array(eventTypes).sorted()
    }
    
    // MARK: - Data Management (Replaces scheduleHandler management methods)
    
    /// Load event data from cached file (replaces getCachedData)
    /// - Returns: True if data was loaded successfully
    func loadCachedData() -> Bool {
        print("📚 [MDF_DEBUG] EventManager.loadCachedData() called")
        print("📚 [MDF_DEBUG] Festival: \(FestivalConfig.current.festivalShortName)")
        let result = csvImporter.importEventsFromFile()
        print("📚 [MDF_DEBUG] loadCachedData result: \(result)")
        return result
    }
    
    /// Download and import fresh event data (replaces populateSchedule)
    /// - Parameters:
    ///   - forceDownload: Whether to force download even if data exists
    ///   - completion: Completion handler with success status
    func downloadAndImportEvents(forceDownload: Bool = false, completion: @escaping (Bool) -> Void) {
        print("🌐 [MDF_DEBUG] EventManager.downloadAndImportEvents() called")
        print("🌐 [MDF_DEBUG] Festival: \(FestivalConfig.current.festivalShortName)")
        print("🌐 [MDF_DEBUG] forceDownload: \(forceDownload)")
        csvImporter.downloadAndImportEvents(forceDownload: forceDownload) { success in
            print("🌐 [MDF_DEBUG] EventManager.downloadAndImportEvents result: \(success)")
            completion(success)
        }
    }
    
    /// Clear all cached event data (replaces clearCache)
    func clearCachedData() {
        csvImporter.clearCachedData()
    }
    
    /// Check if event data is empty
    /// - Returns: True if no events are stored
    func isEmpty() -> Bool {
        return csvImporter.isEmpty()
    }
    
    // MARK: - Legacy Compatibility Methods
    
    /// Get scheduling data in legacy format (for gradual migration)
    /// - Returns: Dictionary matching old schedulingData format
    func getLegacySchedulingData() -> [String: [TimeInterval: [String: String]]] {
        let events = getAllEvents()
        var result: [String: [TimeInterval: [String: String]]] = [:]
        
        for event in events {
            let bandName = event.bandName
            
            if result[bandName] == nil {
                result[bandName] = [:]
            }
            
            let eventData: [String: String] = [
                "Location": event.location,
                "Date": event.date ?? "",
                "Day": event.day ?? "",
                "Start Time": event.startTime ?? "",
                "End Time": event.endTime ?? "",
                "Type": event.eventType ?? "",
                "Notes": event.notes ?? "",
                "Description URL": event.descriptionUrl ?? "",
                "ImageURL": event.eventImageUrl ?? "",
                "ImageDate": "" // SQLite doesn't store ImageDate separately
            ]
            
            result[bandName]?[event.timeIndex] = eventData
        }
        
        return result
    }
    
    /// Get scheduling data by time in legacy format
    /// - Returns: Dictionary matching old schedulingDataByTime format
    func getLegacySchedulingDataByTime() -> [TimeInterval: [String: String]] {
        let events = getAllEvents()
        var result: [TimeInterval: [String: String]] = [:]
        
        for event in events {
            let eventData: [String: String] = [
                "Band": event.bandName,
                "Location": event.location,
                "Date": event.date ?? "",
                "Day": event.day ?? "",
                "Start Time": event.startTime ?? "",
                "End Time": event.endTime ?? "",
                "Type": event.eventType ?? "",
                "Notes": event.notes ?? "",
                "Description URL": event.descriptionUrl ?? "",
                "ImageURL": event.eventImageUrl ?? "",
                "ImageDate": "" // SQLite doesn't store ImageDate separately
            ]
            
            result[event.timeIndex] = eventData
        }
        
        return result
    }
}

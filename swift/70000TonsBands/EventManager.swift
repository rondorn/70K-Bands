import Foundation
import CoreData

/// Manages all event operations using Core Data
/// Replaces the legacy scheduleHandler dictionary system with database operations
class EventManager {
    private let coreDataManager: CoreDataManager
    private let csvImporter: EventCSVImporter
    
    init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        print("📊 [MDF_DEBUG] EventManager.init() called")
        print("📊 [MDF_DEBUG] Festival: \(FestivalConfig.current.festivalShortName)")
        self.coreDataManager = coreDataManager
        self.csvImporter = EventCSVImporter(coreDataManager: coreDataManager)
        print("📊 [MDF_DEBUG] EventManager.init() completed - csvImporter created")
    }
    
    // MARK: - Event Data Access (Replaces scheduleHandler methods)
    
    /// Get all events for a band (replaces schedulingData[bandName])
    /// - Parameter bandName: Name of the band
    /// - Returns: Array of events sorted by time
    func getEvents(for bandName: String) -> [Event] {
        return csvImporter.getEvents(for: bandName)
    }
    
    /// Get events by time index (replaces schedulingDataByTime[timeIndex])
    /// - Parameter timeIndex: Time index to search for
    /// - Returns: Array of events at that time
    func getEvents(byTimeIndex timeIndex: TimeInterval) -> [Event] {
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
    func getAllEvents() -> [Event] {
        print("🔍 [MDF_DEBUG] getAllEvents() called")
        print("🔍 [MDF_DEBUG] Festival: \(FestivalConfig.current.festivalShortName)")
        print("🔍 [MDF_DEBUG] Current eventYear: \(eventYear)")
        
        let results = getEvents(forYear: eventYear)
        print("🔍 [MDF_DEBUG] Found \(results.count) events in Core Data for year \(eventYear)")
        
        if results.count > 0 {
            print("🔍 [MDF_DEBUG] First few events:")
            for (index, event) in results.prefix(3).enumerated() {
                print("   \(index + 1). \(event.band?.bandName ?? "Unknown") at \(event.location ?? "Unknown") on \(event.date ?? "Unknown")")
            }
        }
        
        return results
    }
    
    // MARK: - Advanced Filtering and Queries
    
    /// Get events by year
    /// - Parameter year: Event year to filter by
    /// - Returns: Events for the specified year
    func getEvents(forYear year: Int) -> [Event] {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "eventYear == %d", year)
        request.sortDescriptors = [NSSortDescriptor(key: "timeIndex", ascending: true)]
        
        do {
            return try coreDataManager.context.fetch(request)
        } catch {
            print("❌ Error fetching events for year \(year): \(error)")
            return []
        }
    }
    
    /// Get events by location (filtered by current year)
    /// - Parameter location: Location to filter by
    /// - Returns: Events at the specified location for current eventYear
    func getEvents(atLocation location: String) -> [Event] {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "location CONTAINS[cd] %@ AND eventYear == %d", location, Int32(eventYear))
        request.sortDescriptors = [NSSortDescriptor(key: "timeIndex", ascending: true)]
        
        do {
            return try coreDataManager.context.fetch(request)
        } catch {
            print("❌ Error fetching events at location \(location): \(error)")
            return []
        }
    }
    
    /// Get events by type (filtered by current year)
    /// - Parameter eventType: Event type to filter by
    /// - Returns: Events of the specified type for current eventYear
    func getEvents(ofType eventType: String) -> [Event] {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "eventType == %@ AND eventYear == %d", eventType, Int32(eventYear))
        request.sortDescriptors = [NSSortDescriptor(key: "timeIndex", ascending: true)]
        
        do {
            return try coreDataManager.context.fetch(request)
        } catch {
            print("❌ Error fetching events of type \(eventType): \(error)")
            return []
        }
    }
    
    /// Get events by day (filtered by current year)
    /// - Parameter day: Day to filter by
    /// - Returns: Events on the specified day for current eventYear
    func getEvents(onDay day: String) -> [Event] {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "day == %@ AND eventYear == %d", day, Int32(eventYear))
        request.sortDescriptors = [NSSortDescriptor(key: "timeIndex", ascending: true)]
        
        do {
            return try coreDataManager.context.fetch(request)
        } catch {
            print("❌ Error fetching events on day \(day): \(error)")
            return []
        }
    }
    
    /// Get events within time range (filtered by current year)
    /// - Parameters:
    ///   - startTime: Start time interval
    ///   - endTime: End time interval
    /// - Returns: Events within the time range for current eventYear
    func getEvents(from startTime: TimeInterval, to endTime: TimeInterval) -> [Event] {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "timeIndex >= %f AND timeIndex <= %f AND eventYear == %d", startTime, endTime, Int32(eventYear))
        request.sortDescriptors = [NSSortDescriptor(key: "timeIndex", ascending: true)]
        
        do {
            return try coreDataManager.context.fetch(request)
        } catch {
            print("❌ Error fetching events in time range: \(error)")
            return []
        }
    }
    
    /// Get upcoming events (replaces hasUpcomingShows logic, filtered by current year)
    /// - Parameter bandName: Name of the band
    /// - Returns: Future events for the band in current eventYear
    func getUpcomingEvents(for bandName: String) -> [Event] {
        let currentTime = Date().timeIntervalSince1970
        
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "band.bandName == %@ AND timeIndex > %f AND eventYear == %d", bandName, currentTime, Int32(eventYear))
        request.sortDescriptors = [NSSortDescriptor(key: "timeIndex", ascending: true)]
        
        do {
            return try coreDataManager.context.fetch(request)
        } catch {
            print("❌ Error fetching upcoming events for \(bandName): \(error)")
            return []
        }
    }
    
    /// Get past events (filtered by current year)
    /// - Parameter bandName: Name of the band
    /// - Returns: Past events for the band in current eventYear
    func getPastEvents(for bandName: String) -> [Event] {
        let currentTime = Date().timeIntervalSince1970
        
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "band.bandName == %@ AND timeIndex <= %f AND eventYear == %d", bandName, currentTime, Int32(eventYear))
        request.sortDescriptors = [NSSortDescriptor(key: "timeIndex", ascending: false)]
        
        do {
            return try coreDataManager.context.fetch(request)
        } catch {
            print("❌ Error fetching past events for \(bandName): \(error)")
            return []
        }
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
        priorityManager: PriorityManager,
        attendedHandle: ShowsAttended
    ) -> (events: [String], bands: [String], eventCount: Int, bandCount: Int) {
        
        print("🚀 QUERY-BASED FILTERING START - Year: \(year), Sort: \(sortBy)")
        
        // DEBUG: Check what years we have in the database
        let allEventsRequest: NSFetchRequest<Event> = Event.fetchRequest()
        do {
            let allEvents = try coreDataManager.context.fetch(allEventsRequest)
            print("🔍 DEBUG: Total events in database: \(allEvents.count)")
            let eventYears = Dictionary(grouping: allEvents, by: { $0.eventYear })
            for (year, events) in eventYears.sorted(by: { $0.key < $1.key }) {
                print("🔍 DEBUG: Year \(year) has \(events.count) events")
            }
            
            // Check if events have year 0 (which means they weren't properly imported)
            let zeroYearEvents = allEvents.filter { $0.eventYear == 0 }
            if !zeroYearEvents.isEmpty {
                print("🚨 ERROR: Found \(zeroYearEvents.count) events with eventYear = 0 (improperly imported)")
            }
            
            // Check for duplicate events (same band, time, location)
            let currentYearEvents = allEvents.filter { $0.eventYear == Int32(year) }
            var duplicateGroups: [String: [Event]] = [:]
            
            for event in currentYearEvents {
                guard let bandName = event.band?.bandName else { continue }
                let key = "\(bandName)|\(event.timeIndex)|\(event.location ?? "Unknown")"
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
            
            // Clean up duplicates if found
            if !duplicates.isEmpty {
                print("🚨 RUNNING DUPLICATE CLEANUP...")
                coreDataManager.removeDuplicateEvents()
                print("🚨 DUPLICATE CLEANUP COMPLETE - Please check results")
            }
        } catch {
            print("❌ Error checking event years: \(error)")
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Build compound predicate for all active filters
        var eventPredicates: [NSPredicate] = []
        var bandPredicates: [NSPredicate] = []
        
        // 1. YEAR FILTERING
        print("🎯 [MDF_DEBUG] YEAR FILTERING:")
        print("   Filtering for eventYear == \(year)")
        print("   Global eventYear variable: \(eventYear)")
        let yearPredicate = NSPredicate(format: "eventYear == %d", year)
        eventPredicates.append(yearPredicate)
        
        // 2. EVENT TYPE FILTERING (EXCLUSIVE approach - show everything EXCEPT filtered out types)
        // This ensures new unknown event types appear by default
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
            let eventTypePredicate = NSPredicate(format: "NOT (eventType IN %@)", excludedEventTypes)
            eventPredicates.append(eventTypePredicate)
        } else {
            print("🔍 DEBUG: No event types excluded - showing ALL event types")
        }
        
        // 3. VENUE FILTERING (DYNAMIC approach using FestivalConfig venues)
        // This ensures new venues from different festivals are handled automatically
        
        // Get the filter venues from FestivalConfig (only venues with showInFilters=true)
        let filterVenues = FestivalConfig.current.getFilterVenueNames()
        
        // Build list of enabled filter venues
        var enabledFilterVenues: [String] = []
        
        for venueName in filterVenues {
            if getShowVenueEvents(venueName: venueName) {
                enabledFilterVenues.append(venueName)
                print("🔍 DEBUG: ✅ Including \(venueName) venues")
            } else {
                print("🔍 DEBUG: ❌ EXCLUDING \(venueName) venues")
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
            print("🔍 DEBUG: ✅ Including Other venues (venues with showInFilters=false)")
            // If Other venues are enabled, we need to add a predicate for "NOT any filter venue"
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
            print("🔍 DEBUG: ❌ EXCLUDING Other venues (venues with showInFilters=false)")
        }
        
        // Apply the venue filter: show events that match enabled venues OR other venues (if enabled)
        if !venuePredicateParts.isEmpty {
            let venuePredicate = NSCompoundPredicate(orPredicateWithSubpredicates: venuePredicateParts)
            eventPredicates.append(venuePredicate)
            print("🔍 DEBUG: Applied venue filter: enabled=\(enabledFilterVenues), other=\(getShowOtherShows())")
        } else {
            // No venues enabled and Other venues disabled = hide all venues
            print("🔍 DEBUG: ⚠️ No venues enabled - this will show no events")
            eventPredicates.append(NSPredicate(value: false)) // Force no results
        }
        
        // 4. TIME FILTERING (upcoming events only if hideExpiredScheduleData is enabled)
        if getHideExpireScheduleData() {
            let currentTime = Date().timeIntervalSince1970
            let timePredicate = NSPredicate(format: "endTimeIndex > %f", currentTime)
            eventPredicates.append(timePredicate)
        }
        
        // Execute query for events
        let eventRequest: NSFetchRequest<Event> = Event.fetchRequest()
        if !eventPredicates.isEmpty {
            eventRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: eventPredicates)
            print("🔍 DEBUG: Final query predicate: \(eventRequest.predicate!)")
        }
        
        // Set sort order
        if sortBy == "name" {
            eventRequest.sortDescriptors = [NSSortDescriptor(key: "band.bandName", ascending: true)]
        } else {
            eventRequest.sortDescriptors = [NSSortDescriptor(key: "timeIndex", ascending: true)]
        }
        
        var filteredEvents: [Event] = []
        do {
            filteredEvents = try coreDataManager.context.fetch(eventRequest)
            print("🚀 QUERY RESULT: Found \(filteredEvents.count) events from database")
        } catch {
            print("❌ Error fetching filtered events: \(error)")
            filteredEvents = []
        }
        
        // 5. PRIORITY FILTERING (post-query filtering for priority since it's in separate system)
        var eventStrings: [String] = []
        var bandNames: Set<String> = Set()
        
        for event in filteredEvents {
            guard let bandName = event.band?.bandName else { continue }
            
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
        
        // 6. Get bands without events (replaces band-only logic)
        let bandRequest: NSFetchRequest<Band> = Band.fetchRequest()
        bandRequest.predicate = NSPredicate(format: "eventYear == %d", year)
        bandRequest.sortDescriptors = [NSSortDescriptor(key: "bandName", ascending: true)]
        
        var allBandNames: [String] = []
        do {
            let bands = try coreDataManager.context.fetch(bandRequest)
            allBandNames = bands.compactMap { $0.bandName }
        } catch {
            print("❌ Error fetching bands: \(error)")
        }
        
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
    ) -> [Event] {
        var predicates: [NSPredicate] = []
        
        // Band name filtering
        if let bandNames = bandNames, !bandNames.isEmpty {
            let bandPredicate = NSPredicate(format: "band.bandName IN %@", bandNames)
            predicates.append(bandPredicate)
        }
        
        // Location filtering
        if let locations = locations, !locations.isEmpty {
            let locationPredicates = locations.map { NSPredicate(format: "location CONTAINS[cd] %@", $0) }
            let locationPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: locationPredicates)
            predicates.append(locationPredicate)
        }
        
        // Event type filtering
        if let eventTypes = eventTypes, !eventTypes.isEmpty {
            let typePredicate = NSPredicate(format: "eventType IN %@", eventTypes)
            predicates.append(typePredicate)
        }
        
        // Day filtering
        if let days = days, !days.isEmpty {
            let dayPredicate = NSPredicate(format: "day IN %@", days)
            predicates.append(dayPredicate)
        }
        
        // Year filtering
        if let year = year {
            let yearPredicate = NSPredicate(format: "eventYear == %d", year)
            predicates.append(yearPredicate)
        }
        
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        request.sortDescriptors = [NSSortDescriptor(key: "timeIndex", ascending: true)]
        
        do {
            return try coreDataManager.context.fetch(request)
        } catch {
            print("❌ Error fetching filtered events: \(error)")
            return []
        }
    }
    
    // MARK: - Statistics and Counts
    
    /// Get event count for a band
    /// - Parameter bandName: Name of the band
    /// - Returns: Number of events for the band
    func getEventCount(for bandName: String) -> Int {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "band.bandName == %@", bandName)
        
        do {
            return try coreDataManager.context.count(for: request)
        } catch {
            print("❌ Error counting events for \(bandName): \(error)")
            return 0
        }
    }
    
    /// Get total event count
    /// - Returns: Total number of events in database
    func getTotalEventCount() -> Int {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        
        do {
            return try coreDataManager.context.count(for: request)
        } catch {
            print("❌ Error counting total events: \(error)")
            return 0
        }
    }
    
    /// Get unique locations
    /// - Returns: Array of unique location names
    func getUniqueLocations() -> [String] {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.propertiesToFetch = ["location"]
        request.returnsDistinctResults = true
        request.resultType = .dictionaryResultType
        
        do {
            let results = try coreDataManager.context.fetch(request) as! [[String: Any]]
            return results.compactMap { $0["location"] as? String }.sorted()
        } catch {
            print("❌ Error fetching unique locations: \(error)")
            return []
        }
    }
    
    /// Get unique event types
    /// - Returns: Array of unique event type names
    func getUniqueEventTypes() -> [String] {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.propertiesToFetch = ["eventType"]
        request.returnsDistinctResults = true
        request.resultType = .dictionaryResultType
        
        do {
            let results = try coreDataManager.context.fetch(request) as! [[String: Any]]
            return results.compactMap { $0["eventType"] as? String }.sorted()
        } catch {
            print("❌ Error fetching unique event types: \(error)")
            return []
        }
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
            guard let bandName = event.band?.bandName else { continue }
            
            if result[bandName] == nil {
                result[bandName] = [:]
            }
            
            let eventData: [String: String] = [
                "Location": event.location ?? "",
                "Date": event.date ?? "",
                "Day": event.day ?? "",
                "Start Time": event.startTime ?? "",
                "End Time": event.endTime ?? "",
                "Type": event.eventType ?? "",
                "Notes": event.notes ?? "",
                "Description URL": event.descriptionUrl ?? "",
                "ImageURL": event.eventImageUrl ?? "",
                "ImageDate": event.eventImageDate ?? ""
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
                "Band": event.band?.bandName ?? "",
                "Location": event.location ?? "",
                "Date": event.date ?? "",
                "Day": event.day ?? "",
                "Start Time": event.startTime ?? "",
                "End Time": event.endTime ?? "",
                "Type": event.eventType ?? "",
                "Notes": event.notes ?? "",
                "Description URL": event.descriptionUrl ?? "",
                "ImageURL": event.eventImageUrl ?? "",
                "ImageDate": event.eventImageDate ?? ""
            ]
            
            result[event.timeIndex] = eventData
        }
        
        return result
    }
}

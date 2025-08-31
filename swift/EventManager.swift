import Foundation
import CoreData

/// Manages all event operations using Core Data
/// Replaces the legacy scheduleHandler dictionary system with database operations
class EventManager {
    private let coreDataManager: CoreDataManager
    private let csvImporter: EventCSVImporter
    
    init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        self.coreDataManager = coreDataManager
        self.csvImporter = EventCSVImporter(coreDataManager: coreDataManager)
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
    
    /// Get all events (replaces full schedule access)
    /// - Returns: All events sorted by time
    func getAllEvents() -> [Event] {
        return csvImporter.getEventsArray()
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
    
    /// Get events by location
    /// - Parameter location: Location to filter by
    /// - Returns: Events at the specified location
    func getEvents(atLocation location: String) -> [Event] {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "location CONTAINS[cd] %@", location)
        request.sortDescriptors = [NSSortDescriptor(key: "timeIndex", ascending: true)]
        
        do {
            return try coreDataManager.context.fetch(request)
        } catch {
            print("❌ Error fetching events at location \(location): \(error)")
            return []
        }
    }
    
    /// Get events by type
    /// - Parameter eventType: Event type to filter by
    /// - Returns: Events of the specified type
    func getEvents(ofType eventType: String) -> [Event] {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "eventType == %@", eventType)
        request.sortDescriptors = [NSSortDescriptor(key: "timeIndex", ascending: true)]
        
        do {
            return try coreDataManager.context.fetch(request)
        } catch {
            print("❌ Error fetching events of type \(eventType): \(error)")
            return []
        }
    }
    
    /// Get events by day
    /// - Parameter day: Day to filter by
    /// - Returns: Events on the specified day
    func getEvents(onDay day: String) -> [Event] {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "day == %@", day)
        request.sortDescriptors = [NSSortDescriptor(key: "timeIndex", ascending: true)]
        
        do {
            return try coreDataManager.context.fetch(request)
        } catch {
            print("❌ Error fetching events on day \(day): \(error)")
            return []
        }
    }
    
    /// Get events within time range
    /// - Parameters:
    ///   - startTime: Start time interval
    ///   - endTime: End time interval
    /// - Returns: Events within the time range
    func getEvents(from startTime: TimeInterval, to endTime: TimeInterval) -> [Event] {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "timeIndex >= %f AND timeIndex <= %f", startTime, endTime)
        request.sortDescriptors = [NSSortDescriptor(key: "timeIndex", ascending: true)]
        
        do {
            return try coreDataManager.context.fetch(request)
        } catch {
            print("❌ Error fetching events in time range: \(error)")
            return []
        }
    }
    
    /// Get upcoming events (replaces hasUpcomingShows logic)
    /// - Parameter bandName: Name of the band
    /// - Returns: Future events for the band
    func getUpcomingEvents(for bandName: String) -> [Event] {
        let currentTime = Date().timeIntervalSince1970
        
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "band.bandName == %@ AND timeIndex > %f", bandName, currentTime)
        request.sortDescriptors = [NSSortDescriptor(key: "timeIndex", ascending: true)]
        
        do {
            return try coreDataManager.context.fetch(request)
        } catch {
            print("❌ Error fetching upcoming events for \(bandName): \(error)")
            return []
        }
    }
    
    /// Get past events
    /// - Parameter bandName: Name of the band
    /// - Returns: Past events for the band
    func getPastEvents(for bandName: String) -> [Event] {
        let currentTime = Date().timeIntervalSince1970
        
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "band.bandName == %@ AND timeIndex <= %f", bandName, currentTime)
        request.sortDescriptors = [NSSortDescriptor(key: "timeIndex", ascending: false)]
        
        do {
            return try coreDataManager.context.fetch(request)
        } catch {
            print("❌ Error fetching past events for \(bandName): \(error)")
            return []
        }
    }
    
    // MARK: - Complex Filtering (Replaces MasterViewController filtering logic)
    
    /// Get events with complex filtering criteria
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
        return csvImporter.importEventsFromFile()
    }
    
    /// Download and import fresh event data (replaces populateSchedule)
    /// - Parameters:
    ///   - forceDownload: Whether to force download even if data exists
    ///   - completion: Completion handler with success status
    func downloadAndImportEvents(forceDownload: Bool = false, completion: @escaping (Bool) -> Void) {
        csvImporter.downloadAndImportEvents(forceDownload: forceDownload, completion: completion)
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
                "ImageURL": event.eventImageUrl ?? ""
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
                "ImageURL": event.eventImageUrl ?? ""
            ]
            
            result[event.timeIndex] = eventData
        }
        
        return result
    }
}

import Foundation
import CoreData

/// Imports event/schedule data from CSV files into Core Data
/// Replaces the legacy scheduleHandler dictionary system with database storage
class EventCSVImporter {
    private let coreDataManager: CoreDataManager
    
    init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        self.coreDataManager = coreDataManager
    }
    
    // MARK: - CSV Import Methods
    
    /// Import events from CSV string data
    /// - Parameter csvString: Raw CSV data string
    /// - Returns: True if import was successful
    func importEventsFromCSV(_ csvString: String) -> Bool {
        print("🎭 Starting event CSV import to Core Data...")
        
        guard !csvString.isEmpty else {
            print("❌ CSV string is empty")
            return false
        }
        
        // Check if file has valid headers
        let hasValidHeaders = csvString.contains("Band,Location,Date,Day,Start Time,End Time,Type")
        guard hasValidHeaders else {
            print("❌ CSV does not contain valid headers")
            return false
        }
        
        do {
            let csvData = try CSV(csvStringToParse: csvString)
            print("📊 Processing \(csvData.rows.count) event entries...")
            
            var importedCount = 0
            var updatedCount = 0
            var skippedCount = 0
            
            for lineData in csvData.rows {
                // Skip rows without required data
                guard let bandName = lineData["Band"], !bandName.isEmpty,
                      let location = lineData["Location"], !location.isEmpty,
                      let date = lineData["Date"], !date.isEmpty,
                      let startTime = lineData["Start Time"], !startTime.isEmpty else {
                    skippedCount += 1
                    continue
                }
                
                // Get or create the band
                let band = coreDataManager.createOrUpdateBand(name: bandName)
                
                // Create unique identifier for this event
                let timeIndex = getDateIndex(date, timeString: startTime, band: bandName)
                
                // Check if event already exists
                let existingEvent = fetchEvent(band: band, timeIndex: timeIndex)
                let event = existingEvent ?? Event(context: coreDataManager.context)
                
                // Update event data
                event.band = band
                event.location = location
                event.date = date
                event.day = lineData["Day"] ?? ""
                event.startTime = startTime
                event.endTime = lineData["End Time"] ?? ""
                event.timeIndex = timeIndex
                event.eventYear = Int32(eventYear)
                
                // Handle event type
                var eventType = lineData["Type"] ?? ""
                if eventType == "Unofficial Event (Old)" {
                    eventType = "Unofficial Event"
                }
                event.eventType = eventType
                
                // Optional fields
                event.notes = lineData["Notes"]
                event.descriptionUrl = lineData["Description URL"]
                event.eventImageUrl = lineData["ImageURL"]
                
                // Set timestamps
                if existingEvent == nil {
                    event.createdAt = Date()
                    importedCount += 1
                    print("✅ Imported event: \(bandName) at \(location) on \(date)")
                } else {
                    updatedCount += 1
                    print("🔄 Updated event: \(bandName) at \(location) on \(date)")
                }
                event.updatedAt = Date()
            }
            
            // Save all changes
            coreDataManager.saveContext()
            
            print("🎉 Event import complete!")
            print("📊 Imported: \(importedCount), Updated: \(updatedCount), Skipped: \(skippedCount)")
            print("📊 Total: \(importedCount + updatedCount) events processed")
            
            return true
            
        } catch {
            print("❌ Error parsing CSV: \(error)")
            return false
        }
    }
    
    /// Import events from the standard event file location
    /// This replaces scheduleHandler.getCachedData()
    func importEventsFromFile() -> Bool {
        let documentsPath = getDocumentsDirectory()
        let scheduleFilePath = documentsPath + "/schedule.txt"
        
        guard let csvString = try? String(contentsOfFile: scheduleFilePath, encoding: .utf8) else {
            print("❌ Could not read schedule file at: \(scheduleFilePath)")
            return false
        }
        
        return importEventsFromCSV(csvString)
    }
    
    /// Download and import events from URL
    /// This replaces scheduleHandler.populateSchedule()
    func downloadAndImportEvents(forceDownload: Bool = false, completion: @escaping (Bool) -> Void) {
        print("🌐 Starting event data download and import...")
        
        // Check if we should skip download
        if !forceDownload {
            let existingEventCount = fetchEvents().count
            if existingEventCount > 0 {
                print("📚 Events already in database (\(existingEventCount) events), skipping download")
                completion(true)
                return
            }
        }
        
        // Get the schedule URL from pointer data
        let scheduleUrl = getPointerUrlData(keyValue: "scheduleUrl") ?? ""
        guard !scheduleUrl.isEmpty else {
            print("❌ Could not get schedule URL from pointer data")
            completion(false)
            return
        }
        
        print("📥 Downloading event data from: \(scheduleUrl)")
        
        // Download the CSV data
        DispatchQueue.global(qos: .userInitiated).async {
            let csvData = getUrlData(urlString: scheduleUrl)
            
            DispatchQueue.main.async {
                guard !csvData.isEmpty else {
                    print("❌ Downloaded CSV data is empty")
                    completion(false)
                    return
                }
                
                // Save to file for caching
                self.saveEventDataToFile(csvData)
                
                // Import to Core Data
                let success = self.importEventsFromCSV(csvData)
                
                if success {
                    print("✅ Event download and import completed successfully")
                } else {
                    print("❌ Event import failed")
                }
                
                completion(success)
            }
        }
    }
    
    // MARK: - Data Access Methods (Compatible with existing code)
    
    /// Get all events as array (replacement for scheduleHandler access)
    func getEventsArray() -> [Event] {
        return fetchEvents()
    }
    
    /// Get events for a specific band (replacement for schedulingData[bandName])
    func getEvents(for bandName: String) -> [Event] {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "band.bandName == %@", bandName)
        request.sortDescriptors = [NSSortDescriptor(key: "timeIndex", ascending: true)]
        
        do {
            return try coreDataManager.context.fetch(request)
        } catch {
            print("❌ Error fetching events for band \(bandName): \(error)")
            return []
        }
    }
    
    /// Get events by time index (replacement for schedulingDataByTime)
    func getEvents(byTimeIndex timeIndex: TimeInterval) -> [Event] {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "timeIndex == %f", timeIndex)
        
        do {
            return try coreDataManager.context.fetch(request)
        } catch {
            print("❌ Error fetching events by time index: \(error)")
            return []
        }
    }
    
    /// Get event data for specific band and time (replacement for getData method)
    func getEventData(bandName: String, timeIndex: TimeInterval, field: String) -> String {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "band.bandName == %@ AND timeIndex == %f", bandName, timeIndex)
        request.fetchLimit = 1
        
        do {
            guard let event = try coreDataManager.context.fetch(request).first else {
                return ""
            }
            
            // Map field names to event properties
            switch field {
            case "Location": return event.location ?? ""
            case "Date": return event.date ?? ""
            case "Day": return event.day ?? ""
            case "Start Time": return event.startTime ?? ""
            case "End Time": return event.endTime ?? ""
            case "Type": return event.eventType ?? ""
            case "Notes": return event.notes ?? ""
            case "Description URL": return event.descriptionUrl ?? ""
            case "ImageURL": return event.eventImageUrl ?? ""
            default: return ""
            }
        } catch {
            print("❌ Error fetching event data: \(error)")
            return ""
        }
    }
    
    /// Check if events data is empty
    func isEmpty() -> Bool {
        return fetchEvents().isEmpty
    }
    
    /// Clear all cached event data
    func clearCachedData() {
        let request: NSFetchRequest<NSFetchRequestResult> = Event.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try coreDataManager.context.execute(deleteRequest)
            coreDataManager.saveContext()
            print("🗑️ Cleared all event data from Core Data")
        } catch {
            print("❌ Error clearing event data: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveEventDataToFile(_ data: String) {
        let documentsPath = getDocumentsDirectory()
        let scheduleFilePath = documentsPath + "/schedule.txt"
        
        do {
            try data.write(toFile: scheduleFilePath, atomically: true, encoding: .utf8)
            print("💾 Saved event data to file: \(scheduleFilePath)")
        } catch {
            print("❌ Error saving event data to file: \(error)")
        }
    }
    
    private func getDocumentsDirectory() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        return paths[0]
    }
    
    private func fetchEvents() -> [Event] {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timeIndex", ascending: true)]
        
        do {
            return try coreDataManager.context.fetch(request)
        } catch {
            print("❌ Error fetching events: \(error)")
            return []
        }
    }
    
    private func fetchEvent(band: Band, timeIndex: TimeInterval) -> Event? {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "band == %@ AND timeIndex == %f", band, timeIndex)
        request.fetchLimit = 1
        
        do {
            return try coreDataManager.context.fetch(request).first
        } catch {
            print("❌ Error fetching event: \(error)")
            return nil
        }
    }
    
    /// Calculate unique time index for event (matches scheduleHandler logic)
    private func getDateIndex(_ dateString: String, timeString: String, band: String) -> TimeInterval {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-M-d HH:mm"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let fullDateString = "\(dateString) \(timeString)"
        
        if let date = dateFormatter.date(from: fullDateString) {
            var timeIndex = date.timeIntervalSince1970
            
            // Ensure uniqueness by checking existing events
            while fetchEvent(band: coreDataManager.createOrUpdateBand(name: band), timeIndex: timeIndex) != nil {
                timeIndex += 1
            }
            
            return timeIndex
        } else {
            // Fallback to current time if parsing fails
            return Date().timeIntervalSince1970
        }
    }
}

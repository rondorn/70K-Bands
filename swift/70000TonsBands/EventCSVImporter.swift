import Foundation
import CoreData

/// Imports event/schedule data from CSV files into Core Data
/// Replaces the legacy scheduleHandler dictionary system with database storage
class EventCSVImporter {
    private let coreDataManager: CoreDataManager
    
    init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        print("🎭 [MDF_DEBUG] EventCSVImporter.init() called")
        print("🎭 [MDF_DEBUG] Festival: \(FestivalConfig.current.festivalShortName)")
        self.coreDataManager = coreDataManager
        print("🎭 [MDF_DEBUG] EventCSVImporter.init() completed")
    }
    
    // MARK: - Event Identifier Generation
    
    /// Creates a sanitized event identifier using the band's sanitized name
    /// Format: "eventName:sanitizedBandName:location:startTime:eventType:year"
    static func createSanitizedEventIdentifier(bandName: String, location: String, startTime: String, eventType: String, year: String) -> String {
        let sanitizedBandName = BandCSVImporter.sanitizeBandName(bandName)
        return "eventName:\(sanitizedBandName):\(location):\(startTime):\(eventType):\(year)"
    }
    
    /// Creates the original event identifier format (for backward compatibility)
    /// Format: "eventName:originalBandName:location:startTime:eventType:year"  
    static func createOriginalEventIdentifier(bandName: String, location: String, startTime: String, eventType: String, year: String) -> String {
        return "eventName:\(bandName):\(location):\(startTime):\(eventType):\(year)"
    }
    
    // MARK: - CSV Import Methods
    
    /// Import events from CSV string data
    /// - Parameter csvString: Raw CSV data string
    /// - Returns: True if import was successful
    func importEventsFromCSV(_ csvString: String) -> Bool {
        print("🎭 [MDF_DEBUG] Starting event CSV import to Core Data...")
        print("🎭 [MDF_DEBUG] Festival Config: \(FestivalConfig.current.festivalShortName)")
        print("🎭 [MDF_DEBUG] CSV string length: \(csvString.count)")
        
        guard !csvString.isEmpty else {
            print("❌ [MDF_DEBUG] CSV string is empty")
            return false
        }
        
        // Debug: Show first 500 characters of CSV
        let preview = String(csvString.prefix(500))
        print("🎭 [MDF_DEBUG] CSV Preview: \(preview)")
        
        // Check if file has valid headers
        let hasValidHeaders = csvString.contains("Band,Location,Date,Day,Start Time,End Time,Type")
        print("🎭 [MDF_DEBUG] Has valid headers: \(hasValidHeaders)")
        
        guard hasValidHeaders else {
            print("❌ [MDF_DEBUG] CSV does not contain valid headers")
            print("❌ [MDF_DEBUG] Looking for: 'Band,Location,Date,Day,Start Time,End Time,Type'")
            let firstLine = csvString.components(separatedBy: "\n").first ?? "No first line"
            print("❌ [MDF_DEBUG] First line found: '\(firstLine)'")
            return false
        }
        
        do {
            let csvData = try CSV(csvStringToParse: csvString)
            print("📊 [MDF_DEBUG] CSV parsed successfully. Processing \(csvData.rows.count) event entries...")
            
            var importedCount = 0
            var updatedCount = 0
            var skippedCount = 0
            var rowIndex = 0
            
            for lineData in csvData.rows {
                rowIndex += 1
                
                // Debug first few rows
                if rowIndex <= 3 {
                    print("🎭 [MDF_DEBUG] Row \(rowIndex) data: \(lineData)")
                }
                
                // Skip rows without required data
                guard let bandName = lineData["Band"], !bandName.isEmpty,
                      let location = lineData["Location"], !location.isEmpty,
                      let date = lineData["Date"], !date.isEmpty,
                      let startTime = lineData["Start Time"], !startTime.isEmpty else {
                    skippedCount += 1
                    if rowIndex <= 5 {
                        print("⚠️ [MDF_DEBUG] Row \(rowIndex) SKIPPED - Missing data:")
                        print("   Band: '\(lineData["Band"] ?? "nil")'")
                        print("   Location: '\(lineData["Location"] ?? "nil")'") 
                        print("   Date: '\(lineData["Date"] ?? "nil")'")
                        print("   Start Time: '\(lineData["Start Time"] ?? "nil")'")
                    }
                    continue
                }
                
                // Debug processing for first few events
                if rowIndex <= 3 {
                    print("✅ [MDF_DEBUG] Row \(rowIndex) PROCESSING:")
                    print("   Band: '\(bandName)'")
                    print("   Location: '\(location)'")
                    print("   Date: '\(date)'")
                    print("   Start Time: '\(startTime)'")
                    print("   Event Year: \(eventYear)")
                }
                
                // Get or create the band
                let band = coreDataManager.createOrUpdateBand(name: bandName, eventYear: Int32(eventYear))
                
                // Create unique identifier for this event
                let timeIndex = getDateIndex(date, timeString: startTime, band: bandName)
                
                if rowIndex <= 3 {
                    print("🕐 [MDF_DEBUG] Row \(rowIndex) Time Index: \(timeIndex)")
                    let dateObj = Date(timeIntervalSince1970: timeIndex)
                    print("🕐 [MDF_DEBUG] Row \(rowIndex) Parsed Date: \(dateObj)")
                }
                
                // Check if event already exists
                let existingEvent = fetchEvent(band: band, timeIndex: timeIndex)
                let event = existingEvent ?? Event(context: coreDataManager.context)
                
                if rowIndex <= 3 {
                    print("💾 [MDF_DEBUG] Row \(rowIndex) Event Status: \(existingEvent != nil ? "EXISTING" : "NEW")")
                }
                
                // Update event data
                event.band = band
                event.location = location
                event.date = date
                event.day = lineData["Day"] ?? ""
                event.startTime = startTime
                event.endTime = lineData["End Time"] ?? ""
                event.timeIndex = timeIndex
                
                // Debug year assignment
                if rowIndex <= 3 {
                    print("🎯 [MDF_DEBUG] Row \(rowIndex) YEAR ASSIGNMENT:")
                    print("   Global eventYear variable: \(eventYear)")
                    print("   Event date string: '\(date)'")
                    print("   Assigning eventYear = \(eventYear) to Core Data event")
                }
                
                event.eventYear = Int32(eventYear)
                
                // Handle event type
                var eventType = lineData["Type"] ?? ""
                if eventType == "Unofficial Event (Old)" {
                    eventType = "Unofficial Event"
                }
                event.eventType = eventType
                
                // Generate identifiers for Firebase safety and backward compatibility
                let yearString = String(eventYear)
                event.identifier = EventCSVImporter.createOriginalEventIdentifier(
                    bandName: bandName, 
                    location: location, 
                    startTime: startTime, 
                    eventType: eventType, 
                    year: yearString
                )
                event.sanitizedIdentifier = EventCSVImporter.createSanitizedEventIdentifier(
                    bandName: bandName, 
                    location: location, 
                    startTime: startTime, 
                    eventType: eventType, 
                    year: yearString
                )
                
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
        print("📁 [MDF_DEBUG] importEventsFromFile called")
        print("📁 [MDF_DEBUG] Festival: \(FestivalConfig.current.festivalShortName)")
        
        let documentsPath = getDocumentsDirectory()
        let scheduleFilePath = documentsPath + "/schedule.txt"
        
        print("📁 [MDF_DEBUG] Looking for file at: \(scheduleFilePath)")
        print("📁 [MDF_DEBUG] File exists: \(FileManager.default.fileExists(atPath: scheduleFilePath))")
        
        guard let csvString = try? String(contentsOfFile: scheduleFilePath, encoding: .utf8) else {
            print("❌ [MDF_DEBUG] Could not read schedule file at: \(scheduleFilePath)")
            print("❌ [MDF_DEBUG] Directory contents:")
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: documentsPath) {
                for file in contents {
                    print("   - \(file)")
                }
            }
            return false
        }
        
        print("📁 [MDF_DEBUG] Successfully read file, length: \(csvString.count)")
        return importEventsFromCSV(csvString)
    }
    
    /// Download and import events from URL
    /// This replaces scheduleHandler.populateSchedule()
    func downloadAndImportEvents(forceDownload: Bool = false, completion: @escaping (Bool) -> Void) {
        print("🌐 [MDF_DEBUG] downloadAndImportEvents called")
        print("🌐 [MDF_DEBUG] Festival: \(FestivalConfig.current.festivalShortName)")
        print("🌐 [MDF_DEBUG] forceDownload: \(forceDownload)")
        
        // Check if we should skip download
        if !forceDownload {
            let existingEventCount = fetchEvents().count
            print("🌐 [MDF_DEBUG] Existing event count: \(existingEventCount)")
            if existingEventCount > 0 {
                print("📚 [MDF_DEBUG] Events already in database (\(existingEventCount) events), skipping download")
                completion(true)
                return
            }
        }
        
        // Get the schedule URL from pointer data
        let scheduleUrl = getPointerUrlData(keyValue: "scheduleUrl") ?? ""
        print("🌐 [MDF_DEBUG] Schedule URL from pointer: '\(scheduleUrl)'")
        print("🌐 [MDF_DEBUG] getScheduleUrl(): '\(getScheduleUrl())'")
        
        guard !scheduleUrl.isEmpty else {
            print("❌ [MDF_DEBUG] Could not get schedule URL from pointer data")
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
        print("🕐 [MDF_DEBUG] getDateIndex called:")
        print("   dateString: '\(dateString)'")
        print("   timeString: '\(timeString)'")
        print("   band: '\(band)'")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-M-d HH:mm"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let fullDateString = "\(dateString) \(timeString)"
        print("   fullDateString: '\(fullDateString)'")
        print("   dateFormat: '\(dateFormatter.dateFormat ?? "nil")'")
        
        if let date = dateFormatter.date(from: fullDateString) {
            print("✅ [MDF_DEBUG] Date parsed successfully: \(date)")
            var timeIndex = date.timeIntervalSince1970
            
            // Ensure uniqueness by checking existing events
            while fetchEvent(band: coreDataManager.createOrUpdateBand(name: band, eventYear: Int32(eventYear)), timeIndex: timeIndex) != nil {
                timeIndex += 1
            }
            
            print("✅ [MDF_DEBUG] Final timeIndex: \(timeIndex)")
            return timeIndex
        } else {
            print("❌ [MDF_DEBUG] Date parsing FAILED!")
            print("❌ [MDF_DEBUG] Trying alternative formats...")
            
            // Try the scheduleHandler formats
            let alternativeFormats = [
                "M/d/yyyy HH:mm",         // Single digit month/day + 24-hour (MOST LIKELY)
                "MM/dd/yyyy HH:mm",       // Double digit + 24-hour
                "M/d/yyyy H:mm",          // Single digit + single hour
                "MM/dd/yyyy H:mm"         // Double digit + single hour
            ]
            
            for format in alternativeFormats {
                dateFormatter.dateFormat = format
                if let date = dateFormatter.date(from: fullDateString) {
                    let timeInterval = date.timeIntervalSince1970
                    print("✅ [MDF_DEBUG] Alternative format '\(format)' worked: \(date) -> \(timeInterval)")
                    return timeInterval
                } else {
                    print("❌ [MDF_DEBUG] Format '\(format)' failed")
                }
            }
            
            // Fallback to current time if parsing fails
            let fallbackTime = Date().timeIntervalSince1970
            print("❌ [MDF_DEBUG] All formats failed, using fallback: \(fallbackTime)")
            return fallbackTime
        }
    }
}

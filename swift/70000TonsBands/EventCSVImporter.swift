import Foundation

/// Imports event/schedule data from CSV files directly into SQLite (via DataManager)
/// Replaces the legacy scheduleHandler dictionary system with database storage
/// All data writes go directly to SQLite - no Core Data intermediate step
/// Band table: only ensures a band row exists (createBandIfNotExists). Never sets or changes lineIndex; that is only set when the full band list is imported (BandCSVImporter).
class EventCSVImporter {
    private let dataManager = DataManager.shared
    
    init() {
        print("🎭 [MDF_DEBUG] EventCSVImporter.init() called")
        print("🎭 [MDF_DEBUG] Festival: \(FestivalConfig.current.festivalShortName)")
        print("🎭 [MDF_DEBUG] Using DataManager: \(type(of: dataManager))")
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
    
    /// Import events from CSV string data directly into SQLite
    /// - Parameter csvString: Raw CSV data string
    /// - Returns: True if import was successful
    func importEventsFromCSV(_ csvString: String) -> Bool {
        print("🎭 [MDF_DEBUG] Starting event CSV import to SQLite...")
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
                
                // Skip rows whose CSV Type indicates a non-show special row (never match on band name — real bands must not be dropped by substring).
                let specialEventTypes = [
                    "All Star Jam", "Meet & Greet", "Meet and Greet", "Q&A", "Q & A",
                    "Panel Discussion", "Workshop", "Seminar", "Awards", "Award Ceremony",
                    "Closing Ceremony", "Opening Ceremony", "Festival", "Special Event"
                ]
                
                let eventTypeFromCSV = lineData["Type"] ?? ""
                let isSpecialEvent = specialEventTypes.contains { specialType in
                    eventTypeFromCSV.localizedCaseInsensitiveContains(specialType)
                }
                
                if isSpecialEvent {
                    skippedCount += 1
                    if rowIndex <= 5 {
                        print("⚠️ [MDF_DEBUG] Row \(rowIndex) SKIPPED - Special event type (no band):")
                        print("   Band: '\(bandName)'")
                        print("   Type: '\(eventTypeFromCSV)'")
                        print("   Reason: Special event without actual band")
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
                
                // Ensure band exists in SQLite (create if needed). Does not set lineIndex; band list is never changed by schedule import.
                _ = dataManager.createBandIfNotExists(name: bandName, eventYear: eventYear)
                
                let normalizedStoredDate = ScheduleDateNormalization.canonicalStorageCalendarDate(from: date) ?? date
                
                // Create unique identifier for this event (use same string family as SQLite `date` column)
                let timeIndex = getDateIndex(normalizedStoredDate, timeString: startTime, band: bandName)
                
                if rowIndex <= 3 {
                    print("🕐 [MDF_DEBUG] Row \(rowIndex) Time Index: \(timeIndex)")
                    let dateObj = Date(timeIntervalSinceReferenceDate: timeIndex)
                    print("🕐 [MDF_DEBUG] Row \(rowIndex) Parsed Date: \(dateObj)")
                }
                
                // Calculate end time index (CRITICAL for proper event filtering)
                let endTime = lineData["End Time"] ?? ""
                let endTimeIndex = getDateIndex(normalizedStoredDate, timeString: endTime, band: bandName)
                
                if rowIndex <= 3 {
                    print("🕐 [MDF_DEBUG] Row \(rowIndex) End Time Index: \(endTimeIndex)")
                    print("🕐 [MDF_DEBUG] Row \(rowIndex) Duration: \((endTimeIndex - timeIndex) / 60) minutes")
                }
                
                // Handle event type
                var eventType = lineData["Type"] ?? ""
                if eventType == "Unofficial Event (Old)" {
                    eventType = "Unofficial Event"
                }
                
                // Check if event already exists in SQLite
                let existingEvents = dataManager.fetchEventsForBand(bandName, forYear: eventYear)
                let existingEvent = existingEvents.first { $0.timeIndex == timeIndex }
                
                if rowIndex <= 3 {
                    print("💾 [MDF_DEBUG] Row \(rowIndex) Event Status: \(existingEvent != nil ? "EXISTING" : "NEW")")
                    print("🎯 [MDF_DEBUG] Row \(rowIndex) YEAR ASSIGNMENT:")
                    print("   Global eventYear variable: \(eventYear)")
                    print("   Event date string: '\(date)'")
                    print("   Assigning eventYear = \(eventYear) to SQLite event")
                }
                
                // Get ImageDate for logging
                let imageDateFromCSV = lineData["ImageDate"] ?? ""
                let trimmedImageDate = imageDateFromCSV.trimmingCharacters(in: .whitespacesAndNewlines)
                let imageDate = trimmedImageDate.isEmpty ? nil : trimmedImageDate
                
                // DEBUG: Log ImageDate parsing for ALL events with ImageURL
                if let imageUrl = lineData["ImageURL"], !imageUrl.isEmpty {
                    if let imageDate = imageDate, !imageDate.isEmpty {
                        print("📅 [CSV_IMPORT] Parsed ImageDate '\(imageDate)' for band '\(lineData["Band"] ?? "unknown")' with ImageURL: \(imageUrl)")
                    } else {
                        print("⚠️ [CSV_IMPORT] Band '\(lineData["Band"] ?? "unknown")' has ImageURL but ImageDate is empty or missing")
                        print("⚠️ [CSV_IMPORT] Raw ImageDate value: '\(imageDateFromCSV)' (length: \(imageDateFromCSV.count))")
                        if rowIndex <= 5 {
                            print("⚠️ [CSV_IMPORT] Available CSV keys: \(lineData.keys.sorted())")
                        }
                    }
                }
                
                // Create or update event directly in SQLite
                _ = dataManager.createOrUpdateEvent(
                    bandName: bandName,
                    timeIndex: timeIndex,
                    endTimeIndex: endTimeIndex,
                    location: location,
                    date: normalizedStoredDate,
                    day: lineData["Day"],
                    startTime: startTime,
                    endTime: endTime,
                    eventType: eventType,
                    eventYear: eventYear,
                    notes: lineData["Notes"],
                    descriptionUrl: lineData["Description URL"],
                    eventImageUrl: lineData["ImageURL"]
                )
                
                // Track import/update counts
                if existingEvent == nil {
                    importedCount += 1
                    print("✅ Imported event: \(bandName) at \(location) on \(date)")
                } else {
                    updatedCount += 1
                    print("🔄 Updated event: \(bandName) at \(location) on \(date)")
                }
            }
            
            // SQLite writes are immediate (no saveContext needed)
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
                
                // Import directly to SQLite
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
    
    // MARK: - Data Access Methods (Using SQLite)
    
    /// Get all events as EventData array (replacement for scheduleHandler access)
    func getEventsArray() -> [EventData] {
        return dataManager.fetchEvents(forYear: eventYear)
    }
    
    /// Get events for a specific band (replacement for schedulingData[bandName])
    func getEvents(for bandName: String) -> [EventData] {
        return dataManager.fetchEventsForBand(bandName, forYear: eventYear)
    }
    
    /// Get events by time index (replacement for schedulingDataByTime)
    func getEvents(byTimeIndex timeIndex: TimeInterval) -> [EventData] {
        let allEvents = dataManager.fetchEvents(forYear: eventYear)
        return allEvents.filter { $0.timeIndex == timeIndex }
    }
    
    /// Get event data for specific band and time (replacement for getData method)
    func getEventData(bandName: String, timeIndex: TimeInterval, field: String) -> String {
        let events = dataManager.fetchEventsForBand(bandName, forYear: eventYear)
        guard let event = events.first(where: { $0.timeIndex == timeIndex }) else {
            return ""
        }
        
        // Map field names to event properties
        switch field {
        case "Location": return event.location
        case "Date": return event.date ?? ""
        case "Day": return event.day ?? ""
        case "Start Time": return event.startTime ?? ""
        case "End Time": return event.endTime ?? ""
        case "Type": return event.eventType ?? ""
        case "Notes": return event.notes ?? ""
        case "Description URL": return event.descriptionUrl ?? ""
        case "ImageURL": return event.eventImageUrl ?? ""
        case "ImageDate": return "" // SQLite doesn't store ImageDate separately
        default: return ""
        }
    }
    
    /// Check if events data is empty
    func isEmpty() -> Bool {
        return dataManager.fetchEvents(forYear: eventYear).isEmpty
    }
    
    /// Clear all cached event data for current year
    func clearCachedData() {
        let events = dataManager.fetchEvents(forYear: eventYear)
        for event in events {
            dataManager.deleteEvent(bandName: event.bandName, timeIndex: event.timeIndex, eventYear: eventYear)
        }
        print("🗑️ Cleared all event data from SQLite for year \(eventYear)")
    }
    
    /// Clean up orphaned bands that have no events (fake band entries)
    /// DISABLED: This function previously deleted bands without events, but that's incorrect behavior.
    /// Bands and events are separate entities - bands can legitimately exist without events.
    /// Fake bands (like "All Star Jam") are now filtered out in the UI display logic instead of being deleted.
    func cleanupOrphanedBands() {
        print("🧹 [CLEANUP] Orphaned band cleanup is DISABLED")
        print("🧹 [CLEANUP] Bands and events are separate entities - bands can exist without events")
        print("🧹 [CLEANUP] Fake bands are filtered in UI display logic, not deleted from database")
        // No-op: Do not delete bands based on event presence
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
    
    private func fetchEvents() -> [EventData] {
        return dataManager.fetchEvents(forYear: eventYear).sorted { $0.timeIndex < $1.timeIndex }
    }
    
    private func fetchEvent(bandName: String, timeIndex: TimeInterval) -> EventData? {
        let events = dataManager.fetchEventsForBand(bandName, forYear: eventYear)
        return events.first { $0.timeIndex == timeIndex }
    }
    
    /// Calculate unique time index for event (matches scheduleHandler logic)
    private func getDateIndex(_ dateString: String, timeString: String, band: String) -> TimeInterval {
        print("🕐 [MDF_DEBUG] getDateIndex called:")
        print("   dateString: '\(dateString)'")
        print("   timeString: '\(timeString)'")
        print("   band: '\(band)'")
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current
        
        let fullDateString = "\(dateString) \(timeString)"
        print("   fullDateString: '\(fullDateString)'")
        
        let primaryFormats = [
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd H:mm",
            "yyyy-M-d HH:mm",
            "M/d/yyyy HH:mm",
            "MM/dd/yyyy HH:mm",
        ]
        var parsedPrimary: Date?
        for fmt in primaryFormats {
            dateFormatter.dateFormat = fmt
            if let date = dateFormatter.date(from: fullDateString) {
                parsedPrimary = date
                print("   primary format matched: \(fmt)")
                break
            }
        }
        
        if let date = parsedPrimary {
            print("✅ [MDF_DEBUG] Date parsed successfully: \(date)")
            var timeIndex = date.timeIntervalSinceReferenceDate // FIX: Match ScheduleCSVImporter reference
            
            // Ensure uniqueness by checking existing events in SQLite
            while fetchEvent(bandName: band, timeIndex: timeIndex) != nil {
                timeIndex += 1
            }
            
            print("✅ [MDF_DEBUG] Final timeIndex: \(timeIndex)")
            return timeIndex
        } else {
            print("❌ [MDF_DEBUG] Date parsing FAILED!")
            print("❌ [MDF_DEBUG] Trying alternative formats...")
            
            // Try the scheduleHandler formats
            let alternativeFormats = [
                "yyyy-MM-dd HH:mm",
                "yyyy-MM-dd H:mm",
                "yyyy-MM-dd h:mm a",
                "yyyy-M-d HH:mm",
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

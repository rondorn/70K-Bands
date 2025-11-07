//
//  ScheduleCSVImporter.swift
//  70000TonsBands
//
//  Core Data-backed CSV importer for schedule/event data
//  Handles smart import with update/delete logic for schedule events
//

import Foundation
import CoreData

class ScheduleCSVImporter {
    
    private let coreDataManager = CoreDataManager.shared
    
    /// Imports schedule data from CSV string into Core Data (THREAD-SAFE)
    /// Uses smart import logic: updates existing events, adds new ones, removes obsolete ones
    /// - Parameter csvString: The CSV data as a string
    /// - Returns: True if import was successful, false otherwise
    func importEventsFromCSVString(_ csvString: String) -> Bool {
        // Perform import on background context to prevent threading issues
        return coreDataManager.performBackgroundTask { backgroundContext in
            return self.importEventsFromCSVStringSynchronous(csvString, context: backgroundContext)
        } ?? false
    }
    
    /// Synchronous import implementation that works with a specific context
    private func importEventsFromCSVStringSynchronous(_ csvString: String, context: NSManagedObjectContext) -> Bool {
        print("DEBUG_MARKER: Starting schedule CSV import to Core Data")
        print("DEBUG_MARKER: CSV data length: \(csvString.count) characters")
        
        // Test date parsing with example data first
        testDateParsing()
        
        guard !csvString.isEmpty else {
            print("DEBUG_MARKER: CSV string is empty, skipping import")
            return false
        }
        
        // CRITICAL DEBUG: Check if CSV contains unofficial events at the raw level
        print("🔧 [UNOFFICIAL_DEBUG] =============================================")
        print("🔧 [UNOFFICIAL_DEBUG] ANALYZING RAW CSV FOR UNOFFICIAL EVENTS...")
        let rawLines = csvString.components(separatedBy: .newlines)
        let unofficialLines = rawLines.filter { line in
            return line.contains("Unofficial Event") || line.contains("Cruiser Organized")
        }
        print("🔧 [UNOFFICIAL_DEBUG] 🚨 FOUND \(unofficialLines.count) lines with unofficial events in raw CSV")
        for (index, line) in unofficialLines.enumerated().prefix(5) {
            print("🔧 [UNOFFICIAL_DEBUG] - Raw CSV Line \(index + 1): \(line)")
        }
        print("🔧 [UNOFFICIAL_DEBUG] =============================================")
        
        if unofficialLines.count == 0 {
            print("🔧 [UNOFFICIAL_DEBUG] ❌ NO unofficial events found in raw CSV - this explains the missing events!")
            print("🔧 [UNOFFICIAL_DEBUG] CSV might not contain 2025 unofficial events or they have different type names")
        }
        
        // Parse CSV data
        var csvData: CSV
        do {
            csvData = try CSV(csvStringToParse: csvString)
            print("DEBUG_MARKER: Successfully parsed CSV with \(csvData.rows.count) rows")
        } catch {
            print("DEBUG_MARKER: Failed to parse CSV: \(error)")
            return false
        }
        
        // Check if CSV has valid headers
        let hasValidHeaders = csvString.contains("Band,Location,Date,Day,Start Time,End Time,Type")
        if !hasValidHeaders {
            print("DEBUG_MARKER: CSV doesn't have expected headers, but proceeding with import")
        }
        
        var importedEvents: Set<String> = []
        var successCount = 0
        var errorCount = 0
        var processedUnofficialCount = 0
        var skippedUnofficialCount = 0
        
        // Process each row
        for (rowIndex, lineData) in csvData.rows.enumerated() {
            // Check if this is an unofficial event row BEFORE processing
            let eventType = lineData[typeField] ?? ""
            let isUnofficialEvent = eventType == "Unofficial Event" || eventType == "Cruiser Organized"
            
            if isUnofficialEvent {
                print("🔧 [UNOFFICIAL_DEBUG] 📍 Found unofficial event in CSV row \(rowIndex + 1):")
                print("🔧 [UNOFFICIAL_DEBUG] - Raw eventType: '\(eventType)'")
                print("🔧 [UNOFFICIAL_DEBUG] - Band: '\(lineData[bandField] ?? "nil")'")
                print("🔧 [UNOFFICIAL_DEBUG] - Date: '\(lineData[dateField] ?? "nil")'")
                print("🔧 [UNOFFICIAL_DEBUG] - Start Time: '\(lineData[startTimeField] ?? "nil")'")
                print("🔧 [UNOFFICIAL_DEBUG] - About to process this row...")
                processedUnofficialCount += 1
            }
            
            if isUnofficialEvent {
                print("🔧 [UNOFFICIAL_DEBUG] ⚠️ Processing UNOFFICIAL event row...")
                print("🔧 [UNOFFICIAL_DEBUG] - Raw CSV fields:")
                print("🔧 [UNOFFICIAL_DEBUG]   - bandField (\(bandField)): '\(lineData[bandField] ?? "nil")'")
                print("🔧 [UNOFFICIAL_DEBUG]   - locationField (\(locationField)): '\(lineData[locationField] ?? "nil")'")
                print("🔧 [UNOFFICIAL_DEBUG]   - dateField (\(dateField)): '\(lineData[dateField] ?? "nil")'")
                print("🔧 [UNOFFICIAL_DEBUG]   - dayField (\(dayField)): '\(lineData[dayField] ?? "nil")'")
                print("🔧 [UNOFFICIAL_DEBUG]   - startTimeField (\(startTimeField)): '\(lineData[startTimeField] ?? "nil")'")
                print("🔧 [UNOFFICIAL_DEBUG]   - endTimeField (\(endTimeField)): '\(lineData[endTimeField] ?? "nil")'")
                print("🔧 [UNOFFICIAL_DEBUG]   - typeField (\(typeField)): '\(lineData[typeField] ?? "nil")'")
            }
            
            guard let bandName = lineData[bandField], !bandName.isEmpty,
                  let location = lineData[locationField],
                  let date = lineData[dateField],
                  let day = lineData[dayField],
                  let startTime = lineData[startTimeField],
                  let endTime = lineData[endTimeField],
                  let eventType = lineData[typeField] else {
                if isUnofficialEvent {
                    print("🔧 [UNOFFICIAL_DEBUG] ❌ UNOFFICIAL event FAILED guard conditions!")
                }
                print("DEBUG_MARKER: Skipping row with missing required fields")
                if isUnofficialEvent {
                    print("🔧 [UNOFFICIAL_DEBUG] ❌ UNOFFICIAL event SKIPPED due to missing required fields!")
                    skippedUnofficialCount += 1
                }
                errorCount += 1
                continue
            }
            
            if isUnofficialEvent {
                print("🔧 [UNOFFICIAL_DEBUG] ✅ UNOFFICIAL event PASSED guard conditions")
                print("🔧 [UNOFFICIAL_DEBUG] - bandName: '\(bandName)'")
                print("🔧 [UNOFFICIAL_DEBUG] - location: '\(location)'")
                print("🔧 [UNOFFICIAL_DEBUG] - date: '\(date)'")
                print("🔧 [UNOFFICIAL_DEBUG] - eventType: '\(eventType)'")
            }
            
            // Calculate start and end time indices from date + time strings
            let startTimeIndex = getDateIndex(date, timeString: startTime, band: bandName)
            let endTimeIndex = getDateIndex(date, timeString: endTime, band: bandName)
            
            print("🔍 [TIMEINDEX_DEBUG] Band '\(bandName)': startTimeIndex=\(startTimeIndex), endTimeIndex=\(endTimeIndex)")
            
            if eventType == "Show" {
                print("🔍 [SHOW_EVENT_DEBUG] ✅ IMPORTING Show event: '\(bandName)' at '\(location)' - timeIndex: \(startTimeIndex)")
            }
            
            if isUnofficialEvent {
                print("🔧 [UNOFFICIAL_DEBUG] ⏰ UNOFFICIAL event time indices:")
                print("🔧 [UNOFFICIAL_DEBUG] - startTimeIndex: \(startTimeIndex)")
                print("🔧 [UNOFFICIAL_DEBUG] - endTimeIndex: \(endTimeIndex)")
                print("🔧 [UNOFFICIAL_DEBUG] - date: '\(date)', startTime: '\(startTime)', endTime: '\(endTime)'")
            }
            
            // CRITICAL: Skip events with invalid timeIndex (date parsing failed)
            if startTimeIndex == -1 || endTimeIndex == -1 {
                if isUnofficialEvent {
                    print("🔧 [UNOFFICIAL_DEBUG] ❌ UNOFFICIAL event REJECTED due to invalid timeIndex!")
                    print("🔧 [UNOFFICIAL_DEBUG] - startTimeIndex: \(startTimeIndex), endTimeIndex: \(endTimeIndex)")
                    print("🔧 [UNOFFICIAL_DEBUG] - This means date parsing FAILED for this unofficial event")
                    skippedUnofficialCount += 1
                }
                print("🚨 [TIMEINDEX_AUDIT] SKIPPING event for '\(bandName)' due to invalid timeIndex")
                print("🚨 [TIMEINDEX_AUDIT] Raw data: date='\(date)', startTime='\(startTime)', endTime='\(endTime)'")
                continue
            }
            
            // Validate that timeIndex is reasonable (only check for invalid/zero values)
            // REMOVED: Year range validation per user requirement - events should not be filtered by actual date
            if startTimeIndex <= 0 {
                if isUnofficialEvent {
                    print("🔧 [UNOFFICIAL_DEBUG] ❌ UNOFFICIAL event REJECTED due to invalid timeIndex!")
                    print("🔧 [UNOFFICIAL_DEBUG] - timeIndex: \(startTimeIndex)")
                    skippedUnofficialCount += 1
                }
                print("🚨 [TIMEINDEX_AUDIT] SKIPPING event for '\(bandName)' - invalid timeIndex: \(startTimeIndex)")
                continue
            }
            
            // [MDF_DEBUG] Event ACCEPTED - no year range filtering per user requirement
            print("✅ [MDF_DEBUG] Event ACCEPTED for '\(bandName)' - timeIndex: \(startTimeIndex)")
            
            // Create unique identifier for this event
            let eventId = "\(bandName)_\(startTimeIndex)"
            importedEvents.insert(eventId)
            
            // Find or create the band using the passed context
            let band = createOrUpdateBand(name: bandName, context: context)
            
            // Debug Show events specifically
            if eventType == "Show" {
                print("🔍 [SHOW_EVENT_DEBUG] 🎯 CREATING Show event:")
                print("🔍 [SHOW_EVENT_DEBUG] - bandName: '\(bandName)'")
                print("🔍 [SHOW_EVENT_DEBUG] - band object: \(band)")
                print("🔍 [SHOW_EVENT_DEBUG] - band.bandName: '\(band.bandName ?? "nil")'")
                print("🔍 [SHOW_EVENT_DEBUG] - timeIndex: \(startTimeIndex)")
                print("🔍 [SHOW_EVENT_DEBUG] - location: '\(location)'")
            }
            
            if isUnofficialEvent {
                print("🔧 [UNOFFICIAL_DEBUG] 🎯 CREATING UNOFFICIAL event:")
                print("🔧 [UNOFFICIAL_DEBUG] - bandName: '\(bandName)'")
                print("🔧 [UNOFFICIAL_DEBUG] - band object: \(band)")
                print("🔧 [UNOFFICIAL_DEBUG] - band.bandName: '\(band.bandName ?? "nil")'")
                print("🔧 [UNOFFICIAL_DEBUG] - timeIndex: \(startTimeIndex)")
                print("🔧 [UNOFFICIAL_DEBUG] - location: '\(location)'")
                print("🔧 [UNOFFICIAL_DEBUG] - eventType: '\(eventType)'")
                print("🔧 [UNOFFICIAL_DEBUG] - 🚨 CRITICAL: eventYear being used for import: \(eventYear)")
                print("🔧 [UNOFFICIAL_DEBUG] - About to call createOrUpdateEvent...")
            }
            
            // Get ImageDate from CSV (trim whitespace, use nil if empty)
            let imageDateFromCSV = lineData[imageUrlDateField] ?? ""
            let trimmedImageDate = imageDateFromCSV.trimmingCharacters(in: .whitespacesAndNewlines)
            let eventImageDate = trimmedImageDate.isEmpty ? nil : trimmedImageDate
            
            // DEBUG: Log ImageDate parsing for events with ImageURL
            if let imageUrl = lineData[imageUrlField], !imageUrl.isEmpty {
                if !trimmedImageDate.isEmpty {
                    print("📅 [CSV_IMPORT] Parsed ImageDate '\(trimmedImageDate)' for band '\(bandName)' with ImageURL: \(imageUrl)")
                } else {
                    print("⚠️ [CSV_IMPORT] Band '\(bandName)' has ImageURL but ImageDate is empty or missing")
                }
            }
            
            // Find existing event or create new one with calculated time indices
            let event = createOrUpdateEvent(context: context,
                band: band,
                timeIndex: startTimeIndex,
                endTimeIndex: endTimeIndex,
                location: location,
                date: date,
                day: day,
                startTime: startTime,
                endTime: endTime,
                eventType: eventType,
                eventYear: Int32(eventYear),
                notes: lineData[notesField],
                descriptionUrl: lineData[descriptionUrlField],
                eventImageUrl: lineData[imageUrlField],
                eventImageDate: eventImageDate
            )
            
            // Debug Show events after creation
            if eventType == "Show" {
                print("🔍 [SHOW_EVENT_DEBUG] ✅ CREATED Show event:")
                print("🔍 [SHOW_EVENT_DEBUG] - event.band: \(event.band?.description ?? "nil")")
                print("🔍 [SHOW_EVENT_DEBUG] - event.band?.bandName: '\(event.band?.bandName ?? "nil")'")
                print("🔍 [SHOW_EVENT_DEBUG] - event.eventType: '\(event.eventType ?? "nil")'")
                print("🔍 [SHOW_EVENT_DEBUG] - event.identifier: '\(event.identifier ?? "nil")'")
            }
            
            if isUnofficialEvent {
                print("🔧 [UNOFFICIAL_DEBUG] ✅ CREATED UNOFFICIAL event:")
                print("🔧 [UNOFFICIAL_DEBUG] - event.band: \(event.band?.description ?? "nil")")
                print("🔧 [UNOFFICIAL_DEBUG] - event.band?.bandName: '\(event.band?.bandName ?? "nil")'")
                print("🔧 [UNOFFICIAL_DEBUG] - event.eventType: '\(event.eventType ?? "nil")'")
                print("🔧 [UNOFFICIAL_DEBUG] - event.eventYear: \(event.eventYear)")
                print("🔧 [UNOFFICIAL_DEBUG] - event.timeIndex: \(event.timeIndex)")
                print("🔧 [UNOFFICIAL_DEBUG] - event.location: '\(event.location ?? "nil")'")
                print("🔧 [UNOFFICIAL_DEBUG] - Successfully imported unofficial event to Core Data!")
            }
            
            successCount += 1
        }
        
        print("DEBUG_MARKER: Processed \(csvData.rows.count) CSV rows: \(successCount) successful, \(errorCount) errors")
        
        // Summary debug for unofficial events
        print("🔧 [UNOFFICIAL_DEBUG] ===== UNOFFICIAL EVENT IMPORT SUMMARY =====")
        let allEvents = fetchEvents(forYear: Int32(eventYear), context: context)
        let unofficialEventsInDB = allEvents.filter { event in
            let type = event.eventType ?? ""
            return type == "Unofficial Event" || type == "Cruiser Organized"
        }
        print("🔧 [UNOFFICIAL_DEBUG] Total events in Core Data for year \(eventYear): \(allEvents.count)")
        print("🔧 [UNOFFICIAL_DEBUG] Unofficial events in Core Data for year \(eventYear): \(unofficialEventsInDB.count)")
        if unofficialEventsInDB.count > 0 {
            for event in unofficialEventsInDB.prefix(3) {
                print("🔧 [UNOFFICIAL_DEBUG] - '\(event.band?.bandName ?? "nil")' type: '\(event.eventType ?? "nil")' location: '\(event.location ?? "nil")'")
            }
        }
        print("🔧 [UNOFFICIAL_DEBUG] =============================================")
        print("🔧 [UNOFFICIAL_DEBUG] 📊 CSV IMPORT SUMMARY:")
        print("🔧 [UNOFFICIAL_DEBUG] - Unofficial events found in raw CSV: \(unofficialLines.count)")
        print("🔧 [UNOFFICIAL_DEBUG] - Unofficial events processed during import: \(processedUnofficialCount)")
        print("🔧 [UNOFFICIAL_DEBUG] - Unofficial events skipped during import: \(skippedUnofficialCount)")
        print("🔧 [UNOFFICIAL_DEBUG] - Total successful imports: \(successCount)")
        print("🔧 [UNOFFICIAL_DEBUG] - Total failed imports: \(errorCount)")
        print("🔧 [UNOFFICIAL_DEBUG] =============================================")
        
        // DELETION LOGIC: Remove events from current year that are not in the downloaded CSV
        print("🗑️ [DELETION_DEBUG] ========== STARTING EVENT DELETION ANALYSIS ==========")
        let currentEvents = fetchEvents(forYear: Int32(eventYear), context: context)
        var deletedCount = 0
        
        print("🗑️ [DELETION_DEBUG] Current year: \(eventYear)")
        print("🗑️ [DELETION_DEBUG] Events currently in Core Data for \(eventYear): \(currentEvents.count)")
        print("🗑️ [DELETION_DEBUG] Events imported from CSV: \(importedEvents.count)")
        print("🗑️ [DELETION_DEBUG] Imported event identifiers: \(importedEvents.sorted())")
        
        // Check each existing event to see if it was in the CSV
        for event in currentEvents {
            guard let band = event.band, let bandName = band.bandName else {
                print("🗑️ [DELETION_DEBUG] ⚠️ Skipping event with no band: \(event)")
                continue
            }
            
            let eventId = "\(bandName)_\(event.timeIndex)"
            let eventType = event.eventType ?? "unknown"
            
            if !importedEvents.contains(eventId) {
                print("🗑️ [DELETION_DEBUG] 🚨 REMOVING event not found in CSV:")
                print("🗑️ [DELETION_DEBUG] - Event ID: \(eventId)")
                print("🗑️ [DELETION_DEBUG] - Band: '\(bandName)'")
                print("🗑️ [DELETION_DEBUG] - Type: '\(eventType)'")
                print("🗑️ [DELETION_DEBUG] - Year: \(event.eventYear)")
                print("🗑️ [DELETION_DEBUG] - TimeIndex: \(event.timeIndex)")
                print("🗑️ [DELETION_DEBUG] - Location: '\(event.location ?? "nil")'")
                print("🗑️ [DELETION_DEBUG] - Date: '\(event.date ?? "nil")'")
                
                // Show why it wasn't found in imported events
                let similarIds = importedEvents.filter { $0.contains(bandName) }
                if similarIds.isEmpty {
                    print("🗑️ [DELETION_DEBUG] - No similar band names found in CSV import")
                } else {
                    print("🗑️ [DELETION_DEBUG] - Similar band names in CSV: \(similarIds)")
                }
                
                context.delete(event)
                deletedCount += 1
            } else {
                print("🗑️ [DELETION_DEBUG] ✅ KEEPING event found in CSV: \(eventId) (type: \(eventType))")
            }
        }
        
        print("🗑️ [DELETION_DEBUG] ========== DELETION ANALYSIS COMPLETE ==========")
        print("🗑️ [DELETION_DEBUG] Total events deleted: \(deletedCount)")
        
        // Save changes (handled by performBackgroundTask)
        
        print("DEBUG_MARKER: Schedule import completed - Added/Updated: \(successCount), Deleted: \(deletedCount)")
        
        return errorCount == 0
    }
    
    /// Helper function to calculate date index (same logic as original scheduleHandler)
    private func getDateIndex(_ dateString: String, timeString: String, band: String) -> TimeInterval {
        let fullTimeString: String = dateString + " " + timeString
        
        print("🔍 [TIMEINDEX_DEBUG] Parsing date for band '\(band)':")
        print("🔍 [TIMEINDEX_DEBUG] - dateString: '\(dateString)'")
        print("🔍 [TIMEINDEX_DEBUG] - timeString: '\(timeString)'")
        print("🔍 [TIMEINDEX_DEBUG] - fullTimeString: '\(fullTimeString)'")
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        // PRIMARY FORMAT: Based on actual CSV format analysis
        // Show events: "1/30/2025 17:15" (M/d/yyyy H:mm - note single digit hour!)
        // Unofficial events: "01/30/2025 18:00" (MM/dd/yyyy HH:mm)
        let primaryFormats = [
            "M/d/yyyy H:mm",          // Show events format: single digit month/day + single digit hour (CRITICAL!)
            "MM/dd/yyyy H:mm",        // Unofficial events with single digit hour
            "M/d/yyyy HH:mm",         // Single digit month/day + padded hour
            "MM/dd/yyyy HH:mm"        // Double digit + padded hour
        ]
        
        for format in primaryFormats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: fullTimeString) {
                let timeInterval = date.timeIntervalSince1970
                print("🔍 [TIMEINDEX_DEBUG] ✅ Primary format '\(format)' worked: \(date) -> timeInterval: \(timeInterval)")
                return timeInterval
            }
        }
        
        print("🔍 [TIMEINDEX_DEBUG] ❌ Primary formats failed, trying fallback formats")
        
        // FALLBACK FORMATS: For compatibility with other possible formats
        let fallbackFormats = [
            "M/d/yyyy h:mm a",        // 12-hour with AM/PM
            "MM/dd/yyyy h:mm a",      // 12-hour with AM/PM (padded)
            "yyyy-MM-dd HH:mm",       // ISO-like format
            "MM/dd/yyyy h:mma",       // No space before AM/PM
            "M/d/yyyy h:mma"          // Single digit + no space
        ]
        
        for format in fallbackFormats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: fullTimeString) {
                let timeInterval = date.timeIntervalSince1970
                print("🔍 [TIMEINDEX_DEBUG] ✅ Fallback format '\(format)' worked: \(date) -> timeInterval: \(timeInterval)")
                return timeInterval
            }
        }
        
        print("🔍 [TIMEINDEX_DEBUG] ❌ All date formats failed for '\(fullTimeString)'")
        print("🚨 [TIMEINDEX_AUDIT] CRITICAL: Date parsing failed, this event will be SKIPPED")
        print("🚨 [TIMEINDEX_AUDIT] Expected Show event format: 'M/d/yyyy H:mm' (e.g., '1/30/2025 17:15')")
        print("🚨 [TIMEINDEX_AUDIT] Expected Unofficial event format: 'MM/dd/yyyy H:mm' (e.g., '01/30/2025 18:00')")
        // Return a sentinel value that can be detected and handled
        return -1
    }
    
    /// Test function to verify date parsing works with example CSV data
    private func testDateParsing() {
        print("🧪 [DATE_PARSING_TEST] Testing with example CSV data")
        
        // Test with actual Show event format from CSV
        let testDate = "1/30/2025"
        let testStartTime = "17:15"  // Show events use single digit hour format
        let testEndTime = "18:00"
        
        let startTimeIndex = getDateIndex(testDate, timeString: testStartTime, band: "Onslaught")
        let endTimeIndex = getDateIndex(testDate, timeString: testEndTime, band: "Onslaught")
        
        if startTimeIndex > 0 && endTimeIndex > 0 {
            let startDate = Date(timeIntervalSince1970: startTimeIndex)
            let endDate = Date(timeIntervalSince1970: endTimeIndex)
            print("🧪 [DATE_PARSING_TEST] ✅ SUCCESS!")
            print("🧪 [DATE_PARSING_TEST] Start: \(startDate) (\(startTimeIndex))")
            print("🧪 [DATE_PARSING_TEST] End: \(endDate) (\(endTimeIndex))")
        } else {
            print("🧪 [DATE_PARSING_TEST] ❌ FAILED!")
            print("🧪 [DATE_PARSING_TEST] startTimeIndex: \(startTimeIndex)")
            print("🧪 [DATE_PARSING_TEST] endTimeIndex: \(endTimeIndex)")
        }
        
        // Also test with Unofficial Event format for comparison
        print("🧪 [DATE_PARSING_TEST] Testing Unofficial Event format")
        let unofficialDate = "01/30/2025"
        let unofficialTime = "18:00"
        
        let unofficialTimeIndex = getDateIndex(unofficialDate, timeString: unofficialTime, band: "TestEvent")
        if unofficialTimeIndex > 0 {
            let unofficialDateObj = Date(timeIntervalSince1970: unofficialTimeIndex)
            print("🧪 [DATE_PARSING_TEST] ✅ Unofficial format SUCCESS: \(unofficialDateObj)")
        } else {
            print("🧪 [DATE_PARSING_TEST] ❌ Unofficial format FAILED")
        }
    }
    
    // MARK: - Helper Methods for Thread-Safe Context Operations
    
    private func createOrUpdateBand(name: String, context: NSManagedObjectContext) -> Band {
        // Try to find existing band first using name and year
        let request: NSFetchRequest<Band> = Band.fetchRequest()
        request.predicate = NSPredicate(format: "bandName == %@ AND eventYear == %d", name, Int32(eventYear))
        request.fetchLimit = 1
        
        do {
            let existingBand = try context.fetch(request).first
            let band = existingBand ?? Band(context: context)
            
            // Update fields
            band.bandName = name
            band.eventYear = Int32(eventYear)
            
            return band
        } catch {
            print("Error finding/creating band: \(error)")
            // Fallback to creating new band
            let band = Band(context: context)
            band.bandName = name
            band.eventYear = Int32(eventYear)
            return band
        }
    }
    
    private func createOrUpdateEvent(
        context: NSManagedObjectContext,
        band: Band,
        timeIndex: TimeInterval,
        endTimeIndex: TimeInterval?,
        location: String,
        date: String?,
        day: String?,
        startTime: String?,
        endTime: String?,
        eventType: String?,
        eventYear: Int32?,
        notes: String?,
        descriptionUrl: String?,
        eventImageUrl: String?,
        eventImageDate: String?
    ) -> Event {
        // Try to find existing event using bandName and timeIndex (more reliable than object comparison)
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "band.bandName == %@ AND timeIndex == %lf AND eventYear == %d", band.bandName ?? "", timeIndex, eventYear ?? Int32(0))
        request.fetchLimit = 1
        
        do {
            let existingEvent = try context.fetch(request).first
            let event = existingEvent ?? Event(context: context)
            
            // Update all fields
            event.band = band
            event.timeIndex = timeIndex
            event.endTimeIndex = endTimeIndex ?? 0
            event.location = location
            event.date = date
            event.day = day
            event.startTime = startTime
            event.endTime = endTime
            event.eventType = eventType
            event.eventYear = eventYear ?? Int32(0)
            event.notes = notes
            event.descriptionUrl = descriptionUrl
            event.eventImageUrl = eventImageUrl
            event.eventImageDate = eventImageDate
            
            return event
        } catch {
            print("Create or update event error: \(error)")
            // Fallback to creating new event
            let event = Event(context: context)
            event.band = band
            event.timeIndex = timeIndex
            event.endTimeIndex = endTimeIndex ?? 0
            event.location = location
            event.date = date
            event.day = day
            event.startTime = startTime
            event.endTime = endTime
            event.eventType = eventType
            event.eventYear = eventYear ?? Int32(0)
            event.notes = notes
            event.descriptionUrl = descriptionUrl
            event.eventImageUrl = eventImageUrl
            event.eventImageDate = eventImageDate
            return event
        }
    }
    
    private func fetchEvents(forYear year: Int32, context: NSManagedObjectContext) -> [Event] {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "eventYear == %d", year)
        do {
            return try context.fetch(request)
        } catch {
            print("Fetch events for year error: \(error)")
            return []
        }
    }
}

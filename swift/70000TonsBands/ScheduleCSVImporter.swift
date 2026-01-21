//
//  ScheduleCSVImporter.swift
//  70000TonsBands
//
//  SQLite-only CSV importer for schedule/event data
//  NO Core Data - uses DataManager (SQLite) exclusively
//

import Foundation

class ScheduleCSVImporter {
    
    private let dataManager = DataManager.shared
    
    /// Imports schedule data from CSV string into SQLite
    /// Uses smart import logic: updates existing events, adds new ones
    /// - Parameter csvString: The CSV data as a string
    /// - Returns: True if import was successful, false otherwise
    func importEventsFromCSVString(_ csvString: String) -> Bool {
        print("DEBUG_MARKER: Starting schedule CSV import to SQLite (NO Core Data)")
        print("DEBUG_MARKER: CSV data length: \(csvString.count) characters")
        
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
        
        // Parse CSV
        guard let csvData = try? CSV(csvStringToParse: csvString) else {
            print("DEBUG_MARKER: Failed to parse CSV")
            return false
        }
        
        print("DEBUG_MARKER: CSV parsed successfully, found \(csvData.rows.count) rows")
        print("🔍 [CSV_HEADERS_DEBUG] CSV headers: \(csvData.headers)")
        print("🔍 [CSV_FIELDS_DEBUG] Looking for fields:")
        print("  - bandField: '\(bandField)'")
        print("  - locationField: '\(locationField)'")
        print("  - dateField: '\(dateField)'")
        print("  - startTimeField: '\(startTimeField)'")
        print("  - endTimeField: '\(endTimeField)'")
        print("  - typeField: '\(typeField)'")
        
        // SAFETY CHECK: Validate CSV has reasonable number of rows before deleting anything
        // A typical event schedule should have at least 50+ events
        // If CSV has fewer than 10 rows, it's likely corrupt/incomplete - keep existing data
        if csvData.rows.count < 10 {
            print("⚠️ [EVENT_SAFETY] CSV has only \(csvData.rows.count) rows - likely corrupt or incomplete")
            print("⚠️ [EVENT_SAFETY] Import ABORTED - keeping existing database data to prevent data loss")
            return false
        }
        
        // STEP 1: DELETE ALL old events for this year (CSV validation passed)
        // This ensures test data doesn't persist when production data is downloaded
        print("🗑️ [EVENT_CLEANUP] STEP 1: Deleting ALL old events for year \(eventYear)")
        let existingEvents = dataManager.fetchEvents(forYear: eventYear)
        print("🗑️ [EVENT_CLEANUP] Found \(existingEvents.count) existing events to delete")
        
        for event in existingEvents {
            dataManager.deleteEvent(bandName: event.bandName, timeIndex: event.timeIndex, eventYear: eventYear)
        }
        print("🗑️ [EVENT_CLEANUP] Deleted \(existingEvents.count) old events for year \(eventYear)")
        
        // STEP 2: Import new events from CSV
        print("🚀 [EVENT_IMPORT] STEP 2: Importing \(csvData.rows.count) events from CSV")
        
        var successCount = 0
        var errorCount = 0
        var skippedUnofficialCount = 0
        
        // CSV rows are dictionaries with string keys matching the header names
        for (rowIndex, lineData) in csvData.rows.enumerated() {
            guard let bandName = lineData[bandField],
                  let location = lineData[locationField],
                  let date = lineData[dateField],
                  let day = lineData[dayField],
                  let startTime = lineData[startTimeField],
                  let endTime = lineData[endTimeField],
                  let eventType = lineData[typeField] else {
                print("DEBUG_MARKER: Skipping row with missing required fields")
                errorCount += 1
                continue
            }
            
            // Check if this is an unofficial event
            let isUnofficialEvent = (eventType == "Unofficial Event" || eventType == "Cruiser Organized")
            
            if isUnofficialEvent || rowIndex < 3 {
                print("🔍 [CSV_ROW_DEBUG] Row \(rowIndex + 1):")
                print("  - bandName: '\(bandName)'")
                print("  - location: '\(location)'")
                print("  - date: '\(date)'")
                print("  - day: '\(day)'")
                print("  - startTime: '\(startTime)'")
                print("  - endTime: '\(endTime)'")
                print("  - eventType: '\(eventType)'")
            }
            
            // Calculate time indices
            let startTimeIndex = calculateTimeIndex(date: date, time: startTime)
            let endTimeIndex = calculateTimeIndex(date: date, time: endTime)
            
            // CRITICAL: Skip events with invalid timeIndex
            if startTimeIndex == -1 || endTimeIndex == -1 || startTimeIndex <= 0 {
                if isUnofficialEvent {
                    print("🔧 [UNOFFICIAL_DEBUG] ❌ UNOFFICIAL event REJECTED due to invalid timeIndex!")
                    skippedUnofficialCount += 1
                }
                continue
            }
            
            // Ensure band exists in SQLite WITHOUT overwriting existing data
            // This won't destroy imageUrl and other metadata from the bands CSV import
            _ = dataManager.createBandIfNotExists(name: bandName, eventYear: eventYear)
            
            // Create event in SQLite
            _ = dataManager.createOrUpdateEvent(
                bandName: bandName,
                timeIndex: startTimeIndex,
                endTimeIndex: endTimeIndex,
                location: location,
                date: date,
                day: day,
                startTime: startTime,
                endTime: endTime,
                eventType: eventType,
                eventYear: eventYear,
                notes: lineData[notesField],
                descriptionUrl: lineData[descriptionUrlField],
                eventImageUrl: lineData[imageUrlField]
            )
            
            if isUnofficialEvent {
                print("🔧 [UNOFFICIAL_DEBUG] ✅ Imported unofficial event to SQLite: '\(bandName)' at '\(location)'")
            }
            
            successCount += 1
        }
        
        print("DEBUG_MARKER: Processed \(csvData.rows.count) CSV rows: \(successCount) successful, \(errorCount) errors")
        print("🔧 [UNOFFICIAL_DEBUG] Skipped \(skippedUnofficialCount) unofficial events due to invalid timeIndex")
        
        // Verify events were written to SQLite
        let eventsInSQLite = dataManager.fetchEvents(forYear: eventYear)
        print("✅ [SQLITE_FIX] Total events in SQLite for year \(eventYear): \(eventsInSQLite.count)")
        
        let unofficialEventsInSQLite = eventsInSQLite.filter { event in
            let type = event.eventType ?? ""
            return type == "Unofficial Event" || type == "Cruiser Organized"
        }
        print("✅ [SQLITE_FIX] Unofficial events in SQLite for year \(eventYear): \(unofficialEventsInSQLite.count)")
        
        return successCount > 0
    }
    
    // MARK: - Time Index Calculation
    
    private func calculateTimeIndex(date: String, time: String) -> Double {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current // FIX: Use device's local timezone, no shifting
        
        let dateTimeString = "\(date) \(time)"
        
        print("🔍 [DATE_PARSE_DEBUG] Attempting to parse: '\(dateTimeString)' in timezone \(TimeZone.current.identifier)")
        print("🔍 [DATE_PARSE_DEBUG] - Date component: '\(date)'")
        print("🔍 [DATE_PARSE_DEBUG] - Time component: '\(time)'")
        
        // Try multiple date formats to handle different CSV formats
        let formats = [
            "M/d/yyyy HH:mm",      // Single digit month/day + 24-hour (e.g., "1/26/2026 15:00")
            "MM/dd/yyyy HH:mm",    // Padded + 24-hour (e.g., "01/26/2026 15:00")
            "M/d/yyyy H:mm",       // Single digit month/day/hour (e.g., "1/30/2025 17:15")
            "MM/dd/yyyy H:mm",     // Padded date + single digit hour
            "M/d/yyyy h:mm a",     // 12-hour with AM/PM
            "MM/dd/yyyy h:mm a",   // Padded + 12-hour with AM/PM
        ]
        
        for (index, format) in formats.enumerated() {
            formatter.dateFormat = format
            if let parsedDate = formatter.date(from: dateTimeString) {
                let timeIndex = parsedDate.timeIntervalSinceReferenceDate
                print("✅ [DATE_PARSE_SUCCESS] Format \(index + 1) worked: '\(format)' -> timeIndex: \(timeIndex)")
                return timeIndex
            }
        }
        
        print("❌ [DATE_PARSE_ERROR] Failed to parse: '\(dateTimeString)'")
        print("❌ [DATE_PARSE_ERROR] Tried all \(formats.count) formats but none matched")
        return -1
    }
}


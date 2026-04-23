//
//  ScheduleCSVImporter.swift
//  70000TonsBands
//
//  SQLite-only CSV importer for schedule/event data
//  NO Core Data - uses DataManager (SQLite) exclusively
//  Band table: only ensures a band row exists (createBandIfNotExists). Never sets or changes lineIndex; that is only set when the full band list is imported (BandCSVImporter).
//

import Foundation

class ScheduleCSVImporter {
    
    private let dataManager = DataManager.shared
    
    /// Imports schedule data from CSV string into SQLite (atomic replace with retry on DB lock).
    /// - Returns: (success, importedCount). Only store checksum when success and DB event count equals importedCount.
    func importEventsFromCSVString(_ csvString: String) -> (success: Bool, importedCount: Int) {
        print("DEBUG_MARKER: Starting schedule CSV import to SQLite (NO Core Data)")
        print("DEBUG_MARKER: CSV data length: \(csvString.count) characters")
        
        guard !csvString.isEmpty else {
            print("DEBUG_MARKER: CSV string is empty, skipping import")
            return (false, 0)
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
            return (false, 0)
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
        
        // VALIDATION: Abort only if required headers are missing (malformed or wrong format)
        // Empty or small CSVs with valid headers are valid (e.g. test schedules) - proceed as normal
        let requiredHeaders = Set([bandField, locationField, dateField, dayField, startTimeField, endTimeField, typeField])
        let headerSet = Set(csvData.headers.map { $0.trimmingCharacters(in: .whitespaces) })
        guard requiredHeaders.isSubset(of: headerSet) else {
            print("⚠️ [EVENT_VALIDATION] CSV missing required headers - aborting import")
            return (false, 0)
        }
        
        // Build event list from CSV (same validation and time-index logic). Then replace all events for this year in one atomic transaction with retry on DB lock.
        print("🚀 [EVENT_IMPORT] Building \(csvData.rows.count) events from CSV for atomic replace")
        var eventsToImport: [EventData] = []
        var errorCount = 0
        var skippedUnofficialCount = 0
        
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
            
            let isUnofficialEvent = (eventType == "Unofficial Event" || eventType == "Cruiser Organized")
            if isUnofficialEvent || rowIndex < 3 {
                print("🔍 [CSV_ROW_DEBUG] Row \(rowIndex + 1): bandName: '\(bandName)', location: '\(location)', eventType: '\(eventType)'")
            }
            
            let dateForIndex = date
            let normalizedStoredDate = ScheduleDateNormalization.canonicalStorageCalendarDate(from: date) ?? date

            let startTimeIndex = calculateTimeIndex(date: dateForIndex, time: startTime)
            let endTimeIndex = calculateTimeIndex(date: dateForIndex, time: endTime)
            if startTimeIndex == -1 || endTimeIndex == -1 || startTimeIndex <= 0 {
                if isUnofficialEvent { skippedUnofficialCount += 1 }
                continue
            }
            
            let event = EventData(
                bandName: bandName,
                eventYear: eventYear,
                timeIndex: startTimeIndex,
                endTimeIndex: endTimeIndex,
                location: location,
                date: normalizedStoredDate,
                day: day,
                startTime: startTime,
                endTime: endTime,
                eventType: eventType,
                notes: lineData[notesField],
                descriptionUrl: lineData[descriptionUrlField],
                eventImageUrl: lineData[imageUrlField]
            )
            eventsToImport.append(event)
        }
        
        print("DEBUG_MARKER: Processed \(csvData.rows.count) CSV rows: \(eventsToImport.count) valid, \(errorCount) errors. Skipped \(skippedUnofficialCount) unofficial (invalid timeIndex).")
        
        // Atomic replace: delete all events for year, insert new list. Single transaction with retry on "database is locked". Returns false if DB write failed so caller does not store checksum.
        let replaced = dataManager.replaceEvents(forYear: eventYear, events: eventsToImport)
        if !replaced {
            print("❌ [EVENT_IMPORT] replaceEvents failed (e.g. database locked) — DB unchanged; do not store checksum")
            return (false, 0)
        }
        
        let eventsInSQLite = dataManager.fetchEvents(forYear: eventYear)
        print("✅ [SQLITE_FIX] Total events in SQLite for year \(eventYear): \(eventsInSQLite.count)")
        let unofficialInDb = eventsInSQLite.filter { ($0.eventType ?? "").contains("Unofficial") || ($0.eventType ?? "").contains("Cruiser") }
        print("✅ [SQLITE_FIX] Unofficial events in SQLite for year \(eventYear): \(unofficialInDb.count)")
        return (true, eventsToImport.count)
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
        
        // Try multiple date formats to handle different CSV formats and canonical yyyy-MM-dd storage
        let formats = [
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd H:mm",
            "yyyy-MM-dd h:mm a",
            "yyyy-M-d HH:mm",
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


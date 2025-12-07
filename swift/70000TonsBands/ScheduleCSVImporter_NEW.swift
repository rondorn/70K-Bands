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
        guard let csvData = try? CSV(string: csvString) else {
            print("DEBUG_MARKER: Failed to parse CSV")
            return false
        }
        
        print("DEBUG_MARKER: CSV parsed successfully, found \(csvData.rows.count) rows")
        
        // Get field indices
        guard let bandNameField = csvData.header.firstIndex(of: "Name"),
              let locationField = csvData.header.firstIndex(of: "Location"),
              let dateField = csvData.header.firstIndex(of: "Date"),
              let dayField = csvData.header.firstIndex(of: "Day"),
              let startTimeField = csvData.header.firstIndex(of: "StartTime"),
              let endTimeField = csvData.header.firstIndex(of: "EndTime"),
              let eventTypeField = csvData.header.firstIndex(of: "EventType") else {
            print("DEBUG_MARKER: Required CSV columns not found")
            return false
        }
        
        let notesField = csvData.header.firstIndex(of: "Notes")
        let descriptionUrlField = csvData.header.firstIndex(of: "DescriptionURL")
        let imageUrlField = csvData.header.firstIndex(of: "ImageURL")
        
        var successCount = 0
        var errorCount = 0
        var skippedUnofficialCount = 0
        
        for lineData in csvData.rows {
            guard lineData.count > max(bandNameField, locationField, dateField, dayField, startTimeField, endTimeField, eventTypeField) else {
                print("DEBUG_MARKER: Skipping malformed row")
                errorCount += 1
                continue
            }
            
            let bandName = lineData[bandNameField]
            let location = lineData[locationField]
            let date = lineData[dateField]
            let day = lineData[dayField]
            let startTime = lineData[startTimeField]
            let endTime = lineData[endTimeField]
            let eventType = lineData[eventTypeField]
            
            // Check if this is an unofficial event
            let isUnofficialEvent = (eventType == "Unofficial Event" || eventType == "Cruiser Organized")
            
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
            
            // Ensure band exists in SQLite
            _ = dataManager.createOrUpdateBand(
                name: bandName,
                eventYear: eventYear,
                officialSite: nil,
                imageUrl: nil,
                youtube: nil,
                metalArchives: nil,
                wikipedia: nil,
                country: nil,
                genre: nil,
                noteworthy: nil,
                priorYears: nil
            )
            
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
                notes: notesField != nil ? lineData[notesField!] : nil,
                descriptionUrl: descriptionUrlField != nil ? lineData[descriptionUrlField!] : nil,
                eventImageUrl: imageUrlField != nil ? lineData[imageUrlField!] : nil
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
        formatter.dateFormat = "M/d/yyyy h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        
        let dateTimeString = "\(date) \(time)"
        guard let parsedDate = formatter.date(from: dateTimeString) else {
            return -1
        }
        
        return parsedDate.timeIntervalSinceReferenceDate
    }
}



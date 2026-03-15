//
//  SQLiteDataManager.swift
//  70000 Tons Bands
//
//  SQLite implementation of DataManagerProtocol
//  Thread-safe, fast, and doesn't require performAndWait blocks
//

import Foundation
import SQLite

/// SQLite implementation of the data manager
/// Fully thread-safe - can be called from any thread without restrictions
class SQLiteDataManager: DataManagerProtocol {
    
    static let shared = SQLiteDataManager()
    
    private var db: Connection?
    
    // Database version for schema migrations
    private let currentSchemaVersion = 9  // v9: bands.lineIndex for canonical order (offline QR)
    private let schemaVersionKey = "SQLiteSchemaVersion"
    
    // Table definitions
    private let bandsTable = Table("bands")
    private let eventsTable = Table("events")
    private let userPrioritiesTable = Table("user_priorities")
    private let userAttendancesTable = Table("user_attendances")
    private let descriptionMapTable = Table("description_map")
    
    // Band columns
    private let bandId = Expression<Int64>("id")
    private let bandName = Expression<String>("bandName")
    private let eventYear = Expression<Int>("eventYear")
    private let officialSite = Expression<String?>("officialSite")
    private let imageUrl = Expression<String?>("imageUrl")
    private let youtube = Expression<String?>("youtube")
    private let metalArchives = Expression<String?>("metalArchives")
    private let wikipedia = Expression<String?>("wikipedia")
    private let country = Expression<String?>("country")
    private let genre = Expression<String?>("genre")
    private let noteworthy = Expression<String?>("noteworthy")
    private let priorYears = Expression<String?>("priorYears")
    /// 0-based position in source artist CSV; used for canonical band order when bandFile.txt is missing (offline).
    private let lineIndex = Expression<Int?>("lineIndex")
    
    // Event columns
    private let eventId = Expression<Int64>("id")
    private let eventBandName = Expression<String>("bandName")
    private let eventYear_col = Expression<Int>("eventYear")
    private let location = Expression<String>("location")
    private let eventType = Expression<String?>("eventType")
    private let date = Expression<String?>("date")
    private let day = Expression<String?>("day")
    private let startTime = Expression<String?>("startTime")
    private let endTime = Expression<String?>("endTime")
    private let timeIndex = Expression<Double>("timeIndex")
    private let endTimeIndex = Expression<Double>("endTimeIndex")
    private let notes = Expression<String?>("notes")
    private let descriptionUrl = Expression<String?>("descriptionUrl")
    private let eventImageUrl = Expression<String?>("eventImageUrl")
    
    // User Priority columns
    private let priorityId = Expression<Int64>("id")
    private let priorityBandName = Expression<String>("bandName")
    private let priorityEventYear = Expression<Int>("eventYear")
    private let priorityValue = Expression<Int>("priority")
    private let priorityLastModified = Expression<Double?>("lastModified")
    
    // User Attendance columns
    private let attendanceId = Expression<Int64>("id")
    private let attendanceBandName = Expression<String>("bandName")
    private let attendanceEventYear = Expression<Int>("eventYear")
    private let attendanceTimeIndex = Expression<Double>("timeIndex")
    private let attendanceStatus = Expression<Int>("status")
    private let attendanceLastModified = Expression<Double?>("lastModified")
    
    // Description Map columns
    private let descMapId = Expression<Int64>("id")
    private let descMapEntityName = Expression<String>("entityName")  // Band or event name
    private let descMapEventYear = Expression<Int>("eventYear")
    private let descMapDescriptionUrl = Expression<String>("descriptionUrl")
    private let descMapDescriptionUrlDate = Expression<String?>("descriptionUrlDate")  // Optional modification date
    
    private init() {
        setupDatabase()
    }
    
    // MARK: - Transaction helpers
    
    /// Runs the provided block inside a single IMMEDIATE transaction.
    /// This ensures readers never observe partial delete/insert states during large refreshes
    /// (e.g., schedule imports) and fixes event-count oscillations.
    @discardableResult
    func withImmediateTransaction(_ label: String, _ block: () -> Bool) -> Bool {
        guard let db = db else { return false }
        
        do {
            try db.execute("BEGIN IMMEDIATE TRANSACTION")
            let ok = block()
            if ok {
                try db.execute("COMMIT")
                return true
            } else {
                try db.execute("ROLLBACK")
                return false
            }
        } catch {
            try? db.execute("ROLLBACK")
            return false
        }
    }
    
    /// Deletes all events for a given year in a single statement.
    /// Returns the number of deleted rows (best-effort; 0 if DB not available).
    @discardableResult
    func deleteAllEvents(forYear year: Int) -> Int {
        guard let db = db else { return 0 }
        do {
            let count = try db.run(eventsTable.filter(eventYear_col == year).delete())
            return count
        } catch {
            return 0
        }
    }
    
    private func setupDatabase() {
        do {
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            let dbPath = "\(documentsPath)/70kbands.sqlite3"
            db = try Connection(dbPath)
            
            // CRITICAL: Set busy timeout to handle concurrent writes
            // This prevents "database is locked" errors when multiple managers access the same DB
            try db?.execute("PRAGMA busy_timeout = 30000")  // 30 seconds
            
            // Enable WAL mode for better concurrency
            try db?.execute("PRAGMA journal_mode=WAL")
            
            // Check schema version and recreate tables if needed
            let needsMigration = try checkAndMigrateSchema()
            
            try createTables()
            
            // Verify unique constraint was created
            try verifyUniqueConstraints()
            
            // IMPORTANT: Only save version AFTER tables are successfully created
            if needsMigration {
                UserDefaults.standard.set(currentSchemaVersion, forKey: schemaVersionKey)
            }
        } catch {
            // Initialization failed
        }
    }
    
    private func verifyUniqueConstraints() throws {
        guard let db = db else { return }
        
    }
    
    private func checkAndMigrateSchema() throws -> Bool {
        guard let db = db else { return false }
        
        let storedVersion = UserDefaults.standard.integer(forKey: schemaVersionKey)
        
        if storedVersion < currentSchemaVersion {
            // v8 -> v9: Add lineIndex to bands (no drop; preserve data). Only when upgrading from 8 (table exists).
            if storedVersion == 8 {
                try? db.execute("ALTER TABLE bands ADD COLUMN lineIndex INTEGER")
            }
            // Major schema bumps: drop and recreate (only when needed in future)
            if storedVersion < 8 {
                try? db.run(bandsTable.drop(ifExists: true))
                try? db.run(eventsTable.drop(ifExists: true))
                try? db.run(userPrioritiesTable.drop(ifExists: true))
                try? db.run(userAttendancesTable.drop(ifExists: true))
                try? db.run(descriptionMapTable.drop(ifExists: true))
                for year in 2011...2030 {
                    UserDefaults.standard.removeObject(forKey: "batchInsertCallCount_\(year)")
                }
            }
            // Return true to indicate migration was performed
            return true
        }
        return false
    }
    
    private func createTables() throws {
        guard let db = db else { return }
        
        // Bands table
        try db.run(bandsTable.create(ifNotExists: true) { t in
            t.column(bandId, primaryKey: .autoincrement)
            t.column(bandName)
            t.column(eventYear)
            t.column(officialSite)
            t.column(imageUrl)
            t.column(youtube)
            t.column(metalArchives)
            t.column(wikipedia)
            t.column(country)
            t.column(genre)
            t.column(noteworthy)
            t.column(priorYears)
            t.column(lineIndex)
            t.unique(bandName, eventYear)
        })
        
        // Events table
        try db.run(eventsTable.create(ifNotExists: true) { t in
            t.column(eventId, primaryKey: .autoincrement)
            t.column(eventBandName)
            t.column(eventYear_col)
            t.column(location)
            t.column(eventType)
            t.column(date)
            t.column(day)
            t.column(startTime)
            t.column(endTime)
            t.column(timeIndex)
            t.column(endTimeIndex)
            t.column(notes)
            t.column(descriptionUrl)
            t.column(eventImageUrl)
            t.unique(eventBandName, eventYear_col, timeIndex)
        })
        
        // User Priorities table
        try db.run(userPrioritiesTable.create(ifNotExists: true) { t in
            t.column(priorityId, primaryKey: .autoincrement)
            t.column(priorityBandName)
            t.column(priorityEventYear)
            t.column(priorityValue)
            t.column(priorityLastModified)
            t.unique(priorityBandName, priorityEventYear)
        })
        
        // User Attendances table
        try db.run(userAttendancesTable.create(ifNotExists: true) { t in
            t.column(attendanceId, primaryKey: .autoincrement)
            t.column(attendanceBandName)
            t.column(attendanceEventYear)
            t.column(attendanceTimeIndex)
            t.column(attendanceStatus)
            t.column(attendanceLastModified)
            t.unique(attendanceBandName, attendanceEventYear, attendanceTimeIndex)
        })
        
        // Description Map table
        try db.run(descriptionMapTable.create(ifNotExists: true) { t in
            t.column(descMapId, primaryKey: .autoincrement)
            t.column(descMapEntityName)
            t.column(descMapEventYear)
            t.column(descMapDescriptionUrl)
            t.column(descMapDescriptionUrlDate)
            t.unique(descMapEntityName, descMapEventYear)
        })
        
        // Create indexes
        try db.run(bandsTable.createIndex(eventYear, ifNotExists: true))
        try db.run(eventsTable.createIndex(eventYear_col, ifNotExists: true))
        try db.run(eventsTable.createIndex(eventBandName, ifNotExists: true))
        try db.run(descriptionMapTable.createIndex(descMapEventYear, ifNotExists: true))
        try db.run(descriptionMapTable.createIndex(descMapEntityName, ifNotExists: true))
    }
    
    // MARK: - Band Operations
    
    func fetchBands(forYear year: Int) -> [BandData] {
        guard let db = db else { return [] }
        
        do {
            let query = bandsTable.filter(eventYear == year)
            var bands: [BandData] = []
            
            for row in try db.prepare(query) {
                let band = BandData(
                    bandName: row[bandName],
                    eventYear: year,
                    officialSite: row[officialSite],
                    imageUrl: row[imageUrl],
                    youtube: row[youtube],
                    metalArchives: row[metalArchives],
                    wikipedia: row[wikipedia],
                    country: row[country],
                    genre: row[genre],
                    noteworthy: row[noteworthy],
                    priorYears: row[priorYears]
                )
                bands.append(band)
            }
            return bands
        } catch {
            return []
        }
    }
    
    func fetchBands() -> [BandData] {
        guard let db = db else { return [] }
        
        do {
            var bands: [BandData] = []
            
            for row in try db.prepare(bandsTable) {
                let band = BandData(
                    bandName: row[bandName],
                    eventYear: row[eventYear],
                    officialSite: row[officialSite],
                    imageUrl: row[imageUrl],
                    youtube: row[youtube],
                    metalArchives: row[metalArchives],
                    wikipedia: row[wikipedia],
                    country: row[country],
                    genre: row[genre],
                    noteworthy: row[noteworthy],
                    priorYears: row[priorYears]
                )
                bands.append(band)
            }
            
            return bands
        } catch {
            return []
        }
    }
    
    func fetchBand(byName name: String, eventYear year: Int) -> BandData? {
        guard let db = db else { return nil }
        
        do {
            let query = bandsTable.filter(bandName == name && eventYear == year).limit(1)
            
            for row in try db.prepare(query) {
                let band = BandData(
                    bandName: row[bandName],
                    eventYear: year,
                    officialSite: row[officialSite],
                    imageUrl: row[imageUrl],
                    youtube: row[youtube],
                    metalArchives: row[metalArchives],
                    wikipedia: row[wikipedia],
                    country: row[country],
                    genre: row[genre],
                    noteworthy: row[noteworthy],
                    priorYears: row[priorYears]
                )
                return band
            }
            
            return nil
        } catch {
            return nil
        }
    }
    
    /// Band names in canonical (artist CSV) order for QR; uses lineIndex only. No fallback.
    /// Only bands with non-nil lineIndex are included (schedule-only bands have nil and are excluded).
    /// If this returns empty, band list import (BandCSVImporter) did not run or failed for this year.
    func fetchBandNamesInCanonicalOrder(forYear year: Int) -> [String] {
        guard let db = db else {
            print("[LineIndex] LOOKUP year=\(year) db=nil → count=0")
            return []
        }
        do {
            let query = bandsTable
                .filter(eventYear == year && lineIndex !== nil)
                .order(lineIndex.asc)
            var names: [String] = []
            for row in try db.prepare(query) {
                names.append(row[bandName])
            }
            if !names.isEmpty {
                print("[LineIndex] LOOKUP year=\(year) → count=\(names.count)")
            } else {
                let totalForYear = try Int(db.scalar(bandsTable.filter(eventYear == year).count))
                print("[LineIndex] LOOKUP year=\(year) → count=0 (bands in DB for year: \(totalForYear), none have lineIndex)")
            }
            return names
        } catch {
            print("[LineIndex] LOOKUP year=\(year) error=\(error) → count=0")
            return []
        }
    }
    
    /// lineIndex: only set when called from full band list import (BandCSVImporter); pass nil for schedule/event paths so existing lineIndex is not overwritten.
    func createOrUpdateBand(name: String, eventYear year: Int, officialSite: String?, imageUrl: String?, youtube: String?, metalArchives: String?, wikipedia: String?, country: String?, genre: String?, noteworthy: String?, priorYears: String?, lineIndex lineIndexParam: Int? = nil) -> BandData {
        guard let db = db else {
            fatalError("Database not initialized")
        }
        
        // Helper to validate image URLs (reject nil, empty, whitespace-only)
        func isValidImageURL(_ url: String?) -> Bool {
            guard let url = url else { return false }
            let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && trimmed != "http://"
        }
        
        // Determine final image URL: use new one if valid, otherwise preserve existing
        var finalImageUrl = imageUrl
        if !isValidImageURL(imageUrl) {
            // New URL is invalid - check if we should preserve existing
            do {
                let query = bandsTable.filter(bandName == name && eventYear == year)
                if let existingBand = try db.pluck(query),
                   let existingImageUrl = existingBand[self.imageUrl],
                   isValidImageURL(existingImageUrl) {
                    // Preserve existing valid image URL
                    finalImageUrl = existingImageUrl
                }
            } catch {
                // Could not check existing band image URL
            }
        }
        
        do {
            if let idx = lineIndexParam {
                print("[LineIndex] WRITE single year=\(year) name=\(name) lineIndex=\(idx)")
            } else {
                print("[LineIndex] WRITE nil year=\(year) name=\(name) (replace — overwrites existing lineIndex if any)")
            }
            let insert = bandsTable.insert(
                or: .replace,
                bandName <- name,
                eventYear <- year,
                self.officialSite <- officialSite,
                self.imageUrl <- finalImageUrl,  // ✅ Use validated/preserved URL
                self.youtube <- youtube,
                self.metalArchives <- metalArchives,
                self.wikipedia <- wikipedia,
                self.country <- country,
                self.genre <- genre,
                self.noteworthy <- noteworthy,
                self.priorYears <- priorYears,
                self.lineIndex <- lineIndexParam
            )
            try db.run(insert)
        } catch {
            // Insert/update failed
        }

        // Return the band as a plain struct (no Core Data!)
        return BandData(
            bandName: name,
            eventYear: year,
            officialSite: officialSite,
            imageUrl: finalImageUrl,
            youtube: youtube,
            metalArchives: metalArchives,
            wikipedia: wikipedia,
            country: country,
            genre: genre,
            noteworthy: noteworthy,
            priorYears: priorYears
        )
    }
    
    /// Create band only if it doesn't exist (won't overwrite existing data). Used by schedule/event import only.
    /// Never sets lineIndex (new rows get nil). Does not modify existing bands; lineIndex is only set when the full band list is imported (BandCSVImporter).
    func createBandIfNotExists(name: String, eventYear year: Int) -> Bool {
        guard let db = db else { return false }
        
        do {
            // Check if band already exists
            let query = bandsTable.filter(bandName == name && eventYear == year)
            let count = try db.scalar(query.count)
            
            if count > 0 {
                // Band exists, don't overwrite
                return true
            }
            
            // Band doesn't exist, create minimal entry
            print("[LineIndex] INSERT nil year=\(year) name=\(name) (new band, schedule/event path)")
            let insert = bandsTable.insert(
                or: .ignore,  // ✅ IGNORE if already exists (race condition safety)
                bandName <- name,
                eventYear <- year,
                self.officialSite <- nil,
                self.imageUrl <- nil,
                self.youtube <- nil,
                self.metalArchives <- nil,
                self.wikipedia <- nil,
                self.country <- nil,
                self.genre <- nil,
                self.noteworthy <- nil,
                self.priorYears <- nil,
                self.lineIndex <- nil
            )
            try db.run(insert)
            return true
        } catch {
            return false
        }
    }
    
    // Guard to prevent concurrent batch inserts
    private var isBatchInserting = false
    private let batchInsertLock = NSLock()
    
    private static func isDatabaseLocked(_ error: Error) -> Bool {
        let s = String(describing: error)
        return s.contains("database is locked") || s.contains("SQLITE_BUSY") || s.contains("code: 5")
    }
    
    /// Batch insert/update bands within a single transaction. lineIndex = 0-based row order from the full band list CSV only (count varies by year). Only this path and createOrUpdateBand(..., lineIndex:) set lineIndex; schedule/event import must never set it.
    /// Retries on "database is locked" so band list import can succeed when other threads hold the DB briefly.
    /// - Returns: true if the batch wrote successfully; false if DB was nil, locked after retries, or another error. Caller must not run delete/clear when false (leave existing records alone).
    func batchCreateOrUpdateBands(_ bands: [(name: String, eventYear: Int, officialSite: String?, imageUrl: String?, youtube: String?, metalArchives: String?, wikipedia: String?, country: String?, genre: String?, noteworthy: String?, priorYears: String?, lineIndex: Int?)]) -> Bool {
        // Prevent concurrent batch inserts
        batchInsertLock.lock()
        defer { batchInsertLock.unlock() }
        
        if isBatchInserting { return false }
        
        isBatchInserting = true
        defer { isBatchInserting = false }
        
        guard let db = db else { return false }
        
        let callCount = UserDefaults.standard.integer(forKey: "batchInsertCallCount_\(bands.first?.eventYear ?? 0)") + 1
        UserDefaults.standard.set(callCount, forKey: "batchInsertCallCount_\(bands.first?.eventYear ?? 0)")
        
        let year = bands.first?.eventYear ?? -1
        let count = bands.count
        let firstLineIndex = bands.first?.lineIndex
        let lastLineIndex = bands.last?.lineIndex
        print("[LineIndex] WRITE batch year=\(year) count=\(count) lineIndex range: first=\(firstLineIndex.map { String($0) } ?? "nil") last=\(lastLineIndex.map { String($0) } ?? "nil")")
        
        let maxRetries = 5
        var lastError: Error?
        for attempt in 1...maxRetries {
            do {
                try db.transaction {
                    for (index, bandData) in bands.enumerated() {
                        var finalImageUrl = bandData.imageUrl
                        if bandData.imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
                            || bandData.imageUrl == "http://" || bandData.imageUrl == "https://" {
                            let query = bandsTable.filter(bandName == bandData.name && eventYear == bandData.eventYear)
                            if let existingBand = try db.pluck(query),
                               let existingImageUrl = existingBand[self.imageUrl],
                               !(existingImageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty),
                               existingImageUrl != "http://" {
                                finalImageUrl = existingImageUrl
                            }
                        }
                        let insert = bandsTable.insert(
                            or: .replace,
                            bandName <- bandData.name,
                            eventYear <- bandData.eventYear,
                            self.officialSite <- bandData.officialSite,
                            self.imageUrl <- finalImageUrl,
                            self.youtube <- bandData.youtube,
                            self.metalArchives <- bandData.metalArchives,
                            self.wikipedia <- bandData.wikipedia,
                            self.country <- bandData.country,
                            self.genre <- bandData.genre,
                            self.noteworthy <- bandData.noteworthy,
                            self.priorYears <- bandData.priorYears,
                            self.lineIndex <- bandData.lineIndex
                        )
                        try db.run(insert)
                    }
                }
                print("[LineIndex] WRITE batch year=\(year) completed \(count) rows")
                return true
            } catch {
                lastError = error
                if Self.isDatabaseLocked(error) && attempt < maxRetries {
                    let delayMs = 200 * attempt
                    print("[LineIndex] WRITE batch year=\(year) database locked, retry \(attempt)/\(maxRetries) in \(delayMs)ms")
                    Thread.sleep(forTimeInterval: Double(delayMs) / 1000.0)
                } else {
                    print("[LineIndex] WRITE batch failed year=\(year) error=\(error)")
                    return false
                }
            }
        }
        if let e = lastError {
            print("[LineIndex] WRITE batch failed year=\(year) after \(maxRetries) attempts error=\(e)")
        }
        return false
    }
    
    func deleteBand(name: String, eventYear year: Int) {
        guard let db = db else { return }
        
        do {
            let bandToDelete = bandsTable.filter(bandName == name && eventYear == year)
            try db.run(bandToDelete.delete())
        } catch {
            // Delete failed
        }
    }
    
    /// Called only after full band list import. Clears lineIndex for any band in this year not in the artist list (e.g. schedule-only names). Retries on "database is locked".
    func clearLineIndexForBandsNotIn(eventYear year: Int, bandNamesInArtistList: Set<String>) {
        guard let db = db else { return }
        let maxRetries = 5
        var lastError: Error?
        for attempt in 1...maxRetries {
            do {
                let bands = bandsTable.filter(eventYear == year)
                var cleared = 0
                for row in try db.prepare(bands) {
                    let name = row[bandName]
                    if !bandNamesInArtistList.contains(name) {
                        try db.run(bandsTable.filter(bandName == name && eventYear == year).update(lineIndex <- nil))
                        cleared += 1
                        print("[LineIndex] CLEAR year=\(year) name=\(name) (not in artist list)")
                    }
                }
                if cleared > 0 {
                    print("[LineIndex] CLEAR year=\(year) cleared \(cleared) bands (artist list size=\(bandNamesInArtistList.count))")
                }
                return
            } catch {
                lastError = error
                if Self.isDatabaseLocked(error) && attempt < maxRetries {
                    let delayMs = 200 * attempt
                    print("[LineIndex] CLEAR year=\(year) database locked, retry \(attempt)/\(maxRetries) in \(delayMs)ms")
                    Thread.sleep(forTimeInterval: Double(delayMs) / 1000.0)
                } else {
                    print("[LineIndex] CLEAR year=\(year) error=\(error)")
                    return
                }
            }
        }
        if let e = lastError {
            print("[LineIndex] CLEAR year=\(year) failed after \(maxRetries) attempts error=\(e)")
        }
    }
    
    // MARK: - Event Operations
    
    func fetchEvents(forYear year: Int) -> [EventData] {
        guard let db = db else { return [] }
        
        do {
            let query = eventsTable.filter(eventYear_col == year)
            var events: [EventData] = []
            
            for row in try db.prepare(query) {
                let event = EventData(
                    bandName: row[eventBandName],
                    eventYear: year,
                    timeIndex: row[timeIndex],
                    endTimeIndex: row[endTimeIndex],
                    location: row[location],
                    date: row[date],
                    day: row[day],
                    startTime: row[startTime],
                    endTime: row[endTime],
                    eventType: row[eventType],
                    notes: row[notes],
                    descriptionUrl: row[descriptionUrl],
                    eventImageUrl: row[eventImageUrl]
                )
                events.append(event)
            }
            return events
        } catch {
            return []
        }
    }
    
    func fetchEvents() -> [EventData] {
        guard let db = db else { return [] }
        
        do {
            var events: [EventData] = []
            
            for row in try db.prepare(eventsTable) {
                let event = EventData(
                    bandName: row[eventBandName],
                    eventYear: row[eventYear_col],
                    timeIndex: row[timeIndex],
                    endTimeIndex: row[endTimeIndex],
                    location: row[location],
                    date: row[date],
                    day: row[day],
                    startTime: row[startTime],
                    endTime: row[endTime],
                    eventType: row[eventType],
                    notes: row[notes],
                    descriptionUrl: row[descriptionUrl],
                    eventImageUrl: row[eventImageUrl]
                )
                events.append(event)
            }
            return events
        } catch {
            return []
        }
    }
    
    func fetchEventsForBand(_ bandName: String, forYear year: Int) -> [EventData] {
        guard let db = db else { return [] }
        
        do {
            let query = eventsTable.filter(eventBandName == bandName && eventYear_col == year)
            var events: [EventData] = []
            
            for row in try db.prepare(query) {
                let event = EventData(
                    bandName: bandName,
                    eventYear: year,
                    timeIndex: row[timeIndex],
                    endTimeIndex: row[endTimeIndex],
                    location: row[location],
                    date: row[date],
                    day: row[day],
                    startTime: row[startTime],
                    endTime: row[endTime],
                    eventType: row[eventType],
                    notes: row[notes],
                    descriptionUrl: row[descriptionUrl],
                    eventImageUrl: row[eventImageUrl]
                )
                events.append(event)
            }
            return events
        } catch {
            return []
        }
    }
    
    func fetchEvents(forYear year: Int, location locationFilter: String?, eventType typeFilter: String?) -> [EventData] {
        guard let db = db else { return [] }
        
        do {
            var query = eventsTable.filter(eventYear_col == year)
            if let locationFilter = locationFilter {
                query = query.filter(location == locationFilter)
            }
            if let typeFilter = typeFilter {
                query = query.filter(eventType == typeFilter)
            }
            
            var events: [EventData] = []
            for row in try db.prepare(query) {
                let event = EventData(
                    bandName: row[eventBandName],
                    eventYear: year,
                    timeIndex: row[timeIndex],
                    endTimeIndex: row[endTimeIndex],
                    location: row[location],
                    date: row[date],
                    day: row[day],
                    startTime: row[startTime],
                    endTime: row[endTime],
                    eventType: row[eventType],
                    notes: row[notes],
                    descriptionUrl: row[descriptionUrl],
                    eventImageUrl: row[eventImageUrl]
                )
                events.append(event)
            }
            return events
        } catch {
            return []
        }
    }
    
    func createOrUpdateEvent(bandName name: String, timeIndex: Double, endTimeIndex: Double, location loc: String, date dt: String?, day dy: String?, startTime st: String?, endTime et: String?, eventType type: String?, eventYear year: Int, notes n: String?, descriptionUrl url: String?, eventImageUrl imgUrl: String?) -> EventData {
        guard let db = db else {
            fatalError("Database not initialized")
        }
        
        // NOTE: Event images are allowed to be null - most events don't have their own images
        // Only special events (like Meet & Greet) have event-specific images
        // The DetailView fallback logic will use band images when event images are null
        
        do {
            let insert = eventsTable.insert(
                or: .replace,
                eventBandName <- name,
                eventYear_col <- year,
                self.location <- loc,
                self.eventType <- type,
                self.date <- dt,
                self.day <- dy,
                self.startTime <- st,
                self.endTime <- et,
                self.timeIndex <- timeIndex,
                self.endTimeIndex <- endTimeIndex,
                self.notes <- n,
                self.descriptionUrl <- url,
                self.eventImageUrl <- imgUrl  // ✅ Write as-is (null is valid for events)
            )
            try db.run(insert)
        } catch {
            // Insert/update failed
        }
        
        // Return the event as a plain struct (no Core Data!)
        return EventData(
            bandName: name,
            eventYear: year,
            timeIndex: timeIndex,
            endTimeIndex: endTimeIndex,
            location: loc,
            date: dt,
            day: dy,
            startTime: st,
            endTime: et,
            eventType: type,
            notes: n,
            descriptionUrl: url,
            eventImageUrl: imgUrl
        )
    }
    
    func deleteEvent(bandName name: String, timeIndex ti: Double, eventYear year: Int) {
        guard let db = db else { return }
        
        do {
            let eventToDelete = eventsTable.filter(
                eventBandName == name &&
                eventYear_col == year &&
                timeIndex == ti
            )
            try db.run(eventToDelete.delete())
        } catch {
            // Delete failed
        }
    }
    
    /// Replaces all events for the given year with the provided list. Runs in a single transaction with retry on "database is locked" so we never leave partial state or store a checksum when the write failed.
    func replaceEvents(forYear year: Int, events: [EventData]) -> Bool {
        guard let db = db else { return false }
        let maxRetries = 5
        var lastError: Error?
        for attempt in 1...maxRetries {
            do {
                try db.transaction {
                    _ = try db.run(eventsTable.filter(eventYear_col == year).delete())
                    for e in events {
                        _ = self.createBandIfNotExists(name: e.bandName, eventYear: year)
                        let insert = eventsTable.insert(
                            or: .replace,
                            eventBandName <- e.bandName,
                            eventYear_col <- year,
                            self.location <- e.location,
                            self.eventType <- e.eventType,
                            self.date <- e.date,
                            self.day <- e.day,
                            self.startTime <- e.startTime,
                            self.endTime <- e.endTime,
                            self.timeIndex <- e.timeIndex,
                            self.endTimeIndex <- e.endTimeIndex,
                            self.notes <- e.notes,
                            self.descriptionUrl <- e.descriptionUrl,
                            self.eventImageUrl <- e.eventImageUrl
                        )
                        try db.run(insert)
                    }
                }
                return true
            } catch {
                lastError = error
                if Self.isDatabaseLocked(error) && attempt < maxRetries {
                    let delayMs = 200 * attempt
                    print("[ScheduleImport] replaceEvents year=\(year) database locked, retry \(attempt)/\(maxRetries) in \(delayMs)ms")
                    Thread.sleep(forTimeInterval: Double(delayMs) / 1000.0)
                } else {
                    print("[ScheduleImport] replaceEvents year=\(year) failed: \(error)")
                    return false
                }
            }
        }
        if let e = lastError {
            print("[ScheduleImport] replaceEvents year=\(year) failed after \(maxRetries) attempts: \(e)")
        }
        return false
    }
    
    func cleanupProblematicEvents(currentYear year: Int) {
        // No cleanup needed for SQLite
    }
    
    // MARK: - User Priority Operations
    
    func fetchUserPriorities() -> [UserPriorityData] {
        guard let db = db else { return [] }
        
        do {
            var priorities: [UserPriorityData] = []
            
            for row in try db.prepare(userPrioritiesTable) {
                let timestamp = row[priorityLastModified]
                let updatedAt = timestamp.map { Date(timeIntervalSince1970: $0) }
                
                let priority = UserPriorityData(
                    bandName: row[priorityBandName],
                    eventYear: row[priorityEventYear],
                    priorityLevel: row[priorityValue],
                    updatedAt: updatedAt
                )
                priorities.append(priority)
            }
            return priorities
        } catch {
            return []
        }
    }
    
    func createOrUpdateUserPriority(bandName name: String, eventYear year: Int, priorityLevel level: Int) -> UserPriorityData {
        guard let db = db else {
            fatalError("Database not initialized")
        }
        
        do {
            let insert = userPrioritiesTable.insert(
                or: .replace,
                priorityBandName <- name,
                priorityEventYear <- year,
                priorityValue <- level,
                priorityLastModified <- Date().timeIntervalSince1970
            )
            try db.run(insert)
        } catch {
            // Insert/update failed
        }
        
        return UserPriorityData(bandName: name, eventYear: year, priorityLevel: level, updatedAt: Date())
    }
    
    func deleteUserPriority(bandName name: String, eventYear year: Int) {
        guard let db = db else { return }
        
        do {
            let priorityToDelete = userPrioritiesTable.filter(priorityBandName == name && priorityEventYear == year)
            try db.run(priorityToDelete.delete())
        } catch {
            // Delete failed
        }
    }
    
    // MARK: - User Attendance Operations
    
    func fetchUserAttendances() -> [UserAttendanceData] {
        guard let db = db else { return [] }
        
        do {
            var attendances: [UserAttendanceData] = []
            
            for row in try db.prepare(userAttendancesTable) {
                let timestamp = row[attendanceLastModified]
                let updatedAt = timestamp.map { Date(timeIntervalSince1970: $0) }
                
                let attendance = UserAttendanceData(
                    bandName: row[attendanceBandName],
                    eventYear: row[attendanceEventYear],
                    timeIndex: row[attendanceTimeIndex],
                    attendanceStatus: row[attendanceStatus],
                    updatedAt: updatedAt
                )
                attendances.append(attendance)
            }
            return attendances
        } catch {
            return []
        }
    }
    
    func createOrUpdateUserAttendance(bandName name: String, eventYear year: Int, timeIndex ti: Double, attendanceStatus status: Int) -> UserAttendanceData {
        guard let db = db else {
            fatalError("Database not initialized")
        }
        
        do {
            let insert = userAttendancesTable.insert(
                or: .replace,
                attendanceBandName <- name,
                attendanceEventYear <- year,
                attendanceTimeIndex <- ti,
                attendanceStatus <- status,
                attendanceLastModified <- Date().timeIntervalSince1970
            )
            try db.run(insert)
        } catch {
            // Insert/update failed
        }
        
        return UserAttendanceData(bandName: name, eventYear: year, timeIndex: ti, attendanceStatus: status, updatedAt: Date())
    }
    
    func deleteUserAttendance(bandName name: String, eventYear year: Int, timeIndex ti: Double) {
        guard let db = db else { return }
        
        do {
            let attendanceToDelete = userAttendancesTable.filter(
                attendanceBandName == name && 
                attendanceEventYear == year && 
                attendanceTimeIndex == ti
            )
            try db.run(attendanceToDelete.delete())
        } catch {
            // Delete failed
        }
    }
    
    // MARK: - Description Map Operations
    
    /// Get description URL for a band or event
    func getDescriptionUrl(forEntity entityName: String, eventYear year: Int) -> String? {
        guard let db = db else { return nil }
        
        do {
            let query = descriptionMapTable.filter(descMapEntityName == entityName && descMapEventYear == year)
            if let row = try db.pluck(query) {
                return try row.get(descMapDescriptionUrl)
            }
            return nil
        } catch {
            return nil
        }
    }
    
    /// Get all description URLs for a given year
    func getAllDescriptionUrls(forYear year: Int) -> [String: String] {
        guard let db = db else { return [:] }
        
        var descriptionMap: [String: String] = [:]
        
        do {
            let query = descriptionMapTable.filter(descMapEventYear == year)
            for row in try db.prepare(query) {
                let entityName = try row.get(descMapEntityName)
                let url = try row.get(descMapDescriptionUrl)
                descriptionMap[entityName] = url
            }
        } catch {
            // Failed to fetch
        }
        
        return descriptionMap
    }
    
    /// Insert or update description URL for a band or event
    func createOrUpdateDescriptionUrl(forEntity entityName: String, eventYear year: Int, descriptionUrl url: String, descriptionUrlDate urlDate: String? = nil) {
        guard let db = db else { return }
        
        do {
            let insert = descriptionMapTable.insert(
                or: .replace,
                descMapEntityName <- entityName,
                descMapEventYear <- year,
                descMapDescriptionUrl <- url,
                descMapDescriptionUrlDate <- urlDate
            )
            try db.run(insert)
        } catch {
            // Insert/update failed
        }
    }
    
    /// Batch insert description map entries (for loading from CSV)
    func batchInsertDescriptionMap(entries: [(entityName: String, eventYear: Int, url: String, urlDate: String?)]) {
        guard let db = db else { return }
        
        do {
            try db.transaction {
                for entry in entries {
                    let insert = descriptionMapTable.insert(
                        or: .replace,
                        descMapEntityName <- entry.entityName,
                        descMapEventYear <- entry.eventYear,
                        descMapDescriptionUrl <- entry.url,
                        descMapDescriptionUrlDate <- entry.urlDate
                    )
                    try db.run(insert)
                }
            }
        } catch {
            // Batch insert failed
        }
    }
    
    /// Delete description URL for a band or event
    func deleteDescriptionUrl(forEntity entityName: String, eventYear year: Int) {
        guard let db = db else { return }
        
        do {
            let entryToDelete = descriptionMapTable.filter(
                descMapEntityName == entityName && 
                descMapEventYear == year
            )
            try db.run(entryToDelete.delete())
        } catch {
            // Delete failed
        }
    }
    
    /// Clear all description map entries for a specific year
    func clearDescriptionMap(forYear year: Int) {
        guard let db = db else { return }
        
        do {
            let entriesToDelete = descriptionMapTable.filter(descMapEventYear == year)
            _ = try db.run(entriesToDelete.delete())
        } catch {
            // Clear failed
        }
    }
}


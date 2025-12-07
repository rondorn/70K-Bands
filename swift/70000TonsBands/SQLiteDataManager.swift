//
//  SQLiteDataManager.swift
//  70000 Tons Bands
//
//  SQLite implementation of DataManagerProtocol
//  Thread-safe, fast, and doesn't require performAndWait blocks
//

import Foundation
import SQLite
import CoreData

/// SQLite implementation of the data manager
/// Fully thread-safe - can be called from any thread without restrictions
class SQLiteDataManager: DataManagerProtocol {
    
    static let shared = SQLiteDataManager()
    
    private var db: Connection?
    
    // Database version for schema migrations
    private let currentSchemaVersion = 7  // v7: Disabled CoreDataPreloadManager monitoring for SQLite backend
    private let schemaVersionKey = "SQLiteSchemaVersion"
    
    // Table definitions
    private let bandsTable = Table("bands")
    private let eventsTable = Table("events")
    private let userPrioritiesTable = Table("user_priorities")
    private let userAttendancesTable = Table("user_attendances")
    
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
    
    private init() {
        print("📊 SQLiteDataManager: Initializing SQLite backend")
        setupDatabase()
    }
    
    private func setupDatabase() {
        do {
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            let dbPath = "\(documentsPath)/70kbands.sqlite3"
            print("📊 SQLiteDataManager: Database path: \(dbPath)")
            
            db = try Connection(dbPath)
            
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
                print("✅ SQLiteDataManager: Schema version updated to \(currentSchemaVersion)")
            }
            
            print("✅ SQLiteDataManager: Initialization complete")
        } catch {
            print("❌ SQLiteDataManager: Failed to initialize: \(error)")
        }
    }
    
    private func verifyUniqueConstraints() throws {
        guard let db = db else { return }
        
        // Query SQLite schema to verify unique constraints exist
        let schemaQuery = "SELECT sql FROM sqlite_master WHERE type='table' AND name='bands'"
        if let schema = try db.scalar(schemaQuery) as? String {
            print("🔍 [SCHEMA_DEBUG] Bands table schema:")
            print(schema)
            
            if schema.contains("UNIQUE") {
                print("✅ [SCHEMA_DEBUG] Unique constraint FOUND in schema")
            } else {
                print("❌ [SCHEMA_DEBUG] Unique constraint NOT FOUND - this will cause duplicates!")
            }
        }
        
        // Also check indexes
        let indexQuery = "SELECT name, sql FROM sqlite_master WHERE type='index' AND tbl_name='bands'"
        for row in try db.prepare(indexQuery) {
            print("🔍 [SCHEMA_DEBUG] Index: \(row[0] ?? "unknown")")
            print("🔍 [SCHEMA_DEBUG] SQL: \(row[1] ?? "unknown")")
        }
    }
    
    private func checkAndMigrateSchema() throws -> Bool {
        guard let db = db else { return false }
        
        let storedVersion = UserDefaults.standard.integer(forKey: schemaVersionKey)
        
        if storedVersion < currentSchemaVersion {
            print("🔄 SQLiteDataManager: Schema version \(storedVersion) is outdated (current: \(currentSchemaVersion))")
            print("🔄 SQLiteDataManager: Dropping old tables to recreate with unique constraints...")
            
            // Drop old tables
            try? db.run(bandsTable.drop(ifExists: true))
            try? db.run(eventsTable.drop(ifExists: true))
            try? db.run(userPrioritiesTable.drop(ifExists: true))
            try? db.run(userAttendancesTable.drop(ifExists: true))
            
            // Reset batch insert counters for all years since we're starting fresh
            for year in 2011...2030 {
                UserDefaults.standard.removeObject(forKey: "batchInsertCallCount_\(year)")
            }
            
            print("✅ SQLiteDataManager: Old tables dropped and counters reset, will recreate with proper constraints")
            
            // Return true to indicate migration was performed
            // Version will be saved AFTER tables are successfully created
            return true
        } else {
            print("✅ SQLiteDataManager: Schema version is current (\(currentSchemaVersion))")
            return false
        }
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
        
        // Create indexes
        try db.run(bandsTable.createIndex(eventYear, ifNotExists: true))
        try db.run(eventsTable.createIndex(eventYear_col, ifNotExists: true))
        try db.run(eventsTable.createIndex(eventBandName, ifNotExists: true))
        
        print("✅ SQLiteDataManager: Tables created successfully")
    }
    
    // MARK: - Band Operations
    
    func fetchBands(forYear year: Int) -> [BandData] {
        guard let db = db else {
            print("❌ SQLiteDataManager: Database not initialized")
            return []
        }
        
        do {
            // Debug: Check total bands in database
            let totalCount = try db.scalar(bandsTable.count)
            print("🔍 [FETCH_DEBUG] Total bands in database (all years): \(totalCount)")
            
            // Debug: Check bands for specific year
            let query = bandsTable.filter(eventYear == year)
            let yearCount = try db.scalar(query.count)
            print("🔍 [FETCH_DEBUG] Bands for year \(year): \(yearCount)")
            
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
            
            print("✅ SQLiteDataManager: Fetched \(bands.count) bands for year \(year) (NO Core Data objects!)")
            return bands
        } catch {
            print("❌ SQLiteDataManager: Failed to fetch bands: \(error)")
            return []
        }
    }
    
    func fetchBands() -> [BandData] {
        guard let db = db else {
            print("❌ SQLiteDataManager: Database not initialized")
            return []
        }
        
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
            
            print("✅ SQLiteDataManager: Fetched \(bands.count) bands (all years, NO Core Data objects!)")
            return bands
        } catch {
            print("❌ SQLiteDataManager: Failed to fetch all bands: \(error)")
            return []
        }
    }
    
    func fetchBand(byName name: String, eventYear year: Int) -> BandData? {
        guard let db = db else {
            print("❌ SQLiteDataManager: Database not initialized")
            return nil
        }
        
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
            print("❌ SQLiteDataManager: Failed to fetch band '\(name)': \(error)")
            return nil
        }
    }
    
    func createOrUpdateBand(name: String, eventYear year: Int, officialSite: String?, imageUrl: String?, youtube: String?, metalArchives: String?, wikipedia: String?, country: String?, genre: String?, noteworthy: String?, priorYears: String?) -> BandData {
        guard let db = db else {
            fatalError("Database not initialized")
        }
        
        do {
            let insert = bandsTable.insert(
                or: .replace,
                bandName <- name,
                eventYear <- year,
                self.officialSite <- officialSite,
                self.imageUrl <- imageUrl,
                self.youtube <- youtube,
                self.metalArchives <- metalArchives,
                self.wikipedia <- wikipedia,
                self.country <- country,
                self.genre <- genre,
                self.noteworthy <- noteworthy,
                self.priorYears <- priorYears
            )
            try db.run(insert)
            print("✅ SQLiteDataManager: Inserted/updated band '\(name)' for year \(year) (NO Core Data!)")
        } catch {
            print("❌ SQLiteDataManager: Failed to insert/update band: \(error)")
        }
        
        // Return the band as a plain struct (no Core Data!)
        return BandData(
            bandName: name,
            eventYear: year,
            officialSite: officialSite,
            imageUrl: imageUrl,
            youtube: youtube,
            metalArchives: metalArchives,
            wikipedia: wikipedia,
            country: country,
            genre: genre,
            noteworthy: noteworthy,
            priorYears: priorYears
        )
    }
    
    // Guard to prevent concurrent batch inserts
    private var isBatchInserting = false
    private let batchInsertLock = NSLock()
    
    /// Batch insert/update bands within a single transaction for better performance
    func batchCreateOrUpdateBands(_ bands: [(name: String, eventYear: Int, officialSite: String?, imageUrl: String?, youtube: String?, metalArchives: String?, wikipedia: String?, country: String?, genre: String?, noteworthy: String?, priorYears: String?)]) {
        // Prevent concurrent batch inserts
        batchInsertLock.lock()
        defer { batchInsertLock.unlock() }
        
        if isBatchInserting {
            print("⚠️ [BATCH_DEBUG] Batch insert already in progress - BLOCKING duplicate insert attempt")
            return
        }
        
        isBatchInserting = true
        defer { isBatchInserting = false }
        
        guard let db = db else {
            print("❌ SQLiteDataManager: Database not initialized")
            return
        }
        
        // Debug: Check how many times this has been called
        let callCount = UserDefaults.standard.integer(forKey: "batchInsertCallCount_\(bands.first?.eventYear ?? 0)") + 1
        UserDefaults.standard.set(callCount, forKey: "batchInsertCallCount_\(bands.first?.eventYear ?? 0)")
        print("🔍 [BATCH_DEBUG] This is batch insert call #\(callCount) for year \(bands.first?.eventYear ?? 0)")
        
        do {
            // Debug: Check what's in DB before insert
            let totalBeforeInsert = try db.scalar(bandsTable.count)
            print("🔍 [BATCH_DEBUG] Total bands in DB BEFORE insert: \(totalBeforeInsert)")
            
            print("🔄 SQLiteDataManager: Starting batch insert of \(bands.count) bands in single transaction")
            if let firstBand = bands.first {
                print("🔍 [BATCH_DEBUG] First band year: \(firstBand.eventYear), name: '\(firstBand.name)'")
            }
            
            try db.transaction {
                for (index, bandData) in bands.enumerated() {
                    let insert = bandsTable.insert(
                        or: .replace,
                        bandName <- bandData.name,
                        eventYear <- bandData.eventYear,
                        self.officialSite <- bandData.officialSite,
                        self.imageUrl <- bandData.imageUrl,
                        self.youtube <- bandData.youtube,
                        self.metalArchives <- bandData.metalArchives,
                        self.wikipedia <- bandData.wikipedia,
                        self.country <- bandData.country,
                        self.genre <- bandData.genre,
                        self.noteworthy <- bandData.noteworthy,
                        self.priorYears <- bandData.priorYears
                    )
                    try db.run(insert)
                    
                    if (index + 1) % 10 == 0 {
                        print("🔄 SQLiteDataManager: Inserted \(index + 1)/\(bands.count) bands for year \(bandData.eventYear)")
                    }
                }
            }
            
            // Debug: Verify what's actually in the database after insert
            let totalAfterInsert = try db.scalar(bandsTable.count)
            print("🔍 [BATCH_DEBUG] Total bands in DB AFTER insert: \(totalAfterInsert)")
            print("🔍 [BATCH_DEBUG] Net change: +\(totalAfterInsert - totalBeforeInsert) bands")
            
            print("✅ SQLiteDataManager: Batch insert complete - \(bands.count) bands inserted/updated")
        } catch {
            print("❌ SQLiteDataManager: Batch insert failed: \(error)")
        }
    }
    
    func deleteBand(name: String, eventYear year: Int) {
        guard let db = db else { return }
        
        do {
            let bandToDelete = bandsTable.filter(bandName == name && eventYear == year)
            try db.run(bandToDelete.delete())
            print("✅ SQLiteDataManager: Deleted band '\(name)' for year \(year)")
        } catch {
            print("❌ SQLiteDataManager: Failed to delete band: \(error)")
        }
    }
    
    // MARK: - Event Operations
    
    func fetchEvents(forYear year: Int) -> [EventData] {
        guard let db = db else {
            print("❌ SQLiteDataManager: Database not initialized")
            return []
        }
        
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
            
            print("✅ SQLiteDataManager: Fetched \(events.count) events for year \(year) (NO Core Data!)")
            return events
        } catch {
            print("❌ SQLiteDataManager: Failed to fetch events: \(error)")
            return []
        }
    }
    
    func fetchEvents() -> [EventData] {
        guard let db = db else {
            print("❌ SQLiteDataManager: Database not initialized")
            return []
        }
        
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
            
            print("✅ SQLiteDataManager: Fetched \(events.count) events (all years, NO Core Data!)")
            return events
        } catch {
            print("❌ SQLiteDataManager: Failed to fetch all events: \(error)")
            return []
        }
    }
    
    func fetchEventsForBand(_ bandName: String, forYear year: Int) -> [EventData] {
        guard let db = db else {
            print("❌ SQLiteDataManager: Database not initialized")
            return []
        }
        
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
            
            print("✅ SQLiteDataManager: Fetched \(events.count) events for band '\(bandName)' year \(year)")
            return events
        } catch {
            print("❌ SQLiteDataManager: Failed to fetch events for band: \(error)")
            return []
        }
    }
    
    func fetchEvents(forYear year: Int, location locationFilter: String?, eventType typeFilter: String?) -> [EventData] {
        guard let db = db else {
            print("❌ SQLiteDataManager: Database not initialized")
            return []
        }
        
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
            
            print("✅ SQLiteDataManager: Fetched \(events.count) events for year \(year) with filters (NO Core Data!)")
            return events
        } catch {
            print("❌ SQLiteDataManager: Failed to fetch events: \(error)")
            return []
        }
    }
    
    func createOrUpdateEvent(bandName name: String, timeIndex: Double, endTimeIndex: Double, location loc: String, date dt: String?, day dy: String?, startTime st: String?, endTime et: String?, eventType type: String?, eventYear year: Int, notes n: String?, descriptionUrl url: String?, eventImageUrl imgUrl: String?) -> EventData {
        guard let db = db else {
            fatalError("Database not initialized")
        }
        
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
                self.eventImageUrl <- imgUrl
            )
            try db.run(insert)
            print("✅ SQLiteDataManager: Inserted/updated event for '\(name)' at timeIndex \(timeIndex) (NO Core Data!)")
        } catch {
            print("❌ SQLiteDataManager: Failed to insert/update event: \(error)")
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
            print("✅ SQLiteDataManager: Deleted event")
        } catch {
            print("❌ SQLiteDataManager: Failed to delete event: \(error)")
        }
    }
    
    func cleanupProblematicEvents(currentYear year: Int) {
        print("⚠️ SQLiteDataManager.cleanupProblematicEvents(currentYear:) - no cleanup needed for SQLite")
    }
    
    // MARK: - User Priority Operations
    
    func fetchUserPriorities() -> [UserPriorityData] {
        guard let db = db else {
            print("❌ SQLiteDataManager: Database not initialized")
            return []
        }
        
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
            
            print("✅ SQLiteDataManager: Fetched \(priorities.count) user priorities (NO Core Data!)")
            return priorities
        } catch {
            print("❌ SQLiteDataManager: Failed to fetch user priorities: \(error)")
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
            print("✅ SQLiteDataManager: Inserted/updated user priority for '\(name)'")
        } catch {
            print("❌ SQLiteDataManager: Failed to insert/update user priority: \(error)")
        }
        
        return UserPriorityData(bandName: name, eventYear: year, priorityLevel: level, updatedAt: Date())
    }
    
    func deleteUserPriority(bandName name: String, eventYear year: Int) {
        guard let db = db else { return }
        
        do {
            let priorityToDelete = userPrioritiesTable.filter(priorityBandName == name && priorityEventYear == year)
            try db.run(priorityToDelete.delete())
            print("✅ SQLiteDataManager: Deleted user priority for '\(name)'")
        } catch {
            print("❌ SQLiteDataManager: Failed to delete user priority: \(error)")
        }
    }
    
    // MARK: - User Attendance Operations
    
    func fetchUserAttendances() -> [UserAttendanceData] {
        guard let db = db else {
            print("❌ SQLiteDataManager: Database not initialized")
            return []
        }
        
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
            
            print("✅ SQLiteDataManager: Fetched \(attendances.count) user attendances (NO Core Data!)")
            return attendances
        } catch {
            print("❌ SQLiteDataManager: Failed to fetch user attendances: \(error)")
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
            print("✅ SQLiteDataManager: Inserted/updated user attendance for '\(name)'")
        } catch {
            print("❌ SQLiteDataManager: Failed to insert/update user attendance: \(error)")
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
            print("✅ SQLiteDataManager: Deleted user attendance for '\(name)'")
        } catch {
            print("❌ SQLiteDataManager: Failed to delete user attendance: \(error)")
        }
    }
}


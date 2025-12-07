//
//  CoreDataToSQLiteMigrator.swift
//  70000 Tons Bands
//
//  Handles one-time migration of all Core Data to SQLite
//  Preserves ALL user data: bands, events, priorities, and attendance
//

import Foundation
import CoreData
import SQLite

class CoreDataToSQLiteMigrator {
    
    static let shared = CoreDataToSQLiteMigrator()
    private let coreDataMigrationKey = "hasCompletedCoreDataToSQLiteMigration_v1"
    private let fileMigrationKey = "hasCompletedFileToSQLiteMigration_v1"
    
    private init() {}
    
    /// Performs all necessary migrations in correct order
    /// Call this during app startup before any data access
    /// Migration order:
    /// 1. Core Data → SQLite (if Core Data has data)
    /// 2. Legacy Files → SQLite (if file-based priorities exist)
    func migrateIfNeeded() {
        print("🔄 CoreDataToSQLiteMigrator: Checking for needed migrations...")
        
        // Step 1: Migrate Core Data to SQLite (runs once)
        migrateCoreDataIfNeeded()
        
        // Step 2: Migrate file-based priorities to SQLite (runs once)
        migrateLegacyFilesIfNeeded()
        
        print("✅ CoreDataToSQLiteMigrator: All migration checks complete")
    }
    
    private func migrateCoreDataIfNeeded() {
        // Check if Core Data migration already completed
        if UserDefaults.standard.bool(forKey: coreDataMigrationKey) {
            print("✅ Core Data → SQLite migration already completed, skipping")
            print("ℹ️  Core Data will NOT be initialized (not needed)")
            return
        }
        
        print("🔍 Checking if Core Data migration is needed...")
        print("   [DIAG] Checking if Core Data persistent store exists (file check only, no Core Data access)...")
        
        // Check if Core Data persistent store file exists (without accessing Core Data)
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let coreDataStoreURL = URL(fileURLWithPath: documentsPath).appendingPathComponent("70000TonsBands.sqlite")
        
        let coreDataExists = FileManager.default.fileExists(atPath: coreDataStoreURL.path)
        print("   [DIAG] Core Data store file exists: \(coreDataExists)")
        
        if !coreDataExists {
            print("   ✅ Core Data store doesn't exist (fresh install) - skipping migration")
            print("   ℹ️  Core Data will NOT be initialized (not needed)")
            UserDefaults.standard.set(true, forKey: coreDataMigrationKey)
            UserDefaults.standard.synchronize()
            return
        }
        
        // Check file size - if it's tiny (< 50KB), it's probably empty
        if let attributes = try? FileManager.default.attributesOfItem(atPath: coreDataStoreURL.path),
           let fileSize = attributes[.size] as? Int64 {
            print("   [DIAG] Core Data store size: \(fileSize) bytes")
            if fileSize < 50000 {
                print("   ✅ Core Data store is very small (< 50KB), likely empty - skipping migration")
                print("   ℹ️  Core Data will NOT be initialized (not needed)")
                UserDefaults.standard.set(true, forKey: coreDataMigrationKey)
                UserDefaults.standard.synchronize()
                return
            }
        }
        
        print("   🚀 Core Data store has data - proceeding with migration...")
        print("   ⚠️  Core Data WILL be initialized now (needed for migration)")
        let startTime = Date()
        
        do {
            try performCoreDataMigration()
            
            // Mark migration as complete
            UserDefaults.standard.set(true, forKey: coreDataMigrationKey)
            UserDefaults.standard.synchronize()
            
            let elapsed = Date().timeIntervalSince(startTime)
            print("🎉 Core Data → SQLite migration completed in \(String(format: "%.2f", elapsed)) seconds")
        } catch {
            print("❌ Core Data → SQLite migration failed: \(error)")
            print("⚠️  App will continue but existing Core Data may not be migrated")
            
            // Mark as complete anyway to avoid infinite retry
            UserDefaults.standard.set(true, forKey: coreDataMigrationKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    private func migrateLegacyFilesIfNeeded() {
        // Check if file migration already completed
        if UserDefaults.standard.bool(forKey: fileMigrationKey) {
            print("✅ Legacy file → SQLite migration already completed, skipping")
            return
        }
        
        // Check if PriorityManager already migrated files to Core Data
        // If so, we can skip file migration since Core Data migration already handled it
        let priorityMigrationCompleted = UserDefaults.standard.bool(forKey: "PriorityMigrationCompleted")
        if priorityMigrationCompleted {
            print("ℹ️  Legacy files were already migrated to Core Data, marking file migration as complete")
            UserDefaults.standard.set(true, forKey: fileMigrationKey)
            UserDefaults.standard.synchronize()
            return
        }
        
        print("🚀 Starting legacy file → SQLite migration...")
        let startTime = Date()
        
        do {
            let migratedCount = try performFileMigration()
            
            // Mark migration as complete
            UserDefaults.standard.set(true, forKey: fileMigrationKey)
            UserDefaults.standard.synchronize()
            
            let elapsed = Date().timeIntervalSince(startTime)
            print("🎉 Legacy file → SQLite migration completed in \(String(format: "%.2f", elapsed)) seconds")
            print("   Migrated \(migratedCount) priorities from files")
        } catch {
            print("❌ Legacy file → SQLite migration failed: \(error)")
            print("⚠️  App will continue but file-based priorities may not be migrated")
        }
    }
    
    private func performCoreDataMigration() throws {
        // ONLY initialize Core Data when migration is actually needed
        print("🔄 Initializing Core Data for migration...")
        let coreDataManager = CoreDataManager.shared
        let container = coreDataManager.persistentContainer
        print("✅ Core Data initialized for migration")
        
        // Use background context to avoid main thread deadlock
        let backgroundContext = container.newBackgroundContext()
        backgroundContext.automaticallyMergesChangesFromParent = true
        
        // Get database connection
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let dbPath = "\(documentsPath)/70kbands.sqlite3"
        let db = try Connection(dbPath)
        
        // Create tables - they should already exist from SQLiteDataManager init
        print("📊 Verifying SQLite tables exist...")
        
        // Define tables
        let bandsTable = Table("bands")
        let eventsTable = Table("events")
        let userPrioritiesTable = Table("user_priorities")
        let userAttendancesTable = Table("user_attendances")
        
        // Define columns (must match SQLiteDataManager)
        let bandId = Expression<Int64>("id")
        let bandName = Expression<String>("bandName")
        let eventYear = Expression<Int>("eventYear")
        let officialSite = Expression<String?>("officialSite")
        let imageUrl = Expression<String?>("imageUrl")
        let youtube = Expression<String?>("youtube")
        let metalArchives = Expression<String?>("metalArchives")
        let wikipedia = Expression<String?>("wikipedia")
        let country = Expression<String?>("country")
        let genre = Expression<String?>("genre")
        let noteworthy = Expression<String?>("noteworthy")
        let priorYears = Expression<String?>("priorYears")
        
        let eventId = Expression<Int64>("id")
        let eventBandName = Expression<String>("bandName")
        let eventYear_col = Expression<Int>("eventYear")
        let location = Expression<String>("location")
        let eventType = Expression<String?>("eventType")
        let date = Expression<String?>("date")
        let day = Expression<String?>("day")
        let startTime = Expression<String?>("startTime")
        let endTime = Expression<String?>("endTime")
        let timeIndex = Expression<Double>("timeIndex")
        let endTimeIndex = Expression<Double>("endTimeIndex")
        let notes = Expression<String?>("notes")
        let descriptionUrl = Expression<String?>("descriptionUrl")
        let eventImageUrl = Expression<String?>("eventImageUrl")
        
        let priorityId = Expression<Int64>("id")
        let priorityBandName = Expression<String>("bandName")
        let priorityEventYear = Expression<Int>("eventYear")
        let priorityValue = Expression<Int>("priority")
        let priorityLastModified = Expression<Double?>("lastModified")
        
        let attendanceId = Expression<Int64>("id")
        let attendanceBandName = Expression<String>("bandName")
        let attendanceEventYear = Expression<Int>("eventYear")
        let attendanceTimeIndex = Expression<Double>("timeIndex")
        let attendanceStatus = Expression<Int>("status")
        let attendanceLastModified = Expression<Double?>("lastModified")
        
        // Migrate Bands
        print("📊 Migrating bands...")
        var coreDataBands: [Band] = []
        backgroundContext.performAndWait {
            let request: NSFetchRequest<Band> = Band.fetchRequest()
            coreDataBands = (try? backgroundContext.fetch(request)) ?? []
        }
        print("   Found \(coreDataBands.count) bands in Core Data")
        
        var bandsMigrated = 0
        for band in coreDataBands {
            guard let name = band.bandName else { continue }
            
            let insert = bandsTable.insert(
                or: .replace,
                bandName <- name,
                eventYear <- Int(band.eventYear),
                officialSite <- band.officialSite,
                imageUrl <- band.imageUrl,
                youtube <- band.youtube,
                metalArchives <- band.metalArchives,
                wikipedia <- band.wikipedia,
                country <- band.country,
                genre <- band.genre,
                noteworthy <- band.noteworthy,
                priorYears <- band.priorYears
            )
            try db.run(insert)
            bandsMigrated += 1
        }
        print("✅ Migrated \(bandsMigrated) bands")
        
        // Migrate Events
        print("📊 Migrating events...")
        var coreDataEvents: [Event] = []
        backgroundContext.performAndWait {
            let request: NSFetchRequest<Event> = Event.fetchRequest()
            coreDataEvents = (try? backgroundContext.fetch(request)) ?? []
        }
        print("   Found \(coreDataEvents.count) events in Core Data")
        
        var eventsMigrated = 0
        for event in coreDataEvents {
            guard let name = event.band?.bandName else { continue }
            
            let insert = eventsTable.insert(
                or: .replace,
                eventBandName <- name,
                eventYear_col <- Int(event.eventYear),
                location <- event.location ?? "",
                eventType <- event.eventType,
                date <- event.date,
                day <- event.day,
                startTime <- event.startTime,
                endTime <- event.endTime,
                timeIndex <- event.timeIndex,
                endTimeIndex <- event.endTimeIndex,
                notes <- event.notes,
                descriptionUrl <- event.descriptionUrl,
                eventImageUrl <- event.eventImageUrl
            )
            try db.run(insert)
            eventsMigrated += 1
        }
        print("✅ Migrated \(eventsMigrated) events")
        
        // Migrate User Priorities
        print("📊 Migrating user priorities...")
        var coreDataPriorities: [UserPriority] = []
        backgroundContext.performAndWait {
            let request: NSFetchRequest<UserPriority> = UserPriority.fetchRequest()
            coreDataPriorities = (try? backgroundContext.fetch(request)) ?? []
        }
        print("   Found \(coreDataPriorities.count) priorities in Core Data")
        
        var prioritiesMigrated = 0
        for priority in coreDataPriorities {
            guard let band = priority.band, let name = band.bandName else { continue }
            
            let insert = userPrioritiesTable.insert(
                or: .replace,
                priorityBandName <- name,
                priorityEventYear <- Int(priority.eventYear),
                priorityValue <- Int(priority.priorityLevel),
                priorityLastModified <- priority.updatedAt?.timeIntervalSince1970
            )
            try db.run(insert)
            prioritiesMigrated += 1
        }
        print("✅ Migrated \(prioritiesMigrated) user priorities")
        
        // Migrate User Attendances
        print("📊 Migrating user attendances...")
        var coreDataAttendances: [UserAttendance] = []
        backgroundContext.performAndWait {
            let request: NSFetchRequest<UserAttendance> = UserAttendance.fetchRequest()
            coreDataAttendances = (try? backgroundContext.fetch(request)) ?? []
        }
        print("   Found \(coreDataAttendances.count) attendances in Core Data")
        
        var attendancesMigrated = 0
        for attendance in coreDataAttendances {
            guard let event = attendance.event,
                  let band = event.band,
                  let name = band.bandName else { continue }
            
            let insert = userAttendancesTable.insert(
                or: .replace,
                attendanceBandName <- name,
                attendanceEventYear <- Int(attendance.eventYear),
                attendanceTimeIndex <- event.timeIndex,
                attendanceStatus <- Int(attendance.attendanceStatus),
                attendanceLastModified <- attendance.updatedAt?.timeIntervalSince1970
            )
            try db.run(insert)
            attendancesMigrated += 1
        }
        print("✅ Migrated \(attendancesMigrated) user attendances")
        
        print("🎉 Migration summary:")
        print("   Bands: \(bandsMigrated)")
        print("   Events: \(eventsMigrated)")
        print("   Priorities: \(prioritiesMigrated)")
        print("   Attendances: \(attendancesMigrated)")
    }
    
    private func performFileMigration() throws -> Int {
        print("📁 Checking for legacy file-based priority data...")
        
        // Get database connection
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let dbPath = "\(documentsPath)/70kbands.sqlite3"
        let db = try Connection(dbPath)
        
        // Define priority table
        let userPrioritiesTable = Table("user_priorities")
        let priorityId = Expression<Int64>("id")
        let priorityBandName = Expression<String>("bandName")
        let priorityEventYear = Expression<Int>("eventYear")
        let priorityValue = Expression<Int>("priority")
        let priorityLastModified = Expression<Double?>("lastModified")
        
        var migratedCount = 0
        
        // Source 1: Legacy cache from cacheVariables
        let legacyCache = cacheVariables.bandPriorityStorageCache
        if !legacyCache.isEmpty {
            print("📦 Found \(legacyCache.count) priorities in legacy cache")
            for (bandName, priority) in legacyCache {
                let insert = userPrioritiesTable.insert(
                    or: .replace,
                    priorityBandName <- bandName,
                    priorityEventYear <- eventYear,  // Use global eventYear
                    priorityValue <- priority,
                    priorityLastModified <- Date().timeIntervalSince1970
                )
                try db.run(insert)
                migratedCount += 1
            }
        }
        
        // Source 2: Legacy file (PriorityDataWrite.txt)
        let legacyFileData = loadLegacyPriorityFile()
        if !legacyFileData.isEmpty {
            print("📁 Found \(legacyFileData.count) priorities in legacy file")
            for (bandName, priority) in legacyFileData {
                // Only insert if not already migrated from cache
                if legacyCache[bandName] == nil {
                    let insert = userPrioritiesTable.insert(
                        or: .replace,
                        priorityBandName <- bandName,
                        priorityEventYear <- eventYear,
                        priorityValue <- priority,
                        priorityLastModified <- Date().timeIntervalSince1970
                    )
                    try db.run(insert)
                    migratedCount += 1
                }
            }
            
            // Rename legacy file after migration
            if let legacyFile = findLegacyPriorityFile() {
                renameLegacyFile(at: legacyFile)
            }
        }
        
        if migratedCount == 0 {
            print("ℹ️  No legacy priority data found to migrate")
        }
        
        return migratedCount
    }
    
    private func loadLegacyPriorityFile() -> [String: Int] {
        guard let legacyFile = findLegacyPriorityFile() else {
            return [:]
        }
        
        guard let fileContent = try? String(contentsOf: legacyFile, encoding: .utf8) else {
            return [:]
        }
        
        var priorityData: [String: Int] = [:]
        for line in fileContent.components(separatedBy: .newlines) {
            let components = line.components(separatedBy: "::")
            if components.count >= 2 {
                let bandName = components[0]
                if let priority = Int(components[1]), priority > 0 {
                    priorityData[bandName] = priority
                }
            }
        }
        
        return priorityData
    }
    
    private func findLegacyPriorityFile() -> URL? {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let possiblePaths = [
            "\(documentsPath)/PriorityDataWrite.txt",
            "\(documentsPath)/priorityDataWrite.txt"
        ]
        
        for path in possiblePaths {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        
        return nil
    }
    
    private func renameLegacyFile(at url: URL) {
        let renamedURL = url.deletingLastPathComponent().appendingPathComponent(url.lastPathComponent + ".migrated")
        do {
            try FileManager.default.moveItem(at: url, to: renamedURL)
            print("✅ Renamed legacy file to: \(renamedURL.lastPathComponent)")
        } catch {
            print("⚠️  Could not rename legacy file: \(error)")
        }
    }
}


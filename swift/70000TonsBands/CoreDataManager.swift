//
//  CoreDataManager.swift
//  70000TonsBands
//
//  Simple, clean Core Data manager using pure Swift
//

import Foundation
import CoreData

class CoreDataManager {
    static let shared = CoreDataManager()
    
    // Thread-safe initialization using dispatch_once pattern
    private var _persistentContainer: NSPersistentContainer?
    private let initQueue = DispatchQueue(label: "com.rdorn.coredata.init", qos: .userInitiated)
    
    private init() {
        // Initialization happens via initializeIfNeeded()
    }
    
    /// Thread-safe initialization - can be called from any thread
    /// Will only initialize once, subsequent calls return immediately
    private func initializeIfNeeded() {
        guard _persistentContainer == nil else { return }
        
        initQueue.sync {
            // Double-check inside lock
            guard _persistentContainer == nil else { return }
            
            print("🚀 CoreDataManager: Starting Core Data initialization...")
            let startTime = Date()
            
            _persistentContainer = createPersistentContainer()
            
            let elapsedTime = Date().timeIntervalSince(startTime)
            print("✅ CoreDataManager: Initialized in \(String(format: "%.3f", elapsedTime)) seconds")
        }
    }
    
    /// Creates and configures the persistent container
    private func createPersistentContainer() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "DataModel")
        
        // Configure store description for optimal concurrency BEFORE loading
        if let storeDescription = container.persistentStoreDescriptions.first {
            // Enable WAL (Write-Ahead Logging) to prevent reader/writer blocking
            // This significantly reduces Core Data race conditions
            storeDescription.setOption([
                "journal_mode": "WAL",           // Write-Ahead Logging prevents deadlocks
                "synchronous": "NORMAL",         // Balanced safety/performance
                "cache_size": "10000"           // Larger cache for better performance
            ] as NSDictionary, forKey: NSSQLitePragmasOption)
            
            print("✅ SQLite WAL mode enabled for concurrency safety")
        }
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("❌ CRITICAL Core Data error: \(error)")
                fatalError("Failed to load Core Data store: \(error)")
            }
        }
        
        // Configure main context for UI operations
        // automaticallyMergesChangesFromParent safely handles background context saves
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        print("✅ Core Data stack initialized successfully with WAL mode")
        return container
    }
    
    /// Thread-safe accessor for persistent container
    /// Initializes on first access if needed
    var persistentContainer: NSPersistentContainer {
        initializeIfNeeded()
        return _persistentContainer!
    }
    
    // Main thread context - ONLY use this on main thread
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // Background context for imports and heavy operations
    lazy var backgroundContext: NSManagedObjectContext = {
        let context = persistentContainer.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        return context
    }()
    
    // MARK: - Safe Background Operations
    
    /// Perform background Core Data operation safely
    /// Use this instead of directly accessing backgroundContext
    func performSafeBackgroundTask<T>(_ operation: @escaping (NSManagedObjectContext) -> T) -> T? {
        var result: T?
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        context.performAndWait {
            result = operation(context)
        }
        
        return result
    }
    
    /// Perform background Core Data operation safely with completion
    func performSafeBackgroundTask(_ operation: @escaping (NSManagedObjectContext) -> Void, completion: @escaping () -> Void = {}) {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        context.perform {
            operation(context)
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    // DEPRECATED: Dynamic context switching can cause concurrency issues
    // Use viewContext or backgroundContext directly, or use performBackgroundTask
    var context: NSManagedObjectContext {
        // Always return viewContext to prevent object/context mismatches
        // Background operations should use performBackgroundTask instead
        return viewContext
    }
    
    // MARK: - Save Context
    
    func saveContext() {
        context.performAndWait {
            if context.hasChanges {
                do {
                    print("💾 About to save Core Data context with \(context.insertedObjects.count) insertions, \(context.updatedObjects.count) updates, \(context.deletedObjects.count) deletions")
                    try context.save()
                    print("✅ Core Data save successful")
                } catch {
                    print("❌ CRITICAL: Core Data save failed with error: \(error)")
                    print("❌ Error localizedDescription: \(error.localizedDescription)")
                    if let nsError = error as NSError? {
                        print("❌ Error domain: \(nsError.domain)")
                        print("❌ Error code: \(nsError.code)")
                        print("❌ Error userInfo: \(nsError.userInfo)")
                    }
                    // Use fatalError to get full crash details with the Core Data error
                    fatalError("Core Data save failed: \(error)")
                }
            } else {
                print("💾 No changes to save in Core Data context")
            }
        }
    }
    
    func saveContextWithReturn() -> Bool {
        var result = true
        context.performAndWait {
            if context.hasChanges {
                do {
                    try context.save()
                    result = true
                } catch {
                    print("Save error: \(error)")
                    result = false
                }
            }
        }
        return result
    }
    
    // MARK: - Background Operations
    
    func performBackgroundTask<T>(_ operation: @escaping (NSManagedObjectContext) throws -> T) -> T? {
        var result: T?
        var error: Error?
        
        backgroundContext.performAndWait {
            do {
                result = try operation(backgroundContext)
                if backgroundContext.hasChanges {
                    try backgroundContext.save()
                }
            } catch let operationError {
                error = operationError
                print("Background operation error: \(operationError)")
            }
        }
        
        if error != nil {
            return nil
        }
        return result
    }
    
    func performBackgroundTaskAsync<T>(_ operation: @escaping (NSManagedObjectContext) throws -> T, completion: @escaping (T?) -> Void) {
        // Create a NEW background context for each operation to prevent concurrent access issues
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        context.perform {
            do {
                let result = try operation(context)
                if context.hasChanges {
                    try context.save()
                }
                DispatchQueue.main.async {
                    completion(result)
                }
            } catch {
                print("Background async operation error: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    // MARK: - Band Operations
    
    func fetchBands() -> [Band] {
        var result: [Band] = []
        viewContext.performAndWait {
            // Temporarily disable automatic merges during fetch to prevent collection mutation
            let originalMergesSetting = viewContext.automaticallyMergesChangesFromParent
            viewContext.automaticallyMergesChangesFromParent = false
            
            defer {
                // Re-enable merges after fetch completes (even if error occurs)
                viewContext.automaticallyMergesChangesFromParent = originalMergesSetting
            }
            
            let request: NSFetchRequest<Band> = Band.fetchRequest()
            do {
                result = try viewContext.fetch(request)
            } catch {
                print("Fetch bands error: \(error)")
                result = []
            }
        }
        return result
    }
    
    func fetchBands(forYear year: Int32) -> [Band] {
        var result: [Band] = []
        viewContext.performAndWait {
            // Temporarily disable automatic merges during fetch to prevent collection mutation
            let originalMergesSetting = viewContext.automaticallyMergesChangesFromParent
            viewContext.automaticallyMergesChangesFromParent = false
            
            defer {
                // Re-enable merges after fetch completes (even if error occurs)
                viewContext.automaticallyMergesChangesFromParent = originalMergesSetting
            }
            
            let request: NSFetchRequest<Band> = Band.fetchRequest()
            request.predicate = NSPredicate(format: "eventYear == %d", year)
            do {
                result = try viewContext.fetch(request)
            } catch {
                print("Fetch bands for year error: \(error)")
                result = []
            }
        }
        return result
    }
    
    func fetchBand(byName name: String) -> Band? {
        var result: Band? = nil
        viewContext.performAndWait {
            // Temporarily disable automatic merges during fetch to prevent collection mutation
            let originalMergesSetting = viewContext.automaticallyMergesChangesFromParent
            viewContext.automaticallyMergesChangesFromParent = false
            
            defer {
                // Re-enable merges after fetch completes (even if error occurs)
                viewContext.automaticallyMergesChangesFromParent = originalMergesSetting
            }
            
            let request: NSFetchRequest<Band> = Band.fetchRequest()
            request.predicate = NSPredicate(format: "bandName == %@", name)
            request.fetchLimit = 1
            
            do {
                result = try viewContext.fetch(request).first
            } catch {
                print("Fetch band by name error: \(error)")
                result = nil
            }
        }
        return result
    }
    
    func fetchBand(byName name: String, eventYear: Int32) -> Band? {
        var result: Band? = nil
        context.performAndWait {
            let request: NSFetchRequest<Band> = Band.fetchRequest()
            request.predicate = NSPredicate(format: "bandName == %@ AND eventYear == %d", name, eventYear)
            request.fetchLimit = 1
            
            do {
                result = try context.fetch(request).first
            } catch {
                print("Fetch band by name and year error: \(error)")
                result = nil
            }
        }
        return result
    }
    
    func createBand(name: String) -> Band {
        let band = Band(context: context)
        band.bandName = name
        return band
    }
    
    // Private helper method without performAndWait for internal use
    private func _fetchBand(byName name: String, eventYear: Int32) -> Band? {
        let request: NSFetchRequest<Band> = Band.fetchRequest()
        request.predicate = NSPredicate(format: "bandName == %@ AND eventYear == %d", name, eventYear)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Internal fetch band by name and year error: \(error)")
            return nil
        }
    }
    
    func createOrUpdateBand(
        name: String,
        eventYear: Int32,
        officialSite: String? = nil,
        imageUrl: String? = nil,
        youtube: String? = nil,
        metalArchives: String? = nil,
        wikipedia: String? = nil,
        country: String? = nil,
        genre: String? = nil,
        noteworthy: String? = nil,
        priorYears: String? = nil
    ) -> Band {
        var resultBand: Band!
        context.performAndWait {
            // Try to find existing band first using name and year (internal method without performAndWait)
            let existingBand = _fetchBand(byName: name, eventYear: eventYear)
            let band = existingBand ?? Band(context: context)
            
            // Update all fields
            band.bandName = name
            band.eventYear = eventYear
            band.officialSite = officialSite
            band.imageUrl = imageUrl
            band.youtube = youtube
            band.metalArchives = metalArchives
            band.wikipedia = wikipedia
            band.country = country
            band.genre = genre
            band.noteworthy = noteworthy
            band.priorYears = priorYears
            
            // CRITICAL FIX: Load existing userPriority relationship to preserve priority data
            // This prevents priority data from being lost during CSV import/year changes
            if band.userPriority == nil {
                // Try to find existing priority data for this band (year-agnostic)
                let priorityRequest: NSFetchRequest<UserPriority> = UserPriority.fetchRequest()
                priorityRequest.predicate = NSPredicate(format: "band.bandName == %@", name)
                priorityRequest.fetchLimit = 1
                
                do {
                    if let existingPriority = try context.fetch(priorityRequest).first {
                        // Link the existing priority to this band
                        band.userPriority = existingPriority
                        existingPriority.band = band
                        print("🔄 [PRIORITY_PRESERVATION] Linked existing priority for band: \(name)")
                    }
                } catch {
                    print("❌ [PRIORITY_PRESERVATION] Error loading priority for \(name): \(error)")
                }
            }
            
            resultBand = band
        }
        return resultBand
    }
    
    func deleteBand(_ band: Band) {
        context.delete(band)
    }
    
    func deleteAllBands() {
        let request: NSFetchRequest<NSFetchRequestResult> = Band.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            print("Delete all bands error: \(error)")
        }
    }
    
    func clearAllData() {
        // Use background context for heavy deletion work to prevent blocking UI
        backgroundContext.performAndWait {
            print("🧹 CoreDataManager: Clearing year-specific data from Core Data")
            print("🚨 CRITICAL: UserPriority and UserAttendance records are NEVER deleted")
            print("🚨 UserPriority: year-agnostic user preferences (likes/dislikes)")
            print("🚨 UserAttendance: year-specific but should be preserved for historical records")
            
            // Use individual object deletion to properly handle relationships
            // This is slower but prevents crashes from dangling references
            
            // 1. PROTECTED: UserAttendance records are NEVER deleted
            // Attendance data represents historical records of what user attended
            // These should be preserved even when changing years
            print("🛡️ PROTECTED: UserAttendance records are preserved - historical attendance data")
            
            // 2. PROTECTED: UserPriority records are NEVER deleted
            // Priority data represents user preferences that are year-agnostic
            // If someone likes Dark Tranquillity in 2012, they should still like them in 2025
            print("🛡️ PROTECTED: UserPriority records are preserved - user preferences are year-agnostic")
            
            // 3. Delete Event records
            let eventRequest: NSFetchRequest<Event> = Event.fetchRequest()
            do {
                let events = try backgroundContext.fetch(eventRequest)
                for event in events {
                    backgroundContext.delete(event)
                }
                print("🧹 Deleted \(events.count) Event records")
            } catch {
                print("❌ Error fetching Events: \(error)")
            }
            
            // 4. Delete Band records (last, since others reference them)
            let bandRequest: NSFetchRequest<Band> = Band.fetchRequest()
            do {
                let bands = try backgroundContext.fetch(bandRequest)
                for band in bands {
                    backgroundContext.delete(band)
                }
                print("🧹 Deleted \(bands.count) Band records")
            } catch {
                print("❌ Error fetching Bands: \(error)")
            }
            
            // 5. CRITICAL FIX: Clean up any orphaned bands that might have been created
            // This prevents fake band entries for special events from persisting
            let orphanedBandRequest: NSFetchRequest<Band> = Band.fetchRequest()
            orphanedBandRequest.predicate = NSPredicate(format: "events.@count == 0")
            do {
                let orphanedBands = try backgroundContext.fetch(orphanedBandRequest)
                for band in orphanedBands {
                    backgroundContext.delete(band)
                }
                if !orphanedBands.isEmpty {
                    print("🧹 [CLEANUP] Deleted \(orphanedBands.count) orphaned bands with no events")
                }
            } catch {
                print("❌ Error cleaning up orphaned bands: \(error)")
            }
        }
    }
    
    /// Smart year change: Keep existing data, only check if target year data exists
    /// This eliminates unnecessary clearing and re-downloading of existing data
    func checkDataForYear(_ year: Int32) -> (hasEvents: Bool, hasBands: Bool) {
        return viewContext.performAndWait {
            // Check if we have events for this year
            let eventRequest: NSFetchRequest<Event> = Event.fetchRequest()
            eventRequest.predicate = NSPredicate(format: "eventYear == %d", year)
            eventRequest.fetchLimit = 1
            
            let eventCount = (try? viewContext.count(for: eventRequest)) ?? 0
            
            // Check if we have bands for this year  
            let bandRequest: NSFetchRequest<Band> = Band.fetchRequest()
            bandRequest.predicate = NSPredicate(format: "eventYear == %d", year)
            bandRequest.fetchLimit = 1
            
            let bandCount = (try? viewContext.count(for: bandRequest)) ?? 0
            
            print("📊 Year \(year) data check: \(eventCount > 0 ? "✅" : "❌") events, \(bandCount > 0 ? "✅" : "❌") bands")
            
            return (hasEvents: eventCount > 0, hasBands: bandCount > 0)
        }
    }
    
    /// Smart year change that preserves existing data and only downloads what's needed
    /// Returns whether downloads are needed for the target year
    func smartYearChange(to targetYear: Int32) -> (needsEventDownload: Bool, needsBandDownload: Bool) {
        let dataStatus = checkDataForYear(targetYear)
        
        print("🔄 Smart year change to \(targetYear):")
        print("   📊 Events: \(dataStatus.hasEvents ? "✅ Available" : "❌ Need download")")
        print("   📊 Bands: \(dataStatus.hasBands ? "✅ Available" : "❌ Need download")")
        
        // TODO: Add checksum comparison here to detect data changes on server
        // For now, assume data exists = no download needed
        
        if dataStatus.hasEvents && dataStatus.hasBands {
            print("🚀 Year \(targetYear): Using cached data, no downloads needed!")
        } else {
            print("📥 Year \(targetYear): Will download missing data")
        }
        
        return (needsEventDownload: !dataStatus.hasEvents, needsBandDownload: !dataStatus.hasBands)
    }
    
    /// DEPRECATED: Only use for complete app reset
    /// Year changes should NOT clear existing data - they should just query for the target year
    func clearYearSpecificData() {
        print("⚠️  DEPRECATED: clearYearSpecificData() called - this should only be used for app reset")
        print("⚠️  Year changes should use smart data management instead of clearing existing data")
        
        // For now, just disable the clearing to prevent data loss
        // This method can be removed once all year change logic is updated
        print("✅ Keeping all existing data - year changes now use smart filtering instead")
    }
    
    // MARK: - Event Operations
    
    func fetchEvents() -> [Event] {
        var result: [Event] = []
        viewContext.performAndWait {
            // Temporarily disable automatic merges during fetch to prevent collection mutation
            let originalMergesSetting = viewContext.automaticallyMergesChangesFromParent
            viewContext.automaticallyMergesChangesFromParent = false
            
            defer {
                // Re-enable merges after fetch completes (even if error occurs)
                viewContext.automaticallyMergesChangesFromParent = originalMergesSetting
            }
            
            let request: NSFetchRequest<Event> = Event.fetchRequest()
            do {
                result = try viewContext.fetch(request)
            } catch {
                print("Fetch events error: \(error)")
                result = []
            }
        }
        return result
    }
    
    func fetchEvents(forYear year: Int32) -> [Event] {
        var result: [Event] = []
        let maxRetries = 3
        var attempt = 0
        
        viewContext.performAndWait {
            // Temporarily disable automatic merges during fetch to prevent collection mutation
            let originalMergesSetting = viewContext.automaticallyMergesChangesFromParent
            viewContext.automaticallyMergesChangesFromParent = false
            
            defer {
                // Re-enable merges after fetch completes (even if error occurs)
                viewContext.automaticallyMergesChangesFromParent = originalMergesSetting
            }
            
            while attempt < maxRetries {
                do {
                    // Add defensive checks before fetch
                    guard viewContext.persistentStoreCoordinator != nil else {
                        print("ERROR: Core Data context has no persistent store coordinator")
                        break
                    }
                    
                    let request: NSFetchRequest<Event> = Event.fetchRequest()
                    request.predicate = NSPredicate(format: "eventYear == %d", year)
                    
                    result = try viewContext.fetch(request)
                    print("DEBUG: Successfully fetched \(result.count) events for year \(year) on attempt \(attempt + 1)")
                    break // Success, exit retry loop
                } catch {
                    attempt += 1
                    print("ERROR: Fetch events for year \(year) - attempt \(attempt) failed: \(error)")
                    
                    if attempt < maxRetries {
                        // Try to refresh the context on retry
                        viewContext.refreshAllObjects()
                        
                        // Exponential backoff: 0.1s, 0.2s, 0.4s
                        let delay = 0.1 * pow(2.0, Double(attempt - 1))
                        print("DEBUG: Retrying in \(delay) seconds...")
                        Thread.sleep(forTimeInterval: delay)
                    } else {
                        print("ERROR: All \(maxRetries) attempts failed for year \(year)")
                        result = []
                    }
                }
            }
        }
        return result
    }
    
    /// Fetch events with custom predicate (for filtering)
    func fetchEvents(forYear year: Int32, predicate: NSPredicate) -> [Event] {
        var result: [Event] = []
        let maxRetries = 3
        var attempt = 0
        
        viewContext.performAndWait {
            // Temporarily disable automatic merges during fetch to prevent collection mutation
            let originalMergesSetting = viewContext.automaticallyMergesChangesFromParent
            viewContext.automaticallyMergesChangesFromParent = false
            
            defer {
                // Re-enable merges after fetch completes (even if error occurs)
                viewContext.automaticallyMergesChangesFromParent = originalMergesSetting
            }
            
            while attempt < maxRetries {
                do {
                    // Add defensive checks before fetch
                    guard viewContext.persistentStoreCoordinator != nil else {
                        print("ERROR: Core Data context has no persistent store coordinator")
                        break
                    }
                    
                    let request: NSFetchRequest<Event> = Event.fetchRequest()
                    request.predicate = predicate
                    
                    result = try viewContext.fetch(request)
                    print("DEBUG: Successfully fetched \(result.count) events with predicate on attempt \(attempt + 1)")
                    break // Success, exit retry loop
                } catch {
                    attempt += 1
                    print("ERROR: Fetch events with predicate - attempt \(attempt) failed: \(error)")
                    
                    if attempt < maxRetries {
                        // Try to refresh the context on retry
                        viewContext.refreshAllObjects()
                        
                        // Exponential backoff: 0.1s, 0.2s, 0.4s
                        let delay = 0.1 * pow(2.0, Double(attempt - 1))
                        print("DEBUG: Retrying in \(delay) seconds...")
                        Thread.sleep(forTimeInterval: delay)
                    } else {
                        print("ERROR: All \(maxRetries) attempts failed for predicate fetch")
                        result = []
                    }
                }
            }
        }
        return result
    }
    
    func fetchEventsForBand(_ bandName: String, forYear year: Int32) -> [Event] {
        var result: [Event] = []
        let maxRetries = 3
        var attempt = 0
        
        viewContext.performAndWait {
            // Temporarily disable automatic merges during fetch to prevent collection mutation
            let originalMergesSetting = viewContext.automaticallyMergesChangesFromParent
            viewContext.automaticallyMergesChangesFromParent = false
            
            defer {
                // Re-enable merges after fetch completes (even if error occurs)
                viewContext.automaticallyMergesChangesFromParent = originalMergesSetting
            }
            
            while attempt < maxRetries {
                do {
                    // Add defensive checks before fetch
                    guard viewContext.persistentStoreCoordinator != nil else {
                        print("ERROR: Core Data context has no persistent store coordinator")
                        break
                    }
                    
                    let request: NSFetchRequest<Event> = Event.fetchRequest()
                    request.predicate = NSPredicate(format: "band.bandName == %@ AND eventYear == %d", bandName, year)
                    
                    result = try viewContext.fetch(request)
                    print("DEBUG: Successfully fetched \(result.count) events for band '\(bandName)' year \(year) on attempt \(attempt + 1)")
                    break // Success, exit retry loop
                } catch {
                    attempt += 1
                    print("ERROR: Fetch events for band '\(bandName)' year \(year) - attempt \(attempt) failed: \(error)")
                    
                    if attempt < maxRetries {
                        // Try to refresh the context on retry
                        viewContext.refreshAllObjects()
                        
                        // Exponential backoff: 0.1s, 0.2s, 0.4s
                        let delay = 0.1 * pow(2.0, Double(attempt - 1))
                        print("DEBUG: Retrying in \(delay) seconds...")
                        Thread.sleep(forTimeInterval: delay)
                    } else {
                        print("ERROR: All \(maxRetries) attempts failed for band '\(bandName)' year \(year)")
                        result = []
                    }
                }
            }
        }
        return result
    }
    
    func fetchEvent(byTimeIndex timeIndex: Double, eventName: String, forYear year: Int32) -> Event? {
        var result: Event?
        viewContext.performAndWait {
            // Temporarily disable automatic merges during fetch to prevent collection mutation
            let originalMergesSetting = viewContext.automaticallyMergesChangesFromParent
            viewContext.automaticallyMergesChangesFromParent = false
            
            defer {
                // Re-enable merges after fetch completes (even if error occurs)
                viewContext.automaticallyMergesChangesFromParent = originalMergesSetting
            }
            
            let request: NSFetchRequest<Event> = Event.fetchRequest()
            // For standalone events, we look for events where the event name matches and timeIndex matches
            // This handles cases where:
            // 1. eventType, location, or notes contain the event name
            // 2. band.bandName contains the event name (for fake bands created from standalone events)
            request.predicate = NSPredicate(format: "timeIndex == %lf AND eventYear == %d AND (eventType CONTAINS[cd] %@ OR location CONTAINS[cd] %@ OR band.bandName CONTAINS[cd] %@ OR notes CONTAINS[cd] %@)", timeIndex, year, eventName, eventName, eventName, eventName)
            request.fetchLimit = 1
            do {
                let results = try viewContext.fetch(request)
                result = results.first
                // Event found - return it (reduced logging for performance)
            } catch {
                print("Fetch event by timeIndex and name error: \(error)")
                result = nil
            }
        }
        return result
    }
    
    func createEvent(band: Band, location: String, startTime: String, eventType: String? = nil) -> Event {
        let event = Event(context: context)
        event.band = band
        event.location = location
        event.startTime = startTime
        event.eventType = eventType
        return event
    }
    
    func createOrUpdateEvent(
        band: Band,
        timeIndex: TimeInterval,
        endTimeIndex: TimeInterval? = nil,
        location: String,
        date: String? = nil,
        day: String? = nil,
        startTime: String? = nil,
        endTime: String? = nil,
        eventType: String? = nil,
        eventYear: Int32? = nil,
        notes: String? = nil,
        descriptionUrl: String? = nil,
        eventImageUrl: String? = nil
    ) -> Event {
        var resultEvent: Event!
        context.performAndWait {
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
                
                resultEvent = event
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
                resultEvent = event
            }
        }
        return resultEvent
    }
    
    func deleteEvent(_ event: Event) {
        context.delete(event)
    }
    
    func cleanupProblematicEvents(currentYear: Int) {
        viewContext.performAndWait {
            print("🧹 [CLEANUP_DEBUG] Starting cleanup for problematic events (currentYear: \(currentYear))")
            // CRITICAL DEBUG: Check unofficial events BEFORE cleanup
            let preCleanupRequest: NSFetchRequest<Event> = Event.fetchRequest()
            preCleanupRequest.predicate = NSPredicate(format: "eventType == 'Unofficial Event' OR eventType == 'Cruiser Organized'")
            
            var preCleanupUnofficial: [Event] = []
            do {
                preCleanupUnofficial = try viewContext.fetch(preCleanupRequest)
                print("🔧 [CLEANUP_DEBUG] BEFORE cleanup: \(preCleanupUnofficial.count) unofficial events in Core Data")
                for event in preCleanupUnofficial.prefix(3) {
                    print("🔧 [CLEANUP_DEBUG] - Before: '\(event.band?.bandName ?? "nil")' year=\(event.eventYear) type='\(event.eventType ?? "nil")'")
                }
            } catch {
                print("🔧 [CLEANUP_DEBUG] Error checking pre-cleanup unofficial events: \(error)")
            }
            
            let request: NSFetchRequest<Event> = Event.fetchRequest()
            // Clean up events from wrong years only - this should NOT affect current year events
            // CSV importers handle current year cleanup, this handles cross-year cleanup
            request.predicate = NSPredicate(format: "eventYear != %d AND eventYear != 0", Int32(currentYear))
            
            print("🔧 [CLEANUP_DEBUG] Cleanup query: eventYear != \(Int32(currentYear)) AND eventYear != 0")
            print("🔧 [CLEANUP_DEBUG] This will KEEP events with eventYear = \(Int32(currentYear)) or eventYear = 0")
            print("🔧 [CLEANUP_DEBUG] This will DELETE events from other years (not \(currentYear))")
            
            do {
                let problematicEvents = try viewContext.fetch(request)
                print("🧹 Found \(problematicEvents.count) events from wrong years to clean up (currentYear: \(currentYear))")
                
                // Log each event being deleted for debugging
                if problematicEvents.count > 0 {
                    print("🔧 [CLEANUP_DEBUG] Events that will be deleted:")
                    for event in problematicEvents.prefix(10) {
                        let eventType = event.eventType ?? "nil"
                        let bandName = event.band?.bandName ?? "nil"
                        print("🔧 [CLEANUP_DEBUG] - DELETE: '\(bandName)' year=\(event.eventYear) type='\(eventType)' (expected year: \(currentYear))")
                    }
                    if problematicEvents.count > 10 {
                        print("🔧 [CLEANUP_DEBUG] ... and \(problematicEvents.count - 10) more events")
                    }
                }
                
                for event in problematicEvents {
                    print("🧹 Deleting wrong-year event: '\(event.band?.bandName ?? "unknown")' year: \(event.eventYear) (expected: \(currentYear))")
                    viewContext.delete(event)
                }
                
                if problematicEvents.count > 0 {
                    try viewContext.save()
                    print("🧹 Cleaned up \(problematicEvents.count) wrong-year events")
                }
                
                // CRITICAL DEBUG: Check unofficial events AFTER cleanup
                let postCleanupUnofficial = try viewContext.fetch(preCleanupRequest)
                print("🔧 [CLEANUP_DEBUG] AFTER cleanup: \(postCleanupUnofficial.count) unofficial events in Core Data")
                if preCleanupUnofficial.count != postCleanupUnofficial.count {
                    print("🚨 [CLEANUP_DEBUG] UNOFFICIAL EVENTS DELETED! Before: \(preCleanupUnofficial.count) After: \(postCleanupUnofficial.count)")
                }
                
            } catch {
                print("Cleanup problematic events error: \(error)")
            }
        }
    }
    
    // MARK: - Cleanup Operations
    
    func removeDuplicateEvents() {
        backgroundContext.performAndWait {
            print("🧹 Starting duplicate event cleanup...")
            
            let request: NSFetchRequest<Event> = Event.fetchRequest()
            do {
                let allEvents = try backgroundContext.fetch(request)
                print("🧹 Found \(allEvents.count) total events")
                
                // Group events by unique key (bandName + timeIndex + eventYear)
                var eventGroups: [String: [Event]] = [:]
                
                for event in allEvents {
                    guard let bandName = event.band?.bandName else { continue }
                    let key = "\(bandName)|\(event.timeIndex)|\(event.eventYear)"
                    
                    if eventGroups[key] == nil {
                        eventGroups[key] = []
                    }
                    eventGroups[key]!.append(event)
                }
                
                // Find duplicates and keep only the newest one
                var deletedCount = 0
                for (key, events) in eventGroups {
                    if events.count > 1 {
                        // Sort by createdAt and keep the most recent
                        let sortedEvents = events.sorted { 
                            ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) 
                        }
                        
                        // Delete all but the first (most recent)
                        for i in 1..<sortedEvents.count {
                            backgroundContext.delete(sortedEvents[i])
                            deletedCount += 1
                        }
                        
                        if events.count > 5 { // Only log if many duplicates
                            print("🧹 Removed \(events.count - 1) duplicates for: \(key)")
                        }
                    }
                }
                
                // Save changes
                if deletedCount > 0 {
                    try backgroundContext.save()
                    print("🧹 ✅ Successfully removed \(deletedCount) duplicate events")
                } else {
                    print("🧹 ✅ No duplicates found")
                }
                
            } catch {
                print("❌ Error cleaning up duplicates: \(error)")
            }
        }
    }
    
    // MARK: - Priority Operations
    
    func fetchUserPriorities() -> [UserPriority] {
        var result: [UserPriority] = []
        viewContext.performAndWait {
            // Temporarily disable automatic merges during fetch to prevent collection mutation
            let originalMergesSetting = viewContext.automaticallyMergesChangesFromParent
            viewContext.automaticallyMergesChangesFromParent = false
            
            defer {
                // Re-enable merges after fetch completes (even if error occurs)
                viewContext.automaticallyMergesChangesFromParent = originalMergesSetting
            }
            
            let request: NSFetchRequest<UserPriority> = UserPriority.fetchRequest()
            
            do {
                result = try viewContext.fetch(request)
            } catch {
                print("❌ Error fetching user priorities: \(error)")
                result = []
            }
        }
        return result
    }
    
    func createUserPriority(band: Band, priority: Int16, lastModified: Double? = nil) -> UserPriority {
        let userPriority = UserPriority(context: context)
        userPriority.band = band
        userPriority.priorityLevel = priority
        userPriority.createdAt = Date()
        userPriority.updatedAt = Date()
        return userPriority
    }
    
    // MARK: - Attendance Operations
    
    func fetchUserAttendances() -> [UserAttendance] {
        var result: [UserAttendance] = []
        viewContext.performAndWait {
            // Temporarily disable automatic merges during fetch to prevent collection mutation
            let originalMergesSetting = viewContext.automaticallyMergesChangesFromParent
            viewContext.automaticallyMergesChangesFromParent = false
            
            defer {
                // Re-enable merges after fetch completes (even if error occurs)
                viewContext.automaticallyMergesChangesFromParent = originalMergesSetting
            }
            
            let request: NSFetchRequest<UserAttendance> = UserAttendance.fetchRequest()
            
            do {
                result = try viewContext.fetch(request)
            } catch {
                print("❌ Error fetching user attendances: \(error)")
                result = []
            }
        }
        return result
    }
    
    func createUserAttendance(event: Event, status: Int16, lastModified: Double? = nil) -> UserAttendance {
        let userAttendance = UserAttendance(context: context)
        userAttendance.event = event
        userAttendance.attendanceStatus = status
        userAttendance.eventYear = event.eventYear
        userAttendance.createdAt = Date()
        userAttendance.updatedAt = Date()
        
        // CRITICAL: Set the index field for iCloud restoration
        userAttendance.index = "\(event.band?.bandName ?? ""):\(event.location ?? ""):\(event.startTime ?? ""):\(event.eventType ?? ""):\(event.eventYear)"
        
        return userAttendance
    }
}

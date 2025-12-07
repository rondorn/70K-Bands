//
//  CoreDataPreloadManager.swift
//  70000TonsBands
//
//  Core Data-driven preload system that monitors data changes and triggers targeted cache updates
//  Waits for Core Data to have data before starting, then provides immediate display with incremental updates
//

import Foundation
import CoreData
import UIKit

protocol CoreDataPreloadManagerDelegate: AnyObject {
    func preloadManager(_ manager: CoreDataPreloadManager, didLoadInitialData bandCount: Int)
    func preloadManager(_ manager: CoreDataPreloadManager, didUpdateData changeType: CoreDataPreloadManager.ChangeType)
    func preloadManager(_ manager: CoreDataPreloadManager, didCompleteYearChange newYear: Int)
}

class CoreDataPreloadManager {
    static let shared = CoreDataPreloadManager()
    
    // MARK: - Types
    
    enum ChangeType {
        case bandsUpdated(added: Int, modified: Int, deleted: Int)
        case eventsUpdated(added: Int, modified: Int, deleted: Int)  
        case prioritiesUpdated(count: Int)
        case attendanceUpdated(count: Int)
        case fullRefresh
    }
    
    enum LoadState {
        case waiting          // Waiting for Core Data to have bands
        case loading         // Loading initial data
        case ready           // Ready with data, monitoring for changes
        case yearChanging    // Performing year change (full refresh)
    }
    
    // MARK: - Properties
    
    weak var delegate: CoreDataPreloadManagerDelegate?
    private(set) var loadState: LoadState = .waiting
    
    // CRITICAL: Lazy initialization to prevent triggering Core Data on first launch
    // Core Data should ONLY be initialized when migration is needed
    private lazy var coreDataManager = CoreDataManager.shared
    private let cellCache = CellDataCache.shared
    
    // Monitoring
    private var bandsObserver: NSObjectProtocol?
    private var eventsObserver: NSObjectProtocol?
    private var prioritiesObserver: NSObjectProtocol?
    private var attendanceObserver: NSObjectProtocol?
    
    // State tracking
    private var currentEventYear: Int32 = 0
    private var lastBandCount: Int = 0
    private var lastEventCount: Int = 0
    private var isSuspended: Bool = false  // Flag to temporarily suspend monitoring during bulk operations
    private var isUsingSQLite: Bool {
        // Check if DataManager is using SQLite backend
        return DataManager.shared is SQLiteDataManager
    }
    private var isMonitoring = false
    
    // Polling control to prevent infinite loops
    private var pollingAttempts = 0
    private var maxPollingAttempts = 10 // Stop after 20 seconds (10 attempts × 2 seconds)
    private var lastPollingTime: Date = Date.distantPast
    
    // Queue for coordinated updates
    private let updateQueue = DispatchQueue(label: "coredata.preload.updates", qos: .userInitiated)
    
    // MARK: - Initialization
    
    private init() {
        currentEventYear = Int32(eventYear)
        print("🔄 CoreDataPreloadManager initialized for year \(currentEventYear)")
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Interface
    
    /// Start the preload system - will wait for Core Data to have bands before proceeding
    func start(delegate: CoreDataPreloadManagerDelegate) {
        self.delegate = delegate
        
        // Reset polling counters when starting
        resetPollingCounters()
        
        updateQueue.async { [weak self] in
            self?.checkInitialDataAndStart()
        }
    }
    
    /// Force a year change - clears everything and rebuilds
    func performYearChange(newYear: Int) {
        print("🔄 CoreDataPreloadManager: Starting year change from \(currentEventYear) to \(newYear)")
        
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.loadState = .yearChanging
            self.stopMonitoring()
            
            // Clear cache
            self.cellCache.clearCache()
            
            // Reset polling counters for year change
            self.resetPollingCounters()
            
            // Update year
            self.currentEventYear = Int32(newYear)
            
            // Restart the whole process
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.checkInitialDataAndStart()
                
                DispatchQueue.main.async {
                    self.delegate?.preloadManager(self, didCompleteYearChange: newYear)
                }
            }
        }
    }
    
    /// Manually trigger a targeted refresh for specific band
    func refreshBand(_ bandName: String) {
        updateQueue.async { [weak self] in
            self?.performIncrementalUpdate(for: bandName)
        }
    }
    
    /// Reset polling and restart if we were stuck in cache-only mode
    /// Call this when fresh data becomes available (e.g., after network comes back)
    func resetAndRestartIfNeeded() {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            // If we're currently in a waiting state due to max polling attempts, try again
            if self.loadState == .ready && self.pollingAttempts >= self.maxPollingAttempts {
                print("🔄 CoreDataPreloadManager: Network may be back - resetting polling and trying again")
                self.resetPollingCounters()
                self.checkInitialDataAndStart()
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func resetPollingCounters() {
        pollingAttempts = 0
        lastPollingTime = Date.distantPast
        print("🔄 CoreDataPreloadManager: Reset polling counters")
    }
    
    /// Gentle background check for Core Data sync (non-aggressive)
    private func performLazyCoreDatasync() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let bandCount = self.coreDataManager.getBandCount(for: self.currentEventYear)
            if bandCount > 0 {
                print("✅ CoreDataPreloadManager: Lazy sync complete - Core Data now has \(bandCount) bands")
                // Already marked as ready, just log success
            } else {
                print("🔄 CoreDataPreloadManager: Lazy sync - Core Data still empty, but continuing with memory data")
                // Don't restart aggressive polling - we're working fine with memory
            }
        }
    }
    
    // MARK: - Private Implementation
    
    private func checkInitialDataAndStart() {
        pollingAttempts += 1
        let timeSinceLastPoll = Date().timeIntervalSince(lastPollingTime)
        lastPollingTime = Date()
        
        print("🔄 CoreDataPreloadManager: Checking for initial data... (attempt \(pollingAttempts)/\(maxPollingAttempts))")
        
        // CORE DATA FIX: Must call Core Data from main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Check if we have bands in Core Data (on main thread)
            let bandCount = self.coreDataManager.getBandCount(for: self.currentEventYear)
            
            // IMPORT DEBUG: Also check if data is being loaded elsewhere
            let isLoadingBandData = isLoadingBandData // Global flag
            let bandNamesInMemory = bandNamesHandler.shared.getBandNames().count
            
            print("🔄 CoreDataPreloadManager: Core Data bands: \(bandCount), Memory bands: \(bandNamesInMemory), Loading: \(isLoadingBandData)")
            
            if bandCount == 0 {
                print("🔄 CoreDataPreloadManager: No bands found (attempt \(self.pollingAttempts)/\(self.maxPollingAttempts))")
                
                // FOREGROUND REFRESH FIX: If we have memory data, the import is likely in progress
                // Don't aggressively poll - just wait for the proper notification
                if bandNamesInMemory > 0 {
                    print("🔄 CoreDataPreloadManager: Found \(bandNamesInMemory) bands in memory - Core Data import in progress")
                    print("🔄 CoreDataPreloadManager: Using memory data immediately, will sync with Core Data later")
                    
                    // Use memory data immediately and mark as ready
                    self.loadState = .ready
                    self.delegate?.preloadManager(self, didLoadInitialData: bandNamesInMemory)
                    
                    // Set up a gentle background check for Core Data sync (non-aggressive)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self] in
                        self?.performLazyCoreDatasync()
                    }
                    return
                }
                
                // Only poll aggressively if we have NO data anywhere
                if self.pollingAttempts >= self.maxPollingAttempts {
                    print("⚠️ CoreDataPreloadManager: STOPPING POLLING after \(self.pollingAttempts) attempts")
                    print("⚠️ CoreDataPreloadManager: No data found in memory or Core Data")
                    self.loadState = .ready
                    self.delegate?.preloadManager(self, didLoadInitialData: 0)
                    return
                }
                
                self.loadState = .waiting
                
                // Only continue aggressive polling if we have no data at all
                let delay = min(5.0, 10.0) // Reduce polling frequency
                print("🔄 CoreDataPreloadManager: Scheduling retry in \(delay) seconds...")
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.updateQueue.async {
                        self?.checkInitialDataAndStart()
                    }
                }
                return
            }
            
            print("✅ CoreDataPreloadManager: Found \(bandCount) bands after \(self.pollingAttempts) attempts, starting preload...")
            self.loadState = .loading
            
            // Reset polling counters since we found data
            self.pollingAttempts = 0
            
            // Load initial data immediately (on main thread)
            self.performInitialLoad()
        }
    }
    
    private func performInitialLoad() {
        // CORE DATA FIX: This method must be called on main thread
        assert(Thread.isMainThread, "performInitialLoad must be called on main thread")
        
        print("🚀 CoreDataPreloadManager: Loading initial data from Core Data...")
        
        // Get all bands from Core Data for current year (on main thread)
        let bands = coreDataManager.getAllBands(for: currentEventYear)
        lastBandCount = bands.count
        
        // Get events (on main thread)
        let events = coreDataManager.getAllEvents(for: currentEventYear)
        lastEventCount = events.count
        
        print("📊 CoreDataPreloadManager: Loaded \(bands.count) bands, \(events.count) events")
        
        // Configure cell cache with current data (main thread is fine)
        configureCellCacheForCoreData()
        
        // Build initial cache from Core Data
        let bandNames = bands.map { $0.bandName ?? "" }
        
        // Move cache building to background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.cellCache.rebuildCache(from: bandNames, sortBy: getSortedBy(), reason: "Initial Core Data load") {
                print("✅ CoreDataPreloadManager: Initial cache build complete")
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.loadState = .ready
                    self.startMonitoring()
                    self.delegate?.preloadManager(self, didLoadInitialData: self.lastBandCount)
                }
            }
        }
    }
    
    private func configureCellCacheForCoreData() {
        // Configure cache with data handlers that work with Core Data
        // This integrates with the existing CellDataCache system
        cellCache.configure(
            schedule: scheduleHandler.shared,
            dataHandle: dataHandler(), 
            priorityManager: PriorityManager(),
            attendedHandle: ShowsAttended()
        )
    }
    
    private func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        print("👀 CoreDataPreloadManager: Starting Core Data change monitoring")
        
        let context = coreDataManager.viewContext
        
        // Monitor band changes
        bandsObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: context,
            queue: .main
        ) { [weak self] notification in
            self?.handleCoreDataChange(notification, entityName: "Band")
        }
        
        // Monitor event changes  
        eventsObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: context,
            queue: .main
        ) { [weak self] notification in
            self?.handleCoreDataChange(notification, entityName: "Event")
        }
        
        // Monitor priority changes
        prioritiesObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: context,
            queue: .main
        ) { [weak self] notification in
            self?.handleCoreDataChange(notification, entityName: "Priority")
        }
        
        // Monitor attendance changes
        attendanceObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: context,
            queue: .main
        ) { [weak self] notification in
            self?.handleCoreDataChange(notification, entityName: "AttendedStatus")
        }
    }
    
    private func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        
        print("🛑 CoreDataPreloadManager: Stopping Core Data change monitoring")
        
        [bandsObserver, eventsObserver, prioritiesObserver, attendanceObserver].forEach {
            if let observer = $0 {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        
        bandsObserver = nil
        eventsObserver = nil
        prioritiesObserver = nil
        attendanceObserver = nil
    }
    
    private func handleCoreDataChange(_ notification: Notification, entityName: String) {
        guard loadState == .ready else { return }
        
        // Skip if monitoring is suspended (during bulk operations)
        guard !isSuspended else { return }
        
        // Skip Core Data monitoring entirely when using SQLite backend
        // (temporary NSManagedObjects from SQLite cause spurious notifications)
        guard !isUsingSQLite else {
            print("🔇 CoreDataPreloadManager: Ignoring Core Data change (using SQLite backend)")
            return
        }
        
        // CORE DATA FIX: Process changes on main thread where managed objects are safe to access
        DispatchQueue.main.async { [weak self] in
            self?.processCoreDataChange(notification, entityName: entityName)
        }
    }
    
    // MARK: - Suspension Control
    
    /// Temporarily suspend monitoring during bulk operations to prevent flooding of change notifications
    func suspendMonitoring() {
        print("⏸️ CoreDataPreloadManager: Monitoring suspended for bulk operation")
        isSuspended = true
    }
    
    /// Resume monitoring after bulk operations complete, triggering a UI refresh
    func resumeMonitoring() {
        print("▶️ CoreDataPreloadManager: Monitoring resumed (with notification)")
        isSuspended = false
        
        // Trigger a refresh by posting a notification (more reliable than delegate during startup)
        DispatchQueue.main.async {
            print("📢 CoreDataPreloadManager: Posting bandNamesCacheReady notification for UI refresh")
            NotificationCenter.default.post(name: NSNotification.Name("bandNamesCacheReady"), object: nil)
        }
    }
    
    /// Resume monitoring silently without triggering notifications (let completion handler handle refresh)
    func resumeMonitoringSilently() {
        print("▶️ CoreDataPreloadManager: Monitoring resumed (silent mode)")
        isSuspended = false
    }
    
    private func processCoreDataChange(_ notification: Notification, entityName: String) {
        guard let userInfo = notification.userInfo else { return }
        
        let inserted = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
        let updated = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
        let deleted = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []
        
        // Filter for the entity we care about and current year
        let relevantInserted = filterObjectsForCurrentYear(inserted, entityName: entityName)
        let relevantUpdated = filterObjectsForCurrentYear(updated, entityName: entityName)
        let relevantDeleted = filterObjectsForCurrentYear(deleted, entityName: entityName)
        
        if relevantInserted.isEmpty && relevantUpdated.isEmpty && relevantDeleted.isEmpty {
            return // No relevant changes
        }
        
        print("📝 CoreDataPreloadManager: \(entityName) changes - inserted: \(relevantInserted.count), updated: \(relevantUpdated.count), deleted: \(relevantDeleted.count)")
        
        // Perform incremental update
        switch entityName {
        case "Band":
            handleBandChanges(inserted: relevantInserted, updated: relevantUpdated, deleted: relevantDeleted)
        case "Event":
            handleEventChanges(inserted: relevantInserted, updated: relevantUpdated, deleted: relevantDeleted)
        case "Priority":
            handlePriorityChanges(inserted: relevantInserted, updated: relevantUpdated, deleted: relevantDeleted)
        case "AttendedStatus":
            handleAttendanceChanges(inserted: relevantInserted, updated: relevantUpdated, deleted: relevantDeleted)
        default:
            break
        }
    }
    
    private func filterObjectsForCurrentYear(_ objects: Set<NSManagedObject>, entityName: String) -> [NSManagedObject] {
        return objects.compactMap { object in
            // Check if object belongs to current year
            switch entityName {
            case "Band":
                if let band = object as? Band, band.eventYear == currentEventYear {
                    return band
                }
            case "Event":
                if let event = object as? Event, event.eventYear == currentEventYear {
                    return event
                }
            case "Priority", "AttendedStatus":
                // These might not have eventYear directly, but are related to bands/events
                return object
            default:
                break
            }
            return nil
        }
    }
    
    private func handleBandChanges(inserted: [NSManagedObject], updated: [NSManagedObject], deleted: [NSManagedObject]) {
        // Update cache for affected bands
        let affectedBandNames = Set((inserted + updated + deleted).compactMap { obj in
            (obj as? Band)?.bandName
        })
        
        for bandName in affectedBandNames {
            performIncrementalUpdate(for: bandName)
        }
        
        // Notify delegate
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let changeType = ChangeType.bandsUpdated(
                added: inserted.count,
                modified: updated.count, 
                deleted: deleted.count
            )
            self.delegate?.preloadManager(self, didUpdateData: changeType)
        }
    }
    
    private func handleEventChanges(inserted: [NSManagedObject], updated: [NSManagedObject], deleted: [NSManagedObject]) {
        // Events affect display of related bands
        let affectedBands = Set((inserted + updated + deleted).compactMap { obj -> String? in
            (obj as? Event)?.band?.bandName
        })
        
        for bandName in affectedBands {
            performIncrementalUpdate(for: bandName)
        }
        
        // Notify delegate
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let changeType = ChangeType.eventsUpdated(
                added: inserted.count,
                modified: updated.count,
                deleted: deleted.count
            )
            self.delegate?.preloadManager(self, didUpdateData: changeType)
        }
    }
    
    private func handlePriorityChanges(inserted: [NSManagedObject], updated: [NSManagedObject], deleted: [NSManagedObject]) {
        // Priority changes affect cache display
        cellCache.markForPriorityUpdate()
        
        // Notify delegate
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let changeType = ChangeType.prioritiesUpdated(count: inserted.count + updated.count + deleted.count)
            self.delegate?.preloadManager(self, didUpdateData: changeType)
        }
    }
    
    private func handleAttendanceChanges(inserted: [NSManagedObject], updated: [NSManagedObject], deleted: [NSManagedObject]) {
        // Attendance changes affect cache display
        cellCache.markForAttendanceUpdate()
        
        // Notify delegate  
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let changeType = ChangeType.attendanceUpdated(count: inserted.count + updated.count + deleted.count)
            self.delegate?.preloadManager(self, didUpdateData: changeType)
        }
    }
    
    private func performIncrementalUpdate(for bandName: String) {
        print("🔄 CoreDataPreloadManager: Incremental update for band: \(bandName)")
        
        // Update single band in cache
        cellCache.updateCacheForBand(bandName) {
            print("✅ CoreDataPreloadManager: Updated cache for \(bandName)")
        }
    }
}

// MARK: - Extensions

extension CoreDataManager {
    
    /// Get count of bands for specific year
    func getBandCount(for year: Int32) -> Int {
        // CORE DATA FIX: Must be called on main thread
        assert(Thread.isMainThread, "getBandCount must be called on main thread")
        
        let request: NSFetchRequest<Band> = Band.fetchRequest()
        request.predicate = NSPredicate(format: "eventYear == %d", year)
        
        do {
            return try viewContext.count(for: request)
        } catch {
            print("❌ Error getting band count: \(error)")
            return 0
        }
    }
    
    /// Get all bands for specific year
    func getAllBands(for year: Int32) -> [Band] {
        // CORE DATA FIX: Must be called on main thread
        assert(Thread.isMainThread, "getAllBands must be called on main thread")
        
        let request: NSFetchRequest<Band> = Band.fetchRequest()
        request.predicate = NSPredicate(format: "eventYear == %d", year)
        request.sortDescriptors = [NSSortDescriptor(key: "bandName", ascending: true)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("❌ Error fetching bands: \(error)")
            return []
        }
    }
    
    /// Get all events for specific year
    func getAllEvents(for year: Int32) -> [Event] {
        // CORE DATA FIX: Must be called on main thread
        assert(Thread.isMainThread, "getAllEvents must be called on main thread")
        
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "eventYear == %d", year)
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: true)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("❌ Error fetching events: \(error)")
            return []
        }
    }
}

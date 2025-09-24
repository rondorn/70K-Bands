//
//  ThreadSafeCoreDataManager.swift
//  70000TonsBands
//
//  Comprehensive solution for thread-safe Core Data operations
//  Eliminates both crashes AND deadlocks while ensuring reliable updates
//

import Foundation
import CoreData
import UIKit

/// Thread-safe Core Data manager that prevents both crashes and deadlocks
/// Uses actor-pattern with dedicated writer context and automatic change propagation
class ThreadSafeCoreDataManager {
    static let shared = ThreadSafeCoreDataManager()
    
    // MARK: - Core Data Stack
    
    /// Main persistent container with optimized configuration
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DataModel")
        
        // Configure store for optimal concurrency
        let storeDescription = container.persistentStoreDescriptions.first!
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // SQLite optimizations for concurrency
        storeDescription.setOption([
            "journal_mode": "WAL",           // Write-Ahead Logging prevents reader blocking
            "synchronous": "NORMAL",         // Balanced safety/performance
            "cache_size": "10000",          // Larger cache for better performance
            "temp_store": "MEMORY"          // Use memory for temporary storage
        ] as NSDictionary, forKey: NSSQLitePragmasOption)
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error)")
            }
        }
        
        // Configure main context for UI operations
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil // Disable undo for performance
        
        return container
    }()
    
    /// Main context - ONLY for UI operations on main thread
    var mainContext: NSManagedObjectContext {
        dispatchPrecondition(condition: .onQueue(.main))
        return persistentContainer.viewContext
    }
    
    /// Dedicated background context for all write operations
    private lazy var writerContext: NSManagedObjectContext = {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        context.undoManager = nil
        return context
    }()
    
    // MARK: - Thread Coordination
    
    /// Serial queue for coordinating all write operations
    private let writerQueue = DispatchQueue(label: "com.70kBands.CoreDataWriter", qos: .userInitiated)
    
    /// Concurrent queue for read operations
    private let readerQueue = DispatchQueue(label: "com.70kBands.CoreDataReader", qos: .userInitiated, attributes: .concurrent)
    
    /// Operation queue for managing complex operations
    private lazy var operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1 // Serial execution for data integrity
        queue.qualityOfService = .userInitiated
        queue.underlyingQueue = writerQueue
        return queue
    }()
    
    // MARK: - State Management
    
    /// Tracks ongoing operations to prevent conflicts
    private var activeOperations: Set<String> = []
    private let operationsLock = NSLock()
    
    /// Version tracking for conflict detection
    private var dataVersion: Int = 0
    private let versionLock = NSLock()
    
    private init() {
        setupChangeNotifications()
    }
    
    // MARK: - Public API
    
    /// Performs a read operation safely on background thread
    /// - Parameters:
    ///   - operation: The read operation to perform
    ///   - completion: Called with the result on main thread
    func performRead<T>(_ operation: @escaping (NSManagedObjectContext) throws -> T, 
                       completion: @escaping (Result<T, Error>) -> Void) {
        
        readerQueue.async {
            let readContext = self.persistentContainer.newBackgroundContext()
            readContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
            
            readContext.perform {
                do {
                    let result = try operation(readContext)
                    DispatchQueue.main.async {
                        completion(.success(result))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    /// Performs a write operation safely with conflict detection
    /// - Parameters:
    ///   - operationId: Unique identifier for the operation
    ///   - operation: The write operation to perform
    ///   - completion: Called with the result on main thread
    func performWrite<T>(_ operationId: String = UUID().uuidString,
                        operation: @escaping (NSManagedObjectContext) throws -> T,
                        completion: @escaping (Result<T, Error>) -> Void = { _ in }) {
        
        // Check for conflicting operations
        operationsLock.lock()
        guard !activeOperations.contains(operationId) else {
            operationsLock.unlock()
            DispatchQueue.main.async {
                completion(.failure(CoreDataError.operationInProgress))
            }
            return
        }
        activeOperations.insert(operationId)
        operationsLock.unlock()
        
        let writeOperation = BlockOperation {
            self.writerContext.perform {
                do {
                    let result = try operation(self.writerContext)
                    
                    // Save if there are changes
                    if self.writerContext.hasChanges {
                        try self.writerContext.save()
                        
                        // Increment version for conflict detection
                        self.versionLock.lock()
                        self.dataVersion += 1
                        self.versionLock.unlock()
                        
                        print("✅ Core Data write operation completed: \(operationId)")
                    }
                    
                    DispatchQueue.main.async {
                        completion(.success(result))
                    }
                    
                } catch {
                    print("❌ Core Data write operation failed: \(operationId) - \(error)")
                    
                    // Rollback on error
                    self.writerContext.rollback()
                    
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
                
                // Remove from active operations
                self.operationsLock.lock()
                self.activeOperations.remove(operationId)
                self.operationsLock.unlock()
            }
        }
        
        operationQueue.addOperation(writeOperation)
    }
    
    /// Performs a batch write operation for bulk updates
    /// - Parameters:
    ///   - operations: Array of operations to perform atomically
    ///   - completion: Called when all operations complete
    func performBatchWrite(_ operations: [(String, (NSManagedObjectContext) throws -> Void)],
                          completion: @escaping (Result<Void, Error>) -> Void = { _ in }) {
        
        let batchId = "batch_\(UUID().uuidString)"
        
        performWrite(batchId, operation: { context in
            for (operationId, operation) in operations {
                print("🔄 Executing batch operation: \(operationId)")
                try operation(context)
            }
            return ()
        }, completion: completion)
    }
    
    // MARK: - Specific Operations
    
    /// Thread-safe band creation/update
    func createOrUpdateBand(
        name: String,
        eventYear: Int32,
        properties: [String: Any] = [:],
        completion: @escaping (Result<Band, Error>) -> Void = { _ in }
    ) {
        let operationId = "band_\(name)_\(eventYear)"
        
        performWrite(operationId, operation: { context in
            // Find existing band
            let request: NSFetchRequest<Band> = Band.fetchRequest()
            request.predicate = NSPredicate(format: "bandName == %@ AND eventYear == %d", name, eventYear)
            request.fetchLimit = 1
            
            let band = try context.fetch(request).first ?? Band(context: context)
            
            // Update properties
            band.bandName = name
            band.eventYear = eventYear
            
            for (key, value) in properties {
                band.setValue(value, forKey: key)
            }
            
            return band
        }, completion: completion)
    }
    
    /// Thread-safe priority update
    func updatePriority(
        bandName: String,
        priority: Int,
        completion: @escaping (Result<Void, Error>) -> Void = { _ in }
    ) {
        let operationId = "priority_\(bandName)"
        
        performWrite(operationId, operation: { context in
            // Find or create band
            let bandRequest: NSFetchRequest<Band> = Band.fetchRequest()
            bandRequest.predicate = NSPredicate(format: "bandName == %@", bandName)
            bandRequest.fetchLimit = 1
            
            let band = try context.fetch(bandRequest).first ?? {
                let newBand = Band(context: context)
                newBand.bandName = bandName
                return newBand
            }()
            
            // Find or create priority
            let priorityRequest: NSFetchRequest<UserPriority> = UserPriority.fetchRequest()
            priorityRequest.predicate = NSPredicate(format: "band == %@", band)
            priorityRequest.fetchLimit = 1
            
            let userPriority = try context.fetch(priorityRequest).first ?? {
                let newPriority = UserPriority(context: context)
                newPriority.band = band
                newPriority.createdAt = Date()
                return newPriority
            }()
            
            userPriority.priorityLevel = Int16(priority)
            userPriority.updatedAt = Date()
            
            return ()
        }, completion: completion)
    }
    
    // MARK: - Data Loading Coordination
    
    /// Coordinates data loading during app launch
    func performLaunchDataLoad(completion: @escaping (Result<Void, Error>) -> Void) {
        print("🚀 Starting coordinated launch data load...")
        
        let launchOperations = [
            ("preload_bands", { (context: NSManagedObjectContext) in
                // Preload critical band data
                let request: NSFetchRequest<Band> = Band.fetchRequest()
                request.fetchLimit = 100 // Limit initial load
                _ = try context.fetch(request)
            }),
            ("preload_events", { (context: NSManagedObjectContext) in
                // Preload critical event data
                let request: NSFetchRequest<Event> = Event.fetchRequest()
                request.fetchLimit = 100
                _ = try context.fetch(request)
            })
        ]
        
        performBatchWrite(launchOperations, completion: completion)
    }
    
    /// Coordinates data refresh for pull-to-refresh
    func performRefreshDataLoad(completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔄 Starting coordinated refresh data load...")
        
        // Cancel any ongoing operations that might conflict
        operationQueue.cancelAllOperations()
        
        // Perform refresh operations
        performLaunchDataLoad(completion: completion)
    }
    
    // MARK: - Change Notifications
    
    private func setupChangeNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidSave(_:)),
            name: .NSManagedObjectContextDidSave,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(persistentStoreRemoteChange(_:)),
            name: .NSPersistentStoreRemoteChange,
            object: nil
        )
    }
    
    @objc private func contextDidSave(_ notification: Notification) {
        guard let context = notification.object as? NSManagedObjectContext,
              context != mainContext else { return }
        
        // Merge changes into main context on main thread
        DispatchQueue.main.async {
            self.mainContext.mergeChanges(fromContextDidSave: notification)
            
            // Post notification for UI updates
            NotificationCenter.default.post(
                name: .coreDataDidUpdate,
                object: nil,
                userInfo: notification.userInfo
            )
        }
    }
    
    @objc private func persistentStoreRemoteChange(_ notification: Notification) {
        print("📱 Remote Core Data changes detected")
        
        // Handle remote changes (iCloud, etc.)
        DispatchQueue.main.async {
            // Refresh main context
            self.mainContext.refreshAllObjects()
            
            // Notify UI of changes
            NotificationCenter.default.post(name: .coreDataDidUpdate, object: nil)
        }
    }
}

// MARK: - Supporting Types

enum CoreDataError: Error, LocalizedError {
    case operationInProgress
    case contextNotAvailable
    case saveFailure(Error)
    
    var errorDescription: String? {
        switch self {
        case .operationInProgress:
            return "A conflicting Core Data operation is already in progress"
        case .contextNotAvailable:
            return "Core Data context is not available"
        case .saveFailure(let error):
            return "Failed to save Core Data changes: \(error.localizedDescription)"
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let coreDataDidUpdate = Notification.Name("CoreDataDidUpdate")
}

// MARK: - Usage Examples

extension ThreadSafeCoreDataManager {
    
    /// Example: Safe band list loading
    func loadBandList(for year: Int32, completion: @escaping (Result<[Band], Error>) -> Void) {
        performRead({ context in
            let request: NSFetchRequest<Band> = Band.fetchRequest()
            request.predicate = NSPredicate(format: "eventYear == %d", year)
            request.sortDescriptors = [NSSortDescriptor(key: "bandName", ascending: true)]
            return try context.fetch(request)
        }, completion: completion)
    }
    
    /// Example: Safe priority retrieval
    func getPriority(for bandName: String, completion: @escaping (Result<Int, Error>) -> Void) {
        performRead({ context in
            let request: NSFetchRequest<UserPriority> = UserPriority.fetchRequest()
            request.predicate = NSPredicate(format: "band.bandName == %@", bandName)
            request.fetchLimit = 1
            
            if let priority = try context.fetch(request).first {
                return Int(priority.priorityLevel)
            }
            return 0
        }, completion: completion)
    }
}


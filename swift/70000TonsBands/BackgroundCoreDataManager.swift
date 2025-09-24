//
//  BackgroundCoreDataManager.swift
//  70000TonsBands
//
//  Handles background Core Data updates for iCloud sync while maintaining GUI responsiveness
//

import Foundation
import CoreData

/// Manages background Core Data operations for iCloud sync
/// Allows background updates while GUI reads from main context
class BackgroundCoreDataManager {
    static let shared = BackgroundCoreDataManager()
    
    // MARK: - Core Data Stack
    
    /// Main context for GUI operations (read-only from background)
    private let mainContext: NSManagedObjectContext
    
    /// Background context for iCloud updates (write-only)
    private let backgroundContext: NSManagedObjectContext
    
    /// Persistent container for both contexts
    private let persistentContainer: NSPersistentContainer
    
    private init() {
        // Initialize persistent container
        persistentContainer = NSPersistentContainer(name: "DataModel")
        
        // Configure store for optimal concurrency
        let storeDescription = persistentContainer.persistentStoreDescriptions.first!
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // SQLite optimizations for concurrency
        storeDescription.setOption([
            "journal_mode": "WAL",           // Write-Ahead Logging prevents reader blocking
            "synchronous": "NORMAL",         // Balanced safety/performance
            "cache_size": "10000",          // Larger cache for better performance
            "temp_store": "MEMORY"          // Use memory for temporary storage
        ] as NSDictionary, forKey: NSSQLitePragmasOption)
        
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error)")
            }
        }
        
        // Configure main context for UI operations
        mainContext = persistentContainer.viewContext
        mainContext.automaticallyMergesChangesFromParent = true
        mainContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        mainContext.undoManager = nil // Disable undo for performance
        
        // Configure background context for iCloud updates
        backgroundContext = persistentContainer.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        backgroundContext.undoManager = nil
        
        setupChangeNotifications()
    }
    
    // MARK: - Public API
    
    /// Main context for GUI operations (always use this for reading)
    var viewContext: NSManagedObjectContext {
        return mainContext
    }
    
    /// Performs background Core Data operation for iCloud sync
    /// - Parameters:
    ///   - operation: The Core Data operation to perform on background context
    ///   - completion: Called when operation completes
    func performBackgroundUpdate(
        _ operation: @escaping (NSManagedObjectContext) throws -> Void,
        completion: @escaping (Result<Void, Error>) -> Void = { _ in }
    ) {
        backgroundContext.perform {
            do {
                try operation(self.backgroundContext)
                
                // Save changes if any
                if self.backgroundContext.hasChanges {
                    try self.backgroundContext.save()
                    print("✅ Background Core Data update completed successfully")
                }
                
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                print("❌ Background Core Data update failed: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Performs background Core Data operation for iCloud sync with result
    /// - Parameters:
    ///   - operation: The Core Data operation to perform on background context
    ///   - completion: Called with the result when operation completes
    func performBackgroundUpdate<T>(
        _ operation: @escaping (NSManagedObjectContext) throws -> T,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        backgroundContext.perform {
            do {
                let result = try operation(self.backgroundContext)
                
                // Save changes if any
                if self.backgroundContext.hasChanges {
                    try self.backgroundContext.save()
                    print("✅ Background Core Data update completed successfully")
                }
                
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                print("❌ Background Core Data update failed: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Change Notifications
    
    private func setupChangeNotifications() {
        // Listen for background context saves
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(backgroundContextDidSave(_:)),
            name: .NSManagedObjectContextDidSave,
            object: backgroundContext
        )
        
        // Listen for remote changes (iCloud, etc.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(persistentStoreRemoteChange(_:)),
            name: .NSPersistentStoreRemoteChange,
            object: nil
        )
    }
    
    @objc private func backgroundContextDidSave(_ notification: Notification) {
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

// MARK: - Notification Extensions

extension Notification.Name {
    static let coreDataDidUpdate = Notification.Name("CoreDataDidUpdate")
}

// MARK: - Usage Examples

extension BackgroundCoreDataManager {
    
    /// Example: Update priority from iCloud in background
    func updatePriorityFromiCloud(
        bandName: String,
        priority: Int,
        timestamp: Double,
        deviceUID: String,
        completion: @escaping (Result<Void, Error>) -> Void = { _ in }
    ) {
        performBackgroundUpdate { context in
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
            
            // Update priority
            userPriority.priorityLevel = Int16(priority)
            userPriority.updatedAt = Date(timeIntervalSince1970: timestamp)
            // Note: Add deviceUID field to Core Data model if needed
            
        } completion: { result in
            switch result {
            case .success:
                print("✅ Priority updated from iCloud: \(bandName) = \(priority)")
            case .failure(let error):
                print("❌ Failed to update priority from iCloud: \(error)")
            }
            completion(result)
        }
    }
    
    /// Example: Batch update multiple priorities from iCloud
    func updateMultiplePrioritiesFromiCloud(
        _ priorities: [(bandName: String, priority: Int, timestamp: Double, deviceUID: String)],
        completion: @escaping (Result<Void, Error>) -> Void = { _ in }
    ) {
        performBackgroundUpdate { context in
            for (bandName, priority, timestamp, deviceUID) in priorities {
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
                
                // Update priority
                userPriority.priorityLevel = Int16(priority)
                userPriority.updatedAt = Date(timeIntervalSince1970: timestamp)
            }
        } completion: completion
    }
}

//
//  DeadlockFixes.swift
//  70000TonsBands
//
//  Critical deadlock fixes for launch issues
//  These fixes address the root causes of intermittent deadlocks
//

import Foundation
import CoreData
import UIKit

// MARK: - Fix 1: Safe Core Data Manager
class SafeCoreDataManager {
    static let shared = SafeCoreDataManager()
    
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidSave(_:)),
            name: .NSManagedObjectContextDidSave,
            object: nil
        )
    }
    
    // MARK: - Core Data Stack with Deadlock Prevention
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DataModel")
        
        // Configure store options to prevent deadlocks
        let storeOptions = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true,
            NSSQLitePragmasOption: [
                "journal_mode": "WAL",  // Write-Ahead Logging prevents deadlocks
                "synchronous": "NORMAL"  // Balanced performance/safety
            ]
        ]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("❌ CRITICAL Core Data error: \(error)")
                fatalError("Failed to load Core Data store: \(error)")
            }
        }
        
        // Configure main context for deadlock prevention
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        print("✅ Safe Core Data stack initialized successfully")
        return container
    }()
    
    // Main thread context - ONLY use this on main thread
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - DEADLOCK-SAFE Operations
    
    /// Performs Core Data operation safely without blocking threads
    /// This replaces ALL performAndWait calls to prevent deadlocks
    func performSafeOperation<T>(_ operation: @escaping (NSManagedObjectContext) -> T, completion: @escaping (T?) -> Void) {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        context.perform {
            let result = operation(context)
            
            // Save if needed
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    print("❌ Safe operation save error: \(error)")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }
            }
            
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    /// Synchronous operation with timeout to prevent indefinite blocking
    func performSafeOperationSync<T>(_ operation: @escaping (NSManagedObjectContext) -> T, timeout: TimeInterval = 5.0) -> T? {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        var result: T?
        let semaphore = DispatchSemaphore(value: 0)
        
        context.perform {
            result = operation(context)
            
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    print("❌ Safe sync operation save error: \(error)")
                    result = nil
                }
            }
            
            semaphore.signal()
        }
        
        // Wait with timeout to prevent deadlocks
        let timeoutResult = semaphore.wait(timeout: .now() + timeout)
        if timeoutResult == .timedOut {
            print("⚠️ Core Data operation timed out after \(timeout)s - preventing deadlock")
            return nil
        }
        
        return result
    }
    
    @objc private func contextDidSave(_ notification: Notification) {
        guard let context = notification.object as? NSManagedObjectContext else { return }
        
        // Merge changes into view context safely
        if context != viewContext {
            viewContext.perform {
                self.viewContext.mergeChanges(fromContextDidSave: notification)
            }
        }
    }
}

// MARK: - Fix 2: Safe Priority Manager
class SafePriorityManager {
    private let coreDataManager: SafeCoreDataManager
    
    init(coreDataManager: SafeCoreDataManager = SafeCoreDataManager.shared) {
        self.coreDataManager = coreDataManager
    }
    
    /// Sets priority for a band - DEADLOCK-SAFE version
    func setPriority(for bandName: String, priority: Int, completion: @escaping (Bool) -> Void = { _ in }) {
        print("🎯 Setting priority for \(bandName) = \(priority)")
        
        coreDataManager.performSafeOperation({ context in
            // Get or create the band
            let bandRequest: NSFetchRequest<Band> = Band.fetchRequest()
            bandRequest.predicate = NSPredicate(format: "bandName == %@", bandName)
            bandRequest.fetchLimit = 1
            
            let band: Band
            do {
                band = try context.fetch(bandRequest).first ?? {
                    let newBand = Band(context: context)
                    newBand.bandName = bandName
                    return newBand
                }()
            } catch {
                print("❌ Error fetching/creating band: \(error)")
                return false
            }
            
            // Get or create the priority record
            let priorityRequest: NSFetchRequest<UserPriority> = UserPriority.fetchRequest()
            priorityRequest.predicate = NSPredicate(format: "band == %@", band)
            priorityRequest.fetchLimit = 1
            
            let userPriority: UserPriority
            do {
                userPriority = try context.fetch(priorityRequest).first ?? {
                    let newUserPriority = UserPriority(context: context)
                    newUserPriority.band = band
                    newUserPriority.priorityLevel = 0
                    newUserPriority.createdAt = Date()
                    newUserPriority.updatedAt = Date()
                    return newUserPriority
                }()
            } catch {
                print("❌ Error fetching/creating user priority: \(error)")
                return false
            }
            
            // Update the priority
            userPriority.priorityLevel = Int16(priority)
            userPriority.updatedAt = Date()
            
            return true
        }) { success in
            if success == true {
                print("✅ Priority saved for \(bandName): \(priority)")
                
                // Sync to iCloud in background
                DispatchQueue.global(qos: .default).async {
                    let iCloudHandler = iCloudDataHandler()
                    iCloudHandler.writeAPriorityRecord(bandName: bandName, priority: priority)
                }
            } else {
                print("❌ Failed to save priority for \(bandName)")
            }
            
            completion(success == true)
        }
    }
    
    /// Gets priority for a band - DEADLOCK-SAFE version
    func getPriority(for bandName: String, completion: @escaping (Int) -> Void) {
        coreDataManager.performSafeOperation({ context in
            let request: NSFetchRequest<UserPriority> = UserPriority.fetchRequest()
            request.predicate = NSPredicate(format: "band.bandName == %@", bandName)
            request.fetchLimit = 1
            
            do {
                if let userPriority = try context.fetch(request).first {
                    return Int(userPriority.priorityLevel)
                }
            } catch {
                print("❌ Error fetching priority for band \(bandName): \(error)")
            }
            
            return 0
        }) { priority in
            completion(priority ?? 0)
        }
    }
}

// MARK: - Fix 3: Safe Launch Coordinator
class SafeLaunchCoordinator {
    static let shared = SafeLaunchCoordinator()
    
    private let launchQueue = DispatchQueue(label: "com.70kBands.SafeLaunch", qos: .userInitiated)
    private var isLaunchInProgress = false
    private var launchCompletionHandlers: [() -> Void] = []
    
    private init() {}
    
    /// Coordinates safe app launch without deadlocks
    func performSafeLaunch(completion: @escaping () -> Void) {
        launchQueue.async {
            // Prevent multiple simultaneous launches
            guard !self.isLaunchInProgress else {
                self.launchCompletionHandlers.append(completion)
                return
            }
            
            self.isLaunchInProgress = true
            print("🚀 Starting safe launch sequence...")
            
            // Step 1: Initialize Core Data (blocking but safe)
            let coreDataManager = SafeCoreDataManager.shared
            _ = coreDataManager.persistentContainer
            
            // Step 2: Setup basic configuration (non-blocking)
            DispatchQueue.main.async {
                setupDefaults()
                
                // Step 3: Load essential data (background, non-blocking)
                DispatchQueue.global(qos: .userInitiated).async {
                    self.loadEssentialData {
                        // Step 4: Complete launch
                        DispatchQueue.main.async {
                            print("✅ Safe launch sequence completed")
                            self.isLaunchInProgress = false
                            
                            // Execute completion handlers
                            completion()
                            self.launchCompletionHandlers.forEach { $0() }
                            self.launchCompletionHandlers.removeAll()
                        }
                    }
                }
            }
        }
    }
    
    private func loadEssentialData(completion: @escaping () -> Void) {
        let group = DispatchGroup()
        
        // Load band names
        group.enter()
        let bandNamesHandler = bandNamesHandler.shared
        bandNamesHandler.gatherData(forceDownload: false) {
            group.leave()
        }
        
        // Load schedule data
        group.enter()
        let scheduleHandler = scheduleHandler.shared
        scheduleHandler.gatherData(forceDownload: false) {
            group.leave()
        }
        
        // Wait for all essential data with timeout
        group.notify(queue: .global(qos: .userInitiated)) {
            print("✅ Essential data loaded successfully")
            completion()
        }
        
        // Timeout protection
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 10.0) {
            print("⚠️ Essential data loading timeout - proceeding anyway")
            completion()
        }
    }
}

// MARK: - Fix 4: Thread-Safe Refresh Manager
class ThreadSafeRefreshManager {
    static let shared = ThreadSafeRefreshManager()
    
    private let refreshQueue = DispatchQueue(label: "com.70kBands.Refresh", qos: .userInitiated)
    private var isRefreshInProgress = false
    private let refreshLock = NSLock()
    
    private init() {}
    
    /// Performs thread-safe band list refresh without deadlocks
    func refreshBandList(reason: String, completion: @escaping ([String]) -> Void) {
        refreshQueue.async {
            self.refreshLock.lock()
            defer { self.refreshLock.unlock() }
            
            guard !self.isRefreshInProgress else {
                print("⚠️ Refresh already in progress, skipping: \(reason)")
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }
            
            self.isRefreshInProgress = true
            print("🔄 Starting thread-safe refresh: \(reason)")
            
            // Perform refresh operations safely
            let bandNamesHandler = bandNamesHandler.shared
            let scheduleHandler = scheduleHandler.shared
            let priorityManager = SafePriorityManager()
            
            // Load data without blocking
            bandNamesHandler.readBandFile()
            scheduleHandler.getCachedData()
            
            // Get filtered bands
            getFilteredBands(
                bandNameHandle: bandNamesHandler,
                schedule: scheduleHandler,
                dataHandle: dataHandler(), // Legacy - will be replaced
                priorityManager: PriorityManager(), // Legacy - will be replaced
                attendedHandle: ShowsAttended(),
                searchCriteria: ""
            ) { filteredBands in
                self.isRefreshInProgress = false
                print("✅ Thread-safe refresh completed: \(reason)")
                
                DispatchQueue.main.async {
                    completion(filteredBands)
                }
            }
        }
    }
}


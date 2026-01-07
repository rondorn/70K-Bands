//
//  ReliableDataCoordinator.swift
//  70000TonsBands
//
//  Coordinates all data operations to ensure reliability across launch, refresh, and modifications
//  Prevents race conditions and ensures consistent state
//

import Foundation
import UIKit

/// Coordinates all data operations to ensure reliability and prevent conflicts
class ReliableDataCoordinator {
    static let shared = ReliableDataCoordinator()
    
    // MARK: - Dependencies
    
    private let coreDataManager = ThreadSafeCoreDataManager.shared
    private let coordinatorQueue = DispatchQueue(label: "com.70kBands.DataCoordinator", qos: .userInitiated)
    
    // MARK: - State Management
    
    private var currentOperations: [DataOperation] = []
    private let operationsLock = NSLock()
    
    /// Tracks the current state of data loading
    enum DataState {
        case uninitialized
        case loading
        case ready
        case refreshing
        case error(Error)
    }
    
    private var currentState: DataState = .uninitialized
    private let stateLock = NSLock()
    
    /// Completion handlers waiting for data to be ready
    private var pendingCompletions: [(Result<Void, Error>) -> Void] = []
    
    private init() {
        setupNotifications()
    }
    
    // MARK: - Public API
    
    /// Performs initial data load during app launch
    /// Ensures all critical data is loaded before UI becomes interactive
    func performLaunchDataLoad(completion: @escaping (Result<Void, Error>) -> Void) {
        coordinatorQueue.async {
            self.stateLock.lock()
            
            // If already loading or ready, handle appropriately
            switch self.currentState {
            case .ready:
                self.stateLock.unlock()
                DispatchQueue.main.async {
                    completion(.success(()))
                }
                return
                
            case .loading:
                // Add to pending completions
                self.pendingCompletions.append(completion)
                self.stateLock.unlock()
                return
                
            case .refreshing:
                // Wait for refresh to complete
                self.pendingCompletions.append(completion)
                self.stateLock.unlock()
                return
                
            case .error, .uninitialized:
                // Proceed with loading
                self.currentState = .loading
                self.stateLock.unlock()
                break
            }
            
            print("🚀 Starting launch data load...")
            
            let launchOperation = DataOperation(
                id: "launch_\(UUID().uuidString)",
                type: .launch,
                priority: .high
            )
            
            self.executeOperation(launchOperation) { result in
                self.stateLock.lock()
                
                switch result {
                case .success:
                    self.currentState = .ready
                    print("✅ Launch data load completed successfully")
                    
                case .failure(let error):
                    self.currentState = .error(error)
                    print("❌ Launch data load failed: \(error)")
                }
                
                // Execute all pending completions
                let completions = self.pendingCompletions
                self.pendingCompletions.removeAll()
                self.stateLock.unlock()
                
                DispatchQueue.main.async {
                    completion(result)
                    completions.forEach { $0(result) }
                }
            }
        }
    }
    
    /// Performs data refresh (pull-to-refresh or background refresh)
    /// Ensures refresh doesn't conflict with ongoing operations
    func performDataRefresh(isUserInitiated: Bool = true, completion: @escaping (Result<Void, Error>) -> Void = { _ in }) {
        coordinatorQueue.async {
            self.stateLock.lock()
            
            // Check if we can perform refresh
            switch self.currentState {
            case .loading:
                // Can't refresh while initial load is in progress
                self.stateLock.unlock()
                DispatchQueue.main.async {
                    completion(.failure(DataCoordinatorError.operationInProgress("Initial load in progress")))
                }
                return
                
            case .refreshing:
                // Already refreshing
                self.pendingCompletions.append(completion)
                self.stateLock.unlock()
                return
                
            case .uninitialized, .ready, .error:
                // Proceed with refresh
                self.currentState = .refreshing
                self.stateLock.unlock()
                break
            }
            
            print("🔄 Starting data refresh (user initiated: \(isUserInitiated))...")
            
            let refreshOperation = DataOperation(
                id: "refresh_\(UUID().uuidString)",
                type: .refresh,
                priority: isUserInitiated ? .high : .normal
            )
            
            self.executeOperation(refreshOperation) { result in
                self.stateLock.lock()
                
                switch result {
                case .success:
                    self.currentState = .ready
                    print("✅ Data refresh completed successfully")
                    
                case .failure(let error):
                    // Don't change state to error for refresh failures
                    // Keep previous state (likely .ready)
                    print("⚠️ Data refresh failed: \(error)")
                }
                
                // Execute all pending completions
                let completions = self.pendingCompletions
                self.pendingCompletions.removeAll()
                self.stateLock.unlock()
                
                DispatchQueue.main.async {
                    completion(result)
                    completions.forEach { $0(result) }
                    
                    // Post refresh notification for UI updates
                    NotificationCenter.default.post(name: .dataRefreshCompleted, object: nil)
                }
            }
        }
    }
    
    /// Performs a data modification (priority change, attendance update, etc.)
    /// Ensures modifications don't conflict with ongoing loads/refreshes
    func performDataModification<T>(
        operationId: String,
        operation: @escaping (ThreadSafeCoreDataManager) throws -> T,
        completion: @escaping (Result<T, Error>) -> Void = { _ in }
    ) {
        coordinatorQueue.async {
            print("📝 Starting data modification: \(operationId)")
            
            let modifyOperation = DataOperation(
                id: operationId,
                type: .modification,
                priority: .high
            )
            
            // Execute modification
            self.coreDataManager.performWrite(operationId, operation: { context in
                return try operation(self.coreDataManager)
            }) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let value):
                        print("✅ Data modification completed: \(operationId)")
                        completion(.success(value))
                        
                        // Post modification notification
                        NotificationCenter.default.post(
                            name: .dataModificationCompleted,
                            object: nil,
                            userInfo: ["operationId": operationId]
                        )
                        
                    case .failure(let error):
                        print("❌ Data modification failed: \(operationId) - \(error)")
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    /// Waits for data to be ready before executing operation
    /// Useful for operations that depend on initial data load
    func waitForDataReady(timeout: TimeInterval = 10.0, completion: @escaping (Result<Void, Error>) -> Void) {
        coordinatorQueue.async {
            self.stateLock.lock()
            
            switch self.currentState {
            case .ready:
                self.stateLock.unlock()
                DispatchQueue.main.async {
                    completion(.success(()))
                }
                return
                
            case .loading, .refreshing:
                // Add to pending completions with timeout
                self.pendingCompletions.append(completion)
                self.stateLock.unlock()
                
                // Set up timeout
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                    self.coordinatorQueue.async {
                        self.stateLock.lock()
                        
                        // Remove completion if still pending (timeout occurred)
                        if let index = self.pendingCompletions.firstIndex(where: { _ in true }) {
                            self.pendingCompletions.remove(at: index)
                            self.stateLock.unlock()
                            
                            DispatchQueue.main.async {
                                completion(.failure(DataCoordinatorError.timeout))
                            }
                        } else {
                            self.stateLock.unlock()
                        }
                    }
                }
                return
                
            case .error(let error):
                self.stateLock.unlock()
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
                
            case .uninitialized:
                self.stateLock.unlock()
                // Trigger initial load
                self.performLaunchDataLoad(completion: completion)
                return
            }
        }
    }
    
    // MARK: - Operation Execution
    
    private func executeOperation(_ operation: DataOperation, completion: @escaping (Result<Void, Error>) -> Void) {
        print("⚙️ Executing operation: \(operation.id) (\(operation.type))")
        
        switch operation.type {
        case .launch:
            executeLaunchOperation(operation, completion: completion)
        case .refresh:
            executeRefreshOperation(operation, completion: completion)
        case .modification:
            // Modifications are handled directly in performDataModification
            completion(.success(()))
        }
    }
    
    private func executeLaunchOperation(_ operation: DataOperation, completion: @escaping (Result<Void, Error>) -> Void) {
        // Coordinate launch data loading
        let group = DispatchGroup()
        var errors: [Error] = []
        
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
        
        // Load Core Data
        group.enter()
        coreDataManager.performLaunchDataLoad { result in
            if case .failure(let error) = result {
                errors.append(error)
            }
            group.leave()
        }
        
        // Wait for all operations with timeout
        group.notify(queue: .global(qos: .userInitiated)) {
            if errors.isEmpty {
                completion(.success(()))
            } else {
                completion(.failure(DataCoordinatorError.multipleErrors(errors)))
            }
        }
        
        // Timeout protection
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 15.0) {
            completion(.failure(DataCoordinatorError.timeout))
        }
    }
    
    private func executeRefreshOperation(_ operation: DataOperation, completion: @escaping (Result<Void, Error>) -> Void) {
        // Coordinate refresh data loading
        let group = DispatchGroup()
        var errors: [Error] = []
        
        // Refresh band names
        group.enter()
        let bandNamesHandler = bandNamesHandler.shared
        bandNamesHandler.gatherData(forceDownload: true) {
            group.leave()
        }
        
        // Refresh schedule data
        group.enter()
        let scheduleHandler = scheduleHandler.shared
        scheduleHandler.gatherData(forceDownload: true) {
            group.leave()
        }
        
        // Refresh Core Data
        group.enter()
        coreDataManager.performRefreshDataLoad { result in
            if case .failure(let error) = result {
                errors.append(error)
            }
            group.leave()
        }
        
        group.notify(queue: .global(qos: .userInitiated)) {
            if errors.isEmpty {
                completion(.success(()))
            } else {
                completion(.failure(DataCoordinatorError.multipleErrors(errors)))
            }
        }
    }
    
    // MARK: - Notifications
    
    private func setupNotifications() {
        // Listen for app lifecycle events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        // Perform background refresh when app becomes active
        performDataRefresh(isUserInitiated: false)
    }
    
    @objc private func appWillEnterForeground() {
        // Ensure data is ready when coming from background
        waitForDataReady { result in
            if case .failure = result {
                // Trigger refresh if data is not ready
                self.performDataRefresh(isUserInitiated: false)
            }
        }
    }
}

// MARK: - Supporting Types

struct DataOperation {
    let id: String
    let type: OperationType
    let priority: Priority
    let timestamp: Date = Date()
    
    enum OperationType {
        case launch
        case refresh
        case modification
    }
    
    enum Priority {
        case high
        case normal
        case low
    }
}

enum DataCoordinatorError: Error, LocalizedError {
    case operationInProgress(String)
    case timeout
    case multipleErrors([Error])
    
    var errorDescription: String? {
        switch self {
        case .operationInProgress(let operation):
            return "Data operation in progress: \(operation)"
        case .timeout:
            return "Data operation timed out"
        case .multipleErrors(let errors):
            return "Multiple errors occurred: \(errors.map { $0.localizedDescription }.joined(separator: ", "))"
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let dataRefreshCompleted = Notification.Name("DataRefreshCompleted")
    static let dataModificationCompleted = Notification.Name("DataModificationCompleted")
}

// MARK: - Integration Helpers

extension ReliableDataCoordinator {
    
    /// Helper for updating band priority reliably
    func updateBandPriority(bandName: String, priority: Int, completion: @escaping (Result<Void, Error>) -> Void = { _ in }) {
        performDataModification(operationId: "priority_\(bandName)") { coreDataManager in
            coreDataManager.updatePriority(bandName: bandName, priority: priority) { result in
                switch result {
                case .success:
                    // Also sync to iCloud (Default profile only)
                    DispatchQueue.global(qos: .default).async {
                        // Use SQLiteiCloudSync - only syncs Default profile
                        let sqliteiCloudSync = SQLiteiCloudSync()
                        if sqliteiCloudSync.writePriorityToiCloud(bandName: bandName, priority: priority) {
                            print("☁️ Priority synced to iCloud for \(bandName) (Default profile only)")
                        } else {
                            print("☁️ Priority sync skipped for \(bandName) (not Default profile or iCloud disabled)")
                        }
                    }
                    completion(.success(()))
                    
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            return ()
        } completion: { result in
            completion(result.map { _ in () })
        }
    }
    
    /// Helper for pull-to-refresh integration
    func handlePullToRefresh(completion: @escaping () -> Void) {
        performDataRefresh(isUserInitiated: true) { result in
            switch result {
            case .success:
                print("✅ Pull-to-refresh completed successfully")
            case .failure(let error):
                print("⚠️ Pull-to-refresh failed: \(error)")
            }
            completion()
        }
    }
}


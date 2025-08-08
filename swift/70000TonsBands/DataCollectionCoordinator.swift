//
//  DataCollectionCoordinator.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/7/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation

/// Coordinates data collection across all data handlers to ensure proper loading order and prevent conflicts.
/// 
/// Key Features:
/// - On first install: Loads bandNamesHandler in foreground before anything else
/// - Parallel independent loading: Each class can run independently and in parallel
/// - Year change override: When year is changed via preferences, all current data collection stops
/// - Single instance per class: Each class can only run one at a time
class DataCollectionCoordinator {
    
    // MARK: - Singleton
    static let shared = DataCollectionCoordinator()
    
    // MARK: - Private Properties
    private let coordinatorQueue = DispatchQueue(label: "com.70kBands.DataCollectionCoordinator", qos: .userInitiated)
    private var isFirstInstall: Bool = false
    private var isYearChangeInProgress: Bool = false
    private var yearChangeRequested: Bool = false
    
    // Track running operations for each data type
    private var runningOperations: Set<DataOperationType> = []
    private var pendingOperations: [DataOperationType: [() -> Void]] = [:]
    
    // MARK: - Public Properties
    var isInitialLoadComplete: Bool = false
    
    // MARK: - Initialization
    private init() {
        checkFirstInstall()
    }
    
    // MARK: - First Install Detection
    private func checkFirstInstall() {
        // Check if this is the first time the app is running
        let hasRunBefore = UserDefaults.standard.bool(forKey: "hasRunBefore")
        if !hasRunBefore {
            isFirstInstall = true
            UserDefaults.standard.set(true, forKey: "hasRunBefore")
            print("[DataCollectionCoordinator] First install detected")
        }
    }
    
    // MARK: - Public Methods
    
    /// Requests data collection for a specific data type with optional year override
    /// - Parameters:
    ///   - operationType: The type of data operation to perform
    ///   - eventYearOverride: If true, cancels all other operations and runs immediately
    ///   - completion: Completion handler called when operation finishes
    func requestDataCollection(
        operationType: DataOperationType,
        eventYearOverride: Bool = false,
        completion: (() -> Void)? = nil
    ) {
        coordinatorQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Handle year change override
            if eventYearOverride {
                self.handleYearChangeOverride(operationType: operationType, completion: completion)
                return
            }
            
            // Handle first install - band names must load first in foreground
            if self.isFirstInstall && operationType == .bandNames {
                self.handleFirstInstallBandNames(completion: completion)
                return
            }
            
            // Handle first install - other operations wait for band names
            if self.isFirstInstall && operationType != .bandNames {
                self.queueOperationForFirstInstall(operationType: operationType, completion: completion)
                return
            }
            
            // Normal operation flow
            self.handleNormalOperation(operationType: operationType, completion: completion)
        }
    }
    
    /// Notifies the coordinator that a year change is being requested
    /// This will cancel all current operations and prioritize the year change
    func notifyYearChangeRequested() {
        coordinatorQueue.async { [weak self] in
            guard let self = self else { return }
            self.yearChangeRequested = true
            self.isYearChangeInProgress = true
            
            // Immediately cancel all running operations
            self.runningOperations.removeAll()
            self.pendingOperations.removeAll()
            
            print("[DataCollectionCoordinator] Year change requested - canceled all operations")
        }
    }
    
    /// Notifies the coordinator that a year change has completed
    func notifyYearChangeCompleted() {
        coordinatorQueue.async { [weak self] in
            guard let self = self else { return }
            self.yearChangeRequested = false
            self.isYearChangeInProgress = false
            print("[DataCollectionCoordinator] Year change completed")
        }
    }
    
    // MARK: - Private Methods
    
    private func handleYearChangeOverride(operationType: DataOperationType, completion: (() -> Void)?) {
        // Cancel all running operations
        runningOperations.removeAll()
        pendingOperations.removeAll()
        
        // Run the year change operation immediately
        runningOperations.insert(operationType)
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.executeOperation(operationType: operationType) {
                DispatchQueue.main.async {
                    self.runningOperations.remove(operationType)
                    completion?()
                }
            }
        }
    }
    
    private func handleFirstInstallBandNames(completion: (() -> Void)?) {
        print("[DataCollectionCoordinator] First install: Loading band names in foreground")
        
        // Run band names loading in foreground (main thread)
        DispatchQueue.main.async {
            self.executeOperation(operationType: .bandNames) {
                DispatchQueue.main.async {
                    self.isFirstInstall = false
                    self.isInitialLoadComplete = true
                    print("[DataCollectionCoordinator] First install: Band names loaded, proceeding with other operations")
                    
                    // Execute any pending operations in parallel
                    self.executePendingOperationsInParallel()
                    
                    completion?()
                }
            }
        }
    }
    
    private func queueOperationForFirstInstall(operationType: DataOperationType, completion: (() -> Void)?) {
        if pendingOperations[operationType] == nil {
            pendingOperations[operationType] = []
        }
        pendingOperations[operationType]?.append(completion ?? {})
        print("[DataCollectionCoordinator] First install: Queued \(operationType) operation")
    }
    
    private func executePendingOperations() {
        for (operationType, completions) in pendingOperations {
            for completion in completions {
                handleNormalOperation(operationType: operationType, completion: completion)
            }
        }
        pendingOperations.removeAll()
    }
    
    private func executePendingOperationsInParallel() {
        // Execute all pending operations in parallel
        let group = DispatchGroup()
        
        for (operationType, completions) in pendingOperations {
            for completion in completions {
                group.enter()
                handleNormalOperation(operationType: operationType) {
                    completion()
                    group.leave()
                }
            }
        }
        
        pendingOperations.removeAll()
        
        // Notify when all operations are complete
        group.notify(queue: .main) {
            print("[DataCollectionCoordinator] First install: All pending operations completed")
        }
    }
    
    private func handleNormalOperation(operationType: DataOperationType, completion: (() -> Void)?) {
        // Check if operation is already running
        if runningOperations.contains(operationType) {
            print("[DataCollectionCoordinator] \(operationType) already running, ignoring request")
            return
        }
        
        // Check if year change is in progress
        if isYearChangeInProgress {
            print("[DataCollectionCoordinator] Year change in progress, ignoring \(operationType) request")
            return
        }
        
        // Start the operation
        runningOperations.insert(operationType)
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.executeOperation(operationType: operationType) {
                DispatchQueue.main.async {
                    self.runningOperations.remove(operationType)
                    completion?()
                }
            }
        }
    }
    
    private func executeOperation(operationType: DataOperationType, completion: @escaping () -> Void) {
        print("[DataCollectionCoordinator] Executing \(operationType) operation")
        
        switch operationType {
        case .bandNames:
            let bandNamesHandle = bandNamesHandler.shared
            bandNamesHandle.requestDataCollection(eventYearOverride: yearChangeRequested) {
                completion()
            }
            
        case .schedule:
            let scheduleHandle = scheduleHandler.shared
            scheduleHandle.requestDataCollection(eventYearOverride: yearChangeRequested) {
                completion()
            }
            
        case .dataHandler:
            let dataHandle = dataHandler()
            dataHandle.requestDataCollection(eventYearOverride: yearChangeRequested) {
                completion()
            }
            
        case .showsAttended:
            let attendedHandle = ShowsAttended()
            attendedHandle.requestDataCollection(eventYearOverride: yearChangeRequested) {
                completion()
            }
            
        case .customBandDescription:
            let descriptionHandle = CustomBandDescription.shared
            descriptionHandle.requestDataCollection(eventYearOverride: yearChangeRequested) {
                completion()
            }
            
        case .imageHandler:
            let imageHandle = imageHandler.shared
            imageHandle.requestDataCollection(eventYearOverride: yearChangeRequested) {
                completion()
            }
        }
    }
}

// MARK: - Data Operation Types

/// Represents different types of data operations that can be coordinated
enum DataOperationType: Hashable {
    case bandNames
    case schedule
    case dataHandler
    case showsAttended
    case customBandDescription
    case imageHandler
}

// MARK: - Convenience Extensions

extension DataCollectionCoordinator {
    
    /// Convenience method to request band names data collection
    func requestBandNamesCollection(eventYearOverride: Bool = false, completion: (() -> Void)? = nil) {
        requestDataCollection(operationType: .bandNames, eventYearOverride: eventYearOverride, completion: completion)
    }
    
    /// Convenience method to request schedule data collection
    func requestScheduleCollection(eventYearOverride: Bool = false, completion: (() -> Void)? = nil) {
        requestDataCollection(operationType: .schedule, eventYearOverride: eventYearOverride, completion: completion)
    }
    
    /// Convenience method to request data handler collection
    func requestDataHandlerCollection(eventYearOverride: Bool = false, completion: (() -> Void)? = nil) {
        requestDataCollection(operationType: .dataHandler, eventYearOverride: eventYearOverride, completion: completion)
    }
    
    /// Convenience method to request shows attended collection
    func requestShowsAttendedCollection(eventYearOverride: Bool = false, completion: (() -> Void)? = nil) {
        requestDataCollection(operationType: .showsAttended, eventYearOverride: eventYearOverride, completion: completion)
    }
    
    /// Convenience method to request custom band description collection
    func requestCustomBandDescriptionCollection(eventYearOverride: Bool = false, completion: (() -> Void)? = nil) {
        requestDataCollection(operationType: .customBandDescription, eventYearOverride: eventYearOverride, completion: completion)
    }
    
    /// Convenience method to request image handler collection
    func requestImageHandlerCollection(eventYearOverride: Bool = false, completion: (() -> Void)? = nil) {
        requestDataCollection(operationType: .imageHandler, eventYearOverride: eventYearOverride, completion: completion)
    }
} 
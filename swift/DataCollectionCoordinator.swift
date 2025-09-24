//
//  DataCollectionCoordinator.swift
//  70000TonsBands
//
//  Coordinates all data collection operations with proper priority handling
//  Year changes = NUCLEAR priority (cancel everything)
//  Regular operations = QUEUE priority (reject duplicates)
//

import Foundation

/// Coordinates all data collection operations to prevent conflicts and ensure proper prioritization
class DataCollectionCoordinator {
    static let shared = DataCollectionCoordinator()
    
    // MARK: - Private Properties
    
    private let coordinatorQueue = DispatchQueue(label: "com.70kBands.DataCollectionCoordinator", qos: .userInitiated)
    private var activeOperations: [String: DataOperation] = [:]
    private var isYearChangeInProgress = false
    
    // MARK: - Operation Types
    
    enum OperationType {
        case yearChange
        case bandData
        case scheduleData  
        case refresh
        case iCloudSync
    }
    
    enum OperationPriority {
        case nuclear    // Year change - cancels everything immediately
        case high       // User-initiated actions (pull-to-refresh)
        case normal     // Background operations
        case low        // Optional operations (image loading, etc.)
    }
    
    struct DataOperation {
        let id: String
        let type: OperationType
        let priority: OperationPriority
        let startTime: Date
        let cancellationToken: CancellationToken
        let description: String
    }
    
    private init() {
        print("🎯 DataCollectionCoordinator initialized")
    }
    
    // MARK: - Year Change Operations (NUCLEAR Priority)
    
    /// Requests a year change operation with nuclear priority
    /// This will immediately cancel ALL other operations and block new ones
    func requestYearChange(to year: String, description: String = "", operation: @escaping () async -> Void) {
        coordinatorQueue.async {
            print("🚨 YEAR CHANGE REQUESTED - NUCLEAR PRIORITY")
            print("🚨 Target year: \(year)")
            print("🚨 Description: \(description)")
            
            // STEP 1: Cancel ALL existing operations immediately
            self.cancelAllOperations(reason: "Year change to \(year)")
            
            // STEP 2: Set year change flag to block new operations
            self.isYearChangeInProgress = true
            
            // STEP 3: Create and execute year change operation
            let yearChangeOp = DataOperation(
                id: "yearChange_\(year)_\(Date().timeIntervalSince1970)",
                type: .yearChange,
                priority: .nuclear,
                startTime: Date(),
                cancellationToken: CancellationToken(),
                description: "Year change to \(year): \(description)"
            )
            
            self.activeOperations[yearChangeOp.id] = yearChangeOp
            print("🚨 Year change operation started: \(yearChangeOp.id)")
            
            Task {
                // Execute the year change operation
                await operation()
                
                // Clean up after year change completes
                await MainActor.run {
                    self.coordinatorQueue.async {
                        self.activeOperations.removeValue(forKey: yearChangeOp.id)
                        self.isYearChangeInProgress = false
                        
                        let duration = Date().timeIntervalSince(yearChangeOp.startTime)
                        print("✅ YEAR CHANGE COMPLETED in \(String(format: "%.1f", duration))s")
                        print("✅ Normal operations can now resume")
                    }
                }
            }
        }
    }
    
    // MARK: - Regular Data Operations (QUEUE Priority)
    
    /// Requests band data collection with duplicate rejection
    func requestBandData(forceDownload: Bool = false, description: String = "", completion: @escaping (Bool) -> Void) {
        coordinatorQueue.async {
            let operationId = "bandData_\(forceDownload)"
            
            // REJECT if year change in progress
            guard !self.isYearChangeInProgress else {
                print("❌ Band data request REJECTED - year change in progress")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // REJECT if same operation already running
            if self.activeOperations[operationId] != nil {
                print("❌ Band data request REJECTED - already in progress")
                print("❌ Existing operation: \(self.activeOperations[operationId]?.description ?? "unknown")")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // ACCEPT - start operation
            print("✅ Band data request ACCEPTED")
            let operation = DataOperation(
                id: operationId,
                type: .bandData,
                priority: .normal,
                startTime: Date(),
                cancellationToken: CancellationToken(),
                description: "Band data (force: \(forceDownload)): \(description)"
            )
            
            self.activeOperations[operationId] = operation
            print("🔄 Starting band data operation: \(operation.description)")
            
            // Execute operation
            Task {
                let success = await self.executeBandDataOperation(
                    forceDownload: forceDownload,
                    cancellationToken: operation.cancellationToken
                )
                
                await MainActor.run {
                    self.coordinatorQueue.async {
                        self.activeOperations.removeValue(forKey: operationId)
                        let duration = Date().timeIntervalSince(operation.startTime)
                        print("✅ Band data operation completed in \(String(format: "%.1f", duration))s - Success: \(success)")
                    }
                    completion(success)
                }
            }
        }
    }
    
    /// Requests schedule data collection with duplicate rejection
    func requestScheduleData(forceDownload: Bool = false, description: String = "", completion: @escaping (Bool) -> Void) {
        coordinatorQueue.async {
            let operationId = "scheduleData_\(forceDownload)"
            
            // REJECT if year change in progress
            guard !self.isYearChangeInProgress else {
                print("❌ Schedule data request REJECTED - year change in progress")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // REJECT if same operation already running
            if self.activeOperations[operationId] != nil {
                print("❌ Schedule data request REJECTED - already in progress")
                print("❌ Existing operation: \(self.activeOperations[operationId]?.description ?? "unknown")")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // ACCEPT - start operation
            print("✅ Schedule data request ACCEPTED")
            let operation = DataOperation(
                id: operationId,
                type: .scheduleData,
                priority: .normal,
                startTime: Date(),
                cancellationToken: CancellationToken(),
                description: "Schedule data (force: \(forceDownload)): \(description)"
            )
            
            self.activeOperations[operationId] = operation
            print("🔄 Starting schedule data operation: \(operation.description)")
            
            // Execute operation
            Task {
                let success = await self.executeScheduleDataOperation(
                    forceDownload: forceDownload,
                    cancellationToken: operation.cancellationToken
                )
                
                await MainActor.run {
                    self.coordinatorQueue.async {
                        self.activeOperations.removeValue(forKey: operationId)
                        let duration = Date().timeIntervalSince(operation.startTime)
                        print("✅ Schedule data operation completed in \(String(format: "%.1f", duration))s - Success: \(success)")
                    }
                    completion(success)
                }
            }
        }
    }
    
    /// Requests a combined data refresh (band + schedule) with coordination
    func requestDataRefresh(forceDownload: Bool = false, description: String = "Combined refresh", completion: @escaping (Bool) -> Void) {
        print("🔄 Combined data refresh requested: \(description)")
        
        let group = DispatchGroup()
        var bandSuccess = false
        var scheduleSuccess = false
        
        // Request band data
        group.enter()
        requestBandData(forceDownload: forceDownload, description: "\(description) - bands") { success in
            bandSuccess = success
            group.leave()
        }
        
        // Request schedule data
        group.enter()
        requestScheduleData(forceDownload: forceDownload, description: "\(description) - schedule") { success in
            scheduleSuccess = success
            group.leave()
        }
        
        // Complete when both finish
        group.notify(queue: .main) {
            let overallSuccess = bandSuccess && scheduleSuccess
            print("✅ Combined data refresh completed - Bands: \(bandSuccess), Schedule: \(scheduleSuccess)")
            completion(overallSuccess)
        }
    }
    
    // MARK: - Operation Execution
    
    private func executeBandDataOperation(forceDownload: Bool, cancellationToken: CancellationToken) async -> Bool {
        return await withCheckedContinuation { continuation in
            // Check cancellation before starting
            guard !cancellationToken.isCancelled else {
                print("🚫 Band data operation cancelled before starting")
                continuation.resume(returning: false)
                return
            }
            
            let bandNamesHandler = bandNamesHandler.shared
            
            // Execute with cancellation checking
            if forceDownload {
                bandNamesHandler.gatherData(forceDownload: true) {
                    if cancellationToken.isCancelled {
                        print("🚫 Band data operation was cancelled during execution")
                        continuation.resume(returning: false)
                    } else {
                        print("✅ Band data operation completed successfully")
                        continuation.resume(returning: true)
                    }
                }
            } else {
                // For non-force operations, just read cached data
                bandNamesHandler.readBandFile()
                
                // Check cancellation after cache read
                if cancellationToken.isCancelled {
                    print("🚫 Band data cache read was cancelled")
                    continuation.resume(returning: false)
                } else {
                    print("✅ Band data cache read completed successfully")
                    continuation.resume(returning: true)
                }
            }
        }
    }
    
    private func executeScheduleDataOperation(forceDownload: Bool, cancellationToken: CancellationToken) async -> Bool {
        return await withCheckedContinuation { continuation in
            // Check cancellation before starting
            guard !cancellationToken.isCancelled else {
                print("🚫 Schedule data operation cancelled before starting")
                continuation.resume(returning: false)
                return
            }
            
            let scheduleHandler = scheduleHandler.shared
            
            // Execute with cancellation checking
            if forceDownload {
                scheduleHandler.gatherData(forceDownload: true) {
                    if cancellationToken.isCancelled {
                        print("🚫 Schedule data operation was cancelled during execution")
                        continuation.resume(returning: false)
                    } else {
                        print("✅ Schedule data operation completed successfully")
                        continuation.resume(returning: true)
                    }
                }
            } else {
                // For non-force operations, just read cached data
                scheduleHandler.getCachedData()
                
                // Check cancellation after cache read
                if cancellationToken.isCancelled {
                    print("🚫 Schedule data cache read was cancelled")
                    continuation.resume(returning: false)
                } else {
                    print("✅ Schedule data cache read completed successfully")
                    continuation.resume(returning: true)
                }
            }
        }
    }
    
    // MARK: - Operation Management
    
    private func cancelAllOperations(reason: String) {
        print("🚨 CANCELLING ALL OPERATIONS: \(reason)")
        print("🚨 Active operations before cancellation: \(activeOperations.count)")
        
        for (id, operation) in activeOperations {
            print("🚫 Cancelling operation: \(id) - \(operation.description)")
            operation.cancellationToken.cancel()
        }
        
        activeOperations.removeAll()
        print("🚨 All operations cancelled")
    }
    
    /// Gets current operation status for debugging
    func getOperationStatus() -> [String: Any] {
        var status: [String: Any] = [:]
        
        coordinatorQueue.sync {
            status["yearChangeInProgress"] = isYearChangeInProgress
            status["activeOperationCount"] = activeOperations.count
            status["activeOperations"] = activeOperations.mapValues { operation in
                [
                    "type": String(describing: operation.type),
                    "priority": String(describing: operation.priority),
                    "description": operation.description,
                    "duration": Date().timeIntervalSince(operation.startTime)
                ]
            }
        }
        
        return status
    }
    
    /// Emergency cancellation of all operations
    func emergencyCancelAll(reason: String = "Emergency cancellation") {
        coordinatorQueue.async {
            print("🚨 EMERGENCY CANCELLATION: \(reason)")
            self.cancelAllOperations(reason: reason)
            self.isYearChangeInProgress = false
        }
    }
}

// MARK: - Cancellation Token

class CancellationToken {
    private var _isCancelled = false
    private let lock = NSLock()
    
    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isCancelled
    }
    
    func cancel() {
        lock.lock()
        _isCancelled = true
        lock.unlock()
        print("🚫 Cancellation token activated")
    }
}

// MARK: - Convenience Extensions

extension DataCollectionCoordinator {
    
    /// Convenience method for pull-to-refresh
    func handlePullToRefresh(completion: @escaping (Bool) -> Void) {
        requestDataRefresh(
            forceDownload: true, 
            description: "Pull-to-refresh"
        ) { success in
            completion(success)
        }
    }
    
    /// Convenience method for app launch data loading
    func handleAppLaunchDataLoad(completion: @escaping (Bool) -> Void) {
        requestDataRefresh(
            forceDownload: false,
            description: "App launch"
        ) { success in
            completion(success)
        }
    }
    
    /// Convenience method for background refresh
    func handleBackgroundRefresh(completion: @escaping (Bool) -> Void) {
        requestDataRefresh(
            forceDownload: false,
            description: "Background refresh"
        ) { success in
            completion(success)
        }
    }
}

// MARK: - Usage Examples

/*
 
 YEAR CHANGE USAGE:
 
 DataCollectionCoordinator.shared.requestYearChange(to: "2025", description: "User selected 2025") {
     await performYearChangeLogic()
 }
 
 REGULAR DATA COLLECTION:
 
 DataCollectionCoordinator.shared.requestBandData(forceDownload: true, description: "User refresh") { success in
     if success {
         // Update UI with new band data
     } else {
         // Handle rejection or failure
     }
 }
 
 PULL-TO-REFRESH:
 
 DataCollectionCoordinator.shared.handlePullToRefresh { success in
     refreshControl.endRefreshing()
     if success {
         // Data refreshed successfully
     }
 }
 
 */


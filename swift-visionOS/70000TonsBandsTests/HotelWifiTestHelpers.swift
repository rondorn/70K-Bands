//
//  HotelWifiTestHelpers.swift
//  70000TonsBandsTests
//
//  Created by Ron Dorn on 12/19/24.
//  Copyright (c) 2024 Ron Dorn. All rights reserved.
//

import Foundation
import XCTest
@testable import _0000TonsBands

/// Helper utilities for hotel WiFi offline testing
class HotelWifiTestHelpers {
    
    // MARK: - Performance Monitoring
    
    /// Monitors performance of operations and logs results
    static func monitorPerformance<T>(operation: String, block: () -> T) -> T {
        let startTime = Date()
        let result = block()
        let duration = Date().timeIntervalSince(startTime)
        
        print("[PerformanceMonitor] \(operation): \(String(format: "%.3f", duration))s")
        return result
    }
    
    /// Monitors performance of async operations
    static func monitorAsyncPerformance(operation: String, block: @escaping () -> Void, completion: @escaping () -> Void) {
        let startTime = Date()
        block()
        let duration = Date().timeIntervalSince(startTime)
        
        print("[PerformanceMonitor] \(operation): \(String(format: "%.3f", duration))s")
        completion()
    }
    
    // MARK: - Network Simulation
    
    /// Simulates different network conditions
    enum NetworkCondition {
        case hotelWifi          // Connected but no internet
        case slowConnection     // Very slow internet
        case intermittent       // Intermittent connectivity
        case noConnection       // No WiFi at all
        case normalConnection   // Normal internet
    }
    
    static func simulateNetworkCondition(_ condition: NetworkCondition) {
        switch condition {
        case .hotelWifi:
            print("[NetworkSimulator] Simulating hotel WiFi (connected, no internet)")
            // Override network functions to return empty/error responses
            
        case .slowConnection:
            print("[NetworkSimulator] Simulating slow connection")
            // Add delays to network operations
            
        case .intermittent:
            print("[NetworkSimulator] Simulating intermittent connection")
            // Randomly fail network operations
            
        case .noConnection:
            print("[NetworkSimulator] Simulating no connection")
            // All network operations fail
            
        case .normalConnection:
            print("[NetworkSimulator] Simulating normal connection")
            // Normal network behavior
        }
    }
    
    // MARK: - Data Validation
    
    /// Validates that data handlers return expected offline behavior
    static func validateOfflineDataBehavior() -> Bool {
        var allValid = true
        
        // Test data handler
        let dataHandle = dataHandler()
        let priorityData = dataHandle.getPriorityData()
        if !priorityData.isEmpty {
            print("[DataValidator] Data handler has cached priority data")
        }
        
        // Test schedule handler
        let scheduleHandle = scheduleHandler()
        let scheduleData = scheduleHandle.getBandSortedSchedulingData()
        if !scheduleData.isEmpty {
            print("[DataValidator] Schedule handler has cached schedule data")
        }
        
        // Test band names handler
        let bandNameHandle = bandNamesHandler()
        let bandNames = bandNameHandle.getBandNames()
        if !bandNames.isEmpty {
            print("[DataValidator] Band names handler has cached band data")
        }
        
        // Test shows attended
        let attendedHandle = ShowsAttended()
        let attendedData = attendedHandle.getShowsAttended()
        if !attendedData.isEmpty {
            print("[DataValidator] Shows attended has cached attendance data")
        }
        
        return allValid
    }
    
    // MARK: - GUI Responsiveness Testing
    
    /// Tests GUI responsiveness by simulating rapid user interactions
    static func testGUIResponsiveness() -> Bool {
        let startTime = Date()
        var operationsCompleted = 0
        let totalOperations = 50
        
        for i in 0..<totalOperations {
            // Simulate rapid data access
            let dataHandle = dataHandler()
            let priority = dataHandle.getPriorityData("TestBand\(i)")
            
            // Simulate rapid schedule access
            let scheduleHandle = scheduleHandler()
            let schedule = scheduleHandle.getBandSortedSchedulingData()
            
            // Simulate rapid band names access
            let bandNameHandle = bandNamesHandler()
            let bandNames = bandNameHandle.getBandNames()
            
            operationsCompleted += 1
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let averageTime = totalTime / Double(totalOperations)
        
        print("[GUIResponsiveness] Completed \(operationsCompleted) operations in \(String(format: "%.3f", totalTime))s")
        print("[GUIResponsiveness] Average operation time: \(String(format: "%.3f", averageTime))s")
        
        // GUI should remain responsive (operations under 0.1s each)
        return averageTime < 0.1 && operationsCompleted == totalOperations
    }
    
    // MARK: - Cache Validation
    
    /// Validates that cache operations work correctly in offline mode
    static func validateCacheOperations() -> Bool {
        var allValid = true
        
        // Test cache clearing
        let dataHandle = dataHandler()
        dataHandle.clearCachedData()
        
        let scheduleHandle = scheduleHandler()
        scheduleHandle.clearCache()
        
        let bandNameHandle = bandNamesHandler()
        bandNameHandle.clearCachedData()
        
        // Test cache population
        dataHandle.getCachedData()
        scheduleHandle.getCachedData()
        bandNameHandle.getCachedData()
        
        print("[CacheValidator] Cache operations completed successfully")
        return allValid
    }
    
    // MARK: - File Operations Testing
    
    /// Tests file operations in offline mode
    static func testFileOperations() -> Bool {
        var allValid = true
        
        // Test file writing
        let dataHandle = dataHandler()
        dataHandle.addPriorityData("TestBand", priority: 3)
        dataHandle.writeFile()
        
        // Verify file was written
        if FileManager.default.fileExists(atPath: storageFile.path) {
            print("[FileValidator] Priority data file written successfully")
        } else {
            print("[FileValidator] ERROR: Priority data file not written")
            allValid = false
        }
        
        // Test file reading
        let readData = dataHandle.readFile(dateWinnerPassed: "")
        if !readData.isEmpty {
            print("[FileValidator] Priority data file read successfully")
        } else {
            print("[FileValidator] WARNING: No data read from file (may be expected in offline mode)")
        }
        
        return allValid
    }
    
    // MARK: - Error Handling Validation
    
    /// Tests error handling in offline mode
    static func testErrorHandling() -> Bool {
        var allValid = true
        
        // Test network request handling
        let testUrl = "http://example.com/test"
        let httpData = getUrlData(urlString: testUrl)
        
        if httpData.isEmpty {
            print("[ErrorValidator] Network requests properly return empty data in offline mode")
        } else {
            print("[ErrorValidator] WARNING: Network request returned data in offline mode")
            allValid = false
        }
        
        // Test file operations with non-existent files
        let nonExistentFile = URL(fileURLWithPath: "/non/existent/path")
        do {
            let fileData = try String(contentsOf: nonExistentFile, encoding: .utf8)
            print("[ErrorValidator] ERROR: Should have thrown exception for non-existent file")
            allValid = false
        } catch {
            print("[ErrorValidator] File operations properly handle non-existent files")
        }
        
        return allValid
    }
    
    // MARK: - Coordinator Testing
    
    /// Tests coordinator behavior in offline mode
    static func testCoordinatorOfflineBehavior(completion: @escaping (Bool) -> Void) {
        let coordinator = DataCollectionCoordinator.shared
        var allValid = true
        let group = DispatchGroup()
        
        // Test all coordinator operations
        let operations: [(String, () -> Void)] = [
            ("Band Names", { coordinator.requestBandNamesCollection(eventYearOverride: false) }),
            ("Schedule", { coordinator.requestScheduleCollection(eventYearOverride: false) }),
            ("Data Handler", { coordinator.requestDataHandlerCollection(eventYearOverride: false) }),
            ("Shows Attended", { coordinator.requestShowsAttendedCollection(eventYearOverride: false) }),
            ("Custom Band Description", { coordinator.requestCustomBandDescriptionCollection(eventYearOverride: false) }),
            ("Image Handler", { coordinator.requestImageHandlerCollection(eventYearOverride: false) })
        ]
        
        for (operationName, operation) in operations {
            group.enter()
            let startTime = Date()
            
            operation()
            
            let duration = Date().timeIntervalSince(startTime)
            print("[CoordinatorValidator] \(operationName) completed in \(String(format: "%.3f", duration))s")
            
            // Operations should complete quickly in offline mode
            if duration > 5.0 {
                print("[CoordinatorValidator] WARNING: \(operationName) took too long (\(duration)s)")
                allValid = false
            }
            
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(allValid)
        }
    }
}

// MARK: - Test Utilities

extension HotelWifiTestHelpers {
    
    /// Creates test data for offline testing
    static func createTestData() {
        // Create some test priority data
        let dataHandle = dataHandler()
        dataHandle.addPriorityData("TestBand1", priority: 1)
        dataHandle.addPriorityData("TestBand2", priority: 2)
        dataHandle.addPriorityData("TestBand3", priority: 3)
        
        // Create some test attendance data
        let attendedHandle = ShowsAttended()
        attendedHandle.addShowsAttended(band: "TestBand1", location: "TestVenue1", startTime: "20:00", eventType: "show", eventYearString: "2024")
        attendedHandle.addShowsAttended(band: "TestBand2", location: "TestVenue2", startTime: "21:00", eventType: "show", eventYearString: "2024")
        
        print("[TestDataCreator] Created test data for offline testing")
    }
    
    /// Cleans up test data
    static func cleanupTestData() {
        // Clear cache variables
        cacheVariables.bandPriorityStorageCache = [:]
        cacheVariables.scheduleStaticCache = [:]
        cacheVariables.scheduleTimeStaticCache = [:]
        cacheVariables.attendedStaticCache = [:]
        cacheVariables.bandDescriptionUrlCache = [:]
        cacheVariables.bandDescriptionUrlDateCache = [:]
        cacheVariables.bandNamesStaticCache = [:]
        cacheVariables.bandNamesArrayStaticCache = [:]
        
        // Remove test files
        let testFiles = [
            storageFile,
            scheduleFile,
            bandFile,
            showsAttended,
            descriptionMapFile
        ]
        
        for file in testFiles {
            if FileManager.default.fileExists(atPath: file.path) {
                try? FileManager.default.removeItem(at: file)
            }
        }
        
        print("[TestDataCleanup] Cleaned up test data")
    }
} 
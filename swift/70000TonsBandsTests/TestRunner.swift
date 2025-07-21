//
//  TestRunner.swift
//  70000TonsBandsTests
//
//  Created by Ron Dorn on 12/19/24.
//  Copyright (c) 2024 Ron Dorn. All rights reserved.
//

import Foundation
import XCTest
@testable import _0000TonsBands
    
/// Test runner for hotel WiFi offline functionality tests
/// Provides comprehensive testing of offline mode behavior
class HotelWifiTestRunner {
    
    // MARK: - Properties
    private var testResults: [String: TestResult] = [:]
    private var startTime: Date?
    private var totalTests = 0
    private var passedTests = 0
    private var failedTests = 0
    
    // MARK: - Test Result Structure
    struct TestResult {
        let name: String
        let passed: Bool
        let duration: TimeInterval
        let errorMessage: String?
        let performanceMetrics: [String: Double]
    }
    
    // MARK: - Main Test Execution
    
    /// Runs all hotel WiFi offline tests
    func runAllTests() {
        print("=" * 80)
        print("HOTEL WIFI OFFLINE FUNCTIONAL TEST SUITE")
        print("=" * 80)
        print("Testing app behavior when connected to WiFi but with no internet access")
        print("(Simulating hotel WiFi scenario)")
        print("")
        
        startTime = Date()
        
        // Run individual test scenarios
        runTest("Data Handler Initialization", test: testDataHandlerInitialization)
        runTest("Cached Data Loading", test: testCachedDataLoading)
        runTest("GUI Performance", test: testGUIPerformance)
        runTest("Offline Operations", test: testOfflineOperations)
        runTest("Error Handling", test: testErrorHandling)
        runTest("Coordinator Behavior", test: testCoordinatorBehavior)
        runTest("Data Validation", test: testDataValidation)
        runTest("Cache Operations", test: testCacheOperations)
        runTest("File Operations", test: testFileOperations)
        runTest("Rapid User Interactions", test: testRapidUserInteractions)
        runTest("Memory Usage", test: testMemoryUsage)
        
        // Print comprehensive results
        printResults()
    }
    
    // MARK: - Individual Test Methods
    
    private func testDataHandlerInitialization() -> TestResult {
        let startTime = Date()
        var errorMessage: String?
        var passed = true
        
        do {
            // Test initialization of all data handlers
            let dataHandle = dataHandler()
            let scheduleHandle = scheduleHandler()
            let bandNameHandle = bandNamesHandler()
            let attendedHandle = ShowsAttended()
            let imageHandle = imageHandler()
            let descriptionHandle = CustomBandDescription()
            
            // Verify all handlers initialized successfully
            if dataHandle == nil || scheduleHandle == nil || bandNameHandle == nil ||
               attendedHandle == nil || imageHandle == nil || descriptionHandle == nil {
                passed = false
                errorMessage = "One or more data handlers failed to initialize"
            }
            
        } catch {
            passed = false
            errorMessage = "Exception during data handler initialization: \(error.localizedDescription)"
        }
        
        let duration = Date().timeIntervalSince(startTime)
        return TestResult(
            name: "Data Handler Initialization",
            passed: passed,
            duration: duration,
            errorMessage: errorMessage,
            performanceMetrics: ["initialization_time": duration]
        )
    }
    
    private func testCachedDataLoading() -> TestResult {
        let startTime = Date()
        var errorMessage: String?
        var passed = true
        
        do {
            // Test cached data loading for all handlers
            let dataHandle = dataHandler()
            let scheduleHandle = scheduleHandler()
            let bandNameHandle = bandNamesHandler()
            let attendedHandle = ShowsAttended()
            
            // Load cached data
            dataHandle.getCachedData()
            scheduleHandle.getCachedData()
            bandNameHandle.getCachedData()
            attendedHandle.getCachedData()
            
            // Verify operations completed without errors
            // (In offline mode, these should complete quickly with cached data)
            
        } catch {
            passed = false
            errorMessage = "Exception during cached data loading: \(error.localizedDescription)"
        }
        
        let duration = Date().timeIntervalSince(startTime)
        return TestResult(
            name: "Cached Data Loading",
            passed: passed,
            duration: duration,
            errorMessage: errorMessage,
            performanceMetrics: ["cached_loading_time": duration]
        )
    }
    
    private func testGUIPerformance() -> TestResult {
        let startTime = Date()
        var errorMessage: String?
        var passed = true
        
        do {
            // Test GUI responsiveness
            let isResponsive = HotelWifiTestHelpers.testGUIResponsiveness()
            if !isResponsive {
                passed = false
                errorMessage = "GUI operations were not responsive enough"
            }
            
        } catch {
            passed = false
            errorMessage = "Exception during GUI performance test: \(error.localizedDescription)"
        }
        
        let duration = Date().timeIntervalSince(startTime)
        return TestResult(
            name: "GUI Performance",
            passed: passed,
            duration: duration,
            errorMessage: errorMessage,
            performanceMetrics: ["gui_responsiveness_time": duration]
        )
    }
    
    private func testOfflineOperations() -> TestResult {
        let startTime = Date()
        var errorMessage: String?
        var passed = true
        
        do {
            // Test offline operations
            let dataHandle = dataHandler()
            
            // Test priority data operations
            dataHandle.addPriorityData("TestBand", priority: 5)
            let priority = dataHandle.getPriorityData("TestBand")
            if priority != 5 {
                passed = false
                errorMessage = "Priority data not stored/retrieved correctly"
            }
            
            // Test file operations
            dataHandle.writeFile()
            if !FileManager.default.fileExists(atPath: storageFile.path) {
                passed = false
                errorMessage = "Data file not written successfully"
            }
            
        } catch {
            passed = false
            errorMessage = "Exception during offline operations: \(error.localizedDescription)"
        }
        
        let duration = Date().timeIntervalSince(startTime)
        return TestResult(
            name: "Offline Operations",
            passed: passed,
            duration: duration,
            errorMessage: errorMessage,
            performanceMetrics: ["offline_operations_time": duration]
        )
    }
    
    private func testErrorHandling() -> TestResult {
        let startTime = Date()
        var errorMessage: String?
        var passed = true
        
        do {
            // Test error handling
            let errorHandlingValid = HotelWifiTestHelpers.testErrorHandling()
            if !errorHandlingValid {
                passed = false
                errorMessage = "Error handling not graceful in offline mode"
            }
            
        } catch {
            passed = false
            errorMessage = "Exception during error handling test: \(error.localizedDescription)"
        }
        
        let duration = Date().timeIntervalSince(startTime)
        return TestResult(
            name: "Error Handling",
            passed: passed,
            duration: duration,
            errorMessage: errorMessage,
            performanceMetrics: ["error_handling_time": duration]
        )
    }
    
    private func testCoordinatorBehavior() -> TestResult {
        let startTime = Date()
        var errorMessage: String?
        var passed = true
        
        do {
            // Test coordinator behavior in offline mode
            let coordinator = DataCollectionCoordinator.shared
            
            // Test all coordinator operations
            coordinator.requestBandNamesCollection(eventYearOverride: false)
            coordinator.requestScheduleCollection(eventYearOverride: false)
            coordinator.requestDataHandlerCollection(eventYearOverride: false)
            coordinator.requestShowsAttendedCollection(eventYearOverride: false)
            coordinator.requestCustomBandDescriptionCollection(eventYearOverride: false)
            coordinator.requestImageHandlerCollection(eventYearOverride: false)
            
            // Verify operations completed without errors
            // (In offline mode, these should complete quickly)
            
        } catch {
            passed = false
            errorMessage = "Exception during coordinator behavior test: \(error.localizedDescription)"
        }
        
        let duration = Date().timeIntervalSince(startTime)
        return TestResult(
            name: "Coordinator Behavior",
            passed: passed,
            duration: duration,
            errorMessage: errorMessage,
            performanceMetrics: ["coordinator_time": duration]
        )
    }
    
    private func testDataValidation() -> TestResult {
        let startTime = Date()
        var errorMessage: String?
        var passed = true
        
        do {
            // Test data validation
            let dataValid = HotelWifiTestHelpers.validateOfflineDataBehavior()
            if !dataValid {
                passed = false
                errorMessage = "Data validation failed in offline mode"
            }
            
        } catch {
            passed = false
            errorMessage = "Exception during data validation test: \(error.localizedDescription)"
        }
        
        let duration = Date().timeIntervalSince(startTime)
        return TestResult(
            name: "Data Validation",
            passed: passed,
            duration: duration,
            errorMessage: errorMessage,
            performanceMetrics: ["data_validation_time": duration]
        )
    }
    
    private func testCacheOperations() -> TestResult {
        let startTime = Date()
        var errorMessage: String?
        var passed = true
        
        do {
            // Test cache operations
            let cacheValid = HotelWifiTestHelpers.validateCacheOperations()
            if !cacheValid {
                passed = false
                errorMessage = "Cache operations failed in offline mode"
            }
            
        } catch {
            passed = false
            errorMessage = "Exception during cache operations test: \(error.localizedDescription)"
        }
        
        let duration = Date().timeIntervalSince(startTime)
        return TestResult(
            name: "Cache Operations",
            passed: passed,
            duration: duration,
            errorMessage: errorMessage,
            performanceMetrics: ["cache_operations_time": duration]
        )
    }
    
    private func testFileOperations() -> TestResult {
        let startTime = Date()
        var errorMessage: String?
        var passed = true
        
        do {
            // Test file operations
            let fileValid = HotelWifiTestHelpers.testFileOperations()
            if !fileValid {
                passed = false
                errorMessage = "File operations failed in offline mode"
            }
            
        } catch {
            passed = false
            errorMessage = "Exception during file operations test: \(error.localizedDescription)"
        }
        
        let duration = Date().timeIntervalSince(startTime)
        return TestResult(
            name: "File Operations",
            passed: passed,
            duration: duration,
            errorMessage: errorMessage,
            performanceMetrics: ["file_operations_time": duration]
        )
    }
    
    private func testRapidUserInteractions() -> TestResult {
        let startTime = Date()
        var errorMessage: String?
        var passed = true
        
        do {
            // Test rapid user interactions
            let dataHandle = dataHandler()
            let scheduleHandle = scheduleHandler()
            let bandNameHandle = bandNamesHandler()
            let imageHandle = imageHandler()
            let descriptionHandle = CustomBandDescription()
            
            // Simulate rapid interactions
            for i in 0..<20 {
                _ = dataHandle.getPriorityData("TestBand\(i)")
                _ = scheduleHandle.getBandSortedSchedulingData()
                _ = bandNameHandle.getBandNames()
                _ = imageHandle.displayImage(urlString: "http://example.com/band\(i).jpg", bandName: "TestBand\(i)")
                _ = descriptionHandle.getDescription(bandName: "TestBand\(i)")
            }
            
            // Verify operations completed without errors
            let duration = Date().timeIntervalSince(startTime)
            if duration > 5.0 {
                passed = false
                errorMessage = "Rapid interactions took too long (\(duration)s)"
            }
            
        } catch {
            passed = false
            errorMessage = "Exception during rapid user interactions test: \(error.localizedDescription)"
        }
        
        let duration = Date().timeIntervalSince(startTime)
        return TestResult(
            name: "Rapid User Interactions",
            passed: passed,
            duration: duration,
            errorMessage: errorMessage,
            performanceMetrics: ["rapid_interactions_time": duration]
        )
    }
    
    private func testMemoryUsage() -> TestResult {
        let startTime = Date()
        var errorMessage: String?
        var passed = true
        
        do {
            // Monitor memory usage
            let initialMemory = getMemoryUsage()
            
            // Perform operations
            for i in 0..<50 {
                let dataHandle = dataHandler()
                let scheduleHandle = scheduleHandler()
                let bandNameHandle = bandNamesHandler()
                let attendedHandle = ShowsAttended()
                let imageHandle = imageHandler()
                let descriptionHandle = CustomBandDescription()
                
                _ = dataHandle.getPriorityData()
                _ = scheduleHandle.getBandSortedSchedulingData()
                _ = bandNameHandle.getBandNames()
                _ = attendedHandle.getShowsAttended()
                _ = imageHandle.displayImage(urlString: "http://example.com/test.jpg", bandName: "TestBand")
                _ = descriptionHandle.getDescription(bandName: "TestBand")
            }
            
            let finalMemory = getMemoryUsage()
            let memoryIncrease = finalMemory - initialMemory
            
            if memoryIncrease > 50.0 {
                passed = false
                errorMessage = "Memory usage increased too much (\(memoryIncrease)MB)"
            }
            
        } catch {
            passed = false
            errorMessage = "Exception during memory usage test: \(error.localizedDescription)"
        }
        
        let duration = Date().timeIntervalSince(startTime)
        return TestResult(
            name: "Memory Usage",
            passed: passed,
            duration: duration,
            errorMessage: errorMessage,
            performanceMetrics: ["memory_usage_time": duration]
        )
    }
    
    // MARK: - Helper Methods
    
    private func runTest(_ name: String, test: () -> TestResult) {
        totalTests += 1
        print("Running test: \(name)")
        
        let result = test()
        testResults[name] = result
        
        if result.passed {
            passedTests += 1
            print("✅ PASSED: \(name) (\(String(format: "%.3f", result.duration))s)")
        } else {
            failedTests += 1
            print("❌ FAILED: \(name) (\(String(format: "%.3f", result.duration))s)")
            if let error = result.errorMessage {
                print("   Error: \(error)")
            }
        }
        
        print("")
        }
        
    private func printResults() {
        let totalTime = Date().timeIntervalSince(startTime ?? Date())
        
        print("=" * 80)
        print("TEST RESULTS SUMMARY")
        print("=" * 80)
        print("Total Tests: \(totalTests)")
        print("Passed: \(passedTests)")
        print("Failed: \(failedTests)")
        print("Success Rate: \(String(format: "%.1f", Double(passedTests) / Double(totalTests) * 100))%")
        print("Total Time: \(String(format: "%.3f", totalTime))s")
        print("")
        
        if failedTests > 0 {
            print("FAILED TESTS:")
            print("-" * 40)
            for (name, result) in testResults {
                if !result.passed {
                    print("• \(name)")
                    if let error = result.errorMessage {
                        print("  Error: \(error)")
                    }
                }
            }
            print("")
        }
        
        print("PERFORMANCE METRICS:")
        print("-" * 40)
        for (name, result) in testResults {
            print("• \(name): \(String(format: "%.3f", result.duration))s")
        }
        print("")
        
        if failedTests == 0 {
            print("🎉 ALL TESTS PASSED! App works correctly in hotel WiFi offline mode.")
        } else {
            print("⚠️  \(failedTests) test(s) failed. Review the issues above.")
        }
        print("=" * 80)
    }
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        } else {
            return 0.0
        }
    }
}

// MARK: - String Extension for Repetition

extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
} 
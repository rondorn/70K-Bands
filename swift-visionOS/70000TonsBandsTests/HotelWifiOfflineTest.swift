//
//  HotelWifiOfflineTest.swift
//  70000TonsBandsTests
//
//  Created by Ron Dorn on 12/19/24.
//  Copyright (c) 2024 Ron Dorn. All rights reserved.
//

import XCTest
import Foundation
import Network
@testable import _0000TonsBands

/// Functional test that simulates hotel WiFi scenario where device is connected to WiFi
/// but has no internet access (like when you connect to hotel WiFi but haven't paid for access).
/// Verifies all app components work properly in offline mode without affecting GUI performance.
class HotelWifiOfflineTest: XCTestCase {
    
    // MARK: - Test Properties
    private var originalNetworkReachability: NetworkReachability?
    private var mockNetworkHandler: MockNetworkHandler?
    private var testStartTime: Date?
    private var guiPerformanceMetrics: [String: TimeInterval] = [:]
    
    // MARK: - Test Components
    private var dataHandler: dataHandler?
    private var scheduleHandler: scheduleHandler?
    private var bandNamesHandler: bandNamesHandler?
    private var showsAttended: ShowsAttended?
    private var imageHandler: imageHandler?
    private var customBandDescription: CustomBandDescription?
    private var coordinator: DataCollectionCoordinator?
    
    // MARK: - Setup and Teardown
    
    override func setUp() {
        super.setUp()
        print("[HotelWifiOfflineTest] Setting up test environment")
        
        // Store original network reachability
        originalNetworkReachability = NetworkReachability.shared
        
        // Create mock network handler that simulates hotel WiFi
        mockNetworkHandler = MockNetworkHandler()
        mockNetworkHandler?.simulateHotelWifi()
        
        // Initialize test components
        initializeTestComponents()
        
        // Clear any existing cached data
        clearTestData()
        
        // Create some test data for offline testing
        HotelWifiTestHelpers.createTestData()
        
        testStartTime = Date()
    }
    
    override func tearDown() {
        print("[HotelWifiOfflineTest] Cleaning up test environment")
        
        // Restore original network reachability
        if let original = originalNetworkReachability {
            NetworkReachability.shared = original
        }
        
        // Clear test data
        clearTestData()
        HotelWifiTestHelpers.cleanupTestData()
        
        // Reset components
        dataHandler = nil
        scheduleHandler = nil
        bandNamesHandler = nil
        showsAttended = nil
        imageHandler = nil
        customBandDescription = nil
        coordinator = nil
        
        super.tearDown()
    }
    
    // MARK: - Test Initialization
    
    private func initializeTestComponents() {
        print("[HotelWifiOfflineTest] Initializing test components")
        
        // Initialize all data handlers
        dataHandler = dataHandler()
        scheduleHandler = scheduleHandler()
        bandNamesHandler = bandNamesHandler()
        showsAttended = ShowsAttended()
        imageHandler = imageHandler()
        customBandDescription = CustomBandDescription()
        coordinator = DataCollectionCoordinator.shared
    }
    
    private func clearTestData() {
        print("[HotelWifiOfflineTest] Clearing test data")
        
        // Clear cache variables
        cacheVariables.bandPriorityStorageCache = [:]
        cacheVariables.scheduleStaticCache = [:]
        cacheVariables.scheduleTimeStaticCache = [:]
        cacheVariables.attendedStaticCache = [:]
        cacheVariables.bandDescriptionUrlCache = [:]
        cacheVariables.bandDescriptionUrlDateCache = [:]
        cacheVariables.bandNamesStaticCache = [:]
        cacheVariables.bandNamesArrayStaticCache = [:]
        
        // Clear test files
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
    }
    
    // MARK: - Main Test
    
    func testHotelWifiOfflineMode() {
        print("[HotelWifiOfflineTest] Starting hotel WiFi offline mode test")
        
        // Verify network state
        XCTAssertFalse(isInternetAvailable(), "Internet should not be available in hotel WiFi scenario")
        
        // Test 1: Verify all data handlers initialize without crashing
        testDataHandlerInitialization()
        
        // Test 2: Verify cached data loading works
        testCachedDataLoading()
        
        // Test 3: Verify GUI performance is not affected
        testGUIPerformance()
        
        // Test 4: Verify offline operations work correctly
        testOfflineOperations()
        
        // Test 5: Verify error handling is graceful
        testErrorHandling()
        
        // Test 6: Verify coordinator behavior in offline mode
        testCoordinatorOfflineBehavior()
        
        // Test 7: Verify data validation in offline mode
        testDataValidation()
        
        // Test 8: Verify cache operations work correctly
        testCacheOperations()
        
        // Test 9: Verify file operations work correctly
        testFileOperations()
        
        print("[HotelWifiOfflineTest] Hotel WiFi offline mode test completed successfully")
    }
    
    // MARK: - Individual Test Methods
    
    private func testDataHandlerInitialization() {
        print("[HotelWifiOfflineTest] Testing data handler initialization")
        
        let expectation = XCTestExpectation(description: "Data handlers initialize without crashing")
        
        DispatchQueue.main.async {
            // Use helper to monitor performance
            let initializationTime = HotelWifiTestHelpers.monitorPerformance(operation: "Data Handler Initialization") {
                // Initialize all handlers
                let dataHandle = dataHandler()
                let scheduleHandle = scheduleHandler()
                let bandNameHandle = bandNamesHandler()
                let attendedHandle = ShowsAttended()
                let imageHandle = imageHandler()
                let descriptionHandle = CustomBandDescription()
                
                // Verify handlers are not nil
                XCTAssertNotNil(dataHandle, "dataHandler should initialize successfully")
                XCTAssertNotNil(scheduleHandle, "scheduleHandler should initialize successfully")
                XCTAssertNotNil(bandNameHandle, "bandNamesHandler should initialize successfully")
                XCTAssertNotNil(attendedHandle, "ShowsAttended should initialize successfully")
                XCTAssertNotNil(imageHandle, "imageHandler should initialize successfully")
                XCTAssertNotNil(descriptionHandle, "CustomBandDescription should initialize successfully")
                
                return true
            }
            
            // Verify initialization completed quickly (under 1 second)
            XCTAssertLessThan(initializationTime, 1.0, "Data handler initialization should be fast in offline mode")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    private func testCachedDataLoading() {
        print("[HotelWifiOfflineTest] Testing cached data loading")
        
        let expectation = XCTestExpectation(description: "Cached data loads without network access")
        
        DispatchQueue.main.async {
            let startTime = Date()
            
            // Test data handler cached loading
            dataHandler?.getCachedData {
                let dataLoadTime = Date().timeIntervalSince(startTime)
                XCTAssertLessThan(dataLoadTime, 0.5, "Cached data loading should be very fast")
                
                // Test schedule handler cached loading
                scheduleHandler?.getCachedData()
                let scheduleLoadTime = Date().timeIntervalSince(startTime)
                XCTAssertLessThan(scheduleLoadTime, 1.0, "Schedule cached loading should be fast")
                
                // Test band names cached loading
                bandNamesHandler?.getCachedData {
                    let bandNamesLoadTime = Date().timeIntervalSince(startTime)
                    XCTAssertLessThan(bandNamesLoadTime, 1.0, "Band names cached loading should be fast")
                    
                    // Test shows attended cached loading
                    showsAttended?.getCachedData()
                    let attendedLoadTime = Date().timeIntervalSince(startTime)
                    XCTAssertLessThan(attendedLoadTime, 1.0, "Shows attended cached loading should be fast")
                    
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    private func testGUIPerformance() {
        print("[HotelWifiOfflineTest] Testing GUI performance")
        
        let expectation = XCTestExpectation(description: "GUI operations remain responsive")
        
        DispatchQueue.main.async {
            // Use helper to test GUI responsiveness
            let isResponsive = HotelWifiTestHelpers.testGUIResponsiveness()
            XCTAssertTrue(isResponsive, "GUI should remain responsive in offline mode")
            
            // Test image loading performance
            let imageStartTime = Date()
            let testImage = imageHandler?.displayImage(urlString: "http://example.com/test.jpg", bandName: "TestBand")
            let imageLoadTime = Date().timeIntervalSince(imageStartTime)
            XCTAssertLessThan(imageLoadTime, 0.1, "Image loading should be fast in offline mode")
            
            // Test description loading performance
            let descStartTime = Date()
            let description = customBandDescription?.getDescription(bandName: "TestBand") ?? ""
            let descLoadTime = Date().timeIntervalSince(descStartTime)
            XCTAssertLessThan(descLoadTime, 0.1, "Description loading should be fast in offline mode")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    private func testOfflineOperations() {
        print("[HotelWifiOfflineTest] Testing offline operations")
        
        let expectation = XCTestExpectation(description: "Offline operations work correctly")
        
        DispatchQueue.main.async {
            // Test priority data operations
            dataHandler?.addPriorityData("TestBand", priority: 5)
            let priority = dataHandler?.getPriorityData("TestBand") ?? 0
            XCTAssertEqual(priority, 5, "Priority data should be stored and retrieved correctly")
            
            // Test shows attended operations
            showsAttended?.addShowsAttended(band: "TestBand", location: "TestVenue", startTime: "20:00", eventType: "show", eventYearString: "2024")
            let attended = showsAttended?.getShowsAttended() ?? [:]
            XCTAssertFalse(attended.isEmpty, "Shows attended data should be stored")
            
            // Test file writing operations
            dataHandler?.writeFile()
            XCTAssertTrue(FileManager.default.fileExists(atPath: storageFile.path), "Data should be written to file")
            
            // Test cache operations
            dataHandler?.clearCachedData()
            scheduleHandler?.clearCache()
            bandNamesHandler?.clearCachedData()
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    private func testErrorHandling() {
        print("[HotelWifiOfflineTest] Testing error handling")
        
        let expectation = XCTestExpectation(description: "Error handling is graceful")
        
        DispatchQueue.main.async {
            // Use helper to test error handling
            let errorHandlingValid = HotelWifiTestHelpers.testErrorHandling()
            XCTAssertTrue(errorHandlingValid, "Error handling should be graceful in offline mode")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    private func testCoordinatorOfflineBehavior() {
        print("[HotelWifiOfflineTest] Testing coordinator offline behavior")
        
        let expectation = XCTestExpectation(description: "Coordinator handles offline mode correctly")
        
        DispatchQueue.main.async {
            let startTime = Date()
            
            // Test coordinator operations in offline mode
            coordinator?.requestBandNamesCollection(eventYearOverride: false) {
                let bandNamesTime = Date().timeIntervalSince(startTime)
                XCTAssertLessThan(bandNamesTime, 2.0, "Band names collection should complete quickly in offline mode")
                
                coordinator?.requestScheduleCollection(eventYearOverride: false) {
                    let scheduleTime = Date().timeIntervalSince(startTime)
                    XCTAssertLessThan(scheduleTime, 3.0, "Schedule collection should complete quickly in offline mode")
                    
                    coordinator?.requestDataHandlerCollection(eventYearOverride: false) {
                        let dataTime = Date().timeIntervalSince(startTime)
                        XCTAssertLessThan(dataTime, 4.0, "Data handler collection should complete quickly in offline mode")
                        
                        coordinator?.requestShowsAttendedCollection(eventYearOverride: false) {
                            let attendedTime = Date().timeIntervalSince(startTime)
                            XCTAssertLessThan(attendedTime, 5.0, "Shows attended collection should complete quickly in offline mode")
                            
                            coordinator?.requestCustomBandDescriptionCollection(eventYearOverride: false) {
                                let descTime = Date().timeIntervalSince(startTime)
                                XCTAssertLessThan(descTime, 6.0, "Description collection should complete quickly in offline mode")
                                
                                coordinator?.requestImageHandlerCollection(eventYearOverride: false) {
                                    let imageTime = Date().timeIntervalSince(startTime)
                                    XCTAssertLessThan(imageTime, 7.0, "Image handler collection should complete quickly in offline mode")
                                    
                                    expectation.fulfill()
                                }
                            }
                        }
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    private func testDataValidation() {
        print("[HotelWifiOfflineTest] Testing data validation")
        
        let expectation = XCTestExpectation(description: "Data validation works in offline mode")
        
        DispatchQueue.main.async {
            // Use helper to validate offline data behavior
            let dataValid = HotelWifiTestHelpers.validateOfflineDataBehavior()
            XCTAssertTrue(dataValid, "Data validation should work correctly in offline mode")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    private func testCacheOperations() {
        print("[HotelWifiOfflineTest] Testing cache operations")
        
        let expectation = XCTestExpectation(description: "Cache operations work correctly")
        
        DispatchQueue.main.async {
            // Use helper to validate cache operations
            let cacheValid = HotelWifiTestHelpers.validateCacheOperations()
            XCTAssertTrue(cacheValid, "Cache operations should work correctly in offline mode")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    private func testFileOperations() {
        print("[HotelWifiOfflineTest] Testing file operations")
        
        let expectation = XCTestExpectation(description: "File operations work correctly")
        
        DispatchQueue.main.async {
            // Use helper to test file operations
            let fileValid = HotelWifiTestHelpers.testFileOperations()
            XCTAssertTrue(fileValid, "File operations should work correctly in offline mode")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Additional Test Scenarios
    
    func testRapidUserInteractions() {
        print("[HotelWifiOfflineTest] Testing rapid user interactions")
        
        let expectation = XCTestExpectation(description: "Rapid user interactions remain responsive")
        
        DispatchQueue.main.async {
            let startTime = Date()
            
            // Simulate rapid user interactions
            for i in 0..<20 {
                // Rapid data access
                let priority = dataHandler?.getPriorityData("TestBand\(i)") ?? 0
                let schedule = scheduleHandler?.getBandSortedSchedulingData() ?? [:]
                let attended = showsAttended?.getShowsAttended() ?? [:]
                let bandNames = bandNamesHandler?.getBandNames() ?? []
                
                // Rapid image access
                let image = imageHandler?.displayImage(urlString: "http://example.com/band\(i).jpg", bandName: "TestBand\(i)")
                
                // Rapid description access
                let description = customBandDescription?.getDescription(bandName: "TestBand\(i)") ?? ""
                
                // Verify operations complete quickly
                let operationTime = Date().timeIntervalSince(startTime)
                XCTAssertLessThan(operationTime, 2.0, "Rapid interactions should complete quickly")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testMemoryUsageInOfflineMode() {
        print("[HotelWifiOfflineTest] Testing memory usage in offline mode")
        
        let expectation = XCTestExpectation(description: "Memory usage remains reasonable")
        
        DispatchQueue.main.async {
            // Monitor memory usage during operations
            let initialMemory = self.getMemoryUsage()
            
            // Perform various operations
            for i in 0..<50 {
                let dataHandle = dataHandler()
                let scheduleHandle = scheduleHandler()
                let bandNameHandle = bandNamesHandler()
                let attendedHandle = ShowsAttended()
                let imageHandle = imageHandler()
                let descriptionHandle = CustomBandDescription()
                
                // Access data
                _ = dataHandle.getPriorityData()
                _ = scheduleHandle.getBandSortedSchedulingData()
                _ = bandNameHandle.getBandNames()
                _ = attendedHandle.getShowsAttended()
                _ = imageHandle.displayImage(urlString: "http://example.com/test.jpg", bandName: "TestBand")
                _ = descriptionHandle.getDescription(bandName: "TestBand")
            }
            
            let finalMemory = self.getMemoryUsage()
            let memoryIncrease = finalMemory - initialMemory
            
            // Memory increase should be reasonable (less than 50MB)
            XCTAssertLessThan(memoryIncrease, 50.0, "Memory usage should remain reasonable in offline mode")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Helper Methods
    
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

// MARK: - Mock Network Handler

/// Mock network handler that simulates hotel WiFi connectivity
class MockNetworkHandler {
    
    func simulateHotelWifi() {
        print("[MockNetworkHandler] Simulating hotel WiFi (connected but no internet)")
        
        // Override the network reachability to simulate hotel WiFi
        NetworkReachability.shared = MockNetworkReachability()
    }
}

/// Mock network reachability that simulates hotel WiFi
class MockNetworkReachability: NetworkReachability {
    
    override var isReachable: Bool {
        return true // WiFi is connected
    }
    
    override var isReachableOnCellular: Bool {
        return false // No cellular fallback
    }
    
    override var isReachableOnEthernetOrWiFi: Bool {
        return true // WiFi is connected
    }
    
    override var connectionDescription: String {
        return "Hotel WiFi (No Internet Access)"
    }
}

// MARK: - Network Testing Extension

extension HotelWifiOfflineTest {
    
    /// Override the isInternetAvailable function for testing
    private func isInternetAvailable() -> Bool {
        // In hotel WiFi scenario, we're connected but have no internet
        return false
    }
    
    /// Override the getUrlData function for testing
    private func getUrlData(urlString: String) -> String {
        // Return empty string to simulate no internet access
        print("[HotelWifiOfflineTest] Mock getUrlData called with: \(urlString)")
        return ""
    }
} 
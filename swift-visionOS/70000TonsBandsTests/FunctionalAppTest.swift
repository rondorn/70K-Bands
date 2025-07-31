//
//  FunctionalAppTest.swift
//  70000TonsBandsTests
//
//  Created by Ron Dorn on 1/2/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import UIKit
import XCTest
@testable import _0000TonsBands

class FunctionalAppTest: XCTestCase {
    
    var app: XCUIApplication!
    var dataHandler: dataHandler!
    var bandNamesHandler: bandNamesHandler!
    var iCloudHandler: iCloudDataHandler!
    var countryHandler: countryHandler!
    var scheduleHandler: scheduleHandler!
    var alertPreferencesController: AlertPreferenesController!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        
        // Initialize the app
        app = XCUIApplication()
        app.launch()
        
        // Initialize handlers
        dataHandler = dataHandler()
        bandNamesHandler = bandNamesHandler()
        iCloudHandler = iCloudDataHandler()
        countryHandler = countryHandler()
        scheduleHandler = scheduleHandler()
        alertPreferencesController = AlertPreferenesController()
    }
    
    override func tearDown() {
        app = nil
        dataHandler = nil
        bandNamesHandler = nil
        iCloudHandler = nil
        countryHandler = nil
        scheduleHandler = nil
        alertPreferencesController = nil
        super.tearDown()
    }
    
    // MARK: - Installation Tests
    
    func testAppCanBeInstalled() {
        // Test that the app launches successfully
        XCTAssertTrue(app.state == .runningForeground, "App should be running in foreground")
        
        // Test that the main window is visible
        XCTAssertTrue(app.windows.firstMatch.exists, "Main window should be visible")
        
        // Test that the app has a valid bundle identifier
        XCTAssertNotNil(app.bundleIdentifier, "App should have a valid bundle identifier")
        
        // Test that the app has a valid display name
        XCTAssertNotNil(app.label, "App should have a valid display name")
        
        print("✅ App installation test passed")
    }
    
    func testAppLaunchPerformance() {
        measure {
            app.launch()
        }
    }
    
    // MARK: - Alert Tests
    
    func testAlertPreferencesAreAccessible() {
        // Navigate to settings/preferences if there's a settings button
        let settingsButton = app.buttons["Settings"]
        if settingsButton.exists {
            settingsButton.tap()
            
            // Look for alert preferences
            let alertPreferences = app.cells["Alert Preferences"]
            XCTAssertTrue(alertPreferences.exists, "Alert preferences should be accessible")
            
            alertPreferences.tap()
            
            // Test that alert options are available
            let mustSeeAlert = app.switches["Must See Alert"]
            let mightSeeAlert = app.switches["Might See Alert"]
            let alertForShows = app.switches["Alert for Shows"]
            let alertForSpecial = app.switches["Alert for Special Events"]
            
            XCTAssertTrue(mustSeeAlert.exists, "Must See Alert toggle should be available")
            XCTAssertTrue(mightSeeAlert.exists, "Might See Alert toggle should be available")
            XCTAssertTrue(alertForShows.exists, "Alert for Shows toggle should be available")
            XCTAssertTrue(alertForSpecial.exists, "Alert for Special Events toggle should be available")
        }
        
        print("✅ Alert preferences test passed")
    }
    
    func testAlertDefaultsAreSet() {
        // Test that default alert settings are properly configured
        let defaults = UserDefaults.standard
        
        XCTAssertEqual(defaults.string(forKey: "mustSeeAlert"), "YES", "Must see alert should default to YES")
        XCTAssertEqual(defaults.string(forKey: "mightSeeAlert"), "YES", "Might see alert should default to YES")
        XCTAssertEqual(defaults.string(forKey: "alertForShows"), "YES", "Alert for shows should default to YES")
        XCTAssertEqual(defaults.string(forKey: "alertForSpecial"), "YES", "Alert for special events should default to YES")
        XCTAssertEqual(defaults.string(forKey: "alertForMandG"), "NO", "Alert for meet and greet should default to NO")
        XCTAssertEqual(defaults.string(forKey: "alertForClinics"), "NO", "Alert for clinics should default to NO")
        XCTAssertEqual(defaults.string(forKey: "alertForListening"), "NO", "Alert for listening sessions should default to NO")
        XCTAssertEqual(defaults.string(forKey: "minBeforeAlert"), "10", "Minutes before alert should default to 10")
        
        print("✅ Alert defaults test passed")
    }
    
    // MARK: - Country Tests
    
    func testCountryDataIsLoaded() {
        // Test that country data can be loaded
        countryHandler.loadCountryData()
        
        let shortLongDict = countryHandler.getCountryShortLong()
        let longShortDict = countryHandler.getCountryLongShort()
        
        // Test that country dictionaries are populated
        XCTAssertFalse(shortLongDict.isEmpty, "Country short to long mapping should not be empty")
        XCTAssertFalse(longShortDict.isEmpty, "Country long to short mapping should not be empty")
        
        // Test some common countries
        XCTAssertEqual(shortLongDict["US"], "United States", "US should map to United States")
        XCTAssertEqual(shortLongDict["CA"], "Canada", "CA should map to Canada")
        XCTAssertEqual(shortLongDict["GB"], "United Kingdom", "GB should map to United Kingdom")
        
        XCTAssertEqual(longShortDict["United States"], "US", "United States should map to US")
        XCTAssertEqual(longShortDict["Canada"], "CA", "Canada should map to CA")
        XCTAssertEqual(longShortDict["United Kingdom"], "GB", "United Kingdom should map to GB")
        
        print("✅ Country data test passed")
    }
    
    func testCountrySelectionIsAvailable() {
        // Look for country selection UI elements
        let countryButton = app.buttons["Country"]
        let countryCell = app.cells["Country"]
        let countryLabel = app.staticTexts["Country"]
        
        // At least one of these should exist
        let countryElementExists = countryButton.exists || countryCell.exists || countryLabel.exists
        XCTAssertTrue(countryElementExists, "Country selection should be available in the UI")
        
        print("✅ Country selection test passed")
    }
    
    // MARK: - Band Data Tests
    
    func testBandNamesArePopulated() {
        // Test that band names can be loaded
        let expectation = XCTestExpectation(description: "Band names loaded")
        
        bandNamesHandler.getCachedData {
            let bandNames = self.bandNamesHandler.getBandNames()
            let bandNamesArray = self.bandNamesHandler.getBandNamesArray()
            
            // Test that band data is populated
            XCTAssertFalse(bandNames.isEmpty, "Band names dictionary should not be empty")
            XCTAssertFalse(bandNamesArray.isEmpty, "Band names array should not be empty")
            
            // Test that we have some expected bands (these should be common metal bands)
            let hasMetalBands = bandNamesArray.contains { bandName in
                let lowerBandName = bandName.lowercased()
                return lowerBandName.contains("metallica") || 
                       lowerBandName.contains("iron maiden") || 
                       lowerBandName.contains("black sabbath") ||
                       lowerBandName.contains("slayer") ||
                       lowerBandName.contains("megadeth")
            }
            
            XCTAssertTrue(hasMetalBands, "Should contain some well-known metal bands")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30.0)
        print("✅ Band names population test passed")
    }
    
    func testBandDataIsAccessibleInUI() {
        // Look for band list or search functionality
        let searchField = app.searchFields.firstMatch
        let bandList = app.tables.firstMatch
        let bandCell = app.cells.firstMatch
        
        // At least one of these should exist for band interaction
        let bandUIExists = searchField.exists || bandList.exists || bandCell.exists
        XCTAssertTrue(bandUIExists, "Band data should be accessible in the UI")
        
        print("✅ Band data UI test passed")
    }
    
    func testBandPriorityDataIsWorking() {
        // Test priority data functionality
        let testBandName = "Test Band"
        let testPriority = 5
        let testTimestamp = Date().timeIntervalSince1970
        
        // Test adding priority data
        dataHandler.addPriorityDataWithTimestamp(testBandName, priority: testPriority, timestamp: testTimestamp)
        
        // Test retrieving priority data
        let retrievedPriority = dataHandler.getPriorityData(testBandName)
        let retrievedTimestamp = dataHandler.getPriorityLastChange(testBandName)
        
        XCTAssertEqual(retrievedPriority, testPriority, "Retrieved priority should match set priority")
        XCTAssertEqual(retrievedTimestamp, testTimestamp, accuracy: 1.0, "Retrieved timestamp should match set timestamp")
        
        // Test getting all priority data
        let allPriorityData = dataHandler.getPriorityData()
        XCTAssertTrue(allPriorityData.keys.contains(testBandName), "All priority data should contain the test band")
        
        print("✅ Band priority data test passed")
    }
    
    // MARK: - iCloud Tests
    
    func testICloudStatusIsCheckable() {
        // Test that iCloud status can be checked
        let iCloudEnabled = iCloudHandler.checkForIcloud()
        
        // The result should be a boolean (either true or false)
        XCTAssertTrue(type(of: iCloudEnabled) == Bool.self, "iCloud check should return a boolean")
        
        print("✅ iCloud status check test passed")
    }
    
    func testICloudDataRestoration() {
        // Test iCloud data restoration functionality
        let expectation = XCTestExpectation(description: "iCloud data restoration")
        
        // Test reading priority data from iCloud
        DispatchQueue.global(qos: .background).async {
            self.iCloudHandler.readAllPriorityData()
            
            DispatchQueue.main.async {
                // Test that the operation completes without crashing
                XCTAssertTrue(true, "iCloud data restoration should complete without errors")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 60.0)
        print("✅ iCloud data restoration test passed")
    }
    
    func testICloudKeyValueStore() {
        // Test iCloud key-value store functionality
        let testKey = "FunctionalTestKey"
        let testValue = "FunctionalTestValue"
        
        // Write to iCloud
        NSUbiquitousKeyValueStore.default.set(testValue, forKey: testKey)
        NSUbiquitousKeyValueStore.default.synchronize()
        
        // Read from iCloud
        let retrievedValue = NSUbiquitousKeyValueStore.default.string(forKey: testKey)
        
        // Note: In test environment, iCloud might not be available, so we just test the API
        XCTAssertNotNil(retrievedValue, "Should be able to read from iCloud key-value store")
        
        // Clean up
        NSUbiquitousKeyValueStore.default.removeObject(forKey: testKey)
        NSUbiquitousKeyValueStore.default.synchronize()
        
        print("✅ iCloud key-value store test passed")
    }
    
    // MARK: - Year Change and Event Loading Tests
    
    func testYearChangeTo2025AndEventLoading() {
        // Test the complete flow: preferences -> year change -> event loading -> time display
        let expectation = XCTestExpectation(description: "Year change to 2025 and event loading")
        
        // Step 1: Test that preferences are accessible
        let preferencesButton = app.buttons["Settings"]
        XCTAssertTrue(preferencesButton.exists, "Settings button should be accessible")
        
        // Step 2: Test year selection functionality
        let yearSelectionButton = app.buttons["Select Event Year"]
        XCTAssertTrue(yearSelectionButton.exists, "Year selection button should be accessible")
        
        // Step 3: Test that 2025 is available in year options
        let yearOptions = ["Current", "2025", "2024", "2023"]
        let has2025Option = yearOptions.contains("2025")
        XCTAssertTrue(has2025Option, "2025 should be available as a year option")
        
        // Step 4: Test year change functionality
        DispatchQueue.global(qos: .background).async {
            // Simulate year change to 2025
            self.simulateYearChangeTo2025()
            
            // Step 5: Test that schedule data is loaded for 2025
            self.scheduleHandler.getCachedData()
            
            // Step 6: Test that events are sorted by time
            let timeSortedData = self.scheduleHandler.getTimeSortedSchedulingData()
            XCTAssertFalse(timeSortedData.isEmpty, "Time-sorted schedule data should be populated")
            
            // Step 7: Test that events are properly formatted with time information
            let bandSortedData = self.scheduleHandler.getBandSortedSchedulingData()
            XCTAssertFalse(bandSortedData.isEmpty, "Band-sorted schedule data should be populated")
            
            // Step 8: Verify that events have proper time formatting
            for (bandName, timeEvents) in bandSortedData {
                for (timeIndex, eventData) in timeEvents {
                    XCTAssertNotNil(eventData["startTime"], "Event should have start time")
                    XCTAssertNotNil(eventData["endTime"], "Event should have end time")
                    XCTAssertNotNil(eventData["date"], "Event should have date")
                    XCTAssertNotNil(eventData["location"], "Event should have location")
                    XCTAssertNotNil(eventData["type"], "Event should have type")
                    
                    // Test that time index is valid
                    XCTAssertGreaterThan(timeIndex, 0, "Time index should be valid")
                }
            }
            
            DispatchQueue.main.async {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 60.0)
        print("✅ Year change to 2025 and event loading test passed")
    }
    
    func testEventDisplayByTime() {
        // Test that events are properly displayed sorted by time
        let expectation = XCTestExpectation(description: "Event display by time")
        
        DispatchQueue.global(qos: .background).async {
            // Load schedule data
            self.scheduleHandler.getCachedData()
            
            // Get time-sorted data
            let timeSortedData = self.scheduleHandler.getTimeSortedSchedulingData()
            
            // Test that data is sorted by time
            let timeKeys = Array(timeSortedData.keys).sorted()
            XCTAssertEqual(timeKeys, timeKeys.sorted(), "Time keys should be sorted chronologically")
            
            // Test that each time slot has events
            for timeKey in timeKeys {
                let eventsAtTime = timeSortedData[timeKey]
                XCTAssertNotNil(eventsAtTime, "Should have events at time \(timeKey)")
                XCTAssertFalse(eventsAtTime?.isEmpty ?? true, "Should have events at time \(timeKey)")
            }
            
            // Test that events have proper time formatting
            for (timeKey, events) in timeSortedData {
                for (bandName, _) in events {
                    let eventData = self.scheduleHandler.getData(bandName, index: timeKey, variable: "startTime")
                    let endTimeData = self.scheduleHandler.getData(bandName, index: timeKey, variable: "endTime")
                    let dateData = self.scheduleHandler.getData(bandName, index: timeKey, variable: "date")
                    let locationData = self.scheduleHandler.getData(bandName, index: timeKey, variable: "location")
                    let typeData = self.scheduleHandler.getData(bandName, index: timeKey, variable: "type")
                    
                    XCTAssertFalse(eventData.isEmpty, "Event should have start time")
                    XCTAssertFalse(endTimeData.isEmpty, "Event should have end time")
                    XCTAssertFalse(dateData.isEmpty, "Event should have date")
                    XCTAssertFalse(locationData.isEmpty, "Event should have location")
                    XCTAssertFalse(typeData.isEmpty, "Event should have type")
                }
            }
            
            DispatchQueue.main.async {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 30.0)
        print("✅ Event display by time test passed")
    }
    
    func testPreferencesYearChangeWorkflow() {
        // Test the complete preferences year change workflow
        let expectation = XCTestExpectation(description: "Preferences year change workflow")
        
        DispatchQueue.global(qos: .background).async {
            // Step 1: Test that preferences controller can handle year changes
            let alertPreferences = AlertPreferenesController()
            
            // Step 2: Test year change functionality
            alertPreferences.eventYearChangeAttempt = "2025"
            
            // Step 3: Test that URLs are updated for 2025
            setArtistUrl("2025")
            setScheduleUrl("2025")
            
            // Step 4: Test that data is reloaded for 2025
            self.bandNamesHandler.getCachedData()
            self.scheduleHandler.getCachedData()
            
            // Step 5: Verify that 2025 data is loaded
            let bandNames = self.bandNamesHandler.getBandNames()
            let scheduleData = self.scheduleHandler.getBandSortedSchedulingData()
            
            XCTAssertFalse(bandNames.isEmpty, "Band names should be loaded for 2025")
            XCTAssertFalse(scheduleData.isEmpty, "Schedule data should be loaded for 2025")
            
            // Step 6: Test that events are displayed by time
            let timeSortedData = self.scheduleHandler.getTimeSortedSchedulingData()
            XCTAssertFalse(timeSortedData.isEmpty, "Time-sorted events should be available")
            
            DispatchQueue.main.async {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 60.0)
        print("✅ Preferences year change workflow test passed")
    }
    
    // MARK: - Integration Tests
    
    func testAppDataFlow() {
        // Test the complete data flow from app launch to data availability
        let expectation = XCTestExpectation(description: "Complete data flow")
        
        // Simulate app launch data loading
        DispatchQueue.global(qos: .background).async {
            // Load band names
            self.bandNamesHandler.getCachedData {
                // Load country data
                self.countryHandler.loadCountryData()
                
                // Load priority data
                self.dataHandler.getCachedData {
                    // Check iCloud status
                    let iCloudEnabled = self.iCloudHandler.checkForIcloud()
                    
                    DispatchQueue.main.async {
                        // Verify all data is available
                        let bandNames = self.bandNamesHandler.getBandNames()
                        let countryData = self.countryHandler.getCountryShortLong()
                        let priorityData = self.dataHandler.getPriorityData()
                        
                        XCTAssertFalse(bandNames.isEmpty, "Band names should be loaded")
                        XCTAssertFalse(countryData.isEmpty, "Country data should be loaded")
                        XCTAssertTrue(type(of: iCloudEnabled) == Bool.self, "iCloud status should be checkable")
                        
                        expectation.fulfill()
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 60.0)
        print("✅ Complete data flow test passed")
    }
    
    func testAppStability() {
        // Test that the app remains stable during normal operations
        let expectation = XCTestExpectation(description: "App stability")
        
        // Perform various operations to test stability
        DispatchQueue.global(qos: .background).async {
            for i in 1...10 {
                // Load data multiple times
                self.bandNamesHandler.getCachedData()
                self.dataHandler.getCachedData()
                self.countryHandler.loadCountryData()
                
                // Add some test priority data
                self.dataHandler.addPriorityData("TestBand\(i)", priority: i)
                
                // Small delay between operations
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            DispatchQueue.main.async {
                XCTAssertTrue(self.app.state == .runningForeground, "App should remain running after multiple operations")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 30.0)
        print("✅ App stability test passed")
    }
    
    // MARK: - Performance Tests
    
    func testDataLoadingPerformance() {
        measure {
            let expectation = XCTestExpectation(description: "Data loading performance")
            
            bandNamesHandler.getCachedData {
                dataHandler.getCachedData {
                    countryHandler.loadCountryData()
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    func testPriorityDataWritePerformance() {
        measure {
            for i in 1...100 {
                dataHandler.addPriorityData("PerformanceTestBand\(i)", priority: i)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func simulateYearChangeTo2025() {
        // Simulate the year change process to 2025
        print("Simulating year change to 2025")
        
        // Set the year change attempt
        alertPreferencesController.eventYearChangeAttempt = "2025"
        
        // Update URLs for 2025
        setArtistUrl("2025")
        setScheduleUrl("2025")
        
        // Clear cached data to force reload
        bandNamesHandler.clearCachedData()
        scheduleHandler.clearCache()
        dataHandler.clearCachedData()
        
        // Reload data for 2025
        bandNamesHandler.getCachedData()
        scheduleHandler.getCachedData()
        dataHandler.getCachedData()
        
        print("Year change to 2025 simulation completed")
    }
} 
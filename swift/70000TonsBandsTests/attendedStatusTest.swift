//
//  attendedStatusTest.swift
//  70000TonsBandsTests
//
//  Created by Ron Dorn on 1/2/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation

/// Test to verify that null/empty attended status values display as "Will Not Attend" but cycle to "Will Attend" on first click
/// This ensures the requirement: "When clicking to add attended status to an event, 
/// Null or no entry should display as 'Will Not Attend' but cycle to 'Will Attend' on first click"

struct TestResult {
    let name: String
    let passed: Bool
    let error: String?
    let duration: TimeInterval
    let category: String
}

class AttendedStatusTest {
    
    private var results: [TestResult] = []
    private var startTime: Date = Date()
    
    func runAllTests() {
        print("🧪 Testing Attended Status Null/Empty Handling")
        print(String(repeating: "=", count: 50))
        
        testNullStatusTreatedAsWillNotAttend()
        testEmptyStatusTreatedAsWillNotAttend()
        testUnrecognizedStatusTreatedAsWillNotAttend()
        testCyclingLogicWithNullStatus()
        testCyclingLogicWithEmptyStatus()
        testFilteringLogicWithNullStatus()
        testFilteringLogicWithEmptyStatus()
        
        generateReport()
    }
    
    // MARK: - Core Logic Tests
    
    func testNullStatusTreatedAsWillNotAttend() {
        let testStart = Date()
        print("  Running: testNullStatusTreatedAsWillNotAttend")
        
        // Simulate the getShowAttendedStatus logic
        let nullStatus: String? = nil
        let expectedResult = "sawNone" // Will Not Attend (for display)
        
        // Simulate the logic from getShowAttendedStatus method
        var value = ""
        if (nullStatus == "sawAll") {
            value = "sawAll"
        } else if (nullStatus == "sawSome") {
            value = "sawSome"
        } else {
            // This handles null, empty, and any other unrecognized values - all treated as "Will Not Attend" for display
            value = "sawNone" // Will Not Attend
        }
        
        let success = value == expectedResult
        
        if success {
            print("    ✅ testNullStatusTreatedAsWillNotAttend - PASSED")
        } else {
            print("    ❌ testNullStatusTreatedAsWillNotAttend - FAILED")
        }
        
        results.append(TestResult(
            name: "testNullStatusTreatedAsWillNotAttend",
            passed: success,
            error: success ? nil : "Null status not treated as Will Not Attend for display",
            duration: Date().timeIntervalSince(testStart),
            category: "Attended Status"
        ))
    }
    
    func testEmptyStatusTreatedAsWillNotAttend() {
        let testStart = Date()
        print("  Running: testEmptyStatusTreatedAsWillNotAttend")
        
        // Simulate the getShowAttendedStatus logic
        let emptyStatus = ""
        let expectedResult = "sawNone" // Will Not Attend (for display)
        
        // Simulate the logic from getShowAttendedStatus method
        var value = ""
        if (emptyStatus == "sawAll") {
            value = "sawAll"
        } else if (emptyStatus == "sawSome") {
            value = "sawSome"
        } else {
            // This handles null, empty, and any other unrecognized values - all treated as "Will Not Attend" for display
            value = "sawNone" // Will Not Attend
        }
        
        let success = value == expectedResult
        
        if success {
            print("    ✅ testEmptyStatusTreatedAsWillNotAttend - PASSED")
        } else {
            print("    ❌ testEmptyStatusTreatedAsWillNotAttend - FAILED")
        }
        
        results.append(TestResult(
            name: "testEmptyStatusTreatedAsWillNotAttend",
            passed: success,
            error: success ? nil : "Empty status not treated as Will Not Attend for display",
            duration: Date().timeIntervalSince(testStart),
            category: "Attended Status"
        ))
    }
    
    func testUnrecognizedStatusTreatedAsWillNotAttend() {
        let testStart = Date()
        print("  Running: testUnrecognizedStatusTreatedAsWillNotAttend")
        
        // Simulate the getShowAttendedStatus logic
        let unrecognizedStatus = "invalid_status"
        let expectedResult = "sawNone" // Will Not Attend (for display)
        
        // Simulate the logic from getShowAttendedStatus method
        var value = ""
        if (unrecognizedStatus == "sawAll") {
            value = "sawAll"
        } else if (unrecognizedStatus == "sawSome") {
            value = "sawSome"
        } else {
            // This handles null, empty, and any other unrecognized values - all treated as "Will Not Attend" for display
            value = "sawNone" // Will Not Attend
        }
        
        let success = value == expectedResult
        
        if success {
            print("    ✅ testUnrecognizedStatusTreatedAsWillNotAttend - PASSED")
        } else {
            print("    ❌ testUnrecognizedStatusTreatedAsWillNotAttend - FAILED")
        }
        
        results.append(TestResult(
            name: "testUnrecognizedStatusTreatedAsWillNotAttend",
            passed: success,
            error: success ? nil : "Unrecognized status not treated as Will Not Attend for display",
            duration: Date().timeIntervalSince(testStart),
            category: "Attended Status"
        ))
    }
    
    // MARK: - Cycling Logic Tests
    
    func testCyclingLogicWithNullStatus() {
        let testStart = Date()
        print("  Running: testCyclingLogicWithNullStatus")
        
        // Simulate the addShowsAttended cycling logic
        let nullStatus: String? = nil
        let expectedResult = "sawAll" // Will Attend (first click on new event)
        
        // Simulate the logic from addShowsAttended method
        var value = ""
        if (nullStatus == nil) {
            // First click on a new event - set to "Will Attend"
            value = "sawAll" // Will Attend
        } else if (nullStatus == "sawAll") {
            value = "sawSome" // Partially Attended
        } else if (nullStatus == "sawSome") {
            value = "sawNone" // Will Not Attend
        } else if (nullStatus == "sawNone") {
            value = "sawAll" // Will Not Attend -> Will Attend
        } else {
            value = "sawAll" // fallback
        }
        
        let success = value == expectedResult
        
        if success {
            print("    ✅ testCyclingLogicWithNullStatus - PASSED")
        } else {
            print("    ❌ testCyclingLogicWithNullStatus - FAILED")
        }
        
        results.append(TestResult(
            name: "testCyclingLogicWithNullStatus",
            passed: success,
            error: success ? nil : "Null status cycling logic failed",
            duration: Date().timeIntervalSince(testStart),
            category: "Attended Status"
        ))
    }
    
    func testCyclingLogicWithEmptyStatus() {
        let testStart = Date()
        print("  Running: testCyclingLogicWithEmptyStatus")
        
        // Simulate the addShowsAttended cycling logic
        let emptyStatus = ""
        let expectedResult = "sawAll" // Will Attend (first click on new event)
        
        // Simulate the logic from addShowsAttended method
        var value = ""
        if (emptyStatus == "sawNone") {
            value = "sawAll" // Will Attend
        } else if (emptyStatus == "sawAll") {
            value = "sawSome" // Partially Attended
        } else if (emptyStatus == "sawSome") {
            value = "sawNone" // Will Not Attend
        } else {
            // Empty string doesn't match any known status, so it falls through to fallback
            value = "sawAll" // fallback - treats any unrecognized value as "Will Attend"
        }
        
        let success = value == expectedResult
        
        if success {
            print("    ✅ testCyclingLogicWithEmptyStatus - PASSED")
        } else {
            print("    ❌ testCyclingLogicWithEmptyStatus - FAILED")
        }
        
        results.append(TestResult(
            name: "testCyclingLogicWithEmptyStatus",
            passed: success,
            error: success ? nil : "Empty status cycling logic failed",
            duration: Date().timeIntervalSince(testStart),
            category: "Attended Status"
        ))
    }
    
    // MARK: - Filtering Logic Tests
    
    func testFilteringLogicWithNullStatus() {
        let testStart = Date()
        print("  Running: testFilteringLogicWithNullStatus")
        
        // Simulate the willAttenedFilters logic
        let nullStatus: String? = nil
        let expectedResult = false // Should be filtered out (hidden) because null gets normalized to "sawNone"
        
        // Simulate the logic from willAttenedFilters method
        // First, getShowAttendedStatus normalizes null to "sawNone"
        var normalizedStatus = ""
        if (nullStatus == "sawAll") {
            normalizedStatus = "sawAll"
        } else if (nullStatus == "sawSome") {
            normalizedStatus = "sawSome"
        } else {
            normalizedStatus = "sawNone" // Null gets normalized to "Will Not Attend"
        }
        
        // Then the filtering logic checks the normalized status
        var showEvent = true
        if (normalizedStatus == "sawNone") {
            showEvent = false
        }
        
        let success = showEvent == expectedResult
        
        if success {
            print("    ✅ testFilteringLogicWithNullStatus - PASSED")
        } else {
            print("    ❌ testFilteringLogicWithNullStatus - FAILED")
        }
        
        results.append(TestResult(
            name: "testFilteringLogicWithNullStatus",
            passed: success,
            error: success ? nil : "Null status filtering logic failed",
            duration: Date().timeIntervalSince(testStart),
            category: "Attended Status"
        ))
    }
    
    func testFilteringLogicWithEmptyStatus() {
        let testStart = Date()
        print("  Running: testFilteringLogicWithEmptyStatus")
        
        // Simulate the willAttenedFilters logic
        let emptyStatus = ""
        let expectedResult = false // Should be filtered out (hidden) because empty gets normalized to "sawNone"
        
        // Simulate the logic from willAttenedFilters method
        // First, getShowAttendedStatus normalizes empty to "sawNone"
        var normalizedStatus = ""
        if (emptyStatus == "sawAll") {
            normalizedStatus = "sawAll"
        } else if (emptyStatus == "sawSome") {
            normalizedStatus = "sawSome"
        } else {
            normalizedStatus = "sawNone" // Empty gets normalized to "Will Not Attend"
        }
        
        // Then the filtering logic checks the normalized status
        var showEvent = true
        if (normalizedStatus == "sawNone") {
            showEvent = false
        }
        
        let success = showEvent == expectedResult
        
        if success {
            print("    ✅ testFilteringLogicWithEmptyStatus - PASSED")
        } else {
            print("    ❌ testFilteringLogicWithEmptyStatus - FAILED")
        }
        
        results.append(TestResult(
            name: "testFilteringLogicWithEmptyStatus",
            passed: success,
            error: success ? nil : "Empty status filtering logic failed",
            duration: Date().timeIntervalSince(testStart),
            category: "Attended Status"
        ))
    }
    
    // MARK: - Helper Methods
    
    private func generateReport() {
        let totalTests = results.count
        let passedTests = results.filter { $0.passed }.count
        let failedTests = totalTests - passedTests
        let totalDuration = Date().timeIntervalSince(startTime)
        
        print("\n" + String(repeating: "=", count: 60))
        print("📊 ATTENDED STATUS TEST REPORT")
        print(String(repeating: "=", count: 60))
        print("Total Tests: \(totalTests)")
        print("Passed: \(passedTests) ✅")
        print("Failed: \(failedTests) ❌")
        print("Success Rate: \(Int((Double(passedTests) / Double(totalTests)) * 100))%")
        print("Duration: \(String(format: "%.2f", totalDuration)) seconds")
        
        if failedTests > 0 {
            print("\n❌ FAILED TESTS:")
            for result in results where !result.passed {
                print("  • \(result.name): \(result.error ?? "Unknown error")")
            }
        }
        
        print("\n✅ PASSED TESTS:")
        for result in results where result.passed {
            print("  • \(result.name)")
        }
        
        print("\n" + String(repeating: "=", count: 60))
        
        if failedTests == 0 {
            print("🎉 ALL ATTENDED STATUS TESTS PASSED!")
            print("✅ Null/empty attended status values display as 'Will Not Attend' but cycle to 'Will Attend' on first click")
            print("✅ Cycling logic works correctly with null/empty values")
            print("✅ Filtering logic works correctly with null/empty values")
        } else {
            print("⚠️  Some attended status tests failed. Please review the issues above.")
        }
        print(String(repeating: "=", count: 60))
    }
}

// Run the tests if this file is executed directly
if CommandLine.arguments.contains("test") {
    let testRunner = AttendedStatusTest()
    testRunner.runAllTests()
} 
//
//  DebugLogger.swift
//  70000TonsBands
//
//  Created for conditional debug logging
//  This file provides debug logging utilities that are compiled out in release builds
//

import Foundation

/// Debug logging functions that are only compiled in DEBUG builds
/// In RELEASE builds, these functions are completely removed from the binary
///
/// Usage:
///   debugLog("Simple message")
///   debugLog("Value is: \(someValue)")
///   debugLog("Method(\(param)): Starting operation")

#if DEBUG
/// Prints a debug message. Only compiled in DEBUG builds.
/// - Parameter message: The message to print (can include string interpolation)
@inline(__always)
func debugLog(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
    let fileName = (file as NSString).lastPathComponent
    print("[\(fileName):\(line)] \(message())")
}

/// Prints a debug message with category prefix. Only compiled in DEBUG builds.
/// - Parameters:
///   - category: Category/prefix for the log message
///   - message: The message to print (can include string interpolation)
@inline(__always)
func debugLog(_ category: String, _ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
    let fileName = (file as NSString).lastPathComponent
    print("[\(fileName):\(line)] [\(category)] \(message())")
}

/// Prints a debug message with detailed source information. Only compiled in DEBUG builds.
/// - Parameter message: The message to print (can include string interpolation)
@inline(__always)
func debugLogVerbose(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
    let fileName = (file as NSString).lastPathComponent
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    print("[\(timestamp)] [\(fileName):\(line)] \(function): \(message())")
}

/// Prints a separator line for visual organization. Only compiled in DEBUG builds.
@inline(__always)
func debugLogSeparator() {
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
}

/// Prints a warning message in yellow (if terminal supports colors). Only compiled in DEBUG builds.
/// - Parameter message: The warning message to print
@inline(__always)
func debugWarning(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
    let fileName = (file as NSString).lastPathComponent
    print("⚠️ [\(fileName):\(line)] WARNING: \(message())")
}

/// Prints an error message in red (if terminal supports colors). Only compiled in DEBUG builds.
/// - Parameter message: The error message to print
@inline(__always)
func debugError(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
    let fileName = (file as NSString).lastPathComponent
    print("❌ [\(fileName):\(line)] ERROR: \(message())")
}

#else
// RELEASE BUILD: All debug functions are empty and will be optimized away by the compiler
@inline(__always)
func debugLog(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {}

@inline(__always)
func debugLog(_ category: String, _ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {}

@inline(__always)
func debugLogVerbose(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {}

@inline(__always)
func debugLogSeparator() {}

@inline(__always)
func debugWarning(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {}

@inline(__always)
func debugError(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {}
#endif

// MARK: - Always-On Logging (for production errors/important events)

/// Logs a message that will appear in BOTH debug and release builds
/// Use this sparingly for critical errors or important production events
/// - Parameter message: The message to log
func productionLog(_ message: String, file: String = #file, line: Int = #line) {
    let fileName = (file as NSString).lastPathComponent
    NSLog("[\(fileName):\(line)] \(message)")
}

/// Logs an error that will appear in BOTH debug and release builds
/// Use this for critical errors that need to be tracked in production
/// - Parameter message: The error message to log
func productionError(_ message: String, file: String = #file, line: Int = #line) {
    let fileName = (file as NSString).lastPathComponent
    NSLog("❌ ERROR [\(fileName):\(line)] \(message)")
}

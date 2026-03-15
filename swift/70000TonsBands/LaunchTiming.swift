//
//  LaunchTiming.swift
//  70000TonsBands
//
//  Instrumentation for Option D: measure main-thread and key-path durations at launch.
//
//  How to use: Run the app normally (Xcode Run or device). Capture console output,
//  then grep for "⏱️ [LAUNCH]" to see all timed events. No Instruments or special run needed.
//
//  Log format: "⏱️ [LAUNCH] <ms>ms [MAIN|BG] <label> START|END duration=<ms>ms"
//  - First column "ms" = milliseconds since the first instrumented line (first entry ~0ms).
//  - MAIN = ran on main (UI) thread (can cause lag); BG = background.
//  - duration= only on END lines; sum MAIN durations to see main-thread cost.
//

import Foundation

enum LaunchTiming {
    private static var referenceTime: Date?
    private static let lock = NSLock()

    /// Milliseconds since the first call to msSinceLaunch() in this process.
    static func msSinceLaunch() -> Double {
        lock.lock()
        defer { lock.unlock() }
        if referenceTime == nil {
            referenceTime = Date()
        }
        return Date().timeIntervalSince(referenceTime!) * 1000
    }

    /// Log a timed block end: label, thread (MAIN/BG), and duration in ms.
    static func logEnd(_ label: String, startTime: Date, thread: String = Thread.isMainThread ? "MAIN" : "BG") {
        let durationMs = Date().timeIntervalSince(startTime) * 1000
        let sinceLaunch = msSinceLaunch()
        print("⏱️ [LAUNCH] \(String(format: "%.1f", sinceLaunch))ms [\(thread)] \(label) END duration=\(String(format: "%.1f", durationMs))ms")
    }

    /// Log a block start (no duration).
    static func logStart(_ label: String, thread: String = Thread.isMainThread ? "MAIN" : "BG") {
        let sinceLaunch = msSinceLaunch()
        print("⏱️ [LAUNCH] \(String(format: "%.1f", sinceLaunch))ms [\(thread)] \(label) START")
    }
}

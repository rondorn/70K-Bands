//
//  MasterViewYearChangeCoordinator.swift
//  70000TonsBands
//
//  Extracted from MasterViewController: year-change / CSV refresh coordination shared across
//  preferences, band loading, and the main list. Behavior matches the original static logic.
//

import UIKit

/// Owns global (process-wide) state for year transitions and overlapping refresh work.
/// `MasterViewController` forwards static members here so existing `MasterViewController.*` call sites stay valid.
final class MasterViewYearChangeCoordinator {

    static var currentDataRefreshOperationId: UUID = UUID()
    static var isYearChangeInProgress: Bool = false
    static var isCsvDownloadInProgress: Bool = false
    static var isRefreshingAlerts: Bool = false
    static let backgroundRefreshLock = NSLock()

    private static var yearChangeDataReady: Bool = false
    private static let yearChangeDataReadyLock = NSLock()
    private static var pendingYearChangeCompletion: Bool = false

    private static var yearChangeStartTime: Date?
    private static var deadlockDetectionTimer: Timer?

    static func notifyYearChangeStarting() {
        print("🚨 [YEAR_CHANGE_DEADLOCK_FIX] Year change starting - cancelling ALL background operations")
        isYearChangeInProgress = true
        currentDataRefreshOperationId = UUID()
        yearChangeStartTime = Date()

        yearChangeDataReadyLock.lock()
        yearChangeDataReady = false
        pendingYearChangeCompletion = false
        yearChangeDataReadyLock.unlock()

        deadlockDetectionTimer?.invalidate()
        deadlockDetectionTimer = Timer.scheduledTimer(withTimeInterval: 45.0, repeats: false) { _ in
            print("🚨 DEADLOCK DETECTED: Year change has been running for 45+ seconds")
            print("🚨 EMERGENCY RECOVERY: Forcing year change completion")

            notifyYearChangeCompleted()

            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("EmergencyYearChangeRecovery"),
                    object: nil
                )
            }
        }
    }

    /// Marks year change data as ready — called after initial data load completes.
    static func markYearChangeDataReady() {
        yearChangeDataReadyLock.lock()
        yearChangeDataReady = true
        let shouldComplete = pendingYearChangeCompletion
        yearChangeDataReadyLock.unlock()

        if shouldComplete {
            notifyYearChangeCompleted()
        }
    }

    static func notifyYearChangeCompleted() {
        yearChangeDataReadyLock.lock()
        let dataReady = yearChangeDataReady
        if !dataReady {
            pendingYearChangeCompletion = true
            yearChangeDataReadyLock.unlock()
            return
        }
        pendingYearChangeCompletion = false
        yearChangeDataReadyLock.unlock()

        print("✅ [YEAR_CHANGE_DEADLOCK_FIX] Year change completed - background operations can resume")
        isYearChangeInProgress = false

        deadlockDetectionTimer?.invalidate()
        deadlockDetectionTimer = nil

        if let startTime = yearChangeStartTime {
            let duration = Date().timeIntervalSince(startTime)
            print("📊 Year change took \(String(format: "%.2f", duration)) seconds")
            yearChangeStartTime = nil
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("YearChangeCompleted"),
                object: nil
            )
        }
    }

    static func isYearChangeDataReady() -> Bool {
        yearChangeDataReadyLock.lock()
        defer { yearChangeDataReadyLock.unlock() }
        return yearChangeDataReady
    }
}

// MARK: - Backward compatibility

extension MasterViewController {
    static var currentDataRefreshOperationId: UUID {
        get { MasterViewYearChangeCoordinator.currentDataRefreshOperationId }
        set { MasterViewYearChangeCoordinator.currentDataRefreshOperationId = newValue }
    }

    static var isYearChangeInProgress: Bool {
        get { MasterViewYearChangeCoordinator.isYearChangeInProgress }
        set { MasterViewYearChangeCoordinator.isYearChangeInProgress = newValue }
    }

    static var isCsvDownloadInProgress: Bool {
        get { MasterViewYearChangeCoordinator.isCsvDownloadInProgress }
        set { MasterViewYearChangeCoordinator.isCsvDownloadInProgress = newValue }
    }

    static var isRefreshingAlerts: Bool {
        get { MasterViewYearChangeCoordinator.isRefreshingAlerts }
        set { MasterViewYearChangeCoordinator.isRefreshingAlerts = newValue }
    }

    static var backgroundRefreshLock: NSLock {
        MasterViewYearChangeCoordinator.backgroundRefreshLock
    }

    static func notifyYearChangeStarting() {
        MasterViewYearChangeCoordinator.notifyYearChangeStarting()
    }

    static func markYearChangeDataReady() {
        MasterViewYearChangeCoordinator.markYearChangeDataReady()
    }

    static func notifyYearChangeCompleted() {
        MasterViewYearChangeCoordinator.notifyYearChangeCompleted()
    }

    static func isYearChangeDataReady() -> Bool {
        MasterViewYearChangeCoordinator.isYearChangeDataReady()
    }
}

//
//  BackgroundWorkMonitor.swift
//  70000TonsBands
//
//  Tracks deferred local schedule-alert rebuilds and bulk image/notes downloads.
//

import Foundation

/// Persists pending background work so foreground recovery can retry after iOS suspends a task.
final class BackgroundWorkMonitor {
    static let shared = BackgroundWorkMonitor()

    private let lock = NSLock()
    private let localAlertsPendingKey = "BackgroundWork.localAlertsPending"
    private let bulkDownloadPendingKey = "BackgroundWork.bulkDownloadPending"
    private var localAlertsPending = false
    private var bulkDownloadPending = false
    /// Prevents UserDefaults.didChangeNotification → refreshAlerts feedback when we persist pending flags.
    private(set) var suppressRefreshAlertsObserver = false

    private init() {
        localAlertsPending = UserDefaults.standard.bool(forKey: localAlertsPendingKey)
        bulkDownloadPending = UserDefaults.standard.bool(forKey: bulkDownloadPendingKey)
    }

    func markLocalAlertsPending(context: String) {
        lock.lock()
        if localAlertsPending {
            lock.unlock()
            return
        }
        localAlertsPending = true
        lock.unlock()

        print("🔔 [LOCAL_ALERTS] Marked pending (\(context))")
        persistLocalAlertsPending(true)
    }

    func hasPendingLocalAlerts() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return localAlertsPending
    }

    func clearLocalAlertsPending() {
        lock.lock()
        if !localAlertsPending {
            lock.unlock()
            return
        }
        localAlertsPending = false
        lock.unlock()

        print("🔔 [LOCAL_ALERTS] Cleared pending flag")
        persistLocalAlertsPending(false)
    }

    func shouldSuppressRefreshAlertsObserver() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return suppressRefreshAlertsObserver
    }

    func markBulkDownloadPending(context: String) {
        lock.lock()
        if bulkDownloadPending {
            lock.unlock()
            return
        }
        bulkDownloadPending = true
        lock.unlock()

        print("📦 [BULK_DOWNLOAD] Marked pending (\(context))")
        persistBulkDownloadPending(true)
    }

    func hasPendingBulkDownload() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return bulkDownloadPending
    }

    func clearBulkDownloadPending() {
        lock.lock()
        if !bulkDownloadPending {
            lock.unlock()
            return
        }
        bulkDownloadPending = false
        lock.unlock()

        print("📦 [BULK_DOWNLOAD] Cleared pending flag")
        persistBulkDownloadPending(false)
    }

    /// UserDefaults writes post `didChangeNotification` synchronously — never do that under lock or on a serial queue we might re-enter.
    private func persistLocalAlertsPending(_ value: Bool) {
        DispatchQueue.main.async {
            self.suppressRefreshAlertsObserver = true
            UserDefaults.standard.set(value, forKey: self.localAlertsPendingKey)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.suppressRefreshAlertsObserver = false
            }
        }
    }

    private func persistBulkDownloadPending(_ value: Bool) {
        DispatchQueue.global(qos: .utility).async {
            UserDefaults.standard.set(value, forKey: self.bulkDownloadPendingKey)
        }
    }
}

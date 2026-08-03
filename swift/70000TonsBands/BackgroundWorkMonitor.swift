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

    private let queue = DispatchQueue(label: "BackgroundWorkMonitor.queue")
    private let localAlertsPendingKey = "BackgroundWork.localAlertsPending"
    private let bulkDownloadPendingKey = "BackgroundWork.bulkDownloadPending"

    private init() {}

    func markLocalAlertsPending(context: String) {
        queue.sync {
            UserDefaults.standard.set(true, forKey: localAlertsPendingKey)
            print("🔔 [LOCAL_ALERTS] Marked pending (\(context))")
        }
    }

    func hasPendingLocalAlerts() -> Bool {
        queue.sync {
            UserDefaults.standard.bool(forKey: localAlertsPendingKey)
        }
    }

    func clearLocalAlertsPending() {
        queue.sync {
            UserDefaults.standard.set(false, forKey: localAlertsPendingKey)
            print("🔔 [LOCAL_ALERTS] Cleared pending flag")
        }
    }

    func markBulkDownloadPending(context: String) {
        queue.sync {
            UserDefaults.standard.set(true, forKey: bulkDownloadPendingKey)
            print("📦 [BULK_DOWNLOAD] Marked pending (\(context))")
        }
    }

    func hasPendingBulkDownload() -> Bool {
        queue.sync {
            UserDefaults.standard.bool(forKey: bulkDownloadPendingKey)
        }
    }

    func clearBulkDownloadPending() {
        queue.sync {
            UserDefaults.standard.set(false, forKey: bulkDownloadPendingKey)
            print("📦 [BULK_DOWNLOAD] Cleared pending flag")
        }
    }
}

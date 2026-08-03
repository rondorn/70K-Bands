import Foundation

/// Tracks Firebase write outcomes and determines when a full resync is needed.
/// Band and show dirty flags are tracked separately so a band edit does not touch showData.
final class FirebaseWriteMonitor {
    static let shared = FirebaseWriteMonitor()

    private let queue = DispatchQueue(label: "FirebaseWriteMonitor.queue")
    private let legacyDirtyFlagKey = "FirebaseWriteMonitor.hasPendingLocalChanges"
    private let bandDirtyFlagKey = "FirebaseWriteMonitor.hasPendingBandChanges"
    private let showDirtyFlagKey = "FirebaseWriteMonitor.hasPendingShowChanges"
    private let failureFlagKey = "FirebaseWriteMonitor.hasPendingFailures"
    private let failureCountKey = "FirebaseWriteMonitor.failureCount"
    private let successCountKey = "FirebaseWriteMonitor.successCount"
    private let fullSyncInProgressKey = "FirebaseWriteMonitor.fullSyncInProgress"
    private let fullSyncSawSuccessKey = "FirebaseWriteMonitor.fullSyncSawSuccess"
    private let fullSyncHadFailureKey = "FirebaseWriteMonitor.fullSyncHadFailure"

    private init() {
        migrateLegacyDirtyFlagIfNeeded()
    }

    private func migrateLegacyDirtyFlagIfNeeded() {
        queue.sync {
            let defaults = UserDefaults.standard
            if defaults.bool(forKey: legacyDirtyFlagKey) {
                defaults.set(true, forKey: bandDirtyFlagKey)
                defaults.set(true, forKey: showDirtyFlagKey)
                defaults.set(false, forKey: legacyDirtyFlagKey)
            }
        }
    }

    func recordWriteSuccess(context: String) {
        queue.async {
            let defaults = UserDefaults.standard
            let current = defaults.integer(forKey: self.successCountKey)
            defaults.set(current + 1, forKey: self.successCountKey)
            if defaults.bool(forKey: self.fullSyncInProgressKey) {
                defaults.set(true, forKey: self.fullSyncSawSuccessKey)
            }
            if context.hasPrefix("band_batch") {
                defaults.set(false, forKey: self.bandDirtyFlagKey)
            }
            if context.hasPrefix("event_batch") {
                defaults.set(false, forKey: self.showDirtyFlagKey)
            }
            print("✅ [FIREBASE_MONITOR] Success recorded (\(context)). Total successes: \(current + 1)")
        }
    }

    func recordWriteFailure(context: String) {
        queue.async {
            let defaults = UserDefaults.standard
            let current = defaults.integer(forKey: self.failureCountKey)
            defaults.set(current + 1, forKey: self.failureCountKey)
            defaults.set(true, forKey: self.failureFlagKey)
            if defaults.bool(forKey: self.fullSyncInProgressKey) {
                defaults.set(true, forKey: self.fullSyncHadFailureKey)
            }
            print("❌ [FIREBASE_MONITOR] Failure recorded (\(context)). Total failures: \(current + 1). Full sync required.")
        }
    }
    
    /// Marks that local data changed and should be fully synced later.
    func markLocalChangePendingSync(context: String) {
        queue.sync {
            let defaults = UserDefaults.standard
            if context.hasPrefix("priority:") {
                defaults.set(true, forKey: self.bandDirtyFlagKey)
                print("📝 [FIREBASE_MONITOR] Band change marked dirty (\(context)).")
            } else if context.hasPrefix("attendance:") || context.hasPrefix("attendance_clear") {
                defaults.set(true, forKey: self.showDirtyFlagKey)
                print("📝 [FIREBASE_MONITOR] Show change marked dirty (\(context)).")
            } else {
                defaults.set(true, forKey: self.bandDirtyFlagKey)
                defaults.set(true, forKey: self.showDirtyFlagKey)
                print("📝 [FIREBASE_MONITOR] Local change marked dirty (\(context)).")
            }
        }
    }
    
    func hasPendingBandChanges() -> Bool {
        var result = false
        queue.sync {
            result = UserDefaults.standard.bool(forKey: bandDirtyFlagKey)
        }
        return result
    }
    
    func hasPendingShowChanges() -> Bool {
        var result = false
        queue.sync {
            result = UserDefaults.standard.bool(forKey: showDirtyFlagKey)
        }
        return result
    }
    
    func hasPendingLocalChanges() -> Bool {
        return hasPendingBandChanges() || hasPendingShowChanges()
    }

    func hasPendingFailures() -> Bool {
        var result = false
        queue.sync {
            result = UserDefaults.standard.bool(forKey: failureFlagKey)
        }
        return result
    }
    
    func shouldRunFullSync() -> Bool {
        return hasPendingLocalChanges() || hasPendingFailures()
    }
    
    func shouldRunBandSync() -> Bool {
        return hasPendingBandChanges() || hasPendingFailures()
    }
    
    func shouldRunShowSync() -> Bool {
        return hasPendingShowChanges() || hasPendingFailures()
    }

    func beginFullSyncAttempt() {
        queue.async {
            let defaults = UserDefaults.standard
            defaults.set(true, forKey: self.fullSyncInProgressKey)
            defaults.set(false, forKey: self.fullSyncSawSuccessKey)
            defaults.set(false, forKey: self.fullSyncHadFailureKey)
            print("🔄 [FIREBASE_MONITOR] Full sync attempt started.")
        }
    }
    
    @discardableResult
    func finalizeFullSyncAttempt() -> Bool {
        var cleared = false
        queue.sync {
            let defaults = UserDefaults.standard
            let sawSuccess = defaults.bool(forKey: self.fullSyncSawSuccessKey)
            let hadFailure = defaults.bool(forKey: self.fullSyncHadFailureKey)
            
            if sawSuccess && !hadFailure {
                defaults.set(false, forKey: self.failureFlagKey)
                defaults.set(0, forKey: self.failureCountKey)
                cleared = true
                print("✅ [FIREBASE_MONITOR] Full sync succeeded. Cleared pending failure flags.")
            } else {
                print("⚠️ [FIREBASE_MONITOR] Full sync not confirmed successful (sawSuccess=\(sawSuccess), hadFailure=\(hadFailure)). Keeping pending flags.")
            }
            
            defaults.set(false, forKey: self.fullSyncInProgressKey)
            defaults.set(false, forKey: self.fullSyncSawSuccessKey)
            defaults.set(false, forKey: self.fullSyncHadFailureKey)
        }
        return cleared
    }
    
    func clearPendingStateAfterFullSyncTriggered() {
        queue.async {
            let defaults = UserDefaults.standard
            defaults.set(false, forKey: self.bandDirtyFlagKey)
            defaults.set(false, forKey: self.showDirtyFlagKey)
            defaults.set(false, forKey: self.failureFlagKey)
            defaults.set(0, forKey: self.failureCountKey)
            print("🔄 [FIREBASE_MONITOR] Cleared pending dirty/failure flags after full sync trigger.")
        }
    }
}

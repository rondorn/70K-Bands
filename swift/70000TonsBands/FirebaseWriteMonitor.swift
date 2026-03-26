import Foundation

/// Tracks Firebase write outcomes and determines when a full resync is needed.
/// The failure flag persists until a full sync is triggered.
final class FirebaseWriteMonitor {
    static let shared = FirebaseWriteMonitor()

    private let queue = DispatchQueue(label: "FirebaseWriteMonitor.queue")
    private let dirtyFlagKey = "FirebaseWriteMonitor.hasPendingLocalChanges"
    private let failureFlagKey = "FirebaseWriteMonitor.hasPendingFailures"
    private let failureCountKey = "FirebaseWriteMonitor.failureCount"
    private let successCountKey = "FirebaseWriteMonitor.successCount"
    private let fullSyncInProgressKey = "FirebaseWriteMonitor.fullSyncInProgress"
    private let fullSyncSawSuccessKey = "FirebaseWriteMonitor.fullSyncSawSuccess"
    private let fullSyncHadFailureKey = "FirebaseWriteMonitor.fullSyncHadFailure"

    private init() {}

    func recordWriteSuccess(context: String) {
        queue.async {
            let defaults = UserDefaults.standard
            let current = defaults.integer(forKey: self.successCountKey)
            defaults.set(current + 1, forKey: self.successCountKey)
            if defaults.bool(forKey: self.fullSyncInProgressKey) {
                defaults.set(true, forKey: self.fullSyncSawSuccessKey)
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
    /// This persists across app restarts and is independent from write-failure callbacks.
    func markLocalChangePendingSync(context: String) {
        queue.async {
            UserDefaults.standard.set(true, forKey: self.dirtyFlagKey)
            print("📝 [FIREBASE_MONITOR] Local change marked dirty (\(context)). Full sync required.")
        }
    }
    
    func hasPendingLocalChanges() -> Bool {
        var result = false
        queue.sync {
            result = UserDefaults.standard.bool(forKey: dirtyFlagKey)
        }
        return result
    }

    /// Returns true if a full Firebase resync should run.
    func hasPendingFailures() -> Bool {
        var result = false
        queue.sync {
            result = UserDefaults.standard.bool(forKey: failureFlagKey)
        }
        return result
    }
    
    /// Returns true when either local changes are pending or failures were observed.
    func shouldRunFullSync() -> Bool {
        return hasPendingLocalChanges() || hasPendingFailures()
    }

    /// Marks the beginning of a full-sync attempt.
    func beginFullSyncAttempt() {
        queue.async {
            let defaults = UserDefaults.standard
            defaults.set(true, forKey: self.fullSyncInProgressKey)
            defaults.set(false, forKey: self.fullSyncSawSuccessKey)
            defaults.set(false, forKey: self.fullSyncHadFailureKey)
            print("🔄 [FIREBASE_MONITOR] Full sync attempt started.")
        }
    }
    
    /// Finalizes a full-sync attempt.
    /// Pending state is cleared only when at least one write succeeded and no writes failed.
    @discardableResult
    func finalizeFullSyncAttempt() -> Bool {
        var cleared = false
        queue.sync {
            let defaults = UserDefaults.standard
            let sawSuccess = defaults.bool(forKey: self.fullSyncSawSuccessKey)
            let hadFailure = defaults.bool(forKey: self.fullSyncHadFailureKey)
            
            if sawSuccess && !hadFailure {
                defaults.set(false, forKey: self.dirtyFlagKey)
                defaults.set(false, forKey: self.failureFlagKey)
                defaults.set(0, forKey: self.failureCountKey)
                cleared = true
                print("✅ [FIREBASE_MONITOR] Full sync succeeded. Cleared pending dirty/failure flags.")
            } else {
                print("⚠️ [FIREBASE_MONITOR] Full sync not confirmed successful (sawSuccess=\(sawSuccess), hadFailure=\(hadFailure)). Keeping pending flags.")
            }
            
            defaults.set(false, forKey: self.fullSyncInProgressKey)
            defaults.set(false, forKey: self.fullSyncSawSuccessKey)
            defaults.set(false, forKey: self.fullSyncHadFailureKey)
        }
        return cleared
    }
    
    /// Force-clears pending-sync state after a known-good full sync trigger.
    /// Prefer finalizeFullSyncAttempt() for normal flow.
    func clearPendingStateAfterFullSyncTriggered() {
        queue.async {
            let defaults = UserDefaults.standard
            defaults.set(false, forKey: self.dirtyFlagKey)
            defaults.set(false, forKey: self.failureFlagKey)
            defaults.set(0, forKey: self.failureCountKey)
            print("🔄 [FIREBASE_MONITOR] Cleared pending dirty/failure flags after full sync trigger.")
        }
    }
}

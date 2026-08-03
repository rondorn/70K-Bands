//
//  FirebaseConnectionHelper.swift
//  70K Bands
//

import Foundation
import Firebase

/// Lazily opens and closes Firebase Realtime Database connections to stay within concurrent connection limits.
enum FirebaseConnectionHelper {
    private static let queue = DispatchQueue(label: "FirebaseConnectionHelper.queue")

    static func databaseReference() -> DatabaseReference? {
        guard AppDelegate.isFirebaseConfigured else {
            print("⚠️ [FIREBASE_CONN] Firebase not configured — skipping database reference")
            return nil
        }
        return Database.database().reference()
    }

    static func goOffline(reason: String) {
        guard AppDelegate.isFirebaseConfigured else { return }
        queue.async {
            Database.database().goOffline()
            print("🔌 [FIREBASE_CONN] goOffline (\(reason))")
        }
    }

    static func goOnline(reason: String) {
        guard AppDelegate.isFirebaseConfigured else { return }
        queue.sync {
            Database.database().goOnline()
            print("🔌 [FIREBASE_CONN] goOnline (\(reason))")
        }
    }

    /// Spreads connection opens across launches using a stable per-device delay (0–20s).
    static func jitterDelayMs(for userId: String, maxJitterMs: Int = 20_000) -> Int {
        guard !userId.isEmpty else { return 0 }
        let hash = abs(userId.hashValue)
        return hash % (maxJitterMs + 1)
    }

    /// Festival year for Firebase paths: always `Current::eventYear` from the pointer file,
    /// never UI browse year or calendar fallback. Returns 0 when unknown — callers must skip writes.
    static func firebaseStorageEventYear(maxWaitSeconds: TimeInterval = 0) -> Int {
        let deadline = Date().addingTimeInterval(maxWaitSeconds)
        repeat {
            if let year = pointerConfigCurrentEventYearInt(), year > 2000 {
                return year
            }

            var memoryYear: Int?
            storePointerLock.sync {
                if let value = cacheVariables.storePointerData["Current:eventYear"],
                   let year = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)),
                   year > 2000 {
                    memoryYear = year
                }
            }
            if let year = memoryYear {
                return year
            }

            if maxWaitSeconds > 0, Date() < deadline {
                Thread.sleep(forTimeInterval: 0.5)
            } else {
                break
            }
        } while Date() < deadline

        print("❌ [FIREBASE_CONN] Unable to resolve pointer Current event year for Firebase storage")
        return 0
    }
}

/// Filter Xcode console with: `FIREBASE_SYNC_TRACE`
enum FirebaseSyncTrace {
    static let prefix = "[FIREBASE_SYNC_TRACE]"

    static func log(_ step: String, _ detail: String = "") {
        if detail.isEmpty {
            print("\(prefix) \(step)")
        } else {
            print("\(prefix) \(step) | \(detail)")
        }
    }

    static func snapshot(_ label: String) {
        let monitor = FirebaseWriteMonitor.shared
        let uid = UIDevice.current.identifierForVendor?.uuidString ?? "nil"
        let uidShort = uid.count > 8 ? String(uid.prefix(8)) + "…" : uid
        let storageYear = FirebaseConnectionHelper.firebaseStorageEventYear()
        let profile = SharedPreferencesManager.shared.getActivePreferenceSource()
        log(
            "SNAPSHOT \(label)",
            "uid=\(uidShort) profile=\(profile) bandDirty=\(monitor.hasPendingBandChanges()) showDirty=\(monitor.hasPendingShowChanges()) pendingFailures=\(monitor.hasPendingFailures()) shouldRunFullSync=\(monitor.shouldRunFullSync()) shouldRunBandSync=\(monitor.shouldRunBandSync()) firebaseConfigured=\(AppDelegate.isFirebaseConfigured) storageYear=\(storageYear) uiEventYear=\(eventYear) inTestEnvironment=\(inTestEnvironment)"
        )
    }
}

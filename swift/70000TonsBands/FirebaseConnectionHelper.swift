//
//  FirebaseConnectionHelper.swift
//  70K Bands
//

import Foundation
import Firebase

/// Lazily opens and closes Firebase Realtime Database connections to stay within concurrent connection limits.
///
/// One WebSocket per app. Sessions are refcounted so overlapping user/band/show writes share one
/// connection, then disconnect after a short idle so a herd of launches does not stay online.
enum FirebaseConnectionHelper {
    private static let queue = DispatchQueue(label: "FirebaseConnectionHelper.queue")
    private static var writeSessionCount = 0
    private static var idleCloseWork: DispatchWorkItem?
    /// Coalesce back-to-back writes (user then band) into one connection pulse.
    private static let idleCloseDelaySeconds: TimeInterval = 1.0
    static let launchJitterMaxMs = 20_000

    static func databaseReference() -> DatabaseReference? {
        guard AppDelegate.isFirebaseConfigured else {
            print("⚠️ [FIREBASE_CONN] Firebase not configured — skipping database reference")
            return nil
        }
        return Database.database().reference()
    }

    /// Opens the RTDB connection if this is the first in-flight write on this device.
    @discardableResult
    static func beginWriteSession(reason: String) -> DatabaseReference? {
        guard AppDelegate.isFirebaseConfigured else {
            print("⚠️ [FIREBASE_CONN] Firebase not configured — skipping write session (\(reason))")
            return nil
        }
        queue.sync {
            idleCloseWork?.cancel()
            idleCloseWork = nil
            writeSessionCount += 1
            if writeSessionCount == 1 {
                Database.database().goOnline()
                print("🔌 [FIREBASE_CONN] goOnline (\(reason)) sessions=1")
            } else {
                print("🔌 [FIREBASE_CONN] reuse connection (\(reason)) sessions=\(writeSessionCount)")
            }
        }
        return Database.database().reference()
    }

    /// Closes the RTDB connection when the last in-flight write finishes (after a 1s idle).
    static func endWriteSession(reason: String) {
        guard AppDelegate.isFirebaseConfigured else { return }
        queue.async {
            writeSessionCount = max(0, writeSessionCount - 1)
            print("🔌 [FIREBASE_CONN] endWriteSession (\(reason)) sessions=\(writeSessionCount)")
            guard writeSessionCount == 0 else { return }
            idleCloseWork?.cancel()
            let work = DispatchWorkItem {
                if writeSessionCount == 0 {
                    Database.database().goOffline()
                    print("🔌 [FIREBASE_CONN] goOffline (idle after \(reason))")
                }
            }
            idleCloseWork = work
            queue.asyncAfter(deadline: .now() + idleCloseDelaySeconds, execute: work)
        }
    }

    /// After `FirebaseApp.configure()` the SDK is online. Disconnect until a write session starts.
    static func goIdleAfterConfigure() {
        guard AppDelegate.isFirebaseConfigured else { return }
        queue.async {
            if writeSessionCount == 0 {
                Database.database().goOffline()
                print("🔌 [FIREBASE_CONN] goOffline (post-configure idle)")
            }
        }
    }

    /// Spreads connection opens across launches using a stable per-device delay (0–20s).
    /// 200 devices launching together → ~10 starts/sec over 20s; short sessions aim for ~25 concurrent.
    static func jitterDelayMs(for userId: String, maxJitterMs: Int = launchJitterMaxMs) -> Int {
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

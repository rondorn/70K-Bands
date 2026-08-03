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

    /// Spreads connection opens across launches using a stable per-device delay (0–20s).
    static func jitterDelayMs(for userId: String, maxJitterMs: Int = 20_000) -> Int {
        guard !userId.isEmpty else { return 0 }
        let hash = abs(userId.hashValue)
        return hash % (maxJitterMs + 1)
    }
}

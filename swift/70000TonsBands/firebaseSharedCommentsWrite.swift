//
//  firebaseSharedCommentsWrite.swift
//  70K Bands
//
//  Write-only Firebase submissions for shared band descriptions.
//

import Foundation
import Firebase

class firebaseSharedCommentsWrite {

    var ref: DatabaseReference?
    private let maxAttempts = 3
    private let retryDelay: TimeInterval = 2.0

    init() {
        initializeFirebaseReference()
    }

    private func initializeFirebaseReference(attempt: Int = 1) {
        guard AppDelegate.isFirebaseConfigured else {
            print("⚠️ [SHARED_COMMENTS] Firebase not configured (attempt \(attempt)/\(maxAttempts))")
            if attempt < maxAttempts {
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + retryDelay) { [weak self] in
                    self?.initializeFirebaseReference(attempt: attempt + 1)
                }
            }
            return
        }

        ref = Database.database().reference()
        print("✅ [SHARED_COMMENTS] Firebase reference initialized")
    }

    /// Writes to `notes/{userID}/{year}/{band}`.
    func writeSharedComment(
        bandName: String,
        descriptionText: String,
        userName: String,
        completion: @escaping (Bool) -> Void
    ) {
        if inTestEnvironment {
            print("⏭️ [SHARED_COMMENTS] Skipping write in test environment")
            DispatchQueue.main.async { completion(true) }
            return
        }

        guard !bandName.isEmpty else {
            DispatchQueue.main.async { completion(false) }
            return
        }

        guard let firebaseRef = ref else {
            print("❌ [SHARED_COMMENTS] Firebase reference not initialized")
            FirebaseWriteMonitor.shared.recordWriteFailure(context: "shared_comments_ref_nil")
            DispatchQueue.main.async { completion(false) }
            return
        }

        let userDataHandle = userDataHandler()
        guard !userDataHandle.uid.isEmpty else {
            print("❌ [SHARED_COMMENTS] Missing user ID")
            FirebaseWriteMonitor.shared.recordWriteFailure(context: "shared_comments_uid_empty")
            DispatchQueue.main.async { completion(false) }
            return
        }

        let sanitizedBandName = sanitizeBandNameForFirebase(bandName)
        let yearString = String(eventYear)
        let path = "notes/\(userDataHandle.uid)/\(yearString)/\(sanitizedBandName)"

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let payload: [String: Any] = [
            "userID": userDataHandle.uid,
            "userName": userName,
            "band": bandName,
            "year": yearString,
            "descriptionText": descriptionText,
            "updatedAt": formatter.string(from: Date())
        ]

        print("📝 [SHARED_COMMENTS] Writing to \(path)")

        firebaseRef.child(path).setValue(payload) { error, _ in
            if let error = error {
                print("❌ [SHARED_COMMENTS] Write failed: \(error.localizedDescription)")
                FirebaseWriteMonitor.shared.recordWriteFailure(context: "shared_comments:\(bandName)")
                DispatchQueue.main.async { completion(false) }
            } else {
                print("✅ [SHARED_COMMENTS] Write succeeded for '\(bandName)'")
                FirebaseWriteMonitor.shared.recordWriteSuccess(context: "shared_comments:\(bandName)")
                DispatchQueue.main.async { completion(true) }
            }
        }
    }

    private func sanitizeBandNameForFirebase(_ bandName: String) -> String {
        bandName
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "#", with: "_")
            .replacingOccurrences(of: "$", with: "_")
            .replacingOccurrences(of: "[", with: "_")
            .replacingOccurrences(of: "]", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "'", with: "_")
            .replacingOccurrences(of: "\"", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .components(separatedBy: .controlCharacters).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

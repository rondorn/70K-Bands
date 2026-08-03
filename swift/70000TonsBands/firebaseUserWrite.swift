//
//  firebaseUserWrite.swift
//  70K Bands
//
//  Created by Ron Dorn on 3/19/19.
//  Copyright © 2019 Ron Dorn. All rights reserved.
//

import Foundation
import Firebase

class firebaseUserWrite {

    static let shared = firebaseUserWrite()

    private static let dedupDefaultsKey = "firebaseUserWrite.compareBlock"
    private static let maxJitterMs = 20_000

    private let schedulerQueue = DispatchQueue(label: "firebaseUserWrite.scheduler")
    private var pendingWorkItem: DispatchWorkItem?
    private var writeInProgress = false

    private init() {}

    /// Legacy entry point — schedules a jittered write when data changed.
    func writeData() {
        firebaseUserWrite.scheduleWriteIfNeeded()
    }

    /// Schedules a user-data write with deterministic 0–20s jitter.
    static func scheduleWriteIfNeeded() {
        shared.scheduleWriteIfNeededInternal(immediate: false)
    }

    /// Cancels any pending schedule and writes immediately (e.g. app entering background).
    static func flushPendingWriteOnBackground() {
        shared.scheduleWriteIfNeededInternal(immediate: true)
    }

    private func scheduleWriteIfNeededInternal(immediate: Bool) {
        guard inTestEnvironment == false else { return }

        schedulerQueue.async {
            let hadPendingWrite = self.pendingWorkItem != nil
            if let pending = self.pendingWorkItem {
                pending.cancel()
                self.pendingWorkItem = nil
            }

            let userDataHandle = userDataHandler()
            guard userDataHandle.uid.isEmpty == false else { return }

            if immediate {
                if hadPendingWrite || self.shouldSkipDueToDedup(for: userDataHandle) == false {
                    print("🔥 [USER_WRITE] Flushing pending user write immediately on background")
                    self.performWrite(markDedupBeforeWrite: true)
                } else {
                    print("🔥 [USER_WRITE] Background flush skipped — already written today with same metadata")
                }
                return
            }

            if self.shouldSkipDueToDedup(for: userDataHandle) {
                print("🔥 [USER_WRITE] Skipping — already sent today with same metadata")
                return
            }

            let delayMs = FirebaseConnectionHelper.jitterDelayMs(for: userDataHandle.uid, maxJitterMs: Self.maxJitterMs)
            print("🔥 [USER_WRITE] Scheduling write after \(delayMs)ms deterministic jitter")

            let workItem = DispatchWorkItem { [weak self] in
                self?.pendingWorkItem = nil
                self.performWrite(markDedupBeforeWrite: true)
            }
            self.pendingWorkItem = workItem
            self.schedulerQueue.asyncAfter(deadline: .now() + .milliseconds(delayMs), execute: workItem)
        }
    }

    private func shouldSkipDueToDedup(for userDataHandle: userDataHandler) -> Bool {
        let compareBlock = buildCompareBlock(for: userDataHandle)
        return compareBlock == UserDefaults.standard.string(forKey: Self.dedupDefaultsKey)
    }

    private func buildCompareBlock(for userDataHandle: userDataHandler) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd/MM/yyyy"
        let dateOnly = formatter.string(from: Date())
        return "\(userDataHandle.country)-\(userDataHandle.language)-\(userDataHandle.bandsVersion)-\(dateOnly)"
    }

    private func performWrite(markDedupBeforeWrite: Bool) {
        guard writeInProgress == false else {
            print("🔥 [USER_WRITE] Write already in progress — skipping duplicate request")
            return
        }
        writeInProgress = true

        DispatchQueue.global(qos: .utility).async { [weak self] in
            defer { self?.writeInProgress = false }

            guard let self = self else { return }

            let userDataHandle = userDataHandler()
            guard userDataHandle.uid.isEmpty == false else { return }

            if markDedupBeforeWrite {
                let compareBlock = self.buildCompareBlock(for: userDataHandle)
                UserDefaults.standard.set(compareBlock, forKey: Self.dedupDefaultsKey)
            }

            guard let firebaseRef = FirebaseConnectionHelper.databaseReference() else {
                print("⚠️ [USER_WRITE] Firebase reference unavailable, skipping write")
                FirebaseWriteMonitor.shared.recordWriteFailure(context: "user_ref_nil")
                return
            }

            let allProfiles = SQLiteProfileManager.shared.getAllProfiles()
            let activeProfileCount = allProfiles.count

            print("🔥 [USER_WRITE] Writing userData for \(userDataHandle.uid)")
            firebaseRef.child("userData/").child(userDataHandle.uid).setValue([
                "userID": userDataHandle.uid,
                "country": userDataHandle.country,
                "language": userDataHandle.language,
                "platform": "iOS",
                "osVersion": userDataHandle.iosVersion,
                "70kVersion": userDataHandle.bandsVersion,
                "lastLaunch": userDataHandle.getCurrentDateString(),
                "activeProfiles": activeProfileCount
            ]) { error, _ in
                if let error = error {
                    print("🔥 [USER_WRITE] Write failed: \(error)")
                    FirebaseWriteMonitor.shared.recordWriteFailure(context: "user:\(userDataHandle.uid)")
                } else {
                    print("🔥 [USER_WRITE] Write succeeded")
                    FirebaseWriteMonitor.shared.recordWriteSuccess(context: "user:\(userDataHandle.uid)")
                }
                FirebaseConnectionHelper.goOffline(reason: "user_write_complete")
            }
        }
    }
}

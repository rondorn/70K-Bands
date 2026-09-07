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

    private static let lastSuccessfulWriteTimeKey = "firebaseUserWrite.lastSuccessfulWriteTime"
    /// Prevents duplicate writes from jitter + background flush in the same session, not across relaunches.
    private static let writeCooldownSeconds: TimeInterval = 60
    private static let maxJitterMs = 20_000

    private let schedulerQueue = DispatchQueue(label: "firebaseUserWrite.scheduler")
    private var pendingWorkItem: DispatchWorkItem?
    private var writeInProgress = false

    private init() {}

    /// Legacy entry point — schedules a jittered write when data changed.
    func writeData() {
        firebaseUserWrite.scheduleWriteIfNeeded()
    }

    /// Schedules a user-data write with deterministic 0–20s jitter (launch / foreground).
    static func scheduleWriteIfNeeded() {
        shared.scheduleWriteIfNeededInternal(immediate: false)
    }

    /// Cancels any pending schedule and writes immediately (e.g. app entering background).
    static func flushPendingWriteOnBackground() {
        shared.scheduleWriteIfNeededInternal(immediate: true)
    }

    /// Writes now with no extra jitter. Use after the launch/foreground window has already waited.
    static func writeImmediatelyIfNeeded() {
        shared.scheduleWriteIfNeededInternal(immediate: true)
    }

    private func scheduleWriteIfNeededInternal(immediate: Bool) {
        guard inTestEnvironment == false else {
            print("🔥 [USER_WRITE] Skipping — simulator/test environment (inTestEnvironment=true)")
            NetworkCounter.record("Firebase-User skipped=simulator")
            return
        }

        schedulerQueue.async {
            let hadPendingWrite = self.pendingWorkItem != nil
            if let pending = self.pendingWorkItem {
                pending.cancel()
                self.pendingWorkItem = nil
            }

            let userDataHandle = userDataHandler()
            guard userDataHandle.uid.isEmpty == false else {
                print("🔥 [USER_WRITE] Skipping — uid empty")
                return
            }

            if immediate {
                if hadPendingWrite || self.shouldSkipDueToCooldown() == false {
                    print("🔥 [USER_WRITE] Flushing user write immediately")
                    self.performWrite()
                } else {
                    print("🔥 [USER_WRITE] Background flush skipped — wrote successfully within cooldown")
                }
                return
            }

            if self.shouldSkipDueToCooldown() {
                print("🔥 [USER_WRITE] Skipping — wrote successfully within cooldown")
                return
            }

            let delayMs = FirebaseConnectionHelper.jitterDelayMs(for: userDataHandle.uid, maxJitterMs: Self.maxJitterMs)
            print("🔥 [USER_WRITE] Scheduling write after \(delayMs)ms deterministic jitter")

            let workItem = DispatchWorkItem { [weak self] in
                self?.pendingWorkItem = nil
                self?.performWrite()
            }
            self.pendingWorkItem = workItem
            self.schedulerQueue.asyncAfter(deadline: .now() + .milliseconds(delayMs), execute: workItem)
        }
    }

    private func shouldSkipDueToCooldown() -> Bool {
        let last = UserDefaults.standard.double(forKey: Self.lastSuccessfulWriteTimeKey)
        guard last > 0 else { return false }
        return Date().timeIntervalSince1970 - last < Self.writeCooldownSeconds
    }

    private func performWrite() {
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

            if AppDelegate.isFirebaseConfigured == false {
                print("🔥 [USER_WRITE] Firebase not configured yet — retrying in 4s")
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 4.0) {
                    firebaseUserWrite.writeImmediatelyIfNeeded()
                }
                return
            }

            let activeProfileCount = SQLiteProfileManager.shared.getAllProfiles().count

            print("🔥 [USER_WRITE] Writing userData for \(userDataHandle.uid)")
            guard let firebaseRef = FirebaseConnectionHelper.beginWriteSession(reason: "user") else {
                print("⚠️ [USER_WRITE] Firebase reference unavailable, skipping write")
                FirebaseWriteMonitor.shared.recordWriteFailure(context: "user_ref_nil")
                return
            }
            NetworkCounter.record("Firebase-User")
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
                    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastSuccessfulWriteTimeKey)
                    FirebaseWriteMonitor.shared.recordWriteSuccess(context: "user:\(userDataHandle.uid)")
                }
                FirebaseConnectionHelper.endWriteSession(reason: "user_write_complete")
            }
        }
    }
}

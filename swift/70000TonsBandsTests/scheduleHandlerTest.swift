//
//  scheduleHandlerTest.swift
//  70K Bands
//
//  Created by Ron Dorn on 2/10/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import XCTest

/// QA **Chapter 1 — Bands only** (`pointer_bands_only.txt`): lineup + **empty schedule** (header-only or no event rows).
/// This suite asserts **no** schedule events, not missing data.
///
/// Planned additions (separate fixtures / cases): Ch.2 bands + preparties; then future-dated events; then current/past window.
class loadingSchedule: XCTestCase {

    /// `scheduleHandler` is a singleton (`private init`); tests must use `shared`.
    var schedule: scheduleHandler { scheduleHandler.shared }

    func testViewDidLoad() {
        downloadCsvSchedule()
        getCsvScheduleOffline()
    }

    func downloadCsvSchedule() {
        print("Sync: Loading schedule data loadingSchedule")
        schedule.DownloadCsv()
        schedule.populateSchedule()

        XCTAssertTrue(
            schedule.schedulingData.isEmpty,
            "Band-only fixture: expect no per-band schedule entries (QA Ch.1)"
        )
        XCTAssertTrue(
            schedule.schedulingDataByTime.isEmpty,
            "Band-only fixture: expect no time-indexed events (QA Ch.1)"
        )
    }

    func getCsvScheduleOffline() {
        schedule.schedulingData = [String: [TimeInterval: [String: String]]]()
        schedule.populateSchedule()

        print(schedule.schedulingData)
        XCTAssertTrue(
            schedule.schedulingData.isEmpty,
            "Band-only fixture: offline populate should leave schedule empty (QA Ch.1)"
        )
        XCTAssertTrue(
            schedule.schedulingDataByTime.isEmpty,
            "Band-only fixture: no time slots without event rows (QA Ch.1)"
        )
    }
}

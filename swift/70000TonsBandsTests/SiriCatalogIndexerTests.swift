//
//  SiriCatalogIndexerTests.swift
//  70K BandsTests
//

import XCTest

final class SiriCatalogIndexerTests: XCTestCase {

    func testPointerYearsSkipCurrentAndRepairSingleColonURL() {
        let pointer = """
        Default::artistUrl::https://example.com/default-artist.csv
        Default::scheduleUrl::https://example.com/default-schedule.csv
        Current::artistUrl::https://example.com/2026-artist.csv
        Current::scheduleUrl::https://example.com/2026-schedule.csv
        Current::eventYear::2026
        2026::artistUrl::https://example.com/2026-artist.csv
        2026::scheduleUrl::https://example.com/2026-schedule.csv
        2014::artistUrl:https://example.com/2014-artist.csv
        2014::scheduleUrl::https://example.com/2014-schedule.csv
        """
        let years = SiriCatalogPointer.years(in: pointer)
        XCTAssertEqual(years.map(\.year), [2014, 2026])
        XCTAssertEqual(years[0].artistURL, "https://example.com/2014-artist.csv")
        XCTAssertEqual(years[1].scheduleURL, "https://example.com/2026-schedule.csv")
    }

    func testCurrentYearIsUsedWhenItHasNoSection() {
        let pointer = """
        Current::artistUrl::https://example.com/artist.csv
        Current::scheduleUrl::https://example.com/schedule.csv
        Current::eventYear::2026
        """
        let years = SiriCatalogPointer.years(in: pointer)
        XCTAssertEqual(years.count, 1)
        XCTAssertEqual(years[0].year, 2026)
        XCTAssertEqual(years[0].artistURL, "https://example.com/artist.csv")
    }

    func testCurrentYearComesFromThePointerCurrentSection() {
        let pointer = """
        Current::eventYear::2026
        2025::artistUrl::https://example.com/2025-artist.csv
        2025::scheduleUrl::https://example.com/2025-schedule.csv
        2026::artistUrl::https://example.com/2026-artist.csv
        2026::scheduleUrl::https://example.com/2026-schedule.csv
        """
        XCTAssertEqual(SiriCatalogPointer.currentYear(in: pointer), 2026)
    }

    func testCheckpointMatchesOnlyWhenIndexedBytesAreUnchanged() {
        let entry = SiriCatalogCheckpointEntry(
            artistURL: "https://example.com/a.csv",
            scheduleURL: "https://example.com/s.csv",
            artistChecksum: "aaa",
            scheduleChecksum: "bbb",
            indexed: true
        )
        XCTAssertTrue(entry.isCurrent(
            artistURL: "https://example.com/a.csv",
            scheduleURL: "https://example.com/s.csv",
            artistChecksum: "aaa",
            scheduleChecksum: "bbb"
        ))
        XCTAssertFalse(entry.isCurrent(
            artistURL: "https://example.com/a.csv",
            scheduleURL: "https://example.com/s.csv",
            artistChecksum: "changed",
            scheduleChecksum: "bbb"
        ))
        var unfinished = entry
        unfinished.indexed = false
        XCTAssertFalse(unfinished.isCurrent(
            artistURL: entry.artistURL,
            scheduleURL: entry.scheduleURL,
            artistChecksum: entry.artistChecksum,
            scheduleChecksum: entry.scheduleChecksum
        ))
    }
}

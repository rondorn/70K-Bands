//
//  QAWalkthroughChapter1UITests.swift
//  70K BandsUITests
//
//  Mirrors QA_WALKTHROUGH.md Chapter 1: bands-only pointer, then spot-check fixture band visible.
//

import XCTest

final class QAWalkthroughChapter1UITests: XCTestCase {

    /// Same URL as QA_WALKTHROUGH.md Ch.1 (GitHub raw pointer).
    private let chapter1PointerURL =
        "https://raw.githubusercontent.com/rondorn/70K-Bands/master/qa-config/pointers/pointer_bands_only.txt"

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITESTING"] = "1"
        app.launchEnvironment["UITEST_CUSTOM_POINTER_URL"] = chapter1PointerURL
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// First slice of walkthrough: custom pointer applied at launch; after load, a known fixture band appears.
    func testChapter1_PointerBandsOnly_ShowsFixtureBand() throws {
        app.launch()

        // Network + SQLite + pointer chain can be slow on CI; allow up to 3 minutes.
        let amorphis = app.staticTexts["Amorphis"]
        XCTAssertTrue(
            amorphis.waitForExistence(timeout: 180),
            "Expected fixture band 'Amorphis' to appear after Ch.1 pointer load (see QA_WALKTHROUGH Ch.1 / setup)."
        )
    }

    /// QA_WALKTHROUGH.md Ch.1 step 4+: open band detail and verify all four link icons open the in-app web sheet and dismiss.
    /// Fixture `qa_lineup_three_bands.csv` includes official, Metal Archives, Wikipedia, and YouTube URLs for Amorphis.
    func testChapter1_BandDetail_FourLinksOpenAndDismissWebSheet() throws {
        app.launch()

        let table = app.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 180), "Expected main band table after Ch.1 pointer load.")

        let amorphisCell = table.cells.containing(.staticText, identifier: "Amorphis").element
        XCTAssertTrue(
            amorphisCell.waitForExistence(timeout: 180),
            "Expected a row containing 'Amorphis'."
        )
        scrollCellOnScreen(amorphisCell, in: table)
        amorphisCell.tap()

        let linksLabel = app.staticTexts["Links:"]
        XCTAssertTrue(
            linksLabel.waitForExistence(timeout: 60),
            "Expected band detail Links section (QA_WALKTHROUGH Ch.1 band detail)."
        )

        let linkIds = [
            "bandDetailLinkOfficial",
            "bandDetailLinkMetalArchives",
            "bandDetailLinkWikipedia",
            "bandDetailLinkYouTube",
        ]
        for linkId in linkIds {
            let linkButton = app.buttons[linkId]
            XCTAssertTrue(
                linkButton.waitForExistence(timeout: 30),
                "Expected detail link button \(linkId) for Amorphis fixture."
            )
            XCTAssertTrue(linkButton.isHittable, "Link \(linkId) should be tappable.")
            linkButton.tap()

            let done = app.buttons["bandDetailWebSheetDone"]
            XCTAssertTrue(
                done.waitForExistence(timeout: 25),
                "Tapping \(linkId) should present in-app web sheet with Done (default link preferences)."
            )
            done.tap()
            XCTAssertTrue(
                linksLabel.waitForExistence(timeout: 15),
                "After Done, detail Links section should be visible again."
            )
        }
    }

    private func scrollCellOnScreen(_ cell: XCUIElement, in table: XCUIElement) {
        var attempts = 0
        while !cell.isHittable && attempts < 25 {
            table.swipeUp()
            attempts += 1
        }
    }
}

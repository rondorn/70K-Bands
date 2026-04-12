//
//  QAWalkthroughChapter1RankingUITests.swift
//  70K BandsUITests
//
//  QA_WALKTHROUGH Ch.1: narrative ranking — three bands, three UI paths; then filter sheet to show
//  **Wont** only. Priority icons use UITest-only AX (`qaMasterCellPriorityIcon`). Do **not** scroll
//  the master list for ranking steps: pick bands from the **top** of the sorted lineup. Filters
//  are opened only in the final phase (Show Unknown / Must / Might off, Show Wont on).
//
//  Band-ranking toggles are driven in UI tests by **UIKit** `UISwitch` views
//  (`FilterMenuUITestSwitchesView`, portrait filter menu bottom strip when `UITESTING=1`), not SwiftUI
//  toggles — XCUITest does not reliably expose those.
//

import XCTest

final class QAWalkthroughChapter1RankingUITests: XCTestCase {

    private let chapter1PointerURL =
        "https://raw.githubusercontent.com/rondorn/70K-Bands/master/qa-config/pointers/pointer_bands_only.txt"

    private var app: XCUIApplication!

    /// First rows under locale name sort in `qa_lineup_three_bands.csv` (must stay in the first viewport).
    private let bandSwipeMust = "Abysmal Dawn"
    private let bandLongPressMight = "Amorphis"
    private let bandDetailWont = "Angra"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITESTING"] = "1"
        app.launchArguments.append("-UITesting")
        app.launchArguments.append(contentsOf: ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"])
        app.launchEnvironment["UITEST_CUSTOM_POINTER_URL"] = chapter1PointerURL
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// Fresh install + launch + dismiss dialogs, then rank three bands (swipe / long-press / detail)
    /// and assert after each step via the row priority icon (no Filters sheet).
    func testChapter1_NarrativeRankingThreeBands_StepwiseVerified() throws {
        app.launch()

        XCTContext.runActivity(named: "Dismiss launch alerts (notification and/or country confirm)") { _ in
            dismissPostLaunchDialogsIfNeeded()
        }

        let table = app.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 180), "Band table should load.")

        XCTAssertTrue(
            table.staticTexts[bandSwipeMust].firstMatch.waitForExistence(timeout: 180),
            "Fixture should include \(bandSwipeMust) in the master table (top of name-sorted list)."
        )

        waitForListBandCount(app: app, exact: 60, timeout: 35)
        XCTAssertEqual(table.cells.count, 60, "Full lineup should be visible before ranking (default filters/sort).")

        // 1) First visible row → Must via swipe actions
        XCTContext.runActivity(named: "Mark \(bandSwipeMust) as Must (swipe), verify row icon") { _ in
            let cell = requireBandRowOnScreenAtDefaultScroll(table: table, bandName: bandSwipeMust)
            applyRankViaSwipe(cell: cell, rank: 1)
            assertMasterListRowShowsPriority(forBand: bandSwipeMust, rank: 1, message: "Row should show Must after swipe.")
        }

        // 2) Second row → Might via long-press menu
        XCTContext.runActivity(named: "Mark \(bandLongPressMight) as Might (long-press), verify row icon") { _ in
            let cell = requireBandRowOnScreenAtDefaultScroll(table: table, bandName: bandLongPressMight)
            applyRankViaLongPress(cell: cell, rank: 2)
            assertMasterListRowShowsPriority(forBand: bandLongPressMight, rank: 2, message: "Row should show Might after long-press.")
        }

        // 3) Third row → Wont via band detail segmented control
        XCTContext.runActivity(named: "Mark \(bandDetailWont) as Wont (detail), verify row icon") { _ in
            let cell = requireBandRowOnScreenAtDefaultScroll(table: table, bandName: bandDetailWont)
            applyRankViaDetail(cell: cell, bandName: bandDetailWont, rank: 3, table: table)
            assertMasterListRowShowsPriority(forBand: bandDetailWont, rank: 3, message: "Row should show Wont after detail.")
        }

        XCTContext.runActivity(named: "Confirm full 60-band list still visible (defaults unchanged)") { _ in
            waitForListBandCount(app: app, exact: 60, timeout: 35)
            XCTAssertEqual(table.cells.count, 60)
        }

        // Filter to **Wont** only: hide Unknown, Must, and Might — only Angra (detail Wont) should remain.
        XCTContext.runActivity(named: "Filters: hide Unknown, Must, Might — verify only Wont band(s)") { _ in
            openFilterSheet()
            setFilterToggle(identifier: "qaFilterToggleUnknownSee", on: false)
            setFilterToggle(identifier: "qaFilterToggleMustSee", on: false)
            setFilterToggle(identifier: "qaFilterToggleMightSee", on: false)
            setFilterToggle(identifier: "qaFilterToggleWontSee", on: true)
            tapFilterSheetDone()
            XCTAssertTrue(table.waitForExistence(timeout: 15))

            waitForListBandCount(app: app, exact: 1, timeout: 35)
            XCTAssertEqual(table.cells.count, 1, "With only Wont visible, expect a single row.")
            XCTAssertTrue(
                table.staticTexts[bandDetailWont].waitForExistence(timeout: 10),
                "The Wont-ranked band \(bandDetailWont) should be the only list entry."
            )
            XCTAssertFalse(
                table.staticTexts[bandSwipeMust].exists,
                "Must-ranked \(bandSwipeMust) should be filtered out."
            )
            XCTAssertFalse(
                table.staticTexts[bandLongPressMight].exists,
                "Might-ranked \(bandLongPressMight) should be filtered out."
            )
        }
    }

    // MARK: - Assertions (row priority icon)

    private func assertMasterListRowShowsPriority(forBand name: String, rank: Int, message: String) {
        let table = app.tables.firstMatch
        let cell = requireBandRowOnScreenAtDefaultScroll(table: table, bandName: name)
        let expected = segmentLabel(for: rank)
        let icon = cell.images.matching(identifier: "qaMasterCellPriorityIcon").element(boundBy: 0)
        XCTAssertTrue(icon.waitForExistence(timeout: 10), message)
        XCTAssertEqual(icon.label, expected, message)
    }

    // MARK: - Band list helpers

    private func cellForBand(table: XCUIElement, bandName: String) -> XCUIElement {
        table.cells.containing(NSPredicate(format: "label CONTAINS[c] %@", bandName)).element
    }

    /// Resolves the **table cell** for `bandName`. Query the **table’s** `staticTexts` (not `app.`):
    /// `app.staticTexts[band]` can match a non–hittable node while `exists` is true, which falsely
    /// failed `isHittable` checks. We only require the label + row to exist — no master-list scrolling.
    private func requireBandRowOnScreenAtDefaultScroll(table: XCUIElement, bandName: String) -> XCUIElement {
        let title = table.staticTexts[bandName].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 15), "Band name \(bandName) should appear in the master table.")
        let cell = cellForBand(table: table, bandName: bandName)
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "Row for \(bandName)")
        return cell
    }

    // MARK: - Ranking actions

    private func applyRankViaLongPress(cell: XCUIElement, rank: Int) {
        let el = app.buttons[longPressButtonId(rank: rank)]
        cell.press(forDuration: 0.9)
        XCTAssertTrue(el.waitForExistence(timeout: 8), "Long-press priority menu for rank \(rank)")
        el.tap()
    }

    private func longPressButtonId(rank: Int) -> String {
        switch rank {
        case 1: return "qaLongPressMust"
        case 2: return "qaLongPressMight"
        case 3: return "qaLongPressWont"
        default:
            XCTFail("Invalid rank \(rank)")
            return "qaLongPressMust"
        }
    }

    private func swipeButtonId(rank: Int) -> String {
        switch rank {
        case 1: return "qaSwipeMust"
        case 2: return "qaSwipeMight"
        case 3: return "qaSwipeWont"
        default:
            XCTFail("Invalid rank \(rank)")
            return "qaSwipeMust"
        }
    }

    private func applyRankViaSwipe(cell: XCUIElement, rank: Int) {
        let bid = swipeButtonId(rank: rank)

        if priorityIconAlreadyShowsRank(cell: cell, rank: rank) {
            return
        }

        if swipeActionButton(bid).waitForExistence(timeout: 1) {
            swipeActionButton(bid).tap()
            return
        }

        // A full swipe can **perform** the first action and dismiss the tray without a separate tap.
        // The swipe button then disappears while the row already shows the new rank — keep swiping
        // only until the icon matches, not until `qaSwipe…` exists again.
        XCTAssertTrue(cell.exists, "Cell must exist before row swipe")
        for attempt in 0 ..< 18 {
            if attempt > 0, waitForPriorityIcon(cell: cell, rank: rank, waitUpTo: 0.6) {
                return
            }
            if swipeActionButton(bid).exists {
                swipeActionButton(bid).tap()
                return
            }
            let start = cell.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.5))
            let end = cell.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
            start.press(forDuration: 0.22, thenDragTo: end)
            Thread.sleep(forTimeInterval: 0.35)
            if waitForPriorityIcon(cell: cell, rank: rank) {
                return
            }
        }

        if !swipeActionButton(bid).exists && !waitForPriorityIcon(cell: cell, rank: rank) {
            for _ in 0 ..< 10 {
                if swipeActionButton(bid).exists {
                    swipeActionButton(bid).tap()
                    return
                }
                if waitForPriorityIcon(cell: cell, rank: rank) {
                    return
                }
                cell.swipeLeft()
                Thread.sleep(forTimeInterval: 0.25)
                if waitForPriorityIcon(cell: cell, rank: rank) {
                    return
                }
            }
        }

        if waitForPriorityIcon(cell: cell, rank: rank) {
            return
        }

        let btn = swipeActionButton(bid)
        XCTAssertTrue(
            btn.waitForExistence(timeout: 6),
            "Swipe action \(bid) — could not reveal or apply; row icon still not \(segmentLabel(for: rank))."
        )
        btn.tap()
    }

    /// Single snapshot — use at the start of `applyRankViaSwipe` (no long poll before first gesture).
    private func priorityIconAlreadyShowsRank(cell: XCUIElement, rank: Int) -> Bool {
        let expected = segmentLabel(for: rank)
        let icon = cell.images.matching(identifier: "qaMasterCellPriorityIcon").element(boundBy: 0)
        return icon.exists && icon.label == expected
    }

    /// After a swipe, iOS may apply the row action and reload; the tray closes — poll until the icon matches.
    private func waitForPriorityIcon(cell: XCUIElement, rank: Int, waitUpTo timeout: TimeInterval = 2.5) -> Bool {
        let expected = segmentLabel(for: rank)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let icon = cell.images.matching(identifier: "qaMasterCellPriorityIcon").element(boundBy: 0)
            if icon.exists && icon.label == expected {
                return true
            }
            Thread.sleep(forTimeInterval: 0.12)
        }
        return false
    }

    /// `UITableViewRowAction` buttons often appear as top-level `app.buttons` once the swipe tray is open,
    /// not only under the cell query — always resolve via `app.buttons[…]`.
    private func swipeActionButton(_ identifier: String) -> XCUIElement {
        app.buttons[identifier]
    }

    private func applyRankViaDetail(cell: XCUIElement, bandName: String, rank: Int, table: XCUIElement) {
        cell.tap()
        let picker = app.segmentedControls["bandDetailPriorityPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 20), "Detail priority picker for \(bandName)")
        let segmentTitle = segmentLabel(for: rank)
        picker.buttons[segmentTitle].tap()
        let back = app.navigationBars.buttons["Back"]
        XCTAssertTrue(back.waitForExistence(timeout: 10))
        back.tap()
        XCTAssertTrue(table.waitForExistence(timeout: 15))
    }

    private func segmentLabel(for rank: Int) -> String {
        switch rank {
        case 1: return NSLocalizedString("Must", comment: "A Must See Band")
        case 2: return NSLocalizedString("Might", comment: "A Might See Band")
        case 3: return NSLocalizedString("Wont", comment: "A Wont See Band")
        default:
            XCTFail("Bad rank")
            return "Must"
        }
    }

    // MARK: - Filter sheet (Band Ranking toggles)

    private func openFilterSheet() {
        tapFiltersButtonOpeningSheet()
        waitForFilterSheetPresented()
    }

    private func tapFiltersButtonOpeningSheet() {
        let filtersTitle = NSLocalizedString("Filters", comment: "")
        let header = app.descendants(matching: .any).matching(identifier: "qaMasterListFiltersHeader").element(boundBy: 0)
        if !header.waitForExistence(timeout: 15) {
            let toolbarFilters = app.toolbars.firstMatch.buttons[filtersTitle]
            XCTAssertTrue(toolbarFilters.waitForExistence(timeout: 8), "qaMasterListFiltersHeader or toolbar Filters ‘\(filtersTitle)’")
            toolbarFilters.tap()
            return
        }
        let filtersBtn = header.buttons[filtersTitle]
        XCTAssertTrue(filtersBtn.waitForExistence(timeout: 6), "Filters button inside qaMasterListFiltersHeader")
        filtersBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func waitForFilterSheetPresented(timeout: TimeInterval = 40) {
        // Primary: UITest-only UIKit switches (same ids as SwiftUI toggles) — always in the tree when the menu is up.
        if uitestBandFilterSwitch(identifier: "qaFilterToggleUnknownSee").waitForExistence(timeout: min(20, timeout)) {
            return
        }
        let list = filterSheetListElement()
        let sheetRoot = app.descendants(matching: .any).matching(identifier: "qaCommonFilterSheetRoot").element(boundBy: 0)
        if list.waitForExistence(timeout: min(timeout, 10)) { return }
        if sheetRoot.waitForExistence(timeout: min(timeout, 15)) { return }
        XCTAssertTrue(
            filterSheetDoneElement().waitForExistence(timeout: 8),
            "Filter sheet did not appear (UITest UISwitches, qaFilterSheetList, qaCommonFilterSheetRoot, or qaFilterSheetDone)"
        )
    }

    private func filterSheetDoneElement() -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "qaFilterSheetDone").element(boundBy: 0)
    }

    private func tapFilterSheetDone() {
        let doneTitle = NSLocalizedString("Done", comment: "")
        let byId = filterSheetDoneElement()
        if byId.waitForExistence(timeout: 4) {
            byId.tap()
            return
        }
        if app.buttons[doneTitle].waitForExistence(timeout: 3) {
            app.buttons[doneTitle].tap()
            return
        }
        if app.staticTexts[doneTitle].waitForExistence(timeout: 3) {
            app.staticTexts[doneTitle].tap()
        }
    }

    /// `UISwitch` in `FilterMenuUITestSwitchesView` — `value` is "0" / "1". `on` is the desired **Show** state.
    private func setFilterToggle(identifier: String, on: Bool) {
        waitForUitestBandFilterSwitch(identifier: identifier)
        let toggle = filterSwitchElement(identifier: identifier)
        let onStr = (toggle.value as? String) ?? "0"
        let isOn = (onStr == "1")
        if isOn == on { return }
        toggle.tap()
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            let v = (toggle.value as? String) ?? "0"
            if (v == "1") == on { return }
            toggle.tap()
        }
        XCTFail("Could not set \(identifier) to Show=\(on)")
    }

    /// SwiftUI `List` often maps to an XCUI `Table`; fall back to any element with the id (debug / legacy).
    private func filterSheetListElement() -> XCUIElement {
        let asTable = app.tables.matching(identifier: "qaFilterSheetList").element(boundBy: 0)
        if asTable.waitForExistence(timeout: 1.0) {
            return asTable
        }
        return app.descendants(matching: .any).matching(identifier: "qaFilterSheetList").element(boundBy: 0)
    }

    private func uitestBandFilterSwitch(identifier: String) -> XCUIElement {
        app.switches.matching(identifier: identifier).element(boundBy: 0)
    }

    private func waitForUitestBandFilterSwitch(identifier: String) {
        XCTAssertTrue(
            uitestBandFilterSwitch(identifier: identifier).waitForExistence(timeout: 15),
            "Expected UITest UISwitch \(identifier) on the portrait filter menu (FilterMenuUITestSwitchesView)."
        )
    }

    private func filterSwitchElement(identifier: String) -> XCUIElement {
        uitestBandFilterSwitch(identifier: identifier)
    }

    // MARK: - Launch alerts

    private func dismissPostLaunchDialogsIfNeeded() {
        let confirmCountry = NSLocalizedString("confirmCountry", comment: "")
        let allowLabels = ["Allow", "Don’t Allow", "Don't Allow"]
        let genericDismiss = ["OK", "Continue", "Dismiss", "Close"]
        let deadline = Date().addingTimeInterval(25)
        while Date() < deadline {
            guard app.alerts.firstMatch.waitForExistence(timeout: 2.0) else { return }
            let alert = app.alerts.firstMatch
            if alert.buttons[confirmCountry].exists {
                alert.buttons[confirmCountry].tap()
                Thread.sleep(forTimeInterval: 0.35)
                continue
            }
            var tapped = false
            for label in allowLabels + genericDismiss {
                let b = alert.buttons[label]
                if b.exists {
                    b.tap()
                    tapped = true
                    Thread.sleep(forTimeInterval: 0.35)
                    break
                }
            }
            if !tapped {
                // Unknown copy — tap the last button (often “Don’t Allow” / secondary) to clear the sheet.
                let buttons = alert.buttons
                if buttons.count > 0 {
                    buttons.element(boundBy: buttons.count - 1).tap()
                    Thread.sleep(forTimeInterval: 0.35)
                    continue
                }
                return
            }
        }
    }

    private func waitForListBandCount(app: XCUIApplication, exact: Int, timeout: TimeInterval) {
        let el = app.staticTexts["qaMasterListCountTitle"]
        XCTAssertTrue(el.waitForExistence(timeout: min(timeout, 15)))
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let n = parsedDisplayedCount(from: el.label), n == exact { return }
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTFail("Expected title count \(exact), last label: \(el.label)")
    }

    private func parsedDisplayedCount(from label: String) -> Int? {
        let pattern = "(\\d+)\\s+Bands"
        guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(label.startIndex..., in: label)
        guard let m = re.firstMatch(in: label, options: [], range: range),
              let dr = Range(m.range(at: 1), in: label) else { return nil }
        return Int(String(label[dr]))
    }
}

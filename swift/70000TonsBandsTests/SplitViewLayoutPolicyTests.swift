//
//  SplitViewLayoutPolicyTests.swift
//  70K BandsTests
//
//  iPhone Duo / split-view layout rules.
//

import XCTest
import UIKit

class SplitViewLayoutPolicyTests: XCTestCase {

    func testIPadUsesSplitInBothOrientations() {
        XCTAssertTrue(
            SplitViewLayoutPolicy.shouldUseSplitView(idiom: .pad, isLargeDisplay: true, isLandscape: false)
        )
        XCTAssertTrue(
            SplitViewLayoutPolicy.shouldUseSplitView(idiom: .pad, isLargeDisplay: true, isLandscape: true)
        )
    }

    func testPhoneSplitOnlyInLandscapeWhenLarge() {
        XCTAssertFalse(
            SplitViewLayoutPolicy.shouldUseSplitView(idiom: .phone, isLargeDisplay: true, isLandscape: false),
            "Duo open portrait with no band open should be list-only"
        )
        XCTAssertTrue(
            SplitViewLayoutPolicy.shouldUseSplitView(idiom: .phone, isLargeDisplay: true, isLandscape: true),
            "Duo open landscape / Pro Max landscape should split"
        )
    }

    func testOpenDetailDoesNotKeepSplitInPhonePortrait() {
        // Landscape split → open a band → rotate to portrait must leave split.
        // Keeping split for an open detail left a squeezed secondary that ate taps.
        XCTAssertFalse(
            SplitViewLayoutPolicy.shouldUseSplitView(
                idiom: .phone,
                isLargeDisplay: true,
                isLandscape: false,
                hasOpenDetail: true
            ),
            "Open Duo portrait is list/detail stacked, never side-by-side"
        )
    }

    func testCompactCoverDoesNotSplitEvenWithDetailOpen() {
        XCTAssertFalse(
            SplitViewLayoutPolicy.shouldUseSplitView(
                idiom: .phone,
                isLargeDisplay: false,
                isLandscape: false,
                hasOpenDetail: true
            ),
            "Closed Duo cover stays one column"
        )
        XCTAssertFalse(
            SplitViewLayoutPolicy.shouldUseSplitView(
                idiom: .phone,
                isLargeDisplay: false,
                isLandscape: true,
                hasOpenDetail: true
            )
        )
    }

    func testLandscapePhoneStillSplitsWithOrWithoutDetail() {
        XCTAssertTrue(
            SplitViewLayoutPolicy.shouldUseSplitView(
                idiom: .phone,
                isLargeDisplay: true,
                isLandscape: true,
                hasOpenDetail: false
            )
        )
        XCTAssertTrue(
            SplitViewLayoutPolicy.shouldUseSplitView(
                idiom: .phone,
                isLargeDisplay: true,
                isLandscape: true,
                hasOpenDetail: true
            )
        )
    }

    func testPlaceholderColumnIsNotAnOpenBandDetail() {
        let placeholder = UIViewController()
        placeholder.title = "Band Details"
        let navigation = UINavigationController(rootViewController: placeholder)
        XCTAssertFalse(SplitViewLayoutPolicy.containsBandDetail(nil))
        XCTAssertFalse(SplitViewLayoutPolicy.containsBandDetail(placeholder))
        XCTAssertFalse(SplitViewLayoutPolicy.containsBandDetail(navigation))
        XCTAssertTrue(SplitViewLayoutPolicy.isPlaceholderDetail(navigation))
    }

    func testPushedDetailIsNotInstalledOnTheOnlyColumn() {
        XCTAssertFalse(
            SplitViewLayoutPolicy.canInstallPushedDetailOnExistingSecondary(columnCount: 1),
            "The only column while closed is the band list"
        )
        XCTAssertTrue(
            SplitViewLayoutPolicy.canInstallPushedDetailOnExistingSecondary(columnCount: 2)
        )
    }

    func testCompactPhoneNeverSplits() {
        XCTAssertFalse(
            SplitViewLayoutPolicy.shouldUseSplitView(idiom: .phone, isLargeDisplay: false, isLandscape: false)
        )
        XCTAssertFalse(
            SplitViewLayoutPolicy.shouldUseSplitView(idiom: .phone, isLargeDisplay: false, isLandscape: true),
            "Closed Duo / normal iPhone stays list (or landscape calendar), not split"
        )
    }

    func testManualCalendarToggleOnOpenDuoEvenInPortrait() {
        XCTAssertTrue(
            SplitViewLayoutPolicy.shouldOfferManualScheduleCalendarToggle(
                usesSplitLayout: false,
                hingeAvailable: true,
                isHingeClosed: false
            ),
            "Open Duo portrait must show the calendar icon"
        )
        XCTAssertTrue(
            SplitViewLayoutPolicy.shouldOfferManualScheduleCalendarToggle(
                usesSplitLayout: true,
                hingeAvailable: true,
                isHingeClosed: false
            ),
            "Open Duo landscape / split still shows the calendar icon"
        )
    }

    func testManualCalendarToggleHiddenOnClosedDuoAndPhone() {
        XCTAssertFalse(
            SplitViewLayoutPolicy.shouldOfferManualScheduleCalendarToggle(
                usesSplitLayout: false,
                hingeAvailable: true,
                isHingeClosed: true
            ),
            "Closed Duo cover must not show the calendar icon"
        )
        XCTAssertFalse(
            SplitViewLayoutPolicy.shouldOfferManualScheduleCalendarToggle(
                usesSplitLayout: false,
                hingeAvailable: false,
                isHingeClosed: false
            ),
            "Regular iPhone uses landscape auto-calendar, not the icon"
        )
    }

    func testManualCalendarToggleOnSplitLayouts() {
        XCTAssertTrue(
            SplitViewLayoutPolicy.shouldOfferManualScheduleCalendarToggle(
                usesSplitLayout: true,
                hingeAvailable: false,
                isHingeClosed: false
            ),
            "iPad / large-phone split keeps the calendar icon"
        )
    }

    func testListOnlyForcesCompactSizeClass() {
        XCTAssertTrue(SplitViewLayoutPolicy.shouldForceCompactHorizontalSizeClass(useSplit: false))
        XCTAssertFalse(SplitViewLayoutPolicy.shouldForceCompactHorizontalSizeClass(useSplit: true))
    }

    func testListOnlyPrimaryColumnFillsWindow() {
        XCTAssertEqual(
            SplitViewLayoutPolicy.primaryColumnWidth(useSplit: false, availableWidth: 834),
            834
        )
    }

    func testSplitPrimaryColumnStaysUsable() {
        let width = SplitViewLayoutPolicy.primaryColumnWidth(useSplit: true, availableWidth: 1180)
        XCTAssertEqual(width, 400)
        XCTAssertGreaterThanOrEqual(width, SplitViewLayoutPolicy.splitPrimaryColumnMinWidth)
        XCTAssertLessThan(width, 1180)
    }

    func testCompactListChromeSkipsIPadEvenWhenPrimaryIsCompact() {
        XCTAssertFalse(
            SplitViewLayoutPolicy.usesCompactListChrome(
                idiom: .pad,
                horizontalSizeClass: .compact,
                hingeAvailable: false,
                isHingeClosed: false
            ),
            "iPad split primary is compact but has no cover chrome"
        )
    }

    func testCompactListChromeUsedOnPhone() {
        XCTAssertTrue(
            SplitViewLayoutPolicy.usesCompactListChrome(
                idiom: .phone,
                horizontalSizeClass: .compact,
                hingeAvailable: false,
                isHingeClosed: false
            )
        )
    }

    func testCompactListChromeUsedOnClosedDuo() {
        XCTAssertTrue(
            SplitViewLayoutPolicy.usesCompactListChrome(
                idiom: .phone,
                horizontalSizeClass: .regular,
                hingeAvailable: true,
                isHingeClosed: true
            )
        )
    }

    func testCompactListChromeSkippedOnOpenDuoAndSplit() {
        XCTAssertFalse(
            SplitViewLayoutPolicy.usesCompactListChrome(
                idiom: .phone,
                horizontalSizeClass: .compact,
                hingeAvailable: true,
                isHingeClosed: false
            ),
            "Open Duo has no cover side chrome"
        )
        XCTAssertFalse(
            SplitViewLayoutPolicy.usesCompactListChrome(
                idiom: .phone,
                horizontalSizeClass: .compact,
                hingeAvailable: false,
                isHingeClosed: false,
                isShowingSplitLayout: true
            ),
            "Split primary is compact but must not park share/gear as cover chrome"
        )
    }

    func testNavBarOverflowShowsIconsInlineWhenBudgetAllows() {
        // Picture 1: short title leaves room — no ⋯.
        let actions: [SplitViewLayoutPolicy.NavBarTrailingAction] = [
            .calendar, .preferences
        ]
        let result = SplitViewLayoutPolicy.NavigationBarOverflowPolicy.partitionTrailingActions(
            trailingBudget: 200,
            actions: actions
        )
        XCTAssertEqual(result.inline, actions)
        XCTAssertTrue(result.overflow.isEmpty)
    }

    func testNavBarOverflowPreferencesAloneSkipsEllipsis() {
        // Band list with only preferences and a little room: gear inline, no ⋯.
        let result = SplitViewLayoutPolicy.NavigationBarOverflowPolicy.partitionTrailingActions(
            trailingBudget: 50,
            actions: [.preferences]
        )
        XCTAssertEqual(result.inline, [.preferences])
        XCTAssertTrue(result.overflow.isEmpty)
    }

    func testNavBarOverflowUsesEllipsisWhenBudgetTight() {
        // Picture 2: long "(2026) 211 Events" title leaves little trailing room.
        let actions: [SplitViewLayoutPolicy.NavBarTrailingAction] = [
            .calendar, .preferences
        ]
        let result = SplitViewLayoutPolicy.NavigationBarOverflowPolicy.partitionTrailingActions(
            trailingBudget: 70,
            actions: actions
        )
        XCTAssertTrue(result.inline.isEmpty)
        XCTAssertEqual(result.overflow, actions)
    }

    func testNavBarOverflowAllowsOneActionWhenPartialBudget() {
        let actions: [SplitViewLayoutPolicy.NavBarTrailingAction] = [
            .calendar, .preferences
        ]
        // One slot after reserving ⋯ (44), not enough for both with breathing room.
        let result = SplitViewLayoutPolicy.NavigationBarOverflowPolicy.partitionTrailingActions(
            trailingBudget: 100,
            actions: actions
        )
        XCTAssertEqual(result.inline, [.calendar])
        XCTAssertEqual(result.overflow, [.preferences])
    }

    func testNavigationTitleCentersWhenTrailingIconsFit() {
        XCTAssertTrue(
            SplitViewLayoutPolicy.shouldCenterNavigationTitle(
                inlineTrailingCount: 2,
                overflowTrailingCount: 0,
                usesCompactListChrome: false
            ),
            "Roomy iPad / Duo bars should center the app name and count"
        )
        XCTAssertTrue(
            SplitViewLayoutPolicy.shouldCenterNavigationTitle(
                inlineTrailingCount: 1,
                overflowTrailingCount: 1,
                usesCompactListChrome: false
            )
        )
    }

    func testNavigationTitleStaysLeadingWhenEllipsisOnly() {
        XCTAssertFalse(
            SplitViewLayoutPolicy.shouldCenterNavigationTitle(
                inlineTrailingCount: 0,
                overflowTrailingCount: 2,
                usesCompactListChrome: false
            ),
            "Cramped bars keep the title next to stats so ⋯ cannot crush it"
        )
    }

    func testNavigationTitleCentersOnClosedDuoCompactChrome() {
        XCTAssertTrue(
            SplitViewLayoutPolicy.shouldCenterNavigationTitle(
                inlineTrailingCount: 0,
                overflowTrailingCount: 0,
                usesCompactListChrome: true
            ),
            "Closed Duo side chrome frees the bar — title must not stay pinned left"
        )
    }

    func testNavigationTitlePinsOnlyOnClosedDuo() {
        XCTAssertTrue(
            SplitViewLayoutPolicy.shouldPinNavigationTitleOnScroll(
                hingeAvailable: true,
                isHingeClosed: true
            )
        )
        XCTAssertFalse(
            SplitViewLayoutPolicy.shouldPinNavigationTitleOnScroll(
                hingeAvailable: true,
                isHingeClosed: false
            ),
            "Open Duo must not pin title minimization"
        )
        XCTAssertFalse(
            SplitViewLayoutPolicy.shouldPinNavigationTitleOnScroll(
                hingeAvailable: false,
                isHingeClosed: false
            ),
            "iPhone and iPad have no hinge and must keep default nav scrolling"
        )
    }

    func testClosedDuoOnlyInsetsBandListPriorityIcon() {
        XCTAssertEqual(
            SplitViewLayoutPolicy.closedDuoBandListPriorityIconExtraTrailingInset(
                hingeAvailable: true,
                isHingeClosed: true
            ),
            SplitViewLayoutPolicy.closedDuoBandListPriorityIconExtraTrailing
        )
        XCTAssertEqual(
            SplitViewLayoutPolicy.closedDuoBandListPriorityIconExtraTrailingInset(
                hingeAvailable: true,
                isHingeClosed: false
            ),
            0,
            "Open Duo must not move the list priority icon"
        )
        XCTAssertEqual(
            SplitViewLayoutPolicy.closedDuoBandListPriorityIconExtraTrailingInset(
                hingeAvailable: false,
                isHingeClosed: false
            ),
            0,
            "iPhone and iPad must not move the list priority icon"
        )
    }

    func testSeparatorStopsAtTrailingSafeArea() {
        XCTAssertEqual(
            SplitViewLayoutPolicy.additionalRowTrailingInset(
                safeAreaTrailing: 72,
                contentAlreadyInSafeArea: true
            ),
            0,
            "Cells already in the safe area must not be inset again (that creates dead space)"
        )
        XCTAssertEqual(
            SplitViewLayoutPolicy.additionalRowTrailingInset(
                safeAreaTrailing: 72,
                contentAlreadyInSafeArea: false
            ),
            72
        )
        XCTAssertEqual(SplitViewLayoutPolicy.separatorTrailingInset(safeAreaTrailing: 0), 0)
        XCTAssertEqual(
            SplitViewLayoutPolicy.separatorTrailingInset(safeAreaTrailing: 72),
            72,
            "Separator lines must stop before the reserved side-icon column"
        )
        XCTAssertEqual(SplitViewLayoutPolicy.separatorTrailingInset(safeAreaTrailing: -4), 0)
    }

    func testCollapseKeepsRealDetailAndDiscardsPlaceholder() {
        XCTAssertTrue(
            SplitViewLayoutPolicy.shouldDiscardSecondaryOnCollapse(isPlaceholderDetail: true)
        )
        XCTAssertFalse(
            SplitViewLayoutPolicy.shouldDiscardSecondaryOnCollapse(isPlaceholderDetail: false)
        )
    }

    func testPlaceholderDetection() {
        XCTAssertTrue(SplitViewLayoutPolicy.isPlaceholderDetail(nil))

        let placeholder = UIViewController()
        placeholder.title = "Band Details"
        XCTAssertTrue(SplitViewLayoutPolicy.isPlaceholderDetail(placeholder))

        let nav = UINavigationController(rootViewController: placeholder)
        XCTAssertTrue(SplitViewLayoutPolicy.isPlaceholderDetail(nav))
    }

    func testDuoRevealRequiresHingeClosedAfterCollapse() {
        XCTAssertTrue(
            DuoClosedListRevealPolicy.shouldScheduleSlideToList(
                hingeAvailable: true,
                hingeClosed: true,
                keptDetailOnCollapse: true,
                transitionFinished: true,
                detailStillOnTop: true,
                cancelledByUser: false
            )
        )
    }

    func testDuoRevealIgnoredWithoutHinge() {
        XCTAssertFalse(
            DuoClosedListRevealPolicy.shouldScheduleSlideToList(
                hingeAvailable: false,
                hingeClosed: false,
                keptDetailOnCollapse: true,
                transitionFinished: true,
                detailStillOnTop: true,
                cancelledByUser: false
            ),
            "iPhone / iPad have no hinge and must not auto-slide"
        )
    }

    func testDuoRevealIgnoredIfHingeStillOpen() {
        XCTAssertFalse(
            DuoClosedListRevealPolicy.shouldScheduleSlideToList(
                hingeAvailable: true,
                hingeClosed: false,
                keptDetailOnCollapse: true,
                transitionFinished: true,
                detailStillOnTop: true,
                cancelledByUser: false
            )
        )
    }

    func testDuoRevealIgnoredBeforeTransitionFinishes() {
        XCTAssertFalse(
            DuoClosedListRevealPolicy.shouldScheduleSlideToList(
                hingeAvailable: true,
                hingeClosed: true,
                keptDetailOnCollapse: true,
                transitionFinished: false,
                detailStillOnTop: true,
                cancelledByUser: false
            )
        )
    }

    func testDuoRevealIgnoredWithoutKeptDetail() {
        XCTAssertFalse(
            DuoClosedListRevealPolicy.shouldScheduleSlideToList(
                hingeAvailable: true,
                hingeClosed: true,
                keptDetailOnCollapse: false,
                transitionFinished: true,
                detailStillOnTop: true,
                cancelledByUser: false
            )
        )
    }

    func testDuoRevealCancelledByUserTouch() {
        XCTAssertFalse(
            DuoClosedListRevealPolicy.shouldScheduleSlideToList(
                hingeAvailable: true,
                hingeClosed: true,
                keptDetailOnCollapse: true,
                transitionFinished: true,
                detailStillOnTop: true,
                cancelledByUser: true
            )
        )
    }

    func testDuoRevealDelaySkipsPeekWhenReduceMotion() {
        XCTAssertEqual(DuoClosedListRevealPolicy.delayBeforeSlide(prefersReducedMotion: true), 0)
        XCTAssertEqual(DuoClosedListRevealPolicy.delayBeforeSlide(prefersReducedMotion: false), 0.25)
    }

    func testCoverPortraitIsNotLandscapeLayout() {
        XCTAssertFalse(
            PhoneLandscapeLayoutPolicy.isLandscape(
                windowSize: CGSize(width: 466, height: 678),
                horizontalSizeClass: .compact,
                verticalSizeClass: .regular
            )
        )
    }

    func testCoverLandscapeIsCompactCompact() {
        XCTAssertTrue(
            PhoneLandscapeLayoutPolicy.isLandscape(
                windowSize: CGSize(width: 678, height: 466),
                horizontalSizeClass: .compact,
                verticalSizeClass: .compact
            ),
            "Closed Duo landscape / iPhone landscape should use the calendar overlay"
        )
        XCTAssertTrue(
            PhoneLandscapeLayoutPolicy.isLandscape(
                windowSize: CGSize(width: 400, height: 500),
                horizontalSizeClass: .compact,
                verticalSizeClass: .compact
            ),
            "Compact-compact is landscape even if the window has not reported a wide aspect yet"
        )
    }

    func testUpsideDownPortraitIsStillPortraitLayout() {
        XCTAssertFalse(
            PhoneLandscapeLayoutPolicy.isLandscape(
                windowSize: CGSize(width: 466, height: 678),
                horizontalSizeClass: .compact,
                verticalSizeClass: .regular
            ),
            "Portrait upside down stays list, not calendar"
        )
    }
}

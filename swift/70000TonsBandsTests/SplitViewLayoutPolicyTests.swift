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
            "Duo open portrait / large phone portrait should be list-only"
        )
        XCTAssertTrue(
            SplitViewLayoutPolicy.shouldUseSplitView(idiom: .phone, isLargeDisplay: true, isLandscape: true),
            "Duo open landscape / Pro Max landscape should split"
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

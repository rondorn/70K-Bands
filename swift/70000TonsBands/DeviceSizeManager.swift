//
//  DeviceSizeManager.swift
//  70K Bands
//
//  Created by Cursor on 2/8/26.
//  Copyright (c) 2026 Ron Dorn. All rights reserved.
//

import UIKit
import SwiftUI

/// Layout rules for iPhone, iPad, and foldable phones (iPhone Duo).
/// Split view is for iPad in any orientation, and for large phones (Duo inner / Pro Max)
/// in landscape only. Open Duo portrait is always a single column — an open band detail
/// is pushed on the list stack, never side-by-side (that caused stuck/unresponsive UI
/// after rotating from landscape split).
enum SplitViewLayoutPolicy {
    /// Whether master/detail should sit side by side.
    /// iPad: always. Phone: only landscape on a large display. `hasOpenDetail` is ignored
    /// for phones (kept for call-site compatibility); portrait with a band open stays
    /// single-column so rotate landscape→portrait does not leave a stuck split.
    static func shouldUseSplitView(
        idiom: UIUserInterfaceIdiom,
        isLargeDisplay: Bool,
        isLandscape: Bool,
        hasOpenDetail: Bool = false
    ) -> Bool {
        guard isLargeDisplay else { return false }
        if idiom == .pad {
            return true
        }
        // Phone / Duo: landscape only. An open detail must not keep split in portrait.
        _ = hasOpenDetail
        return isLandscape
    }

    /// A collapsed split reports only the list column. The detail must not be installed
    /// there — that replaces the band list and leaves the right column empty.
    static func canInstallPushedDetailOnExistingSecondary(columnCount: Int) -> Bool {
        columnCount > 1
    }

    /// True when this controller is showing a band, including one pushed on the list.
    static func containsBandDetail(_ viewController: UIViewController?) -> Bool {
        guard let viewController else { return false }
        if viewController is DetailHostingController {
            return true
        }
        if let navigation = viewController as? UINavigationController {
            return navigation.viewControllers.contains { $0 is DetailHostingController }
        }
        if let split = viewController as? UISplitViewController {
            return split.viewControllers.contains { containsBandDetail($0) }
        }
        return false
    }

    /// Extra inset for row content (Day column). 0 when cells already live in the safe area.
    static func additionalRowTrailingInset(
        safeAreaTrailing: CGFloat,
        contentAlreadyInSafeArea: Bool
    ) -> CGFloat {
        if contentAlreadyInSafeArea { return 0 }
        return max(0, safeAreaTrailing)
    }

    /// Separators draw across the full cell, including the unsafe area. Inset them so the
    /// line stops before the reserved side-icon column (clock / wifi / share / gear).
    static func separatorTrailingInset(safeAreaTrailing: CGFloat) -> CGFloat {
        max(0, safeAreaTrailing)
    }

    /// Share/gear belong in iOS 27 side chrome only on iPhone and closed Duo.
    /// Split layouts (iPad, open Duo) also report `.compact` on the primary column but
    /// have no cover chrome — keeping those items inline crushes the title/count.
    static func usesCompactListChrome(
        idiom: UIUserInterfaceIdiom,
        horizontalSizeClass: UIUserInterfaceSizeClass,
        hingeAvailable: Bool,
        isHingeClosed: Bool,
        isShowingSplitLayout: Bool = false
    ) -> Bool {
        guard idiom != .pad else { return false }
        if isShowingSplitLayout { return false }
        if hingeAvailable && !isHingeClosed { return false }
        return horizontalSizeClass == .compact || (hingeAvailable && isHingeClosed)
    }

    /// iOS 27 cover chrome minimizes the nav title into the list on closed Duo only.
    /// iPhone, iPad, and open Duo must keep the system default.
    static func shouldPinNavigationTitleOnScroll(
        hingeAvailable: Bool,
        isHingeClosed: Bool
    ) -> Bool {
        hingeAvailable && isHingeClosed
    }

    /// Extra trailing space for the no-schedule priority icon (tag 7) on closed Duo.
    /// The cover chrome sits on that icon; other layouts already clear it.
    static let closedDuoBandListPriorityIconExtraTrailing: CGFloat = 36

    static func closedDuoBandListPriorityIconExtraTrailingInset(
        hingeAvailable: Bool,
        isHingeClosed: Bool
    ) -> CGFloat {
        (hingeAvailable && isHingeClosed) ? closedDuoBandListPriorityIconExtraTrailing : 0
    }

    /// Regular-width windows still split unless we force compact. Duo inner portrait is
    /// regular-width, so without this the list sits beside an empty second column.
    static func shouldForceCompactHorizontalSizeClass(useSplit: Bool) -> Bool {
        !useSplit
    }

    static let splitPrimaryColumnWidth: CGFloat = 400
    static let splitPrimaryColumnMinWidth: CGFloat = 280
    static let splitPrimaryColumnMaxWidth: CGFloat = 480

    /// Side-by-side: a usable list column. List-only: fill the window so no empty pane remains.
    static func primaryColumnWidth(useSplit: Bool, availableWidth: CGFloat) -> CGFloat {
        guard availableWidth > 1 else {
            return useSplit ? splitPrimaryColumnWidth : 320
        }
        if useSplit {
            return min(splitPrimaryColumnWidth, max(splitPrimaryColumnMinWidth, availableWidth * 0.42))
        }
        return availableWidth
    }

    /// Trailing nav actions that can move into an overflow (⋯) menu when the bar is tight.
    enum NavBarTrailingAction: Equatable {
        case calendar
        case share
        case preferences
    }

    /// Decides which trailing actions stay inline vs move behind an ellipsis.
    /// `trailingBudget` is space left after stats + title — short titles (band list)
    /// can show icons inline; long titles ("(2026) 211 Events") keep them in ⋯.
    enum NavigationBarOverflowPolicy {
        static let approximateBarButtonWidth: CGFloat = 44
        static let minimumTitleWidth: CGFloat = 168
        static let leadingControlsWidth: CGFloat = 44
        static let horizontalMargins: CGFloat = 24

        /// How many trailing icons fit in the remaining nav-bar budget (no ellipsis).
        static func maxInlineTrailingCount(trailingBudget: CGFloat) -> Int {
            guard trailingBudget >= approximateBarButtonWidth else { return 0 }
            return Int(trailingBudget / approximateBarButtonWidth)
        }

        /// Extra cushion so two trailing icons don't crush a long year/count title.
        static let multiIconBreathingRoom: CGFloat = 36

        /// `actions` is priority order (calendar first). When everything fits, overflow
        /// is empty (no ⋯). Otherwise lower-priority actions move behind ⋯.
        static func partitionTrailingActions(
            trailingBudget: CGFloat,
            actions: [NavBarTrailingAction]
        ) -> (inline: [NavBarTrailingAction], overflow: [NavBarTrailingAction]) {
            guard trailingBudget > 1, !actions.isEmpty else {
                return (actions, [])
            }

            let allInlineWidth = CGFloat(actions.count) * approximateBarButtonWidth
            let needed =
                allInlineWidth
                + (actions.count > 1 ? multiIconBreathingRoom : 0)
            if trailingBudget >= needed {
                return (actions, [])
            }

            // Reserve one slot for ⋯, then fill remaining slots from the front.
            let budgetForInline = trailingBudget - approximateBarButtonWidth
            let maxInline = maxInlineTrailingCount(trailingBudget: budgetForInline)
            let inline = Array(actions.prefix(maxInline))
            let overflow = Array(actions.dropFirst(inline.count))
            if overflow.isEmpty {
                return (actions, [])
            }
            return (inline, overflow)
        }

        /// Full-bar width helper used by older call sites / tests.
        static func partitionTrailingActions(
            availableWidth: CGFloat,
            actions: [NavBarTrailingAction]
        ) -> (inline: [NavBarTrailingAction], overflow: [NavBarTrailingAction]) {
            let reserved = leadingControlsWidth + minimumTitleWidth + horizontalMargins
            return partitionTrailingActions(
                trailingBudget: availableWidth - reserved,
                actions: actions
            )
        }
    }

    /// Nav calendar/list toggle: iPad and other split layouts, plus an open Duo in any
    /// orientation. Closed Duo and regular iPhone stay orientation-driven (no icon).
    static func shouldOfferManualScheduleCalendarToggle(
        usesSplitLayout: Bool,
        hingeAvailable: Bool,
        isHingeClosed: Bool
    ) -> Bool {
        if usesSplitLayout { return true }
        return hingeAvailable && !isHingeClosed
    }

    /// Discard the secondary column when collapsing if it is only the empty placeholder.
    static func shouldDiscardSecondaryOnCollapse(isPlaceholderDetail: Bool) -> Bool {
        isPlaceholderDetail
    }

    /// Center the app-name/count in `titleView` when the bar is not ellipsis-only.
    /// Compact chrome (closed Duo / phone): always center — share/gear/stats park in the
    /// side icon column, so a leading title looks pinned in the corner.
    /// Ellipsis-only split bars keep the title in `leftBarButtonItems` so it cannot
    /// be crushed; with trailing room the same leading placement looks left-justified.
    static func shouldCenterNavigationTitle(
        inlineTrailingCount: Int,
        overflowTrailingCount: Int,
        usesCompactListChrome: Bool
    ) -> Bool {
        if usesCompactListChrome { return true }
        // Cramped: everything is behind ⋯ — keep title leading next to stats.
        if inlineTrailingCount == 0 && overflowTrailingCount > 0 { return false }
        return true
    }

    static func isPlaceholderDetail(_ viewController: UIViewController?) -> Bool {
        guard let viewController = viewController else { return true }
        let top: UIViewController
        if let nav = viewController as? UINavigationController {
            guard let navTop = nav.topViewController else { return true }
            top = navTop
        } else {
            top = viewController
        }
        if top is DetailHostingController {
            return false
        }
        return top.title == "Band Details"
    }
}

/// Compact iPhone / Duo cover landscape, including when interface orientation still reports portrait.
enum PhoneLandscapeLayoutPolicy {
    static func isLandscape(
        windowSize: CGSize,
        horizontalSizeClass: UIUserInterfaceSizeClass,
        verticalSizeClass: UIUserInterfaceSizeClass
    ) -> Bool {
        if windowSize.width > windowSize.height { return true }
        return horizontalSizeClass == .compact && verticalSizeClass == .compact
    }
}

/// After Duo closes from landscape split, briefly keep details then slide to the list.
/// Other devices never schedule this: `hingeAvailable` is false without a hinge.
enum DuoClosedListRevealPolicy {
    static let peekDuration: TimeInterval = 0.25

    static func shouldScheduleSlideToList(
        hingeAvailable: Bool,
        hingeClosed: Bool,
        keptDetailOnCollapse: Bool,
        transitionFinished: Bool,
        detailStillOnTop: Bool,
        cancelledByUser: Bool
    ) -> Bool {
        hingeAvailable
            && hingeClosed
            && keptDetailOnCollapse
            && transitionFinished
            && detailStillOnTop
            && !cancelledByUser
    }

    static func delayBeforeSlide(prefersReducedMotion: Bool) -> TimeInterval {
        prefersReducedMotion ? 0 : peekDuration
    }
}

/// Coordinates the Duo-only “peek details, then slide to list” after a fold-close.
final class DuoClosedListRevealController {
    static let shared = DuoClosedListRevealController()

    private var keptDetailOnCollapse = false
    private var transitionFinished = false
    private var cancelledByUser = false
    private var workItem: DispatchWorkItem?

    private init() {}

    func noteKeptDetailOnCollapse() {
        keptDetailOnCollapse = true
        cancelledByUser = false
        transitionFinished = false
        cancelWorkItem()
    }

    func noteTransitionFinished() {
        transitionFinished = true
        trySchedule()
    }

    func hingeStateDidChange() {
        if !DeviceSizeManager.shared.hingeAvailable {
            cancelPending(clearCollapseFlag: true)
            return
        }
        if DeviceSizeManager.shared.isHingeClosed {
            trySchedule()
            return
        }
        // Fully reopened: drop the peek. Partial fold is still closing — wait for `.closed`.
        if DeviceSizeManager.shared.isHingeFullyOpen {
            cancelPending(clearCollapseFlag: true)
        }
    }

    /// Finger on details, Back, or a user swipe — stay on whatever they chose.
    func cancelBecauseUserInteracted() {
        guard keptDetailOnCollapse || workItem != nil else { return }
        cancelledByUser = true
        keptDetailOnCollapse = false
        cancelWorkItem()
    }

    func installCancelTracking(on view: UIView) {
        if view.gestureRecognizers?.contains(where: { $0 is PeekCancelTouchRecognizer }) == true {
            return
        }
        let recognizer = PeekCancelTouchRecognizer()
        recognizer.onTouch = { [weak self] in
            self?.cancelBecauseUserInteracted()
        }
        recognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(recognizer)
    }

    private func trySchedule() {
        let detailOnTop = Self.detailIsOnTop()
        guard DuoClosedListRevealPolicy.shouldScheduleSlideToList(
            hingeAvailable: DeviceSizeManager.shared.hingeAvailable,
            hingeClosed: DeviceSizeManager.shared.isHingeClosed,
            keptDetailOnCollapse: keptDetailOnCollapse,
            transitionFinished: transitionFinished,
            detailStillOnTop: detailOnTop,
            cancelledByUser: cancelledByUser
        ) else {
            return
        }
        guard workItem == nil else { return }

        let delay = DuoClosedListRevealPolicy.delayBeforeSlide(
            prefersReducedMotion: UIAccessibility.isReduceMotionEnabled
        )
        let item = DispatchWorkItem { [weak self] in
            self?.performSlideToList()
        }
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func performSlideToList() {
        defer { reset() }
        guard Self.detailIsOnTop(), let nav = Self.listNavigationController() else { return }
        let animated = !UIAccessibility.isReduceMotionEnabled
        nav.popViewController(animated: animated)
    }

    private func cancelPending(clearCollapseFlag: Bool) {
        cancelWorkItem()
        if clearCollapseFlag {
            keptDetailOnCollapse = false
        }
    }

    private func cancelWorkItem() {
        workItem?.cancel()
        workItem = nil
    }

    private func reset() {
        keptDetailOnCollapse = false
        transitionFinished = false
        cancelledByUser = false
        workItem = nil
    }

    private static func listNavigationController() -> UINavigationController? {
        if let nav = masterView?.navigationController {
            return nav
        }
        return nil
    }

    private static func detailIsOnTop() -> Bool {
        listNavigationController()?.topViewController is DetailHostingController
    }
}

/// Fires on contact then fails so SwiftUI / the nav bar still get the touch.
final class PeekCancelTouchRecognizer: UIGestureRecognizer {
    var onTouch: (() -> Void)?

    init() {
        super.init(target: nil, action: nil)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        onTouch?()
        state = .failed
    }
}

/// Centralized manager for determining if device has a large display (tablet) vs normal display (phone)
/// Recalculates on orientation changes and device folds to ensure accurate classification
class DeviceSizeManager: ObservableObject {
    static let shared = DeviceSizeManager()
    
    @Published private(set) var isLargeDisplay: Bool = false

    /// Horizontal insets that list content must avoid (Duo closed-display clock / side controls).
    private(set) var usableHorizontalInsets: UIEdgeInsets = .zero

    /// Secondary column parked while a large phone is in portrait (list-only).
    var parkedSecondaryViewController: UIViewController?

    /// Avoids re-applying split layout every `viewDidLayoutSubviews`.
    var lastAdaptiveLayoutSignature: String = ""

    /// True after a `UIHingeInteraction` reports a hinge. False on every non-Duo device.
    private(set) var hingeAvailable = false
    private(set) var isHingeClosed = false
    private(set) var isHingeFullyOpen = false
    private var hingeTrackingInstalled = false

    static let hingeDidChangeNotification = Notification.Name("DeviceSizeManager.hingeDidChange")
    
    private var orientationObserver: NSObjectProtocol?
    
    private init() {
        // Calculate initial value
        updateDeviceSize()
        
        // Listen for orientation changes
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateDeviceSize()
        }
        
        // Also listen for trait collection changes (handles foldable devices, window size changes)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(traitCollectionDidChange),
            name: UIApplication.didChangeStatusBarOrientationNotification,
            object: nil
        )
    }
    
    deinit {
        if let observer = orientationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func traitCollectionDidChange() {
        updateDeviceSize()
    }
    
    /// Recalculates device size classification
    /// This is called automatically on orientation changes, but can be called manually if needed
    func updateDeviceSize() {
        let newValue = calculateIsLargeDisplay()
        if newValue != isLargeDisplay {
            isLargeDisplay = newValue
            print("📱 [DEVICE_SIZE] Device size updated: \(isLargeDisplay ? "Large Display" : "Normal Display")")
        }
    }

    func updateUsableInsets(from view: UIView) {
        usableHorizontalInsets = UIEdgeInsets(
            top: 0,
            left: view.safeAreaInsets.left,
            bottom: 0,
            right: view.safeAreaInsets.right
        )
    }

    var trailingUsableInset: CGFloat {
        SplitViewLayoutPolicy.additionalRowTrailingInset(
            safeAreaTrailing: usableHorizontalInsets.right,
            contentAlreadyInSafeArea: true
        )
    }

    var separatorTrailingInsetForReservedChrome: CGFloat {
        SplitViewLayoutPolicy.separatorTrailingInset(safeAreaTrailing: usableHorizontalInsets.right)
    }

    /// Current window size; prefers the key window so Duo cover vs inner display is accurate.
    func currentWindowSize() -> CGSize {
        if let window = keyWindow() {
            return window.bounds.size
        }
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return windowScene.windows.first?.bounds.size ?? windowScene.screen.bounds.size
        }
        return UIScreen.main.bounds.size
    }

    func isCurrentlyLandscape() -> Bool {
        let size = currentWindowSize()
        return size.width > size.height
    }

    /// Landscape for the iPhone calendar overlay: window aspect, or compact-compact (Duo cover / classic iPhone).
    func isPhoneLandscapeLayout() -> Bool {
        let traits = keyWindow()?.traitCollection
        return PhoneLandscapeLayoutPolicy.isLandscape(
            windowSize: currentWindowSize(),
            horizontalSizeClass: traits?.horizontalSizeClass ?? .unspecified,
            verticalSizeClass: traits?.verticalSizeClass ?? .unspecified
        )
    }

    /// Auto landscape calendar overlay: compact phones and the closed Duo cover only.
    /// Open Duo and split layouts use the nav calendar toggle instead.
    func allowsIPhoneLandscapeCalendar() -> Bool {
        if isOpenDuoDisplay() { return false }
        return !shouldUseSplitView()
    }

    /// Inner display with the hinge open (not the closed cover).
    func isOpenDuoDisplay() -> Bool {
        hingeAvailable && !isHingeClosed
    }

    /// Calendar icon in the nav bar (manual list ↔ calendar), including open Duo portrait.
    func shouldOfferManualScheduleCalendarToggle() -> Bool {
        SplitViewLayoutPolicy.shouldOfferManualScheduleCalendarToggle(
            usesSplitLayout: shouldUseSplitView(),
            hingeAvailable: hingeAvailable,
            isHingeClosed: isHingeClosed
        )
    }

    /// Split view for iPad always; for large phones / open Duo in landscape only.
    func shouldUseSplitView() -> Bool {
        updateDeviceSize()
        if hingeAvailable && isHingeClosed {
            return false
        }
        return SplitViewLayoutPolicy.shouldUseSplitView(
            idiom: UIDevice.current.userInterfaceIdiom,
            isLargeDisplay: isLargeDisplay,
            isLandscape: isCurrentlyLandscape(),
            hasOpenDetail: false
        )
    }

    /// Band detail pushed on the list, or already showing in the secondary column.
    func hasOpenBandDetail() -> Bool {
        SplitViewLayoutPolicy.containsBandDetail(keyWindow()?.rootViewController)
    }
    
    /// Determines if the device has a large display (tablet) vs normal display (phone)
    /// Criteria can be changed here in one place
    private func calculateIsLargeDisplay() -> Bool {
        // Method 1: Check user interface idiom (iPad vs iPhone)
        // This is the primary indicator for iOS devices
        if UIDevice.current.userInterfaceIdiom == .pad {
            return true
        }

        // Method 2: Window size in points (the visible surface, not the hardware screen).
        // Using screen.bounds is wrong on foldables: the inner display can stay "large"
        // while the app is actually on the compact cover.
        if let window = keyWindow() {
            let minDimension = min(window.bounds.width, window.bounds.height)
            let largeDisplayThreshold: CGFloat = 768.0
            if minDimension >= largeDisplayThreshold {
                return true
            }
            if window.traitCollection.horizontalSizeClass == .regular {
                return true
            }
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            if let window = windowScene.windows.first {
                let minDimension = min(window.bounds.width, window.bounds.height)
                if minDimension >= 768.0 {
                    return true
                }
                if window.traitCollection.horizontalSizeClass == .regular {
                    return true
                }
            }
        }
        
        return false
    }

    private func keyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let key = scenes.flatMap({ $0.windows }).first(where: { $0.isKeyWindow }) {
            return key
        }
        return scenes.first?.windows.first
    }
    
    /// Convenience method for checking if device is large display
    /// Use this throughout the codebase instead of checking UIDevice.current.userInterfaceIdiom
    static func isLargeDisplay() -> Bool {
        return shared.isLargeDisplay
    }

    static func shouldUseSplitView() -> Bool {
        shared.shouldUseSplitView()
    }

    /// Starts hinge observation. No-op below iOS 27.1 and if already installed.
    func attachHingeTracking(to view: UIView) {
        guard #available(iOS 27.1, *) else { return }
        guard !hingeTrackingInstalled else { return }
        hingeTrackingInstalled = true
        let interaction = UIHingeInteraction { [weak self] _, update in
            self?.applyHingeUpdate(update)
        }
        view.addInteraction(interaction)
    }

    @available(iOS 27.1, *)
    private func applyHingeUpdate(_ update: UIHingeInteraction.Update) {
        if let hinge = update.hinge {
            hingeAvailable = true
            isHingeClosed = hinge.status == .closed
            isHingeFullyOpen = hinge.status == .fullyOpen
        } else {
            hingeAvailable = false
            isHingeClosed = false
            isHingeFullyOpen = false
        }
        DuoClosedListRevealController.shared.hingeStateDidChange()
        lastAdaptiveLayoutSignature = ""
        NotificationCenter.default.post(name: Self.hingeDidChangeNotification, object: self)
    }
}

/// Root split controller. iPhone’s default is `.allButUpsideDown`; `.all` is required for
/// portrait-upside-down on devices that support it (Touch ID phones, and possibly Duo’s cover).
final class AdaptiveSplitViewController: UISplitViewController {
    private var isTransitioningSize = false
    private var pushedDetailRehomeAttempts = 0

    var isSizeTransitionInProgress: Bool { isTransitioningSize }

    /// Fold transitions can ignore the first stack edit. Retry after layout settles.
    func schedulePushedDetailRehomeIfNeeded() {
        let detailOnList = (viewControllers.first as? UINavigationController)?.topViewController is DetailHostingController
        let canMove = SplitViewLayoutPolicy.canInstallPushedDetailOnExistingSecondary(
            columnCount: viewControllers.count
        )
        guard detailOnList, canMove else {
            if !detailOnList {
                pushedDetailRehomeAttempts = 0
            }
            return
        }
        guard pushedDetailRehomeAttempts < 2 else { return }
        pushedDetailRehomeAttempts += 1
        DispatchQueue.main.async { [weak self] in
            DeviceSizeManager.shared.lastAdaptiveLayoutSignature = ""
            self?.applyAdaptiveListDetailLayout()
        }
    }

    func resetPushedDetailRehomeAttempts() {
        pushedDetailRehomeAttempts = 0
    }

    override var shouldAutorotate: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        isTransitioningSize = true
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            guard let self = self else { return }
            self.isTransitioningSize = false
            DeviceSizeManager.shared.lastAdaptiveLayoutSignature = ""
            self.applyAdaptiveListDetailLayout()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !isTransitioningSize else { return }
        applyAdaptiveListDetailLayout()
    }
}

extension UISplitViewController {
    /// iOS 27’s Swift overlay traps on `preferredDisplayMode` / `preferredSplitBehavior`
    /// (every enum case, including via the ObjC IMP). Layout is therefore applied only by
    /// child membership, size class, and CGFloat column widths.
    func applyAdaptiveListDetailLayout() {
        if let adaptive = self as? AdaptiveSplitViewController, adaptive.isSizeTransitionInProgress {
            return
        }
        DeviceSizeManager.shared.updateDeviceSize()
        let useSplit = DeviceSizeManager.shared.shouldUseSplitView()
        let width = view.bounds.width
        guard width > 1 else { return }

        let detailOnPrimary = (viewControllers.first as? UINavigationController)?.topViewController is DetailHostingController
        let signature = "\(useSplit)|\(Int(width.rounded()))|\(isCollapsed)|\(viewControllers.count)|\(detailOnPrimary)"
        guard signature != DeviceSizeManager.shared.lastAdaptiveLayoutSignature else { return }
        DeviceSizeManager.shared.lastAdaptiveLayoutSignature = signature

        restoreParkedSecondaryIfNeeded()
        view.backgroundColor = .black
        applyHorizontalSizeClassOverride(useSplit: useSplit)
        applyPrimaryColumnWidths(useSplit: useSplit, availableWidth: width)

        if useSplit {
            ensureSecondaryColumnExistsForSplit()
            movePushedDetailOntoSecondaryIfNeeded()
            (self as? AdaptiveSplitViewController)?.schedulePushedDetailRehomeIfNeeded()
        } else {
            // Portrait / closed cover: never leave two columns. A squeezed secondary after
            // landscape→portrait was leaving an invisible pane that ate all taps.
            collapseSecondaryOntoPrimaryIfNeeded()
            (self as? AdaptiveSplitViewController)?.resetPushedDetailRehomeAttempts()
        }
    }

    /// Detail pushed while the cover was closed must move to the right column when the
    /// inner display opens. The list stays in the left column.
    func secondaryControllerForExpanding(from primaryViewController: UIViewController) -> UIViewController? {
        if let secondary = detachPushedDetailForSecondaryColumn(from: primaryViewController) {
            return secondary
        }
        if let parked = DeviceSizeManager.shared.parkedSecondaryViewController {
            DeviceSizeManager.shared.parkedSecondaryViewController = nil
            return parked
        }
        // Already moved into the right column. Returning nil here makes UIKit
        // substitute an empty detail and hide the band the user had open.
        if viewControllers.count > 1, SplitViewLayoutPolicy.containsBandDetail(viewControllers.last) {
            return viewControllers.last
        }
        return nil
    }

    private func detachPushedDetailForSecondaryColumn(from primaryViewController: UIViewController) -> UIViewController? {
        guard let primaryNav = primaryViewController as? UINavigationController,
              primaryNav.viewControllers.count > 1,
              let detail = primaryNav.viewControllers.last as? DetailHostingController else {
            return nil
        }
        detail.suppressesDismissNotification = true
        guard let popped = primaryNav.popViewController(animated: false) else {
            detail.suppressesDismissNotification = false
            return nil
        }
        return makeBandDetailNavigationController(rootViewController: popped)
    }

    private func makeBandDetailNavigationController(rootViewController: UIViewController) -> UINavigationController {
        let navigation = UINavigationController(rootViewController: rootViewController)
        navigation.applyBandDetailColumnChrome()
        return navigation
    }

    private func applyHorizontalSizeClassOverride(useSplit: Bool) {
        guard #available(iOS 17.0, *) else { return }
        if SplitViewLayoutPolicy.shouldForceCompactHorizontalSizeClass(useSplit: useSplit) {
            traitOverrides.horizontalSizeClass = .compact
        } else {
            traitOverrides.horizontalSizeClass = .unspecified
        }
    }

    private func applyPrimaryColumnWidths(useSplit: Bool, availableWidth: CGFloat) {
        let primary = SplitViewLayoutPolicy.primaryColumnWidth(
            useSplit: useSplit,
            availableWidth: availableWidth
        )
        preferredPrimaryColumnWidth = primary
        if useSplit {
            preferredPrimaryColumnWidthFraction = 0.42
            minimumPrimaryColumnWidth = min(SplitViewLayoutPolicy.splitPrimaryColumnMinWidth, primary)
            maximumPrimaryColumnWidth = max(primary, SplitViewLayoutPolicy.splitPrimaryColumnMaxWidth)
        } else {
            preferredPrimaryColumnWidthFraction = 1.0
            minimumPrimaryColumnWidth = primary
            maximumPrimaryColumnWidth = primary
        }
    }

    /// Shows a band in the right column when that column exists. Never replaces the list stack.
    func showBandDetailInSecondaryColumn(_ detail: UIViewController, animated: Bool) {
        guard let primaryNav = viewControllers.first as? UINavigationController else { return }
        if SplitViewLayoutPolicy.canInstallPushedDetailOnExistingSecondary(columnCount: viewControllers.count),
           let detailNav = viewControllers.last as? UINavigationController,
           detailNav !== primaryNav {
            detailNav.applyBandDetailColumnChrome()
            detailNav.setViewControllers([detail], animated: animated)
            return
        }
        primaryNav.pushViewController(detail, animated: animated)
    }

    func objcSecondaryViewController() -> UIViewController? {
        viewControllers.count > 1 ? viewControllers.last : nil
    }

    private func restoreParkedSecondaryIfNeeded() {
        guard let parked = DeviceSizeManager.shared.parkedSecondaryViewController else { return }
        DeviceSizeManager.shared.parkedSecondaryViewController = nil
        if viewControllers.count == 1 {
            viewControllers.append(parked)
        }
    }

    /// Landscape split needs two columns. After a portrait collapse we may only have the list.
    private func ensureSecondaryColumnExistsForSplit() {
        guard viewControllers.count == 1,
              let primary = viewControllers.first else { return }
        if let parked = DeviceSizeManager.shared.parkedSecondaryViewController {
            DeviceSizeManager.shared.parkedSecondaryViewController = nil
            viewControllers = [primary, parked]
            return
        }
        let placeholder = UIViewController()
        placeholder.view.backgroundColor = .black
        placeholder.title = "Band Details"
        let label = UILabel()
        label.text = NSLocalizedString(
            "SelectBandMessage",
            comment: "Message shown in detail view when no band is selected"
        )
        label.textAlignment = .center
        label.textColor = .white
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        placeholder.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: placeholder.view.safeAreaLayoutGuide.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: placeholder.view.safeAreaLayoutGuide.centerYAnchor),
            label.leadingAnchor.constraint(
                greaterThanOrEqualTo: placeholder.view.safeAreaLayoutGuide.leadingAnchor,
                constant: 40
            ),
            label.trailingAnchor.constraint(
                lessThanOrEqualTo: placeholder.view.safeAreaLayoutGuide.trailingAnchor,
                constant: -40
            )
        ])
        let detailNav = UINavigationController(rootViewController: placeholder)
        detailNav.applyBandDetailColumnChrome()
        viewControllers = [primary, detailNav]
    }

    /// Rotate landscape→portrait (or close the cover): push any open band onto the list
    /// stack and drop the secondary column so nothing overlays / steals touches.
    private func collapseSecondaryOntoPrimaryIfNeeded() {
        guard viewControllers.count > 1,
              let primaryNav = viewControllers.first as? UINavigationController else { return }
        let secondary = viewControllers[1]
        guard secondary !== primaryNav else { return }

        if SplitViewLayoutPolicy.containsBandDetail(secondary),
           !(primaryNav.topViewController is DetailHostingController) {
            let detail: DetailHostingController? = {
                if let nav = secondary as? UINavigationController {
                    return nav.viewControllers.compactMap { $0 as? DetailHostingController }.last
                }
                return secondary as? DetailHostingController
            }()
            if let detail {
                detail.suppressesDismissNotification = true
                if let nav = secondary as? UINavigationController {
                    let remaining = nav.viewControllers.filter { $0 !== detail }
                    nav.setViewControllers(remaining, animated: false)
                }
                primaryNav.pushViewController(detail, animated: false)
            }
        }

        // Park a non-detail secondary so landscape can restore a column quickly.
        if SplitViewLayoutPolicy.isPlaceholderDetail(secondary) {
            DeviceSizeManager.shared.parkedSecondaryViewController = secondary
        } else if !SplitViewLayoutPolicy.containsBandDetail(secondary) {
            DeviceSizeManager.shared.parkedSecondaryViewController = secondary
        } else {
            DeviceSizeManager.shared.parkedSecondaryViewController = nil
        }
        viewControllers = [primaryNav]
    }

    private func movePushedDetailOntoSecondaryIfNeeded() {
        // Column count is 1 while the cover is closed. `viewControllers.last` is the
        // list navigation controller then — replacing its stack with the detail removes
        // the band list and leaves an empty detail column after the screen opens.
        guard SplitViewLayoutPolicy.canInstallPushedDetailOnExistingSecondary(columnCount: viewControllers.count),
              let primaryNav = viewControllers.first as? UINavigationController,
              primaryNav.viewControllers.count > 1,
              let detail = primaryNav.viewControllers.last as? DetailHostingController else {
            return
        }
        if let coordinator = primaryNav.transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                DeviceSizeManager.shared.lastAdaptiveLayoutSignature = ""
                self?.movePushedDetailOntoSecondaryIfNeeded()
            }
            return
        }
        let secondary = viewControllers.last
        guard let secondary, secondary !== primaryNav else { return }
        let list = Array(primaryNav.viewControllers.dropLast())
        guard !list.isEmpty else { return }

        detail.suppressesDismissNotification = true
        UIView.performWithoutAnimation {
            primaryNav.setViewControllers(list, animated: false)
            if let detailNav = secondary as? UINavigationController {
                detailNav.applyBandDetailColumnChrome()
                detailNav.setViewControllers([detail], animated: false)
            } else if let index = self.viewControllers.firstIndex(where: { $0 === secondary }) {
                var columns = self.viewControllers
                columns[index] = self.makeBandDetailNavigationController(rootViewController: detail)
                self.viewControllers = columns
            }
            if primaryNav.viewControllers.contains(where: { $0 === detail }) {
                detail.suppressesDismissNotification = false
            }
        }
    }
}

extension UINavigationController {
    func applyBandDetailColumnChrome() {
        overrideUserInterfaceStyle = .dark
        navigationBar.isTranslucent = true
        navigationBar.backgroundColor = .clear
        navigationBar.barTintColor = .clear
        navigationBar.tintColor = .white
        navigationBar.shadowImage = UIImage()
        navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationBar.barStyle = .black
    }
}

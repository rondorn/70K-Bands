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
/// Split view is for iPad in any orientation, and for large iPhones only when landscape.
enum SplitViewLayoutPolicy {
    /// Whether master/detail should sit side by side.
    /// iPad: always. Phone (including Duo inner display): only when the window is landscape.
    static func shouldUseSplitView(
        idiom: UIUserInterfaceIdiom,
        isLargeDisplay: Bool,
        isLandscape: Bool
    ) -> Bool {
        guard isLargeDisplay else { return false }
        if idiom == .pad {
            return true
        }
        return isLandscape
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
    /// iPad's split primary column is also `.compact`, but it has no cover chrome —
    /// putting those items in the nav bar crushes the title and stats control.
    static func usesCompactListChrome(
        idiom: UIUserInterfaceIdiom,
        horizontalSizeClass: UIUserInterfaceSizeClass,
        hingeAvailable: Bool,
        isHingeClosed: Bool
    ) -> Bool {
        guard idiom != .pad else { return false }
        return horizontalSizeClass == .compact || (hingeAvailable && isHingeClosed)
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

    /// Discard the secondary column when collapsing if it is only the empty placeholder.
    static func shouldDiscardSecondaryOnCollapse(isPlaceholderDetail: Bool) -> Bool {
        isPlaceholderDetail
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

    /// Calendar overlay is for compact phones (including the closed Duo cover), not split layouts.
    func allowsIPhoneLandscapeCalendar() -> Bool {
        !shouldUseSplitView()
    }

    /// Split view for iPad always; for large phones (Duo inner / Pro Max) only in landscape.
    func shouldUseSplitView() -> Bool {
        updateDeviceSize()
        if hingeAvailable && isHingeClosed {
            return false
        }
        return SplitViewLayoutPolicy.shouldUseSplitView(
            idiom: UIDevice.current.userInterfaceIdiom,
            isLargeDisplay: isLargeDisplay,
            isLandscape: isCurrentlyLandscape()
        )
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

    var isSizeTransitionInProgress: Bool { isTransitioningSize }

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

        let signature = "\(useSplit)|\(Int(width.rounded()))"
        guard signature != DeviceSizeManager.shared.lastAdaptiveLayoutSignature else { return }
        DeviceSizeManager.shared.lastAdaptiveLayoutSignature = signature

        restoreParkedSecondaryIfNeeded()
        view.backgroundColor = .black
        applyHorizontalSizeClassOverride(useSplit: useSplit)
        applyPrimaryColumnWidths(useSplit: useSplit, availableWidth: width)

        if useSplit {
            movePushedDetailOntoSecondaryIfNeeded()
        }
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

    private func movePushedDetailOntoSecondaryIfNeeded() {
        guard let primaryNav = viewControllers.first as? UINavigationController,
              primaryNav.viewControllers.count > 1,
              let detail = primaryNav.viewControllers.last as? DetailHostingController else {
            return
        }
        primaryNav.popViewController(animated: false)
        if let detailNav = viewControllers.last as? UINavigationController {
            detailNav.setViewControllers([detail], animated: false)
        } else if viewControllers.count == 1 {
            viewControllers.append(UINavigationController(rootViewController: detail))
        }
    }
}

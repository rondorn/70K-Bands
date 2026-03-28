//
//  MasterViewLandscapeScheduleCoordinator.swift
//  70000TonsBands
//
//  Extracted from MasterViewController: landscape calendar presentation, orientation checks,
//  and dismiss/refresh behavior. Host retains list state (currentViewingDay, scroll position).
//

import SwiftUI
import UIKit

/// Owns landscape schedule modal state and presentation; `MasterViewController` remains the UIKit presenter and list owner.
final class MasterViewLandscapeScheduleCoordinator {

    weak var host: MasterViewController?

    var landscapeScheduleViewController: UIViewController?
    var isShowingLandscapeSchedule: Bool = false
    var isDismissingLandscapeSchedule: Bool = false
    var lastPortraitDismissCheckTime: CFTimeInterval = 0

    init(host: MasterViewController) {
        self.host = host
    }

    // MARK: - Orientation & visibility

    /// Call after a filter change (e.g. Hide Expired Events) so list vs calendar is re-evaluated in landscape.
    func recheckLandscapeScheduleAfterFilterChange() {
        checkOrientationAndShowLandscapeIfNeeded()
    }

    func checkOrientationAndShowLandscapeIfNeeded() {
        guard let host = host else { return }
        print("🔄 [ORIENTATION_CHECK] checkOrientationAndShowLandscapeIfNeeded called")
        print("🔄 [ORIENTATION_CHECK] filterMenuButton.isHidden: \(host.filterMenuButton?.isHidden ?? true)")
        print("🔄 [ORIENTATION_CHECK] bandSearch.isHidden: \(host.bandSearch?.isHidden ?? true)")
        print("🔄 [ORIENTATION_CHECK] view.window: \(host.view.window != nil ? "exists" : "nil")")
        print("🔄 [ORIENTATION_CHECK] isShowingLandscapeSchedule: \(isShowingLandscapeSchedule)")

        let mainWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? host.view.window

        let windowBounds = mainWindow?.bounds ?? host.view.bounds
        let windowBoundsLandscape = windowBounds.width > windowBounds.height
        let viewBoundsLandscape = host.view.bounds.width > host.view.bounds.height
        let statusBarLandscape = UIApplication.shared.statusBarOrientation.isLandscape
        let deviceOrientationLandscape = UIDevice.current.orientation.isLandscape

        let isLandscape: Bool
        if !statusBarLandscape && !deviceOrientationLandscape {
            isLandscape = false
        } else if statusBarLandscape || deviceOrientationLandscape {
            isLandscape = true
        } else {
            isLandscape = windowBoundsLandscape || viewBoundsLandscape
        }

        if let landscapeVC = landscapeScheduleViewController,
           landscapeVC.presentedViewController != nil {
            print("🔄 [LANDSCAPE_SCHEDULE] Detail screen is presented - skipping orientation change handling")
            print("🔄 [LANDSCAPE_SCHEDULE] Detail screen will handle its own orientation, landscape view stays")
            return
        }

        if !host.isSplitViewCapable() {
            print("🚫 [LANDSCAPE_SCHEDULE] Orientation check - windowBounds: \(windowBoundsLandscape) (w:\(windowBounds.width) h:\(windowBounds.height)), viewBounds: \(viewBoundsLandscape) (w:\(host.view.bounds.width) h:\(host.view.bounds.height)), statusBar: \(statusBarLandscape), device: \(deviceOrientationLandscape), isLandscape: \(isLandscape), isShowingCalendar: \(isShowingLandscapeSchedule)")

            if !isLandscape {
                if isShowingLandscapeSchedule {
                    print("🚫 [LANDSCAPE_SCHEDULE] iPhone rotated to portrait - immediately dismissing calendar view (portrait never shows calendar)")
                    print("🚫 [ORIENTATION_CHECK] Before dismissLandscapeScheduleView - filterMenuButton.isHidden: \(host.filterMenuButton?.isHidden ?? true)")
                    print("🚫 [ORIENTATION_CHECK] Before dismissLandscapeScheduleView - bandSearch.isHidden: \(host.bandSearch?.isHidden ?? true)")
                    dismissLandscapeScheduleView()
                    print("🚫 [ORIENTATION_CHECK] After dismissLandscapeScheduleView - filterMenuButton.isHidden: \(host.filterMenuButton?.isHidden ?? true)")
                    print("🚫 [ORIENTATION_CHECK] After dismissLandscapeScheduleView - bandSearch.isHidden: \(host.bandSearch?.isHidden ?? true)")
                }
                return
            }
        }

        let isScheduleView = getShowScheduleView()

        if host.isSplitViewCapable() {
            print("📱 [IPAD_TOGGLE] Schedule View: \(isScheduleView), Manual Calendar View: \(host.isManualCalendarView)")
            return
        }

        if let topVC = host.navigationController?.topViewController, topVC is DetailHostingController {
            print("🔄 [ORIENTATION] Detail view is showing in navigation stack - skipping orientation handling")
            return
        }

        let hasEventEntries = host.bands.contains { item in
            item.contains(":") && item.components(separatedBy: ":").first?.doubleValue != nil
        }

        print("🔄 [LANDSCAPE_SCHEDULE] Check orientation - Landscape: \(isLandscape), Schedule View: \(isScheduleView), Has Event Entries: \(hasEventEntries), Bands Count: \(host.bands.count)")

        if isLandscape && isScheduleView && hasEventEntries {
            host.updateCurrentViewingDayFromVisibleCells()
            presentLandscapeScheduleView()
        } else {
            dismissLandscapeScheduleView()
        }
    }

    /// Helper method to check if iPhone is in portrait and dismiss calendar view (multiple attempts).
    func checkAndDismissIfPortrait(attempt: Int, maxAttempts: Int) {
        guard let host = host else { return }
        guard !host.isSplitViewCapable() && isShowingLandscapeSchedule else {
            return
        }

        if let landscapeVC = landscapeScheduleViewController,
           landscapeVC.presentedViewController != nil {
            print("🔄 [ORIENTATION] Detail screen is presented - skipping portrait dismissal check")
            return
        }

        let mainWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? host.view.window

        let windowBounds = mainWindow?.bounds ?? host.view.bounds
        let windowBoundsLandscape = windowBounds.width > windowBounds.height
        let viewBoundsLandscape = host.view.bounds.width > host.view.bounds.height
        let statusBarLandscape = UIApplication.shared.statusBarOrientation.isLandscape
        let deviceOrientationLandscape = UIDevice.current.orientation.isLandscape

        let isLandscape: Bool
        if !statusBarLandscape && !deviceOrientationLandscape {
            isLandscape = false
        } else if statusBarLandscape || deviceOrientationLandscape {
            isLandscape = true
        } else {
            isLandscape = windowBoundsLandscape || viewBoundsLandscape
        }

        print("🚫 [ORIENTATION] Portrait check attempt \(attempt)/\(maxAttempts) - windowBounds: \(windowBoundsLandscape) (w:\(windowBounds.width) h:\(windowBounds.height)), viewBounds: \(viewBoundsLandscape), statusBar: \(statusBarLandscape), device: \(deviceOrientationLandscape), isLandscape: \(isLandscape)")

        if !isLandscape {
            print("🚫 [ORIENTATION] iPhone detected in portrait - dismissing calendar view immediately")
            dismissLandscapeScheduleView()
            return
        }

        if attempt < maxAttempts {
            let delay = Double(attempt) * 0.2
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.checkAndDismissIfPortrait(attempt: attempt + 1, maxAttempts: maxAttempts)
            }
        }
    }

    // MARK: - Present / refresh / dismiss

    func presentLandscapeScheduleView() {
        guard let host = host else { return }
        guard !isShowingLandscapeSchedule else {
            print("🔄 [LANDSCAPE_SCHEDULE] Already showing landscape schedule view")
            return
        }

        if !host.isSplitViewCapable() {
            let mainWindow = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? host.view.window

            let windowBounds = mainWindow?.bounds ?? host.view.bounds
            let windowBoundsLandscape = windowBounds.width > windowBounds.height
            let viewBoundsLandscape = host.view.bounds.width > host.view.bounds.height
            let statusBarLandscape = UIApplication.shared.statusBarOrientation.isLandscape
            let deviceOrientationLandscape = UIDevice.current.orientation.isLandscape

            let isLandscape: Bool
            if !statusBarLandscape && !deviceOrientationLandscape {
                isLandscape = false
            } else if statusBarLandscape || deviceOrientationLandscape {
                isLandscape = true
            } else {
                isLandscape = windowBoundsLandscape || viewBoundsLandscape
            }

            if !isLandscape {
                print("🚫 [LANDSCAPE_SCHEDULE] iPhone in portrait mode - calendar mode is not allowed")
                return
            }
        }

        print("🔄 [LANDSCAPE_SCHEDULE] Presenting landscape schedule view")

        let hideExpiredEvents = getHideExpireScheduleData()
        print("🔄 [LANDSCAPE_SCHEDULE] hideExpiredEvents: \(hideExpiredEvents)")

        if hideExpiredEvents && host.bands.isEmpty {
            print("⚠️ [LANDSCAPE_SCHEDULE] No bands in portrait view - staying in portrait view")
            return
        }

        let timeSinceScroll = host.lastProgrammaticScrollTime.map { Date().timeIntervalSince($0) } ?? 1.0

        if timeSinceScroll < 0.5, let scrolledDay = host.currentViewingDay {
            print("🔄 [LANDSCAPE_SCHEDULE] Recent programmatic scroll detected (\(String(format: "%.2f", timeSinceScroll))s ago), using scrolled day: '\(scrolledDay)'")
        } else {
            if host.currentViewingDay == nil {
                print("🔄 [LANDSCAPE_SCHEDULE] currentViewingDay is nil, updating from visible cells")
            } else {
                print("🔄 [LANDSCAPE_SCHEDULE] No recent scroll, updating from visible cells (current: '\(host.currentViewingDay!)')")
            }
            host.updateCurrentViewingDayFromVisibleCells()
        }

        let initialDay = host.currentViewingDay
        if let day = initialDay {
            print("🔄 [LANDSCAPE_SCHEDULE] Starting on tracked day: '\(day)'")
        } else {
            print("🔄 [LANDSCAPE_SCHEDULE] No tracked day found, will start on first day")
        }

        let landscapeView = LandscapeScheduleView(
            priorityManager: host.priorityManager,
            attendedHandle: host.attendedHandle,
            initialDay: initialDay,
            hideExpiredEvents: hideExpiredEvents,
            isSplitViewCapable: host.isSplitViewCapable(),
            onDismissRequested: { [weak self, weak host] currentDay in
                if let day = currentDay {
                    host?.currentViewingDay = day
                    print("🔄 [LANDSCAPE_SCHEDULE] Calendar → list: will show day \(day)")
                }
                host?.isManualCalendarView = false
                self?.dismissLandscapeScheduleView()
            },
            onCurrentDayChanged: { [weak host] day in
                host?.currentViewingDay = day
            },
            onShowMessage: { [weak host] message in
                host?.showToastOnTopmostVC(message: message)
            },
            onBandTapped: { [weak self, weak host] bandName, currentDay in
                guard let host = host else { return }

                print("🔄 [LANDSCAPE_SCHEDULE] Band tapped: \(bandName) on day: \(currentDay ?? "unknown")")

                if isCombinedEventBandName(bandName) {
                    if let individualBands = combinedEventsMap[bandName], individualBands.count == 2 {
                        host.promptForBandSelectionLandscape(combinedBandName: bandName, bands: individualBands, currentDay: currentDay)
                        return
                    }
                }

                if let day = currentDay {
                    host.currentViewingDay = day
                    print("🔄 [LANDSCAPE_SCHEDULE] Saved current viewing day: \(day)")
                }

                host.savedScrollPosition = host.tableView.contentOffset
                print("🔄 [LANDSCAPE_SCHEDULE] Saved scroll position: \(host.savedScrollPosition!)")

                let bandIndex: Int
                if let index = host.bands.firstIndex(where: { band in
                    getNameFromSortable(band, sortedBy: getSortedBy()) == bandName
                }) {
                    bandIndex = index
                } else {
                    print("⚠️ [LANDSCAPE_SCHEDULE] Band not in filtered list, using index 0")
                    bandIndex = 0
                }

                bandSelected = bandName
                bandListIndexCache = bandIndex
                currentBandList = host.bands

                let detailController = DetailHostingController(bandName: bandName, showCustomBackButton: true)

                if host.isSplitViewCapable() {
                    detailController.modalPresentationStyle = .formSheet
                    detailController.preferredContentSize = CGSize(width: 800, height: 900)
                }

                self?.landscapeScheduleViewController?.present(detailController, animated: true) {
                    print("✅ [LANDSCAPE_SCHEDULE] Detail view presented")
                }
            },
            onLongPress: { [weak self, weak host] bandName, location, startTime, eventType, day in
                guard let host = host else { return }

                if isCombinedEventBandName(bandName) {
                    let individualBands = combinedEventsMap[bandName] ?? combinedEventBandParts(bandName)
                    if let bands = individualBands, bands.count == 2 {
                        host.promptForBandSelectionLandscapeForLongPress(
                            combinedBandName: bandName,
                            bands: bands,
                            location: location,
                            startTime: startTime,
                            eventType: eventType,
                            day: day
                        )
                        return
                    }
                }

                var cellDataText = "\(bandName);\(location);\(eventType);\(startTime)"
                if !day.isEmpty {
                    cellDataText += ";\(day)"
                }
                let presentingViewController = self?.landscapeScheduleViewController ?? host
                host.showLongPressMenu(bandName: bandName, cellDataText: cellDataText, indexPath: IndexPath(row: 0, section: 0), presentingFrom: presentingViewController)
            }
        )

        let hostingController = UIHostingController(rootView: landscapeView)
        hostingController.modalPresentationStyle = UIModalPresentationStyle.fullScreen

        landscapeScheduleViewController = hostingController
        isShowingLandscapeSchedule = true

        host.present(hostingController, animated: true) {
            print("✅ [LANDSCAPE_SCHEDULE] Landscape schedule view presented")
        }
    }

    func refreshLandscapeScheduleViewIfNeeded(for bandName: String? = nil) {
        guard isShowingLandscapeSchedule else {
            return
        }

        print("🔄 [LANDSCAPE_SCHEDULE] Posting refresh notification for band: \(bandName ?? "all")")

        var userInfo: [String: Any] = [:]
        if let bandName = bandName {
            userInfo["bandName"] = bandName
        }
        NotificationCenter.default.post(
            name: Notification.Name("RefreshLandscapeSchedule"),
            object: nil,
            userInfo: userInfo.isEmpty ? nil : userInfo
        )
    }

    func dismissLandscapeScheduleView(completion: (() -> Void)? = nil) {
        guard isShowingLandscapeSchedule, let viewController = landscapeScheduleViewController else {
            completion?()
            return
        }
        guard !isDismissingLandscapeSchedule else { return }
        isDismissingLandscapeSchedule = true
        let wrappedCompletion: () -> Void = { [weak self] in
            self?.isDismissingLandscapeSchedule = false
            completion?()
        }

        if let presentedVC = viewController.presentedViewController {
            presentedVC.dismiss(animated: false) { [weak self] in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.dismissLandscapeViewControllerWithUIRestore(viewController: viewController, completion: wrappedCompletion)
                }
            }
        } else {
            dismissLandscapeViewControllerWithUIRestore(viewController: viewController, completion: wrappedCompletion)
        }
    }

    private func dismissLandscapeViewControllerWithUIRestore(viewController: UIViewController, completion: (() -> Void)?) {
        dismissLandscapeViewController(viewController: viewController) { [weak self] in
            guard let self = self, let host = self.host else { return }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self, let host = self.host else { return }

                host.filterMenuButton?.isHidden = false
                host.bandSearch?.isHidden = false
                host.filterMenuButton?.alpha = 1.0
                host.bandSearch?.alpha = 1.0
                host.mainToolBar?.isHidden = false
                host.mainToolBar?.alpha = 1.0
                host.view.isHidden = false
                host.view.alpha = 1.0

                if let filterSuperview = host.filterMenuButton?.superview {
                    filterSuperview.isHidden = false
                    filterSuperview.alpha = 1.0
                }
                if let searchSuperview = host.bandSearch?.superview {
                    searchSuperview.isHidden = false
                    searchSuperview.alpha = 1.0
                }

                host.view.setNeedsLayout()
                host.view.layoutIfNeeded()

                DispatchQueue.main.async {
                    host.tableView.reloadSections(IndexSet(integer: 0), with: .none)
                    host.navigationItem.title = nil
                    host.updateCountLable()
                }

                self.checkOrientationAndShowLandscapeIfNeeded()
                completion?()
            }
        }
    }

    private func dismissLandscapeViewController(viewController: UIViewController, completion: (() -> Void)?) {
        guard let host = host else { return }
        let dayToShow = host.currentViewingDay
        viewController.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.landscapeScheduleViewController = nil
            self.isShowingLandscapeSchedule = false

            if host.isSplitViewCapable() {
                host.isManualCalendarView = false
                host.viewToggleButton?.image = UIImage(systemName: "calendar")
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak host] in
                guard let host = host else { return }
                host.scrollListToDayIfNeeded(day: dayToShow)

                host.filterMenuButton?.isHidden = false
                host.bandSearch?.isHidden = false
                host.filterMenuButton?.alpha = 1.0
                host.bandSearch?.alpha = 1.0
                host.mainToolBar?.isHidden = false
                host.mainToolBar?.alpha = 1.0

                if let filterBar = host.filterMenuButton?.superview {
                    filterBar.isHidden = false
                    filterBar.alpha = 1.0
                }
                if let searchBar = host.bandSearch?.superview {
                    searchBar.isHidden = false
                    searchBar.alpha = 1.0
                }

                host.view.isHidden = false
                host.view.alpha = 1.0

                host.view.setNeedsLayout()
                host.view.layoutIfNeeded()
            }
            completion?()
        }
    }
}

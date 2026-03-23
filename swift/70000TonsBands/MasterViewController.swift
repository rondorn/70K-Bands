//
//  MasterViewController.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/2/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import UIKit
import Firebase
import AVKit
import SwiftUI

class MasterViewController: UITableViewController, UISplitViewControllerDelegate, UISearchBarDelegate, UIGestureRecognizerDelegate {
    
    // MARK: - Year Change Thread Management
    private static var currentDataRefreshOperationId: UUID = UUID()
    static var isYearChangeInProgress: Bool = false
    static var isCsvDownloadInProgress: Bool = false
    static var isRefreshingAlerts: Bool = false
    static let backgroundRefreshLock = NSLock()
    
    // MARK: - Year Change Data Readiness (Race Condition Fix)
    private static var yearChangeDataReady: Bool = false
    private static var yearChangeDataReadyLock = NSLock()
    private static var pendingYearChangeCompletion: Bool = false
    
    // MARK: - Deadlock Prevention
    private static var yearChangeStartTime: Date?
    private static var deadlockDetectionTimer: Timer?
    private var backgroundOperationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        queue.qualityOfService = .utility
        queue.name = "MasterViewController.backgroundOperations"
        return queue
    }()
    
    // MARK: - Year Change Coordination Methods
    static func notifyYearChangeStarting() {
        print("🚨 [YEAR_CHANGE_DEADLOCK_FIX] Year change starting - cancelling ALL background operations")
        isYearChangeInProgress = true
        currentDataRefreshOperationId = UUID()
        yearChangeStartTime = Date()
        
        // Reset data readiness flag
        yearChangeDataReadyLock.lock()
        yearChangeDataReady = false
        pendingYearChangeCompletion = false
        yearChangeDataReadyLock.unlock()
        
        // ADD DEADLOCK DETECTION TIMER
        deadlockDetectionTimer?.invalidate()
        deadlockDetectionTimer = Timer.scheduledTimer(withTimeInterval: 45.0, repeats: false) { _ in
            print("🚨 DEADLOCK DETECTED: Year change has been running for 45+ seconds")
            print("🚨 EMERGENCY RECOVERY: Forcing year change completion")
            
            notifyYearChangeCompleted()
            
            // Post emergency notification
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("EmergencyYearChangeRecovery"), 
                    object: nil
                )
            }
        }
    }
    
    /// Marks year change data as ready - called after initial data load completes
    static func markYearChangeDataReady() {
        yearChangeDataReadyLock.lock()
        yearChangeDataReady = true
        let shouldComplete = pendingYearChangeCompletion
        yearChangeDataReadyLock.unlock()
        
        // If completion was pending, do it now
        if shouldComplete {
            notifyYearChangeCompleted()
        }
    }
    
    static func notifyYearChangeCompleted() {
        yearChangeDataReadyLock.lock()
        let dataReady = yearChangeDataReady
        if !dataReady {
            // Data not ready yet - defer completion
            pendingYearChangeCompletion = true
            yearChangeDataReadyLock.unlock()
            return
        }
        pendingYearChangeCompletion = false
        yearChangeDataReadyLock.unlock()
        
        print("✅ [YEAR_CHANGE_DEADLOCK_FIX] Year change completed - background operations can resume")
        isYearChangeInProgress = false
        
        // Cancel deadlock detection
        deadlockDetectionTimer?.invalidate()
        deadlockDetectionTimer = nil
        
        if let startTime = yearChangeStartTime {
            let duration = Date().timeIntervalSince(startTime)
            print("📊 Year change took \(String(format: "%.2f", duration)) seconds")
            yearChangeStartTime = nil
        }
        
        // Post notification to trigger deferred operations
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("YearChangeCompleted"),
                object: nil
            )
        }
    }
    
    /// Checks if year change data is ready (for race condition prevention)
    static func isYearChangeDataReady() -> Bool {
        yearChangeDataReadyLock.lock()
        defer { yearChangeDataReadyLock.unlock() }
        return yearChangeDataReady
    }
    
    private func cancelAllBackgroundOperations() {
        print("🚨 [YEAR_CHANGE_DEADLOCK_FIX] Cancelling \(backgroundOperationQueue.operationCount) operations")
        backgroundOperationQueue.cancelAllOperations()
        // Also cancel any existing dispatch group operations by incrementing operation ID
        MasterViewController.currentDataRefreshOperationId = UUID()
    }
    
    @IBOutlet var mainTableView: UITableView!
    
    // MARK: - Preference Synchronization
    private var lastPreferenceReturnTime: TimeInterval?
    private var justReturnedFromPreferences = false
    @IBOutlet weak var mainToolBar: UIToolbar!
    
    @IBOutlet weak var titleButton: UINavigationItem!

    @IBOutlet weak var preferenceButton: UIBarButtonItem!
    @IBOutlet weak var filterMenuButton: UIButton!

    @IBOutlet weak var Undefined: UIButton!

    @IBOutlet weak var shareButton: UIBarButtonItem!
    
    @IBOutlet weak var contentController: UIView!
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var blankScreenActivityIndicator: UIActivityIndicatorView!
    
    // MARK: - Landscape Schedule View
    private var landscapeScheduleViewController: UIViewController?
    private var isShowingLandscapeSchedule: Bool = false
    private var isDismissingLandscapeSchedule: Bool = false
    private var lastPortraitDismissCheckTime: CFTimeInterval = 0
    private var currentViewingDay: String? = nil  // Track which day user is viewing
    private var savedScrollPosition: CGPoint? = nil  // Save scroll position when navigating away
    private var lastProgrammaticScrollTime: Date? = nil  // Track when we last scrolled programmatically
    
    // iPad-specific calendar toggle
    private var viewToggleButton: UIBarButtonItem?
    private var isManualCalendarView: Bool = false  // For iPad: true = calendar view, false = list view
    
    /// When non-nil, user opened band list from Auto Choose Attendance wizard; show "Back to wizard" and re-present wizard when tapped.
    private var autoChooseWizardResumeYear: Int?
    
    @IBOutlet weak var statsButton: UIBarButtonItem!
    @IBOutlet weak var filterButtonBar: UIBarButtonItem!
    @IBOutlet weak var searchButtonBar: UIBarButtonItem!
    @IBOutlet weak var menuButton: UIBarButtonItem!
    
    @IBOutlet weak var bandSearch: UISearchBar!
        
    let schedule = scheduleHandler.shared
    let bandNameHandle = bandNamesHandler.shared
    let attendedHandle = ShowsAttended()
    let iCloudDataHandle = iCloudDataHandler();
    
    // MARK: - Service Classes
    private lazy var viewModel: MasterViewModel = {
        MasterViewModel(
            schedule: schedule,
            bandNameHandle: bandNameHandle,
            dataHandle: dataHandle,
            priorityManager: priorityManager,
            attendedHandle: attendedHandle,
            iCloudDataHandle: iCloudDataHandle
        )
    }()
    
    private lazy var cacheManager: MasterViewCacheManager = {
        MasterViewCacheManager(
            schedule: schedule,
            bandNameHandle: bandNameHandle,
            dataHandle: dataHandle,
            attendedHandle: attendedHandle,
            bandDescriptions: bandDescriptions
        )
    }()
    
    private lazy var uiManager: MasterViewUIManager = {
        MasterViewUIManager(
            schedule: schedule,
            dataHandle: dataHandle,
            priorityManager: priorityManager,
            attendedHandle: attendedHandle
        )
    }()
    
    var filterTextNeeded = true;
    var viewableCell = UITableViewCell()
    
    
    @IBOutlet weak var titleButtonArea: UINavigationItem!
    var backgroundColor = UIColor.white;
    var textColor = UIColor.black;
    
    var sharedMessage = ""
    var objects = NSMutableArray()
    var bands =  [String]()
    var bandsByTime = [String]()
    var bandsByName = [String]()
    var reloadTableBool = true
    
    var filtersOnText = ""
    
    var bandDescriptions = CustomBandDescription()
    
    @IBOutlet weak var titleLabel: UINavigationItem!
    
    /// Reusable titleView count label
    private var titleCountLabel: UILabel?
    
    var dataHandle = dataHandler()
    private let priorityManager = SQLitePriorityManager.shared
    
    var videoURL = URL("")
    var player = AVPlayer()
    var playerLayer = AVPlayerLayer()
    
    // --- ADDED: Timer and download state ---
    // NOTE: Schedule download state is now managed by ViewModel internally
    // This property is kept for backward compatibility but shouldDownloadSchedule() uses ViewModel
    var lastScheduleDownload: Date? = nil {
        didSet {
            // Sync with ViewModel when updated
            if lastScheduleDownload != nil {
                viewModel.updateLastScheduleDownload()
            }
        }
    }
    var scheduleRefreshTimer: Timer? = nil
    let scheduleDownloadInterval: TimeInterval = 5 * 60 // 5 minutes
    let minDownloadInterval: TimeInterval = 60 // 1 minute
    // --- END ADDED ---
    
    // MARK: - Legacy State (managed by service classes)
    // These are kept for backward compatibility but should use service classes
    var lastRefreshDataRun: Date? = nil
    var lastBandNamesCacheRefresh: Date? = nil {
        didSet {
            // Sync with CacheManager if needed
            if let date = lastBandNamesCacheRefresh {
                cacheManager.resetCacheRefreshThrottle()
            }
        }
    }
    
    // Add the missing property
    var isPerformingQuickLoad = false
    
    var easterEggTriggeredForSearch = false
    private var pupaPartyOverlay: PupaPartyOverlayView?
    
    /// Last search text used for refresh - prevents spurious refresh when text hasn't changed
    private var lastSearchTextForRefresh: String = ""
    
    // Flag to track if country dialog should be shown after data loads on first install
    private var shouldShowCountryDialogAfterDataLoad = false

    // MARK: - Image pipeline diagnostics
    private func logImagePipelineState(_ context: String) {
        // Keep this lightweight and safe to call from any thread.
        let year = eventYear
        let bandCount = bandNameHandle.getBandNames().count

        // Schedule cache: count bands + approximate total events from cached dictionary.
        let scheduleBands = schedule.schedulingData.count
        let scheduleEventsApprox = schedule.schedulingData.values.reduce(0) { $0 + $1.count }

        let combinedCount = CombinedImageListHandler.shared.combinedImageList.count

        print("🧩 [IMAGE_PIPELINE] \(context) | year=\(year) bands=\(bandCount) scheduleBands=\(scheduleBands) scheduleEvents≈\(scheduleEventsApprox) combinedImageList=\(combinedCount)")
    }
    
    var filterRequestID = 0
    
    static var isRefreshingBandList = false
    private static var refreshBandListSafetyTimer: Timer?
    
    // Flag to ensure snap-to-top after pull-to-refresh is not overridden
    var shouldSnapToTopAfterRefresh = false
    
    // Flag to prevent endless auto-selection loops on iPad
    var hasAutoSelectedForIPad = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let viewDidLoadStart = Date()
        LaunchTiming.logStart("MasterViewController.viewDidLoad", thread: "MAIN")
        defer { LaunchTiming.logEnd("MasterViewController.viewDidLoad", startTime: viewDidLoadStart, thread: "MAIN") }

        print("🎮 [MDF_DEBUG] MasterViewController.viewDidLoad() called")
        print("🎮 [MDF_DEBUG] Festival: \(FestivalConfig.current.festivalShortName)")
        print("🎮 [MDF_DEBUG] App Name: \(FestivalConfig.current.appName)")
        
        // Configure CellDataCache dependencies for performance using CacheManager
        cacheManager.configureCellDataCache(priorityManager: priorityManager)
        
        // Set initial title to app name before data loads
        print("🔧 [INIT_DEBUG] About to call updateTitleForActivePreferenceSource()")
        updateTitleForActivePreferenceSource()
        print("🔧 [INIT_DEBUG] updateTitleForActivePreferenceSource() completed")
        
        bandSearch?.placeholder = NSLocalizedString("SearchCriteria", comment: "")
        bandSearch?.searchTextField.returnKeyType = .done
        if let sb = bandSearch { installSearchKeyboardDoneToolbar(sb) }
        if let searchImg = UIImage(named: "70KSearch") {
            bandSearch?.setImage(searchImg, for: .init(rawValue: 0)!, state: .normal)
        }
        // Apply festival-configurable toolbar icons (Preferences, Share)
        if let prefImg = UIImage(named: FestivalConfig.current.preferencesIcon) {
            preferenceButton?.image = prefImg
        }
        if let shareImg = UIImage(named: FestivalConfig.current.shareIcon) {
            shareButton?.image = shareImg
        }
        readFiltersFile()
        
        // Data loading now uses SQLite directly - no preload system needed
        let hasRunBefore = UserDefaults.standard.bool(forKey: "hasRunBefore")
        print("🎮 [MDF_DEBUG] hasRunBefore: \(hasRunBefore)")
        
        // Preload country data in background to ensure it's always available
        countryHandler.shared.loadCountryData { 
            print("[MasterViewController] Country data preloaded successfully")
        }
        
        if !hasRunBefore {
            shouldShowCountryDialogAfterDataLoad = true
            print("🎮 [MDF_DEBUG] First install detected - delaying country dialog until data loads")
            print("[MasterViewController] First install detected - delaying country dialog until data loads")
        } else {
            print("🎮 [MDF_DEBUG] Not first install - showing country dialog immediately if needed")
            // Not first install, show country dialog immediately if needed
            getCountry()
        }
        
        self.navigationController?.navigationBar.barStyle = UIBarStyle.black
        self.navigationController?.navigationBar.isTranslucent = false  // Solid black, no transparency over scrolling content
        self.navigationController?.navigationBar.barTintColor = .black
        self.navigationController?.navigationBar.tintColor = UIColor.white
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.white]
        
        // Keep nav bar and stats icon visible when scrolling (do not hide on swipe)
        self.navigationController?.hidesBarsOnSwipe = false
        self.navigationController?.hidesBarsWhenVerticallyCompact = false
        self.navigationController?.barHideOnSwipeGestureRecognizer.isEnabled = false
        self.navigationController?.navigationBar.prefersLargeTitles = false
        
        // Ensure back button always says "Back" when navigating from this view
        let backItem = UIBarButtonItem()
        backItem.title = "Back"
        self.navigationItem.backBarButtonItem = backItem
        
        //have a reference to this controller for external refreshes
        masterView = self;
        
        // Do any additional setup after loading the view, typically from a nib.
        if isSplitViewCapable() {
            splitViewController?.preferredDisplayMode = UISplitViewController.DisplayMode.allVisible
            splitViewController?.preferredPrimaryColumnWidth = 400 // Make left column wider (default ~320)
        }
        
        blankScreenActivityIndicator.hidesWhenStopped = true
        
        //icloud change notification
        NotificationCenter.default.addObserver(self,
                                                         selector: #selector(MasterViewController.onSettingsChanged(_:)),
                                                         name: UserDefaults.didChangeNotification ,
                                                         object: nil)
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(MasterViewController.pullTorefreshData), for: UIControl.Event.valueChanged)
        refreshControl.tintColor = UIColor.red;
        self.refreshControl = refreshControl
        
        mainTableView.separatorColor = UIColor.lightGray
        mainTableView.tableFooterView = UIView() // Remove separators for empty rows
        mainTableView.cellLayoutMarginsFollowReadableWidth = false  // Full width so Day label isn't clipped
        mainTableView.keyboardDismissMode = .onDrag  // Dismiss keyboard when scrolling list
        let tapToDismissKeyboard = UITapGestureRecognizer(target: self, action: #selector(dismissSearchKeyboard(_:)))
        tapToDismissKeyboard.cancelsTouchesInView = false
        tapToDismissKeyboard.delegate = self
        mainTableView.addGestureRecognizer(tapToDismissKeyboard)
        
        //do an initial load of iCloud data on launch
        let showsAttendedHandle = ShowsAttended()
        
        // Only show initial waiting message on first install (reuse hasRunBefore from above)
        if !hasRunBefore {
            print("🎮 [MDF_DEBUG] FIRST LAUNCH PATH - will call performOptimizedFirstLaunch")
            print("[MasterViewController] 🚀 FIRST INSTALL - Starting optimized first launch sequence")
            showInitialWaitingMessage()
            
            // OPTIMIZED FIRST LAUNCH: Download and import data in proper sequence
            // FIX: Call directly instead of dispatching - the delay was preventing execution
            // because viewWillAppear was blocking the main thread
            self.performOptimizedFirstLaunch()
        } else {
            print("🎮 [MDF_DEBUG] SUBSEQUENT LAUNCH PATH - will call performOptimizedSubsequentLaunch")
            print("[MasterViewController] 🚀 SUBSEQUENT LAUNCH - Starting optimized cached launch sequence")
            
            // OPTIMIZED SUBSEQUENT LAUNCH: Display cached data immediately, then update in background
            self.performOptimizedSubsequentLaunch()
        }
        
        UserDefaults.standard.didChangeValue(forKey: "mustSeeAlert")
        
        NotificationCenter.default.addObserver(self, selector: #selector(MasterViewController.refreshDisplayAfterWake2), name: NSNotification.Name(rawValue: "RefreshDisplay"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(MasterViewController.refreshGUI), name: NSNotification.Name(rawValue: "refreshGUI"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector:#selector(MasterViewController.refreshAlerts), name: UserDefaults.didChangeNotification, object: nil)
        
        refreshDisplayAfterWake();
    
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(MasterViewController.showReceivedMessage(_:)),
                                               name: UserDefaults.didChangeNotification, object: nil)
        
        setNeedsStatusBarAppearanceUpdate()
        
        setToolbar();
    
        mainTableView.estimatedSectionHeaderHeight = 44.0
        
        // Add long press gesture recognizer for priority/attendance menu
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        mainTableView.addGestureRecognizer(longPressGesture)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.displayFCMToken(notification:)),
                                               name: Notification.Name("FCMToken"), object: nil)
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(MasterViewController.refreshMainDisplayAfterRefresh), name:NSNotification.Name(rawValue: "refreshMainDisplayAfterRefresh"), object: nil)
        
        let iCloudHandle = iCloudDataHandler()

        //change the notch area to all black
        navigationController?.view.backgroundColor = .black
     
        filterMenuButton?.setTitle(NSLocalizedString("Filters", comment: ""), for: UIControl.State.normal)
        
        //these are needed for iOS 26 visual fixes
        if #available(iOS 26.0, *) {
            preferenceButton?.hidesSharedBackground = true
            statsButton?.hidesSharedBackground = true
            shareButton?.hidesSharedBackground = true
            filterButtonBar?.hidesSharedBackground = true
            searchButtonBar?.hidesSharedBackground = true
            titleButtonArea?.leftBarButtonItem?.hidesSharedBackground = true
            titleButtonArea?.rightBarButtonItem?.hidesSharedBackground = true
            
            preferenceButton?.customView?.backgroundColor = .black
            statsButton?.customView?.backgroundColor = .white 
            
            filterMenuButton?.backgroundColor = .black
            shareButton?.customView?.backgroundColor = .black
            bandSearch?.backgroundColor = .black
            bandSearch?.tintColor = .lightGray
            bandSearch?.barTintColor = .black
            bandSearch?.searchTextField.backgroundColor = .black
            bandSearch?.searchTextField.textColor = .white
            bandSearch?.searchTextField.attributedPlaceholder = NSAttributedString(
                string: NSLocalizedString("SearchCriteria", comment: ""),
                attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray]
            )

            
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(MasterViewController.OnOrientationChange), name: UIDevice.orientationDidChangeNotification, object: nil)
        
        // Initialize DeviceSizeManager to start listening for orientation changes
        // This ensures device size classification is recalculated on orientation changes
        _ = DeviceSizeManager.shared
        
        NotificationCenter.default.addObserver(self, selector: #selector(bandNamesCacheReadyHandler), name: .bandNamesCacheReady, object: nil)
        
        // --- ADDED: Start 5-min timer ---
        startScheduleRefreshTimer()
        // --- END ADDED ---
        
        NotificationCenter.default.addObserver(self, selector: #selector(handlePushNotificationReceived), name: Notification.Name("PushNotificationReceived"), object: nil)
        // App foreground handling is now done globally in AppDelegate
        NotificationCenter.default.addObserver(self, selector: #selector(self.detailDidUpdate), name: Notification.Name("DetailDidUpdate"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleDetailScreenDismissing), name: Notification.Name("DetailScreenDismissing"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(iCloudDataReadyHandler), name: Notification.Name("iCloudDataReady"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(iCloudRefresh), name: Notification.Name("iCloudRefresh"), object: nil)
        
        // Register for toast notifications from migration
        NotificationCenter.default.addObserver(self, selector: #selector(showToastMessage(_:)), name: Notification.Name("ShowToastNotification"), object: nil)
        
        // Register for detailed migration results dialog
        print("🔔 REGISTERING MIGRATION DIALOG OBSERVER IN MasterViewController")
        NotificationCenter.default.addObserver(self, selector: #selector(showMigrationResultsDialog(_:)), name: Notification.Name("ShowMigrationResultsDialog"), object: nil)
        print("🔔 MIGRATION DIALOG OBSERVER REGISTERED SUCCESSFULLY")
        NotificationCenter.default.addObserver(self, selector: #selector(iCloudAttendedDataRestoredHandler), name: Notification.Name("iCloudAttendedDataRestored"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePresentAutoChooseAttendanceWizardWithoutAlert(_:)), name: Notification.Name("PresentAutoChooseAttendanceWizardWithoutAlert"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAutoChooseAttendanceOpenBandDetail(_:)), name: Notification.Name("AutoChooseAttendanceOpenBandDetail"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(bandNamesCacheReadyHandler), name: NSNotification.Name("BandNamesDataReady"), object: nil)
        
        // ✅ DEADLOCK FIX: Register observer for first launch band names loaded
        print("🔍 [NOTIF_REG] Observer target: \(self)")
        print("🔍 [NOTIF_REG] Observer selector: #selector(firstLaunchBandNamesLoadedHandler)")
        print("🔍 [NOTIF_REG] Notification name: BandNamesLoadedFirstLaunch")
        
        NotificationCenter.default.addObserver(self, selector: #selector(firstLaunchBandNamesLoadedHandler), name: NSNotification.Name("BandNamesLoadedFirstLaunch"), object: nil)
        
        print("🔍 [NOTIF_REG] Testing if observer was registered by posting test notification...")
        
        // DIAGNOSTIC: Immediately test if the observer is working
        NotificationCenter.default.post(name: NSNotification.Name("BandNamesLoadedFirstLaunch_TEST"), object: nil)
        print("🔍 [NOTIF_REG] Test notification posted (should not trigger handler)")
        
        // ✅ DEADLOCK FIX: Register observer for first launch schedule loaded
        NotificationCenter.default.addObserver(self, selector: #selector(firstLaunchScheduleLoadedHandler), name: NSNotification.Name("ScheduleLoadedFirstLaunch"), object: nil)
        
        // ✅ DEADLOCK FIX: Register observer for first launch iCloud loaded
        NotificationCenter.default.addObserver(self, selector: #selector(firstLaunchICloudLoadedHandler), name: NSNotification.Name("iCloudLoadedFirstLaunch"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handlePointerDataUpdated), name: Notification.Name("PointerDataUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleBackgroundDataRefresh), name: Notification.Name("BackgroundDataRefresh"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleForegroundRefresh), name: Notification.Name("ForegroundRefresh"), object: nil)
        
        // Register for iCloud loading notifications
        NotificationCenter.default.addObserver(self, selector: #selector(handleiCloudLoadingStarted), name: Notification.Name("iCloudLoadingStarted"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleiCloudLoadingCompleted), name: Notification.Name("iCloudLoadingCompleted"), object: nil)
        
        // Listen for when returning from preferences screen
        NotificationCenter.default.addObserver(self, selector: #selector(handleReturnFromPreferences), name: Notification.Name("DismissPreferencesScreen"), object: nil)
        
        // Listen for when returning from preferences screen after year change (no additional refresh needed)
        NotificationCenter.default.addObserver(self, selector: #selector(handleReturnFromPreferencesAfterYearChange), name: Notification.Name("DismissPreferencesScreenAfterYearChange"), object: nil)
        
        // When venue filters change (e.g. from calendar filter sheet), refresh list so it uses same persistence
        NotificationCenter.default.addObserver(self, selector: #selector(handleVenueFiltersDidChange), name: Notification.Name("VenueFiltersDidChange"), object: nil)
        
        
        // Legacy initialization code removed - now handled by optimized launch methods in performOptimizedFirstLaunch() and performOptimizedSubsequentLaunch()
    }
    
    @objc func bandNamesCacheReadyHandler() {
        // 🔧 FIX: Skip refresh during first launch - the first launch handlers will update the UI
        if cacheVariables.justLaunched {
            print("🎛️ [FIRST_LAUNCH_FIX] ⚠️ SKIPPING bandNamesCacheReadyHandler - first launch still in progress")
            print("🎛️ [FIRST_LAUNCH_FIX] First launch handlers will update the UI when data is ready")
            return
        }
        
        // Prevent infinite loop: only refresh if we haven't already refreshed recently
        // Use CacheManager for throttling
        if cacheManager.shouldThrottleCacheRefresh() {
            return
        }
        lastBandNamesCacheRefresh = Date()
        print("Calling refreshBandList from bandNamesCacheReadyHandler with reason: Band names cache ready")
        
        // Ensure refreshBandList is called on main thread to avoid UI access issues
        if Thread.isMainThread {
        refreshBandList(reason: "Band names cache ready")
        } else {
            DispatchQueue.main.async {
                self.refreshBandList(reason: "Band names cache ready")
            }
        }
        
        // Show country dialog after data loads on first install
        if shouldShowCountryDialogAfterDataLoad {
            shouldShowCountryDialogAfterDataLoad = false
            print("[MasterViewController] Data loaded - showing country dialog for first install")
            DispatchQueue.main.async {
                self.getCountry()
            }
        }
    }
    
    /// ✅ DEADLOCK FIX: Handler for first launch band names loaded notification
    /// This uses NotificationCenter instead of main.async to avoid main queue blocking
    @objc func firstLaunchBandNamesLoadedHandler() {
        let handlerStartTime = CFAbsoluteTimeGetCurrent()
        print("🚀 [NOTIF_TRACE] firstLaunchBandNamesLoadedHandler CALLED at \(handlerStartTime)")
        print("🔍 [NOTIF_TRACE] Current thread: \(Thread.current)")
        print("🔍 [NOTIF_TRACE] Is main thread: \(Thread.current.isMainThread)")
        print("🔍 [NOTIF_TRACE] Main runloop: \(RunLoop.main)")
        print("🔍 [NOTIF_TRACE] Current runloop: \(RunLoop.current)")
        
        // ✅ DIAGNOSTIC: Check main thread status
        print("🔍 [NOTIF_TRACE] About to check if main thread is blocked...")
        print("🔍 [NOTIF_TRACE] About to queue main.async block for Step 3")
        
        // ✅ CRITICAL: Directly populate bands array and reload table view
        // This bypasses all the complex refresh logic that might skip or delay the update
        DispatchQueue.main.async { [weak self] in
            let asyncStartTime = CFAbsoluteTimeGetCurrent()
            print("🎯 [NOTIF_TRACE] ======== main.async BLOCK EXECUTING for Step 3 ========")
            print("🎯 [NOTIF_TRACE] Queued at: \(handlerStartTime), Executing at: \(asyncStartTime)")
            print("🎯 [NOTIF_TRACE] Delay: \((asyncStartTime - handlerStartTime) * 1000)ms")
            print("🎯 [NOTIF_TRACE] Current thread: \(Thread.current)")
            
            guard let self = self else {
                print("❌ [NOTIF_TRACE] self deallocated in Step 3 handler")
                return
            }
            
            print("🔍 [NOTIF_TRACE] self is valid, getting filtered bands for display")
            let bandNames = getFilteredScheduleData(sortedBy: getSortedBy(), priorityManager: self.priorityManager, attendedHandle: self.attendedHandle)
            print("🔍 [NOTIF_TRACE] Got \(bandNames.count) filtered items (events + bands)")
            
            // Directly update the bands array
            let beforeCount = self.bands.count
            self.bands = bandNames
            let afterCount = self.bands.count
            print("🔍 [NOTIF_TRACE] Updated bands array: \(beforeCount) -> \(afterCount)")
            
            // Update iPad toggle button visibility based on data availability
            self.setupViewToggleButton()
            
            // Force table view reload
            print("🔍 [NOTIF_TRACE] About to call tableView.reloadData()")
            self.tableView.reloadData()
            print("🔍 [NOTIF_TRACE] tableView.reloadData() COMPLETED")
            
            // Update count label
            print("🔍 [NOTIF_TRACE] About to call updateCountLable()")
            self.updateCountLable()
            print("🔍 [NOTIF_TRACE] updateCountLable() COMPLETED")
            
            print("🚀 [NOTIF_TRACE] Step 3 refresh COMPLETED - UI now showing \(self.bands.count) bands")
            print("🎯 [NOTIF_TRACE] ======== main.async BLOCK FINISHED for Step 3 ========")
        }
        
        print("🔍 [NOTIF_TRACE] main.async block QUEUED for Step 3 (has not executed yet)")
        print("🔍 [NOTIF_TRACE] firstLaunchBandNamesLoadedHandler RETURNING")
    }
    
    /// ✅ DEADLOCK FIX: Handler for first launch schedule loaded notification
    @objc func firstLaunchScheduleLoadedHandler() {
        print("🚀 FIRST LAUNCH: Step 5 - Schedule imported, final display refresh (via notification)")
        print("🔍 [FIRST_LAUNCH_DEBUG] Current thread: \(Thread.current.isMainThread ? "MAIN" : "BACKGROUND")")
        
        // ✅ CRITICAL: Directly populate bands array and reload table view
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                print("❌ [FIRST_LAUNCH_DEBUG] self deallocated in Step 5 handler")
                return
            }
            
            print("🔍 [FIRST_LAUNCH_DEBUG] Getting filtered bands for display (with schedule)")
            let bandNames = getFilteredScheduleData(sortedBy: getSortedBy(), priorityManager: self.priorityManager, attendedHandle: self.attendedHandle)
            print("🔍 [FIRST_LAUNCH_DEBUG] Got \(bandNames.count) filtered items (events + bands)")
            
            // Directly update the bands array
            self.bands = bandNames
            
            // Update iPad toggle button visibility based on data availability
            self.setupViewToggleButton()
            
            // Force table view reload
            print("🔍 [FIRST_LAUNCH_DEBUG] Reloading table view with \(self.bands.count) bands")
            self.tableView.reloadData()
            
            // Update count label
            self.updateCountLable()
            
            print("🚀 [FIRST_LAUNCH_DEBUG] Step 5 refresh COMPLETED - UI now showing \(self.bands.count) bands")
        }
    }
    
    /// ✅ DEADLOCK FIX: Handler for first launch iCloud loaded notification
    @objc func firstLaunchICloudLoadedHandler() {
        print("🚀 FIRST LAUNCH: Final refresh with iCloud data (via notification)")
        print("🔍 [FIRST_LAUNCH_DEBUG] Current thread: \(Thread.current.isMainThread ? "MAIN" : "BACKGROUND")")
        
        // ✅ CRITICAL: Directly populate bands array and reload table view
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                print("❌ [FIRST_LAUNCH_DEBUG] self deallocated in Final iCloud handler")
                return
            }
            
            print("🔍 [FIRST_LAUNCH_DEBUG] Getting filtered bands for display (with iCloud)")
            let bandNames = getFilteredScheduleData(sortedBy: getSortedBy(), priorityManager: self.priorityManager, attendedHandle: self.attendedHandle)
            print("🔍 [FIRST_LAUNCH_DEBUG] Got \(bandNames.count) filtered items (events + bands)")
            
            // Directly update the bands array
            self.bands = bandNames
            
            // Update iPad toggle button visibility based on data availability
            self.setupViewToggleButton()
            
            // Force table view reload
            print("🔍 [FIRST_LAUNCH_DEBUG] Reloading table view with \(self.bands.count) bands")
            self.tableView.reloadData()
            
            // Update count label
            self.updateCountLable()
            
            print("🚀 [FIRST_LAUNCH_DEBUG] Final iCloud refresh COMPLETED - UI now showing \(self.bands.count) bands")
        }
    }
    
    func searchBarSearchButtonShouldReturn(_ searchBar: UITextField) -> Bool {
        print ("Filtering activated 4, Done")
        searchBar.resignFirstResponder()
        return true
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        print("Filtering activated 1")
        searchBar.resignFirstResponder()
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        // No Cancel button - user dismisses via built-in X (clears & dismisses) or tap/scroll
    }
    
    @objc private func dismissSearchKeyboard(_ gesture: UITapGestureRecognizer) {
        view.endEditing(true)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    /// Keyboard Done toolbar - matches DetailView pattern, uses system .done for native look
    private func installSearchKeyboardDoneToolbar(_ searchBar: UISearchBar) {
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        toolbar.sizeToFit()
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(searchKeyboardDoneTapped))
        toolbar.items = [flex, done]
        toolbar.barTintColor = .black
        toolbar.tintColor = .systemBlue
        searchBar.searchTextField.inputAccessoryView = toolbar
    }
    
    @objc private func searchKeyboardDoneTapped() {
        view.endEditing(true)
    }
    
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // When user clears search (e.g. taps X): dismiss keyboard and ensure search bar is NOT re-selected.
        // iOS automatically re-focuses the search bar when clear is tapped. A short delay lets that complete,
        // then we resign to dismiss the keyboard for good.
        if searchText.isEmpty {
            let bar = searchBar
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                bar.resignFirstResponder()
            }
        }
        
        // Only refresh when search text actually changed - prevents spurious refresh without user input
        guard searchText != lastSearchTextForRefresh else { return }
        lastSearchTextForRefresh = searchText
        
        print("Filtering activated 2  \(searchBar.text ?? "") \(searchBar.text?.count ?? 0)")
        let normalized = normalizedEasterEggSearchText(searchText)
        
        // Accept "more cow bell" or "more cowbell" in any case (with/without spaces).
        let compact = normalized.replacingOccurrences(of: " ", with: "")
        if compact.contains("morecowbell") {
            if !easterEggTriggeredForSearch {
                triggerEasterEgg()
                easterEggTriggeredForSearch = true
            }
        } else {
            easterEggTriggeredForSearch = false
        }
        
        // "pupa party" easter egg: bounce an image around the screen until the user taps anywhere.
        if normalized == "pupa party" {
            if pupaPartyOverlay == nil {
                triggerPupaPartyEasterEgg()
            }
        }
        
        print("Calling refreshBandList from searchBar(_:textDidChange:) with reason: Search changed")
        refreshBandList(reason: "Search changed")
    }

    private func normalizedEasterEggSearchText(_ text: String) -> String {
        // Lowercase + trim + collapse whitespace so users can type "pupa   party".
        let trimmed = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(whereSeparator: { $0.isWhitespace })
        return parts.joined(separator: " ")
    }
    
    @objc func iCloudRefresh() {
        // Move to background to prevent GUI blocking during iCloud operations
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.refreshDataWithBackgroundUpdate(reason: "iCloud refresh")
        }
    }
    
    @objc func refreshMainDisplayAfterRefresh() {
        print("Calling refreshBandList from refreshMainDisplayAfterRefresh with reason: Main display after refresh")
        // Ensure refreshBandList is called on main thread to avoid UI access issues
        if Thread.isMainThread {
            refreshBandList(reason: "Main display after refresh")
        } else {
            DispatchQueue.main.async {
                self.refreshBandList(reason: "Main display after refresh")
            }
        }
    }
    

    
    @objc func displayFCMToken(notification: NSNotification){
      guard let userInfo = notification.userInfo else {return}
      if let fcmToken = userInfo["token"] as? String {
        let message = fcmToken

      }
    }
    
    /// Helper to show toast message at center of screen
    func showToast(message: String, duration: TimeInterval = 2.0) {
        DispatchQueue.main.async {
            let visibleLocation = CGRect(origin: self.tableView.contentOffset, size: self.tableView.bounds.size)
            ToastMessages(message).show(self, cellLocation: visibleLocation, placeHigh: true)
        }
    }

    /// Show toast on the topmost view controller (e.g. when landscape calendar is presented modally)
    func showToastOnTopmostVC(message: String) {
        DispatchQueue.main.async {
            var topVC: UIViewController? = self
            while let presented = topVC?.presentedViewController {
                topVC = presented
            }
            guard let vc = topVC else { return }
            let visibleLocation = CGRect(origin: .zero, size: vc.view.bounds.size)
            ToastMessages(message).show(vc, cellLocation: visibleLocation, placeHigh: false, placeAtBottom: true)
        }
    }
    
    @objc func showToastMessage(_ notification: NSNotification) {
        guard let message = notification.object as? String else { return }
        
        DispatchQueue.main.async {
            // Simple toast implementation using UIAlertController
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            self.present(alert, animated: true)
            
            // Auto-dismiss after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                alert.dismiss(animated: true)
            }
        }
    }
    
    @objc func showMigrationResultsDialog(_ notification: NSNotification) {
        print("🚨 RECEIVED MIGRATION DIALOG NOTIFICATION")
        
        guard let dialogData = notification.object as? [String: Any],
              let migratedCount = dialogData["migratedCount"] as? Int,
              let finalCount = dialogData["finalCount"] as? Int,
              let dataSources = dialogData["dataSources"] as? [String],
              let issues = dialogData["issues"] as? [String],
              let success = dialogData["success"] as? Bool else { 
            print("❌ FAILED TO PARSE MIGRATION DIALOG DATA")
            return 
        }
        
        print("🚨 PARSED DIALOG DATA - Creating UI dialog...")
        
        DispatchQueue.main.async {
            let title = success ? NSLocalizedString("Data Migration Complete", comment: "Migration dialog title when successful") : NSLocalizedString("Data Migration Report", comment: "Migration dialog title when reporting")
            
            var message = ""
            
            if success {
                let successFormat = NSLocalizedString("Successfully migrated %d priority records", comment: "Migration success message with count")
                message += "✅ \(String(format: successFormat, migratedCount))\n"
                let finalCountFormat = NSLocalizedString("Final count: %d records in database", comment: "Migration final count message")
                message += "📊 \(String(format: finalCountFormat, finalCount))\n"
                
                if !dataSources.isEmpty {
                    let dataSourcesFormat = NSLocalizedString("Data sources: %@", comment: "Migration data sources list")
                    message += "📁 \(String(format: dataSourcesFormat, dataSources.joined(separator: ", ")))\n"
                }
            } else {
                message += "⚠️ \(NSLocalizedString("No data found to migrate", comment: "Migration no data message"))\n"
                let currentCountFormat = NSLocalizedString("Current database count: %d records", comment: "Migration current count message")
                message += "📊 \(String(format: currentCountFormat, finalCount))\n"
            }
            
            // Show issues if any
            if !issues.isEmpty {
                message += "\n🔍 \(NSLocalizedString("Issues encountered:", comment: "Migration issues header"))\n"
                for (index, issue) in issues.prefix(5).enumerated() {
                    message += "• \(issue)\n"
                }
                if issues.count > 5 {
                    let moreIssuesFormat = NSLocalizedString("... and %d more issues", comment: "Migration more issues message")
                    message += String(format: moreIssuesFormat, issues.count - 5) + "\n"
                }
                message += "\n📸 \(NSLocalizedString("You can take a screenshot to report these issues.", comment: "Migration screenshot instruction"))"
            }
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .default))
            
            print("🚨 PRESENTING MIGRATION DIALOG TO USER")
            self.present(alert, animated: true)
            print("🚨 MIGRATION DIALOG PRESENTED SUCCESSFULLY")
        }
        
    }

    override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        self.tableView.reloadData()
    }
    
    func checkForEasterEgg(){
        if (lastRefreshCount > 0){
            
            if (lastRefreshCount == 9){
                triggerEasterEgg()
                lastRefreshCount = 0
                lastRefreshEpicTime = Int(Date().timeIntervalSince1970)
                
            } else if (Int(Date().timeIntervalSince1970) > (lastRefreshEpicTime + 40)){
                print ("Easter Egg triggered after more then 40 seconds")
                lastRefreshCount = 1
                lastRefreshEpicTime = Int(Date().timeIntervalSince1970)
                
            } else {
                lastRefreshCount = lastRefreshCount + 1;
                print ("Easter Egg incrementing counter, on \(lastRefreshCount)")
                
            }
            
            
            
        } else {
            lastRefreshCount = 1;
            print ("Easter Egg incrementing counter, on \(lastRefreshCount)")
            
            lastRefreshEpicTime = Int(Date().timeIntervalSince1970)
        }
    }
    
    func triggerEasterEgg(){
    
        if let url = Bundle.main.url(forResource: "SNL-More_Cowbell", withExtension: "mov") {
            videoURL = url
            player = AVPlayer(url: url)
            playerLayer = AVPlayerLayer(player: player)
            
            playerLayer.frame = self.view.bounds
            self.view.layer.addSublayer(playerLayer)
            player.play()
            
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async { [self] in
                sleep(42)
                finishedPlaying()
            }
        } else {
            print("Error: SNL-More_Cowbell.mov not found in bundle.")
        }
    }

    private func triggerPupaPartyEasterEgg() {
        // Keep this isolated: purely visual overlay; no data refresh, no filtering changes.
        let image = loadPupaPartyImage()
            ?? UIImage(named: "70KSearch")
            ?? UIImage(systemName: "sparkles")
        
        let overlay = PupaPartyOverlayView(image: image, minHeightFraction: 0.20)
        overlay.onDismiss = { [weak self] in
            self?.pupaPartyOverlay = nil
        }
        
        let containerView: UIView = navigationController?.view ?? self.view
        overlay.frame = containerView.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.addSubview(overlay)
        overlay.startAnimating()
        
        pupaPartyOverlay = overlay
    }

    private func loadPupaPartyImage() -> UIImage? {
        // Preferred: Images.xcassets with name "pupa_party"
        if let img = UIImage(named: "pupa_party") {
            return img
        }
        
        // Fallback: a raw resource file included in the app bundle (e.g. "pupa_party.png")
        let candidates: [(name: String, ext: String?)] = [
            ("pupa_party", "png"),
            ("PupaParty", "png"),
            ("pupa_party", nil)
        ]
        
        for candidate in candidates {
            let path = Bundle.main.path(forResource: candidate.name, ofType: candidate.ext)
            if let path, let img = UIImage(contentsOfFile: path) {
                return img
            }
        }
        
        return nil
    }

    // MARK: - "Pupa Party" Easter Egg

    private final class PupaPartyOverlayView: UIView {
        
        private let imageView: UIImageView
        private var displayLink: CADisplayLink?
        private var lastTimestamp: CFTimeInterval?
        private var velocity: CGPoint = .zero
        private let minHeightFraction: CGFloat
        
        var onDismiss: (() -> Void)?
        
        init(image: UIImage?, minHeightFraction: CGFloat) {
            self.imageView = UIImageView(image: image)
            self.minHeightFraction = minHeightFraction
            super.init(frame: .zero)
            commonInit()
        }
        
        required init?(coder: NSCoder) {
            self.imageView = UIImageView(image: UIImage(named: "pupa_party"))
            self.minHeightFraction = 0.20
            super.init(coder: coder)
            commonInit()
        }
        
        private func commonInit() {
            backgroundColor = .clear
            isOpaque = false
            isUserInteractionEnabled = true
            
            imageView.contentMode = .scaleAspectFit
            imageView.isUserInteractionEnabled = false
            addSubview(imageView)
            
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            addGestureRecognizer(tap)
        }
        
        func startAnimating() {
            layoutImageViewInitialFrameIfNeeded()
            configureInitialVelocityIfNeeded()
            
            let link = CADisplayLink(target: self, selector: #selector(step))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
        
        private func layoutImageViewInitialFrameIfNeeded() {
            guard imageView.bounds.size == .zero else { return }

            let fallbackSize = CGSize(width: 300, height: 600)
            let original = imageView.image?.size ?? fallbackSize
            let aspect = original.width / max(original.height, 1)

            // Requirement: at least 20% of the screen height (e.g., iPhone 17).
            let targetHeight = max(bounds.height * minHeightFraction, 120)
            var width = targetHeight * max(aspect, 0.05)
            var height = targetHeight

            // Keep it within the screen width with a small margin, preserving aspect ratio.
            let maxWidth = bounds.width * 0.92
            if width > maxWidth {
                let scale = maxWidth / width
                width *= scale
                height *= scale
            }

            imageView.bounds = CGRect(x: 0, y: 0, width: width, height: height)
            
            let safeBounds = bounds.insetBy(dx: width / 2, dy: height / 2)
            let startX = CGFloat.random(in: safeBounds.minX...max(safeBounds.maxX, safeBounds.minX))
            let startY = CGFloat.random(in: safeBounds.minY...max(safeBounds.maxY, safeBounds.minY))
            imageView.center = CGPoint(x: startX, y: startY)
        }
        
        private func configureInitialVelocityIfNeeded() {
            guard velocity == .zero else { return }
            let speed = CGFloat.random(in: 180...360) // points / sec
            let angle = CGFloat.random(in: 0...(2 * .pi))
            velocity = CGPoint(x: cos(angle) * speed, y: sin(angle) * speed)
        }
        
        @objc private func step(link: CADisplayLink) {
            guard bounds.width > 0, bounds.height > 0 else { return }
            
            let now = link.timestamp
            let dt: CGFloat
            if let lastTimestamp {
                dt = CGFloat(now - lastTimestamp)
            } else {
                dt = 0
            }
            lastTimestamp = now
            
            guard dt > 0 else { return }
            
            var nextCenter = CGPoint(
                x: imageView.center.x + velocity.x * dt,
                y: imageView.center.y + velocity.y * dt
            )
            
            let halfW = imageView.bounds.width / 2
            let halfH = imageView.bounds.height / 2
            let minX = halfW
            let maxX = bounds.width - halfW
            let minY = halfH
            let maxY = bounds.height - halfH
            
            var bounced = false
            
            if nextCenter.x <= minX {
                nextCenter.x = minX
                velocity.x = abs(velocity.x)
                bounced = true
            } else if nextCenter.x >= maxX {
                nextCenter.x = maxX
                velocity.x = -abs(velocity.x)
                bounced = true
            }
            
            if nextCenter.y <= minY {
                nextCenter.y = minY
                velocity.y = abs(velocity.y)
                bounced = true
            } else if nextCenter.y >= maxY {
                nextCenter.y = maxY
                velocity.y = -abs(velocity.y)
                bounced = true
            }
            
            if bounced {
                // Add a tiny randomness so it feels screensaver-y.
                velocity.x *= CGFloat.random(in: 0.92...1.08)
                velocity.y *= CGFloat.random(in: 0.92...1.08)
            }
            
            imageView.center = nextCenter
        }
        
        @objc private func handleTap() {
            stopAndRemove()
        }
        
        private func stopAndRemove() {
            displayLink?.invalidate()
            displayLink = nil
            lastTimestamp = nil
            removeFromSuperview()
            onDismiss?()
        }
        
        deinit {
            displayLink?.invalidate()
        }
    }
    
    func finishedPlaying() {
        print("Easter Egg, lets make this go away")
        player.pause()
        if playerLayer.superlayer != nil {
            playerLayer.removeFromSuperlayer()
        }
        player.replaceCurrentItem(with: nil)
        refreshDataWithBackgroundUpdate(reason: "Easter egg finished")
    }
    
    // Defensive cleanup method for navigation - NO data refresh
    func cleanupEasterEggPlayer() {
        player.pause()
        if playerLayer.superlayer != nil {
            playerLayer.removeFromSuperlayer()
        }
        player.replaceCurrentItem(with: nil)
    }
    
    func chooseCountry(){
        
        let countryHandle = countryHandler.shared
        
        // Load country data asynchronously to avoid blocking main thread
        countryHandle.loadCountryData { [weak self] in
            guard let self = self else { return }
            
            let defaultCountry = NSLocale.current.regionCode ?? "US"
            var countryLongShort = countryHandle.getCountryLongShort()

            let alertController = UIAlertController(title: NSLocalizedString("Choose Country", comment: "Alert title for country selection"), message: nil, preferredStyle: .actionSheet)
            var sortedKeys = countryLongShort.keys.sorted()
            for keyValue in sortedKeys {
                alertController.addAction(UIAlertAction(title: keyValue, style: .default, handler: { (_) in
                    do {
                        let finalCountyValue = countryLongShort[keyValue] ?? "Unknown"
                        print ("countryValue writing Acceptable country of " + finalCountyValue + " found")
                        try finalCountyValue.write(to: countryFile, atomically: false, encoding: String.Encoding.utf8)
                    } catch {
                        let countryName = countryLongShort[keyValue] ?? "Unknown"
                        print ("countryValue Error writing Acceptable country of " + countryName + " found " + error.localizedDescription)
                    }
                }))
            }

            if let popoverController = alertController.popoverPresentationController {
                popoverController.sourceView = self.view
                popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.maxY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
           }
       
          self.present(alertController, animated: true, completion: nil)
        }
    }
    
    /// Shows the waiting message immediately on first install only, before data loading begins
    private func showInitialWaitingMessage() {
        let waitingMessage = NSLocalizedString("waiting_for_data", comment: "")
        let initialData = [waitingMessage]
        
        // Update the bands array and table view immediately
        setBands(initialData)
        
        // Force immediate table view update
        self.tableView.reloadData()
        print("[MasterViewController] Initial waiting message displayed immediately (first install only)")
        
        // KISS: After table reload, ensure titleView is visible
        navigationItem.title = nil
        updateCountLable()
        
        // Also ensure the bands array is set globally for mainListController
        bands = initialData
    }
    
    func getCountry(){
        
        //chooseCountry()
        do {
            userCountry = try String(contentsOf: countryFile, encoding: .utf8)
            print ("Using countryValue value of " + userCountry + " \(countryFile)")
            
            if (userCountry.isEmpty == false){
                return
            }
        } catch {
            //do nothing
        }

        // Use shared country handler with background loading to prevent GUI blocking
        let countryHandle = countryHandler.shared
        
        // Load country data in background (uses cache if available)
        countryHandle.loadCountryData { [weak self] in
            guard let self = self else { return }
            
            // This completion block runs on main thread
            let defaultCountry = NSLocale.current.regionCode ?? "United States"
            let countryShortLong = countryHandle.getCountryShortLong()
            let countryLongShort = countryHandle.getCountryLongShort()
            let defaultLongCountry = countryShortLong[defaultCountry] ?? "Unknown"
            
            //UIAlertControllerStyleAlert
            let alert = UIAlertController.init(title: NSLocalizedString("verifyCountry", comment: ""), message: NSLocalizedString("correctCountryDescription", comment: ""), preferredStyle: UIAlertController.Style.alert)
            
            
            alert.addTextField { (textField) in
                textField.text = defaultLongCountry
                textField.isEnabled = false
            }

            let correctButton = UIAlertAction.init(title: NSLocalizedString("correctCountry", comment: ""), style: .default) { _ in
                alert.dismiss(animated: true)
                self.chooseCountry();
            }
            alert.addAction(correctButton)
            
            let OkButton = UIAlertAction.init(title: NSLocalizedString("confirmCountry", comment: ""), style: .default) { _ in
                var countryValue = countryLongShort[alert.textFields![0].text!]
                print ("countryValue Acceptable country of " + countryValue! + " found")
                
                do {
                    print ("countryValue writing Acceptable country of " + countryValue! + " found")
                    try countryValue!.write(to: countryFile, atomically: false, encoding: String.Encoding.utf8)
                } catch {
                    print ("countryValue Error writing Acceptable country of " + countryValue! + " found " + error.localizedDescription)
                }
            }
            alert.addAction(OkButton)
            
            
            if let popoverController = alert.popoverPresentationController {
                popoverController.sourceView = self.view
                popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.maxY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
           }
       
           self.present(alert, animated: true, completion: nil)
        }
        
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let countryHandle = countryHandler.shared
        
        // Only use autocomplete if country data is already loaded (don't block main thread)
        guard !countryHandle.getCountryShortLong().isEmpty else {
            return true  // Allow typing but no autocomplete until data is loaded
        }
        
        let countryShortLong = countryHandle.getCountryShortLong()
        var autoCompletionPossibilities = [String]()
        
        for value in countryShortLong.values {
            autoCompletionPossibilities.append(value)
        }
        
        return !autoCompleteText( in : textField, using: string, suggestionsArray: autoCompletionPossibilities)
    }
    
    func autoCompleteText( in textField: UITextField, using string: String, suggestionsArray: [String]) -> Bool {
            if !string.isEmpty,
                let selectedTextRange = textField.selectedTextRange,
                selectedTextRange.end == textField.endOfDocument,
                let prefixRange = textField.textRange(from: textField.beginningOfDocument, to: selectedTextRange.start),
                let text = textField.text( in : prefixRange) {
                let prefix = text + string
                let matches = suggestionsArray.filter {
                    $0.hasPrefix(prefix)
                }
                if (matches.count > 0) {
                    textField.text = matches[0]
                    if let start = textField.position(from: textField.beginningOfDocument, offset: prefix.count) {
                        textField.selectedTextRange = textField.textRange(from: start, to: textField.endOfDocument)
                        return true
                    }
                }
            }
            return false
        }
    
    func setToolbar(){
        navigationController?.navigationBar.barTintColor = UIColor.black
        navigationController?.navigationBar.isTranslucent = false
        mainToolBar?.barTintColor = .black
        mainToolBar?.isTranslucent = false
    }
    
    /// Builds titleView with count label. Stats icon is set as leftBarButtonItem (far left, symmetric with preferences).
    private func makeTitleViewWithStats(text: String, profileColor: UIColor) -> UIView {
        let label: UILabel
        if let existing = titleCountLabel {
            label = existing
        } else {
            label = UILabel()
            label.font = UIFont.boldSystemFont(ofSize: 17)
            label.textAlignment = .center
            label.isUserInteractionEnabled = true
            label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showProfilePicker)))
            titleCountLabel = label
        }
        label.text = text
        label.textColor = profileColor
        label.sizeToFit()
        label.frame = CGRect(x: 0, y: 0, width: max(label.bounds.width, 100), height: 44)
        return label
    }
    
    /// Updates left bar button with stats icon (far left, symmetric with preferences on right). Uses customView to stay visible when scrolling.
    private func installStatsBarButton() {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(named: FestivalConfig.current.statsIcon), for: .normal)
        btn.tintColor = .white
        btn.addTarget(self, action: #selector(statsButtonTapped(_:)), for: .touchUpInside)
        btn.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        container.addSubview(btn)
        btn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            btn.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            btn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            btn.widthAnchor.constraint(equalToConstant: 44),
            btn.heightAnchor.constraint(equalToConstant: 44)
        ])
        let barItem = UIBarButtonItem(customView: container)
        if #available(iOS 26.0, *) {
            barItem.hidesSharedBackground = true
        }
        navigationItem.leftBarButtonItem = barItem
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        print ("The awakeFromNib was called");
        if isSplitViewCapable() {
            self.clearsSelectionOnViewWillAppear = false
            self.preferredContentSize = CGSize(width: 320.0, height: 600.0)
        }
    }

    // Track background refresh operations to prevent overlapping
    private static var isBackgroundRefreshInProgress = false
    
    // Centralized background refresh with immediate GUI update
    func refreshDataWithBackgroundUpdate(reason: String) {
        // Delegate to ViewModel
        viewModel.refreshDataWithBackgroundUpdate(
            reason: reason,
            onCacheRefresh: { [weak self] in
                guard let self = self else { return }
                // Ensure refreshBandList is called on main thread to avoid UI access issues
                if Thread.isMainThread {
                    self.refreshBandList(reason: "\(reason) - immediate cache refresh")
                } else {
                    DispatchQueue.main.async {
                        self.refreshBandList(reason: "\(reason) - immediate cache refresh")
                    }
                }
            },
            onBackgroundComplete: { [weak self] in
                guard let self = self else { return }
                self.refreshBandList(reason: "\(reason) - background refresh complete")
            }
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Re-apply on each appear – physical device may reset nav bar behavior
        navigationController?.hidesBarsOnSwipe = false
        navigationController?.hidesBarsWhenVerticallyCompact = false
        navigationController?.barHideOnSwipeGestureRecognizer.isEnabled = false
        navigationController?.navigationBar.prefersLargeTitles = false
        
        // Ensure UI elements are visible when view appears (especially after rotation)
        print("🔄 [VIEW_LIFECYCLE] viewWillAppear called")
        print("🔄 [VIEW_LIFECYCLE] isShowingLandscapeSchedule: \(isShowingLandscapeSchedule)")
        print("🔄 [VIEW_LIFECYCLE] presentedViewController: \(presentedViewController != nil ? String(describing: type(of: presentedViewController!)) : "nil")")
        print("🔄 [VIEW_LIFECYCLE] view.window: \(view.window != nil ? "exists" : "nil")")
        print("🔄 [VIEW_LIFECYCLE] filterMenuButton.isHidden: \(filterMenuButton?.isHidden ?? true)")
        print("🔄 [VIEW_LIFECYCLE] bandSearch.isHidden: \(bandSearch?.isHidden ?? true)")
        print("🔄 [VIEW_LIFECYCLE] filterMenuButton.superview: \((filterMenuButton?.superview).map { String(describing: type(of: $0)) } ?? "nil")")
        print("🔄 [VIEW_LIFECYCLE] bandSearch.superview: \((bandSearch?.superview).map { String(describing: type(of: $0)) } ?? "nil")")
        
        filterMenuButton?.isHidden = false
        bandSearch?.isHidden = false
        filterMenuButton?.alpha = 1.0
        bandSearch?.alpha = 1.0
        mainToolBar?.isHidden = false
        mainToolBar?.alpha = 1.0
        
        // Stats on far left (symmetric with preferences on right), or "Back to wizard" when returning from wizard's band list
        if autoChooseWizardResumeYear != nil {
            installBackToWizardButtonIfNeeded()
        } else {
            installStatsBarButton()
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", startTime))] viewWillAppear START - returning from details")
        print("🎛️ [PREFERENCES_SYNC] ⚠️ viewWillAppear called - this might override user preference changes!")
        print("🎛️ [PREFERENCES_SYNC] Current hideExpiredEvents at viewWillAppear start: \(getHideExpireScheduleData())")
        
        // Setup iPad view toggle button
        setupViewToggleButton()
        
        // Register for preference source change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onPreferenceSourceChanged(_:)),
            name: Notification.Name("PreferenceSourceChanged"),
            object: nil
        )
        
        // Update title in case source changed
        updateTitleForActivePreferenceSource()
        
        // Ensure back button always says "Back" when navigating from this view
        let backItem = UIBarButtonItem()
        backItem.title = "Back"
        self.navigationItem.backBarButtonItem = backItem
        
        let setupTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", setupTime))] viewWillAppear - basic setup complete")
        
        isLoadingBandData = false
        writeFiltersFile()
        
        let filtersTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", filtersTime))] viewWillAppear - filters written, starting background refresh")
        print("🎛️ [PREFERENCES_SYNC] hideExpiredEvents after writeFiltersFile: \(getHideExpireScheduleData())")
        
        // 🔧 FIX: Skip automatic refresh if we just returned from preferences to prevent override
        if justReturnedFromPreferences {
            print("🎛️ [PREFERENCES_SYNC] ⚠️ SKIPPING viewWillAppear refresh - just returned from preferences (flag-based detection)")
            print("🎛️ [PREFERENCES_SYNC] This prevents overriding user's preference changes")
            // Clear the flag after use
            justReturnedFromPreferences = false
        } else if cacheVariables.justLaunched {
            print("🎛️ [FIRST_LAUNCH_FIX] ⚠️ SKIPPING viewWillAppear refresh - first launch still in progress")
            print("🎛️ [FIRST_LAUNCH_FIX] This prevents flickering during initial data load")
        } else {
            print("🎛️ [PREFERENCES_SYNC] Proceeding with viewWillAppear refresh (normal app flow)")
            
            // CRITICAL: Move ALL data refresh operations to background to prevent GUI blocking
            // This ensures the UI remains responsive when returning from background/details
            // Simple cache refresh when returning from details - no background operations needed
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                let backgroundStartTime = CFAbsoluteTimeGetCurrent()
                print("🕐 [\(String(format: "%.3f", backgroundStartTime))] Cache refresh START - reason: Return from details")
                
                // Just refresh from cache - no network operations needed - dispatch to main thread
                DispatchQueue.main.async {
                self.refreshBandList(reason: "Return from details - cache refresh")
                
                let backgroundEndTime = CFAbsoluteTimeGetCurrent()
                print("🕐 [\(String(format: "%.3f", backgroundEndTime))] Cache refresh END - reason: Return from details")
                }
            }
        }
        
        cleanupEasterEggPlayer() // Defensive: ensure no video is left over
        
        // Schedule scroll position restoration and landscape check for after data loads
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // Restore scroll position if we have one saved
            if let savedPosition = self.savedScrollPosition {
                print("🔄 [LANDSCAPE_SCHEDULE] Restoring scroll position: \(savedPosition)")
                self.tableView.setContentOffset(savedPosition, animated: false)
                self.savedScrollPosition = nil
                
                // Update viewing day from restored position
                self.updateCurrentViewingDayFromVisibleCells()
            }
            
            // CRITICAL FIX: When returning from detail screen, check if detail screen was dismissed
            // from landscape view. If so, check orientation and show appropriate view.
            // This handles the case where user rotates in detail screen, then exits detail screen.
            if self.isShowingLandscapeSchedule,
               let landscapeVC = self.landscapeScheduleViewController,
               landscapeVC.presentedViewController == nil {
                // Detail screen was dismissed, check orientation to show appropriate view
                print("🔄 [LANDSCAPE_SCHEDULE] Detail screen dismissed, checking orientation for appropriate view")
                
                // CRITICAL FIX: For iPad (master/detail), preserve the view state we left from
                // Don't change based on orientation - use isManualCalendarView to restore state
                if self.isSplitViewCapable() {
                    // iPad: Restore the view state based on manual toggle, not orientation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        guard let self = self else { return }
                        if self.isManualCalendarView {
                            // User was in calendar mode - restore calendar view
                            if !self.isShowingLandscapeSchedule {
                                print("📱 [IPAD_TOGGLE] Restoring calendar view after detail dismissal in viewWillAppear (was in calendar mode)")
                                self.updateCurrentViewingDayFromVisibleCells()
                                self.presentLandscapeScheduleView()
                            } else {
                                print("📱 [IPAD_TOGGLE] Calendar view already showing after detail dismissal in viewWillAppear")
                            }
                        } else {
                            // User was in list mode - ensure list view is showing
                            if self.isShowingLandscapeSchedule {
                                print("📱 [IPAD_TOGGLE] Dismissing calendar view after detail dismissal in viewWillAppear (was in list mode)")
                                self.dismissLandscapeScheduleView()
                            } else {
                                print("📱 [IPAD_TOGGLE] List view already showing after detail dismissal in viewWillAppear")
                            }
                        }
                    }
                    return // Exit early - iPad behavior handled above
                }
                
                // iPhone: Use orientation-based logic (existing behavior)
                // CRITICAL FIX: Use a small delay to ensure view bounds are updated after detail dismissal
                // Then check if iPhone is in portrait and dismiss calendar view immediately
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    guard let self = self else { return }
                    
                    // CRITICAL FIX: If iPhone is in portrait, immediately dismiss calendar view
                    // Don't wait for orientation check - portrait mode never shows calendar
                    // Get main window (not landscape view controller's window)
                    let mainWindow = UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .flatMap { $0.windows }
                        .first { $0.isKeyWindow } ?? self.view.window
                    
                    let windowBounds = mainWindow?.bounds ?? self.view.bounds
                    let windowBoundsLandscape = windowBounds.width > windowBounds.height
                    let viewBoundsLandscape = self.view.bounds.width > self.view.bounds.height
                    let statusBarLandscape = UIApplication.shared.statusBarOrientation.isLandscape
                    let deviceOrientationLandscape = UIDevice.current.orientation.isLandscape
                    
                    // CRITICAL: Prioritize device orientation and status bar over window bounds
                    let isLandscape: Bool
                    if !statusBarLandscape && !deviceOrientationLandscape {
                        // Both device and statusBar say portrait - trust them
                        isLandscape = false
                    } else if statusBarLandscape || deviceOrientationLandscape {
                        // Device or statusBar say landscape - trust them
                        isLandscape = true
                    } else {
                        // Fallback to window bounds
                        isLandscape = windowBoundsLandscape || viewBoundsLandscape
                    }
                    
                    if !isLandscape {
                        print("🚫 [LANDSCAPE_SCHEDULE] iPhone in portrait after detail dismissal in viewWillAppear - immediately dismissing calendar")
                        self.dismissLandscapeScheduleView()
                        return // Skip orientation check - we've already dismissed
                    }
                    
                    self.checkOrientationAndShowLandscapeIfNeeded()
                }
            } else {
                // Normal case: Check orientation and show landscape view if needed
                self.checkOrientationAndShowLandscapeIfNeeded()
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", endTime))] viewWillAppear END - total time: \(String(format: "%.3f", (endTime - startTime) * 1000))ms")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Ensure UI elements are visible when view appears (especially after rotation)
        print("🔄 [VIEW_LIFECYCLE] viewDidAppear called")
        print("🔄 [VIEW_LIFECYCLE] isShowingLandscapeSchedule: \(isShowingLandscapeSchedule)")
        print("🔄 [VIEW_LIFECYCLE] presentedViewController: \(presentedViewController != nil ? String(describing: type(of: presentedViewController!)) : "nil")")
        print("🔄 [VIEW_LIFECYCLE] view.window: \(view.window != nil ? "exists" : "nil")")
        print("🔄 [VIEW_LIFECYCLE] filterMenuButton.isHidden: \(filterMenuButton?.isHidden ?? true)")
        print("🔄 [VIEW_LIFECYCLE] bandSearch.isHidden: \(bandSearch?.isHidden ?? true)")
        print("🔄 [VIEW_LIFECYCLE] navigationItem.titleView: \(navigationItem.titleView != nil ? String(describing: type(of: navigationItem.titleView!)) : "nil")")
        
        filterMenuButton?.isHidden = false
        bandSearch?.isHidden = false
        filterMenuButton?.alpha = 1.0
        bandSearch?.alpha = 1.0
        mainToolBar?.isHidden = false
        mainToolBar?.alpha = 1.0
        
        // KISS: Always ensure titleView is visible when view appears
        // Clear navigationItem.title first (it hides titleView)
        navigationItem.title = nil
        
        // Update the counter (this creates/updates titleView)
        updateCountLable()
        
        // Force navigation bar to refresh
        navigationController?.navigationBar.setNeedsLayout()
        navigationController?.navigationBar.layoutIfNeeded()
        
        // Force view to update layout
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        // Run orientation check after view has laid out (fixes launch in landscape showing portrait)
        if !isSplitViewCapable() {
            checkOrientationAndShowLandscapeIfNeeded()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // CRITICAL FIX: Check orientation after layout changes (more reliable than OnOrientationChange)
        // This catches cases where orientation changes but the notification hasn't fired yet
        // BUT: Don't dismiss if a detail screen is currently presented - let it handle its own orientation
        // PERF: Skip if already dismissing (prevents cascade) or if we checked recently (debounce)
        if !isSplitViewCapable() && isShowingLandscapeSchedule && !isDismissingLandscapeSchedule {
            let now = CFAbsoluteTimeGetCurrent()
            if now - lastPortraitDismissCheckTime < 0.25 {
                return
            }
            lastPortraitDismissCheckTime = now
            
            // CRITICAL: If a detail screen is currently presented, don't dismiss on orientation change
            if let landscapeVC = landscapeScheduleViewController,
               landscapeVC.presentedViewController != nil {
                return
            }
            
            let mainWindow = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? view.window
            
            let windowBounds = mainWindow?.bounds ?? view.bounds
            let statusBarLandscape = UIApplication.shared.statusBarOrientation.isLandscape
            let deviceOrientationLandscape = UIDevice.current.orientation.isLandscape
            
            let isLandscape: Bool
            if !statusBarLandscape && !deviceOrientationLandscape {
                isLandscape = false
            } else if statusBarLandscape || deviceOrientationLandscape {
                isLandscape = true
            } else {
                isLandscape = windowBounds.width > windowBounds.height
            }
            
            if !isLandscape {
                dismissLandscapeScheduleView()
            }
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        print("🔄 [ROTATION] viewWillTransition called - size: \(size)")
        print("🔄 [ROTATION] isShowingLandscapeSchedule: \(isShowingLandscapeSchedule)")
        print("🔄 [ROTATION] presentedViewController: \(presentedViewController != nil ? String(describing: type(of: presentedViewController!)) : "nil")")
        print("🔄 [ROTATION] filterMenuButton.isHidden: \(filterMenuButton?.isHidden ?? true)")
        print("🔄 [ROTATION] bandSearch.isHidden: \(bandSearch?.isHidden ?? true)")
        print("🔄 [ROTATION] view.window: \(view.window != nil ? "exists" : "nil")")
        
        // If transitioning from landscape to portrait, dismiss any open landscape filter menu
        // This must happen synchronously before rotation to prevent blocking the transition
        if isShowingLandscapeSchedule, let landscapeVC = landscapeScheduleViewController {
            // Check for presented sheet (SwiftUI sheet presentation)
            if let presentedSheet = landscapeVC.presentedViewController {
                print("🔄 [ROTATION] Found presented sheet on landscape VC: \(type(of: presentedSheet))")
                print("🔄 [ROTATION] Dismissing landscape filter menu sheet before rotation")
                // Dismiss synchronously - don't wait for animation
                presentedSheet.dismiss(animated: false, completion: {
                    print("🔄 [ROTATION] Landscape sheet dismissal completed")
                })
            }
            // Also check for any child view controllers that might be filter menus
            for childVC in landscapeVC.children.reversed() {
                let childTypeName = String(describing: type(of: childVC))
                if childTypeName.contains("HostingController") || childTypeName.contains("Filter") {
                    print("🔄 [ROTATION] Removing filter menu child view controller from landscape: \(childTypeName)")
                    childVC.view.removeFromSuperview()
                    childVC.removeFromParent()
                }
            }
        }
        
        // Determine if we're transitioning from landscape to portrait
        let isTransitioningToPortrait = size.width < size.height
        
        // If transitioning to portrait and landscape view is showing, ensure it's fully dismissed
        if isTransitioningToPortrait && isShowingLandscapeSchedule {
            print("🔄 [ROTATION] Transitioning to portrait - ensuring landscape view is dismissed")
            // Use coordinator to ensure dismissal happens before rotation completes
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                guard let self = self else { return }
                // Double-check that landscape view is dismissed
                if self.isShowingLandscapeSchedule {
                    print("🔄 [ROTATION] Landscape view still showing after rotation - forcing dismissal")
                    self.dismissLandscapeScheduleView()
                }
            }
        }
        
        // Dismiss the SwiftUI filter menu (portrait mode) before rotation
        if let existing = currentFilterMenuHostingController {
            print("🔄 [ROTATION] Dismissing portrait filter menu hosting controller")
            existing.view.removeFromSuperview()
            existing.removeFromParent()
            currentFilterMenuHostingController = nil
        }
        
        print("🔄 [ROTATION] After dismissing menus - filterMenuButton.isHidden: \(filterMenuButton?.isHidden ?? true)")
        print("🔄 [ROTATION] After dismissing menus - bandSearch.isHidden: \(bandSearch?.isHidden ?? true)")
        
        // Ensure UI elements remain visible during rotation
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            guard let self = self else { return }
            print("🔄 [ROTATION] Rotation animation complete - restoring UI")
            self.filterMenuButton?.isHidden = false
            self.bandSearch?.isHidden = false
            self.filterMenuButton?.alpha = 1.0
            self.bandSearch?.alpha = 1.0
            self.mainToolBar?.isHidden = false
            self.mainToolBar?.alpha = 1.0
            
            print("🔄 [ROTATION] After restore in animation - filterMenuButton.isHidden: \(self.filterMenuButton?.isHidden ?? true)")
            print("🔄 [ROTATION] After restore in animation - bandSearch.isHidden: \(self.bandSearch?.isHidden ?? true)")
            print("🔄 [ROTATION] After restore in animation - view.window: \(self.view.window != nil ? "exists" : "nil")")
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cleanupEasterEggPlayer()
    }

    @IBAction func titleButtonAction(_ sender: AnyObject) {
        // Show profile picker instead of scrolling to top
        showProfilePicker()
    }
    
    /// Gets the color for the currently active profile
    private func getColorForCurrentProfile() -> UIColor {
        let sharingManager = SharedPreferencesManager.shared
        let activeProfile = sharingManager.getActivePreferenceSource()
        return ProfileColorManager.shared.getColor(for: activeProfile)
    }
    
    /// Shows profile picker UI
    @objc func showProfilePicker() {
        print("🔍 [PICKER] Opening profile picker")
        
        let pickerVC = ProfilePickerViewController(style: UITableView.Style.plain)
        pickerVC.masterViewController = self
        
        let navController = UINavigationController(rootViewController: pickerVC)
        
        if isSplitViewCapable() {
            // Large display: Use popover for proper split view support
            navController.modalPresentationStyle = .popover
            
            if let popover = navController.popoverPresentationController {
                // Anchor to the title view (count label)
                popover.sourceView = navigationItem.titleView ?? navigationController?.navigationBar ?? view
                popover.sourceRect = navigationItem.titleView?.bounds ?? CGRect(x: view.bounds.midX, y: 0, width: 0, height: 0)
                popover.permittedArrowDirections = [.up, .down]
                popover.backgroundColor = UIColor.black.withAlphaComponent(0.9)
                
                // Set delegate to handle dismissal
                popover.delegate = pickerVC
            }
            
            navController.preferredContentSize = CGSize(width: 320, height: 400)
        } else {
            // iPhone: Use overCurrentContext for transparency
            navController.modalPresentationStyle = .overCurrentContext
            navController.modalTransitionStyle = .crossDissolve
            navController.view.backgroundColor = UIColor.clear
            navController.preferredContentSize = CGSize(width: 300, height: 400)
        }
        
        present(navController, animated: true)
    }
    
    /// Confirms deletion of a profile
    /// Clears all caches and forces a complete refresh
    func clearAllCachesAndRefresh() {
        print("🔄 [PROFILE] Forcing complete data refresh...")
        
        // Clear all caches using CacheManager
        cacheManager.clearAllCachesAndMasterViewData(
            objects: &objects,
            bands: &bands,
            bandsByTime: &bandsByTime,
            bandsByName: &bandsByName
        )
        
        // Force refresh with user-initiated flag to bypass throttle
        refreshData(isUserInitiated: true, forceDownload: false)
        quickRefresh_Pre()
    }

    
    @objc func showReceivedMessage(_ notification: Notification) {
        if let info = notification.userInfo as? Dictionary<String,AnyObject> {
            if let aps = info["aps"] as? Dictionary<String, String> {
                let title = NSLocalizedString("Message received", comment: "Alert title when a push notification message is received")
                showAlert(title, message: aps["alert"]!)
            }
        } else {
            print("Software failure. Guru meditation.")
        }
    }
    
    func showAlert(_ title:String, message:String) {

            let alert = UIAlertController(title: title,
                                          message: message, preferredStyle: .alert)
            let dismissAction = UIAlertAction(title: NSLocalizedString("Dismiss", comment: "Alert dismiss button"), style: .destructive, handler: nil)
            alert.addAction(dismissAction)
            self.present(alert, animated: true, completion: nil)
            isLoadingBandData = false
            // Refresh data when showing alert - often means new data was announced
            refreshDataWithBackgroundUpdate(reason: "Show alert")
    }
    
    
    private var currentFilterMenuHostingController: UIHostingController<PortraitFilterSheetView>?
    
    @IBAction func filterMenuButtonPress(_ sender: Any) {
        print("🔘 [FILTER_MENU] filterMenuButtonPress called")
        print("🔘 [FILTER_MENU] Current view controller: \(type(of: self))")
        print("🔘 [FILTER_MENU] isShowingLandscapeSchedule: \(isShowingLandscapeSchedule)")
        print("🔘 [FILTER_MENU] presentedViewController: \(presentedViewController != nil ? String(describing: type(of: presentedViewController!)) : "nil")")
        print("🔘 [FILTER_MENU] filterMenuButton.isHidden: \(filterMenuButton?.isHidden ?? true)")
        print("🔘 [FILTER_MENU] filterMenuButton.alpha: \(filterMenuButton?.alpha ?? 0)")
        print("🔘 [FILTER_MENU] filterMenuButton.superview: \((filterMenuButton?.superview).map { String(describing: type(of: $0)) } ?? "nil")")
        print("🔘 [FILTER_MENU] view.isHidden: \(view.isHidden)")
        print("🔘 [FILTER_MENU] view.window: \(view.window != nil ? "exists" : "nil")")
        
        // Dismiss existing menu if present
        if let existing = currentFilterMenuHostingController {
            print("🔘 [FILTER_MENU] Dismissing existing menu")
            existing.view.removeFromSuperview()
            existing.removeFromParent()
            currentFilterMenuHostingController = nil
            mainTableView.isScrollEnabled = true
            return
        }
        
        // Ensure filter state (Clear Filters / badge) is current when opening the sheet
        setFilterTitleText()
        
        // Create SwiftUI filter sheet with dismiss handler
        let filterSheetView = PortraitFilterSheetView(
            onDismiss: { [weak self] in
                self?.dismissFilterMenuProgrammatically()
            }
        )
        let hostingController = UIHostingController(rootView: filterSheetView)
        currentFilterMenuHostingController = hostingController
        
        print("🔘 [FILTER_MENU] Created hosting controller")
        
        // Make the view controller background darker grey (same as menu)
        hostingController.view.backgroundColor = UIColor(white: 0.2, alpha: 1.0) // Darker grey
        
        // Size the menu similar to the old DropDown (300pt width, positioned near button)
        let menuWidth: CGFloat = 300
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        // Get button frame in view coordinates
        var menuX: CGFloat = 20
        var menuY: CGFloat = 100
        var menuHeight: CGFloat = min(screenHeight * 0.7, 600)
        
        if let btn = effectiveFilterButton, let buttonFrame = btn.superview?.convert(btn.frame, to: view) {
            // Position menu below the button, similar to old DropDown
            menuX = max(20, min(buttonFrame.origin.x - 20, screenWidth - menuWidth - 20))
            menuY = buttonFrame.maxY + 8
            
            // KISS: Calculate height using window coordinates for consistency
            // Convert button frame to window coordinates to get accurate position
            let window: UIWindow? = view.window ?? {
                let scenes = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap { $0.windows }
                return scenes.first { $0.isKeyWindow }
            }()
            
            if let window = window {
                let buttonFrameInWindow = btn.superview?.convert(btn.frame, to: window)
                let buttonBottom = (buttonFrameInWindow?.maxY ?? buttonFrame.maxY) + 8
                let safeAreaBottom = window.safeAreaInsets.bottom
                let bottomPadding: CGFloat = 20 + safeAreaBottom
                let availableHeight = window.bounds.height - buttonBottom - bottomPadding
                
                menuHeight = max(300, min(availableHeight, screenHeight * 0.8))
                
                print("🔘 [FILTER_MENU] Height calculation - window.height: \(window.bounds.height), buttonBottom: \(buttonBottom), availableHeight: \(availableHeight), menuHeight: \(menuHeight)")
            } else {
                // Fallback: use view bounds
                let availableHeight = view.bounds.height - menuY - 20
                menuHeight = max(300, min(availableHeight, screenHeight * 0.8))
                print("🔘 [FILTER_MENU] Height calculation (fallback) - view.height: \(view.bounds.height), menuY: \(menuY), availableHeight: \(availableHeight), menuHeight: \(menuHeight)")
            }
        }
        
        // Configure the view
        hostingController.view.frame = CGRect(x: menuX, y: menuY, width: menuWidth, height: menuHeight)
        hostingController.view.layer.cornerRadius = 8
        hostingController.view.layer.borderWidth = 1
        hostingController.view.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        hostingController.view.clipsToBounds = true
        hostingController.view.alpha = 0
        hostingController.view.isOpaque = true  // Ensure fully opaque
        
        // Disable table scrolling while menu is displayed
        mainTableView.isScrollEnabled = false
        
        // Add as child view controller and subview
        print("🔘 [FILTER_MENU] Adding hosting controller as child")
        print("🔘 [FILTER_MENU] view.frame: \(view.frame)")
        print("🔘 [FILTER_MENU] hostingController.view.frame: \(hostingController.view.frame)")
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        print("🔘 [FILTER_MENU] Hosting controller added, view hierarchy:")
        print("🔘 [FILTER_MENU] - view.subviews.count: \(view.subviews.count)")
        print("🔘 [FILTER_MENU] - hostingController.view.superview: \(hostingController.view.superview != nil ? String(describing: type(of: hostingController.view.superview!)) : "nil")")
        print("🔘 [FILTER_MENU] - hostingController.view.isHidden: \(hostingController.view.isHidden)")
        print("🔘 [FILTER_MENU] - hostingController.view.alpha: \(hostingController.view.alpha)")
        
        // Animate in
        UIView.animate(withDuration: 0.2) {
            hostingController.view.alpha = 1
        } completion: { _ in
            print("🔘 [FILTER_MENU] Animation complete, hostingController.view.alpha: \(hostingController.view.alpha)")
        }
        
        // Add tap gesture to dismiss when tapping outside
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissFilterMenu))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        
        print("🔘 [FILTER_MENU] Menu presentation complete")
    }
    
    @objc private func dismissFilterMenu(_ gesture: UITapGestureRecognizer) {
        guard let hostingController = currentFilterMenuHostingController else { return }
        
        let location = gesture.location(in: view)
        if !hostingController.view.frame.contains(location) {
            // Tapped outside the menu, dismiss it
            dismissFilterMenuProgrammatically()
            gesture.view?.removeGestureRecognizer(gesture)
        }
    }
    
    private func dismissFilterMenuProgrammatically() {
        guard let hostingController = currentFilterMenuHostingController else { return }
        
        UIView.animate(withDuration: 0.2, animations: {
            hostingController.view.alpha = 0
        }) { _ in
            hostingController.view.removeFromSuperview()
            hostingController.removeFromParent()
            self.currentFilterMenuHostingController = nil
            self.mainTableView.isScrollEnabled = true
        }
    }
    
    /// Presents the schedule wizard without showing the import prompt (used when auto-schedule pointer flags trigger).
    @objc private func handlePresentAutoChooseAttendanceWizardWithoutAlert(_ notification: Notification) {
        guard FestivalConfig.current.aiSchedule else { return }
        let year = notification.userInfo?["eventYear"] as? Int ?? eventYear
        DispatchQueue.main.async { [weak self] in
            self?.presentAutoChooseAttendanceWizard(eventYear: year)
        }
    }
    
    private func presentAutoChooseAttendanceWizard(eventYear year: Int) {
        let wizardView = AutoChooseAttendanceWizardView(
            eventYear: year,
            onDismiss: { [weak self] _ in
                self?.autoChooseWizardResumeYear = nil
                self?.presentedViewController?.dismiss(animated: true)
                NotificationCenter.default.post(name: Notification.Name("RefreshLandscapeSchedule"), object: nil)
                self?.refreshBandList(reason: "Auto Choose Attendance", scrollToTop: false)
            },
            onOpenBandList: { [weak self] in
                guard let self = self else { return }
                let resumeYear = year
                self.presentedViewController?.dismiss(animated: true) {
                    self.autoChooseWizardResumeYear = resumeYear
                    self.installBackToWizardButtonIfNeeded()
                }
            },
            onOpenBandDetail: { [weak self] bandName in
                self?.presentBandDetailForWizard(bandName: bandName)
            }
        )
        let hosting = UIHostingController(rootView: wizardView)
        hosting.view.backgroundColor = .black
        present(hosting, animated: true)
    }
    
    private func installBackToWizardButtonIfNeeded() {
        if autoChooseWizardResumeYear != nil {
            let item = UIBarButtonItem(
                title: NSLocalizedString("AutoChooseAttendanceBackToWizard", comment: "Back to wizard"),
                style: .plain,
                target: self,
                action: #selector(backToWizardTapped(_:))
            )
            item.tintColor = .white
            navigationItem.leftBarButtonItem = item
        } else {
            installStatsBarButton()
        }
    }
    
    @objc private func backToWizardTapped(_ sender: Any) {
        guard let year = autoChooseWizardResumeYear else { return }
        autoChooseWizardResumeYear = nil
        installStatsBarButton()
        presentAutoChooseAttendanceWizard(eventYear: year)
    }
    
    /// Presents band detail on top of the wizard so the user can set Must/Might/Wont; when dismissed, returns to wizard.
    private func presentBandDetailForWizard(bandName: String) {
        var top: UIViewController = self
        while let presented = top.presentedViewController { top = presented }
        let detailController = DetailHostingController(bandName: bandName, showCustomBackButton: true)
        detailController.overrideUserInterfaceStyle = .dark
        top.present(detailController, animated: true)
    }
    
    @objc private func handleAutoChooseAttendanceOpenBandDetail(_ notification: Notification) {
        guard let bandName = notification.userInfo?["bandName"] as? String else { return }
        DispatchQueue.main.async { [weak self] in
            self?.presentBandDetailForWizard(bandName: bandName)
        }
    }
    
    @objc func refreshDisplayAfterWake2(){
        cleanupEasterEggPlayer()
        
        // CRITICAL FIX: If this is triggered by iCloud data restoration, force refresh
        if MasterViewController.isRefreshingBandList {
            print("🔄 refreshDisplayAfterWake2: Forcing completion of existing refresh to allow iCloud data display")
            MasterViewController.isRefreshingBandList = false
            MasterViewController.refreshBandListSafetyTimer?.invalidate()
            MasterViewController.refreshBandListSafetyTimer = nil
        }
        
        // Simple cache refresh for screen navigation - no background operations needed
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Priority data now handled by SQLitePriorityManager
            
            // Update GUI on main thread after data loading is complete
            DispatchQueue.main.async {
                // Simple cache refresh when detail view updates priority data
                self.refreshBandList(reason: "Detail view priority update - cache refresh")
            }
        }
    }
    
    @objc func refreshDisplayAfterWake(){
        // Move to background to prevent GUI blocking when waking from sleep
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.refreshDataWithBackgroundUpdate(reason: "Display after wake")
        }
    }
    
    @objc func refreshAlerts(){

        // REENTRANCY GUARD:
        // getPointerUrlData(...) can clear data and synchronously trigger observers that call refreshAlerts again.
        // Without this guard we can infinite-recurse on startup and stack-overflow.
        if MasterViewController.isRefreshingAlerts {
            print("🚫 [ALERTS] refreshAlerts: Skipping - refresh already in progress")
            return
        }

        // YEAR CHANGE / CSV DOWNLOAD GUARD:
        // Alert generation iterates schedule data heavily and can contend with year-change imports/refresh.
        // During year changes we prefer correctness and avoiding deadlocks over regenerating alerts.
        if MasterViewController.isYearChangeInProgress {
            print("🚫 [YEAR_CHANGE] refreshAlerts: Skipping alert regeneration - year change in progress")
            return
        }
        if MasterViewController.isCsvDownloadInProgress {
            print("🚫 [YEAR_CHANGE] refreshAlerts: Skipping alert regeneration - CSV download in progress")
            return
        }

        MasterViewController.isRefreshingAlerts = true
        defer { MasterViewController.isRefreshingAlerts = false }
        
        // CURRENT YEAR ONLY:
        // If the user is browsing a past year, skip notification generation.
        let currentYearFromPointer = Int(getPointerUrlData(keyValue: "eventYear")) ?? eventYear
        if eventYear != currentYearFromPointer {
            print("🚫 [ALERTS] refreshAlerts: Skipping alert regeneration - non-current year selected (eventYear=\(eventYear), current=\(currentYearFromPointer))")
            return
        }

        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            print ("FCM alert")
                let localNotication = localNoticationHandler()
                localNotication.addNotifications()
                
            //}
        }
    
    }
    
    // Centralized refresh method for band list
    func refreshBandList(reason: String = "", scrollToTop: Bool = false, isPullToRefresh: Bool = false, skipDataLoading: Bool = false) {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", startTime))] refreshBandList START - reason: '\(reason)'")
        
        // RACE FIX: During year changes, wait for data to be ready before refreshing
        // This prevents showing stale data or causing crashes (edge case protection)
        let isYearChangeReason = reason.lowercased().contains("year change")
        if isYearChangeReason && !MasterViewController.isYearChangeDataReady() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.refreshBandList(reason: reason, scrollToTop: scrollToTop, isPullToRefresh: isPullToRefresh, skipDataLoading: skipDataLoading)
            }
            return
        }
        
        if MasterViewController.isRefreshingBandList {
            print("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] [YEAR_CHANGE_DEBUG] Global: Band list refresh already in progress. Skipping. Reason: \(reason)")
            return
        }
        MasterViewController.isRefreshingBandList = true
        // Start safety timer
        MasterViewController.refreshBandListSafetyTimer?.invalidate()
        MasterViewController.refreshBandListSafetyTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            print("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] [YEAR_CHANGE_DEBUG] Safety timer: Resetting isRefreshingBandList after 10 seconds.")
            MasterViewController.isRefreshingBandList = false
        }
        print("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] [YEAR_CHANGE_DEBUG] Refreshing band list. Reason: \(reason), current year: \(eventYear)")
        // Save the current scroll position
        let previousOffset = self.tableView.contentOffset
        // GUARD: Only proceed if not already reading
        if bandNameHandle.readingBandFile {
            print("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] Band file is already being read. Skipping redundant refresh.");
            MasterViewController.isRefreshingBandList = false
            MasterViewController.refreshBandListSafetyTimer?.invalidate()
            MasterViewController.refreshBandListSafetyTimer = nil
            return
        }
        // PERFORMANCE OPTIMIZATION: Skip data loading if we're just refreshing UI with already-loaded data
        if skipDataLoading {
            print("🚀 refreshBandList: Skipping data loading, using already-loaded cached data")
            // Jump directly to UI updates
            self.performUIRefreshWithLoadedData(reason: reason, scrollToTop: scrollToTop, previousOffset: self.tableView.contentOffset)
            return
        }
        
        // Move all data loading to background thread to avoid GUI blocking
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                MasterViewController.isRefreshingBandList = false
                MasterViewController.refreshBandListSafetyTimer?.invalidate()
                MasterViewController.refreshBandListSafetyTimer = nil
                return
            }
            
            let backgroundStartTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", backgroundStartTime))] refreshBandList background thread START")
            
            // Perform all data loading in background using CacheManager
            cacheManager.loadCachedData()
            
            let backgroundEndTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", backgroundEndTime))] refreshBandList background thread END - total time: \(String(format: "%.3f", (backgroundEndTime - backgroundStartTime) * 1000))ms")
            
            // Continue with UI updates on main thread
            DispatchQueue.main.async {
                let mainThreadStartDate = Date()
                let mainThreadStartTime = CFAbsoluteTimeGetCurrent()
                LaunchTiming.logStart("refreshBandList.completion TOTAL (main thread)", thread: "MAIN")
                print("🕐 [\(String(format: "%.3f", mainThreadStartTime))] refreshBandList main thread START")
                
                self.filterRequestID += 1
                let requestID = self.filterRequestID
                let filterStartTime = CFAbsoluteTimeGetCurrent()
                print("🕐 [\(String(format: "%.3f", filterStartTime))] Starting getFilteredBands")
                getFilteredBands(
                    bandNameHandle: self.bandNameHandle,
                    schedule: self.schedule,
                    dataHandle: self.dataHandle,
                    priorityManager: self.priorityManager,
                    attendedHandle: self.attendedHandle,
                    searchCriteria: self.effectiveSearchBar?.text ?? "",
                    areFiltersActive: self.filterTextNeeded
                ) { [weak self] (filtered: [String]) in
            // CRITICAL FIX: Ensure all UI operations happen on main thread
            DispatchQueue.main.async {
            guard let self = self else {
                MasterViewController.isRefreshingBandList = false
                MasterViewController.refreshBandListSafetyTimer?.invalidate()
                MasterViewController.refreshBandListSafetyTimer = nil
                return
            }
            // Only update UI if this is the latest request
            if requestID != self.filterRequestID {
                MasterViewController.isRefreshingBandList = false
                MasterViewController.refreshBandListSafetyTimer?.invalidate()
                MasterViewController.refreshBandListSafetyTimer = nil
                return
            }
            var bandsResult = filtered
            if eventCount == 0 {
                bandsResult = self.deduplicatePreservingOrder(bandsResult)
            }
            let sortedBy = getSortedBy()
            let sortStart = Date()
            if sortedBy == "name" {
                bandsResult.sort { item1, item2 in
                    let isEvent1 = item1.contains(":") && item1.components(separatedBy: ":").first?.doubleValue != nil
                    let isEvent2 = item2.contains(":") && item2.components(separatedBy: ":").first?.doubleValue != nil
                    
                    // Events always come before band names only
                    if isEvent1 && !isEvent2 {
                        return true
                    } else if !isEvent1 && isEvent2 {
                        return false
                    } else {
                        // Both are same type, sort alphabetically
                        return getNameFromSortable(item1, sortedBy: sortedBy).localizedCaseInsensitiveCompare(getNameFromSortable(item2, sortedBy: sortedBy)) == .orderedAscending
                    }
                }
            } else if sortedBy == "time" {
                bandsResult.sort { item1, item2 in
                    let isEvent1 = item1.contains(":") && item1.components(separatedBy: ":").first?.doubleValue != nil
                    let isEvent2 = item2.contains(":") && item2.components(separatedBy: ":").first?.doubleValue != nil
                    
                    // Events always come before band names only
                    if isEvent1 && !isEvent2 {
                        return true
                    } else if !isEvent1 && isEvent2 {
                        return false
                    } else {
                        // If both are events, sort by time. If both are bands, sort alphabetically (since bands have no time)
                        if isEvent1 && isEvent2 {
                            // Both are events - sort by time
                        return getTimeFromSortable(item1, sortBy: sortedBy) < getTimeFromSortable(item2, sortBy: sortedBy)
                        } else {
                            // Both are band names - sort alphabetically even when sortBy is "time"
                            return getNameFromSortable(item1, sortedBy: "name").localizedCaseInsensitiveCompare(getNameFromSortable(item2, sortedBy: "name")) == .orderedAscending
                        }
                    }
                }
            }
            LaunchTiming.logEnd("refreshBandList.completion SORT", startTime: sortStart, thread: "MAIN")
            print("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] [YEAR_CHANGE_DEBUG] refreshBandList: Loaded \(bandsResult.count) bands for year \(eventYear)")
            
            // CRITICAL FIX: Detect if we loaded data for year 0 with very few bands
            // This indicates the year hasn't been resolved yet - retry after delay
            if eventYear == 0 && bandsResult.count < 10 {
                print("⚠️ [YEAR_0_RETRY] Detected year 0 with only \(bandsResult.count) bands - waiting for year resolution")
                MasterViewController.isRefreshingBandList = false
                MasterViewController.refreshBandListSafetyTimer?.invalidate()
                MasterViewController.refreshBandListSafetyTimer = nil
                
                // Wait 2 seconds for year to be resolved, then retry up to 3 times
                self.retryBandListWithCorrectYear(attempt: 1, maxAttempts: 3, delay: 2.0, reason: reason, scrollToTop: scrollToTop)
                return
            }
            
            // Safely merge new band data with existing data to prevent race conditions
            let mergeStart = Date()
            self.safelyMergeBandData(bandsResult, reason: reason)
            LaunchTiming.logEnd("refreshBandList.completion MERGE (safelyMergeBandData)", startTime: mergeStart, thread: "MAIN")

            // Pre-load priority data for all bands to improve table view performance
            let priorityStartTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", priorityStartTime))] Starting priority data preload")
            self.preloadPriorityData()
            let priorityEndTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", priorityEndTime))] Priority data preload END - time: \(String(format: "%.3f", (priorityEndTime - priorityStartTime) * 1000))ms")
            
            // Note: Table view reload is now handled in safelyMergeBandData to ensure atomicity
            // Remove the duplicate table view reload logic
            let tableReloadStartTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", tableReloadStartTime))] Table view reload handled by safelyMergeBandData")

            let updateCountStart = Date()
            self.updateCountLable()
            LaunchTiming.logEnd("refreshBandList.completion updateCountLable", startTime: updateCountStart, thread: "MAIN")
            let updateCountEndTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", updateCountEndTime))] updateCountLable END - time: \(String(format: "%.3f", (updateCountEndTime - tableReloadStartTime) * 1000))ms")
            
            // Move attendedHandle.getCachedData() to background using CacheManager
            self.cacheManager.loadAttendedDataInBackground()
            
            // Auto-select first band for large display (split view) after data is loaded (only once and only on initial load)
                if self.isSplitViewCapable() && !self.bands.isEmpty && !self.hasAutoSelectedForIPad && reason.contains("Initial") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.autoSelectFirstValidBandForIPad()
                }
            }
                if self.shouldSnapToTopAfterRefresh {
                    self.shouldSnapToTopAfterRefresh = false
                self.tableView.setContentOffset(.zero, animated: false)
                print("Pull-to-refresh: Snapped to top of list")
            } else if scrollToTop, self.bands.count > 0 {
                let topIndex = IndexPath(row: 0, section: 0)
                self.tableView.scrollToRow(at: topIndex, at: .top, animated: false)
            } else {
                self.tableView.setContentOffset(previousOffset, animated: false)
            }
            // Always show separators when we have mixed content, per-cell logic will hide them for band names
            if eventCount == 0 {
                self.tableView.separatorStyle = .none
            } else {
                self.tableView.separatorStyle = .singleLine
            }
            MasterViewController.isRefreshingBandList = false
            MasterViewController.refreshBandListSafetyTimer?.invalidate()
            MasterViewController.refreshBandListSafetyTimer = nil
            
            let filterEndTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", filterEndTime))] getFilteredBands END - time: \(String(format: "%.3f", (filterEndTime - filterStartTime) * 1000))ms")
            
            let mainThreadEndTime = CFAbsoluteTimeGetCurrent()
            LaunchTiming.logEnd("refreshBandList.completion TOTAL (main thread)", startTime: mainThreadStartDate, thread: "MAIN")
            print("🕐 [\(String(format: "%.3f", mainThreadEndTime))] refreshBandList main thread END - total time: \(String(format: "%.3f", (mainThreadEndTime - mainThreadStartTime) * 1000))ms")
                } // End of DispatchQueue.main.async for UI operations
            } // End of getFilteredBands completion handler
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", endTime))] refreshBandList END - total time: \(String(format: "%.3f", (endTime - startTime) * 1000))ms")
    }
    
    func ensureCorrectSorting(){
        if (eventCount == 0){
            print("Schedule is empty, hide separators")
            mainTableView.separatorStyle = .none
        } else {
            print("Schedule present, show separators (per-cell logic will hide for band names)")
            mainTableView.separatorStyle = .singleLine
        }
        refreshBandList(reason: "Sorting changed")
    }
    
    func quickRefresh_Pre(){
        writeFiltersFile()
        if (isPerformingQuickLoad == false){
            isPerformingQuickLoad = true
            // Move data loading to background to avoid GUI blocking
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                // Priority data now handled by SQLitePriorityManager
                
                DispatchQueue.main.async {
                    print("Calling refreshBandList from quickRefresh_Pre with reason: Quick refresh")
                    self.refreshBandList(reason: "Quick refresh")
                    self.isPerformingQuickLoad = false
                }
            }
        }
    }
    
    @objc func quickRefresh(){
        quickRefresh_Pre()
        // self.tableView.reloadData() is now handled in refreshBandList
    }
    
    @objc func refreshGUI(){
        self.tableView.reloadData()
    }
    
    /// Lightweight refresh that only updates the band list UI without triggering data downloads or heavy processing.
    /// Used for priority changes that only need UI updates, not full data reloads.
    func refreshBandListOnly(reason: String) {
        print("Lightweight refresh (\(reason)): Updating UI only")
        DispatchQueue.main.async { [weak self] in
            self?.refreshBandList(reason: reason)
        }
    }
    
    /// Retries band list refresh after detecting year 0 with minimal bands
    /// Waits for eventYear to be properly resolved before retrying
    private func retryBandListWithCorrectYear(attempt: Int, maxAttempts: Int, delay: TimeInterval, reason: String, scrollToTop: Bool) {
        print("🔄 [YEAR_0_RETRY] Attempt \(attempt)/\(maxAttempts) - waiting \(delay)s for year resolution")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            
            // Check if year has been resolved
            if eventYear != 0 {
                print("✅ [YEAR_0_RETRY] Year resolved to \(eventYear) - retrying band list refresh")
                self.refreshBandList(reason: "\(reason) [year 0 retry - resolved to \(eventYear)]", scrollToTop: scrollToTop)
            } else if attempt < maxAttempts {
                print("⚠️ [YEAR_0_RETRY] Year still 0 after \(delay)s - retrying (attempt \(attempt + 1)/\(maxAttempts))")
                self.retryBandListWithCorrectYear(attempt: attempt + 1, maxAttempts: maxAttempts, delay: delay, reason: reason, scrollToTop: scrollToTop)
            } else {
                print("❌ [YEAR_0_RETRY] Year still 0 after \(maxAttempts) attempts - giving up")
                // Show the data we have (year 0 data) rather than nothing
                self.refreshBandList(reason: "\(reason) [year 0 retry failed]", scrollToTop: scrollToTop)
            }
        }
    }

    @objc func OnOrientationChange(){
        // DEADLOCK FIX: Never block main thread - use async delay instead
        print("🔓 DEADLOCK FIX: Orientation change detected - scheduling refresh with non-blocking delay")
        
        // CRITICAL: Update DeviceSizeManager on orientation change
        // This ensures device size classification is recalculated (important for foldable devices)
        DeviceSizeManager.shared.updateDeviceSize()
        
        // Check if detail view is currently presented - if so, don't handle orientation change
        // Detail view should stay in detail view regardless of orientation
        // Check both navigation controller and landscape view controller for presented detail views
        if let topVC = navigationController?.topViewController, topVC is DetailHostingController {
            print("🔄 [ORIENTATION] Detail view is showing - skipping orientation handling in main view")
            return
        }
        
        // Also check if detail view is presented from landscape view controller
        if let landscapeVC = landscapeScheduleViewController,
           landscapeVC.presentedViewController != nil {
            print("🔄 [ORIENTATION] Detail view is presented from landscape view - skipping orientation handling")
            return
        }
        
        // CRITICAL FIX: For iPhone, check orientation multiple times with increasing delays
        // This ensures we catch the portrait rotation even if view bounds haven't updated yet
        if !isSplitViewCapable() && isShowingLandscapeSchedule {
            // Check immediately
            checkAndDismissIfPortrait(attempt: 1, maxAttempts: 3)
        }
        
        // Check if we should show landscape schedule view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.checkOrientationAndShowLandscapeIfNeeded()
            
            // Refresh band list if not showing landscape
            if !self.isShowingLandscapeSchedule {
                print("Calling refreshBandList from OnOrientationChange with reason: Orientation change")
                self.refreshBandList(reason: "Orientation change")
            }
        }
    }
    
    /// Helper method to check if iPhone is in portrait and dismiss calendar view
    /// Uses multiple attempts with increasing delays to catch orientation changes
    private func checkAndDismissIfPortrait(attempt: Int, maxAttempts: Int) {
        guard !isSplitViewCapable() && isShowingLandscapeSchedule else {
            return
        }
        
        // CRITICAL FIX: If a detail screen is currently presented, don't dismiss on orientation change
        // Let the detail screen handle its own orientation changes
        if let landscapeVC = landscapeScheduleViewController,
           landscapeVC.presentedViewController != nil {
            print("🔄 [ORIENTATION] Detail screen is presented - skipping portrait dismissal check")
            return
        }
        
        // CRITICAL FIX: When landscape view controller is showing, view.window might be the landscape view's window
        // Use the main window (UIApplication.shared.windows or scene) instead, or prioritize device/statusBar orientation
        let mainWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? view.window
        
        let windowBounds = mainWindow?.bounds ?? view.bounds
        let windowBoundsLandscape = windowBounds.width > windowBounds.height
        let viewBoundsLandscape = view.bounds.width > view.bounds.height
        let statusBarLandscape = UIApplication.shared.statusBarOrientation.isLandscape
        let deviceOrientationLandscape = UIDevice.current.orientation.isLandscape
        
        // CRITICAL: Prioritize device orientation and status bar over window bounds when they disagree
        // If device/statusBar say portrait but window says landscape, trust device/statusBar (more reliable)
        let isLandscape: Bool
        if !statusBarLandscape && !deviceOrientationLandscape {
            // Both device and statusBar say portrait - trust them, ignore window bounds
            isLandscape = false
        } else if statusBarLandscape || deviceOrientationLandscape {
            // Device or statusBar say landscape - trust them
            isLandscape = true
        } else {
            // Fallback to window bounds if device/statusBar are unknown
            isLandscape = windowBoundsLandscape || viewBoundsLandscape
        }
        
        print("🚫 [ORIENTATION] Portrait check attempt \(attempt)/\(maxAttempts) - windowBounds: \(windowBoundsLandscape) (w:\(windowBounds.width) h:\(windowBounds.height)), viewBounds: \(viewBoundsLandscape), statusBar: \(statusBarLandscape), device: \(deviceOrientationLandscape), isLandscape: \(isLandscape)")
        
        if !isLandscape {
            print("🚫 [ORIENTATION] iPhone detected in portrait - dismissing calendar view immediately")
            dismissLandscapeScheduleView()
            return
        }
        
        // If still showing as landscape but we haven't exhausted attempts, check again with delay
        if attempt < maxAttempts {
            let delay = Double(attempt) * 0.2 // 0.2s, 0.4s, 0.6s
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.checkAndDismissIfPortrait(attempt: attempt + 1, maxAttempts: maxAttempts)
            }
        }
    }
    
    /// Call after a filter change (e.g. Hide Expired Events) so list vs calendar is re-evaluated in landscape.
    func recheckLandscapeScheduleAfterFilterChange() {
        checkOrientationAndShowLandscapeIfNeeded()
    }
    
    private func checkOrientationAndShowLandscapeIfNeeded() {
        print("🔄 [ORIENTATION_CHECK] checkOrientationAndShowLandscapeIfNeeded called")
        print("🔄 [ORIENTATION_CHECK] filterMenuButton.isHidden: \(filterMenuButton?.isHidden ?? true)")
        print("🔄 [ORIENTATION_CHECK] bandSearch.isHidden: \(bandSearch?.isHidden ?? true)")
        print("🔄 [ORIENTATION_CHECK] view.window: \(view.window != nil ? "exists" : "nil")")
        print("🔄 [ORIENTATION_CHECK] isShowingLandscapeSchedule: \(isShowingLandscapeSchedule)")
        
        // CRITICAL FIX: Check orientation FIRST before any other logic
        // Phone: Use orientation-based switching
        // Get main window (not landscape view controller's window)
        let mainWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? view.window
        
        let windowBounds = mainWindow?.bounds ?? view.bounds
        let windowBoundsLandscape = windowBounds.width > windowBounds.height
        let viewBoundsLandscape = view.bounds.width > view.bounds.height
        let statusBarLandscape = UIApplication.shared.statusBarOrientation.isLandscape
        let deviceOrientationLandscape = UIDevice.current.orientation.isLandscape
        
        // CRITICAL: Prioritize device orientation and status bar over window bounds when they disagree
        // If device/statusBar say portrait but window says landscape, trust device/statusBar (more reliable)
        let isLandscape: Bool
        if !statusBarLandscape && !deviceOrientationLandscape {
            // Both device and statusBar say portrait - trust them, ignore window bounds
            isLandscape = false
        } else if statusBarLandscape || deviceOrientationLandscape {
            // Device or statusBar say landscape - trust them
            isLandscape = true
        } else {
            // Fallback to window bounds if device/statusBar are unknown
            isLandscape = windowBoundsLandscape || viewBoundsLandscape
        }
        
        // CRITICAL FIX: If a detail screen is currently presented from the landscape view,
        // don't dismiss the landscape view on orientation change. Let the detail screen
        // handle its own orientation changes. The landscape view will be dismissed when
        // the user exits the detail screen (handled in detail screen dismissal).
        // This check MUST happen FIRST, before portrait dismissal check, to prevent dismissing detail view
        if let landscapeVC = landscapeScheduleViewController,
           landscapeVC.presentedViewController != nil {
            print("🔄 [LANDSCAPE_SCHEDULE] Detail screen is presented - skipping orientation change handling")
            print("🔄 [LANDSCAPE_SCHEDULE] Detail screen will handle its own orientation, landscape view stays")
            return
        }
        
        // CRITICAL FIX: iPhone in portrait mode should NEVER show calendar mode
        // This check happens AFTER detail view check, so detail views aren't dismissed on orientation change
        if !isSplitViewCapable() {
            // Log detailed orientation info for debugging
            print("🚫 [LANDSCAPE_SCHEDULE] Orientation check - windowBounds: \(windowBoundsLandscape) (w:\(windowBounds.width) h:\(windowBounds.height)), viewBounds: \(viewBoundsLandscape) (w:\(view.bounds.width) h:\(view.bounds.height)), statusBar: \(statusBarLandscape), device: \(deviceOrientationLandscape), isLandscape: \(isLandscape), isShowingCalendar: \(isShowingLandscapeSchedule)")
            
            if !isLandscape {
                // iPhone is in portrait - MUST dismiss calendar view immediately
                // BUT only if no detail view is presented (checked above)
                if isShowingLandscapeSchedule {
                    print("🚫 [LANDSCAPE_SCHEDULE] iPhone rotated to portrait - immediately dismissing calendar view (portrait never shows calendar)")
                    print("🚫 [ORIENTATION_CHECK] Before dismissLandscapeScheduleView - filterMenuButton.isHidden: \(filterMenuButton?.isHidden ?? true)")
                    print("🚫 [ORIENTATION_CHECK] Before dismissLandscapeScheduleView - bandSearch.isHidden: \(bandSearch?.isHidden ?? true)")
                    dismissLandscapeScheduleView()
                    print("🚫 [ORIENTATION_CHECK] After dismissLandscapeScheduleView - filterMenuButton.isHidden: \(filterMenuButton?.isHidden ?? true)")
                    print("🚫 [ORIENTATION_CHECK] After dismissLandscapeScheduleView - bandSearch.isHidden: \(bandSearch?.isHidden ?? true)")
                }
                return // Exit early - portrait mode never shows calendar on iPhone
            }
        }
        
        let isScheduleView = getShowScheduleView()
        
        // iPad: Use manual toggle instead of orientation
        if isSplitViewCapable() {
            print("📱 [IPAD_TOGGLE] Schedule View: \(isScheduleView), Manual Calendar View: \(isManualCalendarView)")
            // iPad behavior is controlled by the manual toggle button, not orientation
            // Do nothing here - the toggle button handles presentation
            return
        }
        
        // CRITICAL FIX: If detail view is presented from main navigation controller,
        // don't handle orientation changes - detail view should stay visible
        if let topVC = navigationController?.topViewController, topVC is DetailHostingController {
            print("🔄 [ORIENTATION] Detail view is showing in navigation stack - skipping orientation handling")
            return
        }
        
        // Check if bands array contains event entries (format: "timeIndex:bandName")
        // When all events are expired, bands array contains only band names (no timeIndex prefix)
        let hasEventEntries = self.bands.contains { item in
            item.contains(":") && item.components(separatedBy: ":").first?.doubleValue != nil
        }
        
        print("🔄 [LANDSCAPE_SCHEDULE] Check orientation - Landscape: \(isLandscape), Schedule View: \(isScheduleView), Has Event Entries: \(hasEventEntries), Bands Count: \(self.bands.count)")
        
        if isLandscape && isScheduleView && hasEventEntries {
            // Always update current viewing day from topmost visible cell before showing calendar
            // This ensures calendar shows the same day as the first visible entry in the list
            updateCurrentViewingDayFromVisibleCells()
            
            // Show landscape schedule view
            presentLandscapeScheduleView()
        } else {
            // Hide landscape schedule view if showing
            dismissLandscapeScheduleView()
        }
    }
    
    private func updateCurrentViewingDayFromVisibleCells() {
        // Delegate to UIManager
        uiManager.updateCurrentViewingDayFromVisibleCells(
            tableView: tableView,
            bands: bands,
            currentViewingDay: &currentViewingDay
        )
    }
    
    /// Scrolls the list view to the first row of the given day (e.g. "Day 3").
    /// Called when switching from calendar to list so the list shows the same day the user was viewing.
    private func scrollListToDayIfNeeded(day: String?) {
        guard let day = day, !bands.isEmpty else { return }
        guard let row = uiManager.firstRowIndex(forDay: day, bands: bands) else {
            print("🔄 [LANDSCAPE_SCHEDULE] No list row found for day: \(day)")
            return
        }
        let indexPath = IndexPath(row: row, section: 0)
        guard row < tableView.numberOfRows(inSection: 0) else { return }
        
        // CRITICAL: Set currentViewingDay BEFORE scrolling so it's preserved
        // This prevents updateCurrentViewingDayFromVisibleCells from overwriting it
        // with an incorrect value if called before scroll completes
        currentViewingDay = day
        lastProgrammaticScrollTime = Date()
        print("🔄 [LANDSCAPE_SCHEDULE] Set currentViewingDay to '\(day)' before scrolling to row \(row)")
        
        tableView.scrollToRow(at: indexPath, at: .top, animated: false)
        print("🔄 [LANDSCAPE_SCHEDULE] List scrolled to day \(day) (row \(row))")
        
        // After scroll completes, verify the visible day matches what we scrolled to
        // Use a delay to ensure scroll animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            // Clear the flag after scroll animation completes
            self.lastProgrammaticScrollTime = nil
            // Only update if currentViewingDay was somehow cleared
            // Otherwise trust the value we set before scrolling
            if self.currentViewingDay != day {
                print("⚠️ [LANDSCAPE_SCHEDULE] currentViewingDay was changed after scroll, updating from visible cells")
                self.updateCurrentViewingDayFromVisibleCells()
            } else {
                print("✅ [LANDSCAPE_SCHEDULE] Scroll completed, currentViewingDay still matches scrolled day '\(day)'")
            }
        }
    }
    
    // MARK: - iPad Split View Detection
    
    private func isSplitViewCapable() -> Bool {
        // Use centralized DeviceSizeManager for consistent device size classification
        // This recalculates on orientation changes and device folds
        return DeviceSizeManager.isLargeDisplay()
    }
    
    private func setupViewToggleButton() {
        // Only show on iPad
        guard isSplitViewCapable() else {
            viewToggleButton = nil
            updateNavigationBar()
            return
        }
        
        // Check same conditions as iPhone landscape mode availability
        let isScheduleView = getShowScheduleView()
        let hideExpiredEvents = getHideExpireScheduleData()
        
        // Determine if schedule data would be available by checking for event entries in bands array
        // Event entries have format "timeIndex:bandName", band-only entries are just "bandName"
        let hasEventEntries = self.bands.contains { item in
            item.contains(":") && item.components(separatedBy: ":").first?.doubleValue != nil
        }
        
        let scheduleDataAvailable: Bool
        if hideExpiredEvents {
            // If hiding expired events, only available if bands array contains event entries
            // When all events are expired, bands array contains only band names (no timeIndex prefix)
            scheduleDataAvailable = hasEventEntries
            print("📱 [IPAD_TOGGLE] hideExpiredEvents=true, hasEventEntries=\(hasEventEntries), bands.count=\(self.bands.count), available=\(scheduleDataAvailable)")
        } else {
            // If showing all events, check if we have event entries
            scheduleDataAvailable = hasEventEntries
            print("📱 [IPAD_TOGGLE] hideExpiredEvents=false, hasEventEntries=\(hasEventEntries), bands.count=\(self.bands.count), available=\(scheduleDataAvailable)")
        }
        
        // Show button only when:
        // 1. We're in schedule view mode
        // 2. Schedule data would actually be available
        let shouldShowButton = isScheduleView && scheduleDataAvailable
        
        print("📱 [IPAD_TOGGLE] isScheduleView=\(isScheduleView), scheduleDataAvailable=\(scheduleDataAvailable), shouldShowButton=\(shouldShowButton)")
        
        guard shouldShowButton else {
            // Hide button if landscape wouldn't be available
            if viewToggleButton != nil {
                viewToggleButton = nil
                updateNavigationBar()
                print("📱 [IPAD_TOGGLE] Button hidden - landscape not available")
            }
            return
        }
        
        // Create or update toggle button: show icon for the *other* view (based on what's on screen)
        let iconName = isShowingLandscapeSchedule ? "list.bullet" : "calendar"
        
        if let existingButton = viewToggleButton {
            // Update existing button icon
            existingButton.image = UIImage(systemName: iconName)
            print("📱 [IPAD_TOGGLE] Button icon updated to: \(iconName)")
        } else {
            // Create new button
            let button = UIBarButtonItem(
                image: UIImage(systemName: iconName),
                style: .plain,
                target: self,
                action: #selector(toggleViewTapped)
            )
            button.tintColor = .white
            viewToggleButton = button
            updateNavigationBar()
            print("📱 [IPAD_TOGGLE] View toggle button created with icon: \(iconName)")
        }
    }
    
    @objc private func toggleViewTapped() {
        isManualCalendarView.toggle()
        print("📱 [IPAD_TOGGLE] Manual toggle to: \(isManualCalendarView ? "Calendar" : "List")")
        
        if isManualCalendarView {
            // Switch to calendar view
            updateCurrentViewingDayFromVisibleCells()
            presentLandscapeScheduleView()
            // Update button to list icon
            viewToggleButton?.image = UIImage(systemName: "list.bullet")
        } else {
            // Switch to list view (scroll to current day happens in dismissLandscapeViewController)
            dismissLandscapeScheduleView()
            // Update button to calendar icon
            viewToggleButton?.image = UIImage(systemName: "calendar")
        }
    }
    
    private func updateNavigationBar() {
        var rightButtons = navigationItem.rightBarButtonItems ?? []
        
        // Remove any existing toggle button first
        rightButtons.removeAll { item in
            item.action == #selector(toggleViewTapped)
        }
        
        // Add the toggle button if it exists (otherwise just leave it removed)
        if let toggleButton = viewToggleButton {
            // Add toggle button at the beginning (leftmost position)
            rightButtons.insert(toggleButton, at: 0)
            print("📱 [IPAD_TOGGLE] Button added to navigation bar")
        } else {
            print("📱 [IPAD_TOGGLE] Button removed from navigation bar")
        }
        
        navigationItem.rightBarButtonItems = rightButtons
    }
    
    // MARK: - Landscape Schedule View Management
    
    private func presentLandscapeScheduleView() {
        // Don't present if already showing
        guard !isShowingLandscapeSchedule else {
            print("🔄 [LANDSCAPE_SCHEDULE] Already showing landscape schedule view")
            return
        }
        
        // CRITICAL FIX: iPhone in portrait mode should NEVER show calendar mode
        // Only allow calendar mode on iPhone when in landscape, or on iPad (master/detail)
        if !isSplitViewCapable() {
            // iPhone: Check orientation - must be landscape to show calendar
            // Get main window (not landscape view controller's window)
            let mainWindow = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? view.window
            
            let windowBounds = mainWindow?.bounds ?? view.bounds
            let windowBoundsLandscape = windowBounds.width > windowBounds.height
            let viewBoundsLandscape = view.bounds.width > view.bounds.height
            let statusBarLandscape = UIApplication.shared.statusBarOrientation.isLandscape
            let deviceOrientationLandscape = UIDevice.current.orientation.isLandscape
            
            // CRITICAL: Prioritize device orientation and status bar over window bounds
            let isLandscape: Bool
            if !statusBarLandscape && !deviceOrientationLandscape {
                // Both device and statusBar say portrait - trust them
                isLandscape = false
            } else if statusBarLandscape || deviceOrientationLandscape {
                // Device or statusBar say landscape - trust them
                isLandscape = true
            } else {
                // Fallback to window bounds
                isLandscape = windowBoundsLandscape || viewBoundsLandscape
            }
            
            if !isLandscape {
                print("🚫 [LANDSCAPE_SCHEDULE] iPhone in portrait mode - calendar mode is not allowed")
                return
            }
        }
        
        print("🔄 [LANDSCAPE_SCHEDULE] Presenting landscape schedule view")
        
        // Check if hiding expired events
        let hideExpiredEvents = getHideExpireScheduleData()
        print("🔄 [LANDSCAPE_SCHEDULE] hideExpiredEvents: \(hideExpiredEvents)")
        
        // If hiding expired events and NO bands are visible in portrait, don't show landscape
        // Use the existing bands array which is already filtered
        if hideExpiredEvents && self.bands.isEmpty {
            print("⚠️ [LANDSCAPE_SCHEDULE] No bands in portrait view - staying in portrait view")
            return
        }
        
        // CRITICAL: Update current viewing day from topmost visible cell before presenting calendar
        // BUT: If we just scrolled programmatically (within last 0.5 seconds), trust the day we scrolled to
        // instead of re-checking visible cells (which may not have updated yet due to scroll animation)
        let timeSinceScroll = lastProgrammaticScrollTime.map { Date().timeIntervalSince($0) } ?? 1.0
        
        if timeSinceScroll < 0.5, let scrolledDay = currentViewingDay {
            // We just scrolled programmatically - trust the day we scrolled to
            print("🔄 [LANDSCAPE_SCHEDULE] Recent programmatic scroll detected (\(String(format: "%.2f", timeSinceScroll))s ago), using scrolled day: '\(scrolledDay)'")
        } else {
            // No recent scroll, or currentViewingDay is nil - update from visible cells
            if currentViewingDay == nil {
                print("🔄 [LANDSCAPE_SCHEDULE] currentViewingDay is nil, updating from visible cells")
            } else {
                print("🔄 [LANDSCAPE_SCHEDULE] No recent scroll, updating from visible cells (current: '\(currentViewingDay!)')")
            }
            updateCurrentViewingDayFromVisibleCells()
        }
        
        // Use the tracked current viewing day
        let initialDay = currentViewingDay
        if let day = initialDay {
            print("🔄 [LANDSCAPE_SCHEDULE] Starting on tracked day: '\(day)'")
        } else {
            print("🔄 [LANDSCAPE_SCHEDULE] No tracked day found, will start on first day")
        }
        
        // Pass the same dependencies used by the main view for filtering
        let landscapeView = LandscapeScheduleView(
            priorityManager: priorityManager,
            attendedHandle: attendedHandle,
            initialDay: initialDay,
            hideExpiredEvents: hideExpiredEvents,
            isSplitViewCapable: isSplitViewCapable(),
            onDismissRequested: { [weak self] currentDay in
                // iPad: User wants to return to list view; use calendar's current day so list shows same day
                if let day = currentDay {
                    self?.currentViewingDay = day
                    print("🔄 [LANDSCAPE_SCHEDULE] Calendar → list: will show day \(day)")
                }
                self?.isManualCalendarView = false
                self?.dismissLandscapeScheduleView()
            },
            onCurrentDayChanged: { [weak self] day in
                // Keep currentViewingDay in sync when user changes day in calendar (swipe/buttons)
                self?.currentViewingDay = day
            },
            onShowMessage: { [weak self] message in
                self?.showToastOnTopmostVC(message: message)
            },
            onBandTapped: { [weak self] bandName, currentDay in
                // Handle band tap - present detail directly from landscape view
                guard let self = self else { return }
                
                print("🔄 [LANDSCAPE_SCHEDULE] Band tapped: \(bandName) on day: \(currentDay ?? "unknown")")
                
                // Check if this is a combined event (internal delimiter, not "/")
                if isCombinedEventBandName(bandName) {
                    if let individualBands = combinedEventsMap[bandName], individualBands.count == 2 {
                        // Prompt user to choose which band
                        self.promptForBandSelectionLandscape(combinedBandName: bandName, bands: individualBands, currentDay: currentDay)
                        return
                    }
                }
                
                // Save the current day for when we return
                if let day = currentDay {
                    self.currentViewingDay = day
                    print("🔄 [LANDSCAPE_SCHEDULE] Saved current viewing day: \(day)")
                }
                
                // Save scroll position
                self.savedScrollPosition = self.tableView.contentOffset
                print("🔄 [LANDSCAPE_SCHEDULE] Saved scroll position: \(self.savedScrollPosition!)")
                
                // Find the band index
                let bandIndex: Int
                if let index = self.bands.firstIndex(where: { band in
                    getNameFromSortable(band, sortedBy: getSortedBy()) == bandName
                }) {
                    bandIndex = index
                } else {
                    print("⚠️ [LANDSCAPE_SCHEDULE] Band not in filtered list, using index 0")
                    bandIndex = 0
                }
                
                // Set up for detail navigation (using globals from Constants.swift)
                bandSelected = bandName
                bandListIndexCache = bandIndex
                currentBandList = self.bands
                
                // Create and present detail view from the stored landscape controller with custom back button
                let detailController = DetailHostingController(bandName: bandName, showCustomBackButton: true)
                
                // CRITICAL FIX: For large display (master/detail), make the detail popup larger to accommodate band name and logo
                if isSplitViewCapable() {
                    // Use formSheet for a larger modal that doesn't cover the entire screen
                    detailController.modalPresentationStyle = .formSheet
                    // Set larger preferred content size to accommodate band name and logo
                    detailController.preferredContentSize = CGSize(width: 800, height: 900)
                }
                
                // Present from the stored landscape view controller
                self.landscapeScheduleViewController?.present(detailController, animated: true) {
                    print("✅ [LANDSCAPE_SCHEDULE] Detail view presented")
                }
            },
            onLongPress: { [weak self] bandName, location, startTime, eventType, day in
                // Handle long press - show priority/attendance menu
                guard let self = self else { return }
                
                // Combined event: show band choice first, then long-press menu for selected band
                if isCombinedEventBandName(bandName) {
                    let individualBands = combinedEventsMap[bandName] ?? combinedEventBandParts(bandName)
                    if let bands = individualBands, bands.count == 2 {
                        self.promptForBandSelectionLandscapeForLongPress(
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
                
                // Single event: show long-press menu directly
                let cellDataText = "\(bandName);\(location);\(eventType);\(startTime)"
                let presentingViewController = self.landscapeScheduleViewController ?? self
                self.showLongPressMenu(bandName: bandName, cellDataText: cellDataText, indexPath: IndexPath(row: 0, section: 0), presentingFrom: presentingViewController)
            }
        )
        
        let hostingController = UIHostingController(rootView: landscapeView)
        hostingController.modalPresentationStyle = .fullScreen
        
        landscapeScheduleViewController = hostingController
        isShowingLandscapeSchedule = true
        
        present(hostingController, animated: true) {
            print("✅ [LANDSCAPE_SCHEDULE] Landscape schedule view presented")
        }
    }
    
    private func refreshLandscapeScheduleViewIfNeeded(for bandName: String? = nil) {
        // Refresh landscape schedule view if it's currently showing
        guard isShowingLandscapeSchedule else {
            return
        }
        
        print("🔄 [LANDSCAPE_SCHEDULE] Posting refresh notification for band: \(bandName ?? "all")")
        
        // Use NotificationCenter to trigger refresh in the SwiftUI view
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
    
    private func dismissLandscapeScheduleView(completion: (() -> Void)? = nil) {
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
        
        // CRITICAL: If a SwiftUI sheet (filter menu) is presented from the landscape view,
        // dismiss it first before dismissing the landscape view controller
        // This prevents the sheet from interfering with the portrait view
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
            guard let self = self else { return }
            
            // Small delay to ensure landscape view is fully dismissed before restoring UI
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self else { return }
                
                // CRITICAL: Restore UI elements BEFORE checking orientation
                // This ensures elements are visible even if orientation check triggers something
                self.filterMenuButton?.isHidden = false
                self.bandSearch?.isHidden = false
                self.filterMenuButton?.alpha = 1.0
                self.bandSearch?.alpha = 1.0
                self.mainToolBar?.isHidden = false
                self.mainToolBar?.alpha = 1.0
                self.view.isHidden = false
                self.view.alpha = 1.0
                
                // Ensure parent views are visible
                if let filterSuperview = self.filterMenuButton?.superview {
                    filterSuperview.isHidden = false
                    filterSuperview.alpha = 1.0
                }
                if let searchSuperview = self.bandSearch?.superview {
                    searchSuperview.isHidden = false
                    searchSuperview.alpha = 1.0
                }
                
                // Force view hierarchy update
                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()
                
                // CRITICAL: Force table view header to refresh to ensure toolbar is visible
                // This ensures the header (which contains the toolbar with buttons) is recreated
                DispatchQueue.main.async {
                    self.tableView.reloadSections(IndexSet(integer: 0), with: .none)
                    
                    // KISS: After table reload, ensure titleView is still visible
                    // Table reload shouldn't affect navigation bar, but be safe
                    self.navigationItem.title = nil
                    self.updateCountLable()
                }
                
                // After landscape view is dismissed, check orientation and show appropriate view
                self.checkOrientationAndShowLandscapeIfNeeded()
                completion?()
            }
        }
    }
    
    private func dismissLandscapeViewController(viewController: UIViewController, completion: (() -> Void)?) {
        let dayToShow = currentViewingDay  // Capture before dismiss so list can scroll to same day
        viewController.dismiss(animated: true) { [weak self] in
            self?.landscapeScheduleViewController = nil
            self?.isShowingLandscapeSchedule = false
            
            // Reset iPad manual toggle state and button icon
            if self?.isSplitViewCapable() == true {
                self?.isManualCalendarView = false
                self?.viewToggleButton?.image = UIImage(systemName: "calendar")
            }
            
            // Calendar → list: show the day the user was viewing in the calendar
            // Scroll to first entry of that day after a brief delay to ensure table view is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                self.scrollListToDayIfNeeded(day: dayToShow)
                
                self.filterMenuButton?.isHidden = false
                self.bandSearch?.isHidden = false
                self.filterMenuButton?.alpha = 1.0
                self.bandSearch?.alpha = 1.0
                self.mainToolBar?.isHidden = false
                self.mainToolBar?.alpha = 1.0
                
                // Ensure parent views are also visible
                if let filterBar = self.filterMenuButton?.superview {
                    filterBar.isHidden = false
                    filterBar.alpha = 1.0
                }
                if let searchBar = self.bandSearch?.superview {
                    searchBar.isHidden = false
                    searchBar.alpha = 1.0
                }
                
                // Ensure the view itself is visible
                self.view.isHidden = false
                self.view.alpha = 1.0
                
                // Force view to update layout
                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()
            }
            completion?()
        }
    }
    
    /// Centralized method that performs the same logic as pull-to-refresh
    /// Can be called from various scenarios: pull-to-refresh, returning from preferences, app foreground, etc.
    /// 
    /// Order of operations:
    /// 1. Refresh from cache
    /// 2. Confirm internet access
    /// 3. Start background process to:
    ///    - Clear cache
    ///    - Refresh all data (band names, schedule, descriptionMap) from URLs
    ///    - Once all data is loaded, refresh the GUI
    func performFullDataRefresh(reason: String, shouldScrollToTop: Bool = false, endRefreshControl: Bool = false) {
        if shouldScrollToTop {
            shouldSnapToTopAfterRefresh = true
        }
        
        // Delegate to ViewModel
        viewModel.performFullDataRefresh(
            reason: reason,
            onCacheRefresh: { [weak self] in
                guard let self = self else { return }
                self.refreshBandList(reason: "\(reason) - cache refresh")
            },
            onNetworkTest: { [weak self] hasNetwork in
                guard let self = self else { return }
                if !hasNetwork {
                    if endRefreshControl {
                        self.refreshControl?.endRefreshing()
                    }
                }
            },
            onBackgroundRefresh: { [weak self] in
                guard let self = self else { return }
                // STEP 3: Start background process
                self.performBackgroundDataRefresh(reason: reason, endRefreshControl: endRefreshControl, shouldScrollToTop: shouldScrollToTop)
            }
        )
    }
    
    /// Background data refresh that follows the network-test-first pattern
    /// Shows cached data immediately, tests network, then does fresh data collection if network is good
    func performBackgroundOnlyDataRefresh(reason: String) {
        // Delegate to ViewModel
        viewModel.performBackgroundOnlyDataRefresh(
            reason: reason,
            onCacheRefresh: { [weak self] in
                guard let self = self else { return }
                self.refreshBandList(reason: "\(reason) - cached display")
            },
            onNetworkTest: { [weak self] networkIsGood in
                guard let self = self else { return }
                if networkIsGood {
                    self.performFreshDataCollection(reason: reason)
                }
            },
            onFreshDataCollection: { [weak self] in
                guard let self = self else { return }
                self.performFreshDataCollection(reason: reason)
            }
        )
    }
    
    @objc func pullTorefreshData(){
        checkForEasterEgg()
        print ("🔄 PULL-TO-REFRESH: Starting pull-to-refresh with robust network testing")
        
        // Use the robust network-test-first pattern for pull-to-refresh
        performPullToRefreshWithRobustNetworkTest()
    }
    
    /// Pull-to-refresh using the robust network testing pattern
    /// Shows busy indicator for 2 seconds, then continues background updates
    func performPullToRefreshWithRobustNetworkTest() {
        print("🔄 PULL-TO-REFRESH: Starting with 2-second busy indicator")
        
        // STEP 1: Check if we're in "waiting for data" state
        let bandCount = bandNameHandle.getBandNames().count
        let eventCount = schedule.schedulingData.count
        let hasData = bandCount > 0 || eventCount > 0
        let isWaitingForData = !hasData || (bands.count == 1 && bands.first?.contains("Waiting for data") == true)
        
        if isWaitingForData {
            print("🔄 PULL-TO-REFRESH: ⚠️ Detected 'waiting for data' state - forcing full data refresh")
            print("🔄 PULL-TO-REFRESH: Current state: \(bandCount) bands, \(eventCount) events")
        }
        
        // STEP 2: Refresh from database first (immediate UI update)
        print("🔄 PULL-TO-REFRESH: Step 2 - Loading database data immediately")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Load all data from database immediately using CacheManager
            self.cacheManager.loadCachedDataImmediately()
            
            // Check again after reload
            let reloadedBandCount = self.bandNameHandle.getBandNames().count
            let reloadedEventCount = self.schedule.schedulingData.count
            let hasDataAfterReload = reloadedBandCount > 0 || reloadedEventCount > 0
            
            print("🔄 PULL-TO-REFRESH: After reload: \(reloadedBandCount) bands, \(reloadedEventCount) events")
            
            // Display to user on main thread
            DispatchQueue.main.async {
                self.refreshBandList(reason: "Pull-to-refresh - immediate database display")
            }
            
            // If still no data and we're in waiting state, ensure we force a full refresh
            if isWaitingForData && !hasDataAfterReload {
                print("🔄 PULL-TO-REFRESH: ⚠️ Still no data after reload - will force full refresh")
            }
        }
        
        // STEP 3: Always end refresh control after exactly 2 seconds (consistent UX)
        // But if we're waiting for data, keep it active longer
        let refreshDuration: TimeInterval = isWaitingForData ? 3.0 : 2.0
        DispatchQueue.main.asyncAfter(deadline: .now() + refreshDuration) { [weak self] in
            guard let self = self else { return }
            print("🔄 PULL-TO-REFRESH: Ending refresh control after \(refreshDuration) seconds (background updates continue)")
            
            // Properly end refresh control with animation
            self.refreshControl?.endRefreshing()
            
            // Ensure table view animates back to normal position (rubber band effect)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.mainTableView.setContentOffset(CGPoint(x: 0, y: 0), animated: true)
                print("🔄 PULL-TO-REFRESH: Table view animated back to normal position")
            }
        }
        
        // STEP 4: Refresh pointer file, then launch unified data refresh.
        // POLICY: Pointer file downloads are allowed ONLY on startup and pull-to-refresh.
        print("🔄 PULL-TO-REFRESH: Step 4 - Refreshing pointer file before data refresh")
        
        if let appDelegate = appDelegate {
            appDelegate.refreshPointerFileForUserInitiatedRefresh { [weak self] _ in
                guard let self = self else { return }
                
                print("🔄 PULL-TO-REFRESH: Pointer refresh complete - user-initiated gesture always honored")
                // User-initiated pull-to-refresh always downloads fresh data (bypasses throttling)
                // Throttling only applies to automatic/background refreshes, not user gestures
                if isWaitingForData {
                    print("🔄 PULL-TO-REFRESH: Empty state detected - forcing full data refresh")
                    self.refreshData(isUserInitiated: true, forceDownload: true)
                } else {
                    print("🔄 PULL-TO-REFRESH: User gesture honored - launching unified data refresh")
                    self.performUnifiedDataRefresh(reason: "Pull-to-refresh")
                }
            }
        } else {
            // Fallback: should never happen, but keep existing behavior.
            print("🔄 PULL-TO-REFRESH: ⚠️ No AppDelegate instance - proceeding without pointer refresh")
            // User-initiated pull-to-refresh always downloads fresh data (bypasses throttling)
            if isWaitingForData {
                refreshData(isUserInitiated: true, forceDownload: true)
            } else {
                print("🔄 PULL-TO-REFRESH: User gesture honored - launching unified data refresh")
                performUnifiedDataRefresh(reason: "Pull-to-refresh")
            }
        }
    }
    
    /// Called when returning from preferences screen (no year change - only refresh if needed)
    @objc func handleReturnFromPreferences() {
        lastPreferenceReturnTime = Date().timeIntervalSince1970
        justReturnedFromPreferences = true  // Set flag to prevent viewWillAppear override
        
        print("🎛️ [PREFERENCES_SYNC] ⚠️ handleReturnFromPreferences called - user returned from preferences")
        print("🎛️ [PREFERENCES_SYNC] Current hideExpiredEvents: \(getHideExpireScheduleData())")
        print("🎛️ [PREFERENCES_SYNC] Set justReturnedFromPreferences flag to prevent viewWillAppear override")
        print("Handling return from preferences screen - no year change occurred")
        print("Performing light refresh (cache-based only, no network operations)")
        
        // Only refresh from cache - no network operations needed since no year change
        refreshBandList(reason: "Return from preferences - cache refresh only")
    }
    
    /// Called when venue filters change (e.g. from calendar filter sheet). List and calendar share the same persistence.
    @objc func handleVenueFiltersDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshBandList(reason: "Venue filters changed (calendar or list)")
        }
    }
    
    /// Called when returning from preferences screen after year change (data already refreshed)
    @objc func handleReturnFromPreferencesAfterYearChange() {
        lastPreferenceReturnTime = Date().timeIntervalSince1970
        justReturnedFromPreferences = true  // Set flag to prevent viewWillAppear override
        
        print("🎛️ [YEAR_CHANGE] handleReturnFromPreferencesAfterYearChange called - user returned after year change")
        print("🎛️ [YEAR_CHANGE] Current eventYear: \(eventYear)")
        print("🎛️ [YEAR_CHANGE] Current hideExpiredEvents: \(getHideExpireScheduleData())")
        logImagePipelineState("ReturnFromPreferencesAfterYearChange (entry)")
        
        // RACE FIX: Wait briefly if year change data isn't ready yet (edge case protection)
        // This prevents reading SQLite before data import completes
        if !MasterViewController.isYearChangeDataReady() {
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.performInitialDataLoadAfterYearChange()
            }
        } else {
            performInitialDataLoadAfterYearChange()
        }
    }
    
    /// Performs initial data load after year change (extracted for reuse)
    private func performInitialDataLoadAfterYearChange() {
        // STEP 1: Load data from SQLite (no waiting needed - SQLite is always ready)
        print("🎛️ [YEAR_CHANGE] Step 1 - Loading data from SQLite")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Wait for data to be available (with timeout)
            var attempts = 0
            let maxAttempts = 50 // Check up to 50 times (10 seconds max)
            var hasData = false
            
            while attempts < maxAttempts && !hasData {
                attempts += 1
                
                // Log current state before each attempt
                print("🔍 [YEAR_CHANGE_DEBUG] Attempt \(attempts)/\(maxAttempts):")
                print("🔍 [YEAR_CHANGE_DEBUG]   Current eventYear = \(eventYear)")
                print("🔍 [YEAR_CHANGE_DEBUG]   About to load cached data...")
                
                // Try loading cached data using CacheManager
                self.cacheManager.loadCachedDataImmediately()
                
                // Check if data is now available
                let bandCount = self.bandNameHandle.getBandNames().count
                let eventCount = self.schedule.schedulingData.count
                hasData = bandCount > 0 || eventCount > 0
                
                print("🔍 [YEAR_CHANGE_DEBUG]   After load: \(bandCount) bands, \(eventCount) events")
                
                if hasData {
                    print("🎛️ [YEAR_CHANGE] ✅ Data available after \(attempts) attempts: \(bandCount) bands, \(eventCount) events")
                    break
                }
                
                if attempts < maxAttempts {
                    // Wait 200ms before next attempt
                    Thread.sleep(forTimeInterval: 0.2)
                }
            }
            
            if !hasData {
                print("🎛️ [YEAR_CHANGE] ⚠️ No data available after \(maxAttempts) attempts - may still be importing")
            }
            
            // Mark data as ready (allows deferred year change completion to proceed)
            MasterViewController.markYearChangeDataReady()
            
            // Display to user on main thread
            DispatchQueue.main.async {
                self.refreshBandList(reason: "Year change - database display after import wait")
            }
        }
        
        // IMPORTANT:
        // Do NOT kick off another unified refresh here.
        // The year-change flow (PreferencesViewModel -> performBackgroundDataRefresh(reason contains "year change"))
        // already downloads/imports:
        // - bands CSV
        // - schedule CSV
        // - descriptionMap
        // - consolidated image list
        //
        // Starting performUnifiedDataRefresh() again after dismiss can mutate caches while the main list is rendering,
        // which matches the "counts changing / hangs" symptom.
    }
    
    
    @objc func refreshData(isUserInitiated: Bool = false, forceDownload: Bool = false) {
        // Delegate to ViewModel
        viewModel.refreshData(
            isUserInitiated: isUserInitiated,
            forceDownload: forceDownload,
            onCacheRefresh: { [weak self] in
                guard let self = self else { return }
                self.refreshBandList(reason: "Cache refresh - showing cached data")
            },
            onBackgroundRefresh: { [weak self] in
                guard let self = self else { return }
                // Call the proper loading sequence method
                self.performBackgroundDataRefresh(reason: "Data refresh from refreshData method", endRefreshControl: false, shouldScrollToTop: false)
            }
        )
    }
    
    /// Clears all caches comprehensively - used during data refresh
    private func clearAllCaches() {
        // Delegate to CacheManager
        cacheManager.clearAllCaches()
        cacheManager.clearMasterViewCachedData(
            objects: &objects,
            bandsByTime: &bandsByTime,
            bandsByName: &bandsByName
        )
        
        // Clear the bands array immediately before refreshing to ensure atomicity
        print("🧹 Clearing bands array before refresh")
        self.bands.removeAll()
    }
    
    func setFilterTitleText(){
        let displayedRealRows = displayedRowsForFilterBadge(in: bands)
        let hiddenRecordsCount = max(0, unfilteredBandCount - displayedRealRows)
        // Delegate to UIManager (safe when called before view load)
        uiManager.setFilterTitleText(
            bands: bands,
            listCount: listCount,
            searchText: effectiveSearchBar?.text,
            filterTextNeeded: &filterTextNeeded,
            filtersOnText: &filtersOnText,
            hiddenRecordsCount: hiddenRecordsCount
        )
        updateFilterButtonBadge()
    }
    
    /// Custom share button view in header (for popover sourceView when using custom layout)
    private weak var customShareButtonView: UIView?
    
    /// Container for filter count badge (allocates space in header stack so badge isn't clipped)
    private weak var filterBadgeContainer: UIView?
    private weak var filterBadgeContainerWidthConstraint: NSLayoutConstraint?
    
    /// Fallback filter/search when IBOutlets not connected (e.g. split view, lazy load)
    private var fallbackFilterButton: UIButton?
    private var fallbackBandSearch: UISearchBar?
    
    /// Search bar to use for criteria (IB outlet or programmatic fallback)
    private var effectiveSearchBar: UISearchBar? { bandSearch ?? fallbackBandSearch }
    
    /// Filter button to use for positioning (IB outlet or programmatic fallback)
    private var effectiveFilterButton: UIButton? { filterMenuButton ?? fallbackFilterButton }
    
    /// Placeholder rows when the list has no real bands/events (must stay in sync with `handleEmptryList` in mainListController).
    private static func isBandListPlaceholderEntry(_ entry: String) -> Bool {
        entry == NSLocalizedString("data_filter_issue", comment: "")
            || entry == NSLocalizedString("waiting_for_data", comment: "")
            || entry == NSLocalizedString("year_change_loading", comment: "")
    }

    /// Matches Android `BandInfo.isScheduleEventRowListIndex` / main-list `time:name` vs band-slot rows.
    private static func isScheduleEventRowListEntry(_ entry: String) -> Bool {
        let parts = entry.split(separator: ":", omittingEmptySubsequences: false).map { String($0) }
        guard parts.count >= 2 else { return false }
        if let t = Double(parts[0]), t > 0 { return true }
        if let t = Double(parts[1]), t > 0 { return true }
        return false
    }
    
    /// Rows that represent actual bands or schedule entries (excludes empty-state message strings).
    private func displayedNonPlaceholderRowCount(in bands: [String]) -> Int {
        bands.filter { !MasterViewController.isBandListPlaceholderEntry($0) }.count
    }

    /// For filter badge: in unofficial-only imported schedules, unofficial/cruiser rows do not count as "displayed" toward the band-centric total.
    private func displayedRowsForFilterBadge(in bands: [String]) -> Int {
        let real = bands.filter { !MasterViewController.isBandListPlaceholderEntry($0) }
        if getShowScheduleView() && scheduleCompositionIsUnofficialOnly(forYear: eventYear) {
            return real.filter { !MasterViewController.isScheduleEventRowListEntry($0) }.count
        }
        return real.count
    }
    
    /// Updates the filter button badge to show hidden records count
    private func updateFilterButtonBadge() {
        ensureFilterCounterAndShareLayout()
    }
    
    /// Updates filter badge in its dedicated container (so it isn't clipped by the narrow Filters button)
    private func ensureFilterCounterAndShareLayout() {
        let displayedRealRows = displayedRowsForFilterBadge(in: bands)
        let hiddenCount = max(0, unfilteredBandCount - displayedRealRows)
        let hasHiddenRecords = hiddenCount > 0
        
        // Clear old badge from button (legacy) in case we're transitioning
        effectiveFilterButton?.subviews.filter { $0.tag == 70000 }.forEach { $0.removeFromSuperview() }
        
        guard let container = filterBadgeContainer else { return }
        container.subviews.forEach { $0.removeFromSuperview() }
        let showBadge = hasHiddenRecords
        container.isHidden = !showBadge
        filterBadgeContainerWidthConstraint?.constant = showBadge ? 36 : 0
        
        if hasHiddenRecords {
            let badge = UILabel()
            badge.tag = 70000
            badge.text = "\(hiddenCount)"
            badge.font = .systemFont(ofSize: 11, weight: .bold)
            badge.textColor = .black
            badge.backgroundColor = .orange
            badge.textAlignment = .center
            badge.clipsToBounds = true
            badge.translatesAutoresizingMaskIntoConstraints = false
            badge.sizeToFit()
            let w = max(28, badge.bounds.width + 8)
            let h = max(28, badge.bounds.height + 6)
            badge.layer.cornerRadius = h / 2
            container.addSubview(badge)
            NSLayoutConstraint.activate([
                badge.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                badge.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                badge.widthAnchor.constraint(equalToConstant: w),
                badge.heightAnchor.constraint(equalToConstant: h)
            ])
        }
    }
    
    // KISS: Helper to reload table and ensure titleView is visible
    private func reloadTableAndUpdateTitle() {
        tableView.reloadData()
        // Ensure titleView is visible after reload
        navigationItem.title = nil
        updateCountLable()
    }
    
    func decideIfScheduleMenuApplies()->Bool{
        
        var showEventMenu = false
        
        if (scheduleReleased == true && (eventCount != eventCounterUnoffical && unfilteredEventCount > 0)){
            showEventMenu = true
        }
        
        if (unfilteredEventCount == 0 || unfilteredEventCount == unfilteredCruiserEventCount){
            showEventMenu = false
        }
        
        if ((eventCount - unfilteredCruiserEventCount) == unfilteredEventCount){
            showEventMenu = false
        }
        
        print ("Show schedule choices = 1-\(scheduleReleased)  2-\(eventCount) 3-\(eventCounterUnoffical) 4-\(unfilteredCurrentEventCount) 5-\(unfilteredEventCount) 6-\(unfilteredCruiserEventCount) 7-\(showEventMenu)")
        return showEventMenu
    }
    
    /// Helper function to check if all currently visible events are Unofficial or Cruiser Organized
    /// This checks the actual visible events after all filters are applied, not the database count
    /// Counts the number of unofficial/cruiser organized events that are actually in the displayed bands array
    /// This counts what's actually on screen, not what's in the database
    private func countUnofficialEventsInDisplayedBands() -> Int {
        return countUnofficialEventsInDisplayedBands(bands: self.bands)
    }

    /// Same as above but takes a snapshot of bands (for use on background queue to avoid main-thread blocking).
    private func countUnofficialEventsInDisplayedBands(bands bandsSnapshot: [String]) -> Int {
        guard getShowUnofficalEvents() else {
            print("📊 [UNOFFICIAL_COUNT_DEBUG] getShowUnofficalEvents() is false, returning 0 unofficial events.")
            return 0
        }

        var count = 0
        print("📊 [UNOFFICIAL_COUNT_DEBUG] Starting countUnofficialEventsInDisplayedBands (bands.count: \(bandsSnapshot.count))")

        for item in bandsSnapshot {
            // Items in bands array are either "timeIndex:bandName" (events) or "bandName" (bands only)
            // Check if this item has a timeIndex (contains ":")
            if item.contains(":") {
                // This is an event - extract the identifier
                let components = item.split(separator: ":", maxSplits: 1)
                if components.count == 2 {
                    let timeIndexStr = String(components[0])
                    let namePart = String(components[1])
                    
                    // Try to parse timeIndex
                    if let timeIndex = Double(timeIndexStr) {
                        // First, try to find the event by timeIndex directly (more reliable)
                        let allEvents = DataManager.shared.fetchEvents(forYear: eventYear)
                        if let event = allEvents.first(where: { abs($0.timeIndex - timeIndex) < 0.001 }) {
                            let eventType = event.eventType ?? ""
                            if eventType == unofficalEventType || eventType == unofficalEventTypeOld {
                                count += 1
                                continue
                            }
                        }
                        
                        // Fallback: try looking up by band name (for band-associated events)
                        let events = DataManager.shared.fetchEventsForBand(namePart, forYear: eventYear)
                        if let event = events.first(where: { abs($0.timeIndex - timeIndex) < 0.001 }) {
                            let eventType = event.eventType ?? ""
                            if eventType == unofficalEventType || eventType == unofficalEventTypeOld {
                                count += 1
                            }
                        }
                    }
                }
            }
        }
        
        print("📊 [UNOFFICIAL_COUNT] Counted \(count) unofficial events in displayed bands array (out of \(bandsSnapshot.count) total items)")
        if count == 0 && bandsSnapshot.count > 0 {
            // Debug: Show what items we're checking
            let eventItems = bandsSnapshot.filter { $0.contains(":") }
            print("📊 [UNOFFICIAL_COUNT_DEBUG] Found \(eventItems.count) items with ':' (potential events)")
            for (index, item) in eventItems.prefix(5).enumerated() {
                print("📊 [UNOFFICIAL_COUNT_DEBUG] [\(index)] Item: '\(item)'")
            }
        }
        return count
    }
    
    /// Counts the number of unofficial/cruiser organized events that are actually being displayed
    /// (after all filters are applied). This is different from eventCounterUnoffical which counts
    /// all unofficial events in the database regardless of filters.
    private func countDisplayedUnofficialEvents() -> Int {
        // Get all events for the current year and apply the same filters that are used for display
        let allEvents = DataManager.shared.fetchEvents(forYear: eventYear)
        
        // Apply the same filtering logic as getFilteredScheduleData
        // 1. Event type filtering
        var excludedEventTypes: [String] = []
        if !getShowUnofficalEvents() {
            excludedEventTypes.append(contentsOf: ["Unofficial Event", "Cruiser Organized"])
        }
        if !getShowMeetAndGreetEvents() {
            excludedEventTypes.append("Meet and Greet")
        }
        if !getShowSpecialEvents() {
            excludedEventTypes.append("Special Event")
        }
        
        var filteredEvents = allEvents.filter { event in
            let eventType = event.eventType ?? ""
            return !excludedEventTypes.contains(eventType)
        }
        
        // 2. Venue filtering (per-venue state: configured prefix match or discovered = full location; same persistence as list/calendar)
        let filterVenues = FestivalConfig.current.getAllVenueNames()
        filteredEvents = filteredEvents.filter { event in
            let location = event.location
            var venueNameToCheck: String?
            for venueName in filterVenues {
                if location.lowercased().hasPrefix(venueName.lowercased()) {
                    venueNameToCheck = venueName
                    break
                }
            }
            if venueNameToCheck == nil {
                venueNameToCheck = location
            }
            guard let name = venueNameToCheck else { return false }
            return getShowVenueEvents(venueName: name)
        }
        
        // 3. Expiration filtering
        if getHideExpireScheduleData() {
            let currentTime = Date().timeIntervalSinceReferenceDate
            filteredEvents = filteredEvents.filter { event in
                var endTimeIndex = event.endTimeIndex
                // FIX: Detect midnight crossing (matches Android logic)
                if event.timeIndex > endTimeIndex {
                    endTimeIndex += 86400 // Add 24 hours
                }
                // Add 10-minute buffer (600 seconds) before expiration
                return endTimeIndex + 600 > currentTime
            }
        }
        
        // 4. Priority filtering
        let priorityFilteredEvents = filteredEvents.filter { event in
            let bandName = event.bandName
            guard !bandName.isEmpty else { return true }
            
            let priority = priorityManager.getPriority(for: bandName)
            
            if priority == 1 && !getMustSeeOn() { return false }
            if priority == 2 && !getMightSeeOn() { return false }
            if priority == 3 && !getWontSeeOn() { return false }
            if priority == 0 && !getUnknownSeeOn() { return false }
            
            return true
        }
        
        // 5. Attendance filtering (if enabled)
        let finalEvents: [EventData]
        if getShowOnlyWillAttened() {
            finalEvents = priorityFilteredEvents.filter { event in
                let bandName = event.bandName
                let location = event.location
                let eventType = event.eventType ?? ""
                let startTime = event.startTime ?? ""
                
                guard !startTime.isEmpty else { return false }
                
                let eventYearString = String(eventYear)
                let attendedStatus = attendedHandle.getShowAttendedStatus(
                    band: bandName,
                    location: location,
                    startTime: startTime,
                    eventType: eventType,
                    eventYearString: eventYearString
                )
                
                return attendedStatus != sawNoneStatus
            }
        } else {
            finalEvents = priorityFilteredEvents
        }
        
        // Count unofficial/cruiser organized events that are actually being displayed
        let unofficialCount = finalEvents.filter { event in
            let eventType = event.eventType ?? ""
            return eventType == unofficalEventType || eventType == unofficalEventTypeOld
        }.count
        
        return unofficialCount
    }

    /// Picks **Bands** vs **Events** for the navigation title count (must match list composition and Android header rules).
    ///
    /// Schedule view:
    /// 1. **No imported rows under `currentEventsForScheduleRules`** (empty DB, header-only CSV, or hide-expired removed all rows) → **Bands** (visible band-slot / lineup count).
    /// 2. **Unofficial-only** current schedule → **Bands** (band-centric; unofficial rows are not “show events” in the title).
    /// 3. **At least one current event** and not unofficial-only → **Events** (`eventCount`), including “all expired but hide-expired is off” (user still sees event rows).
    ///
    /// Bands list mode (`!showScheduleView`) → **Bands**.
    ///
    /// `scheduleHasCurrentEventsForRules` / `scheduleCompositionIsUnofficialOnly` use `mainListController.currentEventsForScheduleRules` (hide-expired aware).
    private func headerTitleCountAndBandVsEventsLabel(
        showScheduleView: Bool,
        year: Int,
        bandsSnapshot: [String],
        effectiveDisplayedBandRows: Int,
        unofficialCountToSubtract: Int,
        eventCount: Int,
        filtersOnText: String
    ) -> (count: Int, unitAndFiltersLabel: String) {
        let bandSlotsDisplayed = displayedRowsForFilterBadge(in: bandsSnapshot)
        let filtersSuffix = " " + filtersOnText

        if !showScheduleView {
            let c = max(effectiveDisplayedBandRows - unofficialCountToSubtract, 0)
            return (c, " " + NSLocalizedString("Bands", comment: "") + filtersSuffix)
        }
        if scheduleCompositionIsUnofficialOnly(forYear: year) {
            return (max(bandSlotsDisplayed, 0), " " + NSLocalizedString("Bands", comment: "") + filtersSuffix)
        }
        if !scheduleHasCurrentEventsForRules(forYear: year) {
            return (max(bandSlotsDisplayed, 0), " " + NSLocalizedString("Bands", comment: "") + filtersSuffix)
        }
        return (max(eventCount, 0), " " + NSLocalizedString("Events", comment: "") + filtersSuffix)
    }
  
    /// Updates the count label at the top of the list showing "{x} Events" or "{x} Bands"
    /// 
    /// ⚠️ REGRESSION WARNING: This function has been fixed multiple times for the same bug!
    /// ⚠️ DO NOT MODIFY without reading the detailed comments inside this function!
    /// ⚠️ The logic is complex and specific - test ALL scenarios before changing!
    func updateCountLable(){
        print("🔧 [INIT_DEBUG] updateCountLable() ENTERED")
        
        // Filter state (Clear Filters / badge) must always run on main so the sheet and header stay in sync
        if Thread.isMainThread {
            setFilterTitleText()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.setFilterTitleText()
            }
        }
        print("🔧 [INIT_DEBUG] setFilterTitleText() completed (or dispatched to main)")
        
        var lableCounterString = String();
        var labeleCounter = Int()
        
        print ("Event or Band label: \(listCount) \(eventCounterUnoffical)")
        
        // CRITICAL FIX: Calculate eventCounterUnoffical from current SQLite data
        // Since we moved to SQLite, the old loops that counted unofficial events are bypassed
        // We need to count unofficial events directly from the current filtered data
        // FULLY ASYNC: NO blocking of main thread to prevent deadlocks
        // DON'T reset eventCounterUnoffical to 0 - use existing value for synchronous display
        let currentYear = eventYear
        
        print("📊 [ASYNC_COUNT] Starting async event count for year \(currentYear)")
        print("📊 [ASYNC_COUNT] Using current eventCounterUnoffical=\(eventCounterUnoffical) for immediate display")
        print("📊 [ASYNC_COUNT] Will update when async count completes")

        let bandsSnapshot = Array(self.bands)
        let filtersOnTextSnapshot = filtersOnText

        // Perform SQLite fetch and heavy title computation on background - only set UI on main
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            print("📊 [ASYNC_COUNT] Fetching events from SQLite on background thread...")
            let allEvents = DataManager.shared.fetchEvents(forYear: currentYear)
            print("📊 [ASYNC_COUNT] Fetched \(allEvents.count) events from SQLite")

            var count = 0
            var eventTypes: Set<String> = []
            for event in allEvents {
                let eventType = event.eventType
                eventTypes.insert(eventType!)
                if eventType == unofficalEventType || eventType == unofficalEventTypeOld {
                    count += 1
                }
            }

            print("📊 [ASYNC_COUNT] Event types found: \(Array(eventTypes).sorted())")
            print("📊 [ASYNC_COUNT] Looking for: '\(unofficalEventType)' or '\(unofficalEventTypeOld)'")
            print("📊 [ASYNC_COUNT] Count completed: \(count) unofficial events out of \(allEvents.count) total")

            // Heavy work on background thread (was blocking main ~230ms)
            let displayedCount = bandsSnapshot.filter { !MasterViewController.isBandListPlaceholderEntry($0) }.count
            let effectiveDisplayedCount = (displayedCount == 0 && listCount > 0) ? listCount : displayedCount
            let showUnofficalEvents = getShowUnofficalEvents()
            let displayedUnofficialCount = showUnofficalEvents ? self.countUnofficialEventsInDisplayedBands(bands: bandsSnapshot) : 0
            let unofficialCountToSubtract = showUnofficalEvents ? displayedUnofficialCount : 0
            let showScheduleView = getShowScheduleView()
            let titleParts = self.headerTitleCountAndBandVsEventsLabel(
                showScheduleView: showScheduleView,
                year: currentYear,
                bandsSnapshot: bandsSnapshot,
                effectiveDisplayedBandRows: effectiveDisplayedCount,
                unofficialCountToSubtract: unofficialCountToSubtract,
                eventCount: eventCount,
                filtersOnText: filtersOnTextSnapshot
            )
            let labeleCounter = titleParts.count
            let lableCounterString = titleParts.unitAndFiltersLabel

            let currentYearSetting = getScheduleUrl()
            let titleText: String
            if currentYearSetting != "Current" && currentYearSetting != "Default" {
                titleText = "(" + currentYearSetting + ") " + String(labeleCounter) + lableCounterString
            } else {
                titleText = String(labeleCounter) + lableCounterString
            }

            DispatchQueue.main.async {
                if Int32(eventYear) == currentYear {
                    eventCounterUnoffical = count
                    print("📊 [ASYNC_COUNT] Updated eventCounterUnoffical to \(count)")
                    self.setFilterTitleText()
                    self.titleButton.title = titleText
                    self.navigationItem.title = nil
                    let profileColor = self.getColorForCurrentProfile()
                    self.navigationItem.titleView = self.makeTitleViewWithStats(text: titleText, profileColor: profileColor)
                    print("📊 [ASYNC_COUNT] Display updated: \(titleText)")
                } else {
                    print("📊 [ASYNC_COUNT] Year changed during count, skipping update")
                }
            }
        }
        
        print("📊 [COUNT_DEBUG] updateCountLable: listCount=\(listCount), eventCount=\(eventCount), bandCount=\(bandCount), eventCounterUnoffical=\(eventCounterUnoffical)")

        // Run heavy count/title computation on background so main thread is not blocked (~230ms)
        let bandsSnapshotSync = Array(self.bands)
        let capturedListCount = listCount
        let capturedEventCount = eventCount
        let capturedFiltersOnText = filtersOnText
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let displayedCount = bandsSnapshotSync.filter { !MasterViewController.isBandListPlaceholderEntry($0) }.count
            let effectiveDisplayedCount = (displayedCount == 0 && capturedListCount > 0) ? capturedListCount : displayedCount
            let showUnofficalEvents = getShowUnofficalEvents()
            let displayedUnofficialCount = showUnofficalEvents ? self.countUnofficialEventsInDisplayedBands(bands: bandsSnapshotSync) : 0
            let unofficialCountToSubtract = showUnofficalEvents ? displayedUnofficialCount : 0
            let showScheduleView = getShowScheduleView()
            let titleParts = self.headerTitleCountAndBandVsEventsLabel(
                showScheduleView: showScheduleView,
                year: eventYear,
                bandsSnapshot: bandsSnapshotSync,
                effectiveDisplayedBandRows: effectiveDisplayedCount,
                unofficialCountToSubtract: unofficialCountToSubtract,
                eventCount: capturedEventCount,
                filtersOnText: capturedFiltersOnText
            )
            let labeleCounter = titleParts.count
            let lableCounterString = titleParts.unitAndFiltersLabel
            let currentYearSetting = getScheduleUrl()
            let titleText: String
            if currentYearSetting != "Current" && currentYearSetting != "Default" {
                titleText = "(" + currentYearSetting + ") " + String(labeleCounter) + lableCounterString
            } else {
                titleText = String(labeleCounter) + lableCounterString
            }
            DispatchQueue.main.async {
                self.titleButton.title = titleText
                self.navigationItem.title = nil
                let profileColor = self.getColorForCurrentProfile()
                self.navigationItem.titleView = self.makeTitleViewWithStats(text: titleText, profileColor: profileColor)
                self.navigationItem.title = nil
            }
        }
    }
    
    @IBAction func shareButtonClicked(_ sender: UIBarButtonItem){
                
        detailShareChoices()
    }
    
    
    func sendSharedMessage(message: String){
        
        var intro:String = ""
        
        print ("sending a shared message of : " + message)
        intro += FCMnumber + " " + message
      
        let objectsToShare = [intro]
        let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: [])
        
        activityVC.modalPresentationStyle = .popover
        if let sourceView = customShareButtonView {
            activityVC.popoverPresentationController?.sourceView = sourceView
            activityVC.popoverPresentationController?.sourceRect = sourceView.bounds
        } else {
            activityVC.popoverPresentationController?.barButtonItem = shareButton
        }
        
        let popoverMenuViewController = activityVC.popoverPresentationController
        popoverMenuViewController?.permittedArrowDirections = .any

        //popoverMenuViewController?.sourceView = unknownButton
        popoverMenuViewController?.sourceRect = CGRect()


        self.present(activityVC, animated: true, completion: nil)
    }
    
    func adaptivePresentationStyleForPresentationController(
        _ controller: UIPresentationController!) -> UIModalPresentationStyle {
            return .none
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Delegate to UIManager
        return uiManager.numberOfRows(bands: bands)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        self.configureCell(cell, atIndexPath: indexPath)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Delegate to UIManager
        uiManager.willDisplayCell(
            cell: cell,
            forRowAt: indexPath,
            bands: bands,
            showScheduleView: getShowScheduleView(),
            currentViewingDay: &currentViewingDay
        )
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let filterBtn: UIButton
        let searchBar: UISearchBar
        if let fb = filterMenuButton, let sb = bandSearch {
            filterBtn = fb
            searchBar = sb
        } else {
            if fallbackFilterButton == nil {
                let btn = UIButton(type: .system)
                btn.setTitle(NSLocalizedString("Filters", comment: ""), for: .normal)
                btn.setImage(UIImage(systemName: "line.3.horizontal.decrease"), for: .normal)
                btn.addTarget(self, action: #selector(filterMenuButtonPress(_:)), for: .touchUpInside)
                btn.tintColor = UIColor(white: 0.67, alpha: 1)
                btn.titleLabel?.font = .systemFont(ofSize: 25)
                btn.backgroundColor = .black
                fallbackFilterButton = btn
            }
            if fallbackBandSearch == nil {
                let bar = UISearchBar()
                bar.placeholder = NSLocalizedString("SearchCriteria", comment: "")
                bar.searchTextField.returnKeyType = .done
                bar.delegate = self
                installSearchKeyboardDoneToolbar(bar)
                bar.barStyle = .black
                bar.searchBarStyle = .prominent
                bar.backgroundColor = .black
                bar.tintColor = .lightGray
                bar.barTintColor = .black
                bar.searchTextField.backgroundColor = .black
                bar.searchTextField.textColor = .white
                bar.searchTextField.attributedPlaceholder = NSAttributedString(
                    string: NSLocalizedString("SearchCriteria", comment: ""),
                    attributes: [.foregroundColor: UIColor.lightGray]
                )
                fallbackBandSearch = bar
            }
            filterBtn = fallbackFilterButton!
            searchBar = fallbackBandSearch!
        }
        let headerWidth = tableView.bounds.width > 0 ? tableView.bounds.width : 320
        
        let container = UIView(frame: CGRect(x: 0, y: 0, width: headerWidth, height: 44))
        container.backgroundColor = .black
        container.isOpaque = true
        mainToolBar?.isHidden = true  // Using custom header instead
        
        if filterMenuButton != nil { filterButtonBar?.customView = nil }
        if bandSearch != nil { searchButtonBar?.customView = nil }
        filterBtn.removeFromSuperview()
        searchBar.removeFromSuperview()
        searchBar.searchTextField.returnKeyType = .done
        installSearchKeyboardDoneToolbar(searchBar)
        filterBtn.isHidden = false
        searchBar.isHidden = false
        filterBtn.alpha = 1.0
        searchBar.alpha = 1.0
        filterBtn.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        searchBar.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        let shareBtn = UIButton(type: .system)
        shareBtn.setImage(UIImage(named: FestivalConfig.current.shareIcon), for: .normal)
        shareBtn.tintColor = UIColor(white: 0.67, alpha: 1)
        shareBtn.addTarget(self, action: #selector(customShareButtonTapped(_:)), for: .touchUpInside)
        shareBtn.translatesAutoresizingMaskIntoConstraints = false
        let shareWidthConstraint = shareBtn.widthAnchor.constraint(equalToConstant: 44)
        shareWidthConstraint.priority = .defaultHigh  // Breakable so layout can resolve when portrait width is tight
        shareWidthConstraint.isActive = true
        shareBtn.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        customShareButtonView = shareBtn
        
        let badgeContainer = UIView()
        badgeContainer.backgroundColor = .clear
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        let widthConstraint = badgeContainer.widthAnchor.constraint(equalToConstant: 36)
        widthConstraint.isActive = true
        filterBadgeContainer = badgeContainer
        filterBadgeContainerWidthConstraint = widthConstraint
        
        let stack = UIStackView(arrangedSubviews: [filterBtn, badgeContainer, searchBar, shareBtn])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fill
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        ensureFilterCounterAndShareLayout()
        return container
    }
    
    @objc private func customShareButtonTapped(_ sender: UIButton) {
        shareButtonClicked(shareButton)
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 44.0
    }
    
    //swip code start
    
    func currentlySectionBandName(_ rowNumber: Int) -> String {
        // Delegate to UIManager
        return uiManager.currentlySectionBandName(rowNumber, bands: bands)
    }

    class TableViewRowAction: UITableViewRowAction
    {
        var image: UIImage?
        
        func _setButton(button: UIButton)
        {
            if let image = image, let titleLabel = button.titleLabel
            {
                let labelString = NSString(string: titleLabel.text!)
                let titleSize = labelString.size(withAttributes: [NSAttributedString.Key.font: titleLabel.font])
                
                button.tintColor = UIColor.white
                button.setImage(image.withRenderingMode(.alwaysTemplate), for: [])
                button.imageEdgeInsets.right = -titleSize.width
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        let attendedHandle = ShowsAttended()
        
        let sawAllShow = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title: "", handler: { (action:UITableViewRowAction!, indexPath:IndexPath!) -> Void in
            
            let currentCel = tableView.cellForRow(at: indexPath)
            
            let cellText = currentCel?.textLabel?.text;
            let cellStatus = currentCel!.viewWithTag(2) as! UILabel
            print ("Cell text for parsing is \(cellText ?? "")")
            let placementOfCell = currentCel?.frame
            
            if (cellStatus.isHidden == false){
                let cellData = cellText?.split(separator: ";")
                
                // CRITICAL: Validate cellData has enough elements to prevent crash
                guard let data = cellData, data.count >= 4 else {
                    print("❌ [SWIPE_ACTION] Invalid cell data format: \(cellText ?? "nil")")
                    let message = NSLocalizedString("Invalid cell data - cannot add attendance", comment: "Toast message when cell data is invalid")
                    ToastMessages(message).show(self, cellLocation: placementOfCell!, placeHigh: false)
                    return
                }
                
                let cellBandName = data[0]
                let cellLocation = data[1]
                let cellEventType  = data[2]
                let cellStartTime = data[3]

                let status = attendedHandle.addShowsAttended(band: String(cellBandName), location: String(cellLocation), startTime: String(cellStartTime), eventType: String(cellEventType),eventYearString: String(eventYear));
                
                let empty : UITextField = UITextField();
                let message = attendedHandle.setShowsAttendedStatus(empty, status: status)
                let visibleLocation = CGRect(origin: self.mainTableView.contentOffset, size: self.mainTableView.bounds.size)
                ToastMessages(message).show(self, cellLocation: placementOfCell!,  placeHigh: false)
                isLoadingBandData = false
                
                // Refresh iPad detail view if this band is currently displayed
                let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
                print("DEBUG: Swipe action - cellBandName from data: '\(String(cellBandName))', bandName from index: '\(bandName)'")
                print("DEBUG: Swipe action - calling refreshIPadDetailViewIfNeeded for band: '\(bandName)'")
                self.refreshIPadDetailViewIfNeeded(for: bandName)
                self.quickRefresh()
            } else {
                let message = NSLocalizedString("No Show Is Associated With This Entry", comment: "Toast message when no show is associated with entry")
                ToastMessages(message).show(self, cellLocation: placementOfCell!, placeHigh: false)
            }
        })
        sawAllShow.setIcon(iconImage: UIImage(named: "icon-seen")!, backColor: UIColor.darkGray, cellHeight: 50, cellWidth: 230)
 
        let mustSeeAction = UITableViewRowAction(style:UITableViewRowAction.Style.normal, title:"", handler: { (action:UITableViewRowAction!, indexPath:IndexPath!) -> Void in
            
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            self.priorityManager.setPriority(for: bandName, priority: 1)
            print ("Offline is offline");
            isLoadingBandData = false
            self.refreshBandListOnly(reason: "Priority changed to Must See")
            
            // Refresh iPad detail view if this band is currently displayed
            self.refreshIPadDetailViewIfNeeded(for: bandName)

        })
        
        
        mustSeeAction.setIcon(iconImage: UIImage(named: mustSeeIconSmall)!, backColor: UIColor.darkGray, cellHeight: 50, cellWidth: 230)
        
        let mightSeeAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title:"", handler: { (action:UITableViewRowAction!, indexPath:IndexPath!) -> Void in
            
            print ("Changing the priority of " + self.currentlySectionBandName(indexPath.row) + " to 2")
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            self.priorityManager.setPriority(for: bandName, priority: 2)
            isLoadingBandData = false
            self.refreshBandListOnly(reason: "Priority changed to Might See")
            
            // Refresh iPad detail view if this band is currently displayed
            self.refreshIPadDetailViewIfNeeded(for: bandName)
            
        })
        
        mightSeeAction.setIcon(iconImage: UIImage(named: mightSeeIconSmall)!, backColor: UIColor.darkGray, cellHeight: 50, cellWidth: 230)
        
        let wontSeeAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title:"", handler: { (action:UITableViewRowAction!, indexPath:IndexPath!) -> Void in
            
            print ("Changing the priority of " + self.currentlySectionBandName(indexPath.row) + " to 3")
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            self.priorityManager.setPriority(for: bandName, priority: 3)
            isLoadingBandData = false
            self.refreshBandListOnly(reason: "Priority changed to Won't See")
            
            // Refresh iPad detail view if this band is currently displayed
            self.refreshIPadDetailViewIfNeeded(for: bandName)
            
        })
        
        wontSeeAction.setIcon(iconImage: UIImage(named: wontSeeIconSmall)!, backColor: UIColor.darkGray, cellHeight: 50, cellWidth: 230)
        
        let setUnknownAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title:"", handler: { (action:UITableViewRowAction!, indexPath:IndexPath!) -> Void in
            
            print ("Changing the priority of " + self.currentlySectionBandName(indexPath.row) + " to 0")
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            self.priorityManager.setPriority(for: bandName, priority: 0)
            isLoadingBandData = false
            self.refreshBandListOnly(reason: "Priority changed to Unknown")
            
            // Refresh iPad detail view if this band is currently displayed
            self.refreshIPadDetailViewIfNeeded(for: bandName)
            
        })
        setUnknownAction.setIcon(iconImage: UIImage(named: unknownIconSmall)!, backColor: UIColor.darkGray, cellHeight: 50, cellWidth: 230)
        
        if (eventCount == 0){
            return [setUnknownAction, wontSeeAction, mightSeeAction, mustSeeAction]
        } else {
            return [sawAllShow, wontSeeAction, mightSeeAction, mustSeeAction]
        }
    }
    
    //swip code end
    
    func configureCell(_ cell: UITableViewCell, atIndexPath indexPath: IndexPath) {
        // Delegate to UIManager
        setBands(bands)
        uiManager.configureCell(
            cell,
            atIndexPath: indexPath,
            bands: bands,
            sortBy: getSortedBy()
        )
    }
    
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("🔍 prepare(for:sender:) called with identifier: \(segue.identifier ?? "nil"), destination: \(type(of: segue.destination))")
        

        
        print("Getting Details")
        print("bands type in prepare(for:sender:):", type(of: bands))
        currentBandList = self.bands
        print ("Waiting for band data to load, Done")
        if (currentBandList.count == 0){
            var attempts = 0
            while(currentBandList.count == 0 && attempts < 3){
                print("prepare(for:sender:): Attempt \(attempts+1) to refresh band list")
                refreshBandList(reason: "Cache refresh")
                currentBandList = self.bands
                attempts += 1
            }
            if currentBandList.count == 0 {
                print("prepare(for:sender:): Band list still empty after 3 attempts, aborting to prevent infinite loop")
                // Optionally: return or handle gracefully here
            }
        }
        self.splitViewController!.delegate = self;

        if isSplitViewCapable() {
            self.splitViewController!.preferredDisplayMode = UISplitViewController.DisplayMode.allVisible
            self.splitViewController!.preferredPrimaryColumnWidth = 400 // Make left column wider (default ~320)
        }

        self.extendedLayoutIncludesOpaqueBars = true
        
        // Note: "showDetail" segue has been replaced with SwiftUI navigation
        updateCountLable()

        tableView.reloadData()

    }
    
    // MARK: - Table View Selection
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Add bounds checking to prevent crash
        guard indexPath.row < bands.count else {
            print("ERROR: Selected index \(indexPath.row) out of bounds for bands array (count: \(bands.count))")
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        
        // Handle cell selection for SwiftUI navigation
        guard let cell = tableView.cellForRow(at: indexPath) else {
            print("Error: Could not get cell for selected row.")
            return
        }
        guard let bandNameView = cell.viewWithTag(2) as? UILabel else {
            print("Error: Could not get bandNameView.")
            return
        }
        guard let bandNameNoSchedule = cell.viewWithTag(12) as? UILabel else {
            print("Error: Could not get bandNameNoSchedule.")
            return
        }
        guard let cellDataView = cell.viewWithTag(1) as? UILabel else {
            print("Error: Could not get cellDataView.")
            return
        }
        
        let cellDataText = cellDataView.text ?? ""
        eventSelectedIndex = cellDataView.text ?? ""
        var bandName = bandNameNoSchedule.text ?? ""
        if bandName.isEmpty {
            bandName = bandNameView.text ?? ""
        }
        
        // Check if this is a combined event (internal delimiter, not "/")
        if isCombinedEventBandName(bandName) {
            if let individualBands = combinedEventsMap[bandName], individualBands.count == 2 {
                // Prompt user to choose which band
                promptForBandSelection(combinedBandName: bandName, bands: individualBands, cellDataText: cellDataText, indexPath: indexPath)
                tableView.deselectRow(at: indexPath, animated: true)
                return
            }
        }
        
        print("BandName for SwiftUI Details is \(bandName)")
        detailMenuChoicesSwiftUI(cellDataText: cellDataText, bandName: bandName, indexPath: indexPath)
        
        // Deselect the row
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    /// Prompts user to select which band they want to act on when multiple bands share the same event (Landscape Calendar View)
    func promptForBandSelectionLandscape(combinedBandName: String, bands: [String], currentDay: String?) {
        guard bands.count == 2 else {
            print("ERROR: Expected exactly 2 bands for combined event, got \(bands.count)")
            return
        }
        let band1 = bands[0]
        let band2 = bands[1]
        let presenter = landscapeScheduleViewController ?? self
        let vc = BandSelectionViewController(
            title: NSLocalizedString("Select Band", comment: "Title for band selection dialog"),
            message: NSLocalizedString("Multiple bands share this event. Which band would you like to view?", comment: "Message for band selection dialog"),
            band1: band1,
            band2: band2,
            onSelect: { [weak self] selectedBand in
                guard let self = self else { return }
                self.navigateToBandFromLandscape(bandName: selectedBand, currentDay: currentDay)
            },
            onCancel: { }
        )
        presenter.present(vc, animated: true, completion: nil)
    }

    /// Prompts user to select which band to apply priority/attendance to when long-pressing a combined event in landscape
    func promptForBandSelectionLandscapeForLongPress(combinedBandName: String, bands: [String], location: String, startTime: String, eventType: String, day: String?) {
        guard bands.count == 2 else {
            print("ERROR: Expected exactly 2 bands for combined event, got \(bands.count)")
            return
        }
        let band1 = bands[0]
        let band2 = bands[1]
        let presentingViewController = landscapeScheduleViewController ?? self
        let vc = BandSelectionViewController(
            title: NSLocalizedString("Select Band", comment: "Title for band selection dialog"),
            message: NSLocalizedString("Which band do you want to set priority or attendance for?", comment: "Long-press combined event: which band to act on"),
            band1: band1,
            band2: band2,
            onSelect: { [weak self] selectedBand in
                guard let self = self else { return }
                let cellDataText = "\(selectedBand);\(location);\(eventType);\(startTime)"
                self.showLongPressMenu(bandName: selectedBand, cellDataText: cellDataText, indexPath: IndexPath(row: 0, section: 0), presentingFrom: presentingViewController)
            },
            onCancel: { }
        )
        presentingViewController.present(vc, animated: true, completion: nil)
    }
    
    /// Navigates to band detail from landscape calendar view
    private func navigateToBandFromLandscape(bandName: String, currentDay: String?) {
        // Save the current day for when we return
        if let day = currentDay {
            self.currentViewingDay = day
            print("🔄 [LANDSCAPE_SCHEDULE] Saved current viewing day: \(day)")
        }
        
        // Save scroll position
        self.savedScrollPosition = self.tableView.contentOffset
        print("🔄 [LANDSCAPE_SCHEDULE] Saved scroll position: \(self.savedScrollPosition!)")
        
        // Find the band index
        let bandIndex: Int
        if let index = self.bands.firstIndex(where: { band in
            getNameFromSortable(band, sortedBy: getSortedBy()) == bandName
        }) {
            bandIndex = index
        } else {
            print("⚠️ [LANDSCAPE_SCHEDULE] Band not in filtered list, using index 0")
            bandIndex = 0
        }
        
        // Set up for detail navigation (using globals from Constants.swift)
        bandSelected = bandName
        bandListIndexCache = bandIndex
        
        // Create and present detail view from the stored landscape controller with custom back button
        let detailController = DetailHostingController(bandName: bandName, showCustomBackButton: true)
        
        // CRITICAL FIX: For large display (master/detail), make the detail popup larger to accommodate band name and logo
        if isSplitViewCapable() {
            // Use formSheet for a larger modal that doesn't cover the entire screen
            detailController.modalPresentationStyle = .formSheet
            // Set larger preferred content size to accommodate band name and logo
            detailController.preferredContentSize = CGSize(width: 800, height: 900)
        }
        
        // Present from the stored landscape view controller
        self.landscapeScheduleViewController?.present(detailController, animated: true) {
            print("✅ [LANDSCAPE_SCHEDULE] Detail view presented")
        }
    }
    
    /// Prompts user to select which band they want to act on when multiple bands share the same event (Portrait List View)
    func promptForBandSelection(combinedBandName: String, bands: [String], cellDataText: String, indexPath: IndexPath) {
        guard bands.count == 2 else {
            print("ERROR: Expected exactly 2 bands for combined event, got \(bands.count)")
            return
        }
        
        let band1 = bands[0]
        let band2 = bands[1]
        
        let alert = UIAlertController(
            title: NSLocalizedString("Select Band", comment: "Title for band selection dialog"),
            message: NSLocalizedString("Multiple bands share this event. Which band would you like to view?", comment: "Message for band selection dialog"),
            preferredStyle: .actionSheet
        )
        
        // Configure popover for iPad
        if let popover = alert.popoverPresentationController {
            if let cell = tableView.cellForRow(at: indexPath) {
                popover.sourceView = cell
                popover.sourceRect = cell.bounds
            } else {
                popover.sourceView = self.view
                popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            }
            popover.permittedArrowDirections = [.up, .down]
        }
        
        // Add action for first band
        let band1Action = UIAlertAction(title: band1, style: .default) { [weak self] _ in
            guard let self = self else { return }
            print("User selected band: \(band1)")
            // Reconstruct cellDataText with the selected band name
            // The cellDataText format is: "bandName;location;eventType;startTime"
            var cellDataComponents = cellDataText.components(separatedBy: ";")
            if cellDataComponents.count >= 1 {
                cellDataComponents[0] = band1
            }
            let updatedCellDataText = cellDataComponents.joined(separator: ";")
            self.detailMenuChoicesSwiftUI(cellDataText: updatedCellDataText, bandName: band1, indexPath: indexPath)
        }
        alert.addAction(band1Action)
        
        // Add action for second band
        let band2Action = UIAlertAction(title: band2, style: .default) { [weak self] _ in
            guard let self = self else { return }
            print("User selected band: \(band2)")
            // Reconstruct cellDataText with the selected band name
            var cellDataComponents = cellDataText.components(separatedBy: ";")
            if cellDataComponents.count >= 1 {
                cellDataComponents[0] = band2
            }
            let updatedCellDataText = cellDataComponents.joined(separator: ";")
            self.detailMenuChoicesSwiftUI(cellDataText: updatedCellDataText, bandName: band2, indexPath: indexPath)
        }
        alert.addAction(band2Action)
        
        // Add cancel action
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
            print("User cancelled band selection")
        }
        alert.addAction(cancelAction)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func showScheduleQRCode() {
        if !isBandFileAvailableForQR(eventYear: eventYear) {
            guard NetworkTesting.isNetworkAvailable() else {
                let alert = UIAlertController(title: NSLocalizedString("Share Schedule via QR Code", comment: ""), message: bandFileRequiredMessageNoNetwork(), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
                present(alert, animated: true)
                return
            }
            let loadingAlert = UIAlertController(title: NSLocalizedString("Share Schedule via QR Code", comment: ""), message: NSLocalizedString("QR downloading band list", comment: "Downloading band list..."), preferredStyle: .alert)
            present(loadingAlert, animated: true)
            BandCSVImporter().downloadAndImportBands(forceDownload: true) { [weak self] success in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        if success, isBandFileAvailableForQR(eventYear: eventYear) {
                            self.proceedShowScheduleQRCode()
                        } else {
                            let failAlert = UIAlertController(title: NSLocalizedString("Share Schedule via QR Code", comment: ""), message: NSLocalizedString("QR band file download failed", comment: "Could not download band list"), preferredStyle: .alert)
                            failAlert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
                            self.present(failAlert, animated: true)
                        }
                    }
                }
            }
            return
        }
        proceedShowScheduleQRCode()
    }

    private func proceedShowScheduleQRCode() {
        // Prefer raw cached schedule CSV (same source as Android). Fall back to CSV built from current events when cache is missing (e.g. schedule from SQLite only).
        let csvString: String? = rawScheduleCSVFromCache().flatMap { $0.isEmpty ? nil : $0 }
            ?? exportScheduleCSV(eventYear: eventYear)
        guard let csv = csvString, !csv.isEmpty else {
            let alert = UIAlertController(title: NSLocalizedString("Share Schedule via QR Code", comment: ""), message: NSLocalizedString("No schedule events to share.", comment: "QR schedule empty"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
            present(alert, animated: true)
            return
        }
        do {
            let payloads = try compressScheduleForOneOrTwoQRs(csvString: csv, eventYear: eventYear)
            let qrVC = payloads.count == 1
                ? ScheduleQRCodeViewController(payloadData: payloads[0])
                : ScheduleQRCodeViewController(schedulePayloads: payloads)
            if DeviceSizeManager.isLargeDisplay() {
                qrVC.modalPresentationStyle = .formSheet
            }
            present(qrVC, animated: true)
        } catch {
            let alert = UIAlertController(title: NSLocalizedString("Share Schedule via QR Code", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
            present(alert, animated: true)
        }
    }

    func showSharingView() {
        let sharingView = SharingHostingController()
        if DeviceSizeManager.isLargeDisplay() {
            sharingView.modalPresentationStyle = .formSheet
        } else {
            sharingView.modalPresentationStyle = .fullScreen
        }
        self.present(sharingView, animated: true)
    }
    
    // MARK: - Shared Preferences Title Update
    
    func updateTitleForActivePreferenceSource() {
        // Now handled by updateCountLable() which applies profile colors
        updateCountLable()
    }
    
    @objc func onPreferenceSourceChanged(_ notification: Notification) {
        print("🔄 [PREFERENCE_SOURCE] Received preference source change notification")
        updateTitleForActivePreferenceSource()
    }
    
    func detailShareChoices(){
        
        sharedMessage = "Start"
        
        let alert = UIAlertController.init(title: NSLocalizedString("Share Type", comment: "Share type dialog title"), message: "", preferredStyle: .actionSheet)
        
        // Set preferred size to ensure all options are visible
        alert.preferredContentSize = CGSize(width: 400, height: 400)
        
        // Configure popover for iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        let reportHandler = showAttendenceReport()
        
        print("🔍 [SHARE_MENU] ========== STARTING SHARE MENU SETUP ==========")
        
        // NEW: Share preferences as file
        let sharePreferencesFile = UIAlertAction.init(title: NSLocalizedString("Share Importable Band/Event Data", comment: "Share importable profile file"), style: .default) { _ in
            print("Opening Sharing view")
            self.showSharingView()
        }
        alert.addAction(sharePreferencesFile)
        print("✅ [SHARE_MENU] Added option 1: Share Importable Band/Event Data")
        
        let mustMightShare = UIAlertAction.init(title: NSLocalizedString("Share Band Report", comment: "Share band priorities as text"), style: .default) { _ in
            print("shared message: Share Must/Might list")
            var message = reportHandler.buildMessage(type: "MustMight")
            self.sendSharedMessage(message: message)
        }
        alert.addAction(mustMightShare)
        print("✅ [SHARE_MENU] Added option 2: Share Band Report")
        
        print("🔍 [SHARE_MENU] About to call reportHandler.assembleReport()...")
        reportHandler.assembleReport();
        print("🔍 [SHARE_MENU] assembleReport() completed")
        
        let isEmpty = reportHandler.getIsReportEmpty()
        print("📋 [SHARE_MENU] Report isEmpty: \(isEmpty)")
        
        if (isEmpty == false){
            print("✅ [SHARE_MENU] isEmpty is FALSE - Adding 'Share Event Report' option")
            let showsAttended = UIAlertAction.init(title: NSLocalizedString("Share Event Report", comment: "Share attended events as text"), style: .default) { _ in
                    print("shared message: Share Event Report")
                    var message = reportHandler.buildMessage(type: "Events")
                    self.sendSharedMessage(message: message)
            }
            alert.addAction(showsAttended)
            print("✅ [SHARE_MENU] Added option 3: Share Event Report")
        } else {
            print("⚠️ [SHARE_MENU] isEmpty is TRUE - NOT adding 'Share Event Report' option")
        }
        
        // Share Schedule via QR Code (70K only; when schedule events present and feature enabled)
        let hasScheduleEvents = DataManager.shared.fetchEvents(forYear: eventYear).count > 0
        if hasScheduleEvents && FestivalConfig.current.scheduleQRShareEnabled {
            let shareScheduleQR = UIAlertAction(title: NSLocalizedString("Share Schedule via QR Code", comment: "Share menu option for QR schedule"), style: .default) { _ in
                self.showScheduleQRCode()
            }
            alert.addAction(shareScheduleQR)
            print("✅ [SHARE_MENU] Added option 4: Share Schedule via QR Code")
        }
        
        let cancelDialog = UIAlertAction.init(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
            self.sharedMessage = "Abort"
            return
        }
        alert.addAction(cancelDialog)
        print("✅ [SHARE_MENU] Added Cancel button")
        
        print("🔍 [SHARE_MENU] Total actions in alert: \(alert.actions.count)")
        for (index, action) in alert.actions.enumerated() {
            print("🔍 [SHARE_MENU] Action \(index): \(action.title ?? "nil") (style: \(action.style.rawValue))")
        }
        
        if let popoverController = alert.popoverPresentationController {
              popoverController.sourceView = self.view
               popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.maxY, width: 0, height: 0)
              popoverController.permittedArrowDirections = []
       }
   
       present(alert, animated: true, completion: nil)
       
        sharedMessage = "Done"
    }
    
    func detailMenuChoices(cellDataText :String, bandName :String, segue :UIStoryboardSegue, indexPath: IndexPath) {
        // Always go straight to details - popup removed, use long press instead
        print ("Go straight to the SwiftUI details screen")
        goToDetailsScreenSwiftUI(bandName: bandName, indexPath: indexPath)
    }
       
       /// SwiftUI version of detailMenuChoices (replaces storyboard segue version)
       func detailMenuChoicesSwiftUI(cellDataText: String, bandName: String, indexPath: IndexPath) {
           // Always go straight to details - popup removed, use long press instead
           print ("Go straight to the SwiftUI details screen")
           goToDetailsScreenSwiftUI(bandName: bandName, indexPath: indexPath)
       }
       
    func goToDetailsScreen(segue :UIStoryboardSegue, bandName :String, indexPath :IndexPath){
        
         print ("bandName = \(bandName) - migrating to SwiftUI DetailView")
         if (bandName.isEmpty == false){
            
            bandSelected = bandName;
            bandListIndexCache = indexPath.row
            
            print ("Bands size is " + String(bands.count) + " Index is  " + String(indexPath.row))

            // Create SwiftUI DetailHostingController instead of using storyboard segue
            let detailController = DetailHostingController(bandName: bandName)
            
            if isSplitViewCapable() {
                detailController.configureSplitViewPresentation()
            }

            if isSplitViewCapable() {
                // Replace detail view in split view
                if let splitVC = self.splitViewController,
                   let navController = splitVC.viewControllers.last as? UINavigationController {
                    navController.setViewControllers([detailController], animated: true)
                } else {
                    self.navigationController?.pushViewController(detailController, animated: true)
                }
            } else {
                // iPhone: Push onto navigation stack
                self.navigationController?.pushViewController(detailController, animated: true)
            }
            
        } else {
            print ("Found an issue with the selection 1");
            return
        }

    }
    
    /// New SwiftUI-based detail navigation (replaces storyboard segue)
    func goToDetailsScreenSwiftUI(bandName: String, indexPath: IndexPath) {
        print("goToDetailsScreenSwiftUI: bandName = \(bandName)")
        
        guard !bandName.isEmpty else {
            print("Found an issue with the selection - empty band name")
            return
        }
        
        bandSelected = bandName
        bandListIndexCache = indexPath.row
        
        print("Bands size is \(bands.count) Index is \(indexPath.row)")
        
        // Track which day this band is on for landscape view initial positioning
        let eventManager = EventManager()
        let allEvents = eventManager.getEvents(forYear: eventYear)
        if let firstEvent = allEvents.first(where: { $0.bandName == bandName }), let day = firstEvent.day {
            currentViewingDay = day
            print("🔄 [DAY_TRACKING] Set currentViewingDay to \(day) for band: \(bandName)")
        }
        
        // IMPORTANT: Populate currentBandList for swipe navigation (same as prepare(for:sender:))
        currentBandList = self.bands
        print("DEBUG: Set currentBandList for SwiftUI navigation - count: \(currentBandList.count)")
        
        if currentBandList.count == 0 {
            print("⚠️ goToDetailsScreenSwiftUI: Band list is empty - using fallback navigation")
            // DEADLOCK FIX: Don't block main thread with synchronous refresh calls
            // Instead, use the existing bands array or trigger async refresh
            if !self.bands.isEmpty {
                currentBandList = self.bands
                print("🔧 Using existing bands array as fallback: \(currentBandList.count) bands")
            } else {
                print("🚨 No bands available - proceeding anyway to avoid deadlock")
                // Trigger async refresh for next time, but don't block current navigation
                DispatchQueue.global(qos: .background).async {
                    self.refreshBandList(reason: "Background cache refresh after empty list")
                }
            }
        }
        
        // Create SwiftUI DetailHostingController
        let detailController = DetailHostingController(bandName: bandName)
        
        if isSplitViewCapable() {
            detailController.configureSplitViewPresentation()

            if let splitVC = self.splitViewController,
               let navController = splitVC.viewControllers.last as? UINavigationController {
                navController.setViewControllers([detailController], animated: true)
            } else {
                self.navigationController?.pushViewController(detailController, animated: true)
            }
        } else {
            // iPhone: Push onto navigation stack
            self.navigationController?.pushViewController(detailController, animated: true)
        }
    }
    
    // MARK: - Long Press Gesture Handler
    
    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        let point = gesture.location(in: mainTableView)
        guard let indexPath = mainTableView.indexPathForRow(at: point) else { return }
        
        guard indexPath.row < bands.count else { return }
        
        let bandEntry = bands[indexPath.row]
        let bandName = getNameFromSortable(bandEntry, sortedBy: sortedBy)
        
        // Convert to window coordinates so the menu can position near the tap
        let pointInWindow = mainTableView.convert(point, to: nil)
        
        // Get cell data to check if this is a scheduled event
        guard let cell = mainTableView.cellForRow(at: indexPath),
              let cellDataView = cell.viewWithTag(1) as? UILabel else {
            // No schedule data - show priority menu only
            showLongPressMenu(bandName: bandName, cellDataText: nil, indexPath: indexPath, sourcePointInWindow: pointInWindow)
            return
        }
        
        let cellDataText = cellDataView.text ?? ""
        showLongPressMenu(bandName: bandName, cellDataText: cellDataText, indexPath: indexPath, sourcePointInWindow: pointInWindow)
    }
    
    // Helper to get icon name for priority
    private func getPriorityIconName(priority: Int) -> String? {
        switch priority {
        case 1: return mustSeeIconSmall
        case 2: return mightSeeIconSmall
        case 3: return wontSeeIconSmall
        case 0: return unknownIconSmall
        default: return nil
        }
    }
    
    // Helper to get icon name for attendance
    private func getAttendanceIconName(status: String) -> String? {
        switch status {
        case sawAllStatus: return sawAllIcon
        case sawSomeStatus: return sawSomeIcon
        case sawNoneStatus: return nil // No icon for "won't attend"
        default: return nil
        }
    }
    
    func showLongPressMenu(bandName: String, cellDataText: String?, indexPath: IndexPath, presentingFrom: UIViewController? = nil, sourcePointInWindow: CGPoint? = nil) {
        // Get current priority
        let currentPriority = priorityManager.getPriority(for: bandName)
        
        // Determine if this is a scheduled event
        var isScheduledEvent = false
        var cellBandName = ""
        var cellLocation = ""
        var cellEventType = ""
        var cellStartTime = ""
        var currentAttendedStatus = ""
        
        if let cellData = cellDataText, !cellData.isEmpty {
            let cellDataArray = cellData.split(separator: ";")
            if cellDataArray.count == 4 {
                isScheduledEvent = true
                cellBandName = String(cellDataArray[0])
                cellLocation = String(cellDataArray[1])
                cellEventType = String(cellDataArray[2])
                cellStartTime = String(cellDataArray[3])
                
                currentAttendedStatus = attendedHandle.getShowAttendedStatus(
                    band: cellBandName,
                    location: cellLocation,
                    startTime: cellStartTime,
                    eventType: cellEventType,
                    eventYearString: String(eventYear)
                )
            }
        }
        
        // Build priority section
        var priorityItems: [CompactActionSheetViewController.MenuItem] = []
        
        let mustSeeTitle = NSLocalizedString("Must", comment: "Must see priority")
        priorityItems.append(CompactActionSheetViewController.MenuItem(
            title: mustSeeTitle,
            iconName: getPriorityIconName(priority: 1),
            isSelected: currentPriority == 1,
            action: { [weak self] in
                self?.priorityManager.setPriority(for: bandName, priority: 1)
                self?.refreshBandListOnly(reason: "Priority changed to Must See")
                self?.refreshIPadDetailViewIfNeeded(for: bandName)
                self?.refreshLandscapeScheduleViewIfNeeded(for: bandName)
            }
        ))
        
        let mightSeeTitle = NSLocalizedString("Might", comment: "Might see priority")
        priorityItems.append(CompactActionSheetViewController.MenuItem(
            title: mightSeeTitle,
            iconName: getPriorityIconName(priority: 2),
            isSelected: currentPriority == 2,
            action: { [weak self] in
                self?.priorityManager.setPriority(for: bandName, priority: 2)
                self?.refreshBandListOnly(reason: "Priority changed to Might See")
                self?.refreshIPadDetailViewIfNeeded(for: bandName)
                self?.refreshLandscapeScheduleViewIfNeeded(for: bandName)
            }
        ))
        
        let wontSeeTitle = NSLocalizedString("Wont", comment: "Won't see priority")
        priorityItems.append(CompactActionSheetViewController.MenuItem(
            title: wontSeeTitle,
            iconName: getPriorityIconName(priority: 3),
            isSelected: currentPriority == 3,
            action: { [weak self] in
                self?.priorityManager.setPriority(for: bandName, priority: 3)
                self?.refreshBandListOnly(reason: "Priority changed to Won't See")
                self?.refreshIPadDetailViewIfNeeded(for: bandName)
                self?.refreshLandscapeScheduleViewIfNeeded(for: bandName)
            }
        ))
        
        let unknownTitle = NSLocalizedString("Unknown", comment: "Unknown priority")
        priorityItems.append(CompactActionSheetViewController.MenuItem(
            title: unknownTitle,
            iconName: getPriorityIconName(priority: 0),
            isSelected: currentPriority == 0,
            action: { [weak self] in
                self?.priorityManager.setPriority(for: bandName, priority: 0)
                self?.refreshBandListOnly(reason: "Priority changed to Unknown")
                self?.refreshIPadDetailViewIfNeeded(for: bandName)
                self?.refreshLandscapeScheduleViewIfNeeded(for: bandName)
            }
        ))
        
        var sections: [CompactActionSheetViewController.MenuSection] = [
            CompactActionSheetViewController.MenuSection(
                header: NSLocalizedString("Band Priority", comment: "Band priority section header"),
                items: priorityItems
            )
        ]
        
        // If this is a scheduled event, add attendance section
        if isScheduledEvent {
            // Capture cellDataText explicitly to ensure it's available in closures
            guard let capturedCellDataText = cellDataText else {
                // Should not happen since isScheduledEvent is true, but safety check
                print("ERROR: cellDataText is nil but isScheduledEvent is true")
                return
            }
            
            var attendanceItems: [CompactActionSheetViewController.MenuItem] = []
            
            // Capture status constants explicitly to ensure they're available
            let sawAllStatusValue = sawAllStatus
            let sawSomeStatusValue = sawSomeStatus
            let sawNoneStatusValue = sawNoneStatus
            
            let allOfEventTitle = NSLocalizedString("EventAttendanceAll", comment: "Event attendance: All")
            attendanceItems.append(CompactActionSheetViewController.MenuItem(
                title: allOfEventTitle,
                iconName: getAttendanceIconName(status: sawAllStatusValue),
                isSelected: currentAttendedStatus == sawAllStatusValue,
            action: { [weak self] in
                guard let self = self else { return }
                self.markAttendingStatus(cellDataText: capturedCellDataText, status: sawAllStatusValue, correctBandName: bandName)
                self.refreshLandscapeScheduleViewIfNeeded(for: bandName)
            }
            ))
            
            let partOfEventTitle = NSLocalizedString("EventAttendancePartial", comment: "Event attendance: Partial")
            attendanceItems.append(CompactActionSheetViewController.MenuItem(
                title: partOfEventTitle,
                iconName: getAttendanceIconName(status: sawSomeStatusValue),
                isSelected: currentAttendedStatus == sawSomeStatusValue,
                action: { [weak self] in
                    guard let self = self else { return }
                    self.markAttendingStatus(cellDataText: capturedCellDataText, status: sawSomeStatusValue, correctBandName: bandName)
                    self.refreshLandscapeScheduleViewIfNeeded(for: bandName)
                }
            ))
            
            let noneOfEventTitle = NSLocalizedString("EventAttendanceNone", comment: "Event attendance: None")
            attendanceItems.append(CompactActionSheetViewController.MenuItem(
                title: noneOfEventTitle,
                iconName: nil,
                isSelected: currentAttendedStatus == sawNoneStatusValue,
                action: { [weak self] in
                    guard let self = self else { return }
                    self.markAttendingStatus(cellDataText: capturedCellDataText, status: sawNoneStatusValue, correctBandName: bandName)
                    self.refreshLandscapeScheduleViewIfNeeded(for: bandName)
                }
            ))
            
            sections.append(CompactActionSheetViewController.MenuSection(
                header: NSLocalizedString("Event Attendance", comment: "Event attendance section header"),
                items: attendanceItems
            ))
        }
        
        // Present from the specified view controller, or self if not specified
        // Pass source point only when presenting from list (so menu appears near tap); calendar/landscape keeps bottom-anchored
        let presentingVC = presentingFrom ?? self
        let useSourcePoint = (presentingFrom == nil || presentingFrom === self) ? sourcePointInWindow : nil
        CompactActionSheetViewController.present(
            from: presentingVC,
            title: bandName,
            sections: sections,
            sourcePointInWindow: useSourcePoint
        )
    }
    
    func markAttendingStatus (cellDataText :String, status: String, correctBandName: String? = nil){
        
        var cellData = cellDataText.split(separator: ";")
        if (cellData.count == 4){
            print ("Cell data is we have data for \(cellData[3])");
            
            let cellBandName = String(cellData[0])
            let cellLocation = String(cellData[1])
            let cellEventType  = String(cellData[2])
            let cellStartTime = String(cellData[3])
            
            let allEvents = DataManager.shared.fetchEvents(forYear: eventYear)
            attendedHandle.addShowsAttendedWithStatus(band: cellBandName, location: cellLocation, startTime: cellStartTime, eventType: cellEventType, eventYearString: String(eventYear), status: status, allEventsForYear: allEvents);
            
            let empty : UITextField = UITextField();
            let message = attendedHandle.setShowsAttendedStatus(empty, status: status)
            
            isLoadingBandData = false
            self.refreshBandListOnly(reason: "Show attendance status changed")
            
            // Refresh iPad detail view if this band is currently displayed
            let bandNameForRefresh = correctBandName ?? getNameFromSortable(cellBandName, sortedBy: sortedBy)
            print("DEBUG: Action sheet - cellBandName from data: '\(cellBandName)', correctBandName: '\(correctBandName ?? "nil")', final: '\(bandNameForRefresh)'")
            print("DEBUG: Action sheet - calling refreshIPadDetailViewIfNeeded for band: '\(bandNameForRefresh)'")
            self.refreshIPadDetailViewIfNeeded(for: bandNameForRefresh)
            
            print ("Cell data is marked show attended \(message)");
            
        }
        
    }
    
    func resortBandsByTime(){
        // Move data loading to background to avoid GUI blocking
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            self.schedule.getCachedData()
        }
    }
    
    func resortBands() {
        
        var message = "";
        if (sortedBy == "time"){
            message = NSLocalizedString("Sorting Chronologically", comment: "")
            
        } else {
            message = NSLocalizedString("Sorting Alphabetically", comment: "")
        }
        setSortedBy(sortedBy)
        
        if #available(iOS 16.0, *) {
            let origin = self.effectiveFilterButton?.frame.origin ?? .zero
            let visibleLocation = CGRect(origin: origin, size: self.mainTableView.bounds.size)
            ToastMessages(message).show(self, cellLocation: visibleLocation,  placeHigh: true)
        } else {
            // Fallback on earlier versions
        }
        
        ensureCorrectSorting()
        updateCountLable()

        self.tableView.reloadData()

        
    }
    
    //iCloud data loading
    @objc func onSettingsChanged(_ notification: Notification) {
        //iCloudDataHandle.writeiCloudData(dataHandle: dataHandle, attendedHandle: attendedHandle)
    }
    
    // MARK: - iPad Auto-Selection
    
    func autoSelectFirstBandForIPad() {
        guard isSplitViewCapable() else { return }
        guard !bands.isEmpty else {
            print("DEBUG: No bands available for auto-selection")
            return
        }
        
        let firstBandEntry = bands[0]
        let sortedBy = getSortedBy()
        let firstBandName = getNameFromSortable(firstBandEntry, sortedBy: sortedBy)
        
        print("DEBUG: Auto-selecting first band for iPad - entry: '\(firstBandEntry)', clean name: '\(firstBandName)'")
        let indexPath = IndexPath(row: 0, section: 0)
        
        // Select the first row in the table
        tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        
        // Navigate to the first band (use clean band name)
        goToDetailsScreenSwiftUI(bandName: firstBandName, indexPath: indexPath)
    }
    
    func autoSelectFirstValidBandForIPad() {
        guard isSplitViewCapable() else { return }
        guard !bands.isEmpty else {
            print("DEBUG: No bands available for auto-selection")
            return
        }
        
        // Prevent multiple auto-selections
        guard !hasAutoSelectedForIPad else {
            print("DEBUG: Auto-selection already performed, skipping")
            return
        }
        
        print("DEBUG: Starting auto-selection for iPad")
        hasAutoSelectedForIPad = true
        
        // Find first band that is not a Cruise Organized event
        var selectedIndex = 0
        let sortedBy = getSortedBy()
        
        for (index, bandEntry) in bands.enumerated() {
            let bandName = getNameFromSortable(bandEntry, sortedBy: sortedBy)
            
            // Check if this band has any Cruise Organized events
            if !isCruiseOrganizedEvent(bandEntry: bandEntry, bandName: bandName) {
                selectedIndex = index
                break
            }
            
            print("DEBUG: Skipping Cruise Organized event at index \(index): \(bandName)")
        }
        
        if selectedIndex < bands.count {
            let selectedBandEntry = bands[selectedIndex]
            let selectedBandName = getNameFromSortable(selectedBandEntry, sortedBy: sortedBy)
            let indexPath = IndexPath(row: selectedIndex, section: 0)
            
            print("DEBUG: Auto-selecting first valid band for iPad at index \(selectedIndex): \(selectedBandName)")
            
            // Select the row in the table
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            
            // Navigate to the selected band (use the clean band name, not the full entry)
            print("DEBUG: About to navigate to SwiftUI detail view for: \(selectedBandName)")
            print("DEBUG: selectedBandEntry (raw): '\(selectedBandEntry)', selectedBandName (clean): '\(selectedBandName)'")
            goToDetailsScreenSwiftUI(bandName: selectedBandName, indexPath: indexPath)
            print("DEBUG: Navigation to SwiftUI detail view completed")
        } else {
            print("DEBUG: All entries are Cruise Organized events, selecting first one anyway")
            autoSelectFirstBandForIPad()
        }
    }
    
    private func isCruiseOrganizedEvent(bandEntry: String, bandName: String) -> Bool {
        // Skip non-band schedule events (like "Mon-Monday Metal Madness", "Tue-Live Concert Event")
        if bandName.contains("-") && (bandName.contains("Mon-") || bandName.contains("Tue-") || bandName.contains("Wed-") || bandName.contains("Thu-") || bandName.contains("Fri-") || bandName.contains("Sat-") || bandName.contains("Sun-")) {
            print("DEBUG: Skipping schedule event: \(bandName)")
            return true
        }
        
        // Check if this band only has Cruise Organized events
        schedule.getCachedData()
        
        guard let bandSchedule = schedule.schedulingData[bandName], !bandSchedule.isEmpty else {
            // If no schedule data, assume it's a regular band
            return false
        }
        
        // Check if ALL events for this band are Cruise Organized
        // bandSchedule is [TimeInterval : [String : String]]
        // Each value is a dictionary containing event details
        let allEventTypes = bandSchedule.values.compactMap { eventDict -> String? in
            return eventDict[typeField] // typeField should contain the event type
        }
        
        // If all events are "Cruiser Organized", skip this band
        let cruiseOrganizedCount = allEventTypes.filter { $0 == "Cruiser Organized" || $0 == "Cruise Organized" }.count
        let isCruiseOnly = cruiseOrganizedCount > 0 && cruiseOrganizedCount == allEventTypes.count
        
        if isCruiseOnly {
            print("DEBUG: Band \(bandName) has only Cruise Organized events (\(cruiseOrganizedCount)/\(allEventTypes.count))")
        }
        
        return isCruiseOnly
    }
    
    func refreshIPadDetailViewIfNeeded(for bandName: String) {
        print("DEBUG: refreshIPadDetailViewIfNeeded called for band: '\(bandName)'")
        
        guard isSplitViewCapable() else {
            return
        }
        
        // Check if the detail view is currently showing this band
        guard let splitVC = splitViewController else {
            print("DEBUG: No split view controller found")
            return
        }
        
        guard let detailNavController = splitVC.viewControllers.last as? UINavigationController else {
            print("DEBUG: No detail navigation controller found")
            return
        }
        
        guard let detailHostingController = detailNavController.topViewController as? DetailHostingController else {
            print("DEBUG: No DetailHostingController found, current controller: \(type(of: detailNavController.topViewController))")
            return
        }
        
        let currentBandName = detailHostingController.getCurrentBandName()
        print("DEBUG: Current detail view band: '\(currentBandName)', requested refresh for: '\(bandName)'")
        print("DEBUG: Band name comparison - current: '\(currentBandName)', requested: '\(bandName)', equal: \(currentBandName == bandName)")
        
        // Check if this is the same band currently displayed
        if currentBandName == bandName {
            print("DEBUG: Band matches, refreshing iPad detail view for band: \(bandName)")
            // Trigger a data refresh which will reload priority and other data
            detailHostingController.refreshDetailData()
        } else {
            print("DEBUG: Band doesn't match, not refreshing")
        }
    }
    
    // MARK: - Segue Handling
    // Note: prepare(for:sender:) is already implemented elsewhere in this class
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        print("🔍 shouldPerformSegue called with identifier: \(identifier)")
        
        if identifier == "showDetail" {
            // showDetail segue has been replaced with SwiftUI navigation
            return false
        }
        
        print("🔄 Allowing segue to proceed normally")
        return super.shouldPerformSegue(withIdentifier: identifier, sender: sender)
    }
    
    private func showSwiftUIPreferences() {
        print("🎯 Showing SwiftUI preferences screen")
        
        // Use the reliable PreferencesHostingController approach
        let preferencesController = PreferencesHostingController()
        
        if DeviceSizeManager.isLargeDisplay() {
            preferencesController.modalPresentationStyle = .formSheet
            // Increased height to accommodate all sections without scrolling
            // Based on actual content: Expired(~80), Attended(~80), Alerts(~450), Details(~80), Misc(~150), Navigation(~70), Padding(~40) = ~950
            // Adding extra buffer for safe area and spacing
            preferencesController.preferredContentSize = CGSize(width: 540, height: 1000)
            
            // Present from the split view controller to center it properly
            if let splitVC = splitViewController {
                splitVC.present(preferencesController, animated: true)
            } else {
                present(preferencesController, animated: true)
            }
        } else {
            // For iPhone, use navigation push
            navigationController?.pushViewController(preferencesController, animated: true)
        }
    }
    

    
    // Add an IBAction method that we can connect directly to the gear button
    @IBAction func preferencesButtonTapped(_ sender: Any) {
        print("🎯 Preferences button tapped directly!")
        showSwiftUIPreferences()
    }

    /// APPLE CENSORSHIP COMPLIANCE: Processes HTML to remove "Android" and "iOS" text from platform rows.
    /// Apple has banned the use of the word "Android" anywhere in any approved iOS app.
    /// This is an Apple censorship requirement - we must remove any "Android" text
    /// from the stats report HTML before saving it to the filesystem.
    /// Failure to comply would result in App Store rejection.
    /// Simple, aggressive string replacement - replaces text anywhere it appears.
    private func processStatsHtmlForAppleCompliance(_ htmlString: String) -> String {
        var processed = htmlString
        
        // Count occurrences before replacement
        let androidCountBefore = processed.components(separatedBy: "Android").count - 1
        let iosCountBefore = processed.components(separatedBy: "iOS").count - 1
        
        print("🔍 [STATS_PROCESS] Before: Android appears \(androidCountBefore) times, iOS appears \(iosCountBefore) times")
        
        // AGGRESSIVE REPLACEMENT: Replace "Android" and "iOS" text anywhere they appear after the emoji
        processed = processed.replacingOccurrences(of: "🤖 Android", with: "🤖 ")
        processed = processed.replacingOccurrences(of: "🤖 android", with: "🤖 ")
        processed = processed.replacingOccurrences(of: "🤖 ANDROID", with: "🤖 ")
        processed = processed.replacingOccurrences(of: "🍎 iOS", with: "🍎 ")
        processed = processed.replacingOccurrences(of: "🍎 ios", with: "🍎 ")
        processed = processed.replacingOccurrences(of: "🍎 IOS", with: "🍎 ")
        
        // Also try with HTML structure (most common case)
        processed = processed.replacingOccurrences(of: "<tr><td>🤖 Android</td>", with: "<tr><td>🤖 </td>")
        processed = processed.replacingOccurrences(of: "<tr><td>🤖 android</td>", with: "<tr><td>🤖 </td>")
        processed = processed.replacingOccurrences(of: "<tr><td>🍎 iOS</td>", with: "<tr><td>🍎 </td>")
        processed = processed.replacingOccurrences(of: "<tr><td>🍎 ios</td>", with: "<tr><td>🍎 </td>")
        
        // Count occurrences after replacement
        let androidCountAfter = processed.components(separatedBy: "Android").count - 1
        let iosCountAfter = processed.components(separatedBy: "iOS").count - 1
        
        print("🔍 [STATS_PROCESS] After: Android appears \(androidCountAfter) times, iOS appears \(iosCountAfter) times")
        
        if androidCountBefore > 0 && androidCountAfter == 0 {
            print("✅ [STATS_PROCESS] Successfully removed all Android text")
        } else if androidCountAfter > 0 {
            print("⚠️ [STATS_PROCESS] WARNING: Android still appears \(androidCountAfter) times!")
        }
        
        if iosCountBefore > 0 && iosCountAfter == 0 {
            print("✅ [STATS_PROCESS] Successfully removed all iOS text")
        } else if iosCountAfter > 0 {
            print("⚠️ [STATS_PROCESS] WARNING: iOS still appears \(iosCountAfter) times!")
        }
        
        return processed
    }
    
    @objc @IBAction func statsButtonTapped(_ sender: Any) {
        let fileManager = FileManager.default
        guard let documentsUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            let title = NSLocalizedString("Error", comment: "Error alert title")
            let message = NSLocalizedString("Could not access documents directory.", comment: "Error message when documents directory cannot be accessed")
            showAlert(title, message: message)
            return
        }
        let fileUrl = documentsUrl.appendingPathComponent("stats.html")

        // Check if we already have a web view controller displayed
        let currentWebViewController = getCurrentWebViewController()
        let fileExists = fileManager.fileExists(atPath: fileUrl.path)
        
        // Only present the web view if we don't already have one
        if currentWebViewController == nil {
            print("🎯 [STATS_DEBUG] Presenting WebView with file URL: \(fileUrl.absoluteString)")
            print("🎯 [STATS_DEBUG] File exists: \(fileExists)")
            presentWebView(url: fileUrl.absoluteString, isLoading: !fileExists)
        }

        // Then attempt to download new content and refresh the view
        if Reachability.isConnectedToNetwork() {
            // Get the report URL on a background thread to avoid main thread blocking
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                let dynamicStatsUrl = getPointerUrlData(keyValue: "reportUrl")
                print("[YEAR_CHANGE_DEBUG] statsButtonTapped: Retrieved reportUrl: \(dynamicStatsUrl)")
                
                if let url = URL(string: dynamicStatsUrl), !dynamicStatsUrl.isEmpty {
                let task = URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
                    guard let self = self else { return }
                    
                    if let data = data {
                        do {
                            // Convert downloaded data to string
                            guard let htmlString = String(data: data, encoding: .utf8) else {
                                print("❌ [STATS] Failed to decode HTML data as UTF-8")
                                if !fileExists {
                                    DispatchQueue.main.async {
                                        self.presentNoDataView(message: "Could not decode stats file.")
                                    }
                                }
                                return
                            }
                            
                            print("📥 [STATS] Downloaded \(data.count) bytes, processing for Apple compliance...")
                            
                            // APPLE CENSORSHIP COMPLIANCE:
                            // Apple has banned the use of the word "Android" anywhere in any approved iOS app.
                            // This is an Apple censorship requirement - we must remove any "Android" text
                            // from the downloaded stats report HTML before saving it to the filesystem.
                            // Failure to comply would result in App Store rejection.
                            let processedHtml = self.processStatsHtmlForAppleCompliance(htmlString)
                            
                            // Convert processed HTML back to data and write to file
                            guard let processedData = processedHtml.data(using: .utf8) else {
                                print("❌ [STATS] Failed to encode processed HTML as UTF-8")
                                if !fileExists {
                                    DispatchQueue.main.async {
                                        self.presentNoDataView(message: "Could not process stats file.")
                                    }
                                }
                                return
                            }
                            
                            try processedData.write(to: fileUrl)
                            print("✅ [STATS] Stats file saved successfully (platform names removed)")
                            
                            // Refresh the currently displayed web view if it exists
                            DispatchQueue.main.async {
                                print("🔄 [STATS_REFRESH] Background download complete, attempting to refresh web view")
                                if let currentWebViewController = self.getCurrentWebViewController(),
                                   let webDisplay = currentWebViewController.webDisplay {
                                    print("🔄 [STATS_REFRESH] ✅ Found web view controller, refreshing with new content")
                                    let request = URLRequest(url: fileUrl)
                                    webDisplay.load(request)
                                } else {
                                    print("🔄 [STATS_REFRESH] ❌ No web view controller found to refresh")
                                    print("🔄 [STATS_REFRESH] getCurrentWebViewController() returned: \(self.getCurrentWebViewController() != nil ? "not nil" : "nil")")
                                }
                            }
                        } catch {
                            // Only show error if we didn't already show cached content
                            if !fileExists {
                                DispatchQueue.main.async {
                                    self.presentNoDataView(message: "Could not save stats file.")
                                }
                            }
                        }
                    } else {
                        // Only show error if we didn't already show cached content
                        if !fileExists {
                            DispatchQueue.main.async {
                                self.presentNoDataView(message: "Could not download stats data.")
                            }
                        }
                    }
                }
                    task.resume()
                } else {
                    print("Invalid stats URL: \(dynamicStatsUrl)")
                    DispatchQueue.main.async {
                        self.presentNoDataView(message: "Could not get stats URL from server.")
                    }
                }
            }
        } else if !fileExists {
            // Only show no data message if there's no cached file
            presentNoDataView(message: "No stats data available. Please connect to the internet to download stats.")
        }
    }
    
    // Helper function to get the current web view controller if it's displayed
    func getCurrentWebViewController() -> WebViewController? {
        if isSplitViewCapable() {
            if let splitViewController = self.splitViewController,
               let detailNavigationController = splitViewController.viewControllers.last as? UINavigationController,
               let webViewController = detailNavigationController.topViewController as? WebViewController {
                return webViewController
            }
        } else {
            if let webViewController = self.navigationController?.topViewController as? WebViewController {
                return webViewController
            }
        }
        return nil
    }
    
    func presentNoDataView(message: String) {
        DispatchQueue.main.async {
            if let webViewController = self.storyboard?.instantiateViewController(withIdentifier: "StatsWebViewController") as? WebViewController {
                // Create HTML content with app's color scheme
                let htmlContent = """
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="UTF-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>No Stats Data</title>
                    <style>
                        body {
                            background-color: #000000;
                            color: #FFFFFF;
                            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                            display: flex;
                            justify-content: center;
                            align-items: center;
                            height: 100vh;
                            margin: 0;
                            text-align: center;
                        }
                        .container {
                            padding: 40px;
                            max-width: 400px;
                        }
                        .icon {
                            font-size: 64px;
                            margin-bottom: 20px;
                            color: #797D7F;
                        }
                        .title {
                            font-size: 24px;
                            font-weight: bold;
                            margin-bottom: 16px;
                            color: #FFFFFF;
                        }
                        .message {
                            font-size: 16px;
                            line-height: 1.5;
                            color: #CCCCCC;
                            margin-bottom: 24px;
                        }
                        .subtitle {
                            font-size: 14px;
                            color: #797D7F;
                        }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <div class="icon">📊</div>
                        <div class="title">No Stats Data</div>
                        <div class="message">\(message)</div>
                        <div class="subtitle">Stats will be available when you're connected to the internet.</div>
                    </div>
                </body>
                </html>
                """
                
                // Write the HTML content to a temporary file
                let fileManager = FileManager.default
                guard let documentsUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    // Fallback to basic alert if we can't get documents directory
                    let title = NSLocalizedString("No Stats Data", comment: "Alert title when stats data is not available")
                    self.showAlert(title, message: message)
                    return
                }
                let tempUrl = documentsUrl.appendingPathComponent("no_stats.html")
                do {
                    try htmlContent.write(to: tempUrl, atomically: true, encoding: .utf8)
                    setUrl(tempUrl.absoluteString)
                    
                    let backItem = UIBarButtonItem()
                    backItem.title = "Back"

                    if self.isSplitViewCapable() {
                        if let splitViewController = self.splitViewController,
                           let detailNavigationController = splitViewController.viewControllers.last as? UINavigationController {
                            detailNavigationController.topViewController?.navigationItem.backBarButtonItem = backItem
                            detailNavigationController.pushViewController(webViewController, animated: true)
                        }
                    } else {
                        self.navigationItem.backBarButtonItem = backItem
                        self.navigationController?.pushViewController(webViewController, animated: true)
                    }
                } catch {
                    // Fallback to basic alert if HTML creation fails
                    let title = NSLocalizedString("No Stats Data", comment: "Alert title when stats data is not available")
                    self.showAlert(title, message: message)
                }
            }
        }
    }
    
    func presentWebView(url: String, isLoading: Bool = false) {
        DispatchQueue.main.async {
            if let webViewController = self.storyboard?.instantiateViewController(withIdentifier: "StatsWebViewController") as? WebViewController {
                let backItem = UIBarButtonItem()
                backItem.title = "Back"

                if isLoading {
                    // Show a loading HTML page
                    let htmlContent = """
                    <!DOCTYPE html>
                    <html>
                    <head>
                        <meta charset=\"UTF-8\">
                        <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
                        <title>Loading Stats</title>
                        <style>
                            body {
                                background-color: #000000;
                                color: #FFFFFF;
                                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                                display: flex;
                                justify-content: center;
                                align-items: center;
                                height: 100vh;
                                margin: 0;
                                text-align: center;
                            }
                            .container {
                                padding: 40px;
                                max-width: 400px;
                            }
                            .icon {
                                font-size: 64px;
                                margin-bottom: 20px;
                                color: #797D7F;
                            }
                            .title {
                                font-size: 24px;
                                font-weight: bold;
                                margin-bottom: 16px;
                                color: #FFFFFF;
                            }
                            .message {
                                font-size: 16px;
                                line-height: 1.5;
                                color: #CCCCCC;
                                margin-bottom: 24px;
                            }
                        </style>
                    </head>
                    <body>
                        <div class=\"container\">
                            <div class=\"icon\">⏳</div>
                            <div class=\"title\">Loading Stats</div>
                            <div class=\"message\">Please wait while stats are being downloaded...</div>
                        </div>
                    </body>
                    </html>
                    """
                    let fileManager = FileManager.default
                    guard let documentsUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                        // Fallback to basic alert if we can't get documents directory
                        let title = NSLocalizedString("Loading Stats", comment: "Alert title when loading stats")
                        let message = NSLocalizedString("Please wait while stats are being downloaded...", comment: "Message shown while stats are loading")
                        self.showAlert(title, message: message)
                        return
                    }
                    let tempUrl = documentsUrl.appendingPathComponent("loading_stats.html")
                    do {
                        try htmlContent.write(to: tempUrl, atomically: true, encoding: .utf8)
                        setUrl(tempUrl.absoluteString)
                    } catch {
                        // Don't push WebView if we couldn't create the loading page
                        self.showAlert("Loading Stats", message: "Please wait while stats are being downloaded...")
                        return
                    }
                } else {
                    setUrl(url)
                }

                if self.isSplitViewCapable() {
                    if let splitViewController = self.splitViewController,
                       let detailNavigationController = splitViewController.viewControllers.last as? UINavigationController {
                        detailNavigationController.topViewController?.navigationItem.backBarButtonItem = backItem
                        detailNavigationController.pushViewController(webViewController, animated: true)
                    }
                } else {
                    self.navigationItem.backBarButtonItem = backItem
                    self.navigationController?.pushViewController(webViewController, animated: true)
                }
            }
        }
    }
    
    func startScheduleRefreshTimer() {
        stopScheduleRefreshTimer()
        scheduleRefreshTimer = Timer.scheduledTimer(withTimeInterval: scheduleDownloadInterval, repeats: true) { [weak self] _ in
            self?.refreshDataWithBackgroundUpdate(reason: "Scheduled timer refresh")
        }
    }
    
    func stopScheduleRefreshTimer() {
        scheduleRefreshTimer?.invalidate()
        scheduleRefreshTimer = nil
    }
    
    func shouldDownloadSchedule(force: Bool = false) -> Bool {
        // Delegate to ViewModel
        return viewModel.shouldDownloadSchedule(force: force)
    }
    
    @objc func handlePushNotificationReceived() {
        // Move to background to prevent GUI blocking when handling push notifications
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.refreshDataWithBackgroundUpdate(reason: "Push notification received")
        }
    }
    
    // App foreground handling moved to AppDelegate for global application-level handling
    
    /// Clears all cached data arrays in MasterViewController - should be called during year changes
    /// This method should only be called when we're ready to immediately populate the arrays with new data
    func clearMasterViewCachedData() {
        // Delegate to CacheManager
        cacheManager.clearMasterViewCachedData(
            objects: &objects,
            bandsByTime: &bandsByTime,
            bandsByName: &bandsByName
        )
    }
    
    /// Safely clears and repopulates the bands array atomically
    func safelyUpdateBandsArray(_ newBands: [String]) {
        print("[YEAR_CHANGE_DEBUG] Safely updating bands array from \(bands.count) to \(newBands.count) items")
        
        // Update the bands array
        bands = newBands
        
        // Immediately reload the table view to ensure consistency
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    @objc func detailDidUpdate() {
        // PERFORMANCE FIX: DetailDidUpdate should ONLY refresh from cache, never trigger network
        // This handles priority changes, attendance changes, and notes changes from detail screen
        print("[MasterViewController] DetailDidUpdate: Cache-only refresh for priority/attendance/notes changes")
        
        // Refresh UI using only cached data (no background network operations)
        DispatchQueue.main.async {
            self.refreshBandList(reason: "Detail screen update - cache only")
        }
    }
    
    @objc func handleDetailScreenDismissing(notification: Notification) {
        // When detail screen is dismissing, check orientation and show appropriate view
        // This handles the case where user rotates in detail screen, then exits detail screen
        print("🔄 [LANDSCAPE_SCHEDULE] Detail screen dismissing, checking orientation for appropriate view")
        
        // CRITICAL FIX: For iPhone, check immediately and again after delay to catch portrait mode
        // This ensures we dismiss landscape view if user exited detail in portrait
        guard !isSplitViewCapable() else {
            // iPad: Use delayed check only (handled below)
            // Use a small delay to ensure detail screen dismissal animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.handleDetailScreenDismissingDelayed()
            }
            return
        }
        
        // iPhone: Check immediately for portrait mode
        checkAndDismissLandscapeIfPortrait()
        
        // Also check after delay to catch any timing issues
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.handleDetailScreenDismissingDelayed()
        }
    }
    
    private func checkAndDismissLandscapeIfPortrait() {
        guard !isSplitViewCapable() && isShowingLandscapeSchedule else {
            return
        }
        
        // Get main window for accurate bounds
        let mainWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? view.window
        
        let windowBounds = mainWindow?.bounds ?? view.bounds
        let windowBoundsLandscape = windowBounds.width > windowBounds.height
        let viewBoundsLandscape = view.bounds.width > view.bounds.height
        let statusBarLandscape = UIApplication.shared.statusBarOrientation.isLandscape
        let deviceOrientationLandscape = UIDevice.current.orientation.isLandscape
        
        // Prioritize device orientation and status bar
        let isLandscape: Bool
        if !statusBarLandscape && !deviceOrientationLandscape {
            isLandscape = false
        } else if statusBarLandscape || deviceOrientationLandscape {
            isLandscape = true
        } else {
            isLandscape = windowBoundsLandscape || viewBoundsLandscape
        }
        
        if !isLandscape {
            print("🚫 [LANDSCAPE_SCHEDULE] iPhone in portrait after detail dismissal (immediate check) - dismissing calendar view")
            dismissLandscapeScheduleView()
        }
    }
    
    private func handleDetailScreenDismissingDelayed() {
        // CRITICAL FIX: For iPad (master/detail), preserve the view state we left from
        // Don't change based on orientation - use isManualCalendarView to restore state
        if self.isSplitViewCapable() {
                // iPad: Restore the view state based on manual toggle, not orientation
                if self.isManualCalendarView {
                    // User was in calendar mode - restore calendar view
                    if !self.isShowingLandscapeSchedule {
                        print("📱 [IPAD_TOGGLE] Restoring calendar view after detail dismissal (was in calendar mode)")
                        self.updateCurrentViewingDayFromVisibleCells()
                        self.presentLandscapeScheduleView()
                    } else {
                        print("📱 [IPAD_TOGGLE] Calendar view already showing after detail dismissal")
                    }
                } else {
                    // User was in list mode - ensure list view is showing
                    if self.isShowingLandscapeSchedule {
                        print("📱 [IPAD_TOGGLE] Dismissing calendar view after detail dismissal (was in list mode)")
                        self.dismissLandscapeScheduleView()
                    } else {
                        print("📱 [IPAD_TOGGLE] List view already showing after detail dismissal")
                    }
                }
                return // Exit early - iPad behavior handled above
        }
        
        // iPhone: Use orientation-based logic (existing behavior)
        // CRITICAL FIX: Use comprehensive orientation check to reliably detect portrait mode
        // Get main window (not landscape view controller's window) for accurate bounds
        let mainWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? self.view.window
        
        let windowBounds = mainWindow?.bounds ?? self.view.bounds
        let windowBoundsLandscape = windowBounds.width > windowBounds.height
        let viewBoundsLandscape = self.view.bounds.width > self.view.bounds.height
        let statusBarLandscape = UIApplication.shared.statusBarOrientation.isLandscape
        let deviceOrientationLandscape = UIDevice.current.orientation.isLandscape
        
        // CRITICAL: Prioritize device orientation and status bar over window bounds
        // If device/statusBar say portrait, trust them (more reliable than window bounds)
        let isLandscape: Bool
        if !statusBarLandscape && !deviceOrientationLandscape {
            // Both device and statusBar say portrait - trust them, ignore window bounds
            isLandscape = false
        } else if statusBarLandscape || deviceOrientationLandscape {
            // Device or statusBar say landscape - trust them
            isLandscape = true
        } else {
            // Fallback to window bounds if device/statusBar are unknown
            isLandscape = windowBoundsLandscape || viewBoundsLandscape
        }
        
        print("🔄 [LANDSCAPE_SCHEDULE] Detail dismissal orientation check (delayed) - windowBounds: \(windowBoundsLandscape) (w:\(windowBounds.width) h:\(windowBounds.height)), viewBounds: \(viewBoundsLandscape), statusBar: \(statusBarLandscape), device: \(deviceOrientationLandscape), isLandscape: \(isLandscape)")
        
        // Check if landscape view is still showing (it should be, since detail was presented from it)
        if self.isShowingLandscapeSchedule {
            // CRITICAL FIX: iPhone in portrait mode should NEVER show calendar mode
            // If we're on iPhone (not iPad) and in portrait, always dismiss calendar view
            if !isLandscape {
                // iPhone in portrait - MUST dismiss calendar view
                print("🚫 [LANDSCAPE_SCHEDULE] iPhone in portrait after detail dismissal (delayed check) - dismissing calendar view (portrait mode never shows calendar)")
                self.dismissLandscapeScheduleView()
            } else {
                // Still in landscape - keep calendar view
                print("🔄 [LANDSCAPE_SCHEDULE] Still in landscape after detail dismissal (delayed check) - keeping calendar view")
                // Landscape view should already be showing, no action needed
            }
        }
    }
    
    @objc func iCloudDataReadyHandler() {
        print("iCloud data ready, forcing reload of all caches and band file.")
        
        // CRITICAL FIX: Force completion of any existing refresh to allow iCloud data to be displayed
        if MasterViewController.isRefreshingBandList {
            print("🔄 iCloudDataReadyHandler: Forcing completion of existing refresh to allow iCloud data display")
            MasterViewController.isRefreshingBandList = false
            MasterViewController.refreshBandListSafetyTimer?.invalidate()
            MasterViewController.refreshBandListSafetyTimer = nil
        }
        
        // Move all data loading to background to avoid GUI blocking
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.bandNameHandle.readBandFile()
            // Priority data now handled by SQLitePriorityManager
            self.attendedHandle.getCachedData()
            self.schedule.getCachedData()
            
            DispatchQueue.main.async {
                print("🔄 iCloudDataReadyHandler: Bypassing refresh blocking to force UI update with iCloud data")
                
                // CRITICAL FIX: Directly call the refresh logic without going through refreshBandList
                // This bypasses the isRefreshingBandList check entirely
                self.forceRefreshWithiCloudData()
            }
        }
    }
    
    /// Forces a refresh specifically for iCloud data restoration, bypassing all blocking logic
    private func forceRefreshWithiCloudData() {
        print("🔄 forceRefreshWithiCloudData: Starting forced refresh for iCloud data display")
        
        // Save the current scroll position
        let previousOffset = self.tableView.contentOffset
        
        // Force refresh the display without any blocking checks
        // Get current bands and pass them to safelyMergeBandData
        let currentBands = self.bands
        self.safelyMergeBandData(currentBands, reason: "iCloud data restoration - forced refresh")
        
        // Restore scroll position
        self.tableView.setContentOffset(previousOffset, animated: false)
        
        print("🔄 forceRefreshWithiCloudData: Completed forced refresh for iCloud data display")
    }
    
    @objc func iCloudAttendedDataRestoredHandler() {
        print("iCloud attended data restored, refreshing display to show updated attended statuses.")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Refresh the band list to show updated attended statuses
            self.refreshBandList(reason: "iCloud attended data restored")
        }
    }
    
    @objc func handleiCloudLoadingStarted() {
        print("iCloud: Loading started - showing progress indicator")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Ensure view is loaded before accessing outlets
            guard self.isViewLoaded else {
                print("iCloud: Warning - view not loaded yet, skipping UI updates")
                return
            }
            
            // Show loading indicator (with nil check)
            if let indicator = self.blankScreenActivityIndicator {
                indicator.startAnimating()
            } else {
                print("iCloud: Warning - blankScreenActivityIndicator is nil")
            }
            
            // CRITICAL: Don't set navigationItem.title - it will override titleView
            // Instead, keep the existing titleView or update it
            // self.navigationItem.title = "Loading iCloud Data..."  // REMOVED - this hides titleView
            // TitleView will show the current count, which is fine during loading
        }
    }
    
    @objc func handleiCloudLoadingCompleted() {
        print("iCloud: Loading completed - hiding progress indicator")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Ensure view is loaded before accessing outlets
            guard self.isViewLoaded else {
                print("iCloud: Warning - view not loaded yet, skipping UI updates")
                return
            }
            
            // Hide loading indicator (with nil check)
            if let indicator = self.blankScreenActivityIndicator {
                indicator.stopAnimating()
            } else {
                print("iCloud: Warning - blankScreenActivityIndicator is nil")
            }
            
            // CRITICAL: Don't set navigationItem.title - it will override titleView
            // Instead, ensure titleView is updated via updateCountLable
            // self.navigationItem.title = "70K Bands"  // REMOVED - this hides titleView
            self.updateCountLable()  // Update titleView instead
        }
    }
    
    @objc func handleDataReady() {
        // Ensure refreshBandList is called on main thread to avoid UI access issues
        if Thread.isMainThread {
            self.refreshBandList()
        } else {
            DispatchQueue.main.async {
        self.refreshBandList()
            }
        }
    }
    
    @objc func handlePointerDataUpdated() {
        // This observer is triggered when pointer data is updated on launch.
        // It will force a refresh of the band list to ensure the UI is updated.
        print("Pointer data updated, forcing refresh of band list.")
        MinimumVersionWarningManager.checkAndShowIfNeeded(reason: "PointerDataUpdated (launch pointer refresh)")
        AutoScheduleWizardManager.checkAndShowIfNeeded(reason: "PointerDataUpdated")
        refreshBandList(reason: "Pointer data updated")
    }
    
    @objc func handleBackgroundDataRefresh() {
        print("MasterViewController: Background data refresh triggered from foreground")
        
        // Prevent conflicts with existing data collection processes
        guard !isLoadingBandData, !bandNameHandle.readingBandFile else {
            print("MasterViewController: Skipping background refresh - data collection already in progress")
            return
        }
        
        // Check if we're in the middle of first launch data loading
        guard !cacheVariables.justLaunched || (!bandNameHandle.getBandNames().isEmpty && !schedule.schedulingData.isEmpty) else {
            print("MasterViewController: Skipping background refresh - first launch still in progress")
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            print("MasterViewController: Starting background data refresh from URL")
            
            // Verify internet connection first
            let internetAvailable = NetworkStatusManager.shared.isInternetAvailable
            if !internetAvailable {
                print("MasterViewController: No internet connection available, skipping background refresh")
                return
            }
            
            // Download all data sources first
            let downloadGroup = DispatchGroup()
            var newDataDownloaded = false
            var contentChanged = false
            
            // Step 1: Download artist/band data FIRST
            downloadGroup.enter()
            print("🎸 Step 1: Downloading artist/band data...")
            self.bandNameHandle.getCachedData(forceNetwork: true) {
                newDataDownloaded = true
                print("✅ Artist/band data downloaded successfully")
                downloadGroup.leave()
            }
            
            // Step 2: Download schedule data SECOND
            downloadGroup.enter()
            print("📅 Step 2: Downloading schedule data...")
            DispatchQueue.global(qos: .utility).async {
                let shouldDownload = self.shouldDownloadSchedule(force: true)
                if shouldDownload {
                    // Use the proper download method that respects the loading order
                    print("📅 Downloading schedule data using proper sequence...")
                    // Don't force download here - let the proper sequence handle it
                    print("📅 Deferring schedule download to proper loading sequence")
                    // Update both MasterViewController and ViewModel state
                    self.lastScheduleDownload = Date()
                    self.viewModel.updateLastScheduleDownload()
                    newDataDownloaded = true
                    print("✅ Schedule data download deferred to proper sequence")
                }
                self.schedule.populateSchedule(forceDownload: false)
                downloadGroup.leave()
            }
            
            // Wait for data download to complete before proceeding
            downloadGroup.notify(queue: .main) {
                // Step 3: Load existing priority data
                print("⭐ Step 3: Priority data handled by SQLitePriorityManager")
                // Priority data handled by SQLitePriorityManager
                print("✅ Priority data available via SQLite")
                
                // Step 4: Load existing attendance data
                print("✅ Step 4: Loading existing attendance data...")
                self.attendedHandle.loadShowsAttended()
                print("✅ Attendance data loaded")
                
                // Step 5: Load iCloud data (only after SQLite data is available)
                print("☁️ Step 5: Loading iCloud data...")
                self.loadICloudData {
                    print("✅ iCloud data loaded")
                    
                    // Step 6: Load description map (only after SQLite data is available)
                    print("📝 Step 6: Loading description map...")
                    self.bandDescriptions.getDescriptionMapFile()
                    self.bandDescriptions.getDescriptionMap()
                    print("✅ Description map loaded")
                    
                    // Step 7: Load combined image URL map (only after SQLite data is available)
                    print("🖼️ Step 7: Loading combined image URL map...")
                    self.loadCombinedImageList()
                    print("✅ Combined image list loaded")
                    
                    // Now determine if content has changed
                    print("🔍 Determining if content has changed...")
                    
                    if !newDataDownloaded {
                        print("⚠️ Unable to download new data, assuming content has changed")
                        contentChanged = true
                    } else {
                        print("✅ New data downloaded, assuming content has changed")
                        contentChanged = true
                    }
                    
                    if contentChanged {
                        // Clear all caches only if content changed
                        print("🧹 Content changed, clearing all caches")
                        self.clearAllCaches()
                    } else {
                        print("ℹ️ No content changes detected, keeping existing cache")
                    }
                    
                    // Refresh the UI on main thread after background data loading
                    DispatchQueue.main.async {
                        print("📱 Updating UI after background data refresh")
                        self.refreshBandList(reason: "Background data refresh from foreground")
                    }
                }
            }
        }
    }
    
    @objc func handleForegroundRefresh() {
        print("🔄 FOREGROUND-REFRESH: Triggered - using unified refresh system")
        
        // Prevent conflicts with existing data collection processes
        guard !isLoadingBandData, !bandNameHandle.readingBandFile else {
            print("🔄 FOREGROUND-REFRESH: Skipping - data collection already in progress")
            return
        }
        
        // Check if we're in the middle of first launch data loading
        guard !cacheVariables.justLaunched || (!bandNameHandle.getBandNames().isEmpty && !schedule.schedulingData.isEmpty) else {
            print("🔄 FOREGROUND-REFRESH: Skipping - first launch still in progress")
            return
        }
        
        // STEP 1: Load all data from database immediately and display
        print("🔄 FOREGROUND-REFRESH: Step 1 - Loading database data immediately")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Load all data from database (Bands, Events, Priorities, Attended)
            self.cacheManager.loadCachedDataImmediately()
            
            // Display to user on main thread
            DispatchQueue.main.async {
                self.refreshBandList(reason: "Foreground refresh - immediate database display")
            }
        }
        
        // STEP 2: Always launch unified data refresh when returning from background (no throttle).
        // Data refresh is expected on: 1) launch, 2) app brought from background, 3) pull-to-refresh.
        print("🔄 FOREGROUND-REFRESH: Step 2 - Launching unified data refresh (no throttle on foreground return)")
        performUnifiedDataRefresh(reason: "Foreground refresh")
    }
    
    // Helper to deduplicate while preserving order
    private func deduplicatePreservingOrder(_ array: [String]) -> [String] {
        var seen = Set<String>()
        return array.filter { seen.insert($0).inserted }
    }
    
    /// Pre-loads priority data for all bands to improve table view performance
    /// This reduces the number of individual getPriorityData calls during cell configuration
    private func preloadPriorityData() {
        // Get all unique band names (without time indices)
        let uniqueBandNames = bands.compactMap { bandEntry -> String? in
            if bandEntry.contains(":") && bandEntry.components(separatedBy: ":").first?.doubleValue != nil {
                // This is a scheduled event, extract the band name
                return bandEntry.components(separatedBy: ":")[1]
            } else {
                // This is just a band name
                return bandEntry
            }
        }.uniqued()
        
        // Pre-load priority data for all bands in a single operation
        DispatchQueue.global(qos: .utility).async {
            // Pre-load priority data for performance (SQLite handles caching automatically)
            _ = self.priorityManager.getAllPriorities()
        }
    }
    
    /// Performs the background data refresh operations
    internal func performBackgroundDataRefresh(reason: String, endRefreshControl: Bool, shouldScrollToTop: Bool, completion: (() -> Void)? = nil) {
        print("Full data refresh (\(reason)): Step 3 - Starting background process")
        
        // YEAR CHANGE DEADLOCK FIX: Generate unique operation ID and check for year change
        let thisOperationId = UUID()
        let isYearChangeOperation = reason.lowercased().contains("year change")
        
        if isYearChangeOperation {
            print("🚨 [YEAR_CHANGE_DEADLOCK_FIX] Year change operation detected - killing all existing operations")
            cancelAllBackgroundOperations()
            MasterViewController.currentDataRefreshOperationId = thisOperationId
        } else {
            // Check if year change is in progress - if so, abort this operation
            if MasterViewController.isYearChangeInProgress {
                print("🚫 [YEAR_CHANGE_DEADLOCK_FIX] Year change in progress - aborting non-year-change operation: \(reason)")
                DispatchQueue.main.async {
                    if endRefreshControl {
                        self.refreshControl?.endRefreshing()
                    }
                    completion?()
                }
                return
            }
            MasterViewController.currentDataRefreshOperationId = thisOperationId
        }
        
        print("✅ [YEAR_CHANGE_DEADLOCK_FIX] Starting operation: \(thisOperationId.uuidString.prefix(8))")
        
        // Function to check if this operation was cancelled
        func isOperationCancelled() -> Bool {
            let cancelled = MasterViewController.currentDataRefreshOperationId != thisOperationId
            if cancelled {
                print("🚫 [YEAR_CHANGE_DEADLOCK_FIX] Operation \(thisOperationId.uuidString.prefix(8)) was cancelled")
            }
            return cancelled
        }
        
        // 3a. Verify internet connection before proceeding
        print("Full data refresh (\(reason)): Step 3a - Verifying internet connection")
        let internetAvailable = NetworkStatusManager.shared.isInternetAvailable
        if !internetAvailable {
            print("Full data refresh (\(reason)): No internet connection available, skipping data refresh")
            DispatchQueue.main.async {
                if endRefreshControl {
                    self.refreshControl?.endRefreshing()
                }
            }
            return
        }
        print("Full data refresh (\(reason)): Internet connection verified")
        
        // 3b. Download all data from URLs first
        print("Full data refresh (\(reason)): Step 3b - Downloading all data from URLs")
        
        // Use a dispatch group to track when all data loading is complete
        let dataLoadGroup = DispatchGroup()
        var newDataDownloaded = false
        var contentChanged = false
        
        // Download schedule data - SYNCHRONIZED to prevent concurrent downloads
        dataLoadGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            // Check cancellation before proceeding
            guard !isOperationCancelled() else {
                dataLoadGroup.leave()
                return
            }
            
            // CRITICAL: Prevent concurrent CSV downloads
            MasterViewController.backgroundRefreshLock.lock()
            let downloadAllowed = !MasterViewController.isCsvDownloadInProgress
            if downloadAllowed {
                MasterViewController.isCsvDownloadInProgress = true
            }
            MasterViewController.backgroundRefreshLock.unlock()
            
            if !downloadAllowed {
                print("Full data refresh (\(reason)): ❌ CSV download already in progress - skipping duplicate")
                dataLoadGroup.leave()
                return
            }
            
            print("Full data refresh (\(reason)): ✅ Starting CSV download (protected)")
            // Actually download schedule data
            self.schedule.DownloadCsv()
            
            // Mark CSV download as complete
            MasterViewController.backgroundRefreshLock.lock()
            MasterViewController.isCsvDownloadInProgress = false
            MasterViewController.backgroundRefreshLock.unlock()
            
            // Check cancellation after download
            guard !isOperationCancelled() else {
                dataLoadGroup.leave()
                return
            }
            newDataDownloaded = true
            dataLoadGroup.leave()
        }
        
        // Download band names data
        dataLoadGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            // Check cancellation before proceeding
            guard !isOperationCancelled() else {
                dataLoadGroup.leave()
                return
            }
            print("Full data refresh (\(reason)): Downloading band names data")
            // Actually download band names data - pass year change flag for proper coordination
            self.bandNameHandle.gatherData(forceDownload: true, isYearChangeOperation: isYearChangeOperation) {
                // Check cancellation in completion handler
                guard !isOperationCancelled() else {
                    dataLoadGroup.leave()
                    return
                }
                newDataDownloaded = true
                dataLoadGroup.leave()
            }
        }
        
        // Download descriptionMap data
        dataLoadGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            // Check cancellation before proceeding
            guard !isOperationCancelled() else {
                dataLoadGroup.leave()
                return
            }
            print("Full data refresh (\(reason)): Downloading description map data")
            self.bandDescriptions.getDescriptionMapFile()
            self.bandDescriptions.getDescriptionMap()
            // Check cancellation after download
            guard !isOperationCancelled() else {
                dataLoadGroup.leave()
                return
            }
            newDataDownloaded = true
            dataLoadGroup.leave()
        }
        
        // 3c. Once all downloads are complete, determine if content changed and clear caches
        dataLoadGroup.notify(queue: .main) {
            // Final cancellation check before proceeding with UI updates
            guard !isOperationCancelled() else {
                print("🚫 [YEAR_CHANGE_DEADLOCK_FIX] Operation \(thisOperationId.uuidString.prefix(8)) cancelled before UI updates")
                if endRefreshControl {
                    self.refreshControl?.endRefreshing()
                }
                completion?()
                return
            }
            print("Full data refresh (\(reason)): Step 3c - All downloads complete, determining content changes")
            
            // If we couldn't download any new data, assume content has changed to be safe
            if !newDataDownloaded {
                print("Full data refresh (\(reason)): Unable to download new data, assuming content has changed")
                contentChanged = true
            } else {
                // For now, assume content has changed if we successfully downloaded new data
                // In the future, we could implement hash comparison here
                print("Full data refresh (\(reason)): New data downloaded, assuming content has changed")
                contentChanged = true
            }
            
            if contentChanged {
                // 3d. Clear ALL caches comprehensively only if content changed
                print("Full data refresh (\(reason)): Step 3d - Content changed, clearing all caches")
                self.bandNameHandle.clearCachedData()
                // Priority cache clearing handled by SQLitePriorityManager
                self.dataHandle.clearCachedData()
                self.schedule.clearCache()
                
                // Clear MasterViewController cached arrays (but not bands array yet)
                self.clearMasterViewCachedData()
                
                // Clear ALL static cache variables to prevent data mixing
                // cacheVariables setters are thread-safe, no need for sync blocks
                cacheVariables.scheduleStaticCache = [:]
                cacheVariables.scheduleTimeStaticCache = [:]
                cacheVariables.bandNamesStaticCache = [:]
                cacheVariables.bandNamesArrayStaticCache = []
                cacheVariables.bandDescriptionUrlCache = [:]
                cacheVariables.bandDescriptionUrlDateCache = [:]
                cacheVariables.attendedStaticCache = [:]
                cacheVariables.lastModifiedDate = nil
                
                // Clear CustomBandDescription instance caches
                self.bandDescriptions.bandDescriptionUrl.removeAll()
                self.bandDescriptions.bandDescriptionUrlDate.removeAll()
                
                print("Full data refresh (\(reason)): All caches cleared comprehensively")
                
                // 3e. Refresh cache from downloaded files
                print("Full data refresh (\(reason)): Step 3e - Refreshing cache from downloaded files")
                // Actually refresh schedule data
                self.schedule.populateSchedule(forceDownload: false)
                
                // Load iCloud data using new SQLite sync system
                // CRITICAL: Skip iCloud operations entirely during profile switches
                let isProfileSwitching = UserDefaults.standard.bool(forKey: "ProfileSwitchInProgress")
                if isProfileSwitching {
                    print("🚫 [REFRESH_DATA] Profile switch in progress - SKIPPING ALL iCloud operations")
                }
                
                let iCloudGroup = DispatchGroup()
                
                iCloudGroup.enter()
                DispatchQueue.global(qos: .utility).async {
                    // CRITICAL: Double-check flag before starting iCloud operations
                    let isStillSwitching = UserDefaults.standard.bool(forKey: "ProfileSwitchInProgress")
                    if isStillSwitching {
                        print("🚫 [REFRESH_DATA] Profile switch still in progress - ABORTING iCloud operations")
                        iCloudGroup.leave()
                        return
                    }
                    
                    let sqliteiCloudSync = SQLiteiCloudSync()
                    
                    // Pull from iCloud BEFORE push. syncAttendanceToiCloud() removes any KV key not present in
                    // local SQLite; if we push first (e.g. fresh install with sparse local rows), we wipe iCloud
                    // attendance before merge — user sees only a handful until another device re-uploads.
                    print("iCloud Debug: Starting SQLite iCloud sync (pull then push)...")
                    
                    let pullGroup = DispatchGroup()
                    pullGroup.enter()
                    sqliteiCloudSync.syncPrioritiesFromiCloud {
                        print("iCloud Debug: Priority pull completed")
                        pullGroup.leave()
                    }
                    pullGroup.enter()
                    sqliteiCloudSync.syncAttendanceFromiCloud {
                        print("iCloud Debug: Attendance pull completed")
                        pullGroup.leave()
                    }
                    
                    pullGroup.notify(queue: .global(qos: .utility)) {
                        let pushGroup = DispatchGroup()
                        pushGroup.enter()
                        sqliteiCloudSync.syncPrioritiesToiCloud {
                            print("iCloud Debug: Priority push completed")
                            pushGroup.leave()
                        }
                        pushGroup.enter()
                        sqliteiCloudSync.syncAttendanceToiCloud {
                            print("iCloud Debug: Attendance push completed")
                            pushGroup.leave()
                        }
                        pushGroup.notify(queue: .global(qos: .utility)) {
                            print("iCloud Debug: All SQLite iCloud sync completed")
                            iCloudGroup.leave()
                        }
                    }
                }
                
                // 3f. Generate consolidated image list then refresh the GUI
                iCloudGroup.notify(queue: .main) {
                    print("Full data refresh (\(reason)): Step 3f - All data loaded (iCloud sync complete)")
                    
                    if endRefreshControl {
                        self.refreshControl?.endRefreshing()
                    }
                    if shouldScrollToTop {
                        self.shouldSnapToTopAfterRefresh = true
                    }
                    
                    // YEAR CHANGE SEQUENCING:
                    // Move combined image list generation to the "post-year-change-ready" phase:
                    // - clear year-change mode
                    // - load caches for the selected year
                    // - then trigger image generation (non-blocking)
                    if isYearChangeOperation {
                        print("🎯 [YEAR_CHANGE] Step FINAL-PRE-UI: Loading bands + schedule + descriptionMap for selected year before UI/Preferences dismissal")
                        
                        // Load description map (it may have been cleared during cache reset).
                        self.bandDescriptions.getDescriptionMapFile()
                        self.bandDescriptions.getDescriptionMap()
                        self.logImagePipelineState("YearChange FINAL-PRE-UI after descriptionMap load")
                        
                        // Mark year-change data as ready and end year-change mode FIRST.
                        MasterViewController.markYearChangeDataReady()
                        MasterViewController.notifyYearChangeCompleted()
                        
                        // Load caches now that year-change mode is cleared (prevents deferrals).
                        self.bandNameHandle.loadCachedDataImmediately()
                        self.schedule.loadCachedDataImmediately()
                        self.logImagePipelineState("YearChange FINAL-PRE-UI after cache load")
                        
                        // Trigger image generation, but never block year-change completion on it.
                        CombinedImageListHandler.shared.triggerRefreshPostDataLoad(
                            bandNameHandle: self.bandNameHandle,
                            scheduleHandle: self.schedule,
                            context: "YearChange post-ready"
                        )
                    } else {
                        // Non-year-change refresh (pull-to-refresh / foreground):
                        // Do not block UI completion on image generation. Trigger it after data commit.
                        CombinedImageListHandler.shared.triggerRefreshPostDataLoad(
                            bandNameHandle: self.bandNameHandle,
                            scheduleHandle: self.schedule,
                            context: "Non-year-change refresh post-commit"
                        )
                        
                        // Final GUI refresh with all new data (images may fill in as the map updates)
                        self.refreshBandList(reason: "\(reason) - final refresh", scrollToTop: false, isPullToRefresh: shouldScrollToTop)
                    }
                    
                    if isYearChangeOperation {
                        print("🎯 [YEAR_CHANGE] Skipping refreshBandList from performBackgroundDataRefresh; will refresh after Preferences flow completes")
                    }
                    
                    print("Full data refresh (\(reason)): Complete (image generation is decoupled)")
                    
                    // Call completion handler to signal data refresh is complete
                    completion?()
                }
            } else {
                print("Full data refresh (\(reason)): No content changes detected, keeping existing cache")
                
                if endRefreshControl {
                    self.refreshControl?.endRefreshing()
                }
                if shouldScrollToTop {
                    self.shouldSnapToTopAfterRefresh = true
                }
                
                // Refresh GUI with existing data
                self.refreshBandList(reason: "\(reason) - no changes detected", scrollToTop: false, isPullToRefresh: shouldScrollToTop)
                
                // Call completion handler to signal data refresh is complete
                completion?()
            }
        }
    }
    
    /// Safely merges new band data with existing data, only removing entries that weren't updated
    /// This approach prevents data loss and maintains consistency
    /// 
    /// Key benefits:
    /// 1. No data loss - existing data is preserved until new data is ready
    /// 2. No race conditions - the bands array is never empty during table view access
    /// 3. Efficient updates - only changed data is processed
    /// 4. Atomic operations - table view updates happen atomically with data changes
    func safelyMergeBandData(_ newBands: [String], reason: String) {
        print("🔄 [MERGE_DEBUG] Safely merging band data - reason: '\(reason)'")
        print("🔄 [MERGE_DEBUG] Current bands count: \(bands.count), New bands count: \(newBands.count)")
        if newBands.count > 0 && newBands.count <= 20 {
            print("🔄 [MERGE_DEBUG] New bands array contents (first \(min(newBands.count, 10)) items):")
            for (index, item) in newBands.prefix(10).enumerated() {
                let name = getNameFromSortable(item, sortedBy: getSortedBy())
                print("🔄 [MERGE_DEBUG] [\(index)] '\(item)' -> name: '\(name)'")
            }
        }
        
        // Create a set of new band names for efficient lookup
        let newBandSet = Set(newBands)
        let currentBandSet = Set(bands)
        
        // Find bands that exist in current but not in new data (these will be removed)
        let bandsToRemove = currentBandSet.subtracting(newBandSet)
        
        // Find bands that are new (these will be added)
        let bandsToAdd = newBandSet.subtracting(currentBandSet)
        
        // Find bands that exist in both (these will be updated)
        let bandsToUpdate = currentBandSet.intersection(newBandSet)
        
        print("🔄 Bands to remove: \(bandsToRemove.count), Bands to add: \(bandsToAdd.count), Bands to update: \(bandsToUpdate.count)")
        
        if !bandsToRemove.isEmpty {
            print("🔄 Removing outdated bands: \(Array(bandsToRemove.prefix(5)))\(bandsToRemove.count > 5 ? " and \(bandsToRemove.count - 5) more..." : "")")
        }
        
        if !bandsToAdd.isEmpty {
            print("🔄 Adding new bands: \(Array(bandsToAdd.prefix(5)))\(bandsToAdd.count > 5 ? " and \(bandsToAdd.count - 5) more..." : "")")
        }
        
        // Update the bands array with the new data
        bands = newBands
        
        // Also update the other arrays to maintain consistency
        bandsByName = newBands
        
        // Update iPad toggle button visibility based on data availability
        setupViewToggleButton()
        
        // CRITICAL FIX: Rebuild CellDataCache after year changes to populate UI cache with priority data
        // This ensures priority data is displayed correctly after year changes
        print("🔄 Rebuilding CellDataCache after band data merge - reason: '\(reason)'")
        CellDataCache.shared.rebuildCache(
            from: newBands,
            sortBy: getSortedBy(),
            reason: "Band data merge: \(reason)"
        ) {
            print("✅ CellDataCache rebuild completed after band data merge")
        }
        
        // Immediately reload the table view to ensure consistency
        DispatchQueue.main.async {
            self.tableView.reloadData()
            print("🔄 Band data merge complete - table view updated")
            
            // KISS: After table reload, ensure titleView is visible
            self.navigationItem.title = nil
            self.updateCountLable()
        }
    }
    
    /// Safely refreshes all data when we want to start completely fresh (e.g., year changes)
    /// This method ensures no race conditions by temporarily setting a safe state
    func safelyRefreshAllData(_ newBands: [String], reason: String) {
        print("🔄 Safely refreshing all data - reason: '\(reason)'")
        print("🔄 Current bands count: \(bands.count), New bands count: \(newBands.count)")
        
        // Set a temporary safe state to prevent crashes during the transition
        let tempBands = bands.isEmpty ? ["Loading..."] : bands
        
        // Update the arrays atomically
        bands = newBands
        bandsByName = newBands
        
        // Update iPad toggle button visibility based on data availability
        setupViewToggleButton()
        
        // CRITICAL FIX: Rebuild CellDataCache after full data refresh to populate UI cache with priority data
        // This ensures priority data is displayed correctly after year changes
        print("🔄 Rebuilding CellDataCache after full data refresh - reason: '\(reason)'")
        CellDataCache.shared.rebuildCache(
            from: newBands,
            sortBy: getSortedBy(),
            reason: "Full data refresh: \(reason)"
        ) {
            print("✅ CellDataCache rebuild completed after full data refresh")
        }
        
        // Immediately reload the table view to ensure consistency
        DispatchQueue.main.async {
            self.tableView.reloadData()
            print("🔄 All data refresh complete - table view updated")
            
            // KISS: After table reload, ensure titleView is visible
            self.navigationItem.title = nil
            self.updateCountLable()
        }
    }
    
    /// Load iCloud data after SQLite data is available
    private func loadICloudData(completion: (() -> Void)? = nil) {
        // CRITICAL: Skip iCloud operations during profile switches
        let isProfileSwitching = UserDefaults.standard.bool(forKey: "ProfileSwitchInProgress")
        if isProfileSwitching {
            print("🚫 [LOAD_ICLOUD] Profile switch in progress - SKIPPING iCloud data load")
            completion?()
            return
        }
        
        print("☁️ Loading iCloud data...")
        
        // Use SQLite iCloud sync system — pull before push (see refreshDataWithBackgroundUpdate).
        let sqliteiCloudSync = SQLiteiCloudSync()
        
        let pullGroup = DispatchGroup()
        pullGroup.enter()
        sqliteiCloudSync.syncPrioritiesFromiCloud {
            print("☁️ Priority pull completed")
            pullGroup.leave()
        }
        pullGroup.enter()
        sqliteiCloudSync.syncAttendanceFromiCloud {
            print("☁️ Attendance pull completed")
            pullGroup.leave()
        }
        
        pullGroup.notify(queue: .main) {
            let pushGroup = DispatchGroup()
            pushGroup.enter()
            sqliteiCloudSync.syncPrioritiesToiCloud {
                pushGroup.leave()
            }
            pushGroup.enter()
            sqliteiCloudSync.syncAttendanceToiCloud {
                pushGroup.leave()
            }
            pushGroup.notify(queue: .main) {
                print("✅ iCloud data loading completed")
                completion?()
            }
        }
    }
    
    /// Load combined image list after core data is available
    private func loadCombinedImageList() {
        print("🖼️ Loading combined image list...")
        
        // Now that we have SQLite data, we can safely load the combined image list
        // Use the shared singleton instance instead of creating a new one
        let combinedImageHandler = CombinedImageListHandler.shared
        
        // Check if refresh is needed and load the combined image list
        print("🖼️ Checking if combined image list refresh is needed...")
        combinedImageHandler.checkAndRefreshOnLaunch()
        
        print("✅ Combined image list loading completed")
    }
    
    // MARK: - PERFORMANCE OPTIMIZED LAUNCH METHODS
    
    /// Optimized first launch: Skip database cache (empty on first install), go straight to network download
    private func performOptimizedFirstLaunch() {
        print("🚀 [MDF_DEBUG] First launch - going straight to network download")
        print("🚀 [MDF_DEBUG] Festival: \(FestivalConfig.current.festivalShortName)")
        print("🚀 FIRST LAUNCH: Triggering immediate network download")
        
        // SQLite database is always ready - proceed with network download
        print("🔍 Starting network download...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                return
            }
            
            // SQLite database is ready - proceed with data loading
            // Go straight to network download
            self.continueFirstLaunchAfterDataLoad()
        }
    }
    
    /// Continue first launch sequence after initial data load
    private func continueFirstLaunchAfterDataLoad() {
        
        // CRITICAL FIX: Clear justLaunched flag to prevent getting stuck in "waiting" mode
        // This ensures the app shows cached data even if there are network/loading issues
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if cacheVariables.justLaunched {
                print("🔧 SAFETY: Clearing justLaunched flag after 3 seconds to prevent app from getting stuck")
                cacheVariables.justLaunched = false
            }
            print("✅ FIRST LAUNCH: 3-second safety timer completed, justLaunched flag cleared")
        }
        
        print("🚀 FIRST LAUNCH: Using unified parallel download with pointer refresh")
        
        // NEW: Use the unified refresh function that does:
        // 1. Download pointer file first
        // 2. Check for year changes
        // 3. Parallel download of bands, events, and iCloud data
        // 4. Single UI refresh when ALL data is ready
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            print("🚀 FIRST LAUNCH: Starting unified data refresh")
            self.performUnifiedDataRefresh(reason: "First launch")
        }
    }
    
    /// Optimized subsequent launch: Show cached SQLite data immediately, then refresh with parallel downloads
    private func performOptimizedSubsequentLaunch() {
        print("🚀 SUBSEQUENT LAUNCH: Step 1 - Displaying cached SQLite data immediately (non-blocking)")
        
        // Load data in background - SQLite is always ready
        print("🔍 Loading data in background...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // SQLite is always ready - no waiting needed
            print("✅ SQLite database ready")
            
            // Step 1: Load database data immediately and display to user
            print("🚀 [UNIFIED_REFRESH] Subsequent launch - loading database data")
            print("🚀 [UNIFIED_REFRESH] Festival: \(FestivalConfig.current.festivalShortName)")
            self.cacheManager.loadCachedDataImmediately()
            
            // Update UI on main thread with database data
            DispatchQueue.main.async {
                self.refreshBandList(reason: "Subsequent launch - immediate database display", skipDataLoading: true)
            }
            
            // Step 2: Launch parallel download threads (with throttling check)
            // Check throttling before downloading fresh data
            if self.shouldDownloadSchedule(force: false) {
                print("🚀 SUBSEQUENT LAUNCH: Throttling check passed - launching unified data refresh")
                self.performUnifiedDataRefresh(reason: "Subsequent launch")
            } else {
                print("🚀 SUBSEQUENT LAUNCH: Throttled - less than 5 minutes since last download, skipping fresh download")
            }
        }
    }
    
    // MARK: - Unified Data Refresh (Pointer First, Then 3 Parallel Threads)
    
    /// Unified data refresh function that:
    /// STEP 1: Downloads and updates pointer file (synchronously)
    /// STEP 2: Checks if year changed and handles it
    /// STEP 3: Launches 3 parallel threads to download:
    ///   - Thread 1: Bands CSV
    ///   - Thread 2: Events CSV  
    ///   - Thread 3: iCloud data + build image map
    /// STEP 4: Updates display once all three threads complete
    /// NOTE: Throttling should be checked by callers before invoking this method.
    /// First launch bypasses throttling, other scenarios should check shouldDownloadSchedule() first.
    /// - Parameter reason: Description of why refresh is occurring
    private func performUnifiedDataRefresh(reason: String) {
        print("🔄 [UNIFIED_REFRESH] Starting unified data refresh - \(reason)")
        
        // Run on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // CRITICAL: Synchronize UserDefaults to read latest settings from Settings.bundle
            UserDefaults.standard.synchronize()
            print("🔄 [UNIFIED_REFRESH] Step 0 - Synchronized UserDefaults to read latest settings")
            
            // Re-read the pointer URL preference to respect user's choice
            let customPointerUrl = UserDefaults.standard.string(forKey: "CustomPointerUrl") ?? ""
            let usingCustomUrl = !customPointerUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            
            if usingCustomUrl {
                defaultStorageUrl = customPointerUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                print("🔄 [UNIFIED_REFRESH] ✅ Using CUSTOM pointer URL: \(defaultStorageUrl)")
            } else {
                let pointerUrlPref = UserDefaults.standard.string(forKey: "PointerUrl") ?? "Prod"
                print("🔄 [UNIFIED_REFRESH] Current PointerUrl preference: '\(pointerUrlPref)'")
                
                // Update defaultStorageUrl based on current preference
                if pointerUrlPref == testingSetting {
                    defaultStorageUrl = FestivalConfig.current.defaultStorageUrlTest
                    print("🔄 [UNIFIED_REFRESH] ✅ Using TESTING pointer URL: \(defaultStorageUrl)")
                } else {
                    defaultStorageUrl = FestivalConfig.current.defaultStorageUrl
                    print("🔄 [UNIFIED_REFRESH] ✅ Using PRODUCTION pointer URL: \(defaultStorageUrl)")
                }
            }
            
            // STEP 1: Download and update pointer file FIRST (synchronously)
            print("🔄 [UNIFIED_REFRESH] Step 1 - Downloading pointer file FIRST")
            let pointerUpdated = self.downloadAndUpdatePointerFileSync()
            
            if pointerUpdated {
                print("✅ [UNIFIED_REFRESH] Pointer file updated successfully")
                
                // Notify pointer consumers (wizard, band list refresh, etc.) so they run on foreground return as well as launch.
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name("PointerDataUpdated"), object: nil)
                }
                
                // STEP 2: Check if year changed
                let newYear = getPointerUrlData(keyValue: "eventYear") ?? String(eventYear)
                let newYearInt = Int(newYear) ?? eventYear
                
                if newYearInt != eventYear {
                    print("🔄 [UNIFIED_REFRESH] Year changed from \(eventYear) to \(newYearInt)")
                    eventYear = newYearInt
                    
                    // Update year file
                    do {
                        try newYear.write(toFile: eventYearFile, atomically: true, encoding: .utf8)
                        print("✅ [UNIFIED_REFRESH] Updated year file to \(newYear)")
                    } catch {
                        print("⚠️ [UNIFIED_REFRESH] Failed to update year file: \(error)")
                    }
                    
                    // Notify that year changed
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: Notification.Name("YearChangedAutomatically"),
                            object: nil,
                            userInfo: ["newYear": newYearInt, "oldYear": eventYear]
                        )
                    }
                }
            } else {
                print("⚠️ [UNIFIED_REFRESH] Pointer file update failed, continuing with cached pointer data")
            }

            // Version warning: check after pointer refresh attempt (fresh if download succeeded; cached otherwise).
            // Requirement: check on app launch and when returning from background; both flows use unified refresh.
            MinimumVersionWarningManager.checkAndShowIfNeeded(reason: "UnifiedRefresh(\(reason)) pointerUpdated=\(pointerUpdated)")
            
            // STEP 3: Launch 3 parallel CSV download threads
            print("🔄 [UNIFIED_REFRESH] Step 3 - Launching 3 parallel CSV download threads")
            
            // Create a dispatch group to track all 3 parallel operations
            let refreshGroup = DispatchGroup()
            
            // Run Bands then Schedule sequentially to avoid SQLite lock contention (same DB file).
            refreshGroup.enter()
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    refreshGroup.leave()
                    return
                }
                print("🔄 [UNIFIED_REFRESH] Step 1 - Downloading Bands CSV")
                self.bandNameHandle.gatherData(forceDownload: true) { [weak self] in
                    guard let self = self else {
                        refreshGroup.leave()
                        return
                    }
                    print("✅ [UNIFIED_REFRESH] Bands CSV complete - now downloading Schedule CSV (sequential to avoid DB lock)")
                    self.schedule.populateSchedule(forceDownload: true)
                    refreshGroup.leave()
                }
            }
            
            // Thread 3: Download iCloud data (parallel with bands+schedule)
            refreshGroup.enter()
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self = self else {
                    refreshGroup.leave()
                    return
                }
                
                print("🔄 [UNIFIED_REFRESH] Thread 3 - Downloading iCloud data")
                self.loadICloudData {
                    print("✅ [UNIFIED_REFRESH] Thread 3 - iCloud data complete")
                    refreshGroup.leave()
                }
            }
            
            // STEP 4: Wait for all 3 parallel downloads to complete
            refreshGroup.notify(queue: .global(qos: .utility)) { [weak self] in
                guard let self = self else { return }
                
                print("📝 [UNIFIED_REFRESH] All CSVs downloaded - now loading description map and image map with fresh data")
                
                // Load description map AFTER CSVs are imported
                // This ensures the description map is available for the details screen
                self.bandDescriptions.getDescriptionMapFile()
                self.bandDescriptions.getDescriptionMap()
                print("✅ [UNIFIED_REFRESH] Description map loaded with fresh CSV data")
                
                // Build image map AFTER CSVs are imported AND AFTER descriptionMap is loaded,
                // but DO NOT block UI completion on image generation (prevents "hung" refreshes).
                self.bandNameHandle.loadCachedDataImmediately()
                self.schedule.loadCachedDataImmediately()
                CombinedImageListHandler.shared.triggerRefreshPostDataLoad(
                    bandNameHandle: self.bandNameHandle,
                    scheduleHandle: self.schedule,
                    context: "UnifiedRefresh(\(reason)) post-commit"
                )
                
                // DISABLED: Orphaned band cleanup removed
                // Bands and events are separate entities - bands can legitimately exist without events
                // Fake bands (like "All Star Jam") are filtered in UI display logic, not deleted from database
                print("🧹 [CLEANUP] Skipping orphaned band cleanup - bands and events are separate entities")
                
                // Now update the display on main thread (images may fill in as the map updates)
                DispatchQueue.main.async {
                    print("🎉 [UNIFIED_REFRESH] All data complete (CSVs + description map) - updating display")
                    
                    // Clear justLaunched flag
                    cacheVariables.justLaunched = false
                    
                    // Update the display with fresh data
                    self.refreshBandList(reason: "\(reason) - all data refreshed")
                    
                    print("✅ [UNIFIED_REFRESH] Display updated - refresh complete")
                }
            }
        }
    }
    
    /// Downloads and updates the pointer file synchronously (blocking)
    /// Returns true if successful, false otherwise
    /// This is called at the start of every data refresh to ensure fresh pointer data
    /// Also called when Pointer URL preference changes to download from new location
    internal func downloadAndUpdatePointerFileSync() -> Bool {
        print("📍 [POINTER_SYNC] Starting synchronous pointer file download")
        
        // Check internet connectivity
        guard Reachability.isConnectedToNetwork() else {
            print("📍 [POINTER_SYNC] No internet connection, using cached pointer data")
            return false
        }
        
        // Get the pointer URL
        guard let url = URL(string: defaultStorageUrl) else {
            print("📍 [POINTER_SYNC] Invalid pointer URL: \(defaultStorageUrl)")
            return false
        }
        
        // Download pointer file synchronously
        let semaphore = DispatchSemaphore(value: 0)
        var downloadSuccess = false
        
        let configuration = URLSessionConfiguration.default
        // Android parity: 10s on GUI thread, 60s in background.
        let timeout = NetworkTimeoutPolicy.timeoutIntervalForCurrentThread()
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: configuration)
        
        let task = session.dataTask(with: url) { (data, response, error) in
            defer { semaphore.signal() }
            
            if let error = error {
                print("📍 [POINTER_SYNC] Download error: \(error)")
                return
            }
            
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  data.count <= 1024 * 1024 else { // 1MB limit
                print("📍 [POINTER_SYNC] Invalid response or data")
                return
            }
            
            // Verify content is valid pointer data
            guard let content = String(data: data, encoding: .utf8),
                  !content.isEmpty else {
                print("📍 [POINTER_SYNC] Downloaded content is empty or invalid")
                return
            }
            
            // Validate pointer format
            let lines = content.components(separatedBy: "\n")
            var validLineCount = 0
            for line in lines.prefix(10) {
                if line.contains("::") && line.components(separatedBy: "::").count >= 3 {
                    validLineCount += 1
                    if validLineCount >= 2 {
                        break
                    }
                }
            }
            
            guard validLineCount >= 2 else {
                print("📍 [POINTER_SYNC] Downloaded content is not valid pointer data")
                return
            }
            
            // Save pointer file
            let documentsPath = getDocumentsDirectory()
            let cachedPointerFile = documentsPath.appendingPathComponent("cachedPointerData.txt")
            
            do {
                // Remove old file
                if FileManager.default.fileExists(atPath: cachedPointerFile) {
                    try FileManager.default.removeItem(atPath: cachedPointerFile)
                }
                
                // Write new file
                try data.write(to: URL(fileURLWithPath: cachedPointerFile))
                
                // Clear in-memory cache to force reload
                storePointerLock.sync() {
                    cacheVariables.storePointerData.removeAll()
                }
                
                print("📍 [POINTER_SYNC] Successfully updated pointer file and cleared cache")
                downloadSuccess = true
                
            } catch {
                print("📍 [POINTER_SYNC] Failed to save pointer file: \(error)")
            }
        }
        
        task.resume()
        semaphore.wait()
        
        return downloadSuccess
    }
    
    /// Continue subsequent launch sequence after initial data load
    private func continueSubsequentLaunchAfterDataLoad() {
        
        // CRITICAL FIX: Clear justLaunched flag to prevent getting stuck in "waiting" mode
        // This ensures the app shows cached data even if there are network/loading issues
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if cacheVariables.justLaunched {
                print("🔧 SAFETY: Clearing justLaunched flag after 2 seconds to prevent app from getting stuck")
                cacheVariables.justLaunched = false
            }
        }
        
        // Step 2: Check if we need background updates (using 5-minute throttling)
        let forceDownload = UserDefaults.standard.bool(forKey: "ForceCSVDownload")
        let shouldUpdateData = forceDownload || self.shouldDownloadSchedule(force: false)
        
        if shouldUpdateData {
            if forceDownload {
                print("🚀 SUBSEQUENT LAUNCH: Step 2 - FORCED CSV download due to pointer URL change")
            } else {
                print("🚀 SUBSEQUENT LAUNCH: Step 2 - Starting background network test for data update (5-minute throttling)")
            }
            
            // Test network first, then do fresh data collection including description map
            self.performBackgroundNetworkTestWithCompletion { [weak self] networkIsGood in
                guard let self = self else { return }
                
                if networkIsGood {
                    print("🚀 SUBSEQUENT LAUNCH: Network test passed - proceeding with fresh data collection")
                    self.performFreshDataCollection(reason: "Subsequent launch - forced or throttled update")
                    
                    // Clear the force flag after successful download
                    if forceDownload {
                        UserDefaults.standard.set(false, forKey: "ForceCSVDownload")
                        UserDefaults.standard.synchronize()
                        print("🚀 SUBSEQUENT LAUNCH: Cleared ForceCSVDownload flag after successful download")
                        
                        // Update LastUsedPointerUrl to match what was just downloaded
                        UserDefaults.standard.set(defaultStorageUrl, forKey: "LastUsedPointerUrl")
                        UserDefaults.standard.synchronize()
                        print("🚀 SUBSEQUENT LAUNCH: Updated LastUsedPointerUrl to '\(defaultStorageUrl)'")
                    }
                } else {
                    print("🚀 SUBSEQUENT LAUNCH: Network test failed - staying with cached data, no fresh data collection")
                    print("🚀 SUBSEQUENT LAUNCH: User will continue seeing cached data until network improves")
                    // Keep the force flag set so it will retry next time
                    if forceDownload {
                        print("🚀 SUBSEQUENT LAUNCH: Keeping ForceCSVDownload flag set for next attempt")
                    }
                }
            }
        } else {
            print("🚀 SUBSEQUENT LAUNCH: Step 2 - Skipping background update (throttled - less than 5 minutes since last download)")
        }
    }
    
    // MARK: - Background Network Testing & Fresh Data Collection
    
    /// Performs a background network test with completion handler - never blocks GUI
    /// This is the key method that enables the pattern: show cached SQLite data immediately, test network, then fresh data collection
    /// - Parameter completion: Called with true if network is good, false if network is bad or unavailable
    private func performBackgroundNetworkTestWithCompletion(completion: @escaping (Bool) -> Void) {
        print("🌐 BACKGROUND NETWORK TEST: Starting ROBUST network test with completion handler")
        
        // Always run network test on background queue to never block GUI
        DispatchQueue.global(qos: .userInitiated).async {
            print("🌐 BACKGROUND NETWORK TEST: Performing real HTTP request to test network quality")
            
            // ROBUST NETWORK TEST: Do actual HTTP request instead of relying on cached values
            let isNetworkGood = self.performRobustNetworkTest()
            
            print("🌐 BACKGROUND NETWORK TEST: Robust network test completed - result: \(isNetworkGood)")
            
            // Call completion handler on main thread for UI updates
            print("🔍 [NETWORK_DEBUG] About to dispatch completion handler to MAIN thread with result: \(isNetworkGood)")
            DispatchQueue.main.async {
                print("🔍 [NETWORK_DEBUG] ===== COMPLETION HANDLER EXECUTING ON MAIN THREAD =====")
                print("🔍 [NETWORK_DEBUG] Calling completion handler with networkIsGood: \(isNetworkGood)")
                completion(isNetworkGood)
                print("🔍 [NETWORK_DEBUG] ===== COMPLETION HANDLER FINISHED =====")
            }
        }
    }
    
    /// Performs a robust network test with actual HTTP request - not cached values
    /// This properly detects 100% packet loss and poor network conditions
    /// - Returns: true if network is good enough for data operations, false otherwise
    private func performRobustNetworkTest() -> Bool {
        print("🌐 ROBUST TEST: Starting real HTTP request to test network")
        
        // CRITICAL FIX: Test with actual Dropbox URL to ensure Dropbox is reachable
        // Testing Google doesn't prove Dropbox works - they may have different network paths
        // Use a small pointer file for the test
        guard let url = URL(string: "https://www.dropbox.com/scl/fi/kd5gzo06yrrafgz81y0ao/productionPointer.txt?rlkey=gt1lpaf11nay0skb6fe5zv17g&raw=1") else {
            print("🌐 ROBUST TEST: ❌ Invalid test URL")
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 4.0 // 4 second timeout for data operations test  
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData // Force fresh request
        
        let semaphore = DispatchSemaphore(value: 0)
        var testResult = false
        
        print("🌐 ROBUST TEST: Making HTTP request to \(url.absoluteString)")
        let startTime = Date()
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            let duration = Date().timeIntervalSince(startTime)
            
            if let error = error {
                print("🌐 ROBUST TEST: ❌ Network error after \(String(format: "%.2f", duration))s: \(error.localizedDescription)")
                if error.localizedDescription.contains("timed out") {
                    print("🌐 ROBUST TEST: ❌ TIMEOUT - This indicates poor network or 100% packet loss")
                }
                testResult = false
            } else if let httpResponse = response as? HTTPURLResponse {
                print("🌐 ROBUST TEST: ✅ HTTP response received after \(String(format: "%.2f", duration))s: \(httpResponse.statusCode)")
                // Google's generate_204 returns 204 No Content on success
                testResult = (httpResponse.statusCode == 204 || httpResponse.statusCode == 200)
                if testResult {
                    print("🌐 ROBUST TEST: ✅ Network is good for data operations")
                } else {
                    print("🌐 ROBUST TEST: ❌ Unexpected HTTP status: \(httpResponse.statusCode)")
                }
            } else {
                print("🌐 ROBUST TEST: ❌ No response received")
                testResult = false
            }
            
            semaphore.signal()
        }
        
        task.resume()
        
        // Wait for test to complete with timeout
        let timeoutResult = semaphore.wait(timeout: .now() + 5.0)
        if timeoutResult == .timedOut {
            print("🌐 ROBUST TEST: ❌ SEMAPHORE TIMEOUT - Network test took too long, assuming bad network")
            task.cancel()
            testResult = false
        }
        
        print("🌐 ROBUST TEST: Final result: \(testResult ? "NETWORK GOOD" : "NETWORK BAD/DOWN")")
        return testResult
    }
    
    /// Performs fresh data collection including description map - only called after network test passes
    /// This method includes all the data sources: band names, schedule, description map, iCloud data
    /// - Parameter reason: Reason for the fresh data collection (for logging)
    private func performFreshDataCollection(reason: String) {
        print("📡 FRESH DATA COLLECTION: Starting fresh data collection - \(reason)")
        
        // Run entirely in background to never block GUI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // CRITICAL: Synchronize UserDefaults to read latest settings from Settings.bundle
            UserDefaults.standard.synchronize()
            print("📡 FRESH DATA COLLECTION: Synchronized UserDefaults to read latest settings")
            
            // Re-read the pointer URL preference to respect user's choice
            let customPointerUrl = UserDefaults.standard.string(forKey: "CustomPointerUrl") ?? ""
            let usingCustomUrl = !customPointerUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            
            if usingCustomUrl {
                defaultStorageUrl = customPointerUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                print("📡 FRESH DATA COLLECTION: ✅ Using CUSTOM pointer URL: \(defaultStorageUrl)")
            } else {
                let pointerUrlPref = UserDefaults.standard.string(forKey: "PointerUrl") ?? "Prod"
                print("📡 FRESH DATA COLLECTION: Current PointerUrl preference: '\(pointerUrlPref)'")
                
                // Update defaultStorageUrl based on current preference
                if pointerUrlPref == testingSetting {
                    defaultStorageUrl = FestivalConfig.current.defaultStorageUrlTest
                    print("📡 FRESH DATA COLLECTION: ✅ Using TESTING pointer URL: \(defaultStorageUrl)")
                } else {
                    defaultStorageUrl = FestivalConfig.current.defaultStorageUrl
                    print("📡 FRESH DATA COLLECTION: ✅ Using PRODUCTION pointer URL: \(defaultStorageUrl)")
                }
            }
            
            // Step 1: Download band names
            print("📡 FRESH DATA COLLECTION: Step 1 - Downloading band names")
            self.bandNameHandle.gatherData(forceDownload: true) { [weak self] in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    print("📡 FRESH DATA COLLECTION: Band names updated - refreshing display")
                    self.refreshBandList(reason: "\(reason) - band names updated")
                }
                
                // Step 2: Download schedule data
                print("📡 FRESH DATA COLLECTION: Step 2 - Downloading schedule data")
                DispatchQueue.global(qos: .userInitiated).async {
                    self.schedule.populateSchedule(forceDownload: true)
                    
                    DispatchQueue.main.async {
                        print("📡 FRESH DATA COLLECTION: Schedule updated - refreshing display")
                        self.refreshBandList(reason: "\(reason) - schedule updated")
                        
                        // Step 3: Download description map and other data
                        print("📡 FRESH DATA COLLECTION: Step 3 - Downloading description map")
                        DispatchQueue.global(qos: .utility).async {
                            // Download description map file
                            self.bandDescriptions.getDescriptionMapFile()
                            self.bandDescriptions.getDescriptionMap()
                            print("📡 FRESH DATA COLLECTION: Description map updated")
                            
                            // Load iCloud data
                            print("📡 FRESH DATA COLLECTION: Step 4 - Loading iCloud data")
                            self.loadICloudData {
                                // Load combined image list
                                print("📡 FRESH DATA COLLECTION: Step 5 - Loading combined image list")
                                self.loadCombinedImageList()
                                
                                print("📡 FRESH DATA COLLECTION: All fresh data collection completed for: \(reason)")
                                
                                // Clear force download flag if it was set (pointer URL change)
                                if UserDefaults.standard.bool(forKey: "ForceCSVDownload") {
                                    UserDefaults.standard.set(false, forKey: "ForceCSVDownload")
                                    UserDefaults.standard.synchronize()
                                    print("📡 FRESH DATA COLLECTION: Cleared ForceCSVDownload flag after successful data collection")
                                }
                                
                                // CRITICAL: Update LastUsedPointerUrl to match what was just downloaded
                                // This ensures future comparisons know which data is currently loaded
                                UserDefaults.standard.set(defaultStorageUrl, forKey: "LastUsedPointerUrl")
                                UserDefaults.standard.synchronize()
                                print("📡 FRESH DATA COLLECTION: Updated LastUsedPointerUrl to '\(defaultStorageUrl)'")
                                
                                // Data is now available in SQLite - refresh display
                                DispatchQueue.main.async {
                                    print("📡 FRESH DATA COLLECTION: Fresh data available in SQLite")
                                    self.refreshBandList(reason: "Fresh data downloaded")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Background data update that only refreshes UI if data actually changed
    private func performBackgroundDataUpdate() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            print("🚀 BACKGROUND UPDATE: Checking for data changes")
            var dataChanged = false
            
            // Check band names for changes
            let bandNamesGroup = DispatchGroup()
            bandNamesGroup.enter()
            
            self.bandNameHandle.gatherData(forceDownload: true) { [weak self] in
                // This completion is called if data actually changed
                dataChanged = true
                print("🚀 BACKGROUND UPDATE: Band names changed")
                bandNamesGroup.leave()
            }
            
            // Check schedule for changes
            let scheduleGroup = DispatchGroup()
            scheduleGroup.enter()
            
            DispatchQueue.global(qos: .utility).async {
                // Get current event count before update
                let eventCountBefore = self.schedule.getBandSortedSchedulingData().count
                
                // Trigger schedule update
                self.schedule.populateSchedule(forceDownload: true)
                
                // Check if event count changed (simple change detection)
                let eventCountAfter = self.schedule.getBandSortedSchedulingData().count
                if eventCountBefore != eventCountAfter {
                    dataChanged = true
                    print("🚀 BACKGROUND UPDATE: Schedule changed (events: \(eventCountBefore) → \(eventCountAfter))")
                } else {
                    print("🚀 BACKGROUND UPDATE: Schedule unchanged (\(eventCountAfter) events)")
                }
                scheduleGroup.leave()
            }
            
            // Wait for both to complete
            let updateGroup = DispatchGroup()
            updateGroup.enter()
            bandNamesGroup.notify(queue: .global(qos: .utility)) {
                updateGroup.leave()
            }
            updateGroup.enter()
            scheduleGroup.notify(queue: .global(qos: .utility)) {
                updateGroup.leave()
            }
            
            updateGroup.notify(queue: .main) {
                if dataChanged {
                    print("🚀 BACKGROUND UPDATE: Data changed, refreshing display")
                    self.refreshBandList(reason: "Background update - data changed")
                } else {
                    print("🚀 BACKGROUND UPDATE: No data changes, display unchanged")
                }
            }
        }
    }
    
    /// Performs UI refresh with already-loaded data (no background data loading)
    private func performUIRefreshWithLoadedData(reason: String, scrollToTop: Bool, previousOffset: CGPoint) {
        print("🚀 performUIRefreshWithLoadedData: Starting fast UI refresh")
        
        self.filterRequestID += 1
        let requestID = self.filterRequestID
        
        getFilteredBands(
            bandNameHandle: self.bandNameHandle,
            schedule: self.schedule,
            dataHandle: self.dataHandle,
            priorityManager: self.priorityManager,
            attendedHandle: self.attendedHandle,
            searchCriteria: self.bandSearch?.text ?? "",
            areFiltersActive: self.filterTextNeeded
        ) { [weak self] (filtered: [String]) in
            // CRITICAL FIX: Ensure all UI operations happen on main thread
            DispatchQueue.main.async {
                guard let self = self else {
                    MasterViewController.isRefreshingBandList = false
                    MasterViewController.refreshBandListSafetyTimer?.invalidate()
                    MasterViewController.refreshBandListSafetyTimer = nil
                    return
                }
                // Only update UI if this is the latest request
                if requestID != self.filterRequestID {
                    MasterViewController.isRefreshingBandList = false
                    MasterViewController.refreshBandListSafetyTimer?.invalidate()
                    MasterViewController.refreshBandListSafetyTimer = nil
                    return
                }
                
                var bandsResult = filtered
                if eventCount == 0 {
                    bandsResult = self.deduplicatePreservingOrder(bandsResult)
                }
                
                let sortedBy = getSortedBy()
                if sortedBy == "name" {
                    bandsResult.sort { item1, item2 in
                        let isEvent1 = item1.contains(":") && item1.components(separatedBy: ":").first?.doubleValue != nil
                        let isEvent2 = item2.contains(":") && item2.components(separatedBy: ":").first?.doubleValue != nil
                        
                        // Events always come before band names only
                        if isEvent1 && !isEvent2 {
                            return true
                        } else if !isEvent1 && isEvent2 {
                            return false
                        } else {
                            // Both are same type, sort alphabetically
                            return getNameFromSortable(item1, sortedBy: sortedBy).localizedCaseInsensitiveCompare(getNameFromSortable(item2, sortedBy: sortedBy)) == .orderedAscending
                        }
                    }
                } else if sortedBy == "time" {
                    bandsResult.sort { item1, item2 in
                        let isEvent1 = item1.contains(":") && item1.components(separatedBy: ":").first?.doubleValue != nil
                        let isEvent2 = item2.contains(":") && item2.components(separatedBy: ":").first?.doubleValue != nil
                        
                        // Events always come before band names only
                        if isEvent1 && !isEvent2 {
                            return true
                        } else if !isEvent1 && isEvent2 {
                            return false
                        } else {
                            // If both are events, sort by time. If both are bands, sort alphabetically (since bands have no time)
                            if isEvent1 && isEvent2 {
                                // Both are events - sort by time
                                return getTimeFromSortable(item1, sortBy: sortedBy) < getTimeFromSortable(item2, sortBy: sortedBy)
                            } else {
                                // Both are band names - sort alphabetically even when sortBy is "time"
                                return getNameFromSortable(item1, sortedBy: "name").localizedCaseInsensitiveCompare(getNameFromSortable(item2, sortedBy: "name")) == .orderedAscending
                            }
                        }
                    }
                }
                
                print("🚀 performUIRefreshWithLoadedData: Loaded \(bandsResult.count) bands for year \(eventYear)")
                
                // Safely merge new band data with existing data to prevent race conditions
                self.safelyMergeBandData(bandsResult, reason: reason)
                
                // Pre-load priority data for all bands to improve table view performance
                self.preloadPriorityData()
                
                self.updateCountLable()
                
                // Handle scrolling
                if scrollToTop, self.bands.count > 0 {
                    let topIndex = IndexPath(row: 0, section: 0)
                    self.tableView.scrollToRow(at: topIndex, at: .top, animated: false)
                } else {
                    self.tableView.setContentOffset(previousOffset, animated: false)
                }
                
                // Always show separators when we have mixed content, per-cell logic will hide them for band names
                if eventCount == 0 {
                    self.tableView.separatorStyle = .none
                } else {
                    self.tableView.separatorStyle = .singleLine
                }
                
                MasterViewController.isRefreshingBandList = false
                MasterViewController.refreshBandListSafetyTimer?.invalidate()
                MasterViewController.refreshBandListSafetyTimer = nil
                
                print("🚀 performUIRefreshWithLoadedData: Fast UI refresh completed")
            } // End of DispatchQueue.main.async for UI operations
        } // End of getFilteredBands completion handler
    }
}

// CoreDataPreloadManagerDelegate removed - data now loaded directly from SQLite

extension UITableViewRowAction {
    
    func setIcon(iconImage: UIImage, backColor: UIColor, cellHeight: CGFloat, cellWidth:CGFloat) {
        // NOTE: This is an extension method for UITableViewRowAction, not MasterViewController
        // It sets the backgroundColor property of the UITableViewRowAction instance itself
        // Original implementation preserved - this is UI logic specific to UITableViewRowAction
        let cellFrame = CGRect(origin: .zero, size: CGSize(width: cellWidth*0.5, height: cellHeight))
        let imageFrame = CGRect(x:0, y:0,width:iconImage.size.width, height: iconImage.size.height)
        let insetFrame = cellFrame.insetBy(dx: ((cellFrame.size.width - imageFrame.size.width) / 2), dy: ((cellFrame.size.height - imageFrame.size.height) / 2))
        let targetFrame = insetFrame.offsetBy(dx: -(insetFrame.width / 2.0), dy: 0.0)
        let imageView = UIImageView(frame: imageFrame)
        imageView.image = iconImage
        imageView.contentMode = .left
        guard let resizedImage = imageView.image else { return }
        UIGraphicsBeginImageContextWithOptions(CGSize(width: cellWidth, height: cellHeight), false, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        backColor.setFill()
        context.fill(CGRect(x:0, y:0, width:cellWidth, height:cellHeight))
        resizedImage.draw(in: CGRect(x:(targetFrame.origin.x / 2), y: targetFrame.origin.y, width:targetFrame.width, height:targetFrame.height))
        guard let actionImage = UIGraphicsGetImageFromCurrentImageContext() else { return }
        UIGraphicsEndImageContext()
        self.backgroundColor = UIColor.init(patternImage: actionImage)
    }
}

extension Array where Element: Hashable {
    /// Returns a new array with duplicate elements removed while preserving order
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}


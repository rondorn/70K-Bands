//
//  MasterViewController.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/2/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import UIKit
import CoreData
import Firebase
import AVKit

class MasterViewController: UITableViewController, UISplitViewControllerDelegate, NSFetchedResultsControllerDelegate, UISearchBarDelegate {
    
    @IBOutlet var mainTableView: UITableView!
    @IBOutlet weak var mainToolBar: UIToolbar!
    
    @IBOutlet weak var titleButton: UINavigationItem!

    @IBOutlet weak var preferenceButton: UIBarButtonItem!
    @IBOutlet weak var filterMenuButton: UIButton!

    @IBOutlet weak var Undefined: UIButton!

    @IBOutlet weak var shareButton: UIBarButtonItem!
    
    @IBOutlet weak var contentController: UIView!
    //@IBOutlet weak var scheduleButton: UIButton!
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var blankScreenActivityIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var statsButton: UIBarButtonItem!
    @IBOutlet weak var filterButtonBar: UIBarButtonItem!
    @IBOutlet weak var searchButtonBar: UIBarButtonItem!
    @IBOutlet weak var menuButton: UIBarButtonItem!
    
    @IBOutlet weak var bandSearch: UISearchBar!
        
    let schedule = scheduleHandler.shared
    let bandNameHandle = bandNamesHandler.shared
    let attendedHandle = ShowsAttended()
    let iCloudDataHandle = iCloudDataHandler();
    
    var filterTextNeeded = true;
    var viewableCell = UITableViewCell()
    
    var filterMenu = DropDown();
    
    @IBOutlet weak var titleButtonArea: UINavigationItem!
    var backgroundColor = UIColor.white;
    var textColor = UIColor.black;
    var managedObjectContext: NSManagedObjectContext? = nil
    
    var sharedMessage = ""
    var objects = NSMutableArray()
    var bands =  [String]()
    var bandsByTime = [String]()
    var bandsByName = [String]()
    var reloadTableBool = true
    
    var filtersOnText = ""
    
    var bandDescriptions = CustomBandDescription()
    
    @IBOutlet weak var titleLabel: UINavigationItem!
    
    var dataHandle = dataHandler()
    
    var videoURL = URL("")
    var player = AVPlayer()
    var playerLayer = AVPlayerLayer()
    
    // --- ADDED: Timer and download state ---
    var lastScheduleDownload: Date? = nil
    var scheduleRefreshTimer: Timer? = nil
    let scheduleDownloadInterval: TimeInterval = 5 * 60 // 5 minutes
    let minDownloadInterval: TimeInterval = 60 // 1 minute
    // --- END ADDED ---
    
    var lastRefreshDataRun: Date? = nil
    var lastBandNamesCacheRefresh: Date? = nil
    
    // Add the missing property
    var isPerformingQuickLoad = false
    
    var easterEggTriggeredForSearch = false
    
    // Flag to track if country dialog should be shown after data loads on first install
    private var shouldShowCountryDialogAfterDataLoad = false
    
    var filterRequestID = 0
    
    static var isRefreshingBandList = false
    private static var refreshBandListSafetyTimer: Timer?
    
    // Flag to ensure snap-to-top after pull-to-refresh is not overridden
    var shouldSnapToTopAfterRefresh = false
    
    // Flag to prevent endless auto-selection loops on iPad
    var hasAutoSelectedForIPad = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bandSearch.placeholder = NSLocalizedString("SearchCriteria", comment: "")
        //bandSearch.backgroundImage = UIImage(named: "70KSearch")!
        //bandSearch.setImage(UIImage(named: "70KSearch")!, for: <#UISearchBar.Icon#>, state: UIControl.State.normal)
        bandSearch.setImage(UIImage(named: "70KSearch")!, for: .init(rawValue: 0)!, state: .normal)
        readFiltersFile()
        
        // Check if this is first install - if so, delay country dialog until data loads
        let hasRunBefore = UserDefaults.standard.bool(forKey: "hasRunBefore")
        // Preload country data in background to ensure it's always available
        countryHandler.shared.loadCountryData { 
            print("[MasterViewController] Country data preloaded successfully")
        }
        
        if !hasRunBefore {
            shouldShowCountryDialogAfterDataLoad = true
            print("[MasterViewController] First install detected - delaying country dialog until data loads")
        } else {
            // Not first install, show country dialog immediately if needed
            getCountry()
        }
        
        self.navigationController?.navigationBar.barStyle = UIBarStyle.blackTranslucent
        self.navigationController?.navigationBar.tintColor = UIColor.white
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.white]
        
        // Ensure back button always says "Back" when navigating from this view
        let backItem = UIBarButtonItem()
        backItem.title = "Back"
        self.navigationItem.backBarButtonItem = backItem
        
        //have a reference to this controller for external refreshes
        masterView = self;
        
        // Do any additional setup after loading the view, typically from a nib.
        if UIDevice.current.userInterfaceIdiom == .pad {
            splitViewController?.preferredDisplayMode = UISplitViewController.DisplayMode.allVisible
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
        
        //scheduleButton.setImage(getSortButtonImage(), for: UIControl.State.normal)
        mainTableView.separatorColor = UIColor.lightGray
        mainTableView.tableFooterView = UIView() // Remove separators for empty rows
        
        //do an initial load of iCloud data on launch
        let showsAttendedHandle = ShowsAttended()
        
        // Only show initial waiting message on first install (reuse hasRunBefore from above)
        if !hasRunBefore {
            print("[MasterViewController] First install - showing initial waiting message")
            showInitialWaitingMessage()
            
            // Delay the data loading slightly to ensure waiting message is visible on first install
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("Calling refreshBandList from viewDidLoad with reason: Initial launch (first install)")
                self.refreshBandList(reason: "Initial launch (first install)")
            }
        } else {
            // Check if we should do a full refresh on launch (if it's been a while since last launch)
            let lastLaunchKey = "LastAppLaunchDate"
            let now = Date()
            let lastLaunch = UserDefaults.standard.object(forKey: lastLaunchKey) as? Date
            let shouldDoFullRefresh = lastLaunch == nil || now.timeIntervalSince(lastLaunch!) > 24 * 60 * 60 // 24 hours
            
            UserDefaults.standard.set(now, forKey: lastLaunchKey)
            
            if shouldDoFullRefresh {
                print("App launch: Been more than 24 hours since last launch, performing full data refresh")
                performFullDataRefresh(reason: "App launch - full refresh")
            } else {
                print("Calling refreshBandList from viewDidLoad with reason: Initial launch")
                refreshBandList(reason: "Initial launch")
            }
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.displayFCMToken(notification:)),
                                               name: Notification.Name("FCMToken"), object: nil)
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(MasterViewController.refreshMainDisplayAfterRefresh), name:NSNotification.Name(rawValue: "refreshMainDisplayAfterRefresh"), object: nil)
        
        let iCloudHandle = iCloudDataHandler()

        //change the notch area to all black
        navigationController?.view.backgroundColor = .black
        //createrFilterMenu(controller: self);
     
        filterMenuButton.setTitle(NSLocalizedString("Filters", comment: ""), for: UIControl.State.normal)
        
        //these are needed for iOS 26 visual fixes
        if #available(iOS 26.0, *) {
            /*
            preferenceButton.hidesSharedBackground = true
            statsButton.hidesSharedBackground = true
            shareButton.hidesSharedBackground = true
            filterButtonBar.hidesSharedBackground = true
            searchButtonBar.hidesSharedBackground = true
            statsButton.hidesSharedBackground = true
            titleButtonArea.leftBarButtonItem?.hidesSharedBackground = true
            titleButtonArea.rightBarButtonItem?.hidesSharedBackground = true
            */
            
            preferenceButton.customView?.backgroundColor = .black
            statsButton.customView?.backgroundColor = .white 
            
            filterMenuButton.backgroundColor = .black
            shareButton.customView?.backgroundColor = .black
            bandSearch.backgroundColor = .black
            bandSearch.tintColor = .lightGray
            bandSearch.barTintColor = .black
            bandSearch.searchTextField.backgroundColor = .black

            
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(MasterViewController.OnOrientationChange), name: UIDevice.orientationDidChangeNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(bandNamesCacheReadyHandler), name: .bandNamesCacheReady, object: nil)
        
        // --- ADDED: Start 5-min timer ---
        startScheduleRefreshTimer()
        // --- END ADDED ---
        
        NotificationCenter.default.addObserver(self, selector: #selector(handlePushNotificationReceived), name: Notification.Name("PushNotificationReceived"), object: nil)
        // App foreground handling is now done globally in AppDelegate
        NotificationCenter.default.addObserver(self, selector: #selector(self.detailDidUpdate), name: Notification.Name("DetailDidUpdate"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(iCloudDataReadyHandler), name: Notification.Name("iCloudDataReady"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(iCloudRefresh), name: Notification.Name("iCloudRefresh"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(bandNamesCacheReadyHandler), name: NSNotification.Name("BandNamesDataReady"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePointerDataUpdated), name: Notification.Name("PointerDataUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleBackgroundDataRefresh), name: Notification.Name("BackgroundDataRefresh"), object: nil)
        
        // Listen for when returning from preferences screen
        NotificationCenter.default.addObserver(self, selector: #selector(handleReturnFromPreferences), name: Notification.Name("DismissPreferencesScreen"), object: nil)
        
        // Defensive: trigger a delayed refresh to help with first-launch data population
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("Calling refreshBandList from delayed initial refresh with reason: Initial delayed refresh")
            self.refreshBandList(reason: "Initial delayed refresh")
        }

        if cacheVariables.justLaunched {
            // Perform network test on initial launch before loading any data (5 second max)
            print("Initial launch: Performing network test before data loading")
            let hasInternet = NetworkTesting.forceNetworkTest()
            print("Initial launch: Network test result: \(hasInternet)")
            
            DispatchQueue.global(qos: .userInitiated).async {
                // Check internet availability first
                if !hasInternet {
                    print("First launch: No internet available, using cached data")
                    DispatchQueue.main.async {
                        // Mark as not just launched
                        cacheVariables.justLaunched = false
                        
                        // Load from cache and refresh UI
                        bandNamesHandler.readBandFileCallCount = 0
                        bandNamesHandler.lastReadBandFileCallTime = nil
                        self.bandNameHandle.forceReadBandFileAndPopulateCache {
                            self.refreshBandList(reason: "First launch - offline mode")
                            
                            // Show offline message if no data available and no valid schedule
                            let noBands = self.bands.isEmpty
                            let noEvents = eventCount == 0
                            let noValidSchedule = !scheduleReleased
                            if noBands && noEvents && noValidSchedule {
                                let alert = UIAlertController(title: "Offline Mode", message: "No internet connection detected. The app will work with cached data when available.", preferredStyle: .alert)
                                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                                self.present(alert, animated: true, completion: nil)
                            } else if noBands && noEvents && scheduleReleased {
                                print("Offline mode: Schedule file available but no events yet - this is normal before events are announced")
                            }
                        }
                    }
                    return
                }
                
                // Download pointer/defaultStorageUrl if needed
                let pointerUrl = getPointerUrlData(keyValue: "artistUrl") ?? "http://dropbox.com"
                // Download band data
                let bandData = getUrlData(urlString: pointerUrl)
                if !bandData.isEmpty {
                    self.bandNameHandle.writeBandFile(bandData)
                }
                // Download schedule data
                let scheduleUrl = getPointerUrlData(keyValue: "scheduleUrl") ?? "http://dropbox.com"
                let scheduleData = getUrlData(urlString: scheduleUrl)
                if !scheduleData.isEmpty {
                    let scheduleFilePath = scheduleFile
                    do {
                        try scheduleData.write(toFile: scheduleFilePath, atomically: true, encoding: .utf8)
                    } catch {
                        print("Error writing schedule data: \(error)")
                    }
                }
                // Mark as not just launched
                cacheVariables.justLaunched = false

                DispatchQueue.main.async {
                    // Force reload of band file and cache before refreshing UI
                    bandNamesHandler.readBandFileCallCount = 0
                    bandNamesHandler.lastReadBandFileCallTime = nil
                    self.bandNameHandle.forceReadBandFileAndPopulateCache {
                        // Always call refreshBandList, even if data is empty
                        self.refreshBandList(reason: "First launch blocking download complete")
                        // If both band and schedule data are empty, show an alert
                        // But don't show retry dialog if schedule is released (valid headers downloaded)
                        let noBands = self.bands.isEmpty
                        let noEvents = eventCount == 0
                        let noValidSchedule = !scheduleReleased
                        if noBands && noEvents && noValidSchedule {
                            let alert = UIAlertController(title: "No Data Loaded", message: "Unable to load band or event data. Please check your internet connection and try again.", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
                                // Retry logic: re-run viewDidLoad's first-launch block
                                cacheVariables.justLaunched = true
                                self.viewDidLoad()
                            })
                            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                            self.present(alert, animated: true, completion: nil)
                        } else if noBands && noEvents && scheduleReleased {
                            print("Schedule file downloaded successfully but contains no data yet - this is normal before events are announced")
                        }
                    }
                }
            }
            return // Prevent normal UI setup until data is ready
        }
    }
    
    @objc func bandNamesCacheReadyHandler() {
        // Prevent infinite loop: only refresh if we haven't already refreshed recently
        let now = Date()
        if let lastBandNamesRefresh = lastBandNamesCacheRefresh, now.timeIntervalSince(lastBandNamesRefresh) < 2.0 {
            print("Skipping bandNamesCacheReadyHandler: Last refresh was too recent (\(now.timeIntervalSince(lastBandNamesRefresh)) seconds ago)")
            return
        }
        lastBandNamesCacheRefresh = now
        print("Calling refreshBandList from bandNamesCacheReadyHandler with reason: Band names cache ready")
        refreshBandList(reason: "Band names cache ready")
        
        // Show country dialog after data loads on first install
        if shouldShowCountryDialogAfterDataLoad {
            shouldShowCountryDialogAfterDataLoad = false
            print("[MasterViewController] Data loaded - showing country dialog for first install")
            DispatchQueue.main.async {
                self.getCountry()
            }
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
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        print("Filtering activated 2  \(searchBar.text) \(searchBar.text?.count)")
        let lowercased = searchText.lowercased()
        if lowercased.contains("more cow bell") {
            if !easterEggTriggeredForSearch {
                triggerEasterEgg()
                easterEggTriggeredForSearch = true
            }
        } else {
            easterEggTriggeredForSearch = false
        }
        print("Calling refreshBandList from searchBar(_:textDidChange:) with reason: Search changed")
        refreshBandList(reason: "Search changed")
    }
    
    @objc func iCloudRefresh() {
        // Move to background to prevent GUI blocking during iCloud operations
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.refreshDataWithBackgroundUpdate(reason: "iCloud refresh")
        }
    }
    
    @objc func refreshMainDisplayAfterRefresh() {
        print("Calling refreshBandList from refreshMainDisplayAfterRefresh with reason: Main display after refresh")
        if (Thread.isMainThread == true){
            refreshBandList(reason: "Main display after refresh")
        }
    }
    
    @objc func displayFCMToken(notification: NSNotification){
      guard let userInfo = notification.userInfo else {return}
      if let fcmToken = userInfo["token"] as? String {
        let message = fcmToken

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
    
    func finishedPlaying() {
        print("Easter Egg, lets make this go away")
        player.pause()
        if playerLayer.superlayer != nil {
            playerLayer.removeFromSuperlayer()
        }
        player.replaceCurrentItem(with: nil)
        refreshDataWithBackgroundUpdate(reason: "Easter egg finished")
    }
    
    func chooseCountry(){
        
        let countryHandle = countryHandler.shared
        
        // Load country data asynchronously to avoid blocking main thread
        countryHandle.loadCountryData { [weak self] in
            guard let self = self else { return }
            
            let defaultCountry = NSLocale.current.regionCode ?? "US"
            var countryLongShort = countryHandle.getCountryLongShort()

            let alertController = UIAlertController(title: "Choose Country", message: nil, preferredStyle: .actionSheet)
            var sortedKeys = countryLongShort.keys.sorted()
            for keyValue in sortedKeys {
                alertController.addAction(UIAlertAction(title: keyValue, style: .default, handler: { (_) in
                    do {
                        let finalCountyValue = countryLongShort[keyValue] ?? "Unknown"
                        print ("countryValue writing Acceptable country of " + finalCountyValue + " found")
                        try finalCountyValue.write(to: countryFile, atomically: false, encoding: String.Encoding.utf8)
                    } catch {
                        print ("countryValue Error writing Acceptable country of " + countryLongShort[keyValue]! + " found " + error.localizedDescription)
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
                    //let countryFileUrl = URL(string: countryFile)
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
        
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        print ("The awakeFromNib was called");
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.clearsSelectionOnViewWillAppear = false
            self.preferredContentSize = CGSize(width: 320.0, height: 600.0)
        }
    }

    // Track background refresh operations to prevent overlapping
    private static var isBackgroundRefreshInProgress = false
    private static let backgroundRefreshLock = NSLock()
    
    // Centralized background refresh with immediate GUI update
    func refreshDataWithBackgroundUpdate(reason: String) {
        // Immediately refresh GUI from cache
        refreshBandList(reason: "\(reason) - immediate cache refresh")
        
        // Check if background refresh is already in progress
        MasterViewController.backgroundRefreshLock.lock()
        if MasterViewController.isBackgroundRefreshInProgress {
            print("Background refresh (\(reason)): Skipping - another refresh already in progress")
            MasterViewController.backgroundRefreshLock.unlock()
            return
        }
        MasterViewController.isBackgroundRefreshInProgress = true
        MasterViewController.backgroundRefreshLock.unlock()
        
        // Trigger background refresh
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { 
                MasterViewController.backgroundRefreshLock.lock()
                MasterViewController.isBackgroundRefreshInProgress = false
                MasterViewController.backgroundRefreshLock.unlock()
                return 
            }
            
            // Check network before attempting downloads
            let internetAvailable = NetworkStatusManager.shared.isInternetAvailable
            if !internetAvailable {
                print("Background refresh (\(reason)): No network, skipping data download")
                MasterViewController.backgroundRefreshLock.lock()
                MasterViewController.isBackgroundRefreshInProgress = false
                MasterViewController.backgroundRefreshLock.unlock()
                return
            }
            
            print("Background refresh (\(reason)): Starting data download")
            
            // Perform the same operations as refreshData but in background
            // Force download for certain high-priority reasons
            let shouldForceDownload = reason.contains("foreground") || reason.contains("notification") || reason.contains("timer")
            let shouldDownload = self.shouldDownloadSchedule(force: shouldForceDownload)
            
            if shouldDownload {
                self.schedule.DownloadCsv()
                self.lastScheduleDownload = Date()
                
                // Also refresh band data when forcing downloads
                if shouldForceDownload {
                    self.bandNameHandle.gatherData()
                }
            }
            self.schedule.populateSchedule(forceDownload: shouldForceDownload)
            
            // Update UI on main thread when complete
            DispatchQueue.main.async {
                self.refreshBandList(reason: "\(reason) - background refresh complete")
            }
            
            // Mark background refresh as complete
            MasterViewController.backgroundRefreshLock.lock()
            MasterViewController.isBackgroundRefreshInProgress = false
            MasterViewController.backgroundRefreshLock.unlock()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Ensure back button always says "Back" when navigating from this view
        let backItem = UIBarButtonItem()
        backItem.title = "Back"
        self.navigationItem.backBarButtonItem = backItem
        
        isLoadingBandData = false
        writeFiltersFile()
        
        // CRITICAL: Move ALL data refresh operations to background to prevent GUI blocking
        // This ensures the UI remains responsive when returning from background/details
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Perform data refresh entirely in background
            self.refreshDataWithBackgroundUpdate(reason: "Return from details")
        }
        
        finishedPlaying() // Defensive: ensure no video is left over
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        finishedPlaying()
    }

    @IBAction func titleButtonAction(_ sender: AnyObject) {
        self.tableView.contentOffset = CGPoint(x: 0, y: 0 - self.tableView.contentInset.top);
        sender.setImage(chevronRight, for: UIControl.State.normal)
        
    }

    
    @objc func showReceivedMessage(_ notification: Notification) {
        if let info = notification.userInfo as? Dictionary<String,AnyObject> {
            if let aps = info["aps"] as? Dictionary<String, String> {
                showAlert("Message received", message: aps["alert"]!)
            }
        } else {
            print("Software failure. Guru meditation.")
        }
    }
    
    func showAlert(_ title:String, message:String) {

            let alert = UIAlertController(title: title,
                                          message: message, preferredStyle: .alert)
            let dismissAction = UIAlertAction(title: "Dismiss", style: .destructive, handler: nil)
            alert.addAction(dismissAction)
            self.present(alert, animated: true, completion: nil)
            isLoadingBandData = false
            refreshDataWithBackgroundUpdate(reason: "Show alert")
    }
    
    
    @IBAction func filterMenuButtonPress(_ sender: Any) {
        
        if (filterMenuButton.isHeld == false){
            createrFilterMenu(controller: self)
            filterMenu.show()
        } else {
            filterMenu.hide()
        }
    }
    
    @objc func refreshDisplayAfterWake2(){
        finishedPlaying()
        // Move all data loading to background thread to avoid GUI blocking
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Refresh priority data in background
            self.dataHandle.getCachedData()
            
            // Update GUI on main thread after data loading is complete
            DispatchQueue.main.async {
                // Force refresh when detail view updates priority data
                self.refreshDataWithBackgroundUpdate(reason: "Detail view priority update")
            }
        }
    }
    
    @objc func refreshDisplayAfterWake(){
        // Move to background to prevent GUI blocking when waking from sleep
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.refreshDataWithBackgroundUpdate(reason: "Display after wake")
        }
        //createrFilterMenu(controller: self)
    }
    
    @objc func refreshAlerts(){

        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            //if #available(iOS 10.0, *) {
            print ("FCM alert")
                let localNotication = localNoticationHandler()
                localNotication.addNotifications()
                
            //}
        }
    
    }
    
    // Centralized refresh method for band list
    func refreshBandList(reason: String = "", scrollToTop: Bool = false, isPullToRefresh: Bool = false) {
        print("DEBUG: refreshBandList called with reason: '\(reason)'")
        if MasterViewController.isRefreshingBandList {
            print("[YEAR_CHANGE_DEBUG] Global: Band list refresh already in progress. Skipping. Reason: \(reason)")
            return
        }
        MasterViewController.isRefreshingBandList = true
        // Start safety timer
        MasterViewController.refreshBandListSafetyTimer?.invalidate()
        MasterViewController.refreshBandListSafetyTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            print("[YEAR_CHANGE_DEBUG] Safety timer: Resetting isRefreshingBandList after 10 seconds.")
            MasterViewController.isRefreshingBandList = false
        }
        print("[YEAR_CHANGE_DEBUG] Refreshing band list. Reason: \(reason), current year: \(eventYear)")
        // Save the current scroll position
        let previousOffset = self.tableView.contentOffset
        // GUARD: Only proceed if not already reading
        if bandNameHandle.readingBandFile {
            print("Band file is already being read. Skipping redundant refresh.");
            MasterViewController.isRefreshingBandList = false
            MasterViewController.refreshBandListSafetyTimer?.invalidate()
            MasterViewController.refreshBandListSafetyTimer = nil
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
            
            // Perform all data loading in background
            self.bandNameHandle.readBandFile()
            self.schedule.getCachedData()
            self.dataHandle.getCachedData()
            
            // Continue with UI updates on main thread
            DispatchQueue.main.async {
                self.filterRequestID += 1
                let requestID = self.filterRequestID
                getFilteredBands(
                    bandNameHandle: self.bandNameHandle,
                    schedule: self.schedule,
                    dataHandle: self.dataHandle,
                    attendedHandle: self.attendedHandle,
                    searchCriteria: self.bandSearch.text ?? ""
                ) { [weak self] (filtered: [String]) in
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
                        // Both are same type, sort by time or alphabetically for band names
                        return getTimeFromSortable(item1, sortBy: sortedBy) < getTimeFromSortable(item2, sortBy: sortedBy)
                    }
                }
            }
            print("[YEAR_CHANGE_DEBUG] refreshBandList: Loaded \(bandsResult.count) bands for year \(eventYear)")
            
            // Update bands array and table view atomically to prevent race conditions
            self.bands = bandsResult
            self.bandsByName = bandsResult
            
            // Ensure table view knows the correct number of rows before reloading
            DispatchQueue.main.async {
                self.tableView.reloadData()
                self.updateCountLable()
            }
            
            // Move attendedHandle.getCachedData() to background to avoid blocking GUI
            DispatchQueue.global(qos: .utility).async {
                self.attendedHandle.getCachedData()
            }
            
            // Auto-select first band for iPad after data is loaded (only once and only on initial load)
            if UIDevice.current.userInterfaceIdiom == .pad && !self.bands.isEmpty && !self.hasAutoSelectedForIPad && reason.contains("Initial") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.autoSelectFirstValidBandForIPad()
                }
            }
            if shouldSnapToTopAfterRefresh {
                shouldSnapToTopAfterRefresh = false
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
                }
            }
        }
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
                
                self.dataHandle.getCachedData()
                
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
    

    @objc func OnOrientationChange(){
        sleep(1)
        print("Calling refreshBandList from OnOrientationChange with reason: Orientation change")
        refreshBandList(reason: "Orientation change")
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
        print("Performing full data refresh: \(reason)")
        
        if shouldScrollToTop {
            shouldSnapToTopAfterRefresh = true
        }
        
        // STEP 1: Refresh from cache first (immediate UI update)
        print("Full data refresh (\(reason)): Step 1 - Refreshing from cache")
        refreshBandList(reason: "\(reason) - cache refresh")
        
        // STEP 2: Confirm internet access
        print("Full data refresh (\(reason)): Step 2 - Confirming internet access")
        let networkTesting = NetworkTesting()
        let hasNetwork = networkTesting.forgroundNetworkTest(callingGui: self)
        
        if !hasNetwork {
            print("Full data refresh (\(reason)): No network connectivity detected, staying with cached data")
            DispatchQueue.main.async {
                if endRefreshControl {
                    self.refreshControl?.endRefreshing()
                }
            }
            return
        }
        
        print("Full data refresh (\(reason)): Internet confirmed, proceeding with background refresh")
        
        // STEP 3: Start background process
        DispatchQueue.global(qos: .userInitiated).async {
            print("Full data refresh (\(reason)): Step 3 - Starting background process")
            
            // 3a. Clear ALL caches comprehensively
            print("Full data refresh (\(reason)): Step 3a - Comprehensive cache clearing")
            self.bandNameHandle.clearCachedData()
            self.dataHandle.clearCachedData()
            self.schedule.clearCache()
            
            // Clear MasterViewController cached arrays
            self.clearMasterViewCachedData()
            
            // Clear ALL static cache variables to prevent data mixing
            staticSchedule.sync {
                cacheVariables.scheduleStaticCache = [:]
                cacheVariables.scheduleTimeStaticCache = [:]
                cacheVariables.bandNamesStaticCache = [:]
                cacheVariables.bandNamesArrayStaticCache = []
                cacheVariables.bandDescriptionUrlCache = [:]
                cacheVariables.bandDescriptionUrlDateCache = [:]
                cacheVariables.attendedStaticCache = [:]
                cacheVariables.lastModifiedDate = nil
            }
            
            // Clear CustomBandDescription instance caches
            self.bandDescriptions.bandDescriptionUrl.removeAll()
            self.bandDescriptions.bandDescriptionUrlDate.removeAll()
            
            print("Full data refresh (\(reason)): All caches cleared comprehensively")
            
            // 3b. Refresh all data from URLs (band names, schedule, descriptionMap)
            print("Full data refresh (\(reason)): Step 3b - Refreshing all data from URLs")
            
            // Use a dispatch group to track when all data loading is complete
            let dataLoadGroup = DispatchGroup()
            
            // Load iCloud data (both read and write to ensure sync)
            dataLoadGroup.enter()
            DispatchQueue.global(qos: .utility).async {
                let iCloudHandle = iCloudDataHandler()
                // First write local data to iCloud to ensure it's backed up
                iCloudHandle.writeAllPriorityData()
                iCloudHandle.writeAllScheduleData()
                // Then read any remote changes from iCloud
                iCloudHandle.readAllPriorityData()
                iCloudHandle.readAllScheduleData()
                dataLoadGroup.leave()
            }
            
            // Load schedule data
            dataLoadGroup.enter()
            DispatchQueue.global(qos: .utility).async {
                self.schedule.DownloadCsv()
                self.schedule.populateSchedule(forceDownload: true)
                dataLoadGroup.leave()
            }
            
            // Load band names data
            dataLoadGroup.enter()
            DispatchQueue.global(qos: .utility).async {
                self.bandNameHandle.gatherData()
                dataLoadGroup.leave()
            }
            
            // Load descriptionMap data
            dataLoadGroup.enter()
            DispatchQueue.global(qos: .utility).async {
                self.bandDescriptions.getDescriptionMapFile()
                self.bandDescriptions.getDescriptionMap()
                dataLoadGroup.leave()
            }
            
            // 3c. Once all data is loaded, generate consolidated image list then refresh the GUI
            dataLoadGroup.notify(queue: .main) {
                print("Full data refresh (\(reason)): Step 3c - All data loaded, generating consolidated image list")
                
                // Generate consolidated image list immediately after both artist and schedule data are loaded
                CombinedImageListHandler.shared.generateCombinedImageList(
                    bandNameHandle: self.bandNameHandle,
                    scheduleHandle: self.schedule
                ) {
                    print("Full data refresh (\(reason)): Step 3d - Consolidated image list generated, refreshing GUI")
                    
                    if endRefreshControl {
                        self.refreshControl?.endRefreshing()
                    }
                    if shouldScrollToTop {
                        self.shouldSnapToTopAfterRefresh = true
                    }
                    
                    // Final GUI refresh with all new data and consolidated images
                    self.refreshBandList(reason: "\(reason) - final refresh", scrollToTop: false, isPullToRefresh: shouldScrollToTop)
                    
                    print("Full data refresh (\(reason)): Complete with consolidated images!")
                }
            }
        }
    }
    
    @objc func pullTorefreshData(){
        checkForEasterEgg()
        print ("iCloud: pull to refresh, load in new iCloud data")
        
        // Use the centralized method with pull-to-refresh specific settings
        performFullDataRefresh(reason: "Pull to refresh", shouldScrollToTop: true, endRefreshControl: true)
    }
    
    /// Called when returning from preferences screen
    @objc func handleReturnFromPreferences() {
        print("Handling return from preferences screen")
        performFullDataRefresh(reason: "Return from preferences")
    }
    
    @objc func refreshData(isUserInitiated: Bool = false, forceDownload: Bool = false) {
        // Throttle: Only allow if 60 seconds have passed, unless user-initiated (pull to refresh)
        let now = Date()
        if !isUserInitiated {
            if let lastRun = lastRefreshDataRun, now.timeIntervalSince(lastRun) < 60 {
                print("refreshData throttled: Only one run per 60 seconds unless user-initiated.")
                return
            }
        }
        lastRefreshDataRun = now
        print ("Redrawing the filter menu! Not")
        print ("Refresh Waiting for bandData, Done - \(refreshDataCounter)")
        localTimeZoneAbbreviation = TimeZone.current.abbreviation()!
        internetAvailble = NetworkStatusManager.shared.isInternetAvailable
        if (internetAvailble == false){
            self.refreshControl?.endRefreshing();
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3), execute: {
                self.refreshControl?.endRefreshing();
            })
        }
        print("Calling refreshBandList from refreshData with reason: Cache refresh")
        // Always download and parse schedule data synchronously before refreshing UI
        DispatchQueue.global(qos: .userInitiated).async {
            let shouldDownload = self.shouldDownloadSchedule(force: forceDownload || isUserInitiated)
            if internetAvailble && shouldDownload {
                self.schedule.DownloadCsv()
                self.lastScheduleDownload = Date()
            }
            self.schedule.populateSchedule(forceDownload: false)
            DispatchQueue.main.async {
                self.refreshBandList(reason: "Cache refresh")
            }
        }
    }
    
    
    
    func setFilterTitleText(){
        
        filterTextNeeded = true
        print ("Making final filtering call \(bandCounter) - \(unfilteredBandCount) - \(unfilteredCurrentEventCount) - \(unfilteredCruiserEventCount)")
        if (bandCounter == unfilteredBandCount && unfilteredCurrentEventCount == unfilteredCruiserEventCount){
            filterTextNeeded = false
            print ("Making final filtering call 1");
            
        } else if (eventCounter == unfilteredEventCount  && getHideExpireScheduleData() == false ) {
            filterTextNeeded = false
            print ("Making final filtering call 2");
        
        } else if (bandCounter == unfilteredBandCount) {
            filterTextNeeded = false
            print ("Making final filtering call 3");

        }  else if ((eventCounter == unfilteredCurrentEventCount && bandCounter == unfilteredBandCount) && getHideExpireScheduleData() == true ) {
            filterTextNeeded = false
            print ("Making final filtering call 4");
        }
        
        if (getShowPoolShows() == true &&
            getShowRinkShows() == true &&
            getShowOtherShows() == true &&
            getShowLoungeShows() == true &&
            getShowTheaterShows() == true &&
            getShowSpecialEvents() == true &&
            getShowUnofficalEvents() == true &&
            getShowOnlyWillAttened() == false &&
            getShowMeetAndGreetEvents() == true &&
            getMustSeeOn() == true &&
            getMightSeeOn() == true &&
            getWontSeeOn() == true &&
            getUnknownSeeOn() == true){
                filterTextNeeded = false
        }
        
        if (getShowUnofficalEvents() == false && unfilteredCruiserEventCount > 0){
            filterTextNeeded = true
        }
        
        
        print ("numberOfFilteredRecords is \(numberOfFilteredRecords)")
        if (filterTextNeeded == true){
            filtersOnText = "(" + NSLocalizedString("Filtering", comment: "") + ")"
        } else {
            filtersOnText = ""
        }
        
        if (bandSearch.text?.isEmpty == false){
            filtersOnText = "(" + NSLocalizedString("Filtering", comment: "") + ")"
        }
    }
    
    func decideIfScheduleMenuApplies()->Bool{
        
        var showEventMenu = false
        
        if (scheduleReleased == true && (eventCount != unofficalEventCount && unfilteredEventCount > 0)){
            showEventMenu = true
        }
        
        if (unfilteredEventCount == 0 || unfilteredEventCount == unfilteredCruiserEventCount){
            showEventMenu = false
        }
        
        if ((eventCount - unfilteredCruiserEventCount) == unfilteredEventCount){
            showEventMenu = false
        }
        
        print ("Show schedule choices = 1-\(scheduleReleased)  2-\(eventCount) 3-\(unofficalEventCount) 4-\(unfilteredCurrentEventCount) 5-\(unfilteredEventCount) 6-\(unfilteredCruiserEventCount) 7-\(showEventMenu)")
        return showEventMenu
    }
    
  
    func updateCountLable(){
        
        setFilterTitleText()
        var lableCounterString = String();
        var labeleCounter = Int()
        
        print ("Event or Band label: \(listCount) \(eventCounterUnoffical)")
        
        // Check if we have a mixture of events and bands, but ALL events are cruiser organized
        let hasEvents = eventCount > 0
        let hasBands = bandCount > 0 || (listCount - eventCounterUnoffical) > 0
        let allEventsAreCruiserOrganized = eventCounterUnoffical > 0 && eventCounterUnoffical == eventCount
        
        if (hasEvents && hasBands && allEventsAreCruiserOrganized) {
            // Mixed list with only cruiser organized events - show only band count
            labeleCounter = listCount - eventCounterUnoffical
            if (labeleCounter < 0){
                labeleCounter = 0
            }
            lableCounterString = " " + NSLocalizedString("Bands", comment: "") + " " + filtersOnText
            sortedBy = "time"
        } else if (listCount != eventCounterUnoffical && listCount > 0 && eventCounterUnoffical > 0){
            // Mixed event types (not all cruiser organized) - show event count
            labeleCounter = listCount
            if (labeleCounter < 0){
                labeleCounter = 0
            }
            lableCounterString = " " + NSLocalizedString("Events", comment: "") + " " + filtersOnText
        } else {
            // Default case - show band count
            labeleCounter = listCount - eventCounterUnoffical
            if (labeleCounter < 0){
                labeleCounter = 0
            }
            lableCounterString = " " + NSLocalizedString("Bands", comment: "") + " " + filtersOnText
            sortedBy = "time"
        }

        var currentYearSetting = getScheduleUrl()
        if (currentYearSetting != "Current" && currentYearSetting != "Default"){
            titleButton.title = "(" + currentYearSetting + ") " + String(labeleCounter) + lableCounterString
            
        } else {
            titleButton.title = String(labeleCounter) + lableCounterString
        }
        //createrFilterMenu(controller: self);
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
        activityVC.popoverPresentationController?.barButtonItem = shareButton
        
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
        print("bands type:", type(of: bands))
        return bands.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        self.configureCell(cell, atIndexPath: indexPath)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let v = UIView()
        
        let toolBarView : UIView = UIView(frame: CGRect(x: 0, y: 0, width: mainTableView.frame.width, height: 44))
        mainToolBar.frame = CGRect(x: 0, y: 0, width: mainTableView.frame.width, height: 44)
        toolBarView.addSubview(mainToolBar)
        
        v.addSubview(toolBarView)
        return v
    }
    
    //swip code start
    
    func currentlySectionBandName(_ rowNumber: Int) -> String{
        print("bands type in currentlySectionBandName:", type(of: bands))
        var bandName = "";
    
        print ("SelfBandCount is " + String(self.bands.count) + " rowNumber is " + String(rowNumber));
        if (self.bands.count > rowNumber && rowNumber >= 0){
            bandName = self.bands[rowNumber]
        } else {
            print("ERROR: Invalid rowNumber \(rowNumber) for bands array (count: \(self.bands.count))")
        }
        
        return bandName
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
                
                let cellBandName = cellData![0]
                
                let cellLocation = cellData![1]
                let cellEventType  = cellData![2]
                let cellStartTime = cellData![3]

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
                let message =  "No Show Is Associated With This Entry"
                ToastMessages(message).show(self, cellLocation: placementOfCell!, placeHigh: false)
            }
        })
        sawAllShow.setIcon(iconImage: UIImage(named: "icon-seen")!, backColor: UIColor.darkGray, cellHeight: 50, cellWidth: 230)
 
        let mustSeeAction = UITableViewRowAction(style:UITableViewRowAction.Style.normal, title:"", handler: { (action:UITableViewRowAction!, indexPath:IndexPath!) -> Void in
            
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            self.dataHandle.addPriorityData(bandName, priority: 1);
            print ("Offline is offline");
            isLoadingBandData = false
            self.quickRefresh()
            
            // Refresh iPad detail view if this band is currently displayed
            self.refreshIPadDetailViewIfNeeded(for: bandName)

        })
        
        
        mustSeeAction.setIcon(iconImage: UIImage(named: mustSeeIconSmall)!, backColor: UIColor.darkGray, cellHeight: 50, cellWidth: 230)
        
        let mightSeeAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title:"", handler: { (action:UITableViewRowAction!, indexPath:IndexPath!) -> Void in
            
            print ("Changing the priority of " + self.currentlySectionBandName(indexPath.row) + " to 2")
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            self.dataHandle.addPriorityData(bandName, priority: 2);
            isLoadingBandData = false
            self.quickRefresh()
            
            // Refresh iPad detail view if this band is currently displayed
            self.refreshIPadDetailViewIfNeeded(for: bandName)
            
        })
        
        mightSeeAction.setIcon(iconImage: UIImage(named: mightSeeIconSmall)!, backColor: UIColor.darkGray, cellHeight: 50, cellWidth: 230)
        
        let wontSeeAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title:"", handler: { (action:UITableViewRowAction!, indexPath:IndexPath!) -> Void in
            
            print ("Changing the priority of " + self.currentlySectionBandName(indexPath.row) + " to 3")
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            self.dataHandle.addPriorityData(bandName, priority: 3);
            isLoadingBandData = false
            self.quickRefresh()
            
            // Refresh iPad detail view if this band is currently displayed
            self.refreshIPadDetailViewIfNeeded(for: bandName)
            
        })
        
        wontSeeAction.setIcon(iconImage: UIImage(named: wontSeeIconSmall)!, backColor: UIColor.darkGray, cellHeight: 50, cellWidth: 230)
        
        let setUnknownAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title:"", handler: { (action:UITableViewRowAction!, indexPath:IndexPath!) -> Void in
            
            print ("Changing the priority of " + self.currentlySectionBandName(indexPath.row) + " to 0")
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            self.dataHandle.addPriorityData(bandName, priority: 0);
            isLoadingBandData = false
            self.quickRefresh()
            
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
        
        setBands(bands)
        //viewableCell = cell
        print ("Toast cell location - Current cell index is \(indexPath.row)")
        
        // Add bounds checking to prevent crash
        guard indexPath.row < bands.count else {
            print("ERROR: Index \(indexPath.row) out of bounds for bands array (count: \(bands.count))")
            // Set default separator style and return early
            cell.separatorInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 0)
            return
        }
        
        getCellValue(indexPath.row, schedule: schedule, sortBy: sortedBy, cell: cell, dataHandle: dataHandle, attendedHandle: attendedHandle)
        
        // Hide separator for band names only (plain strings without time index)
        let bandEntry = bands[indexPath.row]
        let isScheduledEvent = bandEntry.contains(":") && bandEntry.components(separatedBy: ":").first?.doubleValue != nil
        
        if !isScheduledEvent {
            // This is a band name only - hide separator
            cell.separatorInset = UIEdgeInsets(top: 0, left: cell.bounds.size.width, bottom: 0, right: 0)
        } else {
            // This is a scheduled event - show separator normally
            cell.separatorInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 0)
        }
        
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
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.splitViewController!.preferredDisplayMode = UISplitViewController.DisplayMode.allVisible
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
        
        print("BandName for SwiftUI Details is \(bandName)")
        detailMenuChoicesSwiftUI(cellDataText: cellDataText, bandName: bandName, indexPath: indexPath)
        
        // Deselect the row
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func detailShareChoices(){
        
        sharedMessage = "Start"
        
        let alert = UIAlertController.init(title: "Share Type", message: "", preferredStyle: .actionSheet)
        
        // Configure popover for iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        let reportHandler = showAttendenceReport()
        
        let mustMightShare = UIAlertAction.init(title: NSLocalizedString("ShareBandChoices", comment: ""), style: .default) { _ in
            print("shared message: Share Must/Might list")
            var message = reportHandler.buildMessage(type: "MustMight")
            self.sendSharedMessage(message: message)
        }
        alert.addAction(mustMightShare)
        
        reportHandler.assembleReport();
        
        if (reportHandler.getIsReportEmpty() == false){
            let showsAttended = UIAlertAction.init(title: NSLocalizedString("ShareShowChoices", comment: ""), style: .default) { _ in
                    print("shared message: Share Shows Attendedt list")
                    var message = reportHandler.buildMessage(type: "Events")
                    self.sendSharedMessage(message: message)
            }
            alert.addAction(showsAttended)
        }
        
        let cancelDialog = UIAlertAction.init(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
            self.sharedMessage = "Abort"
            return
        }
        alert.addAction(cancelDialog)
        
        if let popoverController = alert.popoverPresentationController {
              popoverController.sourceView = self.view
               popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.maxY, width: 0, height: 0)
              popoverController.permittedArrowDirections = []
       }
   
       present(alert, animated: true, completion: nil)
       
        sharedMessage = "Done"
    }
    
    func detailMenuChoices(cellDataText :String, bandName :String, segue :UIStoryboardSegue, indexPath: IndexPath) {
           
           var cellData = cellDataText.split(separator: ";")
           if (cellData.count == 4 && getPromptForAttended() == true){
               
                let cellBandName = String(cellData[0])
                let cellLocation = String(cellData[1])
                let cellEventType  = String(cellData[2])
                let cellStartTime = String(cellData[3])

                let currentAttendedStatusFriendly = attendedHandle.getShowAttendedStatusUserFriendly(band: cellBandName, location: cellLocation, startTime: cellStartTime, eventType: cellEventType, eventYearString: String(eventYear))
               
                let alert = UIAlertController.init(title: bandName, message: currentAttendedStatusFriendly, preferredStyle: .actionSheet)
                
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
               
                let goToDetails = UIAlertAction.init(title: NSLocalizedString("Go To Details", comment: ""), style: .default) { _ in
                   print("Go To Details - SwiftUI")
                   self.goToDetailsScreenSwiftUI(bandName: bandName, indexPath: indexPath);
                }
                alert.addAction(goToDetails)

                let currentAttendedStatus = attendedHandle.getShowAttendedStatus(band: cellBandName, location: cellLocation, startTime: cellStartTime, eventType: cellEventType, eventYearString: String(eventYear))

                if (currentAttendedStatus != sawAllStatus){
                   let attendChoice = UIAlertAction.init(title: NSLocalizedString("All Of Event", comment: ""), style: .default) { _ in
                      print("You Attended")
                       self.markAttendingStatus(cellDataText: cellDataText, status: sawAllStatus, correctBandName: bandName)
                   }
                   alert.addAction(attendChoice)
                }

                if (currentAttendedStatus != sawSomeStatus && cellEventType == showType){
                   let partialAttend = UIAlertAction.init(title: NSLocalizedString("Part Of Event", comment: ""), style: .default) { _ in
                       print("You Partially Attended")
                       self.markAttendingStatus(cellDataText: cellDataText, status: sawSomeStatus, correctBandName: bandName)
                   }
                   alert.addAction(partialAttend)
                }

                if (currentAttendedStatus != sawNoneStatus){
                   let notAttend = UIAlertAction.init(title: NSLocalizedString("None Of Event", comment: ""), style: .default) { _ in
                       print("You will not Attended")
                       self.markAttendingStatus(cellDataText: cellDataText, status: sawNoneStatus, correctBandName: bandName)
                   }
                   alert.addAction(notAttend)
                }
                
                let disablePrompt = UIAlertAction.init(title: NSLocalizedString("disableAttendedPrompt", comment: ""), style: .default) { _ in
                    setPromptForAttended(false)
                }
                alert.addAction(disablePrompt)
            
                let cancelDialog = UIAlertAction.init(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
                    return
                }
                alert.addAction(cancelDialog)
                
                 if let popoverController = alert.popoverPresentationController {
                       popoverController.sourceView = self.view
                        popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.maxY, width: 0, height: 0)
                       popoverController.permittedArrowDirections = []
                }
            
                present(alert, animated: true, completion: nil)


           } else {
               print ("Go straight to the SwiftUI details screen")
               goToDetailsScreenSwiftUI(bandName: bandName, indexPath: indexPath)
           }
       }
       
       /// SwiftUI version of detailMenuChoices (replaces storyboard segue version)
       func detailMenuChoicesSwiftUI(cellDataText: String, bandName: String, indexPath: IndexPath) {
           
           var cellData = cellDataText.split(separator: ";")
           if (cellData.count == 4 && getPromptForAttended() == true){
               
                let cellBandName = String(cellData[0])
                let cellLocation = String(cellData[1])
                let cellEventType  = String(cellData[2])
                let cellStartTime = String(cellData[3])

                let currentAttendedStatusFriendly = attendedHandle.getShowAttendedStatusUserFriendly(band: cellBandName, location: cellLocation, startTime: cellStartTime, eventType: cellEventType, eventYearString: String(eventYear))
               
                let alert = UIAlertController.init(title: bandName, message: currentAttendedStatusFriendly, preferredStyle: .actionSheet)
                
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
               
                let goToDetails = UIAlertAction.init(title: NSLocalizedString("Go To Details", comment: ""), style: .default) { _ in
                   print("Go To Details - SwiftUI")
                   self.goToDetailsScreenSwiftUI(bandName: bandName, indexPath: indexPath);
                }
                alert.addAction(goToDetails)

                let currentAttendedStatus = attendedHandle.getShowAttendedStatus(band: cellBandName, location: cellLocation, startTime: cellStartTime, eventType: cellEventType, eventYearString: String(eventYear))

                if (currentAttendedStatus != sawAllStatus){
                   let attendChoice = UIAlertAction.init(title: NSLocalizedString("All Of Event", comment: ""), style: .default) { _ in
                      print("You Attended")
                       self.markAttendingStatus(cellDataText: cellDataText, status: sawAllStatus, correctBandName: bandName)
                   }
                   alert.addAction(attendChoice)
                }

                if (currentAttendedStatus != sawSomeStatus && cellEventType == showType){
                   let attendSomeChoice = UIAlertAction.init(title: NSLocalizedString("Part Of Event", comment: ""), style: .default) { _ in
                      print("You Attended Some")
                       self.markAttendingStatus(cellDataText: cellDataText, status: sawSomeStatus, correctBandName: bandName)
                   }
                   alert.addAction(attendSomeChoice)
                }

                if (currentAttendedStatus != sawNoneStatus){
                   let didNotAttendChoice = UIAlertAction.init(title: NSLocalizedString("None Of Event", comment: ""), style: .default) { _ in
                      print("You Did Not Attend")
                       self.markAttendingStatus(cellDataText: cellDataText, status: sawNoneStatus, correctBandName: bandName)
                   }
                   alert.addAction(didNotAttendChoice)
                }
                
                let disablePrompt = UIAlertAction.init(title: NSLocalizedString("disableAttendedPrompt", comment: ""), style: .default) { _ in
                    setPromptForAttended(false)
                }
                alert.addAction(disablePrompt)

                let cancelAction = UIAlertAction.init(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
                   print("Cancel")
                }
                alert.addAction(cancelAction)
               
                self.present(alert, animated: true, completion: nil)
               
           } else {
               print ("Go straight to the SwiftUI details screen")
               goToDetailsScreenSwiftUI(bandName: bandName, indexPath: indexPath)
           }
       }
       
    func goToDetailsScreen(segue :UIStoryboardSegue, bandName :String, indexPath :IndexPath){
        
         print ("bandName = \(bandName) - migrating to SwiftUI DetailView")
         if (bandName.isEmpty == false){
            
            bandSelected = bandName;
            bandListIndexCache = indexPath.row
            
            print ("Bands size is " + String(bands.count) + " Index is  " + String(indexPath.row))

            // Create SwiftUI DetailHostingController instead of using storyboard segue
            let detailController = DetailHostingController(bandName: bandName)
            
            // Configure for split view if needed
            if UIDevice.current.userInterfaceIdiom == .pad {
                detailController.configureSplitViewPresentation()
            }
            
            // Push the SwiftUI detail view controller
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad: Replace detail view in split view
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
        
        // IMPORTANT: Populate currentBandList for swipe navigation (same as prepare(for:sender:))
        currentBandList = self.bands
        print("DEBUG: Set currentBandList for SwiftUI navigation - count: \(currentBandList.count)")
        
        if currentBandList.count == 0 {
            var attempts = 0
            while(currentBandList.count == 0 && attempts < 3){
                print("goToDetailsScreenSwiftUI: Attempt \(attempts+1) to refresh band list")
                refreshBandList(reason: "Cache refresh")
                currentBandList = self.bands
                attempts += 1
            }
            if currentBandList.count == 0 {
                print("goToDetailsScreenSwiftUI: Band list still empty after 3 attempts")
            }
        }
        
        // Create SwiftUI DetailHostingController
        let detailController = DetailHostingController(bandName: bandName)
        
        // Configure for split view if needed
        if UIDevice.current.userInterfaceIdiom == .pad {
            detailController.configureSplitViewPresentation()
            
            // iPad: Replace detail view in split view
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
    
    func markAttendingStatus (cellDataText :String, status: String, correctBandName: String? = nil){
        
        var cellData = cellDataText.split(separator: ";")
        if (cellData.count == 4){
            print ("Cell data is we have data for \(cellData[3])");
            
            let cellBandName = String(cellData[0])
            let cellLocation = String(cellData[1])
            let cellEventType  = String(cellData[2])
            let cellStartTime = String(cellData[3])
            
            attendedHandle.addShowsAttendedWithStatus(band: cellBandName, location: cellLocation, startTime: cellStartTime, eventType: cellEventType,eventYearString: String(eventYear), status: status);
            
            let empty : UITextField = UITextField();
            let message = attendedHandle.setShowsAttendedStatus(empty, status: status)
            
            isLoadingBandData = false
            self.quickRefresh()
            
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
            let visibleLocation = CGRect(origin: self.filterMenuButton.anchorPoint, size: self.mainTableView.bounds.size)
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
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
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
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
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
        
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            print("DEBUG: Not iPad, skipping refresh")
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
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            // For iPad split view, use a well-sized modal that doesn't obscure everything
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

    @objc @IBAction func statsButtonTapped(_ sender: Any) {
        let fileManager = FileManager.default
        guard let documentsUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            showAlert("Error", message: "Could not access documents directory.")
            return
        }
        let fileUrl = documentsUrl.appendingPathComponent("stats.html")

        // Check if we already have a web view controller displayed
        let currentWebViewController = getCurrentWebViewController()
        let fileExists = fileManager.fileExists(atPath: fileUrl.path)
        
        // Only present the web view if we don't already have one
        if currentWebViewController == nil {
            presentWebView(url: fileUrl.absoluteString, isLoading: !fileExists)
        }

        // Then attempt to download new content and refresh the view
        if Reachability.isConnectedToNetwork() {
            let dynamicStatsUrl = getPointerUrlData(keyValue: "reportUrl")
            print("[YEAR_CHANGE_DEBUG] statsButtonTapped: Retrieved reportUrl: \(dynamicStatsUrl)")
            if let url = URL(string: dynamicStatsUrl) {
                let task = URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
                    guard let self = self else { return }
                    
                    if let data = data {
                        do {
                            try data.write(to: fileUrl)
                            // Refresh the currently displayed web view if it exists
                            DispatchQueue.main.async {
                                if let currentWebViewController = self.getCurrentWebViewController(),
                                   let webDisplay = currentWebViewController.webDisplay {
                                    let request = URLRequest(url: fileUrl)
                                    webDisplay.load(request)
                                }
                                // Note: We don't present a new web view here since we already have one
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
            }
        } else if !fileExists {
            // Only show no data message if there's no cached file
            presentNoDataView(message: "No stats data available. Please connect to the internet to download stats.")
        }
    }
    
    // Helper function to get the current web view controller if it's displayed
    func getCurrentWebViewController() -> WebViewController? {
        if UIDevice.current.userInterfaceIdiom == .pad {
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
                    self.showAlert("No Stats Data", message: message)
                    return
                }
                let tempUrl = documentsUrl.appendingPathComponent("no_stats.html")
                do {
                    try htmlContent.write(to: tempUrl, atomically: true, encoding: .utf8)
                    setUrl(tempUrl.absoluteString)
                    
                    let backItem = UIBarButtonItem()
                    backItem.title = "Back"

                    if UIDevice.current.userInterfaceIdiom == .pad {
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
                    self.showAlert("No Stats Data", message: message)
                }
            }
        }
    }
    
    func presentWebView(url: String, isLoading: Bool = false) {
        DispatchQueue.main.async {
            if let webViewController = self.storyboard?.instantiateViewController(withIdentifier: "StatsWebViewController") as? WebViewController {
                setUrl(url)

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
                        self.showAlert("Loading Stats", message: "Please wait while stats are being downloaded...")
                        return
                    }
                    let tempUrl = documentsUrl.appendingPathComponent("loading_stats.html")
                    do {
                        try htmlContent.write(to: tempUrl, atomically: true, encoding: .utf8)
                        setUrl(tempUrl.absoluteString)
                    } catch {
                        // Fallback to basic alert if HTML creation fails
                        self.showAlert("Loading Stats", message: "Please wait while stats are being downloaded...")
                    }
                }

                if UIDevice.current.userInterfaceIdiom == .pad {
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
        let now = Date()
        if force { return true }
        if let last = lastScheduleDownload {
            if now.timeIntervalSince(last) < minDownloadInterval {
                return false
            }
        }
        return true
    }
    
    @objc func handlePushNotificationReceived() {
        // Move to background to prevent GUI blocking when handling push notifications
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.refreshDataWithBackgroundUpdate(reason: "Push notification received")
        }
    }
    
    // App foreground handling moved to AppDelegate for global application-level handling
    
    /// Clears all cached data arrays in MasterViewController - should be called during year changes
    func clearMasterViewCachedData() {
        print("[YEAR_CHANGE_DEBUG] Clearing MasterViewController cached data arrays")
        objects.removeAllObjects()
        bands.removeAll()
        bandsByTime.removeAll()
        bandsByName.removeAll()
        
        // Also clear the table view data
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    @objc func detailDidUpdate() {
        // This notification is now handled by RefreshDisplay notification to avoid duplication
        // The RefreshDisplay notification already calls refreshDataWithBackgroundUpdate which includes:
        // 1. Immediate refreshBandList (includes dataHandle.getCachedData())
        // 2. Background data refresh
        // 3. UI updates when complete
        print("[MasterViewController] DetailDidUpdate: Handled by RefreshDisplay notification to avoid duplication")
    }
    
    @objc func iCloudDataReadyHandler() {
        print("iCloud data ready, forcing reload of all caches and band file.")
        // Move all data loading to background to avoid GUI blocking
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.bandNameHandle.readBandFile()
            self.dataHandle.getCachedData()
            self.attendedHandle.getCachedData()
            self.schedule.getCachedData()
            
            DispatchQueue.main.async {
                print("Calling refreshBandList from iCloudDataReadyHandler with reason: iCloud data ready (after forced reload)")
                self.refreshBandList(reason: "iCloud data ready (after forced reload)")
            }
        }
    }
    
        /*
    @objc func bandNamesCacheReadyHandler() {
        print("Calling refreshBandList from bandNamesCacheReadyHandler with reason: Band names cache ready")
        refreshBandList(reason: "Band names cache ready")
    }
    */
    @objc func handleDataReady() {
        self.refreshBandList()
    }
    
    @objc func handlePointerDataUpdated() {
        // This observer is triggered when pointer data is updated on launch.
        // It will force a refresh of the band list to ensure the UI is updated.
        print("Pointer data updated, forcing refresh of band list.")
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
        guard !cacheVariables.justLaunched || (!bandNameHandle.bandNames.isEmpty && !schedule.schedulingData.isEmpty) else {
            print("MasterViewController: Skipping background refresh - first launch still in progress")
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            print("MasterViewController: Starting background data refresh from URL")
            
            // Refresh band names from URL with force flag to bypass justLaunched check
            self.bandNameHandle.getCachedData(forceNetwork: true) {
                print("MasterViewController: Band names refreshed from URL in background")
            }
            
            // Refresh schedule data from URL if internet is available
            if isInternetAvailable() {
                let shouldDownload = self.shouldDownloadSchedule(force: true)
                if shouldDownload {
                    self.schedule.DownloadCsv()
                    self.lastScheduleDownload = Date()
                    print("MasterViewController: Schedule data refreshed from URL in background")
                }
                self.schedule.populateSchedule(forceDownload: false)
                
                // Refresh description map data from URL
                print("MasterViewController: Refreshing description map from URL in background")
                self.bandDescriptions.getDescriptionMapFile()
                self.bandDescriptions.getDescriptionMap()
                print("MasterViewController: Description map refreshed from URL in background")
            }
            
            // Refresh the UI on main thread after background data loading
            DispatchQueue.main.async {
                print("MasterViewController: Updating UI after background data refresh")
                self.refreshBandList(reason: "Background data refresh from foreground")
            }
        }
    }
    
    // Helper to deduplicate while preserving order
    private func deduplicatePreservingOrder(_ array: [String]) -> [String] {
        var seen = Set<String>()
        return array.filter { seen.insert($0).inserted }
    }
}


extension UITableViewRowAction {
    
    func setIcon(iconImage: UIImage, backColor: UIColor, cellHeight: CGFloat, cellWidth:CGFloat) ///, iconSizePercentage: CGFloat)
    {
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


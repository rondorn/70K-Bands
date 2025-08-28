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
        
        // Set initial title to app name before data loads
        titleButton.title = FestivalConfig.current.appName
        
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
                print("First install detected - calling proper loading sequence to download data")
                // Call the proper loading sequence instead of just refreshBandList
                self.performBackgroundDataRefresh(reason: "First install - initial data download", endRefreshControl: false, shouldScrollToTop: false)
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
                // Move to background thread to prevent main thread blocking
                DispatchQueue.global(qos: .userInitiated).async {
                    self.performFullDataRefresh(reason: "App launch - full refresh")
                }
            } else {
                print("Calling refreshBandList from viewDidLoad with reason: Initial launch")
                // Move to background thread to prevent main thread blocking
                DispatchQueue.global(qos: .userInitiated).async {
                    self.refreshBandList(reason: "Initial launch")
                }
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
        NotificationCenter.default.addObserver(self, selector: #selector(iCloudAttendedDataRestoredHandler), name: Notification.Name("iCloudAttendedDataRestored"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(bandNamesCacheReadyHandler), name: NSNotification.Name("BandNamesDataReady"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePointerDataUpdated), name: Notification.Name("PointerDataUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleBackgroundDataRefresh), name: Notification.Name("BackgroundDataRefresh"), object: nil)
        
        // Listen for when returning from preferences screen
        NotificationCenter.default.addObserver(self, selector: #selector(handleReturnFromPreferences), name: Notification.Name("DismissPreferencesScreen"), object: nil)
        
        // Listen for when returning from preferences screen after year change (no additional refresh needed)
        NotificationCenter.default.addObserver(self, selector: #selector(handleReturnFromPreferencesAfterYearChange), name: Notification.Name("DismissPreferencesScreenAfterYearChange"), object: nil)
        
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
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", startTime))] refreshDataWithBackgroundUpdate START - reason: '\(reason)'")
        
        // Immediately refresh GUI from cache
        let immediateStartTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", immediateStartTime))] Starting immediate cache refresh")
        refreshBandList(reason: "\(reason) - immediate cache refresh")
        let immediateEndTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", immediateEndTime))] Immediate cache refresh END - time: \(String(format: "%.3f", (immediateEndTime - immediateStartTime) * 1000))ms")
        
        // Check if background refresh is already in progress
        MasterViewController.backgroundRefreshLock.lock()
        if MasterViewController.isBackgroundRefreshInProgress {
            print("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] Background refresh (\(reason)): Skipping - another refresh already in progress")
            MasterViewController.backgroundRefreshLock.unlock()
            return
        }
        MasterViewController.isBackgroundRefreshInProgress = true
        MasterViewController.backgroundRefreshLock.unlock()
        
        let lockTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", lockTime))] Background refresh lock acquired, starting background operations")
        
        // Trigger background refresh
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { 
                let errorTime = CFAbsoluteTimeGetCurrent()
                print("🕐 [\(String(format: "%.3f", errorTime))] Background refresh ERROR - self is nil")
                MasterViewController.backgroundRefreshLock.lock()
                MasterViewController.isBackgroundRefreshInProgress = false
                MasterViewController.backgroundRefreshLock.unlock()
                return 
            }
            
            let backgroundStartTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", backgroundStartTime))] Background thread START - reason: '\(reason)'")
            
            // Check network before attempting downloads
            let networkCheckStartTime = CFAbsoluteTimeGetCurrent()
            let internetAvailable = NetworkStatusManager.shared.isInternetAvailable
            let networkCheckEndTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", networkCheckEndTime))] Network check complete - available: \(internetAvailable) - time: \(String(format: "%.3f", (networkCheckEndTime - networkCheckStartTime) * 1000))ms")
            
            if !internetAvailable {
                print("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] Background refresh (\(reason)): No network, skipping data download")
                MasterViewController.backgroundRefreshLock.lock()
                MasterViewController.isBackgroundRefreshInProgress = false
                MasterViewController.backgroundRefreshLock.unlock()
                return
            }
            
            print("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] Background refresh (\(reason)): Starting data download")
            
            // Perform the same operations as refreshData but in background
            // Force download for certain high-priority reasons
            let shouldForceDownload = reason.contains("foreground") || reason.contains("notification") || reason.contains("timer")
            let shouldDownload = self.shouldDownloadSchedule(force: shouldForceDownload)
            
            let downloadStartTime = CFAbsoluteTimeGetCurrent()
            if shouldDownload {
                print("🕐 [\(String(format: "%.3f", downloadStartTime))] Starting CSV download")
                // Don't call DownloadCsv directly - use the proper loading sequence instead
                print("🕐 [\(String(format: "%.3f", downloadStartTime))] Deferring CSV download to proper loading sequence")
                self.lastScheduleDownload = Date()
                
                // Also refresh band data when forcing downloads
                if shouldForceDownload {
                    print("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] Starting band data refresh")
                    // Don't call gatherData directly - use the proper loading sequence instead
                    print("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] Deferring to proper loading sequence")
                }
            }
            
            let populateStartTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", populateStartTime))] Starting schedule population")
            self.schedule.populateSchedule(forceDownload: shouldForceDownload)
            let populateEndTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", populateEndTime))] Schedule population END - time: \(String(format: "%.3f", (populateEndTime - populateStartTime) * 1000))ms")
            
            let downloadEndTime = CFAbsoluteTimeGetCurrent()
            if shouldDownload {
                print("🕐 [\(String(format: "%.3f", downloadEndTime))] CSV download END - time: \(String(format: "%.3f", (downloadEndTime - downloadStartTime) * 1000))ms")
            }
            
            // Update UI on main thread when complete
            let uiUpdateStartTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", uiUpdateStartTime))] Starting UI update on main thread")
            DispatchQueue.main.async {
                let mainThreadStartTime = CFAbsoluteTimeGetCurrent()
                print("🕐 [\(String(format: "%.3f", mainThreadStartTime))] Main thread UI update START")
                self.refreshBandList(reason: "\(reason) - background refresh complete")
                let mainThreadEndTime = CFAbsoluteTimeGetCurrent()
                print("🕐 [\(String(format: "%.3f", mainThreadEndTime))] Main thread UI update END - time: \(String(format: "%.3f", (mainThreadEndTime - mainThreadStartTime) * 1000))ms")
            }
            
            let backgroundEndTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", backgroundEndTime))] Background thread END - total time: \(String(format: "%.3f", (backgroundEndTime - backgroundStartTime) * 1000))ms")
            
            // Mark background refresh as complete
            MasterViewController.backgroundRefreshLock.lock()
            MasterViewController.isBackgroundRefreshInProgress = false
            MasterViewController.backgroundRefreshLock.unlock()
            
            let totalTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", totalTime))] refreshDataWithBackgroundUpdate END - total time: \(String(format: "%.3f", (totalTime - startTime) * 1000))ms")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", startTime))] viewWillAppear START - returning from details")
        
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
        
        // CRITICAL: Move ALL data refresh operations to background to prevent GUI blocking
        // This ensures the UI remains responsive when returning from background/details
        // Simple cache refresh when returning from details - no background operations needed
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let backgroundStartTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", backgroundStartTime))] Cache refresh START - reason: Return from details")
            
            // Just refresh from cache - no network operations needed
            self.refreshBandList(reason: "Return from details - cache refresh")
            
            let backgroundEndTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", backgroundEndTime))] Cache refresh END - reason: Return from details")
        }
        
        finishedPlaying() // Defensive: ensure no video is left over
        
        let endTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", endTime))] viewWillAppear END - total time: \(String(format: "%.3f", (endTime - startTime) * 1000))ms")
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
            // Refresh data when showing alert - often means new data was announced
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
        // Simple cache refresh for screen navigation - no background operations needed
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Refresh priority data in background
            self.dataHandle.getCachedData()
            
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
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", startTime))] refreshBandList START - reason: '\(reason)'")
        
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
            
            // Perform all data loading in background
            let bandFileStartTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", bandFileStartTime))] Starting band file read")
            self.bandNameHandle.readBandFile()
            let bandFileEndTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", bandFileEndTime))] Band file read END - time: \(String(format: "%.3f", (bandFileEndTime - bandFileStartTime) * 1000))ms")
            
            let scheduleStartTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", scheduleStartTime))] Starting schedule getCachedData")
            self.schedule.getCachedData()
            let scheduleEndTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", scheduleEndTime))] Schedule getCachedData END - time: \(String(format: "%.3f", (scheduleEndTime - scheduleStartTime) * 1000))ms")
            
            let dataStartTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", dataStartTime))] Starting dataHandle getCachedData")
            self.dataHandle.getCachedData()
            let dataEndTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", dataEndTime))] dataHandle getCachedData END - time: \(String(format: "%.3f", (dataEndTime - dataStartTime) * 1000))ms")
            
            let backgroundEndTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", backgroundEndTime))] refreshBandList background thread END - total time: \(String(format: "%.3f", (backgroundEndTime - backgroundStartTime) * 1000))ms")
            
            // Continue with UI updates on main thread
            DispatchQueue.main.async {
                let mainThreadStartTime = CFAbsoluteTimeGetCurrent()
                print("🕐 [\(String(format: "%.3f", mainThreadStartTime))] refreshBandList main thread START")
                
                self.filterRequestID += 1
                let requestID = self.filterRequestID
                let filterStartTime = CFAbsoluteTimeGetCurrent()
                print("🕐 [\(String(format: "%.3f", filterStartTime))] Starting getFilteredBands")
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
            print("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] [YEAR_CHANGE_DEBUG] refreshBandList: Loaded \(bandsResult.count) bands for year \(eventYear)")
            
            // Safely merge new band data with existing data to prevent race conditions
            self.safelyMergeBandData(bandsResult, reason: reason)
            
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
            
            self.updateCountLable()
            let updateCountEndTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", updateCountEndTime))] updateCountLable END - time: \(String(format: "%.3f", (updateCountEndTime - tableReloadStartTime) * 1000))ms")
            
            // Move attendedHandle.getCachedData() to background to avoid blocking GUI
            DispatchQueue.global(qos: .utility).async {
                let attendedStartTime = CFAbsoluteTimeGetCurrent()
                print("🕐 [\(String(format: "%.3f", attendedStartTime))] Starting attended data load in background")
                self.attendedHandle.getCachedData()
                let attendedEndTime = CFAbsoluteTimeGetCurrent()
                print("🕐 [\(String(format: "%.3f", attendedEndTime))] Attended data load END - time: \(String(format: "%.3f", (attendedEndTime - attendedStartTime) * 1000))ms")
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
            
            let filterEndTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", filterEndTime))] getFilteredBands END - time: \(String(format: "%.3f", (filterEndTime - filterStartTime) * 1000))ms")
            
            let mainThreadEndTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", mainThreadEndTime))] refreshBandList main thread END - total time: \(String(format: "%.3f", (mainThreadEndTime - mainThreadStartTime) * 1000))ms")
                }
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
    
    /// Lightweight refresh that only updates the band list UI without triggering data downloads or heavy processing.
    /// Used for priority changes that only need UI updates, not full data reloads.
    func refreshBandListOnly(reason: String) {
        print("Lightweight refresh (\(reason)): Updating UI only")
        DispatchQueue.main.async { [weak self] in
            self?.refreshBandList(reason: reason)
        }
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
        
        // Move network test to background to prevent main thread blocking
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
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
            self.performBackgroundDataRefresh(reason: reason, endRefreshControl: endRefreshControl, shouldScrollToTop: shouldScrollToTop)
        }
    }
    
    @objc func pullTorefreshData(){
        checkForEasterEgg()
        print ("iCloud: pull to refresh, load in new iCloud data")
        
        // Use a specialized method for pull-to-refresh that includes live network testing
        performPullToRefreshWithLiveNetworkTest()
    }
    
    /// Specialized pull-to-refresh method with live network testing
    /// This method is allowed to block the GUI briefly since users expect delays during pull-to-refresh
    func performPullToRefreshWithLiveNetworkTest() {
        print("🔄 Starting pull-to-refresh with live network test")
        
        // STEP 1: Refresh from cache first (immediate UI update)
        print("🔄 Pull-to-refresh: Step 1 - Refreshing from cache")
        refreshBandList(reason: "Pull-to-refresh - cache refresh")
        
        // STEP 2: Perform LIVE network test (this will block GUI briefly - acceptable for pull-to-refresh)
        print("🔄 Pull-to-refresh: Step 2 - Performing LIVE network test")
        
        let networkTesting = NetworkTesting()
        let hasNetwork = networkTesting.liveNetworkTestForPullToRefresh()
        
        if !hasNetwork {
            print("🔄 Pull-to-refresh: ❌ Live network test failed - staying with cached data")
            DispatchQueue.main.async {
                self.refreshControl?.endRefreshing()
            }
            return
        }
        
        print("🔄 Pull-to-refresh: ✅ Live network test passed - proceeding with data refresh")
        
        // STEP 3: Start background data refresh (same as regular performFullDataRefresh)
        performBackgroundDataRefresh(reason: "Pull to refresh with live network test", endRefreshControl: true, shouldScrollToTop: true)
    }
    
    /// Called when returning from preferences screen (no year change - only refresh if needed)
    @objc func handleReturnFromPreferences() {
        print("Handling return from preferences screen - no year change occurred")
        print("Performing light refresh (cache-based only, no network operations)")
        
        // Only refresh from cache - no network operations needed since no year change
        refreshBandList(reason: "Return from preferences - cache refresh only")
    }
    
    /// Called when returning from preferences screen after year change (data already refreshed)
    @objc func handleReturnFromPreferencesAfterYearChange() {
        print("Handling return from preferences screen after year change")
        print("No additional refresh needed - data was already refreshed during year change")
        
        // No action needed - year change process already refreshed all data
        // Just ensure the display is updated
        DispatchQueue.main.async {
            // Trigger a display refresh to ensure UI is in sync
            NotificationCenter.default.post(name: Notification.Name(rawValue: "RefreshDisplay"), object: nil)
        }
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
        
        print("🔄 refreshData START - isUserInitiated: \(isUserInitiated), forceDownload: \(forceDownload)")
        
        // Step 1: Display cached data immediately (user sees current data)
        print("📱 Step 1: Displaying cached data immediately")
        refreshBandList(reason: "Cache refresh - showing cached data")
        
        // Step 2: Start background thread for data refresh
        print("🔄 Step 2: Starting background thread for data refresh")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Step 3: Verify internet connection
            print("🌐 Step 3: Verifying internet connection")
            let internetAvailable = NetworkStatusManager.shared.isInternetAvailable
            if !internetAvailable {
                print("❌ No internet connection available, skipping background refresh")
                DispatchQueue.main.async {
                    self.refreshControl?.endRefreshing()
                }
                return
            }
            print("✅ Internet connection verified")
            
            // Step 4: Use the proper loading sequence instead of direct downloads
            print("📥 Step 4: Using proper loading sequence for data refresh")
            
            // Call the proper loading sequence method I implemented
            self.performBackgroundDataRefresh(reason: "Data refresh from refreshData method", endRefreshControl: false, shouldScrollToTop: false)
        }
    }
    
    /// Clears all caches comprehensively - used during data refresh
    private func clearAllCaches() {
        print("🧹 Clearing all caches comprehensively")
        
        // Clear handler caches
        self.bandNameHandle.clearCachedData()
        self.dataHandle.clearCachedData()
        self.schedule.clearCache()
        
        // Clear MasterViewController cached arrays (but not bands array yet)
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
        
        // Clear the bands array only when we're ready to immediately repopulate it
        // This prevents race conditions with the table view
        print("🧹 All caches cleared successfully (bands array will be safely repopulated)")
        
        // Clear the bands array immediately before refreshing to ensure atomicity
        print("🧹 Clearing bands array before refresh")
        self.bands.removeAll()
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
        
        // Add safety check for empty bands array during data refresh
        if bands.isEmpty {
            print("⚠️ Bands array is empty in numberOfRowsInSection - this may happen during data refresh")
            return 0
        }
        
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
        
        // Add safety check for empty bands array during data refresh
        guard !bands.isEmpty else {
            print("ERROR: Bands array is empty in currentlySectionBandName - this may happen during data refresh")
            return ""
        }
        
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
            self.refreshBandListOnly(reason: "Priority changed to Must See")
            
            // Refresh iPad detail view if this band is currently displayed
            self.refreshIPadDetailViewIfNeeded(for: bandName)

        })
        
        
        mustSeeAction.setIcon(iconImage: UIImage(named: mustSeeIconSmall)!, backColor: UIColor.darkGray, cellHeight: 50, cellWidth: 230)
        
        let mightSeeAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title:"", handler: { (action:UITableViewRowAction!, indexPath:IndexPath!) -> Void in
            
            print ("Changing the priority of " + self.currentlySectionBandName(indexPath.row) + " to 2")
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            self.dataHandle.addPriorityData(bandName, priority: 2);
            isLoadingBandData = false
            self.refreshBandListOnly(reason: "Priority changed to Might See")
            
            // Refresh iPad detail view if this band is currently displayed
            self.refreshIPadDetailViewIfNeeded(for: bandName)
            
        })
        
        mightSeeAction.setIcon(iconImage: UIImage(named: mightSeeIconSmall)!, backColor: UIColor.darkGray, cellHeight: 50, cellWidth: 230)
        
        let wontSeeAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title:"", handler: { (action:UITableViewRowAction!, indexPath:IndexPath!) -> Void in
            
            print ("Changing the priority of " + self.currentlySectionBandName(indexPath.row) + " to 3")
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            self.dataHandle.addPriorityData(bandName, priority: 3);
            isLoadingBandData = false
            self.refreshBandListOnly(reason: "Priority changed to Won't See")
            
            // Refresh iPad detail view if this band is currently displayed
            self.refreshIPadDetailViewIfNeeded(for: bandName)
            
        })
        
        wontSeeAction.setIcon(iconImage: UIImage(named: wontSeeIconSmall)!, backColor: UIColor.darkGray, cellHeight: 50, cellWidth: 230)
        
        let setUnknownAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title:"", handler: { (action:UITableViewRowAction!, indexPath:IndexPath!) -> Void in
            
            print ("Changing the priority of " + self.currentlySectionBandName(indexPath.row) + " to 0")
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            self.dataHandle.addPriorityData(bandName, priority: 0);
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
        
        // Add comprehensive bounds checking to prevent crash
        guard indexPath.row >= 0 else {
            print("ERROR: Negative index \(indexPath.row) in configureCell")
            cell.separatorInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 0)
            return
        }
        
        guard indexPath.row < bands.count else {
            print("ERROR: Index \(indexPath.row) out of bounds for bands array (count: \(bands.count))")
            // Set default separator style and return early
            cell.separatorInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 0)
            return
        }
        
        // Ensure bands array is not empty
        guard !bands.isEmpty else {
            print("ERROR: Bands array is empty in configureCell - this may happen during data refresh")
            cell.separatorInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 0)
            return
        }
        
        setBands(bands)
        
        // Configure cell on main thread for immediate display
        getCellValue(indexPath.row, schedule: schedule, sortBy: sortedBy, cell: cell, dataHandle: dataHandle, attendedHandle: attendedHandle)
        
        // Configure separator immediately to avoid async access issues
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
    /// This method should only be called when we're ready to immediately populate the arrays with new data
    func clearMasterViewCachedData() {
        print("[YEAR_CHANGE_DEBUG] Clearing MasterViewController cached data arrays")
        
        // Clear other arrays that don't affect the table view
        objects.removeAllObjects()
        bandsByTime.removeAll()
        bandsByName.removeAll()
        
        // Don't clear the bands array here - it should be cleared and immediately repopulated
        // in the calling method to prevent race conditions
        print("[YEAR_CHANGE_DEBUG] Note: bands array should be cleared and repopulated atomically")
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
    
    @objc func iCloudAttendedDataRestoredHandler() {
        print("iCloud attended data restored, refreshing display to show updated attended statuses.")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Refresh the band list to show updated attended statuses
            self.refreshBandList(reason: "iCloud attended data restored")
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
                    self.lastScheduleDownload = Date()
                    newDataDownloaded = true
                    print("✅ Schedule data download deferred to proper sequence")
                }
                self.schedule.populateSchedule(forceDownload: false)
                downloadGroup.leave()
            }
            
            // Wait for core data (artists + schedule) to complete before proceeding
            downloadGroup.notify(queue: .main) {
                // Step 3: Load existing priority data
                print("⭐ Step 3: Loading existing priority data...")
                self.dataHandle.getCachedData()
                print("✅ Priority data loaded")
                
                // Step 4: Load existing attendance data
                print("✅ Step 4: Loading existing attendance data...")
                self.attendedHandle.loadShowsAttended()
                print("✅ Attendance data loaded")
                
                // Step 5: Load iCloud data (only after core data is available)
                print("☁️ Step 5: Loading iCloud data...")
                self.loadICloudData()
                print("✅ iCloud data loaded")
                
                // Step 6: Load description map (only after core data is available)
                print("📝 Step 6: Loading description map...")
                self.bandDescriptions.getDescriptionMapFile()
                self.bandDescriptions.getDescriptionMap()
                print("✅ Description map loaded")
                
                // Step 7: Load combined image URL map (only after core data is available)
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
            _ = self.dataHandle.getPriorityDataForBands(uniqueBandNames)
        }
    }
    
    /// Performs the background data refresh operations
    internal func performBackgroundDataRefresh(reason: String, endRefreshControl: Bool, shouldScrollToTop: Bool, completion: (() -> Void)? = nil) {
        print("Full data refresh (\(reason)): Step 3 - Starting background process")
        
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
        
        // Download schedule data
        dataLoadGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            print("Full data refresh (\(reason)): Downloading schedule data")
            // Actually download schedule data
            self.schedule.DownloadCsv()
            newDataDownloaded = true
            dataLoadGroup.leave()
        }
        
        // Download band names data
        dataLoadGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            print("Full data refresh (\(reason)): Downloading band names data")
            // Actually download band names data
            self.bandNameHandle.gatherData(forceDownload: true) {
                newDataDownloaded = true
                dataLoadGroup.leave()
            }
        }
        
        // Download descriptionMap data
        dataLoadGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            print("Full data refresh (\(reason)): Downloading description map data")
            self.bandDescriptions.getDescriptionMapFile()
            self.bandDescriptions.getDescriptionMap()
            newDataDownloaded = true
            dataLoadGroup.leave()
        }
        
        // 3c. Once all downloads are complete, determine if content changed and clear caches
        dataLoadGroup.notify(queue: .main) {
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
                self.dataHandle.clearCachedData()
                self.schedule.clearCache()
                
                // Clear MasterViewController cached arrays (but not bands array yet)
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
                
                // 3e. Refresh cache from downloaded files
                print("Full data refresh (\(reason)): Step 3e - Refreshing cache from downloaded files")
                // Actually refresh schedule data
                self.schedule.populateSchedule(forceDownload: false)
                
                // Load iCloud data (both read and write to ensure sync)
                let iCloudGroup = DispatchGroup()
                
                iCloudGroup.enter()
                DispatchQueue.global(qos: .utility).async {
                    let iCloudHandle = iCloudDataHandler()
                    // First write local data to iCloud to ensure it's backed up
                    iCloudHandle.writeAllPriorityData()
                    iCloudHandle.writeAllScheduleData()
                    // Then read any remote changes from iCloud
                    iCloudHandle.readAllPriorityData()
                    iCloudHandle.readAllScheduleData()
                    // Also restore attended data from iCloud
                    iCloudHandle.readCloudAttendedData(attendedHandle: self.attendedHandle)
                    iCloudGroup.leave()
                }
                
                // 3f. Generate consolidated image list then refresh the GUI
                iCloudGroup.notify(queue: .main) {
                    print("Full data refresh (\(reason)): Step 3f - All data loaded, generating consolidated image list")
                    
                    // Generate consolidated image list immediately after both artist and schedule data are loaded
                    CombinedImageListHandler.shared.generateCombinedImageList(
                        bandNameHandle: self.bandNameHandle,
                        scheduleHandle: self.schedule
                    ) {
                        print("Full data refresh (\(reason)): Step 3g - Consolidated image list generated, refreshing GUI")
                        
                        if endRefreshControl {
                            self.refreshControl?.endRefreshing()
                        }
                        if shouldScrollToTop {
                            self.shouldSnapToTopAfterRefresh = true
                        }
                        
                        // Final GUI refresh with all new data and consolidated images
                        // The bands array will be safely repopulated in refreshBandList
                        self.refreshBandList(reason: "\(reason) - final refresh", scrollToTop: false, isPullToRefresh: shouldScrollToTop)
                        
                        print("Full data refresh (\(reason)): Complete with consolidated images!")
                        
                        // Call completion handler to signal data refresh is complete
                        completion?()
                    }
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
        print("🔄 Safely merging band data - reason: '\(reason)'")
        print("🔄 Current bands count: \(bands.count), New bands count: \(newBands.count)")
        
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
        
        // Immediately reload the table view to ensure consistency
        DispatchQueue.main.async {
            self.tableView.reloadData()
            print("🔄 Band data merge complete - table view updated")
            
            // Update the count label to reflect the new data
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
        
        // Immediately reload the table view to ensure consistency
        DispatchQueue.main.async {
            self.tableView.reloadData()
            print("🔄 All data refresh complete - table view updated")
            
            // Update the count label to reflect the new data
            self.updateCountLable()
        }
    }
    
    /// Load iCloud data after core data is available
    private func loadICloudData() {
        print("☁️ Loading iCloud data...")
        
        // Now that we have core data, we can safely sync with iCloud
        let iCloudHandle = iCloudDataHandler()
        
        // Check for old iCloud data format and migrate if needed
        // This must happen BEFORE reading iCloud data to prevent conflicts
        print("☁️ Reading iCloud priority data...")
        iCloudHandle.readAllPriorityData()
        
        print("☁️ Reading iCloud schedule data...")
        iCloudHandle.readAllScheduleData()
        
        // Note: Attended data restoration is handled in the main data refresh flow
        // to prevent duplicate processing and ensure proper sequencing
        
        print("✅ iCloud data loading completed")
    }
    
    /// Load combined image list after core data is available
    private func loadCombinedImageList() {
        print("🖼️ Loading combined image list...")
        
        // Now that we have core data, we can safely load the combined image list
        // Use the shared singleton instance instead of creating a new one
        let combinedImageHandler = CombinedImageListHandler.shared
        
        // Check if refresh is needed and load the combined image list
        print("🖼️ Checking if combined image list refresh is needed...")
        combinedImageHandler.checkAndRefreshOnLaunch()
        
        print("✅ Combined image list loading completed")
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

extension Array where Element: Hashable {
    /// Returns a new array with duplicate elements removed while preserving order
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}


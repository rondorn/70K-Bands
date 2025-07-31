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
        
    let schedule = scheduleHandler()
    let bandNameHandle = bandNamesHandler()
    let attendedHandle = ShowsAttended()
    let iCloudDataHandle = iCloudDataHandler();
    
    var filterTextNeeded = true;
    var viewableCell = UITableViewCell()
    
    var filterMenu = DropDown();
    
    @IBOutlet weak var titleButtonArea: UINavigationItem!
    var backgroundColor = UIColor.white;
    var textColor = UIColor.black;
    var detailViewController: DetailViewController? = nil
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
    
    var filterRequestID = 0
    
    static var isRefreshingBandList = false
    private static var refreshBandListSafetyTimer: Timer?
    
    // Flag to ensure snap-to-top after pull-to-refresh is not overridden
    var shouldSnapToTopAfterRefresh = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bandSearch.placeholder = NSLocalizedString("SearchCriteria", comment: "")
        //bandSearch.backgroundImage = UIImage(named: "70KSearch")!
        //bandSearch.setImage(UIImage(named: "70KSearch")!, for: <#UISearchBar.Icon#>, state: UIControl.State.normal)
        bandSearch.setImage(UIImage(named: "70KSearch")!, for: .init(rawValue: 0)!, state: .normal)
        readFiltersFile()
        getCountry()
        
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
        
        print("Calling refreshBandList from viewDidLoad with reason: Initial launch")
        refreshBandList(reason: "Initial launch")
        
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
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.detailDidUpdate), name: Notification.Name("DetailDidUpdate"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(iCloudDataReadyHandler), name: Notification.Name("iCloudDataReady"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(bandNamesCacheReadyHandler), name: NSNotification.Name("BandNamesDataReady"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePointerDataUpdated), name: Notification.Name("PointerDataUpdated"), object: nil)
        
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
                            
                            // Show offline message if no data available
                            let noBands = self.bands.isEmpty
                            let noEvents = eventCount == 0
                            if noBands && noEvents {
                                let alert = UIAlertController(title: "Offline Mode", message: "No internet connection detected. The app will work with cached data when available.", preferredStyle: .alert)
                                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                                self.present(alert, animated: true, completion: nil)
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
                        let noBands = self.bands.isEmpty
                        let noEvents = eventCount == 0
                        if noBands && noEvents {
                            let alert = UIAlertController(title: "No Data Loaded", message: "Unable to load band or event data. Please check your internet connection and try again.", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
                                // Retry logic: re-run viewDidLoad's first-launch block
                                cacheVariables.justLaunched = true
                                self.viewDidLoad()
                            })
                            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                            self.present(alert, animated: true, completion: nil)
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
        refreshDataWithBackgroundUpdate(reason: "iCloud refresh")
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
        
        let countryHandle = countryHandler()
        countryHandle.loadCountryData()
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
   

      present(alertController, animated: true, completion: nil)
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

            
        let countryHandle = countryHandler()
        countryHandle.loadCountryData()
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
   
       present(alert, animated: true, completion: nil)
        
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let countryHandle = countryHandler()
        countryHandle.loadCountryData()
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
            let shouldDownload = self.shouldDownloadSchedule(force: false)
            if shouldDownload {
                self.schedule.DownloadCsv()
                self.lastScheduleDownload = Date()
            }
            self.schedule.populateSchedule(forceDownload: false)
            
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
        
        // Use centralized background refresh
        refreshDataWithBackgroundUpdate(reason: "Return from details")
        
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
        // Force refresh when detail view updates priority data
        self.refreshDataWithBackgroundUpdate(reason: "Detail view priority update")
    }
    
    @objc func refreshDisplayAfterWake(){
        self.refreshDataWithBackgroundUpdate(reason: "Display after wake")
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
        bandNameHandle.readBandFile()
        schedule.getCachedData()
        dataHandle.getCachedData()
        filterRequestID += 1
        let requestID = filterRequestID
        getFilteredBands(
            bandNameHandle: bandNameHandle,
            schedule: schedule,
            dataHandle: dataHandle,
            attendedHandle: attendedHandle,
            searchCriteria: bandSearch.text ?? ""
        ) { [weak self] filtered in
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
                bandsResult.sort { getNameFromSortable($0, sortedBy: sortedBy).localizedCaseInsensitiveCompare(getNameFromSortable($1, sortedBy: sortedBy)) == .orderedAscending }
            } else if sortedBy == "time" {
                bandsResult.sort { getTimeFromSortable($0, sortBy: sortedBy) < getTimeFromSortable($1, sortBy: sortedBy) }
            }
            print("[YEAR_CHANGE_DEBUG] refreshBandList: Loaded \(bandsResult.count) bands for year \(eventYear)")
            self.bands = bandsResult
            self.bandsByName = bandsResult
            self.attendedHandle.getCachedData()
            self.tableView.reloadData()
            self.updateCountLable()
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
            // Set separator style: none for bands view, singleLine for schedule view
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
    
    func ensureCorrectSorting(){
        if (eventCount == 0){
            print("Schedule is empty, hide separators")
            mainTableView.separatorStyle = .none
        } else {
            print("Schedule present, show separators")
            mainTableView.separatorStyle = .singleLine
        }
        refreshBandList(reason: "Sorting changed")
    }
    
    func quickRefresh_Pre(){
        writeFiltersFile()
        if (isPerformingQuickLoad == false){
            isPerformingQuickLoad = true
            self.dataHandle.getCachedData()
            print("Calling refreshBandList from quickRefresh_Pre with reason: Quick refresh")
            refreshBandList(reason: "Quick refresh")
            self.isPerformingQuickLoad = false
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
    
    @objc func pullTorefreshData(){
        checkForEasterEgg()
        print ("iCloud: pull to refresh, load in new iCloud data")
        shouldSnapToTopAfterRefresh = true
        
        // First, validate network connectivity before clearing any data
        let networkTesting = NetworkTesting()
        let hasNetwork = networkTesting.forgroundNetworkTest(callingGui: self)
        
        if !hasNetwork {
            print("Pull to refresh: No network connectivity detected, keeping existing data")
            DispatchQueue.main.async {
                self.refreshControl?.endRefreshing()
                // Ensure snap-to-top flag is set for pull-to-refresh even with cached data
                self.shouldSnapToTopAfterRefresh = true
                // Refresh GUI from cached data without showing alert
                self.refreshBandList(reason: "Pull to refresh - no network, using cached data")
            }
            return
        }
        
        print("Pull to refresh: Network validated, proceeding with data refresh")
        DispatchQueue.global(qos: .userInitiated).async {
            // Purge caches before loading new data
            self.bandNameHandle.clearCachedData()
            self.dataHandle.clearCachedData()
            self.schedule.clearCache()
            // Reload all data
            let iCloudHandle = iCloudDataHandler()
            iCloudHandle.readAllPriorityData()
            iCloudHandle.readAllScheduleData()
            self.schedule.DownloadCsv()
            self.schedule.populateSchedule(forceDownload: false)
            // Simple approach: after 4 seconds, end refresh and trigger refreshBandList
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                self.refreshControl?.endRefreshing()
                // Ensure the snap-to-top flag is still set for pull-to-refresh
                self.shouldSnapToTopAfterRefresh = true
                self.refreshBandList(reason: "Pull to refresh", scrollToTop: false, isPullToRefresh: true)
            }
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
        if (listCount != eventCounterUnoffical && listCount > 0 && eventCounterUnoffical > 0){
            labeleCounter = listCount
            if (labeleCounter < 0){
                labeleCounter = 0
            }
            lableCounterString = " " + NSLocalizedString("Events", comment: "") + " " + filtersOnText
        } else {
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
        if (self.bands.count > rowNumber){
            bandName = self.bands[rowNumber]
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

        })
        
        
        mustSeeAction.setIcon(iconImage: UIImage(named: mustSeeIconSmall)!, backColor: UIColor.darkGray, cellHeight: 50, cellWidth: 230)
        
        let mightSeeAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title:"", handler: { (action:UITableViewRowAction!, indexPath:IndexPath!) -> Void in
            
            print ("Changing the priority of " + self.currentlySectionBandName(indexPath.row) + " to 2")
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            self.dataHandle.addPriorityData(bandName, priority: 2);
            isLoadingBandData = false
            self.quickRefresh()
            
        })
        
        mightSeeAction.setIcon(iconImage: UIImage(named: mightSeeIconSmall)!, backColor: UIColor.darkGray, cellHeight: 50, cellWidth: 230)
        
        let wontSeeAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title:"", handler: { (action:UITableViewRowAction!, indexPath:IndexPath!) -> Void in
            
            print ("Changing the priority of " + self.currentlySectionBandName(indexPath.row) + " to 3")
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            self.dataHandle.addPriorityData(bandName, priority: 3);
            isLoadingBandData = false
            self.quickRefresh()
            
        })
        
        wontSeeAction.setIcon(iconImage: UIImage(named: wontSeeIconSmall)!, backColor: UIColor.darkGray, cellHeight: 50, cellWidth: 230)
        
        let setUnknownAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title:"", handler: { (action:UITableViewRowAction!, indexPath:IndexPath!) -> Void in
            
            print ("Changing the priority of " + self.currentlySectionBandName(indexPath.row) + " to 0")
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            self.dataHandle.addPriorityData(bandName, priority: 0);
            isLoadingBandData = false
            self.quickRefresh()
            
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
        getCellValue(indexPath.row, schedule: schedule, sortBy: sortedBy, cell: cell, dataHandle: dataHandle, attendedHandle: attendedHandle)
        
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
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
        
        if segue.identifier == "showDetail" {
            if let indexPath = self.tableView.indexPathForSelectedRow {
                guard let cell = self.tableView.cellForRow(at: indexPath) else {
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
                let cellDataText = cellDataView.text ?? "";
                eventSelectedIndex = cellDataView.text ?? ""
                var bandName = bandNameNoSchedule.text ?? ""
                if (bandName.isEmpty == true){
                    bandName = bandNameView.text ?? ""
                }
                print ("BandName for Details is \(bandName)")
                detailMenuChoices(cellDataText: cellDataText, bandName: bandName, segue: segue, indexPath: indexPath)
            }
        }
        updateCountLable()

        tableView.reloadData()

    }
    
    func detailShareChoices(){
        
        sharedMessage = "Start"
        
        let alert = UIAlertController.init(title: "Share Type", message: "", preferredStyle: .actionSheet)
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
               
                let goToDeatils = UIAlertAction.init(title: NSLocalizedString("Go To Details", comment: ""), style: .default) { _ in
                   print("Go To Deatails")
                   self.goToDetailsScreen(segue: segue, bandName: bandName, indexPath: indexPath);
                }
                alert.addAction(goToDeatils)

                let currentAttendedStatus = attendedHandle.getShowAttendedStatus(band: cellBandName, location: cellLocation, startTime: cellStartTime, eventType: cellEventType, eventYearString: String(eventYear))

                if (currentAttendedStatus != sawAllStatus){
                   let attendChoice = UIAlertAction.init(title: NSLocalizedString("All Of Event", comment: ""), style: .default) { _ in
                      print("You Attended")
                       self.markAttendingStatus(cellDataText: cellDataText, status: sawAllStatus)
                   }
                   alert.addAction(attendChoice)
                }

                if (currentAttendedStatus != sawSomeStatus && cellEventType == showType){
                   let partialAttend = UIAlertAction.init(title: NSLocalizedString("Part Of Event", comment: ""), style: .default) { _ in
                       print("You Partially Attended")
                       self.markAttendingStatus(cellDataText: cellDataText, status: sawSomeStatus)
                   }
                   alert.addAction(partialAttend)
                }

                if (currentAttendedStatus != sawNoneStatus){
                   let notAttend = UIAlertAction.init(title: NSLocalizedString("None Of Event", comment: ""), style: .default) { _ in
                       print("You will not Attended")
                       self.markAttendingStatus(cellDataText: cellDataText, status: sawNoneStatus)
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
               print ("Going strait to the details screen")
               
               let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
           
               print ("Bands size is " + String(bands.count) + " Index is  " + String(indexPath.row))
                
               controller.detailItem = bandName as AnyObject
               controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem
               controller.navigationItem.leftItemsSupplementBackButton = true
           }
       }
       
    func goToDetailsScreen(segue :UIStoryboardSegue, bandName :String, indexPath :IndexPath){
        
         print ("bandName = \(bandName) and segue \(segue)")
         if (bandName.isEmpty == false){
            
            bandSelected = bandName;
            bandListIndexCache = indexPath.row
            guard let navController = segue.destination as? UINavigationController else {
                print("Error: segue.destination is not UINavigationController")
                return
            }
            guard let controller = navController.topViewController as? DetailViewController else {
                print("Error: topViewController is not DetailViewController")
                return
            }
        
            print ("Bands size is " + String(bands.count) + " Index is  " + String(indexPath.row))

            controller.detailItem = bandName as AnyObject
            controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem
            controller.navigationItem.leftItemsSupplementBackButton = true
        
            performSegue(withIdentifier: segue.identifier!, sender: self)
            
        } else {
            print ("Found an issue with the selection 1");
            return
        }

    }
    
    func markAttendingStatus (cellDataText :String, status: String){
        
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
            print ("Cell data is marked show attended \(message)");
            
        }
        
    }
    
    func resortBandsByTime(){

        schedule.getCachedData()
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
        refreshDataWithBackgroundUpdate(reason: "Push notification received")
    }
    
    @objc func handleAppWillEnterForeground() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.refreshDataWithBackgroundUpdate(reason: "App will enter foreground")
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        }
    }
    
    @objc func detailDidUpdate() {
        // Refresh data handler cache and reload table data when detail view updates
        dataHandle.getCachedData()
        self.tableView.reloadData()
    }
    
    @objc func iCloudDataReadyHandler() {
        print("iCloud data ready, forcing reload of all caches and band file.")
        bandNameHandle.readBandFile()
        dataHandle.getCachedData()
        attendedHandle.getCachedData()
        schedule.getCachedData()
        DispatchQueue.main.async {
            print("Calling refreshBandList from iCloudDataReadyHandler with reason: iCloud data ready (after forced reload)")
            self.refreshBandList(reason: "iCloud data ready (after forced reload)")
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


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
    
    var easterEggTriggeredBySearch = false
    var isReturningFromDetail = false
    
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
        
        // Ensure refresh control is properly associated with the table view
        tableView.refreshControl = refreshControl
        
        //scheduleButton.setImage(getSortButtonImage(), for: UIControl.State.normal)
        mainTableView.separatorStyle = .none
        
        //do an initial load of iCloud data on launch
        let showsAttendedHandle = ShowsAttended()
        
        // Use coordinator for initial data loading
        let coordinator = DataCollectionCoordinator.shared
        
        // For first install, band names will be loaded in foreground
        // For subsequent launches, all data loads in parallel
        coordinator.requestBandNamesCollection(eventYearOverride: false) {
            coordinator.requestScheduleCollection(eventYearOverride: false) {
                // Update UI immediately with band names and schedule
                DispatchQueue.main.async {
                    print("Initial load: Band names and schedule loaded - updating UI immediately")
                    self.refreshFromCache()
                    self.updateCountLable()
                    self.reloadTablePreservingScroll()
                    
                    // Load remaining data in parallel (lower priority)
                    coordinator.requestDataHandlerCollection(eventYearOverride: false) {
                        coordinator.requestShowsAttendedCollection(eventYearOverride: false) {
                            coordinator.requestCustomBandDescriptionCollection(eventYearOverride: false) {
                                // Start bulk loading of images and descriptions in background
                                DispatchQueue.global(qos: .background).async {
                                    print("Initial load: Starting bulk loading of images and descriptions")
                                    let imageHandle = imageHandler()
                                    let bandNotes = CustomBandDescription()
                                    
                                    // Start bulk loading operations with immutable snapshot
                                    let bandNamesSnapshot = self.bandNameHandle.getBandNamesSnapshot()
                                    imageHandle.getAllImages(bandNamesSnapshot: bandNamesSnapshot)
                                    bandNotes.getAllDescriptions(bandNamesSnapshot: bandNamesSnapshot)
                                }
                                
                                // Initial load complete, refresh the UI
                                DispatchQueue.main.async {
                                    self.performInitialDataRefresh()
                                }
                            }
                        }
                    }
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
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.detailDidUpdate), name: Notification.Name("DetailDidUpdate"), object: nil)
        
        // Add observers for high-priority immediate updates
        NotificationCenter.default.addObserver(self, selector: #selector(self.priorityChangeImmediate), name: Notification.Name("PriorityChangeImmediate"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.attendedChangeImmediate), name: Notification.Name("AttendedChangeImmediate"), object: nil)
        
        // Add observer for year change notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleYearChange), name: Notification.Name("YearChange"), object: nil)
    }
    
    @objc func bandNamesCacheReadyHandler() {
        // Called when band names are loaded (first launch or foreground)
        DispatchQueue.global(qos: .background).async {
            let iCloudHandle = iCloudDataHandler()
            iCloudHandle.readAllPriorityData()
            iCloudHandle.readAllScheduleData()
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
        let searchText = searchBar.text ?? ""
        // Easter egg: Trigger on 'More Cow Bell' (case-insensitive, ignore whitespace)
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare("More Cow Bell") == .orderedSame {
            if !easterEggTriggeredBySearch {
                easterEggTriggeredBySearch = true
                triggerEasterEgg()
            }
        } else {
            // Reset so user can trigger again if they retype
            easterEggTriggeredBySearch = false
        }
        var searchTextForBands = searchText
        if (searchTextForBands.isEmpty){
            searchTextForBands = ""
        }
        bands =  [String]()
        bandsByName = [String]()
        bandNameHandle.readBandFile()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.schedule.getCachedData()
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.bands = []
                self.bands = getFilteredBands(bandNameHandle: self.bandNameHandle, schedule: self.schedule, dataHandle: self.dataHandle, attendedHandle: self.attendedHandle, searchCriteria: searchTextForBands)
                // Deduplicate band names if no shows are present
                if eventCount == 0 {
                    self.bands = self.deduplicatePreservingOrder(self.bands)
                }
                self.bandsByName = self.bands
                self.attendedHandle.getCachedData()
                print("Filtering activated 3  \(searchTextForBands) \(searchTextForBands.count)")
                self.quickRefresh()
            }
        }
    }
    
    @objc func iCloudRefresh() {
        refreshData(isUserInitiated: false)
    }
    
    @objc func refreshMainDisplayAfterRefresh() {
        print ("Refresh done, so updating the display in main 3")
        if (Thread.isMainThread == true){
            refreshFromCache()
        }
    }
    
    @objc func displayFCMToken(notification: NSNotification){
      guard let userInfo = notification.userInfo else {return}
      if let fcmToken = userInfo["token"] as? String {
        let message = fcmToken

      }
    }

    override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        // Preserve scroll position when device rotates
        reloadTablePreservingScroll()
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
    
        videoURL = Bundle.main.url(forResource: "SNL-More_Cowbell", withExtension: "mov")
        player = AVPlayer(url: videoURL!)
        playerLayer = AVPlayerLayer(player: player)
        
        playerLayer.frame = self.view.bounds
        self.view.layer.addSublayer(playerLayer)
        player.play()
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async { [self] in
            sleep(42)
            finishedPlaying()
        }
    }
    
    func finishedPlaying() {
        print ("Easter Egg, lets make this go away")
        self.player.pause()
        self.playerLayer.removeFromSuperlayer()
        self.refreshData(isUserInitiated: false)
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

    override func viewWillAppear(_ animated: Bool) {
        print ("The viewWillAppear was called");
        super.viewWillAppear(animated)
        
        // Ensure back button always says "Back" when navigating from this view
        let backItem = UIBarButtonItem()
        backItem.title = "Back"
        self.navigationItem.backBarButtonItem = backItem
        
        isLoadingBandData = false
        writeFiltersFile()
        
        // Always refresh data to ensure we have the latest information
        // But use a different approach when returning from detail to preserve scroll position
        if isReturningFromDetail {
            // When returning from detail, refresh data but preserve scroll position
            refreshData(isUserInitiated: false)
        } else {
            // For other navigation scenarios, use the normal refresh
            pullTorefreshData()
        }
        
        // Reset the flag after handling the return from detail
        isReturningFromDetail = false
        
        // Removed quickRefresh() and refreshDisplayAfterWake() to avoid unnecessary data refreshes
        // Removed startScheduleRefreshTimer() to avoid restarting timer on every appearance
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
            refreshData(isUserInitiated: false)
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
        
        print("Year change detected - implementing prioritized loading sequence")
        
        // Step 1: Load band names and schedule immediately with high priority
        let coordinator = DataCollectionCoordinator.shared
        
        // Load band names first (highest priority)
        coordinator.requestBandNamesCollection(eventYearOverride: false) {
            // Load schedule immediately after band names
            coordinator.requestScheduleCollection(eventYearOverride: false) {
                // Update UI immediately with band names and schedule
                DispatchQueue.main.async {
                    print("Band names and schedule loaded - updating UI immediately")
                    self.refreshFromCache()
                    self.updateCountLable()
                    self.reloadTablePreservingScroll()
                    
                    // Step 2: Load remaining data in parallel (lower priority)
                    coordinator.requestDataHandlerCollection(eventYearOverride: false) {
                        coordinator.requestShowsAttendedCollection(eventYearOverride: false) {
                            coordinator.requestCustomBandDescriptionCollection(eventYearOverride: false) {
                                // Step 3: Start bulk loading of images and descriptions in background
                                DispatchQueue.global(qos: .background).async {
                                    print("Starting bulk loading of images and descriptions")
                                    let imageHandle = imageHandler()
                                    let bandNotes = CustomBandDescription()
                                    
                                    // Start bulk loading operations with immutable snapshot
                                    let bandNamesSnapshot = self.bandNameHandle.getBandNamesSnapshot()
                                    imageHandle.getAllImages(bandNamesSnapshot: bandNamesSnapshot)
                                    bandNotes.getAllDescriptions(bandNamesSnapshot: bandNamesSnapshot)
                                }
                                
                                DispatchQueue.main.async {
                                    print("Year change loading sequence complete")
                                    if UIDevice.current.userInterfaceIdiom == .pad {
                                        // On iPad, force a complete refresh to update the side-by-side view
                                        self.refreshData(isUserInitiated: false, forceDownload: true, forceBandNameDownload: true)
                                        print("iPad: Complete refresh triggered after year change notification")
                                    } else {
                                        // On iPhone, use normal refresh since screen changes trigger updates
                                        self.refreshData(isUserInitiated: false)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Performs the initial data refresh after coordinator has loaded data
    private func performInitialDataRefresh() {
        // This method is called after the coordinator has loaded all data
        // It performs the same operations as refreshData but without triggering the coordinator again
        
        print ("Initial data refresh: Processing loaded data")
        localTimeZoneAbbreviation = TimeZone.current.abbreviation()!
        internetAvailble = isInternetAvailable();
        
        // Initial data refresh doesn't need refresh control management
        // This is not a pull-to-refresh operation
        
        refreshFromCache()
        let searchCriteria = bandSearch.text ?? ""
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async { [self] in
            while (refreshDataLock == true){ sleep(1); }
            refreshDataLock = true;
            var offline = true
            if Reachability.isConnectedToNetwork(){ offline = false; }
            let bandNameHandle = bandNamesHandler()
            let schedule = scheduleHandler()
            
            self.bandsByName = [String]()
            self.bands = []
            self.bands = getFilteredBands(bandNameHandle: bandNameHandle, schedule: schedule, dataHandle: dataHandle, attendedHandle: self.attendedHandle, searchCriteria: searchCriteria)
            // Deduplicate band names if no shows are present
            if eventCount == 0 {
                self.bands = self.deduplicatePreservingOrder(self.bands)
            }
            currentBandList = self.bands
            self.bandsByName = self.bands
            self.attendedHandle.loadShowsAttended()
            DispatchQueue.main.async{
                print ("Initial data refresh: Updating UI");
                self.bandNameHandle.readBandFile()
                self.dataHandle.getCachedData()
                self.attendedHandle.getCachedData()
                self.ensureCorrectSorting()
                self.refreshAlerts()
                self.updateCountLable()
                self.reloadTablePreservingScroll()
                print ("DONE Initial data refresh");
                refreshDataLock = false;
                print ("Counts: bandCounter = \(bandCounter)")
                print ("Counts: eventCounter = \(eventCounter)")
                print ("Counts: eventCounterUnoffical = \(eventCounterUnoffical)")
                
                // Start bulk loading operations after initial data is loaded
                self.startBulkLoadingOperations()
            }
        }
        print ("Done Initial data refresh");
    }
    
    @objc func refreshDisplayAfterWake(){
        print("Refresh display after wake - implementing prioritized loading sequence")
        
        // Step 1: Load band names and schedule immediately with high priority
        let coordinator = DataCollectionCoordinator.shared
        
        // Load band names first (highest priority)
        coordinator.requestBandNamesCollection(eventYearOverride: false) {
            // Load schedule immediately after band names
            coordinator.requestScheduleCollection(eventYearOverride: false) {
                // Update UI immediately with band names and schedule
                DispatchQueue.main.async {
                    print("Band names and schedule loaded - updating UI immediately")
                    self.refreshFromCache()
                    self.updateCountLable()
                    self.reloadTablePreservingScroll()
                    
                    // Step 2: Load remaining data in parallel (lower priority)
                    coordinator.requestDataHandlerCollection(eventYearOverride: false) {
                        coordinator.requestShowsAttendedCollection(eventYearOverride: false) {
                            coordinator.requestCustomBandDescriptionCollection(eventYearOverride: false) {
                                // Step 3: Start bulk loading of images and descriptions in background
                                DispatchQueue.global(qos: .background).async {
                                    print("Starting bulk loading of images and descriptions")
                                    let imageHandle = imageHandler()
                                    let bandNotes = CustomBandDescription()
                                    
                                    // Start bulk loading operations with immutable snapshot
                                    let bandNamesSnapshot = self.bandNameHandle.getBandNamesSnapshot()
                                    imageHandle.getAllImages(bandNamesSnapshot: bandNamesSnapshot)
                                    bandNotes.getAllDescriptions(bandNamesSnapshot: bandNamesSnapshot)
                                }
                                
                                DispatchQueue.main.async {
                                    print("Refresh display loading sequence complete")
                                    if UIDevice.current.userInterfaceIdiom == .pad {
                                        // On iPad, force a complete refresh to update the side-by-side view
                                        self.refreshData(isUserInitiated: false, forceDownload: true, forceBandNameDownload: true)
                                        print("iPad: Complete refresh triggered after year change")
                                    } else {
                                        // On iPhone, use normal refresh since screen changes trigger updates
                                        self.refreshData(isUserInitiated: false)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
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
    
    /// Reloads the table view while preserving the current scroll position (unless called from pull-to-refresh)
    func reloadTablePreservingScroll() {
        let offset = self.tableView.contentOffset
        self.tableView.reloadData()
        self.tableView.setContentOffset(offset, animated: false)
    }

    func refreshFromCache (){
        print ("RefreshFromCache called")
        bands =  [String]()
        bandsByName = [String]()
        bandNameHandle.readBandFile()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.schedule.getCachedData()
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.bands = []
                self.bands = getFilteredBands(bandNameHandle: self.bandNameHandle, schedule: self.schedule, dataHandle: self.dataHandle, attendedHandle: self.attendedHandle, searchCriteria: self.bandSearch.text ?? "")
                // Deduplicate band names if no shows are present
                if eventCount == 0 {
                    self.bands = self.deduplicatePreservingOrder(self.bands)
                }
                self.bandsByName = self.bands
                self.attendedHandle.getCachedData()
                self.reloadTablePreservingScroll()
            }
        }
    }
    
    func ensureCorrectSorting(){
        
        if (eventCount == 0){
            print("Schedule is empty, stay hidden")
            //self.scheduleButton.isHidden = true;
            //willAttendButton.isHidden = true;
            mainTableView.separatorColor = UIColor.black
            //print ("setting showOnlyWillAttened value of false = 1")
            //setShowOnlyWillAttened(false);
            
        } else if (sortedBy == "name"){
            print("Sort By is Name, Show")
            //self.scheduleButton.isHidden = false;
            //willAttendButton.isHidden = false;
            //scheduleButton.setImage(getSortButtonImage(), for: UIControl.State.normal)
            mainTableView.separatorColor = UIColor.lightGray
            
        } else {
            print("Sort By is Time, Show")
            mainTableView.separatorColor = UIColor.lightGray
            
        }

        // REVERT: Remove the filtering that excluded bands with only filtered future shows
        // Restore to:
        // bands = getFilteredBands(...)
        // Deduplicate if needed
        bands = getFilteredBands(bandNameHandle: bandNameHandle, schedule: schedule, dataHandle: dataHandle, attendedHandle: attendedHandle, searchCriteria: bandSearch.text ?? "")
        if eventCount == 0 {
            bands = self.deduplicatePreservingOrder(bands)
        }
    }
    
    func quickRefresh_Pre(){
        writeFiltersFile()
        
        if (isPerformingQuickLoad == false){
            isPerformingQuickLoad = true
            
            self.dataHandle.getCachedData()
            self.bands = getFilteredBands(bandNameHandle: bandNameHandle, schedule: schedule, dataHandle: dataHandle, attendedHandle: attendedHandle, searchCriteria: bandSearch.text ?? "")
            // Deduplicate band names if no shows are present
            if eventCount == 0 {
                self.bands = self.deduplicatePreservingOrder(self.bands)
            }
            self.bandsByName = self.bands
            ensureCorrectSorting()
            self.attendedHandle.getCachedData()
            updateCountLable()
            isPerformingQuickLoad = false
        }
    }
    
    @objc func quickRefresh(){
        quickRefresh_Pre()
        self.reloadTablePreservingScroll()
    }
    
    @objc func refreshGUI(){
        self.reloadTablePreservingScroll()
    }
    

    @objc func OnOrientationChange(){
        sleep(1)
        quickRefresh_Pre()
        self.reloadTablePreservingScroll()
    }
    
    @objc func pullTorefreshData(){
        // Only check for Easter egg if this is an actual pull-to-refresh gesture
        // Check if the refresh control is currently refreshing (indicating user gesture)
        if refreshControl?.isRefreshing == true {
            checkForEasterEgg()
        }
        
        print ("iCloud: pull to refresh, load in new iCloud data")
        
        // Ensure refresh control is properly associated with the table view
        if refreshControl?.superview == nil {
            tableView.refreshControl = refreshControl
        }
        
        // Use coordinator for data loading with prioritized sequence
        let coordinator = DataCollectionCoordinator.shared
        
        // Load band names first (highest priority)
        coordinator.requestBandNamesCollection(eventYearOverride: false) {
            // Load schedule immediately after band names
            coordinator.requestScheduleCollection(eventYearOverride: false) {
                // Update UI immediately with band names and schedule
                DispatchQueue.main.async {
                    print("Pull to refresh: Band names and schedule loaded - updating UI immediately")
                    self.refreshFromCache()
                    self.updateCountLable()
                    self.reloadTablePreservingScroll()
                    
                    // Load remaining data in parallel (lower priority)
                    coordinator.requestDataHandlerCollection(eventYearOverride: false) {
                        coordinator.requestShowsAttendedCollection(eventYearOverride: false) {
                            coordinator.requestCustomBandDescriptionCollection(eventYearOverride: false) {
                                // Start bulk loading of images and descriptions in background
                                DispatchQueue.global(qos: .background).async {
                                    print("Pull to refresh: Starting bulk loading of images and descriptions")
                                    let imageHandle = imageHandler()
                                    let bandNotes = CustomBandDescription()
                                    
                                    // Start bulk loading operations with immutable snapshot
                                    let bandNamesSnapshot = self.bandNameHandle.getBandNamesSnapshot()
                                    imageHandle.getAllImages(bandNamesSnapshot: bandNamesSnapshot)
                                    bandNotes.getAllDescriptions(bandNamesSnapshot: bandNamesSnapshot)
                                }
                                
                                // Once done, refresh the GUI on the main thread
                                DispatchQueue.main.async {
                                    self.refreshData(isUserInitiated: true)
                                    print ("pullTorefreshData: Loading schedule data on pull to refresh - Done")
                                }
                            }
                        }
                    }
                }
            }
        }
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            let iCloudHandle = iCloudDataHandler()
            iCloudHandle.readAllPriorityData()
            iCloudHandle.readAllScheduleData()
            NotificationCenter.default.post(name: Notification.Name(rawValue: "refreshMainDisplayAfterRefresh"), object: nil)
        }
    }
    
    @objc func refreshData(isUserInitiated: Bool = false, forceDownload: Bool = false, forceBandNameDownload: Bool = false) {
        // Throttle: Only allow if 60 seconds have passed, unless user-initiated (pull to refresh) or forced download
        let now = Date()
        if !isUserInitiated && !forceDownload {
            if let lastRun = lastRefreshDataRun, now.timeIntervalSince(lastRun) < 60 {
                print("refreshData throttled: Only one run per 60 seconds unless user-initiated or forced download.")
                // But still force band name refresh if requested
                if forceBandNameDownload {
                    DataCollectionCoordinator.shared.requestBandNamesCollection(eventYearOverride: false) {
                        print("Forced band name refresh (throttled schedule)")
                    }
                }
                return
            }
        }
        lastRefreshDataRun = now
        print ("Redrawing the filter menu! Not")
        print ("Refresh Waiting for bandData, Done - \(refreshDataCounter)")
        localTimeZoneAbbreviation = TimeZone.current.abbreviation()!
        internetAvailble = isInternetAvailable();
        
        // Only manage refresh control for pull-to-refresh operations
        if isUserInitiated && refreshControl?.isRefreshing == true {
            // Always end refreshing after 4 seconds for pull-to-refresh
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(4), execute: {
                self.refreshControl?.endRefreshing()
                // Ensure table view snaps back to top after pull-to-refresh
                DispatchQueue.main.async {
                    self.tableView.setContentOffset(.zero, animated: true)
                }
            })
        }
        // No timeout management for non-pull-to-refresh operations
        refreshFromCache()
        let searchCriteria = bandSearch.text ?? ""
        let shouldDownload = shouldDownloadSchedule(force: forceDownload || isUserInitiated)
        
        // Use coordinator for data loading
        let coordinator = DataCollectionCoordinator.shared
        
        if shouldDownload && internetAvailble {
            // Load all data types in parallel using coordinator
            coordinator.requestBandNamesCollection(eventYearOverride: false) {
                coordinator.requestScheduleCollection(eventYearOverride: false) {
                    coordinator.requestDataHandlerCollection(eventYearOverride: false) {
                        coordinator.requestShowsAttendedCollection(eventYearOverride: false) {
                            coordinator.requestCustomBandDescriptionCollection(eventYearOverride: false) {
                                DispatchQueue.main.async {
                                    // Preserve scroll position when coordinator completes
                                    self.reloadTablePreservingScroll()
                                }
                            }
                        }
                    }
                }
            }
        }
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async { [self] in
            while (refreshDataLock == true){ sleep(1); }
            refreshDataLock = true;
            var offline = true
            if Reachability.isConnectedToNetwork(){ offline = false; }
            let bandNameHandle = bandNamesHandler()
            let schedule = scheduleHandler()
            if (offline == false && (shouldDownload || forceBandNameDownload)) {
                cacheVariables();
                dataHandle.getCachedData()
                bandNameHandle.gatherData();
                print ("Loading show attended data! From MasterViewController")
                schedule.populateSchedule()
            }
            self.bandsByName = [String]()
            self.bands = []
            self.bands = getFilteredBands(bandNameHandle: bandNameHandle, schedule: schedule, dataHandle: dataHandle, attendedHandle: self.attendedHandle, searchCriteria: searchCriteria)
            // Deduplicate band names if no shows are present
            if eventCount == 0 {
                self.bands = self.deduplicatePreservingOrder(self.bands)
            }
            currentBandList = self.bands
            self.bandsByName = self.bands
            self.attendedHandle.loadShowsAttended()
            DispatchQueue.main.async{
                print ("Refreshing data in backgroud");
                self.bandNameHandle.readBandFile()
                self.dataHandle.getCachedData()
                self.attendedHandle.getCachedData()
                self.ensureCorrectSorting()
                self.refreshAlerts()
                self.updateCountLable()
                // Only preserve scroll if not a pull-to-refresh
                if !isUserInitiated {
                    self.reloadTablePreservingScroll()
                } else {
                    self.tableView.reloadData()
                }
                print ("DONE Refreshing data in backgroud 1");
                refreshDataLock = false;
                // NotificationCenter.default.post(name: Notification.Name(rawValue: "refreshMainDisplayAfterRefresh"), object: nil)
                print ("Counts: bandCounter = \(bandCounter)")
                print ("Counts: eventCounter = \(eventCounter)")
                print ("Counts: eventCounterUnoffical = \(eventCounterUnoffical)")
            }
        }
        print ("Done Refreshing data in backgroud 2");
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
    
  
    func updateCountLable() {
        setFilterTitleText()
        let currentYearSetting = getScheduleUrl()
        let yearText = (currentYearSetting != "Current" && currentYearSetting != "Default") ? "(\(currentYearSetting)) " : ""

        // Determine if only 'Cruiser Organized' events are present
        let onlyCruiserOrganized = (unfilteredEventCount > 0 && unfilteredEventCount == unfilteredCruiserEventCount)
        // Determine if there are any non-'Cruiser Organized' events
        let hasNonCruiserEvents = (eventCounter - eventCounterUnoffical) > 0

        var labelCounter: Int
        var labelCounterString: String

        if hasNonCruiserEvents {
            // Show Events
            labelCounter = eventCounter
            labelCounterString = " Events " + filtersOnText
        } else {
            // Show Bands (either only Cruiser Organized events, or just bands)
            labelCounter = bandCounter
            labelCounterString = " Bands " + filtersOnText
        }

        if yearText.isEmpty {
            titleButton.title = "\(labelCounter)\(labelCounterString)"
        } else {
            titleButton.title = "\(yearText)\(labelCounter)\(labelCounterString)"
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
        
        currentBandList = self.bands
        print ("Waiting for band data to load, Done")
        if (currentBandList.count == 0){
            while(currentBandList.count == 0){
                refreshFromCache()
                currentBandList = self.bands
            }
        }
        self.splitViewController!.delegate = self;
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.splitViewController!.preferredDisplayMode = UISplitViewController.DisplayMode.allVisible
        }
        
        self.extendedLayoutIncludesOpaqueBars = true
        
        if segue.identifier == "showDetail" {
            // Set flag to indicate we're navigating to detail view
            isReturningFromDetail = true
            
            if let indexPath = self.tableView.indexPathForSelectedRow {
            
                let cell = self.tableView.cellForRow(at: indexPath)
                let bandNameView = cell!.viewWithTag(2) as! UILabel
                let bandNameNoSchedule = cell!.viewWithTag(12) as! UILabel
                
                let cellDataView = cell!.viewWithTag(1) as! UILabel
                let cellDataText = cellDataView.text ?? "";
                
                eventSelectedIndex = cellDataView.text!
                var bandName = bandNameNoSchedule.text ?? ""
                
                if (bandName.isEmpty == true){
                    bandName = bandNameView.text ?? ""
                }
                
                print ("BandName for Details is \(bandName)")
                detailMenuChoices(cellDataText: cellDataText, bandName: bandName, segue: segue, indexPath: indexPath)
            }
        }
        updateCountLable()

        // Preserve scroll position when preparing for segue
        reloadTablePreservingScroll()

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
            let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
        
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

        // Preserve scroll position when resorting bands
        reloadTablePreservingScroll()

        
    }
    
    //iCloud data loading
    @objc func onSettingsChanged(_ notification: Notification) {
        //iCloudDataHandle.writeiCloudData(dataHandle: dataHandle, attendedHandle: attendedHandle)
    }

    @objc @IBAction func statsButtonTapped(_ sender: Any) {
        let fileManager = FileManager.default
        let documentsUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileUrl = documentsUrl.appendingPathComponent("stats.html")

        // Always present the web view immediately with local file
        let fileExists = fileManager.fileExists(atPath: fileUrl.path)
        presentWebView(url: fileUrl.absoluteString, isLoading: !fileExists)

        // Always attempt to download new content and refresh the view
        if Reachability.isConnectedToNetwork() {
            let task = URLSession.shared.dataTask(with: URL(string: statsUrl)!) { (data, response, error) in
                if let data = data {
                    do {
                        try data.write(to: fileUrl)
                        // Refresh the currently displayed web view with the local file
                        DispatchQueue.main.async {
                            if let currentWebViewController = self.getCurrentWebViewController() {
                                let request = URLRequest(url: fileUrl)
                                currentWebViewController.webDisplay.load(request)
                            } else {
                                // If no cached content was shown initially, present the web view now with local file
                                self.presentWebView(url: fileUrl.absoluteString, isLoading: false)
                            }
                        }
                    } catch {
                        // Only show error if we didn't already show cached content
                        if !fileExists {
                            self.presentNoDataView(message: "Could not save stats file.")
                        }
                    }
                } else {
                    // Only show error if we didn't already show cached content
                    if !fileExists {
                        self.presentNoDataView(message: "Could not download stats data.")
                    }
                }
            }
            task.resume()
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
                let documentsUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
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
            // Safety check: Ensure stats screen never loads remote URLs directly
            if url.contains("dropbox.com") || url.contains("http://") || url.contains("https://") {
                print("WARNING: Attempted to load remote URL in stats screen: \(url)")
                // Fall back to local file or show error
                let fileManager = FileManager.default
                let documentsUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
                let localFileUrl = documentsUrl.appendingPathComponent("stats.html")
                
                if fileManager.fileExists(atPath: localFileUrl.path) {
                    setUrl(localFileUrl.absoluteString)
                } else {
                    self.presentNoDataView(message: "Stats data not available locally. Please try again.")
                    return
                }
            } else {
                setUrl(url)
            }
            
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
                    let documentsUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
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
            self?.refreshData(isUserInitiated: false)
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
        print("Push notification received - implementing prioritized loading sequence")
        
        // Step 1: Load band names and schedule immediately with high priority
        let coordinator = DataCollectionCoordinator.shared
        
        // Load band names first (highest priority)
        coordinator.requestBandNamesCollection(eventYearOverride: false) {
            // Load schedule immediately after band names
            coordinator.requestScheduleCollection(eventYearOverride: false) {
                // Update UI immediately with band names and schedule
                DispatchQueue.main.async {
                    print("Push notification: Band names and schedule loaded - updating UI immediately")
                    self.refreshFromCache()
                    self.updateCountLable()
                    self.reloadTablePreservingScroll()
                    
                    // Load remaining data in parallel (lower priority)
                    coordinator.requestDataHandlerCollection(eventYearOverride: false) {
                        coordinator.requestShowsAttendedCollection(eventYearOverride: false) {
                            coordinator.requestCustomBandDescriptionCollection(eventYearOverride: false) {
                                // Start bulk loading of images and descriptions in background
                                DispatchQueue.global(qos: .background).async {
                                    print("Push notification: Starting bulk loading of images and descriptions")
                                    let imageHandle = imageHandler()
                                    let bandNotes = CustomBandDescription()
                                    
                                    // Start bulk loading operations with immutable snapshot
                                    let bandNamesSnapshot = self.bandNameHandle.getBandNamesSnapshot()
                                    imageHandle.getAllImages(bandNamesSnapshot: bandNamesSnapshot)
                                    bandNotes.getAllDescriptions(bandNamesSnapshot: bandNamesSnapshot)
                                }
                                
                                DispatchQueue.main.async {
                                    self.refreshData(isUserInitiated: false)
                                    print("Push notification loading sequence complete")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    @objc func handleAppWillEnterForeground() {
        print("App will enter foreground - implementing prioritized loading sequence")
        
        // Step 1: Load band names and schedule immediately with high priority
        let coordinator = DataCollectionCoordinator.shared
        
        // Load band names first (highest priority)
        coordinator.requestBandNamesCollection(eventYearOverride: false) {
            // Load schedule immediately after band names
            coordinator.requestScheduleCollection(eventYearOverride: false) {
                // Update UI immediately with band names and schedule
                DispatchQueue.main.async {
                    print("Foreground: Band names and schedule loaded - updating UI immediately")
                    self.refreshFromCache()
                    self.updateCountLable()
                    self.reloadTablePreservingScroll()
                    
                    // Load remaining data in parallel (lower priority)
                    coordinator.requestDataHandlerCollection(eventYearOverride: false) {
                        coordinator.requestShowsAttendedCollection(eventYearOverride: false) {
                            coordinator.requestCustomBandDescriptionCollection(eventYearOverride: false) {
                                // Start bulk loading of images and descriptions in background
                                DispatchQueue.global(qos: .background).async {
                                    print("Foreground: Starting bulk loading of images and descriptions")
                                    let imageHandle = imageHandler()
                                    let bandNotes = CustomBandDescription()
                                    
                                    // Start bulk loading operations with immutable snapshot
                                    let bandNamesSnapshot = self.bandNameHandle.getBandNamesSnapshot()
                                    imageHandle.getAllImages(bandNamesSnapshot: bandNamesSnapshot)
                                    bandNotes.getAllDescriptions(bandNamesSnapshot: bandNamesSnapshot)
                                }
                                
                                DispatchQueue.main.async {
                                    // Preserve scroll position when app enters foreground
                                    self.reloadTablePreservingScroll()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    @objc func detailDidUpdate() {
        if UIDevice.current.userInterfaceIdiom == .pad {
            // On iPad, refresh data and preserve scroll position when detail view updates
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                // Refresh data in background
                self?.dataHandle.getCachedData()
                self?.attendedHandle.getCachedData()
                
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    // Update the band list with fresh data using high-priority function
                    self.bands = getFilteredBandsImmediate(bandNameHandle: self.bandNameHandle, schedule: self.schedule, dataHandle: self.dataHandle, attendedHandle: self.attendedHandle, searchCriteria: self.bandSearch.text ?? "")
                    
                    // Deduplicate band names if no shows are present
                    if eventCount == 0 {
                        self.bands = self.deduplicatePreservingOrder(self.bands)
                    }
                    
                    // Preserve scroll position when detail view updates
                    self.reloadTablePreservingScroll()
                    
                    print("iPad: Band list updated after detail view priority change")
                }
            }
        }
    }
    
    /// HIGH PRIORITY: Immediate update when priority changes occur
    @objc func priorityChangeImmediate(_ notification: Notification) {
        guard let bandName = notification.object as? String else { return }
        
        print("HIGH PRIORITY: Immediate priority change update for \(bandName)")
        
        // Immediately refresh cached data
        dataHandle.getCachedData()
        
        // Update the band list immediately with high priority
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Force immediate refresh of the band list using high-priority function
            self.bands = getFilteredBandsImmediate(bandNameHandle: self.bandNameHandle, schedule: self.schedule, dataHandle: self.dataHandle, attendedHandle: self.attendedHandle, searchCriteria: self.bandSearch.text ?? "")
            
            // Deduplicate band names if no shows are present
            if eventCount == 0 {
                self.bands = self.deduplicatePreservingOrder(self.bands)
            }
            
            // Update counts and refresh table immediately
            self.updateCountLable()
            self.reloadTablePreservingScroll()
            
            print("HIGH PRIORITY: Band list immediately updated for priority change")
        }
    }
    
    /// HIGH PRIORITY: Immediate update when attended changes occur
    @objc func attendedChangeImmediate(_ notification: Notification) {
        // The notification object might be nil for attended changes from ShowsAttended
        let bandName = notification.object as? String
        
        print("HIGH PRIORITY: Immediate attended change update for \(bandName ?? "unknown band")")
        
        // Immediately refresh cached data
        attendedHandle.getCachedData()
        
        // Update the band list immediately with high priority
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Force immediate refresh of the band list using high-priority function
            self.bands = getFilteredBandsImmediate(bandNameHandle: self.bandNameHandle, schedule: self.schedule, dataHandle: self.dataHandle, attendedHandle: self.attendedHandle, searchCriteria: self.bandSearch.text ?? "")
            
            // Deduplicate band names if no shows are present
            if eventCount == 0 {
                self.bands = self.deduplicatePreservingOrder(self.bands)
            }
            
            // Update counts and refresh table immediately
            self.updateCountLable()
            self.reloadTablePreservingScroll()
            
            print("HIGH PRIORITY: Band list immediately updated for attended change")
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop and clear the easter egg video if playing
        if player.timeControlStatus == .playing || player.timeControlStatus == .paused {
            player.pause()
            playerLayer.removeFromSuperlayer()
        }
    }
    
    // Stop easter egg video if a list entry is clicked
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if player.timeControlStatus == .playing || player.timeControlStatus == .paused {
            player.pause()
            playerLayer.removeFromSuperlayer()
        }
    }
    
    // Helper to deduplicate while preserving order
    private func deduplicatePreservingOrder(_ array: [String]) -> [String] {
        var seen = Set<String>()
        return array.filter { seen.insert($0).inserted }
    }
    
    /// Starts bulk loading operations for images and descriptions
    private func startBulkLoadingOperations() {
        let bandNamesSnapshot = self.bandNameHandle.getBandNamesSnapshot()
        DispatchQueue.global(qos: .background).async {
            print("MasterViewController: Starting bulk loading operations")
            let imageHandle = imageHandler()
            let bandNotes = CustomBandDescription()
            // Start bulk loading operations with immutable snapshot
            imageHandle.getAllImages(bandNamesSnapshot: bandNamesSnapshot)
            bandNotes.getAllDescriptions(bandNamesSnapshot: bandNamesSnapshot)
        }
    }
    
    /// Handles year change notifications and ensures proper data loading sequence
    @objc func handleYearChange() {
        print("Year change detected - implementing parallel loading with immediate UI updates")
        
        // Step 1: Load band names and schedule in parallel with immediate UI updates
        let coordinator = DataCollectionCoordinator.shared
        
        // Track completion status for both operations
        var bandNamesLoaded = false
        var scheduleLoaded = false
        
        // Add timeout to prevent indefinite blocking
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
            print("Year change: Timeout reached - updating UI with available data")
            DispatchQueue.main.async {
                self.refreshFromCache()
                self.updateCountLable()
                self.reloadTablePreservingScroll()
            }
        }
        
        // Function to check if we can update UI
        let checkAndUpdateUI = {
            if bandNamesLoaded && scheduleLoaded {
                timeoutTimer.invalidate()
                DispatchQueue.main.async {
                    print("Year change: Both band names and schedule loaded - updating UI")
                    self.refreshFromCache()
                    self.updateCountLable()
                    self.reloadTablePreservingScroll()
                    
                    // Start loading remaining data in background (non-blocking)
                    self.startRemainingDataLoad()
                }
            } else if bandNamesLoaded || scheduleLoaded {
                // Update UI with partial data to improve responsiveness
                DispatchQueue.main.async {
                    print("Year change: Partial data loaded - updating UI with available data")
                    self.refreshFromCache()
                    self.updateCountLable()
                    self.reloadTablePreservingScroll()
                }
            }
        }
        
        // Load band names in parallel
        coordinator.requestBandNamesCollection(eventYearOverride: false) {
            print("Year change: Band names loaded")
            bandNamesLoaded = true
            checkAndUpdateUI()
        }
        
        // Load schedule in parallel
        coordinator.requestScheduleCollection(eventYearOverride: false) {
            print("Year change: Schedule loaded")
            scheduleLoaded = true
            checkAndUpdateUI()
        }
    }
    
    /// Handles stats page errors by refreshing stats data and notifying user
    @objc func handleStatsPageError() {
        print("📊 MasterViewController: Handling stats page error")
        
        DispatchQueue.main.async {
            // Show user feedback
            let alert = UIAlertController(
                title: NSLocalizedString("Stats Error", comment: "Stats error alert title"),
                message: NSLocalizedString("There was an issue loading the stats page. Attempting to refresh the data.", comment: "Stats error alert message"),
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK button"), style: .default))
            
            // Present the alert
            if let topViewController = UIApplication.shared.keyWindow?.rootViewController {
                var presentingViewController = topViewController
                while let presented = presentingViewController.presentedViewController {
                    presentingViewController = presented
                }
                presentingViewController.present(alert, animated: true)
            }
            
            // Attempt to refresh stats data in background
            DispatchQueue.global(qos: .background).async {
                print("📊 Refreshing stats data in background")
                // Add any stats-specific refresh logic here if needed
                // For now, we'll just log the attempt
            }
        }
    }
    
    /// Starts loading remaining data in background (non-blocking)
    private func startRemainingDataLoad() {
        let coordinator = DataCollectionCoordinator.shared
        
        // Load remaining data in parallel (lower priority, non-blocking)
        coordinator.requestDataHandlerCollection(eventYearOverride: false) {
            print("Year change: Data handler loaded")
        }
        
        coordinator.requestShowsAttendedCollection(eventYearOverride: false) {
            print("Year change: Shows attended loaded")
        }
        
        coordinator.requestCustomBandDescriptionCollection(eventYearOverride: true) {
            print("Year change: Custom band descriptions loaded")
            
            // Start bulk loading of images and descriptions in background
            DispatchQueue.global(qos: .background).async {
                print("Year change: Starting bulk loading of images and descriptions")
                let imageHandle = imageHandler()
                let bandNotes = CustomBandDescription()
                
                // Start bulk loading operations with immutable snapshot
                let bandNamesSnapshot = self.bandNameHandle.getBandNamesSnapshot()
                imageHandle.getAllImages(bandNamesSnapshot: bandNamesSnapshot)
                bandNotes.getAllDescriptions(bandNamesSnapshot: bandNamesSnapshot)
            }
            
            DispatchQueue.main.async {
                print("Year change loading sequence complete")
                if UIDevice.current.userInterfaceIdiom == .pad {
                    // On iPad, force a complete refresh to update the side-by-side view
                    self.refreshData(isUserInitiated: false, forceDownload: true, forceBandNameDownload: true)
                    print("iPad: Complete refresh triggered after year change")
                } else {
                    // On iPhone, use normal refresh since screen changes trigger updates
                    self.refreshData(isUserInitiated: false)
                }
            }
        }
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


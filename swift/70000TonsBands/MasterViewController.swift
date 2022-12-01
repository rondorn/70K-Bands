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

class MasterViewController: UITableViewController, UISplitViewControllerDelegate, NSFetchedResultsControllerDelegate {
    
    @IBOutlet var mainTableView: UITableView!
    @IBOutlet weak var mainToolBar: UIToolbar!
    
    @IBOutlet weak var titleButton: UINavigationItem!

    @IBOutlet weak var preferenceButton: UIBarButtonItem!
    @IBOutlet weak var mustSeeButton: UIButton!
    @IBOutlet weak var mightSeeButton: UIButton!
    @IBOutlet weak var willNotSeeButton: UIButton!
    @IBOutlet weak var wontSeeButton: UIButton!
    @IBOutlet weak var unknownButton: UIButton!
    
    @IBOutlet weak var willAttendButton: UIButton!
    
    @IBOutlet weak var Undefined: UIButton!

    @IBOutlet weak var shareButton: UIBarButtonItem!
    
    @IBOutlet weak var contentController: UIView!
    @IBOutlet weak var scheduleButton: UIButton!
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var blankScreenActivityIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var menuButton: UIBarButtonItem!
    
    let schedule = scheduleHandler()
    let bandNameHandle = bandNamesHandler()
    let attendedHandle = ShowsAttended()
    let iCloudDataHandle = iCloudDataHandler();
    
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
    
    var bandDescriptions = CustomBandDescription()
    
    @IBOutlet weak var titleLabel: UINavigationItem!
    
    var dataHandle = dataHandler()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        getCountry()
        
        self.navigationController?.navigationBar.barStyle = UIBarStyle.blackTranslucent
        self.navigationController?.navigationBar.tintColor = UIColor.white
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.white]
        
        //have a reference to this controller for external refreshes
        masterView = self;
        
        // Do any additional setup after loading the view, typically from a nib.
        splitViewController?.preferredDisplayMode = UISplitViewController.DisplayMode.allVisible
        
        blankScreenActivityIndicator.hidesWhenStopped = true
        
        //icloud change notification
        NotificationCenter.default.addObserver(self,
                                                         selector: #selector(MasterViewController.onSettingsChanged(_:)),
                                                         name: UserDefaults.didChangeNotification ,
                                                         object: nil)
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(MasterViewController.refreshData), for: UIControl.Event.valueChanged)
        refreshControl.tintColor = UIColor.red;
        self.refreshControl = refreshControl
        
        scheduleButton.setImage(getSortButtonImage(), for: UIControl.State.normal)
        mainTableView.separatorColor = UIColor.lightGray
        
        dataHandle.readFiltersFile()
        setFilterButtons()

        refreshData()
        
        UserDefaults.standard.didChangeValue(forKey: "mustSeeAlert")
        
        NotificationCenter.default.addObserver(self, selector: #selector(MasterViewController.refreshDisplayAfterWake), name: NSNotification.Name(rawValue: "RefreshDisplay"), object: nil)
        
        
        NotificationCenter.default.addObserver(self, selector:#selector(MasterViewController.refreshAlerts), name: UserDefaults.didChangeNotification, object: nil)
        
        if (getShowOnlyWillAttened() == true){
            willAttendButton.setImage(UIImage(named: "icon-seen"), for: UIControl.State())
        } else {
            willAttendButton.setImage(UIImage(named: "icon-seen-alt"), for: UIControl.State())
        }
        
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
        let userDataHandle = firebaseUserWrite()
        userDataHandle.writeData()
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
        //ToastMessages(message).show(self, cellLocation: self.view.frame)

      }
    }
    
    override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        
        // Reload Data here
       self.tableView.reloadData()

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
        let dataHandle = dataHandler()
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
        isLoadingBandData = false
        quickRefresh()
        refreshDisplayAfterWake();
    }

    @IBAction func titleButtonAction(_ sender: AnyObject) {
        self.tableView.contentOffset = CGPoint(x: 0, y: 0 - self.tableView.contentInset.top);
    }
    
    @IBAction func menuButtonAction(_ sender: AnyObject) {
        
        let secondViewController = self.storyboard?.instantiateViewController(withIdentifier: "sortMenuNavigation")
        let window = UIApplication.shared.windows[0] as UIWindow
        UIView.transition(
            from: window.rootViewController!.view,
            to: secondViewController!.view,
            duration: 0.65,
            options: .transitionCrossDissolve,
            completion: {
                finished in window.rootViewController = secondViewController
        })
        
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
            refreshData()
    }
    
    func setFilterButtons(){
        
        print ("Status of getWontSeeOn = \(getWontSeeOn())")
        if (getMustSeeOn() == false || getShowOnlyWillAttened() == true){
            mustSeeButton.setImage(getRankGuiIcons(rank: "mustAlt"), for: UIControl.State())
        }
        if (getMightSeeOn() == false || getShowOnlyWillAttened() == true){
            mightSeeButton.setImage(getRankGuiIcons(rank: "mightAlt"), for: UIControl.State())
        }
        if (getWontSeeOn() == false || getShowOnlyWillAttened() == true){
            wontSeeButton.setImage(getRankGuiIcons(rank: "wontAlt"), for: UIControl.State())
        }
        if (getUnknownSeeOn() == false || getShowOnlyWillAttened() == true){
            unknownButton.setImage(getRankGuiIcons(rank: "unknownAlt"), for: UIControl.State())
        }
        
        if (getShowOnlyWillAttened() == true){
            willAttendButton.setImage(UIImage(named: "icon-seen"), for: UIControl.State())
        } else {
            willAttendButton.setImage(UIImage(named: "icon-seen-alt"), for: UIControl.State())
        }
        
        scheduleButton.setImage(getSortButtonImage(), for: UIControl.State.normal)
        mainTableView.separatorColor = UIColor.lightGray

    }
    
    @objc func refreshDisplayAfterWake(){
        self.refreshData()

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
    
    func refreshFromCache (){
        
        print ("RefreshFromCache called")
        
        bands =  [String]()
        bandsByName = [String]()
        bandNameHandle.readBandFile()
        schedule.getCachedData()
        bands = getFilteredBands(bandNameHandle: bandNameHandle, schedule: schedule, dataHandle: dataHandle, attendedHandle: attendedHandle)
        bandsByName = bands
        attendedHandle.getCachedData()
        setShowOnlyAttenedFilterStatus()
    }
    
    func ensureCorrectSorting(){
        
        if (eventCount == 0){
            print("Schedule is empty, stay hidden")
            self.scheduleButton.isHidden = true;
            willAttendButton.isHidden = true;
            mainTableView.separatorColor = UIColor.black
            setShowOnlyWillAttened(false);
            resetFilterIcons();
            scheduleButton.setImage(getSortButtonImage(), for: UIControl.State.normal)
            scheduleButton.setImage(getSortButtonImage(), for: UIControl.State())
            //self.scheduleButton.setTitle(getScheduleIcon(), for: UIControl.State())
            
        } else if (sortedBy == "name"){
            print("Sort By is Name, Show")
            self.scheduleButton.isHidden = false;
            willAttendButton.isHidden = false;
            scheduleButton.setImage(getSortButtonImage(), for: UIControl.State.normal)
            mainTableView.separatorColor = UIColor.lightGray
            
        } else {
            print("Sort By is Time, Show")
            //self.sortBandsByTime()
            self.scheduleButton.isHidden = false;
            willAttendButton.isHidden = false;
            scheduleButton.setImage(getSortButtonImage(), for: UIControl.State.normal)
            mainTableView.separatorColor = UIColor.lightGray
            
        }
        bands =  [String]()
        bands = getFilteredBands(bandNameHandle: bandNameHandle, schedule: schedule, dataHandle: dataHandle, attendedHandle: attendedHandle)
    }
    
    func quickRefresh(){
        
        if (isPerformingQuickLoad == false){
            isPerformingQuickLoad = true

            self.dataHandle.getCachedData()
            self.attendedHandle.getCachedData()
            
            self.bands = getFilteredBands(bandNameHandle: bandNameHandle, schedule: schedule, dataHandle: dataHandle, attendedHandle: attendedHandle)
            self.bandsByName = self.bands
            ensureCorrectSorting()
            updateCountLable()
            setShowOnlyAttenedFilterStatus()
            isPerformingQuickLoad = false
            self.tableView.reloadData()
        }
    }
    
    @objc func refreshData(){
        
        print ("Refresh Waiting for bandData, Done - \(refreshDataCounter)")
        //check if the timezonr has changes for whatever reason
        localTimeZoneAbbreviation = TimeZone.current.abbreviation()!
        
        internetAvailble = isInternetAvailable();
        print ("Refresh Internetavailable is  \(internetAvailble)");
        if (internetAvailble == false){
            self.refreshControl?.endRefreshing();
        
        } else {
            //clear busy indicator after a 3 second delay
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3), execute: {
                self.refreshControl?.endRefreshing();
            })
        }
        
        refreshFromCache()
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async { [self] in
            
            while (refreshDataLock == true){
                sleep(1);
            }
            refreshDataLock = true;
            let dataHandle = dataHandler()
            var offline = true

            if Reachability.isConnectedToNetwork(){
                offline = false;
            }
            
            let bandNameHandle = bandNamesHandler()
            let schedule = scheduleHandler()
            if (offline == false){
                cacheVariables();
                dataHandle.getCachedData()
                bandNameHandle.gatherData();
                self.attendedHandle.loadShowsAttended()
                
                schedule.DownloadCsv()

                DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
                    let bandNotes = CustomBandDescription();
                    let imageHandle = imageHandler()
                    
                    bandNotes.getDescriptionMapFile();
                    bandNotes.getAllDescriptions()
                    imageHandle.getAllImages(bandNameHandle: bandNameHandle)
                }
                
            }
            self.bandsByName = [String]()
            self.bands =  [String]()

            schedule.populateSchedule()
            self.bands = getFilteredBands(bandNameHandle: bandNameHandle, schedule: schedule, dataHandle: dataHandle, attendedHandle: self.attendedHandle)
            
            currentBandList = self.bands
            self.bandsByName = self.bands
            
            let iCloudHandle = iCloudDataHandler()
            iCloudHandle.readCloudData()
            
            
            DispatchQueue.main.async{
                print ("Refreshing data in backgroud");

                self.bandNameHandle.readBandFile()
                self.dataHandle.getCachedData()
                self.ensureCorrectSorting()
                self.updateCountLable()
                self.refreshAlerts()
                self.setShowOnlyAttenedFilterStatus()
                self.tableView.reloadData()
                print ("DONE Refreshing data in backgroud 1");
                refreshDataLock = false;
                NotificationCenter.default.post(name: Notification.Name(rawValue: "refreshMainDisplayAfterRefresh"), object: nil)
            }
            //NotificationCenter.default.post(name: Notification.Name(rawValue: "refreshMainDisplayAfterRefresh"), object: nil)
        }
        //NotificationCenter.default.post(name: Notification.Name(rawValue: "refreshMainDisplayAfterRefresh"), object: nil)
        print ("Done Refreshing data in backgroud 2");
    } 
    
    
    func setShowOnlyAttenedFilterStatus(){
        
        print ("attendingCount is \(attendingCount)")
        if (attendingCount == 0){
            willAttendButton.isHidden = true;
            willAttendButton.isEnabled = false;
            showOnlyWillAttened = false;
            setShowOnlyWillAttened(false)
            resetFilterIcons();
        } else {
            willAttendButton.isHidden = false;
            willAttendButton.isEnabled = true;
        }
    }
    
    func resetFilterIcons(){

        if (getMustSeeOn() == true){
            mustSeeButton.setImage(getRankGuiIcons(rank: "must"), for: UIControl.State())
        }
        mustSeeButton.isEnabled = true
        
        if (getMightSeeOn() == true){
            mightSeeButton.setImage(getRankGuiIcons(rank: "might"), for: UIControl.State())
        }
        mightSeeButton.isEnabled = true
        
        if (getWontSeeOn() == true){
            wontSeeButton.setImage(getRankGuiIcons(rank: "wont"), for: UIControl.State())
        }
        wontSeeButton.isEnabled = true
        
        if (getUnknownSeeOn() == true){
            unknownButton.setImage(getRankGuiIcons(rank: "unknown"), for: UIControl.State())
        }
        unknownButton.isEnabled = true
    }
    
    @IBAction func onlyShowAttendedFilter(_ sender: UIButton) {
        
        if (getShowOnlyWillAttened() == false){
            setShowOnlyWillAttened(true)
            
            willAttendButton.setImage(UIImage(named: "icon-seen"), for: UIControl.State())
            
            mustSeeButton.setImage(getRankGuiIcons(rank: "mustAlt"), for: UIControl.State())
            mustSeeButton.setTitleShadowColor(UIColor.white, for: .focused)
            mustSeeButton.isEnabled = false
            
            mightSeeButton.setImage(getRankGuiIcons(rank: "mightAlt"), for: UIControl.State())
            mightSeeButton.isEnabled = false
            
            wontSeeButton.setImage(getRankGuiIcons(rank: "wontAlt"), for: UIControl.State())
            wontSeeButton.isEnabled = false
            
            unknownButton.setImage(getRankGuiIcons(rank: "unknownAlt"), for: UIControl.State())
            unknownButton.isEnabled = false
            
            let message = NSLocalizedString("showAttendedFilterTrueHelp", comment: "")
            ToastMessages(message).show(self, cellLocation: self.view.frame, placeHigh: false)
            
        } else {
            let message = NSLocalizedString("showAttendedFilterFalseHelp", comment: "")
            ToastMessages(message).show(self, cellLocation: self.view.frame,  placeHigh: false)
            
            setShowOnlyWillAttened(false)
            willAttendButton.setImage(UIImage(named: "icon-seen-alt"), for: UIControl.State())
            resetFilterIcons();
        }
        
        dataHandle.writeFiltersFile();
        
        bands =  [String]()
        quickRefresh()
        bands = getFilteredBands(bandNameHandle: bandNameHandle, schedule: schedule, dataHandle: dataHandle, attendedHandle: attendedHandle)
        
        updateCountLable()
        tableView.reloadData()
    }
    
    @IBAction func filterContent(_ sender: UIButton) {
        
        print ("sender.titleLabel is \(sender.tag) = \(getMustSeeIcon())")
        if (sender.tag == mustSeeIconFilterTag){
            
            if (getMustSeeOn() == true){
                setMustSeeOn(false)
                sender.setTitle(mustSeeIcon, for: UIControl.State())
                sender.setImage(getRankGuiIcons(rank: "mustAlt"), for: UIControl.State())
            } else {
                setMustSeeOn(true)
                sender.setTitle(mustSeeIcon, for: UIControl.State())
                sender.setImage(getRankGuiIcons(rank: "must"), for: UIControl.State())

            }

        } else if (sender.tag == mightSeeIconFilterTag){
            if (getMightSeeOn() == true){
                setMightSeeOn(false)
                sender.setImage(getRankGuiIcons(rank: "mightAlt"), for: UIControl.State())
            } else {
                setMightSeeOn(true)
                sender.setImage(getRankGuiIcons(rank: "might"), for: UIControl.State())
            }
            
        } else if (sender.tag == wontSeeIconFilterTag){
            if (getWontSeeOn() == true){
                setWontSeeOn(false)
                sender.setImage(getRankGuiIcons(rank: "wontAlt"), for: UIControl.State())
            } else {
                setWontSeeOn(true)
                sender.backgroundColor = UIColor.clear
                sender.setImage(getRankGuiIcons(rank: "wont"), for: UIControl.State())
            }
            
        } else if (sender.tag == unknownIconFilterTag){
            if (getUnknownSeeOn() == true){
                setUnknownSeeOn(false)
                sender.setImage(getRankGuiIcons(rank: "unknownAlt"), for: UIControl.State())
            } else {
                setUnknownSeeOn(true)
                sender.setImage(getRankGuiIcons(rank: "unknown"), for: UIControl.State())
            }
            
        } else {
            bands =  [String]()
        
            bands = getFilteredBands(bandNameHandle: bandNameHandle, schedule: schedule, dataHandle: dataHandle, attendedHandle: attendedHandle)
            updateCountLable()
            tableView.reloadData()
            return
        }
        
        dataHandle.writeFiltersFile()
        print("Sorted  by is " + sortedBy)
        bands =  [String]()
        quickRefresh()
        
        bands = getFilteredBands(bandNameHandle: bandNameHandle, schedule: schedule, dataHandle: dataHandle, attendedHandle: attendedHandle)
    
        
        updateCountLable()
        tableView.reloadData()
    }
    
    func updateCountLable(){
        
        var lableCounterString = String();
        var labeleCounter = Int()

        print ("eventCount = \(eventCount) and unofficalEventCount = \(unofficalEventCount)")
        if eventCount == 0 {
            labeleCounter = bandsByName.count
            lableCounterString = " bands";
        
        } else if eventCount == unofficalEventCount {
            labeleCounter = bandsByName.count - unofficalEventCount
            lableCounterString = " bands";
            
        } else {
            labeleCounter = eventCount
            lableCounterString = " events";
        }
        print ("labeleCounter:" + String(labeleCounter))
        print ("lableCounterString:" + lableCounterString)
        
        print ("titleButtonTitle:" + String(describing: titleButton.title))
        titleButton.title = "70,000 Tons " + String(labeleCounter) + lableCounterString        
        
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

        popoverMenuViewController?.sourceView = unknownButton
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
        
        let dataHandle = dataHandler()
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
                
                ToastMessages(message).show(self, cellLocation: placementOfCell!,  placeHigh: false)
                isLoadingBandData = false
                self.quickRefresh()
            } else {
                let message =  "No Show Is Associated With This Entry"
                ToastMessages(message).show(self, cellLocation: placementOfCell!, placeHigh: false)
            }
        })
        sawAllShow.setIcon(iconImage: UIImage(named: "icon-seen")!, backColor: UIColor.darkGray, cellHeight: 58, cellWidth: 105)
 
        let mustSeeAction = UITableViewRowAction(style:UITableViewRowAction.Style.normal, title:"", handler: { (action:UITableViewRowAction!, indexPath:IndexPath!) -> Void in
            
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            dataHandle.addPriorityData(bandName, priority: 1);
            print ("Offline is offline");
            isLoadingBandData = false
            self.quickRefresh()

        })
        
        
        mustSeeAction.setIcon(iconImage: UIImage(named: mustSeeIcon)!, backColor: UIColor.darkGray, cellHeight: 58, cellWidth: 105)
        
        let mightSeeAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title:"", handler: { (action:UITableViewRowAction!, indexPath:IndexPath!) -> Void in
            
            print ("Changing the priority of " + self.currentlySectionBandName(indexPath.row) + " to 2")
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            dataHandle.addPriorityData(bandName, priority: 2);
            isLoadingBandData = false
            self.quickRefresh()
            
        })
        
        mightSeeAction.setIcon(iconImage: UIImage(named: mightSeeIcon)!, backColor: UIColor.darkGray, cellHeight: 58, cellWidth: 105)
        
        let wontSeeAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title:"", handler: { (action:UITableViewRowAction!, indexPath:IndexPath!) -> Void in
            
            print ("Changing the priority of " + self.currentlySectionBandName(indexPath.row) + " to 3")
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            dataHandle.addPriorityData(bandName, priority: 3);
            isLoadingBandData = false
            self.quickRefresh()
            
        })
        
        wontSeeAction.setIcon(iconImage: UIImage(named: wontSeeIcon)!, backColor: UIColor.darkGray, cellHeight: 58, cellWidth: 105)
        
        let setUnknownAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title:"", handler: { (action:UITableViewRowAction!, indexPath:IndexPath!) -> Void in
            
            print ("Changing the priority of " + self.currentlySectionBandName(indexPath.row) + " to 0")
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            dataHandle.addPriorityData(bandName, priority: 0);
            isLoadingBandData = false
            self.quickRefresh()
            
        })
        setUnknownAction.setIcon(iconImage: UIImage(named: unknownIcon)!, backColor: UIColor.darkGray, cellHeight: 58, cellWidth: 105)
        
        if (eventCount == 0){
            return [setUnknownAction, wontSeeAction, mightSeeAction, mustSeeAction]
        } else {
            return [sawAllShow, wontSeeAction, mightSeeAction, mustSeeAction]
        }
    }
    
    //swip code end
    
    func configureCell(_ cell: UITableViewCell, atIndexPath indexPath: IndexPath) {
        
        setBands(bands)
        setScheduleButton(scheduleButton.isHidden)
        
        
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
        
        self.splitViewController!.preferredDisplayMode = UISplitViewController.DisplayMode.allVisible
        
        self.extendedLayoutIncludesOpaqueBars = true
        
        if segue.identifier == "showDetail" {
            if let indexPath = self.tableView.indexPathForSelectedRow {
            
                let cell = self.tableView.cellForRow(at: indexPath)
                let bandNameView = cell!.viewWithTag(2) as! UILabel
                
                let cellDataView = cell!.viewWithTag(1) as! UILabel
                let cellDataText = cellDataView.text ?? "";
                
                eventSelectedIndex = cellDataView.text!
                
                let bandName = bandNameView.text ?? "";
                
                detailMenuChoices(cellDataText: cellDataText, bandName: bandName, segue: segue, indexPath: indexPath)
            }
        }
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
           if (cellData.count == 4 && defaults.bool(forKey: "promptForAttended") == true){
               
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
                    defaults.set(false, forKey: "promptForAttended")
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
    
    @IBAction func resortBands(_ sender: UIButton) {
        
        var message = "";
        if (sortedBy == "name"){
            sortedBy = "time"
            message = NSLocalizedString("Sorting Chronologically", comment: "")
            
        } else {
            message = NSLocalizedString("Sorting Alphabetically", comment: "")
            sortedBy = "name"
        }
        setSortedBy(sortedBy)
        ToastMessages(message).show(self, cellLocation: self.view.frame,  placeHigh: false)
        ensureCorrectSorting()
        dataHandle.writeFiltersFile()
        self.tableView.reloadData()
        
    }
    
    //iCloud data loading
    @objc func onSettingsChanged(_ notification: Notification) {
        //iCloudDataHandle.writeiCloudData(dataHandle: dataHandle, attendedHandle: attendedHandle)
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



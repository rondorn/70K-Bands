//
//  MasterViewController.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/2/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import UIKit
import CoreData


class MasterViewController: UITableViewController, UISplitViewControllerDelegate, NSFetchedResultsControllerDelegate {
    
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
    let attendedHandler = ShowsAttended()

    var backgroundColor = UIColor.white;
    var textColor = UIColor.black;
    var detailViewController: DetailViewController? = nil
    var managedObjectContext: NSManagedObjectContext? = nil
    
    var objects = NSMutableArray()
    var bands =  [String]()
    var bandsByTime = [String]()
    var bandsByName = [String]()
    var reloadTableBool = true
    
    @IBOutlet weak var titleLabel: UINavigationItem!
    
    var dataHandle = dataHandler()

    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        self.refreshControl = refreshControl
        
        //scheduleButton.setBackgroundImage(getSortButtonImage(), for: UIControl.State.normal)
        scheduleButton.setImage(getSortButtonImage(), for: UIControl.State.normal)
        //scheduleButton.setTitle(getBandIconSort(), for: UIControl.State())
        dataHandle.readFiltersFile()
        setFilterButtons()

        refreshData()
        
        UserDefaults.standard.didChangeValue(forKey: "mustSeeAlert")
        
        NotificationCenter.default.addObserver(self, selector: #selector(MasterViewController.refreshDisplayAfterWake), name: NSNotification.Name(rawValue: "RefreshDisplay"), object: nil)
        
        
        NotificationCenter.default.addObserver(self, selector:#selector(MasterViewController.refreshAlerts), name: UserDefaults.didChangeNotification, object: nil)
        
        if (getShowOnlyWillAttened() == true){
            willAttendButton.setImage(UIImage(named: "ticket_icon"), for: UIControl.State())
        } else {
            willAttendButton.setImage(UIImage(named: "ticket_icon_alt"), for: UIControl.State())
        }
        
        refreshDisplayAfterWake();
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(MasterViewController.showReceivedMessage(_:)),
                                               name: UserDefaults.didChangeNotification, object: nil)
        
        setNeedsStatusBarAppearanceUpdate() 
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
            willAttendButton.setImage(UIImage(named: "ticket_icon"), for: UIControl.State())
        } else {
            willAttendButton.setImage(UIImage(named: "ticket_icon_alt"), for: UIControl.State())
        }
        
        //scheduleButton.setBackgroundImage(getSortButtonImage(), for: UIControl.State())
        scheduleButton.setImage(getSortButtonImage(), for: UIControl.State.normal)
        //self.scheduleButton.setTitle(getScheduleIcon(), for: UIControl.State())
    }
    
    @objc func refreshDisplayAfterWake(){
        self.refreshData()
    }
    
    @objc func refreshAlerts(){

        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            if #available(iOS 10.0, *) {
                let localNotication = localNoticationHandler()
                localNotication.addNotifications()
                
            } else {
                // Fallback on earlier versions
            }
        }
    
    }
    
    func refreshFromCache (){
        
        

        print ("RefreshFromCache called")
        bands =  [String]()
        bandsByName = [String]()
        bandNameHandle.readBandFile()
        schedule.getCachedData()
        bands = getFilteredBands(bandNameHandle: bandNameHandle, schedule: schedule, dataHandle: dataHandle)
        bandsByName = bands
        setShowOnlyAttenedFilterStatus()
    }
    
    func ensureCorrectSorting(){
        
        if (eventCount == 0){
            print("Schedule is empty, stay hidden")
            self.scheduleButton.isHidden = true;
            willAttendButton.isHidden = true;
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
            //scheduleButton.setImage(getSortButtonImage(), for: UIControl.State())
            //self.scheduleButton.setTitle(getScheduleIcon(), for: UIControl.State())
            
        } else {
            print("Sort By is Time, Show")
            //self.sortBandsByTime()
            self.scheduleButton.isHidden = false;
            willAttendButton.isHidden = false;
            //scheduleButton.setBackgroundImage(getSortButtonImage(), for: UIControl.State.normal)
            scheduleButton.setImage(getSortButtonImage(), for: UIControl.State.normal)
            //self.scheduleButton.setTitle(getBandIconSort(), for: UIControl.State())
            
        }
        bands =  [String]()
        bands = getFilteredBands(bandNameHandle: bandNameHandle, schedule: schedule, dataHandle: dataHandle)
    }
    
    func quickRefresh(){
        
        if (isPerformingQuickLoad == false){
            isPerformingQuickLoad = true
            
            dataHandle.refreshData()
            self.bands = getFilteredBands(bandNameHandle: bandNameHandle, schedule: schedule, dataHandle: dataHandle)
            self.bandsByName = self.bands
            ensureCorrectSorting()
            updateCountLable()
            setShowOnlyAttenedFilterStatus()
            isPerformingQuickLoad = false
            self.tableView.reloadData()
        }
    }
    
    @objc func refreshData(){
        
        print ("Waiting for bandData, Done")
        
        //check if the timezonr has changes for whatever reason
        localTimeZoneAbbreviation = TimeZone.current.abbreviation()!
        
        internetAvailble = isInternetAvailable();
        print ("Internetavailable is  \(internetAvailble)");
        if (internetAvailble == false){
            self.refreshControl?.endRefreshing();
        
        } else {
            //clear busy indicator after a 3 second delay
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3), execute: {
                self.refreshControl?.endRefreshing();
            })
        }

        refreshFromCache()
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            
            let dataHandle = dataHandler()
            var offline = true
            let attendedHandler = ShowsAttended()
            
            if Reachability.isConnectedToNetwork(){
                offline = false;
            }
            
            let bandNameHandle = bandNamesHandler()
            let schedule = scheduleHandler()
            if (offline == false){
                
                dataHandle.refreshData()
                bandNameHandle.gatherData();
                
                schedule.DownloadCsv()
                let validate = validateCSVSchedule()
                validate.validateSchedule()
                
                DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
                    let bandNotes = CustomBandDescription();
                    
                    bandNotes.getAllDescriptions()
                    getAllImages()
                }
                
            }
            self.bandsByName = [String]()
            self.bands =  [String]()
            
            schedule.populateSchedule()
            self.bands = getFilteredBands(bandNameHandle: bandNameHandle, schedule: schedule, dataHandle: dataHandle)
            self.bandsByName = self.bands
            
            
            DispatchQueue.main.async{
                self.dataHandle.refreshData()
                self.ensureCorrectSorting()
                self.updateCountLable()
                self.tableView.reloadData()
                self.refreshAlerts()
                self.setShowOnlyAttenedFilterStatus()
                self.tableView.reloadData()
            }
        
        }
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
            
            willAttendButton.setImage(UIImage(named: "ticket_icon"), for: UIControl.State())
            
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
            ToastMessages(message).show(self, cellLocation: self.view.frame)
            
        } else {
            let message = NSLocalizedString("showAttendedFilterFalseHelp", comment: "")
            ToastMessages(message).show(self, cellLocation: self.view.frame)
            
            setShowOnlyWillAttened(false)
            willAttendButton.setImage(UIImage(named: "ticket_icon_alt"), for: UIControl.State())
            resetFilterIcons();
        }
        
        dataHandle.writeFiltersFile();
        
        bands =  [String]()
        quickRefresh()
        bands = getFilteredBands(bandNameHandle: bandNameHandle, schedule: schedule, dataHandle: dataHandle)
        
        updateCountLable()
        tableView.reloadData()
    }
    
    @IBAction func filterContent(_ sender: UIButton) {
        
        if (sender.titleLabel?.text == getMustSeeIcon()){
            
            if (getMustSeeOn() == true){
                setMustSeeOn(false)
                sender.setTitle(mustSeeIcon, for: UIControl.State())
                sender.setImage(getRankGuiIcons(rank: "mustAlt"), for: UIControl.State())
            } else {
                setMustSeeOn(true)
                sender.setTitle(mustSeeIcon, for: UIControl.State())
                sender.setImage(getRankGuiIcons(rank: "must"), for: UIControl.State())

            }

        } else if (sender.titleLabel?.text == getMightSeeIcon()){
            if (getMightSeeOn() == true){
                setMightSeeOn(false)
                sender.setImage(getRankGuiIcons(rank: "mightAlt"), for: UIControl.State())
            } else {
                setMightSeeOn(true)
                sender.setImage(getRankGuiIcons(rank: "might"), for: UIControl.State())
            }
            
        } else if (sender.titleLabel?.text == getWillNotSeeIcon()){
            if (getWontSeeOn() == true){
                setWontSeeOn(false)
                sender.setImage(getRankGuiIcons(rank: "wontAlt"), for: UIControl.State())
            } else {
                setWontSeeOn(true)
                sender.backgroundColor = UIColor.clear
                sender.setImage(getRankGuiIcons(rank: "wont"), for: UIControl.State())
            }
            
        } else if (sender.titleLabel?.text == getUnknownIcon()){
            if (getUnknownSeeOn() == true){
                setUnknownSeeOn(false)
                sender.setImage(getRankGuiIcons(rank: "unknownAlt"), for: UIControl.State())
            } else {
                setUnknownSeeOn(true)
                sender.setImage(getRankGuiIcons(rank: "unknown"), for: UIControl.State())
            }
            
        } else {
            bands =  [String]()
        
            bands = getFilteredBands(bandNameHandle: bandNameHandle, schedule: schedule, dataHandle: dataHandle)
            updateCountLable()
            tableView.reloadData()
            return
        }
        
        dataHandle.writeFiltersFile()
        print("Sorted  by is " + sortedBy)
        bands =  [String]()
        quickRefresh()
        
        bands = getFilteredBands(bandNameHandle: bandNameHandle, schedule: schedule, dataHandle: dataHandle)
        
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
        
        var intro:String = ""
        
        let reportHandler = showAttendenceReport()
        reportHandler.assembleReport()
            
        intro += reportHandler.buildMessage()
      
        let objectsToShare = [intro]
        let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: [])
        
        activityVC.modalPresentationStyle = .popover
        activityVC.preferredContentSize = CGSize(width: 50, height: 100)
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
    
    //swip code start
    
    func currentlySectionBandName(_ rowNumber: Int) -> String{
        
        var bandName = "";
    
        print ("SelfBandCount is " + String(self.bands.count) + " rowNumber is " + String(rowNumber));
        if (self.bands.count > rowNumber){
            bandName = self.bands[rowNumber]
        }
        
        return bandName
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        let dataHandle = dataHandler()
        let attendedHandler = ShowsAttended()
        
        let sawAllShow = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title: attendedShowIcon, handler: { (action:UITableViewRowAction!, indexPath:IndexPath!) -> Void in
            
            let currentCel = tableView.cellForRow(at: indexPath)
            
            let cellText = currentCel?.textLabel?.text;
            let cellStatus = currentCel!.viewWithTag(2) as! UILabel
            print ("Cell text for parsing is \(cellText)")
            let placementOfCell = currentCel?.frame
            
            if (cellStatus.isHidden == false){
                let cellData = cellText?.split(separator: ";")
                
                let cellBandName = cellData![0]
                let cellLocation = cellData![1]
                let cellEventType  = cellData![2]
                let cellStartTime = cellData![3]

                let status = attendedHandler.addShowsAttended(band: String(cellBandName), location: String(cellLocation), startTime: String(cellStartTime), eventType: String(cellEventType),eventYearString: String(eventYear));
                
                let empty : UITextField = UITextField();
                let message = attendedHandler.setShowsAttendedStatus(empty, status: status)
                
                attendedHandler.loadShowsAttended()
                
                ToastMessages(message).show(self, cellLocation: placementOfCell!)
                isLoadingBandData = false
                self.quickRefresh()
            } else {
                let message =  "No Show Is Associated With This Entry"
                ToastMessages(message).show(self, cellLocation: placementOfCell!)
            }
        })
 
        let mustSeeAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title:getMustSeeIcon(), handler: { (action:UITableViewRowAction!, indexPath:IndexPath!) -> Void in
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            dataHandle.addPriorityData(bandName, priority: 1, attendedHandler: attendedHandler);
            print ("Offline is offline");
            isLoadingBandData = false
            self.quickRefresh()

        })

        let mightSeeAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title:getMightSeeIcon(), handler: { (action:UITableViewRowAction!, indexPath:IndexPath!) -> Void in
            
            print ("Changing the priority of " + self.currentlySectionBandName(indexPath.row) + " to 2")
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            dataHandle.addPriorityData(bandName, priority: 2, attendedHandler: attendedHandler);
            isLoadingBandData = false
            self.quickRefresh()
            
        })
        
        let wontSeeAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title:getWillNotSeeIcon(), handler: { (action:UITableViewRowAction!, indexPath:IndexPath!) -> Void in
            
            print ("Changing the priority of " + self.currentlySectionBandName(indexPath.row) + " to 3")
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            dataHandle.addPriorityData(bandName, priority: 3, attendedHandler: attendedHandler);
            isLoadingBandData = false
            self.quickRefresh()
            
        })
        
        let setUnknownAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title:getUnknownIcon(), handler: { (action:UITableViewRowAction!, indexPath:IndexPath!) -> Void in
            
            print ("Changing the priority of " + self.currentlySectionBandName(indexPath.row) + " to 0")
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            dataHandle.addPriorityData(bandName, priority: 0, attendedHandler: attendedHandler);
            isLoadingBandData = false
            self.quickRefresh()
            
        })
        
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
        
        getCellValue(indexPath.row, schedule: schedule, sortBy: sortedBy, cell: cell, dataHandle: dataHandle)
    
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("Getting Details")
        
        print ("Waiting for band data to load, Done")
        self.splitViewController!.delegate = self;
        
        self.splitViewController!.preferredDisplayMode = UISplitViewController.DisplayMode.allVisible
        
        self.extendedLayoutIncludesOpaqueBars = true
        
        if segue.identifier == "showDetail" {
            if let indexPath = self.tableView.indexPathForSelectedRow {
                
                let bandName = getNameFromSortable(currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy);
                 if (bandName.isEmpty == false){
                    print ("Bands size is " + String(bands.count) + " Index is  " + String(indexPath.row))
                    bandListIndexCache = indexPath.row
                    let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
                
                        print ("Bands size is " + String(bands.count) + " Index is  " + String(indexPath.row))

                        controller.detailItem = bandName as AnyObject
                        controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem
                        controller.navigationItem.leftItemsSupplementBackButton = true
                } else {
                    print ("Found an issue with the selection");
                    return
                }
            }
        }
        tableView.reloadData()
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
        ToastMessages(message).show(self, cellLocation: self.view.frame)
        ensureCorrectSorting()
        dataHandle.writeFiltersFile()
        self.tableView.reloadData()
        
    }
    
    //iCloud data loading
    @objc func onSettingsChanged(_ notification: Notification) {
        dataHandle.writeiCloudData()
    }

}


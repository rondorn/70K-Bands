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
    
    
    @IBOutlet weak var mustSeeButton: UIButton!
    @IBOutlet weak var mightSeeButton: UIButton!
    @IBOutlet weak var willNotSeeButton: UIButton!
    @IBOutlet weak var wontSeeButton: UIButton!
    @IBOutlet weak var unknownButton: UIButton!
    
    @IBOutlet weak var Undefined: UIButton!
    @IBOutlet weak var shareButton: UIBarButtonItem!
    @IBOutlet weak var contentController: UIView!
    @IBOutlet weak var scheduleButton: UIButton!
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var blankScreenActivityIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var menuButton: UIBarButtonItem!
    
    var detailViewController: DetailViewController? = nil
    var managedObjectContext: NSManagedObjectContext? = nil
    
    var objects = NSMutableArray()
    var bands =  [String]()
    var bandsByTime = [String]()
    var bandsByName = [String]()
    var reloadTableBool = true
    
    @IBOutlet weak var titleLabel: UINavigationItem!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
            self.clearsSelectionOnViewWillAppear = false
            self.preferredContentSize = CGSize(width: 320.0, height: 600.0)
        }
    }

    override func viewWillAppear(animated: Bool) {
        print ("The viewWillAppear was called");
        super.viewWillAppear(animated)
        refreshData()
        tableView.reloadData()
    }
    
    @IBAction func menuButtonAction(sender: AnyObject) {
        let secondViewController = self.storyboard?.instantiateViewControllerWithIdentifier("sortMenuNavigation")
        let window = UIApplication.sharedApplication().windows[0] as UIWindow
        UIView.transitionFromView(
            window.rootViewController!.view,
            toView: secondViewController!.view,
            duration: 0.65,
            options: .TransitionCrossDissolve,
            completion: {
                finished in window.rootViewController = secondViewController
        })
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sortedBy = "time"
        
        //have a reference to this controller for external refreshes
        masterView = self;
        
        // Do any additional setup after loading the view, typically from a nib.
        splitViewController?.preferredDisplayMode = UISplitViewControllerDisplayMode.AllVisible
        
        blankScreenActivityIndicator.hidesWhenStopped = true
        
        //icloud change notification
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: #selector(MasterViewController.onSettingsChanged(_:)),
            name: NSUserDefaultsDidChangeNotification ,
            object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self,
                                                         selector: #selector(MasterViewController.showReceivedMessage(_:)),
                                                         name: NSUserDefaultsDidChangeNotification, object: nil)
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(MasterViewController.refreshData), forControlEvents: UIControlEvents.ValueChanged)
        self.refreshControl = refreshControl
        scheduleButton.setTitle(getBandIconSort(), forState: UIControlState.Normal)
        
        readFiltersFile()
        setFilterButtons()
        refreshData()
        
        NSUserDefaults.standardUserDefaults().didChangeValueForKey("mustSeeAlert")
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(MasterViewController.refreshDisplayAfterWake), name: "RefreshDisplay", object: nil)
        
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector:#selector(MasterViewController.refreshAlerts), name: NSUserDefaultsDidChangeNotification, object: nil)
        
        if (eventCount != 0 && sortedBy == "name"){
            sortedBy = "time";
        }
        
    }
 
    
    func showReceivedMessage(notification: NSNotification) {
        if let info = notification.userInfo as? Dictionary<String,AnyObject> {
            if let aps = info["aps"] as? Dictionary<String, String> {
                showAlert("Message received", message: aps["alert"]!)
            }
        } else {
            print("Software failure. Guru meditation.")
        }
    }
    
    func showAlert(title:String, message:String) {

            let alert = UIAlertController(title: title,
                                          message: message, preferredStyle: .Alert)
            let dismissAction = UIAlertAction(title: "Dismiss", style: .Destructive, handler: nil)
            alert.addAction(dismissAction)
            self.presentViewController(alert, animated: true, completion: nil)

    }
    
    func setFilterButtons(){
        
        if (getMustSeeOn() == false){
            mustSeeButton.setImage(UIImage(named: "mustSeeIconAlt"), forState: .Normal)
        }
        if (getMightSeeOn() == false){
            mightSeeButton.setImage(UIImage(named: "mightSeeIconAlt"), forState: .Normal)
        }
        if (getWontSeeOn() == false){
            wontSeeButton.setImage(UIImage(named: "willNotSeeAlt"), forState: .Normal)
        }
        if (getUnknownSeeOn() == false){
            unknownButton.setImage(UIImage(named: "unknownAlt"), forState: .Normal)
        }
    }
    
    func refreshDisplayAfterWake(){
        
        if (sortedBy == "time"){
            refreshFromCache()
            self.tableView.reloadData()
        } else {
            refreshData()
        }
    }
    
    func refreshAlerts(){
        dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_BACKGROUND.rawValue), 0)) {
            let localNotication = localNoticationHandler()
            localNotication.clearNotifications()
            localNotication.addNotifications()
        }
    }
    
    func refreshFromCache (){
        
        bands =  [String]()
        bandsByName = [String]()
        readBandFile()
        schedule.populateSchedule()
        bands = getFilteredBands(getBandNames(), schedule: schedule, sortedBy: sortedBy)
        bandsByName = bands
        
    }
    
    func ensureCorrectSorting(){
        
        if (eventCount == 0){
            print("Schedule is empty, stay hidden")
            self.scheduleButton.hidden = true;
            sortedBy = "name"
            self.scheduleButton.setTitle(getScheduleIcon(), forState: UIControlState.Normal)
            
        } else if (sortedBy == "name"){
            print("Sort By is Name, Show")
            self.scheduleButton.hidden = false;
            self.scheduleButton.setTitle(getScheduleIcon(), forState: UIControlState.Normal)
            
        } else {
            sortedBy = "time"
            print("Sort By is Time, Show")
            //self.sortBandsByTime()
            self.scheduleButton.hidden = false;
            self.scheduleButton.setTitle(getBandIconSort(), forState: UIControlState.Normal)
            
        }
        bands =  [String]()
        bands = getFilteredBands(getBandNames(), schedule: schedule, sortedBy: sortedBy)
    }
    
    func quickRefresh(){
        
        self.bands = getFilteredBands(getBandNames(), schedule: schedule, sortedBy: sortedBy)
        self.bandsByName = self.bands
        ensureCorrectSorting()
        updateCountLable()
        
        self.tableView.reloadData()
    }
    
    func refreshData(){
        
        refreshFromCache()
        
        let priority = DISPATCH_QUEUE_PRIORITY_DEFAULT
        
        dispatch_async(dispatch_get_global_queue(priority, 0)) {
            
            gatherData();

            if (offline == false){
                schedule.DownloadCsv()
                let validate = validateCSVSchedule()
                validate.validateSchedule()
            }
            self.bandsByName = [String]()
            self.bands =  [String]()
            
            schedule.populateSchedule()
            self.bands = getFilteredBands(getBandNames(), schedule: schedule, sortedBy: sortedBy)
            self.bandsByName = self.bands
            dispatch_async(dispatch_get_main_queue()){
                
                self.ensureCorrectSorting()
                self.updateCountLable()
                self.tableView.reloadData()
                self.blankScreenActivityIndicator.stopAnimating()
            }
        }
        
        if (bands.count == 0){
            blankScreenActivityIndicator.startAnimating()
        }
        ensureCorrectSorting()
        refreshAlerts()
        
        updateCountLable()
        self.tableView.reloadData()
        if (self.refreshControl?.refreshing == true){
            sleep(5)
            self.refreshControl?.endRefreshing()
        }
        
        
    } 
    
    func showHideFilterMenu(){
        print ("totalUpcomingEvents is " + String(totalUpcomingEvents))
        if (totalUpcomingEvents == 0){
            menuButton.title = "";
            menuButton.enabled = false;
        } else {
            menuButton.title = "Filters";
            menuButton.enabled = true;
        }
    }
    
    @IBAction func filterContent(sender: UIButton) {
        
        
        if (sender.titleLabel?.text == getMustSeeIcon()){
            
            if (getMustSeeOn() == true){
                setMustSeeOn(false)
                sender.setImage(UIImage(named: "willSeeIconAlt"), forState: .Normal)
            
            } else {
                setMustSeeOn(true)
                sender.setImage(UIImage(named: "willSeeIcon"), forState: .Normal)

            }

        } else if (sender.titleLabel?.text == getMightSeeIcon()){
            if (getMightSeeOn() == true){
                setMightSeeOn(false)
                sender.setImage(UIImage(named: "mightSeeIconAlt"), forState: .Normal)
            } else {
                setMightSeeOn(true)
                sender.setImage(UIImage(named: "mightSeeIcon"), forState: .Normal)
            }
            
        } else if (sender.titleLabel?.text == getWillNotSeeIcon()){
            if (getWontSeeOn() == true){
                setWontSeeOn(false)
                sender.setImage(UIImage(named: "willNotSeeAlt"), forState: .Normal)
            } else {
                setWontSeeOn(true)
                sender.backgroundColor = UIColor.clearColor()
                sender.setImage(UIImage(named: "willNotSee"), forState: .Normal)
            }
            
        } else if (sender.titleLabel?.text == getUnknownIcon()){
            if (getUnknownSeeOn() == true){
                setUnknownSeeOn(false)
                sender.setImage(UIImage(named: "unknownAlt"), forState: .Normal)
            } else {
                setUnknownSeeOn(true)
                sender.setImage(UIImage(named: "unknown"), forState: .Normal)
            }
            
        } else {
            bands =  [String]()
            bands = getFilteredBands(getBandNames(), schedule: schedule,sortedBy: sortedBy)
            updateCountLable()
            tableView.reloadData()
            return
        }
        
        print("Sorted  by is " + sortedBy)
        bands =  [String]()
        quickRefresh()
        bands = getFilteredBands(getBandNames(), schedule: schedule,sortedBy: sortedBy)
        
        updateCountLable()
        tableView.reloadData()
    }
    
    func updateCountLable(){
        
        var lableCounterString = String();
        var labeleCounter = Int()
        
        if eventCount == 0 {
            labeleCounter = bandsByName.count
            lableCounterString = " bands";
            
        } else {
            labeleCounter = eventCount
            lableCounterString = " events";
        }
        
        titleLabel.title = "70,000 Tons\t" + String(labeleCounter) + lableCounterString
        showHideFilterMenu()
        
    }
    
    @IBAction func shareButtonClicked(sender: UIButton){
        
        let intro = "These are the bands I MUST see on the 70,000 Tons Cruise\n"
        var favoriteBands = "\n"
        
        bands = getBandNames()
        for band in bands {
            if (getPriorityData(band) == 1){
                print ("Adding band " + band)
                favoriteBands += "\t" + getMustSeeIcon() + "\t" +  band + "\n"
            }
        }
        
        let outtro =  "\n\nhttp://www.facebook.com/70kBands\n"
        
        let objectsToShare = [intro, favoriteBands, outtro]
        let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
        
        activityVC.modalPresentationStyle = .Popover
        activityVC.preferredContentSize = CGSizeMake(50, 100)
        activityVC.popoverPresentationController?.barButtonItem = shareButton
        
        let popoverMenuViewController = activityVC.popoverPresentationController
        popoverMenuViewController?.permittedArrowDirections = .Any

        popoverMenuViewController?.sourceView = sender
        popoverMenuViewController?.sourceRect = CGRect()


        self.presentViewController(activityVC, animated: true, completion: nil)
    }

    func adaptivePresentationStyleForPresentationController(
        controller: UIPresentationController!) -> UIModalPresentationStyle {
            return .None
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table View

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bands.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) 
        self.configureCell(cell, atIndexPath: indexPath)
        return cell
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    }
    
    //swip code start
    
    func currentlySectionBandName(rowNumber: Int) -> String{
        
        var bandName = "None";
    
        print ("SelfBandCount is " + String(self.bands.count) + " rowNumber is " + String(rowNumber));
        if (self.bands.count >= rowNumber){
            bandName = self.bands[rowNumber]
        }
        
        return bandName
    }
    
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        
        let mustSeeAction = UITableViewRowAction(style: UITableViewRowActionStyle.Default, title: getMustSeeIcon() , handler: { (action:UITableViewRowAction!, indexPath:NSIndexPath!) -> Void in
            print ("Changing the priority of " + self.currentlySectionBandName(indexPath.row) + " to 1")
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            addPriorityData(bandName, priority: 1);
            print ("Offline is offline");
            self.quickRefresh()

        })

        let mightSeeAction = UITableViewRowAction(style: UITableViewRowActionStyle.Default, title: getMightSeeIcon() , handler: { (action:UITableViewRowAction!, indexPath:NSIndexPath!) -> Void in
            
            print ("Changing the priority of " + self.currentlySectionBandName(indexPath.row) + " to 2")
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            addPriorityData(bandName, priority: 2);
            self.quickRefresh()
            
        })
        
        let wontSeeAction = UITableViewRowAction(style: UITableViewRowActionStyle.Default, title: getWillNotSeeIcon() , handler: { (action:UITableViewRowAction!, indexPath:NSIndexPath!) -> Void in
            
            print ("Changing the priority of " + self.currentlySectionBandName(indexPath.row) + " to 3")
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            addPriorityData(bandName, priority: 3);
            self.quickRefresh()
            
        })
        
        let setUnknownAction = UITableViewRowAction(style: UITableViewRowActionStyle.Default, title: getUnknownIcon() , handler: { (action:UITableViewRowAction!, indexPath:NSIndexPath!) -> Void in
            
            print ("Changing the priority of " + self.currentlySectionBandName(indexPath.row) + " to 0")
            let bandName = getNameFromSortable(self.currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy)
            addPriorityData(bandName, priority: 0);
            self.quickRefresh()
            
        })
        
        mustSeeAction.backgroundColor = UIColor.whiteColor()
        mightSeeAction.backgroundColor = UIColor.whiteColor()
        wontSeeAction.backgroundColor = UIColor.whiteColor()
        setUnknownAction.backgroundColor = UIColor.whiteColor()
        
        return [setUnknownAction, wontSeeAction, mightSeeAction, mustSeeAction]
    }
    
    //swip code end
    
    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
        
        setBands(bands)
        setScheduleButton(scheduleButton.hidden)
        
        cell.textLabel!.text = getCellValue(indexPath.row, schedule: schedule, sortBy: sortedBy)

    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        print("Getting Details")
        if segue.identifier == "showDetail" {
            if let indexPath = self.tableView.indexPathForSelectedRow {

                let controller = (segue.destinationViewController as! UINavigationController).topViewController as! DetailViewController
                
                print ("Bands size is " + String(bands.count) + " Index is  " + String(indexPath.row))
                let bandName = getNameFromSortable(currentlySectionBandName(indexPath.row) as String, sortedBy: sortedBy);
                controller.detailItem = bandName
                controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
                controller.navigationItem.leftItemsSupplementBackButton = true
            }
        }
        tableView.reloadData()
    }
    
    func resortBandsByTime(){
        schedule.populateSchedule()
    }
    
    @IBAction func resortBands(sender: UIButton) {
        
        if (sortedBy == "name"){
            sortedBy = "time"
            ensureCorrectSorting()
            
        } else {
            
            sortedBy = "name"
            ensureCorrectSorting()
            
        }
        
        self.tableView.reloadData()
    
    }
    
    //iCloud data loading
    func onSettingsChanged(notification: NSNotification) {
        writeiCloudData()
    }

}


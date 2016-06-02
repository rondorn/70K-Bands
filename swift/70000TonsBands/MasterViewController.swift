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
    
    
    var detailViewController: DetailViewController? = nil
    var managedObjectContext: NSManagedObjectContext? = nil

    var objects = NSMutableArray()
    var bands =  [String]()
    var bandsByTime = [String]()
    var bandsByName = [String]()
    
    @IBOutlet weak var titleLabel: UINavigationItem!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
            self.clearsSelectionOnViewWillAppear = false
            self.preferredContentSize = CGSize(width: 320.0, height: 600.0)
        }
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
        
        if (schedule.getBandSortedSchedulingData().count > 2 && sortedBy == "name"){
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
            resortBandsByTime()
            //bands = bandsByTime
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
        
        readBandFile()
        schedule.populateSchedule()
        bands = getFilteredBands(getBandNames(), schedule: schedule, sortedBy: sortedBy)
        bandsByName = bands
        
    }
    
    func ensureCorrectSorting(){
        
        if (schedule.schedulingData.isEmpty == true){
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
        bands = getFilteredBands(getBandNames(), schedule: schedule, sortedBy: sortedBy)
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
    
    @IBAction func settingsAction(sender: UIButton) {
         UIApplication.sharedApplication().openURL(NSURL(string:UIApplicationOpenSettingsURLString)!);
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
            bands = getFilteredBands(getBandNames(), schedule: schedule,sortedBy: sortedBy)
            updateCountLable()
            tableView.reloadData()
            return
        }
        
        print("Sorted  by is " + sortedBy)
        bands = getFilteredBands(getBandNames(), schedule: schedule,sortedBy: sortedBy)
        if (sortedBy == "time"){
            //sortBandsByTime()
            //bands = bandsByTime
        }
        
        updateCountLable()
        tableView.reloadData()
    }
    
    func updateCountLable(){
        
        var lableCounterString = String();
        var labeleCounter = Int()
        
        if bandCount > 0 {
            labeleCounter = bandCount
            lableCounterString = " bands";
            
        } else {
            labeleCounter = eventCount
            lableCounterString = " events";
        }
        
       titleLabel.title = "70,000 Tons\t" + String(labeleCounter) + lableCounterString
        
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
    
    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
        
        setBands(bands)
        setScheduleButton(scheduleButton.hidden)
        
        cell.textLabel!.text = getCellValue(indexPath.row, schedule: schedule, sortBy: sortedBy)

    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        print("Getting Details")
        if segue.identifier == "showDetail" {
            if let indexPath = self.tableView.indexPathForSelectedRow {
                print(bands[indexPath.row])
                //let object = bands[indexPath.row] as String
                //(segue.destinationViewController as DetailViewController).detailItem = bands[indexPath.row]
                let controller = (segue.destinationViewController as! UINavigationController).topViewController as! DetailViewController
                
                let bandName = getNameFromSortable(bands[indexPath.row] as String, sortedBy: sortedBy);
                controller.detailItem = bandName
                controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
                controller.navigationItem.leftItemsSupplementBackButton = true
            }
        }
        tableView.reloadData()
    }
    
    /*
    func sortBandsByTime() {
        
        var sortableBands = Dictionary<NSTimeInterval, String>()
        var sortableTimeIndexArray = [NSTimeInterval]()
        var sortedBands = [String]()
        
        //var fullBands = bands;
        var dupAvoidBands = Dictionary<String,Int>()
        
        let futureTime :Int64 = 8000000000000;
        var noShowsLeftMagicNumber = NSTimeInterval(futureTime)
        
        for bandName in bands {
            let timeIndex: NSTimeInterval = schedule.getCurrentIndex(bandName);
            if (timeIndex > NSDate().timeIntervalSince1970 - 3600){
                sortableBands[timeIndex] = bandName
                sortableTimeIndexArray.append(timeIndex)
            } else {
                sortableBands[noShowsLeftMagicNumber] = bandName
                sortableTimeIndexArray.append(noShowsLeftMagicNumber)
                noShowsLeftMagicNumber = noShowsLeftMagicNumber + 1
            }
        }
        
        
        let sortedArray = sortableTimeIndexArray.sort({$0 < $1})
        
        for index in sortedArray{
            //if (dupAvoidBands[sortableBands[index]!] == nil){
                sortedBands.append(sortableBands[index]!)
                dupAvoidBands[sortableBands[index]!] = 1
            //}
        }
        
        
        bandsByTime = sortedBands
        
    }
    */
    
    func resortBandsByTime(){
        schedule.populateSchedule()
        //sortBandsByTime()
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


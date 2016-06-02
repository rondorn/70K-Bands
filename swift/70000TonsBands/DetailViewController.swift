//
//  DetailViewController.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/2/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import UIKit
import CoreData

class DetailViewController: UIViewController{
    
    @IBOutlet weak var titleLable: UINavigationItem!
    @IBOutlet weak var bandLogo: UIImageView!
    @IBOutlet weak var officialUrlButton: UIButton!
    @IBOutlet weak var wikipediaUrlButton: UIButton!
    @IBOutlet weak var youtubeUrlButton: UIButton!
    @IBOutlet weak var metalArchivesButton: UIButton!
    
    @IBOutlet weak var returnToMaster: UINavigationItem!
    
    @IBOutlet weak var Event1: UITextField!
    @IBOutlet weak var Event2: UITextField!
    @IBOutlet weak var Event3: UITextField!
    @IBOutlet weak var Event4: UITextField!
    @IBOutlet weak var Event5: UITextField!
    
    @IBOutlet weak var priorityButtons: UISegmentedControl!
    @IBOutlet weak var priorityView: UITextField!
    
    /*
    @IBOutlet weak var Event1Button: UIButton!
    @IBOutlet weak var Event2Button: UIButton!
    @IBOutlet weak var Event3Button: UIButton!
    @IBOutlet weak var Event4Button: UIButton!
    @IBOutlet weak var Event5Button: UIButton!
    */
    
    @IBOutlet weak var Country: UITextField!
    @IBOutlet weak var Genre: UITextField!
    @IBOutlet weak var NoteWorthy: UITextField!

    var bandName :String!
    var schedule = scheduleHandler()
    
    var detailItem: AnyObject? {
        didSet {
            // Update the view.
            self.configureView()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.configureView()
        
        readFile()
        
        splitViewController?.preferredDisplayMode = UISplitViewControllerDisplayMode.AllVisible
        
        if bandName == nil && bands.isEmpty == false {
            var bands = getBandNames()
            bandName = bands[0]
            print("Providing default band of " + bandName)
        }
        
        if (bandName != nil) {
            
            schedule.populateSchedule()
            let imageURL = getBandImageUrl(bandName)
            print("imageUrl: " + imageURL)
            
            //called twice to ensure image is loaded even if delayed
            displayImage(imageURL, bandName: bandName, logoImage: bandLogo)
            sleep(1)
            displayImage(imageURL, bandName: bandName, logoImage: bandLogo)
            
            print ("Priority for bandName " + bandName + " ", terminator: "")
            print(getPriorityData(bandName))
            
            showBandDetails()
            showFullSchedule()
            setButtonNames()
            rotationChecking()
            
        } else {
            bandName = "";
            priorityButtons.hidden = true
            Country.text = ""
            Genre.text = ""
            NoteWorthy.text = ""
            officialUrlButton.hidden = true;
            wikipediaUrlButton.hidden = true;
            youtubeUrlButton.hidden = true;
            metalArchivesButton.hidden = true;
        }
        
        disableButtonsIfNeeded()
        disableLinksWithEmptyData();
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(DetailViewController.rotationChecking), name: UIDeviceOrientationDidChangeNotification, object: nil)
    }
    
    func disableLinksWithEmptyData(){
        
        if (getofficalPage(bandName).isEmpty == true || getofficalPage(bandName) == "Unavailable"){
            officialUrlButton.hidden = true;
            wikipediaUrlButton.hidden = true;
            youtubeUrlButton.hidden = true;
            metalArchivesButton.hidden = true;
        } else {
            print ("Office link is " + getofficalPage(bandName));
        }
    }
 
 
    func showBandDetails(){
 
        if (UIDeviceOrientationIsPortrait(UIDevice.currentDevice().orientation) || UIDevice.currentDevice().userInterfaceIdiom != .Phone){
            
            if (bandCountry[bandName] == nil || bandCountry[bandName]!.isEmpty){
                Country.text = "";
            } else {
                Country.text = "Country:\t" + bandCountry[bandName]!
            
            }

            if (bandGenre[bandName] == nil || bandGenre[bandName]!.isEmpty){
                Genre.text = ""
            
            } else {
                Genre.text = "Genre:\t" + bandGenre[bandName]!
            
            }
    
            if (bandNoteWorthy[bandName] == nil || bandNoteWorthy[bandName]!.isEmpty){
                NoteWorthy.text = ""
            } else {
                NoteWorthy.text = "Note:\t" + bandNoteWorthy[bandName]!
            }
            
        } else if (UIDevice.currentDevice().userInterfaceIdiom == .Phone) {
            Country.text = ""
            Genre.text = ""
            NoteWorthy.text = ""
            
        }
        
        if (bandName.isEmpty) {
            bandName = "";
            priorityButtons.hidden = true
            Country.text = ""
            Genre.text = ""
            NoteWorthy.text = ""
            officialUrlButton.hidden = true;
            wikipediaUrlButton.hidden = true;
            youtubeUrlButton.hidden = true;
            metalArchivesButton.hidden = true;
        }
    }
    
    
    func rotationChecking(){
        
        //need to hide things to make room in the detail display
        if(UIDeviceOrientationIsLandscape(UIDevice.currentDevice().orientation)){
            //if schdule exists, hide the web links that probably dont work anyway
            //only needed on iPhones. iPads have enought room for both
            if (schedule.schedulingData[bandName]?.isEmpty == false && UIDevice.currentDevice().userInterfaceIdiom == .Phone){
                
                officialUrlButton.hidden = true;
                wikipediaUrlButton.hidden = true;
                youtubeUrlButton.hidden = true;
                metalArchivesButton.hidden = true;
                
            }
            
        } else {

            officialUrlButton.hidden = false;
            wikipediaUrlButton.hidden = false;
            youtubeUrlButton.hidden = false;
            metalArchivesButton.hidden = false;
        }
        showBandDetails();
    }
    
    func setButtonNames(){
        
        let MustSee = NSLocalizedString("Must", comment: "A Must See Band")
        let MightSee: String = NSLocalizedString("Might", comment: "A Might See Band")
        let WontSee: String = NSLocalizedString("Wont", comment: "A Wont See Band")
        
        priorityButtons.setTitle(mustSeeIcon + " " + MustSee, forSegmentAtIndex: 1)
        priorityButtons.setTitle(willSeeIcon + " " + MightSee, forSegmentAtIndex: 2)
        priorityButtons.setTitle(willNotSeeIcon + " " + WontSee, forSegmentAtIndex: 3)

        priorityButtons.setTitle(unknownIcon, forSegmentAtIndex: 0)
        
        if (bandPriorityStorage[bandName!] != nil){
            priorityButtons.selectedSegmentIndex = bandPriorityStorage[bandName!]!
        }
    }
    
    @IBAction func setBandPriority() {
        addPriorityData(bandName, priority: priorityButtons.selectedSegmentIndex)
    }
    
    @IBAction func openLink(sender: UIButton) {
        
        var sendToUrl = String()
        
        if (sender.titleLabel?.text == officalSiteButtonName){
           sendToUrl = getofficalPage(bandName)
        
        } else if (sender.titleLabel?.text == wikipediaButtonName){
            sendToUrl = getWikipediaPage(bandName)
        
        } else if (sender.titleLabel?.text == youTubeButtonName){
            sendToUrl = getYouTubePage(bandName)
            
        } else if (sender.titleLabel?.text == metalArchivesButtonName){
            sendToUrl = getMetalArchives(bandName)
            
        }
        
        if (sender.enabled == true){
            splitViewController?.preferredDisplayMode = UISplitViewControllerDisplayMode.PrimaryHidden
            setUrl(sendToUrl)
        }
    }

    func configureView() {
        
        // Update the user interface for the detail item.
        if let detail: AnyObject = self.detailItem {
            if let label = self.titleLable {
                bandName = detail.description
                label.title = bandName
            }
        }
    }
    
    func showFullSchedule () {
    
        if (schedule.schedulingData[bandName]?.isEmpty == false){
            let keyValues = schedule.schedulingData[bandName]!.keys
            let sortedArray = keyValues.sort();
            var count = 1
            
            for index in sortedArray {
                
                let location = schedule.getData(bandName, index:index, variable: "Location")
                let day = schedule.getData(bandName, index: index, variable: "Day")
                let startTime = schedule.getData(bandName, index: index, variable: "Start Time")
                let endTime = schedule.getData(bandName, index: index, variable: "End Time")
                let date = schedule.getData(bandName, index:index, variable: "Date")
                let type = schedule.getData(bandName, index:index, variable: "Type")
                let notes = schedule.getData(bandName, index:index, variable: "Notes")
                let eventIcon = getEventTypeIcon(type)
                
                var scheduleText = String()
                if (!date.isEmpty){
                    scheduleText = day
                    scheduleText += " - " + startTime
                    scheduleText += " - " + endTime
                    scheduleText += " - " + location
                    scheduleText += " - " + type  + " " + eventIcon;
                    
                    if (notes.isEmpty == false){
                        scheduleText += " - " + notes
                    }
                    
                
                    switch count {
                    case 1:
                        Event1.text = scheduleText
                        //Event1Button.hidden = false;
                        
                    case 2:
                        Event2.text = scheduleText
                        //Event2Button.hidden = false;
                        
                    case 3:
                        Event3.text = scheduleText
                        //Event3Button.hidden = false;
                        
                    case 4:
                        Event4.text = scheduleText
                        //Event4Button.hidden = false;
                        
                    case 5:
                        Event5.text = scheduleText
                        //Event5Button.hidden = false;
                        
                    default:
                        print("To many events")
                    }
                   
                    count += 1
                    
                }
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func disableButtonsIfNeeded(){
        
        if (offline == true || bandName == nil){
            print ("Offline is active")
            officialUrlButton.userInteractionEnabled = false
            officialUrlButton.tintColor = UIColor.grayColor()
            
            wikipediaUrlButton.userInteractionEnabled = false
            wikipediaUrlButton.tintColor = UIColor.grayColor()
            
            youtubeUrlButton.userInteractionEnabled = false
            youtubeUrlButton.tintColor = UIColor.grayColor()
            
            metalArchivesButton.userInteractionEnabled = false
            metalArchivesButton.tintColor = UIColor.grayColor()

        }

    }
    
    @IBAction func wentToShowToggle(sender: UIButton) {
        
        if (sender.titleLabel?.text == "⬜️"){
            sender.setTitle("☑️", forState: UIControlState.Normal);
            
        } else {
           sender.setTitle("⬜️", forState: UIControlState.Normal);
        }
        
        
        
    }
    
}


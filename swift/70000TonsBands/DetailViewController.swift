//
//  DetailViewController.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/2/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import UIKit

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
            println("Providing default band of " + bandName)
        }
        
        if bandName != nil {
            
            schedule.populateSchedule()
            var imageURL = getBandImageUrl(bandName)
            println("imageUrl: " + imageURL)
            displayImage(imageURL, bandName, bandLogo)
            
            
            print ("Priority for bandName " + bandName + " ")
            println(getPriorityData(bandName))
            
            showFullSchedule()
            setButtonNames()
            rotationChecking()
            
        } else {
            priorityButtons.hidden = true
        }
        
        disableButtonsIfNeeded()
        
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "rotationChecking", name: UIDeviceOrientationDidChangeNotification, object: nil)
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
    }
    
    func setButtonNames(){
        
        var MustSee = NSLocalizedString("Must", comment: "A Must See Band")
        var MightSee: String = NSLocalizedString("Might", comment: "A Might See Band")
        var WontSee: String = NSLocalizedString("Wont", comment: "A Wont See Band")
        
        priorityButtons.setTitle(mustSeeIcon + " " + MustSee, forSegmentAtIndex: 1)
        priorityButtons.setTitle(willSeeIcon + " " + MightSee, forSegmentAtIndex: 2)
        priorityButtons.setTitle(willNotSeeIcon + " " + WontSee, forSegmentAtIndex: 3)

        priorityButtons.setTitle(unknownIcon, forSegmentAtIndex: 0)
        
        if (bandPriorityStorage[bandName!] != nil){
            priorityButtons.selectedSegmentIndex = bandPriorityStorage[bandName!]!
        }
    }
    
    @IBAction func setBandPriority() {
        addPriorityData(bandName, priorityButtons.selectedSegmentIndex)
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
            setUrl(sendToUrl)
            splitViewController?.preferredDisplayMode = UISplitViewControllerDisplayMode.PrimaryHidden
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
            var keyValues = schedule.schedulingData[bandName]!.keys
            var arrayValues = keyValues.array
            var sortedArray = sorted(arrayValues, {
                $0 < $1
            })
            
            var count = 1
            for index in sortedArray {
                
                var location = schedule.getData(bandName, index:index.0, variable: "Location")
                var day = schedule.getData(bandName, index: index.0, variable: "Day")
                var startTime = schedule.getData(bandName, index: index.0, variable: "Start Time")
                var endTime = schedule.getData(bandName, index: index.0, variable: "End Time")
                var date = schedule.getData(bandName, index:index.0, variable: "Date")
                var type = schedule.getData(bandName, index:index.0, variable: "Type")
                var notes = schedule.getData(bandName, index:index.0, variable: "Notes")
                
                var scheduleText = String()
                if (!date.isEmpty){
                    scheduleText = day
                    scheduleText += " - " + startTime
                    scheduleText += " - " + endTime
                    scheduleText += " - " + location
                    scheduleText += " - " + type
                    
                    if (notes.isEmpty == false){
                        scheduleText += " - " + notes
                    }
                    
                    switch count {
                    case 1:
                        Event1.text = scheduleText
                        
                    case 2:
                        Event2.text = scheduleText
                        
                    case 3:
                        Event3.text = scheduleText
                        
                    case 4:
                        Event4.text = scheduleText
                        
                    case 5:
                        Event5.text = scheduleText
                        
                    default:
                        println("To many events")
                    }
                    count++
                    
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
}


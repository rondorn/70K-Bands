//
//  DetailViewController.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/2/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import UIKit
import CoreData

class DetailViewController: UIViewController, UITextViewDelegate{
    
    @IBOutlet weak var titleLable: UINavigationItem!
    @IBOutlet weak var bandLogo: UIImageView!
    @IBOutlet weak var officialUrlButton: UIButton!
    @IBOutlet weak var wikipediaUrlButton: UIButton!
    @IBOutlet weak var youtubeUrlButton: UIButton!
    @IBOutlet weak var metalArchivesButton: UIButton!
    
    @IBOutlet weak var customNotesButton: UIButton!
    @IBOutlet weak var customNotesText: UITextView!
    
    
    
    @IBOutlet weak var returnToMaster: UINavigationItem!
    
    @IBOutlet weak var Event1: UITextField!
    @IBOutlet weak var Event2: UITextField!
    @IBOutlet weak var Event3: UITextField!
    @IBOutlet weak var Event4: UITextField!
    @IBOutlet weak var Event5: UITextField!
    
    @IBOutlet weak var priorityButtons: UISegmentedControl!
    @IBOutlet weak var priorityView: UITextField!
        
    @IBOutlet weak var Country: UITextField!
    @IBOutlet weak var Genre: UITextField!
    @IBOutlet weak var NoteWorthy: UITextField!
    
    var bandName :String!
    var schedule = scheduleHandler()
    var imagePosition = CGFloat(0);
    
    var detailItem: AnyObject? {
        didSet {
            // Update the view.
            self.configureView()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.configureView()
        
        //splitViewController?.preferredDisplayMode = UISplitViewControllerDisplayMode.allVisible
        
        customNotesText.delegate = self as? UITextViewDelegate
        
        readFile()
        
        if (bandName == nil || bands.isEmpty == true) {
            var bands = getBandNames()
            bandName = bands[0]
            print("Providing default band of " + bandName)
        }
        
        print ("bandName is " + bandName)

        if (bandName != nil && bandName.isEmpty == false && bandName != "None") {
            
            let imageURL = getBandImageUrl(bandName)
            print("imageUrl: " + imageURL)
            
            //called twice to ensure image is loaded even if delayed
            displayImage(urlString: imageURL, bandName: bandName, logoImage: bandLogo)
            sleep(1)
            displayImage(urlString: imageURL, bandName: bandName, logoImage: bandLogo)
            
            print ("Priority for bandName " + bandName + " ", terminator: "")
            print(getPriorityData(bandName))
            
            print ("showBandDetails");
            showBandDetails()
            
            print ("showFullSchedule");
            showFullSchedule()
            setButtonNames()
            rotationChecking()
            loadComments()
            
            print ("Checking button status:" + bandName)
            disableButtonsIfNeeded()
            disableLinksWithEmptyData();
            
            NotificationCenter.default.addObserver(self, selector: #selector(DetailViewController.rotationChecking), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
            
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        customNotesText.scrollRangeToVisible(NSRange(location:0, length:0))
        
    }
    
    func disableLinksWithEmptyData(){
        
        if (getofficalPage(bandName).isEmpty == true || getofficalPage(bandName) == "Unavailable"){
            officialUrlButton.isHidden = true;
            wikipediaUrlButton.isHidden = true;
            youtubeUrlButton.isHidden = true;
            metalArchivesButton.isHidden = true;
            
        }
    }
  
    func showBandDetails(){
 
        if (UIDeviceOrientationIsLandscape(UIDevice.current.orientation) == false || UIDevice.current.userInterfaceIdiom == .pad){
            
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
            
        } else if (UIDevice.current.userInterfaceIdiom == .phone) {
            Country.text = ""
            Genre.text = ""
            NoteWorthy.text = ""
        }
        
        if (bandName.isEmpty) {
            bandName = "";
            priorityButtons.isHidden = true
            Country.text = ""
            Genre.text = ""
            NoteWorthy.text = ""
            officialUrlButton.isHidden = true;
            wikipediaUrlButton.isHidden = true;
            youtubeUrlButton.isHidden = true;
            metalArchivesButton.isHidden = true;
            customNotesText.isHidden = true;
            customNotesButton.isHidden = true;
            
            officialUrlButton.isEnabled = false;
            wikipediaUrlButton.isEnabled = false;
            youtubeUrlButton.isEnabled = false;
            metalArchivesButton.isEnabled = false;
        }
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        print ("Editing of commentFile has begun")
        if (customNotesText.text == "Add your custom notes here"){
            customNotesText.text = ""
            customNotesText.textColor = UIColor.black
        }
    }
    

    func loadComments(){
        let commentFile = directoryPath.appendingPathComponent( bandName + "_comment.txt")
        print ("Loading commentFile");
        if let data = try? String(contentsOf: commentFile, encoding: String.Encoding.utf8) {
            if (data.isEmpty == false){
                customNotesText.text = data;
                customNotesText.textColor = UIColor.black
                
            } else {
                print ("Nothing in commentFile");
            }
        } else {
           customNotesText.text = "Add your custom notes here";
           customNotesText.textColor = UIColor.gray
           print ("commentFile does not exist");
        }

    }
    
    func saveComments(){
        if (bandName != nil && bandName.isEmpty == false){
            let commentFile = directoryPath.appendingPathComponent( bandName + "_comment.txt")
            if (customNotesText.text != "Add your custom notes here"){
                print ("saving commentFile");
                DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                    //DispatchQueue.global(priority: Int(DispatchQoS.QoSClass.background.rawValue)).async {
                    var commentString = self.customNotesText.text;
                
                    print ("Wrote commentFile " + commentString!)

                    do {
                        try commentString?.write(to: commentFile, atomically: false, encoding: String.Encoding.utf8)
                    } catch {
                        print("commentFile " + error.localizedDescription)
                    }
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated : Bool) {
        super.viewWillDisappear(animated)
        saveComments()
    }
    
    func rotationChecking(){
        
        //need to hide things to make room in the detail display
        if(UIDeviceOrientationIsLandscape(UIDevice.current.orientation)){
            //if schdule exists, hide the web links that probably dont work anyway
            //only needed on iPhones. iPads have enought room for both
            if (schedule.schedulingData[bandName]?.isEmpty == false && UIDevice.current.userInterfaceIdiom == .phone){
                
                officialUrlButton.isHidden = true;
                wikipediaUrlButton.isHidden = true;
                youtubeUrlButton.isHidden = true;
                metalArchivesButton.isHidden = true;
                customNotesText.isHidden = true;
                customNotesButton.isHidden = true;
            }
            bandLogo.contentMode = UIViewContentMode.top
            priorityButtons.contentPositionAdjustment(forSegmentType: <#T##UISegmentedControlSegment#>, barMetrics: <#T##UIBarMetrics#>)
            
        } else {

            officialUrlButton.isHidden = false;
            wikipediaUrlButton.isHidden = false;
            youtubeUrlButton.isHidden = false;
            metalArchivesButton.isHidden = false;
            customNotesText.isHidden = false;
            customNotesButton.isHidden = false;
            bandLogo.contentMode = UIViewContentMode.scaleAspectFit
        }

        showBandDetails();
    }
    
    func setButtonNames(){
        
        let MustSee = NSLocalizedString("Must", comment: "A Must See Band")
        let MightSee: String = NSLocalizedString("Might", comment: "A Might See Band")
        let WontSee: String = NSLocalizedString("Wont", comment: "A Wont See Band")
        
        priorityButtons.setTitle(mustSeeIcon + " " + MustSee, forSegmentAt: 1)
        priorityButtons.setTitle(willSeeIcon + " " + MightSee, forSegmentAt: 2)
        priorityButtons.setTitle(willNotSeeIcon + " " + WontSee, forSegmentAt: 3)

        priorityButtons.setTitle(unknownIcon, forSegmentAt: 0)
        
        if (bandPriorityStorage[bandName!] != nil){
            priorityButtons.selectedSegmentIndex = bandPriorityStorage[bandName!]!
        }
    }
    
    @IBAction func setBandPriority() {
        if (bandName != nil){
            addPriorityData(bandName, priority: priorityButtons.selectedSegmentIndex)
        }
    }
    
    @IBAction func openLink(_ sender: UIButton) {
        
        var sendToUrl = String()
        
        if (bandName != nil){
            if (sender.titleLabel?.text == officalSiteButtonName){
               sendToUrl = getofficalPage(bandName)
            
            } else if (sender.titleLabel?.text == wikipediaButtonName){
                sendToUrl = getWikipediaPage(bandName)
            
            } else if (sender.titleLabel?.text == youTubeButtonName){
                sendToUrl = getYouTubePage(bandName)
                
            } else if (sender.titleLabel?.text == metalArchivesButtonName){
                sendToUrl = getMetalArchives(bandName)
                
            }
            
            if (sender.isEnabled == true){
                splitViewController?.preferredDisplayMode = UISplitViewControllerDisplayMode.primaryHidden
                setUrl(sendToUrl)
            }
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
        
        schedule.populateSchedule()
        
        if (schedule.schedulingData[bandName]?.isEmpty == false){
            let keyValues = schedule.schedulingData[bandName]!.keys
            let sortedArray = keyValues.sorted();
            var count = 1
            
            schedule.buildTimeSortedSchedulingData();
            
            for index in sortedArray {
                
                let location = schedule.getData(bandName, index:index, variable: locationField)
                let day = schedule.getData(bandName, index: index, variable: "Day")
                let startTime = schedule.getData(bandName, index: index, variable: "Start Time")
                let endTime = schedule.getData(bandName, index: index, variable: "End Time")
                let date = schedule.getData(bandName, index:index, variable: "Date")
                let type = schedule.getData(bandName, index:index, variable: "Type")
                let notes = schedule.getData(bandName, index:index, variable: "Notes")
                
                var scheduleText = String()
                if (!date.isEmpty){
                    scheduleText = day
                    scheduleText += " - " + startTime
                    scheduleText += " - " + endTime
                    scheduleText += " - " + location + getVenuIcon(location)
                    scheduleText += " - " + type  + " " + getEventTypeIcon(type);
                    
                    if (notes.isEmpty == false && notes != " "){
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
        
        print ("Checking button status " + bandName)
        if (offline == true || bandName == nil){
            print ("Offline is active")
            officialUrlButton.isUserInteractionEnabled = false
            officialUrlButton.tintColor = UIColor.gray
            
            wikipediaUrlButton.isUserInteractionEnabled = false
            wikipediaUrlButton.tintColor = UIColor.gray
            
            youtubeUrlButton.isUserInteractionEnabled = false
            youtubeUrlButton.tintColor = UIColor.gray
            
            metalArchivesButton.isUserInteractionEnabled = false
            metalArchivesButton.tintColor = UIColor.gray

        }

    }
    
    @IBAction func wentToShowToggle(_ sender: UIButton) {
        
        if (sender.titleLabel?.text == "⬜️"){
            sender.setTitle("☑️", for: UIControlState());
            
        } else {
           sender.setTitle("⬜️", for: UIControlState());
        }
        
        
        
    }
    
}

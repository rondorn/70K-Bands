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
    
    @IBOutlet weak var Links: UIView!
    @IBOutlet weak var notesSection: UIView!

    @IBOutlet weak var extraData: UIView!
    @IBOutlet weak var eventView: UIView!
    
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
        
        customNotesText.delegate = self as? UITextViewDelegate
        
        readFile()
        
        if (bandName == nil || bands.isEmpty == true) {
            var bands = getBandNames()
            bandName = bands[bandListIndexCache]
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
            
            print ("Checking button status:" + bandName)
            disableButtonsIfNeeded()
            disableLinksWithEmptyData();
            
            NotificationCenter.default.addObserver(self, selector: #selector(DetailViewController.rotationChecking), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
            
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?){
        notesSection.endEditing(true)
        super.touchesBegan(touches, with: event)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        splitViewController?.preferredDisplayMode = UISplitViewControllerDisplayMode.allVisible
        loadComments()
        super.viewDidAppear(animated)
        
    }
    
    
    func disableLinksWithEmptyData(){
        
        print ("getofficalPage(bandName) is " + getofficalPage(bandName) )
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
                Country.isHidden = true
            } else {
                Country.text = "Country:\t" + bandCountry[bandName]!
                Country.isHidden = false
            }

            if (bandGenre[bandName] == nil || bandGenre[bandName]!.isEmpty){
                Genre.text = ""
                Genre.isHidden = true
            
            } else {
                Genre.text = "Genre:\t" + bandGenre[bandName]!
                Genre.isHidden = false
            
            }
    
            if (bandNoteWorthy[bandName] == nil || bandNoteWorthy[bandName]!.isEmpty){
                NoteWorthy.text = ""
                NoteWorthy.isHidden = true
            } else {
                NoteWorthy.text = "Note:\t" + bandNoteWorthy[bandName]!
                NoteWorthy.isHidden = false
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
        
        customNotesText.text = bandNotes.getDescription(bandName: bandName)
        customNotesText.textColor = UIColor.black
        setNotesHeight()
    }
    
    func saveComments(){
        
        if (bandName != nil && bandName.isEmpty == false){
            let commentFile = directoryPath.appendingPathComponent( bandName + "_comment.txt")
            if (customNotesText.text.starts(with: "Comment text is not available yet") == true){
                    removeBadNote(commentFile: commentFile)
                
            } else if (customNotesText.text.characters.count < 2){
                removeBadNote(commentFile: commentFile)

            } else {
                print ("saving commentFile");
                
                DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                    let commentString = self.customNotesText.text;
                    print ("Writting commentFile " + commentString!)

                    do {
                        try commentString?.write(to: commentFile, atomically: false, encoding: String.Encoding.utf8)
                    } catch {
                        print("commentFile " + error.localizedDescription)
                    }
                }
            }

        }
    }
    
    func removeBadNote(commentFile: URL){
        do {
            print ("commentFile being deleted")
            try FileManager.default.removeItem(atPath: commentFile.path)
            
        } catch let error as NSError {
            print ("Encountered an error removing old commentFile " + error.debugDescription)
        }
        
        if (FileManager.default.fileExists(atPath: commentFile.path) == true){
            print ("ERROR: commentFile was not deleted")
        } else {
            print ("CONFIRMATION: commentFile was deleted")
            loadComments()
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
                
                Links.isHidden = true
                Links.sizeToFit()
            
            }
            
            if (UIDevice.current.userInterfaceIdiom == .phone){
                extraData.isHidden = true
                extraData.sizeToFit()
                
                notesSection.isHidden = true
                customNotesText.text = "";
                setNotesHeight()
            }
            
            bandLogo.contentMode = UIViewContentMode.top
            bandLogo.sizeToFit()
            
            
        } else {

            if (UIDevice.current.userInterfaceIdiom == .phone){
                Links.isHidden = false
                extraData.isHidden = false
                notesSection.isHidden = false
                
                Links.sizeToFit()
                extraData.sizeToFit()
                loadComments()
            }
            
            bandLogo.contentMode = UIViewContentMode.scaleAspectFit
            bandLogo.sizeToFit()
        }

        showBandDetails();
    }
    
    func setNotesHeight(){

        customNotesText.scrollRangeToVisible(NSRange(location:0, length:0))

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
        
        print ("This should open up the link to " + (sender.titleLabel?.text)!);
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
                let day = schedule.getData(bandName, index: index, variable: dayField)
                var startTime = schedule.getData(bandName, index: index, variable: startTimeField)
                var endTime = schedule.getData(bandName, index: index, variable: endTimeField)
                let date = schedule.getData(bandName, index:index, variable: dateField)
                let type = schedule.getData(bandName, index:index, variable: typeField)
                let notes = schedule.getData(bandName, index:index, variable: notesField)
                
                startTime = formatTimeValue(timeValue: startTime)
                endTime = formatTimeValue(timeValue: endTime)
                
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
        hideEmptyData();
    }
    
    func hideEmptyData() {
        if (Event1.text?.isEmpty)!{
            Event1.isHidden = true;
        } else {
            Event1.isHidden = false;
        }
        if (Event2.text?.isEmpty)!{
            Event2.isHidden = true;
        } else {
            Event2.isHidden = false;
        }
        if (Event3.text?.isEmpty)!{
            Event3.isHidden = true;
        } else {
            Event3.isHidden = false;
        }
        if (Event4.text?.isEmpty)!{
            Event4.isHidden = true;
        } else {
            Event4.isHidden = false;
        }
        if (Event5.text?.isEmpty)!{
            Event5.isHidden = true;
        } else {
            Event5.isHidden = false;
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
    
    @IBAction func clickedOnEvent(_ sender: UITextField) {
        
        let fieldText = sender.text;
        sender.backgroundColor = UIColor.blue
        let message = "I saw " + bandName + " on " + fieldText!;
        
        showToast(message: message);
        print ("User clicked on an event \(bandName) \(fieldText)");

        //var showsAtten = ShowsAttended();
        
        //showsAtten.addShowsAttended();
        //showsAttendedShowAttendedTracker.addShowsAttended();
        
    }
    
    func showToast(message : String) {
        
        let toastLabel = UILabel(frame: CGRect(x: 10, y: self.view.frame.size.height-250, width: self.view.frame.size.width - 10, height: 45))
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        toastLabel.textColor = UIColor.white
        toastLabel.textAlignment = .center;
        toastLabel.font = UIFont(name: "Montserrat-Light", size: 12.0)
        toastLabel.text = message
        toastLabel.alpha = 1.0
        toastLabel.layer.cornerRadius = 10;
        toastLabel.clipsToBounds  =  true
        self.view.addSubview(toastLabel)
        UIView.animate(withDuration: 4.0, delay: 0.1, options: .curveEaseOut, animations: {
            toastLabel.alpha = 0.0
        }, completion: {(isCompleted) in
            toastLabel.removeFromSuperview()
        })
    }

}

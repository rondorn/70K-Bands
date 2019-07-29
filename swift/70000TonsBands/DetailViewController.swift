//
//  DetailViewController.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/2/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import UIKit
import CoreData

class DetailViewController: UIViewController, UITextViewDelegate, UITextFieldDelegate{
    
    
    
    @IBOutlet weak var linkGroup: UIStackView!
    
    @IBOutlet weak var titleLable: UINavigationItem!
    @IBOutlet weak var bandLogo: UIImageView!

    @IBOutlet weak var LinksSection: UIView!
    @IBOutlet weak var vistLinksLable: UILabel!
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
    
    
    @IBOutlet weak var Event1AttendedIcon: UIImageView!
    @IBOutlet weak var Event2AttendedIcon: UIImageView!
    @IBOutlet weak var Event3AttendedIcon: UIImageView!
    @IBOutlet weak var Event4AttendedIcon: UIImageView!
    @IBOutlet weak var Event5AttendedIcon: UIImageView!
    
    @IBOutlet weak var Event1TypeIcon: UIImageView!
    @IBOutlet weak var Event2TypeIcon: UIImageView!
    @IBOutlet weak var Event3TypeIcon: UIImageView!
    @IBOutlet weak var Event4TypeIcon: UIImageView!
    @IBOutlet weak var Event5TypeIcon: UIImageView!
    
    @IBOutlet weak var Event1: UITextField!
    @IBOutlet weak var Event2: UITextField!
    @IBOutlet weak var Event3: UITextField!
    @IBOutlet weak var Event4: UITextField!
    @IBOutlet weak var Event5: UITextField!
    
    @IBOutlet weak var PriorityIcon: UIImageView!
    @IBOutlet weak var priorityButtons: UISegmentedControl!
    @IBOutlet weak var priorityView: UITextField!
    
    @IBOutlet weak var Country: UITextField!
    @IBOutlet weak var Genre: UITextField!
    @IBOutlet weak var NoteWorthy: UITextField!
    
    var backgroundNotesText = "";
    var bandName :String!
    var schedule = scheduleHandler()
    var bandNameHandle = bandNamesHandler()
    let attendedHandle = ShowsAttended()
    let dataHandle = dataHandler()
    var bandPriorityStorage = [String:Int]()
    let bandNotes = CustomBandDescription();
    
    var imagePosition = CGFloat(0);
    
    var eventCount = 0;
    var displayedImaged:UIImage?
    
    var scheduleIndex : [String:[String:String]] = [String:[String:String]]()

    var detailItem: AnyObject? {
        didSet {
            // Update the view.
            self.configureView()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.configureView()
        
        self.navigationController?.navigationBar.barStyle = UIBarStyle.blackTranslucent
        self.navigationController?.navigationBar.tintColor = UIColor.white
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.white]
        
        customNotesText.textColor = UIColor.white
        
        bandPriorityStorage = dataHandle.readFile(dateWinnerPassed: "")
        
        if (bandName == nil && bandSelected.isEmpty == false){
            bandName = bandSelected
        }
        
        if (bandName == nil || bands.isEmpty == true) {
            var bands = bandNameHandle.getBandNames()
            print ("bands discovered are \(bands)")
            bandName = bands[0]
            print("Providing default band of " + bandName)
        }
        
        print ("bandName is " + bandName)
        
        if (bandName != nil && bandName.isEmpty == false && bandName != "None") {
            
            let imageURL = self.bandNameHandle.getBandImageUrl(self.bandName)
            print ("urlString is - Sending imageURL of \(imageURL) for band \(String(describing: bandName))")
            
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                
                let imageHandle = imageHandler()
                
                self.displayedImaged = imageHandle.displayImage(urlString: imageURL, bandName: self.bandName)
                DispatchQueue.main.async {
                    // Calculate the biggest size that fixes in the given CGSize
                    self.bandLogo.image = self.displayedImaged
                    self.imageSizeController(special: "")
                }
            }
            
            print ("Priority for bandName " + bandName + " ", terminator: "")
            print(dataHandle.getPriorityData(bandName))
            
            print ("showFullSchedule");
            showFullSchedule()
            setButtonNames()
            rotationChecking()
            
            print ("showBandDetails");
            showBandDetails()
            
            print ("Checking button status:" + bandName)
            disableButtonsIfNeeded()
            disableLinksWithEmptyData();
            
            //used to disable keyboard input for these fields
            self.Event1.delegate = self
            self.Event2.delegate = self
            self.Event3.delegate = self
            self.Event4.delegate = self
            self.Event5.delegate = self
            
            NotificationCenter.default.addObserver(self, selector: #selector(DetailViewController.rotationChecking), name: UIDevice.orientationDidChangeNotification, object: nil)
            
        }
        
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    //used to disable keyboard input for event fields
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        print ("Started editing");
        return false
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?){
        print ("Ended editing");
        notesSection.endEditing(true)
        super.touchesBegan(touches, with: event)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        splitViewController?.preferredDisplayMode = UISplitViewController.DisplayMode.allVisible
        loadComments()
        super.viewDidAppear(animated)
        
    }
    
    func imageSizeController(special: String){
        
        if (officialUrlButton.isHidden == false){
            if (special == "top"){
                self.bandLogo.contentMode = UIView.ContentMode.top
                self.bandLogo.contentMode = UIView.ContentMode.scaleAspectFit
            } else if (special == "scale"){
                 self.bandLogo.contentMode = UIView.ContentMode.top
                 self.bandLogo.contentMode = UIView.ContentMode.scaleAspectFit
            }
            self.bandLogo.sizeToFit()
        } else {
            self.customNotesText.textContainerInset = UIEdgeInsets(top: 50, left: 0, bottom: 5, right: 0)
            self.bandLogo.contentMode = UIView.ContentMode.top
            self.bandLogo.sizeToFit()
        }
        
        if (eventCount <= 1){
            let screenSize = UIScreen.main.bounds
            customNotesText.frame.size.height = screenSize.height * 0.57
        }
    }
    
    func disableLinksWithEmptyData(){
        
        if (bandNameHandle.getofficalPage(bandName).isEmpty == true || bandNameHandle.getofficalPage(bandName) == "Unavailable"){
            officialUrlButton.isHidden = true;
            wikipediaUrlButton.isHidden = true;
            youtubeUrlButton.isHidden = true;
            metalArchivesButton.isHidden = true;
            linkGroup.isHidden = true
            vistLinksLable.isHidden = true;
            LinksSection.isHidden = true;
        }
    }
  
    func showBandDetails(){
        
        if (UIApplication.shared.statusBarOrientation  == .portrait ||
            UIDevice.current.userInterfaceIdiom == .pad){
            
            let bandCountry = bandNameHandle.getBandCountry(bandName)
            print ("Band County is \(bandCountry)")
            if (bandCountry.isEmpty == true){
                Country.text = "";
                Country.isHidden = true
                extraData.isHidden = true
            } else {
                Country.text = "Country:\t" + bandCountry
                Country.isHidden = false
            }
            
            let bandGenre = bandNameHandle.getBandGenre(bandName)
            if (bandGenre.isEmpty == true){
                Genre.text = ""
                Genre.isHidden = true
            
            } else {
                Genre.text = "Genre:\t" + bandGenre
                Genre.isHidden = false
            
            }
            
            let bandNoteWorthy = bandNameHandle.getBandNoteWorthy(bandName)
            if (bandNoteWorthy.isEmpty == true){
                NoteWorthy.text = ""
                NoteWorthy.isHidden = true
            } else {
                NoteWorthy.text = "Note:\t" + bandNoteWorthy
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
            vistLinksLable.isHidden = true;
            LinksSection.isHidden = true;
            
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
            customNotesText.textColor = UIColor.white
        }
        
    }
    

    func loadComments(){
        customNotesText.text = bandNotes.getDescription(bandName: bandName)
        customNotesText.textColor = UIColor.white
        setNotesHeight()
    }
    
    func saveComments(){
        
        if (bandName != nil && bandName.isEmpty == false){
            let commentFile = directoryPath.appendingPathComponent( bandName + "_comment.txt")
            if (customNotesText.text.starts(with: "Comment text is not available yet") == true){
                    removeBadNote(commentFile: commentFile)
                
            } else if (customNotesText.text.count < 2){
                removeBadNote(commentFile: commentFile)

            } else {
                print ("saving commentFile");
                
                let commentString = self.customNotesText.text;
                DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
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
            print ("commentFile being deleted \(commentFile)")
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
    
    @objc func rotationChecking(){
        
        //need to hide things to make room in the detail display
        if(UIApplication.shared.statusBarOrientation  == .landscapeLeft || UIApplication.shared.statusBarOrientation  == .landscapeRight){
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
            
            imageSizeController(special: "top")
            
            
        } else {

            if (UIDevice.current.userInterfaceIdiom == .phone){
                Links.isHidden = false
                extraData.isHidden = false
                notesSection.isHidden = false
                
                Links.sizeToFit()
                extraData.sizeToFit()
                loadComments()
            }
            
            imageSizeController(special: "scale")
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
        
        priorityButtons.setTitle(MustSee, forSegmentAt: 1)
        priorityButtons.setTitle(MightSee, forSegmentAt: 2)
        priorityButtons.setTitle(WontSee, forSegmentAt: 3)

        priorityButtons.setTitle("Unknown", forSegmentAt: 0)
        
        if (bandPriorityStorage[bandName!] != nil){
            priorityButtons.selectedSegmentIndex = bandPriorityStorage[bandName!]!
            let priorityImageName = getPriorityGraphic(bandPriorityStorage[bandName!]!)
            PriorityIcon.image = UIImage(named: priorityImageName) ?? UIImage()
        }
    }
    
    @IBAction func setBandPriority() {
        if (bandName != nil){
            dataHandle.addPriorityData(bandName, priority: priorityButtons.selectedSegmentIndex)
            
            let priorityImageName = getPriorityGraphic(priorityButtons.selectedSegmentIndex)
            PriorityIcon.image = UIImage(named: priorityImageName) ?? UIImage()
        }
    }
    
    @IBAction func openLink(_ sender: UIButton) {
        
        
        var sendToUrl = String()

        if (bandName != nil){
            if (sender.accessibilityIdentifier == officalSiteButtonName){
               webMessageHelp = NSLocalizedString("officialWebSiteLinkHelp", comment: "officialWebSiteLinkHelp")
               sendToUrl = bandNameHandle.getofficalPage(bandName)
            
            } else if (sender.accessibilityIdentifier == wikipediaButtonName){
                webMessageHelp = NSLocalizedString("WikipediaLinkHelp", comment: "WikipediaLinkHelp")
                sendToUrl = bandNameHandle.getWikipediaPage(bandName)
            
            } else if (sender.accessibilityIdentifier == youTubeButtonName){
                webMessageHelp = NSLocalizedString("YouTubeLinkHelp", comment: "YouTubeLinkHelp")
                sendToUrl = bandNameHandle.getYouTubePage(bandName)
                
            } else if (sender.accessibilityIdentifier == metalArchivesButtonName){
                webMessageHelp = NSLocalizedString("MetalArchiveLinkHelp", comment: "MetalArchiveLinkHelp")
                sendToUrl = bandNameHandle.getMetalArchives(bandName)
                
            }
            
            if (sender.isEnabled == true && sendToUrl.isEmpty == false){
                splitViewController?.preferredDisplayMode = UISplitViewController.DisplayMode.primaryHidden
                setUrl(sendToUrl)
            }
        }
    }
    
    func configureView() {
        
        bandName = self.detailItem?.description
        
        // Update the user interface for the detail item.
        if let detail: AnyObject = self.detailItem {
            if let label = self.titleLable {
                print ("determining detail bandName \(detail) - \(label) - \(String(describing: detail.description))")
                bandName = detail.description
                label.title = bandName
            }
        }
    }
    
    func showFullSchedule () {
        
        schedule.getCachedData()
        scheduleQueue.sync {
            if (schedule.schedulingData[bandName]?.isEmpty == false){
                
                let keyValues = schedule.schedulingData[bandName]!.keys
                let sortedArray = keyValues.sorted();
                var count = 1
                eventCount = keyValues.count;
                if (eventCount == 1){
                    count = 4;
                }
                schedule.buildTimeSortedSchedulingData();
                
                for index in sortedArray {
                    
                    let location = schedule.getData(bandName, index:index, variable: locationField)
                    let day = schedule.getData(bandName, index: index, variable: dayField)
                    var startTime = schedule.getData(bandName, index: index, variable: startTimeField)
                    var endTime = schedule.getData(bandName, index: index, variable: endTimeField)
                    let date = schedule.getData(bandName, index:index, variable: dateField)
                    let type = schedule.getData(bandName, index:index, variable: typeField)
                    let notes = schedule.getData(bandName, index:index, variable: notesField)
                    let scheduleDescriptionUrl = schedule.getData(bandName, index:index, variable: descriptionUrlField)
                    
                    if (scheduleDescriptionUrl.isEmpty == false && scheduleDescriptionUrl.count > 3){
                        print ("Loading customNotesTest from URL")
                        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                            self.backgroundNotesText = self.bandNotes.getDescriptionFromUrl(bandName: self.bandName, descriptionUrl: scheduleDescriptionUrl)
                            
                            DispatchQueue.main.async {
                                self.customNotesText.text = self.backgroundNotesText;
                            }
                        }
                        
                        
                    }
                    
                    let rawStartTime = startTime
                    
                    startTime = formatTimeValue(timeValue: startTime)
                    endTime = formatTimeValue(timeValue: endTime)
                    
                    var scheduleText = String()
                    if (!date.isEmpty){
                        scheduleText = day
                        scheduleText += " - " + startTime
                        scheduleText += " - " + endTime
                        scheduleText += " - " + location + getVenuIcon(location)
                        scheduleText += " - " + type
                        
                        if (notes.isEmpty == false && notes != " "){
                            scheduleText += " - " + notes
                        }
                        
                        scheduleIndex[scheduleText] = [String:String]()
                    
                        scheduleIndex[scheduleText]!["bandName"] = bandName;
                        scheduleIndex[scheduleText]!["location"] = location;
                        scheduleIndex[scheduleText]!["startTime"] = rawStartTime;
                        scheduleIndex[scheduleText]!["eventType"] = type;
                        
                        let status = attendedHandle.getShowAttendedStatus(band: bandName, location: location, startTime: rawStartTime, eventType: type, eventYearString: String(eventYear));
                        
                        print ("Show Attended Load \(status) - \(location) - \(startTime) - \(type)")
                        switch count {
                        case 1:
                            Event1.text = scheduleText
                            _ = attendedHandle.setShowsAttendedStatus(Event1,status: status);
                            Event1AttendedIcon.image = getAttendedIcons(attendedStatus: status)
                            Event1TypeIcon.image = getEventTypeIcon(type)
                            
                        case 2:
                            Event2.text = scheduleText
                            _ = attendedHandle.setShowsAttendedStatus(Event2,status: status);
                            Event2AttendedIcon.image = getAttendedIcons(attendedStatus: status)
                            Event2TypeIcon.image = getEventTypeIcon(type)
                            
                        case 3:
                            Event3.text = scheduleText
                            _ = attendedHandle.setShowsAttendedStatus(Event3,status: status);
                            Event3AttendedIcon.image = getAttendedIcons(attendedStatus: status)
                            Event3TypeIcon.image = getEventTypeIcon(type)
                            
                        case 4:
                            Event4.text = scheduleText
                            _ = attendedHandle.setShowsAttendedStatus(Event4,status: status);
                            Event4AttendedIcon.image = getAttendedIcons(attendedStatus: status)
                            Event4TypeIcon.image = getEventTypeIcon(type)
                            
                        case 5:
                            Event5.text = scheduleText
                            _ = attendedHandle.setShowsAttendedStatus(Event5,status: status);
                            Event5AttendedIcon.image = getAttendedIcons(attendedStatus: status)
                            Event5TypeIcon.image = getEventTypeIcon(type)
                            
                        default:
                            print("To many events")
                        }
                       
                        count += 1
                        
                    }
                }
            }
            hideEmptyData();
        }
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
        
        var offline = true
        
        if Reachability.isConnectedToNetwork(){
            offline = false;
        }
        
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
    
    @IBAction func noteButtonClick(_ sender: Any) {
        print ("Clicked the notes button")
        let screenSize = UIScreen.main.bounds
        customNotesText.frame.size.height = screenSize.height
    }
    
    @IBAction func clickedOnEvent(_ sender: UITextField) {
        
        sender.resignFirstResponder()
        let scheduleText = attendedHandle.removeIcons(text: sender.text!);
        
        print ("scheduleIndex = \(scheduleText)")
        let location = scheduleIndex[scheduleText]!["location"]
        let startTime = scheduleIndex[scheduleText]!["startTime"]
        let eventType = scheduleIndex[scheduleText]!["eventType"]
        
        let status = attendedHandle.addShowsAttended(band: bandName, location: location!, startTime: startTime!, eventType: eventType!,eventYearString: String(eventYear));
        
        let message = attendedHandle.setShowsAttendedStatus(sender,status: status);
        
        let eventImage = getAttendedIcons(attendedStatus: status)
        
        updateEventImage(sender: sender, eventImage: eventImage)
        
        ToastMessages(message).show(self, cellLocation: self.view.frame)
    }
    
    func updateEventImage(sender: UITextField, eventImage: UIImage) {
        
        var attendGraphicField = UIImageView()
        var skip = false
        
        switch sender.tag {
        case 11:
            attendGraphicField = Event1AttendedIcon
            
        case 12:
            attendGraphicField = Event2AttendedIcon
            
        case 13:
            attendGraphicField = Event3AttendedIcon
 
        case 14:
            attendGraphicField = Event4AttendedIcon
            
        case 15:
            attendGraphicField = Event5AttendedIcon
            
        default:
            skip = true
        }
        
        if skip == false {
            attendGraphicField.image = eventImage
        }
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

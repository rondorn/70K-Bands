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
        
        attendedHandle.loadShowsAttended()
        if (bandName == nil && bandSelected.isEmpty == false){
            bandName = bandSelected
        }
         //print ("bandName is 2 " + bandName)
        
        if ((bandName == nil || bands.isEmpty == true) && bands.count > 0) {
            var bands = bandNameHandle.getBandNames()
            print ("bands discovered are \(bands)")
            bandName = bands[0]
            print("Providing default band of " + bandName)
        } else if (bandName == nil || bands.isEmpty == true){
                bandName = "Waiting for Data"
        }
        
        print ("bandName is 3 " + bandName)
        
        //bandSelected = bandName
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
            
            if (defaults.bool(forKey: "notesFontSizeLarge") == true){
                customNotesText.font = UIFont(name: customNotesText.font!.fontName, size: 20)
            }
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
        
        let screenSize = UIScreen.main.bounds
        
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
            self.bandLogo.contentMode = UIView.ContentMode.scaleAspectFit
            self.bandLogo.sizeToFit()
        }
        
        if (eventCount <= 1){
            customNotesText.frame.size.height = screenSize.height * 0.47
        }
        
        self.bandLogo.contentMode = UIView.ContentMode.scaleAspectFit
        self.bandLogo.clipsToBounds = true
        

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
        
        } else {
            officialUrlButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 1, bottom: 0, right: 1)
            wikipediaUrlButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            youtubeUrlButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            metalArchivesButton.imageEdgeInsets = UIEdgeInsets(top: -1, left: 0, bottom: -1, right: 0)
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
                
                Event1.font = UIFont.systemFont(ofSize: 25)
                Event2.font = UIFont.systemFont(ofSize: 25)
                Event3.font = UIFont.systemFont(ofSize: 25)
                Event4.font = UIFont.systemFont(ofSize: 25)
                Event5.font = UIFont.systemFont(ofSize: 25)
                
                Event1.sizeToFit()
                Event2.sizeToFit()
                Event3.sizeToFit()
                Event4.sizeToFit()
                Event5.sizeToFit()
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
                
                
                Event1.font = UIFont.systemFont(ofSize: 17)
                Event2.font = UIFont.systemFont(ofSize: 17)
                Event3.font = UIFont.systemFont(ofSize: 17)
                Event4.font = UIFont.systemFont(ofSize: 17)
                Event5.font = UIFont.systemFont(ofSize: 17)
                
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
        let UnknonwSee: String = NSLocalizedString("Unknown", comment: "A Wont See Band")
        
        priorityButtons.setTitle(MustSee, forSegmentAt: 1)
        priorityButtons.setTitle(MightSee, forSegmentAt: 2)
        priorityButtons.setTitle(WontSee, forSegmentAt: 3)

        priorityButtons.setTitle(UnknonwSee, forSegmentAt: 0)
        
        let font = UIFont.boldSystemFont(ofSize: 11)
        let fontColor = [NSAttributedString.Key.foregroundColor: UIColor.white, NSAttributedString.Key.font: font]
        priorityButtons.setTitleTextAttributes(fontColor, for: .normal)
        
        let fontColorSelected = [NSAttributedString.Key.foregroundColor: UIColor.black, NSAttributedString.Key.font: font]
        priorityButtons.setTitleTextAttributes(fontColorSelected, for: .selected)
        
        if (bandPriorityStorage[bandName!] != nil){
            priorityButtons.selectedSegmentIndex = bandPriorityStorage[bandName!]!
            let priorityImageName = getPriorityGraphic(bandPriorityStorage[bandName!]!)
            PriorityIcon.image = UIImage(named: priorityImageName) ?? UIImage()
        }
    }
    
    @IBAction func swipeRightAction(_ sender: Any) {
        swipeNextRecord(direction: "Next");
    }
        
    @IBAction func swipeLeftAction(_ sender: Any) {
        swipeNextRecord(direction: "Previous");
    }
    
    func swipeNextRecord(direction: String){
        
        var bandNameNext = ""
        var bandNameIndex = ""
        var timeIndex = "";
        var last = false;
        var scheduleMatch = false;
        
        var sizeBands = bands.count;
        var counter = 0;
        
        for band in currentBandList {
            
            print ("swipeAction bandName - \(band)")
            counter = counter + 1
            var indexSplit = band.components(separatedBy: ":")
            var currentBandInLoop = bandNameFromIndex(index: band)
                        
            if (indexSplit.count >= 1){
                if (indexSplit[0].isNumeric == true){
                    if (timeIndexMap[band] == eventSelectedIndex){
                        if (sizeBands != counter){
                            if (direction == "Previous"){
                                counter = counter - 2;
                                if (counter > -1){
                                    eventSelectedIndex = timeIndexMap[currentBandList[counter]]!
                                    bandNameNext = bandNameFromIndex(index: currentBandList[counter])
                                }
                            } else {
                                print ("swipeAction Next - bandNameNext = \(timeIndexMap[currentBandList[counter]]) bandName = \(currentBandList[counter]) - \(currentBandList.count) = \(counter)")
                                if (counter < sizeBands){
                                    eventSelectedIndex = timeIndexMap[currentBandList[counter]]!
                                    bandNameNext = bandNameFromIndex(index: currentBandList[counter])
                                }
                            }
                        }
                        break
                    }
                } else {
                    if (currentBandInLoop == bandName){
                        if (direction == "Previous"){
                            counter = counter - 2;
                            if (counter > -1){
                                 bandNameNext = bandNameFromIndex(index: currentBandList[counter])
                             }
                        } else {
                            if (counter < sizeBands){
                                 bandNameNext = bandNameFromIndex(index: currentBandList[counter])
                             }
                        }
                        break
                    }
                }
            } else {
            
                if (currentBandInLoop == bandName){
                    if (direction == "Previous"){
                        counter = counter - 2;
                        if (counter > -1){
                            bandNameNext = bandNameFromIndex(index: currentBandList[counter])
                        }

                    }
                    if (counter < sizeBands){
                        bandNameNext = bandNameFromIndex(index: currentBandList[counter])
                    }
                    break
                }
            }
        }
        print ("swipeAction \(direction) - bandNameNext = \(bandNameNext) bandName = \(bandName)")
        while (bandNameNext == bandName){
            if (direction == "Next"){
                counter = counter + 1
            } else {
                counter = counter - 1
            }
            print ("swipeRightAction - counter = \(counter) sizeBands = \(sizeBands)")
            if (counter <= (sizeBands - 1)){
                bandNameNext = bandNameFromIndex(index: currentBandList[counter])
            } else {
                counter = sizeBands
            }
            
        }
        if (counter == sizeBands || counter < 0){
            bandNameNext = ""
        }
        jumpToNextOrPreviousScreen(nextBandName: bandNameNext, direction: direction)
    }

    func bandNameFromIndex(index :String) -> String{
        
        var bandName = index;
        var indexSplit = index.components(separatedBy: ":")
        if (indexSplit.count >= 2){
            var index1 = indexSplit[0]
            var index2 = indexSplit[1]
            
            if (index1.isNumeric == true){
                bandName = index2;
            } else {
               bandName = index1;
            }
        }
        
        return bandName;
    }
    
    @IBAction func ClickOnNotes(_ sender: Any) {
        //ToastMessages("Edit Notes").show(self, cellLocation: self.view.frame)
        textViewDidBeginEditing(customNotesText)
        //customNotesText.font = UIFont(name: customNotesText.font!.fontName, size: 25)

    }
    @IBAction func setBandPriority() {
        if (bandName != nil){
            dataHandle.addPriorityData(bandName, priority: priorityButtons.selectedSegmentIndex)
            
            let priorityImageName = getPriorityGraphic(priorityButtons.selectedSegmentIndex)
            PriorityIcon.image = UIImage(named: priorityImageName) ?? UIImage()
        }
    }
    
    func jumpToNextOrPreviousScreen(nextBandName :String, direction :String){
        
        var message = ""
        print ("jumpToNextOrPreviousScreen -  bandName \(nextBandName)")
        if (nextBandName.isEmpty == true){
            if (direction == "Next"){
                message = "End of List"
            } else {
                message = "Already at start of List"
            }
            ToastMessages(message).show(self, cellLocation: self.view.frame)
        } else {
            message = direction + "-" + nextBandName
        
        
            bandSelected = nextBandName
            bandName = nextBandName
            
            ToastMessages(message).show(self, cellLocation: self.view.frame)
            
            detailItem = bandName as AnyObject
            self.viewDidLoad()
            self.viewWillAppear(true)
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
                    let day = monthDateRegionalFormatting(dateValue: schedule.getData(bandName, index: index, variable: dayField))
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
                        scheduleText += " - " + location
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
                            
                            setLocationInfo(eventField: Event1, scheduleText: scheduleText, bandName: bandName, locationName: location, status: status, type: type, EventAttendedIcon: Event1AttendedIcon, EventTypeIcon: Event1TypeIcon)

                        case 2:
                            setLocationInfo(eventField: Event2, scheduleText: scheduleText, bandName: bandName, locationName: location, status: status, type: type, EventAttendedIcon: Event2AttendedIcon, EventTypeIcon: Event2TypeIcon)
                            
                        case 3:
                            setLocationInfo(eventField: Event3, scheduleText: scheduleText, bandName: bandName, locationName: location, status: status, type: type, EventAttendedIcon: Event3AttendedIcon, EventTypeIcon: Event3TypeIcon)
                            
                        case 4:
                            setLocationInfo(eventField: Event4, scheduleText: scheduleText, bandName: bandName, locationName: location, status: status, type: type, EventAttendedIcon: Event4AttendedIcon, EventTypeIcon: Event4TypeIcon)
                            
                        case 5:
                            setLocationInfo(eventField: Event5, scheduleText: scheduleText, bandName: bandName, locationName: location, status: status, type: type, EventAttendedIcon: Event5AttendedIcon, EventTypeIcon: Event5TypeIcon)
                            
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
    
    func setLocationInfo(eventField: UITextField, scheduleText: String, bandName: String, locationName: String, status: String, type: String, EventAttendedIcon: UIImageView, EventTypeIcon: UIImageView){
        
        eventField.text = scheduleText
        _ = attendedHandle.setShowsAttendedStatus(eventField,status: status);
        EventAttendedIcon.image = getAttendedIcons(attendedStatus: status)
        EventTypeIcon.image = getEventTypeIcon(eventType: type, eventName: bandName)
        
        eventField.halfTextColorChange(fullText: eventField.text!, changeText: locationName, locationColor: getVenueColor(venue: locationName))
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
        
        sender.halfTextColorChange(fullText: sender.text!, changeText: location!, locationColor: getVenueColor(venue: location!))
        
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


extension UITextField {
    func halfTextColorChange (fullText : String , changeText : String, locationColor: UIColor ) {
        let strNumber: NSString = fullText as NSString
        let range = (strNumber).range(of: changeText)
        let attribute = NSMutableAttributedString.init(string: fullText)
        attribute.addAttribute(NSAttributedString.Key.foregroundColor, value: locationColor , range: range)
        self.attributedText = attribute
    }
}


extension UIImage {
    
    func resize(maxWidthHeight : Double)-> UIImage? {
        
        let actualHeight = Double(size.height)
        let actualWidth = Double(size.width)
        var maxWidth = 0.0
        var maxHeight = 0.0
        
        if actualWidth > actualHeight {
            maxWidth = maxWidthHeight
            let per = (100.0 * maxWidthHeight / actualWidth)
            maxHeight = (actualHeight * per) / 100.0
        }else{
            maxHeight = maxWidthHeight
            let per = (100.0 * maxWidthHeight / actualHeight)
            maxWidth = (actualWidth * per) / 100.0
        }
        
        let hasAlpha = true
        let scale: CGFloat = 0.0
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: maxWidth, height: maxHeight), !hasAlpha, scale)
        self.draw(in: CGRect(origin: .zero, size: CGSize(width: maxWidth, height: maxHeight)))
        
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        return scaledImage
    }
    
}

extension String {
    var isNumeric: Bool {
        guard self.characters.count > 0 else { return false }
        let nums: Set<Character> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "."]
        return Set(self).isSubset(of: nums)
    }
}

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

    @IBOutlet weak var linkViewTopSpacingConstraint: NSLayoutConstraint!
    @IBOutlet weak var dataViewTopSpacingConstraint: NSLayoutConstraint!
    @IBOutlet weak var notesViewTopSpacingConstraint: NSLayoutConstraint!
    
    var heightConstraint:NSLayoutConstraint = NSLayoutConstraint()
    var linkViewNumber = CGFloat(0)
    var dataViewNumber = CGFloat(0)
    var notesViewNumber = CGFloat(0)
    var noteHeightMove = 49
    
    var mainConstraints:[NSLayoutConstraint] = [NSLayoutConstraint]()
    var notesViewConstraints:[NSLayoutConstraint] = [NSLayoutConstraint]()
    
    var everyOtherFlag = true
    
    @IBOutlet weak var vistLinksLable: UILabel!
    @IBOutlet weak var officialUrlButton: UIButton!
    @IBOutlet weak var wikipediaUrlButton: UIButton!
    @IBOutlet weak var youtubeUrlButton: UIButton!
    @IBOutlet weak var metalArchivesButton: UIButton!
    
    @IBOutlet weak var customNotesButton: UIButton!
    @IBOutlet weak var customNotesText: UITextView!
    
    
    @IBOutlet var mainView: UIView!
    @IBOutlet weak var LinksSection: UIView!
    @IBOutlet weak var notesSection: UIView!
    @IBOutlet weak var extraData: UIView!

    @IBOutlet weak var returnToMaster: UINavigationItem!
    
    @IBOutlet weak var PriorityIcon: UIImageView!
    @IBOutlet weak var priorityButtons: UISegmentedControl!
    @IBOutlet weak var priorityView: UITextField!
    
    @IBOutlet weak var Country: UITextField!
    @IBOutlet weak var Genre: UITextField!
    @IBOutlet weak var NoteWorthy: UITextField!
    
    @IBOutlet weak var EventView1: UIView!
    @IBOutlet weak var EventView2: UIView!
    @IBOutlet weak var EventView3: UIView!
    @IBOutlet weak var EventView4: UIView!
    @IBOutlet weak var EventView5: UIView!
    
    var eventView1Hidden = false
    var eventView2Hidden = false
    var eventView3Hidden = false
    var eventView4Hidden = false
    var eventView5Hidden = false
    
    var eventRestoreMap:[String:[String:UIView]] = [String:[String:UIView]]();
    var constraintRestoreMap:[String:[String:[NSLayoutConstraint]]] = [String:[String:[NSLayoutConstraint]]]();
    
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
        
        self.title = bandName
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
            
            if (defaults.bool(forKey: "notesFontSizeLarge") == true){
                customNotesText.font = UIFont(name: customNotesText.font!.fontName, size: 20)
            }
            NotificationCenter.default.addObserver(self, selector: #selector(DetailViewController.rotationChecking), name: UIDevice.orientationDidChangeNotification, object: nil)
            
            setupEventAttendClicks()
            setupSwipeGenstures()
            customNotesText.isScrollEnabled = false
        }
        
    }
    
    func setupSwipeGenstures(){
        
        var swipeRight = UISwipeGestureRecognizer(target: self, action: "swipeRightAction:")
        swipeRight.direction = UISwipeGestureRecognizer.Direction.right
        self.mainView.addGestureRecognizer(swipeRight)
        
        var swipeLeft = UISwipeGestureRecognizer(target: self, action: "swipeLeftAction:")
        swipeLeft.direction = UISwipeGestureRecognizer.Direction.left
        self.mainView.addGestureRecognizer(swipeLeft)
        
    }
    
    func resetScheduleGUI(){
        
        LinksSection.isHidden = false
        notesSection.isHidden = false
        extraData.isHidden = false
        
        vistLinksLable.isHidden = false
        officialUrlButton.isHidden = false
        wikipediaUrlButton.isHidden = false
        youtubeUrlButton.isHidden = false
        metalArchivesButton.isHidden = false
        
        disableLinksWithEmptyData()
        
        Country.isHidden = false
        Genre.isHidden = false
        NoteWorthy.isHidden = false
        
        if (everyOtherFlag == false){
            noteHeightMove = 51
            everyOtherFlag = true
        } else {
            noteHeightMove = 49
            everyOtherFlag = false
        }
        
        if (eventView1Hidden == true){
            restoreEvents(eventView: EventView1, eventIndex: "event1")
            eventView1Hidden = false
        } else {
            var eventTypeText1 = EventView1.viewWithTag(3) as! UILabel
            eventTypeText1.text = ""
        }
        if (eventView2Hidden == true){
            restoreEvents(eventView: EventView2, eventIndex: "event2")
            eventView2Hidden = false
        } else {
            
            var eventTypeText2 = EventView2.viewWithTag(3) as! UILabel
            eventTypeText2.text = ""
        }
        if (eventView3Hidden == true){
            restoreEvents(eventView: EventView3, eventIndex: "event3")
            eventView3Hidden = false
        } else {
            var eventTypeText3 = EventView3.viewWithTag(3) as! UILabel
            eventTypeText3.text = ""
        }
        if (eventView4Hidden == true){
            restoreEvents(eventView: EventView4, eventIndex: "event4")
            eventView4Hidden = false
        } else {
            var eventTypeText4 = EventView4.viewWithTag(3) as! UILabel
            eventTypeText4.text = ""
        }
        if (eventView5Hidden == true){
            restoreEvents(eventView: EventView5, eventIndex: "event5")
            eventView5Hidden = false
        } else {
            var eventTypeText5 = EventView5.viewWithTag(3) as! UILabel
            eventTypeText5.text = ""
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    func setupEventAttendClicks(){
            
        let gesture1 = UITapGestureRecognizer(target: self, action:  #selector(self.clickedOnEvent))
        self.EventView1.addGestureRecognizer(gesture1)
        
        let gesture2 = UITapGestureRecognizer(target: self, action:  #selector(self.clickedOnEvent))
        self.EventView2.addGestureRecognizer(gesture2)
 
        let gesture3 = UITapGestureRecognizer(target: self, action:  #selector(self.clickedOnEvent))
        self.EventView3.addGestureRecognizer(gesture3)
        
        let gesture4 = UITapGestureRecognizer(target: self, action:  #selector(self.clickedOnEvent))
        self.EventView4.addGestureRecognizer(gesture4)
        
        let gesture5 = UITapGestureRecognizer(target: self, action:  #selector(self.clickedOnEvent))
        self.EventView5.addGestureRecognizer(gesture5)
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
        } else {
            officialUrlButton.isHidden = false;
            wikipediaUrlButton.isHidden = false;
            youtubeUrlButton.isHidden = false;
            metalArchivesButton.isHidden = false;
            linkGroup.isHidden = false
            vistLinksLable.isHidden = false;
            LinksSection.isHidden = false;
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
        customNotesText.isScrollEnabled = true
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
                
                LinksSection.isHidden = true
                LinksSection.sizeToFit()
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
                LinksSection.isHidden = false
                extraData.isHidden = false
                notesSection.isHidden = false
                
                LinksSection.sizeToFit()
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
        swipeNextRecord(direction: "Previous");
    }
        
    @IBAction func swipeLeftAction(_ sender: Any) {
        swipeNextRecord(direction: "Next");
    }
    
    func swipeNextRecord(direction: String){
        
        var bandNameNext = ""
        var bandNameIndex = ""
        var timeIndex = "";
        var last = false;
        var scheduleMatch = false;
        
        var sizeBands = bands.count;
        var counter = 0;
        
        if (currentBandList.count == 0){
            
        }
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
        var animationMovement = CGFloat.init();
        
        var translatedDirection = NSLocalizedString(direction, comment: "");
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            animationMovement = 0;
        } else {
            if (direction == "Next"){
                animationMovement = -600;
            } else {
                animationMovement = 600;
            }
        }
        
        print ("jumpToNextOrPreviousScreen -  bandName \(nextBandName)")
        
        if (nextBandName.isEmpty == true){
            if (direction == "Next"){
                message = NSLocalizedString("EndofList", comment: "");
            } else {
                message = NSLocalizedString("AlreadyAtStart", comment: "");
            }
            ToastMessages(message).show(self, cellLocation: self.view.frame, heightValue: 3)
        } else {
            message = translatedDirection + "-" + nextBandName
        
        
            bandSelected = nextBandName
            bandName = nextBandName
            
            ToastMessages(message).show(self, cellLocation: self.view.frame, heightValue: 3)
            
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
                
                var frameNotes = self.customNotesText.frame
                frameNotes.origin.x += animationMovement
                self.customNotesText.frame = frameNotes

                var frameLogo = self.bandLogo.frame
                frameLogo.origin.x += animationMovement
                self.bandLogo.frame = frameLogo

                var frameLinks = self.LinksSection.frame
                frameLinks.origin.x += animationMovement
                self.LinksSection.frame = frameLinks
                
                var frameEvents1 = self.EventView1.frame
                frameEvents1.origin.x += animationMovement
                self.EventView1.frame = frameEvents1
                
                var frameEvents2 = self.EventView2.frame
                frameEvents2.origin.x += animationMovement
                self.EventView2.frame = frameEvents2
                
                var frameEvents3 = self.EventView3.frame
                frameEvents3.origin.x += animationMovement
                self.EventView3.frame = frameEvents3
                
                var frameEvents4 = self.EventView4.frame
                frameEvents4.origin.x += animationMovement
                self.EventView4.frame = frameEvents4
                
                var frameEvents5 = self.EventView5.frame
                frameEvents5.origin.x += animationMovement
                self.EventView5.frame = frameEvents5
                
                var frameExtras = self.extraData.frame
                frameExtras.origin.x += animationMovement
                self.extraData.frame = frameExtras
                
            }, completion: { finished in })
        
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
               
        resetScheduleGUI()
        schedule.getCachedData()
        scheduleQueue.sync {
            if (schedule.schedulingData[bandName]?.isEmpty == false){
                
                let keyValues = schedule.schedulingData[bandName]!.keys
                let sortedArray = keyValues.sorted();
                var count = 1
                eventCount = keyValues.count;

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
                        
                        let status = attendedHandle.getShowAttendedStatus(band: bandName, location: location, startTime: rawStartTime, eventType: type, eventYearString: String(eventYear));
                        
                        print ("Show Attended Load \(status) - \(location) - \(startTime) - \(type)")
                        switch count {
                        case 1:
                            populateScheduleData(eventSlot: "event1", eventView: EventView1, location: location, day: day, startTime: rawStartTime, endTime: endTime, date: date, eventType: type, notes: notes, timeIndex: index)
                        case 2:
                            populateScheduleData(eventSlot: "event2", eventView: EventView2, location: location, day: day, startTime: rawStartTime, endTime: endTime, date: date, eventType: type, notes: notes, timeIndex: index)
                            
                        case 3:
                            populateScheduleData(eventSlot: "event3", eventView: EventView3, location: location, day: day, startTime: rawStartTime, endTime: endTime, date: date, eventType: type,notes: notes, timeIndex: index)
                            
                        case 4:
                           populateScheduleData(eventSlot: "event4",eventView: EventView4, location: location, day: day, startTime: rawStartTime, endTime: endTime, date: date, eventType: type,notes: notes, timeIndex: index)
                            
                        case 5:
                            populateScheduleData(eventSlot: "event5",eventView: EventView5, location: location, day: day, startTime: rawStartTime, endTime: endTime, date: date, eventType: type,notes: notes, timeIndex: index)
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
    
    func populateScheduleData(eventSlot: String, eventView: UIView, location: String, day:String, startTime: String,
                              endTime: String, date: String, eventType: String, notes: String,timeIndex: TimeInterval){
        
        scheduleIndex[eventSlot] = [String:String]();
        scheduleIndex[eventSlot]!["location"] = location
        scheduleIndex[eventSlot]!["eventType"] = eventType
        scheduleIndex[eventSlot]!["startTime"] = startTime
        
        let attendedView = eventView.viewWithTag(4) as! UIImageView
        print ("Icon parms \(bandName) \(location) \(startTime) \(eventType)")
        let icon = attendedHandle.getShowAttendedIcon(band: bandName,location: location,startTime: startTime,eventType: eventType,eventYearString: String(eventYear));
        attendedView.image = icon

        var locationColor = eventView.viewWithTag(1)
        locationColor?.backgroundColor = getVenueColor(venue: location);
        
        var locationView = eventView.viewWithTag(2) as! UILabel
        var locationText = location
        if (venueLocation[location] != nil){
            locationText += " " + venueLocation[location]!
        }
        locationView.textColor = UIColor.white
        locationView.text = locationText

        let eventTypeText = eventView.viewWithTag(3)  as! UILabel
        eventTypeText.textColor = UIColor.lightGray
        if (eventType == showType){
            eventTypeText.text = " "
        } else {
            eventTypeText.text = eventType
        }
    
            
        let eventTypeImageView = eventView.viewWithTag(5) as! UIImageView
        let eventIcon = getEventTypeIcon(eventType: eventType, eventName: bandName)
        eventTypeImageView.image = eventIcon
        
        let startTimeView = eventView.viewWithTag(6) as! UILabel
        let startTime = schedule.getData(bandName, index: timeIndex, variable: startTimeField)
        let startTimeText = formatTimeValue(timeValue: startTime)
        startTimeView.textColor = UIColor.white
        startTimeView.text = startTimeText
        
        let endTimeView = eventView.viewWithTag(7) as! UILabel
        let endTime = schedule.getData(bandName, index: timeIndex, variable: endTimeField)
        let endTimeText = formatTimeValue(timeValue: endTime)
        endTimeView.textColor = UIColor.darkGray
        endTimeView.text = endTimeText
        
        let dayLabelView = eventView.viewWithTag(8) as! UILabel
        dayLabelView.text = "Day"
        
        let dayView = eventView.viewWithTag(9) as! UILabel
        dayView.textColor = UIColor.white
        var dayText = ""
        if day == "Day 1"{
            dayText = "1";
        
        } else if day == "Day 2"{
            dayText = "2";
            
        } else if day == "Day 3"{
            dayText = "3";
            
        } else if day == "Day 4"{
            dayText = "4";
            
        } else {
            dayText = day
        }
        
        dayView.text = dayText

 
        let notesView = eventView.viewWithTag(10) as! UILabel
        notesView.textColor = UIColor.lightGray
        notesView.text = notes

    }
    
    func hideEmptyData() {
        
        var genericUIText:UILabel = UILabel()
        genericUIText.text = "placeHolder"
        
        var eventTypeText1:UILabel = UILabel()
        var eventTypeText2:UILabel  = UILabel()
        var eventTypeText3:UILabel  = UILabel()
        var eventTypeText4:UILabel  = UILabel()
        var eventTypeText5:UILabel  = UILabel()
        var reloadData = false
        
        eventTypeText1 = EventView1.viewWithTag(3) as! UILabel
        eventTypeText2 = EventView2.viewWithTag(3) as! UILabel
        eventTypeText3 = EventView3.viewWithTag(3) as! UILabel
        eventTypeText4 = EventView4.viewWithTag(3) as! UILabel
        eventTypeText5 = EventView5.viewWithTag(3) as! UILabel
        
        if (eventTypeText1.text?.isEmpty)!{
            hideEvent(eventView: EventView1, eventIndex: "event1")
            eventView1Hidden = true
        }
        if (eventTypeText2.text?.isEmpty)!{
            hideEvent(eventView: EventView2, eventIndex: "event2")
            eventView2Hidden = true
        }
        if (eventTypeText3.text?.isEmpty)!{
            hideEvent(eventView: EventView3, eventIndex: "event3")
            eventView3Hidden = true
        }
        if (eventTypeText4.text?.isEmpty)!{
            hideEvent(eventView: EventView4, eventIndex: "event4")
            eventView4Hidden = true
        }
        if (eventTypeText5.text?.isEmpty)!{
            hideEvent(eventView: EventView5, eventIndex: "event5")
            eventView5Hidden = true
        }
    }
    
    func restoreEvents(eventView: UIView, eventIndex: String){
        
        restorEvent(eventView: eventView, eventIndex: eventIndex, fieldIndex: "locationColor")
        restorEvent(eventView: eventView, eventIndex: eventIndex, fieldIndex: "locationView")
        restorEvent(eventView: eventView, eventIndex: eventIndex, fieldIndex: "eventTypeText")
        restorEvent(eventView: eventView, eventIndex: eventIndex, fieldIndex: "attendedView")
        restorEvent(eventView: eventView, eventIndex: eventIndex, fieldIndex: "eventTypeImageView")
        restorEvent(eventView: eventView, eventIndex: eventIndex, fieldIndex: "startTimeView")
        restorEvent(eventView: eventView, eventIndex: eventIndex, fieldIndex: "endTimeView")
        restorEvent(eventView: eventView, eventIndex: eventIndex, fieldIndex: "dayLabelView")
        restorEvent(eventView: eventView, eventIndex: eventIndex, fieldIndex: "dayView")
        restorEvent(eventView: eventView, eventIndex: eventIndex, fieldIndex: "notesView")
        
        let currentConstraints = constraintRestoreMap[eventIndex]?[eventIndex]
        eventView.addConstraints(currentConstraints!)
        
        var eventTypeText = eventView.viewWithTag(3) as! UILabel
        eventTypeText.text = ""
        
        self.notesViewTopSpacingConstraint.constant =  self.notesViewTopSpacingConstraint.constant + CGFloat(noteHeightMove)
        self.dataViewTopSpacingConstraint.constant = self.dataViewTopSpacingConstraint.constant + 50
        self.linkViewTopSpacingConstraint.constant = self.linkViewTopSpacingConstraint.constant + 50
        
        
    }
    
    func restorEvent(eventView: UIView, eventIndex: String, fieldIndex: String){
        
        let currentView = eventRestoreMap[eventIndex]?[fieldIndex]
        let currentConstraints = constraintRestoreMap[eventIndex]?[fieldIndex]
        currentView?.addConstraints(currentConstraints!)
        eventView.addSubview(currentView!)
    }
    
    func hideEvent(eventView: UIView, eventIndex: String){
        
        eventRestoreMap[eventIndex] = [String:UIView]();
        constraintRestoreMap[eventIndex] = [String:[NSLayoutConstraint]]();
        
        constraintRestoreMap[eventIndex]?[eventIndex] = eventView.constraints
        
        var locationColor = eventView.viewWithTag(1)
        eventRestoreMap[eventIndex]?["locationColor"] = locationColor;
        constraintRestoreMap[eventIndex]?["locationColor"] = locationColor?.constraints
        locationColor?.removeFromSuperview()
        
        var locationView = eventView.viewWithTag(2) as! UILabel
        eventRestoreMap[eventIndex]?["locationView"] = locationView;
        constraintRestoreMap[eventIndex]?["locationView"] = locationView.constraints
        locationView.removeFromSuperview()
        
        let eventTypeText = eventView.viewWithTag(3)  as! UILabel
        eventRestoreMap[eventIndex]?["eventTypeText"] = eventTypeText;
        constraintRestoreMap[eventIndex]?["eventTypeText"] = eventTypeText.constraints
        eventTypeText.removeFromSuperview()
        
        let attendedView = eventView.viewWithTag(4) as! UIImageView
        eventRestoreMap[eventIndex]?["attendedView"] = attendedView;
        constraintRestoreMap[eventIndex]?["attendedView"] = attendedView.constraints
        attendedView.removeFromSuperview()
        
        let eventTypeImageView = eventView.viewWithTag(5) as! UIImageView
        eventRestoreMap[eventIndex]?["eventTypeImageView"] = eventTypeImageView;
        constraintRestoreMap[eventIndex]?["eventTypeImageView"] = eventTypeImageView.constraints
        eventTypeImageView.removeFromSuperview()
        
        let startTimeView = eventView.viewWithTag(6) as! UILabel
        eventRestoreMap[eventIndex]?["startTimeView"] = startTimeView;
        constraintRestoreMap[eventIndex]?["startTimeView"] = startTimeView.constraints
        startTimeView.removeFromSuperview()
        
        let endTimeView = eventView.viewWithTag(7) as! UILabel
        eventRestoreMap[eventIndex]?["endTimeView"] = endTimeView;
        constraintRestoreMap[eventIndex]?["endTimeView"] = endTimeView.constraints
        endTimeView.removeFromSuperview()
        
        let dayLabelView = eventView.viewWithTag(8) as! UILabel
        eventRestoreMap[eventIndex]?["dayLabelView"] = dayLabelView;
        constraintRestoreMap[eventIndex]?["dayLabelView"] = dayLabelView.constraints
        dayLabelView.removeFromSuperview()
        
        let dayView = eventView.viewWithTag(9) as! UILabel
        eventRestoreMap[eventIndex]?["dayView"] = dayView;
        constraintRestoreMap[eventIndex]?["dayView"] = dayView.constraints
        dayView.removeFromSuperview()
        
        let notesView = eventView.viewWithTag(10) as! UILabel
        eventRestoreMap[eventIndex]?["notesView"] = notesView;
        constraintRestoreMap[eventIndex]?["notesView"] = notesView.constraints
        notesView.removeFromSuperview()
        
        linkViewTopSpacingConstraint.constant = linkViewTopSpacingConstraint.constant - 50
        dataViewTopSpacingConstraint.constant = dataViewTopSpacingConstraint.constant - 50
        notesViewTopSpacingConstraint.constant = notesViewTopSpacingConstraint.constant - 50
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
    
    @objc func clickedOnEvent(sender: UITapGestureRecognizer) {
        
        var eventString = ""
        if (sender.view?.tag == 51){
            eventString = "event1";
        
        } else if (sender.view?.tag == 52){
            eventString = "event2";
        
        } else if (sender.view?.tag == 53){
            eventString = "event3";

        } else if (sender.view?.tag == 54){
            eventString = "event4";

        } else if (sender.view?.tag == 55){
            eventString = "event5";
        }

        let location = scheduleIndex[eventString]!["location"]
        let startTime = scheduleIndex[eventString]!["startTime"]
        let eventType = scheduleIndex[eventString]!["eventType"]
        
        let status = attendedHandle.addShowsAttended(band: bandName, location: location!, startTime: startTime!, eventType: eventType!,eventYearString: String(eventYear));
        
        let empty : UITextField = UITextField();
        let message = attendedHandle.setShowsAttendedStatus(empty,status: status);
        
        ToastMessages(message).show(self, cellLocation: self.view.frame, heightValue: 3)

        showFullSchedule ()
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

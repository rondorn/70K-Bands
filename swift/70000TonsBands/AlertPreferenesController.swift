//
//  AlertPreferenesController.swift
//  70K Bands
//
//  Created by Ron Dorn on 2/14/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import UIKit
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func >= <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l >= r
  default:
    return !(lhs < rhs)
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func <= <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l <= r
  default:
    return !(rhs < lhs)
  }
}


class AlertPreferenesController: UIViewController, UITextFieldDelegate {
    
    var restartAlertTitle = String();
    var restartAlertText = String();
    var okPrompt = String();
    var cancelPrompt = String();
    var yearChangeAborted = String();
    var eventOrBandPrompt = String();
    var bandListButton = String()
    var eventListButton = String()
    
    var hideExpireScheduleData = Bool()
    var promptForAttended = Bool()
    
    var eventYearChangeAttempt = "Current";
    var changeYearDialogBoxTitle = String();
    
    
    @IBOutlet weak var DetailScreenSection: UILabel!
    @IBOutlet weak var NotesFontSizeLargeLabel: UILabel!
    @IBOutlet weak var NotesFontSizeLargeSwitch: UISwitch!
    
    @IBOutlet weak var HideExpiredLabel: UILabel!
    @IBOutlet weak var HideExpiredSwitchLabel: UILabel!
    @IBOutlet weak var HideExpiredSwitch: UISwitch!
    
    @IBOutlet weak var PromptForAttendedLabel: UILabel!
    @IBOutlet weak var PromptForAttendedSwitchLabel: UILabel!
    @IBOutlet weak var PromptForAttendedSwitch: UISwitch!
    
    @IBOutlet weak var alertPreferenceHeader: UILabel!
    @IBOutlet weak var AlertOnMustSee: UISwitch!
    @IBOutlet weak var AlertOnMightSee: UISwitch!
    
    @IBOutlet weak var AlertOnlyForAttended: UISwitch!
    
    @IBOutlet weak var AlertForShows: UISwitch!
    @IBOutlet weak var AlertForSpecialEvents: UISwitch!
    @IBOutlet weak var AlertForMeetAndGreets: UISwitch!
    @IBOutlet weak var AlertForClinic: UISwitch!
    @IBOutlet weak var AlertForListeningEvent: UISwitch!
    @IBOutlet weak var MinBeforeAlert: UITextField!

    @IBOutlet weak var alertForUnofficalEvents: UISwitch!
    
    //labels
    @IBOutlet weak var mustSeeAlertLable: UILabel!
    @IBOutlet weak var mightSeeAlertLable: UILabel!
    @IBOutlet weak var onlyAlertForAttendedLable: UILabel!
    @IBOutlet weak var minBeforeAlertLable: UILabel!
    @IBOutlet weak var alertForShowsLable: UILabel!
    @IBOutlet weak var alertForSpecialLable: UILabel!
    @IBOutlet weak var alertForMandGLable: UILabel!
    @IBOutlet weak var alertForClinicsLable: UILabel!

    @IBOutlet weak var alertForListeningLable: UILabel!
    
    @IBOutlet weak var selectYearLable: UILabel!
    @IBOutlet weak var userIDLabel: UILabel!
    
    @IBOutlet weak var alertForUnofficalEventsLable: UILabel!
    
    @IBOutlet weak var selectEventYear: UIButton!
    @IBOutlet weak var SelectEventYearMenu: UIMenu!
    
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var controlView: UIControl!
    
    var dataHandle = dataHandler()
    var currentYearSetting = getScheduleUrl()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        filterMenuNeedsUpdating = true
        let screenSize: CGRect = UIScreen.main.bounds
        var screenHeight = screenSize.height
        let screenWidth = screenSize.width
        
        if (screenWidth < 350){
            screenHeight = 1000;
            scrollView.contentInset = UIEdgeInsets(top: 0, left: -25, bottom: 0, right: 0);
        }
        scrollView.contentSize = CGSize(width: 300,height: screenHeight);
        
        
        // Do any additional setup after loading the view, typically from a nib.
        setExistingValues()
        setLocalizedLables()

        buildEventYearMenu(currentYear: currentYearSetting)
        disableAlertButtonsIfNeeded()
        self.navigationItem.title = NSLocalizedString("PreferenceHeader", comment: "")

        NotificationCenter.default.addObserver(self, selector: #selector(self.displayWaitingMessage), name: NSNotification.Name(rawValue: "DisplayWaitingMessage"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.eventsOrBandsPrompt), name: NSNotification.Name(rawValue: "EventsOrBandsPrompt"), object: nil)
        
        
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewWillDisappear(_ animated : Bool) {
        super.viewWillDisappear(animated)
        
        //reset alerts
        let localNotification = localNoticationHandler()
        localNotification.clearNotifications()
        localNotification.addNotifications()
        
        masterView.quickRefresh()
    }
    
    func buildEventYearMenu(currentYear: String){

        if (eventYearArray == nil || eventYearArray.isEmpty == true){
            let variableStoreHandle = variableStore();
            print ("eventYearsInfoFile: file is loading \(eventYearsInfoFile)");
            eventYearArray = variableStoreHandle.readDataFromDiskArray(fileName: eventYearsInfoFile) ?? ["Current"]
            
            print ("eventYearsInfoFile: file is loaded \(eventYearArray)");
        }
        // Set up the pop-up button items
        var actionArray = [UIAction]()
        print ("Looping through event years")
        for eventElement in eventYearArray {
            var yearChange = eventElement;
            if (yearChange.isYearValue == false){
                yearChange = NSLocalizedString("Current", comment: "")
            }
            
            print ("Looping through event years, on \(eventElement)")
            let actionItem = UIAction(title: yearChange) { [weak self] _ in
                self?.eventYearDidChange(year: yearChange)
            }

            print ("eventElement = \(yearChange) - pointerIndex = \(currentYear)")
            
            if (eventElement == currentYear){
                actionItem.state = UIAction.State.on
            }
            actionArray.append(actionItem)
        }
        
        // Create a UIMenu with the action
        let menu = UIMenu(title: "", children: actionArray)
        
        selectEventYear.menu = menu

    }
    
    func eventYearDidChange(year: String){
        print("Selected index \(year)")
        
        var yearChange = year;
        
        if (yearChange.isYearValue == false){
            yearChange = "Current"
        }
        
        eventYearChangeAttempt = yearChange
        
        UseLastYearsDataAction()
    }
    
    func setLocalizedLables (){
        
        alertPreferenceHeader.text = NSLocalizedString("AlertPreferences", comment: "")
        mustSeeAlertLable.text = NSLocalizedString("Alert On Must See Bands", comment: "")
        mightSeeAlertLable.text = NSLocalizedString("Alert On Might See Bands", comment: "")
        onlyAlertForAttendedLable.text = NSLocalizedString("Alert Only for Will Attend Events", comment: "")
        
        minBeforeAlertLable.text = NSLocalizedString("Minutes Before Event to Alert", comment: "")
        alertForShowsLable.text = NSLocalizedString("Alert For Shows", comment: "")
        alertForSpecialLable.text = NSLocalizedString("Alert For Special Events", comment: "")
        alertForMandGLable.text = NSLocalizedString("Alert For Meeting and Greet Events", comment: "")
        alertForClinicsLable.text = NSLocalizedString("Alert For Clinics", comment: "")
        alertForListeningLable.text  = NSLocalizedString("Alert For Album Listening Events", comment: "")
        alertForUnofficalEventsLable.text = NSLocalizedString("Alert For Unofficial Events", comment: "")
        
        restartAlertTitle = NSLocalizedString("restartTitle", comment: "")
        restartAlertText = NSLocalizedString("restartMessage", comment: "")
        changeYearDialogBoxTitle = NSLocalizedString("changeYearDialogBoxTitle", comment: "")
        
        okPrompt = NSLocalizedString("Ok", comment: "")
        cancelPrompt = NSLocalizedString("Cancel", comment: "")
        yearChangeAborted = NSLocalizedString("yearChangeAborted", comment: "")
        eventOrBandPrompt = NSLocalizedString("eventOrBandPrompt", comment: "")
        bandListButton = NSLocalizedString("bandListButton", comment: "")
        eventListButton = NSLocalizedString("eventListButton", comment: "")
        
        NotesFontSizeLargeLabel.text = NSLocalizedString("NoteFontSize", comment: "")
        
        HideExpiredLabel.text = NSLocalizedString("showHideExpiredLabel", comment: "")
        HideExpiredSwitchLabel.text = NSLocalizedString("hideExpiredEvents", comment: "")
        
        PromptForAttendedLabel.text = NSLocalizedString("Prompt For Attended Status Header", comment: "")
        PromptForAttendedSwitchLabel.text = NSLocalizedString("Prompt For Attended Status", comment: "")
        
        selectYearLable.text = NSLocalizedString("SelectYearLabel", comment: "")
        
        var uidString = "Unknown"
        if (UIDevice.current.identifierForVendor != nil){
            if (UIDevice.current.identifierForVendor != nil){
                uidString = UIDevice.current.identifierForVendor!.uuidString
            }
        }
        userIDLabel.text = "UserID:\t" + uidString + "\nBuild:\t" + versionInformation + "\nVersion: "
        userIDLabel.text = userIDLabel.text! + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String)
        userIDLabel.numberOfLines = 2
        userIDLabel.adjustsFontSizeToFitWidth = true
    }
    
    func setExistingValues (){
        
        AlertOnMustSee.isOn = getMustSeeAlertValue()
        AlertOnMightSee.isOn = getMightSeeAlertValue()
        AlertOnlyForAttended.isOn = getOnlyAlertForAttendedValue()
        
        print ("Setting MinBeforeAlert as " + String(getMinBeforeAlertValue()))
        MinBeforeAlert.text = String(getMinBeforeAlertValue())

        AlertForShows.isOn = getAlertForShowsValue()
        AlertForSpecialEvents.isOn = getAlertForSpecialValue()
        AlertForMeetAndGreets.isOn = getAlertForMandGValue()
        alertForUnofficalEvents.isOn = getAlertForUnofficalEventsValue()
        AlertForClinic.isOn = getAlertForClinicEvents()
        AlertForListeningEvent.isOn = getAlertForListeningEvents()
        
        NotesFontSizeLargeSwitch.isOn = getNotesFontSizeLargeValue()
        
        self.MinBeforeAlert.delegate = self
        
        print ("getPointerUrlData: lastYear setting is \(getScheduleUrl()) in AlertPrefs")
        
        HideExpiredSwitch.isOn = getHideExpireScheduleData()
        PromptForAttendedSwitch.isOn = getPromptForAttended()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true);
        return false;
    }
    
    func disableAlertButtonsIfNeeded(){
        
        if (AlertOnlyForAttended.isOn == true){
            AlertOnMustSee.isEnabled = false;
            AlertOnMightSee.isEnabled = false;
            AlertForShows.isEnabled = false;
            AlertForSpecialEvents.isEnabled = false;
            AlertForMeetAndGreets.isEnabled = false;
            AlertForClinic.isEnabled = false;
            AlertForListeningEvent.isEnabled = false;
            alertForUnofficalEvents.isEnabled = false;
            
            mustSeeAlertLable.isEnabled = false
            mightSeeAlertLable.isEnabled = false
            alertForShowsLable.isEnabled = false
            alertForSpecialLable.isEnabled = false
            alertForMandGLable.isEnabled = false
            alertForClinicsLable.isEnabled = false
            alertForListeningLable.isEnabled = false
            alertForUnofficalEventsLable.isEnabled = false
            
        } else {
            AlertOnMustSee.isEnabled = true;
            AlertOnMightSee.isEnabled = true;
            AlertForShows.isEnabled = true;
            AlertForSpecialEvents.isEnabled = true;
            AlertForMeetAndGreets.isEnabled = true;
            AlertForClinic.isEnabled = true;
            AlertForListeningEvent.isEnabled = true;
            alertForUnofficalEvents.isEnabled = true;
            
            mustSeeAlertLable.isEnabled = true
            mightSeeAlertLable.isEnabled = true
            alertForShowsLable.isEnabled = true
            alertForSpecialLable.isEnabled = true
            alertForMandGLable.isEnabled = true
            alertForClinicsLable.isEnabled = true
            alertForListeningLable.isEnabled = true
            alertForUnofficalEventsLable.isEnabled = true
        }
    }
    
    @IBAction func MinBeforeAlertEndAction() {
        print ("MinBeforeAlert ENDING text is \(MinBeforeAlert.text)")
    }
    
    @IBAction func MinBeforeAlertAction() {
        
        print ("MinBeforeAlert text is \(MinBeforeAlert.text)")
        let minBeforeAlertTemp = Int(MinBeforeAlert.text!)
        
        print ("MinBeforeAlert is \(minBeforeAlertTemp)")
        if (minBeforeAlertTemp >= 0 && minBeforeAlertTemp <= 60){
            setMinBeforeAlertValue(Int(minBeforeAlertTemp ??  10))

            MinBeforeAlert.resignFirstResponder()
            
            let localNotification = localNoticationHandler()
            localNotification.clearNotifications()
            
        } else {
            
            MinBeforeAlert.resignFirstResponder()
            MinBeforeAlert.text = String(format: "%.0f", getMinBeforeAlertValue())
            let alert = UIAlertView()
            alert.title = "Number Provided Is Invalid"
            alert.message =  ("Number Provided \(minBeforeAlertTemp) is Invalid\nMust be a value between 0 and 60")
            alert.addButton(withTitle: okPrompt)
            alert.show()
        }
        
    }
    
    @IBAction func MustSeeChange() {
        setMustSeeAlertValue(AlertOnMustSee.isOn)
    }
    
    @IBAction func MightSeeChange() {
        setMightSeeAlertValue(AlertOnMightSee.isOn)
    }
    
    @IBAction func AlertOnlyForAttendedChange() {
        setOnlyAlertForAttendedValue(AlertOnlyForAttended.isOn)
        disableAlertButtonsIfNeeded()
        
        var helpMessage = "";
        if (AlertOnlyForAttended.isOn == true){
            helpMessage = NSLocalizedString("Only alert for shows you will attend", comment: "")
        } else {
            helpMessage = NSLocalizedString("Alert for shows according to your favorites selection", comment: "")
        }
        
        ToastMessages(helpMessage).show(self, cellLocation: self.view.frame, placeHigh: false)
    }
    
    @IBAction func AlertForShowsChange() {
        setAlertForShowsValue(AlertForShows.isOn)
    }
    
    @IBAction func AlertForSpecialEventChange() {
        setAlertForSpecialValue(AlertForSpecialEvents.isOn)
    }

    @IBAction func AlertForClinicChange() {
        setAlertForClinicEvents(AlertForClinic.isOn)
    }
    
    @IBAction func AlertForListeningEventChange() {
        setAlertForListeningEvents(AlertForListeningEvent.isOn)
    }
    
    
    @IBAction func AlertForMeetAndGreetChange() {
        setAlertForMandGValue(AlertForMeetAndGreets.isOn)
    }
    
    @IBAction func backgroundTap (_ sender: UIControl){
        MinBeforeAlert.resignFirstResponder()
    }
    
    @IBAction func alertForUnofficalEventChange(_ sender: Any) {
        setAlertForUnofficalEventsValue(alertForUnofficalEvents.isOn)
    }
    
    @IBAction func hideExpired(_ sender: Any) {
        setHideExpireScheduleData(HideExpiredSwitch.isOn)
        print ("Loading showExpired Writing \(HideExpiredSwitch.isOn) to hideExpireScheduleDataBoolean")
    }
    
    @IBAction func promptForAttended(_ sender: Any) {
        setPromptForAttended(PromptForAttendedSwitch.isOn)
    }
    
    @IBAction func notesFontSizeLarge(_ sender: Any) {
        setNotesFontSizeLargeValue(NotesFontSizeLargeSwitch.isOn)
    }
    
    @IBAction func UseLastYearsDataAction() {
        
        print ("Files were in UseLastYearsDataAction")
        
        let alertController = UIAlertController(title: changeYearDialogBoxTitle, message: restartAlertText, preferredStyle: .alert)
        
        // Create the actions
        let okAction = UIAlertAction(title: okPrompt, style: UIAlertAction.Style.default) {
            UIAlertAction in
            NotificationCenter.default.post(name: Notification.Name(rawValue: "DisplayWaitingMessage"), object: nil)
            
            Task{
                        
                await self.lastYearWarningAccepted()
                
                await DispatchQueue.global(qos: DispatchQoS.QoSClass.default).sync {
                    if (self.eventYearChangeAttempt.isYearValue == false){
                        self.HideExpiredSwitch.isOn = true
                        setHideExpireScheduleData(true)
                        self.navigationController?.popViewController(animated: true)
                        self.dismiss(animated: true, completion: nil)
                    } else {
                        NotificationCenter.default.post(name: Notification.Name(rawValue: "EventsOrBandsPrompt"), object: nil)
                    }
                }
                
            }

        }
        let cancelAction = UIAlertAction(title: cancelPrompt, style: UIAlertAction.Style.cancel) {
            UIAlertAction in
            self.buildEventYearMenu(currentYear: self.currentYearSetting)
        }
        
        // Add the actions
        alertController.addAction(okAction)
        alertController.addAction(cancelAction)
        
        // Present the controller
        self.present(alertController, animated: true, completion: nil)
    }
    
    @objc func displayWaitingMessage(){
        let waitingMessage = NSLocalizedString("waiting_for_data", comment: "")
        ToastMessages(waitingMessage).show(self, cellLocation: self.view.frame, placeHigh: false)
    }
    
    func networkDownWarning(){
        let alertController = UIAlertController(title: changeYearDialogBoxTitle, message: yearChangeAborted, preferredStyle: .alert)
        
        // Create the actions
        let okAction = UIAlertAction(title: okPrompt, style: UIAlertAction.Style.default) {
            UIAlertAction in
            self.buildEventYearMenu(currentYear: self.currentYearSetting)
            return
        }

        // Add the actions
        alertController.addAction(okAction)
        
        // Present the controller
        self.present(alertController, animated: true, completion: nil)
    }

    @objc func eventsOrBandsPrompt(){

        let alertController = UIAlertController(title: changeYearDialogBoxTitle, message: eventOrBandPrompt, preferredStyle: .alert)
        
        // Create the actions
        let bandAction = UIAlertAction(title:bandListButton, style: UIAlertAction.Style.default) {
            UIAlertAction in
            self.HideExpiredSwitch.isOn = true
            setHideExpireScheduleData(true)
            self.navigationController?.popViewController(animated: true)
            self.dismiss(animated: true, completion: nil)
        }
        // Add the actions
        alertController.addAction(bandAction)
        
        let eventAction = UIAlertAction(title:eventListButton, style: UIAlertAction.Style.default) {
            UIAlertAction in
            self.HideExpiredSwitch.isOn = false
            setHideExpireScheduleData(false)
            self.navigationController?.popViewController(animated: true)
            self.dismiss(animated: true, completion: nil)
        }
        // Add the actions
        alertController.addAction(eventAction)

        
        // Present the controller
        self.present(alertController, animated: true, completion: nil)
    }

    
    func lastYearWarningAccepted() async{
        
        let netTest = NetworkTesting()
        internetAvailble = netTest.forgroundNetworkTest(callingGui: self)
        
        if (internetAvailble == false){
            print("No internet connection is available, can NOT switch years at this time")
            
            networkDownWarning()
            return()
        }
        print ("Files were Ok, Pressed")
        

        print ("Files were Seeing last years data \(eventYearChangeAttempt)")
        
        setArtistUrl(eventYearChangeAttempt)
        setScheduleUrl(eventYearChangeAttempt)
        writeFiltersFile()
        cacheVariables.storePointerData = [String:String]()
        var pointerIndex = getScheduleUrl()
        
        print ("Files were Done setting \(pointerIndex)")
        do {
            try  FileManager.default.removeItem(atPath: scheduleFile)
            try  FileManager.default.removeItem(atPath: bandFile)

            print ("Files were removed")
        } catch {
            print ("Files were not removed..why?");
            //guess there was no file to delete
        }

        setMustSeeOn(true);
        setMightSeeOn(true);
        setWontSeeOn(true);
        setUnknownSeeOn(true);

        //clear all existing notifications
        let localNotification = localNoticationHandler()
        localNotification.clearNotifications();
        eventYear = Int(getPointerUrlData(keyValue: "eventYear"))!
        
        setupCurrentYearUrls()
        setupDefaults()
        
        print ("Refreshing data in backgroud..not really..\(eventYear)")
        var bandNamesHandle = bandNamesHandler()
        bandNamesHandle.gatherData()
        
        dataHandle = dataHandler()
        dataHandle.clearCachedData()
        dataHandle.readFile(dateWinnerPassed: "")
        NotificationCenter.default.post(name: Notification.Name(rawValue: "RefreshDisplay"), object: nil)
    }

}

extension String {
    var isYearValue: Bool {
        return self.range(
            of: "^\\d\\d\\d\\d$", options: .regularExpression) != nil
    }
}

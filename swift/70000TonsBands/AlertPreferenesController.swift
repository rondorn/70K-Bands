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
    
    var mustSeeAlertValue = Bool()
    var mightSeeAlertValue = Bool()
    var onlyAlertForAttendedValue = Bool()
    
    var alertForShowsValue = Bool()
    var alertForSpecialValue = Bool()
    var alertForMandGValue = Bool()
    var alertForClinicsValue = Bool()
    var alertForListeningValue = Bool()
    
    var alertForUnofficalEventsValue = Bool()
    
    var minBeforeAlertValue = Double()
    var notesFontSizeLargeValue = Bool()
    
    var minBeforeAlertLabel = String()
    var restartAlertTitle = String();
    var restartAlertText = String();
    var okPrompt = String();
    var cancelPrompt = String();
    var yearChangeAborted = String();
    var eventOrBandPrompt = String();
    var bandListButton = String()
    var eventListButton = String()
    
    var showSpecialValue = Bool()
    var showMandGValue = Bool()
    var showClinicsValue = Bool()
    var showListeningValue = Bool()
    
    var showPoolShows = Bool()
    var showTheaterShows = Bool()
    var showRinkShows = Bool()
    var showLoungeShows = Bool()
    var showOtherShows = Bool()
    var showUnofficalEvents = Bool()
    var hideExpireScheduleData = Bool()
    var promptForAttended = Bool()
    
    var eventYearChangeAttempt = "Current";
    var changeYearDialogBoxTitle = String();
    
    @IBOutlet weak var VenuePoolLabel: UILabel!
    @IBOutlet weak var VenueTheaterLabel: UILabel!
    @IBOutlet weak var VenueRinkLabel: UILabel!
    @IBOutlet weak var VenueLoungeLabel: UILabel!
    @IBOutlet weak var VenueOtherLabel: UILabel!
    
    
    @IBOutlet weak var DetailScreenSection: UILabel!
    @IBOutlet weak var NotesFontSizeLargeLabel: UILabel!
    @IBOutlet weak var NotesFontSizeLargeSwitch: UISwitch!
    
    @IBOutlet weak var showHideVenues: UILabel!
    @IBOutlet weak var VenuePoolSwitch: UISwitch!
    @IBOutlet weak var VenueTheaterSwitch: UISwitch!
    @IBOutlet weak var VenueRinkSwitch: UISwitch!
    @IBOutlet weak var VenueLoungeSwitch: UISwitch!
    @IBOutlet weak var VenueOtherSwitch: UISwitch!
    
    @IBOutlet weak var showHideEventType: UILabel!
    @IBOutlet weak var EventSpecialLabel: UILabel!
    @IBOutlet weak var EventMeetAndGreetLabel: UILabel!
    @IBOutlet weak var EventClinicLabel: UILabel!
    @IBOutlet weak var EventListeningPartyLabel: UILabel!
    @IBOutlet weak var EventCruiseOrganizedLabel: UILabel!
    
    @IBOutlet weak var EventSpecialSwitch: UISwitch!
    @IBOutlet weak var EventMeetAndGreetSwitch: UISwitch!
    @IBOutlet weak var EventClinicSwitch: UISwitch!
    @IBOutlet weak var EventListeningPartySwitch: UISwitch!
    @IBOutlet weak var EventCruiserOrganizedSwitch: UISwitch!
    
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
    var currentYearSetting = defaults.string(forKey: "scheduleUrl") ?? "Current"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        self.navigationItem.title = "Preferences - Build:" + versionInformation

        NotificationCenter.default.addObserver(self, selector: #selector(self.displayWaitingMessage), name: NSNotification.Name(rawValue: "DisplayWaitingMessage"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.eventsOrBandsPrompt), name: NSNotification.Name(rawValue: "EventsOrBandsPrompt"), object: nil)
        
        
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewWillDisappear(_ animated : Bool) {
        super.viewWillDisappear(animated)
        
        print ("sendLocalAlert! Running new code");
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
        
        showHideVenues.text =  NSLocalizedString("venueFilterHeader", comment: "")
        VenuePoolLabel.text = NSLocalizedString("PoolVenue", comment: "")
        VenueTheaterLabel.text = NSLocalizedString("TheaterVenue", comment: "")
        VenueRinkLabel.text = NSLocalizedString("RinkVenue", comment: "")
        VenueLoungeLabel.text = NSLocalizedString("LoungeVenue", comment: "")
        VenueOtherLabel.text = NSLocalizedString("OtherVenue", comment: "")
        
        VenuePoolLabel.textColor = getVenueColor(venue: venuePoolKey)
        VenueTheaterLabel.textColor = getVenueColor(venue: venueTheaterKey)
        VenueRinkLabel.textColor = getVenueColor(venue: venueRinkKey)
        VenueLoungeLabel.textColor = getVenueColor(venue: venueLoungeKey)
        VenueOtherLabel.textColor = getVenueColor(venue: "other")
        
        showHideEventType.text = NSLocalizedString("showTypeFilterHeader", comment: "")
        EventSpecialLabel.text = NSLocalizedString(specialEventType, comment: "")
        EventMeetAndGreetLabel.text = NSLocalizedString(meetAndGreetype, comment: "")
        EventClinicLabel.text = NSLocalizedString(clinicType, comment: "")
        EventListeningPartyLabel.text = NSLocalizedString(listeningPartyType, comment: "")
        EventCruiseOrganizedLabel.text =  NSLocalizedString(unofficalEventType, comment: "")
        
        NotesFontSizeLargeLabel.text = NSLocalizedString("NoteFontSize", comment: "")
        
        HideExpiredLabel.text = NSLocalizedString("showHideExpiredLabel", comment: "")
        HideExpiredSwitchLabel.text = NSLocalizedString("hideExpiredEvents", comment: "")
        
        PromptForAttendedLabel.text = NSLocalizedString("Prompt For Attended Status", comment: "")
        PromptForAttendedSwitchLabel.text = NSLocalizedString("Prompt For Attended Status", comment: "")
        
        selectYearLable.text = NSLocalizedString("SelectYearLabel", comment: "")
        
        var uidString = "Unknown"
        if (UIDevice.current.identifierForVendor != nil){
            if (UIDevice.current.identifierForVendor != nil){
                uidString = UIDevice.current.identifierForVendor!.uuidString
            }
        }
        userIDLabel.text = "UserID: " + uidString
        userIDLabel.adjustsFontSizeToFitWidth = true
    }
    
    func setExistingValues (){
        
        mustSeeAlertValue = defaults.bool(forKey: "mustSeeAlert")
        mightSeeAlertValue = defaults.bool(forKey: "mightSeeAlert")
        onlyAlertForAttendedValue = defaults.bool(forKey: "onlyAlertForAttended")
        
        alertForShowsValue = defaults.bool(forKey: "alertForShows")
        alertForSpecialValue = defaults.bool(forKey: "alertForSpecial")
        alertForMandGValue = defaults.bool(forKey: "alertForMandG")
        alertForClinicsValue = defaults.bool(forKey: "alertForClinics")
        alertForListeningValue = defaults.bool(forKey: "alertForListening")
        notesFontSizeLargeValue = defaults.bool(forKey: "notesFontSizeLarge")
        
        alertForUnofficalEventsValue = defaults.bool(forKey: "alertForUnofficalEvents")
        
        minBeforeAlertValue = Double(defaults.integer(forKey: "minBeforeAlert"))
        
        AlertOnMustSee.isOn = mustSeeAlertValue
        AlertOnMightSee.isOn = mightSeeAlertValue
        AlertOnlyForAttended.isOn = onlyAlertForAttendedValue
        
        MinBeforeAlert.text = String(format: "%.0f", minBeforeAlertValue)
        AlertForShows.isOn = alertForShowsValue
        AlertForSpecialEvents.isOn = alertForSpecialValue
        AlertForMeetAndGreets.isOn = alertForMandGValue
        AlertForClinic.isOn = alertForClinicsValue
        AlertForListeningEvent.isOn = alertForListeningValue
        alertForUnofficalEvents.isOn = alertForUnofficalEventsValue
        NotesFontSizeLargeSwitch.isOn = notesFontSizeLargeValue
        
        self.MinBeforeAlert.delegate = self
        
        print ("getPointerUrlData: lastYear setting is \(defaults.string(forKey: "scheduleUrl")) in AlertPrefs")
        
        showSpecialValue = defaults.bool(forKey: "showSpecial")
        showMandGValue = defaults.bool(forKey: "showMandG")
        showClinicsValue = defaults.bool(forKey: "showClinics")
        showListeningValue = defaults.bool(forKey: "showListening")
        
        showPoolShows = defaults.bool(forKey: "showPoolShows")
        showTheaterShows = defaults.bool(forKey: "showTheaterShows")
        showRinkShows = defaults.bool(forKey: "showRinkShows")
        showLoungeShows = defaults.bool(forKey: "showLoungeShows")
        showOtherShows = defaults.bool(forKey: "showOtherShows")
        showUnofficalEvents = defaults.bool(forKey: "showUnofficalEvents")
        hideExpireScheduleData = defaults.bool(forKey: "hideExpireScheduleData")
        promptForAttended = defaults.bool(forKey: "promptForAttended")
        
        
        EventSpecialSwitch.isOn = showSpecialValue;
        EventMeetAndGreetSwitch.isOn = showMandGValue;
        EventClinicSwitch.isOn = showClinicsValue;
        EventListeningPartySwitch.isOn = showListeningValue;
        
        VenuePoolSwitch.isOn = showPoolShows;
        VenueTheaterSwitch.isOn = showTheaterShows;
        VenueRinkSwitch.isOn = showRinkShows;
        VenueLoungeSwitch.isOn = showLoungeShows;
        VenueOtherSwitch.isOn = showOtherShows;
        EventCruiserOrganizedSwitch.isOn = showUnofficalEvents
        HideExpiredSwitch.isOn = hideExpireScheduleData
        PromptForAttendedSwitch.isOn = promptForAttended
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
    
    
    @IBAction func MinBeforeAlertAction() {
        
        let minBeforeAlertTemp = Int(MinBeforeAlert.text!)
        
        if (minBeforeAlertTemp >= 0 && minBeforeAlertTemp <= 60){
            defaults.set(minBeforeAlertTemp!, forKey: "minBeforeAlert")
            MinBeforeAlert.resignFirstResponder()
            
            let localNotification = localNoticationHandler()
            localNotification.clearNotifications()
            
        } else {
            
            MinBeforeAlert.resignFirstResponder()
            MinBeforeAlert.text = String(format: "%.0f", minBeforeAlertValue)
            let alert = UIAlertView()
            alert.title = "Number Provided Is Invalid"
            alert.message =  "Number Provided Is Invalid\nMust be a value between 0 and 60"
            alert.addButton(withTitle: okPrompt)
            alert.show()
        }
        
    }
    
    @IBAction func MustSeeChange() {
        defaults.set(AlertOnMustSee.isOn, forKey: "mustSeeAlert")
    }
    
    @IBAction func MightSeeChange() {
        defaults.set(AlertOnMightSee.isOn, forKey: "mightSeeAlert")
    }
    
    @IBAction func AlertOnlyForAttendedChange() {
        defaults.set(AlertOnlyForAttended.isOn, forKey: "onlyAlertForAttended")
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
        defaults.set(AlertForShows.isOn, forKey: "alertForShows")
    }
    
    @IBAction func AlertForSpecialEventChange() {
        defaults.set(AlertForSpecialEvents.isOn, forKey: "alertForSpecial")
    }
    
    @IBAction func AlertForMeetAndGreetChange() {
        defaults.set(AlertForMeetAndGreets.isOn, forKey: "alertForMandG")
    }
    
    @IBAction func AlertForClinicChange() {
        defaults.set(AlertForClinic.isOn, forKey: "alertForClinics")
    }
    
    @IBAction func AlertForListeningEventChange() {
        defaults.set(AlertForListeningEvent.isOn, forKey: "alertForListening")
    }
    
    @IBAction func backgroundTap (_ sender: UIControl){
        MinBeforeAlert.resignFirstResponder()
    }
    
    @IBAction func alertForUnofficalEventChange(_ sender: Any) {
        defaults.set(alertForUnofficalEvents.isOn, forKey: "alertForUnofficalEvents")
    }
    
    @IBAction func venuePool(_ sender: Any) {
        defaults.set(VenuePoolSwitch.isOn, forKey: "showPoolShows")
    }
    
    @IBAction func venueTheater(_ sender: Any) {
        defaults.set(VenueTheaterSwitch.isOn, forKey: "showTheaterShows")
    }
    
    @IBAction func venueRink(_ sender: Any) {
        defaults.set(VenueRinkSwitch.isOn, forKey: "showRinkShows")
    }
    
    @IBAction func venueLounge(_ sender: Any) {
        defaults.set(VenueLoungeSwitch.isOn, forKey: "showLoungeShows")
    }
    
    @IBAction func venueOther(_ sender: Any) {
        defaults.set(VenueOtherSwitch.isOn, forKey: "showOtherShows")
    }
    
    @IBAction func eventSpecial(_ sender: Any) {
        defaults.set(EventSpecialSwitch.isOn, forKey: "showSpecial")
    }
    
    @IBAction func eventMeetAndGreet(_ sender: Any) {
        defaults.set(EventMeetAndGreetSwitch.isOn, forKey: "showMandG")
    }
    
    @IBAction func eventClinic(_ sender: Any) {
        defaults.set(EventClinicSwitch.isOn, forKey: "showClinics")
    }
    
    @IBAction func eventListeningParty(_ sender: Any) {
        defaults.set(EventListeningPartySwitch.isOn, forKey: "showListening")
    }
    
    @IBAction func eventCruiseOrganized(_ sender: Any) {
        defaults.set(EventCruiserOrganizedSwitch.isOn, forKey: "showUnofficalEvents")
    }
    
    @IBAction func hideExpired(_ sender: Any) {
        defaults.set(HideExpiredSwitch.isOn, forKey: "hideExpireScheduleData")
    }
    
    @IBAction func promptForAttended(_ sender: Any) {
        defaults.set(PromptForAttendedSwitch.isOn, forKey: "promptForAttended")
    }
    
    @IBAction func notesFontSizeLarge(_ sender: Any) {
        defaults.set(NotesFontSizeLargeSwitch.isOn, forKey: "notesFontSizeLarge")
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
                        defaults.setValue(true, forKey: "hideExpireScheduleData")
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
            defaults.setValue(true, forKey: "hideExpireScheduleData")
            self.navigationController?.popViewController(animated: true)
            self.dismiss(animated: true, completion: nil)
        }
        // Add the actions
        alertController.addAction(bandAction)
        
        let eventAction = UIAlertAction(title:eventListButton, style: UIAlertAction.Style.default) {
            UIAlertAction in
            self.HideExpiredSwitch.isOn = false
            defaults.setValue(false, forKey: "hideExpireScheduleData")
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
        defaults.setValue(eventYearChangeAttempt, forKey: "artistUrl")
        defaults.setValue(eventYearChangeAttempt, forKey: "scheduleUrl")
        
        cacheVariables.storePointerData = [String:String]()
        var pointerIndex = defaults.string(forKey: "scheduleUrl") ?? "Default"
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

        dataHandle.writeFiltersFile();
        
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

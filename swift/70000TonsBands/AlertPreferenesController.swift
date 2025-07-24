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
    
    // Track the latest data load request
    static var currentLoadRequestID: Int = 0
    var myLoadRequestID: Int = 0
    
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
    
    /// Called after the controller's view is loaded into memory. Sets up UI, observers, and initial values.
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Ensure back button always says "Back"
        let backItem = UIBarButtonItem()
        backItem.title = "Back"
        self.navigationItem.backBarButtonItem = backItem
        
        filterMenuNeedsUpdating = true
        let screenSize: CGRect = UIScreen.main.bounds
        var screenHeight = screenSize.height
        let screenWidth = screenSize.width
        
        if (screenWidth < 350){
            screenHeight = 1200;
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
    
    /// Specifies the preferred status bar style for this view controller.
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    /// Called just before the view appears. Ensures the back button is labeled correctly.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Ensure back button always says "Back" when navigating from this view
        let backItem = UIBarButtonItem()
        backItem.title = "Back"
        self.navigationItem.backBarButtonItem = backItem
    }
    
    /// Called just before the view disappears. Resets local notifications and refreshes the master view.
    override func viewWillDisappear(_ animated : Bool) {
        super.viewWillDisappear(animated)
        
        //reset alerts
        let localNotification = localNoticationHandler()
        localNotification.clearNotifications()
        localNotification.addNotifications()
        
        // Perform data loading in the background
        DispatchQueue.global(qos: .background).async {
            //print ("Sync: Loading schedule data AlertController")
            masterView.bandNameHandle.gatherData()
            masterView.schedule.DownloadCsv()
            masterView.schedule.populateSchedule(forceDownload: false)
            
            // Once done, refresh the GUI on the main thread
            DispatchQueue.main.async {
                masterView.refreshData(isUserInitiated: true)
            }
        }
    }
    
    /// Builds the event year menu for selecting different event years.
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
    
    /// Handles the event year change action and triggers the use of last year's data if needed.
    func eventYearDidChange(year: String){
        print("Selected index \(year)")
        
        var yearChange = year;
        
        if (yearChange.isYearValue == false){
            yearChange = "Current"
        }
        
        eventYearChangeAttempt = yearChange
        // Increment the global request ID and store for this load
        AlertPreferenesController.currentLoadRequestID += 1
        myLoadRequestID = AlertPreferenesController.currentLoadRequestID
        // Always purge caches and reload everything, even for 'Current' year
        bandNamesHandler().clearCachedData()
        dataHandler().clearCachedData()
        masterView.schedule.clearCache()
        
        UseLastYearsDataAction()
    }
    
    /// Sets all localized labels and prompt strings for the UI.
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
        
        if let uidString = UIDevice.current.identifierForVendor?.uuidString {
            userIDLabel.text = "UserID:\t" + uidString + "\nBuild:\t" + versionInformation + "\nVersion: "
            userIDLabel.text = userIDLabel.text! + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String)
            userIDLabel.numberOfLines = 2
            userIDLabel.adjustsFontSizeToFitWidth = true
        } else {
            print("AlertPreferenesController: ERROR - UIDevice identifierForVendor is nil, cannot set uidString")
        }
    }
    
    /// Sets the UI elements to reflect the current saved preference values.
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
    
    /// UITextFieldDelegate method. Dismisses the keyboard when return is pressed.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true);
        return false;
    }
    
    /// Enables or disables alert-related buttons based on the 'AlertOnlyForAttended' switch.
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
            
            mustSeeAlertLable.textColor = .darkGray
            mightSeeAlertLable.textColor = .darkGray
            alertForShowsLable.textColor = .darkGray
            alertForSpecialLable.textColor = .darkGray
            alertForMandGLable.textColor = .darkGray
            alertForClinicsLable.textColor = .darkGray
            alertForListeningLable.textColor = .darkGray
            alertForUnofficalEventsLable.textColor = .darkGray
            
        } else {
            AlertOnMustSee.isEnabled = true;
            AlertOnMightSee.isEnabled = true;
            AlertForShows.isEnabled = true;
            AlertForSpecialEvents.isEnabled = true;
            AlertForMeetAndGreets.isEnabled = true;
            AlertForClinic.isEnabled = true;
            AlertForListeningEvent.isEnabled = true;
            alertForUnofficalEvents.isEnabled = true;
            
            mustSeeAlertLable.textColor = .white
            mightSeeAlertLable.textColor = .white
            alertForShowsLable.textColor = .white
            alertForSpecialLable.textColor = .white
            alertForMandGLable.textColor = .white
            alertForClinicsLable.textColor = .white
            alertForListeningLable.textColor = .white
            alertForUnofficalEventsLable.textColor = .white
        }
    }
    
    /// Called when editing ends in the 'MinBeforeAlert' text field. Used for debugging.
    @IBAction func MinBeforeAlertEndAction() {
        print ("MinBeforeAlert ENDING text is \(MinBeforeAlert.text)")
    }
    
    /// Called when the 'MinBeforeAlert' value is changed. Validates and saves the value, or shows an error.
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
    
    /// Called when the 'Must See' alert switch is toggled. Saves the new value.
    @IBAction func MustSeeChange() {
        setMustSeeAlertValue(AlertOnMustSee.isOn)
    }
    
    /// Called when the 'Might See' alert switch is toggled. Saves the new value.
    @IBAction func MightSeeChange() {
        setMightSeeAlertValue(AlertOnMightSee.isOn)
    }
    
    /// Called when the 'Alert Only For Attended' switch is toggled. Updates state and shows a help message.
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
    
    /// Called when the 'Alert For Shows' switch is toggled. Saves the new value.
    @IBAction func AlertForShowsChange() {
        setAlertForShowsValue(AlertForShows.isOn)
    }
    
    /// Called when the 'Alert For Special Events' switch is toggled. Saves the new value.
    @IBAction func AlertForSpecialEventChange() {
        setAlertForSpecialValue(AlertForSpecialEvents.isOn)
    }

    /// Called when the 'Alert For Clinic' switch is toggled. Saves the new value.
    @IBAction func AlertForClinicChange() {
        setAlertForClinicEvents(AlertForClinic.isOn)
    }
    
    /// Called when the 'Alert For Listening Event' switch is toggled. Saves the new value.
    @IBAction func AlertForListeningEventChange() {
        setAlertForListeningEvents(AlertForListeningEvent.isOn)
    }
    
    
    /// Called when the 'Alert For Meet And Greet' switch is toggled. Saves the new value.
    @IBAction func AlertForMeetAndGreetChange() {
        setAlertForMandGValue(AlertForMeetAndGreets.isOn)
    }
    
    /// Dismisses the keyboard when the background is tapped.
    @IBAction func backgroundTap (_ sender: UIControl){
        MinBeforeAlert.resignFirstResponder()
    }
    
    /// Called when the 'Alert For Unofficial Events' switch is toggled. Saves the new value.
    @IBAction func alertForUnofficalEventChange(_ sender: Any) {
        setAlertForUnofficalEventsValue(alertForUnofficalEvents.isOn)
    }
    
    /// Called when the 'Hide Expired' switch is toggled. Saves the new value and logs the change.
    @IBAction func hideExpired(_ sender: Any) {
        setHideExpireScheduleData(HideExpiredSwitch.isOn)
        print ("Loading showExpired Writing \(HideExpiredSwitch.isOn) to hideExpireScheduleDataBoolean")
    }
    
    /// Called when the 'Prompt For Attended' switch is toggled. Saves the new value.
    @IBAction func promptForAttended(_ sender: Any) {
        setPromptForAttended(PromptForAttendedSwitch.isOn)
    }
    
    /// Called when the 'Notes Font Size Large' switch is toggled. Saves the new value.
    @IBAction func notesFontSizeLarge(_ sender: Any) {
        setNotesFontSizeLargeValue(NotesFontSizeLargeSwitch.isOn)
    }
    
    /// Handles the action to use last year's data, showing a confirmation dialog and updating state as needed.
    @IBAction func UseLastYearsDataAction() {
        
        print ("Files were in UseLastYearsDataAction")
        
        let alertController = UIAlertController(title: changeYearDialogBoxTitle, message: restartAlertText, preferredStyle: .alert)
        
        // Create the actions
        let okActionButton = UIAlertAction(title: okPrompt, style: .default) { _ in
            NotificationCenter.default.post(name: Notification.Name(rawValue: "DisplayWaitingMessage"), object: nil)
            Task{
                await self.lastYearWarningAccepted()
                await DispatchQueue.global(qos: DispatchQoS.QoSClass.default).sync {
                    if (self.eventYearChangeAttempt.isYearValue == false){
                        // For "Current" year, automatically use Band List without asking
                        self.HideExpiredSwitch.isOn = true
                        setHideExpireScheduleData(true)
                        masterView.refreshData(isUserInitiated: true)
                        self.navigationController?.popViewController(animated: true)
                        self.dismiss(animated: true, completion: nil)
                    } else {
                        // For specific years, show the dialog to let user choose
                        NotificationCenter.default.post(name: Notification.Name(rawValue: "EventsOrBandsPrompt"), object: nil)
                    }
                }
            }
        }
        let cancelActionButton = UIAlertAction(title: cancelPrompt, style: .cancel) { _ in
            self.buildEventYearMenu(currentYear: self.currentYearSetting)
        }
        
        // Add the actions
        alertController.addAction(okActionButton)
        alertController.addAction(cancelActionButton)
        
        // Present the controller
        self.present(alertController, animated: true, completion: nil)
    }
    
    /// Displays a toast message indicating that the app is waiting for data.
    @objc func displayWaitingMessage(){
        let waitingMessage = NSLocalizedString("waiting_for_data", comment: "")
        ToastMessages(waitingMessage).show(self, cellLocation: self.view.frame, placeHigh: false)
    }
    
    /// Shows a warning dialog if the network is down when attempting to change years.
    func networkDownWarning(){
        let alertController = UIAlertController(title: changeYearDialogBoxTitle, message: yearChangeAborted, preferredStyle: .alert)
        
        // Create the actions
        let okAction = UIAlertAction(title: okPrompt, style: .default) { _ in
            self.buildEventYearMenu(currentYear: self.currentYearSetting)
            return
        }

        // Add the actions
        alertController.addAction(okAction)
        
        // Present the controller
        self.present(alertController, animated: true, completion: nil)
    }

    /// Prompts the user to choose between events or bands when changing years.
    @objc func eventsOrBandsPrompt(){

        let alertController = UIAlertController(title: changeYearDialogBoxTitle, message: eventOrBandPrompt, preferredStyle: .alert)
        
        // Create the actions
        let bandAction = UIAlertAction(title:bandListButton, style: .default) { _ in
            self.HideExpiredSwitch.isOn = true
            setHideExpireScheduleData(true)
            // Always proceed regardless of schedule status
            masterView.refreshData(isUserInitiated: true)
            self.navigationController?.popViewController(animated: true)
            self.dismiss(animated: true, completion: nil)
        }
        // Add the actions
        alertController.addAction(bandAction)
        
        let eventAction = UIAlertAction(title:eventListButton, style: .default) { _ in
            self.HideExpiredSwitch.isOn = false
            setHideExpireScheduleData(false)
            // Always proceed regardless of schedule status
            masterView.refreshData(isUserInitiated: true)
            self.navigationController?.popViewController(animated: true)
            self.dismiss(animated: true, completion: nil)
        }
        // Add the actions
        alertController.addAction(eventAction)

        
        // Present the controller
        self.present(alertController, animated: true, completion: nil)
    }

    
    /// Handles the acceptance of the last year warning, updates URLs, clears data, and refreshes the app state.
    func lastYearWarningAccepted() async{
        
        let netTest = NetworkTesting()
        internetAvailble = netTest.forgroundNetworkTest(callingGui: self)
        
        if (internetAvailble == false){
            print("No internet connection is available, can NOT switch years at this time")
            
            networkDownWarning()
            return()
        }
        // LOCK GUI: Disable user interaction until data is loaded
        DispatchQueue.main.async {
            self.view.isUserInteractionEnabled = false
        }
        print ("Files were in UseLastYearsDataAction")
        
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
        
        // --- Purge all caches before loading new data ---
        bandNamesHandler().clearCachedData()
        dataHandler().clearCachedData()
        masterView.schedule.clearCache()
        // --- Refactored: Wait for both band and schedule data to load before proceeding ---
        let group = DispatchGroup()
        // Increment the global request ID and store for this load
        AlertPreferenesController.currentLoadRequestID += 1
        let thisLoadRequestID = AlertPreferenesController.currentLoadRequestID
        
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            let bandNamesHandle = bandNamesHandler()
            bandNamesHandle.clearCachedData()
            bandNamesHandle.gatherData {
                group.leave()
            }
        }
        
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            let dataHandle = dataHandler()
            dataHandle.clearCachedData()
            dataHandle.readFile(dateWinnerPassed: "")
            masterView.schedule.clearCache()
            
            // Ensure CSV is downloaded before populating schedule
            print("Year change: Downloading schedule CSV first")
            masterView.schedule.DownloadCsv()
            
            // Wait for file to be written and verify it exists
            var attempts = 0
            while !FileManager.default.fileExists(atPath: scheduleFile) && attempts < 10 {
                Thread.sleep(forTimeInterval: 0.2)
                attempts += 1
                print("Year change: Waiting for schedule file to be written (attempt \(attempts))")
            }
            
            if FileManager.default.fileExists(atPath: scheduleFile) {
                print("Year change: Schedule file downloaded successfully, now populating")
                masterView.schedule.populateSchedule(forceDownload: false) // Don't force download since we already did it
            } else {
                print("Year change: Schedule file download failed, will retry in populateSchedule")
                masterView.schedule.populateSchedule(forceDownload: true) // Force download as fallback
            }
            
            group.leave()
        }
        
        group.notify(queue: .main) {
            // Only update UI if this is the latest request
            if thisLoadRequestID != AlertPreferenesController.currentLoadRequestID { return }
            // Now all data is loaded, allow user to proceed (refresh UI, dismiss waiting message, etc.)
            // Ensure schedule is parsed before UI refresh
            masterView.schedule.populateSchedule(forceDownload: false)
            NotificationCenter.default.post(name: Notification.Name(rawValue: "RefreshDisplay"), object: nil)
            // UNLOCK GUI: Re-enable user interaction
            self.view.isUserInteractionEnabled = true
            // Don't dismiss the Preferences screen - let the user make their choice
            // The navigation will happen when they select Band List or Event List
        }
    }

}

extension String {
    var isYearValue: Bool {
        return self.range(
            of: "^\\d\\d\\d\\d$", options: .regularExpression) != nil
    }
}

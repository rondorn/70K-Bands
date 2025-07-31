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
    
    var yearChagingTo = "Current";
    
    var eventYearChangeAttempt = "Current";
    var changeYearDialogBoxTitle = String();
    
    // Track the latest data load request
    static var currentLoadRequestID: Int = 0
    var myLoadRequestID: Int = 0
    
    // Track data loading request IDs to cancel outdated requests
    static var currentBandDataRequestID: Int = 0
    static var currentScheduleDataRequestID: Int = 0
    
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
        // Cancel any ongoing data loading processes
        print("[YEAR_CHANGE_DEBUG] Canceling ongoing data loading processes for year change")
        isLoadingBandData = false
        isLoadingSchedule = false
        
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
                        // Show persistent waiting overlay for automatic Band List selection
                        DispatchQueue.main.async {
                            self.showPersistentWaitingOverlay()
                        }
                        
                        self.HideExpiredSwitch.isOn = true
                        setHideExpireScheduleData(true)
                        masterView.refreshData(isUserInitiated: true)
                        
                        // Use sophisticated navigation that waits for data to be ready
                        self.navigateBackWithDataDelay()
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
    
    /// Shows a persistent waiting overlay that stays visible until navigation completes
    func showPersistentWaitingOverlay() {
        DispatchQueue.main.async {
            // Create a full-screen overlay
            let overlayView = UIView(frame: self.view.bounds)
            overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            overlayView.tag = 999 // Tag for easy removal
            
            // Create activity indicator
            let activityIndicator = UIActivityIndicatorView(style: .large)
            activityIndicator.color = .white
            activityIndicator.center = overlayView.center
            activityIndicator.startAnimating()
            
            // Create label
            let label = UILabel()
            label.text = NSLocalizedString("waiting_for_data", comment: "")
            label.textColor = .white
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            label.numberOfLines = 0
            
            // Position label below activity indicator
            label.frame = CGRect(x: 0, y: 0, width: overlayView.bounds.width - 40, height: 60)
            label.center = CGPoint(x: overlayView.center.x, y: overlayView.center.y + 50)
            
            // Add subviews
            overlayView.addSubview(activityIndicator)
            overlayView.addSubview(label)
            
            // Add to view hierarchy
            self.view.addSubview(overlayView)
            self.view.bringSubviewToFront(overlayView)
            
            print("[YEAR_CHANGE_DEBUG] Persistent waiting overlay displayed")
        }
    }
    
    /// Removes the persistent waiting overlay
    func hidePersistentWaitingOverlay() {
        DispatchQueue.main.async {
            if let overlayView = self.view.viewWithTag(999) {
                overlayView.removeFromSuperview()
                print("[YEAR_CHANGE_DEBUG] Persistent waiting overlay removed")
            }
        }
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
            // Show persistent waiting overlay immediately when user makes choice
            self.showPersistentWaitingOverlay()
            
            self.HideExpiredSwitch.isOn = true
            setHideExpireScheduleData(true)
            // Always proceed regardless of schedule status
            masterView.refreshData(isUserInitiated: true)
            
            // Use sophisticated navigation that waits for data to be ready
            self.navigateBackWithDataDelay()
        }
        // Add the actions
        alertController.addAction(bandAction)
        
        let eventAction = UIAlertAction(title:eventListButton, style: .default) { _ in
            // Show persistent waiting overlay immediately when user makes choice
            self.showPersistentWaitingOverlay()
            
            self.HideExpiredSwitch.isOn = false
            setHideExpireScheduleData(false)
            // Always proceed regardless of schedule status
            masterView.refreshData(isUserInitiated: true)
            
            // Use sophisticated navigation that waits for data to be ready
            self.navigateBackWithDataDelay()
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
        
        print("[YEAR_CHANGE_DEBUG] lastYearWarningAccepted: Setting URLs for year \(eventYearChangeAttempt)")
        setArtistUrl(eventYearChangeAttempt)
        setScheduleUrl(eventYearChangeAttempt)
        writeFiltersFile()
        cacheVariables.storePointerData = [String:String]()
        var pointerIndex = getScheduleUrl()
        
        print("[YEAR_CHANGE_DEBUG] lastYearWarningAccepted: pointerIndex=\(pointerIndex), artistUrl=\(getArtistUrl()), scheduleUrl=\(getScheduleUrl())")
        do {
            try  FileManager.default.removeItem(atPath: scheduleFile)
            try  FileManager.default.removeItem(atPath: bandFile)
            try  FileManager.default.removeItem(atPath: eventYearFile)

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
        
        // Clear the pointer data cache to ensure fresh data
        cacheVariables.storePointerData = [String:String]()
        
        setupCurrentYearUrls()
        setupDefaults()
        
        // Now get the event year after cache is cleared
        eventYear = Int(getPointerUrlData(keyValue: "eventYear"))!
        
        print ("Refreshing data in backgroud..not really..\(eventYear)")
        
        // --- Purge all caches before loading new data ---
        bandNamesHandler().clearCachedData()
        dataHandler().clearCachedData()
        masterView.schedule.clearCache()
        
        // Clear static caches to ensure fresh data
        staticSchedule.sync {
            cacheVariables.scheduleStaticCache = [:]
            cacheVariables.scheduleTimeStaticCache = [:]
            cacheVariables.bandNamesStaticCache = [:]
        }
        // --- Refactored: Wait for both band and schedule data to load before proceeding ---
        let group = DispatchGroup()
        // Increment the global request ID and store for this load
        AlertPreferenesController.currentLoadRequestID += 1
        let thisLoadRequestID = AlertPreferenesController.currentLoadRequestID
        
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            // Increment and store request ID for this band data load
            AlertPreferenesController.currentBandDataRequestID += 1
            let thisBandRequestID = AlertPreferenesController.currentBandDataRequestID
            
            print("[YEAR_CHANGE_DEBUG] Starting band names data loading for year \(self.eventYearChangeAttempt) (request \(thisBandRequestID))")
            let bandNamesHandle = bandNamesHandler()
            bandNamesHandle.clearCachedData()
            bandNamesHandle.gatherData {
                // Only proceed if this is still the current request
                if thisBandRequestID == AlertPreferenesController.currentBandDataRequestID {
                    print("[YEAR_CHANGE_DEBUG] Band names data loading completed for year \(self.eventYearChangeAttempt) (request \(thisBandRequestID))")
                } else {
                    print("[YEAR_CHANGE_DEBUG] Band names data loading cancelled - outdated request \(thisBandRequestID) vs current \(AlertPreferenesController.currentBandDataRequestID)")
                }
                group.leave()
            }
        }
        
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            // Increment and store request ID for this schedule data load
            AlertPreferenesController.currentScheduleDataRequestID += 1
            let thisScheduleRequestID = AlertPreferenesController.currentScheduleDataRequestID
            
            print("[YEAR_CHANGE_DEBUG] Starting schedule data loading for year \(self.eventYearChangeAttempt) (request \(thisScheduleRequestID))")
            let dataHandle = dataHandler()
            dataHandle.clearCachedData()
            dataHandle.readFile(dateWinnerPassed: "")
            masterView.schedule.clearCache()
            
            // Check if this request is still current before proceeding
            if thisScheduleRequestID != AlertPreferenesController.currentScheduleDataRequestID {
                print("[YEAR_CHANGE_DEBUG] Schedule data loading cancelled - outdated request \(thisScheduleRequestID) vs current \(AlertPreferenesController.currentScheduleDataRequestID)")
                group.leave()
                return
            }
            
            // Ensure CSV is downloaded before populating schedule
            print("[YEAR_CHANGE_DEBUG] Downloading schedule CSV first")
            masterView.schedule.DownloadCsv()
            
            // Wait for file to be written and verify it exists
            var attempts = 0
            while !FileManager.default.fileExists(atPath: scheduleFile) && attempts < 10 {
                // Check if request is still current during wait
                if thisScheduleRequestID != AlertPreferenesController.currentScheduleDataRequestID {
                    print("[YEAR_CHANGE_DEBUG] Schedule data loading cancelled during file wait - outdated request \(thisScheduleRequestID)")
                    group.leave()
                    return
                }
                Thread.sleep(forTimeInterval: 0.2)
                attempts += 1
                print("[YEAR_CHANGE_DEBUG] Waiting for schedule file to be written (attempt \(attempts))")
            }
            
            // Final check before populating
            if thisScheduleRequestID != AlertPreferenesController.currentScheduleDataRequestID {
                print("[YEAR_CHANGE_DEBUG] Schedule data loading cancelled before population - outdated request \(thisScheduleRequestID)")
                group.leave()
                return
            }
            
            if FileManager.default.fileExists(atPath: scheduleFile) {
                print("[YEAR_CHANGE_DEBUG] Schedule file downloaded successfully, now populating")
                masterView.schedule.populateSchedule(forceDownload: false) // Don't force download since we already did it
            } else {
                print("[YEAR_CHANGE_DEBUG] Schedule file download failed, will retry in populateSchedule")
                masterView.schedule.populateSchedule(forceDownload: true) // Force download as fallback
            }
            
            print("[YEAR_CHANGE_DEBUG] Schedule data loading completed for year \(self.eventYearChangeAttempt) (request \(thisScheduleRequestID))")
            group.leave()
        }
        
        group.notify(queue: .main) {
            print("[YEAR_CHANGE_DEBUG] All data loading completed for year \(self.eventYearChangeAttempt)")
            // Only update UI if this is the latest request
            if thisLoadRequestID != AlertPreferenesController.currentLoadRequestID { 
                print("[YEAR_CHANGE_DEBUG] Ignoring outdated request \(thisLoadRequestID) vs current \(AlertPreferenesController.currentLoadRequestID)")
                return 
            }
            // Now all data is loaded, allow user to proceed (refresh UI, dismiss waiting message, etc.)
            // Don't call populateSchedule again - it was already called in the background tasks
            NotificationCenter.default.post(name: Notification.Name(rawValue: "RefreshDisplay"), object: nil)
            // UNLOCK GUI: Re-enable user interaction
            self.view.isUserInteractionEnabled = true
            print("[YEAR_CHANGE_DEBUG] UI unlocked and refresh notification sent for year \(self.eventYearChangeAttempt)")
            // Don't dismiss the Preferences screen - let the user make their choice
            // The navigation will happen when they select Band List or Event List
        }
    }


    
    /// Navigates back to MasterViewController with a simple delay to allow data loading to complete
    func navigateBackWithDataDelay() {
        // Enhanced delay to account for retry logic: wait 8 seconds then navigate back
        // This gives enough time for background processes including retries to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            print("[YEAR_CHANGE_DEBUG] Navigating back after enhanced delay")
            // Remove the persistent overlay before navigating
            self.hidePersistentWaitingOverlay()
            self.navigationController?.popViewController(animated: true)
            self.dismiss(animated: true, completion: nil)
        }
    }

}

extension String {
    var isYearValue: Bool {
        return self.range(
            of: "^\\d\\d\\d\\d$", options: .regularExpression) != nil
    }
}

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
        
        // Configure labels for multiline text after view setup
        configureLabelsForMultilineText()
        
        // Update scroll view size after all setup is complete
        updateScrollViewContentSize()

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
        
        // Ensure labels are configured for multiline text
        configureLabelsForMultilineText()
        
        // Update scroll view size when view appears
        updateScrollViewContentSize()
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
        alertPreferenceHeader.numberOfLines = 0
        alertPreferenceHeader.adjustsFontSizeToFitWidth = true
        
        mustSeeAlertLable.text = NSLocalizedString("Alert On Must See Bands", comment: "")
        mustSeeAlertLable.numberOfLines = 0
        mustSeeAlertLable.adjustsFontSizeToFitWidth = true
        
        mightSeeAlertLable.text = NSLocalizedString("Alert On Might See Bands", comment: "")
        mightSeeAlertLable.numberOfLines = 0
        mightSeeAlertLable.adjustsFontSizeToFitWidth = true
        
        onlyAlertForAttendedLable.text = NSLocalizedString("Alert Only for Will Attend Events", comment: "")
        onlyAlertForAttendedLable.numberOfLines = 0
        onlyAlertForAttendedLable.adjustsFontSizeToFitWidth = true
        
        minBeforeAlertLable.text = NSLocalizedString("Minutes Before Event to Alert", comment: "")
        minBeforeAlertLable.numberOfLines = 0
        minBeforeAlertLable.adjustsFontSizeToFitWidth = true
        
        alertForShowsLable.text = NSLocalizedString("Alert For Shows", comment: "")
        alertForShowsLable.numberOfLines = 0
        alertForShowsLable.adjustsFontSizeToFitWidth = true
        
        alertForSpecialLable.text = NSLocalizedString("Alert For Special Events", comment: "")
        alertForSpecialLable.numberOfLines = 0
        alertForSpecialLable.adjustsFontSizeToFitWidth = true
        
        alertForMandGLable.text = NSLocalizedString("Alert For Meeting and Greet Events", comment: "")
        alertForMandGLable.numberOfLines = 0
        alertForMandGLable.adjustsFontSizeToFitWidth = true
        
        alertForClinicsLable.text = NSLocalizedString("Alert For Clinics", comment: "")
        alertForClinicsLable.numberOfLines = 0
        alertForClinicsLable.adjustsFontSizeToFitWidth = true
        
        alertForListeningLable.text  = NSLocalizedString("Alert For Album Listening Events", comment: "")
        alertForListeningLable.numberOfLines = 0
        alertForListeningLable.adjustsFontSizeToFitWidth = true
        
        alertForUnofficalEventsLable.text = NSLocalizedString("Alert For Unofficial Events", comment: "")
        alertForUnofficalEventsLable.numberOfLines = 0
        alertForUnofficalEventsLable.adjustsFontSizeToFitWidth = true
        
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
        NotesFontSizeLargeLabel.numberOfLines = 0
        NotesFontSizeLargeLabel.adjustsFontSizeToFitWidth = true
        
        HideExpiredLabel.text = NSLocalizedString("showHideExpiredLabel", comment: "")
        HideExpiredLabel.numberOfLines = 0
        HideExpiredLabel.adjustsFontSizeToFitWidth = true
        
        HideExpiredSwitchLabel.text = NSLocalizedString("hideExpiredEvents", comment: "")
        HideExpiredSwitchLabel.numberOfLines = 0
        HideExpiredSwitchLabel.adjustsFontSizeToFitWidth = true
        
        PromptForAttendedLabel.text = NSLocalizedString("Prompt For Attended Status Header", comment: "")
        PromptForAttendedLabel.numberOfLines = 0
        PromptForAttendedLabel.adjustsFontSizeToFitWidth = true
        
        PromptForAttendedSwitchLabel.text = NSLocalizedString("Prompt For Attended Status", comment: "")
        PromptForAttendedSwitchLabel.numberOfLines = 0
        PromptForAttendedSwitchLabel.adjustsFontSizeToFitWidth = true
        
        selectYearLable.text = NSLocalizedString("SelectYearLabel", comment: "")
        selectYearLable.numberOfLines = 0
        selectYearLable.adjustsFontSizeToFitWidth = true
        
        // Enable multiline support for Detail Screen section header
        DetailScreenSection.numberOfLines = 0
        DetailScreenSection.adjustsFontSizeToFitWidth = true
        
        // Configure all labels for proper multiline text wrapping
        configureLabelsForMultilineText()
        
        // Update scroll view size after text is set
        updateScrollViewContentSize()
        
        if let uidString = UIDevice.current.identifierForVendor?.uuidString {
            // Construct the UserID and Build text for display
            let userIDPart = "UserID: " + uidString
            let buildPart = "Build: " + versionInformation
            let fullText = userIDPart + "\n" + buildPart
            
            userIDLabel.text = fullText
            userIDLabel.numberOfLines = 0  // Allow unlimited lines
            userIDLabel.lineBreakMode = .byWordWrapping  // Use word wrapping for long UUIDs
            userIDLabel.adjustsFontSizeToFitWidth = false  // Don't shrink text - use line wrapping instead
        } else {
            print("AlertPreferenesController: ERROR - UIDevice identifierForVendor is nil, cannot set uidString")
        }
    }
    
    /// Configures all labels for proper multiline text wrapping and pins toggle buttons to the right
    func configureLabelsForMultilineText() {
        let screenWidth = UIScreen.main.bounds.width
        let maxControlWidth: CGFloat = 100 // Maximum width for any control (button, text field, switch)
        let rightMargin: CGFloat = 5
        let leftMargin: CGFloat = 20
        let spacing: CGFloat = 10
        // Calculate label width based on controls being positioned at screen edge
        let labelWidth = screenWidth - leftMargin - maxControlWidth - rightMargin - spacing
        
        // Array of all switches that need to be pinned to the right
        let switches: [UISwitch] = [
            AlertOnMustSee,
            AlertOnMightSee,
            AlertOnlyForAttended,
            AlertForShows,
            AlertForSpecialEvents,
            AlertForMeetAndGreets,
            AlertForClinic,
            AlertForListeningEvent,
            alertForUnofficalEvents,
            NotesFontSizeLargeSwitch,
            HideExpiredSwitch,
            PromptForAttendedSwitch
        ]
        
        // Pin all switches to the actual right edge of the screen using absolute positioning
        let rightEdgeX = screenWidth - rightMargin - 51 // 51 is standard UISwitch width
        
        for switchControl in switches {
            // Use frame-based positioning to ensure they're at the screen edge
            let currentY = switchControl.frame.origin.y
            switchControl.frame = CGRect(x: rightEdgeX, y: currentY, width: 51, height: 31)
        }
        
        // Pin the MinBeforeAlert text field to the right edge
        let textFieldWidth: CGFloat = 60
        let textFieldX = screenWidth - rightMargin - textFieldWidth
        let currentTextFieldY = MinBeforeAlert.frame.origin.y
        MinBeforeAlert.frame = CGRect(x: textFieldX, y: currentTextFieldY, width: textFieldWidth, height: MinBeforeAlert.frame.height)
        
        // Pin the year selection button to the right edge  
        let buttonWidth: CGFloat = 100
        let buttonX = screenWidth - rightMargin - buttonWidth
        let currentButtonY = selectEventYear.frame.origin.y
        selectEventYear.frame = CGRect(x: buttonX, y: currentButtonY, width: buttonWidth, height: selectEventYear.frame.height)
        
        // Array of all labels that need multiline support and dynamic font sizing
        let labels: [UILabel] = [
            alertPreferenceHeader,
            mustSeeAlertLable,
            mightSeeAlertLable,
            onlyAlertForAttendedLable,
            minBeforeAlertLable,
            alertForShowsLable,
            alertForSpecialLable,
            alertForMandGLable,
            alertForClinicsLable,
            alertForListeningLable,
            alertForUnofficalEventsLable,
            NotesFontSizeLargeLabel,
            HideExpiredLabel,
            HideExpiredSwitchLabel,
            PromptForAttendedLabel,
            PromptForAttendedSwitchLabel,
            selectYearLable,
            DetailScreenSection,
            userIDLabel  // Added to support dynamic font sizing and multiline text
        ]
        
        // Configure each label for multiline text and dynamic font sizing
        for label in labels {
            // Remove any existing width constraints
            let widthConstraints = label.constraints.filter { $0.firstAttribute == .width }
            label.removeConstraints(widthConstraints)
            
            // Set preferred maximum width for text wrapping
            label.preferredMaxLayoutWidth = labelWidth
            
            // Enable dynamic font sizing
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.7 // Allow font to scale down to 70% of original size
            
            // Ensure word wrapping is enabled
            label.lineBreakMode = .byWordWrapping
            
            // Force layout update
            label.setNeedsLayout()
        }
        
        // Update scroll view content size and re-position controls after layout
        DispatchQueue.main.async {
            self.view.layoutIfNeeded()
            
            // Re-position controls after layout is complete
            self.repositionControlsToScreenEdge()
            
            // Calculate actual content height by finding the bottom-most element
            var maxY: CGFloat = 0
            for subview in self.controlView.subviews {
                let bottomY = subview.frame.origin.y + subview.frame.size.height
                maxY = max(maxY, bottomY)
            }
            
            // Add extra padding for safety and account for potential layout changes
            let contentHeight = maxY + 100
            let minHeight = UIScreen.main.bounds.height + 200 // Ensure scrolling is always possible
            let finalHeight = max(contentHeight, minHeight)
            
            self.scrollView.contentSize = CGSize(width: self.scrollView.frame.width, height: finalHeight)
            print("Updated scroll view content size to: \(self.scrollView.contentSize)")
        }
    }
    
    /// Repositions all controls to the actual screen edge after layout is complete
    func repositionControlsToScreenEdge() {
        let screenWidth = UIScreen.main.bounds.width
        let rightMargin: CGFloat = 5
        
        // Array of all switches that need to be repositioned
        let switches: [UISwitch] = [
            AlertOnMustSee,
            AlertOnMightSee,
            AlertOnlyForAttended,
            AlertForShows,
            AlertForSpecialEvents,
            AlertForMeetAndGreets,
            AlertForClinic,
            AlertForListeningEvent,
            alertForUnofficalEvents,
            NotesFontSizeLargeSwitch,
            HideExpiredSwitch,
            PromptForAttendedSwitch
        ]
        
        // Position all switches at screen edge
        let switchX = screenWidth - rightMargin - 51 // 51 is standard UISwitch width
        for switchControl in switches {
            let currentY = switchControl.frame.origin.y
            switchControl.frame = CGRect(x: switchX, y: currentY, width: 51, height: 31)
        }
        
        // Position MinBeforeAlert text field
        let textFieldWidth: CGFloat = 60
        let textFieldX = screenWidth - rightMargin - textFieldWidth
        let currentTextFieldY = MinBeforeAlert.frame.origin.y
        MinBeforeAlert.frame = CGRect(x: textFieldX, y: currentTextFieldY, width: textFieldWidth, height: MinBeforeAlert.frame.height)
        
        // Position year selection button
        let buttonWidth: CGFloat = 100
        let buttonX = screenWidth - rightMargin - buttonWidth
        let currentButtonY = selectEventYear.frame.origin.y
        selectEventYear.frame = CGRect(x: buttonX, y: currentButtonY, width: buttonWidth, height: selectEventYear.frame.height)
        
        print("Repositioned controls to screen edge - screen width: \(screenWidth)")
    }
    
    /// Recalculates and updates the scroll view content size based on actual content
    func updateScrollViewContentSize() {
        DispatchQueue.main.async {
            // Force layout to ensure all label sizes are calculated
            self.view.layoutIfNeeded()
            
            // Wait a bit more for text layout to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                var maxY: CGFloat = 0
                
                // Check all subviews in the control view
                for subview in self.controlView.subviews {
                    let bottomY = subview.frame.origin.y + subview.frame.size.height
                    maxY = max(maxY, bottomY)
                }
                
                // Add substantial padding for wrapped text and bottom elements
                let contentHeight = maxY + 150
                let minHeight = UIScreen.main.bounds.height + 300
                let finalHeight = max(contentHeight, minHeight)
                
                self.scrollView.contentSize = CGSize(width: self.scrollView.frame.width, height: finalHeight)
                print("Final scroll view content size: \(self.scrollView.contentSize), maxY was: \(maxY)")
            }
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
        // Enhanced delay to account for retry logic: wait 2 seconds then navigate back
        // This gives enough time for background processes including retries to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
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

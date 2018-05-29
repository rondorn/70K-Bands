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
    var alertForShowsValue = Bool()
    var alertForSpecialValue = Bool()
    var alertForMandGValue = Bool()
    var alertForClinicsValue = Bool()
    var alertForListeningValue = Bool()
    
    
    var minBeforeAlertValue = Double()
    
    var minBeforeAlertLabel = String()
    var restartAlertTitle = String();
    var restartAlertText = String();
    var okPrompt = String();
    var cancelPrompt = String();
    
    @IBOutlet weak var AlertOnMustSee: UISwitch!
    @IBOutlet weak var AlertOnMightSee: UISwitch!
    @IBOutlet weak var AlertForShows: UISwitch!
    @IBOutlet weak var AlertForSpecialEvents: UISwitch!
    @IBOutlet weak var AlertForMeetAndGreets: UISwitch!
    @IBOutlet weak var AlertForClinic: UISwitch!
    @IBOutlet weak var AlertForListeningEvent: UISwitch!
    @IBOutlet weak var MinBeforeAlert: UITextField!
    @IBOutlet weak var UseLastYearsData: UISwitch!
    

    //labels
    @IBOutlet weak var mustSeeAlertLable: UILabel!
    @IBOutlet weak var mightSeeAlertLable: UILabel!
    @IBOutlet weak var minBeforeAlertLable: UILabel!
    @IBOutlet weak var alertForShowsLable: UILabel!
    @IBOutlet weak var alertForSpecialLable: UILabel!
    @IBOutlet weak var alertForMandGLable: UILabel!
    @IBOutlet weak var alertForClinicsLable: UILabel!
    @IBOutlet weak var useLastYearsLable: UILabel!
    @IBOutlet weak var alertForListeningLable: UILabel!
    @IBOutlet weak var lastYearsDetailsLable: UITextView!
    
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var controlView: UIControl!
    
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
        
        self.navigationItem.title = "Alert Preferences - Build:" + (((Bundle.main.infoDictionary?["CFBundleVersion"])!) as! String)
    }
    
    func setLocalizedLables (){
    
        mustSeeAlertLable.text = NSLocalizedString("Alert On Must See Bands", comment: "")
        mightSeeAlertLable.text = NSLocalizedString("Alert On Might See Bands", comment: "")
        minBeforeAlertLable.text = NSLocalizedString("Minutes Before Event to Alert", comment: "")
        alertForShowsLable.text = NSLocalizedString("Alert For Shows", comment: "")
        alertForSpecialLable.text = NSLocalizedString("Alert For Special Events", comment: "")
        alertForMandGLable.text = NSLocalizedString("Alert For Meeting and Greet Events", comment: "")
        alertForClinicsLable.text = NSLocalizedString("Alert For Clinics", comment: "")
        alertForListeningLable.text  = NSLocalizedString("Alert For Album Listening Events", comment: "")
        
        useLastYearsLable.text = NSLocalizedString("Use Last Years Data", comment: "")
        lastYearsDetailsLable.text = NSLocalizedString("LastYearsFeatureExplication", comment: "")
        
        restartAlertTitle = NSLocalizedString("restarTitle", comment: "")
        restartAlertText = NSLocalizedString("restartMessage", comment: "")
        
        okPrompt = NSLocalizedString("Ok", comment: "")
        cancelPrompt = NSLocalizedString("Cancel", comment: "")
    }
    
    func setExistingValues (){
        
        mustSeeAlertValue = defaults.bool(forKey: "mustSeeAlert")
        mightSeeAlertValue = defaults.bool(forKey: "mightSeeAlert")
        alertForShowsValue = defaults.bool(forKey: "alertForShows")
        alertForSpecialValue = defaults.bool(forKey: "alertForSpecial")
        alertForMandGValue = defaults.bool(forKey: "alertForMandG")
        alertForClinicsValue = defaults.bool(forKey: "alertForClinics")
        alertForListeningValue = defaults.bool(forKey: "alertForListening")
        
        minBeforeAlertValue = Double(defaults.integer(forKey: "minBeforeAlert"))
        
        AlertOnMustSee.isOn = mustSeeAlertValue
        AlertOnMightSee.isOn = mightSeeAlertValue
        
        MinBeforeAlert.text = String(format: "%.0f", minBeforeAlertValue)
        AlertForShows.isOn = alertForShowsValue
        AlertForSpecialEvents.isOn = alertForSpecialValue
        AlertForMeetAndGreets.isOn = alertForMandGValue
        AlertForClinic.isOn = alertForClinicsValue
        AlertForListeningEvent.isOn = alertForListeningValue
        
        self.MinBeforeAlert.delegate = self
        
        if (defaults.string(forKey: "scheduleUrl") == lastYearsScheduleUrlDefault){
            UseLastYearsData.isOn = true
        } else {
            UseLastYearsData.isOn = false
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true);
        return false;
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
            alert.addButton(withTitle: "Ok")
            alert.show()
        }
        
    }
    
    @IBAction func MustSeeChange() {
        defaults.set(AlertOnMustSee.isOn, forKey: "mustSeeAlert")
    }
    
    @IBAction func MightSeeChange() {
        defaults.set(AlertOnMightSee.isOn, forKey: "mightSeeAlert")
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
    
    @IBAction func UseLastYearsDataAction() {
        
        let alert: UIAlertView = UIAlertView()
        alert.title = restartAlertTitle
        alert.message = restartAlertText
        
        alert.addButton(withTitle: cancelPrompt)
        alert.addButton(withTitle: okPrompt)
        alert.delegate = self  // set the delegate here
        alert.show()
        
    }
    
    func alertView(_ alertView: UIAlertView, clickedButtonAtIndex buttonIndex: Int) {
        let buttonTitle = alertView.buttonTitle(at: buttonIndex)
        print("\(buttonTitle) pressed")
        if buttonTitle == okPrompt {
            
            if (UseLastYearsData.isOn == true){
                defaults.setValue(lastYearsartistUrlDefault, forKey: "artistUrl")
                defaults.setValue(lastYearsScheduleUrlDefault, forKey: "scheduleUrl")
                
            } else {
                defaults.setValue(artistUrlDefault, forKey: "artistUrl")
                defaults.setValue(scheduleUrlDefault, forKey: "scheduleUrl")
            }

            do {
                try  FileManager.default.removeItem(atPath: scheduleFile)
                try  FileManager.default.removeItem(atPath: bandFile)
            } catch {
                //guess there was no file to delete
            }
            
            //clear all existing notifications
            let localNotification = localNoticationHandler()
            localNotification.clearNotifications();
            
            exit(0)
            
        } else {
            if (UseLastYearsData.isOn == true){
                UseLastYearsData.isOn = false
                
            } else {
                UseLastYearsData.isOn = true
            }
        }
    }
    
}

//
//  SortMenuController.swift
//  70K Bands
//
//  Created by Ron Dorn on 6/11/16.
//  Copyright © 2016 Ron Dorn. All rights reserved.
//

import Foundation

import Foundation
import UIKit


class SortMenuController: UIViewController  {
    
    
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet weak var poolLabel: UILabel!
    @IBOutlet weak var theaterLable: UILabel!
    @IBOutlet weak var rinkLabel: UILabel!
    @IBOutlet weak var loungeLable: UILabel!
    @IBOutlet weak var specialEventLabel: UILabel!
    @IBOutlet weak var listeningEventLabel: UILabel!
    @IBOutlet weak var clinicLabel: UILabel!
    @IBOutlet weak var meetAndGreetLable: UILabel!
    
    
    @IBOutlet weak var poolToggle: UISwitch!
    @IBOutlet weak var theaterToggle: UISwitch!
    @IBOutlet weak var rinkToggle: UISwitch!
    @IBOutlet weak var loungeToggle: UISwitch!
    @IBOutlet weak var otherToggle: UISwitch!
    @IBOutlet weak var specialEventToggle: UISwitch!
    @IBOutlet weak var meetAndGreetToggle: UISwitch!
    @IBOutlet weak var clinicToggle: UISwitch!
    @IBOutlet weak var listeningEventToggle: UISwitch!
    
    var showSpecialValue = Bool()
    var showMandGValue = Bool()
    var showClinicsValue = Bool()
    var showListeningValue = Bool()

    var showPoolShows = Bool()
    var showTheaterShows = Bool()
    var showRinkShows = Bool()
    var showLoungeShows = Bool()
    var showOtherShows = Bool()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setExistingValues()
        setLabels()
    }
    
    func setLabels(){
        
        poolLabel.text = poolVenueText + " " + poolVenue
        theaterLable.text = theaterVenueText + " " + theaterVenue
        rinkLabel.text = rinkVenueText + " " + rinkVenue
        loungeLable.text = loungeVenueText + " " + loungeVenue
        
        specialEventLabel.text = specialEventType + " " + specialEventTypeIcon
        meetAndGreetLable.text = meetAndGreetype + " " + mAndmEventTypeIcon
        clinicLabel.text = clinicType + " " + clinicEventTypeIcon
        listeningEventLabel.text = listeningPartyType + " " + listeningEventTypeIcon
        
    }
    
    
    func setExistingValues (){
        
        showSpecialValue = defaults.boolForKey("showSpecial")
        showMandGValue = defaults.boolForKey("showMandG")
        showClinicsValue = defaults.boolForKey("showClinics")
        showListeningValue = defaults.boolForKey("showListening")
        
        showPoolShows = defaults.boolForKey("showPoolShows")
        showTheaterShows = defaults.boolForKey("showTheaterShows")
        showRinkShows = defaults.boolForKey("showRinkShows")
        showLoungeShows = defaults.boolForKey("showLoungeShows")
        showOtherShows = defaults.boolForKey("showOtherShows")
        
        specialEventToggle.on = showSpecialValue;
        meetAndGreetToggle.on = showMandGValue;
        clinicToggle.on = showClinicsValue;
        listeningEventToggle.on = showListeningValue;
        
        poolToggle.on = showPoolShows;
        theaterToggle.on = showTheaterShows;
        rinkToggle.on = showRinkShows;
        loungeToggle.on = showLoungeShows;
        otherToggle.on = showOtherShows;
    }
    
 
    @IBAction func poolSwitchAction(sender: UISwitch) {
        defaults.setBool(poolToggle.on, forKey: "showPoolShows")
    }
    
    @IBAction func theaterSwitchAction(sender: UISwitch) {
        defaults.setBool(theaterToggle.on, forKey: "showTheaterShows")
    }
    
    @IBAction func rinkSwitchAction(sender: UISwitch) {
        defaults.setBool(rinkToggle.on, forKey: "showRinkShows")
    }
    
    @IBAction func loungeSwitchAction(sender: UISwitch) {
        defaults.setBool(loungeToggle.on, forKey: "showLoungeShows")
    }
    
    @IBAction func otherSwitchAction(sender: UISwitch) {
        defaults.setBool(otherToggle.on, forKey: "showOtherShows")
    }
    
    @IBAction func specialEventSwitchAction(sender: UISwitch) {
        defaults.setBool(specialEventToggle.on, forKey: "showSpecial")
    }
    
    @IBAction func meetAndGreetSwitchAction(sender: UISwitch) {
        defaults.setBool(meetAndGreetToggle.on, forKey: "showMandG")
    }
    
    @IBAction func clinicSwitchAction(sender: UISwitch) {
        defaults.setBool(clinicToggle.on, forKey: "showClinics")
    }
    
    @IBAction func ListeningEventSwitchAction(sender: UISwitch) {
        defaults.setBool(listeningEventToggle.on, forKey: "showListening")
    }
    
    override func viewDidDisappear(animated: Bool) {
        masterView.quickRefresh()
    }
    
    @IBAction func returnButtonAction(sender: AnyObject) {
        
        self.dismissViewControllerAnimated(true, completion: nil)

    }
    

}
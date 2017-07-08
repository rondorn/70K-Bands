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
        
        specialEventLabel.text = NSLocalizedString(specialEventType, comment: "") + " " + specialEventTypeIcon
        meetAndGreetLable.text = NSLocalizedString(meetAndGreetype, comment: "") + " " + mAndmEventTypeIcon
        clinicLabel.text = NSLocalizedString(clinicType, comment: "") + " " + clinicEventTypeIcon
        listeningEventLabel.text = NSLocalizedString(listeningPartyType, comment: "") + " " + listeningEventTypeIcon
        
    }
    
    
    func setExistingValues (){
        
        showSpecialValue = defaults.bool(forKey: "showSpecial")
        showMandGValue = defaults.bool(forKey: "showMandG")
        showClinicsValue = defaults.bool(forKey: "showClinics")
        showListeningValue = defaults.bool(forKey: "showListening")
        
        showPoolShows = defaults.bool(forKey: "showPoolShows")
        showTheaterShows = defaults.bool(forKey: "showTheaterShows")
        showRinkShows = defaults.bool(forKey: "showRinkShows")
        showLoungeShows = defaults.bool(forKey: "showLoungeShows")
        showOtherShows = defaults.bool(forKey: "showOtherShows")
        
        specialEventToggle.isOn = showSpecialValue;
        meetAndGreetToggle.isOn = showMandGValue;
        clinicToggle.isOn = showClinicsValue;
        listeningEventToggle.isOn = showListeningValue;
        
        poolToggle.isOn = showPoolShows;
        theaterToggle.isOn = showTheaterShows;
        rinkToggle.isOn = showRinkShows;
        loungeToggle.isOn = showLoungeShows;
        otherToggle.isOn = showOtherShows;
    }
    
 
    @IBAction func poolSwitchAction(_ sender: UISwitch) {
        defaults.set(poolToggle.isOn, forKey: "showPoolShows")
    }
    
    @IBAction func theaterSwitchAction(_ sender: UISwitch) {
        defaults.set(theaterToggle.isOn, forKey: "showTheaterShows")
    }
    
    @IBAction func rinkSwitchAction(_ sender: UISwitch) {
        defaults.set(rinkToggle.isOn, forKey: "showRinkShows")
    }
    
    @IBAction func loungeSwitchAction(_ sender: UISwitch) {
        defaults.set(loungeToggle.isOn, forKey: "showLoungeShows")
    }
    
    @IBAction func otherSwitchAction(_ sender: UISwitch) {
        defaults.set(otherToggle.isOn, forKey: "showOtherShows")
    }
    
    @IBAction func specialEventSwitchAction(_ sender: UISwitch) {
        defaults.set(specialEventToggle.isOn, forKey: "showSpecial")
    }
    
    @IBAction func meetAndGreetSwitchAction(_ sender: UISwitch) {
        defaults.set(meetAndGreetToggle.isOn, forKey: "showMandG")
    }
    
    @IBAction func clinicSwitchAction(_ sender: UISwitch) {
        defaults.set(clinicToggle.isOn, forKey: "showClinics")
    }
    
    @IBAction func ListeningEventSwitchAction(_ sender: UISwitch) {
        defaults.set(listeningEventToggle.isOn, forKey: "showListening")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        masterView.quickRefresh()
    }
    
    @IBAction func returnButtonAction(_ sender: AnyObject) {
        
        self.dismiss(animated: true, completion: nil)

    }
    

}

//
//  preferenceDefault.swift
//  70K Bands
//
//  Created by Ron Dorn on 2/11/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation


let artistUrlDefault = FestivalConfig.current.artistUrlDefault
let scheduleUrlDefault = FestivalConfig.current.scheduleUrlDefault
let iCloudDefault = "YES"
let mustSeeAlertDefault = "YES"
let mightSeeAlertDefault = "YES"
let minBeforeAlertDefault = "10"
let alertForShowsDefault = "YES"
let alertForSpecialDefault = "YES"
let alertForMandGDefault = "NO"
let alertForClinicsDefault = "NO"
let alertForListeningDefault = "NO"
let validateScheduleFileDefault = "NO"

func setDefaults(){
    
    let defaults = ["artistUrl": artistUrlDefault,
                    "scheduleUrl": scheduleUrlDefault,
                    "iCloud": iCloudDefault,
                    "mustSeeAlert": mustSeeAlertDefault, "mightSeeAlert": mightSeeAlertDefault,
                    "minBeforeAlert": minBeforeAlertDefault, "alertForShows": alertForShowsDefault,
                    "alertForSpecial": alertForSpecialDefault, "alertForMandG": alertForMandGDefault,
                    "alertForClinics": alertForClinicsDefault, "alertForListening": alertForListeningDefault,
                    "validateScheduleFile": validateScheduleFileDefault]

    UserDefaults.standard.register(defaults: defaults)
}


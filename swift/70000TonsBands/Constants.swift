//
//  Constants.swift
//  70K Bands
//
//  Created by Ron Dorn on 2/7/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import CoreData


//CSV field names
var typeField = "Type"
var showField = "Show"
var bandField = "Band"
var locationField = "Location"
var dayField = "Day"
var dateField = "Date"
var startTimeField = "Start Time"
var endTimeField = "End Time"
var notesField = "Notes"

//link containers
var wikipediaLink = [String: String]()
var youtubeLinks = [String: String]()
var metalArchiveLinks = [String: String]()
var bandCountry = [String: String]()
var bandGenre = [String: String]()
var bandNoteWorthy = [String: String]()

//valid event types
var showType = "Show"
var meetAndGreetype = "Meet and Greet"
var clinicType = "Clinic"
var listeningPartyType = "Listening Party"
var specialEventType = "Special Event"

//links to external site
var officalSiteButtonName = "Offical Web Site"
var wikipediaButtonName = "Wikipedia"
var youTubeButtonName = "YouTube"
var metalArchivesButtonName = "Metal Archives"

//file names
let dirs = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.AllDomainsMask, true)
let scheduleFile = getDocumentsDirectory().stringByAppendingPathComponent("scheduleFile.txt")

//defaults preferences
let artistUrlDefault = "Default"
let scheduleUrlDefault = "Default"

let lastYearsartistUrlDefault = "https://www.dropbox.com/s/0uz41zl8jbirca2/lastYeaysartistLineup.csv?dl=1"
//let lastYearsScheduleUrlDefault = "https://www.dropbox.com/s/czrg31whgc0211p/lastYearsSchedule.csv?dl=1"
let lastYearsScheduleUrlDefault = "https://www.dropbox.com/s/ufn4m1e2fn07arf/artistsSchedule2016.csv?dl=1"
let defaultStorageUrl = "https://www.dropbox.com/s/29ktavd9fksxw85/productionPointer1.txt?dl=1"

let mustSeeAlertDefault = "YES"
let mightSeeAlertDefault = "YES"
let minBeforeAlertDefault = "10"
let alertForShowsDefault = "YES"
let alertForSpecialDefault = "YES"
let alertForMandGDefault = "NO"
let alertForClinicsDefault = "NO"
let alertForListeningDefault = "NO"
let validateScheduleFileDefault = "NO"

var schedule = scheduleHandler()
let defaults = NSUserDefaults.standardUserDefaults()
var byPassCsvDownloadCheck = false

func getDocumentsDirectory() -> NSString {
    let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
    let documentsDirectory = paths[0]
    return documentsDirectory
}




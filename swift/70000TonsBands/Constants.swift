//
//  Constants.swift
//  70K Bands
//
//  Created by Ron Dorn on 2/7/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import CoreData

//prevent alerts from being re-added all the time
var alertTracker = [String]()

//prevent mutiple threads doing the same thing
var isAlertGenerationRunning = false
var isLoadingBandData = false
var isLoadingCommentData = false

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
var urlField = "URL"

//link containers
var wikipediaLink = [String: String]()
var youtubeLinks = [String: String]()
var metalArchiveLinks = [String: String]()
var bandCountry = [String: String]()
var bandGenre = [String: String]()
var bandNoteWorthy = [String: String]()

//var band list placeHolder
var bandListIndexCache = 0

//valid event types
var showType = "Show"
var meetAndGreetype = "Meet and Greet"
var clinicType = "Clinic"
var listeningPartyType = "Listening Party"
var specialEventType = "Special Event"

var poolVenueText = "Pool"
var rinkVenueText = "Rink"
var loungeVenueText = "Lounge"
var theaterVenueText = "Theater"

//links to external site
var officalSiteButtonName = "Offical Web Site"
var wikipediaButtonName = "Wikipedia"
var youTubeButtonName = "YouTube"
var metalArchivesButtonName = "Metal Archives"

//file names
let dirs = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.allDomainsMask, true)

let scheduleFile = getDocumentsDirectory().appendingPathComponent("scheduleFile.txt")
let descriptionMapFile = getDocumentsDirectory().appendingPathComponent("descriptionMapFile.csv")

//defaults preferences
let artistUrlDefault = "Default"
let scheduleUrlDefault = "Default"

let lastYearsartistUrlDefault = "lastYear"
let lastYearsScheduleUrlDefault = "lastYear"

let defaultStorageUrl = "https://www.dropbox.com/s/ezquwptowec4wy7/productionPointer2019.txt?dl=1"

let artistUrlpointer = "artistUrl"
let lastYearsartistUrlpointer = "lastYearsartistUrl"
let scheduleUrlpointer = "scheduleUrl";
let lastYearscheduleUrlpointer = "lastYearsScheduleUrl";

let mustSeeAlertDefault = "YES"
let mightSeeAlertDefault = "YES"
let minBeforeAlertDefault = "10"
let alertForShowsDefault = "YES"
let alertForSpecialDefault = "YES"
let alertForMandGDefault = "NO"
let alertForClinicsDefault = "NO"
let alertForListeningDefault = "NO"
let validateScheduleFileDefault = "NO"

let showSpecialDefault = "YES"
let showMandGDefault = "YES"
let showClinicsDefault = "YES"
let showListeningDefault = "YES"

let showPoolShowsDefault = "YES"
let showTheaterShowsDefault = "YES"
let showRinkShowsDefault = "YES"
let showLoungeShowsDefault = "YES"
let showOtherShowsDefault = "YES"

var schedule = scheduleHandler()
var bandNotes = CustomBandDescription();

var bandDescriptionUrl = [String:String]()

let defaults = UserDefaults.standard
var byPassCsvDownloadCheck = false
var listOfVenues = [String]()

var masterView: MasterViewController!

var googleCloudID = "Nothing";

func getDocumentsDirectory() -> NSString {
    let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
    let documentsDirectory = paths[0]
    return documentsDirectory as NSString
}

func getPointerUrlData(keyValue: String) -> String {
    
    var url = String()
    let httpData = getUrlData(defaultStorageUrl)
    
    if (httpData.isEmpty == false){
    let dataArray = httpData.components(separatedBy: "\n")
        for record in dataArray {
            var valueArray = record.components(separatedBy: "::")
            print ("Checking " + valueArray[0] + " would use " + valueArray[1] + " Against key " + keyValue)
            if (valueArray[0] == keyValue){
                url = valueArray[1]
                break
            }
        }
    }
    print ("Using default " + keyValue + " of " + url)
    return url
}


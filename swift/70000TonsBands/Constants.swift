//
//  Constants.swift
//  70K Bands
//
//  Created by Ron Dorn on 2/7/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import CoreData
import SystemConfiguration
import UIKit
//prevent alerts from being re-added all the time
var alertTracker = [String]()

//file locations
var showsAttendedFileName = "showsAttended.data";

//icloud data types
var PRIORITY = "priority";  
var ATTENDED = "attended";
var NOTE = "note";

var defaultUrlConverFlagString = "defaultUrlConverFlag.txt"
var directoryPath = URL(fileURLWithPath:dirs[0])
var storageFile = directoryPath.appendingPathComponent( "data.txt")
var dateFile = directoryPath.appendingPathComponent( "date.txt")
var bandsFile = directoryPath.appendingPathComponent( "bands.txt")
var lastFilters = directoryPath.appendingPathComponent("lastFilters.txt")
var defaultUrlConverFlagUrl = directoryPath.appendingPathComponent(defaultUrlConverFlagString)
var showsAttended = directoryPath.appendingPathComponent(showsAttendedFileName)
var iCloudCheck = false;

//prevent mutiple threads doing the same thing
var isAlertGenerationRunning = false
var isLoadingBandData = false
var isLoadingCommentData = false
var isPerformingQuickLoad = false
var localTimeZoneAbbreviation :String = TimeZone.current.abbreviation()!

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
var descriptionUrlField = "Description URL"
var imageUrlField = "ImageURL"

//link containers
var wikipediaLink = [String: String]()
var youtubeLinks = [String: String]()
var metalArchiveLinks = [String: String]()
var bandCountry = [String: String]()
var bandGenre = [String: String]()
var bandNoteWorthy = [String: String]()

//var band list placeHolder
var bandListIndexCache = 0

//number of unoffical events
var unofficalEventCount = 0

//valid event types
var showType = "Show"
var meetAndGreetype = "Meet and Greet"
var clinicType = "Clinic"
var listeningPartyType = "Listening Party"
var specialEventType = "Special Event"
var unofficalEventTypeOld = "Unofficial Event"
var unofficalEventType = "Cruiser Organized"

var poolVenueText = "Pool"
var rinkVenueText = "Rink"
var loungeVenueText = "Lounge"
var theaterVenueText = "Theater"

//links to external site
var officalSiteButtonName = "Offical Web Site"
var wikipediaButtonName = "Wikipedia"
var youTubeButtonName = "YouTube"
var metalArchivesButtonName = "Metal Archives"

let attendedHandler = ShowsAttended()
let sawAllColor = UIColor.blue
let sawSomeColor = UIColor.brown
let sawNoneColor = UIColor.black
let sawAllStatus = "sawAll";
let sawSomeStatus = "sawSome";
let sawNoneStatus = "sawNone";

//alert topics
let subscriptionTopic = "/topics/global"
let subscriptionTopicTest = "/topics/Testing09162019"
let subscriptionUnofficalTopic = "/topics/unofficalEvents"

//file names
let dirs = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.allDomainsMask, true)

let scheduleFile = getDocumentsDirectory().appendingPathComponent("scheduleFile.txt")
let descriptionMapFile = getDocumentsDirectory().appendingPathComponent("descriptionMapFile.csv")

//defaults preferences
var artistUrlDefault = ""//UserDefaults.standard.string(forKey: "artistUrl")
var scheduleUrlDefault = ""//UserDefaults.standard.string(forKey: "scheduleUrl")

let defaultPrefsValue = "Default";

let lastYearsartistUrlDefault = "lastYear"
let lastYearsScheduleUrlDefault = "lastYear"

let defaultStorageUrl = "https://www.dropbox.com/s/5bqlfnf41w7emgv/productionPointer2019New.txt?dl=1"
//let defaultStorageUrl = "https://www.dropbox.com/s/sh6ctneu8kjkxrc/productionPointer2019Test.txt?dl=1"

let artistUrlpointer = "artistUrl"
let lastYearsartistUrlpointer = "lastYearsartistUrl"
let scheduleUrlpointer = "scheduleUrl";
let lastYearscheduleUrlpointer = "lastYearsScheduleUrl";

let mustSeeAlertDefault = "YES"
let mightSeeAlertDefault = "YES"

let onlyAlertForAttendedDefault = "NO"

let minBeforeAlertDefault = "10"
let alertForShowsDefault = "YES"
let alertForSpecialDefault = "YES"
let alertForUnofficalDefault = "YES"
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
let showUnofficalEventsDefault = "YES"

var internetAvailble = isInternetAvailable();

var hasScheduleData = false;
var schedule = scheduleHandler()
var bandNotes = CustomBandDescription();

var bandDescriptionUrl = [String:String]()
var imageUrls = [String:String]()

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

func isInternetAvailable() -> Bool {
    
    var zeroAddress = sockaddr_in()
    zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
    zeroAddress.sin_family = sa_family_t(AF_INET)
    
    let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
            SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
        }
    }
    
    var flags = SCNetworkReachabilityFlags()
    if !SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) {
        return false
    }
    let isReachable = flags.contains(.reachable)
    let needsConnection = flags.contains(.connectionRequired)
    return (isReachable && !needsConnection)
}

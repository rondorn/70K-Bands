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
let bandFile = getDocumentsDirectory().appendingPathComponent("bandFile")

var schedulingDataCacheFile = directoryPath.appendingPathComponent( "schedulingDataCacheFile")
var schedulingDataByTimeCacheFile = directoryPath.appendingPathComponent( "schedulingDataByTimeCacheFile")

let staticSchedule = DispatchQueue(label: "staticSchedule", attributes: .concurrent)
let staticBandNames = DispatchQueue(label: "staticBandNames", attributes: .concurrent)
let staticAttended = DispatchQueue(label: "staticAttended", attributes: .concurrent)
let staticBandName = DispatchQueue(label: "staticBandName", attributes: .concurrent)

var scheduleStaticCache = [String : [TimeInterval : [String : String]]]()
var scheduleTimeStaticCache = [TimeInterval : [String : String]]()
var bandNamedStaticCache = [String :[String : String]]()
var attendedStaticCache = [String : String]()
var bandNamesStaticCache =  [String :[String : String]]()
var bandNamesArrayStaticCache = [String]()

var schedulingAttendedCacheFile = directoryPath.appendingPathComponent( "schedulingAttendedCacheFile")
var bandNamesCacheFile = directoryPath.appendingPathComponent( "bandNamesCacheFile")

var iCloudCheck = false;

//prevent mutiple threads doing the same thing
var isAlertGenerationRunning = false
var isLoadingBandData = false
var isLoadingSchedule = false
var isLoadingCommentData = false
var isPerformingQuickLoad = false
var isReadingBandFile = false;

let scheduleQueue = DispatchQueue(label: "scheduleQueue")
let bandNameQueue = DispatchQueue(label: "bandNameQueue")
let bandPriorityQueue = DispatchQueue(label: "bandPriorityQueue")
let showsAttendedQueue = DispatchQueue(label: "showsAttendedQueue")

var localTimeZoneAbbreviation :String = TimeZone.current.abbreviation()!

var loadingiCloud = false;
var savingiCloud = false;

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

var venueLocation = [String:String]()

//links to external site
var officalSiteButtonName = "Offical Web Site"
var wikipediaButtonName = "Wikipedia"
var youTubeButtonName = "YouTube"
var metalArchivesButtonName = "Metal Archives"

let sawAllColor = UIColor.green
let sawSomeColor = UIColor.yellow
let sawNoneColor = UIColor.white
let sawAllStatus = "sawAll";
let sawSomeStatus = "sawSome";
let sawNoneStatus = "sawNone";

//alert topics
let subscriptionTopic = "global"
let subscriptionTopicTest = "Testing2020"
let subscriptionUnofficalTopic = "unofficalEvents"

//file names
let dirs = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.allDomainsMask, true)

let scheduleFile = getDocumentsDirectory().appendingPathComponent("scheduleFile.txt")
let descriptionMapFile = getDocumentsDirectory().appendingPathComponent("descriptionMapFile.csv")

let eventYearFile = getDocumentsDirectory().appendingPathComponent("eventYearFile")

var eventYear:Int = 0

//defaults preferences
var artistUrlDefault = ""
var scheduleUrlDefault = ""

let defaultPrefsValue = "Default";

let lastYearsartistUrlDefault = "lastYear"
let lastYearsScheduleUrlDefault = "lastYear"

let defaultStorageUrl = "https://www.dropbox.com/s/5bqlfnf41w7emgv/productionPointer2019New.txt?raw=1"
//let defaultStorageUrl = "https://www.dropbox.com/s/sh6ctneu8kjkxrc/productionPointer2019Test.txt?raw=1"

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
var hideExpireScheduleDataDefault = "YES";

var internetAvailble = isInternetAvailable();

var hasScheduleData = false;

//var bandDescriptionUrl = [String:String]()
var imageUrls = [String:String]()

let defaults = UserDefaults.standard
var byPassCsvDownloadCheck = false
var listOfVenues = [String]()

var masterView: MasterViewController!

var googleCloudID = "Nothing";

func resolvePriorityNumber (priority: String)->String {

    var result = ""
    
    if (priority == "1"){
        result = "Must";
    
    } else if (priority == "2"){
        result = "Might";

    } else if (priority == "3"){
        result = "Wont";
        
    } else {
        result = "Unknown";
    }
    
    return result;
}

func getDocumentsDirectory() -> NSString {
    let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
    let documentsDirectory = paths[0]
    return documentsDirectory as NSString
}

func getPointerUrlData(keyValue: String, dataHandle: dataHandler) -> String {
    
    var url = String()
    let httpData = dataHandle.getUrlData(defaultStorageUrl)
    
    if (httpData.isEmpty == false){
        let dataArray = httpData.components(separatedBy: "\n")
        for record in dataArray {
            var valueArray = record.components(separatedBy: "::")

            if (valueArray.isEmpty == false && valueArray.count >= 2){
                print ("Checking " + valueArray[0] + " would use " + valueArray[1] + " Against key " + keyValue)
                if (valueArray[0] == keyValue){
                    url = valueArray[1]
                    break
                }
            }
        }
    } else if (keyValue == "eventYear"){
        print ("eventYear = unknown \(eventYear)")
        do {
            url = try! String(contentsOfFile: eventYearFile, encoding: String.Encoding.utf8)
        } catch let error as NSError {
            print ("Encountered an error of reading file eventYearFile " + error.debugDescription)
        }
    }
    
    print ("Using default " + keyValue + " of " + url)
    
    if (keyValue == "eventYear"){
        do {
            try url.write(toFile: eventYearFile, atomically: true,encoding: String.Encoding.utf8)
            print ("Just created file " + eventYearFile);
        } catch let error as NSError {
            print ("Encountered an error of creating file eventYearFile " + error.debugDescription)
        }
    }
    return url
}

func setupDefaults() {
    
    //register Application Defaults
    var defaults = ["artistUrl": artistUrlDefault,
                    "scheduleUrl": scheduleUrlDefault,
                    "mustSeeAlert": mustSeeAlertDefault, "mightSeeAlert": mightSeeAlertDefault,
                    "onlyAlertForAttended": onlyAlertForAttendedDefault,
                    "minBeforeAlert": minBeforeAlertDefault, "alertForShows": alertForShowsDefault,
                    "alertForSpecial": alertForSpecialDefault, "alertForMandG": alertForMandGDefault,
                    "alertForClinics": alertForClinicsDefault, "alertForListening": alertForListeningDefault,
                    "validateScheduleFile": validateScheduleFileDefault, "showSpecial": showSpecialDefault,
                    "showMandG": showMandGDefault, "showClinics": showClinicsDefault,
                    "showListening": showListeningDefault, "showPoolShows": showPoolShowsDefault,
                    "showTheaterShows": showTheaterShowsDefault, "showRinkShows": showRinkShowsDefault,
                    "showLoungeShows": showLoungeShowsDefault, "showOtherShows": showOtherShowsDefault,
                    "alertForUnofficalEvents": alertForUnofficalDefault, "showUnofficalEvents" : showUnofficalEventsDefault,
                    "hideExpireScheduleData": hideExpireScheduleDataDefault]
    
    UserDefaults.standard.register(defaults: defaults)
    
    setupVenueLocations()
    
    print ("Schedule URL is \(UserDefaults.standard.string(forKey: "scheduleUrl"))")
    eventYear = Int(getPointerUrlData(keyValue: "eventYear", dataHandle: dataHandler()))!;

    if (UserDefaults.standard.string(forKey: "scheduleUrl") == "lastYear"){
        eventYear = eventYear - 1
    }
    
    print ("eventYear = \(eventYear)")
}

func setupVenueLocations(){
    
    venueLocation[poolVenueText] = "Deck 11"
    venueLocation[rinkVenueText] = "Deck 3"
    venueLocation[loungeVenueText] = "Deck 4"
    venueLocation[theaterVenueText] = "Deck 3/4"
    venueLocation["Sports Bar"] = "Deck 4"
    venueLocation["Viking Crown"] = "Deck 14"
    venueLocation["Boleros Lounge"] = "Deck 4"
    
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

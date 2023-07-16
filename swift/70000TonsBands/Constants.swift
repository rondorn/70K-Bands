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
import Network
//prevent alerts from being re-added all the time
var alertTracker = [String]()

//file locations
var showsAttendedFileName = "showsAttended.data";

//icloud data types
var PRIORITY = "priority";  
var ATTENDED = "attended";
var NOTE = "note";

var FCMnumber = "";
var refreshDataCounter = 0;
var defaultUrlConverFlagString = "defaultUrlConverFlag.txt"
var directoryPath = URL(fileURLWithPath:dirs[0])
var storageFile = directoryPath.appendingPathComponent( "data.txt")
var dateFile = directoryPath.appendingPathComponent( "date.txt")
var bandsFile = directoryPath.appendingPathComponent( "bands.txt")
var lastFilters = directoryPath.appendingPathComponent("lastFilters.txt")
var defaultUrlConverFlagUrl = directoryPath.appendingPathComponent(defaultUrlConverFlagString)
var showsAttended = directoryPath.appendingPathComponent(showsAttendedFileName)
let bandFile = getDocumentsDirectory().appendingPathComponent("bandFile")
let countryFile = directoryPath.appendingPathComponent("countryFile")

var currentBandList = [String]()

var downloadingAllComments = false
var downloadingAllImages = false
var bandSelected = String();
var eventSelectedIndex = String();

var timeIndexMap : [String:String] = [String:String]();

var inTestEnvironment = false;

var webMessageHelp = String();

var schedulingDataCacheFile = directoryPath.appendingPathComponent( "schedulingDataCacheFile")
var schedulingDataByTimeCacheFile = directoryPath.appendingPathComponent( "schedulingDataByTimeCacheFile")
var bandNamesCacheFile = directoryPath.appendingPathComponent( "bandNamesCacheFile")

let staticLastModifiedDate = DispatchQueue(label: "staticLastModifiedDate")
let staticSchedule = DispatchQueue(label: "staticSchedule")
let staticAttended = DispatchQueue(label: "staticAttended")
let staticBandName = DispatchQueue(label: "staticBandName")
let staticData = DispatchQueue(label: "staticData")
let storePointerLock = DispatchQueue(label: "storePointerLock")
let bandDescriptionLock = DispatchQueue(label: "bandDescriptionLock")

var iCloudCheck = false;
var internetCheckCache = ""
var internetCheckCacheDate = NSDate().timeIntervalSince1970

//prevent mutiple threads doing the same thing
var isAlertGenerationRunning = false
var isLoadingBandData = false
var isLoadingSchedule = false
var isLoadingCommentData = false
var isPerformingQuickLoad = false
var isReadingBandFile = false;
var isGetFilteredBands = false;

var refreshDataLock = false;

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
var urlDateField = "Date"
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
var karaokeEventType = "Karaoke";

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

var descriptionLock = false;

let venuePoolKey:String = "Pool";
let venueTheaterKey:String = "Theater";
let venueLoungeKey:String = "Lounge";
let venueRinkKey:String = "Rink";

let sawAllColor = hexStringToUIColor(hex: "#67C10C")
let sawSomeColor = hexStringToUIColor(hex: "#F0D905")
let sawNoneColor = hexStringToUIColor(hex: "#5DADE2")
let sawAllStatus = "sawAll";
let sawSomeStatus = "sawSome";
let sawNoneStatus = "sawNone";

//alert topics
let subscriptionTopic = "global"
let subscriptionTopicTest = "Testing20221127-1"
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
let lastYearSetting = "lastYear"
let testingSetting = "Testing"

var userCountry = ""

var defaultStorageUrl = "https://www.dropbox.com/s/5bqlfnf41w7emgv/productionPointer2019New.txt?raw=1"
//var defaultStorageUrl = "https://www.dropbox.com/s/sh6ctneu8kjkxrc/productionPointer2019Test.txt?raw=1"
let defaultStorageUrlTest = "https://www.dropbox.com/s/ruknei80s1qtdvb/productionPointer2023Test.txt?raw=1"
let networkTestingUrl = "https://www.dropbox.com/s/3c5m8he1jinezkh/test.txt?raw=1";

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
let iCloudActiveDefault = "YES"
let notesFontSizeLargeDefault = "NO"
let showPoolShowsDefault = "YES"
let showTheaterShowsDefault = "YES"
let showRinkShowsDefault = "YES"
let showLoungeShowsDefault = "YES"
let showOtherShowsDefault = "YES"
let showUnofficalEventsDefault = "YES"
var hideExpireScheduleDataDefault = "YES";
var promptForAttendedDefault = "YES";

var internetAvailble = isInternetAvailable();

var hasScheduleData = false;

let defaults = UserDefaults.standard
var byPassCsvDownloadCheck = false
var listOfVenues = [String]()

var filteredBandCount = 0
var unfilteredBandCount = 0

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

func getPointerUrlData(keyValue: String) -> String {
    
    var url = String()
    
    if (UserDefaults.standard.string(forKey: "PointerUrl") == testingSetting){
        defaultStorageUrl = defaultStorageUrlTest
        inTestEnvironment = true;
        
    }
    #if targetEnvironment(simulator)
        inTestEnvironment = true;
    #endif
    
    //returned cached data when needed. Will only look up pointer data on launch as this
    //does not change very often during the year
    storePointerLock.sync() {
        if (cacheVariables.storePointerData.isEmpty == false){
            url = cacheVariables.storePointerData[keyValue] ?? ""
            print ("got cached URL data of = \(url) for \(keyValue)")
        }
    }

    if (url.isEmpty == true){
        print ("getting URL data of \(defaultStorageUrl) - \(keyValue)")
        let httpData = getUrlData(urlString: defaultStorageUrl)
        print ("httpData for pointers data = \(httpData)")
        if (httpData.isEmpty == false){
            
            let dataArray = httpData.components(separatedBy: "\n")
            for record in dataArray {
                print ("httpRecord for pointers data = \(record)")
                var valueArray = record.components(separatedBy: "::")
                if (valueArray.isEmpty == false && valueArray.count >= 2){
                    print ("2 Checking " + valueArray[0] + " would use " + valueArray[1] + " Against key " + keyValue)
                    if (valueArray[0] == keyValue){
                        
                        url = valueArray[1]
                    }
                    
                    storePointerLock.async(flags: .barrier) {
                        cacheVariables.storePointerData[valueArray[0]] = valueArray[1];
                    }
                }
            }
        } else {
            print ("Why is \(keyValue) emptry - \(url)")
        }
        
        if (keyValue == "eventYear"){
            do {
                if (url.count == 4){
                    try url.write(toFile: eventYearFile, atomically: true,encoding: String.Encoding.utf8)
                    try cacheVariables.storePointerData[keyValue] = url
                    print ("Just created eventYear file " + eventYearFile);
                } else {
                    try url = try String(contentsOfFile: eventYearFile, encoding: String.Encoding.utf8)
                    print ("Just reading eventYear file " + eventYearFile + " and got \(url)");
                }
            } catch let error as NSError {
                print ("Encountered an error of creating file eventYearFile " + error.debugDescription)
                url = "2024" //provide a default year
            }
        }

    }
    print ("Using Final value of " + keyValue + " of " + url)
    
    return url
}

func setupDefaults() {
    
    //register Application Defaults
    let defaults = ["artistUrl": artistUrlDefault,
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
                    "hideExpireScheduleData": hideExpireScheduleDataDefault, "promptForAttended": promptForAttendedDefault,
                    "iCloud": iCloudActiveDefault, "notesFontSizeLarge" : notesFontSizeLargeDefault]
    
    UserDefaults.standard.register(defaults: defaults)
    
    setupVenueLocations()
    
    print ("Schedule URL is \(UserDefaults.standard.string(forKey: "scheduleUrl") ?? "")")
    

    print ("Trying to get the year  \(eventYear)")
    eventYear = Int(getPointerUrlData(keyValue: "eventYear"))!

    print ("eventYear is \(eventYear) scheduleURL is \(getPointerUrlData(keyValue: "scheduleUrl"))")
    
    if (UserDefaults.standard.string(forKey: "scheduleUrl") == lastYearSetting){
        eventYear = eventYear - 1
    }

}

func setupVenueLocations(){
    
    venueLocation[poolVenueText] = "Deck 11"
    venueLocation[rinkVenueText] = "Deck 3"
    venueLocation[loungeVenueText] = "Deck 5"
    venueLocation[theaterVenueText] = "Deck 3/4"
    venueLocation["Sports Bar"] = "Deck 4"
    venueLocation["Viking Crown"] = "Deck 14"
    venueLocation["Boleros Lounge"] = "Deck 4"
    
}

func isInternetAvailable() -> Bool {
    
    var networkTesting = NetworkTesting()
    
    var returnState = networkTesting.isInternetAvailable()
    
    return returnState;
    
}

struct cacheVariables {
    
    static var bandPriorityStorageCache = [String:Int]()
    static var scheduleStaticCache = [String : [TimeInterval : [String : String]]]()
    static var scheduleTimeStaticCache = [TimeInterval : [String : String]]()
    static var bandNamedStaticCache = [String :[String : String]]()
    static var attendedStaticCache = [String : String]()
    static var bandNamesStaticCache =  [String :[String : String]]()
    static var bandNamesArrayStaticCache = [String]()
    static var storePointerData = [String:String]()
    static var bandDescriptionUrlCache = [String:String]()
    static var bandDescriptionUrlDateCache = [String:String]()
    static var lastModifiedDate:Date? = nil;
}


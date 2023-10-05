//
//  Settings70k.swift
//  70K Bands
//
//  Created by Ron Dorn on 10/2/23.
//  Copyright © 2023 Ron Dorn. All rights reserved.
//

import Foundation

var mustSeeOn = true;
var mightSeeOn = true;
var wontSeeOn = true;
var unknownSeeOn = true;
var hideExpireScheduleData = true;
var showTheaterShows = true
var showPoolShows = true
var showRinkShows = true
var showLoungeShows = true
var showOtherShows = true
var showUnofficalEvents = true
var showSpecialEvents = true
var showMeetAndGreetEvents = true
var showOnlyWillAttened = false;
var sortedBy = "time"

var mustSeeAlertValue = true
var mightSeeAlertValue = true
var onlyAlertForAttendedValue = false

var alertForShowsValue = true
var alertForSpecialValue = true
var alertForMandGValue = false
var alertForUnofficalEventsValue = true
var alertForClinicEvents = false
var alertForListeningEvents = false

var notesFontSizeLargeValue = false

var minBeforeAlertValue = 10

var promptForAttended = true

var artistUrlPointer = "Current"
var scheduleUrlPointer  = "Current"

func setArtistUrl(_ value: String){
    print ("setupCurrentYearUrls: setting setArtistUrl to \(value)")
    artistUrlPointer = value
}
func getArtistUrl() -> String{
    print ("setupCurrentYearUrls: loading ArtistUrl of \(artistUrlPointer)")
    return artistUrlPointer
}

func setScheduleUrl(_ value: String){

    scheduleUrlPointer = value
}
func getScheduleUrl() -> String{
    return scheduleUrlPointer
}

func setPromptForAttended(_ value: Bool){
    promptForAttended = value
}
func getPromptForAttended()->Bool{
    return promptForAttended
}

func setMinBeforeAlertValue(_ value: Int){
    minBeforeAlertValue = value
}
func getMinBeforeAlertValue()->Int{
    return minBeforeAlertValue
}

func setNotesFontSizeLargeValue(_ value: Bool){
    notesFontSizeLargeValue = value
}
func getNotesFontSizeLargeValue()->Bool{
    return notesFontSizeLargeValue
}

func setAlertForListeningEvents(_ value: Bool){
    alertForListeningEvents = value
}
func getAlertForListeningEvents()->Bool{
    return alertForListeningEvents
}

func setAlertForClinicEvents(_ value: Bool){
    alertForClinicEvents = value
}
func getAlertForClinicEvents()->Bool{
    return alertForClinicEvents
}

func setAlertForUnofficalEventsValue(_ value: Bool){
    alertForUnofficalEventsValue = value
}
func getAlertForUnofficalEventsValue()->Bool{
    return alertForUnofficalEventsValue
}

func setAlertForMandGValue(_ value: Bool){
    alertForMandGValue = value
}
func getAlertForMandGValue()->Bool{
    return alertForMandGValue
}

func setAlertForShowsValue(_ value: Bool){
    alertForShowsValue = value
}
func getAlertForShowsValue()->Bool{
    return alertForShowsValue
}

func setAlertForSpecialValue(_ value: Bool){
    alertForSpecialValue = value
}
func getAlertForSpecialValue()->Bool{
    return alertForSpecialValue
}

func setMustSeeAlertValue(_ value: Bool){
    mustSeeAlertValue = value
}
func getMustSeeAlertValue()->Bool{
    return mustSeeAlertValue
}

func setMightSeeAlertValue(_ value: Bool){
    mightSeeAlertValue = value
}
func getMightSeeAlertValue()->Bool{
    return mightSeeAlertValue
}

func setOnlyAlertForAttendedValue(_ value: Bool){
    onlyAlertForAttendedValue = value
}
func getOnlyAlertForAttendedValue()->Bool{
    return onlyAlertForAttendedValue
}

func setShowTheaterShows(_ value: Bool){
    showTheaterShows = value
}
func getShowTheaterShows() -> Bool{
    return showTheaterShows
}

func setShowPoolShows(_ value: Bool){
    showPoolShows = value
}
func getShowPoolShows() -> Bool{
    return showPoolShows
}

func setShowRinkShows(_ value: Bool){
    showRinkShows = value
}
func getShowRinkShows() -> Bool{
    return showRinkShows
}

func setShowLoungeShows(_ value: Bool){
    showLoungeShows = value
}
func getShowLoungeShows() -> Bool{
    return showLoungeShows
}

func setShowOtherShows(_ value: Bool){
    showOtherShows = value
}
func getShowOtherShows() -> Bool{
    return showOtherShows
}

func setShowUnofficalEvents(_ value: Bool){
    showUnofficalEvents = value
}
func getShowUnofficalEvents() -> Bool{
    return showUnofficalEvents
}

func setShowSpecialEvents(_ value: Bool){
    showSpecialEvents = value
}
func getShowSpecialEvents() -> Bool{
    return showSpecialEvents
}

func setShowMeetAndGreetEvents(_ value: Bool){
    showMeetAndGreetEvents = value
}
func getShowMeetAndGreetEvents() -> Bool{
    return showMeetAndGreetEvents
}

func setHideExpireScheduleData(_ value: Bool){
    hideExpireScheduleData = value
}
func getHideExpireScheduleData() -> Bool{
    return hideExpireScheduleData
}

func setHideScheduleButton(_ value: Bool){
    hideScheduleButton = value
}

func getHideScheduleButton() -> Bool{
    return hideScheduleButton
}

func setScheduleButton(_ value: Bool){
    hideScheduleButton = value
}
func getScheduleButton() -> Bool{
    return hideScheduleButton
}

func setMustSeeOn(_ value: Bool){
    mustSeeOn = value
}
func getMustSeeOn() -> Bool{
    return mustSeeOn
}
func setMightSeeOn(_ value: Bool){
    mightSeeOn = value
}

func getMightSeeOn() -> Bool{
    return mightSeeOn
}
func setWontSeeOn(_ value: Bool){
    wontSeeOn = value
}
func getWontSeeOn() -> Bool{
    return wontSeeOn
}

func setUnknownSeeOn(_ value: Bool){
    unknownSeeOn = value
}
func getUnknownSeeOn() -> Bool{
    return unknownSeeOn
}

func setShowOnlyWillAttened(_ value: Bool){
    showOnlyWillAttened = value
    print ("Setting showOnlyWillAttened to \(value)")
}
func getShowOnlyWillAttened() -> Bool{
    print ("Returning showOnlyWillAttened as \(showOnlyWillAttened)")
    return showOnlyWillAttened
}

func setSortedBy(_ value: String){
    sortedBy = value
}
func getSortedBy() -> String{
    return sortedBy
}

func writeFiltersFile(){
    
    DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
        
        var prefsString = String()
        
        print ("Status of getWontSeeOn save = \(getWontSeeOn())")
        prefsString = "mustSeeOn:" + boolToString(getMustSeeOn()) + ";"
        prefsString += "mightSeeOn:" + boolToString(getMightSeeOn()) + ";"
        prefsString += "wontSeeOn:" + boolToString(getWontSeeOn()) + ";"
        prefsString += "unknownSeeOn:" + boolToString(getUnknownSeeOn()) + ";"
        prefsString += "showOnlyWillAttened:" + boolToString(getShowOnlyWillAttened()) + ";"
        prefsString += "sortedBy:" + getSortedBy() + ";"
        prefsString += "currentTimeZone:" + localTimeZoneAbbreviation + ";"
        prefsString += "hideExpireScheduleData:" + boolToString(getHideExpireScheduleData()) + ";"
        
        prefsString += "showTheaterShows:" + boolToString(getShowTheaterShows()) + ";"
        prefsString += "showPoolShows:" + boolToString(getShowPoolShows()) + ";"
        prefsString += "showRinkShows:" + boolToString(getShowRinkShows()) + ";"
        prefsString += "showLoungeShows:" + boolToString(getShowLoungeShows()) + ";"
        prefsString += "showOtherShows:" + boolToString(getShowOtherShows()) + ";"
        prefsString += "showUnofficalEvents:" + boolToString(getShowUnofficalEvents()) + ";"
        prefsString += "showSpecialEvents:" + boolToString(getShowSpecialEvents()) + ";"
        prefsString += "showMeetAndGreetEvents:" + boolToString(getShowMeetAndGreetEvents()) + ";"

        prefsString += "mustSeeAlertValue:" + boolToString(getMustSeeAlertValue()) + ";"
        prefsString += "mightSeeAlertValue:" + boolToString(getMightSeeAlertValue()) + ";"
        prefsString += "onlyAlertForAttendedValue:" + boolToString(getOnlyAlertForAttendedValue()) + ";"

        prefsString += "alertForShowsValue:" + boolToString(getAlertForShowsValue()) + ";"
        prefsString += "alertForSpecialValue:" + boolToString(getAlertForSpecialValue()) + ";"
        prefsString += "alertForMandGValue:" + boolToString(getAlertForMandGValue()) + ";"
        prefsString += "alertForUnofficalEventsValue:" + boolToString(getAlertForUnofficalEventsValue()) + ";"
        prefsString += "alertForClinicEvents:" + boolToString(getAlertForClinicEvents()) + ";"
        prefsString += "alertForListeningEvents:" + boolToString(getAlertForListeningEvents()) + ";"
        
        prefsString += "notesFontSizeLargeValue:" + boolToString(getNotesFontSizeLargeValue()) + ";"
        
        prefsString += "minBeforeAlertValue:" + String(getMinBeforeAlertValue()) + ";"

        prefsString += "promptForAttended:" + boolToString(getPromptForAttended()) + ";"
        
        prefsString += "sortedBy:" + getSortedBy() + ";"
        
        prefsString += "artistUrl:" + getArtistUrl() + ";"
        prefsString += "scheduleUrl:" + getScheduleUrl() + ";"
        
        print ("Wrote prefs " + prefsString)
        do {
            try prefsString.write(to: lastFilters, atomically: false, encoding: String.Encoding.utf8)
            print ("saved sortedBy = " + getSortedBy())
        } catch {
            print ("Status of getWontSeeOn NOT saved \(error.localizedDescription)")
        }
        print ("Saving showOnlyWillAttened = \(getShowOnlyWillAttened())")
    }
}


func readFiltersFile(){
    
    var tempCurrentTimeZone = "";
    
    print ("Status of getWontSeeOn loading")
    if (FileManager.default.fileExists(atPath:lastFilters.relativePath) == false){
        print ("lastFilters does not exist")
        return()
    }
    
    if let data = try? String(contentsOf:lastFilters, encoding: String.Encoding.utf8) {
        print ("Status of sortedBy loading 1 " + data)
        let dataArray = data.components(separatedBy: ";")
        for record in dataArray {
            print ("Status of getWontSeeOn loading loop")
            var valueArray = record.components(separatedBy: ":")
            
            switch valueArray[0] {
                
            case "mustSeeOn":
                setMustSeeOn(stringToBool(valueArray[1]))
            
            case "mightSeeOn":
                setMightSeeOn(stringToBool(valueArray[1]))
           
            case "wontSeeOn":
                setWontSeeOn(stringToBool(valueArray[1]))
                print ("Status of getWontSeeOn load = \(valueArray[1])")
            
            case "unknownSeeOn":
                setUnknownSeeOn(stringToBool(valueArray[1]))
            
            case "showOnlyWillAttened":
                setShowOnlyWillAttened(stringToBool(valueArray[1]))
            
            case "currentTimeZone":
                tempCurrentTimeZone = valueArray[1]
            
            case "sortedBy":
                print ("activly Loading sortedBy = " + valueArray[1])
                setSortedBy(valueArray[1])
            
            case "hideExpireScheduleData":
                setHideExpireScheduleData(stringToBool(valueArray[1]))

            case "showTheaterShows":
                setShowTheaterShows(stringToBool(valueArray[1]))
            
            case "showPoolShows":
                setShowPoolShows(stringToBool(valueArray[1]))

            case "showRinkShows":
                setShowRinkShows(stringToBool(valueArray[1]))
            
            case "showLoungeShows":
                setShowLoungeShows(stringToBool(valueArray[1]))
            
            case "showOtherShows":
                setShowOtherShows(stringToBool(valueArray[1]))
            
            case "showUnofficalEvents":
                setShowUnofficalEvents(stringToBool(valueArray[1]))
            
            case "showSpecialEvents":
                setShowSpecialEvents(stringToBool(valueArray[1]))
            
            case "showMeetAndGreetEvents":
                setShowMeetAndGreetEvents(stringToBool(valueArray[1]))

            case "mustSeeAlertValue":
                setMustSeeAlertValue(stringToBool(valueArray[1]))
                
            case "mightSeeAlertValue":
                setMightSeeAlertValue(stringToBool(valueArray[1]))
                
            case "onlyAlertForAttendedValue":
                setOnlyAlertForAttendedValue(stringToBool(valueArray[1]))
                
            case "alertForShowsValue":
                setAlertForShowsValue(stringToBool(valueArray[1]))
                
            case "alertForSpecialValue":
                setAlertForSpecialValue(stringToBool(valueArray[1]))
                
            case "alertForMandGValue":
                setAlertForMandGValue(stringToBool(valueArray[1]))

            case "alertForListeningEvents":
                setAlertForListeningEvents(stringToBool(valueArray[1]))
                
            case "alertForClinicEvents":
                setAlertForClinicEvents(stringToBool(valueArray[1]))
                
            case "alertForUnofficalEventsValue":
                setAlertForUnofficalEventsValue(stringToBool(valueArray[1]))
                
            case "notesFontSizeLargeValue":
                setNotesFontSizeLargeValue(stringToBool(valueArray[1]))
            
            case "promptForAttended":
                setPromptForAttended(stringToBool(valueArray[1]))
                
            case "minBeforeAlertValue":
                setMinBeforeAlertValue(Int(valueArray[1]) ?? 10)
            
            case "sortedBy":
                setSortedBy(valueArray[1])
                
            case "artistUrl":
                setArtistUrl(valueArray[1])
                
            case "scheduleUrl":
                setScheduleUrl(valueArray[1])
                
                default:
                    print("Not sure why this would happen")
            }
        }
        print ("Loading setScheduleUrl = \(getScheduleUrl())")
        print ("Loading mustSeeOn = \(getMustSeeOn())")
    }
    
    if (tempCurrentTimeZone != localTimeZoneAbbreviation){
        alertTracker = [String]()
        let localNotification = localNoticationHandler()
        localNotification.clearNotifications()
        localNotification.addNotifications()
    }
}


func boolToString(_ value: Bool) -> String{
    
    var result = String()
    
    if (value == true){
        result = "true"
    } else {
        result = "false"
    }
    
    return result
}

func stringToBool(_ value: String) -> Bool{
    
    var result = Bool()
    
    if (value == "true"){
        result = true
    } else {
        result = false
    }
    
    return result
}

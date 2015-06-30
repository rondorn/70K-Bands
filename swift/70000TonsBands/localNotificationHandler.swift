//
//  localNotificationHandler.swift
//  70K Bands
//
//  Created by Ron Dorn on 2/6/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import UIKit

class localNoticationHandler {
    
    var schedule = scheduleHandler()
    var alertTextMessage = String()
    
    init(){
        schedule.populateSchedule()
    }
    
    func willAddToNotifications(bandName: String, eventTypeValue: String) -> Bool{
        
        let defaults = NSUserDefaults.standardUserDefaults()
        var mustSeeAlert = defaults.boolForKey("mustSeeAlert")
        var mightSeeAlert = defaults.boolForKey("mightSeeAlert")
        var alertForShows = defaults.boolForKey("alertForShows")
        var alertForSpecial = defaults.boolForKey("alertForSpecial")
        var alertForMandG = defaults.boolForKey("alertForMandG")
        var alertForClinics = defaults.boolForKey("alertForClinics")
        var alertForListening = defaults.boolForKey("alertForListening")
        
        print ("Checking for alert for bands " + bandName + " ... ")
        
        var alertStatus = false
        
        if (eventTypeValue == specialEventType && alertForSpecial == true){
            alertStatus = true
        }
        if (eventTypeValue == showType && alertForShows == true){
            alertStatus = checkBandPriority(bandName, mustSeeAlert: mustSeeAlert, mightSeeAlert: mightSeeAlert)
        }
        if (eventTypeValue == listeningPartyType && alertForListening == true){
            alertStatus = checkBandPriority(bandName, mustSeeAlert: mustSeeAlert, mightSeeAlert: mightSeeAlert)
        }
        if (eventTypeValue == meetAndGreetype && alertForMandG == true){
            alertStatus = checkBandPriority(bandName, mustSeeAlert: mustSeeAlert, mightSeeAlert: mightSeeAlert)
        }
        if (eventTypeValue == clinicType && alertForClinics == true){
            alertStatus = checkBandPriority(bandName, mustSeeAlert: mustSeeAlert, mightSeeAlert: mightSeeAlert)
        }
        
        return alertStatus
    }
    
    func checkBandPriority (bandName: String, mustSeeAlert: Bool, mightSeeAlert: Bool)->Bool{
        
        if (mustSeeAlert == true && getPriorityData(bandName) == 1){
            println("Ok")
            return true
        }
        if (mightSeeAlert == true && getPriorityData(bandName) == 2){
            println("Ok")
            return true
        }
        
        return false
    }
    
    func getAlertMessage(name:String, indexValue: NSDate){
        
        var eventType = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: "Type")
        
        switch eventType {
            
        case showType:
            showMessage(name, indexValue: indexValue)
            
        case specialEventType:
            specialEventMessage(name, indexValue: indexValue)
            
        case meetAndGreetype:
            meetingAndGreetMessage(name, indexValue: indexValue)
            
        case clinicType:
            clinicMessage(name, indexValue: indexValue)
            
        case listeningPartyType:
            listeningPartyMessage (name, indexValue: indexValue)
            
        default:
            println("Unknown type")
            
        }
    }
    
    func showMessage(name:String, indexValue: NSDate){
        
        var locationName = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: locationField)
        var startingTime = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: startTimeField)
        
        alertTextMessage = name + " will be playing the " + locationName + " at " + startingTime
    }
    
    func specialEventMessage(name:String, indexValue: NSDate){
        
        var locationName = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: locationField)
        var startingTime = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: startTimeField)
        
        alertTextMessage = "Special event '" + name + "' taking place at the " + locationName + " starting at " + startingTime
    }
    
    func meetingAndGreetMessage(name:String, indexValue: NSDate){
        
        var locationName = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: locationField)
        var startingTime = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: startTimeField)
        
        alertTextMessage = name + " is holding a Meet and Greet at the " + locationName + " starting at " + startingTime
    }
    
    func listeningPartyMessage(name:String, indexValue: NSDate){
        
        var locationName = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: locationField)
        var startingTime = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: startTimeField)
        
        alertTextMessage = name + " is holding a new album listening party at the " + locationName + " starting at " + startingTime
    }
    
    func clinicMessage(name:String, indexValue: NSDate){
        
        var locationName = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: locationField)
        var startingTime = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: startTimeField)
        var note = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: notesField)
        
        alertTextMessage = note + " from " + name + " is holding a clinic at the " + locationName + " starting at " + startingTime
    }
    
    func addNotifications(){
        
        if (schedule.schedulingData.isEmpty == false){
            for bandName in schedule.schedulingData{
                for startTime in schedule.schedulingData[bandName.0]!{
                    var alertTime = NSDate(timeIntervalSince1970: startTime.0)
                    println ("Date provided is \(alertTime)")
                    if (willAddToNotifications(bandName.0, eventTypeValue:schedule.schedulingData[bandName.0]![startTime.0]![typeField]!) == true){
                        let compareResult = alertTime.compare(NSDate())
                        if compareResult == NSComparisonResult.OrderedDescending {
                            
                            getAlertMessage(bandName.0, indexValue: alertTime)
                            addNotification(alertTextMessage, showTime: alertTime)
                        }
                    }
                }
            }
        }
    }
    
    func addNotification(message: String, showTime: NSDate) {
        let defaults = NSUserDefaults.standardUserDefaults()
        var minBeforeAlert = -defaults.integerForKey("minBeforeAlert")
        
        var alertTime = NSCalendar.currentCalendar().dateByAddingUnit(
            .CalendarUnitMinute,
            value: minBeforeAlert,
            toDate: showTime,
            options: NSCalendarOptions(0))
        
        var localNotification:UILocalNotification = UILocalNotification()
        localNotification.alertBody = message
        localNotification.fireDate = alertTime
        localNotification.timeZone = NSTimeZone.defaultTimeZone()
        localNotification.soundName = "OnMyWayToDeath.wav"
        
        UIApplication.sharedApplication().scheduleLocalNotification(localNotification)
        
        
        var dateFormatter = NSDateFormatter();
        dateFormatter.dateFormat = "M-d-yy h:mm a"
        dateFormatter.timeZone = NSTimeZone.defaultTimeZone()
        
        println ("Adding alert message " + message + " for alert at " + dateFormatter.stringFromDate(alertTime!))
        
    }
    
    func clearNotifications(){
        UIApplication.sharedApplication().cancelAllLocalNotifications()
    }
}

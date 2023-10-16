//
//  localNotificationHandler.swift
//  70K Bands
//
//  Created by Ron Dorn on 2/6/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import UIKit
import UserNotifications

class localNoticationHandler {
    
    var schedule = scheduleHandler()
    var alertTextMessage = String()
    let attendedHandle = ShowsAttended()
    var dataHandle = dataHandler()
    
    init(){

    }

    func refreshAlerts(){
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            if #available(iOS 10.0, *) {
                let localNotication = localNoticationHandler()
                localNotication.addNotifications()
            } else {
                // Fallback on earlier versions
            }
        }
    }
    
    func willAddToNotifications(_ bandName: String, eventType :String, startTime: String, location:String) -> Bool{
        

        print ("Checking for alert for bands " + bandName + " ... ", terminator: "")
        
        var alertStatus = false
        
        let attendedStatus = attendedHandle.getShowAttendedStatus(band: bandName, location: location, startTime: startTime, eventType: eventType,eventYearString: String(eventYear));
        
        print ("Checking for alert for getOnlyAlertForAttendedValue \(getOnlyAlertForAttendedValue())")
        if (getOnlyAlertForAttendedValue() == true){
            print ("Checking for alert for attendedStatus \(attendedStatus)")
            if (attendedStatus != sawNoneStatus){
                alertStatus = true
            }
        } else {
            if (eventType == specialEventType && getAlertForSpecialValue() == true){
                alertStatus = true
            }
            if (eventType == showType && getAlertForShowsValue() == true){
                alertStatus = checkBandPriority(bandName, attendedStatus:attendedStatus)
            }
            if (eventType == listeningPartyType && getAlertForListeningEvents() == true){
                alertStatus = checkBandPriority(bandName, attendedStatus:attendedStatus)
            }
            if (eventType == meetAndGreetype && getAlertForMandGValue() == true){
                alertStatus = checkBandPriority(bandName, attendedStatus:attendedStatus)
            }
            if (eventType == clinicType && getAlertForClinicEvents() == true){
                alertStatus = checkBandPriority(bandName, attendedStatus:attendedStatus)
            }
            if ((eventType == unofficalEventType || eventType == unofficalEventTypeOld) && getAlertForUnofficalEventsValue() == true){
                alertStatus = checkBandPriority(bandName, attendedStatus:attendedStatus)
                print ("alertUnofficial is set to \(alertStatus) for \(bandName)")
            }
        }
        
        return alertStatus
    }
    
    func checkBandPriority (_ bandName: String, attendedStatus: String)->Bool{
        
        if (getMustSeeAlertValue() == true && dataHandle.getPriorityData(bandName) == 1){
            return true
        }
        if (getMightSeeAlertValue()  == true && dataHandle.getPriorityData(bandName) == 2){
            return true
        }
        
        if (getMustSeeAlertValue() == true && attendedStatus != sawNoneStatus){
            return true
        }
        
        return false
    }
    
    func getAlertMessage(_ name:String, indexValue: Date){
        
        let eventType = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: "Type")
        
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
        
        case unofficalEventType:
            unofficalEventMessage(name, indexValue: indexValue)
            
        default:
            print("Unknown type")
            
        }
    }
    
    func showMessage(_ name:String, indexValue: Date){
        
        let locationName = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: locationField)
        let startingTime = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: startTimeField)
        
        alertTextMessage = name + " will be playing the " + locationName + " at " + formatTimeValue(timeValue: startingTime)
    }
    
    func specialEventMessage(_ name:String, indexValue: Date){
        
        let locationName = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: locationField)
        let startingTime = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: startTimeField)
        
        alertTextMessage = "Special event '" + name + "' is taking place at the " + locationName + " starting at " + formatTimeValue(timeValue: startingTime)
    }

    func unofficalEventMessage(_ name:String, indexValue: Date){
        
        let locationName = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: locationField)
        let startingTime = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: startTimeField)
        
        alertTextMessage = "Unoffical event '" + name + "' is taking place at " + locationName + " starting at " + formatTimeValue(timeValue: startingTime)
    }
    
    func meetingAndGreetMessage(_ name:String, indexValue: Date){
        
        let locationName = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: locationField)
        let startingTime = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: startTimeField)
        
        alertTextMessage = name + " is holding a Meet and Greet at the " + locationName + " starting at " + formatTimeValue(timeValue: startingTime)
    }
    
    func listeningPartyMessage(_ name:String, indexValue: Date){
        
        let locationName = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: locationField)
        let startingTime = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: startTimeField)
        
        alertTextMessage = name + " is holding a new album listening party at the " + locationName + " starting at " + formatTimeValue(timeValue: startingTime)
    }
    
    func clinicMessage(_ name:String, indexValue: Date){
        
        let locationName = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: locationField)
        let startingTime = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: startTimeField)
        let note = schedule.getData(name, index: indexValue.timeIntervalSince1970, variable: notesField)
        
        alertTextMessage = note + " from " + name + " is holding a clinic at the " + locationName + " starting at " + formatTimeValue(timeValue: startingTime)
    }
    
    func addNotifications(){
        
        print ("Locking object with schedule.schedulingData")
        
        scheduleQueue.sync {

            if (schedule.schedulingData.isEmpty == false){
                for bandName in schedule.schedulingData{
                    for startTime in schedule.schedulingData[bandName.0]!{
                        let alertTime = NSDate(timeIntervalSince1970: startTime.0)
                        //print ("Adding notificaiton \(bandName) Date provided is \(alertTime)")
                        if (startTime.0.isZero == false && bandName.0.isEmpty == false && typeField.isEmpty == false){
                            
                            if (schedule.schedulingData[bandName.0]?[startTime.0]?[typeField]?.isEmpty == false){
                                let eventTypeValue = (schedule.schedulingData[bandName.0]?[startTime.0]?[typeField])!
                                let startTimeValue = (schedule.schedulingData[bandName.0]?[startTime.0]?[startTimeField])!
                                let locationValue = (schedule.schedulingData[bandName.0]?[startTime.0]?[locationField])!
                                
                                let addToNoticication = willAddToNotifications(bandName.0, eventType: eventTypeValue, startTime: startTimeValue, location:locationValue)
                                
                                if (addToNoticication == true){
                                    let compareResult = alertTime.compare(NSDate() as Date)
                                    if compareResult == ComparisonResult.orderedDescending {
                                        print ("Adding notificaiton \(alertTextMessage) for \(alertTime)")
                                        getAlertMessage(bandName.0, indexValue: alertTime as Date)
                                        addNotification(message: alertTextMessage, showTime: alertTime)

                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func addNotification(message: String, showTime: NSDate) {
        
        if (alertTracker.contains(message) == false){
            
            alertTracker.append(message)
            
            let minBeforeAlert = getMinBeforeAlertValue()
            
            let alertTime = (Calendar.current as NSCalendar).date(
                byAdding: .minute,
                value: -minBeforeAlert,
                to: showTime as Date,
                options: NSCalendar.Options(rawValue: 0))
            
            let epocAlertTime = alertTime?.timeIntervalSince1970;
            let epocCurrentTime = Date().timeIntervalSince1970
            
            let alertTimeInSeconds = epocAlertTime! - epocCurrentTime;
            
            if (alertTimeInSeconds > 0){
                print ("sendLocalAlert! \(String(describing: epocAlertTime)) minus \(epocCurrentTime) equals \(alertTimeInSeconds)")
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: alertTimeInSeconds, repeats: false)
                
                let content = UNMutableNotificationContent()
                content.body = message
                content.sound = UNNotificationSound.init(named: UNNotificationSoundName(rawValue: "OnMyWayToDeath.wav"))
                
                let request = UNNotificationRequest(identifier: message, content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(request)
                
                print ("sendLocalAlert! Adding alert \(message) for alert at \(alertTimeInSeconds) -n\(getMinBeforeAlertValue())")
            }
        }
        
    }
    
    func clearNotifications(){
        print ("sendLocalAlert! clearing all alerts")
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        alertTracker = [String]()
    }
}

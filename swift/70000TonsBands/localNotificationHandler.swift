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
    
    var schedule = scheduleHandler.shared
    var alertTextMessage = String()
    let attendedHandle = ShowsAttended()
    var dataHandle = dataHandler()
    
    /**
     Initializes a new instance of localNoticationHandler.
     */
    init(){

    }

    /**
     Refreshes alerts by asynchronously adding notifications, depending on iOS version.
     */
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
    
    /**
     Determines if an event should be added to notifications based on band, event type, and user preferences.
     - Parameters:
        - bandName: The name of the band.
        - eventType: The type of event.
        - startTime: The start time of the event.
        - location: The location of the event.
     - Returns: true if the event should be added to notifications, false otherwise.
     */
    func willAddToNotifications(_ bandName: String, eventType :String, startTime: String, location:String) -> Bool{
        

        print ("Checking for alert for bands " + bandName + " ... ", terminator: "")
        
        var alertStatus = false
        
        let attendedStatus = attendedHandle.getShowAttendedStatus(band: bandName, location: location, startTime: startTime, eventType: eventType,eventYearString: String(eventYear));
        print ("AttendedAlertDebug: \(attendedStatus) for \(bandName) - \(location) - \(startTime) - \(eventType) - \(eventYear)")
        
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
    
    /**
     Checks if a band should trigger an alert based on priority and attendance status.
     - Parameters:
        - bandName: The name of the band.
        - attendedStatus: The attendance status for the band.
     - Returns: true if the band should trigger an alert, false otherwise.
     */
    func checkBandPriority (_ bandName: String, attendedStatus: String)->Bool{
        
        let priorityManager = SQLitePriorityManager.shared
        if (getMustSeeAlertValue() == true && priorityManager.getPriority(for: bandName) == 1){
            return true
        }
        if (getMightSeeAlertValue()  == true && priorityManager.getPriority(for: bandName) == 2){
            return true
        }
        
        if (getMustSeeAlertValue() == true && attendedStatus != sawNoneStatus){
            return true
        }
        
        return false
    }
    
    /**
     Sets the alert message for a given event name and date, based on event type.
     - Parameters:
        - name: The name of the event or band.
        - indexValue: The date of the event.
     */
    func getAlertMessage(_ name:String, indexValue: Date){
        
        let eventType = schedule.getData(name, index: indexValue.timeIntervalSinceReferenceDate, variable: "Type")
        
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
        
        case unofficalEventType, unofficalEventTypeOld:
            unofficalEventMessage(name, indexValue: indexValue)
            
        default:
            print("Unknown type")
            
        }
    }
    
    /**
     Sets the alert message for a show event.
     - Parameters:
        - name: The name of the band.
        - indexValue: The date of the event.
     */
    func showMessage(_ name:String, indexValue: Date){
        
        let locationName = schedule.getData(name, index: indexValue.timeIntervalSinceReferenceDate, variable: locationField)
        let startingTime = schedule.getData(name, index: indexValue.timeIntervalSinceReferenceDate, variable: startTimeField)
        
        alertTextMessage = name + " will be playing the " + locationName + " at " + formatTimeValue(timeValue: startingTime)
    }
    
    /**
     Sets the alert message for a special event.
     - Parameters:
        - name: The name of the event.
        - indexValue: The date of the event.
     */
    func specialEventMessage(_ name:String, indexValue: Date){
        
        let locationName = schedule.getData(name, index: indexValue.timeIntervalSinceReferenceDate, variable: locationField)
        let startingTime = schedule.getData(name, index: indexValue.timeIntervalSinceReferenceDate, variable: startTimeField)
        
        alertTextMessage = "Special event '" + name + "' is taking place at the " + locationName + " starting at " + formatTimeValue(timeValue: startingTime)
    }

    /**
     Sets the alert message for an unofficial event.
     - Parameters:
        - name: The name of the event.
        - indexValue: The date of the event.
     */
    func unofficalEventMessage(_ name:String, indexValue: Date){
        
        let locationName = schedule.getData(name, index: indexValue.timeIntervalSinceReferenceDate, variable: locationField)
        let startingTime = schedule.getData(name, index: indexValue.timeIntervalSinceReferenceDate, variable: startTimeField)
        
        alertTextMessage = "Unoffical event '" + name + "' is taking place at " + locationName + " starting at " + formatTimeValue(timeValue: startingTime)
    }
    
    /**
     Sets the alert message for a meet and greet event.
     - Parameters:
        - name: The name of the band.
        - indexValue: The date of the event.
     */
    func meetingAndGreetMessage(_ name:String, indexValue: Date){
        
        let locationName = schedule.getData(name, index: indexValue.timeIntervalSinceReferenceDate, variable: locationField)
        let startingTime = schedule.getData(name, index: indexValue.timeIntervalSinceReferenceDate, variable: startTimeField)
        
        alertTextMessage = name + " is holding a Meet and Greet at the " + locationName + " starting at " + formatTimeValue(timeValue: startingTime)
    }
    
    /**
     Sets the alert message for a listening party event.
     - Parameters:
        - name: The name of the band.
        - indexValue: The date of the event.
     */
    func listeningPartyMessage(_ name:String, indexValue: Date){
        
        let locationName = schedule.getData(name, index: indexValue.timeIntervalSinceReferenceDate, variable: locationField)
        let startingTime = schedule.getData(name, index: indexValue.timeIntervalSinceReferenceDate, variable: startTimeField)
        
        alertTextMessage = name + " is holding a new album listening party at the " + locationName + " starting at " + formatTimeValue(timeValue: startingTime)
    }
    
    /**
     Sets the alert message for a clinic event.
     - Parameters:
        - name: The name of the band.
        - indexValue: The date of the event.
     */
    func clinicMessage(_ name:String, indexValue: Date){
        
        let locationName = schedule.getData(name, index: indexValue.timeIntervalSinceReferenceDate, variable: locationField)
        let startingTime = schedule.getData(name, index: indexValue.timeIntervalSinceReferenceDate, variable: startTimeField)
        let note = schedule.getData(name, index: indexValue.timeIntervalSinceReferenceDate, variable: notesField)
        
        alertTextMessage = note + " from " + name + " is holding a clinic at the " + locationName + " starting at " + formatTimeValue(timeValue: startingTime)
    }
    
    /**
     Adds notifications for all eligible events in the schedule.
     TIMEZONE FIX: Recalculates event times using current timezone, not pre-calculated values.
     This ensures notifications fire at the correct local time even after timezone changes.
     */
    func addNotifications(){
        
        print ("✅ [THREAD_SAFE] addNotifications: No locking needed with SQLite")
        print ("🌍 [ALERT_TIMEZONE] Scheduling alerts using current timezone: \(TimeZone.current.identifier)")

        // YEAR CHANGE / CSV DOWNLOAD GUARD:
        // Avoid generating notifications while the year-change pipeline is importing schedule/band data.
        // This prevents lock contention and “deadlock-like” hangs during year switches.
        if MasterViewController.isYearChangeInProgress {
            print("🚫 [YEAR_CHANGE] addNotifications: Skipping - year change in progress")
            return
        }
        if MasterViewController.isCsvDownloadInProgress {
            print("🚫 [YEAR_CHANGE] addNotifications: Skipping - CSV download in progress")
            return
        }

        // CURRENT YEAR ONLY:
        // Notifications are only meaningful for the current sailing year.
        // If the user is browsing a past year, skip notification generation entirely.
        let currentYearFromPointer = Int(getPointerUrlData(keyValue: "eventYear")) ?? eventYear
        if eventYear != currentYearFromPointer {
            print("🚫 [ALERTS] addNotifications: Skipping - non-current year selected (eventYear=\(eventYear), current=\(currentYearFromPointer))")
            return
        }
        
        // Don't add notifications if schedule data is empty or inconsistent
        if schedule.schedulingData.isEmpty {
            print("[YEAR_CHANGE_DEBUG] addNotifications: Skipping - schedule data is empty")
            return
        }
        
        // ✅ DEADLOCK FIX: Removed scheduleQueue.sync - SQLite is thread-safe, no blocking needed
        if (schedule.schedulingData.isEmpty == false){
                for bandName in schedule.schedulingData{
                    guard let bandSchedule = schedule.schedulingData[bandName.0] else {
                        print("[YEAR_CHANGE_DEBUG] addNotifications: Skipping band \(bandName.0) - no schedule data")
                        continue
                    }
                    
                    for startTime in bandSchedule{
                        //print ("Adding notificaiton \(bandName) Date provided is \(alertTime)")
                        if (startTime.0.isZero == false && bandName.0.isEmpty == false && typeField.isEmpty == false){
                            
                            guard let eventData = schedule.schedulingData[bandName.0]?[startTime.0],
                                  let eventTypeValue = eventData[typeField],
                                  let startTimeValue = eventData[startTimeField],
                                  let dateValue = eventData[dateField],
                                  let locationValue = eventData[locationField],
                                  !eventTypeValue.isEmpty else {
                                print("[YEAR_CHANGE_DEBUG] addNotifications: Skipping event - missing required data for \(bandName.0) at \(startTime.0)")
                                continue
                            }
                            
                            // TIMEZONE FIX: Recalculate alert time using CURRENT timezone, not stored timeIndex
                            // This ensures the notification fires at the correct local time
                            let recalculatedTimeIndex = calculateTimeIndexForAlert(date: dateValue, time: startTimeValue)
                            
                            // Skip if we couldn't parse the time
                            if recalculatedTimeIndex == -1 {
                                print("⚠️ [ALERT_TIMEZONE] Failed to parse time for \(bandName.0) - skipping alert")
                                continue
                            }
                            
                            let alertTime = NSDate(timeIntervalSinceReferenceDate: recalculatedTimeIndex)
                            
                            let addToNoticication = willAddToNotifications(bandName.0, eventType: eventTypeValue, startTime: startTimeValue, location:locationValue)
                            
                            if (addToNoticication == true){
                                let compareResult = alertTime.compare(NSDate() as Date)
                                if compareResult == ComparisonResult.orderedDescending {
                                    print ("🔔 [ALERT_TIMEZONE] Scheduling notification for \(bandName.0) at \(alertTime) (current TZ)")
                                    getAlertMessage(bandName.0, indexValue: alertTime as Date)
                                    addNotification(message: alertTextMessage, showTime: alertTime)

                                }
                            }
                        }
                    }
                }
            }
        // ✅ DEADLOCK FIX: Removed closing brace of scheduleQueue.sync block
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
    
    // MARK: - Timezone-Independent Time Calculation
    
    /**
     Calculate time index at alert scheduling time using CURRENT timezone.
     This ensures that if the user changes timezones, alerts are recalculated correctly
     and always fire at the same wall-clock time regardless of device timezone.
     
     - Parameters:
        - date: Date string from event data (e.g., "12/07/2025")
        - time: Time string from event data (e.g., "17:00")
     - Returns: timeIntervalSinceReferenceDate for the event, or -1 if parsing fails
     */
    private func calculateTimeIndexForAlert(date: String, time: String) -> Double {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current // Use CURRENT timezone at alert scheduling time
        
        let dateTimeString = "\(date) \(time)"
        
        // Try multiple date formats to handle different CSV formats
        let formats = [
            "M/d/yyyy HH:mm",      // Single digit month/day + 24-hour (e.g., "1/26/2026 15:00")
            "MM/dd/yyyy HH:mm",    // Padded + 24-hour (e.g., "01/26/2026 15:00")
            "M/d/yyyy H:mm",       // Single digit month/day/hour (e.g., "1/30/2025 17:15")
            "MM/dd/yyyy H:mm",     // Padded date + single digit hour
            "M/d/yyyy h:mm a",     // 12-hour with AM/PM
            "MM/dd/yyyy h:mm a",   // Padded + 12-hour with AM/PM
        ]
        
        for format in formats {
            formatter.dateFormat = format
            if let parsedDate = formatter.date(from: dateTimeString) {
                let timeIndex = parsedDate.timeIntervalSinceReferenceDate
                print("🌍 [ALERT_TIMEZONE] Parsed '\(dateTimeString)' as \(parsedDate) in timezone \(TimeZone.current.identifier)")
                return timeIndex
            }
        }
        
        // If parsing fails, return -1 to signal error
        print("⚠️ [ALERT_TIMEZONE] Failed to parse '\(dateTimeString)' with any known format")
        return -1
    }
}

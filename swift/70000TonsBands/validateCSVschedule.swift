//
//  validateCSVschedule.swift
//  70K Bands
//
//  Created by Ron Dorn on 2/7/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import UIKit

class validateCSVSchedule {
    
    let scheduleFile = URL(fileURLWithPath: dirs[0]).appendingPathComponent( "scheduleFile.txt")

    var numberOfShows = 0
    var numberOfClinics = 0
    var numberOfSpecialEvents = 0
    var numberOfmAndg = 0
    var numberOfListering = 0
    
    var eventsPerDate = Dictionary<Date, Int>()
    var eventsPerDay = Dictionary<String, Int>()
    var errorMessage = ""
    var summaryMessage = ""
    
    var bands = [String]()
    
    var dateFormatter = DateFormatter();
    var sortedDates = [Date]()
    
    init(){
        dateFormatter.dateFormat = "M-d-yy"
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    }
    
    func validateSchedule(){
        
        let defaults = UserDefaults.standard
        let validateSchedulePreference = defaults.bool(forKey: "validateScheduleFile")
        
        if (validateSchedulePreference == true){
            bands = getBandNames()
            var scheduleFileString = ""
            do {
                scheduleFileString = try String(contentsOf:scheduleFile);
            } catch _ {
                //do nothing
            }
            if let csvDataString = try? String(contentsOfFile: scheduleFileString, encoding: String.Encoding.utf8) {
                
                var csvData: CSV
                var error: NSErrorPointer? = nil
                csvData = try! CSV(csvStringToParse: csvDataString)
                
                verifyExpectedFieldsExists(csvData)
                verifyTypes(csvData)
                verifyBandNames(csvData)
                verifySaneDates(csvData)
                validateDayField(csvData)
                validateTimeField(csvData, fieldName: startTimeField)
                validateTimeField(csvData, fieldName: endTimeField)
                
                summaryMessage = "number Of Shows = " + String(numberOfShows) + "\n"
                summaryMessage += "number Of Clinics = " + String(numberOfClinics) + "\n"
                summaryMessage += "number Of SpecialEvents = " + String(numberOfSpecialEvents) + "\n"
                summaryMessage += "number Of Meet and Greets = " + String(numberOfmAndg) + "\n"
                summaryMessage += "number Of Listering Parties = " + String(numberOfListering) + "\n\n"
                
                for index in eventsPerDay {
                    summaryMessage += index.0 + " has " + String(index.1) + " events\n"
                }
                
                summaryMessage += "\n"
                
                //for index in eventsPerDate {
                for index in sortedDates {
                    let date = dateFormatter.string(from: index)
                    let events = String(eventsPerDate[index]!)
                    summaryMessage += date + " has " + events + " events\n"
                }
                
            } else {
                errorMessage = "Schedule file was not found\n"
            }
            
            showAlert(summaryMessage, title: "Verification Summary Message")
            showAlert(errorMessage, title: "Verification Error Message")
        }
    }
        
    func validateTimeField(_ csvData: CSV, fieldName: String){
        
        var count = 1;
        
        for lineData in csvData.rows {
            
            count = count + 1
            
            let pattern = "^\\d{1,2}:\\d{1,2}\\sAM|PM$"
            var error: NSError? = nil
            var regex: NSRegularExpression?
            do {
                regex = try NSRegularExpression(pattern: pattern, options: NSRegularExpression.Options.dotMatchesLineSeparators)
            } catch let error1 as NSError {
                error = error1
                regex = nil
            }
            
        }

    }
    
    func validateDayField(_ csvData: CSV){
        
        var count = 1;
        
        for lineData in csvData.rows {
            
            count = count + 1
            
            switch lineData[dayField]!{
            case "Mon":
                if (eventsPerDay["Mon"] == nil){
                    eventsPerDay["Mon"] = 1
                } else {
                    eventsPerDay["Mon"] = eventsPerDay["Mon"]! + 1
                }
            case "Tue":
                if (eventsPerDay["Tue"] == nil){
                    eventsPerDay["Tue"] = 1
                } else {
                    eventsPerDay["Tue"] = eventsPerDay["Tue"]! + 1
                }
            case "Wed":
                if (eventsPerDay["Wed"] == nil){
                    eventsPerDay["Wed"] = 1
                } else {
                    eventsPerDay["Wed"] = eventsPerDay["Wed"]! + 1
                }
            case "Thu":
                if (eventsPerDay["Thu"] == nil){
                    eventsPerDay["Thu"] = 1
                } else {
                    eventsPerDay["Thu"] = eventsPerDay["Thu"]! + 1
                }
            case "Fri":
                if (eventsPerDay["Fri"] == nil){
                    eventsPerDay["Fri"] = 1
                } else {
                    eventsPerDay["Fri"] = eventsPerDay["Fri"]! + 1
                }
            case "Sat":
                if (eventsPerDay["Sat"] == nil){
                    eventsPerDay["Sat"] = 1
                } else {
                    eventsPerDay["Sat"] = eventsPerDay["Sat"]! + 1
                }
            case "Sun":
                    if (eventsPerDay["Sun"] == nil){
                        eventsPerDay["Sun"] = 1
                    } else {
                        eventsPerDay["Sun"] = eventsPerDay["Sun"]! + 1
                }
            default:
                errorMessage += "Unknown day of week '" + lineData[dayField]! + "' found on line " + String(count) + "\n"
            }
        }
    
    }

    func verifySaneDates (_ csvData: CSV){
        
        for lineData in csvData.rows {

            var startTimeIndex = Date()
            let fullTimeString: String = lineData[dateField]!
            
            startTimeIndex = dateFormatter.date(from: fullTimeString)!
            
            if (eventsPerDate[startTimeIndex] == nil){
                sortedDates.append(startTimeIndex)
                eventsPerDate[startTimeIndex] = 1
            } else {
               eventsPerDate[startTimeIndex] = eventsPerDate[startTimeIndex]!  + 1
            }
        
        }
        
        sortedDates.sorted(by: {
            $1.compare($0) == ComparisonResult.orderedDescending
        })

    }
    
    func verifyExpectedFieldsExists(_ csvData: CSV){
        for lineData in csvData.rows {
            if (lineData[bandField] == nil){
                errorMessage += "'Band' field not found\n"
            }
            if (lineData[locationField] == nil){
                errorMessage += "'Location' field not found\n"
            }
            if (lineData[bandField] == nil){
                errorMessage += "'Date' field not found\n"
            }
            if (lineData[dayField] == nil){
                errorMessage += "'Day' field not found\n"
            }
            if (lineData[startTimeField] == nil){
                errorMessage += "'Start Time' field not found\n"
            }
            if (lineData[endTimeField] == nil){
                errorMessage += "'End Time' field not found\n"
            }
            if (lineData[typeField] == nil){
                errorMessage += "'Type' field not found\n"
            }
            break
        }
    }
    
    func verifyTypes (_ csvData: CSV){
        for lineData in csvData.rows {
            switch lineData[typeField]!{
                case showType:
                    incremetNumberOfShows();
                case meetAndGreetype:
                    incremetNumberOfmAndg()
                case clinicType:
                    incremetNumberOfClinics()
                case listeningPartyType:
                    incremeNumberOfListering()
                case specialEventType:
                    incremetNumberOfSpecialEvents()
                default:
                    errorMessage += "Unknown event type of '" + lineData[typeField]! + "' found\n"
            }
        }
    }
    
    func verifyBandNames(_ csvData: CSV){
        
        var bandDictionary = Dictionary<String, Int>()
        
        for bandName in bands {
            bandDictionary[bandName] = 1
        }
        
        var count = 1
        for lineData in csvData.rows {
            if (lineData["Type"] == "Show"){
                count = count + 1
                if (bandDictionary[lineData["Band"]!] == nil){
                    errorMessage += "Bands " + lineData[bandField]! + " does not match known band names. Line " + String(count) + "\n"
                }
            }
        }
    }
    
    func incremetNumberOfShows(){
        numberOfShows += 1
    }
    func incremetNumberOfClinics(){
        numberOfClinics += 1
    }
    func incremetNumberOfSpecialEvents(){
        numberOfSpecialEvents += 1
    }
    func incremetNumberOfmAndg(){
        numberOfmAndg += 1
    }
    func incremeNumberOfListering(){
        numberOfListering += 1
    }
}

//
//  ConvertScheduleToCurrentWeek.swift
//  70K Bands
//
//  Created by Ron Dorn on 2/16/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation

var newCsvString:String = "Band,Location,Date,Day,Start Time,End Time,Type,Notes\n"

class ConvertScheduleToCurrentWeek {
    
    /**
     Converts the schedule CSV file to use the current week's dates and writes the result to file.
     */
    func convertScheduleCSV (){
        
         if let csvDataString = String(contentsOfFile: scheduleFile, encoding: NSUTF8StringEncoding, error: nil) {
            
            var csvData: CSV
            
            var error: NSErrorPointer = nil
            csvData = CSV(csvStringToParse: csvDataString, error: error)!
            
            for lineData in csvData.rows {
                
                var newDate: NSDate = getDateForDayOfWeek(lineData[dayField]!)
            
                println (getHourFromString(lineData[startTimeField]!))
                println (getAmPmFromString(lineData[startTimeField]!))
                
                if (getAmPmFromString(lineData[startTimeField]!) == "AM"){
                    println("Yes, we are in AM")
                    if (getHourFromString(lineData[startTimeField]!).toInt() < 8 ||
                        getHourFromString(lineData[startTimeField]!).toInt() == 12){
                            newDate = addDay(newDate)
                            print ("Adding a day to the calendar for " + lineData[startTimeField]! + " ")
                    }
                }
                
                var dateFormatter = NSDateFormatter();
                dateFormatter.dateFormat = "M-d-yy"
                dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
                
                var newDateString = dateFormatter.stringFromDate(newDate)
                
                var fullTimeString: String = newDateString + " " + lineData[startTimeField]!
                
                var fullDateFormatter = NSDateFormatter()
                dateFormatter.dateFormat = "M-d-yy h:mm a"
                dateFormatter.timeZone = NSTimeZone.defaultTimeZone()
                dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
                
                //this fix is needed for daylight savings time when we spring folder and lose an hour
                var startTime = lineData[startTimeField]!
                var endTime = lineData[endTimeField]!
                if (dateFormatter.dateFromString(fullTimeString) == nil){
                    startTime = startTime.stringByReplacingOccurrencesOfString("2:", withString: "3:", options: NSStringCompareOptions.LiteralSearch, range: nil)
                    endTime = endTime.stringByReplacingOccurrencesOfString("3:", withString: "4:", options: NSStringCompareOptions.LiteralSearch, range: nil)
                    endTime = endTime.stringByReplacingOccurrencesOfString("2:", withString: "3:", options: NSStringCompareOptions.LiteralSearch, range: nil)
                }
                writeNewCsv(lineData, newDate: newDateString, startTime: startTime, endTime: endTime)
                
            }
            
            println (newCsvString)
            
            newCsvString.writeToFile(scheduleFile, atomically: false, encoding: NSUTF8StringEncoding)

        }
    }
    
    /**
     Extracts the hour component from a start time string.
     - Parameter startTime: The start time string (e.g., "8:00 AM").
     - Returns: The hour as a string.
     */
    func getHourFromString(startTime: String) -> String{
        
        var hourSpilt = startTime.componentsSeparatedByString(":")
        
        var hour = hourSpilt[0]
        
        return hour
    
    }
    
    /**
     Extracts the AM/PM component from a start time string.
     - Parameter startTime: The start time string (e.g., "8:00 AM").
     - Returns: The AM/PM string.
     */
    func getAmPmFromString(startTime: String) -> String{
        
        var amPmSplit = startTime.componentsSeparatedByString(" ")
        
        var amPm = amPmSplit[1]
        
        return amPm
    }
    
    /**
     Writes a new CSV line with the provided data and appends it to the output string.
     - Parameters:
        - csvLine: The dictionary representing a CSV row.
        - newDate: The new date string.
        - startTime: The start time string.
        - endTime: The end time string.
     */
    func writeNewCsv(csvLine: Dictionary<String, String>, newDate: String, startTime: String, endTime: String){
        
        newCsvString += csvLine[bandField]! + ","
        newCsvString += csvLine[locationField]! + ","
        newCsvString += newDate + ","
        newCsvString += csvLine[dayField]! + ","
        newCsvString += startTime + ","
        newCsvString += endTime + ","
        newCsvString += csvLine[typeField]! + ","
        newCsvString += csvLine[notesField]! + "\n"
    }
    
    /**
     Returns the NSDate for the given day of the week, advancing from today until the correct day is found.
     - Parameter dayOfWeek: The day of the week as a string (e.g., "Mon").
     - Returns: The NSDate corresponding to the next occurrence of the given day.
     */
    func getDateForDayOfWeek(dayOfWeek: String) -> NSDate{
        
        var dateForDay = NSDate()
        
        var weekDay = getDayOfWeek(dateForDay)
        
        while (weekDay == 1 || weekDay == 2 || weekDay == 5 || weekDay == 6 || weekDay == 7){
            dateForDay = addDay(dateForDay)
            weekDay = getDayOfWeek(dateForDay)
        }
        
        while (weekDay != getDayNumFromDayName(dayOfWeek)){
            
            print (dayOfWeek + "Does weekday ")
            print (weekDay)
            print (" = ")
            println(getDayNumFromDayName(dayOfWeek))
            
            dateForDay = addDay(dateForDay)
            weekDay = getDayOfWeek(dateForDay)
        }
        
        return dateForDay
        
    }
    
    /**
     Returns the weekday number for a given NSDate.
     - Parameter dateValue: The NSDate to check.
     - Returns: The weekday number (1 = Sunday, 2 = Monday, ...).
     */
    func getDayOfWeek(dateValue: NSDate) -> Int {
        
        let myCalendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian);
        let myComponents = myCalendar?.components(NSCalendarUnit.CalendarUnitWeekday, fromDate: dateValue)
        
        let weekDay = myComponents?.weekday
        
        return weekDay!
        
    }
    
    /**
     Returns the weekday number for a given day name string.
     - Parameter dayOfWeek: The day of the week as a string (e.g., "Mon").
     - Returns: The weekday number (1 = Sunday, 2 = Monday, ...).
     */
    func getDayNumFromDayName(dayOfWeek: String) -> Int{
        
        var dayNumber = Int()
        
        switch dayOfWeek{
            
            case "Sun":
                dayNumber = 1
            
            case "Mon":
                dayNumber = 2
            
            case "Tue":
                dayNumber = 3
            
            case "Wed":
                dayNumber = 4
            
            case "Thu":
                dayNumber = 5
            
            case "Fri":
                dayNumber = 6
            
            case "Sat":
                dayNumber = 7
            
            default:
                dayNumber = 1
            
        }
        
        return dayNumber
        
    }
    
    /**
     Adds one day to the given NSDate and returns the new date.
     - Parameter dateValue: The NSDate to increment.
     - Returns: The new NSDate one day later.
     */
    func addDay(dateValue: NSDate) -> NSDate {
        
        print ("Old Date " )
        println (dateValue)
        
        var currentTimePlusADay = NSCalendar.currentCalendar().dateByAddingUnit(
            .CalendarUnitHour,
            value: +24,
            toDate: dateValue,
            options: NSCalendarOptions(0))
        
        print ("New Date " )
        println (currentTimePlusADay)
        
        return currentTimePlusADay!
    }

}
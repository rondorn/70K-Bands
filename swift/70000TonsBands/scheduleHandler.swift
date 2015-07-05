//
//  scheduleHandler.swift
//  70K Bands
//
//  Created by Ron Dorn on 1/31/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//  70K Bands
//  Distributed under the GNU GPL v2. For full terms see the file docs/COPYING.
//

import Foundation

public class scheduleHandler {

    var schedulingData: [String : [NSTimeInterval : [String : String]]] = [String : [NSTimeInterval : [String : String]]]()
    
    //bands/time imdex/variable/value
    func populateSchedule(){
        
        if let csvDataString = String(contentsOfFile: scheduleFile, encoding: NSUTF8StringEncoding, error: nil) {
            
            var unuiqueIndex = Dictionary<NSTimeInterval, Int>()
            var csvData: CSV
            
            var error: NSErrorPointer = nil
            csvData = CSV(csvStringToParse: csvDataString, error: error)!
            
            for lineData in csvData.rows {
                //println ("Working on band " + lineData[bandField]!)
                if (lineData[dateField]?.isEmpty == false && lineData[startTimeField]?.isEmpty == false){
                    
                    var dateIndex = getDateIndex(lineData[dateField]!, timeString: lineData[startTimeField]!, band: lineData["Band"]!)
                    
                    //ensures all dateIndex's are unuique
                    while (unuiqueIndex[dateIndex] == 1){
                        dateIndex = dateIndex + 1;
                    }
                    
                    unuiqueIndex[dateIndex] = 1
                    
                    var dateFormatter = NSDateFormatter();
                    dateFormatter.dateFormat = "YYYY-M-d h:mm a"
                    
                    println("Adding index for band " + lineData[bandField]! + " ")
                    //println (dateFormatter.stringFromDate(dateIndex))
                    
                    if (self.schedulingData[lineData[bandField]!] == nil){
                        self.schedulingData[lineData[bandField]!] = [NSTimeInterval : [String : String]]()
                    }
                    if (self.schedulingData[lineData[bandField]!]![dateIndex] == nil){
                        self.schedulingData[lineData[bandField]!]![dateIndex] = [String : String]()
                    }
                    
                    setData(lineData[bandField]!, index:dateIndex, variable:locationField, value: lineData[locationField]!)
                    setData(lineData[bandField]!, index:dateIndex, variable:dayField, value: lineData[dayField]!)
                    setData(lineData[bandField]!, index:dateIndex, variable:startTimeField, value: lineData[startTimeField]!)
                    setData(lineData[bandField]!, index:dateIndex, variable:endTimeField, value: lineData[endTimeField]!)
                    setData(lineData[bandField]!, index:dateIndex, variable:dateField, value: lineData[dateField]!)
                    setData(lineData[bandField]!, index:dateIndex, variable:typeField, value: lineData[typeField]!)
                    setData(lineData[bandField]!, index:dateIndex, variable:notesField, value: lineData[notesField]!)
                    
                }
            }
        }
    }
    
    
    func DownloadCsv (){
        
        if (defaults.stringForKey("scheduleUrl") != lastYearsScheduleUrlDefault || byPassCsvDownloadCheck == true){
            
            var scheduleUrl = defaults.stringForKey("scheduleUrl")
            
            if (scheduleUrl == "Default"){
               scheduleUrl = getDefaultScheduleUrl()
            }
            
            println("scheduleUrl = " + scheduleUrl!)
            var error:NSError?
            var ok:Bool = NSFileManager.defaultManager().removeItemAtPath(scheduleFile, error: &error)
            
            var httpData = getUrlData(scheduleUrl!)
            
            println("This will be making HTTP Calls for schedule")
            
            if (httpData.isEmpty == false){
                httpData.writeToFile(scheduleFile, atomically: false, encoding: NSUTF8StringEncoding)
            }
        }
    }
    
    func getDefaultScheduleUrl() -> String{
        
        var url = String()
        var httpData = getUrlData(defaultStorageUrl)
        
        var dataArray = httpData.componentsSeparatedByString("\n")
        for record in dataArray {
            var valueArray = record.componentsSeparatedByString("::")
            if (valueArray[0] == "scheduleUrl"){
                url = valueArray[1]
            }
        }
        
        println ("Using default Schedule URL of " + url)
        return url
    }
    
    func getDateIndex (dateString: String, timeString: String, band:String) -> NSTimeInterval{
        
        var startTimeIndex = NSTimeInterval()
        var fullTimeString: String = dateString + " " + timeString;
        
        var dateFormatter = NSDateFormatter();
        dateFormatter.dateFormat = "M-d-yy h:mm a"
        dateFormatter.timeZone = NSTimeZone.defaultTimeZone()

        if (fullTimeString.isEmpty == false){
            println ("'" + fullTimeString + "'");
            println(dateFormatter.dateFromString(fullTimeString))
            if (dateFormatter.dateFromString(fullTimeString) != nil){
                startTimeIndex = dateFormatter.dateFromString(fullTimeString)!.timeIntervalSince1970
                println(startTimeIndex)
            }
        }
                
        return startTimeIndex
    }
    
    func getCurrentIndex (bandName: String) -> NSTimeInterval {
        
        var dateIndex = NSTimeIntervalSince1970
        
        if (self.schedulingData[bandName]?.isEmpty == false){
        
            var keyValues = self.schedulingData[bandName]!.keys
            var arrayValues = keyValues.array
            var sortedArray = sorted(arrayValues, {$0 < $1})
            
            if (self.schedulingData[bandName] != nil){
                for dateIndexTemp in sortedArray {
                    
                    dateIndex = dateIndexTemp.0;
                    
                    if (self.schedulingData[bandName]![dateIndex]![typeField]! == showType){
                        var currentTime =  NSDate().timeIntervalSince1970
                        var currentTimePlusAnHour = currentTime - 3600

                        if dateIndex > currentTimePlusAnHour {
                            return dateIndex
                        }
                    }
                }
            }
        }
        
        return dateIndex
    }
    
    func setData (bandName:String, index:NSTimeInterval, variable:String, value:String){
        if (!variable.isEmpty){
            self.schedulingData[bandName]![index]![variable] = value
        }
    }
    
    func getData(bandName:String, index:NSTimeInterval, variable:String) -> String{
        
        if (self.schedulingData[bandName] != nil && variable.isEmpty == false){
            if (self.schedulingData[bandName]![index]?.isEmpty == false){
                if (self.schedulingData[bandName]![index]![variable]?.isEmpty == false){
                    return self.schedulingData[bandName]![index]![variable]!
                }
            }
        }
        
        return String()
    }
    
    func convertStringToNSDate(dateStr: String) -> NSDate {
        
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat =  "yyyy'-'MM'-'dd HH':'mm':'ss '+0000'"
        let date = dateFormatter.dateFromString(dateStr)
        
        return date!
    }
}



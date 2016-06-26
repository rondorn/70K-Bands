//
//  scheduleHandler.swift
//  70K Bands
//
//  Created by Ron Dorn on 1/31/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation

public class scheduleHandler {
    
    var schedulingData: [String : [NSTimeInterval : [String : String]]] = [String : [NSTimeInterval : [String : String]]]()
    var schedulingDataByTime: [NSTimeInterval : [String : String]] = [NSTimeInterval : [String : String]]()
    
    func populateSchedule(){
        
        if let csvDataString = try? String(contentsOfFile: scheduleFile, encoding: NSUTF8StringEncoding) {
            
            var unuiqueIndex = Dictionary<NSTimeInterval, Int>()
            var csvData: CSV
            
            csvData = try! CSV(csvStringToParse: csvDataString)
            
            for lineData in csvData.rows {
                if (lineData[dateField]?.isEmpty == false && lineData[startTimeField]?.isEmpty == false){
                    
                    var dateIndex = getDateIndex(lineData[dateField]!, timeString: lineData[startTimeField]!, band: lineData["Band"]!)
                    
                    //ensures all dateIndex's are unuique
                    while (unuiqueIndex[dateIndex] == 1){
                        dateIndex = dateIndex + 1;
                    }
                    
                    unuiqueIndex[dateIndex] = 1
                    
                    let dateFormatter = NSDateFormatter();
                    dateFormatter.dateFormat = "YYYY-M-d h:mm a"
                    dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
                    
                    print("Adding index for band " + lineData[bandField]! + " ")
                    print (dateIndex)
                    
                    if (self.schedulingData[lineData[bandField]!] == nil){
                        self.schedulingData[lineData[bandField]!] = [NSTimeInterval : [String : String]]()
                    }
                    
                    if (self.schedulingData[lineData[bandField]!]![dateIndex] == nil){
                        self.schedulingData[lineData[bandField]!]![dateIndex] = [String : String]()
                    }
                    print ("Adding location of " + lineData[locationField]!)
                    
                    //doing this double for unknown reason, it wont work if the first entry is single
                    setData(lineData[bandField]!, index:dateIndex, variable:dayField, value: lineData[dayField]!)
                    setData(lineData[bandField]!, index:dateIndex, variable:dayField, value: lineData[dayField]!)
                    
                    setData(lineData[bandField]!, index:dateIndex, variable:startTimeField, value: lineData[startTimeField]!)
                    setData(lineData[bandField]!, index:dateIndex, variable:endTimeField, value: lineData[endTimeField]!)
                    setData(lineData[bandField]!, index:dateIndex, variable:dateField, value: lineData[dateField]!)
                    setData(lineData[bandField]!, index:dateIndex, variable:typeField, value: lineData[typeField]!)
                    setData(lineData[bandField]!, index:dateIndex, variable:notesField, value: lineData[notesField]!)
                    setData(lineData[bandField]!, index:dateIndex, variable:locationField, value: lineData[locationField]!)
                    
                } else {
                    print ("Unable to parse schedule file")
                }
            }
        } else {
            print ("Encountered an error could not open schedule file ")
        }
    }
    
    
    func DownloadCsv (){
        
        var scheduleUrl = "";
        
        print ("working with scheduleFile " + scheduleFile)
        if (defaults.stringForKey("scheduleUrl") == lastYearsScheduleUrlDefault){
            scheduleUrl = lastYearsScheduleUrlDefault;
        } else {
            scheduleUrl = defaults.stringForKey("scheduleUrl")!
        }
        
        print ("Downloading Schedule URL " + scheduleUrl);
        if (scheduleUrl == "Default"){
            scheduleUrl = getDefaultScheduleUrl()
        }
        
        print("scheduleUrl = " + scheduleUrl)
        
        let httpData = getUrlData(scheduleUrl)
        
        print("This will be making HTTP Calls for schedule " + httpData);
        
        if (httpData.isEmpty == false){
            do {
                try NSFileManager.defaultManager().removeItemAtPath(scheduleFile)
                
            } catch let error as NSError {
                print ("Encountered an error removing old schedule file " + error.debugDescription)
            }
            do {
                try httpData.writeToFile(scheduleFile, atomically: false, encoding: NSUTF8StringEncoding)
            } catch let error as NSError {
                print ("Encountered an error writing schedule file " + error.debugDescription)
            }
            
        }
    }
    
    func getDefaultScheduleUrl() -> String{
        
        var url = String()
        let httpData = getUrlData(defaultStorageUrl)
        
        let dataArray = httpData.componentsSeparatedByString("\n")
        for record in dataArray {
            var valueArray = record.componentsSeparatedByString("::")
            if (valueArray[0] == "scheduleUrl"){
                url = valueArray[1]
            }
        }
        
        print ("Using default Schedule URL of " + url)
        return url
    }
    
    func getDateIndex (dateString: String, timeString: String, band:String) -> NSTimeInterval{
        
        var startTimeIndex = NSTimeInterval()
        let fullTimeString: String = dateString + " " + timeString;
        
        let dateFormatter = NSDateFormatter();
        dateFormatter.dateFormat = "M-d-yy h:mm a"
        dateFormatter.timeZone = NSTimeZone.defaultTimeZone()
        dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        
        if (fullTimeString.isEmpty == false){
            print ("timeString '" + fullTimeString + "'");
            print(dateFormatter.dateFromString(fullTimeString))
            if (dateFormatter.dateFromString(fullTimeString) != nil){
                startTimeIndex = dateFormatter.dateFromString(fullTimeString)!.timeIntervalSince1970
                print(startTimeIndex)
            } else {
                print ("What the hell!!")
                print(dateFormatter.dateFromString(fullTimeString))
            }
        }
                
        return startTimeIndex
    }
    
    func getCurrentIndex (bandName: String) -> NSTimeInterval {
        
        let dateIndex = NSTimeIntervalSince1970
        
        if (self.schedulingData[bandName]?.isEmpty == false){
        
            let keyValues = self.schedulingData[bandName]!.keys
            let sortedArray = keyValues.reverse()
            
            if (self.schedulingData[bandName] != nil){
                for dateIndexTemp in sortedArray {
                    if (self.schedulingData[bandName]![dateIndexTemp]![typeField]! == showType){
                        let currentTime =  NSDate().timeIntervalSince1970
                        let currentTimePlusAnHour = currentTime - 3600
                        
                        print ("time comparison of scheduledate " + dateIndexTemp.description + " vs " + currentTimePlusAnHour.description)
                        if dateIndexTemp > currentTimePlusAnHour {
                            print("Returning dateIndex of " + dateIndexTemp.description )
                            return dateIndexTemp
                        }
                    }
                }
            }
        }
        return dateIndex
    }
    
    func setData (bandName:String, index:NSTimeInterval, variable:String, value:String){
        
        if (variable.isEmpty == false && value.isEmpty == false){
            if (bandName.isEmpty == false && index.isZero == false && self.schedulingData[bandName] != nil){
                if (self.schedulingData[bandName]?.isEmpty == false){
                    if (self.schedulingData[bandName]![index]!.isEmpty == false){
                        print ("value for variable is " + value)
                        self.schedulingData[bandName]![index]![variable] = value
                    }
                }
            }
        }
        if (self.schedulingData[bandName]![index]![variable] == nil){
            self.schedulingData[bandName]![index]![variable] = "";
        }
    }
    
    func getData(bandName:String, index:NSTimeInterval, variable:String) -> String{
        
        print ("schedule value lookup. Getting variable " + variable + " for " + bandName + " - " + index.description);
        print (self.schedulingData[bandName])
        if (self.schedulingData[bandName] != nil && variable.isEmpty == false){
            print ("schedule value lookup. loop 1")
            if (self.schedulingData[bandName]![index]?.isEmpty == false){
                print ("schedule value lookup. loop 2")
                if (self.schedulingData[bandName]![index]![variable]?.isEmpty == false){
                    print ("schedule value lookup. loop 3")
                    print ("schedule value lookup. Returning " + self.schedulingData[bandName]![index]![variable]!)
                    return self.schedulingData[bandName]![index]![variable]!
                }
            }
        }
        print ("schedule value lookup. Returning nothing")
        return String()
    }

    func buildTimeSortedSchedulingData () {
        
        for bandName in schedulingData.keys {
            for timeIndex in (schedulingData[bandName]!.keys){
                print ("timeSortadding timeIndex:" + String(timeIndex) + " bandName:" + bandName);
                self.schedulingDataByTime[timeIndex] = [bandName:bandName]
                
            }
        }
        
        print ("schedulingDataByTime is")
        print (schedulingDataByTime);
        
    }
    
    func getTimeSortedSchedulingData () -> [NSTimeInterval : [String : String]] {
        return schedulingDataByTime
    }
    
    func getBandSortedSchedulingData () -> [String : [NSTimeInterval : [String : String]]] {
    
        return schedulingData;
    
    }
    
    func convertStringToNSDate(dateStr: String) -> NSDate {
        
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat =  "yyyy'-'MM'-'dd HH':'mm':'ss '+0000'"
        dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        
        let date = dateFormatter.dateFromString(dateStr)
        
        return date!
    }
}



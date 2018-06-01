//
//  scheduleHandler.swift
//  70K Bands
//
//  Created by Ron Dorn on 1/31/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation

open class scheduleHandler {
    
    var schedulingData: [String : [TimeInterval : [String : String]]] = [String : [TimeInterval : [String : String]]]()
    var schedulingDataByTime: [TimeInterval : [String : String]] = [TimeInterval : [String : String]]()
    
    func populateSchedule(){
        
        if (FileManager.default.fileExists(atPath: scheduleFile) == false){
            DownloadCsv();
        }
        
        if let csvDataString = try? String(contentsOfFile: scheduleFile, encoding: String.Encoding.utf8) {
            
            var unuiqueIndex = Dictionary<TimeInterval, Int>()
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
                    
                    let dateFormatter = DateFormatter();
                    dateFormatter.dateFormat = "YYYY-M-d HH:mm"
                    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                    
                    print("Adding index for band " + lineData[bandField]! + " ")
                    print (dateIndex)
                    
                    if (self.schedulingData[lineData[bandField]!] == nil){
                        self.schedulingData[lineData[bandField]!] = [TimeInterval : [String : String]]()
                    }
                    
                    if (self.schedulingData[lineData[bandField]!]![dateIndex] == nil){
                        self.schedulingData[lineData[bandField]!]![dateIndex] = [String : String]()
                    }
                    print ("Adding location of " + lineData[locationField]!)
                    
                    //doing this double for unknown reason, it wont work if the first entry is single
                    setData(bandName: lineData[bandField]!, index:dateIndex, variable:dayField, value: lineData[dayField]!)
                    setData(bandName: lineData[bandField]!, index:dateIndex, variable:dayField, value: lineData[dayField]!)
                    
                    setData(bandName: lineData[bandField]!, index:dateIndex, variable:startTimeField, value: lineData[startTimeField]!)
                    setData(bandName: lineData[bandField]!, index:dateIndex, variable:endTimeField, value: lineData[endTimeField]!)
                    setData(bandName: lineData[bandField]!, index:dateIndex, variable:dateField, value: lineData[dateField]!)
                    setData(bandName: lineData[bandField]!, index:dateIndex, variable:typeField, value: lineData[typeField]!)
                    setData(bandName: lineData[bandField]!, index:dateIndex, variable:notesField, value: lineData[notesField]!)
                    setData(bandName: lineData[bandField]!, index:dateIndex, variable:locationField, value: lineData[locationField]!)
                    
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
        if (defaults.string(forKey: "scheduleUrl") == lastYearsScheduleUrlDefault){
            scheduleUrl = lastYearsScheduleUrlDefault;
        } else {
            scheduleUrl = defaults.string(forKey: "scheduleUrl")!
        }
        
        print ("Downloading Schedule URL " + scheduleUrl);
        if (scheduleUrl == "Default"){
            scheduleUrl = getPointerUrlData(keyValue: scheduleUrlpointer)
            
        } else if (scheduleUrl == "lastYear"){
            scheduleUrl = getPointerUrlData(keyValue: lastYearscheduleUrlpointer)
        
        }
        
        print("scheduleUrl = " + scheduleUrl)
        
        let httpData = getUrlData(scheduleUrl)
        
        print("This will be making HTTP Calls for schedule " + httpData);
        
        if (httpData.isEmpty == false){
            do {
                try FileManager.default.removeItem(atPath: scheduleFile)
            
            } catch let error as NSError {
                print ("Encountered an error removing old schedule file " + error.debugDescription)
            }
            do {
                try httpData.write(toFile: scheduleFile, atomically: false, encoding: String.Encoding.utf8)
            } catch let error as NSError {
                print ("Encountered an error writing schedule file " + error.debugDescription)
            }
            
        }
    }

    func getDateIndex (_ dateString: String, timeString: String, band:String) -> TimeInterval{
        
        var startTimeIndex = TimeInterval()
        let fullTimeString: String = dateString + " " + timeString;
        
        let dateFormatter = DateFormatter();
        dateFormatter.dateFormat = "M-d-yy HH:mm"
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        if (fullTimeString.isEmpty == false){
            //print ("timeString '" + fullTimeString + "'");
            //print(dateFormatter.date(from: fullTimeString))
            if (dateFormatter.date(from: fullTimeString) != nil){
                startTimeIndex = dateFormatter.date(from: fullTimeString)!.timeIntervalSince1970
                print(startTimeIndex)
            } else {
                print ("What the hell!!")
                print(dateFormatter.date(from: fullTimeString))
            }
        }
                
        return startTimeIndex
    }
    
    func getCurrentIndex (_ bandName: String) -> TimeInterval {
        
        let dateIndex = NSTimeIntervalSince1970
        
        if (self.schedulingData[bandName]?.isEmpty == false){
        
            let keyValues = self.schedulingData[bandName]!.keys
            let sortedArray = keyValues.reversed()
            
            if (self.schedulingData[bandName] != nil){
                for dateIndexTemp in sortedArray {
                    if (self.schedulingData[bandName]![dateIndexTemp]![typeField]! == showType){
                        let currentTime =  Date().timeIntervalSince1970
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
    
    func setData (bandName:String, index:TimeInterval, variable:String, value:String){
        
        if (variable.isEmpty == false && value.isEmpty == false){
            if (bandName.isEmpty == false && index.isZero == false && self.schedulingData[bandName] != nil){
                if (self.schedulingData[bandName]?.isEmpty == false){
                    //if (self.schedulingData[bandName]![index]?.isEmpty == false){
                        if (value.isEmpty == false){
                            print ("value for variable is " + value)
                            self.schedulingData[bandName]![index]![variable] = value
                        }
                    //}
                }
            }
        }
        
    }
    
    func getData(_ bandName:String, index:TimeInterval, variable:String) -> String{
        
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
    
    func getTimeSortedSchedulingData () -> [TimeInterval : [String : String]] {
        return schedulingDataByTime
    }
    
    func getBandSortedSchedulingData () -> [String : [TimeInterval : [String : String]]] {
    
        return schedulingData;
    
    }
    
    func convertStringToNSDate(_ dateStr: String) -> Date {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat =  "yyyy'-'MM'-'dd HH':'mm':'ss '+0000'"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let date = dateFormatter.date(from: dateStr)
        
        return date!
    }
}



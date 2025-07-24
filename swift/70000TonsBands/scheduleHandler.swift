//
//  scheduleHandler.swift
//  70K Bands
//
//  Created by Ron Dorn on 1/31/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation

open class scheduleHandler {
    
    // Thread-safe queue for all scheduling data access
    private let scheduleHandlerQueue = DispatchQueue(label: "com.yourapp.scheduleHandlerQueue", attributes: .concurrent)
    
    // Private backing stores
    private var _schedulingData: [String : [TimeInterval : [String : String]]] = [:]
    private var _schedulingDataByTime: [TimeInterval : [String : String]] = [:]
    
    // Thread-safe accessors
    var schedulingData: [String : [TimeInterval : [String : String]]] {
        get {
            return scheduleHandlerQueue.sync { _schedulingData }
        }
        set {
            scheduleHandlerQueue.async(flags: .barrier) { self._schedulingData = newValue }
        }
    }
    var schedulingDataByTime: [TimeInterval : [String : String]] {
        get {
            return scheduleHandlerQueue.sync { _schedulingDataByTime }
        }
        set {
            scheduleHandlerQueue.async(flags: .barrier) { self._schedulingDataByTime = newValue }
        }
    }
    
    // Helper for thread-safe mutation
    private func mutateSchedulingData(_ block: @escaping (inout [String : [TimeInterval : [String : String]]]) -> Void) {
        scheduleHandlerQueue.async(flags: .barrier) {
            block(&self._schedulingData)
        }
    }
    private func mutateSchedulingDataByTime(_ block: @escaping (inout [TimeInterval : [String : String]]) -> Void) {
        scheduleHandlerQueue.async(flags: .barrier) {
            block(&self._schedulingDataByTime)
        }
    }

    init() {
        print ("Loading schedule Data")
        getCachedData()
    }
    
    func getCachedData(){
        
        var staticCacheUsed = false
        
        staticSchedule.sync {
            if (cacheVariables.scheduleStaticCache.isEmpty == false && cacheVariables.scheduleTimeStaticCache.isEmpty == false ){
                staticCacheUsed = true
                // Make a deep copy to avoid mutating shared cache
                self.schedulingData = cacheVariables.scheduleStaticCache.mapValues { $0.mapValues { $0 } }
                self.schedulingDataByTime = cacheVariables.scheduleTimeStaticCache.mapValues { $0 }
            }
        }
        
        if (staticCacheUsed == false){
            if ((FileManager.default.fileExists(atPath: schedulingDataCacheFile.path)) == true){
                self.schedulingData = NSKeyedUnarchiver.unarchiveObject(withFile: schedulingDataCacheFile.path)
                    as! [String : [TimeInterval : [String : String]]]
            } else {
                
                DispatchQueue.main.async {
                    print ("Cache did not load, loading schedule data")
                    self.populateSchedule()
                }
            }
            
            if ((FileManager.default.fileExists(atPath: schedulingDataByTimeCacheFile.path)) == true){
                self.schedulingDataByTime = NSKeyedUnarchiver.unarchiveObject(withFile: schedulingDataByTimeCacheFile.path) as! [TimeInterval : [String : String]]
            } else {
                DispatchQueue.main.async {
                    print ("Cache did not load, loading schedule data")
                    self.populateSchedule()
                }
            }
            
            if self.schedulingData.isEmpty && !cacheVariables.justLaunched {
                print("Skipping schedule cache population: schedulingData is empty and app is not just launched.")
                return
            }
            staticSchedule.sync {
                cacheVariables.scheduleStaticCache = self.schedulingData
                cacheVariables.scheduleTimeStaticCache = self.schedulingDataByTime
            }
            
        }
    }
    
    func clearCache(){
        self.schedulingData = [:]
    }
    
    func populateSchedule(){
        
        print ("Loading schedule data 1")
        isLoadingSchedule = true;
        
        self.schedulingData = [:]
        self.schedulingDataByTime = [:]
    
        
        if (FileManager.default.fileExists(atPath: scheduleFile) == false){
            //print ("Sync: Loading schedule data 1")
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
                    scheduleReleased = true
                    if (schedulingData[lineData[bandField]!] == nil){
                        self.schedulingData[lineData[bandField]!] = [TimeInterval : [String : String]]()
        
                    }
                    if (schedulingData[lineData[bandField]!]?[dateIndex] == nil){
                        self.schedulingData[lineData[bandField]!]?[dateIndex] = [String : String]()
                        
                    }

                    print ("Adding location of " + lineData[locationField]!)
                    
                    //doing this double for unknown reason, it wont work if the first entry is single
                    print ("adding dayField");
                    setData(bandName: lineData[bandField]!, index:dateIndex, variable:dayField, value: lineData[dayField]!)
                    setData(bandName: lineData[bandField]!, index:dateIndex, variable:dayField, value: lineData[dayField]!)
                    
                    print ("adding startTimeField");
                    setData(bandName: lineData[bandField]!, index:dateIndex, variable:startTimeField, value: lineData[startTimeField]!)
                    setData(bandName: lineData[bandField]!, index:dateIndex, variable:endTimeField, value: lineData[endTimeField]!)
                    
                    print ("adding dateField");
                    setData(bandName: lineData[bandField]!, index:dateIndex, variable:dateField, value: lineData[dateField]!)
                    
                    print ("adding typeField");
                    var eventType = lineData[typeField]!;
                    if (eventType == unofficalEventTypeOld){
                        eventType = unofficalEventType;
                    }
                    setData(bandName: lineData[bandField]!, index:dateIndex, variable:typeField, value: eventType)
                    
                    print ("adding notesField");
                    if let noteValue = lineData[notesField] {
                        setData(bandName: lineData[bandField]!, index:dateIndex, variable:notesField, value: noteValue)
                    }
                    
                    print ("adding locationField");
                    setData(bandName: lineData[bandField]!, index:dateIndex, variable:locationField, value: lineData[locationField]!)
                    
                    print ("adding descriptionUrlField \(lineData)")
                    
                    if let descriptUrl = lineData[descriptionUrlField] {
                        if (descriptUrl.isEmpty == false && descriptUrl.count >= 2){
                            
                            bandDescriptionLock.sync {
                                cacheVariables.bandDescriptionUrlCache[lineData[bandField]!] = descriptUrl
                            }
                        }
                    } else {
                        print ("field descriptionUrlField not present for " + lineData[bandField]!);
                    }
                    
                    if let imageUrl = lineData[imageUrlField] {
                        if (imageUrl.isEmpty == false && imageUrl.count >= 2){
                            //save inmage in background
                            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                                
                                let imageHandle = imageHandler()
                                _ = imageHandle.displayImage(urlString: imageUrl, bandName: lineData[bandField]!)
                            }
                        }
                        
                    }
                } else {
                    print ("Unable to parse schedule file")
                }
            }
        } else {
            print ("Encountered an error could not open schedule file ")
        }
        
        //saveCacheFile
        NSKeyedArchiver.archiveRootObject(schedulingData, toFile: schedulingDataCacheFile.path)
        NSKeyedArchiver.archiveRootObject(schedulingDataByTime, toFile: schedulingDataByTimeCacheFile.path)

    }
    
    
    func DownloadCsv (){
        
        var scheduleUrl = "";
        
        //print ("Sync: working with scheduleFile " + scheduleFile)
        
        if (scheduleUrl.isEmpty == true){
            scheduleUrl = defaultPrefsValue
        }
    
        print ("Downloading Schedule URL " + scheduleUrl);
        scheduleUrl = getPointerUrlData(keyValue: "scheduleUrl")

        print("scheduleUrl = " + scheduleUrl)
        
        let httpData = getUrlData(urlString: scheduleUrl)
        
        print("This will be making HTTP Calls for schedule " + httpData);
        
        let oldScheduleFile = scheduleFile + ".old"
        var didRenameOld = false
        // Rename existing file to .old
        if FileManager.default.fileExists(atPath: scheduleFile) {
            do {
                if FileManager.default.fileExists(atPath: oldScheduleFile) {
                    try FileManager.default.removeItem(atPath: oldScheduleFile)
                }
                try FileManager.default.moveItem(atPath: scheduleFile, toPath: oldScheduleFile)
                didRenameOld = true
            } catch let error as NSError {
                print ("Encountered an error renaming old schedule file " + error.debugDescription)
                isLoadingBandData = false
            }
        }
        
        if (httpData.isEmpty == false){
            do {
                try httpData.write(toFile: scheduleFile, atomically: false, encoding: String.Encoding.utf8)
                // If write succeeds, remove the .old file
                if didRenameOld && FileManager.default.fileExists(atPath: oldScheduleFile) {
                    try? FileManager.default.removeItem(atPath: oldScheduleFile)
                }
            } catch let error as NSError {
                print ("Encountered an error writing schedule file " + error.debugDescription)
                isLoadingBandData = false
                // Restore the old file if write fails
                if didRenameOld && FileManager.default.fileExists(atPath: oldScheduleFile) {
                    do {
                        if FileManager.default.fileExists(atPath: scheduleFile) {
                            try FileManager.default.removeItem(atPath: scheduleFile)
                        }
                        try FileManager.default.moveItem(atPath: oldScheduleFile, toPath: scheduleFile)
                        print("Restored old schedule file after failed download.")
                    } catch let restoreError as NSError {
                        print("Failed to restore old schedule file: " + restoreError.debugDescription)
                    }
                }
            }
        } else {
            print ("No data downloaded for schedule file.")
            // Restore the old file if no data was downloaded
            if didRenameOld && FileManager.default.fileExists(atPath: oldScheduleFile) {
                do {
                    if FileManager.default.fileExists(atPath: scheduleFile) {
                        try FileManager.default.removeItem(atPath: scheduleFile)
                    }
                    try FileManager.default.moveItem(atPath: oldScheduleFile, toPath: scheduleFile)
                    print("Restored old schedule file after empty download.")
                } catch let restoreError as NSError {
                    print("Failed to restore old schedule file: " + restoreError.debugDescription)
                }
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
            print(dateFormatter.date(from: fullTimeString) as Any)
            if (dateFormatter.date(from: fullTimeString) != nil){
                startTimeIndex = dateFormatter.date(from: fullTimeString)!.timeIntervalSince1970
                print(startTimeIndex)
                
                print ("timeString \(band) '" + fullTimeString + "' \(startTimeIndex)");
            } else {
                print ("What the hell!!")
                print(dateFormatter.date(from: fullTimeString) as Any)
            }
        }
                
        return startTimeIndex
    }
    
    func getCurrentIndex (_ bandName: String) -> TimeInterval {
        
        let dateIndex = NSTimeIntervalSince1970
        
        if (schedulingData[bandName]?.isEmpty == false){
        
            let keyValues = schedulingData[bandName]!.keys
            let sortedArray = keyValues.reversed()
            
            if (schedulingData[bandName] != nil){
                for dateIndexTemp in sortedArray {
                    if (schedulingData[bandName]![dateIndexTemp]![typeField]! == showType){
                        let currentTime =  Date().timeIntervalSince1970
                        let currentTimePlusAnHour = currentTime - 3600
                        
                        print ("time comparison of scheduledate " + dateIndexTemp.description + " vs " + currentTimePlusAnHour.description)
                        //if dateIndexTemp > currentTimePlusAnHour{
                            print("Returning dateIndex of " + dateIndexTemp.description )
                            return dateIndexTemp
                        //}
                    }
                }
            }
        }
        return dateIndex
    }
    
    func setData (bandName:String, index:TimeInterval, variable:String, value:String){
        guard !variable.isEmpty, !value.isEmpty, !bandName.isEmpty, !index.isZero else { return }
        mutateSchedulingData { schedulingData in
            if self.isSchedulingDataPresent(schedulingData: schedulingData, bandName: bandName) {
                schedulingData[bandName]?[index]?[variable] = value
            }
        }
    }
    
    func isSchedulingDataPresent(schedulingData: [String : [TimeInterval : [String : String]]], bandName: String)->Bool{
        var results = true
        if (schedulingData.isEmpty == true){
            results = false
        } else if (schedulingData[bandName]?.isEmpty == true){
            results = false
        }
        
        
        return results
    }
    
    func getData(_ bandName: String, index: TimeInterval, variable: String) -> String {
        guard !variable.isEmpty else { return "" }
        return scheduleHandlerQueue.sync {
            guard let bandDict = self._schedulingData[bandName] else {
                print("getData: No entry for bandName \(bandName)")
                return ""
            }
            guard let timeDict = bandDict[index] else {
                print("getData: No entry for index \(index) in band \(bandName)")
                return ""
            }
            guard let value = timeDict[variable], !value.isEmpty else {
                print("getData: No value for variable \(variable) in band \(bandName) at index \(index)")
                return ""
            }
            return value
        }
    }

    func buildTimeSortedSchedulingData () {
        scheduleHandlerQueue.async(flags: .barrier) {
            for bandName in self._schedulingData.keys {
                if let bandSchedule = self._schedulingData[bandName], !bandSchedule.isEmpty {
                    for timeIndex in bandSchedule.keys {
                        print ("timeSortadding timeIndex:" + String(timeIndex) + " bandName:" + bandName);
                        self._schedulingDataByTime[timeIndex] = [bandName:bandName]
                    }
                }
            }
            print ("schedulingDataByTime is")
        }
    }
    
    func getTimeSortedSchedulingData () -> [TimeInterval : [String : String]] {
        return scheduleHandlerQueue.sync { self._schedulingDataByTime }
    }
    
    func getBandSortedSchedulingData () -> [String : [TimeInterval : [String : String]]] {
        
        return scheduleHandlerQueue.sync { self._schedulingData }
    
    }
    
    func convertStringToNSDate(_ dateStr: String) -> Date {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat =  "yyyy'-'MM'-'dd HH':'mm':'ss '+0000'"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let date = dateFormatter.date(from: dateStr)
        
        return date!
    }
}



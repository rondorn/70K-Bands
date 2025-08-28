//
//  scheduleHandler.swift
//  70K Bands
//
//  Created by Ron Dorn on 1/31/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation

open class scheduleHandler {
    
    // Singleton instance
    static let shared = scheduleHandler()
    
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

    private init() {
        print ("🔄 scheduleHandler singleton initialized - Loading schedule Data")
        getCachedData()
    }
    
    func getCachedData(){
        
        var staticCacheUsed = false
        
        staticSchedule.sync {
            if (cacheVariables.scheduleStaticCache.isEmpty == false && cacheVariables.scheduleTimeStaticCache.isEmpty == false ){
                staticCacheUsed = true
                print("[YEAR_CHANGE_DEBUG] getCachedData: Using static cache with \(cacheVariables.scheduleStaticCache.count) bands")
                // Make a deep copy to avoid mutating shared cache
                self.schedulingData = cacheVariables.scheduleStaticCache.mapValues { $0.mapValues { $0 } }
                self.schedulingDataByTime = cacheVariables.scheduleTimeStaticCache.mapValues { $0 }
            } else {
                print("[YEAR_CHANGE_DEBUG] getCachedData: Static cache is empty, will load from file")
            }
        }
        
        if (staticCacheUsed == false){
            if ((FileManager.default.fileExists(atPath: schedulingDataCacheFile.path)) == true){
                self.schedulingData = NSKeyedUnarchiver.unarchiveObject(withFile: schedulingDataCacheFile.path)
                    as! [String : [TimeInterval : [String : String]]]
            } else {
                
                DispatchQueue.main.async {
                    print ("Cache did not load, loading schedule data")
                    self.populateSchedule(forceDownload: false)
                }
            }
            
            if ((FileManager.default.fileExists(atPath: schedulingDataByTimeCacheFile.path)) == true){
                self.schedulingDataByTime = NSKeyedUnarchiver.unarchiveObject(withFile: schedulingDataByTimeCacheFile.path) as! [TimeInterval : [String : String]]
            } else {
                DispatchQueue.main.async {
                    print ("Cache did not load, loading schedule data")
                    self.populateSchedule(forceDownload: false)
                }
            }
            
            // Only skip cache population if we don't have a valid schedule file at all
            // If scheduleReleased is true, it means we have a valid file (even if just headers)
            if self.schedulingData.isEmpty && !cacheVariables.justLaunched && !scheduleReleased {
                print("Skipping schedule cache population: schedulingData is empty, app is not just launched, and no valid schedule file.")
                return
            }
            staticSchedule.sync {
                cacheVariables.scheduleStaticCache = self.schedulingData
                cacheVariables.scheduleTimeStaticCache = self.schedulingDataByTime
            }
            
        }
    }
    
    func clearCache(){
        print("[YEAR_CHANGE_DEBUG] Clearing schedule cache for year \(eventYear)")
        self.schedulingData = [:]
        self.schedulingDataByTime = [:]
        
        // Also clear the static cache
        staticSchedule.sync {
            cacheVariables.scheduleStaticCache = [:]
            cacheVariables.scheduleTimeStaticCache = [:]
        }
    }
    
    func populateSchedule(forceDownload: Bool = false){
        
        // Prevent concurrent schedule loading
        if isLoadingSchedule {
            print("[YEAR_CHANGE_DEBUG] Schedule loading already in progress, skipping duplicate request")
            return
        }
        
        print ("[YEAR_CHANGE_DEBUG] Loading schedule data for year \(eventYear), forceDownload: \(forceDownload)")
        isLoadingSchedule = true;
        
        // Ensure isLoadingSchedule is always reset, even if there are errors
        defer {
            isLoadingSchedule = false
            print("[YEAR_CHANGE_DEBUG] Schedule loading completed, isLoadingSchedule reset to false")
        }
        
        self.schedulingData = [:]
        self.schedulingDataByTime = [:]
    
        
        if (FileManager.default.fileExists(atPath: scheduleFile) == false || forceDownload){
            //print ("Sync: Loading schedule data 1")
            if forceDownload {
                // Only download if explicitly forced - don't auto-download on first launch
                DownloadCsv();
            } else {
                print("Schedule file not found - deferring download to proper loading sequence")
                print("This prevents infinite retry loops when network is unavailable")
            }
        }
        
        if let csvDataString = try? String(contentsOfFile: scheduleFile, encoding: String.Encoding.utf8) {
            print("[YEAR_CHANGE_DEBUG] Schedule file loaded successfully, size: \(csvDataString.count) characters")
            
            // Check if file has valid headers - this is a valid state even without data
            let hasValidHeaders = csvDataString.contains("Band,Location,Date,Day,Start Time,End Time,Type")
            if hasValidHeaders {
                scheduleReleased = true
                print("[YEAR_CHANGE_DEBUG] Schedule file has valid headers - marking as released even if no data rows")
            }
            
            var unuiqueIndex = Dictionary<TimeInterval, Int>()
            var csvData: CSV
            
            csvData = try! CSV(csvStringToParse: csvDataString)
            
            print("[YEAR_CHANGE_DEBUG] Processing \(csvData.rows.count) schedule entries")
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
                    if let descriptionUrl = lineData[descriptionUrlField] {
                        setData(bandName: lineData[bandField]!, index:dateIndex, variable:descriptionUrlField, value: descriptionUrl)
                    }
                    
                    print ("adding imageUrlField \(lineData)")
                    if let imageUrl = lineData[imageUrlField] {
                        setData(bandName: lineData[bandField]!, index:dateIndex, variable:imageUrlField, value: imageUrl)
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
        
        print("[YEAR_CHANGE_DEBUG] Schedule population completed for year \(eventYear): \(schedulingData.count) bands, \(schedulingDataByTime.count) time slots")
        
        // Check if combined image list needs regeneration after schedule data is loaded
        if forceDownload {
            print("[YEAR_CHANGE_DEBUG] Schedule data downloaded from URL, checking if combined image list needs regeneration")
            let bandNameHandle = bandNamesHandler.shared
            if CombinedImageListHandler.shared.needsRegeneration(bandNameHandle: bandNameHandle, scheduleHandle: self) {
                print("[YEAR_CHANGE_DEBUG] Regenerating combined image list due to new schedule data")
                CombinedImageListHandler.shared.generateCombinedImageList(
                    bandNameHandle: bandNameHandle,
                    scheduleHandle: self
                ) {
                    print("[YEAR_CHANGE_DEBUG] Combined image list regenerated after schedule data load")
                }
            }
        }

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
        
        // Enhanced retry logic for schedule data
        let maxRetries = 3
        var retryCount = 0
        var httpData = ""
        var success = false
        
        while retryCount < maxRetries && !success {
            retryCount += 1
            print("Schedule data download attempt \(retryCount)/\(maxRetries)")
            
            // Add a small delay between retries
            if retryCount > 1 {
                Thread.sleep(forTimeInterval: 1.0)
            }
            
            httpData = getUrlData(urlString: scheduleUrl)
            print("This will be making HTTP Calls for schedule " + httpData);
            
            // Check if data contains valid CSV headers (schedule file with headers but no data is valid)
            let hasValidHeaders = httpData.contains("Band,Location,Date,Day,Start Time,End Time,Type")
            
            if (httpData.isEmpty == false && (httpData.count > 100 || hasValidHeaders)) {
                success = true
                if hasValidHeaders && httpData.count <= 100 {
                    print("Schedule data downloaded successfully on attempt \(retryCount) - headers only (valid for future years)")
                } else {
                    print("Schedule data downloaded successfully on attempt \(retryCount)")
                }
            } else {
                print("Schedule download attempt \(retryCount) failed: Data is empty or invalid")
                if retryCount < maxRetries {
                    Thread.sleep(forTimeInterval: 2.0)
                }
            }
        }
        
        if !success {
            print("Failed to download schedule data after \(maxRetries) attempts")
        }
        
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
                isLoadingSchedule = false
            }
        }
        
        // Only write new data if it's not empty and appears valid (headers-only files are valid)
        let hasValidHeaders = httpData.contains("Band,Location,Date,Day,Start Time,End Time,Type")
        if (httpData.isEmpty == false && (httpData.count > 100 || hasValidHeaders)) { // Accept headers-only files
            do {
                try httpData.write(toFile: scheduleFile, atomically: false, encoding: String.Encoding.utf8)
                // If write succeeds, remove the .old file
                if didRenameOld && FileManager.default.fileExists(atPath: oldScheduleFile) {
                    try? FileManager.default.removeItem(atPath: oldScheduleFile)
                }
                print("Successfully downloaded and wrote new schedule data")
            } catch let error as NSError {
                print ("Encountered an error writing schedule file " + error.debugDescription)
                isLoadingSchedule = false
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
            let hasValidHeaders = httpData.contains("Band,Location,Date,Day,Start Time,End Time,Type")
            if hasValidHeaders {
                print("Schedule file has valid headers but was rejected due to size - this should not happen")
            } else {
                print ("No valid data downloaded for schedule file, keeping existing data.")
            }
            // Restore the old file if no valid data was downloaded
            if didRenameOld && FileManager.default.fileExists(atPath: oldScheduleFile) {
                do {
                    if FileManager.default.fileExists(atPath: scheduleFile) {
                        try FileManager.default.removeItem(atPath: scheduleFile)
                    }
                    try FileManager.default.moveItem(atPath: oldScheduleFile, toPath: scheduleFile)
                    print("Restored old schedule file after invalid download.")
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
        print("[YEAR_CHANGE_DEBUG] Building time-sorted scheduling data for year \(eventYear)")
        
        // Ensure we're always on a background thread to prevent main thread blocking
        if Thread.isMainThread {
            DispatchQueue.global(qos: .utility).async {
                self.buildTimeSortedSchedulingData()
            }
            return
        }
        
        scheduleHandlerQueue.async(flags: .barrier) {
            self._schedulingDataByTime.removeAll()
            var timeSlotCount = 0
            for bandName in self._schedulingData.keys {
                if let bandSchedule = self._schedulingData[bandName], !bandSchedule.isEmpty {
                    for timeIndex in bandSchedule.keys {
                        print ("[YEAR_CHANGE_DEBUG] timeSortadding timeIndex:" + String(timeIndex) + " bandName:" + bandName);
                        self._schedulingDataByTime[timeIndex] = [bandName:bandName]
                        timeSlotCount += 1
                    }
                }
            }
            print ("[YEAR_CHANGE_DEBUG] schedulingDataByTime built with \(timeSlotCount) time slots for year \(eventYear)")
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



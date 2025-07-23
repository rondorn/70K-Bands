//
//  scheduleHandler.swift
//  70K Bands
//
//  Created by Ron Dorn on 1/31/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import UIKit

open class scheduleHandler {
    
    var schedulingData: [String : [TimeInterval : [String : String]]] = [String : [TimeInterval : [String : String]]]()
    var schedulingDataByTime: [TimeInterval : [String : String]] = [TimeInterval : [String : String]]()
    
    // Track when the last Dropbox error alert was shown (to prevent spam)
    private var lastDropboxErrorAlertTime: TimeInterval = 0
    private let dropboxErrorAlertInterval: TimeInterval = 3600 // 1 hour in seconds

    init() {
        print ("Loading schedule Data")
        getCachedData()
    }
    
    func getCachedData(){
        
        var staticCacheUsed = false
        
        staticSchedule.sync {
            if (cacheVariables.scheduleStaticCache.isEmpty == false && cacheVariables.scheduleTimeStaticCache.isEmpty == false ){
                staticCacheUsed = true
                schedulingData = cacheVariables.scheduleStaticCache
                schedulingDataByTime = cacheVariables.scheduleTimeStaticCache
            }
        }
        
        if (staticCacheUsed == false){
            if ((FileManager.default.fileExists(atPath: schedulingDataCacheFile.path)) == true){
                schedulingData = NSKeyedUnarchiver.unarchiveObject(withFile: schedulingDataCacheFile.path)
                    as! [String : [TimeInterval : [String : String]]]
            } else {
                
                DispatchQueue.main.async {
                    print ("Cache did not load, loading schedule data")
                    self.populateSchedule()
                }
            }
            
            if ((FileManager.default.fileExists(atPath: schedulingDataByTimeCacheFile.path)) == true){
                schedulingDataByTime = NSKeyedUnarchiver.unarchiveObject(withFile: schedulingDataByTimeCacheFile.path) as! [TimeInterval : [String : String]]
            } else {
                DispatchQueue.main.async {
                    print ("Cache did not load, loading schedule data")
                    self.populateSchedule()
                }
            }
            
            if schedulingData.isEmpty && !cacheVariables.justLaunched {
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
        cacheVariables.scheduleStaticCache = [String : [TimeInterval : [String : String]]]()
    }
    
    func populateSchedule(completion: (() -> Void)? = nil){
        
        print ("Loading schedule data 1")
        isLoadingSchedule = true;
        
        self.schedulingData.removeAll();
        self.schedulingDataByTime.removeAll();
    
        
        if (FileManager.default.fileExists(atPath: scheduleFile) == false){
            //print ("Sync: Loading schedule data 1")
            DownloadCsv(completion: completion);
        } else {
            // File exists, process it synchronously
            self._processScheduleFile()
            completion?()
        }
        
        // Remove the duplicate call to _processScheduleFile() that was here
    }
    
    private func _processScheduleFile() {
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
    
    
    func DownloadCsv(completion: (() -> Void)? = nil){
        
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
        
        // Validate that the downloaded data is actually a CSV file
        if !httpData.isEmpty {
            let isCSV = validateCSVContent(httpData)
            if !isCSV {
                let errorMessage = "DropBoxIssue: Downloaded file is not a valid CSV. File appears to be: \(getFileTypeDescription(httpData))"
                let fullContent = "DropBoxIssue: Full file contents:\n\(httpData)"
                print(errorMessage)
                print(fullContent)
                
                // Show toast alert to user (only once per hour to prevent spam)
                let currentTime = Date().timeIntervalSince1970
                if currentTime - lastDropboxErrorAlertTime >= dropboxErrorAlertInterval {
                    DispatchQueue.main.async {
                        self.showToastAlert(title: "Dropbox Issue", message: "Dropbox issues are preventing the data from being loaded.")
                    }
                    lastDropboxErrorAlertTime = currentTime
                }
                
                // Restore old file if available
                if didRenameOld && FileManager.default.fileExists(atPath: oldScheduleFile) {
                    do {
                        if FileManager.default.fileExists(atPath: scheduleFile) {
                            try FileManager.default.removeItem(atPath: scheduleFile)
                        }
                        try FileManager.default.moveItem(atPath: oldScheduleFile, toPath: scheduleFile)
                        print("Restored old schedule file after invalid CSV download.")
                    } catch let restoreError as NSError {
                        print("Failed to restore old schedule file: " + restoreError.debugDescription)
                    }
                }
                
                // Call completion and return early
                DispatchQueue.main.async {
                    completion?()
                }
                return
            }
        }
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
        
        // Process the downloaded file and call completion
        self._processScheduleFile()
        
        // Ensure completion is called on the main thread
        DispatchQueue.main.async {
            completion?()
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
    
    func setData(bandName: String, index: TimeInterval, variable: String, value: String) {
        guard !variable.isEmpty, !value.isEmpty, !bandName.isEmpty, !index.isZero else { return }
        // Ensure the bandName dictionary exists
        if schedulingData[bandName] == nil {
            schedulingData[bandName] = [TimeInterval: [String: String]]()
        }
        // Ensure the index dictionary exists
        if schedulingData[bandName]?[index] == nil {
            schedulingData[bandName]?[index] = [String: String]()
        }
        // Now safely assign
        schedulingData[bandName]?[index]?[variable] = value
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
    
    func getData(_ bandName:String, index:TimeInterval, variable:String) -> String{
        
        var returnValue = ""

        //print ("schedule value lookup. Getting variable " + variable + " for " + bandName + " - " + index.description);
        //print (schedulingData[bandName] as Any)
        if (schedulingData[bandName] != nil && variable.isEmpty == false){
            //print ("schedule value lookup. loop 1")
            if (schedulingData[bandName]![index]?.isEmpty == false){
                //print ("schedule value lookup. loop 2")

                if (schedulingData[bandName]![index]![variable]?.isEmpty == false){
                    //print ("schedule value lookup. loop 3")
                    //print ("schedule value lookup. Returning " + schedulingData[bandName]![index]![variable]!)
                    returnValue = schedulingData[bandName]![index]![variable]!
                }
            }
        }
        //print ("schedule value lookup. Returning nothing for " + variable + " - " + bandName)
        
        return returnValue
    }

    func buildTimeSortedSchedulingData () {
        
        for bandName in schedulingData.keys {
            if (schedulingData[bandName]?.isEmpty == false){
                for timeIndex in (schedulingData[bandName]?.keys)!{
                    print ("timeSortadding timeIndex:" + String(timeIndex) + " bandName:" + bandName);
                    self.schedulingDataByTime[timeIndex] = [bandName:bandName]
                }
            }
        }
    
        print ("schedulingDataByTime is")
        //print (schedulingDataByTime);

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

    private enum DataCollectionState {
        case idle
        case running
        case queued
        case eventYearOverridePending
    }
    private var state: DataCollectionState = .idle
    private let dataCollectionQueue = DispatchQueue(label: "com.70kBands.scheduleHandler.dataCollectionQueue")
    private var queuedRequest: (() -> Void)?
    private var eventYearOverrideRequested: Bool = false
    private var cancelRequested: Bool = false

    /// Request a schedule data collection. If eventYearOverride is true, aborts all others and runs immediately.
    func requestDataCollection(eventYearOverride: Bool = false, completion: (() -> Void)? = nil) {
        dataCollectionQueue.async { [weak self] in
            guard let self = self else { return }
            if eventYearOverride {
                // Cancel everything and run this immediately
                self.eventYearOverrideRequested = true
                self.cancelRequested = true
                self.queuedRequest = nil
                if self.state == .running {
                    self.state = .eventYearOverridePending
                } else {
                    self.state = .running
                    self._startDataCollection(eventYearOverride: true, completion: completion)
                }
            } else {
                if self.state == .idle {
                    self.state = .running
                    self._startDataCollection(eventYearOverride: false, completion: completion)
                } else if self.state == .running && self.queuedRequest == nil {
                    // Queue one more
                    self.queuedRequest = { [weak self] in self?.requestDataCollection(eventYearOverride: false, completion: completion) }
                    self.state = .queued
                } else {
                    // Already queued, ignore further requests
                }
            }
        }
    }

    private func _startDataCollection(eventYearOverride: Bool, completion: (() -> Void)?) {
        cancelRequested = false
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self._downloadCsvWithCancellation(eventYearOverride: eventYearOverride, completion: completion)
        }
    }

    private func _downloadCsvWithCancellation(eventYearOverride: Bool, completion: (() -> Void)?) {
        defer {
            // Ensure completion is always called
            DispatchQueue.main.async {
                completion?()
            }
        }
        
        var scheduleUrl = ""
        if (scheduleUrl.isEmpty == true){
            scheduleUrl = defaultPrefsValue
        }
        print ("Downloading Schedule URL " + scheduleUrl);
        scheduleUrl = getPointerUrlData(keyValue: "scheduleUrl")
        if cancelRequested { self._dataCollectionDidFinish(); return }
        print("scheduleUrl = " + scheduleUrl)
        
        let httpData = getUrlData(urlString: scheduleUrl)
        if cancelRequested { self._dataCollectionDidFinish(); return }
        print("This will be making HTTP Calls for schedule " + httpData);
        
        let oldScheduleFile = scheduleFile + ".old"
        var didRenameOld = false
        
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
        
        if cancelRequested { self._dataCollectionDidFinish(); return }
        
        if (httpData.isEmpty == false){
            do {
                try httpData.write(toFile: scheduleFile, atomically: false, encoding: String.Encoding.utf8)
                if didRenameOld && FileManager.default.fileExists(atPath: oldScheduleFile) {
                    try? FileManager.default.removeItem(atPath: oldScheduleFile)
                }
            } catch let error as NSError {
                print ("Encountered an error writing schedule file " + error.debugDescription)
                isLoadingBandData = false
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
        
        if cancelRequested { self._dataCollectionDidFinish(); return }
        
        // Optionally, call populateSchedule or other post-processing here
        self._dataCollectionDidFinish()
    }

    private func _dataCollectionDidFinish() {
        dataCollectionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.eventYearOverrideRequested {
                self.eventYearOverrideRequested = false
                self.cancelRequested = false
                self.state = .idle
                self.requestDataCollection(eventYearOverride: true)
            } else if let next = self.queuedRequest {
                self.queuedRequest = nil
                self.state = .running
                next()
            } else {
                self.state = .idle
            }
        }
    }
    
    /// Validates if the downloaded content is a valid CSV file
    private func validateCSVContent(_ content: String) -> Bool {
        // Check if content is empty
        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        
        // Check if content starts with HTML (common error response)
        if content.hasPrefix("<!DOCTYPE") || content.hasPrefix("<html") || content.hasPrefix("<HTML") {
            return false
        }
        
        // Check if content contains CSV-like structure (comma-separated values)
        let lines = content.components(separatedBy: .newlines)
        if lines.isEmpty {
            return false
        }
        
        // Check if first line contains commas (typical CSV header)
        let firstLine = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)
        if firstLine.isEmpty {
            return false
        }
        
        // Count commas in first line - CSV should have multiple columns
        let commaCount = firstLine.filter { $0 == "," }.count
        if commaCount < 2 { // At least 3 columns (2 commas)
            return false
        }
        
        // Check if content contains typical CSV patterns
        let hasCSVPatterns = content.contains(",") && 
                            (content.contains("\n") || content.contains("\r")) &&
                            !content.contains("<html") &&
                            !content.contains("<!DOCTYPE")
        
        return hasCSVPatterns
    }
    
    /// Determines the type of file based on its content
    private func getFileTypeDescription(_ content: String) -> String {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedContent.isEmpty {
            return "Empty file"
        }
        
        if trimmedContent.hasPrefix("<!DOCTYPE") || trimmedContent.hasPrefix("<html") {
            return "HTML file (likely error page)"
        }
        
        if trimmedContent.hasPrefix("<?xml") {
            return "XML file"
        }
        
        if trimmedContent.hasPrefix("{") || trimmedContent.hasPrefix("[") {
            return "JSON file"
        }
        
        if trimmedContent.contains("error") || trimmedContent.contains("Error") {
            return "Error response"
        }
        
        if trimmedContent.contains("404") {
            return "404 Not Found response"
        }
        
        if trimmedContent.contains("403") {
            return "403 Forbidden response"
        }
        
        if trimmedContent.contains("500") {
            return "500 Server Error response"
        }
        
        // Check if it looks like CSV
        let lines = trimmedContent.components(separatedBy: .newlines)
        if !lines.isEmpty {
            let firstLine = lines[0]
            let commaCount = firstLine.filter { $0 == "," }.count
            if commaCount >= 2 {
                return "Possible CSV file with \(commaCount + 1) columns"
            }
        }
        
        return "Unknown file type (first 100 chars: \(String(trimmedContent.prefix(100)))"
    }
    
    /// Shows a toast alert to the user
    private func showToastAlert(title: String, message: String) {
        // Find the top view controller to present the alert
        if let topViewController = UIApplication.shared.keyWindow?.rootViewController {
            var presentingViewController = topViewController
            while let presented = presentingViewController.presentedViewController {
                presentingViewController = presented
            }
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            presentingViewController.present(alert, animated: true)
        }
    }
}



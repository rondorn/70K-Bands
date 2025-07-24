//
//  ShowsAttended.swift
//  
//
//  Created by Ron Dorn on 6/10/18.
//
import Foundation
import UIKit
import CoreData

open class ShowsAttended {

    let iCloudHandle = iCloudDataHandler()
    private var showsAttendedArray = [String : String]();
    private var isLoadingData = false
    private let attendedLock = NSLock()
    private var lastNotificationTime: TimeInterval = 0
    private let notificationDebounceInterval: TimeInterval = 0.1 // 100ms debounce
    
    /**
     Initializes a new instance of ShowsAttended and loads cached data.
     */
    init(){
        print ("Loading shows attended data")
        getCachedData()
    }
    
    
    /**
     Loads cached show attendance data, using a static cache if available.
     */
    func getCachedData(){
        
        // Prevent infinite loop by checking if already loading
        if isLoadingData {
            print("ShowsAttended: Skipping getCachedData - already loading data")
            return
        }
        
        var staticCacheUsed = false
        
        staticAttended.sync() {
            if (cacheVariables.attendedStaticCache.isEmpty == true){
                // Only load if we have band names available to prevent infinite loop
                let bandNameHandle = bandNamesHandler.shared
                
                // Prevent infinite loop: check if band names are being loaded
                if readingBandFile {
                    print("ShowsAttended: Skipping getCachedData - band names are being loaded")
                    return
                }
                
                if !bandNameHandle.getBandNames().isEmpty {
                    loadShowsAttended()
                } else {
                    print("ShowsAttended: Skipping loadShowsAttended - band names not available yet")
                }
            } else {
                staticCacheUsed = true
                showsAttendedArray = cacheVariables.attendedStaticCache
            }
        }

        //iCloudHandle.readCloudAttendedData(attendedHandle: self);
    }
    
    /**
     Requests data collection with optional year override and completion handler.
     - Parameters:
        - eventYearOverride: If true, cancels all other operations and runs immediately
        - completion: Completion handler called when operation finishes
     */
    func requestDataCollection(eventYearOverride: Bool = false, completion: (() -> Void)? = nil) {
        // For ShowsAttended, we just load cached data since it doesn't download from network
        // Only load if not already loading to prevent infinite loops
        if !isLoadingData {
            getCachedData()
        }
        completion?()
    }
    
    /**
     Sets the showsAttendedArray to the provided attendedData.
     - Parameter attendedData: A dictionary of attended data to set.
     */
    func setShowsAttended(attendedData: [String : String]){
        attendedLock.lock()
        defer { attendedLock.unlock() }
        showsAttendedArray = attendedData
    }
    
    /**
     Returns the current showsAttendedArray.
     - Returns: A dictionary of show attendance data.
     */
    func getShowsAttended()->[String : String]{
        attendedLock.lock()
        defer { attendedLock.unlock() }
        
        // Defensive check: ensure showsAttendedArray is actually a dictionary
        guard showsAttendedArray is [String: String] else {
            print("ShowsAttended: CRITICAL ERROR - showsAttendedArray is corrupted in getShowsAttended, type: \(type(of: showsAttendedArray))")
            // Reset the corrupted dictionary
            showsAttendedArray = [:]
            return [:]
        }
        
        // Safer approach: check if we can access the dictionary safely
        let dictionaryCount = showsAttendedArray.count
        if dictionaryCount == 0 {
            // Return empty array if data is not ready to prevent infinite loop
            if isLoadingData {
                print("ShowsAttended: Returning empty array - data not ready yet")
                return [:]
            }
            return [:]
        }
        
        return showsAttendedArray
    }
    
    /**
     Saves the current showsAttendedArray to persistent storage.
     */
    func saveShowsAttended(){
        
        if (showsAttendedArray.count > 0){
            do {
                let json = try JSONEncoder().encode(showsAttendedArray)
                try json.write(to: showsAttended)
                writeLastScheduleDataWrite();
                print ("Loading show attended data! saved showData \(showsAttendedArray)")
            } catch {
                print ("Loading show attended data! Error, unable to save showsAtteneded Data \(error.localizedDescription)")
            }
        }
    }

    /**
     Loads show attendance data from persistent storage and updates the static cache.
     */
    func loadShowsAttended(){
        
        // Prevent infinite loop by checking if already loading
        if isLoadingData {
            print("ShowsAttended: Skipping loadShowsAttended - already loading data")
            return
        }
        
        isLoadingData = true
        
        //print ("Loading shows attended data 1")
        let bandNameHandle = bandNamesHandler.shared
        
        // Prevent infinite loop: check if band names are being loaded
        if readingBandFile {
            print("ShowsAttended: Skipping loadShowsAttended - band names are being loaded")
            isLoadingData = false
            return
        }
        
        let allBands = bandNameHandle.getBandNames()
        
        // Prevent infinite loop by checking if band names are available
        if allBands.isEmpty {
            print("ShowsAttended: Skipping loadShowsAttended - band names not available")
            isLoadingData = false
            return
        }
        
        let artistUrl = getScheduleUrl()

        var unuiqueSpecial = [String]()
        do {
            let data = try Data(contentsOf: showsAttended, options: [])
            //print ("Loading show attended data!! From json")
            
            // Defensive check: validate JSON structure before parsing
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            
            // Ensure we have a dictionary
            guard let dict = jsonObject as? [String: String] else {
                print("ShowsAttended: ERROR - JSON root is not a dictionary, type: \(type(of: jsonObject))")
                showsAttendedArray = [:]
                isLoadingData = false
                return
            }
            
            showsAttendedArray = dict
            print ("Loaded show attended data!! From json \(showsAttendedArray)")
            var needsMigration = false
            let currentTimestamp = String(format: "%.0f", Date().timeIntervalSince1970)
            // Migrate old format (no timestamp) to new format
            for (key, value) in showsAttendedArray {
                let parts = value.split(separator: ":")
                if parts.count == 1 {
                    // Old format, add timestamp
                    showsAttendedArray[key] = value + ":" + currentTimestamp
                    needsMigration = true
                }
            }
            if needsMigration {
                print("Migrated old attendance data to new format with timestamps.")
                saveShowsAttended()
            }
            if (showsAttendedArray.count > 0){
                for index in showsAttendedArray {
                    print ("Loaded show attended data!! From \(index.key) - \(index.value)")
                    showsAttendedArray[index.key] = index.value
                }
            }
            print ("Loading show attended data! cleanup event data loaded showData \(showsAttendedArray)")
            
            // Prevent populating cache with empty data unless app just launched
            if showsAttendedArray.isEmpty && !cacheVariables.justLaunched {
                print("Skipping attended cache population: showsAttendedArray is empty and app is not just launched.")
                return
            }
            staticAttended.async(flags: .barrier) {
                for index in self.showsAttendedArray {

                    cacheVariables.attendedStaticCache[index.key] = index.value ?? ""
                }
            }
            
            //iCloudHandle.readCloudAttendedData(attendedHandle: self)
            
            // Reset loading flag
            isLoadingData = false
            
        } catch {
            print ("Loaded show attended data!! Error, unable to load showsAtteneded Data \(error.localizedDescription)")
            // Reset loading flag on error
            isLoadingData = false
        }
    
    }
    
    /**
     Adds or updates a show attended record with a specific status and timestamp.
     - Parameters:
        - band: The band name.
        - location: The event location.
        - startTime: The event start time.
        - eventType: The type of event.
        - eventYearString: The event year as a string.
        - status: The attendance status to set.
        - newTime: The timestamp to use (Double, seconds since epoch).
     */
    func addShowsAttendedWithStatusAndTime(band: String, location: String, startTime: String, eventType: String, eventYearString: String, status: String, newTime: Double) {
        let index = band + ":" + location + ":" + startTime + ":" + eventType + ":" + eventYearString
        let timestamp = String(format: "%.0f", newTime)
        changeShowAttendedStatus(index: index, status: status + ":" + timestamp)
        staticLastModifiedDate.async(flags: .barrier) {
            cacheVariables.lastModifiedDate = Date()
        }
    }

    /**
     Adds or updates a show attended record with a specific status (uses current time as timestamp).
     - Parameters:
        - band: The band name.
        - location: The event location.
        - startTime: The event start time.
        - eventType: The type of event.
        - eventYearString: The event year as a string.
        - status: The attendance status to set.
     */
    func addShowsAttendedWithStatus (band: String, location: String, startTime: String, eventType: String, eventYearString: String, status: String){
        let now = Date().timeIntervalSince1970
        addShowsAttendedWithStatusAndTime(band: band, location: location, startTime: startTime, eventType: eventType, eventYearString: eventYearString, status: status, newTime: now)
    }
    
    /**
     Adds or cycles the attendance status for a show and returns the new status.
     - Parameters:
        - band: The band name.
        - location: The event location.
        - startTime: The event start time.
        - eventType: The type of event.
        - eventYearString: The event year as a string.
     - Returns: The new attendance status as a string.
     
     Cycling Logic:
     - If attended value is null/empty → First click sets it to "Will Attend"
     - If the value is "Will Attend" → Change to "Partially Attended" (only for 'show' events)
     - If the value is "Partially Attended" → Change to "Will Not Attend"
     - If the value is "Will Not Attend" → Change to "Will Attend"
     - For event types other than shows, partial is not a valid value, so just toggle between "Will Attend" and "Will Not Attend"
     
     Note: Null or empty entries display as "Will Not Attend" but cycle to "Will Attend" on first click.
     */
    func addShowsAttended (band: String, location: String, startTime: String, eventType: String, eventYearString: String)->String{
        attendedLock.lock()
        defer { attendedLock.unlock() }
        
        // Defensive check: ensure showsAttendedArray is actually a dictionary
        guard showsAttendedArray is [String: String] else {
            print("ShowsAttended: CRITICAL ERROR - showsAttendedArray is corrupted in addShowsAttended, type: \(type(of: showsAttendedArray))")
            // Reset the corrupted dictionary
            showsAttendedArray = [:]
        }
        
        // Safer approach: check if we can access the dictionary safely
        let dictionaryCount = showsAttendedArray.count
        if dictionaryCount == 0 {
            // Only load if we have band names available to prevent infinite loop
            let bandNameHandle = bandNamesHandler.shared
            if !bandNameHandle.getBandNames().isEmpty {
                loadShowsAttended();
            } else {
                print("ShowsAttended: Skipping loadShowsAttended in addShowsAttended - band names not available")
            }
        }
        
        var eventTypeValue = eventType;
        if (eventType == unofficalEventTypeOld){
            eventTypeValue = unofficalEventType;
        }
        let index = band + ":" + location + ":" + startTime + ":" + eventTypeValue + ":" + eventYearString
        print ("Loading show attended data! addShowsAttended 1 addAttended data index = '\(index)'")
        var value = ""
        let currentStatus = getShowAttendedStatusRawUnsafe(index: index)
        
        // IMPORTANT: Null or empty entries are treated as "Will Not Attend" (sawNoneStatus) for display
        // Cycling logic:
        // If attended value is null/empty → First click sets it to "Will Attend"
        // If the value is "Will Attend" → Change to "Partially Attended" (only for 'show' events)
        // If the value is "Partially Attended" → Change to "Will Not Attend"
        // If the value is "Will Not Attend" → Change to "Will Attend"
        // For event types other than shows, partial is not a valid value, so just toggle between "Will Attend" and "Will Not Attend"
        if (currentStatus == nil) {
            // First click on a new event - set to "Will Attend"
            value = sawAllStatus // Will Attend
        } else if (currentStatus == sawAllStatus) {
            if eventTypeValue == showType {
                value = sawSomeStatus // Partially Attended
            } else {
                value = sawNoneStatus // For non-shows, just toggle between will and wont
            }
        } else if (currentStatus == sawSomeStatus) {
            value = sawNoneStatus // Partially Attended -> Will Not Attend
        } else if (currentStatus == sawNoneStatus) {
            value = sawAllStatus // Will Not Attend -> Will Attend
        } else {
            value = sawAllStatus // fallback - treats any unrecognized value as "Will Attend" on first click
        }
        let timestamp = String(format: "%.0f", Date().timeIntervalSince1970)
        changeShowAttendedStatus(index: index, status: value + ":" + timestamp)
        staticLastModifiedDate.async(flags: .barrier) {
            cacheVariables.lastModifiedDate = Date()
        }
        return value
    }
    
    /**
     Changes the attendance status for a specific show and updates caches and cloud storage.
     - Parameters:
        - index: The unique index for the show.
        - status: The new attendance status.
     */
    func changeShowAttendedStatus(index: String, status:String){
        attendedLock.lock()
        defer { attendedLock.unlock() }
        
        print ("Loading show attended data! addShowsAttended 2 Settings equals index = '\(index)' - \(status)")
        showsAttendedArray[index] = status
        
        let firebaseEventWrite = firebaseEventDataWrite();
        firebaseEventWrite.writeEvent(index: index, status: status)
        staticAttended.async(flags: .barrier) {
            cacheVariables.attendedStaticCache[index] = status
        }
        saveShowsAttended()
        
        // HIGH PRIORITY: Post immediate update notification with debouncing
        DispatchQueue.main.async {
            let currentTime = Date().timeIntervalSince1970
            if currentTime - self.lastNotificationTime > self.notificationDebounceInterval {
                self.lastNotificationTime = currentTime
                NotificationCenter.default.post(name: Notification.Name("AttendedChangeImmediate"), object: nil)
            }
        }
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            let iCloudHandle = iCloudDataHandler()
            iCloudHandle.writeAScheduleRecord(eventIndex: index, status: status)
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }
    
    /**
     Returns the attendance icon for a specific show.
     - Parameters:
        - band: The band name.
        - location: The event location.
        - startTime: The event start time.
        - eventType: The type of event.
        - eventYearString: The event year as a string.
     - Returns: The corresponding UIImage for the attendance status.
     */
    func getShowAttendedIcon  (band: String, location: String, startTime: String, eventType: String,eventYearString: String)->UIImage{
        
        var iconName = String()
        var icon = UIImage()
        
        var eventTypeValue = eventType;
        if (eventType == unofficalEventTypeOld){
            eventTypeValue = unofficalEventType;
        }
        
        let value = getShowAttendedStatus(band: band,location: location,startTime: startTime,eventType: eventTypeValue,eventYearString: eventYearString);
        print ("Loading show attended getShowAttendedStatus for '\(band)' - \(location) - \(value)")
        
        let index = band + ":" + location + ":" + startTime + ":" + eventTypeValue + ":" + eventYearString
        
        print ("Loading show attended data! getShowAttendedIcon 2 Settings equals showsAttendedArray '\(index)' - \(value)")
        if (value == sawAllStatus){
            iconName = "icon-seen"
        
        } else if (value == sawSomeStatus){
            iconName = "icon-seen-partial"

        }
        
        if (iconName.isEmpty == false){
            icon = UIImage(named: iconName) ?? UIImage()
        }
        
        return icon
    }

    func getShowAttendedColor  (band: String, location: String, startTime: String, eventType: String,eventYearString: String)->UIColor{
        
        var eventTypeValue = eventType;
        if (eventType == unofficalEventTypeOld){
            eventTypeValue = unofficalEventType;
        }
        
        var color : UIColor = UIColor()
        
        let value = getShowAttendedStatus(band: band,location: location,startTime: startTime,eventType: eventTypeValue, eventYearString: eventYearString);
        
        if (value == sawAllStatus){
            color = sawAllColor
            
        } else if (value == sawSomeStatus){
           color = sawSomeColor
            
        } else if (value == sawNoneStatus){
            color = sawNoneColor
        }
        
        return color
    }
    
    /**
     Returns the attendance status for a specific show.
     - Parameters:
        - band: The band name.
        - location: The event location.
        - startTime: The event start time.
        - eventType: The type of event.
        - eventYearString: The event year as a string.
     - Returns: The attendance status as a string. Null or empty entries are treated as "Will Not Attend" (sawNoneStatus) for display.
     */
    func getShowAttendedStatus (band: String, location: String, startTime: String, eventType: String,eventYearString: String)->String{
        attendedLock.lock()
        defer { attendedLock.unlock() }
        
        // Defensive check: ensure showsAttendedArray is actually a dictionary
        guard showsAttendedArray is [String: String] else {
            print("ShowsAttended: CRITICAL ERROR - showsAttendedArray is corrupted in getShowAttendedStatus, type: \(type(of: showsAttendedArray))")
            // Reset the corrupted dictionary
            showsAttendedArray = [:]
            return sawNoneStatus
        }
        
        // Safer approach: check if we can access the dictionary safely
        let dictionaryCount = showsAttendedArray.count
        if dictionaryCount == 0 {
            // Prevent infinite loop by checking if data is ready
            if isLoadingData {
                print("ShowsAttended: Skipping getShowAttendedStatus - data not ready yet")
                return sawNoneStatus
            }
            return sawNoneStatus
        }
        
        var eventTypeVariable = eventType;
        if (eventType == unofficalEventTypeOld){
            eventTypeVariable = unofficalEventType;
        }
        let index = band + ":" + location + ":" + startTime + ":" + eventTypeVariable + ":" + eventYearString
        let raw = getShowAttendedStatusRawUnsafe(index: index)
        var value = ""
        print ("Loading show attended data! getShowAttendedStatusCheck on show index = '\(index)' for status=\(raw ?? "")")
        
        // IMPORTANT: Null or empty entries are treated as "Will Not Attend" (sawNoneStatus) for display
        if (raw == sawAllStatus){
            value = sawAllStatus
        } else if (raw == sawSomeStatus){
            value = sawSomeStatus
        } else {
            // This handles null, empty, and any other unrecognized values - all treated as "Will Not Attend" for display
            value = sawNoneStatus;
        }
        return value
    }
    
    func getShowAttendedStatusUserFriendly (band: String, location: String, startTime: String, eventType: String,eventYearString: String)->String{
        var status = getShowAttendedStatus(band: band, location: location, startTime: startTime, eventType: eventType, eventYearString: eventYearString)
        
        var userFriendlyStatus = "";
        
        if (status == sawAllStatus){
            status = NSLocalizedString("All Of Event", comment: "")
        
        } else if (status == sawSomeStatus){
                status = NSLocalizedString("Part Of Event", comment: "")
            
        } else {
                status = NSLocalizedString("None Of Event", comment: "")
        }
        
        return status
        
    }
    
    func setShowsAttendedStatus(_ sender: UITextField, status: String)->String{
        
        var message : String
        var fieldText = sender.text;
    
        print ("getShowAttendedStatus (inset) = \(status) =\(fieldText ?? "")")
        if (status == sawAllStatus){
            sender.textColor = UIColor.lightGray
            sender.text = fieldText
            message = NSLocalizedString("All Of Event", comment: "")
            
        } else if (status == sawSomeStatus){
            sender.textColor = UIColor.lightGray
            
            fieldText = removeIcons(text: fieldText!)
            sender.text = fieldText
            message = NSLocalizedString("Part Of Event", comment: "")
            
        } else {
            sender.textColor = UIColor.lightGray
            sender.text = fieldText
            message = NSLocalizedString("None Of Event", comment: "")
        }
        
        return message;
    }

    func removeIcons(text : String)->String {
        
        var textValue = text
        
        textValue = textValue.replacingOccurrences(of: sawAllIcon, with: "")
        textValue = textValue.replacingOccurrences(of: sawSomeIcon, with: "")
        
        return textValue
        
    }
    
    func readLastScheduleDataWrite()-> Double{
        
        var lastPriorityDataWrite = Double(32503680000)
        
        if let data = try? String(contentsOf: lastScheduleDataWriteFile, encoding: String.Encoding.utf8) {
            lastPriorityDataWrite = Double(data)!
        }
        
        return lastPriorityDataWrite
    }
    
    func writeLastScheduleDataWrite(){
        
        let currentTime = String(Date().timeIntervalSince1970)
       
        do {
            //try FileManager.default.removeItem(at: storageFile)
            try currentTime.write(to:lastScheduleDataWriteFile, atomically: false, encoding: String.Encoding.utf8)
            print ("writing ScheduleData Date")
        } catch _ {
            print ("writing ScheduleData Date, failed")
        }
    }
    
    // Helper to get the raw status (without timestamp) - thread-safe public interface
    func getShowAttendedStatusRaw(index: String) -> String? {
        attendedLock.lock()
        defer { attendedLock.unlock() }
        return getShowAttendedStatusRawUnsafe(index: index)
    }
    
    // Helper to get the raw status (without timestamp) - unsafe internal method
    private func getShowAttendedStatusRawUnsafe(index: String) -> String? {
        // Defensive check: ensure showsAttendedArray is actually a dictionary
        guard showsAttendedArray is [String: String] else {
            print("ShowsAttended: CRITICAL ERROR - showsAttendedArray is corrupted, type: \(type(of: showsAttendedArray))")
            // Reset the corrupted dictionary
            showsAttendedArray = [:]
            return nil
        }
        
        // Safer approach: check if we can access the dictionary safely
        let dictionaryCount = showsAttendedArray.count
        if dictionaryCount == 0 {
            // Prevent infinite loop by checking if data is ready
            if isLoadingData {
                print("ShowsAttended: Skipping getShowAttendedStatusRaw - data not ready yet")
                return nil
            }
            return nil
        }
        
        // Safe access to the dictionary value using optional chaining
        guard let value = showsAttendedArray[index] else { return nil }
        let parts = value.split(separator: ":")
        return parts.first.map { String($0) }
    }
    
    // New: Get the last change timestamp for a show
    func getShowAttendedLastChange(index: String) -> Double {
        // Defensive check: ensure showsAttendedArray is actually a dictionary
        guard showsAttendedArray is [String: String] else {
            print("ShowsAttended: CRITICAL ERROR - showsAttendedArray is corrupted in getShowAttendedLastChange, type: \(type(of: showsAttendedArray))")
            // Reset the corrupted dictionary
            showsAttendedArray = [:]
            return 0
        }
        
        // Safer approach: check if we can access the dictionary safely
        let dictionaryCount = showsAttendedArray.count
        if dictionaryCount == 0 {
            return 0
        }
        
        // Safe access to the dictionary value using optional chaining
        guard let value = showsAttendedArray[index] else { return 0 }
        let parts = value.split(separator: ":")
        if parts.count == 2, let ts = Double(parts[1]) { return ts }
        if parts.count == 3, let ts = Double(parts[2]) { return ts } // for iCloud format
        return 0
    }
    
    // Returns the last change timestamp for a show, given its parameters
    func getShowAttendedStatusLastChange(band: String, location: String, startTime: String, eventType: String, eventYearString: String) -> Double {
        var eventTypeValue = eventType
        if eventType == unofficalEventTypeOld {
            eventTypeValue = unofficalEventType
        }
        let index = band + ":" + location + ":" + startTime + ":" + eventTypeValue + ":" + eventYearString
        return getShowAttendedLastChange(index: index)
    }
    
}


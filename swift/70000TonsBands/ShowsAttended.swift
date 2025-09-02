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
    // Thread-safe queue and backing store for showsAttendedArray
    private let showsAttendedQueue = DispatchQueue(label: "com.yourapp.showsAttendedQueue", attributes: .concurrent)
    private var _showsAttendedArray = [String : String]()
    
    // Thread-safe accessors
    var showsAttendedArray: [String : String] {
        get { showsAttendedQueue.sync { _showsAttendedArray } }
        set { showsAttendedQueue.async(flags: .barrier) { self._showsAttendedArray = newValue } }
    }
    // Helper for mutation
    private func mutateShowsAttendedArray(_ block: @escaping (inout [String: String]) -> Void) {
        showsAttendedQueue.async(flags: .barrier) { block(&self._showsAttendedArray) }
    }
    
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
        var staticCacheUsed = false
        staticAttended.sync() {
            if (cacheVariables.attendedStaticCache.isEmpty == true){
                loadShowsAttended()
            } else {
                staticCacheUsed = true
                self.showsAttendedArray = cacheVariables.attendedStaticCache
                
                // Even when using static cache, check if migration is needed
                let currentArray = showsAttendedQueue.sync { self._showsAttendedArray }
                var needsMigration = false
                let currentTimestamp = String(format: "%.0f", Date().timeIntervalSince1970)
                
                for (key, value) in currentArray {
                    let parts = value.split(separator: ":")
                    if parts.count == 1 {
                        mutateShowsAttendedArray { arr in arr[key] = value + ":" + currentTimestamp }
                        needsMigration = true
                    }
                }
                
                if needsMigration {
                    print("Migrated old attendance data from static cache to new format with timestamps.")
                    saveShowsAttended()
                    // Update the static cache with migrated data
                    staticAttended.async(flags: .barrier) {
                        for (key, value) in self.showsAttendedArray {
                            cacheVariables.attendedStaticCache[key] = value
                        }
                    }
                }
            }
        }
        // Note: iCloud attended data restoration is now handled centrally in MasterViewController
        // to prevent multiple simultaneous executions
    }
    
    /**
     Sets the showsAttendedArray to the provided attendedData.
     - Parameter attendedData: A dictionary of attended data to set.
     */
    func setShowsAttended(attendedData: [String : String]){
        self.showsAttendedArray = attendedData
    }
    
    /**
     Returns the current showsAttendedArray (copy).
     - Returns: A dictionary of show attendance data.
     */
    func getShowsAttended()->[String : String]{
        return showsAttendedQueue.sync { self._showsAttendedArray }
    }
    
    /**
     Saves the current showsAttendedArray to persistent storage.
     */
    func saveShowsAttended(){
        let currentArray = showsAttendedQueue.sync { self._showsAttendedArray }
        if (currentArray.count > 0){
            do {
                let json = try JSONEncoder().encode(currentArray)
                try json.write(to: showsAttended)
                writeLastScheduleDataWrite();
                // Reduced logging for performance
            } catch {
                print ("Loading show attended data! Error, unable to save showsAtteneded Data \(error.localizedDescription)")
            }
        }
    }
    
    /**
     Loads show attendance data from persistent storage and updates the static cache.
     */
    func loadShowsAttended(){
        let bandNameHandle = bandNamesHandler.shared
        let allBands = bandNameHandle.getBandNames()
        let artistUrl = getScheduleUrl()
        var unuiqueSpecial = [String]()
        do {
            let data = try Data(contentsOf: showsAttended, options: [])
            if let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String : String] {
                self.showsAttendedArray = dict
            } else {
                print("ShowsAttended: ERROR - Unable to decode showsAttendedArray from JSON, data may be corrupted or in an unexpected format.")
                self.showsAttendedArray = [:]
            }
            // Reduced logging for performance - data loaded from JSON
            var needsMigration = false
            let currentTimestamp = String(format: "%.0f", Date().timeIntervalSince1970)
            // Migrate old format (no timestamp) to new format
            let currentArray = showsAttendedQueue.sync { self._showsAttendedArray }
            for (key, value) in currentArray {
                let parts = value.split(separator: ":")
                if parts.count == 1 {
                    mutateShowsAttendedArray { arr in arr[key] = value + ":" + currentTimestamp }
                    needsMigration = true
                }
            }
            if needsMigration {
                print("Migrated old attendance data to new format with timestamps.")
                saveShowsAttended()
            }
            let afterMigrationArray = showsAttendedQueue.sync { self._showsAttendedArray }
            if (afterMigrationArray.count > 0){
                for index in afterMigrationArray {
                    mutateShowsAttendedArray { arr in arr[index.key] = index.value }
                }
            }
            // Reduced logging for performance
            if afterMigrationArray.isEmpty && !cacheVariables.justLaunched {
                print("Skipping attended cache population: showsAttendedArray is empty and app is not just launched.")
                return
            }
            staticAttended.async(flags: .barrier) {
                for index in afterMigrationArray {
                    cacheVariables.attendedStaticCache[index.key] = index.value
                }
            }
        } catch {
            // Handle missing showsAttended.data gracefully - this is expected on first install
            if let nsError = error as NSError?, nsError.code == 260 { // NSFileReadNoSuchFileError
                print("Shows attended data file does not exist yet - this is normal for first app launch. Starting with empty attendance records.")
                // Initialize with empty data for first launch
                self.showsAttendedArray = [:]
            } else {
                print("Error loading shows attended data: \(error.localizedDescription)")
            }
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
     */
    func addShowsAttended (band: String, location: String, startTime: String, eventType: String, eventYearString: String)->String{
        let currentArray = showsAttendedQueue.sync { self._showsAttendedArray }
        if (currentArray.count == 0){
            loadShowsAttended();
        }
        var eventTypeValue = eventType;
        if (eventType == unofficalEventTypeOld){
            eventTypeValue = unofficalEventType;
        }
        let index = band + ":" + location + ":" + startTime + ":" + eventTypeValue + ":" + eventYearString
        // Reduced logging for performance
        var value = ""
        let currentStatus = getShowAttendedStatusRaw(index: index)
        print("DEBUG: addShowsAttended - currentStatus: '\(String(describing: currentStatus))', currentArray.isEmpty: \(currentArray.isEmpty)")
        
        // Treat nil and sawNoneStatus as the same thing - both represent "Will Not Attend"
        if (currentArray.isEmpty == true || currentStatus == nil || currentStatus == sawNoneStatus) {
            // Null or "Will Not Attend" -> "Will Attend"
            value = sawAllStatus
            print("DEBUG: addShowsAttended - Setting to Will Attend (sawAllStatus)")
        } else if (currentStatus == sawAllStatus && eventType == showType ){
            // "Will Attend" -> "Will Attend Some" (only for shows, not other event types)
            value = sawSomeStatus
            print("DEBUG: addShowsAttended - Setting to Will Attend Some (sawSomeStatus)")
        } else if (currentStatus == sawSomeStatus){
            // "Will Attend Some" -> "Will Not Attend"
            value = sawNoneStatus
            print("DEBUG: addShowsAttended - Setting to Will Not Attend (sawNoneStatus)")
        } else if (currentStatus == sawAllStatus) {
            // "Will Attend" for non-show events -> "Will Not Attend"
            value = sawNoneStatus
            print("DEBUG: addShowsAttended - Setting to Will Not Attend (sawNoneStatus) for non-show event")
        } else {
            // fallback - treats any unrecognized value as "Will Not Attend" -> "Will Attend"
            value = sawAllStatus
            print("DEBUG: addShowsAttended - Fallback: unrecognized status '\(String(describing: currentStatus))', setting to Will Attend")
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
        // Reduced logging for performance
        mutateShowsAttendedArray { arr in arr[index] = status }
        let firebaseEventWrite = firebaseEventDataWrite();
        firebaseEventWrite.writeEvent(index: index, status: status)
        staticAttended.async(flags: .barrier) {
            cacheVariables.attendedStaticCache[index] = status
        }
        saveShowsAttended()
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            let iCloudHandle = iCloudDataHandler()
            iCloudHandle.writeAScheduleRecord(eventIndex: index, status: status)
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }
    
    /**
     Changes the attended status for a show with an option to skip iCloud writing
     - Parameters:
        - index: The event index
        - status: The attendance status
        - skipICloud: If true, skips writing to iCloud (useful during restoration)
     */
    func changeShowAttendedStatus(index: String, status: String, skipICloud: Bool) {
        // Reduced logging for performance
        mutateShowsAttendedArray { arr in arr[index] = status }
        let firebaseEventWrite = firebaseEventDataWrite();
        firebaseEventWrite.writeEvent(index: index, status: status)
        staticAttended.async(flags: .barrier) {
            cacheVariables.attendedStaticCache[index] = status
        }
        saveShowsAttended()
        
        if !skipICloud {
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                let iCloudHandle = iCloudDataHandler()
                iCloudHandle.writeAScheduleRecord(eventIndex: index, status: status)
                NSUbiquitousKeyValueStore.default.synchronize()
            }
        } else {
            print("Skipping iCloud write for \(index) during restoration")
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
        // Reduced logging for performance
        
        let index = band + ":" + location + ":" + startTime + ":" + eventTypeValue + ":" + eventYearString
        
        // Reduced logging for performance
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
    
    func getShowAttendedStatus (band: String, location: String, startTime: String, eventType: String,eventYearString: String)->String{
        var eventTypeVariable = eventType;
        if (eventType == unofficalEventTypeOld){
            eventTypeVariable = unofficalEventType;
        }
        let index = band + ":" + location + ":" + startTime + ":" + eventTypeVariable + ":" + eventYearString
        let raw = getShowAttendedStatusRaw(index: index)
        var value = ""
        // Reduced logging for performance
        if (raw == sawAllStatus){
            value = sawAllStatus
        } else if (raw == sawSomeStatus){
            value = sawSomeStatus
        } else {
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
    
    // Helper to get the raw status (without timestamp)
    func getShowAttendedStatusRaw(index: String) -> String? {
        return showsAttendedQueue.sync {
            guard let value = self._showsAttendedArray[index] else { return nil }
            let parts = value.split(separator: ":")
            return parts.first.map { String($0) }
        }
    }
    
    // New: Get the last change timestamp for a show
    func getShowAttendedLastChange(index: String) -> Double {
        return showsAttendedQueue.sync {
            guard let value = self._showsAttendedArray[index] else { return 0 }
            let parts = value.split(separator: ":")
            if parts.count == 2, let ts = Double(parts[1]) { return ts }
            if parts.count == 3, let ts = Double(parts[2]) { return ts } // for iCloud format
            return 0
        }
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
    
    /**
     Forces migration of all attended data to ensure proper timestamp format.
     This method should be called when restoring data from iCloud to ensure consistency.
     */
    func forceMigrationOfAllAttendedData() {
        print("ShowsAttended: Starting forced migration of all attended data")
        let currentArray = showsAttendedQueue.sync { self._showsAttendedArray }
        var needsMigration = false
        let currentTimestamp = String(format: "%.0f", Date().timeIntervalSince1970)
        
        for (key, value) in currentArray {
            let parts = value.split(separator: ":")
            if parts.count == 1 {
                // Old format: just status -> add timestamp
                mutateShowsAttendedArray { arr in arr[key] = value + ":" + currentTimestamp }
                needsMigration = true
                print("ShowsAttended: Migrated \(key) from old format to \(value):\(currentTimestamp)")
            } else if parts.count == 3 {
                // iCloud format: status:uid:timestamp -> convert to local format: status:timestamp
                let status = String(parts[0])
                let timestamp = String(parts[2])
                let localFormat = status + ":" + timestamp
                mutateShowsAttendedArray { arr in arr[key] = localFormat }
                needsMigration = true
                print("ShowsAttended: Migrated \(key) from iCloud format to local format: \(localFormat)")
            }
        }
        
        if needsMigration {
            print("ShowsAttended: Forced migration completed, saving changes")
            saveShowsAttended()
            // Update the static cache with migrated data
            staticAttended.async(flags: .barrier) {
                for (key, value) in self.showsAttendedArray {
                    cacheVariables.attendedStaticCache[key] = value
                }
            }
        } else {
            print("ShowsAttended: No migration needed")
        }
    }
    
}


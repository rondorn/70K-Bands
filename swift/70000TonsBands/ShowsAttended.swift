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
    var showsAttendedArray = [String : String]();
    
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
                showsAttendedArray = cacheVariables.attendedStaticCache
            }
        }

        //iCloudHandle.readCloudAttendedData(attendedHandle: self);
    }
    
    /**
     Sets the showsAttendedArray to the provided attendedData.
     - Parameter attendedData: A dictionary of attended data to set.
     */
    func setShowsAttended(attendedData: [String : String]){
        showsAttendedArray = attendedData
    }
    
    /**
     Returns the current showsAttendedArray.
     - Returns: A dictionary of show attendance data.
     */
    func getShowsAttended()->[String : String]{
        return showsAttendedArray;
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
        
        //print ("Loading shows attended data 1")
        let bandNameHandle = bandNamesHandler()
        
        let allBands = bandNameHandle.getBandNames()
        let artistUrl = getScheduleUrl()

        var unuiqueSpecial = [String]()
        do {
            let data = try Data(contentsOf: showsAttended, options: [])
            //print ("Loading show attended data!! From json")
            showsAttendedArray = (try JSONSerialization.jsonObject(with: data, options: []) as? [String : String])!
            print ("Loaded show attended data!! From json \(showsAttendedArray)")
            if (showsAttendedArray.count > 0){
                for index in showsAttendedArray {
                    print ("Loaded show attended data!! From \(index.key) - \(index.value)")
                    showsAttendedArray[index.key] = index.value
                }
            }
            print ("Loading show attended data! cleanup event data loaded showData \(showsAttendedArray)")
            
            staticAttended.async(flags: .barrier) {
                for index in self.showsAttendedArray {

                    cacheVariables.attendedStaticCache[index.key] = index.value ?? ""
                }
            }
            
            //iCloudHandle.readCloudAttendedData(attendedHandle: self)
            
        } catch {
            print ("Loaded show attended data!! Error, unable to load showsAtteneded Data \(error.localizedDescription)")
        }
    
    }
    
    /**
     Adds or updates a show attended record with a specific status.
     - Parameters:
        - band: The band name.
        - location: The event location.
        - startTime: The event start time.
        - eventType: The type of event.
        - eventYearString: The event year as a string.
        - status: The attendance status to set.
     */
    func addShowsAttendedWithStatus (band: String, location: String, startTime: String, eventType: String, eventYearString: String, status: String){
        
        let index = band + ":" + location + ":" + startTime + ":" + eventType + ":" + eventYearString
            
        changeShowAttendedStatus(index: index, status: status)
        
        staticLastModifiedDate.async(flags: .barrier) {
            cacheVariables.lastModifiedDate = Date()
        }
        
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

        if (showsAttendedArray.count == 0){
            loadShowsAttended();
        }
        
        var eventTypeValue = eventType;
        if (eventType == unofficalEventTypeOld){
            eventTypeValue = unofficalEventType;
        }
        
        let index = band + ":" + location + ":" + startTime + ":" + eventTypeValue + ":" + eventYearString
        
        print ("Loading show attended data! addShowsAttended 1 addAttended data index = '\(index)'")
        var value = ""
        
        if (showsAttendedArray.isEmpty == true || showsAttendedArray[index] == nil ||
            showsAttendedArray[index] == sawNoneStatus){
            
            value = sawAllStatus
         
        } else if (showsAttendedArray[index] == sawAllStatus && eventType == showType ){
            value = sawSomeStatus
         
        } else if (showsAttendedArray[index] == sawSomeStatus){
            value = sawNoneStatus;
            
        } else {
            value = sawNoneStatus;
        }
        
        changeShowAttendedStatus(index: index, status: value)
        
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
        
        print ("Loading show attended data! addShowsAttended 2 Settings equals index = '\(index)' - \(status)")
        showsAttendedArray[index] = status
        
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
    
    func getShowAttendedStatus (band: String, location: String, startTime: String, eventType: String,eventYearString: String)->String{
        
        var eventTypeVariable = eventType;
        if (eventType == unofficalEventTypeOld){
            eventTypeVariable = unofficalEventType;
        }
        
        let index = band + ":" + location + ":" + startTime + ":" + eventTypeVariable + ":" + eventYearString
        
        var value = ""
        
        print ("Loading show attended data! getShowAttendedStatusCheck on show index = '\(index)' for status=\(showsAttendedArray[index] ?? "")")
        
        if (showsAttendedArray[index] == sawAllStatus){
            value = sawAllStatus
            
        } else if (showsAttendedArray[index] == sawSomeStatus){
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
    
}


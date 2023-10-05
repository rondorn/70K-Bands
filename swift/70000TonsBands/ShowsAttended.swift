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
    
    init(){
        print ("Loading shows attended data")
        getCachedData()
    }
    
    
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
    
    func setShowsAttended(attendedData: [String : String]){
        showsAttendedArray = attendedData
    }
    
    func getShowsAttended()->[String : String]{
        return showsAttendedArray;
    }
    
    func saveShowsAttended(){
        
        if (showsAttendedArray.count > 0){
            do {
                let json = try JSONEncoder().encode(showsAttendedArray)
                try json.write(to: showsAttended)
            
                print ("Loading show attended data! saved showData \(showsAttendedArray)")
            } catch {
                print ("Loading show attended data! Error, unable to save showsAtteneded Data \(error.localizedDescription)")
            }
        }
    }

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
    
    func addShowsAttendedWithStatus (band: String, location: String, startTime: String, eventType: String, eventYearString: String, status: String){
        
        let index = band + ":" + location + ":" + startTime + ":" + eventType + ":" + eventYearString
            
        changeShowAttendedStatus(index: index, status: status)
        
        staticLastModifiedDate.async(flags: .barrier) {
            cacheVariables.lastModifiedDate = Date()
        }
        
    }
    
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
    
}


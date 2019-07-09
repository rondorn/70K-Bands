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

    var showsAttendedArray = [String : String]();

    init(){
        print ("Loading shows attended data")
        getCachedData()
    }
    
    
    func getCachedData(){
        
        var staticCacheUsed = false
        
        staticAttended.sync() {
            if (cacheVariables.attendedStaticCache.isEmpty == false){
                staticCacheUsed = true
                showsAttendedArray = cacheVariables.attendedStaticCache
            }
        }
        
        if (staticCacheUsed == false){
            loadShowsAttended()
        }
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
            
                print ("saved showData \(showsAttendedArray)")
            } catch {
                print ("Error, unable to save showsAtteneded Data \(error.localizedDescription)")
            }
        }
    }

    func loadShowsAttended(){
        
        //print ("Loading shows attended data 1")
        let bandNameHandle = bandNamesHandler()
        
        let allBands = bandNameHandle.getBandNames()
        let artistUrl = defaults.string(forKey: "artistUrl")

        var unuiqueSpecial = [String]()
        do {
            let data = try Data(contentsOf: showsAttended, options: [])
            showsAttendedArray = (try JSONSerialization.jsonObject(with: data, options: []) as? [String : String])!
        
            if (showsAttendedArray.count > 0){
                for index in showsAttendedArray {
                    
                    let indexArray = index.key.split(separator: ":")
                    
                    let bandName = String(indexArray[0])
                    let eventType = String(indexArray[4])
                    
                    print ("cleanup event data old or new  \(indexArray.count)")
             
                    if (indexArray.count == 5 && artistUrl == "Default"){
                        print ("converting data for index \(index.key)")
                        var useEventYear = eventYear;
                        if (allBands.contains(bandName) == false){
                            print ("cleanup event data last years band \(bandName) and eventType is \(eventType) and \(unuiqueSpecial)")
                            useEventYear = useEventYear - 1
                            
                            if ((eventType == specialEventType || eventType == unofficalEventType) && unuiqueSpecial.contains(bandName) == false){
                                useEventYear = useEventYear + 1
                                unuiqueSpecial.append(bandName)
                            }
                            
                        }
                        
                        let newIndex = index.key + ":" + String(useEventYear)
                        
                        print ("cleanup event data chaning index from  \(index.key) to \(newIndex)")
                        showsAttendedArray[newIndex] = index.value;
                        
                        showsAttendedArray.removeValue(forKey: index.key)
                    }
 
                }
            }
            print ("cleanup event data loaded showData \(showsAttendedArray)")
            
            staticAttended.async(flags: .barrier) {
                for index in self.showsAttendedArray.keys {
                    print ("Adding attended data \(index) and \(self.showsAttendedArray[index]!)")
                    cacheVariables.attendedStaticCache[index] = self.showsAttendedArray[index]
                }
            }
            
        } catch {
            print ("Error, unable to load showsAtteneded Data \(error.localizedDescription)")
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
        
        print ("addShowsAttended 1 addAttended data index = '\(index)'")
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
        
        print ("addShowsAttended 2 Settings equals index = '\(index)' - \(value)")
        showsAttendedArray[index] = value
        
        staticAttended.async(flags: .barrier) {
            cacheVariables.attendedStaticCache = [String : String]()
        }
        saveShowsAttended()

        return value
    }
    
    func getShowAttendedIcon  (band: String, location: String, startTime: String, eventType: String,eventYearString: String)->UIImage{
        
        var iconName = String()
        var icon = UIImage()
        
        var eventTypeValue = eventType;
        if (eventType == unofficalEventTypeOld){
            eventTypeValue = unofficalEventType;
        }
        
        let value = getShowAttendedStatus(band: band,location: location,startTime: startTime,eventType: eventTypeValue,eventYearString: eventYearString);
        
        let index = band + ":" + location + ":" + startTime + ":" + eventTypeValue + ":" + eventYearString
        
        print ("getShowAttendedIcon 2 Settings equals showsAttendedArray '\(index)' - \(value)")
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
        
        print ("getShowAttendedStatusCheck on show index = '\(index)' for status=\(showsAttendedArray[index] ?? "")")
        
        if (showsAttendedArray[index] == sawAllStatus){
            value = sawAllStatus
            
        } else if (showsAttendedArray[index] == sawSomeStatus){
            value = sawSomeStatus
            
        } else {
            value = sawNoneStatus;
            
        }

        return value
    }
    
    func setShowsAttendedStatus(_ sender: UITextField, status: String)->String{
        
        var message : String
        var fieldText = sender.text;
    
        print ("getShowAttendedStatus (inset) = \(status) =\(fieldText ?? "")")
        if (status == sawAllStatus){
            sender.textColor = sawAllColor
            sender.text = fieldText
            message = NSLocalizedString("All Of Event", comment: "")
            
        } else if (status == sawSomeStatus){
            sender.textColor = sawSomeColor
            
            fieldText = removeIcons(text: fieldText!)
            sender.text = fieldText
            message = NSLocalizedString("Part Of Event", comment: "")
            
        } else {
            sender.textColor = sawNoneColor
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


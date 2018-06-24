//
//  ShowsAttended.swift
//  
//
//  Created by Ron Dorn on 6/10/18.
//
import Foundation
import UIKit
import CoreData

var showsAttendedArray: [String : String] = [String : String]();

open class ShowsAttended {
    
    init(){
        loadShowsAttended()
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
            
                //saveFileToiCloudDrive(localFile: showsAttended)
            
                print ("saved showData \(showsAttendedArray)")
            } catch {
                print ("Error, unable to save showsAtteneded Data \(error.localizedDescription)")
            }
        }
    }

    func loadShowsAttended(){
        
        do {
            //loadFileFromiCloudDrive(localFile: showsAttended)
            let data = try Data(contentsOf: showsAttended, options: [])
            showsAttendedArray = (try JSONSerialization.jsonObject(with: data, options: []) as? [String : String])!
            
             print ("loaded showData \(showsAttendedArray)")
        } catch {
            print ("Error, unable to load showsAtteneded Data \(error.localizedDescription)")
        }
    }
    
    func addShowsAttended (band: String, location: String, startTime: String, eventType: String)->String{
        
        if (showsAttendedArray.count == 0){
            loadShowsAttended();
        }
        
        let index = band + ":" + location + ":" + startTime + ":" + eventType
        
        print ("addAttended data index = \(index)")
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
        
        print ("Settings equals showsAttendedArray \(index) - \(value)")
        showsAttendedArray[index] = value
        
        saveShowsAttended();
        
        return value
    }
    
    func getShowAttendedIcon  (band: String, location: String, startTime: String, eventType: String)->String{
        
        var icon = ""
        
        let value = getShowAttendedStatus(band: band,location: location,startTime: startTime,eventType: eventType);
        
        if (value == sawAllStatus){
            icon = sawAllIcon
        
        } else if (value == sawSomeStatus){
            icon = sawSomeIcon

        } else if (value == sawNoneStatus){
            icon = sawNoneIcon
        }
        
        return icon
    }

    func getShowAttendedColor  (band: String, location: String, startTime: String, eventType: String)->UIColor{
        
        var color : UIColor = UIColor()
        
        let value = getShowAttendedStatus(band: band,location: location,startTime: startTime,eventType: eventType);
        
        if (value == sawAllStatus){
            color = sawAllColor
            
        } else if (value == sawSomeStatus){
           color = sawSomeColor
            
        } else if (value == sawNoneStatus){
            color = sawNoneColor
        }
        
        return color
    }
    
    func getShowAttendedStatus (band: String, location: String, startTime: String, eventType: String)->String{
        
        let index = band + ":" + location + ":" + startTime + ":" + eventType
        
        var value = ""
        
        if (showsAttendedArray[index] == sawAllStatus){
            value = sawAllStatus
            
        } else if (showsAttendedArray[index] == sawSomeStatus){
            value = sawSomeStatus
            
        } else {
            value = sawNoneStatus;
            
        }
        
        print ("getShowAttendedStatus for index \(index) returned \(value)")
        
        return value
    }
    
    func setShowsAttendedStatus(_ sender: UITextField, status: String)->String{
        
        var message : String
        var fieldText = sender.text;
        
        print ("getShowAttendedStatus (inset) = \(status) =\(fieldText)")
        if (status == sawAllStatus){
            sender.textColor = sawAllColor
            fieldText = sawAllIcon + fieldText!
            sender.text = fieldText
            message = "I saw all of this event!";
            
        } else if (status == sawSomeStatus){
            sender.textColor = sawSomeColor
            
            fieldText = removeIcons(text: fieldText!)
            fieldText = sawSomeIcon + fieldText!
            sender.text = fieldText
            message = "I saw some of this event!";
            
        } else {
            sender.textColor = sawNoneColor
            fieldText = removeIcons(text: fieldText!)
            sender.text = fieldText
            message = "I saw none of this event!";
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


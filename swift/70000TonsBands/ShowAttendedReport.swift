//
//  ShowAttendedReport.swift
//  70K Bands
//
//  Created by Ron Dorn on 6/12/18.
//  Copyright © 2018 Ron Dorn. All rights reserved.
//

import Foundation

class showAttendenceReport {
    
    var eventCounts :[String:[String:Int]] = [String:[String:Int]]()
    var bandCounts : [String : [String : [String : Int]]] = [String : [String : [String : Int]]]()
    
    func assembleReport (){
        
        let attended = ShowsAttended()
        
        let showsAttendedArray = attended.getShowsAttended();
        
        for index in showsAttendedArray {
            
            let indexArray = index.key.split(separator: ":")
            
            let bandName = String(indexArray[0])
            let eventType = String(indexArray[4])
            
            getEventTypeCounts(eventType: eventType, sawStatus: index.value)
            getBandCounts(eventType: eventType, bandName: bandName, sawStatus: index.value)
            
        }
    }
    
    func addPlural(count : Int)->String{
        
        var message = "";
        
        if (count >= 2){
            message += "s"
        }
        message += "\n"
        
        return message
    }
    
    func buildMessage()->String{
        
        var message = ""
        var eventCountExists : [String: Bool] = [String: Bool]();
        
        for index in eventCounts {
            
            let eventType = index.key

            let sawAllCount = index.value[sawAllStatus]
            let sawSomeCount = index.value[sawSomeStatus]

            if (sawAllCount != nil && sawAllCount! >= 1){
                eventCountExists[eventType] = true
                let sawAllCountString = String(sawAllCount!)
                message += "Saw " + sawAllCountString + " " + eventType + addPlural(count: sawAllCount!)
            }
            if (sawSomeCount != nil && sawSomeCount! >= 1){
                eventCountExists[eventType] = true
                let sawSomeCountString = String(sawSomeCount!)
                message += "Saw part of " + sawSomeCountString + " " + eventType + addPlural(count: sawSomeCount!)
            }
        }
        
        //bandCounts[eventType]![bandName]![sawStatus]!
        message += "\n"
        for index in bandCounts {
            let eventType = index.key
            var sawSomeCount = 0
            
            let sortedBandNames = Array(index.value.keys).sorted()
            
            if (eventCountExists[eventType] == true){
                message += "For " + eventType + "s\n"

                for bandName in sortedBandNames {

                    var sawCount = 0
                    if (bandCounts[index.key]![bandName]![sawAllStatus] != nil){
                        sawCount = sawCount + bandCounts[index.key]![bandName]![sawAllStatus]!
                    }
                    if (bandCounts[index.key]![bandName]![sawSomeStatus] != nil){
                        sawCount = sawCount + bandCounts[index.key]![bandName]![sawSomeStatus]!
                        sawSomeCount = sawSomeCount + bandCounts[index.key]![bandName]![sawSomeStatus]!
                        }
                        if (sawCount >= 1){
                            let sawCountString = String(sawCount)
                            if (eventType == showType){
                                message += "     " + bandName + " " + sawCountString + " time" + addPlural(count: sawCount)
                            } else {
                                message += "     " + bandName + "\n";
                            }
                        }
                    //}
                }
                if (sawSomeCount >= 1){
                    let sawSomeCountString = String(sawSomeCount)
                    message += "\n" + sawSomeCountString + " of those were partial shows"
                }
            }
 
        }
        
        print ("shows attended message = \(message)")
        
        return message
    }
    
    func getEventTypeCounts (eventType:String, sawStatus: String){
        
        if (eventCounts[eventType] == nil){
            eventCounts[eventType] = [String:Int]()
        }
        
        if (eventCounts[eventType]![sawStatus] == nil){
            eventCounts[eventType]![sawStatus] = 1;
        } else {
            eventCounts[eventType]![sawStatus] = eventCounts[eventType]![sawStatus]! + 1
        }
    }
    
    func getBandCounts (eventType:String, bandName:String, sawStatus: String){
        
        if (bandCounts[eventType] == nil){
            bandCounts[eventType] = [String : [String : Int]]();
        }
        if (bandCounts[eventType]![bandName] == nil){
            bandCounts[eventType]![bandName]  = [String : Int]();
        }
        if (bandCounts[eventType]![bandName]![sawStatus] == nil){
            bandCounts[eventType]![bandName]![sawStatus] = 1;
        } else {
            bandCounts[eventType]![bandName]![sawStatus] = bandCounts[eventType]![bandName]![sawStatus]! + 1
        }
    }
}

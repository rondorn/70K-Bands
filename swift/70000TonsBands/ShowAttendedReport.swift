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
    
    var schedule = scheduleHandler()
    
    var bandNamesHandle = bandNamesHandler()
    
    func assembleReport (){
        
        let attended = ShowsAttended()
        
        let showsAttendedArray = attended.getShowsAttended();
        var unuiqueSpecial = [String]()
        
        schedule.buildTimeSortedSchedulingData();
        if (schedule.getBandSortedSchedulingData().count > 0){
            for index in showsAttendedArray {
                
                let indexArray = index.key.split(separator: ":")
                
                let bandName = String(indexArray[0])
                let eventType = String(indexArray[4])
                let year = String(indexArray[5])
                
                if (year != String(eventYear)){
                    continue
                }
                
                getEventTypeCounts(eventType: eventType, sawStatus: index.value)
                getBandCounts(eventType: eventType, bandName: bandName, sawStatus: index.value)
                
            }
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
        
        var message = "These are the events I attended on the 70,000 Tons Of Metal Cruise\n"
        var eventCountExists : [String: Bool] = [String: Bool]();
        
        if (eventCounts.isEmpty == true){
            message = buildMustMightReport();
            
        } else {
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
                    }
                    if (sawSomeCount >= 1){
                        let sawSomeCountString = String(sawSomeCount)
                        if (sawSomeCount == 1){
                                message += sawSomeCountString + " of those was a partial show\n"
                        } else {
                            message += sawSomeCountString + " of those were partial shows\n"
                        }
                    }
                }
            }
        }
        
        message +=  "\nhttp://www.facebook.com/70kBands"
        
        print ("shows attended message = \(message)")
        
        return message
    }
    
    func buildMustMightReport()->String {
        
        var intro = getMustSeeIcon() + " These are the bands I MUST see on the 70,000 Tons Cruise\n"
        let bands = bandNamesHandle.getBandNames()
        for band in bands {
            if (getPriorityData(band) == 1){
                print ("Adding band " + band)
                intro += "\t\t" +  band + "\n"
            }
        }
        intro += "\n\n" + getMightSeeIcon() + " These are the bands I might see\n"
        for band in bands {
            if (getPriorityData(band) == 2){
                print ("Adding band " + band)
                intro += "\t\t" +  band + "\n"
            }
        }
         return intro
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

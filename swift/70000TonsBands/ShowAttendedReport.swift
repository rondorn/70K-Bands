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
    
    var schedule = scheduleHandler.shared
    var attendedHandle = ShowsAttended()
    
    var bandNamesHandle = bandNamesHandler.shared
    var dataHandle = dataHandler()
    
    var isReportEmpty = false
    var indexMap = [String]()
    
    /**
     Initializes a new instance of showAttendenceReport.
     */
    init(){

    }
    
    /**
     Returns whether the report is empty.
     - Returns: true if the report is empty, false otherwise.
     */
    func getIsReportEmpty()->Bool {
        return isReportEmpty
    }
    
    /**
     Assembles the attendance report by processing attended shows and events.
     */
    func assembleReport (){
        
        schedule.buildTimeSortedSchedulingData();
        
        let scheduleData = schedule.getBandSortedSchedulingData();
        let showsAttendedArray = attendedHandle.getShowsAttended();
        let allBands = bandNamesHandle.getBandNames()
        var unuiqueSpecial = [String]()
        
        var tempEventCount = 0
        
        if (schedule.getBandSortedSchedulingData().count > 0){
            for index in showsAttendedArray {
                
                //prevent duplicate events
                if (indexMap.contains(index.key)){
                    continue
                }
                indexMap.append(index.key)
                
                let indexArray = index.key.split(separator: ":")
                
                let bandName = String(indexArray[0])
                let location = String(indexArray[1])
                let hour = String(indexArray[2])
                let min = String(indexArray[3])
                let eventType = String(indexArray[4])
                let year = String(indexArray[5])
                let status = String(showsAttendedArray[index.key]!)
                
                if (year != String(eventYear)){
                    continue
                }
                if (status == "sawNone"){
                    continue
                }
                
                if (bandName == "Vio-Lence"){
                    print ("Violence data is \(location) - \(hour) - \(min) - \(eventType) - \(year) - \(status)")
                }
                var validateEvent = false
                if scheduleData.index(forKey: bandName) != nil {
                    for timeIndex in scheduleData[bandName]!.keys {
                        print ("scheduleData[bandName] \(scheduleData[bandName]?[timeIndex])")
                        if (scheduleData[bandName]?[timeIndex]?["Location"] == location &&
                            scheduleData[bandName]?[timeIndex]?["Type"] == eventType &&
                            scheduleData[bandName]?[timeIndex]?["Start Time"] == hour + ":" + min){
                            validateEvent = true;
                            continue
                        }
                        
                    }
                }
                
                if (validateEvent == false){
                    continue
                }
                
                if (allBands.contains(bandName) == false &&
                    eventType != unofficalEventType &&
                    eventType != karaokeEventType &&
                    eventType != specialEventType &&
                    eventType != unofficalEventTypeOld){

                    continue
                }
                tempEventCount = tempEventCount + 1
                print ("tempEventCount is \(tempEventCount) - \(year) - \(bandName) - \(location) = \(status)")
                
                print ("eventType = \(eventType) - \(index.value) - \(indexArray)")
                getEventTypeCounts(eventType: eventType, sawStatus: index.value)
                getBandCounts(eventType: eventType, bandName: bandName, sawStatus: index.value)
                
            }
        } else {
            isReportEmpty = true
        }
        if (tempEventCount == 0){
            isReportEmpty = true
        }

    }
    
    /**
     Adds a plural 's' to the event type if the count is 2 or more (except for unofficial events).
     - Parameters:
        - count: The number of events.
        - eventType: The type of event.
     - Returns: A string with the appropriate pluralization.
     */
    func addPlural(count : Int, eventType: String)->String{
        
        var message = "";
        
        if (count >= 2 && eventType != unofficalEventType){
            message += "s"
        }
        message += "\n"
        
        return message
    }
        
    /**
     Builds a report message for the specified type.
     - Parameter type: The type of report to build (e.g., "MustMight", "Events").
     - Returns: The formatted report message as a string.
     */
    func buildMessage(type: String)->String{
        
        var message = ""
        
        if (type == "MustMight"){
            message = buildMustMightReport();
            
        } else if (type == "Events"){
            message = "These are the events I attended on the 70,000 Tons Of Metal Cruise\n"
            var eventCountExists : [String: Bool] = [String: Bool]();
            
            assembleReport()
            
            for index in eventCounts {
                
                let eventType = index.key

                let sawAllCount = index.value[sawAllStatus]
                let sawSomeCount = index.value[sawSomeStatus]

                if (sawAllCount != nil && sawAllCount! >= 1){
                    eventCountExists[eventType] = true
                    let sawAllCountString = String(sawAllCount!)
                    message += "Saw " + sawAllCountString + " " + eventType + addPlural(count: sawAllCount!, eventType: eventType)
                }
                if (sawSomeCount != nil && sawSomeCount! >= 1){
                    eventCountExists[eventType] = true
                    let sawSomeCountString = String(sawSomeCount!)
                    message += "Saw part of " + sawSomeCountString + " " + eventType + addPlural(count: sawSomeCount!, eventType: eventType)
                }
            }
            
            message += "\n"
            for index in bandCounts {
                let eventType = index.key
                var sawSomeCount = 0
                
                let sortedBandNames = Array(index.value.keys).sorted()
                
                if (eventCountExists[eventType] == true){
                    message += "For " + eventType + addPlural(count: 1, eventType: eventType)
                    
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
                                message += "     " + bandName + " " + sawCountString + " time" + addPlural(count: sawCount, eventType: eventType)
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
    
    /**
     Builds a report message for the 'MustMight' type, listing must-see and might-see bands.
     - Returns: The formatted must/might report as a string.
     */
    func buildMustMightReport()->String {
        
        var intro = "These are the bands I MUST see on the 70,000 Tons Cruise\n"
        let bands = bandNamesHandle.getBandNames()
        for band in bands {
            if (dataHandle.getPriorityData(band) == 1){
                print ("Adding band " + band)
                intro += "\t\t" +  band + "\n"
            }
        }
        intro += "\n\n" + "These are the bands I might see\n"
        for band in bands {
            if (dataHandle.getPriorityData(band) == 2){
                print ("Adding band " + band)
                intro += "\t\t" +  band + "\n"
            }
        }
         return intro
    }
    
    /**
     Updates the eventCounts dictionary with the count of events by type and attendance status.
     - Parameters:
        - eventType: The type of event.
        - sawStatus: The attendance status for the event.
     */
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
    
    /**
     Updates the bandCounts dictionary with the count of bands by event type and attendance status.
     - Parameters:
        - eventType: The type of event.
        - bandName: The name of the band.
        - sawStatus: The attendance status for the band.
     */
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

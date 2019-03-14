//
//  showsAttendedWrite.swift
//  70K Bands
//
//  Created by Ron Dorn on 3/14/19.
//  Copyright © 2019 Ron Dorn. All rights reserved.
//

import Foundation
import UIKit

class showsAttendedWrite {

    func writShowAttended (){
    
        let uid = (UIDevice.current.identifierForVendor?.uuidString)!
        let attended = ShowsAttended()
        let showsAttendedArray = attended.getShowsAttended();
        let allBands = getBandNames()
        var showPayload:[String:String] = [String:String]()
        
        schedule.buildTimeSortedSchedulingData();
        if (schedule.getBandSortedSchedulingData().count > 0){
            for index in showsAttendedArray {
                
                //band + ":" + location + ":" + startTime + ":" + eventTypeValue
                let indexArray = index.key.split(separator: ":")
                
                let bandName = String(indexArray[0])
                let location = String(indexArray[1])
                let startTimeHour = String(indexArray[2])
                let startTimeMin = String(indexArray[3])
                let eventType = String(indexArray[4])
                let status = index.value
                
                if (allBands.contains(bandName) == true){
                    print("showAttended data band \(bandName)")
                    print("showAttended data location \(location)")
                    print("showAttended data startTimeHour \(startTimeHour)")
                    print("showAttended data startTimeMin \(startTimeMin)")
                    print("showAttended data eventType \(eventType)")
                    print("showAttended data status \(status)")
                    
                    let time = startTimeHour + ":" + startTimeMin
                    let externalID = uid + "-" + bandName + "-" + time + "-" + location;
                    let bandJson = getShowJSON(bandName: bandName, location: location, time: time, eventType:eventType, status:status);
                    
                    
                    showPayload[externalID] = bandJson;
                }
            }
            
            let bulkWrite = salesforceBulkCalls();
            let csvData = bulkWrite.createCSVText(dataArray:showPayload);
            bulkWrite.processBatchJob(object: "showsAttended__c",externalID: "externalID__c",operation: "upsert", data: csvData);
            
        
        }
    }
    
    func getShowJSON(bandName:String, location:String, time:String, eventType:String, status: String)->String{
        
        let uid = (UIDevice.current.identifierForVendor?.uuidString)!
        let bandChoice = uid + "-" + bandName
        
        var jsonString = "{\"RelatedBandChoicesID__c\" : \"" + bandChoice + "\"";
        jsonString += ",\"attendedStatus__c\" : \"" + status + "\"";
        jsonString += ",\"eventType__c\" : \"" + eventType + "\"";
        jsonString += ",\"relatedUserID__c\" :\"" + uid + "\"";
        jsonString += ",\"Venue__c\" :\"" + location + "\"";
        
        jsonString += "}"
        
        return jsonString
    }
}

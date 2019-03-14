//
//  bandRankingWrite.swift
//  70K Bands
//
//  Created by Ron Dorn on 3/12/19.
//  Copyright © 2019 Ron Dorn. All rights reserved.
//

import Foundation
import UIKit

class bandRankingWrite {
    
    func writeBandData(){
        
        let allBands = getBandNames()
        let uid = (UIDevice.current.identifierForVendor?.uuidString)!
        
        var bandPayload:[String:String] = [String:String]()
        
        let bulkWrite = salesforceBulkCalls();
        //let sfHandler = salesforceRestCalls()
        for bandName in allBands {
            let externalID = uid + "-" + bandName;
            let bandJson = getBandJSON(bandName: bandName, ranking: String(getPriorityData(bandName)), year: "2019");
            
            //print ("csvData is adding data " + bandJson + " to " + externalID);
            bandPayload[externalID] = bandJson;
            //sfHandler.upsert(recordID:externalID, object: "bandChoices__c", data: bandJson)
        }
        
        let csvData = bulkWrite.createCSVText(dataArray:bandPayload);
        bulkWrite.processBatchJob(object: "bandChoices__c",externalID: "externalID__c",operation: "upsert", data: csvData);
        
        print ("csvData is finished " + csvData);
    }
    
    func getBandJSON(bandName:String, ranking:String, year:String)->String{
        
        let uid = (UIDevice.current.identifierForVendor?.uuidString)!

        var jsonString = "{\"Band_Name__c\" : \"" + bandName + "\"";
        jsonString += ",\"ranking__c\" : \"" + resolvePriorityNumber(priority: ranking) + "\"";
        jsonString += ",\"userID__c\" : \"" + uid + "\"";
        jsonString += ",\"Year__c\" :\"" + year + "\"";
        
        jsonString += "}"
        
        return jsonString
    }
}

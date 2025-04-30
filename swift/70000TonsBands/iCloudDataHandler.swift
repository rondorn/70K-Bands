//
//  iCloudDataHandler.swift
//  70K Bands
//
//  Created by Ron Dorn on 7/6/19.
//  Copyright © 2019 Ron Dorn. All rights reserved.
//

import Foundation
import UIKit

let uidString = UIDevice.current.identifierForVendor!.uuidString;

class iCloudDataHandler {
    
    init(){
        
    }
    
    func checkForIcloud()->Bool {
        
        var status = false
        UserDefaults.standard.synchronize()
        var iCloudIndicator = UserDefaults.standard.string(forKey: "iCloud")
        iCloudIndicator = iCloudIndicator?.uppercased()
        if (iCloudIndicator == "YES" || iCloudIndicator == "YES "){
            status = true
        }
        
        print ("iCloud status is \(status)")
        return status
    }
    
    func writeAllPriorityData(){
        
        if (internetAvailble == true && checkForIcloud() == true){
            let priorityHandler = dataHandler()
            priorityHandler.refreshData()
            let priorityData = priorityHandler.getPriorityData()
            
            if (priorityData != nil && priorityData.count > 0){
                for (bandName, priority) in priorityData {
                    writeAPriorityRecord(bandName: bandName, priority: priority)
                }
                NSUbiquitousKeyValueStore.default.synchronize()
                writeLastiCloudDataWrite()
            }
        }
    }
    
    func writeAPriorityRecord(bandName: String, priority: Int){
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            var dataString = String(priority) + ":" + String(Date().timeIntervalSince1970)
            print ("iCloud: writeAPriorityRecord \(bandName) - \(dataString)")
            NSUbiquitousKeyValueStore.default.set(dataString, forKey: "bandName:" + bandName)
        }
    }
    

    func writeAllScheduleData(){
        print ("iCloud: writeAScheduleRecord writeAll ScheduleRecord  1 = START")
        if (checkForIcloud() == true){
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                let attendedHandle = ShowsAttended()
                attendedHandle.loadShowsAttended()
                let showsAttendedArray = attendedHandle.getShowsAttended();
                
                let uid = (UIDevice.current.identifierForVendor?.uuidString) ?? ""
                print ("iCloud: writeAScheduleRecord writeAll ScheduleRecord 2 = \(uid)")
                if (uid.isEmpty == false){
                    print ("iCloud: writeAScheduleRecord writeAll ScheduleRecord 3")
                    if (showsAttendedArray != nil && showsAttendedArray.isEmpty == false){
                        for eventIndex in showsAttendedArray {
                            self.writeAScheduleRecord(eventIndex: eventIndex.key, status: eventIndex.value)
                        }
                        NSUbiquitousKeyValueStore.default.synchronize()
                        self.writeLastiCloudDataWrite()
                    }
                }
            }
        }
    }
    
    func writeAScheduleRecord(eventIndex: String, status: String){
        
        var dataString = status + ":" + UIDevice.current.identifierForVendor!.uuidString
        print ("iCloud: writeAScheduleRecord Storing eventNamex:\(eventIndex) - \(dataString)")
        NSUbiquitousKeyValueStore.default.set(dataString, forKey: "eventName:" + eventIndex)
        writeLastiCloudDataWrite()
    
    }
    
    func readAllPriorityData(){
        print ("iCloud: readAllPriorityData called")
        if ( iCloudDataisLoading == false){
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                iCloudDataisLoading = true;
                let bandNameHandle = bandNamesHandler()
                let bandNames = bandNameHandle.getBandNames()
                
                let priorityHandler = dataHandler()
                priorityHandler.refreshData()
                
                for bandName in bandNames{
                    self.readAPriorityRecord(bandName: bandName, priorityHandler: priorityHandler)
                }
                iCloudDataisLoading = false;
            }
        }
    }
    
    func readAPriorityRecord(bandName: String, priorityHandler: dataHandler){
        
        print ("iCloud: readAPriorityRecord trying to read \(bandName)")
        let index = "bandName:" + bandName
        let tempValue = String(NSUbiquitousKeyValueStore.default.string(forKey: index) ?? "0")
        let currentUid = UIDevice.current.identifierForVendor!.uuidString
        if (tempValue != nil && tempValue.isEmpty == false){
            let tempData = tempValue.split(separator: ":")
            if (tempData.isEmpty == false && tempData.count == 2){
                let newPriority = tempData[0]
                let uidValue = tempData[1]
                let currentPriroity = priorityHandler.getPriorityData(bandName)
                print ("iCloud: before readAPriorityRecord adding \(bandName) - \(newPriority) - \(uidValue) - \(currentUid)")
                if (uidValue != currentUid || currentPriroity == 0){
                    var lastPriorityDataWrite = priorityHandler.readLastPriorityDataWrite()
                    var lastiCloudDataWrite = readLastiCloudDataWrite()
                    
                    if (lastiCloudDataWrite > lastPriorityDataWrite){
                        print ("iCloud: after readAPriorityRecord adding \(bandName) - \(newPriority) - \(uidValue) - \(currentUid)")
                        priorityHandler.addPriorityData(bandName, priority: Int(newPriority) ?? 0)
                    }
                }
            }
        }
    }
    
    func readAllScheduleData(){

        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            
            let scheduleHandle = scheduleHandler()
            scheduleHandle.buildTimeSortedSchedulingData();
            
            let bandNameHandle = bandNamesHandler()
            let bandNames = bandNameHandle.getBandNames()
            
            let attendedHandle = ShowsAttended()
            attendedHandle.loadShowsAttended()
            
            let priorityHandler = dataHandler()
            priorityHandler.refreshData()
            
            let scheduleData = scheduleHandle.getBandSortedSchedulingData()

            if (scheduleData.count > 0){
                for bandName in scheduleData.keys {
                    if (scheduleData.isEmpty == false){
                        for timeIndex in scheduleData[bandName]!.keys {
                            if scheduleData[bandName] != nil {
                                if (scheduleData[bandName]![timeIndex] != nil){
                                    if (scheduleData[bandName]![timeIndex]![locationField] != nil){
                                        let location = scheduleData[bandName]![timeIndex]![locationField]!
                                        let startTime = scheduleData[bandName]![timeIndex]![startTimeField]!
                                        let eventType = scheduleData[bandName]![timeIndex]![typeField]!
                                        
                                        self.readAScheduleRecord(bandName: bandName,location: location,startTime: startTime,eventType: eventType, attendedHandle: attendedHandle, bandNames: bandNames)
                                    }
                                }
                            }
                        }
                    }
                    if (bandNames.contains(bandName) == false){
                        self.readAPriorityRecord(bandName: bandName, priorityHandler: priorityHandler)
                    }
                }
            }
        }
    }
    
    func readAScheduleRecord(bandName: String,
                             location: String,
                             startTime: String,
                             eventType:String,
                             attendedHandle: ShowsAttended,
                             bandNames: [String]){
        
        let eventYearString = String(eventYear)
        
        print ("iCloud: readAScheduleRecord 1 trying to read \(bandName)-\(startTime)")
        var eventIndex = "eventName:" + bandName + ":"
        eventIndex = eventIndex + location + ":"
        eventIndex = eventIndex + startTime + ":"
        eventIndex = eventIndex + eventType + ":"
        eventIndex = eventIndex + eventYearString
        
        

        let tempValue = String(NSUbiquitousKeyValueStore.default.string(forKey: eventIndex) ?? "0")
        let currentUid = UIDevice.current.identifierForVendor!.uuidString
        print ("iCloud: readAScheduleRecord 2 trying to read \(tempValue)-\(eventIndex)")
        if (tempValue != nil && tempValue.isEmpty == false && eventIndex != "0"){
            let tempData = tempValue.split(separator: ":")
            if (tempData.isEmpty == false && tempData.count == 2){
                let newAttended = String(tempData[0])
                let uidValue = tempData[1]
                print ("iCloud: readAScheduleRecord 4 trying to read \(newAttended)-\(uidValue)")
                let currentAttended = attendedHandle.getShowAttendedStatusUserFriendly(band: bandName, location: location, startTime: startTime, eventType: eventType, eventYearString: eventYearString)
                
                print ("iCloud: before readAPriorityRecord adding \(bandName) - \(newAttended) - \(uidValue) - \(currentAttended)")
                if (uidValue != currentUid || currentAttended == nil){
                    var lastScheduleDataWrite = attendedHandle.readLastScheduleDataWrite()
                    var lastiCloudDataWrite = readLastiCloudDataWrite()
                    
                    if (lastiCloudDataWrite >= lastScheduleDataWrite){
                        print ("iCloud data not read due to out of date data = false")
                        print ("iCloud: after readAPriorityRecord adding \(bandName) - \(newAttended) - \(uidValue) - \(currentUid)")
                        attendedHandle.addShowsAttendedWithStatus(band: bandName, location: location, startTime: startTime, eventType: eventType, eventYearString: eventYearString, status: newAttended)
                    } else {
                        print ("iCloud data not read due to out of date data = true")
                    }
                }
            }
        }
    }
    
    func readLastiCloudDataWrite()-> Double{
        
        var lastiCloudDataWrite = Double(0)
        
        if let data = try? String(contentsOf: lastiCloudDataWriteFile, encoding: String.Encoding.utf8) {
            if (data != nil){
                lastiCloudDataWrite = Double(data) ?? 0
            }
        }
        
        return lastiCloudDataWrite
    }
    
    func writeLastiCloudDataWrite(){
        
        let currentTime = String(Date().timeIntervalSince1970)
        
        if (isInternetAvailable() == true){
            do {
                //try FileManager.default.removeItem(at: storageFile)
                try currentTime.write(to:lastiCloudDataWriteFile, atomically: false, encoding: String.Encoding.utf8)
                print ("writing iCloudData Date")
            } catch _ {
                print ("writing iCloudData Date, failed")
            }
        }
    }

}

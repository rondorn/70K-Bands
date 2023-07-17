//
//  iCloudDataHandler.swift
//  70K Bands
//
//  Created by Ron Dorn on 7/6/19.
//  Copyright © 2019 Ron Dorn. All rights reserved.
//

import Foundation


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
    
    func readCloudData (dataHandle: dataHandler){
        
        if (checkForIcloud() == false){
            return
        }
                    
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            let attendedHandle = ShowsAttended()
            
            self.readCloudAPriorityData(dataHandle: dataHandle)
            self.readCloudAttendedData(attendedHandle: attendedHandle)
        }
        
    }
    
    func writeiCloudAttendedData (attendedHandle: ShowsAttended){
        
        if (checkForIcloud() == false){
            return
        }
        
        if (internetAvailble == true){
            DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
                let showsAttendedData = attendedHandle.getShowsAttended()
                var dataString: String = ""
                
                var counter = 0;
                
                for (index, attended) in showsAttendedData {
                    dataString = dataString + index + "!" + attended + ";"
                    print ("Adding icloud \(index) ATTENDED write '\(attended)'")
                    counter += 1
                }
                
                if (counter >= 1){
                    print ("iCloud writing attended data \(dataString)")
                    NSUbiquitousKeyValueStore.default.set(dataString, forKey: "attendedData")
                    NSUbiquitousKeyValueStore.default.synchronize()
                }
            }
        }
    }
    
    func readCloudAttendedData (attendedHandle: ShowsAttended){
        
        if (checkForIcloud() == false){
            return
        }
        
        if (internetAvailble == true){
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                print ("reading iCloudAttended Data")
                let showsAttendedData = attendedHandle.getShowsAttended()
                NSUbiquitousKeyValueStore.default.synchronize()
                var valueTemp = String(NSUbiquitousKeyValueStore.default.string(forKey: "attendedData") ?? "")
                
                if valueTemp.isEmpty == true {
                    self.writeiCloudAttendedData(attendedHandle: attendedHandle)
                    valueTemp = String(NSUbiquitousKeyValueStore.default.string(forKey: "attendedData") ?? "")
                }
                
                //if we have no data, lets bail
                if valueTemp.isEmpty == true {
                    return
                }
                
                print ("Value pairs are \(valueTemp)")
                let splitOutput = valueTemp.components(separatedBy: ";")
                for record in splitOutput {
                    if (record.isEmpty == false){
                        print ("Reading from iCloud \(record)")
                        var varValue = record.components(separatedBy: "!");
                        var index = varValue[0];
                        var status = varValue[1];
                        if (index == "attended"){
                            index = varValue[1]
                            status = varValue[2]
                        }
                        
                        print ("Exiting is for \(index) is \(showsAttendedData[index]) new is \(status)")
                        
                        if showsAttendedData[index] != status {
                            attendedHandle.changeShowAttendedStatus(index: index, status: status)
                        }
                    }
                }
            }
        }
    }

    func writeiCloudPriorityData (bandPriorityStorage: [String:Int]){
        
        if (checkForIcloud() == false){
            return
        }
        
        if (internetAvailble == true){
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                var dataString: String = ""
                
                var counter = 0;
                
                for (band, priority) in bandPriorityStorage {
                    dataString = dataString + band + "!" + String(priority) + ";"
                    print ("Adding icloud \(band) write '\(priority)'")
                    counter += 1
                }
                
                print ("iCloud priority write counter is \(counter)")
                if (counter >= 1){
                    print ("iCloud writing attended data \(dataString)")
                    NSUbiquitousKeyValueStore.default.set(dataString, forKey: "bandPriorities")
                    NSUbiquitousKeyValueStore.default.synchronize()
                }
            }
        }
    }
    
    func readCloudAPriorityData (dataHandle: dataHandler){
        
        if (checkForIcloud() == false){
            return
        }
        
        if (internetAvailble == true){
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                //do a short sleep to ensure that any write has a chance to happen and avoid a race condition
                sleep(2)
                print ("reading iCloudPriority Data")
                let priorityData = dataHandle.getPriorityData()
                
                NSUbiquitousKeyValueStore.default.synchronize()
                var valueTemp = String(NSUbiquitousKeyValueStore.default.string(forKey: "bandPriorities") ?? "")
                
                if valueTemp.isEmpty == true {
                    self.writeiCloudPriorityData(bandPriorityStorage: dataHandle.getPriorityData())
                    valueTemp = String(NSUbiquitousKeyValueStore.default.string(forKey: "bandPriorities") ?? "")
                }
                
                //if we have no data, lets bail
                if valueTemp.isEmpty == true {
                    return
                }
                
                print ("Value pairs are \(valueTemp)")
                let splitOutput = valueTemp.components(separatedBy: ";")
                for record in splitOutput {
                    if (record.isEmpty == false){
                        print ("Reading from iCloud \(record)")
                        var varValue = record.components(separatedBy: "!");
                        var index = varValue[0];
                        var status = varValue[1];
                        if (index == "attended"){
                            index = varValue[1]
                            status = varValue[2]
                        }
                        print ("Exiting is for \(index) is \(priorityData[index]) new is \(status)")
                        if priorityData[index] != Int(status) {
                            dataHandle.addPriorityData(index,priority: Int(status) ?? 0)
                        }
                    }
                }
            }
        }
    }
}

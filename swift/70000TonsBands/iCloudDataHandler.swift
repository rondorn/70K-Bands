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
    
    
    func readCloudData (){
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            let dataHandle = dataHandler();
            let attendedHandle = ShowsAttended()
            
            self.readCloudAPriorityData(dataHandle: dataHandle)
            self.readCloudAttendedData(attendedHandle: attendedHandle)
        }
        
    }
    
    func writeiCloudAttendedData (attendedHandle: ShowsAttended){
        
        if (internetAvailble == true){
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
    
    func readCloudAttendedData (attendedHandle: ShowsAttended){
        
        if (internetAvailble == true){
            
            print ("reading iCloudAttended Data")
            let showsAttendedData = attendedHandle.getShowsAttended()
            NSUbiquitousKeyValueStore.default.synchronize()
            var valueTemp = String(NSUbiquitousKeyValueStore.default.string(forKey: "attendedData") ?? "")
            
            if valueTemp.isEmpty == true {
                writeiCloudAttendedData(attendedHandle: attendedHandle)
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

    func writeiCloudPriorityData (dataHandle: dataHandler){
        
        if (internetAvailble == true){
            let priorityData = dataHandle.getPriorityData()
            var dataString: String = ""
            
            var counter = 0;
            
            for (band, priority) in priorityData {
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
    
    func readCloudAPriorityData (dataHandle: dataHandler){
        
        if (internetAvailble == true){
            
            print ("reading iCloudPriority Data")
            let priorityData = dataHandle.getPriorityData()
            
            NSUbiquitousKeyValueStore.default.synchronize()
            var valueTemp = String(NSUbiquitousKeyValueStore.default.string(forKey: "bandPriorities") ?? "")
            
            if valueTemp.isEmpty == true {
                writeiCloudPriorityData(dataHandle: dataHandle)
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

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
    
    func readCloudData (dataHandle: dataHandler, sleepToCatchUp: Bool){
        
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
        //sleep(11);
        if (checkForIcloud() == false || iCloudDataisLoading == true){
            return
        }
        
        if (internetAvailble == true){
            DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
                iCloudDataisSaving = true
                let showsAttendedData = attendedHandle.getShowsAttended()
                var dataString: String = ""
                
                var counter = 0;
                if showsAttendedData != nil || showsAttendedData.isEmpty == false{
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
                iCloudDataisSaving = false
            }
        }
    }
    
    func readCloudAttendedData (attendedHandle: ShowsAttended){
        
        if (checkForIcloud() == false || iCloudDataisSaving == true){
            return
        }
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            iCloudDataisLoading = true
            sleep(2)
            
            print ("iCloud: reading iCloudAttended Data")
            let showsAttendedData = attendedHandle.getShowsAttended()
            print ("iCloud: showsAttendedData is \(showsAttendedData)")
            NSUbiquitousKeyValueStore.default.synchronize()
            var valueTemp = String(NSUbiquitousKeyValueStore.default.string(forKey: "attendedData") ?? "")
            
            if valueTemp.isEmpty == true {
                self.writeiCloudAttendedData(attendedHandle: attendedHandle)
                valueTemp = String(NSUbiquitousKeyValueStore.default.string(forKey: "attendedData") ?? "")
            }
            
            //if we have no data, lets bail
            if valueTemp.isEmpty == true {
                return
                iCloudDataisLoading = false
            }
            
            print ("Value pairs are \(valueTemp)")
            let splitOutput = valueTemp.components(separatedBy: ";")
            for record in splitOutput {
                if (record.isEmpty == false){
                    print ("iCloud: Reading from iCloud \(record)")
                    var varValue = record.components(separatedBy: "!");
                    var index = varValue[0];
                    var status = varValue[1];
                    if (index == "attended"){
                        index = varValue[1]
                        status = varValue[2]
                    }
                    
                    print ("iCloud: Exiting is for \(index) is \(showsAttendedData[index]) new is \(status)")
                    if status.isEmpty == true {
                        status = "Unknown"
                    }
                    //if showsAttendedData.keys.contains(index) == true {
                        //if showsAttendedData[index] != status {
                            print ("iCloud: Adding status of \(status) to \(index)")
                            attendedHandle.changeShowAttendedStatus(index: index, status: status)
                        //}
                    //}
                }
            }
        }
        iCloudDataisLoading = false
    }

    func writeiCloudPriorityData (bandPriorityStorage: [String:Int]){
        if (checkForIcloud() == false || iCloudDataisLoading == true){
            print ("Not Adding icloud \(iCloudDataisLoading) - \(checkForIcloud())")
            return
        }
        
        if (internetAvailble == true){
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                iCloudDataisSaving = true
                var dataString: String = ""
                
                var counter = 0;
                if (bandPriorityStorage.isEmpty == false){
                    for (band, priority) in bandPriorityStorage {
                        print ("iCloud adding data  \(band)!\(priority)")
                        dataString = dataString + band + "!" + String(priority) + ";"
                        print ("Adding icloud \(band) write '\(priority)'")
                        counter += 1
                    }
                    
                    print ("iCloud priority write counter is \(counter)")
                    if (counter >= 1){
                        print ("iCloud writing Priority data \(dataString)")
                        NSUbiquitousKeyValueStore.default.set(dataString, forKey: "bandPriorities")
                        NSUbiquitousKeyValueStore.default.synchronize()
                    }
                }
                iCloudDataisSaving = false
            }
        }
    }
    
    func readCloudAPriorityData (dataHandle: dataHandler){
        
        if (checkForIcloud() == false || iCloudDataisSaving == true){
            return
        }
        
        if (internetAvailble == true){
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                iCloudDataisLoading = true;
                sleep(2)
                
                //do a short sleep to ensure that any write has a chance to happen and avoid a race condition
                //sleep(10)
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
                    iCloudDataisLoading = false
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
                iCloudDataisLoading = false
            }
        }
    }
}

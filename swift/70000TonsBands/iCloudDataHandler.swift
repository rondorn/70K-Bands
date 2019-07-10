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
    
    func writeiCloudData (dataHandle: dataHandler, attendedHandle: ShowsAttended){
        
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            var templastModifiedDate = Date()
            var dataString: String = ""
            
            var counter = 0;
            
            sleep(1)

            let bandPriorityStorage = dataHandle.getPriorityData()
            
            for (band, priority) in bandPriorityStorage {
                dataString = dataString + PRIORITY + "!" + band + "!" + String(priority) + ";"
                print ("Adding icloud PRIORITIES write \(band) - \(priority)")
                counter += 1
            }
        
            if (counter == 0){
                return;
            }
            
            let showsAttendedData = attendedHandle.getShowsAttended()
            
             for (index, attended) in showsAttendedData {
                dataString = dataString + ATTENDED + "!" + index + "!" + attended + ";"
                print ("Adding icloud ATTENDED write \(index) - '\(attended)'")
                counter += 1
             }
            
            
            if (cacheVariables.lastModifiedDate != nil){
            
                staticLastModifiedDate.sync() {
                    templastModifiedDate = cacheVariables.lastModifiedDate!
                }
                
                if (counter > 2){
                    print ("iCloud writing priority data")
                    NSUbiquitousKeyValueStore.default.set(dataString, forKey: "bandPriorities")
                    NSUbiquitousKeyValueStore.default.set(templastModifiedDate, forKey: "lastModifiedDate")
                    
                    NSUbiquitousKeyValueStore.default.synchronize()
                }
            }
        }
    }
    
    func readiCloudData(dataHandle: dataHandler, attendedHandle: ShowsAttended){
        
        let winner = compareLastModifiedDate()
        print ("Winner is " + winner)
        
        if (winner == "iCloud"){
            NSUbiquitousKeyValueStore.default.synchronize()
            
            print ("iCloud getting priority data from the cloud")
            
            let values = NSUbiquitousKeyValueStore.default.dictionaryRepresentation
            
            print ("iCloud - " + String(describing: values))
            let bandPriorityStorage = dataHandle.getPriorityData()
            let showsAttendedData = attendedHandle.getShowsAttended()
            
            if values["bandPriorities"] != nil {
                let dataString = String(NSUbiquitousKeyValueStore.default.string(forKey: "bandPriorities")!)
                let split1 = dataString.components(separatedBy: ";")
                
                for record in split1 {
                    var split2 = record.components(separatedBy: "!")
                    print ("Number of variable is \(split2.count)")
                    if (split2.count == 3){
                        if (split2[0] == PRIORITY){
                            let bandname = split2[1]
                            let priority = Int(split2[2])
                            
                            print("Cloud compare \(bandname) does \(bandPriorityStorage[bandname]) = \(priority)")
                            
                            if (bandPriorityStorage[bandname] != priority){
                                print ("iCloud changing value for \(bandname) to \(String(describing: priority))")
                                dataHandle.addPriorityData(bandname, priority: priority!)
                            }

                            print ("reading icloud PRIORITIES \(split2[1]) - \(split2[2])")
                        
                            
                        } else if (split2[0] == ATTENDED){
                            
                            let index = split2[1]
                            let status = split2[2]
                            print("Cloud compare \(index) does \(showsAttendedData[index]) = \(status)")
                            if (showsAttendedData[index] != status){
                                print ("iCloud changing value for \(index) to \(status)")
                                attendedHandle.changeShowAttendedStatus(index: index, status: status)
                            }
                        }
                        
                    } else if (split2.count == 1){
                        split2 = record.components(separatedBy: ":")
                        if (split2.count == 2){
                            let bandname = split2[1]
                            let priority = Int(split2[2])
                            
                            if (bandPriorityStorage[bandname] != priority){
                                print ("iCloud changing value for \(bandname) to \(String(describing: priority))")
                                dataHandle.addPriorityData(bandname, priority: priority!)
                            }
                            
                            print ("Adding icloud PRIORITIES \(split2[1]) - \(split2[2])")
                        
                            print ("Adding icloud PRIORITIES compatMode \(split2[0]) - \(split2[1])")
                        }
                    }
                }
            }
        }
    }
    
    func compareLastModifiedDate () -> String {
        
        var winner: String = ""
        var templastModifiedDate:Date? = nil
        var iCloudDate: Date = Date()
        
        staticLastModifiedDate.sync() {
            templastModifiedDate = cacheVariables.lastModifiedDate
        }

        if (templastModifiedDate == nil){
            staticLastModifiedDate.async(flags: .barrier) {
                cacheVariables.lastModifiedDate = Date()
            }
            return "iCloud"
        }
        
        let values = NSUbiquitousKeyValueStore.default.dictionaryRepresentation
        
        if values["lastModifiedDate"] != nil {
            iCloudDate = NSUbiquitousKeyValueStore.default.object(forKey: "lastModifiedDate") as! Date
        } else {
            return "file"
        }
        
        print ("Comparing icloud Date of \(iCloudDate) to \(templastModifiedDate!)")
            
        if (iCloudDate > templastModifiedDate!){
            winner = "iCloud"
        } else {
            winner = "file"
        }

        return winner
        
    }
    
}

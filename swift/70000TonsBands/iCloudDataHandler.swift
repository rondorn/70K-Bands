//
//  iCloudDataHandler.swift
//  70K Bands
//
//  Created by Ron Dorn on 7/6/19.
//  Copyright © 2019 Ron Dorn. All rights reserved.
//

import Foundation


class iCloudDataHandler {
    
    let dataHandle = dataHandler()
    let attendedHandle = ShowsAttended()
        
    init(){
        
    }
    
    func writeiCloudData (dataHandle: dataHandler, attendedHandle: ShowsAttended){

        var dataString: String = ""
        
        var counter = 0;
        
        let bandPriorityStorage = dataHandle.getPriorityData()
        
        for (band, priority) in bandPriorityStorage {
            dataString = dataString + PRIORITY + "!" + band + "!" + String(priority) + ";"
            print ("Adding icloud write PRIORITIES \(band) - \(priority)")
            counter += 1
        }
    
        if (counter == 0){
            return;
        }
        
        let showsAttendedData = attendedHandle.getShowsAttended()
         for (index, attended) in showsAttendedData {
            dataString = dataString + ATTENDED + "!" + index + "!" + attended + ";"
            print ("Adding icloud write ATTENDED \(index) - '\(attended)'")
            counter += 1
         }

        
        if (counter > 2){
            print ("iCloud writing priority data")
            NSUbiquitousKeyValueStore.default.set(dataString, forKey: "bandPriorities")
            NSUbiquitousKeyValueStore.default.set(Date(), forKey: "lastModifiedDate")
            
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }
    
    func readiCloudData(){
        
        let winner = compareLastModifiedDate()
        if (winner == "iCloud"){
            NSUbiquitousKeyValueStore.default.synchronize()
            
            print ("iCloud getting priority data from the cloud")
            
            let values = NSUbiquitousKeyValueStore.default.dictionaryRepresentation
            
            print ("iCloud - " + String(describing: values))
            if values["bandPriorities"] != nil {
                let dataString = String(NSUbiquitousKeyValueStore.default.string(forKey: "bandPriorities")!)
                let split1 = dataString.components(separatedBy: ";")
                
                for record in split1 {
                    var split2 = record.components(separatedBy: "!")
                    print ("Number of variable is \(split2.count)")
                    if (split2.count == 3){
                        if (split2[0] == PRIORITY){
                            staticData.async(flags: .barrier) {
                                let bandname = split2[1]
                                let priority = Int(split2[2])
                                cacheVariables.bandPriorityStorageCache[bandname] = priority
                                print ("reading icloud PRIORITIES \(split2[1]) - \(split2[2])")
                            }
                            
                        } else if (split2[0] == ATTENDED){
                            
                            let index = split2[1]
                            let status = split2[2]
                            staticAttended.async(flags: .barrier){
                                cacheVariables.attendedStaticCache[index] = status
                                print ("reading icloud ATTENDED \(split2[1]) - '\(split2[2])'")
                            }
                        }
                        
                    } else if (split2.count == 1){
                        split2 = record.components(separatedBy: ":")
                        if (split2.count == 2){
                            staticData.async(flags: .barrier) {
                                let bandname = split2[1]
                                let priority = Int(split2[2])
                                cacheVariables.bandPriorityStorageCache[bandname] = priority
                                print ("Adding icloud PRIORITIES \(split2[1]) - \(split2[2])")
                            }
                            print ("Adding icloud PRIORITIES compatMode \(split2[0]) - \(split2[1])")
                        }
                    }
                }
            }
        }
    }
    
    func compareLastModifiedDate () -> String {
        
        var winner: String = ""
        var fileDate: Date = Date()
        var iCloudDate: Date = Date()
        
        
        let dateFormatter: DateFormatter = getDateFormatter()
        dateFormatter.dateFormat = "MM-dd-yy"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let data = try? String(contentsOf: dateFile, encoding: String.Encoding.utf8) {
            print ("Number of variable is Date from data is \(data)")
            if (data.isEmpty == false){
                fileDate = dateFormatter.date(from: data)!
            } else {
                return "file"
            }
        }
        
        
        let values = NSUbiquitousKeyValueStore.default.dictionaryRepresentation
        
        if values["lastModifiedDate"] != nil {
            iCloudDate = NSUbiquitousKeyValueStore.default.object(forKey: "lastModifiedDate") as! Date
        } else {
            return "file"
        }
        
        if (iCloudDate.timeIntervalSince1970 >= fileDate.timeIntervalSince1970){
            winner = "iCloud"
        } else {
            winner = "file"
        }
        
        print ("Winner is " + winner)
        print(iCloudDate);
        print (fileDate);
        
        return winner
        
    }
    
}

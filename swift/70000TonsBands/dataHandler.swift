//
//  dataHandler.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/7/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

class dataHandler {
    
    var bandPriorityStorage = [String:Int]()
    var bandPriorityTimestamps = [String:Double]()
    var readInWrite = false;
    
    init(){
        getCachedData()
    }
    
    func getCachedData(){
    
        print ("Loading priority Data cache")
        
        staticData.sync() {
            if (cacheVariables.bandPriorityStorageCache.isEmpty == false){
                print ("Loading bandPriorityStorage from Data cache")
                self.bandPriorityStorage = cacheVariables.bandPriorityStorageCache
                print ("Loading bandPriorityStorage from Data cache, done")
            } else {
                print ("Loading bandPriorityStorage Cache did not load, loading from file")
                self.refreshData()
            }
            
            var iCloudIndicator = UserDefaults.standard.string(forKey: "iCloud")
            iCloudIndicator = iCloudIndicator?.uppercased()

            print ("Done Loading bandName Data cache")
        }
    }
    
    func refreshData(){
        bandPriorityStorage = readFile(dateWinnerPassed: "")
    }

    func addPriorityData (_ bandname:String, priority: Int){
        
        print ("addPriorityData for \(bandname) = \(priority)")

        let timestamp = Date().timeIntervalSince1970
        bandPriorityStorage[bandname] = priority
        bandPriorityTimestamps[bandname] = timestamp
        
        staticData.async(flags: .barrier) {
            cacheVariables.bandPriorityStorageCache[bandname] = priority
        }
        
        staticLastModifiedDate.async(flags: .barrier) {
            cacheVariables.lastModifiedDate = Date()
        }
                
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            let iCloudHandle = iCloudDataHandler()
            iCloudHandle.writeAPriorityRecord(bandName: bandname, priority: priority)
            
            let firebaseBandData = firebaseBandDataWrite()
            let ranking = resolvePriorityNumber(priority: String(priority)) ?? "Unknown"
            firebaseBandData.writeSingleRecord(dataHandle: self, bandName: bandname, ranking: ranking)
            NSUbiquitousKeyValueStore.default.synchronize()
            self.writeFile()
        }
        
    }
    
    func clearCachedData(){
        staticData.async(flags: .barrier) {
            cacheVariables.bandPriorityStorageCache = [String:Int]()
        }
    }
    
    func getPriorityData (_ bandname:String) -> Int {
        
        var priority = 0
        
        print ("Retrieving priority data for " + bandname + ":", terminator: "\n")
        
        if (bandPriorityStorage[bandname] != nil){
            priority = bandPriorityStorage[bandname]!
            print("Reading data " + bandname + ":" + String(priority))
        }
        

        return priority
    }
    
    func getPriorityLastChange (_ bandname:String) -> Double {
        
        var timestamp = 0.0
        
        print ("Retrieving priority timestamp for " + bandname + ":", terminator: "\n")
        
        if (bandPriorityTimestamps[bandname] != nil){
            timestamp = bandPriorityTimestamps[bandname]!
            print("Reading timestamp " + bandname + ":" + String(timestamp))
        }
        

        return timestamp
    }
    
    func writeFile(){
        // Create thread-safe copies of the data with initial empty values
        var localPriorityStorage: [String: Int] = [:]
        var localPriorityTimestamps: [String: Double] = [:]
        var shouldWrite = false
        
        staticData.sync {
            // Skip if empty
            if !bandPriorityStorage.isEmpty {
                // Make thread-safe copies
                localPriorityStorage = bandPriorityStorage
                localPriorityTimestamps = bandPriorityTimestamps
                shouldWrite = true
            }
        }
        
        // Return early if no data to write
        if !shouldWrite {
            return
        }
        
        var data: String = ""
        
        // Work with the local copies
        for (bandName, priority) in localPriorityStorage {
            let timestamp = localPriorityTimestamps[bandName] ?? Date().timeIntervalSince1970
            print("writing PRIORITIES \(bandName) - \(priority):\(timestamp)")
            data = data + bandName + ":" + String(priority) + ":" + String(format: "%.0f", timestamp) + "\n"
        }
        
        // Write the data
        do {
            try data.write(to: storageFile, atomically: true, encoding: .utf8)
            print("Successfully wrote priority data to file")
        } catch {
            print("Error writing priority data to file: \(error.localizedDescription)")
        }
    }
    
    func getPriorityData() -> [String:Int]{
        
        return bandPriorityStorage;
    }

    func readFile(dateWinnerPassed : String) -> [String:Int]{
        
        print ("Load bandPriorityStorage data")
        bandPriorityStorage = [String:Int]()
        
        if (bandPriorityStorage.count == 0){
            if let data = try? String(contentsOf: storageFile, encoding: String.Encoding.utf8) {
                let dataArray = data.components(separatedBy: "\n")
                for record in dataArray {
                    var element = record.components(separatedBy: ":")
                    
                    // Handle new format: bandName:priority:timestamp (3 parts)
                    if element.count == 3 {
                        var priorityString = element[1]
                        var timestampString = element[2]
                        
                        priorityString = priorityString.replacingOccurrences(of: "\n", with: "", options: NSString.CompareOptions.literal, range: nil)
                        timestampString = timestampString.replacingOccurrences(of: "\n", with: "", options: NSString.CompareOptions.literal, range: nil)
                        
                        let priority = Int(priorityString) ?? 0
                        let timestamp = Double(timestampString) ?? 0.0
                        
                        print ("reading PRIORITIES \(element[0]) - \(priorityString):\(timestampString)")
                        
                        bandPriorityStorage[element[0]] = priority
                        bandPriorityTimestamps[element[0]] = timestamp
                        
                        staticData.async(flags: .barrier) {
                            cacheVariables.bandPriorityStorageCache[element[0]] = priority
                        }
                    }
                    // Handle old format: bandName:priority (2 parts) for backward compatibility
                    else if element.count == 2 {
                        var priorityString = element[1];
                        print ("reading PRIORITIES (old format) \(element[0]) - \(priorityString)")
                         priorityString = priorityString.replacingOccurrences(of: "\n", with: "", options: NSString.CompareOptions.literal, range: nil)
                        
                        let priority = Int(priorityString) ?? 0
                        
                        bandPriorityStorage[element[0]] = priority
                        bandPriorityTimestamps[element[0]] = 0.0  // Default timestamp for old data
                        
                        staticData.async(flags: .barrier) {
                            cacheVariables.bandPriorityStorageCache[element[0]] = priority
                        }
                    }
                }
            }
        }
        
        return bandPriorityStorage
    }

}

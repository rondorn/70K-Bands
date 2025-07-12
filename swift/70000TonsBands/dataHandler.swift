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
    
    /// Refreshes the data by reloading from disk or cache.
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
    
    /// Refreshes the data by reloading from disk or cache.
    func refreshData(){
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            self.bandPriorityStorage = self.readFile(dateWinnerPassed: "")
        }
    }

    /// Adds or updates the priority data for a band with a specific timestamp.
    /// - Parameters:
    ///   - bandName: The name of the band.
    ///   - priority: The priority value to set.
    ///   - timestamp: The timestamp of the update.
    func addPriorityDataWithTimestamp(_ bandname: String, priority: Int, timestamp: Double) {
        print ("addPriorityDataWithTimestamp for \(bandname) = \(priority) at \(timestamp)")
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

    /// Adds or updates the priority data for a band.
    /// - Parameters:
    ///   - bandName: The name of the band.
    ///   - priority: The priority value to set.
    func addPriorityData (_ bandname:String, priority: Int){
        let timestamp = Date().timeIntervalSince1970
        addPriorityDataWithTimestamp(bandname, priority: priority, timestamp: timestamp)
    }
    
    /// Clears the cached data for priorities.
    func clearCachedData(){
        staticData.async(flags: .barrier) {
            cacheVariables.bandPriorityStorageCache = [String:Int]()
        }
    }
    
    /// Returns the priority value for a specific band.
    /// - Parameter bandName: The name of the band.
    /// - Returns: The priority value for the band, or 0 if not found.
    func getPriorityData (_ bandname:String) -> Int {
        var priority = 0
        // Defensive: Convert to native Swift String
        let key = String(describing: bandname)
        print ("Retrieving priority data for " + key + ":", terminator: "\n")
        staticData.sync {
            if let value = bandPriorityStorage[key] {
                priority = value
                print("Reading data " + key + ":" + String(priority))
        }
        }
        return priority
    }
    
    /// Returns the last change timestamp for a band's priority data.
    /// - Parameter bandName: The name of the band.
    /// - Returns: The timestamp of the last change, or 0 if not found.
    func getPriorityLastChange (_ bandname:String) -> Double {
        var timestamp = 0.0
        // Defensive: Convert to native Swift String
        let key = String(describing: bandname)
        print ("Retrieving priority timestamp for " + key + ":", terminator: "\n")
        staticData.sync {
            if let value = bandPriorityTimestamps[key] {
                timestamp = value
                print("Reading timestamp " + key + ":" + String(timestamp))
        }
        }
        return timestamp
    }
    
    /// Writes the current priority data to disk.
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
    
    /// Returns the priority data for all bands as a dictionary.
    /// - Returns: A dictionary mapping band names to their priority values.
    func getPriorityData() -> [String:Int]{
        
        return bandPriorityStorage;
    }

    /// Reads the priority data file from disk.
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

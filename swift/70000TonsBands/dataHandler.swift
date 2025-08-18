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
                staticData.async(flags: .barrier) {
                    self.bandPriorityStorage = cacheVariables.bandPriorityStorageCache
                }
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
            let fileData = self.readFile(dateWinnerPassed: "")
            staticData.async(flags: .barrier) {
                self.bandPriorityStorage = fileData
            }
        }
    }

    /// Adds or updates the priority data for a band with a specific timestamp (SILENT VERSION - no iCloud write).
    /// This version is used when applying iCloud data to prevent infinite loops.
    /// - Parameters:
    ///   - bandName: The name of the band.
    ///   - priority: The priority value to set.
    ///   - timestamp: The timestamp of the update.
    func addPriorityDataWithTimestampSilent(_ bandname: String, priority: Int, timestamp: Double) {
        print ("addPriorityDataWithTimestampSilent for \(bandname) = \(priority) at \(timestamp)")
        staticData.async(flags: .barrier) {
            self.bandPriorityStorage[bandname] = priority
            self.bandPriorityTimestamps[bandname] = timestamp
            cacheVariables.bandPriorityStorageCache[bandname] = priority
        }
        staticLastModifiedDate.async(flags: .barrier) {
            cacheVariables.lastModifiedDate = Date()
        }
        // Only write to local file - NO iCloud or Firebase writes to prevent loops
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            self.writeFile()
        }
    }
    
    /// Adds or updates the priority data for a band with a specific timestamp.
    /// - Parameters:
    ///   - bandName: The name of the band.
    ///   - priority: The priority value to set.
    ///   - timestamp: The timestamp of the update.
    func addPriorityDataWithTimestamp(_ bandname: String, priority: Int, timestamp: Double) {
        print ("addPriorityDataWithTimestamp for \(bandname) = \(priority) at \(timestamp)")
        staticData.async(flags: .barrier) {
            self.bandPriorityStorage[bandname] = priority
            self.bandPriorityTimestamps[bandname] = timestamp
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
        
        // Also clear local instance variables
        bandPriorityStorage.removeAll()
        bandPriorityTimestamps.removeAll()
    }
    
    /// Returns the priority value for a specific band.
    /// - Parameter bandName: The name of the band.
    /// - Returns: The priority value for the band, or 0 if not found.
    func getPriorityData(_ bandname: Any) -> Int {
        print("DEBUG: getPriorityData called with value: \(bandname) (\(type(of: bandname)))")
        guard let bandnameStr = bandname as? String else {
            assertionFailure("getPriorityData called with non-String key: \(bandname) (\(type(of: bandname)))")
            print("ERROR: getPriorityData called with non-String key: \(bandname) (\(type(of: bandname)))")
            return 0
        }
        var priority = 0
        staticData.sync {
            if let value = bandPriorityStorage[bandnameStr] {
                priority = value
            }
        }
        return priority
    }
    
    /// Returns the last change timestamp for a band's priority data.
    /// - Parameter bandName: The name of the band.
    /// - Returns: The timestamp of the last change, or 0 if not found.
    func getPriorityLastChange (_ bandname:String) -> Double {
        var timestamp = 0.0
        staticData.sync {
            if let value = bandPriorityTimestamps[bandname] {
                timestamp = value
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
        var localBandPriorityStorage = [String:Int]()
        
        if (localBandPriorityStorage.count == 0){
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
                        
                        localBandPriorityStorage[element[0]] = priority
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
                        
                        localBandPriorityStorage[element[0]] = priority
                        staticData.async(flags: .barrier) {
                            cacheVariables.bandPriorityStorageCache[element[0]] = priority
                        }
                    }
                }
            }
        }
        
        return localBandPriorityStorage
    }

    func readAllScheduleData() {
        // ... existing code for loading and parsing schedule data ...
        // After schedule data is loaded and parsed:
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("ScheduleDataReady"), object: nil)
        }
    }
}

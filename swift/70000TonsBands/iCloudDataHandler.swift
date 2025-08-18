//
//  iCloudDataHandler.swift
//  70K Bands
//
//  Created by Ron Dorn on 7/6/19.
//  Copyright © 2019 Ron Dorn. All rights reserved.
//

import Foundation
import UIKit

let uidString: String? = UIDevice.current.identifierForVendor?.uuidString

// Extension for array chunking to support batch processing
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

class iCloudDataHandler {
    
    /// Initializes the iCloudDataHandler class
    /// Sets up the handler for managing iCloud data synchronization
    init(){
        //print("iCloud: Initializing iCloudDataHandler")
    }
    
    /// Checks if iCloud is enabled and available for use
    /// Returns true if iCloud is enabled in user defaults, false otherwise
    func checkForIcloud()->Bool {
        print("iCloudGeneral: Starting checkForIcloud operation")
        
        UserDefaults.standard.synchronize()
        var status = false
        
        // Check if the iCloud key exists and get the value
        if let iCloudIndicator = UserDefaults.standard.object(forKey: "iCloud") as? String {
            let normalizedValue = iCloudIndicator.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            print("iCloudGeneral: Retrieved iCloud indicator from UserDefaults: '\(iCloudIndicator)' -> normalized: '\(normalizedValue)'")
            
            if normalizedValue == "YES" || normalizedValue == "TRUE" || normalizedValue == "1" {
                status = true
                print("iCloudGeneral: iCloud is enabled")
            } else {
                print("iCloudGeneral: iCloud is disabled (value: '\(normalizedValue)')")
            }
        } else {
            // Key doesn't exist or is not a string - check if it's a boolean
            if UserDefaults.standard.object(forKey: "iCloud") != nil {
                status = UserDefaults.standard.bool(forKey: "iCloud")
                print("iCloudGeneral: Retrieved iCloud boolean from UserDefaults: \(status)")
            } else {
                // This should not happen now that defaults are registered at app startup
                status = false
                print("iCloudGeneral: iCloud key not found in UserDefaults - this indicates setDefaults() wasn't called")
            }
        }
        
        print("iCloudGeneral: checkForIcloud completed with status: \(status)")
        return status
    }

    /// Reads all priority data from iCloud and syncs to local storage
    /// Iterates through all bands and attempts to read their priority data from iCloud
    func readAllPriorityData(){
        print("iCloudPriority: Starting optimized readAllPriorityData operation")
        
        // Return immediately if already loading to prevent multiple concurrent operations
        guard checkForIcloud() == true else {
            print("iCloudPriority: iCloud data currently loading, skipping read operation")
            return
        }
        
        print("iCloudPriority: iCloud data not currently loading, proceeding with optimized read")
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            iCloudDataisLoading = true;
            print("iCloudPriority: Set iCloudDataisLoading to true")
            
            let bandNameHandle = bandNamesHandler.shared
            let bandNames = bandNameHandle.getBandNames()
            
            let priorityHandler = dataHandler()
            priorityHandler.refreshData()
            
            print("iCloudPriority: Reading priority data for \(bandNames.count) bands using optimized bulk processing")
            
            // Pre-compute common values to avoid repeated calculations
            guard let currentUid = UIDevice.current.identifierForVendor?.uuidString else {
                print("iCloudPriority: Could not get device UID, aborting")
                iCloudDataisLoading = false
                return
            }
            
            // Bulk read all priority keys from iCloud
            let allPriorityKeys = bandNames.map { "bandName:\($0)" }
            var bulkResults: [(String, String)] = []
            
            print("iCloudPriority: Bulk reading \(allPriorityKeys.count) keys from iCloud...")
            for key in allPriorityKeys {
                if let value = NSUbiquitousKeyValueStore.default.string(forKey: key), !value.isEmpty {
                    bulkResults.append((key, value))
                }
            }
            
            print("iCloudPriority: Retrieved \(bulkResults.count) non-empty values from iCloud")
            
            // Process results in parallel with controlled concurrency
            let batchSize = 25 // Smaller batches for parallel processing
            let batches = bulkResults.chunked(into: batchSize)
            let concurrentQueue = DispatchQueue(label: "iCloudPriorityProcessing", qos: .utility, attributes: .concurrent)
            let semaphore = DispatchSemaphore(value: 4) // Limit to 4 concurrent operations
            
            var priorityUpdates: [(String, Int, Double)] = []
            let updatesLock = DispatchQueue(label: "updatesLock")
            
            print("iCloudPriority: Processing \(batches.count) batches in parallel...")
            
            DispatchQueue.concurrentPerform(iterations: batches.count) { batchIndex in
                semaphore.wait()
                defer { semaphore.signal() }
                
                // Check if operation was cancelled
                guard iCloudDataisLoading else { return }
                
                let batch = batches[batchIndex]
                var batchUpdates: [(String, Int, Double)] = []
                
                for (key, value) in batch {
                    // Extract band name from key
                    let bandName = String(key.dropFirst("bandName:".count))
                    
                    // Process priority data
                    if let update = self.processPriorityRecord(bandName: bandName, value: value, currentUid: currentUid, priorityHandler: priorityHandler) {
                        batchUpdates.append(update)
                    }
                }
                
                // Thread-safe addition to updates array
                updatesLock.sync {
                    priorityUpdates.append(contentsOf: batchUpdates)
                }
                
                print("iCloudPriority: Completed batch \(batchIndex + 1)/\(batches.count) (\(batch.count) items, \(batchUpdates.count) updates)")
            }
            
            // Apply all updates in batch using SILENT version to prevent iCloud write loops
            print("iCloudPriority: Applying \(priorityUpdates.count) priority updates...")
            for (bandName, priority, timestamp) in priorityUpdates {
                priorityHandler.addPriorityDataWithTimestampSilent(bandName, priority: priority, timestamp: timestamp)
            }
            
            iCloudDataisLoading = false;
            print("iCloudPriority: Optimized read operation completed with \(priorityUpdates.count) updates applied")
            
            // Notify UI that iCloud data is ready
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("iCloudDataReady"), object: nil)
            }
        }
        
        print("iCloudPriority: readAllPriorityData operation completed")
    }
    
    /// Processes a single priority record efficiently for bulk operations
    /// - Parameters:
    ///   - bandName: The name of the band
    ///   - value: The iCloud value string
    ///   - currentUid: The current device UID
    ///   - priorityHandler: The data handler for priority operations
    /// - Returns: Tuple of (bandName, priority, timestamp) if update is needed, nil otherwise
    private func processPriorityRecord(bandName: String, value: String, currentUid: String, priorityHandler: dataHandler) -> (String, Int, Double)? {
        guard !value.isEmpty && value != "5" else { 
            print("iCloudPriority: Skipping \(bandName) - empty or no data (\(value))")
            return nil 
        }
        
        let tempData = value.split(separator: ":")
        
        // Handle new format: priority:uid:timestamp (3 parts)
        guard tempData.count == 3,
              let newPriority = Int(tempData[0]),
              let timestampValue = Double(tempData[2]) else {
            print("iCloudPriority: Invalid format for band \(bandName): \(value)")
            return nil
        }
        
        let uidValue = String(tempData[1])
        let currentPriority = priorityHandler.getPriorityData(bandName)
        
        print("iCloudPriority: Processing \(bandName) - iCloud: \(newPriority):\(uidValue):\(timestampValue), local: \(currentPriority), currentUID: \(currentUid)")
        
        // RULE 1: Never overwrite local data if UID matches current device
        if uidValue == currentUid {
            print("iCloudPriority: Skipping \(bandName) - UID matches current device (\(uidValue) == \(currentUid))")
            return nil
        }
        
        // RULE 2: Only update if iCloud data is newer than local data
        let localTimestamp = priorityHandler.getPriorityLastChange(bandName)
        
        print("iCloudPriority: Timestamp comparison for \(bandName) - local: \(localTimestamp), iCloud: \(timestampValue)")
        
        if localTimestamp > 0 {
            // Only update if iCloud timestamp is NEWER (>) than local timestamp
            guard timestampValue > localTimestamp else { 
                print("iCloudPriority: Skipping \(bandName) - iCloud timestamp not newer (\(timestampValue) <= \(localTimestamp))")
                return nil 
            }
        } else if currentPriority != 0 {
            // Local data exists but no timestamp - be conservative
            print("iCloudPriority: Skipping \(bandName) - local data exists but no timestamp, being conservative")
            return nil
        }
        
        print("iCloudPriority: Update needed for \(bandName): \(currentPriority) -> \(newPriority) (timestamp: \(timestampValue))")
        return (bandName, newPriority, timestampValue)
    }
    
    /// Reads a single priority record from iCloud for a specific band
    /// - Parameters:
    ///   - bandName: The name of the band to read
    ///   - priorityHandler: The data handler for priority operations
    func readAPriorityRecord(bandName: String, priorityHandler: dataHandler){
        
        if (checkForIcloud() == true){
            print("iCloudPriority: Starting readAPriorityRecord for band: \(bandName)")
            
            let index = "bandName:" + bandName
            //5 indicated no data was present in iCloud
            let tempValue = String(NSUbiquitousKeyValueStore.default.string(forKey: index) ?? "5")
            if let currentUid = UIDevice.current.identifierForVendor?.uuidString {
                print("iCloudPriority: Retrieved value from iCloud: \(tempValue) for key: \(index)")
                
                if (tempValue != nil && tempValue.isEmpty == false){
                    let tempData = tempValue.split(separator: ":")
                    
                    // Handle new format: priority:uid:timestamp (3 parts)
                    if (tempData.isEmpty == false && tempData.count == 3){
                        let newPriority = tempData[0]
                        let uidValue = String(tempData[1])
                        let timestampValue = Double(tempData[2]) ?? 0
                        let currentPriority = priorityHandler.getPriorityData(bandName)
                        
                        print("iCloudPriority: Parsed priority data (new format) - newPriority: \(newPriority), uidValue: \(uidValue), timestamp: \(timestampValue), currentPriority: \(currentPriority)")
                        
                        // RULE 1: Never overwrite local data if UID matches current device
                        if (uidValue == currentUid){
                            print("iCloudPriority: UID \(uidValue) matches current device (\(currentUid)), never overwriting local data for band: \(bandName)")
                            return
                        }
                        
                        // RULE 2: Only update if iCloud data is newer than local data
                        let localTimestamp = priorityHandler.getPriorityLastChange(bandName)
                        
                        print("iCloudPriority: Comparing timestamps - localTimestamp: \(localTimestamp), iCloudTimestamp: \(timestampValue)")
                        
                        if (localTimestamp > 0){
                            // Only update if iCloud timestamp is NEWER (>) than local timestamp
                            if (timestampValue > localTimestamp){
                                print("iCloudPriority: iCloud data is newer (\(timestampValue) > \(localTimestamp)), updating local priority for band: \(bandName)")
                                priorityHandler.addPriorityDataWithTimestampSilent(bandName, priority: Int(newPriority) ?? 0, timestamp: timestampValue)
                                print("iCloudPriority: Priority updated for band: \(bandName) to: \(newPriority)")
                            } else {
                                print("iCloudPriority: Local data is newer or equal (\(timestampValue) <= \(localTimestamp)), skipping update for band: \(bandName)")
                            }
                        } else {
                            // No local timestamp exists, safe to update with iCloud data
                            print("iCloudPriority: No local timestamp found, updating with iCloud data for band: \(bandName)")
                            priorityHandler.addPriorityDataWithTimestampSilent(bandName, priority: Int(newPriority) ?? 0, timestamp: timestampValue)
                            print("iCloudPriority: Priority updated for band: \(bandName) to: \(newPriority)")
                        }
                    } else if (tempData.count == 2) {
                        // Handle old format: priority:uid (no timestamp)
                        let newPriority = tempData[0]
                        let uidValue = String(tempData[1])
                        let timestampValue = 0.0
                        let currentPriority = priorityHandler.getPriorityData(bandName)
                        print("iCloudPriority: Parsed priority data (old format) - newPriority: \(newPriority), uidValue: \(uidValue), timestamp: 0, currentPriority: \(currentPriority)")

                        // Always update local data, since we can't compare timestamps
                        priorityHandler.addPriorityDataWithTimestampSilent(bandName, priority: Int(newPriority) ?? 0, timestamp: timestampValue)
                        print("iCloudPriority: Priority updated for band: \(bandName) to: \(newPriority) (from old format)")

                        // Now update iCloud with the new format (priority:uid:currentTime)
                        let now = Date().timeIntervalSince1970
                        let dataString = String(newPriority) + ":" + currentUid + ":" + String(format: "%.0f", now)
                        NSUbiquitousKeyValueStore.default.set(dataString, forKey: index)
                        NSUbiquitousKeyValueStore.default.synchronize()
                        print("iCloudPriority: Migrated old format to new format for band: \(bandName)")
                    } else {
                        print("iCloudPriority: Invalid data format for band: \(bandName) - expected 3 parts (priority:uid:timestamp), got \(tempData.count) parts. Ignoring old format.")
                    }
                } else {
                    print("iCloudPriority: No iCloud data found for band: \(bandName)")
                }
            } else {
                print("iCloudPriority: ERROR - UIDevice identifierForVendor is nil, cannot compare UIDs for band: \(bandName)")
                return
            }
            
            print("iCloudPriority: readAPriorityRecord completed for band: \(bandName)")
        }
    }
    
    /// Writes all priority data for bands to iCloud
    /// Iterates through all band priority data and syncs it to iCloud storage
    func writeAllPriorityData(){
        print("iCloudPriority: Starting writeAllPriorityData operation")
        
        if (checkForIcloud() == true){
            print("iCloudPriority: Internet available and iCloud enabled, proceeding with data write")
            let priorityHandler = dataHandler()
            priorityHandler.refreshData()
            let priorityData = priorityHandler.getPriorityData()
            
            print("iCloudPriority: Retrieved priority data with \(priorityData.count ?? 0) entries")
            
            if (priorityData != nil && priorityData.count > 0){
                print("iCloudPriority: Writing \(priorityData.count) priority records to iCloud (with timestamp check)")
                for (bandName, priority) in priorityData {
                    print("iCloudPriority: Processing priority record for band: \(bandName)")
                    let index = "bandName:" + bandName
                    let iCloudValue = NSUbiquitousKeyValueStore.default.string(forKey: index)
                    var iCloudTimestamp: Double = 0
                    if let iCloudValue = iCloudValue, !iCloudValue.isEmpty {
                        let parts = iCloudValue.split(separator: ":")
                        if parts.count == 3, let ts = Double(parts[2]) {
                            iCloudTimestamp = ts
                        } else {
                            // Old format or invalid, treat as 0
                            iCloudTimestamp = 0
                        }
                    }
                    // Get the timestamp that would be written for this band
                    var proposedTimestamp = priorityHandler.getPriorityLastChange(bandName)
                    if proposedTimestamp <= 0 {
                        proposedTimestamp = Date().timeIntervalSince1970
                    }
                    print("iCloudPriority: Comparing proposedTimestamp \(proposedTimestamp) to iCloudTimestamp \(iCloudTimestamp) for band: \(bandName)")
                    if proposedTimestamp > iCloudTimestamp {
                        print("iCloudPriority: Proposed data is newer, writing to iCloud for band: \(bandName)")
                        writeAPriorityRecord(bandName: bandName, priority: priority)
                    } else {
                        print("iCloudPriority: Skipping write for band: \(bandName) because iCloud data is newer or equal")
                    }
                }
                NSUbiquitousKeyValueStore.default.synchronize()
                //writeLastiCloudDataWrite()
                print("iCloudPriority: All priority data written and synchronized (with timestamp check)")
            } else {
                print("iCloudPriority: No priority data to write")
            }
        } else {
            print("iCloudPriority: Cannot write priority data - internet unavailable or iCloud disabled")
        }
        
        print("iCloudPriority: writeAllPriorityData operation completed")
    }
    
    /// Writes a single priority record for a specific band to iCloud
    /// - Parameters:
    ///   - bandName: The name of the band
    ///   - priority: The priority value to store
    func writeAPriorityRecord(bandName: String, priority: Int){
        
        if (checkForIcloud() == true){
            print("iCloudPriority: Starting writeAPriorityRecord for band: \(bandName)")
            
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                // Get the timestamp from local data handler or use current time
                let localDataHandler = dataHandler()
                var timestamp = localDataHandler.getPriorityLastChange(bandName)
                
                // If no valid timestamp exists, use current time in seconds since epoch
                if timestamp <= 0 {
                    timestamp = Date().timeIntervalSince1970
                }
                
                // ENFORCE: Always use current device UID and timestamp from local data
                if let currentUid = UIDevice.current.identifierForVendor?.uuidString {
                    let timestampString = String(format: "%.0f", timestamp) // Format to remove decimals
                    
                    // Use format: priority:uid:timestamp for better conflict resolution
                    let dataString = String(priority) + ":" + currentUid + ":" + timestampString
                    print("iCloudPriority: Writing priority record - bandName: \(bandName), priority: \(priority), uid: \(currentUid), timestamp: \(timestampString)")
                    print("iCloudPriority: Full dataString: \(dataString)")
                    
                    NSUbiquitousKeyValueStore.default.set(dataString, forKey: "bandName:" + bandName)
                    print("iCloudPriority: Priority record written for band: \(bandName)")
                    NSUbiquitousKeyValueStore.default.synchronize()
                } else {
                    print("iCloudPriority: ERROR - UIDevice identifierForVendor is nil, cannot write priority record for band: \(bandName)")
                }
            }
        }
    }
    

    /// Writes all schedule/attendance data to iCloud
    /// Syncs all attended shows data to iCloud storage
    func writeAllScheduleData(){
        
        print("iCloudSchedule: Starting writeAllScheduleData operation")
        
        if (checkForIcloud() == true){
            print("iCloudSchedule: iCloud enabled, proceeding with schedule data write")
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                let attendedHandle = ShowsAttended()
                attendedHandle.loadShowsAttended()
                let showsAttendedArray = attendedHandle.getShowsAttended();
                
                let uid = (UIDevice.current.identifierForVendor?.uuidString) ?? ""
                print("iCloudSchedule: Device UID: \(uid)")
                
                if (uid.isEmpty == false){
                    print("iCloudSchedule: Valid UID found, processing attended shows")
                    if (showsAttendedArray != nil && showsAttendedArray.isEmpty == false){
                        print("iCloudSchedule: Writing \(showsAttendedArray.count) schedule records to iCloud")
                        for eventIndex in showsAttendedArray {
                            print("iCloudSchedule: Processing schedule record for event: \(eventIndex.key) - \(eventIndex.value)")
                            self.writeAScheduleRecord(eventIndex: eventIndex.key, status: eventIndex.value)
                        }
                    } else {
                        print("iCloudSchedule: No attended shows data to write")
                    }
                } else {
                    print("iCloudSchedule: Invalid UID, cannot write schedule data")
                }
            }
        } else {
            print("iCloudSchedule: iCloud disabled, skipping schedule data write")
        }
        
        print("iCloudSchedule: writeAllScheduleData operation completed")

    }
    
    /// Writes a single schedule record to iCloud
    /// - Parameters:
    ///   - eventIndex: The event identifier
    ///   - status: The attendance status
    func writeAScheduleRecord(eventIndex: String, status: String){
        if (checkForIcloud() == true){
            print("iCloudSchedule: Starting writeAScheduleRecord for event: \(eventIndex)")
            let timestamp: String
            // If status already contains a timestamp, use it; otherwise, use now
            let statusParts = status.split(separator: ":")
            if statusParts.count == 2 {
                timestamp = String(statusParts[1])
            } else {
                timestamp = String(format: "%.0f", Date().timeIntervalSince1970)
            }
            let statusOnly = String(statusParts[0])
            if let currentUid = UIDevice.current.identifierForVendor?.uuidString {
                let dataString = statusOnly + ":" + currentUid + ":" + timestamp
                print("iCloudSchedule: Writing schedule record - eventIndex: \(eventIndex), dataString: \(dataString)")
                NSUbiquitousKeyValueStore.default.set(dataString, forKey: "eventName:" + eventIndex)
                print("iCloudSchedule: Schedule record written for event: \(eventIndex)")
                NSUbiquitousKeyValueStore.default.synchronize()
            } else {
                print("iCloudSchedule: ERROR - UIDevice identifierForVendor is nil, cannot write schedule record for event: \(eventIndex)")
            }
        } else {
            print("iCloudSchedule: iCloud disabled or unavailable, cannot write schedule record for event: \(eventIndex)")
        }
    }
        
    /// Reads all schedule/attendance data from iCloud
    /// Syncs all attended shows data from iCloud to local storage
    var iCloudScheduleDataisLoading = false;
    func readAllScheduleData(){
        if (checkForIcloud() == true){
            print("iCloudSchedule: Starting optimized readAllScheduleData operation")

            iCloudScheduleDataisLoading = true;
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                print("iCloudSchedule: Initializing handlers for optimized schedule data read")
                
                let scheduleHandle = scheduleHandler.shared
                scheduleHandle.buildTimeSortedSchedulingData();
                
                let bandNameHandle = bandNamesHandler.shared
                let bandNames = bandNameHandle.getBandNames()
                
                let attendedHandle = ShowsAttended()
                attendedHandle.loadShowsAttended()
                
                let priorityHandler = dataHandler()
                priorityHandler.refreshData()
                
                let scheduleData = scheduleHandle.getBandSortedSchedulingData()
                
                print("iCloudSchedule: Processing schedule data for \(scheduleData.count) bands using optimized approach")
                
                if (scheduleData.count > 0){
                    // Pre-flatten the nested schedule structure for efficient processing
                    var flatScheduleItems: [(String, String, String, String)] = []
                    var bandsNotInList: [String] = []
                    
                    print("iCloudSchedule: Flattening schedule data structure...")
                    for bandName in scheduleData.keys {
                        // Track bands not in main list for priority reading
                        if !bandNames.contains(bandName) {
                            bandsNotInList.append(bandName)
                        }
                        
                        if let timeSlots = scheduleData[bandName] {
                            for timeIndex in timeSlots.keys {
                                if let eventData = timeSlots[timeIndex],
                                   let location = eventData[locationField],
                                   let startTime = eventData[startTimeField],
                                   let eventType = eventData[typeField] {
                                    flatScheduleItems.append((bandName, location, startTime, eventType))
                                }
                            }
                        }
                    }
                    
                    print("iCloudSchedule: Flattened \(flatScheduleItems.count) schedule items, \(bandsNotInList.count) bands need priority reading")
                    
                    // Bulk read all schedule keys from iCloud
                    let eventYearString = String(eventYear)
                    let allScheduleKeys = flatScheduleItems.map { (bandName, location, startTime, eventType) in
                        return "eventName:\(bandName):\(location):\(startTime):\(eventType):\(eventYearString)"
                    }
                    
                    var bulkScheduleResults: [(String, String)] = []
                    print("iCloudSchedule: Bulk reading \(allScheduleKeys.count) schedule keys from iCloud...")
                    
                    for key in allScheduleKeys {
                        if let value = NSUbiquitousKeyValueStore.default.string(forKey: key), !value.isEmpty {
                            bulkScheduleResults.append((key, value))
                        }
                    }
                    
                    print("iCloudSchedule: Retrieved \(bulkScheduleResults.count) non-empty schedule values from iCloud")
                    
                    // Process schedule results in parallel
                    let batchSize = 20 // Smaller batches for schedule processing
                    let batches = bulkScheduleResults.chunked(into: batchSize)
                    let semaphore = DispatchSemaphore(value: 3) // Limit concurrent operations
                    
                    var scheduleUpdates: [(String, String)] = []
                    let updatesLock = DispatchQueue(label: "scheduleUpdatesLock")
                    
                    print("iCloudSchedule: Processing \(batches.count) schedule batches in parallel...")
                    
                    DispatchQueue.concurrentPerform(iterations: batches.count) { batchIndex in
                        semaphore.wait()
                        defer { semaphore.signal() }
                        
                        let batch = batches[batchIndex]
                        var batchUpdates: [(String, String)] = []
                        
                        for (key, value) in batch {
                            if let update = self.processScheduleRecord(key: key, value: value, attendedHandle: attendedHandle, bandNames: bandNames) {
                                batchUpdates.append(update)
                            }
                        }
                        
                        // Thread-safe addition to updates array
                        updatesLock.sync {
                            scheduleUpdates.append(contentsOf: batchUpdates)
                        }
                        
                        print("iCloudSchedule: Completed batch \(batchIndex + 1)/\(batches.count) (\(batch.count) items, \(batchUpdates.count) updates)")
                    }
                    
                    // Apply all schedule updates in batch
                    print("iCloudSchedule: Applying \(scheduleUpdates.count) schedule updates...")
                    for (eventIndex, status) in scheduleUpdates {
                        attendedHandle.changeShowAttendedStatus(index: eventIndex, status: status)
                    }
                    
                    // Handle bands not in main list (read their priorities)
                    if !bandsNotInList.isEmpty {
                        print("iCloudSchedule: Reading priorities for \(bandsNotInList.count) bands not in main list...")
                        for bandName in bandsNotInList {
                            self.readAPriorityRecord(bandName: bandName, priorityHandler: priorityHandler)
                        }
                    }
                    
                    print("iCloudSchedule: Optimized processing completed with \(scheduleUpdates.count) updates applied")
                } else {
                    print("iCloudSchedule: No schedule data found to process")
                }
                
                print("iCloudSchedule: readAllScheduleData operation completed")
                // Ensure local attended data is saved to disk for offline use
                attendedHandle.saveShowsAttended()
                self.iCloudScheduleDataisLoading = false;
                // Notify UI that iCloud data is ready
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name("iCloudDataReady"), object: nil)
                }
            }
        } else {
            print("iCloudSchedule: iCloud disabled, skipping schedule data read")
        }
    }
    
    /// Processes a single schedule record efficiently for bulk operations
    /// - Parameters:
    ///   - key: The iCloud key
    ///   - value: The iCloud value
    ///   - attendedHandle: The attended shows handler
    ///   - bandNames: Array of band names
    /// - Returns: Tuple of (eventIndex, status) if update is needed, nil otherwise
    private func processScheduleRecord(key: String, value: String, attendedHandle: ShowsAttended, bandNames: [String]) -> (String, String)? {
        // Extract components from key: "eventName:bandName:location:startTime:eventType:eventYear"
        let keyComponents = key.components(separatedBy: ":")
        guard keyComponents.count >= 6,
              keyComponents[0] == "eventName" else {
            print("iCloudSchedule: Invalid key format: \(key)")
            return nil
        }
        
        let bandName = keyComponents[1]
        let location = keyComponents[2]
        let startTime = keyComponents[3]
        let eventType = keyComponents[4]
        let eventYearString = keyComponents[5]
        
        let eventIndex = key  // Use the full key as eventIndex
        
        // Parse iCloud value (format: "status:uid:timestamp")
        let valueComponents = value.components(separatedBy: ":")
        guard valueComponents.count >= 3,
              let timestamp = Double(valueComponents[2]) else {
            print("iCloudSchedule: Invalid value format for \(eventIndex): \(value)")
            return nil
        }
        
        let iCloudStatus = valueComponents[0]
        let uidValue = valueComponents[1]
        
        // Get current device UID
        guard let currentUid = UIDevice.current.identifierForVendor?.uuidString else {
            return nil
        }
        
        // RULE 1: Never overwrite local data if UID matches current device
        if uidValue == currentUid {
            return nil
        }
        
        // RULE 2: Only update if iCloud data is newer than local data
        let localStatus = attendedHandle.getShowAttendedStatus(band: bandName, location: location, startTime: startTime, eventType: eventType, eventYearString: eventYearString)
        let localTimestamp = attendedHandle.getShowAttendedLastChange(index: eventIndex)
        
        if localTimestamp > 0 {
            // Only update if iCloud timestamp is NEWER than local timestamp
            guard timestamp > localTimestamp else { return nil }
        } else if localStatus != "0" {
            // Local data exists but no timestamp - be conservative
            return nil
        }
        
        print("iCloudSchedule: Update needed for \(eventIndex): \(localStatus) -> \(iCloudStatus)")
        return (eventIndex, iCloudStatus)
    }
    
    /// Reads a single schedule record from iCloud
    /// - Parameters:
    ///   - bandName: The name of the band
    ///   - location: The venue location
    ///   - startTime: The start time of the event
    ///   - eventType: The type of event
    ///   - attendedHandle: The shows attended handler
    ///   - bandNames: Array of all band names
    func readAScheduleRecord(bandName: String,
                             location: String,
                             startTime: String,
                             eventType:String,
                             attendedHandle: ShowsAttended,
                             bandNames: [String]){
        print("iCloudSchedule: Starting readAScheduleRecord for band: \(bandName), location: \(location), startTime: \(startTime)")
        let eventYearString = String(eventYear)
        var eventIndex = "eventName:" + bandName + ":"
        eventIndex = eventIndex + location + ":"
        eventIndex = eventIndex + startTime + ":"
        eventIndex = eventIndex + eventType + ":"
        eventIndex = eventIndex + eventYearString
        print("iCloudSchedule: Constructed event index: \(eventIndex)")
        if let currentUid = UIDevice.current.identifierForVendor?.uuidString {
            let tempValue = String(NSUbiquitousKeyValueStore.default.string(forKey: eventIndex) ?? "0")
            print("iCloudSchedule: Retrieved value from iCloud: \(tempValue) for eventIndex: \(eventIndex)")
            if (tempValue != nil && tempValue.isEmpty == false && eventIndex != "0"){
                let tempData = tempValue.split(separator: ":")
                if (tempData.isEmpty == false && tempData.count == 3){
                    let newAttended = String(tempData[0])
                    let uidValue = tempData[1]
                    let iCloudTimestamp = Double(tempData[2]) ?? 0
                    let localIndex = bandName + ":" + location + ":" + startTime + ":" + eventType + ":" + eventYearString
                    let localTimestamp = attendedHandle.getShowAttendedLastChange(index: localIndex)
                    print("iCloudSchedule: Parsed attendance data \(bandName) - newAttended: \(newAttended), uidValue: \(uidValue), iCloudTimestamp: \(iCloudTimestamp), localTimestamp: \(localTimestamp)")
                    // Only update if iCloud timestamp is newer
                    if (iCloudTimestamp > localTimestamp){
                        print("iCloudSchedule: iCloud data is newer (\(iCloudTimestamp) > \(localTimestamp)), updating local attendance")
                        attendedHandle.addShowsAttendedWithStatusAndTime(band: bandName, location: location, startTime: startTime, eventType: eventType, eventYearString: eventYearString, status: newAttended, newTime: iCloudTimestamp)
                        print("iCloudSchedule: Attendance updated for event: \(eventIndex) to: \(newAttended)")
                    } else {
                        print("iCloudSchedule: Local data is newer or equal (\(iCloudTimestamp) <= \(localTimestamp)), skipping update for event: \(eventIndex)")
                    }
                } else {
                    print("iCloudSchedule: Invalid or old data format for event: \(eventIndex). Skipping.")
                }
            } else {
                print("iCloudSchedule: No iCloud data found for event: \(eventIndex)")
            }
        } else {
            print("iCloudSchedule: ERROR - UIDevice identifierForVendor is nil, cannot process event: \(eventIndex)")
            return
        }
        print("iCloudSchedule: readAScheduleRecord completed for event: \(eventIndex)")
    }

    /// Detects old iCloud priority data format and migrates by overwriting with local data
    /// Checks for data that doesn't match the new format: {priority}:{uid}:{timestamp}
    /// If old format is detected, overwrites all iCloud data with current local data
    func detectAndMigrateOldPriorityData(){
        /*
        print("iCloudPriority: Starting detectAndMigrateOldPriorityData operation")
        
        if (checkForIcloud() == true){
            print("iCloudPriority: iCloud enabled, checking for old priority data format")
            
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                let bandNameHandle = bandNamesHandler()
                let bandNames = bandNameHandle.getBandNames()
                var oldFormatDetected = false
                
                print("iCloudPriority: Scanning \(bandNames.count) bands for old priority data format")
                
                // Check first few bands to detect old format
                let sampleSize = min(10, bandNames.count) // Check up to 10 bands as sample
                for i in 0..<sampleSize {
                    let bandName = bandNames[i]
                    let index = "bandName:" + bandName
                    let tempValue = String(NSUbiquitousKeyValueStore.default.string(forKey: index) ?? "")
                    
                    if (!tempValue.isEmpty && tempValue != "0") {
                        let tempData = tempValue.split(separator: ":")
                        
                        // Check if this is NOT the new format (should have exactly 3 parts)
                        if (tempData.count != 3) {
                            print("iCloudPriority: Old format detected for band: \(bandName) - format: \(tempValue) (has \(tempData.count) parts, expected 3)")
                            oldFormatDetected = true
                            break
                        } else {
                            // Verify the 3-part format is valid (priority:uid:timestamp)
                            if (tempData.count == 3) {
                                let priority = Int(tempData[0])
                                let uid = String(tempData[1])
                                let timestamp = Double(tempData[2])
                                
                                // Check if the format looks valid
                                if (priority == nil || uid.isEmpty || timestamp == nil) {
                                    print("iCloudPriority: Invalid 3-part format detected for band: \(bandName) - format: \(tempValue)")
                                    oldFormatDetected = true
                                    break
                                }
                            }
                        }
                    }
                }
                
                if (oldFormatDetected) {
                    print("iCloudPriority: Old priority data format detected! Migrating all data...")
                    print("iCloudPriority: Overwriting all iCloud priority data with current local data")
                    
                    // Overwrite all iCloud data with local data
                    self.writeAllPriorityData()
                    self.writeAllScheduleData()  // Also ensure schedule data is written during migration
                    
                    print("iCloudPriority: Migration completed - all iCloud priority and schedule data updated to new format")
                } else {
                    print("iCloudPriority: No old priority data format detected, no migration needed")
                }
            }
        } else {
            print("iCloudPriority: iCloud disabled, skipping old data detection")
        }
        
        print("iCloudPriority: detectAndMigrateOldPriorityData operation completed")
         */
    }

    /// Detects old iCloud schedule data format and migrates by overwriting with local data
    /// Checks for data that doesn't match the new format: {status}:{uid}:{timestamp}
    /// If old format is detected, overwrites all iCloud data with current local data
    func detectAndMigrateOldScheduleData(){
        /*
        print("iCloudSchedule: Starting detectAndMigrateOldScheduleData operation")
        if (checkForIcloud() == true){
            print("iCloudSchedule: iCloud enabled, checking for old schedule data format")
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                let attendedHandle = ShowsAttended()
                attendedHandle.loadShowsAttended()
                let showsAttendedArray = attendedHandle.getShowsAttended()
                var oldFormatDetected = false
                print("iCloudSchedule: Scanning \(showsAttendedArray.count) schedule records for old format")
                for (eventIndex, status) in showsAttendedArray {
                    let tempValue = String(NSUbiquitousKeyValueStore.default.string(forKey: "eventName:" + eventIndex) ?? "")
                    if (!tempValue.isEmpty && tempValue != "0") {
                        let tempData = tempValue.split(separator: ":")
                        if (tempData.count != 3) {
                            print("iCloudSchedule: Old format detected for event: \(eventIndex) - format: \(tempValue) (has \(tempData.count) parts, expected 3)")
                            oldFormatDetected = true
                            break
                        } else {
                            // Verify the 3-part format is valid (status:uid:timestamp)
                            if (tempData.count == 3) {
                                let status = String(tempData[0])
                                let uid = String(tempData[1])
                                let timestamp = Double(tempData[2])
                                if (status.isEmpty || uid.isEmpty || timestamp == nil) {
                                    print("iCloudSchedule: Invalid 3-part format detected for event: \(eventIndex) - format: \(tempValue)")
                                    oldFormatDetected = true
                                    break
                                }
                            }
                        }
                    }
                }
                if (oldFormatDetected) {
                    print("iCloudSchedule: Old schedule data format detected! Migrating all data...")
                    print("iCloudSchedule: Overwriting all iCloud schedule data with current local data")
                    self.writeAllScheduleData()
                    print("iCloudSchedule: Migration completed - all iCloud schedule data updated to new format")
                } else {
                    print("iCloudSchedule: No old schedule data format detected, no migration needed")
                }
            }
        } else {
            print("iCloudSchedule: iCloud disabled, skipping old schedule data detection")
        }
        print("iCloudSchedule: detectAndMigrateOldScheduleData operation completed")
        */
    }

    /// Purges iCloud KVS keys older than 3 years, or keys without a timestamp (old format)
    func purgeOldiCloudKeys() {
        print("KVS: Starting purgeOldiCloudKeys")
        let store = NSUbiquitousKeyValueStore.default
        let threeYearsAgo = Date().timeIntervalSince1970 - (3 * 365 * 24 * 60 * 60)
        let allEntries = store.dictionaryRepresentation
        var purgedCount = 0
        var keptCount = 0
        let totalCount = allEntries.count
        var keysToPurge: [String] = []
        var timestampedKeys: [(key: String, timestamp: Double)] = []
        var undatedKeys: [String] = []

        // First pass: normal purge for old/invalid keys
        for (key, value) in allEntries {
            if let valueString = value as? String {
                let parts = valueString.split(separator: ":")
                if parts.count == 3, let timestamp = Double(parts[2]) {
                    if timestamp < threeYearsAgo {
                        print("Purging iCloud key '\(key)' (timestamp: \(timestamp))")
                        store.removeObject(forKey: key)
                        purgedCount += 1
                    } else {
                        keptCount += 1
                        timestampedKeys.append((key, timestamp))
                    }
                } else {
                    // Old format or invalid, purge it
                    print("Purging iCloud key '\(key)' (no valid timestamp, parts: \(parts.count))")
                    store.removeObject(forKey: key)
                    purgedCount += 1
                    undatedKeys.append(key)
                }
            } else {
                keptCount += 1
                undatedKeys.append(key)
            }
        }
        store.synchronize()
        print("KVS: Total keys detected: \(totalCount), Purged: \(purgedCount), Kept: \(keptCount)")

        // Second pass: if still over 1000 keys, purge oldest 100
        let postPurgeEntries = store.dictionaryRepresentation
        let postPurgeCount = postPurgeEntries.count
        if postPurgeCount > 1000 {
            print("KVS: Over 1000 keys detected (\(postPurgeCount)). Purging oldest 100 keys.")
            // Rebuild timestamped/undated lists from current store
            var currentTimestamped: [(key: String, timestamp: Double)] = []
            var currentUndated: [String] = []
            for (key, value) in postPurgeEntries {
                if let valueString = value as? String {
                    let parts = valueString.split(separator: ":")
                    if parts.count == 3, let timestamp = Double(parts[2]) {
                        currentTimestamped.append((key, timestamp))
                    } else {
                        currentUndated.append(key)
                    }
                } else {
                    currentUndated.append(key)
                }
            }
            // Sort timestamped by oldest first
            currentTimestamped.sort { $0.timestamp < $1.timestamp }
            var keysPurgedThisRound: [String] = []
            // Purge up to 100 oldest timestamped keys
            for i in 0..<min(100, currentTimestamped.count) {
                let key = currentTimestamped[i].key
                store.removeObject(forKey: key)
                keysPurgedThisRound.append(key)
            }
            // If fewer than 100 timestamped, fill with undated
            if currentTimestamped.count < 100 {
                let needed = 100 - currentTimestamped.count
                for i in 0..<min(needed, currentUndated.count) {
                    let key = currentUndated[i]
                    store.removeObject(forKey: key)
                    keysPurgedThisRound.append(key)
                }
            }
            store.synchronize()
            print("KVS: Purged \(keysPurgedThisRound.count) keys in oldest-100 pass. Keys: \(keysPurgedThisRound)")
        }
    }

}

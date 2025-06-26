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
    
    /// Initializes the iCloudDataHandler class
    /// Sets up the handler for managing iCloud data synchronization
    init(){
        //print("iCloud: Initializing iCloudDataHandler")
    }
    
    /// Checks if iCloud is enabled and available for use
    /// Returns true if iCloud is enabled in user defaults, false otherwise
    func checkForIcloud()->Bool {
        print("iCloud: Starting checkForIcloud operation")
        
        UserDefaults.standard.synchronize()
        var status = false
        
        // Check if the iCloud key exists and get the value
        if let iCloudIndicator = UserDefaults.standard.object(forKey: "iCloud") as? String {
            let normalizedValue = iCloudIndicator.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            print("iCloud: Retrieved iCloud indicator from UserDefaults: '\(iCloudIndicator)' -> normalized: '\(normalizedValue)'")
            
            if normalizedValue == "YES" || normalizedValue == "TRUE" || normalizedValue == "1" {
                status = true
                print("iCloud: iCloud is enabled")
            } else {
                print("iCloud: iCloud is disabled (value: '\(normalizedValue)')")
            }
        } else {
            // Key doesn't exist or is not a string - check if it's a boolean
            if UserDefaults.standard.object(forKey: "iCloud") != nil {
                status = UserDefaults.standard.bool(forKey: "iCloud")
                print("iCloud: Retrieved iCloud boolean from UserDefaults: \(status)")
            } else {
                // This should not happen now that defaults are registered at app startup
                status = false
                print("iCloud: iCloud key not found in UserDefaults - this indicates setDefaults() wasn't called")
            }
        }
        
        print("iCloud: checkForIcloud completed with status: \(status)")
        return status
    }
    
    /// Writes all priority data for bands to iCloud
    /// Iterates through all band priority data and syncs it to iCloud storage
    func writeAllPriorityData(){
        print("iCloud: Starting writeAllPriorityData operation")
        
        if (checkForIcloud() == true){
            print("iCloud: Internet available and iCloud enabled, proceeding with data write")
            let priorityHandler = dataHandler()
            priorityHandler.refreshData()
            let priorityData = priorityHandler.getPriorityData()
            
            print("iCloud: Retrieved priority data with \(priorityData.count ?? 0) entries")
            
            if (priorityData != nil && priorityData.count > 0){
                print("iCloud: Writing \(priorityData.count) priority records to iCloud")
                for (bandName, priority) in priorityData {
                    print("iCloud: Processing priority record for band: \(bandName)")
                    writeAPriorityRecord(bandName: bandName, priority: priority)
                }
                NSUbiquitousKeyValueStore.default.synchronize()
                //writeLastiCloudDataWrite()
                print("iCloud: All priority data written and synchronized")
            } else {
                print("iCloud: No priority data to write")
            }
        } else {
            print("iCloud: Cannot write priority data - internet unavailable or iCloud disabled")
        }
        
        print("iCloud: writeAllPriorityData operation completed")
    }
    
    /// Writes a single priority record for a specific band to iCloud
    /// - Parameters:
    ///   - bandName: The name of the band
    ///   - priority: The priority value to store
    func writeAPriorityRecord(bandName: String, priority: Int){
        
        if (checkForIcloud() == true){
            print("iCloud: Starting writeAPriorityRecord for band: \(bandName)")
            
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                // Get the timestamp from local data handler or use current time
                let localDataHandler = dataHandler()
                var timestamp = localDataHandler.getPriorityLastChange(bandName)
                
                // If no valid timestamp exists, use current time in seconds since epoch
                if timestamp <= 0 {
                    timestamp = Date().timeIntervalSince1970
                }
                
                // ENFORCE: Always use current device UID and timestamp from local data
                let currentUid = UIDevice.current.identifierForVendor!.uuidString
                let timestampString = String(format: "%.0f", timestamp) // Format to remove decimals
                
                // Use format: priority:uid:timestamp for better conflict resolution
                let dataString = String(priority) + ":" + currentUid + ":" + timestampString
                print("iCloud: Writing priority record - bandName: \(bandName), priority: \(priority), uid: \(currentUid), timestamp: \(timestampString)")
                print("iCloud: Full dataString: \(dataString)")
                
                NSUbiquitousKeyValueStore.default.set(dataString, forKey: "bandName:" + bandName)
                print("iCloud: Priority record written for band: \(bandName)")
                NSUbiquitousKeyValueStore.default.synchronize()

            }
        }
    }
    

    /// Writes all schedule/attendance data to iCloud
    /// Syncs all attended shows data to iCloud storage
    func writeAllScheduleData(){
        /*
        print("iCloud: Starting writeAllScheduleData operation")
        
        if (checkForIcloud() == true){
            print("iCloud: iCloud enabled, proceeding with schedule data write")
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                let attendedHandle = ShowsAttended()
                attendedHandle.loadShowsAttended()
                let showsAttendedArray = attendedHandle.getShowsAttended();
                
                let uid = (UIDevice.current.identifierForVendor?.uuidString) ?? ""
                print("iCloud: Device UID: \(uid)")
                
                if (uid.isEmpty == false){
                    print("iCloud: Valid UID found, processing attended shows")
                    if (showsAttendedArray != nil && showsAttendedArray.isEmpty == false){
                        print("iCloud: Writing \(showsAttendedArray.count) schedule records to iCloud")
                        for eventIndex in showsAttendedArray {
                            print("iCloud: Processing schedule record for event: \(eventIndex.key)")
                            self.writeAScheduleRecord(eventIndex: eventIndex.key, status: eventIndex.value)
                        }
                        NSUbiquitousKeyValueStore.default.synchronize()
                        self.writeLastiCloudDataWrite()
                        print("iCloud: All schedule data written and synchronized")
                    } else {
                        print("iCloud: No attended shows data to write")
                    }
                } else {
                    print("iCloud: Invalid UID, cannot write schedule data")
                }
            }
        } else {
            print("iCloud: iCloud disabled, skipping schedule data write")
        }
        
        print("iCloud: writeAllScheduleData operation completed")
        */
    }
    
    /// Writes a single schedule record to iCloud
    /// - Parameters:
    ///   - eventIndex: The event identifier
    ///   - status: The attendance status
    func writeAScheduleRecord(eventIndex: String, status: String){
        /*
        if (checkForIcloud() == true){
            print("iCloud: Starting writeAScheduleRecord for event: \(eventIndex)")
            
            var dataString = status + ":" + UIDevice.current.identifierForVendor!.uuidString
            print("iCloud: Writing schedule record - eventIndex: \(eventIndex), dataString: \(dataString)")
            NSUbiquitousKeyValueStore.default.set(dataString, forKey: "eventName:" + eventIndex)
            writeLastiCloudDataWrite()
            
            print("iCloud: Schedule record written for event: \(eventIndex)")
        }
        */
    }
    
    /// Reads all priority data from iCloud and syncs to local storage
    /// Iterates through all bands and attempts to read their priority data from iCloud
    func readAllPriorityData(){
        print("iCloud: Starting readAllPriorityData operation")
        
        if (checkForIcloud() == true){
            print("iCloud: iCloud data not currently loading, proceeding with read")
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                iCloudDataisLoading = true;
                print("iCloud: Set iCloudDataisLoading to true")
                
                let bandNameHandle = bandNamesHandler()
                let bandNames = bandNameHandle.getBandNames()
                
                let priorityHandler = dataHandler()
                priorityHandler.refreshData()
                
                print("iCloud: Reading priority data for \(bandNames.count) bands")
                
                for bandName in bandNames{
                    print("iCloud: Processing priority read for band: \(bandName)")
                    self.readAPriorityRecord(bandName: bandName, priorityHandler: priorityHandler)
                }
                
                iCloudDataisLoading = false;
                print("iCloud: Set iCloudDataisLoading to false, read operation completed")
            }
        } else {
            print("iCloud: iCloud data currently loading, skipping read operation")
        }
        
        print("iCloud: readAllPriorityData operation completed")
    }
    
    /// Reads a single priority record from iCloud for a specific band
    /// - Parameters:
    ///   - bandName: The name of the band to read
    ///   - priorityHandler: The data handler for priority operations
    func readAPriorityRecord(bandName: String, priorityHandler: dataHandler){
        
        if (checkForIcloud() == true){
            print("iCloud: Starting readAPriorityRecord for band: \(bandName)")
            
            let index = "bandName:" + bandName
            let tempValue = String(NSUbiquitousKeyValueStore.default.string(forKey: index) ?? "0")
            let currentUid = UIDevice.current.identifierForVendor!.uuidString
            
            print("iCloud: Retrieved value from iCloud: \(tempValue) for key: \(index)")
            
            if (tempValue != nil && tempValue.isEmpty == false){
                let tempData = tempValue.split(separator: ":")
                
                // Handle new format: priority:uid:timestamp (3 parts)
                if (tempData.isEmpty == false && tempData.count == 3){
                    let newPriority = tempData[0]
                    let uidValue = String(tempData[1])
                    let timestampValue = Double(tempData[2]) ?? 0
                    let currentPriority = priorityHandler.getPriorityData(bandName)
                    
                    print("iCloud: Parsed priority data (new format) - newPriority: \(newPriority), uidValue: \(uidValue), timestamp: \(timestampValue), currentPriority: \(currentPriority)")
                    
                    // RULE 1: Never overwrite local data if UID matches current device
                    if (uidValue == currentUid){
                        print("iCloud: UID \(uidValue) matches current device (\(currentUid)), never overwriting local data for band: \(bandName)")
                        return
                    }
                    
                    // RULE 2: Only update if iCloud data is newer than local data
                    let localTimestamp = priorityHandler.getPriorityLastChange(bandName)
                    
                    print("iCloud: Comparing timestamps - localTimestamp: \(localTimestamp), iCloudTimestamp: \(timestampValue)")
                    
                    if (localTimestamp > 0){
                        // Only update if iCloud timestamp is NEWER (>) than local timestamp
                        if (timestampValue > localTimestamp){
                            print("iCloud: iCloud data is newer (\(timestampValue) > \(localTimestamp)), updating local priority for band: \(bandName)")
                            priorityHandler.addPriorityData(bandName, priority: Int(newPriority) ?? 0)
                            print("iCloud: Priority updated for band: \(bandName) to: \(newPriority)")
                        } else {
                            print("iCloud: Local data is newer or equal (\(timestampValue) <= \(localTimestamp)), skipping update for band: \(bandName)")
                        }
                    } else {
                        // No local timestamp exists, safe to update with iCloud data
                        print("iCloud: No local timestamp found, updating with iCloud data for band: \(bandName)")
                        priorityHandler.addPriorityData(bandName, priority: Int(newPriority) ?? 0)
                        print("iCloud: Priority updated for band: \(bandName) to: \(newPriority)")
                    }
                } else {
                    print("iCloud: Invalid data format for band: \(bandName) - expected 3 parts (priority:uid:timestamp), got \(tempData.count) parts. Ignoring old format.")
                }
            } else {
                print("iCloud: No iCloud data found for band: \(bandName)")
            }
            
            print("iCloud: readAPriorityRecord completed for band: \(bandName)")
        }
    }
    
    /// Reads all schedule/attendance data from iCloud
    /// Syncs all attended shows data from iCloud to local storage
    func readAllScheduleData(){
        /*
        if (checkForIcloud() == true){
            print("iCloud: Starting readAllScheduleData operation")

            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                print("iCloud: Initializing handlers for schedule data read")
                
                let scheduleHandle = scheduleHandler()
                scheduleHandle.buildTimeSortedSchedulingData();
                
                let bandNameHandle = bandNamesHandler()
                let bandNames = bandNameHandle.getBandNames()
                
                let attendedHandle = ShowsAttended()
                attendedHandle.loadShowsAttended()
                
                let priorityHandler = dataHandler()
                priorityHandler.refreshData()
                
                let scheduleData = scheduleHandle.getBandSortedSchedulingData()
                
                print("iCloud: Processing schedule data for \(scheduleData.count) bands")
                
                if (scheduleData.count > 0){
                    for bandName in scheduleData.keys {
                        print("iCloud: Processing schedule data for band: \(bandName)")
                        if (scheduleData.isEmpty == false){
                            for timeIndex in scheduleData[bandName]!.keys {
                                if scheduleData[bandName] != nil {
                                    if (scheduleData[bandName]![timeIndex] != nil){
                                        if (scheduleData[bandName]![timeIndex]![locationField] != nil){
                                            let location = scheduleData[bandName]![timeIndex]![locationField]!
                                            let startTime = scheduleData[bandName]![timeIndex]![startTimeField]!
                                            let eventType = scheduleData[bandName]![timeIndex]![typeField]!
                                            
                                            print("iCloud: Reading schedule record for band: \(bandName), location: \(location), startTime: \(startTime)")
                                            
                                            self.readAScheduleRecord(bandName: bandName,location: location,startTime: startTime,eventType: eventType, attendedHandle: attendedHandle, bandNames: bandNames)
                                        }
                                    }
                                }
                            }
                        }
                        if (bandNames.contains(bandName) == false){
                            print("iCloud: Band not in band names list, reading priority: \(bandName)")
                            self.readAPriorityRecord(bandName: bandName, priorityHandler: priorityHandler)
                        }
                    }
                } else {
                    print("iCloud: No schedule data found to process")
                }
                
                print("iCloud: readAllScheduleData operation completed")
            }
        }
         */
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
        /*
        if (checkForIcloud() == true){
            print("iCloud: Starting readAScheduleRecord for band: \(bandName), location: \(location), startTime: \(startTime)")
            
            let eventYearString = String(eventYear)
            
            var eventIndex = "eventName:" + bandName + ":"
            eventIndex = eventIndex + location + ":"
            eventIndex = eventIndex + startTime + ":"
            eventIndex = eventIndex + eventType + ":"
            eventIndex = eventIndex + eventYearString
            
            print("iCloud: Constructed event index: \(eventIndex)")
            
            let tempValue = String(NSUbiquitousKeyValueStore.default.string(forKey: eventIndex) ?? "0")
            let currentUid = UIDevice.current.identifierForVendor!.uuidString
            
            print("iCloud: Retrieved value from iCloud: \(tempValue) for eventIndex: \(eventIndex)")
            
            if (tempValue != nil && tempValue.isEmpty == false && eventIndex != "0"){
                let tempData = tempValue.split(separator: ":")
                if (tempData.isEmpty == false && tempData.count == 2){
                    let newAttended = String(tempData[0])
                    let uidValue = tempData[1]
                    
                    print("iCloud: Parsed attendance data - newAttended: \(newAttended), uidValue: \(uidValue)")
                    
                    let currentAttended = attendedHandle.getShowAttendedStatusUserFriendly(band: bandName, location: location, startTime: startTime, eventType: eventType, eventYearString: eventYearString)
                    
                    print("iCloud: Current local attendance status: \(currentAttended ?? "nil")")
                    
                    if (uidValue != currentUid || currentAttended == nil){
                        var lastScheduleDataWrite = attendedHandle.readLastScheduleDataWrite()
                        var lastiCloudDataWrite = readLastiCloudDataWrite()
                        
                        print("iCloud: Comparing timestamps - lastScheduleDataWrite: \(lastScheduleDataWrite), lastiCloudDataWrite: \(lastiCloudDataWrite)")
                        
                        if (lastiCloudDataWrite >= lastScheduleDataWrite){
                            print("iCloud: iCloud data is newer or equal, updating local attendance")
                            attendedHandle.addShowsAttendedWithStatus(band: bandName, location: location, startTime: startTime, eventType: eventType, eventYearString: eventYearString, status: newAttended)
                            print("iCloud: Attendance updated for event: \(eventIndex) to: \(newAttended)")
                        } else {
                            print("iCloud: Local data is newer, skipping update for event: \(eventIndex)")
                        }
                    } else {
                        print("iCloud: Same UID and existing attendance found, skipping update for event: \(eventIndex)")
                    }
                } else {
                    print("iCloud: Invalid data format for event: \(eventIndex)")
                }
            } else {
                print("iCloud: No iCloud data found for event: \(eventIndex)")
            }
            
            print("iCloud: readAScheduleRecord completed for event: \(eventIndex)")
        }
        */
    }

        /// Detects old iCloud priority data format and migrates by overwriting with local data
    /// Checks for data that doesn't match the new format: {priority}:{uid}:{timestamp}
    /// If old format is detected, overwrites all iCloud data with current local data
    func detectAndMigrateOldPriorityData(){
        print("iCloud: Starting detectAndMigrateOldPriorityData operation")
        
        if (checkForIcloud() == true){
            print("iCloud: iCloud enabled, checking for old priority data format")
            
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                let bandNameHandle = bandNamesHandler()
                let bandNames = bandNameHandle.getBandNames()
                var oldFormatDetected = false
                
                print("iCloud: Scanning \(bandNames.count) bands for old priority data format")
                
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
                            print("iCloud: Old format detected for band: \(bandName) - format: \(tempValue) (has \(tempData.count) parts, expected 3)")
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
                                    print("iCloud: Invalid 3-part format detected for band: \(bandName) - format: \(tempValue)")
                                    oldFormatDetected = true
                                    break
                                }
                            }
                        }
                    }
                }
                
                if (oldFormatDetected) {
                    print("iCloud: Old priority data format detected! Migrating all data...")
                    print("iCloud: Overwriting all iCloud priority data with current local data")
                    
                    // Overwrite all iCloud data with local data
                    self.writeAllPriorityData()
                    
                    print("iCloud: Migration completed - all iCloud priority data updated to new format")
                } else {
                    print("iCloud: No old priority data format detected, no migration needed")
                }
            }
        } else {
            print("iCloud: iCloud disabled, skipping old data detection")
        }
        
        print("iCloud: detectAndMigrateOldPriorityData operation completed")
    }

}

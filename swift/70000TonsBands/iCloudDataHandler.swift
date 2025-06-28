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
                print("iCloudPriority: Writing \(priorityData.count) priority records to iCloud")
                for (bandName, priority) in priorityData {
                    print("iCloudPriority: Processing priority record for band: \(bandName)")
                    writeAPriorityRecord(bandName: bandName, priority: priority)
                }
                NSUbiquitousKeyValueStore.default.synchronize()
                //writeLastiCloudDataWrite()
                print("iCloudPriority: All priority data written and synchronized")
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
                let currentUid = UIDevice.current.identifierForVendor!.uuidString
                let timestampString = String(format: "%.0f", timestamp) // Format to remove decimals
                
                // Use format: priority:uid:timestamp for better conflict resolution
                let dataString = String(priority) + ":" + currentUid + ":" + timestampString
                print("iCloudPriority: Writing priority record - bandName: \(bandName), priority: \(priority), uid: \(currentUid), timestamp: \(timestampString)")
                print("iCloudPriority: Full dataString: \(dataString)")
                
                NSUbiquitousKeyValueStore.default.set(dataString, forKey: "bandName:" + bandName)
                print("iCloudPriority: Priority record written for band: \(bandName)")
                NSUbiquitousKeyValueStore.default.synchronize()

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
            let dataString = statusOnly + ":" + UIDevice.current.identifierForVendor!.uuidString + ":" + timestamp
            print("iCloudSchedule: Writing schedule record - eventIndex: \(eventIndex), dataString: \(dataString)")
            NSUbiquitousKeyValueStore.default.set(dataString, forKey: "eventName:" + eventIndex)
            print("iCloudSchedule: Schedule record written for event: \(eventIndex)")
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }
    
    /// Reads all priority data from iCloud and syncs to local storage
    /// Iterates through all bands and attempts to read their priority data from iCloud
    func readAllPriorityData(){
        print("iCloudPriority: Starting readAllPriorityData operation")
        
        if (checkForIcloud() == true){
            print("iCloudPriority: iCloud data not currently loading, proceeding with read")
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                iCloudDataisLoading = true;
                print("iCloudPriority: Set iCloudDataisLoading to true")
                
                let bandNameHandle = bandNamesHandler()
                let bandNames = bandNameHandle.getBandNames()
                
                let priorityHandler = dataHandler()
                priorityHandler.refreshData()
                
                print("iCloudPriority: Reading priority data for \(bandNames.count) bands")
                
                for bandName in bandNames{
                    print("iCloudPriority: Processing priority read for band: \(bandName)")
                    self.readAPriorityRecord(bandName: bandName, priorityHandler: priorityHandler)
                }
                
                iCloudDataisLoading = false;
                print("iCloudPriority: Set iCloudDataisLoading to false, read operation completed")
            }
        } else {
            print("iCloudPriority: iCloud data currently loading, skipping read operation")
        }
        
        print("iCloudPriority: readAllPriorityData operation completed")
    }
    
    /// Reads a single priority record from iCloud for a specific band
    /// - Parameters:
    ///   - bandName: The name of the band to read
    ///   - priorityHandler: The data handler for priority operations
    func readAPriorityRecord(bandName: String, priorityHandler: dataHandler){
        
        if (checkForIcloud() == true){
            print("iCloudPriority: Starting readAPriorityRecord for band: \(bandName)")
            
            let index = "bandName:" + bandName
            let tempValue = String(NSUbiquitousKeyValueStore.default.string(forKey: index) ?? "0")
            let currentUid = UIDevice.current.identifierForVendor!.uuidString
            
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
                            priorityHandler.addPriorityDataWithTimestamp(bandName, priority: Int(newPriority) ?? 0, timestamp: timestampValue)
                            print("iCloudPriority: Priority updated for band: \(bandName) to: \(newPriority)")
                        } else {
                            print("iCloudPriority: Local data is newer or equal (\(timestampValue) <= \(localTimestamp)), skipping update for band: \(bandName)")
                        }
                    } else {
                        // No local timestamp exists, safe to update with iCloud data
                        print("iCloudPriority: No local timestamp found, updating with iCloud data for band: \(bandName)")
                        priorityHandler.addPriorityDataWithTimestamp(bandName, priority: Int(newPriority) ?? 0, timestamp: timestampValue)
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
                    priorityHandler.addPriorityDataWithTimestamp(bandName, priority: Int(newPriority) ?? 0, timestamp: timestampValue)
                    print("iCloudPriority: Priority updated for band: \(bandName) to: \(newPriority) (from old format)")

                    // Now update iCloud with the new format (priority:uid:currentTime)
                    let currentUid = UIDevice.current.identifierForVendor!.uuidString
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
            
            print("iCloudPriority: readAPriorityRecord completed for band: \(bandName)")
        }
    }
    
    /// Reads all schedule/attendance data from iCloud
    /// Syncs all attended shows data from iCloud to local storage
    var iCloudScheduleDataisLoading = false;
    func readAllScheduleData(){
        if (checkForIcloud() == true){
            print("iCloudSchedule: Starting readAllScheduleData operation")

            iCloudScheduleDataisLoading = true;
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                print("iCloudSchedule: Initializing handlers for schedule data read")
                
                let scheduleHandle = scheduleHandler()
                scheduleHandle.buildTimeSortedSchedulingData();
                
                let bandNameHandle = bandNamesHandler()
                let bandNames = bandNameHandle.getBandNames()
                
                let attendedHandle = ShowsAttended()
                attendedHandle.loadShowsAttended()
                
                let priorityHandler = dataHandler()
                priorityHandler.refreshData()
                
                let scheduleData = scheduleHandle.getBandSortedSchedulingData()
                
                print("iCloudSchedule: Processing schedule data for \(scheduleData.count) bands")
                
                if (scheduleData.count > 0){
                    for bandName in scheduleData.keys {
                        print("iCloudSchedule: Processing schedule data for band: \(bandName)")
                        if (scheduleData.isEmpty == false){
                            for timeIndex in scheduleData[bandName]!.keys {
                                if scheduleData[bandName] != nil {
                                    if (scheduleData[bandName]![timeIndex] != nil){
                                        if (scheduleData[bandName]![timeIndex]![locationField] != nil){
                                            let location = scheduleData[bandName]![timeIndex]![locationField]!
                                            let startTime = scheduleData[bandName]![timeIndex]![startTimeField]!
                                            let eventType = scheduleData[bandName]![timeIndex]![typeField]!
                                            
                                            print("iCloudSchedule: Reading schedule record for band: \(bandName), location: \(location), startTime: \(startTime)")
                                            
                                            self.readAScheduleRecord(bandName: bandName,location: location,startTime: startTime,eventType: eventType, attendedHandle: attendedHandle, bandNames: bandNames)
                                        }
                                    }
                                }
                            }
                        }
                        if (bandNames.contains(bandName) == false){
                            print("iCloudSchedule: Band not in band names list, reading priority: \(bandName)")
                            self.readAPriorityRecord(bandName: bandName, priorityHandler: priorityHandler)
                        }
                    }
                } else {
                    print("iCloudSchedule: No schedule data found to process")
                }
                
                print("iCloudSchedule: readAllScheduleData operation completed")
                // Ensure local attended data is saved to disk for offline use
                attendedHandle.saveShowsAttended()
                self.iCloudScheduleDataisLoading = false;
            }
        }
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
        let tempValue = String(NSUbiquitousKeyValueStore.default.string(forKey: eventIndex) ?? "0")
        let currentUid = UIDevice.current.identifierForVendor!.uuidString
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
        print("iCloudSchedule: readAScheduleRecord completed for event: \(eventIndex)")
    }

    /// Detects old iCloud priority data format and migrates by overwriting with local data
    /// Checks for data that doesn't match the new format: {priority}:{uid}:{timestamp}
    /// If old format is detected, overwrites all iCloud data with current local data
    func detectAndMigrateOldPriorityData(){
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
                    
                    print("iCloudPriority: Migration completed - all iCloud priority data updated to new format")
                } else {
                    print("iCloudPriority: No old priority data format detected, no migration needed")
                }
            }
        } else {
            print("iCloudPriority: iCloud disabled, skipping old data detection")
        }
        
        print("iCloudPriority: detectAndMigrateOldPriorityData operation completed")
    }

    /// Detects old iCloud schedule data format and migrates by overwriting with local data
    /// Checks for data that doesn't match the new format: {status}:{uid}:{timestamp}
    /// If old format is detected, overwrites all iCloud data with current local data
    func detectAndMigrateOldScheduleData(){
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
    }

}

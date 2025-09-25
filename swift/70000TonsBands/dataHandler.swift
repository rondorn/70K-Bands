//
//  dataHandler.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/7/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//
//  LEGACY CLASS - Only used for priority data migration
//  All priority functionality has been moved to PriorityManager (Core Data)
//

import Foundation

/// Legacy data handler class - DEPRECATED
/// This class is only kept for migration purposes to read existing priority files.
/// All new priority operations should use PriorityManager instead.
class dataHandler {
    
    // MARK: - Legacy Priority Data (Migration Only)
    private var bandPriorityStorage = [String:Int]()
    private var bandPriorityTimestamps = [String:Double]()
    
    init(){
        // Only load data if needed for migration
        loadLegacyDataForMigration()
    }
    
    /// Loads legacy priority data from file for migration purposes only
    private func loadLegacyDataForMigration(){
        print("[LEGACY] Loading priority data for migration purposes only")
        let fileData = readFile(dateWinnerPassed: "")
        bandPriorityStorage = fileData
    }
    
    /// MIGRATION ONLY: Returns all priority data for migration to Core Data
    /// - Returns: Dictionary mapping band names to their priority values
    func getPriorityData() -> [String:Int]{
        print("[LEGACY] getPriorityData called - this should only be used for migration")
        return bandPriorityStorage
    }
    
    /// MIGRATION ONLY: Returns the last change timestamp for a band's priority data
    /// - Parameter bandName: The name of the band
    /// - Returns: The timestamp of the last change, or 0 if not found
    func getPriorityLastChange (_ bandname:String) -> Double {
        print("[LEGACY] getPriorityLastChange called for \(bandname) - this should only be used for migration")
        var timestamp = 0.0
        if let value = bandPriorityTimestamps[bandname] {
            timestamp = value
        }
        return timestamp
    }
    
    /// DEPRECATED: Clears cached data - kept for compatibility
    /// CRITICAL: Priority data cache is NEVER cleared - it represents user preferences
    func clearCachedData(){
        print("[LEGACY] clearCachedData called - this is deprecated, use PriorityManager instead")
        print("🛡️ PROTECTED: Priority data cache is NEVER cleared - user preferences are preserved")
        
        // DO NOT clear priority data - it represents user preferences that should persist
        // The legacy cache clearing is disabled to prevent data loss during year changes
        print("🛡️ PROTECTED: bandPriorityStorageCache, bandPriorityStorage, and bandPriorityTimestamps are preserved")
        
        // Only clear non-priority caches if any exist
        // Priority data must be preserved across all year changes
    }
    
    // MARK: - Legacy File Reading (Migration Only)
    
    /// Reads the priority data file from disk for migration purposes
    private func readFile(dateWinnerPassed : String) -> [String:Int]{
        print("[LEGACY] Loading bandPriorityStorage data from file for migration")
        var localBandPriorityStorage = [String:Int]()
        
        if let data = try? String(contentsOf: storageFile, encoding: String.Encoding.utf8) {
            let dataArray = data.components(separatedBy: "\n")
            for record in dataArray {
                let element = record.components(separatedBy: ":")
                
                // Handle new format: bandName:priority:timestamp (3 parts)
                if element.count == 3 {
                    let priorityString = element[1].replacingOccurrences(of: "\n", with: "", options: NSString.CompareOptions.literal, range: nil)
                    let timestampString = element[2].replacingOccurrences(of: "\n", with: "", options: NSString.CompareOptions.literal, range: nil)
                    
                    let priority = Int(priorityString) ?? 0
                    let timestamp = Double(timestampString) ?? 0.0
                    
                    print("[LEGACY] Reading priority \(element[0]) - \(priorityString):\(timestampString)")
                    
                    localBandPriorityStorage[element[0]] = priority
                    bandPriorityTimestamps[element[0]] = timestamp
                }
                // Handle old format: bandName:priority (2 parts) for backward compatibility
                else if element.count == 2 {
                    let priorityString = element[1].replacingOccurrences(of: "\n", with: "", options: NSString.CompareOptions.literal, range: nil)
                    let priority = Int(priorityString) ?? 0
                    
                    print("[LEGACY] Reading priority (old format) \(element[0]) - \(priorityString)")
                    
                    localBandPriorityStorage[element[0]] = priority
                    // No timestamp available in old format
                    bandPriorityTimestamps[element[0]] = 0.0
                }
            }
        }
        
        return localBandPriorityStorage
    }
    
    // MARK: - Non-Priority Functionality (If Any)
    
    /// Placeholder for schedule data functionality - currently empty
    func readAllScheduleData() {
        print("[LEGACY] readAllScheduleData called - functionality may be moved elsewhere")
        // After schedule data is loaded and parsed:
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("ScheduleDataReady"), object: nil)
        }
    }
}
//
//  firebaseEventDataWrite.swift
//  70K Bands
//
//  Created by Ron Dorn on 3/19/19.
//  Copyright © 2019 Ron Dorn. All rights reserved.
//

import Foundation
import Firebase

class firebaseEventDataWrite {
    
    var ref: DatabaseReference?
    var eventCompareFile = "eventCompare.data"
    var firebaseShowsAttendedArray = [String : String]();
    var schedule = scheduleHandler.shared
    let attended = ShowsAttended()
    let variableStoreHandle = variableStore();
    
    // Use SQLite AttendanceManager to read attendance data
    let attendanceManager = SQLiteAttendanceManager.shared
    
    init(){
    }

    private func ensureReference() -> DatabaseReference? {
        if ref == nil {
            ref = FirebaseConnectionHelper.databaseReference()
        }
        return ref
    }
    
    func loadCompareFile()->[String:String]{
        do {
            print ("Staring loadedData")
            firebaseShowsAttendedArray = variableStoreHandle.readDataFromDisk(fileName: eventCompareFile) ?? [String : String]()
            print ("Finished loadedData \(firebaseShowsAttendedArray)")
        } catch {
            print("Couldn't read file.")
        }
        
        return firebaseShowsAttendedArray
    }
    
    /// Sanitizes strings for use as Firebase database path components  
    /// Firebase paths cannot contain: . # $ [ ] / ' " \ and control characters
    private func sanitizeForFirebase(_ input: String) -> String {
        return input
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "#", with: "_")
            .replacingOccurrences(of: "$", with: "_")
            .replacingOccurrences(of: "[", with: "_")
            .replacingOccurrences(of: "]", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "'", with: "_")
            .replacingOccurrences(of: "\"", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            // Remove control characters
            .components(separatedBy: .controlCharacters).joined()
            // Trim whitespace
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Gets sanitized identifier for an event from SQLite, fallback to computing it
    private func getSanitizedIdentifierForEvent(_ originalIndex: String) -> String {
        // SQLite doesn't store sanitized identifiers - compute it directly
        // This is more efficient than storing redundant data
        return sanitizeForFirebase(originalIndex)
    }
    /// Parses attendance storage keys (band names may contain colons; time is hour:min).
    private struct ParsedAttendanceKey {
        let band: String
        let location: String
        let startTime: String
        let eventType: String
        let yearPlain: String
        let scheduleDaySuffix: String?
    }
    
    private func parseAttendanceStorageKey(_ index: String) -> ParsedAttendanceKey? {
        let parts = index.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 6 else { return nil }
        
        let last = parts[parts.count - 1]
        let yearPlain: String
        let scheduleDaySuffix: String?
        if let separatorRange = last.range(of: "__") {
            yearPlain = String(last[..<separatorRange.lowerBound])
            scheduleDaySuffix = String(last[separatorRange.upperBound...])
        } else {
            yearPlain = last
            scheduleDaySuffix = nil
        }
        
        let eventType = parts[parts.count - 2]
        let startTime = parts[parts.count - 4] + ":" + parts[parts.count - 3]
        let location = parts[parts.count - 5]
        let band = parts[0..<(parts.count - 5)].joined(separator: ":")
        return ParsedAttendanceKey(
            band: band,
            location: location,
            startTime: startTime,
            eventType: eventType,
            yearPlain: yearPlain,
            scheduleDaySuffix: scheduleDaySuffix
        )
    }
    
    private func buildEventBatchEntry(index: String, status: String) -> (sanitizedKey: String, payload: [String: Any])? {
        guard let parsed = parseAttendanceStorageKey(index) else {
            print("🔥 firebase EVENT_WRITE: ⚠️ Skipping invalid index format: \(index)")
            return nil
        }
        
        let timeParts = parsed.startTime.split(separator: ":", maxSplits: 1).map(String.init)
        let startTimeHour = timeParts.first ?? ""
        let startTimeMin = timeParts.count > 1 ? timeParts[1] : ""
        let sanitizedIndex = sanitizeForFirebase(index)
        
        var payload: [String: Any] = [
            "originalIdentifier": index,
            "sanitizedKey": sanitizedIndex,
            "bandName": parsed.band,
            "location": parsed.location,
            "startTimeHour": startTimeHour,
            "startTimeMin": startTimeMin,
            "eventType": parsed.eventType,
            "eventYear": parsed.yearPlain,
            "status": status
        ]
        if let scheduleDay = parsed.scheduleDaySuffix, !scheduleDay.isEmpty {
            payload["scheduleDay"] = scheduleDay
        }
        return (sanitizedIndex, payload)
    }
            
    func writeEvent(index: String, status: String){
        
        print("🔥 firebase EVENT_WRITE: writeEvent() called for index: \(index), status: \(status)")
        
        guard let parsed = parseAttendanceStorageKey(index) else {
            print("🔥 firebase EVENT_WRITE: ❌ ERROR - Invalid index format: \(index)")
            return
        }
        
        let timeParts = parsed.startTime.split(separator: ":", maxSplits: 1).map(String.init)
        let startTimeHour = timeParts.first ?? ""
        let startTimeMin = timeParts.count > 1 ? timeParts[1] : ""
        
        print("🔥 firebase EVENT_WRITE: Parsed - Band: \(parsed.band), Location: \(parsed.location), Time: \(parsed.startTime), Type: \(parsed.eventType), Year: \(parsed.yearPlain)")
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            
            print("🔥 firebase EVENT_WRITE: Background write started for \(parsed.band)")
            
            // Check if Firebase reference is initialized
            guard let firebaseRef = self.ensureReference() else {
                print("⚠️ [FIREBASE_EVENT] Cannot write event data: Firebase reference not initialized, skipping analytics")
                FirebaseWriteMonitor.shared.recordWriteFailure(context: "event_ref_nil:\(index)")
                return
            }
            
            self.firebaseShowsAttendedArray = self.loadCompareFile();
            
            let uid = (UIDevice.current.identifierForVendor?.uuidString)!
            
            // Get sanitized identifier from SQLite, fallback to computation
            let sanitizedIndex = self.sanitizeForFirebase(index)
            print("🔥 firebase EVENT_WRITE: Sanitized index: \(sanitizedIndex)")
            
            let firebasePath = "showData/\(uid)/\(parsed.yearPlain)/\(sanitizedIndex)"
            print("🔥 firebase EVENT_WRITE: Writing to path: \(firebasePath)")
            
            var payload: [String: Any] = [
                "originalIdentifier": index,
                "sanitizedKey": sanitizedIndex,
                "bandName": parsed.band,
                "location": parsed.location,
                "startTimeHour": startTimeHour,
                "startTimeMin": startTimeMin,
                "eventType": parsed.eventType,
                "status": status
            ]
            if let scheduleDay = parsed.scheduleDaySuffix, !scheduleDay.isEmpty {
                payload["scheduleDay"] = scheduleDay
            }
            
            firebaseRef.child("showData/").child(uid).child(parsed.yearPlain).child(sanitizedIndex).setValue(payload){
                    (error:Error?, ref:DatabaseReference) in
                    if let error = error {
                        print("🔥 firebase EVENT_WRITE: ❌ Writing firebase event data could not be saved: \(error)")
                        FirebaseWriteMonitor.shared.recordWriteFailure(context: "event:\(index)")
                    } else {
                        print("🔥 firebase EVENT_WRITE: ✅ Writing firebase event data saved successfully for \(parsed.band)!")
                        FirebaseWriteMonitor.shared.recordWriteSuccess(context: "event:\(index)")
                        self.firebaseShowsAttendedArray[index] = status
                        self.variableStoreHandle.storeDataToDisk(data: self.firebaseShowsAttendedArray, fileName: self.eventCompareFile)
                        FirebaseConnectionHelper.goOffline(reason: "event_single_write_complete")
                    }
                }
            
        }
    }

    func writeData (){
        
        print("🔥 firebase EVENT_WRITE: writeData() called - Starting event data write process")
        print("🔥 firebase EVENT_WRITE: inTestEnvironment = \(inTestEnvironment)")
        
        guard FirebaseWriteMonitor.shared.shouldRunShowSync() else {
            print("⏭️ firebase EVENT_WRITE: No pending show sync — skipping showData upload")
            return
        }
        
        // Check if Firebase reference is initialized
        guard ensureReference() != nil else {
            print("⚠️ [FIREBASE_EVENT] Firebase reference not initialized, skipping event analytics reporting")
            return
        }
        
        if (inTestEnvironment == false){
            print("🔥 firebase EVENT_WRITE: Not in test environment, proceeding with write")
            DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
                
                print("🔥 firebase EVENT_WRITE: Background queue started")
                self.firebaseShowsAttendedArray = self.loadCompareFile();
                print("🔥 firebase EVENT_WRITE: Loaded compare file with \(self.firebaseShowsAttendedArray.count) entries")
                
                let uid = (UIDevice.current.identifierForVendor?.uuidString)!
                print("🔥 firebase EVENT_WRITE: Device UID = \(uid)")
                
                if (uid.isEmpty == false){
                    print("🔥 firebase EVENT_WRITE: UID is valid, getting attended events from SQLite")
                    
                    // Use pointer Current::eventYear — never UI browse year or calendar fallback.
                    let storageYear = FirebaseConnectionHelper.firebaseStorageEventYear(maxWaitSeconds: 15)
                    guard storageYear > 2000 else {
                        print("🔥 firebase EVENT_WRITE: ❌ BLOCKED - pointer Current event year unavailable")
                        return
                    }
                    let currentYear = storageYear
                    print("🔥 firebase EVENT_WRITE: Filtering for pointer storage year: \(currentYear) (uiEventYear=\(eventYear))")
                    
                    // Read attendance data from SQLite instead of old file system
                    let attendanceData = self.attendanceManager.getAllAttendanceDataByIndex()
                    print("🔥 firebase EVENT_WRITE: Found \(attendanceData.count) total attendance records in SQLite")
                    
                    // Convert SQLite format to format expected by Firebase write code
                    // SQLite format: [index: ["status": Int, "lastModified": Double]]
                    // Expected format: [index: "statusValue"]
                    // FILTER: Only include events for the current year
                    // NOTE: eventYear is parsed from the index string (format: "bandName:location:time:eventType:year")
                    var showsAttendedArray: [String: String] = [:]
                    var filteredOutCount = 0
                    
                    for (index, data) in attendanceData {
                        // Parse year from index string (format: "bandName:location:time:eventType:year")
                        let indexComponents = index.split(separator: ":")
                        guard indexComponents.count >= 5 else {
                            print("🔥 firebase EVENT_WRITE: ⚠️ Skipping invalid index format: \(index)")
                            filteredOutCount += 1
                            continue
                        }
                        
                        // Extract year from index (last component)
                        let yearString = String(indexComponents[indexComponents.count - 1])
                        guard let recordYear = Int(yearString), recordYear == currentYear else {
                            filteredOutCount += 1
                            continue
                        }
                        
                        // Filter by year - only include current year
                        if let status = data["status"] as? Int {
                            // Convert status to EVENT status string (not band priority)
                            // Event statuses: sawAll, sawSome, sawNone
                            let statusString: String
                            switch status {
                            case 1: statusString = sawSomeStatus  // Will Attend Some -> "sawSome"
                            case 2: statusString = sawAllStatus   // Will Attend / Attended -> "sawAll"
                            case 3: statusString = sawNoneStatus  // Won't Attend -> "sawNone"
                            default: statusString = sawNoneStatus // Unknown defaults to sawNone
                            }
                            showsAttendedArray[index] = statusString
                        }
                    }
                    print("🔥 firebase EVENT_WRITE: Filtered to \(showsAttendedArray.count) events for year \(currentYear) (excluded \(filteredOutCount) from other years)")
                    
                    guard showsAttendedArray.isEmpty == false else {
                        print("⏭️ firebase EVENT_WRITE: No show attendance for pointer year \(currentYear) — skipping showData upload")
                        return
                    }
                    
                    self.schedule.buildTimeSortedSchedulingData();
                    print("🔥 firebase EVENT_WRITE: Built time-sorted schedule data")
                    
                    let scheduleCount = self.schedule.getBandSortedSchedulingData().count
                    print("🔥 firebase EVENT_WRITE: Schedule data count = \(scheduleCount)")
                    
                    if (scheduleCount > 0){
                        let forceFullShowSync = FirebaseWriteMonitor.shared.hasPendingShowChanges()
                        if forceFullShowSync {
                            print("🔥 firebase EVENT_WRITE: Pending show changes — syncing \(showsAttendedArray.count) current-year shows")
                        } else if self.firebaseShowsAttendedArray == showsAttendedArray && didVersionChange == false {
                            print("⏭️ firebase EVENT_WRITE: No show attendance changes — skipping Firebase write")
                            return
                        }
                        
                        guard let firebaseRef = self.ensureReference() else {
                            print("⚠️ [FIREBASE_EVENT] Firebase reference not initialized, skipping batch write")
                            return
                        }
                        
                        var batchUpdate = [String: [String: Any]]()
                        var skippedInvalid = 0
                        for (index, status) in showsAttendedArray {
                            guard let entry = self.buildEventBatchEntry(index: index, status: status) else {
                                skippedInvalid += 1
                                continue
                            }
                            batchUpdate[entry.sanitizedKey] = entry.payload
                        }
                        
                        guard batchUpdate.isEmpty == false else {
                            print("🔥 firebase EVENT_WRITE: ❌ BLOCKED - No valid show records to upload (skipped \(skippedInvalid) invalid indices)")
                            return
                        }
                        
                        print("🔥 firebase EVENT_WRITE: BATCH updateChildren for \(batchUpdate.count) shows at showData/\(uid)/\(currentYear)")
                        firebaseRef.child("showData").child(uid).child(String(currentYear)).updateChildValues(batchUpdate) { error, _ in
                            if let error = error {
                                print("🔥 firebase EVENT_WRITE: ❌ Batch write failed: \(error.localizedDescription)")
                                FirebaseWriteMonitor.shared.recordWriteFailure(context: "event_batch")
                            } else {
                                print("🔥 firebase EVENT_WRITE: ✅ Batch write succeeded for \(batchUpdate.count) shows")
                                FirebaseWriteMonitor.shared.recordWriteSuccess(context: "event_batch")
                                self.firebaseShowsAttendedArray = showsAttendedArray
                                self.variableStoreHandle.storeDataToDisk(data: self.firebaseShowsAttendedArray, fileName: self.eventCompareFile)
                            }
                            FirebaseConnectionHelper.goOffline(reason: "event_batch_write_complete")
                        }
                    } else {
                        print("🔥 firebase EVENT_WRITE: ❌ BLOCKED - Schedule data is empty! Cannot write events.")
                    }
                } else {
                    print("🔥 firebase EVENT_WRITE: ❌ BLOCKED - UID is empty!")
                }
            }
        } else {
            //this is being done soley to prevent capturing garbage stats data within my app!
            print("🔥 firebase EVENT_WRITE: ❌ BLOCKED - Bypassed firebase event data writes due to being in simulator!!!")
        }
    }
    
}

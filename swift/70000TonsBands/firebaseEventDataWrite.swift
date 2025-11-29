//
//  firebaseEventDataWrite.swift
//  70K Bands
//
//  Created by Ron Dorn on 3/19/19.
//  Copyright © 2019 Ron Dorn. All rights reserved.
//

import Foundation
import Firebase
import CoreData

class firebaseEventDataWrite {
    
    var ref: DatabaseReference?
    var eventCompareFile = "eventCompare.data"
    var firebaseShowsAttendedArray = [String : String]();
    var schedule = scheduleHandler.shared
    let attended = ShowsAttended()
    let variableStoreHandle = variableStore();
    
    // NEW: Use Core Data AttendanceManager to read attendance data
    let attendanceManager = AttendanceManager()
    private var initializationAttempts = 0
    private let maxInitAttempts = 3
    
    init(){
        initializeFirebaseReference()
    }
    
    /// Attempts to initialize Firebase Database reference with retry logic
    private func initializeFirebaseReference(attempt: Int = 1) {
        // Check if Firebase is configured
        if AppDelegate.isFirebaseConfigured {
            ref = Database.database().reference()
            print("✅ [FIREBASE_EVENT] Firebase Database reference initialized successfully")
        } else {
            print("⚠️ [FIREBASE_EVENT] Firebase not yet configured (attempt \(attempt)/\(maxInitAttempts))")
            
            if attempt < maxInitAttempts {
                // Retry after 2 second delay
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.initializeFirebaseReference(attempt: attempt + 1)
                }
            } else {
                print("❌ [FIREBASE_EVENT] Failed to initialize Firebase after \(maxInitAttempts) attempts - will skip analytics")
            }
        }
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
    
    /// Gets sanitized identifier for an event from Core Data, fallback to computing it
    private func getSanitizedIdentifierForEvent(_ originalIndex: String) -> String {
        // Try to find the event in Core Data by its original identifier
        let context = CoreDataManager.shared.viewContext
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "identifier == %@", originalIndex)
        request.fetchLimit = 1
        
        do {
            if let event = try context.fetch(request).first,
               let sanitizedIdentifier = event.sanitizedIdentifier,
               !sanitizedIdentifier.isEmpty {
                return sanitizedIdentifier
            }
        } catch {
            print("⚠️ Error fetching sanitized identifier for event: \(error)")
        }
        
        // Fallback to sanitizing the original index
        return sanitizeForFirebase(originalIndex)
    }
            
    func writeEvent(index: String, status: String){
        
        print("🔥 firebase EVENT_WRITE: writeEvent() called for index: \(index), status: \(status)")
        
        let indexArray = index.split(separator: ":")
        
        guard indexArray.count >= 6 else {
            print("🔥 firebase EVENT_WRITE: ❌ ERROR - Invalid index format: \(index) (parts: \(indexArray.count), expected: 6)")
            return
        }
    
        let bandName = String(indexArray[0])
        let location = String(indexArray[1])
        let startTimeHour = String(indexArray[2])
        let startTimeMin = String(indexArray[3])
        let eventType = String(indexArray[4])
        let year = String(indexArray[5])
        
        print("🔥 firebase EVENT_WRITE: Parsed - Band: \(bandName), Location: \(location), Time: \(startTimeHour):\(startTimeMin), Type: \(eventType), Year: \(year)")
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            
            print("🔥 firebase EVENT_WRITE: Background write started for \(bandName)")
            
            // Check if Firebase reference is initialized
            guard let firebaseRef = self.ref else {
                print("⚠️ [FIREBASE_EVENT] Cannot write event data: Firebase reference not initialized, skipping analytics")
                return
            }
            
            self.firebaseShowsAttendedArray = self.loadCompareFile();
            
            let uid = (UIDevice.current.identifierForVendor?.uuidString)!
            
            // Get sanitized identifier from Core Data, fallback to computation
            let sanitizedIndex = self.getSanitizedIdentifierForEvent(index)
            print("🔥 firebase EVENT_WRITE: Sanitized index: \(sanitizedIndex)")
            
            let firebasePath = "showData/\(uid)/\(year)/\(sanitizedIndex)"
            print("🔥 firebase EVENT_WRITE: Writing to path: \(firebasePath)")
            
            firebaseRef.child("showData/").child(uid).child(String(year)).child(sanitizedIndex).setValue([
                "originalIdentifier": index, // Store original for reference
                "sanitizedKey": sanitizedIndex, // Store sanitized for debugging
                "bandName": bandName,
                "location": location,
                "startTimeHour": startTimeHour,
                "startTimeMin": startTimeMin,
                "eventType": eventType,
                "status": status]){
                    (error:Error?, ref:DatabaseReference) in
                    if let error = error {
                        print("🔥 firebase EVENT_WRITE: ❌ Writing firebase event data could not be saved: \(error)")
                    } else {
                        print("🔥 firebase EVENT_WRITE: ✅ Writing firebase event data saved successfully for \(bandName)!")
                        self.firebaseShowsAttendedArray[index] = status
                        self.variableStoreHandle.storeDataToDisk(data: self.firebaseShowsAttendedArray, fileName: self.eventCompareFile)
                    }
                }
            
        }
    }

    func writeData (){
        
        print("🔥 firebase EVENT_WRITE: writeData() called - Starting event data write process")
        print("🔥 firebase EVENT_WRITE: inTestEnvironment = \(inTestEnvironment)")
        
        // Check if Firebase reference is initialized
        guard self.ref != nil else {
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
                    print("🔥 firebase EVENT_WRITE: UID is valid, getting attended events from Core Data")
                    
                    // Get current year from global eventYear variable
                    let currentYear = eventYear
                    print("🔥 firebase EVENT_WRITE: Filtering for current year: \(currentYear)")
                    
                    // NEW: Read attendance data from Core Data instead of old file system
                    let attendanceData = self.attendanceManager.getAllAttendanceDataByIndex()
                    print("🔥 firebase EVENT_WRITE: Found \(attendanceData.count) total attendance records in Core Data")
                    
                    // Convert Core Data format to format expected by Firebase write code
                    // Core Data format: [index: ["status": Int, "eventYear": Int, "lastModified": Double]]
                    // Expected format: [index: "statusValue"]
                    // FILTER: Only include events for the current year
                    var showsAttendedArray: [String: String] = [:]
                    var filteredOutCount = 0
                    
                    for (index, data) in attendanceData {
                        // Filter by year - only include current year
                        if let recordYear = data["eventYear"] as? Int, recordYear == currentYear {
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
                        } else {
                            filteredOutCount += 1
                        }
                    }
                    print("🔥 firebase EVENT_WRITE: Filtered to \(showsAttendedArray.count) events for year \(currentYear) (excluded \(filteredOutCount) from other years)")
                    
                    self.schedule.buildTimeSortedSchedulingData();
                    print("🔥 firebase EVENT_WRITE: Built time-sorted schedule data")
                    
                    let scheduleCount = self.schedule.getBandSortedSchedulingData().count
                    print("🔥 firebase EVENT_WRITE: Schedule data count = \(scheduleCount)")
                    
                    if (scheduleCount > 0){
                        print("🔥 firebase EVENT_WRITE: Schedule data exists, processing \(showsAttendedArray.count) events")
                        var processedCount = 0
                        var skippedCount = 0
                        var writtenCount = 0
                        
                        for index in showsAttendedArray {
                            processedCount += 1
                            let cachedValue = self.firebaseShowsAttendedArray[index.key]
                            let currentValue = index.value
                            
                            if (cachedValue != currentValue || didVersionChange == true){
                                print("🔥 firebase EVENT_WRITE: Event \(processedCount)/\(showsAttendedArray.count): \(index.key) - Writing (cached: \(cachedValue ?? "nil"), current: \(currentValue), versionChanged: \(didVersionChange))")
                                self.writeEvent(index: index.key, status: index.value)
                                writtenCount += 1
                            } else {
                                skippedCount += 1
                                if skippedCount <= 3 {
                                    print("🔥 firebase EVENT_WRITE: Event \(processedCount)/\(showsAttendedArray.count): \(index.key) - Skipped (already written)")
                                }
                            }
                        }
                        print("🔥 firebase EVENT_WRITE: Processing complete - Written: \(writtenCount), Skipped: \(skippedCount), Total: \(processedCount)")
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

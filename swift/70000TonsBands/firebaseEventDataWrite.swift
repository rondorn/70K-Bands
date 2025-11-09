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
    
    // Lazy initialization to ensure Firebase is configured before accessing
    lazy var ref: DatabaseReference = {
        // Check if Firebase is configured
        if FirebaseApp.app() == nil {
            print("⚠️ Firebase not configured yet in firebaseEventDataWrite - configuration may have been deferred")
            // Return a dummy reference that won't crash - writes will fail gracefully
            fatalError("Firebase must be configured before accessing Database")
        }
        return Database.database().reference()
    }()
    
    var eventCompareFile = "eventCompare.data"
    var firebaseShowsAttendedArray = [String : String]();
    var schedule = scheduleHandler.shared
    let attended = ShowsAttended()
    let variableStoreHandle = variableStore();
    
    init(){
        // No longer initialize ref here - it's lazy now
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
        
        let indexArray = index.split(separator: ":")
    
        let bandName = String(indexArray[0])
        let location = String(indexArray[1])
        let startTimeHour = String(indexArray[2])
        let startTimeMin = String(indexArray[3])
        let eventType = String(indexArray[4])
        let year = String(indexArray[5])
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            
            self.firebaseShowsAttendedArray = self.loadCompareFile();
            
            let uid = (UIDevice.current.identifierForVendor?.uuidString)!
            
            // Get sanitized identifier from Core Data, fallback to computation
            let sanitizedIndex = self.getSanitizedIdentifierForEvent(index)
            
            self.ref.child("showData/").child(uid).child(String(year)).child(sanitizedIndex).setValue([
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
                        print("Writing firebase data could not be saved: \(error).")
                    } else {
                        print("Writing firebase data saved successfully!")
                        self.firebaseShowsAttendedArray[index] = status
                        self.variableStoreHandle.storeDataToDisk(data: self.firebaseShowsAttendedArray, fileName: self.eventCompareFile)
                    }
                }
            
        }
    }

    func writeData (){
        
        if (inTestEnvironment == false){
            DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
                
                self.firebaseShowsAttendedArray = self.loadCompareFile();
                
                let uid = (UIDevice.current.identifierForVendor?.uuidString)!
                
                if (uid.isEmpty == false){
                    let showsAttendedArray = self.attended.getShowsAttended();
                    
                    self.schedule.buildTimeSortedSchedulingData();
                    
                    if (self.schedule.getBandSortedSchedulingData().count > 0){
                        for index in showsAttendedArray {
                            if (self.firebaseShowsAttendedArray[index.key] != index.value || didVersionChange == true){
                                self.writeEvent(index: index.key, status: index.value)
                            }
                        }
                    }
                }
            }
        } else {

            //this is being done soley to prevent capturing garbage stats data within my app!
            print ("Bypassed firebase event data writes due to being in simulator!!!")
            
        }
    }
    
}

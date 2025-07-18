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
    
    var ref: DatabaseReference!
    var eventCompareFile = "eventCompare.data"
    var firebaseShowsAttendedArray = [String : String]();
    var schedule = scheduleHandler()
    let attended = ShowsAttended()
    let variableStoreHandle = variableStore();
    
    // Network resilience properties
    private let timeoutInterval: TimeInterval = 5.0
    
    init(){
        ref = Database.database().reference()
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
            
            guard let uid = UIDevice.current.identifierForVendor?.uuidString, !uid.isEmpty else {
                print("writeEvent: Invalid device ID")
                return
            }
            
            // Create a timeout timer
            let timeoutTimer = Timer.scheduledTimer(withTimeInterval: self.timeoutInterval, repeats: false) { _ in
                print("writeEvent: Timeout for \(index), skipping Firebase operation")
            }
            
            self.ref.child("showData/").child(uid).child(String(year)).child(index).setValue([
                "bandName": bandName,
                "location": location,
                "startTimeHour": startTimeHour,
                "startTimeMin": startTimeMin,
                "eventType": eventType,
                "status": status]){
                    (error:Error?, ref:DatabaseReference) in
                    
                    // Cancel timeout timer
                    timeoutTimer.invalidate()
                    
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
            // Check network connectivity before attempting Firebase operations
            let networkTester = NetworkTesting()
            guard networkTester.isInternetAvailable() else {
                print("Firebase: No internet connectivity, skipping Firebase operations")
                return
            }
            
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

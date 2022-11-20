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
    var eventCompareFile = directoryPath.appendingPathComponent( "eventCompare.data")
    
    var schedule = scheduleHandler()
    let attended = ShowsAttended()
    
    init(){
        ref = Database.database().reference()
    }

    func writeData (){
        
        var usingSimulator = false;
        #if targetEnvironment(simulator)
            //usingSimulator = true;
        #endif
        if (inTestEnvironment == true){
            //usingSimulator = true;
        }
        
        if (internetAvailble == true && usingSimulator == false){
            let uid = (UIDevice.current.identifierForVendor?.uuidString)!
            
            if (uid.isEmpty == false){
                let showsAttendedArray = attended.getShowsAttended();
                
                schedule.buildTimeSortedSchedulingData();
                
                if (checkIfDataHasChanged(showsAttnded:showsAttendedArray) == false){
                    return;
                }
                
                if (schedule.getBandSortedSchedulingData().count > 0){
                    for index in showsAttendedArray {
                        
                        let indexArray = index.key.split(separator: ":")
                        
                        let bandName = String(indexArray[0])
                        let location = String(indexArray[1])
                        let startTimeHour = String(indexArray[2])
                        let startTimeMin = String(indexArray[3])
                        let eventType = String(indexArray[4])
                        let year = String(indexArray[5])
                        let status = index.value
                        
                        self.ref.child("showData/").child(uid).child(String(year)).child(index.key).setValue([
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
                                                }
                        }
                    }
                }
            }
        } else {
            if (usingSimulator == true){
                //this is being done soley to prevent capturing garbage stats data within my app!
                print ("Bypassed firebase event data writes due to being in simulator!!!")
            }
        }
    }
    
    func checkIfDataHasChanged(showsAttnded:[String:String] )->Bool{
        
        var result = true
        
        var showsAttndedCache: [String : String] = [String : String]();
        
        do {
            if (try eventCompareFile.checkResourceIsReachable() == true){
                showsAttndedCache =  try (NSKeyedUnarchiver.unarchiveObject(withFile: eventCompareFile.path) as? [String:String])!
                
            }
        } catch {
            print ("checkIfDataHasChanged - unable to read \(error)");
        }
        
        if (showsAttndedCache.count >= 1){
            if (showsAttndedCache == showsAttnded){
                result = false;
            }
        }
        
        do {
            if #available(iOS 11.0, *) {
                let data = try NSKeyedArchiver.archivedData(withRootObject: showsAttnded, requiringSecureCoding: false)
                try data.write(to: eventCompareFile)
                
            }
        } catch {
            print ("checkIfDataHasChanged - unable to write \(error)");
        }
    
        return result
    }
}

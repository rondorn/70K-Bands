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
    
    init(){
        ref = Database.database().reference()
    }

    func writeData (){
        
        if (internetAvailble == true){
            let uid = (UIDevice.current.identifierForVendor?.uuidString)!
            let attended = ShowsAttended()
            let showsAttendedArray = attended.getShowsAttended();
            let allBands = getBandNames()
            //var showPayload:[String:String] = [String:String]()
            
            schedule.buildTimeSortedSchedulingData();
            if (schedule.getBandSortedSchedulingData().count > 0){
                for index in showsAttendedArray {
                    
                    //band + ":" + location + ":" + startTime + ":" + eventTypeValue
                    let indexArray = index.key.split(separator: ":")
                    
                    let bandName = String(indexArray[0])
                    let location = String(indexArray[1])
                    let startTimeHour = String(indexArray[2])
                    let startTimeMin = String(indexArray[3])
                    let eventType = String(indexArray[4])
                    let year = String(indexArray[5])
                    let status = index.value
                    
                    self.ref.child("showData/").child(uid).child(String(year)).child(index.key).setValue(["bandName": bandName,
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
    }
}

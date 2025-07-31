//
//  firebaseEventDataWrite.swift
//  70K Bands
//
//  Created by Ron Dorn on 3/19/19.
//  Copyright © 2019 Ron Dorn. All rights reserved.
//

import Foundation

class firebaseEventDataWrite {
    
    var ref: Any? = nil
    var eventCompareFile = "eventCompare.data"
    var firebaseEventAttendedArray = [String : String]();
    let variableStoreHandle = variableStore();
    
    init(){
        // Firebase functionality removed for visionOS compatibility
    }
    
    func loadCompareFile()->[String:String]{
        do {
            print ("Starting loadedData")
            firebaseEventAttendedArray = variableStoreHandle.readDataFromDisk(fileName: eventCompareFile) ?? [String : String]()
            print ("Finished loadedData \(firebaseEventAttendedArray)")
        } catch {
            print("Couldn't read file.")
        }
        
        return firebaseEventAttendedArray
    }
    
    func writeSingleRecord(eventName: String, status: String){
        // Firebase functionality removed for visionOS compatibility
        print("Firebase functionality removed - writeSingleRecord called for \(eventName)")
    }
    
    func writeData (){
        // Firebase functionality removed for visionOS compatibility
        print("Firebase functionality removed - writeData called")
    }
}

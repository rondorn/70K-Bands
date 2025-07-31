//
//  firebaseBandDataWrite.swift
//  70K Bands
//
//  Created by Ron Dorn on 3/19/19.
//  Copyright © 2019 Ron Dorn. All rights reserved.
//

import Foundation

class firebaseBandDataWrite {
    
    var bandCompareFile = "bandCompare.data"
    var firebaseBandAttendedArray = [String : String]();
    var bandRank: [String : String] = [String : String]();
    let variableStoreHandle = variableStore();
    
    init(){
        // Firebase functionality removed for visionOS compatibility
    }
    
    func loadCompareFile()->[String:String]{
        do {
            print ("Starting loadedData")
            firebaseBandAttendedArray = variableStoreHandle.readDataFromDisk(fileName: bandCompareFile) ?? [String : String]()
            print ("Finished loadedData \(firebaseBandAttendedArray)")
        } catch {
            print("Couldn't read file.")
        }
        
        return firebaseBandAttendedArray
    }
    
    func writeSingleRecord(dataHandle: dataHandler, bandName: String, ranking: String){
        // Firebase functionality removed for visionOS compatibility
        print("Firebase functionality removed - writeSingleRecord called for \(bandName)")
    }
    
    func writeData (dataHandle: dataHandler){
        // Firebase functionality removed for visionOS compatibility
        print("Firebase functionality removed - writeData called")
    }
    
    func buildBandRankArray(dataHandle: dataHandler){
        // Firebase functionality removed for visionOS compatibility
        print("Firebase functionality removed - buildBandRankArray called")
    }
}

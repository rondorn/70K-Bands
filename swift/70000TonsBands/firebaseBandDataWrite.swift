//
//  filebaseBandDataWrite.swift
//  70K Bands
//
//  Created by Ron Dorn on 3/19/19.
//  Copyright © 2019 Ron Dorn. All rights reserved.
//

import Foundation
import Firebase


class firebaseBandDataWrite {
    
    var ref: DatabaseReference!
    var bandCompareFile = "bandCompare.data"
    var firebaseBandAttendedArray = [String : String]();
    var bandRank: [String : String] = [String : String]();
    let variableStoreHandle = variableStore();
    
    init(){
        
        ref = Database.database().reference()
        
    }
    
    
    func loadCompareFile()->[String:String]{
        do {
            print ("Staring loadedData")
            firebaseBandAttendedArray = variableStoreHandle.readDataFromDisk(fileName: bandCompareFile) ?? [String : String]()
            print ("Finished loadedData \(firebaseBandAttendedArray)")
        } catch {
            print("Couldn't read file.")
        }
        
        return firebaseBandAttendedArray
    }
    
    /// Sanitizes band names for use as Firebase database path components
    /// Firebase paths cannot contain: . # $ [ ]
    private func sanitizeBandNameForFirebase(_ bandName: String) -> String {
        return bandName
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "#", with: "_")
            .replacingOccurrences(of: "$", with: "_")
            .replacingOccurrences(of: "[", with: "_")
            .replacingOccurrences(of: "]", with: "_")
    }
    
    func writeSingleRecord(dataHandle: dataHandler, bandName: String, ranking: String){
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            
            self.firebaseBandAttendedArray = self.loadCompareFile()
            
            let uid = (UIDevice.current.identifierForVendor?.uuidString)!
            print ("writeSingleRecord: uid = \(uid) = eventYear = \(eventYear) - bandName - \(bandName)")
            //exit if things look wrong
            if (bandName == nil || bandName.isEmpty == true){
                return
            }
            
            // Sanitize band name for Firebase path
            let sanitizedBandName = self.sanitizeBandNameForFirebase(bandName)
            
            self.ref.child("bandData/").child(uid).child(String(eventYear)).child(sanitizedBandName).setValue([
                "bandName": bandName,
                "ranking": ranking,
                "userID": uid,
                "year": String(eventYear)]){
                    (error:Error?, ref:DatabaseReference) in
                    if let error = error {
                        print("Writing firebase band data could not be saved: \(error).")
                    } else {
                        print("Writing firebase band data saved successfully \(bandName) - \(ranking)!")
                        
                        self.firebaseBandAttendedArray[bandName] = ranking
                        self.variableStoreHandle.storeDataToDisk(data: self.firebaseBandAttendedArray, fileName: self.bandCompareFile)
                        

                    }
                }

        }
    }
    
    func writeData (dataHandle: dataHandler){
        
        if inTestEnvironment == false {
            dataHandle.refreshData()
            let uid = (UIDevice.current.identifierForVendor?.uuidString)!
            firebaseBandAttendedArray = self.loadCompareFile()
            print ("bandDataReport - Loading firebaseBandAttendedArray \(firebaseBandAttendedArray)")
            if (uid.isEmpty == false){
                self.buildBandRankArray(dataHandle: dataHandle)
                for bandName in self.bandRank.keys {
                    
                    let priorityManager = PriorityManager()
                    let rankingInteger = priorityManager.getPriority(for: bandName)
                    let ranking = resolvePriorityNumber(priority: String(rankingInteger)) ?? "Unknown"
                    print ("bandDataReport - Checking band \(bandName) - \(firebaseBandAttendedArray[bandName]) - \(ranking)")
                    if firebaseBandAttendedArray[bandName] != ranking || didVersionChange == true {
                        print ("bandDataReport - fixing record for \(bandName)")
                        writeSingleRecord(dataHandle: dataHandle, bandName: bandName, ranking: ranking)
                    }
                    
                }
            } else {
                print("Not Writing firebase band data, nothing has changed")
            }
        
        }
    }
    
    func buildBandRankArray(dataHandle: dataHandler){
        
        let bandNameHandle = bandNamesHandler.shared
        
        let allBands = bandNameHandle.getBandNames()
        for bandName in allBands {
            
            let priorityManager = PriorityManager()
            let rankingNumber = String(priorityManager.getPriority(for: bandName))
            let rankingString = resolvePriorityNumber(priority: rankingNumber)
            
            bandRank[bandName] = rankingString;
        }
    }
    
    
}

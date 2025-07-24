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
    
    // Network resilience properties
    private let timeoutInterval: TimeInterval = 5.0
    
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
    
    func writeSingleRecord(dataHandle: dataHandler, bandName: String, ranking: String){
        
        // Validate input
        guard !bandName.isEmpty else {
            print("writeSingleRecord: Invalid band name")
            return
        }
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            
            self.firebaseBandAttendedArray = self.loadCompareFile()
            
            guard let uid = UIDevice.current.identifierForVendor?.uuidString, !uid.isEmpty else {
                print("writeSingleRecord: Invalid device ID")
                return
            }
            
            print ("writeSingleRecord: uid = \(uid) = eventYear = \(eventYear) - bandName - \(bandName)")
            
            // Create a timeout timer
            let timeoutTimer = Timer.scheduledTimer(withTimeInterval: self.timeoutInterval, repeats: false) { _ in
                print("writeSingleRecord: Timeout for \(bandName), skipping Firebase operation")
            }
            
            self.ref.child("bandData/").child(uid).child(String(eventYear)).child(bandName).setValue([
                "bandName": bandName,
                "ranking": ranking,
                "userID": uid,
                "year": String(eventYear)]){
                    (error:Error?, ref:DatabaseReference) in
                    
                    // Cancel timeout timer
                    timeoutTimer.invalidate()
                    
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
            // Check network connectivity before attempting Firebase operations
            let networkTester = NetworkTesting()
            guard networkTester.isInternetAvailable() else {
                print("Firebase: No internet connectivity, skipping Firebase operations")
                return
            }
            
            dataHandle.refreshData()
            let uid = (UIDevice.current.identifierForVendor?.uuidString)!
            firebaseBandAttendedArray = self.loadCompareFile()
            print ("bandDataReport - Loading firebaseBandAttendedArray \(firebaseBandAttendedArray)")
            if (uid.isEmpty == false){
                self.buildBandRankArray(dataHandle: dataHandle)
                for bandName in self.bandRank.keys {
                    
                    let rankingInteger = dataHandle.getPriorityData(bandName)
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
            
            let rankingNumber = String(dataHandle.getPriorityData(bandName))
            let rankingString = resolvePriorityNumber(priority: rankingNumber)
            
            bandRank[bandName] = rankingString;
        }
    }
    
    
}

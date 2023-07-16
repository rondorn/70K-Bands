//
//  filebaseBandDataWrite.swift
//  70K Bands
//
//  Created by Ron Dorn on 3/19/19.
//  Copyright © 2019 Ron Dorn. All rights reserved.
//

import Foundation
import Firebase


class filebaseBandDataWrite {
    
    var ref: DatabaseReference!
    var bandCompareFile = directoryPath.appendingPathComponent( "bandCompare.data")
    
    var bandRank: [String : String] = [String : String]();
    var dataHandle = dataHandler()
    
    init(){
        
        ref = Database.database().reference()
        
    }
    
    func writeData (){
        
        var usingSimulator = false;
        #if targetEnvironment(simulator)
            //usingSimulator = true;
        #endif
        if (inTestEnvironment == true){
            usingSimulator = true;
        }
        
        if (usingSimulator == false){
            DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
                let uid = (UIDevice.current.identifierForVendor?.uuidString)!
                if (uid.isEmpty == false){
                    self.buildBandRankArray()
                    
                    if (self.checkIfDataHasChanged(bandRank: self.bandRank) == true){
                        for bandName in self.bandRank.keys {
                            
                            let ranking = self.bandRank[bandName]
                            
                            self.ref.child("bandData/").child(uid).child(String(eventYear)).child(bandName).setValue([
                                "bandName": bandName,
                                "ranking": ranking!,
                                "userID": uid,
                                "year": String(eventYear)]){
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
        } else {
            if (usingSimulator == true){
                //this is being done soley to prevent capturing garbage stats data within my app!
                print ("Bypassed firebase band data writes due to being in simulator!!!")
            }
        }
    }
    
    func buildBandRankArray(){
        
        let bandNameHandle = bandNamesHandler()
        
        let allBands = bandNameHandle.getBandNames()
        for bandName in allBands {
            
            let rankingNumber = String(dataHandle.getPriorityData(bandName))
            let rankingString = resolvePriorityNumber(priority: rankingNumber)
            
            bandRank[bandName] = rankingString;
        }
    }
    
    func checkIfDataHasChanged(bandRank:[String:String] )->Bool{
        
        var result = true
        
        var bandRankCache: [String : String] = [String : String]();
        
        do {
            if (try bandCompareFile.checkResourceIsReachable() == true){
                bandRankCache =  try (NSKeyedUnarchiver.unarchiveObject(withFile: bandCompareFile.path) as? [String:String])!
                
            }
        } catch {
            print ("checkIfDataHasChanged - unable to read \(error)");
        }
        
        if (bandRankCache.count >= 1){
            if (bandRankCache == bandRank){
                result = false;
            }
        }
        
        do {
            if #available(iOS 11.0, *) {
                let data = try NSKeyedArchiver.archivedData(withRootObject: bandRank, requiringSecureCoding: false)
                try data.write(to: bandCompareFile)
                
            }
        } catch {
            print ("checkIfDataHasChanged - unable to write \(error)");
        }
        
        return result
    }
}

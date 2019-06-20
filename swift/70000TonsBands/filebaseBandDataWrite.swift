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
    
    init(){
        
        ref = Database.database().reference()
        
    }
    
    func writeData (){
        
        if (internetAvailble == true){
            
            let uid = (UIDevice.current.identifierForVendor?.uuidString)!
            
            buildBandRankArray()
            
            if (checkIfDataHasChanged(bandRank: bandRank) == true){
                for bandName in bandRank.keys {
                    
                    let ranking = bandRank[bandName]
                    
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
    
    func buildBandRankArray(){
        
        let bandNameHandle = bandNamesHandler()
        
        let allBands = bandNameHandle.getBandNames()
        for bandName in allBands {
            
            let rankingNumber = String(getPriorityData(bandName))
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

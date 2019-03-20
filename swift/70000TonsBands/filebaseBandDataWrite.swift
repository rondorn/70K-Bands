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
    
    init(){
        
        ref = Database.database().reference()
        
    }
    
    func writeData (){
        
        let allBands = getBandNames()
        let uid = (UIDevice.current.identifierForVendor?.uuidString)!
        
        for bandName in allBands {
            let externalID = uid + "-" + bandName;
            let rankingNumber = String(getPriorityData(bandName))
            let rankingString = resolvePriorityNumber(priority: rankingNumber)
            
            self.ref.child("bandData/").child(uid).child(String(eventYear)).child(bandName).setValue(["bandName": bandName,
                                                                    "ranking": rankingString,
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

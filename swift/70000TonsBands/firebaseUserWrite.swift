//
//  firebaseUserWrite.swift
//  70K Bands
//
//  Created by Ron Dorn on 3/19/19.
//  Copyright © 2019 Ron Dorn. All rights reserved.
//

import Foundation
import Firebase

class firebaseUserWrite {
    
    var ref: DatabaseReference!
    
    init(){
        
        ref = Database.database().reference()
    }
    
    func writeData (){
        
        var usingSimulator = false;
        
        #if targetEnvironment(simulator)
            usingSimulator = true;
        #endif
        if (inTestEnvironment == true){
            usingSimulator = true;
        }
        
        if (internetAvailble == true && usingSimulator == false){
            
            let userDataHandle = userDataHandler()
            
            if (userDataHandle.uid.isEmpty == false){
                print ("Firebase UserID is \(userDataHandle.uid)");
                
                print ("Writing firebase data to userData start");

                self.ref.child("userData/").child(userDataHandle.uid).setValue(["userID": userDataHandle.uid,
                                                                               "country": userDataHandle.country,
                                                                               "language": userDataHandle.language,
                                                                               "platform": "iOS",
                                                                               "lastLaunch": userDataHandle.getCurrentDateString()]) {
                                                                                (error:Error?, ref:DatabaseReference) in
                                                                                if let error = error {
                                                                                    print("Writing firebase data could not be saved: \(error).")
                                                                                } else {
                                                                                    print("Writing firebase data saved successfully!")
                                                                                }
                }
            
                print ("Writing firebase data to userData stop")
            }
        } else {
            if (usingSimulator == true){
                //this is being done soley to prevent capturing garbage stats data within my app!
                print ("Bypassed firebase band data writes due to being in simulator!!!")
            }
        }
    }
}

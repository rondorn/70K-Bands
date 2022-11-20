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
            //usingSimulator = true;
        #endif
        if (inTestEnvironment == true){
            //xusingSimulator = true;
        }
        
        //NSLog("", "USER_WRITE_DATA: Starting User Write data code")
        if (internetAvailble == true && usingSimulator == false){
            
            let userDataHandle = userDataHandler()
            print ("Writing Firebase  UserID is \(userDataHandle.uid)");
            //("Writing Firebase data new userData Id is 1 " + userDataHandle.uid)
            if (userDataHandle.uid.isEmpty == false){
                NSLog("Writing Firebase data new userData Id is 2 " + userDataHandle.uid)
                
                print ("Writing Firebase  firebase data to userData start");

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
            
                //NSLog("Writing Firebase data new userData Id is 3 " + userDataHandle.uid)
            }
        } else {
        
            if (usingSimulator == true){
                //this is being done soley to prevent capturing garbage stats data within my app!
                //NSLog("Writing Firebase data new userData canceling in simulator")

            } else {
                //NSLog("Writing Firebase data new userData canceling in offline")
                
            }
        }
    }
}

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
        
        //NSLog("", "USER_WRITE_DATA: Starting User Write data code")
        if (inTestEnvironment == false){
            DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
                
                let randomInt = Int.random(in: 5..<25)
                print ("Writing Firebase  sleeping \(randomInt)");
                sleep(UInt32(randomInt))
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
                                                                                    "osVersion" : userDataHandle.iosVersion,
                                                                                    "70kVersion" : userDataHandle.bandsVersion,
                                                                                    "lastLaunch": userDataHandle.getCurrentDateString()]) {
                        (error:Error?, ref:DatabaseReference) in
                        if let error = error {
                            print("Writing Firebase data could not be saved: \(error).")
                        } else {
                            print("Writing Firebase data saved successfully!")
                        }
                    }
                }
            }
        }
    }
}

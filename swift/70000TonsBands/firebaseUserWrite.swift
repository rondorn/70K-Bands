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
        let initTime = Date()
        print("🔥 [TIMING] firebaseUserWrite.init() CALLED at \(initTime.timeIntervalSince1970)")
        print("🔥 [TIMING] AppDelegate.isFirebaseConfigured = \(AppDelegate.isFirebaseConfigured)")
        
        // Check if FirebaseApp is actually configured
        if FirebaseApp.app() != nil {
            print("🔥 [TIMING] FirebaseApp.app() is NOT NIL (Firebase IS configured)")
        } else {
            print("❌ [TIMING] FirebaseApp.app() is NIL (Firebase NOT configured)")
        }
        
        print("🔥 [TIMING] About to call Database.database().reference()")
        
        ref = Database.database().reference()
        
        print("🔥 [TIMING] Database.database().reference() SUCCESS at \(Date().timeIntervalSince1970)")
    }
    
    func writeData (){
        let writeDataTime = Date()
        print("🔥 [TIMING] firebaseUserWrite.writeData() CALLED at \(writeDataTime.timeIntervalSince1970)")
        
        //NSLog("", "USER_WRITE_DATA: Starting User Write data code")
        if (inTestEnvironment == false){
            DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
                
                let randomInt = Int.random(in: 5..<25)
                print ("🔥 [TIMING] Writing Firebase sleeping \(randomInt) seconds");
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

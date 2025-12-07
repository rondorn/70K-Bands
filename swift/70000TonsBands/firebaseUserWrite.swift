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
    
    var ref: DatabaseReference? // Changed to optional
    private let maxAttempts = 3
    private let retryDelay: TimeInterval = 2.0
    
    init(){
        initializeFirebaseReference()
    }
    
    private func initializeFirebaseReference(attempt: Int = 1) {
        guard AppDelegate.isFirebaseConfigured else {
            print("⚠️ Firebase not yet configured for User Data (attempt \(attempt)/\(maxAttempts))")
            if attempt < maxAttempts {
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + retryDelay) { [weak self] in
                    self?.initializeFirebaseReference(attempt: attempt + 1)
                }
            } else {
                print("❌ Failed to initialize Firebase User Data reference after \(maxAttempts) attempts")
            }
            return
        }
        
        ref = Database.database().reference()
        print("✅ Firebase User Data reference initialized successfully")
    }
    
    func writeData (){
        let writeDataTime = Date()
        print("🔥 [TIMING] firebaseUserWrite.writeData() CALLED at \(writeDataTime.timeIntervalSince1970)")
        
        //NSLog("", "USER_WRITE_DATA: Starting User Write data code")
        if (inTestEnvironment == false){
            DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
                
                // Guard against Firebase not being configured
                guard let firebaseRef = self.ref else {
                    print("⚠️ Firebase User Data reference not initialized, skipping write")
                    return
                }
                
                let randomInt = Int.random(in: 5..<25)
                print ("🔥 [TIMING] Writing Firebase sleeping \(randomInt) seconds");
                sleep(UInt32(randomInt))
                let userDataHandle = userDataHandler()
                print ("Writing Firebase  UserID is \(userDataHandle.uid)");
                //("Writing Firebase data new userData Id is 1 " + userDataHandle.uid)
                if (userDataHandle.uid.isEmpty == false){
                    NSLog("Writing Firebase data new userData Id is 2 " + userDataHandle.uid)
                    
                    print ("Writing Firebase  firebase data to userData start");
                    
                    firebaseRef.child("userData/").child(userDataHandle.uid).setValue(["userID": userDataHandle.uid,
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

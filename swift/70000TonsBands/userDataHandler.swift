//
//  userDataHandler.swift
//  70K Bands
//
//  Created by Ron Dorn on 3/3/19.
//  Copyright © 2019 Ron Dorn. All rights reserved.
//  Based on
//
//  Copyright (c) 2015 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
import UIKit
import Firebase

class userDataHandler: NSObject {
    var uid: String
    var country: String
    var language: String
    var lastLaunch: Date
    var lanuchCount: Int
    
    override init(){
        self.uid = (UIDevice.current.identifierForVendor?.uuidString)!
        self.country = NSLocale.current.regionCode!
        self.language = Locale.current.languageCode!
        self.lastLaunch = NSDate() as Date
        self.lanuchCount = 0
        
        print ("new userData - " + self.uid + " - " + self.country + " - " + self.language);
    }
}

//
//  userDataHandler.swift
//  70K Bands
//
//  Created by Ron Dorn on 3/3/19.
//  Copyright © 2019 Ron Dorn. All rights reserved.
//  Based on
//

import UIKit

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
        self.lanuchCount = 1
        
        print ("new userData - " + self.uid + " - " + self.country + " - " + self.language);
    }
    
    func getCurrentDateString()->String {
        
        let now = Date()
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.init(abbreviation: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        var dateString = formatter.string(from: now)
        
        dateString = dateString.replacingOccurrences(of: " ", with: "T")
        dateString += "-00:00";
        
        return dateString
        
    }

}

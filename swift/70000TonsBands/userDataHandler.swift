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
    var bandsVersion: String
    var iosVersion: String
    
    override init(){
        
        print ("Writing Firebase new userData 1")
        var uidString = "Unknown"
        if (UIDevice.current.identifierForVendor != nil){
            if (UIDevice.current.identifierForVendor != nil){
                uidString = UIDevice.current.identifierForVendor!.uuidString
            }
        }
        
        
        var detectedCountry = ""
        do {
            detectedCountry = try String(contentsOf: countryFile, encoding: .utf8)
            print ("From countryFile \(countryFile) for a country of \(detectedCountry)")
            if (detectedCountry.isEmpty == true){
                print ("Falling back to default Country with empty CountryFile")
                detectedCountry = NSLocale.current.regionCode!
            }
        } catch {
            print ("Error - Falling back to default CountryFile")
            detectedCountry = NSLocale.current.regionCode!
        }
        
        print ("Writing Firebase new userData 2")
        
        self.uid = uidString
        self.country = detectedCountry
        self.language = Locale.current.languageCode ?? "Unknown";
        self.lastLaunch = NSDate() as Date
        self.lanuchCount = 1
        self.bandsVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as! String
        self.iosVersion = UIDevice.current.systemVersion
        
        print ("Writing Firebase  new userData 3")
        print ("Writing Firebase new userData - " + self.uid + " - " + self.country + " - " + self.language);
    }
    

    func getCurrentDateString()->String {
        
        let now = Date()
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.init(abbreviation: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = formatter.string(from: now)
        
        return dateString
        
    }

}

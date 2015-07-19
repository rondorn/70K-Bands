//
//  PushNotificationController.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/15/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import Parse

class PushNotificationController : NSObject {
    
    override init() {
        super.init()
        
        let parseApplicationId = valueForAPIKey(plistName: "ApiKeys", keyname: "PARSE_APPLICATION_ID")
        let parseClientKey     = valueForAPIKey(plistName: "ApiKeys", keyname: "PARSE_CLIENT_KEY")
        
        Parse.setApplicationId(parseApplicationId, clientKey: parseClientKey)
        
    }
}

func valueForAPIKey(#plistName:String, #keyname:String) -> String {
    // Credit to the original source for this technique at
    // http://blog.lazerwalker.com/blog/2014/05/14/handling-private-api-keys-in-open-source-ios-apps
    let filePath = NSBundle.mainBundle().pathForResource(plistName, ofType:"plist")
    let plist = NSDictionary(contentsOfFile:filePath!)
    
    let value:String = plist?.objectForKey(keyname) as! String
    return value
}
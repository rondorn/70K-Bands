//
//  httpHandler.swift
//  70K Bands
//
//  Created by Ron Dorn on 1/31/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation

func HTTPsendRequest(request: NSMutableURLRequest,
    callback: (String, String?) -> Void) {
        let task = NSURLSession.sharedSession().dataTaskWithRequest(
            request,
            completionHandler: {
                data, response, error in
                if error != nil {
                    callback("", error!.localizedDescription)
                } else {
                    callback(
                        NSString(data: data!, encoding: NSUTF8StringEncoding) as! String,
                        nil
                    )
                }
        })
        task.resume()
        
}

func HTTPGet(url: String, callback: (String, String?) -> Void) {
    let request = NSMutableURLRequest(URL: NSURL(string: url)!)
    request.timeoutInterval = 30;
    HTTPsendRequest(request, callback: callback)
}
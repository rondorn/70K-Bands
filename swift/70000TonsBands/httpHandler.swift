//
//  httpHandler.swift
//  70K Bands
//
//  Created by Ron Dorn on 1/31/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation

func HTTPsendRequest(_ request: URLRequest,
    callback: @escaping (String, String?) -> Void) {
        let task = URLSession.shared.dataTask(
            with: request,
            completionHandler: {
                data, response, error in
                if error != nil {
                    callback("", error!.localizedDescription)
                } else {
                    callback(
                        NSString(data: data!, encoding: String.Encoding.utf8.rawValue) as! String,
                        nil
                    )
                }
        })
        task.resume()
        
}

func HTTPGet(_ url: String, callback: @escaping (String, String?) -> Void) {
    if (url.isEmpty == false){
        let request = NSMutableURLRequest(url: URL(string: url)!)
        request.timeoutInterval = 30;
        HTTPsendRequest(request as URLRequest, callback: callback)
    }
}

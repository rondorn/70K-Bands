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
                  
                    let stringVariable = String(data: data!, encoding: String.Encoding(rawValue: String.Encoding.ascii.rawValue))! as String
                    //let stringVariable = String(data: data!, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue))! as String
                    callback(stringVariable, nil)

                }
        })
        task.resume()
        
}

func HTTPGet(_ url: String, callback: @escaping (String, String?) -> Void) {
    if (url.isEmpty == false && url != " "){
        print ("Loading URL - '\(url)'")
        let request = NSMutableURLRequest(url: URL(string: url)!)
        request.timeoutInterval = 15;
        do {
            try? HTTPsendRequest(request as URLRequest, callback: callback)
        } catch {
            print ("loading URL \(url) failed, trying again.")
            HTTPsendRequest(request as URLRequest, callback: callback)
        }
    }
}

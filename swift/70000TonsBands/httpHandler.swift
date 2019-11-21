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

        HTTPsendRequest(request as URLRequest, callback: callback)
        print ("Finished making http call")
    }
}


func getUrlData(urlString: String) -> String{
    
    let currentQueueLabel = OperationQueue.current?.underlyingQueue?.label
    
    if (isInternetAvailable() == false){
        return ""
    }
    var results = String()
    
    if (urlString.isEmpty == false){
        print ("\(currentQueueLabel ?? "") !!Looking up url \(urlString)")
        
        if (urlString == "Unable to communicate with Drop Box!"){
                results = urlString
        } else {
            do {
                //create the url with NSURL
                let url = try URL(string: urlString)! //change the url
                let contents = try String(contentsOf: url)
                print(contents)
                results = contents
            } catch {
                print ("Failed to find data !!Looking up url \(urlString)")
            }
        }
    }
    return results
}

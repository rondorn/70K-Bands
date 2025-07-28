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
                if let error = error {
                    callback("", error.localizedDescription)
                } else if let data = data, let stringVariable = String(data: data, encoding: .ascii) {
                    callback(stringVariable, nil)
                } else {
                    callback("", "Unknown error: data or string conversion failed")
                }
        })
        task.resume()
        
}

func HTTPGet(_ url: String, callback: @escaping (String, String?) -> Void) {
    
    let netTest = NetworkTesting()
    internetAvailble = netTest.isInternetAvailableSynchronous(); //isInternetAvailable();
    if (url.isEmpty == false && url != " " && internetAvailble == true){
        print ("Loading URL - '\(url)'")
        let request = NSMutableURLRequest(url: URL(string: url)!)
        request.timeoutInterval = 15;

        HTTPsendRequest(request as URLRequest, callback: callback)
        print ("Finished making http call")
    }
}


func getUrlData(urlString: String) -> String{
    
    let currentQueueLabel = OperationQueue.current?.underlyingQueue?.label
    
    // Gate all network calls on cached network status
    if (NetworkTesting.isNetworkAvailable() == false){
        print ("Internet is down (cached), returning empty")
        return ""
    }
    var results = String()
    
    if (urlString.isEmpty == false){
        print ("\(currentQueueLabel ?? "") !!Looking up url \(urlString)")
        
        if (urlString == "Unable to communicate with Drop Box!"){
                results = urlString
        } else {
            do {
                print ("Problem URL string is \(urlString)")
                //create the url with NSURL
                let url = try URL(string: urlString) ?? URL(fileURLWithPath: "") //change the url
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

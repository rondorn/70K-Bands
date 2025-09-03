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
    
    // Use cached network status instead of blocking synchronous call
    let netTest = NetworkTesting()
    internetAvailble = netTest.isInternetAvailable(); // Use non-blocking method
    
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
            // IMPORTANT: Only allow synchronous URL loading on background threads
            if Thread.isMainThread {
                print ("⚠️ WARNING: getUrlData called on main thread for \(urlString) - returning empty to prevent UI hang")
                return ""
            }
            
            // Retry logic for handling rate limiting and temporary failures
            var retryCount = 0
            let maxRetries = 3
            var success = false
            
            while retryCount < maxRetries && !success {
                do {
                    if retryCount > 0 {
                        let delay = pow(2.0, Double(retryCount)) // Exponential backoff: 2, 4, 8 seconds
                        print("getUrlData: Retry \(retryCount) after \(delay) second delay for \(urlString)")
                        Thread.sleep(forTimeInterval: delay)
                    }
                    
                    print ("getUrlData: Attempting to load URL \(urlString) (attempt \(retryCount + 1))")
                    let url = try URL(string: urlString) ?? URL(fileURLWithPath: "")
                    let contents = try String(contentsOf: url)
                    
                    if !contents.isEmpty {
                        print("getUrlData: Successfully loaded \(contents.count) characters")
                        results = contents
                        success = true
                    } else {
                        print("getUrlData: Empty response received")
                        retryCount += 1
                    }
                } catch {
                    print("getUrlData: Attempt \(retryCount + 1) failed: \(error.localizedDescription)")
                    retryCount += 1
                    
                    // If this was the last retry, log the final failure
                    if retryCount >= maxRetries {
                        print("getUrlData: All \(maxRetries) attempts failed for \(urlString)")
                    }
                }
            }
        }
    }
    return results
}

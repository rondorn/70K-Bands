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
    internetAvailble = isInternetAvailable();
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
    
    if (isInternetAvailable() == false){
        print ("Internet is down, returning empty")
        return ""
    }
    var results = String()
    
    if (urlString.isEmpty == false){
        print ("\(currentQueueLabel ?? "") !!Looking up url \(urlString)")
        
        if (urlString == "Unable to communicate with Drop Box!"){
            print ("HTTP_ERROR: Unable to communicate with Drop Box! - 1")
                results = urlString
        } else {
            do {
                print ("Problem URL string is \(urlString)")
                //create the url with NSURL
                let url = try URL(string: urlString) ?? URL(fileURLWithPath: "") //change the url
                
                // Use URLSession for better timeout handling and async behavior
                let semaphore = DispatchSemaphore(value: 0)
                var urlContents = ""
                var urlError: Error?
                
                let task = URLSession.shared.dataTask(with: url) { data, response, error in
                    if let error = error {
                        urlError = error
                        print("HTTP_ERROR: Network error for \(urlString): \(error.localizedDescription)")
                    } else if let data = data {
                        urlContents = String(data: data, encoding: .utf8) ?? ""
                        print("[BAND_DEBUG] getUrlData: Received \(data.count) bytes for \(urlString)")
                    } else {
                        print("[BAND_DEBUG] getUrlData: No data received for \(urlString)")
                    }
                    semaphore.signal()
                }
                
                task.resume()
                
                // Wait with timeout to prevent indefinite hanging
                let timeoutResult = semaphore.wait(timeout: .now() + 30.0) // 30 second timeout
                
                if timeoutResult == .timedOut {
                    print("Timeout waiting for URL data: \(urlString)")
                    task.cancel()
                } else if urlError != nil {
                    print("Failed to find data !!Looking up url \(urlString): \(urlError!.localizedDescription)")
                } else {
                    results = urlContents
                }
                
            } catch {
                print ("Failed to find data !!Looking up url \(urlString)")
            }
        }
    }
    return results
}

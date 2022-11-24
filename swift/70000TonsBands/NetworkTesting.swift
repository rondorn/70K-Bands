//
//  NetworkTesting.swift
//  70K Bands
//
//  Created by Ron Dorn on 1/25/20.
//  Copyright © 2020 Ron Dorn. All rights reserved.
//

import Foundation
import Network
import SystemConfiguration

open class NetworkTesting {
    
    var internetCurrentlyTesting = false
    
    init(){
    }


    func isInternetAvailable() -> Bool {
        
        var returnState = false
        
        if (internetCheckCache.isEmpty == false && NSDate().timeIntervalSince1970 < internetCheckCacheDate){
            if internetCheckCache == "false" {
                returnState = false
            } else {
                returnState = true
            }
            
            print ("Internet Found cache is \(returnState), cache will expire at \(internetCheckCacheDate)")

        //cache has expired, but lets return last answer and check again in the background
        } else if (internetCheckCache.isEmpty == false && Thread.isMainThread == false){
            
            if internetCheckCache == "false" {
                returnState = false
            } else {
                returnState = true
            }
            
            print ("Internet Found cache is \(returnState), but refreshing cache in background")
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                self.isInternetAvailableSynchronous()
            }
        
        } else if (Thread.isMainThread == true){
            returnState = false
            print ("Internet Found in main thread, returning false")
            
        } else {
            
            returnState = isInternetAvailableSynchronous()
        }
        
        return returnState;
        
    }

    func isInternetAvailableSynchronous() -> Bool {
        
        var returnState = false
        
        if (isInternetAvailableBasic() == true){
            if (internetCurrentlyTesting == false){
                internetCurrentlyTesting = true
                guard let url = URL(string: networkTestingUrl) else { return false}
                var request = URLRequest(url: url)
                request.timeoutInterval = 10.0
                
                var wait = true
                
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        print("Internet Found \(error.localizedDescription)")
                        returnState = false
                    }
                    if let httpResponse = response as? HTTPURLResponse {
                        print("Internet Found statusCode: \(httpResponse.statusCode)")
                        // do your logic here
                        if httpResponse.statusCode == 200{
                            returnState = true
                            print ("Internet Found returnState = \(returnState)")
                        } else {
                            print("Internet Found  is not 200 status \(httpResponse.statusCode)")
                        }
                        wait = false
                    } else {
                        print ("Internet Found WTF 1")
                        returnState = false
                        wait = false
                    }
                }
                
                task.resume()
                while (wait == true){
                    print ("Internet Found Waiting")
                    sleep(1);
                }
                
                if (returnState == false){
                    internetCheckCache = "false"
                } else {
                    internetCheckCache = "true"
                }
                internetCurrentlyTesting = false
            } else {
                print ("Internet already being tested")
                if internetCheckCache == "false" {
                    returnState = false
                } else {
                    returnState = true
                }
                return returnState
            }
        } else {
            print ("Internet Found is airplane mode...not even testing")
        }
        
        internetCheckCacheDate = NSDate().timeIntervalSince1970 + 15
        
        print ("Internet Found is \(returnState)")
        return returnState
        
    }

    func isInternetAvailableBasic() -> Bool {
        
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }
        
        var flags = SCNetworkReachabilityFlags()
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) {
            return false
        }
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        return (isReachable && !needsConnection)
    }

}

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
import UIKit

// Global network status manager
class NetworkStatusManager {
    static let shared = NetworkStatusManager()
    
    // Global cached network status
    private var _isInternetAvailable: Bool = true // Default to true at startup
    private var _lastTestTime: Date = Date.distantPast
    private var _isCurrentlyTesting: Bool = false
    private let _cacheExpirationInterval: TimeInterval = 15 // 15 seconds cache
    private let _lock = NSLock()
    
    // Thread-safe access to network status
    var isInternetAvailable: Bool {
        get {
            _lock.lock()
            defer { _lock.unlock() }
            
            // If cache is still valid, return cached value
            if Date().timeIntervalSince(_lastTestTime) < _cacheExpirationInterval {
                print("NetworkStatusManager: Returning cached value: \(_isInternetAvailable)")
                return _isInternetAvailable
            }
            
            // Cache expired, trigger background refresh and return last known value
            print("NetworkStatusManager: Cache expired, triggering background refresh")
            triggerBackgroundRefresh()
            return _isInternetAvailable
        }
    }
    
    private init() {
        // Check OS connectivity first, then start background test if needed
        let networkTesting = NetworkTesting()
        if !networkTesting.isInternetAvailableBasic() {
            print("NetworkStatusManager: Initial startup - OS reports no network connectivity")
            _isInternetAvailable = false
            _lastTestTime = Date()
        } else {
            // Start initial network test in background
            triggerBackgroundRefresh()
        }
    }
    
    // Trigger background network test
    private func triggerBackgroundRefresh() {
        guard !_isCurrentlyTesting else {
            print("NetworkStatusManager: Test already in progress, skipping")
            return
        }
        
        _isCurrentlyTesting = true
        print("NetworkStatusManager: Starting background network test")
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.performNetworkTest()
        }
    }
    
    // Perform actual network test
    private func performNetworkTest() {
        let networkTesting = NetworkTesting()
        
        // First check if OS recognizes any network connectivity
        if !networkTesting.isInternetAvailableBasic() {
            print("NetworkStatusManager: OS reports no network connectivity, skipping test")
            _lock.lock()
            _isInternetAvailable = false
            _lastTestTime = Date()
            _isCurrentlyTesting = false
            _lock.unlock()
            return
        }
        
        // Only perform actual network test if OS reports connectivity
        let result = networkTesting.isInternetAvailableSynchronous()
        
        _lock.lock()
        _isInternetAvailable = result
        _lastTestTime = Date()
        _isCurrentlyTesting = false
        _lock.unlock()
        
        print("NetworkStatusManager: Network test completed: \(result)")
    }
    
    // Force immediate network test (for testing purposes)
    func forceNetworkTest(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let networkTesting = NetworkTesting()
            
            // First check if OS recognizes any network connectivity
            if !networkTesting.isInternetAvailableBasic() {
                print("NetworkStatusManager: OS reports no network connectivity, skipping test")
                self?._lock.lock()
                self?._isInternetAvailable = false
                self?._lastTestTime = Date()
                self?._lock.unlock()
                
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            // Only perform actual network test if OS reports connectivity
            let result = networkTesting.isInternetAvailableSynchronous()
            
            self?._lock.lock()
            self?._isInternetAvailable = result
            self?._lastTestTime = Date()
            self?._lock.unlock()
            
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}

open class NetworkTesting {
    
    // Global network availability cache
    private static var cachedNetworkAvailable: Bool?
    private static var lastNetworkTestTime: Date = Date.distantPast
    private static let networkCacheExpiration: TimeInterval = 30.0 // 30 seconds
    private static let networkTestLock = NSLock()
    
    var internetCurrentlyTesting = false
    var testResults = false
    var haveresults = false
    
    init(){
    }

    // Global network availability check with caching
    static func isNetworkAvailable() -> Bool {
        networkTestLock.lock()
        defer { networkTestLock.unlock() }
        
        // Check if cache is still valid
        let now = Date()
        if let cached = cachedNetworkAvailable,
           now.timeIntervalSince(lastNetworkTestTime) < networkCacheExpiration {
            print("NetworkTesting: Returning cached network status: \(cached)")
            return cached
        }
        
        // Cache expired or not available, need to test
        print("NetworkTesting: Cache expired or not available, testing network")
        return false // Will be updated by the test
    }
    
    // Force a network test and update cache
    static func forceNetworkTest() -> Bool {
        let networkTesting = NetworkTesting()
        let result = networkTesting.isInternetAvailableSynchronous()
        
        networkTestLock.lock()
        cachedNetworkAvailable = result
        lastNetworkTestTime = Date()
        networkTestLock.unlock()
        
        print("NetworkTesting: Force test completed, cache updated: \(result)")
        return result
    }
    
    // New main entry point - always returns cached value and triggers background refresh
    func isInternetAvailable() -> Bool {
        return NetworkStatusManager.shared.isInternetAvailable
    }

    func isInternetAvailableSynchronous() -> Bool {
        
        var returnState = false
        
        if (isInternetAvailableBasic() == true){
            if (internetCurrentlyTesting == false){
                internetCurrentlyTesting = true
                
                // Try multiple test URLs to ensure reliable network detection
                let testUrls = [
                    "https://www.dropbox.com"
                ]
                
                var testUrl = testUrls[0] // Default to first URL
                guard let url = URL(string: testUrl) else { return false}
                var request = URLRequest(url: url)
                request.timeoutInterval = 4.0 // 4 second timeout for faster failure
                request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData // Force fresh request
                
                var wait = true
                var startTime = Date()
                
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    let elapsedTime = Date().timeIntervalSince(startTime)
                    print("Internet test completed in \(elapsedTime)s")
                    
                    if let error = error {
                        print("Internet Found error: \(error.localizedDescription)")
                        returnState = false
                    } else if let httpResponse = response as? HTTPURLResponse {
                        print("Internet Found statusCode: \(httpResponse.statusCode)")
                        if httpResponse.statusCode == 200{
                            returnState = true
                            print ("Internet Found returnState = \(returnState)")
                        } else {
                            print("Internet Found is not 200 status \(httpResponse.statusCode)")
                            returnState = false
                        }
                    } else {
                        print ("Internet Found no response")
                        returnState = false
                    }
                    wait = false
                }
                
                task.resume()
                
                // Add a maximum wait time to prevent infinite waiting
                let maxWaitTime: TimeInterval = 4.0 // 4 seconds max
                let waitStartTime = Date()
                
                while (wait == true){
                    let elapsedWaitTime = Date().timeIntervalSince(waitStartTime)
                    if elapsedWaitTime >= maxWaitTime {
                        print("Internet Found timeout after \(elapsedWaitTime)s")
                        returnState = false
                        wait = false
                        break
                    }
                    print ("Internet Found Waiting (\(elapsedWaitTime)s)")
                    usleep(100000); // 0.1 second intervals
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
        
        // Update global cache
        NetworkTesting.networkTestLock.lock()
        NetworkTesting.cachedNetworkAvailable = returnState
        NetworkTesting.lastNetworkTestTime = Date()
        NetworkTesting.networkTestLock.unlock()
        
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
    
    func forgroundNetworkTest(callingGui: UIViewController)->Bool {
        // Check cache first
        let cachedResult = NetworkTesting.isNetworkAvailable()
        if cachedResult {
            print("NetworkTesting: Using cached network status: true")
            return true
        }
        
        // If cache says false or expired, perform test
        self.testResults = false

        let semaphore = DispatchSemaphore(value: 0)

        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            self.testResults = self.isInternetAvailableSynchronous()
            semaphore.signal()
        }

        // Wait with timeout to prevent infinite hanging
        let timeoutResult = semaphore.wait(timeout: .now() + 5.0)
        if timeoutResult == .timedOut {
            print("Network test semaphore timed out after 5 seconds")
            return false
        }
        
        return testResults
    }

}

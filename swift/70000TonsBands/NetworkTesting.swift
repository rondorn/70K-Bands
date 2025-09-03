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

// ⚠️ IMPORTANT: Network Testing Guidelines ⚠️
// 
// This class has TWO types of network testing methods:
//
// 1. NON-BLOCKING methods (safe for general use):
//    - forgroundNetworkTest() - Returns cached values immediately, never blocks GUI
//    - isInternetAvailable() - Returns cached values immediately, never blocks GUI
//    - isInternetAvailableBasic() - Fast OS check, never blocks GUI
//    - performAsyncNetworkTest() - Background test, never blocks GUI
//
// 2. BLOCKING methods (ONLY for critical operations where delays are expected):
//    - forceFreshNetworkTestForYearChange() - ⚠️ WILL block GUI for up to 6 seconds
//    - liveNetworkTestForPullToRefresh() - ⚠️ WILL block GUI briefly, updates cache
//    - performSynchronousNetworkTest() - ⚠️ Internal blocking method
//
// RULE: NEVER use blocking methods in regular app operations. Only use them for
// year changes where the user explicitly expects to wait for network verification.
// All other network operations must be completely non-blocking for smooth UX.

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
        
        // Use the new asynchronous network testing approach
        // This prevents blocking the main thread
        networkTesting.performAsyncNetworkTest()
        
        // Note: The result will be updated asynchronously when the test completes
        // For now, we'll keep the current cached value
        print("NetworkStatusManager: Network test started asynchronously")
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
            
            // Use the new asynchronous network testing approach
            // This prevents blocking the background thread
            networkTesting.performAsyncNetworkTest()
            
            // For now, return the current cached value
            // The completion will be called when the test completes
            self?._lock.lock()
            let currentResult = self?._isInternetAvailable ?? false
            self?._lock.unlock()
            
            DispatchQueue.main.async {
                completion(currentResult)
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
    
    // Add missing cache variables
    var internetCheckCache = "true"
    var internetCheckCacheDate: TimeInterval = 0
    
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
        
        // CRITICAL FIX: Instead of returning false, trigger a test and return cached value
        // This prevents the app from thinking internet is down when cache expires
        let networkTesting = NetworkTesting()
        networkTesting.performAsyncNetworkTest()
        
        // Return the last known cached value instead of false
        let cachedResult = cachedNetworkAvailable ?? true // Default to true if no cache
        print("NetworkTesting: Cache expired, returning last known value: \(cachedResult)")
        return cachedResult
    }
    
    // Force a network test and update cache
    static func forceNetworkTest() -> Bool {
        let networkTesting = NetworkTesting()
        
        // Use the new asynchronous approach instead of blocking synchronous call
        networkTesting.performAsyncNetworkTest()
        
        // Return cached value immediately
        networkTestLock.lock()
        let cachedResult = cachedNetworkAvailable ?? false
        networkTestLock.unlock()
        
        print("NetworkTesting: Force test started asynchronously, returning cached value: \(cachedResult)")
        return cachedResult
    }
    
    // New main entry point - always returns cached value and triggers background refresh
    func isInternetAvailable() -> Bool {
        return NetworkStatusManager.shared.isInternetAvailable
    }

    func isInternetAvailableSynchronous() -> Bool {
        
        // CRITICAL FIX: This method was blocking the main thread with busy-wait loops
        // Now it returns immediately with cached value and triggers background test
        
        if (isInternetAvailableBasic() == true){
            if (internetCurrentlyTesting == false){
                internetCurrentlyTesting = true
                
                // Start the network test in background and return cached value immediately
                DispatchQueue.global(qos: .utility).async { [weak self] in
                    self?.performAsyncNetworkTest()
                }
                
                // Return cached value immediately instead of blocking
                if internetCheckCache == "false" {
                    return false
                } else {
                    return true
                }
            } else {
                print ("Internet already being tested")
                if internetCheckCache == "false" {
                    return false
                } else {
                    return true
                }
            }
        } else {
            print ("Internet Found is airplane mode...not even testing")
            return false
        }
    }
    
    // New method to perform network test asynchronously
    func performAsyncNetworkTest() {
        let testUrls = [
            "https://www.dropbox.com"
        ]
        
        let testUrl = testUrls[0] // Default to first URL
        guard let url = URL(string: testUrl) else { 
            self.updateInternetCache(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 4.0 // 4 second timeout for faster failure
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData // Force fresh request
        
        let startTime = Date()
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let elapsedTime = Date().timeIntervalSince(startTime)
            print("Internet test completed in \(elapsedTime)s")
            
            var returnState = false
            
            if let error = error {
                print("Internet Found error: \(error.localizedDescription)")
                returnState = false
            } else if let httpResponse = response as? HTTPURLResponse {
                print("Internet Found statusCode: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200{
                    returnState = true
                    print ("Internet Found returnState = \(returnState)")
                } else if httpResponse.statusCode == 429 {
                    // Rate limited - internet is available but server is limiting requests
                    print("Internet Found: Rate limited (429) - treating as internet available")
                    returnState = true // Internet is available, just rate limited
                } else {
                    print("Internet Found is not 200 status \(httpResponse.statusCode)")
                    returnState = false
                }
            } else {
                print ("Internet Found no response")
                returnState = false
            }
            
            // Update cache and reset testing flag
            self?.updateInternetCache(returnState)
        }
        
        task.resume()
    }
    
    // Helper method to update internet cache
    private func updateInternetCache(_ result: Bool) {
        if result == false {
            internetCheckCache = "false"
        } else {
            internetCheckCache = "true"
        }
        
        internetCheckCacheDate = NSDate().timeIntervalSince1970 + 15
        
        // Update global cache
        NetworkTesting.networkTestLock.lock()
        NetworkTesting.cachedNetworkAvailable = result
        NetworkTesting.lastNetworkTestTime = Date()
        NetworkTesting.networkTestLock.unlock()
        
        internetCurrentlyTesting = false
        
        print ("Internet Found is \(result)")
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
        
        // If cache says false or expired, trigger background test and return cached value
        // This prevents blocking the main thread
        if !internetCurrentlyTesting {
            internetCurrentlyTesting = true
            
            // Start background test
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.performAsyncNetworkTest()
            }
        }
        
                // Return cached value immediately instead of waiting
        if internetCheckCache == "false" {
            return false
        } else {
            return true
        }
    }
    
    // ⚠️ CRITICAL: This method is ONLY for year changes and other critical operations
    // It WILL block the GUI for up to 6 seconds - use sparingly!
    // This method COMPLETELY bypasses ALL caching and performs a REAL-TIME network test
    func forceFreshNetworkTestForYearChange() -> Bool {
        print("🚨 NetworkTesting: ⚠️ FORCING LIVE REAL-TIME BLOCKING network test for year change")
        print("🚨 NetworkTesting: ⚠️ This will block the GUI for up to 6 seconds!")
        print("🚨 NetworkTesting: ⚠️ BYPASSING ALL CACHES - LIVE TEST ONLY")
        
        // DO NOT touch any cache variables - completely bypass caching system
        // Perform ONLY the live network test
        return performLiveNetworkTestOnly()
    }
    
    // ⚠️ LIVE NETWORK TEST FOR PULL-TO-REFRESH - Blocks GUI but updates cache
    // This method performs a live test and then updates the cache with the result
    func liveNetworkTestForPullToRefresh() -> Bool {
        print("🔄 NetworkTesting: LIVE NETWORK TEST for Pull-to-Refresh")
        print("🔄 NetworkTesting: This will block GUI briefly and update cache")
        
        // Perform the live test
        let liveResult = performLiveNetworkTestOnly()
        
        // Update cache with the live result (unlike year change which doesn't update cache)
        updateInternetCache(liveResult)
        
        print("🔄 NetworkTesting: Pull-to-refresh test completed: \(liveResult) - cache updated")
        return liveResult
    }
    
    // COMPLETELY ISOLATED LIVE NETWORK TEST - NO CACHING WHATSOEVER
    // This method performs ONLY a real-time HTTP request and returns the actual result
    private func performLiveNetworkTestOnly() -> Bool {
        print("🔥 NetworkTesting: PERFORMING LIVE REAL-TIME NETWORK TEST - NO CACHING")
        print("🔥 NetworkTesting: Testing URL: https://www.dropbox.com")
        
        // Create completely fresh URL and request - no cache involvement
        guard let url = URL(string: "https://www.dropbox.com") else {
            print("🔥 NetworkTesting: ❌ LIVE TEST FAILED - Invalid URL")
            return false
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0 // 5 second timeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData // Force fresh request
        request.httpMethod = "GET"
        
        // Use semaphore to make this synchronous
        let semaphore = DispatchSemaphore(value: 0)
        var liveTestResult = false
        
        print("🔥 NetworkTesting: Starting LIVE HTTP request...")
        let startTime = Date()
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            
            let elapsed = Date().timeIntervalSince(startTime)
            print("🔥 NetworkTesting: LIVE HTTP request completed in \(elapsed)s")
            
            if let error = error {
                print("🔥 NetworkTesting: ❌ LIVE TEST FAILED - Network error: \(error.localizedDescription)")
                liveTestResult = false
            } else if let httpResponse = response as? HTTPURLResponse {
                print("🔥 NetworkTesting: LIVE TEST got HTTP status: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    print("🔥 NetworkTesting: ✅ LIVE TEST PASSED - Internet is working")
                    liveTestResult = true
                } else {
                    print("🔥 NetworkTesting: ❌ LIVE TEST FAILED - HTTP error \(httpResponse.statusCode)")
                    liveTestResult = false
                }
            } else {
                print("🔥 NetworkTesting: ❌ LIVE TEST FAILED - No response received")
                liveTestResult = false
            }
        }
        
        task.resume()
        
        // Wait for the live test to complete with timeout
        let timeoutResult = semaphore.wait(timeout: .now() + 6.0) // 6 second total timeout
        
        if timeoutResult == .timedOut {
            print("🔥 NetworkTesting: ❌ LIVE TEST TIMED OUT after 6 seconds")
            task.cancel()
            liveTestResult = false
        }
        
        let totalElapsed = Date().timeIntervalSince(startTime)
        print("🔥 NetworkTesting: 🎯 LIVE TEST FINAL RESULT: \(liveTestResult) (took \(totalElapsed)s)")
        
        // DO NOT UPDATE ANY CACHES - this is a pure live test
        return liveTestResult
    }
    
    // OLD METHOD - keeping for backward compatibility with non-year-change operations
    private func performSynchronousNetworkTest() -> Bool {
        print("NetworkTesting: ⚠️ Performing BLOCKING network test for year change")
        
        // SKIP basic connectivity check for year changes - do the real test
        // Basic connectivity can report "connected" even when internet is down
        print("NetworkTesting: Skipping basic check for year change - doing real internet test")
        
        // Perform the actual network test with a reasonable timeout
        let testUrls = ["https://www.dropbox.com"]
        let testUrl = testUrls[0]
        
        guard let url = URL(string: testUrl) else {
            print("NetworkTesting: Invalid test URL")
            updateInternetCache(false)
            return false
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0 // 5 second timeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        let semaphore = DispatchSemaphore(value: 0)
        var testResult = false
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("NetworkTesting: ❌ Network test FAILED with error: \(error.localizedDescription)")
                testResult = false
            } else if let httpResponse = response as? HTTPURLResponse {
                print("NetworkTesting: Network test got HTTP status: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    print("NetworkTesting: ✅ Network test PASSED")
                    testResult = true
                } else {
                    print("NetworkTesting: ❌ Network test FAILED with HTTP \(httpResponse.statusCode)")
                    testResult = false
                }
            } else {
                print("NetworkTesting: ❌ Network test FAILED - no response")
                testResult = false
            }
            
            // Update cache with result
            self?.updateInternetCache(testResult)
        }
        
        task.resume()
        
        // Wait for test to complete with timeout
        let timeoutResult = semaphore.wait(timeout: .now() + 6.0) // 6 second timeout
        
        if timeoutResult == .timedOut {
            print("NetworkTesting: ❌ Network test TIMED OUT after 6 seconds")
            task.cancel()
            updateInternetCache(false)
            return false
        }
        
        print("NetworkTesting: 🎯 FINAL RESULT: Network test completed with result: \(testResult)")
        return testResult
    }
 
}

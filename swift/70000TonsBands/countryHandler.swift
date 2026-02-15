//
//  countryHandler.swift
//  70K Bands
//
//  Created by Ron Dorn on 11/9/22.
//  Copyright © 2022 Ron Dorn. All rights reserved.
//

import Foundation
import CloudKit

/// Data structure for caching country mappings
private struct CountryCache: Codable {
    let countryShortLong: [String: String]
    let countryLongShort: [String: String]
}

class countryHandler {
    
    var countryShortLong = [String:String]()
    var countryLongShort = [String:String]()
    
    // Persistent caching properties
    private static var isDataLoaded = false
    private static var loadingLock = NSLock()
    private static let cacheFileName = "countryDataCache.json"
    private static var cacheFileURL: URL {
        let documentsPath = getDocumentsDirectory()
        return URL(fileURLWithPath: documentsPath as String).appendingPathComponent(cacheFileName)
    }
    
    // Singleton pattern for shared country data
    static let shared = countryHandler()
    
    init(){
        // Load cached data on initialization
        loadCachedDataIfAvailable()
    }
    
    /// Returns a dictionary mapping country short codes to their long names.
    /// - Returns: A dictionary with country short codes as keys and long names as values.
    func getCountryShortLong()->[String:String]{
        return countryShortLong
    }
    
    /// Returns a dictionary mapping country long names to their short codes.
    /// - Returns: A dictionary with country long names as keys and short codes as values.
    func getCountryLongShort()->[String:String]{
        return countryLongShort
    }
    
    /// Loads cached country data from disk if available
    private func loadCachedDataIfAvailable() {
        countryHandler.loadingLock.lock()
        defer { countryHandler.loadingLock.unlock() }
        
        // Check if we already have data loaded
        if countryHandler.isDataLoaded && !countryShortLong.isEmpty {
            return
        }
        
        // Try to load from cache first
        if loadFromCache() {
            print("CountryHandler: Loaded country data from cache (\(countryShortLong.count) countries)")
            countryHandler.isDataLoaded = true
            return
        }
        
        print("CountryHandler: No cache found, will load from bundle when needed")
    }
    
    /// Loads country data from cache file
    /// - Returns: true if cache was loaded successfully, false otherwise
    private func loadFromCache() -> Bool {
        guard FileManager.default.fileExists(atPath: countryHandler.cacheFileURL.path) else {
            return false
        }
        
        do {
            let data = try Data(contentsOf: countryHandler.cacheFileURL)
            let decoder = JSONDecoder()
            let cachedData = try decoder.decode(CountryCache.self, from: data)
            
            self.countryShortLong = cachedData.countryShortLong
            self.countryLongShort = cachedData.countryLongShort
            
            return !countryShortLong.isEmpty
        } catch {
            print("CountryHandler: Failed to load cache: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Saves country data to cache file
    private func saveToCache() {
        do {
            let cacheData = CountryCache(
                countryShortLong: countryShortLong,
                countryLongShort: countryLongShort
            )
            let encoder = JSONEncoder()
            let data = try encoder.encode(cacheData)
            try data.write(to: countryHandler.cacheFileURL)
            
            print("CountryHandler: Successfully cached country data (\(countryShortLong.count) countries)")
        } catch {
            print("CountryHandler: Failed to save cache: \(error.localizedDescription)")
        }
    }
    
    /// Loads country data from cache or bundled file (thread-safe with caching)
    /// - Parameter completion: Optional completion handler called when loading is complete
    func loadCountryData(completion: (() -> Void)? = nil) {
        countryHandler.loadingLock.lock()
        
        // Check if data is already loaded
        if countryHandler.isDataLoaded && !countryShortLong.isEmpty {
            countryHandler.loadingLock.unlock()
            print("CountryHandler: Data already loaded, skipping")
            completion?()
            return
        }
        countryHandler.loadingLock.unlock()
        
        // Move heavy processing to background thread to prevent GUI blocking
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            countryHandler.loadingLock.lock()
            defer { countryHandler.loadingLock.unlock() }
            
            // Double-check after acquiring lock
            if countryHandler.isDataLoaded && !self.countryShortLong.isEmpty {
                DispatchQueue.main.async { completion?() }
                return
            }
            
            print("CountryHandler: Loading country data from bundle...")
            
            guard let filepath = Bundle.main.path(forResource: "countries", ofType: "txt") else {
                print("CountryHandler: countries.txt not found in bundle")
                DispatchQueue.main.async { completion?() }
                return
            }
            
            do {
                let contents = try String(contentsOfFile: filepath)
                let keys = contents.components(separatedBy: "\n")
                
                var tempShortLong = [String: String]()
                var tempLongShort = [String: String]()
                
                for value in keys {
                    if value.contains(",") {
                        let values = value.components(separatedBy: ",")
                        guard values.count >= 2 else { continue }
                        
                        let countryLongName = values[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        let countryShortName = values[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if !countryLongName.isEmpty && !countryShortName.isEmpty {
                            tempLongShort[countryLongName] = countryShortName
                            tempShortLong[countryShortName] = countryLongName
                        }
                    }
                }
                
                // Update dictionaries atomically
                self.countryLongShort = tempLongShort
                self.countryShortLong = tempShortLong
                
                // Save to cache for next time
                self.saveToCache()
                
                countryHandler.isDataLoaded = true
                print("CountryHandler: Successfully loaded \(self.countryShortLong.count) countries from bundle")
                
                DispatchQueue.main.async { completion?() }
                
            } catch {
                print("CountryHandler: Failed to load countries from bundle: \(error.localizedDescription)")
                DispatchQueue.main.async { completion?() }
            }
        }
    }
    
    /// Ensures country data is loaded (synchronous for backward compatibility)
    /// WARNING: Only use this method if you're already on a background thread
    func ensureCountryDataLoaded() {
        if countryHandler.isDataLoaded && !countryShortLong.isEmpty {
            return
        }
        
        // Load synchronously from cache if available
        if loadFromCache() {
            countryHandler.isDataLoaded = true
            return
        }
        
        // If no cache, load synchronously from bundle (ONLY for backward compatibility)
        // This should only be called from background threads or during app setup
        print("CountryHandler: WARNING - Loading country data synchronously from bundle. This may block the thread.")
        
        guard let filepath = Bundle.main.path(forResource: "countries", ofType: "txt") else {
            print("CountryHandler: countries.txt not found in bundle")
            return
        }
        
        do {
            let contents = try String(contentsOfFile: filepath)
            let keys = contents.components(separatedBy: "\n")
            
            var tempShortLong = [String: String]()
            var tempLongShort = [String: String]()
            
            for value in keys {
                if value.contains(",") {
                    let values = value.components(separatedBy: ",")
                    guard values.count >= 2 else { continue }
                    
                    let countryLongName = values[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let countryShortName = values[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !countryLongName.isEmpty && !countryShortName.isEmpty {
                        tempLongShort[countryLongName] = countryShortName
                        tempShortLong[countryShortName] = countryLongName
                    }
                }
            }
            
            // Update dictionaries atomically
            self.countryLongShort = tempLongShort
            self.countryShortLong = tempShortLong
            
            // Save to cache for next time
            saveToCache()
            
            countryHandler.isDataLoaded = true
            print("CountryHandler: Synchronously loaded \(self.countryShortLong.count) countries from bundle")
            
        } catch {
            print("CountryHandler: Failed to load countries synchronously: \(error.localizedDescription)")
        }
    }
    
}


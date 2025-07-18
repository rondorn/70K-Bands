//
//  bandNames.swift
//  70000TonsApp
//
//  Created by Ron Dorn on 12/23/14.
//  Copyright (c) 2014 Ron Dorn. All rights reserved.
//

import Foundation

open class bandNamesHandler {

    var bandNames =  [String :[String : String]]()
    var bandNamesArray = [String]()
    
    init(){
        print ("Loading bandName Data")
        getCachedData()
    }
    
    /// Loads band name data from cache if available, otherwise loads from disk or Dropbox.
    func getCachedData(completion: (() -> Void)? = nil){
        print("[LOG] getCachedData: START")
        staticBandName.sync() {
            if (cacheVariables.bandNamesStaticCache.isEmpty == false && cacheVariables.bandNamesArrayStaticCache.isEmpty == false ){
                print("[LOG] getCachedData: Loading from cache")
                bandNames = cacheVariables.bandNamesStaticCache
                bandNamesArray = cacheVariables.bandNamesArrayStaticCache
                print("[LOG] getCachedData: END (from cache)")
                completion?()
            } else {
                DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                    print("[LOG] getCachedData: Loading from disk or dropbox")
                    self.gatherData(completion: completion)
                }
            }
        }
        print("[LOG] getCachedData: EXIT")
    }
    
    /// Clears the static cache of band names.
    func clearCachedData(){
        cacheVariables.bandNamesStaticCache = [String :[String : String]]()
    }
    
    /// Gathers band data from the internet if available, writes it to file, and populates the cache.
    /// Calls completion handler when done.
    func gatherData(completion: (() -> Void)? = nil) {
        print("[LOG] gatherData: START")
        var didCallCompletion = false
        let timeoutWorkItem = DispatchWorkItem {
            if !didCallCompletion {
                print("[LOG] gatherData: TIMEOUT - calling completion fallback after 10s")
                didCallCompletion = true
                completion?()
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 10, execute: timeoutWorkItem)
        if isInternetAvailable() == true {
            eventYear = Int(getPointerUrlData(keyValue: "eventYear"))!
            print ("Loading bandName Data gatherData")
            var artistUrl = getPointerUrlData(keyValue: "artistUrl") ?? "http://dropbox.com"
            print ("Getting band data from " + artistUrl);
            let httpData = getUrlData(urlString: artistUrl)
            print ("Getting band data of " + httpData);
            if (httpData.isEmpty == false) {
                writeBandFile(httpData);
            } else {
                print ("Internet is down, prevented blanking out data")
            }
        }
        readBandFile()
        // Defensive type check for bandNames
        if let bandNamesDict = bandNames as? [String: [String: String]] {
            if bandNamesDict.isEmpty && !cacheVariables.justLaunched {
                print("[LOG] gatherData: Skipping cache population: bandNames is empty and app is not just launched.")
                if !didCallCompletion {
                    didCallCompletion = true
                    timeoutWorkItem.cancel()
                    completion?()
                }
                print("[LOG] gatherData: END (empty bandNames)")
                return
            }
        } else {
            print("[LOG] ERROR: bandNames is not a dictionary! Actual type: \(type(of: bandNames)) Value: \(bandNames)")
            bandNames = [String: [String: String]]()
            if !didCallCompletion {
                didCallCompletion = true
                timeoutWorkItem.cancel()
                completion?()
            }
            print("[LOG] gatherData: END (bad type)")
            return
        }
        populateCache {
            if !didCallCompletion {
                didCallCompletion = true
                timeoutWorkItem.cancel()
                print("[LOG] gatherData: END (populateCache complete)")
                completion?()
            }
        }
    }

    /// Populates the static cache variables with the current bandNames dictionary.
    /// Posts a notification when the cache is ready and calls the completion handler.
    func populateCache(completion: (() -> Void)? = nil){
        print("[LOG] populateCache: START")
        staticBandName.async(flags: .barrier) {
            cacheVariables.bandNamesStaticCache =  [String :[String : String]]()
            cacheVariables.bandNamesArrayStaticCache = [String]()
            for bandName in self.bandNames.keys {
                // Defensive: Only add if bandName is String and value is [String: String]
                if let bandDict = self.bandNames[bandName] as? [String: String] {
                    cacheVariables.bandNamesStaticCache[bandName] = bandDict
                    cacheVariables.bandNamesArrayStaticCache.append(bandName)
                } else {
                    print("[LOG] Warning: bandNames[\(bandName)] is not a [String: String]: \(String(describing: self.bandNames[bandName]))")
                }
            }
            DispatchQueue.main.async {
                print("[LOG] populateCache: END (cache ready)")
                NotificationCenter.default.post(name: .bandNamesCacheReady, object: nil)
                completion?()
            }
        }
    }
    
    /// Writes the provided HTTP data string to the band file on disk.
    /// - Parameter httpData: The string data to write to file.
    func writeBandFile (_ httpData: String){
        
        print("write file " + bandFile);
        print (httpData);

        do {
           try httpData.write(toFile: bandFile, atomically: true,encoding: String.Encoding.utf8)
            print ("Just created file bandFile " + bandFile);
        } catch let error as NSError {
            print ("Encountered an error of creating file " + error.debugDescription)
        }
        
    }


    /// Reads the band file from disk and populates the bandNames and bandNamesArray dictionaries.
    /// Handles parsing of CSV data and extraction of band properties.
    func readBandFile (){
        
        if (readingBandFile == false){
            readingBandFile = true
            print ("Loading bandName Data readBandFile")
            print ("Reading content of file " + bandFile);
            
            if let csvDataString = try? String(contentsOfFile: bandFile, encoding: String.Encoding.utf8) {
                print("csvDataString has data", terminator: "");
                
                bandNames =  [String :[String : String]]()
                bandNamesArray = [String]()
                
                //var unuiqueIndex = Dictionary<NSTimeInterval, Int>()
                var csvData: CSV
                
                //var error: NSErrorPointer = nil
                csvData = try! CSV(csvStringToParse: csvDataString)
                
                for lineData in csvData.rows {
                    
                    if (lineData["bandName"]?.isEmpty == false){
                        print ("Working on band " + lineData["bandName"]!)
                        
                        let bandNameValue = lineData["bandName"]!
                        
                        bandNames[bandNameValue] = [String : String]()
                        bandNames[bandNameValue]!["bandName"] = bandNameValue
                        
                        if (lineData.isEmpty == false){
                            if let value = lineData["imageUrl"], !value.isEmpty {
                                bandNames[bandNameValue]!["bandImageUrl"] = "http://" + String(describing: value)
                            }
                            if let value = lineData["officalSite"], !value.isEmpty {
                                bandNames[bandNameValue]!["officalUrls"] = "http://" + String(describing: value)
                            }
                            if let value = lineData["wikipedia"], !value.isEmpty {
                                bandNames[bandNameValue]!["wikipediaLink"] = String(describing: value)
                            }
                            if let value = lineData["youtube"], !value.isEmpty {
                                bandNames[bandNameValue]!["youtubeLinks"] = String(describing: value)
                            }
                            if let value = lineData["metalArchives"], !value.isEmpty {
                                bandNames[bandNameValue]!["metalArchiveLinks"] = String(describing: value)
                            }
                            if let value = lineData["country"], !value.isEmpty {
                                bandNames[bandNameValue]!["bandCountry"] = String(describing: value)
                            }
                            if let value = lineData["genre"], !value.isEmpty {
                                bandNames[bandNameValue]!["bandGenre"] = String(describing: value)
                            }
                            if let value = lineData["noteworthy"], !value.isEmpty {
                                bandNames[bandNameValue]!["bandNoteWorthy"] = String(describing: value)
                            }
                            if let value = lineData["priorYears"], !value.isEmpty {
                                bandNames[bandNameValue]!["priorYears"] = String(describing: value)
                            }
                        }
                    }
                }
                
            } else {
                print ("Could not read file for some reason");
                do {
                    try NSString(contentsOfFile: bandFile, encoding: String.Encoding.utf8.rawValue)
                    
                } catch let error as NSError {
                    print ("Encountered an error on reading file" + error.debugDescription)
                }
            }
            readingBandFile = false
        }
    }

    /// Returns a sorted array of all band names. Loads from cache if necessary.
    /// - Returns: An array of band name strings.
    func getBandNames () -> [String] {
        
        bandNamesArray = [String]()
        
        print ("bandNames data is \(bandNames)")
        if (bandNames.isEmpty == true){
            getCachedData()
        }
        
        if (bandNames.isEmpty == false){
            if (bandNames.count >= 1){
                for bandNameValue in bandNames.keys {
                    bandNamesArray.append(bandNameValue)
                }
                bandNamesArray.sort();
            }
        } else {
            print ("can not load data\n");
            //getCachedData()
            //bandNamesArray.append("Unable to load band data, unknown error")
        }
        print ("bandNamesArray data is \(bandNamesArray)")
        return bandNamesArray
    }

    /// Returns the image URL for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The image URL string.
    func getBandImageUrl(_ band: String) -> String {
        
        print ("Getting image for band \(band) will return \(String(describing: bandNames[band]))")
        return bandNames[band]?["bandImageUrl"] ?? ""
    }

    /// Returns the official website URL for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The official website URL string.
    func getofficalPage (_ band: String) -> String {
        
        print ("Getting officalSite for band \(band) will return \(String(describing: bandNames[band]?["officalUrls"]))")
        
        return bandNames[band]?["officalUrls"] ?? ""
        
    }

    /// Returns the Wikipedia page URL for a given band, localized to the user's language if possible.
    /// - Parameter bandName: The name of the band.
    /// - Returns: The Wikipedia URL string.
    func getWikipediaPage (_ bandName: String) -> String{
        
        var wikipediaUrl = bandNames[bandName]?["wikipediaLink"] ?? ""
        
        if (wikipediaUrl.isEmpty == false){

            let language: String = Locale.current.languageCode!
            
            print ("Language is " + language);
            if (language != "en"){
                let replacement: String = language + ".wikipedia.org";
                
                wikipediaUrl = wikipediaUrl.replacingOccurrences(of: "en.wikipedia.org", with:replacement)
            }
        }
        
        return (wikipediaUrl)
        
    }
    
    /// Returns the YouTube page URL for a given band, localized to the user's language if possible.
    /// - Parameter bandName: The name of the band.
    /// - Returns: The YouTube URL string.
    func getYouTubePage (_ bandName: String) -> String{
        
        var youTubeUrl = bandNames[bandName]?["youtubeLinks"] ?? ""
        
        if (youTubeUrl.isEmpty == false){

            let language: String = Locale.preferredLanguages[0]
            
            if (language != "en"){
                youTubeUrl = youTubeUrl + "&hl=" + language
            }
        }
        
        return (youTubeUrl)
        
    }
    
    /// Returns the Metal Archives URL for a given band, or an empty string if not found.
    /// - Parameter bandName: The name of the band.
    /// - Returns: The Metal Archives URL string.
    func getMetalArchives (_ bandName: String) -> String {
        
        return bandNames[bandName]?["metalArchiveLinks"] ?? ""
    }
    
    /// Returns the country for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The country string.
    func getBandCountry (_ band: String) -> String {
        
        return bandNames[band]?["bandCountry"] ?? ""
    }
    
    /// Returns the genre for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The genre string.
    func getBandGenre (_ band: String) -> String {
        
        return bandNames[band]?["bandGenre"] ?? ""
    }

    /// Returns the 'noteworthy' field for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The noteworthy string.
    func getBandNoteWorthy (_ band: String) -> String {
        
        return bandNames[band]?["bandNoteWorthy"] ?? ""
    }

    /// Returns a comma-separated string of prior years for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The prior years string.
    func getPriorYears (_ band: String) -> String {
        
        var previousYears = bandNames[band]?["priorYears"]
        
        previousYears = previousYears?.replacingOccurrences(of: " ", with: ", ")
        
        return previousYears ?? ""
    }

    private enum DataCollectionState {
        case idle
        case running
        case queued
        case eventYearOverridePending
    }
    private var state: DataCollectionState = .idle
    private let dataCollectionQueue = DispatchQueue(label: "com.70kBands.bandNamesHandler.dataCollectionQueue")
    private var queuedRequest: (() -> Void)?
    private var eventYearOverrideRequested: Bool = false
    private var cancelRequested: Bool = false

    /// Request a band data collection. If eventYearOverride is true, aborts all others and runs immediately.
    func requestDataCollection(eventYearOverride: Bool = false, completion: (() -> Void)? = nil) {
        dataCollectionQueue.async { [weak self] in
            guard let self = self else { return }
            if eventYearOverride {
                // Cancel everything and run this immediately
                self.eventYearOverrideRequested = true
                self.cancelRequested = true
                self.queuedRequest = nil
                if self.state == .running {
                    self.state = .eventYearOverridePending
                } else {
                    self.state = .running
                    self._startDataCollection(eventYearOverride: true, completion: completion)
                }
            } else {
                if self.state == .idle {
                    self.state = .running
                    self._startDataCollection(eventYearOverride: false, completion: completion)
                } else if self.state == .running && self.queuedRequest == nil {
                    // Queue one more
                    self.queuedRequest = { [weak self] in self?.requestDataCollection(eventYearOverride: false, completion: completion) }
                    self.state = .queued
                } else {
                    // Already queued, ignore further requests
                }
            }
        }
    }

    private func _startDataCollection(eventYearOverride: Bool, completion: (() -> Void)?) {
        cancelRequested = false
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self._gatherDataWithCancellation(eventYearOverride: eventYearOverride, completion: completion)
        }
    }

    private func _gatherDataWithCancellation(eventYearOverride: Bool, completion: (() -> Void)?) {
        if isInternetAvailable() == true {
            eventYear = Int(getPointerUrlData(keyValue: "eventYear"))!
            print ("Loading bandName Data gatherData (cancellable)")
            var artistUrl = getPointerUrlData(keyValue: "artistUrl") ?? "http://dropbox.com"
            print ("Getting band data from " + artistUrl);
            let httpData = getUrlData(urlString: artistUrl)
            if cancelRequested { self._dataCollectionDidFinish(); completion?(); return }
            print ("Getting band data of " + httpData);
            if (httpData.isEmpty == false) {
                writeBandFile(httpData);
            } else {
                print ("Internet is down, prevented blanking out data")
            }
        }
        if cancelRequested { self._dataCollectionDidFinish(); completion?(); return }
        readBandFile()
        if cancelRequested { self._dataCollectionDidFinish(); completion?(); return }
        if bandNames.isEmpty && !cacheVariables.justLaunched {
            print("Skipping cache population: bandNames is empty and app is not just launched.")
            self._dataCollectionDidFinish();
            completion?()
            return
        }
        populateCache(completion: { [weak self] in
            if let self = self {
                self._dataCollectionDidFinish()
                completion?()
            }
        })
    }

    private func _dataCollectionDidFinish() {
        dataCollectionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.eventYearOverrideRequested {
                self.eventYearOverrideRequested = false
                self.cancelRequested = false
                self.state = .idle
                self.requestDataCollection(eventYearOverride: true)
            } else if let next = self.queuedRequest {
                self.queuedRequest = nil
                self.state = .running
                next()
            } else {
                self.state = .idle
            }
        }
    }
}

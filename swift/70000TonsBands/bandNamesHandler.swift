//
//  bandNames.swift
//  70000TonsApp
//
//  Created by Ron Dorn on 12/23/14.
//  Copyright (c) 2014 Ron Dorn. All rights reserved.
//

import Foundation

open class bandNamesHandler {

    // These must only be accessed inside staticBandName queue
    var bandNames =  [String :[String : String]]()
    var bandNamesArray = [String]()
    
    init(){
        print ("Loading bandName Data")
        getCachedData()
    }
    
    /// Loads band name data from cache if available, otherwise loads from disk.
    /// Always shows cached/disk data immediately except on first launch or explicit refresh.
    /// Triggers background update if needed.
    func getCachedData(forceNetwork: Bool = false, completion: (() -> Void)? = nil) {
        print("Loading bandName Data cache")
        var needsNetworkFetch = false
        var showedData = false

        staticBandName.sync {
            if !self.bandNames.isEmpty {
                // Cache is available, show immediately
                print("Loading bandName Data cache, from cache")
                showedData = true
            } else if !cacheVariables.bandNamesStaticCache.isEmpty {
                // cacheVariables has data, load into memory and show immediately
                print("Loading bandName Data cache, from cacheVariables")
                staticBandName.async(flags: .barrier) {
                    self.bandNames = cacheVariables.bandNamesStaticCache
                    self.bandNamesArray = cacheVariables.bandNamesArrayStaticCache
                    DispatchQueue.main.async {
                        completion?()
                    }
                }
                showedData = true
            } else if FileManager.default.fileExists(atPath: bandFile) {
                // Disk file exists, load synchronously and show immediately
                print("Loading bandName Data cache, from disk")
                self.readBandFile()
                showedData = true
            } else {
                // No data at all, need to fetch from network (first launch or forced)
                needsNetworkFetch = true
            }
        }

        if showedData {
            // Show data immediately
            DispatchQueue.main.async {
                completion?()
            }
            // After showing, trigger background update if not just launched or forced
            if (!cacheVariables.justLaunched && !forceNetwork) {
                print("Triggering background update for band data")
                DispatchQueue.global(qos: .background).async {
                    self.gatherData()
                }
            }
        } else if needsNetworkFetch || forceNetwork {
            // If we need to fetch from network (first launch or forced refresh), block UI and fetch
            print("No cached/disk data, fetching from network (blocking UI)")
            DispatchQueue.global(qos: .default).async {
                self.gatherData(completion: completion)
            }
        }
        print("Done Loading bandName Data cache")
    }
    
    /// Clears the static cache of band names.
    func clearCachedData(){
        staticBandName.async(flags: .barrier) {
        cacheVariables.bandNamesStaticCache = [String :[String : String]]()
        }
    }
    
    /// Gathers band data from the internet if available, writes it to file, and populates the cache.
    /// Calls completion handler when done.
    func gatherData(completion: (() -> Void)? = nil) {
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
        var isEmpty = false
        staticBandName.sync {
            isEmpty = self.bandNames.isEmpty
        }
        if isEmpty && cacheVariables.justLaunched {
            print("Band file is empty and app is just launched. Retrying network fetch once more.")
            if isInternetAvailable() == true {
                eventYear = Int(getPointerUrlData(keyValue: "eventYear"))!
                let artistUrl = getPointerUrlData(keyValue: "artistUrl") ?? "http://dropbox.com"
                print ("Retrying: Getting band data from " + artistUrl);
                let httpData = getUrlData(urlString: artistUrl)
                if (httpData.isEmpty == false) {
                    writeBandFile(httpData);
                    readBandFile()
                    staticBandName.sync {
                        isEmpty = self.bandNames.isEmpty
                    }
                    if !isEmpty {
                        print("Band data loaded successfully on retry, setting justLaunched to false.")
                        cacheVariables.justLaunched = false
                        populateCache(completion: completion)
                        return
                    }
                } else {
                    print("Retry failed: Internet is down or data is empty.")
                }
            } else {
                print("Retry failed: No internet connection.")
            }
            print("No band data available after retry. Giving up and calling completion.")
            completion?()
            return
        }
        if !isEmpty {
            print("Band data loaded successfully, setting justLaunched to false.")
            cacheVariables.justLaunched = false
        }
        if isEmpty && !cacheVariables.justLaunched {
            print("Skipping cache population: bandNames is empty and app is not just launched.")
            completion?()
            return
        }
        populateCache(completion: completion)
    }

    /// Populates the static cache variables with the current bandNames dictionary.
    /// Posts a notification when the cache is ready and calls the completion handler.
    func populateCache(completion: (() -> Void)? = nil){
        print ("Starting population of acheVariables.bandNamesStaticCache")
        staticBandName.async(flags: .barrier) {
            cacheVariables.bandNamesStaticCache =  [String :[String : String]]()
            cacheVariables.bandNamesArrayStaticCache = [String]()
            // Read bandNames and bandNamesArray inside the queue
            for bandName in self.bandNames.keys {
                cacheVariables.bandNamesStaticCache[bandName] =  [String : String]()
                cacheVariables.bandNamesStaticCache[bandName] =  self.bandNames[bandName]
                print ("Adding Data to cacheVariables.bandNamesStaticCache = \(String(describing: cacheVariables.bandNamesStaticCache[bandName]))")
                cacheVariables.bandNamesArrayStaticCache.append(bandName)
            }
            DispatchQueue.main.async {
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

    // Add at the top of the class (or where readingBandFile is declared):
    private let readingBandFileQueue = DispatchQueue(label: "com.yourapp.readingBandFileQueue")
    private var _readingBandFile: Bool = false
    var readingBandFile: Bool {
        get { return readingBandFileQueue.sync { _readingBandFile } }
        set { readingBandFileQueue.sync { _readingBandFile = newValue } }
    }

    // Add a recursion/loop guard
    // Change these from private static to static so they are accessible from MasterViewController
    static var readBandFileCallCount = 0
    static var lastReadBandFileCallTime: Date? = nil

    /// Reads the band file from disk and populates the bandNames and bandNamesArray dictionaries.
    /// Handles parsing of CSV data and extraction of band properties.
    func readBandFile (){
        let now = Date()
        if let last = Self.lastReadBandFileCallTime, now.timeIntervalSince(last) < 2 {
            Self.readBandFileCallCount += 1
        } else {
            Self.readBandFileCallCount = 1
        }
        Self.lastReadBandFileCallTime = now
        print("readBandFile called ( Self.readBandFileCallCount) at \(now)")
        if Self.readBandFileCallCount > 10 {
            print("Aborting: readBandFile called too many times in a short period. Possible infinite loop.")
            return
        }
        if readingBandFile == false{
            readingBandFile = true
            print ("Loading bandName Data readBandFile")
            print ("Reading content of file " + bandFile);
            if let csvDataString = try? String(contentsOfFile: bandFile, encoding: String.Encoding.utf8) {
                print("csvDataString has data", terminator: "");
                // Write access: must use barrier
                staticBandName.async(flags: .barrier) {
                    self.bandNames =  [String :[String : String]]()
                    self.bandNamesArray = [String]()
                    var csvData: CSV
                    if let csvData = try? CSV(csvStringToParse: csvDataString) {
                        for lineData in csvData.rows {
                            if (lineData["bandName"]?.isEmpty == false){
                                print ("Working on band " + lineData["bandName"]!)
                                let bandNameValue = lineData["bandName"]!
                                self.bandNames[bandNameValue] = [String : String]()
                                self.bandNames[bandNameValue]! ["bandName"] = bandNameValue
                                if (lineData.isEmpty == false){
                                    if (lineData["imageUrl"] != nil){
                                        self.bandNames[bandNameValue]! ["bandImageUrl"] = "http://" + lineData["imageUrl"]!;
                                    }
                                    if (lineData["officalSite"] != nil){
                                        if (lineData["bandName"] != nil){
                                            self.bandNames[bandNameValue]! ["officalUrls"] = "http://" + lineData["officalSite"]!;
                                        }
                                    }
                                    if (lineData["wikipedia"] != nil){
                                        self.bandNames[bandNameValue]! ["wikipediaLink"] = lineData["wikipedia"]!;
                                    }
                                    if (lineData["youtube"] != nil){
                                        self.bandNames[bandNameValue]! ["youtubeLinks"] = lineData["youtube"]!;
                                    }
                                    if (lineData["metalArchives"] != nil){
                                        self.bandNames[bandNameValue]! ["metalArchiveLinks"] = lineData["metalArchives"]!;
                                    }
                                    if (lineData["country"] != nil){
                                        self.bandNames[bandNameValue]! ["bandCountry"] = lineData["country"]!;
                                    }
                                    if (lineData["genre"] != nil){
                                        self.bandNames[bandNameValue]! ["bandGenre"] = lineData["genre"]!;
                                    }
                                    if (lineData["noteworthy"] != nil){
                                        self.bandNames[bandNameValue]! ["bandNoteWorthy"] = lineData["noteworthy"]!;
                                    }
                                    if (lineData["priorYears"] != nil){
                                        self.bandNames[bandNameValue]! ["priorYears"] = lineData["priorYears"]!;
                                    }
                                }
                                self.bandNamesArray.append(bandNameValue)
                            }
                        }
                    } else {
                        print("Error: Failed to parse CSV data in readBandFile.")
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
        // After band names data is loaded and parsed:
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("BandNamesDataReady"), object: nil)
        }
    }

    /// Force read the band file and populate cache, bypassing the recursion/loop guard
    func forceReadBandFileAndPopulateCache(completion: (() -> Void)? = nil) {
        self._readingBandFile = true
        self.readBandFile()
        self._readingBandFile = false
        self.populateCache(completion: completion)
    }

    /// Returns a sorted array of all band names. Loads from cache if necessary.
    /// - Returns: An array of band name strings.
    func getBandNames () -> [String] {
        var result: [String] = []
        var needsCache = false
        staticBandName.sync {
            if self.bandNames.isEmpty {
                needsCache = true
            } else {
                result = Array(self.bandNames.keys).sorted()
            }
        }
        if needsCache {
            getCachedData()
            // After loading, try again to get the result
            staticBandName.sync {
                result = Array(self.bandNames.keys).sorted()
            }
        }
        print ("bandNamesArray data is \(result)")
        return result
    }

    /// Returns the image URL for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The image URL string.
    func getBandImageUrl(_ band: String) -> String {
        var result = ""
        staticBandName.sync {
            result = self.bandNames[band]?["bandImageUrl"] ?? ""
        }
        print ("Getting image for band \(band) will return \(result)")
        return result
    }

    /// Returns the official website URL for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The official website URL string.
    func getofficalPage (_ band: String) -> String {
        var result = ""
        staticBandName.sync {
            result = self.bandNames[band]?["officalUrls"] ?? ""
        }
        print ("Getting officalSite for band \(band) will return \(result)")
        return result
    }

    /// Returns the Wikipedia page URL for a given band, localized to the user's language if possible.
    /// - Parameter bandName: The name of the band.
    /// - Returns: The Wikipedia URL string.
    func getWikipediaPage (_ bandName: String) -> String{
        var wikipediaUrl = ""
        staticBandName.sync {
            wikipediaUrl = self.bandNames[bandName]?["wikipediaLink"] ?? ""
        }
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
        var youTubeUrl = ""
        staticBandName.sync {
            youTubeUrl = self.bandNames[bandName]?["youtubeLinks"] ?? ""
        }
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
        var result = ""
        staticBandName.sync {
            result = self.bandNames[bandName]?["metalArchiveLinks"] ?? ""
        }
        return result
    }
    
    /// Returns the country for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The country string.
    func getBandCountry (_ band: String) -> String {
        var result = ""
        staticBandName.sync {
            result = self.bandNames[band]?["bandCountry"] ?? ""
        }
        return result
    }
    
    /// Returns the genre for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The genre string.
    func getBandGenre (_ band: String) -> String {
        var result = ""
        staticBandName.sync {
            result = self.bandNames[band]?["bandGenre"] ?? ""
        }
        return result
    }

    /// Returns the 'noteworthy' field for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The noteworthy string.
    func getBandNoteWorthy (_ band: String) -> String {
        var result = ""
        staticBandName.sync {
            result = self.bandNames[band]?["bandNoteWorthy"] ?? ""
        }
        return result
    }

    /// Returns a comma-separated string of prior years for a given band, or an empty string if not found.
    /// - Parameter band: The name of the band.
    /// - Returns: The prior years string.
    func getPriorYears (_ band: String) -> String {
        var previousYears: String? = nil
        staticBandName.sync {
            previousYears = self.bandNames[band]?["priorYears"]
        }
        previousYears = previousYears?.replacingOccurrences(of: " ", with: ", ")
        return previousYears ?? ""
    }
}

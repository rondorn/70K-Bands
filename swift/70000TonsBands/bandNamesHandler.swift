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
        print ("Loading bandName Data cache")
        staticBandName.sync() {
            if (cacheVariables.bandNamesStaticCache.isEmpty == false && cacheVariables.bandNamesArrayStaticCache.isEmpty == false ){
                print ("Loading bandName Data cache, from cache")
                bandNames = cacheVariables.bandNamesStaticCache
                bandNamesArray = cacheVariables.bandNamesArrayStaticCache
                completion?()
            } else {
                print ("Loading bandName Data cache, from disk or dropbox")
                gatherData(completion: completion)
            }
        }
        print ("Done Loading bandName Data cache")
    }
    
    /// Clears the static cache of band names.
    func clearCachedData(){
        cacheVariables.bandNamesStaticCache = [String :[String : String]]()
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
        if bandNames.isEmpty && !cacheVariables.justLaunched {
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
                            if (lineData["imageUrl"] != nil){
                                bandNames[bandNameValue]!["bandImageUrl"] = "http://" + lineData["imageUrl"]!;
                            }
                            if (lineData["officalSite"] != nil){
                                if (lineData["bandName"] != nil){
                                    bandNames[bandNameValue]!["officalUrls"] = "http://" + lineData["officalSite"]!;
                                }
                            }
                            if (lineData["wikipedia"] != nil){
                                bandNames[bandNameValue]!["wikipediaLink"] = lineData["wikipedia"]!;
                            }
                            if (lineData["youtube"] != nil){
                                bandNames[bandNameValue]!["youtubeLinks"] = lineData["youtube"]!;
                            }
                            if (lineData["metalArchives"] != nil){
                                bandNames[bandNameValue]!["metalArchiveLinks"] = lineData["metalArchives"]!;
                            }
                            if (lineData["country"] != nil){
                                bandNames[bandNameValue]!["bandCountry"] = lineData["country"]!;
                            }
                            if (lineData["genre"] != nil){
                                bandNames[bandNameValue]!["bandGenre"] = lineData["genre"]!;
                            }
                            if (lineData["noteworthy"] != nil){
                                bandNames[bandNameValue]!["bandNoteWorthy"] = lineData["noteworthy"]!;
                            }
                            if (lineData["priorYears"] != nil){
                                bandNames[bandNameValue]!["priorYears"] = lineData["priorYears"]!;
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
}

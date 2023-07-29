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
    
    func getCachedData(){
        
        print ("Loading bandName Data cache")
        
        let currentQueueLabel = OperationQueue.current?.underlyingQueue?.label
        
        staticBandName.sync() {
            if (cacheVariables.bandNamesStaticCache.isEmpty == false && cacheVariables.bandNamesArrayStaticCache.isEmpty == false ){
                
                print ("Loading bandName Data cache, from cache")
                bandNames = cacheVariables.bandNamesStaticCache
                bandNamesArray = cacheVariables.bandNamesArrayStaticCache
            
            } else if (currentQueueLabel == "com.apple.main-thread"){
                print ("Loading bandName Data cache, from disk")
                readBandFile()
                populateCache()
                
            } else {
                print ("Loading bandName Data cache, from dropbox")
                gatherData()
            }
        }
        
        print ("Done Loading bandName Data cache")
        
    }
    
    func clearCachedData(){
        cacheVariables.bandNamesStaticCache = [String :[String : String]]()
    }
    
    func gatherData() {

        if isInternetAvailable() == true {
            
            eventYear = Int(getPointerUrlData(keyValue: "eventYear"))!
            print ("Loading bandName Data gatherData")
            let defaults = UserDefaults.standard
            
            if (defaults.string(forKey: "artistUrl") == nil){
                setupDefaults()
            }
            
            print ("artistUrl!! = " + defaults.string(forKey: "artistUrl")!)
            var artistUrl = getPointerUrlData(keyValue: artistUrlpointer) ?? "http://dropbox.com"
            
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
        populateCache()
    }

    func populateCache(){
        print ("Starting population of acheVariables.bandNamesStaticCache")
        staticBandName.async(flags: .barrier) {
            //print ("Populating using \(self.bandNames.keys) acheVariables.bandNamesStaticCache")
            
            cacheVariables.bandNamesStaticCache =  [String :[String : String]]()
            cacheVariables.bandNamesArrayStaticCache = [String]()
            for bandName in self.bandNames.keys {
                cacheVariables.bandNamesStaticCache[bandName] =  [String : String]()
                cacheVariables.bandNamesStaticCache[bandName] =  self.bandNames[bandName]
                
                print ("Adding Data to cacheVariables.bandNamesStaticCache = \(String(describing: cacheVariables.bandNamesStaticCache[bandName]))")
                cacheVariables.bandNamesArrayStaticCache.append(bandName)
            }
        }
    }
    
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


    func readBandFile (){
        
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
    }

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

    func getBandImageUrl(_ band: String) -> String {
        
        print ("Getting image for band \(band) will return \(String(describing: bandNames[band]))")
        return bandNames[band]?["bandImageUrl"] ?? ""
    }

    func getofficalPage (_ band: String) -> String {
        
        print ("Getting officalSite for band \(band) will return \(String(describing: bandNames[band]?["officalUrls"]))")
        
        return bandNames[band]?["officalUrls"] ?? ""
        
    }

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
    
    func getMetalArchives (_ bandName: String) -> String {
        
        return bandNames[bandName]?["metalArchiveLinks"] ?? ""
    }
    
    func getBandCountry (_ band: String) -> String {
        
        return bandNames[band]?["bandCountry"] ?? ""
    }
    
    func getBandGenre (_ band: String) -> String {
        
        return bandNames[band]?["bandGenre"] ?? ""
    }

    func getBandNoteWorthy (_ band: String) -> String {
        
        return bandNames[band]?["bandNoteWorthy"] ?? ""
    }
    
}

//
//  bandNames.swift
//  70000TonsApp
//
//  Created by Ron Dorn on 12/23/14.
//  Copyright (c) 2014 Ron Dorn. All rights reserved.
//

import Foundation

var bandNames = [String]()
var bandImageUrl = [String: String]()
var officalUrls = [String: String]()
var offline = false;

let bandFile = getDocumentsDirectory().stringByAppendingPathComponent("bandFile")

func gatherData () {
    
    let defaults = NSUserDefaults.standardUserDefaults()
    var artistUrl = defaults.stringForKey("artistUrl")
    
    if (artistUrl == "Default"){
       artistUrl = getDefaultArtistUrl()
    }
    
    print ("Getting band data from " + artistUrl!);
    let httpData = getUrlData(artistUrl!)
    
    print("This will be making HTTP Calls for bands")
    if (httpData.isEmpty == false){
        writeBandFile(httpData);
        offline = false;
    } else {
        offline = true;
    }
    readBandFile();
}

func writeBandFile (httpData: String){
    
    print("write file " + bandFile);
    print (httpData);
    

    do {
       try httpData.writeToFile(bandFile, atomically: true,encoding: NSUTF8StringEncoding)
        print ("Just created file " + bandFile);
    } catch let error as NSError {
        print ("Encountered an error of creating file " + error.debugDescription)
    }
    
}

func readBandFile (){
    
    bandNames = [String]()
    
    print ("Reading content of file " + bandFile);
    
    if let csvDataString = try? String(contentsOfFile: bandFile, encoding: NSUTF8StringEncoding) {
        print("csvDataString has data", terminator: "");
        
        //var unuiqueIndex = Dictionary<NSTimeInterval, Int>()
        var csvData: CSV
        
        //var error: NSErrorPointer = nil
        csvData = try! CSV(csvStringToParse: csvDataString)
        
        for lineData in csvData.rows {
            print("line data ");
            print(lineData);
            
            if (lineData["bandName"]?.isEmpty == false){
                
                print ("Working on band " + lineData["bandName"]!)
                
                bandNames.append(lineData["bandName"]!);
                
                if (lineData.isEmpty == false){
                    if (lineData["imageUrl"] != nil){
                        bandImageUrl[lineData["bandName"]!] = "http://" + lineData["imageUrl"]!;
                    }
                    if (lineData["officalSite"] != nil){
                        officalUrls[lineData["bandName"]!] = "http://" + lineData["officalSite"]!;
                    }
                    if (lineData["wikipedia"] != nil){
                        wikipediaLink[lineData["bandName"]!] = lineData["wikipedia"]!;
                    }
                    if (lineData["youtube"] != nil){
                        youtubeLinks[lineData["bandName"]!] = lineData["youtube"]!;
                    }
                    if (lineData["metalArchives"] != nil){
                        metalArchiveLinks[lineData["bandName"]!] = lineData["metalArchives"]!;
                    }
                    if (lineData["country"] != nil){
                        bandCountry[lineData["bandName"]!] = lineData["country"]!;
                    }
                    if (lineData["genre"] != nil){
                        bandGenre[lineData["bandName"]!] = lineData["genre"]!;
                    }
                    if (lineData["noteworthy"] != nil){
                        bandNoteWorthy[lineData["bandName"]!] = lineData["noteworthy"]!;
                    }
                }
            }
        }
    } else {
        print ("Could not read file for some reason");
        do {
            try NSString(contentsOfFile: bandFile, encoding: NSUTF8StringEncoding)
            
        } catch let error as NSError {
            print ("Encountered an error on reading file" + error.debugDescription)
        }
    }
}

func getDefaultArtistUrl() -> String{
    
    var url = String()
    let httpData = getUrlData(defaultStorageUrl)
    
    let dataArray = httpData.componentsSeparatedByString("\n")
    for record in dataArray {
        var valueArray = record.componentsSeparatedByString("::")
        if (valueArray[0] == "artistUrl"){
            url = valueArray[1]
        }
    }
    
    print ("Using default BandName URL of " + url)
    return url
}

func getUrlData(urlString: String) -> String{

    var httpData = String()
    
    let semaphore = dispatch_semaphore_create(0)
    
    HTTPGet(urlString) {
        (data: String, error: String?) -> Void in
        if error != nil {
            print("Error, well now what")
            print(error)
            dispatch_semaphore_signal(semaphore)
        } else {
            httpData = data
            dispatch_semaphore_signal(semaphore)
        }
        
    }
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
    
    return httpData
    
}

func getBandNames () -> [String] {
    
    bandNames.sortInPlace{$0 < $1}

    return bandNames
}

func getBandImageUrl(band: String) -> String {
    
    if (bandImageUrl[band]?.isEmpty == false){
        return bandImageUrl[band]!
    } else {
        return ""
    }
}

func getofficalPage (band: String) -> String {
    
    if (officalUrls[band]?.isEmpty == false){
        return officalUrls[band]!
    } else {
        return "Unavailable"
    }
    
}

func getBandCountry () -> [String] {
    
    bandNames.sortInPlace{$0 < $1}
    
    return bandNames
}

func isOffline () -> Bool {
    return offline
}

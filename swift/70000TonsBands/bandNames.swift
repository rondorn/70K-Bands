//
//  bandNames.swift
//  70000TonsApp
//
//  Created by Ron Dorn on 12/23/14.
//  Copyright (c) 2014 Ron Dorn. All rights reserved.
//  70K Bands
//  Distributed under the GNU GPL v2. For full terms see the file docs/COPYING.
//

import Foundation

var bandNames = [String]()
var bandImageUrl = [String: String]()
var officalUrls = [String: String]()
var offline = false;


let bandFile = dirs[0].stringByAppendingPathComponent("bandFile")

func gatherData () {
    
    var error:NSError?

    let defaults = NSUserDefaults.standardUserDefaults()
    var artistUrl = defaults.stringForKey("artistUrl")
    
    if (artistUrl == "Default"){
       artistUrl = getDefaultArtistUrl()
    }
    
    println ("Getting band data from " + artistUrl!);
    var httpData = getUrlData(artistUrl!)
    
    println("This will be making HTTP Calls for bands")
    if (httpData.isEmpty == false){
        writeBandFile(httpData);
        offline = false;
    } else {
        offline = true;
    }
    readBandFile();
}

func writeBandFile (httpData: String){
    
    println("write file " + bandFile);
    println (httpData);
    
    httpData.writeToFile(bandFile, atomically: false, encoding: NSUTF8StringEncoding)

}

func readBandFile (){
    
    bandNames = [String]()
    
    println("reading file " + bandFile);
    if let csvDataString = String(contentsOfFile: bandFile, encoding: NSUTF8StringEncoding, error: nil) {
        print("csvDataString has data");
        
        var unuiqueIndex = Dictionary<NSTimeInterval, Int>()
        var csvData: CSV
        
        var error: NSErrorPointer = nil
        csvData = CSV(csvStringToParse: csvDataString, error: error)!
        
        for lineData in csvData.rows {
            println("line data ");
            println(lineData);
            
            if (lineData["bandName"]?.isEmpty == false){
                
                println ("Working on band " + lineData["bandName"]!)
                
                bandNames.append(lineData["bandName"]!);
                bandImageUrl[lineData["bandName"]!] = "http://" + lineData["imageUrl"]!;
                officalUrls[lineData["bandName"]!] = "http://" + lineData["officalSite"]!;
                wikipediaLink[lineData["bandName"]!] = lineData["wikipedia"]!;
                youtubeLinks[lineData["bandName"]!] = lineData["youtube"]!;
                metalArchiveLinks[lineData["bandName"]!] = lineData["metalArchives"]!;
            }
        }
    }
}

func getDefaultArtistUrl() -> String{
    
    var url = String()
    var httpData = getUrlData(defaultStorageUrl)
    
    var dataArray = httpData.componentsSeparatedByString("\n")
    for record in dataArray {
        var valueArray = record.componentsSeparatedByString("::")
        if (valueArray[0] == "artistUrl"){
            url = valueArray[1]
        }
    }
    
    println ("Using default BandName URL of " + url)
    return url
}

func getUrlData(urlString: String) -> String{

    var httpData = String()
    
    var semaphore = dispatch_semaphore_create(0)
    
    HTTPGet(urlString) {
        (data: String, error: String?) -> Void in
        if error != nil {
            println("Error, well now what")
            println(error)
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
    
    bandNames.sort{$0 < $1}

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

func isOffline () -> Bool {
    return offline
}

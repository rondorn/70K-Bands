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

let bandFile = getDocumentsDirectory().appendingPathComponent("bandFile")

func gatherData () {
    
    let defaults = UserDefaults.standard
    
    print ("artistUrl = " + defaults.string(forKey: "artistUrl")!)
    var artistUrl = defaults.string(forKey: "artistUrl")

    if (artistUrl == "Default"){
        artistUrl = getPointerUrlData(keyValue: artistUrlpointer)
    
    } else if (artistUrl == "lastYear"){
        artistUrl = getPointerUrlData(keyValue: lastYearsartistUrlpointer)
    
    }
    
    print ("Getting band data from " + artistUrl!);
    let httpData = getUrlData(artistUrl!)
    
    print("This will be making HTTP Calls for bands")
    if (httpData.isEmpty == false){
        writeBandFile(httpData);
        offline = false;
    } else {
        print ("Setting offline is true")
        offline = true;
    }
    readBandFile();
}

func writeBandFile (_ httpData: String){
    
    print("write file " + bandFile);
    print (httpData);

    do {
       try httpData.write(toFile: bandFile, atomically: true,encoding: String.Encoding.utf8)
        print ("Just created file " + bandFile);
    } catch let error as NSError {
        print ("Encountered an error of creating file " + error.debugDescription)
    }
    
}


func readBandFile (){
    
    bandNames = [String]()
    
    print ("Reading content of file " + bandFile);
    
    if (FileManager.default.fileExists(atPath: bandFile) == false){
        gatherData();
    }
    if let csvDataString = try? String(contentsOfFile: bandFile, encoding: String.Encoding.utf8) {
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
                
                if (lineData["bandName"] == nil){
                    continue
                }
                if (lineData.isEmpty == false){
                    if (lineData["imageUrl"] != nil){
                        bandImageUrl[lineData["bandName"]!] = "http://" + lineData["imageUrl"]!;
                    }
                    if (lineData["officalSite"] != nil){
                        if (lineData["bandName"] != nil){
                            officalUrls[lineData["bandName"]!] = "http://" + lineData["officalSite"]!;
                        }
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
            try NSString(contentsOfFile: bandFile, encoding: String.Encoding.utf8.rawValue)
            
        } catch let error as NSError {
            print ("Encountered an error on reading file" + error.debugDescription)
        }
    }
}

func getUrlData(_ urlString: String) -> String{

    var httpData = String()
    
    let semaphore = DispatchSemaphore(value: 0)
    
    HTTPGet(urlString) {
        (data: String, error: String?) -> Void in
        if error != nil {
            print("Error, well now what, \(urlString) failed")
            print(error)
            semaphore.signal()
        } else {
            httpData = data
            semaphore.signal()
        }
        
    }
    
    semaphore.wait(timeout: DispatchTime.distantFuture)
    
    return httpData
    
}

func getBandNames () -> [String] {
    
    if (bandNames.isEmpty == false){
        if (bandNames.count >= 2){
            bandNames.sort{$0 < $1}
        }
    }
    return bandNames
}

func getBandImageUrl(_ band: String) -> String {
    
    if (bandImageUrl[band]?.isEmpty == false){
        return bandImageUrl[band]!
    
    } else if (imageUrls[band] != nil) {
        return imageUrls[band]!
        
    } else {
        return ""
    }
}

func getofficalPage (_ band: String) -> String {
    
    if (officalUrls[band]?.isEmpty == false){
        return officalUrls[band]!
    } else {
        return "Unavailable"
    }
    
}

func getBandCountry () -> [String] {
    
    bandNames.sort{$0 < $1}
    
    return bandNames
}

func isOffline () -> Bool {
    return offline
}

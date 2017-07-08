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
var offline = false


public class bandNameHandler {
    
    public func gatherData () {

        let defaults = NSUserDefaults.standardUserDefaults()
        var artistUrl = defaults.stringForKey("artistUrl")
        
        println("artistUrl is " + artistUrl!)
        

        var httpData: String = ""
        bandNames = [String]()
        bandImageUrl = [String: String]()
        officalUrls = [String: String]()
        
        var semaphore = dispatch_semaphore_create(0)
        
        HTTPGet(artistUrl!) {
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
        
        
        println("This will be making HTTP Calls for bands")
        
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        
        if (httpData != ""){
            offline = false
            
            processBandNames(httpData)
            processAuxData(httpData)
            
            artillaryFix()
            writeBandFile()
            
        } else {
            offlineDataLoading()
        }
    }

    func extractData(data: String) {
        
        var pattern = "(.*title=\\\")[^\\\"]+\\\"(.*)"
        
        var error: NSError? = nil
        
        var regex = NSRegularExpression(pattern: pattern, options: NSRegularExpressionOptions.DotMatchesLineSeparators, error: &error)
        
        
        var result = regex?.stringByReplacingMatchesInString(data, options: nil, range: NSRange(location:0,
            length:countElements(data)), withTemplate: "$1$2")
    }


    //this is in place due to an error in the 70,000 tons web site for the 2015 cruise
    //this can be removed if the website is fixed, or after the 2016 info is posted
    func artillaryFix () {
        
        if (bandImageUrl["Artillery"] == nil){
            officalUrls["Artillery"] = "http://artillery.dk"
            bandImageUrl["Artillery"] = "http://70000tons.com/wp-content/uploads/2014/09/artillery_hover.png"
        }
    }

    func offlineDataLoading () {
        
        var bandPriorityStorage = readFile()
        
        bandNames = readBandFile()
        
        for bandName in bandNames {
            officalUrls[bandName] = "Unavailable"
            bandImageUrl[bandName] = ""
        }
        
        offline = true
        
    }


    func processBandNames (httpData: String){
        
        
        var split1 = httpData.componentsSeparatedByString("title=\"")
        var previousItem: String = ""
        
        for item in split1 {
            if let match = item.rangeOfString("70000TONS", options: .RegularExpressionSearch){
                //do nothing
                
            } else {
                if (item != "RSD"){
                    var split2 = item.componentsSeparatedByString("\"")
                    
                    var bandName = split2[0]
                    if (bandName == previousItem){
                        if (bandName == "Arch Enemy"){
                            bandName = "Artillery"
                        }
                    }
                    
                    bandNames.append(bandName)
                    officalUrls[bandName] = "Unavailable"
                    bandImageUrl[bandName] = ""
                    previousItem = bandName
                }
            }
        }
    }

    func processAuxData (httpData: String){
        
        var split1 = httpData.componentsSeparatedByString("<div")
        
        for item in split1 {
            var split2 = httpData.componentsSeparatedByString("=")
            var key = ""
            var bandName = ""
            var officalUrl = ""
            
            for item2 in split2 {
                
                if item2.rangeOfString("title") != nil{
                    key = "bandName"
                    continue
                    
                } else if item2.rangeOfString("this.src") != nil{
                    key = "imageUrl"
                    continue
                    
                } else if item2.rangeOfString("\"ib-block\"><a href") != nil{
                    key = "officialUrl"
                    continue
                    
                }
                
                if (key == "bandName" && item2.rangeOfString("70000") == nil){
                    
                    bandName = item2
                    bandName = bandName.stringByReplacingOccurrencesOfString(" onmouseover", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
                    
                    bandName = bandName.stringByReplacingOccurrencesOfString("\"", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
                    
                    if (officalUrls[bandName] == "Unavailable" && !officalUrl.isEmpty) {
                        officalUrls[bandName] = officalUrl
                    }
                    
                    key = ""
                    
                } else if (key == "imageUrl"){
                    var bandImage = item2
                    bandImage = bandImage.stringByReplacingOccurrencesOfString(";\"", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
                    
                    bandImage = bandImage.stringByReplacingOccurrencesOfString("'", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
                    
                    bandImage = bandImage.stringByReplacingOccurrencesOfString("alt", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
                    
                    bandImage = bandImage.stringByReplacingOccurrencesOfString("onmouseout", withString: "", options:
                        NSStringCompareOptions.LiteralSearch, range: nil)
                    
                    bandImage = bandImage.stringByReplacingOccurrencesOfString(" ", withString: "", options:
                        NSStringCompareOptions.LiteralSearch, range: nil)
                    
                    if (bandImageUrl[bandName] == "" && !bandImage.isEmpty){
                        bandImageUrl[bandName] = "http://70000tons.com" + bandImage
                    }
                    
                    key = ""
                    
                } else if (key == "officialUrl"){
                    officalUrl = item2
                    officalUrl = officalUrl.stringByReplacingOccurrencesOfString("target", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
                    
                    officalUrl = officalUrl.stringByReplacingOccurrencesOfString("\"", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
                    
                    officalUrl = officalUrl.stringByReplacingOccurrencesOfString(" ", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
                    
                    key = ""
                }
            }
        }
        
        
    }


    func getBandNames () -> [String] {
        
        bandNames.sort{$0 < $1}
        
        return bandNames
    }

    func getBandImageUrl(band: String) -> String {
        
        return bandImageUrl[band]!
    }

    func getofficalPage (band: String) -> String {
        
        return officalUrls[band]!
        
    }

    func isOffline () -> Bool {
        return offline
    }
}

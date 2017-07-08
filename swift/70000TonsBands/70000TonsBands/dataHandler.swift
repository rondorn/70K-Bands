//
//  dataHandler.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/7/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import CoreData

var bandPriorityStorage = [String:Int]()

let directoryPath = NSURL(fileURLWithPath:dirs[0])
let storageFile = directoryPath.URLByAppendingPathComponent( "data.txt")
let dateFile = directoryPath.URLByAppendingPathComponent( "date.txt")
let bandsFile = directoryPath.URLByAppendingPathComponent( "bands.txt")
let lastFilters = directoryPath.URLByAppendingPathComponent("lastFilters")

func writeFiltersFile(){
    
    dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_BACKGROUND.rawValue), 0)) {
        var prefsString = String()
        
        prefsString = "mustSeeOn:" + boolToString(getMustSeeOn()) + ";"
        prefsString += "mightSeeOn:" + boolToString(getMightSeeOn()) + ";"
        prefsString += "wontSeeOn:" + boolToString(getWontSeeOn()) + ";"
        prefsString += "unknownSeeOn:" + boolToString(getUnknownSeeOn()) + ";"
        
        print ("Wrote prefs " + prefsString)
        do {
            try prefsString.writeToFile(String(contentsOfURL:lastFilters), atomically: false, encoding: NSUTF8StringEncoding)
        } catch _ {
        }
    }
}


func readFiltersFile(){

    if let data = try? String(contentsOfURL: lastFilters, encoding: NSUTF8StringEncoding) {
        let dataArray = data.componentsSeparatedByString(";")
        for record in dataArray {
            var valueArray = record.componentsSeparatedByString(":")
            switch valueArray[0] {
                
                case "mustSeeOn":
                    setMustSeeOn(stringToBool(valueArray[1]))
                
                case "mightSeeOn":
                    setMightSeeOn(stringToBool(valueArray[1]))
               
                case "wontSeeOn":
                    setWontSeeOn(stringToBool(valueArray[1]))
                
                case "unknownSeeOn":
                    setUnknownSeeOn(stringToBool(valueArray[1]))
                
                default:
                    print("Not sure why this would happen")
            }
        }
    }
}


func boolToString(value: Bool) -> String{
    
    var result = String()
    
    if (value == true){
        result = "true"
    } else {
        result = "false"
    }
    
    return result
}

func stringToBool(value: String) -> Bool{
    
    var result = Bool()
    
    if (value == "true"){
        result = true
    } else {
        result = false
    }
    
    return result
}

func addPriorityData (bandname:String, priority: Int){
    
    bandPriorityStorage[bandname] = priority
    writeFile()
}

func getDateFormatter() -> NSDateFormatter {
    
    let dateFormatter = NSDateFormatter()
    
    dateFormatter.dateFormat = "MM-dd-yy"
    dateFormatter.timeStyle = NSDateFormatterStyle.ShortStyle
    dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
    
    return dateFormatter
}

func getPriorityData (bandname:String) -> Int {
    
    print ("Retrieving data for " + bandname + ":", terminator: "")
    var priority: Int
    
    if (bandPriorityStorage[bandname] == nil){
        print("Returned null for " + bandname)
        priority =  0
        
    } else {
        priority = bandPriorityStorage[bandname]!
        print("Returning data " + bandname + ":" + String(priority))
    }
    
    return priority
}


func getPriorityDataFromiCloud (){
    
    let values = NSUbiquitousKeyValueStore.defaultStore().dictionaryRepresentation
    
    if values["bandPriorities"] != nil {
        let dataString = String(NSUbiquitousKeyValueStore.defaultStore().stringForKey("bandPriorities")!)
        let split1 = dataString.componentsSeparatedByString(";")
    
        for record in split1 {
            var split2 = record.componentsSeparatedByString(":")
            if (split2.count == 2){
                bandPriorityStorage[split2[0]] = Int(split2[1])
            }
        }
    }
}

func writeiCloudData (){

    var dataString: String = ""
    
    
    for (band, priority) in bandPriorityStorage {
        dataString = dataString + band + ":" + String(priority) + ";"
    }

    NSUbiquitousKeyValueStore.defaultStore().setString(dataString, forKey: "bandPriorities")
    NSUbiquitousKeyValueStore.defaultStore().setObject(NSDate(), forKey: "lastModifiedDate")
    
    NSUbiquitousKeyValueStore.defaultStore().synchronize()

    
}

func writeFile(){
    
    let dateFormatter = getDateFormatter()
    dateFormatter.dateFormat = "MM-dd-yy"
    
    var data: String = ""
    let dateTimeModified = NSDate();
    
    let dateTimeModifiedString = dateFormatter.stringFromDate(dateTimeModified)
    
    for (index, element) in bandPriorityStorage{
        data = data + index + ":" + String(element) + "\n"
    }
    
    do {
        try data.writeToURL(storageFile, atomically: false, encoding: NSUTF8StringEncoding)
    } catch _ {
    }
    do {
        try dateTimeModifiedString.writeToURL(dateFile, atomically: false, encoding: NSUTF8StringEncoding)
    } catch _ {
    }
    
    writeiCloudData();
    
}

func compareLastModifiedDate () -> String {
    
    var winner: String = ""
    var fileDate: NSDate = NSDate()
    var iCloudDate: NSDate = NSDate()
    

    let dateFormatter: NSDateFormatter = getDateFormatter()
    dateFormatter.dateFormat = "MM-dd-yy"
    dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
    
    if let data = try? String(contentsOfURL: dateFile, encoding: NSUTF8StringEncoding) {
        fileDate = dateFormatter.dateFromString(data)!
    }
    
    
    let values = NSUbiquitousKeyValueStore.defaultStore().dictionaryRepresentation
    
    if values["lastModifiedDate"] != nil {
        iCloudDate = NSUbiquitousKeyValueStore.defaultStore().objectForKey("lastModifiedDate") as! NSDate
    } else {
        return "file"
    }
    
    if (iCloudDate.timeIntervalSince1970 >= fileDate.timeIntervalSince1970){
        winner = "iCloud"
    } else {
        winner = "file"
    }
    
    print ("Winner is " + winner)
    print(iCloudDate);
    print (fileDate);
    
    return winner
    
}

func readFile() -> [String:Int]{
    
    let dateWinner = compareLastModifiedDate();
    
    if (dateWinner == "iCloud"){
        getPriorityDataFromiCloud();
    }
    
    if (bandPriorityStorage.count == 0){
        if let data = try? String(contentsOfURL: storageFile, encoding: NSUTF8StringEncoding) {
            let dataArray = data.componentsSeparatedByString("\n")
            for record in dataArray {
                var element = record.componentsSeparatedByString(":")
                if element.count == 2 {
                    var priorityString = element[1];
                    
                     priorityString = priorityString.stringByReplacingOccurrencesOfString("\n", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
                    
                    bandPriorityStorage[element[0]] = Int(priorityString)

                }
            }
        }
    }
    
    return bandPriorityStorage
}


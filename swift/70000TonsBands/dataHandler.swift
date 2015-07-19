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

let storageFile = dirs[0].stringByAppendingPathComponent( "data.txt")
let dateFile = dirs[0].stringByAppendingPathComponent( "date.txt")
let bandsFile = dirs[0].stringByAppendingPathComponent( "bands.txt")
let lastFilters = dirs[0].stringByAppendingPathComponent("lastFilters")

func writeFiltersFile(){
    
    dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_BACKGROUND.value), 0)) {
        var prefsString = String()
        
        prefsString = "mustSeeOn:" + boolToString(getMustSeeOn()) + ";"
        prefsString += "mightSeeOn:" + boolToString(getMightSeeOn()) + ";"
        prefsString += "wontSeeOn:" + boolToString(getWontSeeOn()) + ";"
        prefsString += "unknownSeeOn:" + boolToString(getUnknownSeeOn()) + ";"
        
        println ("Wrote prefs " + prefsString)
        prefsString.writeToFile(lastFilters, atomically: false, encoding: NSUTF8StringEncoding)
    }
}


func readFiltersFile(){

    if let data = String(contentsOfFile: lastFilters, encoding: NSUTF8StringEncoding, error: nil) {
        var dataArray = data.componentsSeparatedByString(";")
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
                    println("Not sure why this would happen")
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
    
    print ("Retrieving data for " + bandname + ":")
    var priority: Int
    
    if (bandPriorityStorage[bandname] == nil){
        println("Returned null for " + bandname)
        priority =  0
        
    } else {
        priority = bandPriorityStorage[bandname]!
        println("Returning data " + bandname + ":" + String(priority))
    }
    
    return priority
}


func getPriorityDataFromiCloud (){
    
    let values = NSUbiquitousKeyValueStore.defaultStore().dictionaryRepresentation
    
    if values["bandPriorities"] != nil {
        let dataString = String(NSUbiquitousKeyValueStore.defaultStore().stringForKey("bandPriorities")!)
        var split1 = dataString.componentsSeparatedByString(";")
    
        for record in split1 {
            var split2 = record.componentsSeparatedByString(":")
            if (split2.count == 2){
                bandPriorityStorage[split2[0]] = split2[1].toInt()
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
    var dateTimeModified = NSDate();
    
    var dateTimeModifiedString = dateFormatter.stringFromDate(dateTimeModified)
    
    for (index, element) in bandPriorityStorage{
        data = data + index + ":" + String(element) + "\n"
    }
    
    data.writeToFile(storageFile, atomically: false, encoding: NSUTF8StringEncoding)
    dateTimeModifiedString.writeToFile(dateFile, atomically: false, encoding: NSUTF8StringEncoding)
    
    writeiCloudData();
    
}

func compareLastModifiedDate () -> String {
    
    var winner: String = ""
    var fileDate: NSDate = NSDate()
    var iCloudDate: NSDate = NSDate()
    

    let dateFormatter: NSDateFormatter = getDateFormatter()
    dateFormatter.dateFormat = "MM-dd-yy"
    dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
    
    if var data = String(contentsOfFile: dateFile, encoding: NSUTF8StringEncoding, error: nil) {
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
    
    println ("Winner is " + winner)
    println(iCloudDate);
    println (fileDate);
    
    return winner
    
}

func readFile() -> [String:Int]{
    
    var dateWinner = compareLastModifiedDate();
    
    if (dateWinner == "iCloud"){
        getPriorityDataFromiCloud();
    }
    
    if (bandPriorityStorage.count == 0){
        if let data = String(contentsOfFile: storageFile, encoding: NSUTF8StringEncoding, error: nil) {
            var dataArray = data.componentsSeparatedByString("\n")
            for record in dataArray {
                var element = record.componentsSeparatedByString(":")
                if element.count == 2 {
                    var priorityString = element[1];
                    
                     priorityString = priorityString.stringByReplacingOccurrencesOfString("\n", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
                    
                    bandPriorityStorage[element[0]] = priorityString.toInt()

                }
            }
        }
    }
    
    return bandPriorityStorage
}


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

let directoryPath = URL(fileURLWithPath:dirs[0])
let storageFile = directoryPath.appendingPathComponent( "data.txt")
let dateFile = directoryPath.appendingPathComponent( "date.txt")
let bandsFile = directoryPath.appendingPathComponent( "bands.txt")
let lastFilters = directoryPath.appendingPathComponent("lastFilters")

func writeFiltersFile(){
    DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
    //DispatchQueue.global(priority: Int(DispatchQoS.QoSClass.background.rawValue)).async {
        var prefsString = String()
        
        prefsString = "mustSeeOn:" + boolToString(getMustSeeOn()) + ";"
        prefsString += "mightSeeOn:" + boolToString(getMightSeeOn()) + ";"
        prefsString += "wontSeeOn:" + boolToString(getWontSeeOn()) + ";"
        prefsString += "unknownSeeOn:" + boolToString(getUnknownSeeOn()) + ";"
        
        print ("Wrote prefs " + prefsString)
        do {
            try prefsString.write(toFile: String(contentsOf:lastFilters), atomically: false, encoding: String.Encoding.utf8)
        } catch _ {
        }
    }
}


func readFiltersFile(){

    if let data = try? String(contentsOf: lastFilters, encoding: String.Encoding.utf8) {
        let dataArray = data.components(separatedBy: ";")
        for record in dataArray {
            var valueArray = record.components(separatedBy: ":")
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


func boolToString(_ value: Bool) -> String{
    
    var result = String()
    
    if (value == true){
        result = "true"
    } else {
        result = "false"
    }
    
    return result
}

func stringToBool(_ value: String) -> Bool{
    
    var result = Bool()
    
    if (value == "true"){
        result = true
    } else {
        result = false
    }
    
    return result
}

func addPriorityData (_ bandname:String, priority: Int){
    
    bandPriorityStorage[bandname] = priority
    writeFile()
}

func getDateFormatter() -> DateFormatter {
    
    let dateFormatter = DateFormatter()
    
    dateFormatter.dateFormat = "MM-dd-yy"
    dateFormatter.timeStyle = DateFormatter.Style.short
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    
    return dateFormatter
}

func getPriorityData (_ bandname:String) -> Int {
    
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
    
    let values = NSUbiquitousKeyValueStore.default().dictionaryRepresentation
    
    if values["bandPriorities"] != nil {
        let dataString = String(NSUbiquitousKeyValueStore.default().string(forKey: "bandPriorities")!)
        let split1 = dataString?.components(separatedBy: ";")
    
        for record in split1! {
            var split2 = record.components(separatedBy: ":")
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

    NSUbiquitousKeyValueStore.default().set(dataString, forKey: "bandPriorities")
    NSUbiquitousKeyValueStore.default().set(Date(), forKey: "lastModifiedDate")
    
    NSUbiquitousKeyValueStore.default().synchronize()

    
}

func writeFile(){
    
    let dateFormatter = getDateFormatter()
    dateFormatter.dateFormat = "MM-dd-yy"
    
    var data: String = ""
    let dateTimeModified = Date();
    
    let dateTimeModifiedString = dateFormatter.string(from: dateTimeModified)
    
    for (index, element) in bandPriorityStorage{
        data = data + index + ":" + String(element) + "\n"
    }
    
    do {
        try data.write(to: storageFile, atomically: false, encoding: String.Encoding.utf8)
    } catch _ {
    }
    do {
        try dateTimeModifiedString.write(to: dateFile, atomically: false, encoding: String.Encoding.utf8)
    } catch _ {
    }
    
    writeiCloudData();
    
}

func compareLastModifiedDate () -> String {
    
    var winner: String = ""
    var fileDate: Date = Date()
    var iCloudDate: Date = Date()
    

    let dateFormatter: DateFormatter = getDateFormatter()
    dateFormatter.dateFormat = "MM-dd-yy"
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    
    if let data = try? String(contentsOf: dateFile, encoding: String.Encoding.utf8) {
        fileDate = dateFormatter.date(from: data)!
    }
    
    
    let values = NSUbiquitousKeyValueStore.default().dictionaryRepresentation
    
    if values["lastModifiedDate"] != nil {
        iCloudDate = NSUbiquitousKeyValueStore.default().object(forKey: "lastModifiedDate") as! Date
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
        if let data = try? String(contentsOf: storageFile, encoding: String.Encoding.utf8) {
            let dataArray = data.components(separatedBy: "\n")
            for record in dataArray {
                var element = record.components(separatedBy: ":")
                if element.count == 2 {
                    var priorityString = element[1];
                    
                     priorityString = priorityString.replacingOccurrences(of: "\n", with: "", options: NSString.CompareOptions.literal, range: nil)
                    
                    bandPriorityStorage[element[0]] = Int(priorityString)

                }
            }
        }
    }
    
    return bandPriorityStorage
}


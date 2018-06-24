//
//  dataHandler.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/7/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

var bandPriorityStorage = [String:Int]()

func writeFiltersFile(){
    
    DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
        
        var prefsString = String()
        
        print ("Status of getWontSeeOn save = \(getWontSeeOn())")
        prefsString = "mustSeeOn:" + boolToString(getMustSeeOn()) + ";"
        prefsString += "mightSeeOn:" + boolToString(getMightSeeOn()) + ";"
        prefsString += "wontSeeOn:" + boolToString(getWontSeeOn()) + ";"
        prefsString += "unknownSeeOn:" + boolToString(getUnknownSeeOn()) + ";"
        
        print ("Wrote prefs " + prefsString)
        do {
            try prefsString.write(to: lastFilters, atomically: false, encoding: String.Encoding.utf8)
            print ("Status of getWontSeeOn saved")
        } catch {
            print ("Status of getWontSeeOn NOT saved \(error.localizedDescription)")
        }
    }
}


func readFiltersFile(){
    
    print ("Status of getWontSeeOn loading")
    if let data = try? String(contentsOf: lastFilters, encoding: String.Encoding.utf8) {
        print ("Status of getWontSeeOn loading 1")
        let dataArray = data.components(separatedBy: ";")
        for record in dataArray {
            print ("Status of getWontSeeOn loading loop")
            var valueArray = record.components(separatedBy: ":")
            switch valueArray[0] {
                
                case "mustSeeOn":
                    setMustSeeOn(stringToBool(valueArray[1]))
                
                case "mightSeeOn":
                    setMightSeeOn(stringToBool(valueArray[1]))
               
                case "wontSeeOn":
                    setWontSeeOn(stringToBool(valueArray[1]))
                    print ("Status of getWontSeeOn load = \(valueArray[1])")
                
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

func writeiCloudData (){

    var dataString: String = ""
    
    var counter = 0;
    bandPriorityStorage = readFile(dateWinnerPassed: "file")
    
    for (band, priority) in bandPriorityStorage {
        dataString = dataString + PRIORITY + "!" + band + "!" + String(priority) + ";"
        print ("Adding icloud write PRIORITY \(band) - \(priority)")
        counter += 1
    }
    
    attendedHandler.loadShowsAttended()
    
    let showsAttendedData = attendedHandler.getShowsAttended()
    for (index, attended) in showsAttendedData {
        dataString = dataString + ATTENDED + "!" + index + "!" + attended + ";"
        print ("Adding icloud write ATTENDED \(index) - \(attended)")
        counter += 1
    }
    
    
    if (counter > 2){
        //print ("iCloud writing priority data")
        NSUbiquitousKeyValueStore.default().set(dataString, forKey: "bandPriorities")
        NSUbiquitousKeyValueStore.default().set(Date(), forKey: "lastModifiedDate")
    
        NSUbiquitousKeyValueStore.default().synchronize()
    }
    
}

func readiCloudData(){
    
    NSUbiquitousKeyValueStore.default().synchronize()
    
    print ("iCloud getting priority data from the cloud")
    
    let values = NSUbiquitousKeyValueStore.default().dictionaryRepresentation
    
    var showsAttendedData : [String : String] = [String : String]();
    
    print ("iCloud - " + String(describing: values))
    if values["bandPriorities"] != nil {
        let dataString = String(NSUbiquitousKeyValueStore.default().string(forKey: "bandPriorities")!)
        let split1 = dataString?.components(separatedBy: ";")
        
        for record in split1! {
            var split2 = record.components(separatedBy: "!")
            print ("Number of variable is \(split2.count)")
            if (split2.count == 3){
                if (split2[0] == PRIORITY){
                    bandPriorityStorage[split2[1]] = Int(split2[2])
                    print ("Adding icloud PRIORITIES \(split2[1]) - \(split2[2])")
                } else if (split2[0] == ATTENDED){
                    showsAttendedData[split2[1]] = split2[2];
                    print ("Adding icloud ATTENDED \(split2[1]) - \(split2[2])")
                }
        
            } else if (split2.count == 0){
                    split2 = record.components(separatedBy: ":")
                    print ("Number of variable is split2-0 \(split2[0]) split2-1 \(split2[1])")
                    bandPriorityStorage[split2[0]] = Int(split2[1])
                    writeiCloudData()
            }
        }
    }

    writeFile();
    attendedHandler.setShowsAttended(attendedData: showsAttendedData)
    attendedHandler.saveShowsAttended()
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
        print ("Number of variable is Date from data is \(data)")
        if (data.isEmpty == false){
            fileDate = dateFormatter.date(from: data)!
        } else {
            return "file"
        }
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


func readFile(dateWinnerPassed : String) -> [String:Int]{
    
    if (iCloudCheck == false){
        iCloudCheck = true;
        var dateWinner :String
        
        if (dateWinnerPassed.isEmpty == false){
            dateWinner = compareLastModifiedDate();
        } else {
                dateWinner = dateWinnerPassed
        }
        
        if (dateWinner == "iCloud"){
            print ("iCloud, founder newer data in cloud")
            readiCloudData();
            bandPriorityStorage = readFile(dateWinnerPassed: "file")
            attendedHandler.loadShowsAttended()
            return bandPriorityStorage;
            
        } else {
            print ("iCloud, trying local data")
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
        
        if (bandPriorityStorage.count == 0){
            print ("iCloud, nothing locally, using the cloud")
            readiCloudData();
            bandPriorityStorage = readFile(dateWinnerPassed: "file")
        }
        iCloudCheck = false;
    }
    return bandPriorityStorage
}


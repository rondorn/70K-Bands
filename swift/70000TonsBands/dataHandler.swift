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

class dataHandler {
    
    var bandPriorityStorage = [String:Int]()
    var readInWrite = false;
    
    init(){
        getCachedData()
    }
    
    func getCachedData(){
    
        print ("Loading priority Data cache")

        staticData.sync() {
            if (cacheVariables.bandPriorityStorageCache.isEmpty == false){
                print ("Loading bandPriorityStorage from Data cache")
                self.bandPriorityStorage = cacheVariables.bandPriorityStorageCache
                print ("Loading bandPriorityStorage from Data cache, done")
            } else {
                print ("Loading bandPriorityStorage Cache did not load, loading from file")
                self.refreshData()
            }
        }
        
        print ("Done Loading bandName Data cache")
    }
    
    func refreshData(){
        bandPriorityStorage = readFile(dateWinnerPassed: "")
    }
    
    func writeFiltersFile(){
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            
            var prefsString = String()
            
            print ("Status of getWontSeeOn save = \(getWontSeeOn())")
            prefsString = "mustSeeOn:" + self.boolToString(getMustSeeOn()) + ";"
            prefsString += "mightSeeOn:" + self.boolToString(getMightSeeOn()) + ";"
            prefsString += "wontSeeOn:" + self.boolToString(getWontSeeOn()) + ";"
            prefsString += "unknownSeeOn:" + self.boolToString(getUnknownSeeOn()) + ";"
            prefsString += "showOnlyWillAttened:" + self.self.boolToString(getShowOnlyWillAttened()) + ";"
            prefsString += "sortedBy:" + getSortedBy() + ";"
            prefsString += "currentTimeZone:" + localTimeZoneAbbreviation + ";"
            print ("Wrote prefs " + prefsString)
            do {
                try prefsString.write(to: lastFilters, atomically: false, encoding: String.Encoding.utf8)
                print ("saved sortedBy = " + getSortedBy())
            } catch {
                print ("Status of getWontSeeOn NOT saved \(error.localizedDescription)")
            }
        }
    }


    func readFiltersFile(){
        
        var tempCurrentTimeZone = "";
        
        print ("Status of getWontSeeOn loading")
        if let data = try? String(contentsOf: lastFilters, encoding: String.Encoding.utf8) {
            print ("Status of sortedBy loading 1 " + data)
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
                    
                    case "showOnlyWillAttened":
                        setShowOnlyWillAttened(stringToBool(valueArray[1]))
                    
                    case "currentTimeZone":
                        tempCurrentTimeZone = valueArray[1]
                    
                    case "sortedBy":
                        print ("activly Loading sortedBy = " + valueArray[1])
                        setSortedBy(valueArray[1])
                    
                    default:
                        print("Not sure why this would happen")
                }
            }
            print ("Loading sortedBy = " + getSortedBy())
        }
        
        if (tempCurrentTimeZone != localTimeZoneAbbreviation){
            alertTracker = [String]()
            let localNotification = localNoticationHandler()
            localNotification.clearNotifications()
            localNotification.addNotifications()
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
        
        staticData.async(flags: .barrier) {
            cacheVariables.bandPriorityStorageCache[bandname] = priority
        }
        
        writeFile()
    }

    func getPriorityData (_ bandname:String) -> Int {
        
        var priority = 0
        
        print ("Retrieving priority data for " + bandname + ":", terminator: "")
        
        if (bandPriorityStorage[bandname] != nil){
            priority = bandPriorityStorage[bandname]!
            print("Returning data " + bandname + ":" + String(priority))
        }
        

        return priority
    }

    func writeFile(){
        
        //do not write empty datasets
        if (bandPriorityStorage.isEmpty){
            return
        }
        
        let dateFormatter = getDateFormatter()
        dateFormatter.dateFormat = "MM-dd-yy"
        
        var data: String = ""
        let dateTimeModified = Date();
        
        let dateTimeModifiedString = dateFormatter.string(from: dateTimeModified)
        
        for (index, element) in bandPriorityStorage{
            print ("writing PRIORITIES \(index) - \(element)")
            data = data + index + ":" + String(element) + "\n"
        }

        do {
            //try FileManager.default.removeItem(at: storageFile)
            try data.write(to: storageFile, atomically: false, encoding: String.Encoding.utf8)
            print ("writing PRIORITIES - file WAS writte")
        } catch _ {
            print ("writing PRIORITIES - file was NOT writte")
        }
        do {
            try dateTimeModifiedString.write(to: dateFile, atomically: false, encoding: String.Encoding.utf8)
        } catch _ {
            
        }
    
    }
    
    func getPriorityData() -> [String:Int]{
        return bandPriorityStorage;
    }

    func readFile(dateWinnerPassed : String) -> [String:Int]{
        
        print ("Load bandPriorityStorage data")
        bandPriorityStorage = [String:Int]()
        
        if (bandPriorityStorage.count == 0){
            if let data = try? String(contentsOf: storageFile, encoding: String.Encoding.utf8) {
                let dataArray = data.components(separatedBy: "\n")
                for record in dataArray {
                    var element = record.components(separatedBy: ":")
                    if element.count == 2 {
                        var priorityString = element[1];
                        print ("reading PRIORITIES \(element[0]) - \(priorityString)")
                         priorityString = priorityString.replacingOccurrences(of: "\n", with: "", options: NSString.CompareOptions.literal, range: nil)
                        
                        bandPriorityStorage[element[0]] = Int(priorityString)
                        staticData.async(flags: .barrier) {
                            cacheVariables.bandPriorityStorageCache[element[0]] = Int(priorityString)
                        }
                    }
                }
            }
        }
        
        return bandPriorityStorage
    }
}

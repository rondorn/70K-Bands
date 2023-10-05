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
            
            var iCloudIndicator = UserDefaults.standard.string(forKey: "iCloud")
            iCloudIndicator = iCloudIndicator?.uppercased()

            print ("Done Loading bandName Data cache")
        }
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
            prefsString += "showOnlyWillAttened:" + self.boolToString(getShowOnlyWillAttened()) + ";"
            prefsString += "sortedBy:" + getSortedBy() + ";"
            prefsString += "currentTimeZone:" + localTimeZoneAbbreviation + ";"
            prefsString += "hideExpireScheduleData:" + self.boolToString(getHideExpireScheduleData()) + ";"
            
            prefsString += "showTheaterShows:" + self.boolToString(getShowTheaterShows()) + ";"
            prefsString += "showPoolShows:" + self.boolToString(getShowPoolShows()) + ";"
            prefsString += "showRinkShows:" + self.boolToString(getShowRinkShows()) + ";"
            prefsString += "showLoungeShows:" + self.boolToString(getShowLoungeShows()) + ";"
            prefsString += "showOtherShows:" + self.boolToString(getShowOtherShows()) + ";"
            prefsString += "showUnofficalEvents:" + self.boolToString(getShowUnofficalEvents()) + ";"
            prefsString += "showSpecialEvents:" + self.boolToString(getShowSpecialEvents()) + ";"
            prefsString += "showMeetAndGreetEvents:" + self.boolToString(getShowMeetAndGreetEvents()) + ";"

            prefsString += "mustSeeAlertValue:" + self.boolToString(getMustSeeAlertValue()) + ";"
            prefsString += "mightSeeAlertValue:" + self.boolToString(getMightSeeAlertValue()) + ";"
            prefsString += "onlyAlertForAttendedValue:" + self.boolToString(getOnlyAlertForAttendedValue()) + ";"

            prefsString += "alertForShowsValue:" + self.boolToString(getAlertForShowsValue()) + ";"
            prefsString += "alertForSpecialValue:" + self.boolToString(getAlertForSpecialValue()) + ";"
            prefsString += "alertForMandGValue:" + self.boolToString(getAlertForMandGValue()) + ";"
            prefsString += "alertForUnofficalEventsValue:" + self.boolToString(getAlertForUnofficalEventsValue()) + ";"
            prefsString += "alertForClinicEvents:" + self.boolToString(getAlertForClinicEvents()) + ";"
            prefsString += "alertForListeningEvents:" + self.boolToString(getAlertForListeningEvents()) + ";"
            
            prefsString += "notesFontSizeLargeValue:" + self.boolToString(getNotesFontSizeLargeValue()) + ";"
            
            prefsString += "minBeforeAlertValue:" + String(getMinBeforeAlertValue()) + ";"

            prefsString += "promptForAttended:" + self.boolToString(getPromptForAttended()) + ";"
            
            prefsString += "sortedBy:" + getSortedBy() + ";"
            
            prefsString += "artistUrl:" + getArtistUrl() + ";"
            prefsString += "scheduleUrl:" + getScheduleUrl() + ";"
            
            print ("Wrote prefs " + prefsString)
            do {
                try prefsString.write(to: lastFilters, atomically: false, encoding: String.Encoding.utf8)
                print ("saved sortedBy = " + getSortedBy())
            } catch {
                print ("Status of getWontSeeOn NOT saved \(error.localizedDescription)")
            }
            print ("Saving showOnlyWillAttened = \(getShowOnlyWillAttened())")
        }
    }


    func readFiltersFile(){
        
        var tempCurrentTimeZone = "";
        
        print ("Status of getWontSeeOn loading")
        if (FileManager.default.fileExists(atPath:lastFilters.relativePath) == false){
            print ("lastFilters does not exist")
            return()
        }
        
        if let data = try? String(contentsOf:lastFilters, encoding: String.Encoding.utf8) {
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
                
                case "hideExpireScheduleData":
                    setHideExpireScheduleData(stringToBool(valueArray[1]))

                case "showTheaterShows":
                    setShowTheaterShows(stringToBool(valueArray[1]))
                
                case "showPoolShows":
                    setShowPoolShows(stringToBool(valueArray[1]))

                case "showRinkShows":
                    setShowRinkShows(stringToBool(valueArray[1]))
                
                case "showLoungeShows":
                    setShowLoungeShows(stringToBool(valueArray[1]))
                
                case "showOtherShows":
                    setShowOtherShows(stringToBool(valueArray[1]))
                
                case "showUnofficalEvents":
                    setShowUnofficalEvents(stringToBool(valueArray[1]))
                
                case "showSpecialEvents":
                    setShowSpecialEvents(stringToBool(valueArray[1]))
                
                case "showMeetAndGreetEvents":
                    setShowMeetAndGreetEvents(stringToBool(valueArray[1]))

                case "mustSeeAlertValue":
                    setMustSeeAlertValue(stringToBool(valueArray[1]))
                    
                case "mightSeeAlertValue":
                    setMightSeeAlertValue(stringToBool(valueArray[1]))
                    
                case "onlyAlertForAttendedValue":
                    setOnlyAlertForAttendedValue(stringToBool(valueArray[1]))
                    
                case "alertForShowsValue":
                    setAlertForShowsValue(stringToBool(valueArray[1]))
                    
                case "alertForSpecialValue":
                    setAlertForSpecialValue(stringToBool(valueArray[1]))
                    
                case "alertForMandGValue":
                    setAlertForMandGValue(stringToBool(valueArray[1]))

                case "alertForListeningEvents":
                    setAlertForListeningEvents(stringToBool(valueArray[1]))
                    
                case "alertForClinicEvents":
                    setAlertForClinicEvents(stringToBool(valueArray[1]))
                    
                case "alertForUnofficalEventsValue":
                    setAlertForUnofficalEventsValue(stringToBool(valueArray[1]))
                    
                case "notesFontSizeLargeValue":
                    setNotesFontSizeLargeValue(stringToBool(valueArray[1]))
                
                case "promptForAttended":
                    setPromptForAttended(stringToBool(valueArray[1]))
                    
                case "minBeforeAlertValue":
                    setMinBeforeAlertValue(Int(valueArray[1]) ?? 10)
                
                case "sortedBy":
                    setSortedBy(valueArray[1])
                    
                case "artistUrl":
                    setArtistUrl(valueArray[1])
                    
                case "scheduleUrl":
                    setScheduleUrl(valueArray[1])
                    
                    default:
                        print("Not sure why this would happen")
                }
            }
            print ("Loading setScheduleUrl = \(getScheduleUrl())")
            print ("Loading mustSeeOn = \(getMustSeeOn())")
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
        
        print ("addPriorityData for \(bandname) = \(priority)")

        bandPriorityStorage[bandname] = priority
        
        staticData.async(flags: .barrier) {
            cacheVariables.bandPriorityStorageCache[bandname] = priority
        }
        
        staticLastModifiedDate.async(flags: .barrier) {
            cacheVariables.lastModifiedDate = Date()
        }
        
        writeFile()
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            let iCloudHandle = iCloudDataHandler()
            iCloudHandle.writeAPriorityRecord(bandName: bandname, priority: priority)
            
            let firebaseBandData = firebaseBandDataWrite()
            let ranking = resolvePriorityNumber(priority: String(priority)) ?? "Unknown"
            firebaseBandData.writeSingleRecord(dataHandle: self, bandName: bandname, ranking: ranking)
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }
    
    func clearCachedData(){
        staticData.async(flags: .barrier) {
            cacheVariables.bandPriorityStorageCache = [String:Int]()
        }
    }
    func getPriorityData (_ bandname:String) -> Int {
        
        var priority = 0
        
        print ("Retrieving priority data for " + bandname + ":", terminator: "\n")
        
        if (bandPriorityStorage[bandname] != nil){
            priority = bandPriorityStorage[bandname]!
            print("Reading data " + bandname + ":" + String(priority))
        }
        

        return priority
    }

    func writeFile(){
        
        while (bandPriorityStorage == nil){
            usleep(300)
        }
        //do not write empty datasets
        if (bandPriorityStorage == nil || bandPriorityStorage.isEmpty){
            return
        }
        
        var data: String = ""

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

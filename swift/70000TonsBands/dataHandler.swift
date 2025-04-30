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
            writeLastPriorityDataWrite()
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
    
    func readLastPriorityDataWrite()-> Double{
        
        var lastPriorityDataWrite = Double(0)
        
        if let data = try? String(contentsOf: lastPriorityDataWriteFile, encoding: String.Encoding.utf8) {
            lastPriorityDataWrite = Double(data)!
        }
        
        return lastPriorityDataWrite
    }
    
    func writeLastPriorityDataWrite(){
        
        let currentTime = String(Date().timeIntervalSince1970)
       
        do {
            //try FileManager.default.removeItem(at: storageFile)
            try currentTime.write(to:lastPriorityDataWriteFile, atomically: false, encoding: String.Encoding.utf8)
            print ("writing PriorityData Date")
        } catch _ {
            print ("writing PriorityData Date, failed")
        }
    }

}

//
//  filebaseBandDataWrite.swift
//  70K Bands
//
//  Created by Ron Dorn on 3/19/19.
//  Copyright © 2019 Ron Dorn. All rights reserved.
//

import Foundation
import Firebase
import CoreData


class firebaseBandDataWrite {
    
    var ref: DatabaseReference!
    var bandCompareFile = "bandCompare.data"
    var firebaseBandAttendedArray = [String : String]();
    var bandRank: [String : String] = [String : String]();
    let variableStoreHandle = variableStore();
    
    init(){
        
        ref = Database.database().reference()
        
    }
    
    
    func loadCompareFile()->[String:String]{
        do {
            print ("Staring loadedData")
            firebaseBandAttendedArray = variableStoreHandle.readDataFromDisk(fileName: bandCompareFile) ?? [String : String]()
            print ("Finished loadedData \(firebaseBandAttendedArray)")
        } catch {
            print("Couldn't read file.")
        }
        
        return firebaseBandAttendedArray
    }
    
    /// Sanitizes band names for use as Firebase database path components
    /// Firebase paths cannot contain: . # $ [ ] / ' " \ and control characters
    private func sanitizeBandNameForFirebase(_ bandName: String) -> String {
        return bandName
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "#", with: "_")
            .replacingOccurrences(of: "$", with: "_")
            .replacingOccurrences(of: "[", with: "_")
            .replacingOccurrences(of: "]", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "'", with: "_")
            .replacingOccurrences(of: "\"", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            // Remove control characters
            .components(separatedBy: .controlCharacters).joined()
            // Trim whitespace
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Gets sanitized name for a band from Core Data, fallback to computing it
    private func getSanitizedNameForBand(_ bandName: String) -> String {
        let context = CoreDataManager.shared.viewContext
        let request: NSFetchRequest<Band> = Band.fetchRequest()
        request.predicate = NSPredicate(format: "bandName == %@ AND eventYear == %d", bandName, Int32(eventYear))
        request.fetchLimit = 1
        
        do {
            if let band = try context.fetch(request).first,
               let sanitizedName = band.sanitizedName,
               !sanitizedName.isEmpty {
                return sanitizedName
            }
        } catch {
            print("⚠️ Error fetching sanitized name for \(bandName): \(error)")
        }
        
        // Fallback to computing it
        return sanitizeBandNameForFirebase(bandName)
    }
    
    func writeSingleRecord(bandName: String, ranking: String, sanitizedName: String? = nil){
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            
            self.firebaseBandAttendedArray = self.loadCompareFile()
            
            let uid = (UIDevice.current.identifierForVendor?.uuidString)!
            print ("writeSingleRecord: uid = \(uid) = eventYear = \(eventYear) - bandName - \(bandName)")
            //exit if things look wrong
            if (bandName == nil || bandName.isEmpty == true){
                return
            }
            
            // Use provided sanitized name or fall back to computing it
            let sanitizedBandName = sanitizedName ?? self.sanitizeBandNameForFirebase(bandName)
            
            self.ref.child("bandData/").child(uid).child(String(eventYear)).child(sanitizedBandName).setValue([
                "bandName": bandName,
                "sanitizedKey": sanitizedBandName, // Store for reference/debugging
                "ranking": ranking,
                "userID": uid,
                "year": String(eventYear)]){
                    (error:Error?, ref:DatabaseReference) in
                    if let error = error {
                        print("Writing firebase band data could not be saved: \(error).")
                    } else {
                        print("Writing firebase band data saved successfully \(bandName) - \(ranking)!")
                        
                        self.firebaseBandAttendedArray[bandName] = ranking
                        self.variableStoreHandle.storeDataToDisk(data: self.firebaseBandAttendedArray, fileName: self.bandCompareFile)
                        

                    }
                }

        }
    }
    
    func writeData (){
        
        if inTestEnvironment == false {
            // LEGACY: dataHandle.refreshData() no longer needed - priorities handled by PriorityManager
            let uid = (UIDevice.current.identifierForVendor?.uuidString)!
            firebaseBandAttendedArray = self.loadCompareFile()
            print ("bandDataReport - Loading firebaseBandAttendedArray \(firebaseBandAttendedArray)")
            if (uid.isEmpty == false){
                self.buildBandRankArray()
                for bandName in self.bandRank.keys {
                    
                    let priorityManager = PriorityManager()
                    let rankingInteger = priorityManager.getPriority(for: bandName)
                    let ranking = resolvePriorityNumber(priority: String(rankingInteger)) ?? "Unknown"
                    print ("bandDataReport - Checking band \(bandName) - \(firebaseBandAttendedArray[bandName]) - \(ranking)")
                    if firebaseBandAttendedArray[bandName] != ranking || didVersionChange == true {
                        print ("bandDataReport - fixing record for \(bandName)")
                        let sanitizedName = getSanitizedNameForBand(bandName)
                        writeSingleRecord(bandName: bandName, ranking: ranking, sanitizedName: sanitizedName)
                    }
                    
                }
            } else {
                print("Not Writing firebase band data, nothing has changed")
            }
        
        }
    }
    
    func buildBandRankArray(){
        
        // Get current year from global eventYear variable
        let currentYear = Int32(eventYear)
        print("🔥 firebase BAND_WRITE: Filtering bands for current year: \(currentYear)")
        
        // Get bands for the current year only
        let coreDataManager = CoreDataManager.shared
        let bandsForCurrentYear = coreDataManager.fetchBands(forYear: currentYear)
        print("🔥 firebase BAND_WRITE: Found \(bandsForCurrentYear.count) bands for year \(currentYear)")
        
        for band in bandsForCurrentYear {
            guard let bandName = band.bandName else { continue }
            
            let priorityManager = PriorityManager()
            let rankingNumber = String(priorityManager.getPriority(for: bandName))
            let rankingString = resolvePriorityNumber(priority: rankingNumber)
            
            bandRank[bandName] = rankingString;
        }
        
        print("🔥 firebase BAND_WRITE: Built priority array for \(bandRank.count) bands")
    }
    
    
}

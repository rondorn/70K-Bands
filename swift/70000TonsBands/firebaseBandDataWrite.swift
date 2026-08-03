//
//  filebaseBandDataWrite.swift
//  70K Bands
//
//  Created by Ron Dorn on 3/19/19.
//  Copyright © 2019 Ron Dorn. All rights reserved.
//

import Foundation
import Firebase


class firebaseBandDataWrite {
    
    var ref: DatabaseReference?
    var bandCompareFile = "bandCompare.data"
    var firebaseBandAttendedArray = [String : String]();
    var bandRank: [String : String] = [String : String]();
    let variableStoreHandle = variableStore();
    
    init(){
        print("🔥 [FIREBASE_BAND] init: Creating firebaseBandDataWrite instance")
    }

    private func ensureReference() -> DatabaseReference? {
        if ref == nil {
            ref = FirebaseConnectionHelper.databaseReference()
        }
        return ref
    }
    
    
    func loadCompareFile()->[String:String]{
        do {
            print("🔥 [FIREBASE_BAND] loadCompareFile: Starting to load cache from \(bandCompareFile)")
            firebaseBandAttendedArray = variableStoreHandle.readDataFromDisk(fileName: bandCompareFile) ?? [String : String]()
            print("🔥 [FIREBASE_BAND] loadCompareFile: Loaded \(firebaseBandAttendedArray.count) cached entries")
            if firebaseBandAttendedArray.count > 0 {
                print("🔥 [FIREBASE_BAND] loadCompareFile: Sample entries (first 5): \(Array(firebaseBandAttendedArray.prefix(5)))")
            }
        } catch {
            print("❌ [FIREBASE_BAND] loadCompareFile: ERROR - Couldn't read file: \(error)")
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
    
    /// Gets sanitized name for a band from SQLite, fallback to computing it
    private func getSanitizedNameForBand(_ bandName: String) -> String {
        // Get band from SQLite
        if let band = DataManager.shared.fetchBand(byName: bandName, eventYear: eventYear) {
            // SQLite bands don't have sanitizedName stored, so compute it
            return sanitizeBandNameForFirebase(bandName)
        }
        
        // Fallback to computing it
        return sanitizeBandNameForFirebase(bandName)
    }
    
    func writeSingleRecord(bandName: String, ranking: String, sanitizedName: String? = nil){
        
        print("🔥 [FIREBASE_BAND] writeSingleRecord: ENTRY - bandName='\(bandName)', ranking='\(ranking)', sanitizedName=\(sanitizedName ?? "nil"), thread=\(Thread.isMainThread ? "main" : "background")")
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            
            print("🔥 [FIREBASE_BAND] writeSingleRecord: Inside background queue for '\(bandName)'")
            
            // Check if Firebase reference is initialized
            guard let firebaseRef = self.ensureReference() else {
                print("❌ [FIREBASE_BAND] writeSingleRecord: BLOCKED - Firebase reference not initialized for '\(bandName)'")
                FirebaseWriteMonitor.shared.recordWriteFailure(context: "band_ref_nil:\(bandName)")
                return
            }
            
            print("✅ [FIREBASE_BAND] writeSingleRecord: Firebase reference is valid for '\(bandName)'")
            
            self.firebaseBandAttendedArray = self.loadCompareFile()
            
            let uid = (UIDevice.current.identifierForVendor?.uuidString)!
            print("🔥 [FIREBASE_BAND] writeSingleRecord: uid=\(uid), eventYear=\(eventYear), bandName='\(bandName)'")
            
            guard self.isBandInLineup(bandName, year: eventYear) else {
                print("⏭️ [FIREBASE_BAND] writeSingleRecord: SKIPPING '\(bandName)' — not in \(eventYear) lineup")
                return
            }
            
            //exit if things look wrong
            if (bandName == nil || bandName.isEmpty == true){
                print("❌ [FIREBASE_BAND] writeSingleRecord: BLOCKED - Invalid bandName (nil or empty)")
                return
            }
            
            // Use provided sanitized name or fall back to computing it
            let sanitizedBandName = sanitizedName ?? self.sanitizeBandNameForFirebase(bandName)
            print("🔥 [FIREBASE_BAND] writeSingleRecord: Sanitized band name: '\(sanitizedBandName)' (original: '\(bandName)')")
            
            let firebasePath = "bandData/\(uid)/\(eventYear)/\(sanitizedBandName)"
            print("🔥 [FIREBASE_BAND] writeSingleRecord: Writing to Firebase path: \(firebasePath)")
            
            let dataToWrite: [String: Any] = [
                "bandName": bandName,
                "sanitizedKey": sanitizedBandName,
                "ranking": ranking,
                "userID": uid,
                "year": String(eventYear)
            ]
            print("🔥 [FIREBASE_BAND] writeSingleRecord: Data payload: \(dataToWrite)")
            
            firebaseRef.child("bandData/").child(uid).child(String(eventYear)).child(sanitizedBandName).setValue(dataToWrite){
                    (error:Error?, ref:DatabaseReference) in
                    if let error = error {
                        print("❌ [FIREBASE_BAND] writeSingleRecord: ERROR - Writing firebase band data failed for '\(bandName)': \(error.localizedDescription)")
                        print("❌ [FIREBASE_BAND] writeSingleRecord: Error details - \(error)")
                        FirebaseWriteMonitor.shared.recordWriteFailure(context: "band:\(bandName)")
                    } else {
                        print("✅ [FIREBASE_BAND] writeSingleRecord: SUCCESS - Writing firebase band data saved successfully for '\(bandName)' with ranking '\(ranking)'!")
                        print("✅ [FIREBASE_BAND] writeSingleRecord: Firebase path written: \(ref.url)")
                        FirebaseWriteMonitor.shared.recordWriteSuccess(context: "band:\(bandName)")
                        
                        self.firebaseBandAttendedArray[bandName] = ranking
                        print("🔥 [FIREBASE_BAND] writeSingleRecord: Updating local cache for '\(bandName)' to '\(ranking)'")
                        self.variableStoreHandle.storeDataToDisk(data: self.firebaseBandAttendedArray, fileName: self.bandCompareFile)
                        print("✅ [FIREBASE_BAND] writeSingleRecord: Local cache updated and saved to disk")
                        FirebaseConnectionHelper.goOffline(reason: "band_single_write_complete")
                    }
                }

        }
    }
    
    func writeData (){
        let threadInfo = Thread.isMainThread ? "main" : "background"
        print("🔥 [FIREBASE_BAND] writeData: ========== ENTRY ==========")
        print("🔥 [FIREBASE_BAND] writeData: Called on \(threadInfo) thread")
        print("🔥 [FIREBASE_BAND] writeData: eventYear=\(eventYear), inTestEnvironment=\(inTestEnvironment), didVersionChange=\(didVersionChange)")
        
        // Check if Firebase reference is initialized
        guard ensureReference() != nil else {
            print("❌ [FIREBASE_BAND] writeData: BLOCKED - Firebase reference not initialized, skipping band analytics reporting")
            return
        }
        print("✅ [FIREBASE_BAND] writeData: Firebase reference is initialized")
        
        if inTestEnvironment == false {
            print("✅ [FIREBASE_BAND] writeData: Not in test environment, proceeding")
            
            // LEGACY: dataHandle.refreshData() no longer needed - priorities handled by PriorityManager
            let uid = (UIDevice.current.identifierForVendor?.uuidString)!
            print("🔥 [FIREBASE_BAND] writeData: UID=\(uid.isEmpty ? "EMPTY" : uid)")
            
            firebaseBandAttendedArray = self.loadCompareFile()
            print("🔥 [FIREBASE_BAND] writeData: Loaded \(firebaseBandAttendedArray.count) cached entries")
            
            if (uid.isEmpty == false){
                print("✅ [FIREBASE_BAND] writeData: UID is valid, proceeding with band data processing")
                
                self.buildBandRankArray()
                print("🔥 [FIREBASE_BAND] writeData: Built \(self.bandRank.count) lineup bands for year \(eventYear)")
                
                let cachedRankings = firebaseBandAttendedArray
                if cachedRankings == self.bandRank && didVersionChange == false {
                    print("⏭️ [FIREBASE_BAND] writeData: No lineup band ranking changes — skipping Firebase write")
                    print("🔥 [FIREBASE_BAND] writeData: ========== EXIT ==========")
                    return
                }
                
                guard let firebaseRef = self.ensureReference() else {
                    print("❌ [FIREBASE_BAND] writeData: BLOCKED - Firebase reference not initialized")
                    return
                }
                
                var batchUpdate = [String: [String: Any]]()
                for (bandName, ranking) in self.bandRank {
                    let sanitizedName = sanitizeBandNameForFirebase(bandName)
                    batchUpdate[sanitizedName] = [
                        "bandName": bandName,
                        "sanitizedKey": sanitizedName,
                        "ranking": ranking,
                        "userID": uid,
                        "year": String(eventYear)
                    ]
                }
                
                print("🔥 [FIREBASE_BAND] writeData: BATCH setValue for \(batchUpdate.count) lineup bands at bandData/\(uid)/\(eventYear)")
                firebaseRef.child("bandData").child(uid).child(String(eventYear)).setValue(batchUpdate) { error, _ in
                    if let error = error {
                        print("❌ [FIREBASE_BAND] writeData: Batch write failed: \(error.localizedDescription)")
                        FirebaseWriteMonitor.shared.recordWriteFailure(context: "band_batch")
                    } else {
                        print("✅ [FIREBASE_BAND] writeData: Batch write succeeded — stale non-lineup entries pruned")
                        FirebaseWriteMonitor.shared.recordWriteSuccess(context: "band_batch")
                        self.firebaseBandAttendedArray = self.bandRank
                        self.variableStoreHandle.storeDataToDisk(data: self.firebaseBandAttendedArray, fileName: self.bandCompareFile)
                    }
                    FirebaseConnectionHelper.goOffline(reason: "band_batch_write_complete")
                }
                
            } else {
                print("❌ [FIREBASE_BAND] writeData: BLOCKED - UID is empty, cannot write band data")
            }
        
        } else {
            print("⏭️ [FIREBASE_BAND] writeData: SKIPPED - In test environment")
        }
        
        print("🔥 [FIREBASE_BAND] writeData: ========== EXIT ==========")
    }
    
    func buildBandRankArray(){
        print("🔥 [FIREBASE_BAND] buildBandRankArray: ========== ENTRY ==========")
        
        // CRITICAL: Firebase reporting should ONLY use Default profile
        let firebaseProfileName = "Default"
        print("🔥 [FIREBASE_BAND] buildBandRankArray: CRITICAL - Using ONLY '\(firebaseProfileName)' profile for Firebase reporting")
        
        // Clear previous data
        bandRank.removeAll()
        print("🔥 [FIREBASE_BAND] buildBandRankArray: Cleared previous bandRank array")
        
        // Get current year from global eventYear variable
        let currentYear = Int(eventYear)
        print("🔥 [FIREBASE_BAND] buildBandRankArray: Filtering bands for current year: \(currentYear)")
        
        if currentYear <= 0 {
            print("❌ [FIREBASE_BAND] buildBandRankArray: ERROR - Invalid eventYear: \(currentYear)")
            print("🔥 [FIREBASE_BAND] buildBandRankArray: ========== EXIT (ERROR) ==========")
            return
        }
        
        // Restrict Firebase reporting to lineup bands for the current year (matches Android getBandNames()).
        let lineupBandNames = bandNamesHandler.shared.getBandNames()
        print("🔥 [FIREBASE_BAND] buildBandRankArray: Found \(lineupBandNames.count) lineup bands for year \(currentYear)")
        
        if lineupBandNames.isEmpty {
            print("⚠️ [FIREBASE_BAND] buildBandRankArray: WARNING - No lineup bands found for year \(currentYear)")
            print("🔥 [FIREBASE_BAND] buildBandRankArray: ========== EXIT (EMPTY) ==========")
            return
        }
        
        let priorityManager = SQLitePriorityManager.shared
        var bandsProcessed = 0
        var bandsSkipped = 0
        var priorityCounts: [String: Int] = ["Must": 0, "Might": 0, "Wont": 0, "Unknown": 0]
        
        for bandName in lineupBandNames {
            if bandName.isEmpty {
                bandsSkipped += 1
                print("⚠️ [FIREBASE_BAND] buildBandRankArray: Skipping band with empty bandName")
                continue
            }
            
            bandsProcessed += 1
            let priorityInteger = priorityManager.getPriority(for: bandName, eventYear: currentYear, profileName: firebaseProfileName)
            let rankingNumber = String(priorityInteger)
            let rankingString = resolvePriorityNumber(priority: rankingNumber)
            
            bandRank[bandName] = rankingString
            priorityCounts[rankingString, default: 0] += 1
            
            if bandsProcessed % 50 == 0 || bandName.lowercased().contains("ad infinitum") {
                print("🔥 [FIREBASE_BAND] buildBandRankArray: [\(bandsProcessed)] '\(bandName)' -> priority=\(priorityInteger), ranking='\(rankingString)'")
            }
        }
        
        print("🔥 [FIREBASE_BAND] buildBandRankArray: ========== SUMMARY ==========")
        print("🔥 [FIREBASE_BAND] buildBandRankArray: Bands processed: \(bandsProcessed)")
        print("🔥 [FIREBASE_BAND] buildBandRankArray: Bands skipped (empty name): \(bandsSkipped)")
        print("🔥 [FIREBASE_BAND] buildBandRankArray: Total in bandRank: \(bandRank.count)")
        print("🔥 [FIREBASE_BAND] buildBandRankArray: Priority distribution: \(priorityCounts)")
        
        // Check if specific band is in the array
        if let adInfinitumRanking = bandRank["Ad Infinitum"] {
            print("✅ [FIREBASE_BAND] buildBandRankArray: 'Ad Infinitum' found in bandRank with ranking: '\(adInfinitumRanking)'")
        } else {
            print("❌ [FIREBASE_BAND] buildBandRankArray: 'Ad Infinitum' NOT found in bandRank array!")
            let inLineup = lineupBandNames.contains { $0.lowercased() == "ad infinitum" }
            print("🔥 [FIREBASE_BAND] buildBandRankArray: 'Ad Infinitum' in lineup: \(inLineup)")
        }
        
        print("🔥 [FIREBASE_BAND] buildBandRankArray: ========== EXIT ==========")
    }
    
    private func isBandInLineup(_ bandName: String, year: Int) -> Bool {
        if year == eventYear {
            return bandNamesHandler.shared.getBandNames().contains(bandName)
        }
        return DataManager.shared.fetchBands(forYear: year)
            .contains { $0.lineIndex != nil && $0.bandName == bandName }
    }
    
    
}

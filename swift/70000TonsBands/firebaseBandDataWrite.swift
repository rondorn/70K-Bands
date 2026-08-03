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
    
    /// Lineup bands for the pointer storage year (SQLite when UI year differs).
    private func lineupBandNames(for storageYear: Int) -> [String] {
        if storageYear == eventYear {
            let names = bandNamesHandler.shared.getBandNames()
            if !names.isEmpty {
                return names
            }
        }
        return DataManager.shared.fetchBands(forYear: storageYear)
            .filter { $0.lineIndex != nil }
            .map { $0.bandName }
            .sorted()
    }
    
    func writeSingleRecord(bandName: String, ranking: String, sanitizedName: String? = nil){
        
        print("🔥 [FIREBASE_BAND] writeSingleRecord: ENTRY - bandName='\(bandName)', ranking='\(ranking)', sanitizedName=\(sanitizedName ?? "nil"), thread=\(Thread.isMainThread ? "main" : "background")")
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            
            print("🔥 [FIREBASE_BAND] writeSingleRecord: Inside background queue for '\(bandName)'")
            
            guard let firebaseRef = self.ensureReference() else {
                print("❌ [FIREBASE_BAND] writeSingleRecord: BLOCKED - Firebase reference not initialized for '\(bandName)'")
                FirebaseWriteMonitor.shared.recordWriteFailure(context: "band_ref_nil:\(bandName)")
                return
            }
            
            self.firebaseBandAttendedArray = self.loadCompareFile()
            
            let uid = (UIDevice.current.identifierForVendor?.uuidString)!
            let storageYear = FirebaseConnectionHelper.firebaseStorageEventYear()
            guard storageYear > 2000 else {
                print("❌ [FIREBASE_BAND] writeSingleRecord: BLOCKED - pointer Current event year unavailable")
                return
            }
            print("🔥 [FIREBASE_BAND] writeSingleRecord: uid=\(uid), storageYear=\(storageYear), uiEventYear=\(eventYear), bandName='\(bandName)'")
            
            guard self.isBandInLineup(bandName, storageYear: storageYear) else {
                print("⏭️ [FIREBASE_BAND] writeSingleRecord: SKIPPING '\(bandName)' — not in \(storageYear) lineup")
                return
            }
            
            if bandName.isEmpty {
                print("❌ [FIREBASE_BAND] writeSingleRecord: BLOCKED - Invalid bandName (empty)")
                return
            }
            
            let sanitizedBandName = sanitizedName ?? self.sanitizeBandNameForFirebase(bandName)
            let firebasePath = "bandData/\(uid)/\(storageYear)/\(sanitizedBandName)"
            print("🔥 [FIREBASE_BAND] writeSingleRecord: Writing to Firebase path: \(firebasePath)")
            
            let dataToWrite: [String: Any] = [
                "bandName": bandName,
                "sanitizedKey": sanitizedBandName,
                "ranking": ranking,
                "userID": uid,
                "year": String(storageYear)
            ]
            
            firebaseRef.child("bandData/").child(uid).child(String(storageYear)).child(sanitizedBandName).setValue(dataToWrite){
                    (error:Error?, ref:DatabaseReference) in
                    if let error = error {
                        print("❌ [FIREBASE_BAND] writeSingleRecord: ERROR - \(error.localizedDescription)")
                        FirebaseWriteMonitor.shared.recordWriteFailure(context: "band:\(bandName)")
                    } else {
                        print("✅ [FIREBASE_BAND] writeSingleRecord: SUCCESS for '\(bandName)' at \(ref.url)")
                        FirebaseWriteMonitor.shared.recordWriteSuccess(context: "band:\(bandName)")
                        self.firebaseBandAttendedArray[bandName] = ranking
                        self.variableStoreHandle.storeDataToDisk(data: self.firebaseBandAttendedArray, fileName: self.bandCompareFile)
                        FirebaseConnectionHelper.goOffline(reason: "band_single_write_complete")
                    }
                }

        }
    }
    
    func writeData(completion: (() -> Void)? = nil) {
        let finish: () -> Void = { completion?() }
        let threadInfo = Thread.isMainThread ? "main" : "background"
        print("🔥 [FIREBASE_BAND] writeData: ========== ENTRY ==========")
        print("🔥 [FIREBASE_BAND] writeData: Called on \(threadInfo) thread")

        guard FirebaseWriteMonitor.shared.shouldRunBandSync() else {
            print("⏭️ [FIREBASE_BAND] writeData: No pending band sync — skipping bandData upload")
            finish()
            return
        }

        // Bulk sync may run before pointer download finishes — wait briefly for Current::eventYear.
        let storageYear = FirebaseConnectionHelper.firebaseStorageEventYear(maxWaitSeconds: 15)
        print("🔥 [FIREBASE_BAND] writeData: storageYear=\(storageYear), uiEventYear=\(eventYear), inTestEnvironment=\(inTestEnvironment), didVersionChange=\(didVersionChange)")
        
        guard storageYear > 2000 else {
            print("❌ [FIREBASE_BAND] writeData: BLOCKED - pointer Current event year unavailable; refusing invalid write")
            finish()
            return
        }
        
        guard ensureReference() != nil else {
            print("❌ [FIREBASE_BAND] writeData: BLOCKED - Firebase reference not initialized")
            finish()
            return
        }
        
        if inTestEnvironment == false {
            let uid = (UIDevice.current.identifierForVendor?.uuidString)!
            
            guard uid.isEmpty == false else {
                print("❌ [FIREBASE_BAND] writeData: BLOCKED - UID is empty")
                finish()
                return
            }
            
            firebaseBandAttendedArray = self.loadCompareFile()
            
            buildBandRankArray(storageYear: storageYear)
            
            guard bandRank.isEmpty == false else {
                print("❌ [FIREBASE_BAND] writeData: BLOCKED - no lineup bands for pointer year \(storageYear); refusing invalid write")
                finish()
                return
            }
            
            let forceFullBandSync = FirebaseWriteMonitor.shared.shouldRunBandSync()
            if firebaseBandAttendedArray == bandRank && didVersionChange == false && !forceFullBandSync {
                print("⏭️ [FIREBASE_BAND] writeData: No lineup band ranking changes — skipping Firebase write")
                finish()
                return
            }
            print("🔥 [FIREBASE_BAND] writeData: Sending full lineup (\(bandRank.count) bands) for pointer year \(storageYear)")
            
            guard let firebaseRef = ensureReference() else {
                finish()
                return
            }
            
            var batchUpdate = [String: [String: Any]]()
            for (bandName, ranking) in bandRank {
                let sanitizedName = sanitizeBandNameForFirebase(bandName)
                batchUpdate[sanitizedName] = [
                    "bandName": bandName,
                    "sanitizedKey": sanitizedName,
                    "ranking": ranking,
                    "userID": uid,
                    "year": String(storageYear)
                ]
            }
            
            print("🔥 [FIREBASE_BAND] writeData: BATCH setValue for \(batchUpdate.count) lineup bands at bandData/\(uid)/\(storageYear)")
            firebaseRef.child("bandData").child(uid).child(String(storageYear)).setValue(batchUpdate) { error, _ in
                if let error = error {
                    print("❌ [FIREBASE_BAND] writeData: Batch write failed: \(error.localizedDescription)")
                    FirebaseWriteMonitor.shared.recordWriteFailure(context: "band_batch")
                } else {
                    print("✅ [FIREBASE_BAND] writeData: Batch write succeeded for pointer year \(storageYear)")
                    FirebaseWriteMonitor.shared.recordWriteSuccess(context: "band_batch")
                    self.firebaseBandAttendedArray = self.bandRank
                    self.variableStoreHandle.storeDataToDisk(data: self.firebaseBandAttendedArray, fileName: self.bandCompareFile)
                }
                FirebaseConnectionHelper.goOffline(reason: "band_batch_write_complete")
                finish()
            }
        } else {
            finish()
        }
        
        print("🔥 [FIREBASE_BAND] writeData: ========== EXIT ==========")
    }
    
    func buildBandRankArray(storageYear: Int){
        print("🔥 [FIREBASE_BAND] buildBandRankArray: storageYear=\(storageYear), uiEventYear=\(eventYear)")
        
        let firebaseProfileName = "Default"
        bandRank.removeAll()
        
        guard storageYear > 2000 else {
            print("❌ [FIREBASE_BAND] buildBandRankArray: invalid storageYear")
            return
        }
        
        let lineupBandNames = lineupBandNames(for: storageYear)
        print("🔥 [FIREBASE_BAND] buildBandRankArray: Found \(lineupBandNames.count) lineup bands for pointer year \(storageYear)")
        
        guard lineupBandNames.isEmpty == false else {
            print("❌ [FIREBASE_BAND] buildBandRankArray: no lineup bands for pointer year \(storageYear)")
            return
        }
        
        let priorityManager = SQLitePriorityManager.shared
        for bandName in lineupBandNames {
            guard bandName.isEmpty == false else { continue }
            let priorityInteger = priorityManager.getPriority(for: bandName, eventYear: storageYear, profileName: firebaseProfileName)
            let rankingString = resolvePriorityNumber(priority: String(priorityInteger))
            bandRank[bandName] = rankingString
        }
        
        print("🔥 [FIREBASE_BAND] buildBandRankArray: Built rankings for \(bandRank.count) lineup bands")
    }
    
    private func isBandInLineup(_ bandName: String, storageYear: Int) -> Bool {
        return lineupBandNames(for: storageYear).contains(bandName)
    }
}

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
    private var initializationAttempts = 0
    private let maxInitAttempts = 3
    
    init(){
        print("🔥 [FIREBASE_BAND] init: Creating firebaseBandDataWrite instance")
        print("🔥 [FIREBASE_BAND] init: AppDelegate.isFirebaseConfigured = \(AppDelegate.isFirebaseConfigured)")
        initializeFirebaseReference()
    }
    
    /// Attempts to initialize Firebase Database reference with retry logic
    private func initializeFirebaseReference(attempt: Int = 1) {
        print("🔥 [FIREBASE_BAND] initializeFirebaseReference: Attempt \(attempt)/\(maxInitAttempts)")
        
        // Check if Firebase is configured
        if AppDelegate.isFirebaseConfigured {
            ref = Database.database().reference()
            print("✅ [FIREBASE_BAND] initializeFirebaseReference: Firebase Database reference initialized successfully")
            print("✅ [FIREBASE_BAND] initializeFirebaseReference: ref is \(ref != nil ? "set" : "nil")")
        } else {
            print("⚠️ [FIREBASE_BAND] initializeFirebaseReference: Firebase not yet configured (attempt \(attempt)/\(maxInitAttempts))")
            
            if attempt < maxInitAttempts {
                // Retry after 2 second delay
                print("🔥 [FIREBASE_BAND] initializeFirebaseReference: Scheduling retry in 2 seconds...")
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.initializeFirebaseReference(attempt: attempt + 1)
                }
            } else {
                print("❌ [FIREBASE_BAND] initializeFirebaseReference: Failed to initialize Firebase after \(maxInitAttempts) attempts - will skip analytics")
            }
        }
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
            guard let firebaseRef = self.ref else {
                print("❌ [FIREBASE_BAND] writeSingleRecord: BLOCKED - Firebase reference not initialized for '\(bandName)'")
                FirebaseWriteMonitor.shared.recordWriteFailure(context: "band_ref_nil:\(bandName)")
                return
            }
            
            print("✅ [FIREBASE_BAND] writeSingleRecord: Firebase reference is valid for '\(bandName)'")
            
            self.firebaseBandAttendedArray = self.loadCompareFile()
            
            let uid = (UIDevice.current.identifierForVendor?.uuidString)!
            print("🔥 [FIREBASE_BAND] writeSingleRecord: uid=\(uid), eventYear=\(eventYear), bandName='\(bandName)'")
            
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
        guard self.ref != nil else {
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
                print("🔥 [FIREBASE_BAND] writeData: Processing \(self.bandRank.count) bands from bandRank array")
                
                // CRITICAL: Firebase reporting should ONLY use Default profile
                let firebaseProfileName = "Default"
                print("🔥 [FIREBASE_BAND] writeData: CRITICAL - Using ONLY '\(firebaseProfileName)' profile for Firebase reporting")
                
                var bandsChecked = 0
                var bandsWritten = 0
                var bandsSkipped = 0
                var bandsWithChanges = 0
                
                for bandName in self.bandRank.keys {
                    bandsChecked += 1
                    
                    let priorityManager = SQLitePriorityManager.shared
                    // CRITICAL: Explicitly use "Default" profile for Firebase reporting
                    let rankingInteger = priorityManager.getPriority(for: bandName, eventYear: eventYear, profileName: firebaseProfileName)
                    let ranking = resolvePriorityNumber(priority: String(rankingInteger)) ?? "Unknown"
                    
                    let cachedRanking = firebaseBandAttendedArray[bandName]
                    let cachedRankingStr = cachedRanking ?? "nil (not in cache)"
                    let rankingFromBandRank = self.bandRank[bandName] ?? "nil"
                    let isNewBand = cachedRanking == nil
                    
                    print("🔥 [FIREBASE_BAND] writeData: [\(bandsChecked)/\(self.bandRank.count)] Checking band: '\(bandName)'")
                    print("   - Profile used: '\(firebaseProfileName)' (CRITICAL: Firebase always uses Default)")
                    print("   - Priority integer: \(rankingInteger)")
                    print("   - Current ranking: '\(ranking)'")
                    print("   - Cached ranking: '\(cachedRankingStr)'")
                    print("   - Is new band (not in cache): \(isNewBand)")
                    print("   - Ranking from bandRank: '\(rankingFromBandRank)'")
                    print("   - didVersionChange: \(didVersionChange)")
                    
                    // CRITICAL FIX: Always write new bands (not in cache) even if ranking is "Unknown"
                    // This ensures newly added bands like "Ad Infinitum" get written to Firebase
                    let rankingChanged = cachedRanking != ranking
                    let shouldWrite = isNewBand || rankingChanged || didVersionChange
                    
                    print("   - Comparison: cachedRanking != ranking = \(rankingChanged)")
                    print("   - Should write: \(shouldWrite) (isNewBand=\(isNewBand) OR rankingChanged=\(rankingChanged) OR didVersionChange=\(didVersionChange))")
                    
                    if shouldWrite {
                        bandsWithChanges += 1
                        let writeReason: String
                        if isNewBand {
                            writeReason = "NEW BAND (not in cache)"
                        } else if rankingChanged {
                            writeReason = "ranking changed from '\(cachedRankingStr)' to '\(ranking)'"
                        } else {
                            writeReason = "version changed"
                        }
                        print("✅ [FIREBASE_BAND] writeData: WRITING band '\(bandName)' - \(writeReason) (from '\(firebaseProfileName)' profile)")
                        let sanitizedName = getSanitizedNameForBand(bandName)
                        print("🔥 [FIREBASE_BAND] writeData: Sanitized name for '\(bandName)': '\(sanitizedName)'")
                        writeSingleRecord(bandName: bandName, ranking: ranking, sanitizedName: sanitizedName)
                        bandsWritten += 1
                    } else {
                        bandsSkipped += 1
                        print("⏭️ [FIREBASE_BAND] writeData: SKIPPING band '\(bandName)' - no change (cached: '\(cachedRankingStr)', current: '\(ranking)' from '\(firebaseProfileName)' profile)")
                    }
                }
                
                print("🔥 [FIREBASE_BAND] writeData: ========== SUMMARY ==========")
                print("🔥 [FIREBASE_BAND] writeData: Total bands checked: \(bandsChecked)")
                print("🔥 [FIREBASE_BAND] writeData: Bands with changes: \(bandsWithChanges)")
                print("🔥 [FIREBASE_BAND] writeData: Bands written: \(bandsWritten)")
                print("🔥 [FIREBASE_BAND] writeData: Bands skipped: \(bandsSkipped)")
                print("🔥 [FIREBASE_BAND] writeData: =============================")
                
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
        
        // Upload ALL priorities for the year (lineup + unofficial/special entries),
        // not only lineup bands. This keeps Firebase stats aligned with user choices.
        let allPriorities = SQLitePriorityManager.shared.getAllPriorities(
            eventYear: currentYear,
            profileName: firebaseProfileName
        )
        print("🔥 [FIREBASE_BAND] buildBandRankArray: Found \(allPriorities.count) priority records in SQLite for year \(currentYear) (all entries)")
        
        if allPriorities.isEmpty {
            print("⚠️ [FIREBASE_BAND] buildBandRankArray: WARNING - No priorities found in SQLite for year \(currentYear)")
            print("🔥 [FIREBASE_BAND] buildBandRankArray: ========== EXIT (EMPTY) ==========")
            return
        }
        
        var bandsProcessed = 0
        var bandsSkipped = 0
        var priorityCounts: [String: Int] = ["Must": 0, "Might": 0, "Wont": 0, "Unknown": 0]
        
        for (bandName, priorityInteger) in allPriorities {
            if bandName.isEmpty {
                bandsSkipped += 1
                print("⚠️ [FIREBASE_BAND] buildBandRankArray: Skipping band with empty bandName")
                continue
            }
            
            bandsProcessed += 1
            let rankingNumber = String(priorityInteger)
            let rankingString = resolvePriorityNumber(priority: rankingNumber)
            
            bandRank[bandName] = rankingString
            priorityCounts[rankingString, default: 0] += 1
            
            // Log every 50th band to avoid spam, but always log specific bands if needed
            if bandsProcessed % 50 == 0 || bandName.lowercased().contains("ad infinitum") {
                print("🔥 [FIREBASE_BAND] buildBandRankArray: [\(bandsProcessed)] '\(bandName)' -> priority=\(priorityInteger) (from '\(firebaseProfileName)' profile), ranking='\(rankingString)'")
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
            let hasRawPriority = allPriorities.keys.contains { $0.lowercased() == "ad infinitum" }
            print("🔥 [FIREBASE_BAND] buildBandRankArray: Raw priority entry exists for 'Ad Infinitum': \(hasRawPriority)")
        }
        
        print("🔥 [FIREBASE_BAND] buildBandRankArray: ========== EXIT ==========")
    }
    
    
}

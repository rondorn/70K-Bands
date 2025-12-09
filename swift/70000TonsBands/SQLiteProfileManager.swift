//
//  SQLiteProfileManager.swift
//  70K Bands
//
//  Manages profile metadata in SQLite database
//

import Foundation
import SQLite

class SQLiteProfileManager {
    static let shared = SQLiteProfileManager()
    
    private var db: Connection?
    private let serialQueue = DispatchQueue(label: "com.70kbands.profilemanager.sqlite")
    
    // Table definition
    private let profilesTable = Table("shared_profiles")
    private let userIdColumn = Expression<String>("userId")
    private let labelColumn = Expression<String>("label")
    private let colorColumn = Expression<String>("color")  // Hex color string
    private let importDateColumn = Expression<Date>("importDate")
    private let shareDateColumn = Expression<Date>("shareDate")
    private let eventYearColumn = Expression<Int64>("eventYear")
    private let priorityCountColumn = Expression<Int>("priorityCount")
    private let attendanceCountColumn = Expression<Int>("attendanceCount")
    private let isReadOnlyColumn = Expression<Bool>("isReadOnly")  // true for shared profiles
    
    private init() {
        print("🔧 [PROFILE_INIT] SQLiteProfileManager init() called")
        setupDatabase()
        print("🔧 [PROFILE_INIT] SQLiteProfileManager init() completed")
    }
    
    private func setupDatabase() {
        print("🔧 [PROFILE_INIT] setupDatabase() starting...")
        do {
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            let dbPath = "\(documentsPath)/profiles.sqlite3"
            
            print("📊 SQLiteProfileManager: Database path: \(dbPath)")
            
            db = try Connection(dbPath)
            
            // CRITICAL: Set busy timeout to handle concurrent writes
            // This prevents "database is locked" errors when multiple managers access the same DB
            try db?.execute("PRAGMA busy_timeout = 30000")  // 30 seconds
            print("✅ SQLiteProfileManager: Set busy timeout to 30 seconds")
            
            // Create table if not exists
            try db?.run(profilesTable.create(ifNotExists: true) { t in
                t.column(userIdColumn, primaryKey: true)
                t.column(labelColumn)
                t.column(colorColumn)
                t.column(importDateColumn)
                t.column(shareDateColumn)
                t.column(eventYearColumn)
                t.column(priorityCountColumn)
                t.column(attendanceCountColumn)
                t.column(isReadOnlyColumn, defaultValue: false)
            })
            
            print("✅ SQLiteProfileManager: Database initialized successfully")
            
        } catch {
            print("❌ SQLiteProfileManager: Failed to initialize database: \(error)")
        }
    }
    
    /// Saves or updates a profile
    /// - Parameter profile: The profile metadata to save
    /// - Returns: true if successful
    func saveProfile(_ profile: ProfileMetadata) -> Bool {
        var success = false
        let semaphore = DispatchSemaphore(value: 0)
        
        serialQueue.async { [weak self] in
            defer { semaphore.signal() }
            
            guard let self = self, let db = self.db else { return }
            
            do {
                let existing = self.profilesTable.filter(self.userIdColumn == profile.userId)
                
                if try db.scalar(existing.count) > 0 {
                    // Update
                    try db.run(existing.update(
                        self.labelColumn <- profile.label,
                        self.colorColumn <- profile.color,
                        self.importDateColumn <- profile.importDate,
                        self.shareDateColumn <- profile.shareDate,
                        self.eventYearColumn <- profile.eventYear,
                        self.priorityCountColumn <- profile.priorityCount,
                        self.attendanceCountColumn <- profile.attendanceCount,
                        self.isReadOnlyColumn <- profile.isReadOnly
                    ))
                    print("✅ SQLiteProfileManager: Updated profile: \(profile.label)")
                } else {
                    // Insert
                    try db.run(self.profilesTable.insert(
                        self.userIdColumn <- profile.userId,
                        self.labelColumn <- profile.label,
                        self.colorColumn <- profile.color,
                        self.importDateColumn <- profile.importDate,
                        self.shareDateColumn <- profile.shareDate,
                        self.eventYearColumn <- profile.eventYear,
                        self.priorityCountColumn <- profile.priorityCount,
                        self.attendanceCountColumn <- profile.attendanceCount,
                        self.isReadOnlyColumn <- profile.isReadOnly
                    ))
                    print("✅ SQLiteProfileManager: Inserted profile: \(profile.label)")
                }
                
                success = true
                
            } catch {
                print("❌ SQLiteProfileManager: Failed to save profile: \(error)")
            }
        }
        
        semaphore.wait()
        return success
    }
    
    /// Gets a profile by userId
    /// - Parameter userId: The user ID to look up
    /// - Returns: ProfileMetadata if found, nil otherwise
    /// - Note: If "Default" is requested and doesn't exist, it will be created automatically
    func getProfile(userId: String) -> ProfileMetadata? {
        var result: ProfileMetadata?
        let semaphore = DispatchSemaphore(value: 0)
        
        serialQueue.async { [weak self] in
            defer { semaphore.signal() }
            
            guard let self = self, let db = self.db else { return }
            
            do {
                let query = self.profilesTable.filter(self.userIdColumn == userId)
                
                if let row = try db.pluck(query) {
                    result = ProfileMetadata(
                        userId: try row.get(self.userIdColumn),
                        label: try row.get(self.labelColumn),
                        color: try row.get(self.colorColumn),
                        importDate: try row.get(self.importDateColumn),
                        shareDate: try row.get(self.shareDateColumn),
                        eventYear: try row.get(self.eventYearColumn),
                        priorityCount: try row.get(self.priorityCountColumn),
                        attendanceCount: try row.get(self.attendanceCountColumn),
                        isReadOnly: try row.get(self.isReadOnlyColumn)
                    )
                } else if userId == "Default" {
                    // Auto-create Default profile if it doesn't exist (first launch)
                    print("📝 SQLiteProfileManager: Creating Default profile (first launch)")
                    try db.run(self.profilesTable.insert(
                        self.userIdColumn <- "Default",
                        self.labelColumn <- "Default",
                        self.colorColumn <- "#FFFFFF",
                        self.importDateColumn <- Date(),
                        self.shareDateColumn <- Date(),
                        self.eventYearColumn <- Int64(eventYear),
                        self.priorityCountColumn <- 0,
                        self.attendanceCountColumn <- 0,
                        self.isReadOnlyColumn <- false
                    ))
                    print("✅ SQLiteProfileManager: Default profile created successfully")
                    
                    // Return the newly created profile
                    result = ProfileMetadata(
                        userId: "Default",
                        label: "Default",
                        color: "#FFFFFF",
                        importDate: Date(),
                        shareDate: Date(),
                        eventYear: Int64(eventYear),
                        priorityCount: 0,
                        attendanceCount: 0,
                        isReadOnly: false
                    )
                }
            } catch {
                print("❌ SQLiteProfileManager: Failed to get/create profile: \(error)")
            }
        }
        
        semaphore.wait()
        return result
    }
    
    /// Gets all profiles
    /// - Returns: Array of all ProfileMetadata, with "Default" first
    /// - Note: If no profiles exist, Default will be created automatically
    func getAllProfiles() -> [ProfileMetadata] {
        var results: [ProfileMetadata] = []
        let semaphore = DispatchSemaphore(value: 0)
        
        serialQueue.async { [weak self] in
            defer { semaphore.signal() }
            
            guard let self = self, let db = self.db else { return }
            
            do {
                for row in try db.prepare(self.profilesTable) {
                    let profile = ProfileMetadata(
                        userId: try row.get(self.userIdColumn),
                        label: try row.get(self.labelColumn),
                        color: try row.get(self.colorColumn),
                        importDate: try row.get(self.importDateColumn),
                        shareDate: try row.get(self.shareDateColumn),
                        eventYear: try row.get(self.eventYearColumn),
                        priorityCount: try row.get(self.priorityCountColumn),
                        attendanceCount: try row.get(self.attendanceCountColumn),
                        isReadOnly: try row.get(self.isReadOnlyColumn)
                    )
                    results.append(profile)
                }
                
                // If no profiles exist at all, create Default (first launch)
                if results.isEmpty {
                    print("📝 SQLiteProfileManager: No profiles found, creating Default (first launch)")
                    try db.run(self.profilesTable.insert(
                        self.userIdColumn <- "Default",
                        self.labelColumn <- "Default",
                        self.colorColumn <- "#FFFFFF",
                        self.importDateColumn <- Date(),
                        self.shareDateColumn <- Date(),
                        self.eventYearColumn <- Int64(eventYear),
                        self.priorityCountColumn <- 0,
                        self.attendanceCountColumn <- 0,
                        self.isReadOnlyColumn <- false
                    ))
                    print("✅ SQLiteProfileManager: Default profile created successfully")
                    
                    // Add to results
                    results.append(ProfileMetadata(
                        userId: "Default",
                        label: "Default",
                        color: "#FFFFFF",
                        importDate: Date(),
                        shareDate: Date(),
                        eventYear: Int64(eventYear),
                        priorityCount: 0,
                        attendanceCount: 0,
                        isReadOnly: false
                    ))
                }
            } catch {
                print("❌ SQLiteProfileManager: Failed to get/create profiles: \(error)")
            }
        }
        
        semaphore.wait()
        
        // Sort: Default first, then by label
        return results.sorted { profile1, profile2 in
            if profile1.userId == "Default" { return true }
            if profile2.userId == "Default" { return false }
            return profile1.label < profile2.label
        }
    }
    
    /// Deletes a profile
    /// - Parameter userId: The user ID to delete
    /// - Returns: true if successful
    func deleteProfile(userId: String) -> Bool {
        // Cannot delete Default
        guard userId != "Default" else {
            print("❌ SQLiteProfileManager: Cannot delete Default profile")
            return false
        }
        
        var success = false
        let semaphore = DispatchSemaphore(value: 0)
        
        serialQueue.async { [weak self] in
            defer { semaphore.signal() }
            
            guard let self = self, let db = self.db else { return }
            
            do {
                let profile = self.profilesTable.filter(self.userIdColumn == userId)
                try db.run(profile.delete())
                print("✅ SQLiteProfileManager: Deleted profile: \(userId)")
                success = true
            } catch {
                print("❌ SQLiteProfileManager: Failed to delete profile: \(error)")
            }
        }
        
        semaphore.wait()
        return success
    }
    
    /// Updates the label for a profile
    /// - Parameters:
    ///   - userId: The user ID
    ///   - newLabel: The new label
    /// - Returns: true if successful
    func updateLabel(userId: String, newLabel: String) -> Bool {
        var success = false
        let semaphore = DispatchSemaphore(value: 0)
        
        serialQueue.async { [weak self] in
            defer { semaphore.signal() }
            
            guard let self = self, let db = self.db else { return }
            
            do {
                let profile = self.profilesTable.filter(self.userIdColumn == userId)
                try db.run(profile.update(self.labelColumn <- newLabel))
                print("✅ SQLiteProfileManager: Updated label for \(userId) to: \(newLabel)")
                success = true
            } catch {
                print("❌ SQLiteProfileManager: Failed to update label: \(error)")
            }
        }
        
        semaphore.wait()
        return success
    }
    
    /// Checks if a profile is read-only (i.e., a shared profile)
    /// - Parameter userId: The user ID to check
    /// - Returns: true if read-only, false otherwise
    func isReadOnly(userId: String) -> Bool {
        guard let profile = getProfile(userId: userId) else {
            return true  // If profile doesn't exist, treat as read-only for safety
        }
        return profile.isReadOnly
    }
}

// MARK: - Data Model

struct ProfileMetadata: Codable {
    let userId: String          // Immutable - Firebase UserID or "Default"
    let label: String           // Mutable - Display name
    let color: String           // Hex color (e.g., "#FF0000")
    let importDate: Date
    let shareDate: Date
    let eventYear: Int64
    let priorityCount: Int
    let attendanceCount: Int
    let isReadOnly: Bool        // true for shared profiles
}


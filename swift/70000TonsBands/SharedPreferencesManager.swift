//
//  SharedPreferencesManager.swift
//  70K Bands
//
//  Manages shared preferences feature - allows users to share and import
//  Must/Might/Won't priorities and event attendance schedules
//

import Foundation
import UIKit

// MARK: - Data Models

/// Represents a complete set of shared preferences
struct SharedPreferenceSet: Codable {
    let senderUserId: String       // Firebase UserID (immutable profile key)
    let senderName: String          // Display name (mutable label)
    let shareDate: Date
    let eventYear: Int
    let priorities: [String: Int]  // bandName -> priority level
    let attendance: [String: Int]  // event index -> attendance status
    let version: String = "1.0"
    
    var id: String {
        return "\(senderUserId)_\(eventYear)"
    }
}

/// Metadata about an imported shared preference set
struct ImportedPreferenceMetadata: Codable {
    let id: String                 // senderUserId_eventYear
    let senderUserId: String       // Firebase UserID (immutable profile key)
    let senderName: String         // Display name (mutable label)
    let shareDate: Date
    let eventYear: Int
    let importDate: Date
    let priorityCount: Int
    let attendanceCount: Int
}

// MARK: - Shared Preferences Manager

class SharedPreferencesManager {
    static let shared = SharedPreferencesManager()
    
    private let fileManager = FileManager.default
    private let priorityManager = SQLitePriorityManager.shared
    private let attendanceManager = AttendanceManager()
    
    // Lazy initialization to avoid blocking during app launch
    private lazy var profileManager: SQLiteProfileManager = {
        print("📦 [INIT] Initializing SQLiteProfileManager (lazy)")
        return SQLiteProfileManager.shared
    }()
    
    // Storage keys
    private let activeSourceKey = "ActivePreferenceSource"
    
    // File extension for shared preferences (app-specific)
    private var fileExtension: String {
        return FestivalConfig.current.isMDF() ? "mdfshare" : "70kshare"
    }
    
    // Public property for accessing current profile name
    var currentSharedProfileName: String? {
        return getActivePreferenceSource()
    }
    
    private init() {
        print("🔧 [SHARING_INIT] SharedPreferencesManager init() called")
        
        // Note: profileManager is lazy - won't be initialized until first access
        // This prevents blocking during app launch
        
        // Migrate old UserDefaults metadata to SQLite if needed (async, non-blocking)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.migrateMetadataToSQLite()
        }
        
        print("🔧 [SHARING_INIT] SharedPreferencesManager init() completed")
    }
    
    /// One-time migration from UserDefaults to SQLite
    private func migrateMetadataToSQLite() {
        let metadataKey = "ImportedPreferencesMetadata"
        
        // Check if we have old metadata in UserDefaults
        guard let data = UserDefaults.standard.data(forKey: metadataKey),
              let oldMetadata = try? JSONDecoder().decode([ImportedPreferenceMetadata].self, from: data) else {
            return
        }
        
        print("📦 [MIGRATION] Migrating \(oldMetadata.count) profiles from UserDefaults to SQLite")
        
        for old in oldMetadata {
            let profile = ProfileMetadata(
                userId: old.senderUserId,
                label: old.senderName,
                color: ProfileColorManager.shared.getHexString(for: ProfileColorManager.shared.getColor(for: old.senderUserId)),
                importDate: old.importDate,
                shareDate: old.shareDate,
                eventYear: Int64(old.eventYear),
                priorityCount: old.priorityCount,
                attendanceCount: old.attendanceCount,
                isReadOnly: old.senderUserId != "Default"  // Only Default is editable
            )
            
            if profileManager.saveProfile(profile) {
                print("✅ [MIGRATION] Migrated: \(old.senderName)")
            }
        }
        
        // Clear old UserDefaults data
        UserDefaults.standard.removeObject(forKey: metadataKey)
        UserDefaults.standard.synchronize()
        
        print("✅ [MIGRATION] Migration complete")
    }
    
    // MARK: - Export Functionality
    
    /// Exports current user's priorities and attendance to a shareable file
    /// Sender can provide a name (defaults to device name if not provided)
    /// - Parameter shareName: Optional name for the share (e.g., "John's iPhone")
    /// - Returns: URL of the created file, or nil if export failed
    func exportCurrentPreferences(shareName: String? = nil) -> URL? {
        let name = shareName ?? UIDevice.current.name  // Use device name as default
        
        // Get sender's Firebase UserID (device identifier)
        let senderUserId = UIDevice.current.identifierForVendor?.uuidString ?? "Unknown"
        
        // Get current priorities (from "Default" profile only)
        let priorities = priorityManager.getAllPriorities(eventYear: eventYear, profileName: "Default")
        
        // Get current attendance (from "Default" profile only)
        let attendanceData = SQLiteAttendanceManager.shared.getAllAttendanceDataByIndex(profileName: "Default")
        var attendance: [String: Int] = [:]
        for (index, data) in attendanceData {
            if let status = data["status"] as? Int {
                attendance[index] = status
            }
        }
        
        // Create preference set with sender's UserID (name optional)
        let preferenceSet = SharedPreferenceSet(
            senderUserId: senderUserId,
            senderName: name,
            shareDate: Date(),
            eventYear: eventYear,
            priorities: priorities,
            attendance: attendance
        )
        
        print("📤 [EXPORT] Exporting with UserID: \(senderUserId), Name: '\(name.isEmpty ? "(none provided)" : name)'")
        
        // Encode to JSON (compact, no pretty printing to reduce size)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        
        guard let jsonData = try? encoder.encode(preferenceSet) else {
            print("❌ Failed to encode preference set")
            return nil
        }
        
        // Create file with profile name
        let fileName = "\(name).\(fileExtension)"
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let sharesDir = documentsDir.appendingPathComponent("Shares")
        
        // Create Shares directory if needed
        try? fileManager.createDirectory(at: sharesDir, withIntermediateDirectories: true)
        
        let fileURL = sharesDir.appendingPathComponent(fileName)
        
        // Remove any existing file with same name
        try? fileManager.removeItem(at: fileURL)
        
        do {
            try jsonData.write(to: fileURL, options: [.atomic])
            
            // Set file attributes to ensure it's shareable
            try fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: fileURL.path)
            
            print("✅ Exported preferences to: \(fileURL.path)")
            print("✅ File size: \(jsonData.count) bytes")
            print("✅ Priorities: \(priorities.count), Attendance: \(attendance.count)")
            
            return fileURL
        } catch {
            print("❌ Failed to write export file: \(error)")
            return nil
        }
    }
    
    // MARK: - Import Functionality
    
    /// Validates and parses an imported preference file
    /// - Parameter url: URL of the imported file
    /// - Returns: SharedPreferenceSet if valid, nil otherwise
    func validateImportedFile(at url: URL) -> SharedPreferenceSet? {
        guard url.pathExtension == fileExtension else {
            print("❌ Invalid file extension: \(url.pathExtension)")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let preferenceSet = try JSONDecoder().decode(SharedPreferenceSet.self, from: data)
            print("✅ Valid preference file: \(preferenceSet.senderName) (UserID: \(preferenceSet.senderUserId))")
            return preferenceSet
        } catch {
            print("❌ Failed to decode preference file: \(error)")
            return nil
        }
    }
    
    /// Imports and saves a shared preference set with a custom name
    /// - Parameters:
    ///   - preferenceSet: The preference set to import
    ///   - customName: Custom display name for this import (can be changed later)
    /// - Returns: true if successful, false otherwise
    func importPreferenceSet(_ preferenceSet: SharedPreferenceSet, withName customName: String) -> Bool {
        // Use senderUserId as the immutable profile key
        let profileKey = preferenceSet.senderUserId
        
        print("📥 [IMPORT] ========================================")
        print("📥 [IMPORT] Starting import for profile")
        print("📥 [IMPORT] UserID (key): \(profileKey)")
        print("📥 [IMPORT] Name (label): \(customName)")
        print("📥 [IMPORT] Priorities: \(preferenceSet.priorities.count), Attendance: \(preferenceSet.attendance.count)")
        print("📥 [IMPORT] CURRENT active profile BEFORE import: '\(getActivePreferenceSource())'")
        print("📥 [IMPORT] ========================================")
        
        // Check if this UserID already exists - if so, this is an update
        let existingProfile = profileManager.getProfile(userId: profileKey)
        let isUpdate = existingProfile != nil
        
        if isUpdate {
            print("📥 [IMPORT] Updating existing profile from this sender")
        } else {
            print("📥 [IMPORT] Creating new profile from this sender")
        }
        
        // Import priorities into SQLite with UserID as profile key
        priorityManager.importPriorities(
            for: profileKey,
            priorities: preferenceSet.priorities,
            eventYear: preferenceSet.eventYear
        )
        
        // Convert attendance dictionary to array format for SQLiteAttendanceManager
        var attendanceArray: [[String: Any]] = []
        for (index, status) in preferenceSet.attendance {
            // Parse index: "BandName:Location:StartTime:EventType:Year"
            let components = index.split(separator: ":").map(String.init)
            guard components.count >= 5 else { continue }
            
            let bandNameStr = components[0]
            let yearInt = Int(components[4]) ?? preferenceSet.eventYear
            
            attendanceArray.append([
                "bandName": bandNameStr,
                "status": status,
                "timeIndex": 0.0,  // Will be looked up from events if needed
                "eventYear": yearInt,
                "index": index
            ])
        }
        
        // Import attendance into SQLite with UserID as profile key
        SQLiteAttendanceManager.shared.importAttendance(
            for: profileKey,
            attendanceData: attendanceArray
        )
        
        // Get or assign color
        let colorHex = ProfileColorManager.shared.getHexString(
            for: ProfileColorManager.shared.getColor(for: profileKey)
        )
        
        // Create/update profile metadata in SQLite
        let profile = ProfileMetadata(
            userId: profileKey,
            label: customName,
            color: colorHex,
            importDate: Date(),
            shareDate: preferenceSet.shareDate,
            eventYear: Int64(preferenceSet.eventYear),
            priorityCount: preferenceSet.priorities.count,
            attendanceCount: preferenceSet.attendance.count,
            isReadOnly: false  // Imported profiles are editable - changes save until re-import
        )
        
        // Save to SQLite (will update if exists)
        _ = profileManager.saveProfile(profile)
        
        print("✅ [IMPORT] Imported preference set: \(customName) (UserID: \(profileKey))")
        
        // VERIFICATION: Check that data was actually saved
        print("🔍 [IMPORT_VERIFY] ===== VERIFYING IMPORTED DATA =====")
        let verifyPriorities = priorityManager.getAllPriorities(eventYear: preferenceSet.eventYear, profileName: profileKey)
        let verifyAttendance = SQLiteAttendanceManager.shared.getAllAttendanceDataByIndex(profileName: profileKey)
        print("🔍 [IMPORT_VERIFY] Profile '\(profileKey)' now has:")
        print("   - \(verifyPriorities.count) priorities (expected: \(preferenceSet.priorities.count))")
        print("   - \(verifyAttendance.count) attendance records (expected: \(preferenceSet.attendance.count))")
        if verifyPriorities.count != preferenceSet.priorities.count {
            print("⚠️ [IMPORT_VERIFY] WARNING: Priority count mismatch!")
        }
        if verifyAttendance.count != preferenceSet.attendance.count {
            print("⚠️ [IMPORT_VERIFY] WARNING: Attendance count mismatch!")
        }
        print("🔍 [IMPORT_VERIFY] ===== VERIFICATION COMPLETE =====")
        
        return true
    }
    
    // MARK: - Preference Source Management
    
    /// Gets the currently active preference source
    /// - Returns: "Default" for user's own, or the name of a shared set
    func getActivePreferenceSource() -> String {
        let source = UserDefaults.standard.string(forKey: activeSourceKey) ?? "Default"
        return source
    }
    
    /// Sets the active preference source
    /// - Parameter sourceName: "Default" for user's own, or name of imported set
    func setActivePreferenceSource(_ sourceName: String) {
        let oldSource = getActivePreferenceSource()
        
        print("🔄 [PROFILE_SWITCH] ========================================")
        print("🔄 [PROFILE_SWITCH] SWITCHING PROFILE")
        print("🔄 [PROFILE_SWITCH] FROM: '\(oldSource)'")
        print("🔄 [PROFILE_SWITCH] TO:   '\(sourceName)'")
        print("🔄 [PROFILE_SWITCH] ========================================")
        
        // CRITICAL: Set flag to block iCloud operations during profile switch
        UserDefaults.standard.set(true, forKey: "ProfileSwitchInProgress")
        print("🚫 [PROFILE_SWITCH] iCloud operations BLOCKED during profile switch")
        
        // Check data BEFORE switch
        let oldPriorities = priorityManager.getAllPriorities(eventYear: eventYear, profileName: oldSource)
        let oldAttendance = SQLiteAttendanceManager.shared.getAllAttendanceDataByIndex(profileName: oldSource)
        print("🔄 [PROFILE_SWITCH] OLD profile '\(oldSource)' has:")
        print("   - \(oldPriorities.count) priorities")
        print("   - \(oldAttendance.count) attendance records")
        
        // Check data for NEW profile BEFORE switch
        let newPrioritiesBefore = priorityManager.getAllPriorities(eventYear: eventYear, profileName: sourceName)
        let newAttendanceBefore = SQLiteAttendanceManager.shared.getAllAttendanceDataByIndex(profileName: sourceName)
        print("🔄 [PROFILE_SWITCH] NEW profile '\(sourceName)' has BEFORE switch:")
        print("   - \(newPrioritiesBefore.count) priorities")
        print("   - \(newAttendanceBefore.count) attendance records")
        
        UserDefaults.standard.set(sourceName, forKey: activeSourceKey)
        UserDefaults.standard.synchronize()
        
        // Verify it was saved
        let verified = UserDefaults.standard.string(forKey: activeSourceKey) ?? "Default"
        print("✅ [PROFILE_SWITCH] Active preference source changed: '\(oldSource)' → '\(sourceName)', verified: '\(verified)'")
        
        // Post multiple notifications to ensure UI updates everywhere
        DispatchQueue.main.async {
            // Main refresh notification
            NotificationCenter.default.post(name: Notification.Name("PreferenceSourceChanged"), object: sourceName)
            
            // Force GUI refresh (used by MasterViewController) - just reloads table view
            NotificationCenter.default.post(name: Notification.Name("refreshGUI"), object: nil)
            
            // Additional refresh for specific UI elements
            NotificationCenter.default.post(name: Notification.Name("ReloadBandList"), object: nil)
            
            // CRITICAL: Clear the profile switch flag after a longer delay (5 seconds)
            // This ensures ALL queued operations complete before iCloud is re-enabled
            // We need to block iCloud for the entire duration of the profile switch + UI refresh
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                UserDefaults.standard.set(false, forKey: "ProfileSwitchInProgress")
                print("✅ [PROFILE_SWITCH] iCloud operations UNBLOCKED after profile switch complete (5s delay)")
            }
        }
    }
    
    /// Gets list of all available preference sources (user's own + imported)
    /// - Returns: Array of profile keys (UserIDs for shared, "Default" for own)
    func getAvailablePreferenceSources() -> [String] {
        print("📋 [SOURCES_DEBUG] === Getting available preference sources ===")
        
        // Get all profiles from SQLite profile table
        let profiles = profileManager.getAllProfiles()
        let profileUserIds = profiles.map { $0.userId }
        
        print("📋 [SOURCES_DEBUG] Found \(profiles.count) profiles in SQLite profile table")
        
        // Get profiles from data tables for sync check
        let priorityProfiles = Set(priorityManager.getAllProfileNames())
        let attendanceProfiles = Set(SQLiteAttendanceManager.shared.getAllProfileNames())
        let allDataProfileKeys = priorityProfiles.union(attendanceProfiles)
        
        print("📋 [SOURCES_DEBUG] Priority profiles in data tables: \(priorityProfiles)")
        print("📋 [SOURCES_DEBUG] Attendance profiles in data tables: \(attendanceProfiles)")
        
        // CRITICAL FIX: Sync profile table with data tables - if we have data but no profile entry, recreate
        for profileKey in allDataProfileKeys {
            if !profileUserIds.contains(profileKey) {
                print("⚠️ [SOURCES_DEBUG] ORPHANED DATA FOUND: \(profileKey) exists in data tables but not in profile table!")
                print("⚠️ [SOURCES_DEBUG] Creating placeholder profile to restore visibility")
                
                // Create placeholder profile
                let colorHex = ProfileColorManager.shared.getHexString(
                    for: ProfileColorManager.shared.getColor(for: profileKey)
                )
                
                let placeholderProfile = ProfileMetadata(
                    userId: profileKey,
                    label: profileKey == "Default" ? "Default" : "Recovered: \(profileKey.prefix(8))...",
                    color: colorHex,
                    importDate: Date(),
                    shareDate: Date(),
                    eventYear: Int64(eventYear),
                    priorityCount: 0,
                    attendanceCount: 0,
                    isReadOnly: profileKey != "Default"
                )
                
                _ = profileManager.saveProfile(placeholderProfile)
                print("✅ [SOURCES_DEBUG] Created placeholder profile for: \(profileKey)")
            }
        }
        
        // Return all profile userIds (already sorted with Default first)
        let finalProfiles = profileManager.getAllProfiles()
        let sources = finalProfiles.map { $0.userId }
        
        print("📋 [SOURCES_DEBUG] Final available sources: \(sources)")
        print("📋 [SOURCES_DEBUG] === End getting sources ===")
        return sources
    }
    
    /// Gets the display name for a profile key
    /// - Parameter profileKey: The profile key (UserID or "Default")
    /// - Returns: The display name
    func getDisplayName(for profileKey: String) -> String {
        if let profile = profileManager.getProfile(userId: profileKey) {
            return profile.label
        }
        
        // Fallback to the key itself
        return profileKey
    }
    
    /// Gets the profile key (UserID) for a display name
    /// - Parameter displayName: The display name
    /// - Returns: The profile key (UserID or "Default")
    func getProfileKey(for displayName: String) -> String? {
        if displayName == "Default" {
            return "Default"
        }
        
        // Look up the UserID from profile table
        let profiles = profileManager.getAllProfiles()
        return profiles.first(where: { $0.label == displayName })?.userId
    }
    
    /// Checks if a profile is read-only (cannot be edited)
    /// - Parameter profileKey: The profile key (UserID or "Default")
    /// - Returns: true if read-only, false if editable
    func isReadOnly(profileKey: String) -> Bool {
        return profileManager.isReadOnly(userId: profileKey)
    }
    
    // MARK: - Priority Access (respects active source)
    
    /// Gets priority for a band from the active preference source
    /// - Parameter bandName: Name of the band
    /// - Returns: Priority level (0-3)
    func getPriorityFromActiveSource(for bandName: String) -> Int {
        let activeSource = getActivePreferenceSource()
        
        print("🔍 [PRIORITY_FETCH] Getting priority for '\(bandName)' from profile: '\(activeSource)'")
        
        // All data is now in SQLite with profileName field
        let priority = priorityManager.getPriority(for: bandName, eventYear: eventYear, profileName: activeSource)
        print("🔍 [PRIORITY_FETCH] Profile '\(activeSource)' returned priority: \(priority)")
        return priority
    }
    
    /// Gets all priorities from the active preference source
    /// - Returns: Dictionary of band name to priority level
    func getAllPrioritiesFromActiveSource() -> [String: Int] {
        let activeSource = getActivePreferenceSource()
        print("🔍 [DATA_DEBUG] getAllPrioritiesFromActiveSource() for profile: '\(activeSource)'")
        
        print("🔍 [PRIORITIES_FETCH_ALL] Getting all priorities from profile: '\(activeSource)'")
        
        // All data is now in SQLite with profileName field
        let priorities = priorityManager.getAllPriorities(eventYear: eventYear, profileName: activeSource)
        print("🔍 [PRIORITIES_FETCH_ALL] Profile '\(activeSource)' returned \(priorities.count) priorities")
        return priorities
    }
    
    // MARK: - Attendance Access (respects active source)
    
    /// Gets attendance status for an event from the active preference source
    /// - Parameter index: Event index string
    /// - Returns: Attendance status
    func getAttendanceFromActiveSource(for index: String) -> Int {
        let activeSource = getActivePreferenceSource()
        
        print("🔍 [ATTENDANCE_FETCH] Getting attendance for index '\(index)' from profile: '\(activeSource)'")
        
        // All data is now in SQLite with profileName field
        let status = SQLiteAttendanceManager.shared.getAttendanceStatusByIndex(index: index, profileName: activeSource)
        print("🔍 [ATTENDANCE_FETCH] Profile '\(activeSource)' returned status: \(status)")
        return status
    }
    
    // MARK: - Profile Management
    
    /// Renames the display label for a shared profile (does not change the underlying UserID key)
    /// - Parameters:
    ///   - userId: The sender's UserID (immutable profile key)
    ///   - newName: The new display name
    /// - Returns: true if successful
    func renameProfile(userId: String, newName: String) -> Bool {
        print("✏️ [RENAME] Renaming profile \(userId) to: \(newName)")
        
        return profileManager.updateLabel(userId: userId, newLabel: newName)
    }
    
    /// Deletes an imported preference set by UserID
    /// - Parameter userId: The sender's UserID
    /// - Returns: true if successful
    func deleteImportedSet(byUserId userId: String) -> Bool {
        print("🗑️ [DELETE] Deleting profile with UserID: \(userId)")
        
        // Cannot delete "Default"
        guard userId != "Default" else {
            print("❌ [DELETE] Cannot delete 'Default'")
            return false
        }
        
        // Delete from SQLite (priorities and attendance) using UserID as profile key
        var success = true
        
        priorityManager.deleteProfile(named: userId) { result in
            if !result {
                print("❌ [DELETE] Failed to delete priorities for: \(userId)")
                success = false
            }
        }
        
        SQLiteAttendanceManager.shared.deleteProfile(named: userId) { result in
            if !result {
                print("❌ [DELETE] Failed to delete attendance for: \(userId)")
                success = false
            }
        }
        
        // Delete from profile table
        if !profileManager.deleteProfile(userId: userId) {
            print("❌ [DELETE] Failed to delete profile metadata")
            success = false
        }
        
        // Remove color assignment
        ProfileColorManager.shared.removeColor(for: userId)
        
        // If this was the active source, switch back to Default
        if getActivePreferenceSource() == userId {
            setActivePreferenceSource("Default")
        }
        
        print("✅ [DELETE] Deleted profile with UserID: \(userId)")
        return success
    }
    
    // MARK: - Private Helpers
    
    private func savePreferenceSetToDocuments(_ preferenceSet: SharedPreferenceSet) -> URL? {
        guard let data = try? JSONEncoder().encode(preferenceSet) else {
            return nil
        }
        
        let fileName = "\(preferenceSet.senderName.replacingOccurrences(of: " ", with: "_"))_\(preferenceSet.eventYear).json"
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDir.appendingPathComponent("SharedPreferences").appendingPathComponent(fileName)
        
        // Create directory if needed
        let dirURL = fileURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("❌ Failed to save preference set: \(error)")
            return nil
        }
    }
    
    private func loadPreferenceSet(withName name: String) -> SharedPreferenceSet? {
        guard let fileURL = getPreferenceSetFileURL(forName: name) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(SharedPreferenceSet.self, from: data)
        } catch {
            print("❌ Failed to load preference set '\(name)': \(error)")
            return nil
        }
    }
    
    private func getPreferenceSetFileURL(forName name: String) -> URL? {
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let sharedPrefDir = documentsDir.appendingPathComponent("SharedPreferences")
        
        // Try to find file with this name
        guard let files = try? fileManager.contentsOfDirectory(at: sharedPrefDir, includingPropertiesForKeys: nil) else {
            return nil
        }
        
        for file in files {
            if file.lastPathComponent.starts(with: name.replacingOccurrences(of: " ", with: "_")) {
                return file
            }
        }
        
        return nil
    }
    
    private func isNameAlreadyUsed(_ name: String) -> Bool {
        if name == "Default" {
            return true
        }
        
        let profiles = profileManager.getAllProfiles()
        return profiles.contains { $0.label == name }
    }
    
    /// Diagnostic function to check profile storage integrity
    func diagnoseProfileStorage() {
        print("🔍 [DIAGNOSTIC] === Profile Storage Diagnostic ===")
        
        // Check SQLite data tables
        let priorityProfiles = priorityManager.getAllProfileNames()
        let attendanceProfiles = SQLiteAttendanceManager.shared.getAllProfileNames()
        
        print("🔍 [DIAGNOSTIC] SQLite Priority Data (\(priorityProfiles.count) profiles):")
        for profile in priorityProfiles {
            let count = priorityManager.getPriorityCount(profileName: profile)
            print("  - \(profile): \(count) priorities")
        }
        
        print("🔍 [DIAGNOSTIC] SQLite Attendance Data (\(attendanceProfiles.count) profiles):")
        for profile in attendanceProfiles {
            let count = SQLiteAttendanceManager.shared.getAttendanceCount(profileName: profile)
            print("  - \(profile): \(count) attendances")
        }
        
        // Check profile metadata table
        let profiles = profileManager.getAllProfiles()
        print("🔍 [DIAGNOSTIC] SQLite Profile Metadata (\(profiles.count) profiles):")
        for profile in profiles {
            print("  - \(profile.label) (UserID: \(profile.userId))")
            print("    Color: \(profile.color), ReadOnly: \(profile.isReadOnly)")
            print("    Imported: \(profile.importDate), Priorities: \(profile.priorityCount), Attendance: \(profile.attendanceCount)")
        }
        
        // Check active source
        let activeSource = getActivePreferenceSource()
        let activeProfile = profileManager.getProfile(userId: activeSource)
        print("🔍 [DIAGNOSTIC] Active Source: \(activeSource)")
        if let active = activeProfile {
            print("🔍 [DIAGNOSTIC] Active Profile: \(active.label) (ReadOnly: \(active.isReadOnly))")
        }
        
        print("🔍 [DIAGNOSTIC] === End Diagnostic ===")
    }
}


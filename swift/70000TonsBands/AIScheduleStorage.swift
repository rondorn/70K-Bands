//
//  AIScheduleStorage.swift
//  70000TonsBands
//
//  Persists "has run AI schedule" per year and backup of attendance for restore.
//

import Foundation

/// Storage for AI schedule: "has run" flag per year and attendance backup for restore.
enum AIScheduleStorage {
    private static let hasRunPrefix = "AIScheduleHasRun_"
    private static let backupFileNamePrefix = "AIScheduleBackup_"
    
    static func hasRunAI(for year: Int) -> Bool {
        UserDefaults.standard.bool(forKey: hasRunPrefix + String(year))
    }
    
    static func setHasRunAI(for year: Int, value: Bool) {
        UserDefaults.standard.set(value, forKey: hasRunPrefix + String(year))
    }
    
    private static func backupFileURL(for year: Int) -> URL {
        FilePaths.directoryPath.appendingPathComponent(backupFileNamePrefix + String(year) + ".json")
    }
    
    /// Save attendance state for the given year (only keys ending with ":year").
    /// Call before applying AI schedule so we can restore later.
    static func saveBackup(attended: [String: String], year: Int) {
        let suffix = ":" + String(year)
        let filtered = attended.filter { $0.key.hasSuffix(suffix) }
        guard !filtered.isEmpty else { return }
        do {
            let data = try JSONSerialization.data(withJSONObject: filtered)
            try data.write(to: backupFileURL(for: year))
        } catch {
            print("AIScheduleStorage: Failed to save backup for year \(year): \(error)")
        }
    }

    /// Saves year slice for wizard rollback (may be empty `{}`). Always writes a file so cancel-after-clear can restore.
    static func saveWizardRollbackBackup(attended: [String: String], year: Int) {
        let suffix = ":" + String(year)
        let filtered = attended.filter { $0.key.hasSuffix(suffix) }
        do {
            let data = try JSONSerialization.data(withJSONObject: filtered)
            try data.write(to: backupFileURL(for: year))
        } catch {
            print("AIScheduleStorage: Failed to save wizard rollback backup for year \(year): \(error)")
        }
    }

    /// Restores attendance from the wizard pre-build snapshot and removes the backup file. Does not change hasRunAI.
    static func restoreWizardCancelled(attendedHandle: ShowsAttended, year: Int) {
        guard let backup = loadBackup(year: year) else { return }
        let yearStr = String(year)
        let current = attendedHandle.getShowsAttended()
        for (index, status) in backup {
            attendedHandle.changeShowAttendedStatus(index: index, status: status, skipICloud: false)
        }
        for (index, _) in current where index.hasSuffix(":" + yearStr) && backup[index] == nil {
            attendedHandle.changeShowAttendedStatus(index: index, status: sawNoneStatus, skipICloud: false)
        }
        clearBackup(year: year)
    }
    
    /// Load backup for year, or nil if none.
    static func loadBackup(year: Int) -> [String: String]? {
        let url = backupFileURL(for: year)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return nil
        }
        return dict
    }
    
    static func clearBackup(year: Int) {
        try? FileManager.default.removeItem(at: backupFileURL(for: year))
    }
    
    /// Restore attendance to pre-AI state for the year. Uses backup; then clears backup and sets hasRunAI to false.
    /// - Returns: true if restore was performed, false if no backup.
    static func restore(attendedHandle: ShowsAttended, year: Int) -> Bool {
        guard let backup = loadBackup(year: year) else { return false }
        let yearStr = String(year)
        let current = attendedHandle.getShowsAttended()
        for (index, status) in backup {
            attendedHandle.changeShowAttendedStatus(index: index, status: status, skipICloud: false)
        }
        for (index, _) in current where index.hasSuffix(":" + yearStr) && backup[index] == nil {
            attendedHandle.changeShowAttendedStatus(index: index, status: sawNoneStatus, skipICloud: false)
        }
        clearBackup(year: year)
        setHasRunAI(for: year, value: false)
        return true
    }
}

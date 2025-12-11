//
//  CoreDataToSQLiteMigrationHelper.swift
//  70000 Tons Bands
//
//  One-time migration from Core Data to SQLite
//  Ensures user data is not lost during the transition
//

import Foundation
import CoreData

/// Handles one-time migration from Core Data to SQLite
class CoreDataToSQLiteMigrationHelper {
    
    static let shared = CoreDataToSQLiteMigrationHelper()
    
    private let migrationKey = "CoreDataToSQLiteMigrationCompleted_v2"
    
    private init() {}
    
    /// Checks if migration has already been completed
    func isMigrationCompleted() -> Bool {
        return UserDefaults.standard.bool(forKey: migrationKey)
    }
    
    /// Marks migration as completed
    func markMigrationCompleted() {
        UserDefaults.standard.set(true, forKey: migrationKey)
        print("✅ Migration marked as completed")
    }
    
    /// Performs the one-time migration from Core Data to SQLite
    /// This should be called early in app launch
    func performMigrationIfNeeded() {
        // Check if migration already completed
        guard !isMigrationCompleted() else {
            print("✅ Migration already completed, skipping")
            return
        }
        
        print("🔄 Starting Core Data to SQLite migration...")
        
        // Migrate priorities
        migratePriorities()
        
        // Migrate attendance records
        migrateAttendance()
        
        // Mark migration as complete
        markMigrationCompleted()
        
        print("✅ Core Data to SQLite migration completed successfully")
    }
    
    /// Migrates priority data from Core Data to SQLite
    private func migratePriorities() {
        print("🔄 Migrating priorities from Core Data to SQLite...")
        
        // Try to get data from old Core Data PriorityManager
        do {
            let coreDataManager = CoreDataManager.shared
            let context = coreDataManager.viewContext
            
            let request: NSFetchRequest<UserPriority> = UserPriority.fetchRequest()
            let priorities = try context.fetch(request)
            
            print("📊 Found \(priorities.count) priorities in Core Data")
            
            let sqlitePriorityManager = SQLitePriorityManager.shared
            var migratedCount = 0
            
            for priority in priorities {
                guard let bandName = priority.bandName else { continue }
                
                let priorityValue = Int(priority.priorityLevel)
                let timestamp = priority.updatedAt?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
                
                // Use a semaphore to wait for async operation
                let semaphore = DispatchSemaphore(value: 0)
                
                sqlitePriorityManager.setPriority(
                    for: bandName,
                    priority: priorityValue,
                    timestamp: timestamp
                ) { success in
                    if success {
                        migratedCount += 1
                    }
                    semaphore.signal()
                }
                
                semaphore.wait()
            }
            
            print("✅ Migrated \(migratedCount) priorities to SQLite")
            
        } catch {
            print("⚠️ Failed to migrate priorities from Core Data: \(error)")
            print("⚠️ This is OK if Core Data was never used or is empty")
        }
    }
    
    /// Migrates attendance data from Core Data to SQLite
    private func migrateAttendance() {
        print("🔄 Migrating attendance from Core Data to SQLite...")
        
        do {
            let coreDataManager = CoreDataManager.shared
            let context = coreDataManager.viewContext
            
            let request: NSFetchRequest<UserAttendance> = UserAttendance.fetchRequest()
            let attendances = try context.fetch(request)
            
            print("📊 Found \(attendances.count) attendance records in Core Data")
            
            let sqliteAttendanceManager = SQLiteAttendanceManager.shared
            var migratedCount = 0
            
            for attendance in attendances {
                guard let index = attendance.index else { continue }
                
                let statusValue = Int(attendance.attendanceStatus)
                let timestamp = attendance.updatedAt?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
                
                sqliteAttendanceManager.setAttendanceStatusByIndex(
                    index: index,
                    status: statusValue,
                    timestamp: timestamp
                )
                
                migratedCount += 1
            }
            
            print("✅ Migrated \(migratedCount) attendance records to SQLite")
            
        } catch {
            print("⚠️ Failed to migrate attendance from Core Data: \(error)")
            print("⚠️ This is OK if Core Data was never used or is empty")
        }
    }
    
    /// Force re-migration (for testing or data recovery)
    func forceMigration() {
        UserDefaults.standard.set(false, forKey: migrationKey)
        performMigrationIfNeeded()
    }
}




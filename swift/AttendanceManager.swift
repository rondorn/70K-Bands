import Foundation
import CoreData

/// Manages event attendance using Core Data
/// Replaces the legacy ShowsAttended dictionary system with database storage
class AttendanceManager {
    private let coreDataManager: CoreDataManager
    
    init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        self.coreDataManager = coreDataManager
    }
    
    // MARK: - Attendance Management
    
    /// Sets attendance status for an event (replaces ShowsAttended.setShowAttendedStatus)
    /// - Parameters:
    ///   - bandName: Name of the band
    ///   - location: Event location
    ///   - startTime: Event start time
    ///   - eventType: Type of event
    ///   - eventYear: Year of the event
    ///   - status: Attendance status (0=Unknown, 1=Will Attend, 2=Attended, 3=Won't Attend)
    func setAttendanceStatus(
        bandName: String,
        location: String,
        startTime: String,
        eventType: String,
        eventYear: String,
        status: Int
    ) {
        print("🎪 Setting attendance for \(bandName) at \(location): \(status)")
        
        // Find the event
        guard let event = findEvent(bandName: bandName, location: location, startTime: startTime, eventType: eventType) else {
            print("❌ Could not find event for attendance update")
            return
        }
        
        // Get or create the attendance record
        let userAttendance = getUserAttendance(for: event) ?? createUserAttendance(for: event)
        
        // Update the attendance
        userAttendance.attendanceStatus = Int16(status)
        userAttendance.eventYear = Int32(eventYear) ?? Int32(eventYear)
        userAttendance.updatedAt = Date()
        
        // Save to Core Data
        coreDataManager.saveContext()
        
        print("✅ Attendance saved for \(bandName): \(status)")
    }
    
    /// Gets attendance status for an event (replaces ShowsAttended.getShowAttendedStatus)
    /// - Parameters:
    ///   - bandName: Name of the band
    ///   - location: Event location
    ///   - startTime: Event start time
    ///   - eventType: Type of event
    ///   - eventYear: Year of the event
    /// - Returns: Attendance status (0 if not found)
    func getAttendanceStatus(
        bandName: String,
        location: String,
        startTime: String,
        eventType: String,
        eventYear: String
    ) -> Int {
        guard let event = findEvent(bandName: bandName, location: location, startTime: startTime, eventType: eventType),
              let userAttendance = getUserAttendance(for: event) else {
            return 0
        }
        
        return Int(userAttendance.attendanceStatus)
    }
    
    /// Gets all attendance records (replaces ShowsAttended.getAllAttendanceData)
    /// - Returns: Dictionary of attendance data
    func getAllAttendanceData() -> [String: [String: Any]] {
        let request: NSFetchRequest<UserAttendance> = UserAttendance.fetchRequest()
        
        do {
            let attendances = try coreDataManager.context.fetch(request)
            var result: [String: [String: Any]] = [:]
            
            for attendance in attendances {
                guard let event = attendance.event,
                      let bandName = event.band?.bandName else { continue }
                
                let key = createAttendanceKey(
                    bandName: bandName,
                    location: event.location ?? "",
                    startTime: event.startTime ?? "",
                    eventType: event.eventType ?? ""
                )
                
                result[key] = [
                    "status": Int(attendance.attendanceStatus),
                    "eventYear": Int(attendance.eventYear),
                    "lastModified": attendance.updatedAt?.timeIntervalSince1970 ?? 0
                ]
            }
            
            print("📊 Loaded \(result.count) attendance records from database")
            return result
        } catch {
            print("❌ Error fetching attendance data: \(error)")
            return [:]
        }
    }
    
    /// Gets events filtered by attendance status
    /// - Parameter statuses: Array of attendance statuses to include
    /// - Returns: Array of events matching the attendance criteria
    func getEventsWithAttendanceStatus(_ statuses: [Int]) -> [Event] {
        let request: NSFetchRequest<UserAttendance> = UserAttendance.fetchRequest()
        let statusPredicates = statuses.map { NSPredicate(format: "attendanceStatus == %d", $0) }
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: statusPredicates)
        
        do {
            let attendances = try coreDataManager.context.fetch(request)
            return attendances.compactMap { $0.event }
        } catch {
            print("❌ Error fetching events with attendance status \(statuses): \(error)")
            return []
        }
    }
    
    /// Gets attended events for a band
    /// - Parameter bandName: Name of the band
    /// - Returns: Array of events the user attended
    func getAttendedEvents(for bandName: String) -> [Event] {
        let request: NSFetchRequest<UserAttendance> = UserAttendance.fetchRequest()
        request.predicate = NSPredicate(format: "event.band.bandName == %@ AND attendanceStatus == %d", bandName, 2) // 2 = Attended
        
        do {
            let attendances = try coreDataManager.context.fetch(request)
            return attendances.compactMap { $0.event }
        } catch {
            print("❌ Error fetching attended events for \(bandName): \(error)")
            return []
        }
    }
    
    // MARK: - Migration Support
    
    /// Migrates existing attendance data from the old system to Core Data
    /// - Parameter oldAttendanceData: Dictionary from the old ShowsAttended system
    func migrateExistingAttendance(from oldAttendanceData: [String: [String: Any]]) {
        print("🔄 Starting attendance migration for \(oldAttendanceData.count) records...")
        
        var migratedCount = 0
        var skippedCount = 0
        
        for (key, data) in oldAttendanceData {
            // Parse the old key format
            let components = parseAttendanceKey(key)
            guard let bandName = components["bandName"],
                  let location = components["location"],
                  let startTime = components["startTime"],
                  let eventType = components["eventType"] else {
                print("⏭️ Skipping invalid key: \(key)")
                skippedCount += 1
                continue
            }
            
            // Extract status and year
            guard let status = data["status"] as? Int,
                  let eventYear = data["eventYear"] as? Int else {
                print("⏭️ Skipping invalid data for key: \(key)")
                skippedCount += 1
                continue
            }
            
            // Skip if attendance already exists in database
            let existingStatus = getAttendanceStatus(
                bandName: bandName,
                location: location,
                startTime: startTime,
                eventType: eventType,
                eventYear: String(eventYear)
            )
            
            if existingStatus != 0 {
                print("⏭️ Skipping \(bandName) - already has attendance in database")
                skippedCount += 1
                continue
            }
            
            // Migrate the attendance
            setAttendanceStatus(
                bandName: bandName,
                location: location,
                startTime: startTime,
                eventType: eventType,
                eventYear: String(eventYear),
                status: status
            )
            
            migratedCount += 1
            print("✅ Migrated attendance: \(bandName) at \(location) - status \(status)")
        }
        
        print("🎉 Attendance migration complete!")
        print("📊 Migrated: \(migratedCount), Skipped: \(skippedCount)")
    }
    
    /// Clears all attendance data (replaces ShowsAttended.clearAllData)
    func clearAllAttendance() {
        let request: NSFetchRequest<NSFetchRequestResult> = UserAttendance.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try coreDataManager.context.execute(deleteRequest)
            coreDataManager.saveContext()
            print("🗑️ Cleared all attendance data")
        } catch {
            print("❌ Error clearing attendance data: \(error)")
        }
    }
    
    // MARK: - Private Helpers
    
    private func getUserAttendance(for event: Event) -> UserAttendance? {
        let request: NSFetchRequest<UserAttendance> = UserAttendance.fetchRequest()
        request.predicate = NSPredicate(format: "event == %@", event)
        request.fetchLimit = 1
        
        do {
            return try coreDataManager.context.fetch(request).first
        } catch {
            print("❌ Error fetching user attendance: \(error)")
            return nil
        }
    }
    
    private func createUserAttendance(for event: Event) -> UserAttendance {
        let userAttendance = UserAttendance(context: coreDataManager.context)
        userAttendance.event = event
        userAttendance.attendanceStatus = 0
        userAttendance.eventYear = event.eventYear
        userAttendance.createdAt = Date()
        userAttendance.updatedAt = Date()
        return userAttendance
    }
    
    private func findEvent(bandName: String, location: String, startTime: String, eventType: String) -> Event? {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(
            format: "band.bandName == %@ AND location == %@ AND startTime == %@ AND eventType == %@",
            bandName, location, startTime, eventType
        )
        request.fetchLimit = 1
        
        do {
            return try coreDataManager.context.fetch(request).first
        } catch {
            print("❌ Error finding event: \(error)")
            return nil
        }
    }
    
    private func createAttendanceKey(bandName: String, location: String, startTime: String, eventType: String) -> String {
        return "\(bandName)|\(location)|\(startTime)|\(eventType)"
    }
    
    private func parseAttendanceKey(_ key: String) -> [String: String] {
        let components = key.split(separator: "|")
        guard components.count >= 4 else { return [:] }
        
        return [
            "bandName": String(components[0]),
            "location": String(components[1]),
            "startTime": String(components[2]),
            "eventType": String(components[3])
        ]
    }
}

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
        userAttendance.eventYear = Int32(eventYear) ?? Int32(eventYear)!
        userAttendance.updatedAt = Date()
        
        // CRITICAL: Ensure index is set for iCloud restoration
        if userAttendance.index == nil {
            userAttendance.index = createAttendanceIndex(
                bandName: bandName,
                location: location,
                startTime: startTime,
                eventType: eventType,
                eventYear: Int(eventYear) ?? 0
            )
        }
        
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
    
    // MARK: - Index-Based Attendance Management (for iCloud Restoration)
    
    /// Sets attendance status using index-based lookup (for iCloud restoration)
    /// This method can restore attendance data even when events don't exist yet
    /// - Parameters:
    ///   - index: The attendance index (format: "bandName:location:startTime:eventType:eventYear")
    ///   - status: Attendance status (0=Unknown, 1=Will Attend, 2=Attended, 3=Won't Attend)
    ///   - timestamp: Optional timestamp for the change
    func setAttendanceStatusByIndex(index: String, status: Int, timestamp: Double? = nil) {
        print("🎪 Setting attendance by index: \(index) -> \(status)")
        
        // Parse the index to get event details
        let eventDetails = parseAttendanceIndex(index)
        guard let bandName = eventDetails["bandName"],
              let location = eventDetails["location"],
              let startTime = eventDetails["startTime"],
              let eventType = eventDetails["eventType"],
              let eventYearString = eventDetails["eventYear"],
              let eventYear = Int32(eventYearString) else {
            print("❌ Invalid attendance index format: \(index)")
            return
        }
        
        // Try to find existing attendance record by index
        let existingAttendance = getUserAttendanceByIndex(index: index)
        
        if let attendance = existingAttendance {
            // Update existing record
            attendance.attendanceStatus = Int16(status)
            attendance.eventYear = eventYear
            attendance.updatedAt = timestamp != nil ? Date(timeIntervalSince1970: timestamp!) : Date()
            print("✅ Updated existing attendance record for index: \(index)")
        } else {
            // Create new attendance record (event may not exist yet)
            let userAttendance = UserAttendance(context: coreDataManager.context)
            userAttendance.index = index
            userAttendance.attendanceStatus = Int16(status)
            userAttendance.eventYear = eventYear
            userAttendance.createdAt = timestamp != nil ? Date(timeIntervalSince1970: timestamp!) : Date()
            userAttendance.updatedAt = timestamp != nil ? Date(timeIntervalSince1970: timestamp!) : Date()
            
            // Try to find and link the event if it exists
            if let event = findEvent(bandName: bandName, location: location, startTime: startTime, eventType: eventType) {
                userAttendance.event = event
                print("✅ Created attendance record and linked to existing event for index: \(index)")
            } else {
                print("⚠️ Created attendance record without event link (event not found) for index: \(index)")
            }
        }
        
        // Save to Core Data
        coreDataManager.saveContext()
        print("✅ Attendance saved by index: \(index) -> \(status)")
    }
    
    /// Gets attendance status using index-based lookup
    /// - Parameter index: The attendance index
    /// - Returns: Attendance status (0 if not found)
    func getAttendanceStatusByIndex(index: String) -> Int {
        guard let attendance = getUserAttendanceByIndex(index: index) else {
            // Only log for specific bands we know have data
            if index.contains("Grave:") || index.contains("Destruction:") || index.contains("Hellbutcher:") {
                print("❌ [AttendanceManager] No attendance found for index: \(index)")
            }
            return 0
        }
        let status = Int(attendance.attendanceStatus)
        
        // Log found records for debugging
        if index.contains("Grave:") || index.contains("Destruction:") || index.contains("Hellbutcher:") || status != 0 {
            print("✅ [AttendanceManager] Found status \(status) for index: \(index)")
        }
        
        return status
    }
    
    /// Gets all attendance records by index (for iCloud sync)
    /// - Returns: Dictionary of index -> attendance data
    func getAllAttendanceDataByIndex() -> [String: [String: Any]] {
        let request: NSFetchRequest<UserAttendance> = UserAttendance.fetchRequest()
        request.predicate = NSPredicate(format: "index != nil")
        
        do {
            let attendances = try coreDataManager.context.fetch(request)
            var result: [String: [String: Any]] = [:]
            
            for attendance in attendances {
                guard let index = attendance.index else { continue }
                
                result[index] = [
                    "status": Int(attendance.attendanceStatus),
                    "eventYear": Int(attendance.eventYear),
                    "lastModified": attendance.updatedAt?.timeIntervalSince1970 ?? 0,
                    "hasEvent": attendance.event != nil
                ]
            }
            
            print("📊 Loaded \(result.count) attendance records by index from database")
            return result
        } catch {
            print("❌ Error fetching attendance data by index: \(error)")
            return [:]
        }
    }
    
    /// Ensures all existing attendance records have their index field populated
    /// This is critical for iCloud restoration to work properly
    func ensureAllAttendanceRecordsHaveIndex() {
        print("🔧 Ensuring all attendance records have index field populated...")
        
        let request: NSFetchRequest<UserAttendance> = UserAttendance.fetchRequest()
        request.predicate = NSPredicate(format: "index == nil")
        
        do {
            let attendancesWithoutIndex = try coreDataManager.context.fetch(request)
            var updatedCount = 0
            
            for attendance in attendancesWithoutIndex {
                guard let event = attendance.event else { continue }
                
                let index = createAttendanceIndex(
                    bandName: event.band?.bandName ?? "",
                    location: event.location ?? "",
                    startTime: event.startTime ?? "",
                    eventType: event.eventType ?? "",
                    eventYear: Int(event.eventYear)
                )
                
                attendance.index = index
                updatedCount += 1
                print("✅ Set index for attendance record: \(index)")
            }
            
            if updatedCount > 0 {
                coreDataManager.saveContext()
                print("🔧 Updated \(updatedCount) attendance records with index field")
            } else {
                print("🔧 All attendance records already have index field")
            }
        } catch {
            print("❌ Error ensuring attendance records have index: \(error)")
        }
    }
    
    /// Links existing attendance records to events when events become available
    /// This should be called after events are loaded/imported
    func linkAttendanceRecordsToEvents() {
        print("🔗 Linking attendance records to events...")
        
        let request: NSFetchRequest<UserAttendance> = UserAttendance.fetchRequest()
        request.predicate = NSPredicate(format: "event == nil AND index != nil")
        
        do {
            let unlinkedAttendances = try coreDataManager.context.fetch(request)
            var linkedCount = 0
            
            for attendance in unlinkedAttendances {
                guard let index = attendance.index else { continue }
                
                let eventDetails = parseAttendanceIndex(index)
                guard let bandName = eventDetails["bandName"],
                      let location = eventDetails["location"],
                      let startTime = eventDetails["startTime"],
                      let eventType = eventDetails["eventType"] else { continue }
                
                if let event = findEvent(bandName: bandName, location: location, startTime: startTime, eventType: eventType) {
                    attendance.event = event
                    linkedCount += 1
                    print("✅ Linked attendance record to event: \(bandName) at \(location)")
                }
            }
            
            if linkedCount > 0 {
                coreDataManager.saveContext()
                print("🔗 Linked \(linkedCount) attendance records to events")
            } else {
                print("🔗 No unlinked attendance records found")
            }
        } catch {
            print("❌ Error linking attendance records: \(error)")
        }
    }
    
    // MARK: - Testing and Verification
    
    /// Tests the attendance restoration system by simulating iCloud data
    /// This method helps verify that attendance data can be restored even when events don't exist
    func testAttendanceRestoration() {
        print("🧪 Testing attendance restoration system...")
        
        // Test 1: Create attendance record without event
        let testIndex = "TestBand:TestLocation:12:00 PM:Show:2025"
        let testStatus = 2 // Attended
        
        print("🧪 Test 1: Creating attendance record without event...")
        setAttendanceStatusByIndex(index: testIndex, status: testStatus)
        
        // Verify it was created
        let retrievedStatus = getAttendanceStatusByIndex(index: testIndex)
        if retrievedStatus == testStatus {
            print("✅ Test 1 PASSED: Attendance record created and retrieved by index")
        } else {
            print("❌ Test 1 FAILED: Expected \(testStatus), got \(retrievedStatus)")
        }
        
        // Test 2: Verify the record exists in database
        print("🧪 Test 2: Verifying record exists in database...")
        let allData = getAllAttendanceDataByIndex()
        if allData[testIndex] != nil {
            print("✅ Test 2 PASSED: Record found in database")
        } else {
            print("❌ Test 1 FAILED: Record not found in database")
        }
        
        // Test 3: Test linking when event becomes available
        print("🧪 Test 3: Testing event linking...")
        // This would require creating a test event, but for now we'll just test the linking logic
        linkAttendanceRecordsToEvents()
        
        print("🧪 Attendance restoration test completed")
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
    
    /// DEPRECATED: This method should NEVER be called - attendance data represents historical records
    /// Attendance data should be preserved as it represents what the user actually attended
    /// Even when changing years, historical attendance should be preserved
    @available(*, deprecated, message: "Attendance data should NEVER be cleared - it represents historical records")
    func clearAllAttendance() {
        print("🚨 CRITICAL ERROR: clearAllAttendance() called - this should NEVER happen!")
        print("🚨 Attendance data represents historical records of what user attended")
        print("🚨 This data should be preserved even when changing years")
        print("🚨 This method is deprecated and will be removed - attendance data should NEVER be deleted")
        
        // DO NOT DELETE ANYTHING - just log the error
        print("🛡️ PROTECTED: No attendance data was deleted - historical records are preserved")
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
    
    private func getUserAttendanceByIndex(index: String) -> UserAttendance? {
        let request: NSFetchRequest<UserAttendance> = UserAttendance.fetchRequest()
        request.predicate = NSPredicate(format: "index == %@", index)
        request.fetchLimit = 1
        
        // Log the query for specific bands
        if index.contains("Grave:") || index.contains("Destruction:") || index.contains("Hellbutcher:") {
            print("🔍 [AttendanceManager] Querying Core Data for index: '\(index)'")
        }
        
        do {
            let result = try coreDataManager.context.fetch(request).first
            if index.contains("Grave:") || index.contains("Destruction:") || index.contains("Hellbutcher:") {
                if let attendance = result {
                    print("✅ [AttendanceManager] Core Data returned record with status: \(attendance.attendanceStatus)")
                } else {
                    print("❌ [AttendanceManager] Core Data returned nil for this index")
                }
            }
            return result
        } catch {
            print("❌ Error fetching user attendance by index: \(error)")
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
        
        // CRITICAL: Set the index field for iCloud restoration
        userAttendance.index = createAttendanceIndex(
            bandName: event.band?.bandName ?? "",
            location: event.location ?? "",
            startTime: event.startTime ?? "",
            eventType: event.eventType ?? "",
            eventYear: Int(event.eventYear)
        )
        
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
    
    /// Creates a consistent index for attendance records that matches the iCloud key format
    /// Format: "bandName:location:startTime:eventType:eventYear"
    private func createAttendanceIndex(bandName: String, location: String, startTime: String, eventType: String, eventYear: Int) -> String {
        return "\(bandName):\(location):\(startTime):\(eventType):\(eventYear)"
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
    
    /// Parses an attendance index to extract event details
    /// Format: "bandName:location:startTime:eventType:eventYear"
    private func parseAttendanceIndex(_ index: String) -> [String: String] {
        let components = index.split(separator: ":")
        // Note: startTime format "HH:MM" contains a colon, so we need to account for that
        // Expected format: bandName:location:HH:MM:eventType:eventYear (6 components)
        guard components.count >= 6 else {
            print("❌ parseAttendanceIndex: Invalid component count \(components.count) for index: \(index)")
            return [:]
        }
        
        // Reconstruct startTime from components[2] and components[3]
        let startTime = String(components[2]) + ":" + String(components[3])
        
        return [
            "bandName": String(components[0]),
            "location": String(components[1]),
            "startTime": startTime,
            "eventType": String(components[4]),
            "eventYear": String(components[5])
        ]
    }
}

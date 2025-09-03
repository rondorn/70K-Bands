import Foundation
import CoreData

/// Test and demonstration of the new Core Data event system
/// This replaces the old scheduleHandler dictionary system
class EventSystemTest {
    
    /// Demonstrates the complete event system functionality
    static func runEventSystemDemo() {
        print("🎭 Starting Event System Demo...")
        
        // Initialize managers
        let eventManager = EventManager()
        let attendanceManager = AttendanceManager()
        let csvImporter = EventCSVImporter()
        
        // Step 1: Test basic event operations
        testBasicEventOperations(eventManager, csvImporter)
        
        // Step 2: Test event filtering
        testEventFiltering(eventManager)
        
        // Step 3: Test attendance management
        testAttendanceManagement(attendanceManager)
        
        // Step 4: Test CSV import
        testEventCSVImport(csvImporter)
        
        print("🎉 Event System Demo completed!")
    }
    
    // MARK: - Basic Operations Test
    
    private static func testBasicEventOperations(_ eventManager: EventManager, _ csvImporter: EventCSVImporter) {
        print("\n🧪 Testing Basic Event Operations...")
        
        // Test sample CSV data import
        let sampleCSV = """
        Band,Location,Date,Day,Start Time,End Time,Type,Description URL,Notes,ImageURL
        Metallica,Pool Deck,2025-1-30,Thursday,14:00,15:30,Show,http://example.com/metallica,Great show!,http://example.com/metallica.jpg
        Iron Maiden,Theater,2025-1-31,Friday,20:00,22:00,Show,http://example.com/maiden,Epic performance,http://example.com/maiden.jpg
        Metallica,Radio Room,2025-2-1,Saturday,16:00,17:00,Meet & Greet,http://example.com/meet,VIP only,http://example.com/meet.jpg
        """
        
        let importSuccess = csvImporter.importEventsFromCSV(sampleCSV)
        print("✅ CSV import success: \(importSuccess)")
        
        // Test getting events for a band
        let metallicaEvents = eventManager.getEvents(for: "Metallica")
        print("✅ Metallica events: \(metallicaEvents.count)")
        
        for event in metallicaEvents {
            print("   - \(event.location ?? "Unknown") on \(event.day ?? "Unknown") at \(event.startTime ?? "Unknown")")
        }
        
        // Test getting all events
        let allEvents = eventManager.getAllEvents()
        print("✅ Total events: \(allEvents.count)")
        
        // Test event data retrieval
        if let firstEvent = metallicaEvents.first {
            let location = eventManager.getEventData(
                bandName: "Metallica",
                timeIndex: firstEvent.timeIndex,
                field: "Location"
            )
            print("✅ Event location lookup: \(location)")
        }
    }
    
    // MARK: - Filtering Test
    
    private static func testEventFiltering(_ eventManager: EventManager) {
        print("\n🔍 Testing Event Filtering...")
        
        // Test location filtering
        let poolDeckEvents = eventManager.getEvents(atLocation: "Pool Deck")
        print("✅ Pool Deck events: \(poolDeckEvents.count)")
        
        // Test event type filtering
        let showEvents = eventManager.getEvents(ofType: "Show")
        print("✅ Show events: \(showEvents.count)")
        
        // Test complex filtering
        let filteredEvents = eventManager.getFilteredEvents(
            bandNames: ["Metallica"],
            eventTypes: ["Show"],
            year: 2025
        )
        print("✅ Filtered events (Metallica shows in 2025): \(filteredEvents.count)")
        
        // Test upcoming events
        let upcomingEvents = eventManager.getUpcomingEvents(for: "Metallica")
        print("✅ Upcoming Metallica events: \(upcomingEvents.count)")
        
        // Test unique locations
        let uniqueLocations = eventManager.getUniqueLocations()
        print("✅ Unique locations: \(uniqueLocations.joined(separator: ", "))")
        
        // Test unique event types
        let uniqueTypes = eventManager.getUniqueEventTypes()
        print("✅ Unique event types: \(uniqueTypes.joined(separator: ", "))")
    }
    
    // MARK: - Attendance Test
    
    private static func testAttendanceManagement(_ attendanceManager: AttendanceManager) {
        print("\n🎪 Testing Attendance Management...")
        
        // Test setting attendance
        attendanceManager.setAttendanceStatus(
            bandName: "Metallica",
            location: "Pool Deck",
            startTime: "14:00",
            eventType: "Show",
            eventYear: "2025",
            status: 2 // Attended
        )
        
        attendanceManager.setAttendanceStatus(
            bandName: "Iron Maiden",
            location: "Theater",
            startTime: "20:00",
            eventType: "Show",
            eventYear: "2025",
            status: 1 // Will Attend
        )
        
        // Test getting attendance
        let metallicaAttendance = attendanceManager.getAttendanceStatus(
            bandName: "Metallica",
            location: "Pool Deck",
            startTime: "14:00",
            eventType: "Show",
            eventYear: "2025"
        )
        print("✅ Metallica attendance status: \(metallicaAttendance) (Expected: 2)")
        
        // Test getting all attendance data
        let allAttendance = attendanceManager.getAllAttendanceData()
        print("✅ Total attendance records: \(allAttendance.count)")
        
        // Test getting attended events
        let attendedEvents = attendanceManager.getAttendedEvents(for: "Metallica")
        print("✅ Metallica attended events: \(attendedEvents.count)")
        
        // Test filtering by attendance status
        let willAttendEvents = attendanceManager.getEventsWithAttendanceStatus([1]) // Will Attend
        print("✅ Events user will attend: \(willAttendEvents.count)")
    }
    
    // MARK: - CSV Import Test
    
    private static func testEventCSVImport(_ csvImporter: EventCSVImporter) {
        print("\n📥 Testing CSV Import System...")
        
        // Test larger CSV dataset
        let largerCSV = """
        Band,Location,Date,Day,Start Time,End Time,Type,Description URL,Notes,ImageURL
        Black Sabbath,Pool Deck,2025-1-30,Thursday,12:00,13:30,Show,http://example.com/sabbath,Legendary,http://example.com/sabbath.jpg
        Deep Purple,Theater,2025-1-30,Thursday,15:00,16:30,Show,http://example.com/purple,Classic rock,http://example.com/purple.jpg
        Led Zeppelin,Radio Room,2025-1-31,Friday,18:00,19:30,Show,http://example.com/zeppelin,Epic,http://example.com/zeppelin.jpg
        Pink Floyd,Pool Deck,2025-1-31,Friday,21:00,22:30,Show,http://example.com/floyd,Psychedelic,http://example.com/floyd.jpg
        Black Sabbath,Atrium,2025-2-1,Saturday,14:00,15:00,Meet & Greet,http://example.com/meet,VIP event,
        """
        
        let importSuccess = csvImporter.importEventsFromCSV(largerCSV)
        print("✅ Large CSV import success: \(importSuccess)")
        
        // Test data access methods
        let bandEvents = csvImporter.getEvents(for: "Black Sabbath")
        print("✅ Black Sabbath events: \(bandEvents.count)")
        
        let allEvents = csvImporter.getEventsArray()
        print("✅ Total events after import: \(allEvents.count)")
        
        // Test legacy compatibility
        let eventManager = EventManager()
        let legacyData = eventManager.getLegacySchedulingData()
        print("✅ Legacy scheduling data format: \(legacyData.keys.count) bands")
        
        let legacyByTime = eventManager.getLegacySchedulingDataByTime()
        print("✅ Legacy by-time data format: \(legacyByTime.keys.count) time slots")
    }
    
    // MARK: - Performance Test
    
    /// Demonstrates performance improvement over legacy dictionary system
    static func performanceComparison() {
        print("\n⚡ Performance Comparison: Core Data vs Dictionary...")
        
        let eventManager = EventManager()
        let eventCount = 500
        
        // Test Core Data performance
        let coreDataStart = Date()
        
        // Create sample events
        let csvImporter = EventCSVImporter()
        var sampleCSV = "Band,Location,Date,Day,Start Time,End Time,Type,Description URL,Notes,ImageURL\n"
        
        for i in 1...eventCount {
            let bandName = "Band\(i % 50)" // 50 different bands
            let location = ["Pool Deck", "Theater", "Radio Room", "Atrium"][i % 4]
            let day = ["Thursday", "Friday", "Saturday", "Sunday"][i % 4]
            let startTime = String(format: "%02d:00", (i % 24))
            let endTime = String(format: "%02d:30", (i % 24))
            
            sampleCSV += "\(bandName),\(location),2025-1-30,\(day),\(startTime),\(endTime),Show,http://example.com,Notes,\n"
        }
        
        _ = csvImporter.importEventsFromCSV(sampleCSV)
        
        // Query performance tests
        let allEvents = eventManager.getAllEvents()
        let poolDeckEvents = eventManager.getEvents(atLocation: "Pool Deck")
        let showEvents = eventManager.getEvents(ofType: "Show")
        let filteredEvents = eventManager.getFilteredEvents(
            locations: ["Pool Deck", "Theater"],
            eventTypes: ["Show"]
        )
        
        let coreDataTime = Date().timeIntervalSince(coreDataStart)
        
        print("✅ Core Data Performance:")
        print("   - Imported \(eventCount) events")
        print("   - Retrieved \(allEvents.count) total events")
        print("   - Filtered to \(poolDeckEvents.count) Pool Deck events")
        print("   - Filtered to \(showEvents.count) Show events")
        print("   - Complex filter: \(filteredEvents.count) events")
        print("   - Total time: \(String(format: "%.3f", coreDataTime)) seconds")
        
        print("🎯 Core Data provides:")
        print("   ✅ Indexed queries for fast location/type filtering")
        print("   ✅ Complex multi-criteria filtering in single query")
        print("   ✅ Memory efficient (lazy loading)")
        print("   ✅ ACID transactions for data integrity")
        print("   ✅ Automatic relationship management with bands")
    }
    
    // MARK: - Migration Test
    
    /// Tests migration from legacy schedule system
    static func testMigrationFromLegacySystem() {
        print("\n🔄 Testing Migration from Legacy System...")
        
        // Simulate legacy scheduling data format
        let legacySchedulingData: [String: [TimeInterval: [String: String]]] = [
            "Test Band 1": [
                1643558400.0: [
                    "Location": "Pool Deck",
                    "Date": "2025-1-30",
                    "Day": "Thursday",
                    "Start Time": "14:00",
                    "End Time": "15:30",
                    "Type": "Show",
                    "Notes": "Great show",
                    "Description URL": "http://example.com",
                    "ImageURL": "http://example.com/image.jpg"
                ]
            ],
            "Test Band 2": [
                1643565600.0: [
                    "Location": "Theater",
                    "Date": "2025-1-30",
                    "Day": "Thursday",
                    "Start Time": "16:00",
                    "End Time": "17:30",
                    "Type": "Show",
                    "Notes": "Epic performance",
                    "Description URL": "http://example.com/2",
                    "ImageURL": "http://example.com/image2.jpg"
                ]
            ]
        ]
        
        // Convert legacy data to CSV format for import
        var csvData = "Band,Location,Date,Day,Start Time,End Time,Type,Description URL,Notes,ImageURL\n"
        
        for (bandName, timeData) in legacySchedulingData {
            for (_, eventData) in timeData {
                csvData += "\(bandName),"
                csvData += "\(eventData["Location"] ?? ""),"
                csvData += "\(eventData["Date"] ?? ""),"
                csvData += "\(eventData["Day"] ?? ""),"
                csvData += "\(eventData["Start Time"] ?? ""),"
                csvData += "\(eventData["End Time"] ?? ""),"
                csvData += "\(eventData["Type"] ?? ""),"
                csvData += "\(eventData["Description URL"] ?? ""),"
                csvData += "\(eventData["Notes"] ?? ""),"
                csvData += "\(eventData["ImageURL"] ?? "")\n"
            }
        }
        
        // Import the converted data
        let csvImporter = EventCSVImporter()
        let success = csvImporter.importEventsFromCSV(csvData)
        
        print("✅ Legacy data migration success: \(success)")
        
        // Verify the migration
        let eventManager = EventManager()
        let migratedEvents = eventManager.getAllEvents()
        print("✅ Migrated events count: \(migratedEvents.count)")
        
        // Test that we can still access data in legacy format
        let legacyFormat = eventManager.getLegacySchedulingData()
        print("✅ Legacy format compatibility: \(legacyFormat.keys.count) bands")
        
        for (bandName, timeData) in legacyFormat {
            print("   - \(bandName): \(timeData.keys.count) events")
        }
    }
}

// MARK: - Integration Examples

/// Examples of how to replace legacy schedule code
class EventIntegrationExamples {
    
    /// Example: Replacing DetailViewModel schedule logic
    static func detailViewModelExample() {
        print("\n📱 DetailViewModel Integration Example...")
        
        // OLD CODE (to be removed):
        /*
        private let schedule = scheduleHandler.shared
        
        private func loadScheduleEvents() {
            schedule.getCachedData()
            if let bandSchedule = schedule.schedulingData[bandName] {
                let sortedKeys = bandSchedule.keys.sorted()
                for timeIndex in sortedKeys {
                    let location = schedule.getData(bandName, index: timeIndex, variable: "Location")
                    let day = schedule.getData(bandName, index: timeIndex, variable: "Day")
                    // ... more field access
                }
            }
        }
        */
        
        // NEW CODE (Core Data):
        let eventManager = EventManager()
        let bandName = "Example Band"
        
        // Load events for band
        let events = eventManager.getEvents(for: bandName)
        print("✅ Loaded \(events.count) events for \(bandName)")
        
        for event in events {
            print("   - \(event.location ?? "Unknown") on \(event.day ?? "Unknown")")
            print("     Time: \(event.startTime ?? "Unknown") - \(event.endTime ?? "Unknown")")
            print("     Type: \(event.eventType ?? "Unknown")")
        }
        
        // Much simpler and more efficient!
    }
    
    /// Example: Replacing MasterViewController filtering logic
    static func masterViewControllerExample() {
        print("\n📋 MasterViewController Integration Example...")
        
        let eventManager = EventManager()
        
        // OLD CODE (complex dictionary filtering):
        /*
        let schedule = scheduleHandler.shared
        schedule.getCachedData()
        var filteredEvents: [Event] = []
        
        for (bandName, timeData) in schedule.schedulingData {
            for (timeIndex, eventData) in timeData {
                if eventData["Location"]?.contains("Pool Deck") == true &&
                   eventData["Type"] == "Show" {
                    // Create event object and add to filtered list
                }
            }
        }
        */
        
        // NEW CODE (simple Core Data query):
        let poolDeckShows = eventManager.getFilteredEvents(
            locations: ["Pool Deck"],
            eventTypes: ["Show"]
        )
        print("✅ Pool Deck shows: \(poolDeckShows.count)")
        
        // Additional filtering examples:
        let todayEvents = eventManager.getEvents(onDay: "Thursday")
        let metallicaEvents = eventManager.getEvents(for: "Metallica")
        let upcomingShows = eventManager.getUpcomingEvents(for: "Iron Maiden")
        
        print("✅ Today's events: \(todayEvents.count)")
        print("✅ Metallica events: \(metallicaEvents.count)")
        print("✅ Upcoming Iron Maiden shows: \(upcomingShows.count)")
    }
}

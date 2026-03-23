//
//  ShowsAttended.swift
//  
//
//  Created by Ron Dorn on 6/10/18.
//
import Foundation
import UIKit

// MARK: - Attendance index (same band/location/start/type on different days)

/// Builds SQLite / file attendance keys. When multiple events share the same base tuple for a year,
/// keys append `__` + the **database** `day` string (e.g. `__Day 1`). Non-colliding keys stay unchanged for backward compatibility.
enum AttendanceIndexKeys {
    static func normalizedEventTypeForKey(_ eventType: String) -> String {
        if eventType == unofficalEventTypeOld { return unofficalEventType }
        return eventType
    }

    static func baseKey(band: String, location: String, startTime: String, eventType: String, eventYearString: String) -> String {
        let t = normalizedEventTypeForKey(eventType)
        return "\(band):\(location):\(startTime):\(t):\(eventYearString)"
    }

    /// Base keys that occur more than once for this year (band + location + startTime + normalized type).
    static func collidingBaseKeys(forYear year: Int) -> Set<String> {
        let events = DataManager.shared.fetchEvents(forYear: year)
        var counts: [String: Int] = [:]
        for e in events {
            let st = e.startTime ?? ""
            guard !st.isEmpty else { continue }
            let base = baseKey(
                band: e.bandName,
                location: e.location,
                startTime: st,
                eventType: e.eventType ?? "",
                eventYearString: String(year)
            )
            counts[base, default: 0] += 1
        }
        return Set(counts.filter { $0.value > 1 }.map(\.key))
    }

    /// When the base tuple collides and `scheduleDayFromDatabase` is non-empty, returns `base__DayLabel`.
    static func storageKey(
        band: String,
        location: String,
        startTime: String,
        eventType: String,
        eventYearString: String,
        scheduleDayFromDatabase: String?,
        collidingBases: Set<String>
    ) -> String {
        let base = baseKey(band: band, location: location, startTime: startTime, eventType: eventType, eventYearString: eventYearString)
        guard let d = scheduleDayFromDatabase?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty else {
            return base
        }
        guard collidingBases.contains(base) else {
            return base
        }
        return base + "__" + d
    }
}

open class ShowsAttended {

    private static let collisionLock = NSLock()
    private static var collisionCacheYear: Int?
    private static var collisionCacheBases: Set<String>?

    /// Call after schedule data is reloaded from SQLite so collision detection matches the new schedule.
    static func invalidateAttendanceCollisionCache() {
        collisionLock.lock()
        collisionCacheYear = nil
        collisionCacheBases = nil
        collisionLock.unlock()
    }

    private func collidingBases(forYearString yearStr: String) -> Set<String> {
        guard let y = Int(yearStr) else { return [] }
        Self.collisionLock.lock()
        defer { Self.collisionLock.unlock() }
        if Self.collisionCacheYear == y, let s = Self.collisionCacheBases {
            return s
        }
        let s = AttendanceIndexKeys.collidingBaseKeys(forYear: y)
        Self.collisionCacheYear = y
        Self.collisionCacheBases = s
        return s
    }

    private func resolveAttendanceStorageIndex(
        band: String,
        location: String,
        startTime: String,
        eventType: String,
        eventYearString: String,
        scheduleDay: String?
    ) -> String {
        let bases = collidingBases(forYearString: eventYearString)
        return AttendanceIndexKeys.storageKey(
            band: band,
            location: location,
            startTime: startTime,
            eventType: eventType,
            eventYearString: eventYearString,
            scheduleDayFromDatabase: scheduleDay,
            collidingBases: bases
        )
    }

    private func attendanceIndexMatchesYear(_ index: String, eventYearString: String) -> Bool {
        let parts = index.components(separatedBy: ":")
        guard let rawYear = parts.last else { return false }
        let yearOnly: String
        if let r = rawYear.range(of: "__") {
            yearOnly = String(rawYear[..<r.lowerBound])
        } else {
            yearOnly = rawYear
        }
        return yearOnly == eventYearString
    }

    private func mapAttendanceCode(_ code: Int) -> String {
        switch code {
        case 2: return sawAllStatus
        case 1: return sawSomeStatus
        case 3: return sawNoneStatus
        default: return sawNoneStatus
        }
    }

    let iCloudHandle = iCloudDataHandler()
    // Use SQLite AttendanceManager for all operations
    private let attendanceManager = SQLiteAttendanceManager.shared
    
    // Thread-safe queue and backing store for showsAttendedArray
    private let showsAttendedQueue = DispatchQueue(label: "com.yourapp.showsAttendedQueue", attributes: .concurrent)
    private var _showsAttendedArray = [String : String]()
    
    // Thread-safe accessors
    var showsAttendedArray: [String : String] {
        get { showsAttendedQueue.sync { _showsAttendedArray } }
        set { showsAttendedQueue.async(flags: .barrier) { self._showsAttendedArray = newValue } }
    }
    // Helper for mutation
    private func mutateShowsAttendedArray(_ block: @escaping (inout [String: String]) -> Void) {
        showsAttendedQueue.async(flags: .barrier) { block(&self._showsAttendedArray) }
    }
    
    /**
     Initializes a new instance of ShowsAttended and loads cached data.
     */
    init(){
        print ("Loading shows attended data")
        getCachedData()
    }
    
    /**
     Loads cached show attendance data, using a static cache if available.
     */
    func getCachedData(){
        let t0 = Date()
        let thread = Thread.isMainThread ? "MAIN" : "BG"
        LaunchTiming.logStart("ShowsAttended.getCachedData", thread: thread)
        defer { LaunchTiming.logEnd("ShowsAttended.getCachedData", startTime: t0, thread: thread) }

        // SQLite.swift is thread-safe, so we can access cacheVariables directly
        // cacheVariables already has thread-safe accessors
        let cacheIsEmpty = cacheVariables.attendedStaticCache.isEmpty

        if cacheIsEmpty {
            print("📊 [DEADLOCK_FIX] Cache empty, loading shows attended")
            loadShowsAttended()
        } else {
            // Copy from static cache to instance
            // cacheVariables is already thread-safe, so direct access is safe
            self.showsAttendedArray = cacheVariables.attendedStaticCache
                
            // Even when using static cache, check if migration is needed
            let currentArray = self.showsAttendedQueue.sync { self._showsAttendedArray }
            var needsMigration = false
            let currentTimestamp = String(format: "%.0f", Date().timeIntervalSince1970)
            
            for (key, value) in currentArray {
                let parts = value.split(separator: ":")
                if parts.count == 1 {
                    self.mutateShowsAttendedArray { arr in arr[key] = value + ":" + currentTimestamp }
                    needsMigration = true
                }
            }
            
            if needsMigration {
                print("Migrated old attendance data from static cache to new format with timestamps.")
                self.saveShowsAttended()
                // Update the static cache with migrated data
                // cacheVariables setters are thread-safe
                for (key, value) in self.showsAttendedArray {
                    cacheVariables.attendedStaticCache[key] = value
                }
            }
        }
        // Note: iCloud attended data restoration is now handled centrally in MasterViewController
        // to prevent multiple simultaneous executions
    }
    
    /**
     Sets the showsAttendedArray to the provided attendedData.
     - Parameter attendedData: A dictionary of attended data to set.
     */
    func setShowsAttended(attendedData: [String : String]){
        self.showsAttendedArray = attendedData
    }
    
    /**
     Returns the current showsAttendedArray (copy).
     - Returns: A dictionary of show attendance data.
     */
    func getShowsAttended()->[String : String]{
        return showsAttendedQueue.sync { self._showsAttendedArray }
    }
    
    /**
     Saves the current showsAttendedArray to persistent storage.
     */
    func saveShowsAttended(){
        let currentArray = showsAttendedQueue.sync { self._showsAttendedArray }
        if (currentArray.count > 0){
            do {
                let json = try JSONEncoder().encode(currentArray)
                try json.write(to: showsAttended)
                writeLastScheduleDataWrite();
                // Reduced logging for performance
            } catch {
                print ("Loading show attended data! Error, unable to save showsAtteneded Data \(error.localizedDescription)")
            }
        }
    }
    
    /**
     Loads show attendance data from persistent storage and updates the static cache.
     
     THREAD SAFETY: This method performs file I/O and should ideally be called on a background thread,
     but it's designed to not block if called from main thread by avoiding nested sync calls.
     */
    func loadShowsAttended(){
        let t0 = Date()
        let thread = Thread.isMainThread ? "MAIN" : "BG"
        LaunchTiming.logStart("ShowsAttended.loadShowsAttended", thread: thread)
        defer { LaunchTiming.logEnd("ShowsAttended.loadShowsAttended", startTime: t0, thread: thread) }

        print("📊 [THREAD_SAFE] loadShowsAttended: Starting on thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")

        // SQLite.swift is thread-safe, so we can access data directly without blocking sync calls
        // We don't actually use 'allBands' in this method, so we can skip it entirely
        // let bandNameHandle = bandNamesHandler.shared
        // let allBands = bandNameHandle.getBandNames()  // ← This was causing deadlock!
        print("📊 [DEADLOCK_FIX] Skipping bandNameHandle.getBandNames() - not needed for loading")
        
        let artistUrl = getScheduleUrl()
        var unuiqueSpecial = [String]()
        do {
            let data = try Data(contentsOf: showsAttended, options: [])
            if let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String : String] {
                self.showsAttendedArray = dict
            } else {
                print("ShowsAttended: ERROR - Unable to decode showsAttendedArray from JSON, data may be corrupted or in an unexpected format.")
                self.showsAttendedArray = [:]
            }
            // Reduced logging for performance - data loaded from JSON
            var needsMigration = false
            let currentTimestamp = String(format: "%.0f", Date().timeIntervalSince1970)
            // Migrate old format (no timestamp) to new format
            let currentArray = showsAttendedQueue.sync { self._showsAttendedArray }
            for (key, value) in currentArray {
                let parts = value.split(separator: ":")
                if parts.count == 1 {
                    mutateShowsAttendedArray { arr in arr[key] = value + ":" + currentTimestamp }
                    needsMigration = true
                }
            }
            if needsMigration {
                print("Migrated old attendance data to new format with timestamps.")
                saveShowsAttended()
            }
            let afterMigrationArray = showsAttendedQueue.sync { self._showsAttendedArray }
            if (afterMigrationArray.count > 0){
                for index in afterMigrationArray {
                    mutateShowsAttendedArray { arr in arr[index.key] = index.value }
                }
            }
            // Reduced logging for performance
            if afterMigrationArray.isEmpty && !cacheVariables.justLaunched {
                print("Skipping attended cache population: showsAttendedArray is empty and app is not just launched.")
                return
            }
            // cacheVariables setters are thread-safe, no need for additional sync
            for index in afterMigrationArray {
                cacheVariables.attendedStaticCache[index.key] = index.value
            }
        } catch {
            // Handle missing showsAttended.data gracefully - this is expected on first install
            if let nsError = error as NSError?, nsError.code == 260 { // NSFileReadNoSuchFileError
                print("Shows attended data file does not exist yet - this is normal for first app launch. Starting with empty attendance records.")
                // Initialize with empty data for first launch
                self.showsAttendedArray = [:]
            } else {
                print("Error loading shows attended data: \(error.localizedDescription)")
            }
        }
    }
    
    /// Removes attendance for the given year from the legacy file and static cache.
    /// Call this after clearing SQLite so the UI and any reload don't show stale data from file/cache.
    static func clearLegacyStoreForYear(_ year: Int) {
        let suffix = ":\(year)"
        var removedFromCache = 0
        var current = cacheVariables.attendedStaticCache
        let keysToRemove = current.keys.filter { $0.hasSuffix(suffix) }
        for key in keysToRemove {
            current.removeValue(forKey: key)
            removedFromCache += 1
        }
        cacheVariables.attendedStaticCache = current
        if removedFromCache > 0 {
            print("📋 ShowsAttended: Removed \(removedFromCache) keys for year \(year) from static cache")
        }
        do {
            let fileURL = showsAttended
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
            let data = try Data(contentsOf: fileURL)
            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: String] else { return }
            let filtered = dict.filter { !$0.key.hasSuffix(suffix) }
            if filtered.count != dict.count {
                if filtered.isEmpty {
                    let emptyDict: [String: String] = [:]
                    let emptyData = try JSONSerialization.data(withJSONObject: emptyDict)
                    try emptyData.write(to: fileURL)
                    print("📋 ShowsAttended: Cleared legacy file for year \(year)")
                } else {
                    let newData = try JSONSerialization.data(withJSONObject: filtered)
                    try newData.write(to: fileURL)
                    print("📋 ShowsAttended: Removed \(dict.count - filtered.count) keys for year \(year) from legacy file")
                }
            }
        } catch {
            print("📋 ShowsAttended: Failed to clear legacy file for year \(year): \(error.localizedDescription)")
        }
    }
    
    /// Overlap of 15 min or less is ignored (both shows can stay marked). Only clear when overlap > this threshold.
    private static let shortOverlapThresholdSeconds: Double = 900 // 15 minutes

    /// When marking a Show as attended, clear any other Show already attended that overlaps in time (same calendar day) by more than 15 min. Meet and Greets are not cleared. Overlap <= 15 min is allowed (both can be marked).
    private func clearOverlappingShowAttendance(
        band: String,
        location: String,
        startTime: String,
        eventType: String,
        eventYearString: String,
        scheduleDay: String?,
        currentIndex: String,
        allEvents: [EventData]
    ) {
        guard let thisEvent = allEvents.first(where: { e in
            e.bandName == band && e.location == location && (e.startTime ?? "") == startTime && eventTypeMatches(e.eventType, stored: eventType)
                && (scheduleDay == nil || e.day == scheduleDay)
        }) else { return }
        let thisDay = normalizedCalendarDay(from: thisEvent.date)
        var thisEnd = thisEvent.endTimeIndex
        if thisEvent.timeIndex > thisEnd { thisEnd += 86400 }
        let attended = getShowsAttended()
        let sawNone = sawNoneStatus + ":" + String(format: "%.0f", Date().timeIntervalSince1970)
        for (index, value) in attended {
            guard index != currentIndex else { continue }
            guard attendanceIndexMatchesYear(index, eventYearString: eventYearString) else { continue }
            let statusPart = value.components(separatedBy: ":").first ?? value
            guard statusPart == sawAllStatus || statusPart == sawSomeStatus else { continue }
            guard let (otherBand, otherLocation, otherStart, otherEventType) = parseAttendanceIndex(index) else { continue }
            guard otherEventType == showType else { continue }
            guard let otherEvent = allEvents.first(where: { e in
                e.bandName == otherBand && e.location == otherLocation && (e.startTime ?? "") == otherStart && eventTypeMatches(e.eventType, stored: otherEventType)
            }) else { continue }
            let otherDay = normalizedCalendarDay(from: otherEvent.date)
            guard thisDay == otherDay else { continue }
            var otherEnd = otherEvent.endTimeIndex
            if otherEvent.timeIndex > otherEnd { otherEnd += 86400 }
            let overlaps = thisEvent.timeIndex < otherEnd && otherEvent.timeIndex < thisEnd
            guard overlaps else { continue }
            let overlapStart = max(thisEvent.timeIndex, otherEvent.timeIndex)
            let overlapEnd = min(thisEnd, otherEnd)
            let overlapSeconds = max(0, overlapEnd - overlapStart)
            if overlapSeconds > Self.shortOverlapThresholdSeconds {
                changeShowAttendedStatus(index: index, status: sawNone)
            }
        }
    }
    
    private func eventTypeMatches(_ eventType: String?, stored: String) -> Bool {
        let t = eventType ?? ""
        if t == stored { return true }
        if t == unofficalEventTypeOld && stored == unofficalEventType { return true }
        return false
    }
    
    /// Parse "band:location:startTime:eventType:year" or `...:year__DayLabel` allowing band/location to contain ":".
    private func parseAttendanceIndex(_ index: String) -> (band: String, location: String, startTime: String, eventType: String)? {
        let parts = index.components(separatedBy: ":")
        guard parts.count >= 5 else { return nil }
        let eventType = parts[parts.count - 2]
        let startTime = parts[parts.count - 3]
        let location = parts[parts.count - 4]
        let band = parts[0..<(parts.count - 4)].joined(separator: ":")
        return (band, location, startTime, eventType)
    }
    
    private func normalizedCalendarDay(from dateString: String?) -> String? {
        guard let s = dateString, !s.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        let formats = ["M/d/yyyy", "MM/dd/yyyy", "M-d-yyyy", "MM-dd-yyyy"]
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: s) {
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.string(from: date)
            }
        }
        return nil
    }
    
    /**
     Adds or updates a show attended record with a specific status and timestamp.
     - Parameters:
        - band: The band name.
        - location: The event location.
        - startTime: The event start time.
        - eventType: The type of event.
        - eventYearString: The event year as a string.
        - status: The attendance status to set.
        - newTime: The timestamp to use (Double, seconds since epoch).
        - scheduleDay: SQLite `day` label when the base attendance tuple collides on multiple days (optional).
        - allEventsForYear: If provided, enforces "no overlapping shows attended": when marking a Show (not Meet and Greet) as attended, any other Show already marked attended that overlaps in time will be cleared first. Meet and Greets are allowed to overlap.
     */
    func addShowsAttendedWithStatusAndTime(
        band: String,
        location: String,
        startTime: String,
        eventType: String,
        eventYearString: String,
        status: String,
        newTime: Double,
        scheduleDay: String? = nil,
        allEventsForYear: [EventData]? = nil
    ) {
        // Normalize event type: "Unofficial Event" -> "Cruiser Organized" (for consistency with getShowAttendedStatus)
        var eventTypeValue = eventType
        if eventType == unofficalEventTypeOld {
            eventTypeValue = unofficalEventType
        }
        let index = resolveAttendanceStorageIndex(
            band: band,
            location: location,
            startTime: startTime,
            eventType: eventTypeValue,
            eventYearString: eventYearString,
            scheduleDay: scheduleDay
        )

        // For shows only: clear any other overlapping show attendance (user can't see two shows at once). Meet and Greets may overlap.
        if let events = allEventsForYear, eventTypeValue == showType, status == sawAllStatus || status == sawSomeStatus {
            clearOverlappingShowAttendance(
                band: band,
                location: location,
                startTime: startTime,
                eventType: eventTypeValue,
                eventYearString: eventYearString,
                scheduleDay: scheduleDay,
                currentIndex: index,
                allEvents: events
            )
        }
        
        let timestamp = String(format: "%.0f", newTime)
        changeShowAttendedStatus(index: index, status: status + ":" + timestamp)
        // cacheVariables setters are thread-safe
        cacheVariables.lastModifiedDate = Date()
    }

    /**
     Adds or updates a show attended record with a specific status (uses current time as timestamp).
     - Parameters:
        - band: The band name.
        - location: The event location.
        - startTime: The event start time.
        - eventType: The type of event.
        - eventYearString: The event year as a string.
        - status: The attendance status to set.
        - scheduleDay: SQLite day label when multiple events share the same base tuple (optional).
        - allEventsForYear: If provided, enforces "no overlapping shows attended" when marking a Show as attended (see addShowsAttendedWithStatusAndTime).
     */
    func addShowsAttendedWithStatus(
        band: String,
        location: String,
        startTime: String,
        eventType: String,
        eventYearString: String,
        status: String,
        scheduleDay: String? = nil,
        allEventsForYear: [EventData]? = nil
    ) {
        let now = Date().timeIntervalSince1970
        addShowsAttendedWithStatusAndTime(
            band: band,
            location: location,
            startTime: startTime,
            eventType: eventType,
            eventYearString: eventYearString,
            status: status,
            newTime: now,
            scheduleDay: scheduleDay,
            allEventsForYear: allEventsForYear
        )
    }
    
    /**
     Adds or cycles the attendance status for a show and returns the new status.
     - Parameters:
        - band: The band name.
        - location: The event location.
        - startTime: The event start time.
        - eventType: The type of event.
        - eventYearString: The event year as a string.
     - Returns: The new attendance status as a string.
     */
    func addShowsAttended(
        band: String,
        location: String,
        startTime: String,
        eventType: String,
        eventYearString: String,
        scheduleDay: String? = nil
    ) -> String {
        var eventTypeValue = eventType;
        if (eventType == unofficalEventTypeOld){
            eventTypeValue = unofficalEventType;
        }
        let index = resolveAttendanceStorageIndex(
            band: band,
            location: location,
            startTime: startTime,
            eventType: eventTypeValue,
            eventYearString: eventYearString,
            scheduleDay: scheduleDay
        )

        // Use SQLite AttendanceManager instead of old system
        let currentStatus = attendanceManager.getAttendanceStatusByIndex(index: index)
        
        // Determine new status based on current status
        var newStatus: Int
        switch currentStatus {
        case 0, 3: // No status or Won't Attend -> Will Attend
            newStatus = 2
        case 2 where eventType == showType: // Will Attend -> Will Attend Some (only for shows)
            newStatus = 1
        case 1: // Will Attend Some -> Won't Attend
            newStatus = 3
        case 2: // Will Attend for non-show events -> Won't Attend
            newStatus = 3
        default: // Fallback
            newStatus = 2
        }
        
        // Update using SQLite (all profiles are now editable); explicitly mark as Manual
        attendanceManager.setAttendanceStatusByIndex(index: index, status: newStatus, timestamp: Date().timeIntervalSince1970)
        
        // Convert to string status for return value
        var value = ""
        switch newStatus {
        case 2:
            value = sawAllStatus
        case 1:
            value = sawSomeStatus
        case 3:
            value = sawNoneStatus
        default:
            value = sawNoneStatus
        }
        
        return value
    }
    
    /**
     Changes the attendance status for a specific show and updates caches and cloud storage.
     - Parameters:
        - index: The unique index for the show.
        - status: The new attendance status.
     */
    func changeShowAttendedStatus(index: String, status:String){
        // Parse status to get numeric value (all profiles are now editable)
        let statusParts = status.components(separatedBy: ":")
        let statusString = statusParts[0]
        let numericStatus: Int
        switch statusString {
        case sawAllStatus:
            numericStatus = 2
        case sawSomeStatus:
            numericStatus = 1
        case sawNoneStatus:
            numericStatus = 3
        default:
            numericStatus = 0
        }
        
        // Use SQLite AttendanceManager; explicitly mark as Manual for user-initiated changes
        attendanceManager.setAttendanceStatusByIndex(index: index, status: numericStatus, timestamp: Date().timeIntervalSince1970)
        
        // Keep old system for backward compatibility (legacy cache)
        mutateShowsAttendedArray { arr in arr[index] = status }
        let firebaseEventWrite = firebaseEventDataWrite();
        firebaseEventWrite.writeEvent(index: index, status: status)
        // cacheVariables setters are thread-safe
        cacheVariables.attendedStaticCache[index] = status
        saveShowsAttended()
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            // Use SQLiteiCloudSync - only syncs Default profile
            let sqliteiCloudSync = SQLiteiCloudSync()
            if sqliteiCloudSync.writeAttendanceRecordToiCloud(eventIndex: index, status: status) {
                print("☁️ Attendance synced to iCloud for \(index) (Default profile only)")
            } else {
                print("☁️ Attendance sync skipped for \(index) (not Default profile or iCloud disabled)")
            }
        }
    }
    
    /**
     Changes the attended status for a show with an option to skip iCloud writing
     - Parameters:
        - index: The event index
        - status: The attendance status
        - skipICloud: If true, skips writing to iCloud (useful during restoration)
     */
    func changeShowAttendedStatus(index: String, status: String, skipICloud: Bool) {
        // Parse status string (may be "status" or "status:timestamp") to numeric for SQLite
        let statusParts = status.components(separatedBy: ":")
        let statusString = statusParts[0]
        let numericStatus: Int
        switch statusString {
        case sawAllStatus:
            numericStatus = 2
        case sawSomeStatus:
            numericStatus = 1
        case sawNoneStatus:
            numericStatus = 3
        default:
            numericStatus = 0
        }
        attendanceManager.setAttendanceStatusByIndex(index: index, status: numericStatus, timestamp: Date().timeIntervalSince1970)
        mutateShowsAttendedArray { arr in arr[index] = status }
        let firebaseEventWrite = firebaseEventDataWrite();
        firebaseEventWrite.writeEvent(index: index, status: status)
        cacheVariables.attendedStaticCache[index] = status
        saveShowsAttended()
        
        if !skipICloud {
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                // Use SQLiteiCloudSync - only syncs Default profile
                let sqliteiCloudSync = SQLiteiCloudSync()
                if sqliteiCloudSync.writeAttendanceRecordToiCloud(eventIndex: index, status: status) {
                    print("☁️ Attendance synced to iCloud for \(index) (Default profile only)")
                } else {
                    print("☁️ Attendance sync skipped for \(index) (not Default profile or iCloud disabled)")
                }
            }
        } else {
            print("Skipping iCloud write for \(index) during restoration")
        }
    }
    
    /**
     Returns the attendance icon for a specific show.
     - Parameters:
        - band: The band name.
        - location: The event location.
        - startTime: The event start time.
        - eventType: The type of event.
        - eventYearString: The event year as a string.
     - Returns: The corresponding UIImage for the attendance status.
     */
    func getShowAttendedIcon(
        band: String,
        location: String,
        startTime: String,
        eventType: String,
        eventYearString: String,
        scheduleDay: String? = nil
    ) -> UIImage {

        var iconName = String()
        var icon = UIImage()

        var eventTypeValue = eventType;
        if (eventType == unofficalEventTypeOld){
            eventTypeValue = unofficalEventType;
        }

        let value = getShowAttendedStatus(
            band: band,
            location: location,
            startTime: startTime,
            eventType: eventTypeValue,
            eventYearString: eventYearString,
            scheduleDay: scheduleDay
        )
        // Reduced logging for performance

        // Reduced logging for performance
        if (value == sawAllStatus){
            iconName = "icon-seen"
        
        } else if (value == sawSomeStatus){
            iconName = "icon-seen-partial"

        }
        
        if (iconName.isEmpty == false){
            icon = UIImage(named: iconName) ?? UIImage()
        }
        
        return icon
    }

    func getShowAttendedColor(
        band: String,
        location: String,
        startTime: String,
        eventType: String,
        eventYearString: String,
        scheduleDay: String? = nil
    ) -> UIColor {

        var eventTypeValue = eventType;
        if (eventType == unofficalEventTypeOld){
            eventTypeValue = unofficalEventType;
        }

        var color : UIColor = UIColor()

        let value = getShowAttendedStatus(
            band: band,
            location: location,
            startTime: startTime,
            eventType: eventTypeValue,
            eventYearString: eventYearString,
            scheduleDay: scheduleDay
        )
        
        if (value == sawAllStatus){
            color = sawAllColor
            
        } else if (value == sawSomeStatus){
           color = sawSomeColor
            
        } else if (value == sawNoneStatus){
            color = sawNoneColor
        }
        
        return color
    }
    
    func getShowAttendedStatus(
        band: String,
        location: String,
        startTime: String,
        eventType: String,
        eventYearString: String,
        scheduleDay: String? = nil
    ) -> String {
        var eventTypeVariable = eventType;
        if (eventType == unofficalEventTypeOld){
            eventTypeVariable = unofficalEventType;
        }

        let extendedIndex = resolveAttendanceStorageIndex(
            band: band,
            location: location,
            startTime: startTime,
            eventType: eventTypeVariable,
            eventYearString: eventYearString,
            scheduleDay: scheduleDay
        )
        let baseIndex = AttendanceIndexKeys.baseKey(
            band: band,
            location: location,
            startTime: startTime,
            eventType: eventTypeVariable,
            eventYearString: eventYearString
        )

        if extendedIndex != baseIndex {
            let extCode = attendanceManager.getAttendanceStatusByIndex(index: extendedIndex)
            if extCode != 0 {
                return mapAttendanceCode(extCode)
            }
        }

        let baseCode = attendanceManager.getAttendanceStatusByIndex(index: baseIndex)
        return mapAttendanceCode(baseCode)
    }
    
    func getShowAttendedStatusUserFriendly(
        band: String,
        location: String,
        startTime: String,
        eventType: String,
        eventYearString: String,
        scheduleDay: String? = nil
    ) -> String {
        var status = getShowAttendedStatus(
            band: band,
            location: location,
            startTime: startTime,
            eventType: eventType,
            eventYearString: eventYearString,
            scheduleDay: scheduleDay
        )
        
        var userFriendlyStatus = "";
        
        if (status == sawAllStatus){
            status = NSLocalizedString("All Of Event", comment: "")
        
        } else if (status == sawSomeStatus){
                status = NSLocalizedString("Part Of Event", comment: "")
            
        } else {
                status = NSLocalizedString("None Of Event", comment: "")
        }
        
        return status
        
    }
    
    func setShowsAttendedStatus(_ sender: UITextField, status: String)->String{
        
        var message : String
        var fieldText = sender.text;
    
        print ("getShowAttendedStatus (inset) = \(status) =\(fieldText ?? "")")
        if (status == sawAllStatus){
            sender.textColor = UIColor.lightGray
            sender.text = fieldText
            message = NSLocalizedString("All Of Event", comment: "")
            
        } else if (status == sawSomeStatus){
            sender.textColor = UIColor.lightGray
            
            fieldText = removeIcons(text: fieldText!)
            sender.text = fieldText
            message = NSLocalizedString("Part Of Event", comment: "")
            
        } else {
            sender.textColor = UIColor.lightGray
            sender.text = fieldText
            message = NSLocalizedString("None Of Event", comment: "")
        }
        
        return message;
    }

    func removeIcons(text : String)->String {
        
        var textValue = text
        
        textValue = textValue.replacingOccurrences(of: sawAllIcon, with: "")
        textValue = textValue.replacingOccurrences(of: sawSomeIcon, with: "")
        
        return textValue
        
    }
    
    func readLastScheduleDataWrite()-> Double{
        
        var lastPriorityDataWrite = Double(32503680000)
        
        if let data = try? String(contentsOf: lastScheduleDataWriteFile, encoding: String.Encoding.utf8) {
            lastPriorityDataWrite = Double(data)!
        }
        
        return lastPriorityDataWrite
    }
    
    func writeLastScheduleDataWrite(){
        
        let currentTime = String(Date().timeIntervalSince1970)
       
        do {
            try currentTime.write(to:lastScheduleDataWriteFile, atomically: false, encoding: String.Encoding.utf8)
            print ("writing ScheduleData Date")
        } catch _ {
            print ("writing ScheduleData Date, failed")
        }
    }
    
    // Helper to get the raw status (without timestamp)
    func getShowAttendedStatusRaw(index: String) -> String? {
        return showsAttendedQueue.sync {
            guard let value = self._showsAttendedArray[index] else { return nil }
            let parts = value.split(separator: ":")
            return parts.first.map { String($0) }
        }
    }
    
    // New: Get the last change timestamp for a show
    func getShowAttendedLastChange(index: String) -> Double {
        return showsAttendedQueue.sync {
            guard let value = self._showsAttendedArray[index] else { return 0 }
            let parts = value.split(separator: ":")
            if parts.count == 2, let ts = Double(parts[1]) { return ts }
            if parts.count == 3, let ts = Double(parts[2]) { return ts } // for iCloud format
            return 0
        }
    }
    
    // Returns the last change timestamp for a show, given its parameters
    func getShowAttendedStatusLastChange(
        band: String,
        location: String,
        startTime: String,
        eventType: String,
        eventYearString: String,
        scheduleDay: String? = nil
    ) -> Double {
        var eventTypeValue = eventType
        if eventType == unofficalEventTypeOld {
            eventTypeValue = unofficalEventType
        }
        let extendedIndex = resolveAttendanceStorageIndex(
            band: band,
            location: location,
            startTime: startTime,
            eventType: eventTypeValue,
            eventYearString: eventYearString,
            scheduleDay: scheduleDay
        )
        let baseIndex = AttendanceIndexKeys.baseKey(
            band: band,
            location: location,
            startTime: startTime,
            eventType: eventTypeValue,
            eventYearString: eventYearString
        )
        if extendedIndex != baseIndex {
            let extTs = getShowAttendedLastChange(index: extendedIndex)
            if extTs > 0 { return extTs }
        }
        return getShowAttendedLastChange(index: baseIndex)
    }
    
    // DEBUG: List all attendance keys for debugging
    func debugListAllAttendanceKeys() {
        showsAttendedQueue.sync {
            print("🔍 [ATTENDANCE_DEBUG] === ALL ATTENDANCE KEYS ===")
            let sortedKeys = self._showsAttendedArray.keys.sorted()
            for key in sortedKeys {
                let value = self._showsAttendedArray[key] ?? "nil"
                print("🔍 [ATTENDANCE_DEBUG] Key: '\(key)' -> Value: '\(value)'")
            }
            print("🔍 [ATTENDANCE_DEBUG] === TOTAL: \(sortedKeys.count) keys ===")
        }
    }
    
    /**
     Forces migration of all attended data to ensure proper timestamp format.
     This method should be called when restoring data from iCloud to ensure consistency.
     */
    func forceMigrationOfAllAttendedData() {
        print("ShowsAttended: Starting forced migration of all attended data")
        let currentArray = showsAttendedQueue.sync { self._showsAttendedArray }
        var needsMigration = false
        let currentTimestamp = String(format: "%.0f", Date().timeIntervalSince1970)
        
        for (key, value) in currentArray {
            let parts = value.split(separator: ":")
            if parts.count == 1 {
                // Old format: just status -> add timestamp
                mutateShowsAttendedArray { arr in arr[key] = value + ":" + currentTimestamp }
                needsMigration = true
                print("ShowsAttended: Migrated \(key) from old format to \(value):\(currentTimestamp)")
            } else if parts.count == 3 {
                // iCloud format: status:uid:timestamp -> convert to local format: status:timestamp
                let status = String(parts[0])
                let timestamp = String(parts[2])
                let localFormat = status + ":" + timestamp
                mutateShowsAttendedArray { arr in arr[key] = localFormat }
                needsMigration = true
                print("ShowsAttended: Migrated \(key) from iCloud format to local format: \(localFormat)")
            }
        }
        
        if needsMigration {
            print("ShowsAttended: Forced migration completed, saving changes")
            saveShowsAttended()
            // Update the static cache with migrated data
            staticAttended.async(flags: .barrier) {
                for (key, value) in self.showsAttendedArray {
                    cacheVariables.attendedStaticCache[key] = value
                }
            }
        } else {
            print("ShowsAttended: No migration needed")
        }
    }
    
}


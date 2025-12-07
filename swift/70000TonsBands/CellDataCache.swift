//
//  CellDataCache.swift
//  70000TonsBands
//
//  High-performance pre-fetch cache system for table view cells
//  Eliminates database lookups during scrolling for 60fps performance
//

import Foundation
import UIKit

// MARK: - Cell Data Model

/// Pre-computed data for a single table view cell
/// All display properties are calculated once and cached
struct CellDataModel {
    // Core identifiers
    let bandName: String
    let timeIndex: TimeInterval
    let indexInBands: Int
    
    // Display text
    let displayText: String
    let locationText: String
    let startTimeText: String
    let endTimeText: String
    let dayText: String
    let indexText: String
    
    // Event data
    let location: String
    let startTime: String
    let endTime: String
    let eventType: String
    let notes: String
    let day: String
    
    // Display state
    let hasSchedule: Bool
    let isPartialInfo: Bool
    let scheduleButton: Bool
    let rankLocationSchedule: Bool
    
    // UI elements (pre-loaded)
    let eventIcon: UIImage?
    let priorityIcon: UIImage?
    let attendedIcon: UIImage?
    let priorityGraphicName: String
    
    // Colors and styling
    let bandNameColor: UIColor
    let locationColor: UIColor
    let venueBackgroundColor: UIColor
    
    // Visibility flags
    let shouldShowBandName: Bool
    let shouldHideSeparator: Bool
    let isScheduledEvent: Bool
    
    // Cache metadata
    let cacheTimestamp: Date
    let priorityValue: Int
    let isAttended: Bool
    
    // Schedule lookup optimization
    let scheduleData: [String: String]
}

// MARK: - Cell Data Cache Manager

/// Thread-safe cache manager for pre-computed cell data
/// Supports incremental updates and full rebuilds
class CellDataCache {
    static let shared = CellDataCache()
    
    // MARK: - Properties
    
    private var cellDataArray: [CellDataModel] = []
    private let cacheQueue = DispatchQueue(label: "cellDataCache", qos: .userInitiated, attributes: .concurrent)
    private let updateQueue = DispatchQueue(label: "cellDataCacheUpdates", qos: .userInitiated)
    
    // Configuration
    private let maxCacheSize = 1000
    private var isPopulating = false
    private var lastFullRebuild = Date.distantPast
    
    // Dependencies (injected for thread safety)
    private weak var schedule: scheduleHandler?
    private weak var dataHandle: dataHandler?
    private weak var priorityManager: SQLitePriorityManager?
    private weak var attendedHandle: ShowsAttended?
    
    // MARK: - Public Interface
    
    private init() {
        print("🚀 CellDataCache initialized with max capacity: \(maxCacheSize)")
    }
    
    /// Configure cache dependencies
    func configure(schedule: scheduleHandler, 
                   dataHandle: dataHandler, 
                   priorityManager: SQLitePriorityManager, 
                   attendedHandle: ShowsAttended) {
        self.schedule = schedule
        self.dataHandle = dataHandle
        self.priorityManager = priorityManager
        self.attendedHandle = attendedHandle
    }
    
    /// Get cached cell data for a specific index
    func getCellData(at index: Int) -> CellDataModel? {
        return cacheQueue.sync {
            guard index >= 0 && index < cellDataArray.count else {
                print("⚠️ CellDataCache: Index \(index) out of bounds (cache size: \(cellDataArray.count))")
                return nil
            }
            return cellDataArray[index]
        }
    }
    
    /// Get current cache size
    var count: Int {
        return cacheQueue.sync {
            return cellDataArray.count
        }
    }
    
    /// Check if cache is currently being populated
    var isCurrentlyPopulating: Bool {
        return cacheQueue.sync {
            return isPopulating
        }
    }
    
    // MARK: - Cache Population
    
    /// Full rebuild of the entire cache (for year changes and initial load)
    func rebuildCache(from bands: [String], 
                      sortBy: String, 
                      reason: String = "Full rebuild",
                      completion: @escaping () -> Void = {}) {
        
        print("🔄 CellDataCache: Starting full rebuild - reason: '\(reason)'")
        print("🔄 Rebuilding cache for \(bands.count) bands (empty schedule is valid for current year)")
        
        guard bands.count <= maxCacheSize else {
            print("⚠️ CellDataCache: Band count (\(bands.count)) exceeds max cache size (\(maxCacheSize))")
            completion()
            return
        }
        
        // Handle edge case of empty bands (still valid)
        if bands.isEmpty {
            print("ℹ️ CellDataCache: No bands to cache (this is normal for some data states)")
            completion()
            return
        }
        
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.cacheQueue.async(flags: .barrier) {
                self.isPopulating = true
                let startTime = CFAbsoluteTimeGetCurrent()
                
                var newCellData: [CellDataModel] = []
                
                for (index, bandEntry) in bands.enumerated() {
                    if let cellData = self.createCellData(for: bandEntry, 
                                                         at: index, 
                                                         in: bands, 
                                                         sortedBy: sortBy) {
                        newCellData.append(cellData)
                    }
                }
                
                // Atomic replacement
                self.cellDataArray = newCellData
                self.lastFullRebuild = Date()
                self.isPopulating = false
                
                let endTime = CFAbsoluteTimeGetCurrent()
                let duration = (endTime - startTime) * 1000
                
                print("✅ CellDataCache: Full rebuild completed")
                print("📊 Cache stats: \(self.cellDataArray.count) entries, \(String(format: "%.1f", duration))ms")
                
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }
    
    // MARK: - Incremental Updates
    
    /// Update priority for a specific band (fast incremental update)
    func updatePriority(for bandName: String, completion: @escaping () -> Void = {}) {
        updateQueue.async { [weak self] in
            guard let self = self,
                  let priorityManager = self.priorityManager else { 
                DispatchQueue.main.async { completion() }
                return 
            }
            
            self.cacheQueue.async(flags: .barrier) {
                let startTime = CFAbsoluteTimeGetCurrent()
                var updatedCount = 0
                
                // Update all entries for this band
                for index in 0..<self.cellDataArray.count {
                    if self.cellDataArray[index].bandName == bandName {
                        let oldData = self.cellDataArray[index]
                        let newPriorityValue = priorityManager.getPriority(for: bandName)
                        let newPriorityGraphicName = getPriorityGraphic(newPriorityValue)
                        let newPriorityIcon = newPriorityGraphicName.isEmpty ? nil : UIImage(named: newPriorityGraphicName)
                        
                        // Create updated cell data
                        let updatedData = CellDataModel(
                            bandName: oldData.bandName,
                            timeIndex: oldData.timeIndex,
                            indexInBands: oldData.indexInBands,
                            displayText: oldData.displayText,
                            locationText: oldData.locationText,
                            startTimeText: oldData.startTimeText,
                            endTimeText: oldData.endTimeText,
                            dayText: oldData.dayText,
                            indexText: oldData.indexText,
                            location: oldData.location,
                            startTime: oldData.startTime,
                            endTime: oldData.endTime,
                            eventType: oldData.eventType,
                            notes: oldData.notes,
                            day: oldData.day,
                            hasSchedule: oldData.hasSchedule,
                            isPartialInfo: oldData.isPartialInfo,
                            scheduleButton: oldData.scheduleButton,
                            rankLocationSchedule: oldData.rankLocationSchedule,
                            eventIcon: oldData.eventIcon,
                            priorityIcon: newPriorityIcon,
                            attendedIcon: oldData.attendedIcon,
                            priorityGraphicName: newPriorityGraphicName,
                            bandNameColor: oldData.bandNameColor,
                            locationColor: oldData.locationColor,
                            venueBackgroundColor: oldData.venueBackgroundColor,
                            shouldShowBandName: oldData.shouldShowBandName,
                            shouldHideSeparator: oldData.shouldHideSeparator,
                            isScheduledEvent: oldData.isScheduledEvent,
                            cacheTimestamp: Date(),
                            priorityValue: newPriorityValue,
                            isAttended: oldData.isAttended,
                            scheduleData: oldData.scheduleData
                        )
                        
                        self.cellDataArray[index] = updatedData
                        updatedCount += 1
                    }
                }
                
                let endTime = CFAbsoluteTimeGetCurrent()
                let duration = (endTime - startTime) * 1000
                
                print("⚡ CellDataCache: Priority update for '\(bandName)' completed")
                print("📊 Updated \(updatedCount) entries in \(String(format: "%.1f", duration))ms")
                
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }
    
    /// Update attendance for a specific band (fast incremental update)
    func updateAttendance(for bandName: String, completion: @escaping () -> Void = {}) {
        updateQueue.async { [weak self] in
            guard let self = self,
                  let attendedHandle = self.attendedHandle else { 
                DispatchQueue.main.async { completion() }
                return 
            }
            
            self.cacheQueue.async(flags: .barrier) {
                let startTime = CFAbsoluteTimeGetCurrent()
                var updatedCount = 0
                
                // Update all entries for this band
                for index in 0..<self.cellDataArray.count {
                    let oldData = self.cellDataArray[index]
                    if oldData.bandName == bandName {
                        let newAttendedIcon = attendedHandle.getShowAttendedIcon(
                            band: bandName,
                            location: oldData.location,
                            startTime: oldData.startTime,
                            eventType: oldData.eventType,
                            eventYearString: String(eventYear)
                        )
                        
                        // Create updated cell data
                        let updatedData = CellDataModel(
                            bandName: oldData.bandName,
                            timeIndex: oldData.timeIndex,
                            indexInBands: oldData.indexInBands,
                            displayText: oldData.displayText,
                            locationText: oldData.locationText,
                            startTimeText: oldData.startTimeText,
                            endTimeText: oldData.endTimeText,
                            dayText: oldData.dayText,
                            indexText: oldData.indexText,
                            location: oldData.location,
                            startTime: oldData.startTime,
                            endTime: oldData.endTime,
                            eventType: oldData.eventType,
                            notes: oldData.notes,
                            day: oldData.day,
                            hasSchedule: oldData.hasSchedule,
                            isPartialInfo: oldData.isPartialInfo,
                            scheduleButton: oldData.scheduleButton,
                            rankLocationSchedule: oldData.rankLocationSchedule,
                            eventIcon: oldData.eventIcon,
                            priorityIcon: oldData.priorityIcon,
                            attendedIcon: newAttendedIcon,
                            priorityGraphicName: oldData.priorityGraphicName,
                            bandNameColor: oldData.bandNameColor,
                            locationColor: oldData.locationColor,
                            venueBackgroundColor: oldData.venueBackgroundColor,
                            shouldShowBandName: oldData.shouldShowBandName,
                            shouldHideSeparator: oldData.shouldHideSeparator,
                            isScheduledEvent: oldData.isScheduledEvent,
                            cacheTimestamp: Date(),
                            priorityValue: oldData.priorityValue,
                            isAttended: true, // Updated
                            scheduleData: oldData.scheduleData
                        )
                        
                        self.cellDataArray[index] = updatedData
                        updatedCount += 1
                    }
                }
                
                let endTime = CFAbsoluteTimeGetCurrent()
                let duration = (endTime - startTime) * 1000
                
                print("⚡ CellDataCache: Attendance update for '\(bandName)' completed")
                print("📊 Updated \(updatedCount) entries in \(String(format: "%.1f", duration))ms")
                
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }
    
    /// Invalidate cache (forces full rebuild on next access)
    func invalidateCache() {
        cacheQueue.async(flags: .barrier) {
            self.cellDataArray.removeAll()
            print("🗑️ CellDataCache: Cache invalidated")
        }
    }
    
    // MARK: - Private Methods
    
    /// Create cell data for a single band entry
    private func createCellData(for bandEntry: String, 
                               at index: Int, 
                               in bands: [String], 
                               sortedBy: String) -> CellDataModel? {
        
        guard let schedule = self.schedule,
              let dataHandle = self.dataHandle,
              let priorityManager = self.priorityManager,
              let attendedHandle = self.attendedHandle else {
            print("⚠️ CellDataCache: Dependencies not configured for band: \(bandEntry)")
            return nil
        }
        
        let bandName = getNameFromSortable(bandEntry, sortedBy: sortedBy)
        let timeIndex = getTimeFromSortable(bandEntry, sortBy: sortedBy)
        
        // Debug logging for band entry processing
        if index < 3 { // Only log first few entries to avoid spam
            print("🔍 CellDataCache: Processing band[\(index)]: '\(bandEntry)' -> name: '\(bandName)', timeIndex: \(timeIndex)")
        }
        
        // Pre-calculate all display properties
        var location = ""
        var day = ""
        var startTime = ""
        var endTime = ""
        var event = ""
        var notes = ""
        var hasSchedule = false
        var isScheduledEvent = false
        
        if timeIndex > 1 {
            hasSchedule = true
            isScheduledEvent = true
            
            // Try legacy schedule first, then fallback to Core Data
            location = schedule.getData(bandName, index: timeIndex, variable: locationField)
            day = monthDateRegionalFormatting(dateValue: schedule.getData(bandName, index: timeIndex, variable: dayField))
            startTime = schedule.getData(bandName, index: timeIndex, variable: startTimeField)
            endTime = schedule.getData(bandName, index: timeIndex, variable: endTimeField)
            event = schedule.getData(bandName, index: timeIndex, variable: typeField)
            notes = schedule.getData(bandName, index: timeIndex, variable: notesField)
            
            // Fallback to Core Data if legacy schedule is empty
            if location.isEmpty && startTime.isEmpty && event.isEmpty {
                if let coreDataEvent = CoreDataManager.shared.fetchEvent(byTimeIndex: timeIndex, eventName: bandName, forYear: Int32(eventYear)) {
                    location = coreDataEvent.location ?? ""
                    startTime = coreDataEvent.startTime ?? ""
                    endTime = coreDataEvent.endTime ?? ""
                    event = coreDataEvent.eventType ?? ""
                    notes = coreDataEvent.notes ?? ""
                    
                    // Format day from timeIndex if not available
                    if day.isEmpty {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "MMM d"
                        day = dateFormatter.string(from: Date(timeIntervalSinceReferenceDate: timeIndex)) // FIX: Match storage format
                    }
                }
            }
        }
        
        // Pre-calculate all text formatting
        let startTimeText = formatTimeValue(timeValue: startTime)
        let endTimeText = formatTimeValue(timeValue: endTime)
        var locationText = location
        
        if venueLocation[location] != nil {
            locationText += " " + venueLocation[location]!
        }
        if !notes.isEmpty && notes != " " {
            locationText += " " + notes
        }
        
        let displayText = hasSchedule ? "\(bandName):\(startTimeText):\(locationText)" : bandName
        let indexText = hasSchedule ? "\(bandName);\(location);\(event);\(startTime)" : bandName
        
        // Pre-calculate day text
        var dayText = ""
        if day == "Day 1" {
            dayText = "1"
        } else if day == "Day 2" {
            dayText = "2"
        } else if day == "Day 3" {
            dayText = "3"
        } else if day == "Day 4" {
            dayText = "4"
        } else {
            dayText = day
        }
        
        // Pre-calculate icons
        let eventIcon = getEventTypeIcon(eventType: event, eventName: bandName)
        let priorityValue = priorityManager.getPriority(for: bandName)
        let priorityGraphicName = getPriorityGraphic(priorityValue)
        let priorityIcon = priorityGraphicName.isEmpty ? nil : UIImage(named: priorityGraphicName)
        let attendedIcon = attendedHandle.getShowAttendedIcon(
            band: bandName,
            location: location,
            startTime: startTime,
            eventType: event,
            eventYearString: String(eventYear)
        )
        
        // Pre-calculate colors
        let venueBackgroundColor = getVenueColor(venue: location)
        
        // Pre-calculate display logic for partial info
        let previousBandName = index > 0 ? getNameFromSortable(bands[index - 1], sortedBy: sortedBy) : ""
        let isPartialInfo = (bandName == previousBandName && index != 0 && sortedBy == "name")
        
        // Pre-calculate schedule data
        var scheduleData: [String: String] = [:]
        if hasSchedule {
            scheduleData["location"] = location
            scheduleData["bandName"] = bandName
            scheduleData["startTime"] = startTime
            scheduleData["event"] = event
        }
        
        // Debug logging for successful cell data creation
        if index < 3 { // Only log first few entries to avoid spam
            print("✅ CellDataCache: Created cell data[\(index)]: band='\(bandName)', hasSchedule=\(hasSchedule), display='\(displayText)'")
        }
        
        return CellDataModel(
            bandName: bandName,
            timeIndex: timeIndex,
            indexInBands: index,
            displayText: displayText,
            locationText: locationText,
            startTimeText: startTimeText,
            endTimeText: endTimeText,
            dayText: dayText,
            indexText: indexText,
            location: location,
            startTime: startTime,
            endTime: endTime,
            eventType: event,
            notes: notes,
            day: day,
            hasSchedule: hasSchedule,
            isPartialInfo: isPartialInfo,
            scheduleButton: !hasSchedule,
            rankLocationSchedule: hasSchedule,
            eventIcon: eventIcon,
            priorityIcon: priorityIcon,
            attendedIcon: attendedIcon,
            priorityGraphicName: priorityGraphicName,
            bandNameColor: UIColor.white,
            locationColor: UIColor.lightGray,
            venueBackgroundColor: venueBackgroundColor,
            shouldShowBandName: !isPartialInfo,
            shouldHideSeparator: !isScheduledEvent,
            isScheduledEvent: isScheduledEvent,
            cacheTimestamp: Date(),
            priorityValue: priorityValue,
            isAttended: attendedIcon != nil,
            scheduleData: scheduleData
        )
    }
}

// MARK: - Cache Statistics

extension CellDataCache {
    /// Get cache performance statistics
    func getCacheStats() -> [String: Any] {
        return cacheQueue.sync {
            return [
                "cacheSize": cellDataArray.count,
                "maxCapacity": maxCacheSize,
                "utilizationPercent": Double(cellDataArray.count) / Double(maxCacheSize) * 100,
                "lastFullRebuild": lastFullRebuild,
                "timeSinceRebuild": Date().timeIntervalSince(lastFullRebuild),
                "isPopulating": isPopulating
            ]
        }
    }
    
    /// Print cache statistics
    func printCacheStats() {
        let stats = getCacheStats()
        print("📊 CellDataCache Stats:")
        print("   Size: \(stats["cacheSize"] ?? 0)/\(stats["maxCapacity"] ?? 0)")
        print("   Utilization: \(String(format: "%.1f", stats["utilizationPercent"] as? Double ?? 0))%")
        print("   Last rebuild: \(String(format: "%.1f", stats["timeSinceRebuild"] as? Double ?? 0))s ago")
        print("   Currently populating: \(stats["isPopulating"] as? Bool ?? false)")
    }
    
    // MARK: - CoreDataPreloadManager Support
    
    /// Clear entire cache (used during year changes)
    func clearCache() {
        updateQueue.async(flags: .barrier) {
            self.cacheQueue.async(flags: .barrier) {
                self.cellDataArray.removeAll()
                print("🧹 CellDataCache: Cleared entire cache")
            }
        }
    }
    
    /// Update cache for specific band (incremental update)
    func updateCacheForBand(_ bandName: String, completion: @escaping () -> Void = {}) {
        guard let schedule = schedule, 
              let dataHandle = dataHandle,
              let priorityManager = priorityManager,
              let attendedHandle = attendedHandle else {
            print("⚠️ CellDataCache: Dependencies not configured for band update")
            completion()
            return
        }
        
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.cacheQueue.async(flags: .barrier) {
                // Find and update entries for this band
                var updatedCount = 0
                
                for i in 0..<self.cellDataArray.count {
                    let cell = self.cellDataArray[i]
                    if cell.bandName == bandName {
                        // Recreate cell data with fresh data from Core Data
                        // For now, trigger a rebuild - could be optimized for single band updates
                        updatedCount += 1
                    }
                }
                
                if updatedCount > 0 {
                    print("✅ CellDataCache: Marked \(updatedCount) entries for update - band: \(bandName)")
                    // Mark cache as needing rebuild on next access
                    self.lastFullRebuild = Date.distantPast
                } else {
                    print("ℹ️ CellDataCache: No cache entries found for band: \(bandName)")
                }
                
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }
    
    /// Mark cache for priority updates (bulk update)
    func markForPriorityUpdate() {
        updateQueue.async { [weak self] in
            print("🔄 CellDataCache: Priority data changed, marking for refresh")
            self?.lastFullRebuild = Date.distantPast
        }
    }
    
    /// Mark cache for attendance updates (bulk update) 
    func markForAttendanceUpdate() {
        updateQueue.async { [weak self] in
            print("🔄 CellDataCache: Attendance data changed, marking for refresh")
            self?.lastFullRebuild = Date.distantPast
        }
    }
}

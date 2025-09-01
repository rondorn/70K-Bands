//
//  IndependentDataCollectors.swift
//  70K Bands
//
//  Created by Ron Dorn on 1/7/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import UIKit

// Import required functions and variables from other files
// These are defined in other files but needed here

// MARK: - Independent Data Collector Protocol

/// Protocol that all independent data collectors must implement
protocol IndependentDataCollector {
    var collectorName: String { get }
    var isCollecting: Bool { get }
    var lastCollectionTime: TimeInterval { get }
    
    /// Start data collection independently
    func startCollection(eventYearOverride: Bool, completion: @escaping (Bool) -> Void)
    
    /// Cancel any ongoing collection
    func cancelCollection()
    
    /// Get cached data without triggering collection
    func getCachedData() -> Any?
    
    /// Check if data is available
    func isDataAvailable() -> Bool
}

// MARK: - Base Independent Collector

/// Base class for all independent data collectors
class BaseIndependentCollector: IndependentDataCollector {
    let collectorName: String
    private var _isCollecting = false
    private var _lastCollectionTime: TimeInterval = 0
    private let collectionQueue = DispatchQueue(label: "com.70kBands.collector.\(UUID().uuidString)", qos: .userInitiated)
    private var currentCollectionWorkItem: DispatchWorkItem?
    
    var isCollecting: Bool {
        collectionQueue.sync { _isCollecting }
    }
    
    var lastCollectionTime: TimeInterval {
        collectionQueue.sync { _lastCollectionTime }
    }
    
    init(collectorName: String) {
        self.collectorName = collectorName
    }
    
    func startCollection(eventYearOverride: Bool, completion: @escaping (Bool) -> Void) {
        collectionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Prevent multiple simultaneous collections
            if self._isCollecting {
                print("[\(self.collectorName)] Already collecting, ignoring request")
                completion(false)
                return
            }
            
            self._isCollecting = true
            self._lastCollectionTime = Date().timeIntervalSince1970
            
            // Create timeout work item
            let timeoutWorkItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                print("[\(self.collectorName)] Collection timeout - cancelling")
                self._isCollecting = false
                completion(false)
            }
            
            self.currentCollectionWorkItem = timeoutWorkItem
            
            // Start collection with timeout
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 30, execute: timeoutWorkItem)
            
            // Perform actual collection
            self.performCollection(eventYearOverride: eventYearOverride) { [weak self] success in
                guard let self = self else { return }
                
                self.collectionQueue.async {
                    self._isCollecting = false
                    self.currentCollectionWorkItem?.cancel()
                    self.currentCollectionWorkItem = nil
                    completion(success)
                }
            }
        }
    }
    
    func cancelCollection() {
        collectionQueue.async { [weak self] in
            guard let self = self else { return }
            self.currentCollectionWorkItem?.cancel()
            self.currentCollectionWorkItem = nil
            self._isCollecting = false
        }
    }
    
    func getCachedData() -> Any? {
        // Override in subclasses
        return nil
    }
    
    func isDataAvailable() -> Bool {
        // Override in subclasses
        return false
    }
    
    // Override in subclasses to implement actual collection logic
    func performCollection(eventYearOverride: Bool, completion: @escaping (Bool) -> Void) {
        completion(false)
    }
}

// MARK: - Independent Band Names Collector

class IndependentBandNamesCollector: BaseIndependentCollector {
    private var bandNames: [String: [String: String]] = [:]
    private var bandNamesArray: [String] = []
    private let bandNamesLock = NSLock()
    
    init() {
        super.init(collectorName: "BandNames")
        loadCachedData()
    }
    
    override func getCachedData() -> Any? {
        bandNamesLock.lock()
        defer { bandNamesLock.unlock() }
        return (bandNames, bandNamesArray)
    }
    
    override func isDataAvailable() -> Bool {
        bandNamesLock.lock()
        defer { bandNamesLock.unlock() }
        return !bandNames.isEmpty
    }
    
    private func loadCachedData() {
        // Load from static cache first
        if !cacheVariables.bandNamesStaticCache.isEmpty {
            bandNamesLock.lock()
            bandNames = cacheVariables.bandNamesStaticCache
            bandNamesArray = cacheVariables.bandNamesArrayStaticCache
            bandNamesLock.unlock()
            return
        }
        
        // Load from file if available
        if FileManager.default.fileExists(atPath: bandFile) {
            readBandFile()
        }
    }
    
    override func performCollection(eventYearOverride: Bool, completion: @escaping (Bool) -> Void) {
        print("[BandNames] Starting independent collection")
        
        // Download band data
        let artistUrl = getPointerUrlData(keyValue: "artistUrl") ?? "http://dropbox.com"
        let httpData = getUrlData(urlString: artistUrl)
        
        if !httpData.isEmpty {
            writeBandFile(httpData)
            readBandFile()
            
            // Update static cache
            bandNamesLock.lock()
            cacheVariables.bandNamesStaticCache = bandNames
            cacheVariables.bandNamesArrayStaticCache = bandNamesArray
            bandNamesLock.unlock()
            
            completion(true)
        } else {
            print("[BandNames] No data downloaded")
            completion(false)
        }
    }
    
    private func readBandFile() {
        guard let csvDataString = try? String(contentsOfFile: bandFile, encoding: .utf8) else {
            print("[BandNames] Could not read band file")
            return
        }
        
        let csvData = try! CSV(csvStringToParse: csvDataString)
        var tempBandNames: [String: [String: String]] = [:]
        var tempBandNamesArray: [String] = []
        
        for lineData in csvData.rows {
            guard let bandNameValue = lineData["bandName"], !bandNameValue.isEmpty else { continue }
            
            var bandDict: [String: String] = [:]
            for (key, value) in lineData {
                if !value.isEmpty {
                    bandDict[key] = value
                }
            }
            
            tempBandNames[bandNameValue] = bandDict
            tempBandNamesArray.append(bandNameValue)
        }
        
        bandNamesLock.lock()
        bandNames = tempBandNames
        bandNamesArray = tempBandNamesArray.sorted()
        bandNamesLock.unlock()
        
        print("[BandNames] Processed \(bandNames.count) bands")
    }
    
    private func writeBandFile(_ data: String) {
        do {
            try data.write(toFile: bandFile, atomically: false, encoding: .utf8)
        } catch {
            print("[BandNames] Error writing band file: \(error)")
        }
    }
}

// MARK: - Independent Schedule Collector

class IndependentScheduleCollector: BaseIndependentCollector {
    private var schedulingData: [String: [TimeInterval: [String: String]]] = [:]
    private var schedulingDataByTime: [TimeInterval: [[String: String]]] = [:]
    private let scheduleLock = NSLock()
    
    init() {
        super.init(collectorName: "Schedule")
        loadCachedData()
    }
    
    override func getCachedData() -> Any? {
        scheduleLock.lock()
        defer { scheduleLock.unlock() }
        return (schedulingData, schedulingDataByTime)
    }
    
    override func isDataAvailable() -> Bool {
        scheduleLock.lock()
        defer { scheduleLock.unlock() }
        return !schedulingData.isEmpty
    }
    
    private func loadCachedData() {
        // Load from static cache first
        if !cacheVariables.scheduleStaticCache.isEmpty {
            scheduleLock.lock()
            schedulingData = cacheVariables.scheduleStaticCache
            schedulingDataByTime = cacheVariables.scheduleTimeStaticCache
            scheduleLock.unlock()
            return
        }
        
        // Load from file if available
        if FileManager.default.fileExists(atPath: scheduleFile) {
            processScheduleFile()
        }
    }
    
    override func performCollection(eventYearOverride: Bool, completion: @escaping (Bool) -> Void) {
        print("[Schedule] Starting independent collection")
        
        // Download schedule data
        let scheduleUrl = getPointerUrlData(keyValue: "scheduleUrl")
        let httpData = getUrlData(urlString: scheduleUrl)
        
        if !httpData.isEmpty {
            writeScheduleFile(httpData)
            processScheduleFile()
            
            // Update static cache
            scheduleLock.lock()
            cacheVariables.scheduleStaticCache = schedulingData
            cacheVariables.scheduleTimeStaticCache = schedulingDataByTime
            scheduleLock.unlock()
            
            completion(true)
        } else {
            print("[Schedule] No data downloaded")
            completion(false)
        }
    }
    
    private func processScheduleFile() {
        guard let csvDataString = try? String(contentsOfFile: scheduleFile, encoding: .utf8) else {
            print("[Schedule] Could not read schedule file")
            return
        }
        
        let csvData = try! CSV(csvStringToParse: csvDataString)
        var tempSchedulingData: [String: [TimeInterval: [String: String]]] = [:]
        var tempSchedulingDataByTime: [TimeInterval: [[String: String]]] = [:]
        var uniqueIndex: [TimeInterval: Int] = [:]
        
        for lineData in csvData.rows {
            guard let dateValue = lineData[dateField], !dateValue.isEmpty,
                  let timeValue = lineData[startTimeField], !timeValue.isEmpty,
                  let bandValue = lineData[bandField], !bandValue.isEmpty else { continue }
            
            var dateIndex = getDateIndex(dateValue, timeString: timeValue, band: bandValue)
            
            // Ensure unique index
            while uniqueIndex[dateIndex] == 1 {
                dateIndex += 1
            }
            uniqueIndex[dateIndex] = 1
            
            // Initialize nested dictionaries
            if tempSchedulingData[bandValue] == nil {
                tempSchedulingData[bandValue] = [:]
            }
            if tempSchedulingData[bandValue]?[dateIndex] == nil {
                tempSchedulingData[bandValue]?[dateIndex] = [:]
            }
            
            // Set data
            tempSchedulingData[bandValue]?[dateIndex]?[dayField] = lineData[dayField] ?? ""
            tempSchedulingData[bandValue]?[dateIndex]?[startTimeField] = timeValue
            tempSchedulingData[bandValue]?[dateIndex]?[endTimeField] = lineData[endTimeField] ?? ""
            tempSchedulingData[bandValue]?[dateIndex]?[dateField] = dateValue
            tempSchedulingData[bandValue]?[dateIndex]?[typeField] = lineData[typeField] ?? ""
            tempSchedulingData[bandValue]?[dateIndex]?[notesField] = lineData[notesField] ?? ""
            tempSchedulingData[bandValue]?[dateIndex]?[locationField] = lineData[locationField] ?? ""
            
            // Add to time-sorted data - store as array to prevent data loss
            if tempSchedulingDataByTime[dateIndex] == nil {
                tempSchedulingDataByTime[dateIndex] = []
            }
            var eventData = [String: String]()
            eventData[bandField] = bandValue
            eventData[locationField] = lineData[locationField] ?? ""
            eventData[dateField] = lineData[dateField] ?? ""
            eventData[dayField] = lineData[dayField] ?? ""
            eventData[startTimeField] = lineData[startTimeField] ?? ""
            eventData[endTimeField] = lineData[endTimeField] ?? ""
            eventData[typeField] = lineData[typeField] ?? ""
            eventData[notesField] = lineData[notesField] ?? ""
            tempSchedulingDataByTime[dateIndex]!.append(eventData)
        }
        
        scheduleLock.lock()
        schedulingData = tempSchedulingData
        schedulingDataByTime = tempSchedulingDataByTime
        scheduleLock.unlock()
        
        print("[Schedule] Processed \(schedulingData.count) bands with schedule data")
    }
    
    private func writeScheduleFile(_ data: String) {
        do {
            try data.write(toFile: scheduleFile, atomically: false, encoding: .utf8)
        } catch {
            print("[Schedule] Error writing schedule file: \(error)")
        }
    }
    
    private func getDateIndex(_ dateString: String, timeString: String, band: String) -> TimeInterval {
        let fullTimeString = "\(dateString) \(timeString)"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M-d-yy HH:mm"
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        return dateFormatter.date(from: fullTimeString)?.timeIntervalSince1970 ?? 0
    }
}

// MARK: - Independent Shows Attended Collector

class IndependentShowsAttendedCollector: BaseIndependentCollector {
    private var showsAttendedArray: [String: String] = [:]
    private let attendedLock = NSLock()
    
    init() {
        super.init(collectorName: "ShowsAttended")
        loadCachedData()
    }
    
    override func getCachedData() -> Any? {
        attendedLock.lock()
        defer { attendedLock.unlock() }
        return showsAttendedArray
    }
    
    override func isDataAvailable() -> Bool {
        attendedLock.lock()
        defer { attendedLock.unlock() }
        return !showsAttendedArray.isEmpty
    }
    
    private func loadCachedData() {
        // Load from file if available
        if FileManager.default.fileExists(atPath: showsAttended) {
            loadShowsAttended()
        }
    }
    
    override func performCollection(eventYearOverride: Bool, completion: @escaping (Bool) -> Void) {
        print("[ShowsAttended] Starting independent collection")
        
        // For shows attended, we just need to ensure data is loaded
        // No network download needed - it's user-generated data
        loadShowsAttended()
        completion(true)
    }
    
    private func loadShowsAttended() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: showsAttended)),
              let loadedArray = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            print("[ShowsAttended] Could not load shows attended data")
            return
        }
        
        attendedLock.lock()
        showsAttendedArray = loadedArray
        attendedLock.unlock()
        
        print("[ShowsAttended] Loaded \(showsAttendedArray.count) attended shows")
    }
}

// MARK: - Independent Priority Collector

class IndependentPriorityCollector: BaseIndependentCollector {
    private var bandPriorityStorage: [String: Int] = [:]
    private var bandPriorityTimestamps: [String: Double] = [:]
    private let priorityLock = NSLock()
    
    init() {
        super.init(collectorName: "Priority")
        loadCachedData()
    }
    
    override func getCachedData() -> Any? {
        priorityLock.lock()
        defer { priorityLock.unlock() }
        return (bandPriorityStorage, bandPriorityTimestamps)
    }
    
    override func isDataAvailable() -> Bool {
        priorityLock.lock()
        defer { priorityLock.unlock() }
        return !bandPriorityStorage.isEmpty
    }
    
    private func loadCachedData() {
        // Load from static cache first
        if !cacheVariables.bandPriorityStorageCache.isEmpty {
            priorityLock.lock()
            bandPriorityStorage = cacheVariables.bandPriorityStorageCache
            priorityLock.unlock()
            return
        }
        
        // Load from file if available
        if FileManager.default.fileExists(atPath: priorityFile) {
            loadPriorityData()
        }
    }
    
    override func performCollection(eventYearOverride: Bool, completion: @escaping (Bool) -> Void) {
        print("[Priority] Starting independent collection")
        
        // For priority data, we just need to ensure data is loaded
        // No network download needed - it's user-generated data
        loadPriorityData()
        completion(true)
    }
    
    private func loadPriorityData() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: priorityFile)),
              let loadedStorage = try? JSONSerialization.jsonObject(with: data) as? [String: Int] else {
            print("[Priority] Could not load priority data")
            return
        }
        
        priorityLock.lock()
        bandPriorityStorage = loadedStorage
        priorityLock.unlock()
        
        print("[Priority] Loaded \(bandPriorityStorage.count) priority entries")
    }
}

// MARK: - Independent Data Collection Manager

/// Manages all independent data collectors
public class IndependentDataCollectionManager {
    public static let shared = IndependentDataCollectionManager()
    
    private let collectors: [IndependentDataCollector]
    private let managerQueue = DispatchQueue(label: "com.70kBands.independentManager", qos: .userInitiated)
    
    private init() {
        // Initialize all independent collectors
        collectors = [
            IndependentBandNamesCollector(),
            IndependentScheduleCollector(),
            IndependentShowsAttendedCollector(),
            IndependentPriorityCollector()
        ]
    }
    
    /// Start all data collection in parallel
    public func startAllCollections(eventYearOverride: Bool = false, completion: @escaping () -> Void) {
        print("[IndependentManager] Starting all collections in parallel")
        
        let group = DispatchGroup()
        
        for collector in collectors {
            group.enter()
            collector.startCollection(eventYearOverride: eventYearOverride) { success in
                print("[\(collector.collectorName)] Collection completed with success: \(success)")
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            print("[IndependentManager] All collections completed")
            completion()
        }
    }
    
    /// Start specific collector
    public func startCollection(for collectorName: String, eventYearOverride: Bool = false, completion: @escaping (Bool) -> Void) {
        guard let collector = collectors.first(where: { $0.collectorName == collectorName }) else {
            print("[IndependentManager] Collector not found: \(collectorName)")
            completion(false)
            return
        }
        
        collector.startCollection(eventYearOverride: eventYearOverride, completion: completion)
    }
    
    /// Cancel all collections
    public func cancelAllCollections() {
        for collector in collectors {
            collector.cancelCollection()
        }
    }
    
    /// Get status of all collectors
    func getCollectionStatus() -> [String: Bool] {
        var status: [String: Bool] = [:]
        for collector in collectors {
            status[collector.collectorName] = collector.isCollecting
        }
        return status
    }
} 

// MARK: - Integration Examples

extension IndependentDataCollectionManager {
    
    /// Example: How to replace the old coupled data loading with independent collectors
    func exampleReplaceOldDataLoading() {
        // OLD WAY (causes race conditions):
        // bandNamesHandler.shared.getCachedData { ... }
        // scheduleHandler.shared.getCachedData()
        // ShowsAttended().getCachedData()
        // dataHandler().getCachedData()
        
        // NEW WAY (truly independent):
        startAllCollections { [weak self] in
            print("All data loaded independently!")
            
            // Check status of each collector
            let status = self?.getCollectionStatus() ?? [:]
            for (name, isCollecting) in status {
                print("\(name): \(isCollecting ? "Collecting" : "Idle")")
            }
        }
    }
    
    /// Example: Load only specific data types
    func exampleLoadSpecificData() {
        // Load only band names and schedule (most important)
        let group = DispatchGroup()
        
        group.enter()
        startCollection(for: "BandNames") { success in
            print("Band names loaded: \(success)")
            group.leave()
        }
        
        group.enter()
        startCollection(for: "Schedule") { success in
            print("Schedule loaded: \(success)")
            group.leave()
        }
        
        group.notify(queue: .main) {
            print("Critical data loaded!")
        }
    }
    
    /// Example: Handle year change with independent collectors
    func exampleYearChange() {
        // Cancel all current collections
        cancelAllCollections()
        
        // Start fresh collections for new year
        startAllCollections(eventYearOverride: true) {
            print("Year change data loading complete!")
        }
    }
}

 
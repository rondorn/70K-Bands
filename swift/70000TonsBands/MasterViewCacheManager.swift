//
//  MasterViewCacheManager.swift
//  70K Bands
//
//  Created by Refactoring
//  Copyright (c) 2026 Ron Dorn. All rights reserved.
//

import Foundation
import UIKit

/// Cache Manager for MasterViewController
/// Handles all cache clearing, loading, and management operations
class MasterViewCacheManager {
    
    // MARK: - Dependencies
    private let schedule: scheduleHandler
    private let bandNameHandle: bandNamesHandler
    private let dataHandle: dataHandler
    private let attendedHandle: ShowsAttended
    private let bandDescriptions: CustomBandDescription
    
    // MARK: - Cache State
    private var lastBandNamesCacheRefresh: Date? = nil
    private let minCacheRefreshInterval: TimeInterval = 2.0 // Minimum time between cache refreshes
    
    // MARK: - Initialization
    init(
        schedule: scheduleHandler,
        bandNameHandle: bandNamesHandler,
        dataHandle: dataHandler,
        attendedHandle: ShowsAttended,
        bandDescriptions: CustomBandDescription
    ) {
        self.schedule = schedule
        self.bandNameHandle = bandNameHandle
        self.dataHandle = dataHandle
        self.attendedHandle = attendedHandle
        self.bandDescriptions = bandDescriptions
    }
    
    // MARK: - Cache Configuration
    
    /// Configures CellDataCache with required dependencies
    func configureCellDataCache(priorityManager: SQLitePriorityManager) {
        print("🔧 [CACHE_CONFIG] Configuring CellDataCache dependencies")
        CellDataCache.shared.configure(
            schedule: schedule,
            dataHandle: dataHandle,
            priorityManager: priorityManager,
            attendedHandle: attendedHandle
        )
        print("🔧 [CACHE_CONFIG] CellDataCache configured successfully")
    }
    
    // MARK: - Cache Clearing
    
    /// Clears all caches comprehensively - used during data refresh
    /// Clears handler caches, static cache variables, and instance caches
    func clearAllCaches() {
        print("🧹 Clearing all caches comprehensively")
        
        // Clear handler caches
        bandNameHandle.clearCachedData()
        // LEGACY: Priority cache clearing now handled by PriorityManager if needed
        dataHandle.clearCachedData()
        schedule.clearCache()
        
        // ✅ DEADLOCK FIX: Clear cache without sync block - SQLite is thread-safe
        // Clear ALL static cache variables to prevent data mixing
        cacheVariables.scheduleStaticCache = [:]
        cacheVariables.scheduleTimeStaticCache = [:]
        cacheVariables.bandNamesStaticCache = [:]
        cacheVariables.bandNamesArrayStaticCache = []
        cacheVariables.bandDescriptionUrlCache = [:]
        cacheVariables.bandDescriptionUrlDateCache = [:]
        cacheVariables.attendedStaticCache = [:]
        cacheVariables.lastModifiedDate = nil
        
        // Clear CustomBandDescription instance caches
        bandDescriptions.bandDescriptionUrl.removeAll()
        bandDescriptions.bandDescriptionUrlDate.removeAll()
        
        print("🧹 All caches cleared successfully")
    }
    
    /// Clears MasterViewController-specific cached data arrays
    /// Note: Does not clear the bands array - it should be cleared and repopulated atomically
    func clearMasterViewCachedData(objects: inout NSMutableArray, bandsByTime: inout [String], bandsByName: inout [String]) {
        print("[YEAR_CHANGE_DEBUG] Clearing MasterViewController cached data arrays")
        
        // Clear other arrays that don't affect the table view
        objects.removeAllObjects()
        bandsByTime.removeAll()
        bandsByName.removeAll()
        
        // Don't clear the bands array here - it should be cleared and immediately repopulated
        // in the calling method to prevent race conditions
        print("[YEAR_CHANGE_DEBUG] Note: bands array should be cleared and repopulated atomically")
    }
    
    /// Clears all static caches used by MasterViewController
    func clearStaticCaches() {
        print("🧹 Clearing static caches")
        
        cacheVariables.bandNamesStaticCache.removeAll()
        cacheVariables.bandNamesArrayStaticCache.removeAll()
        CellDataCache.shared.clearCache()
        
        print("🧹 Static caches cleared successfully")
    }
    
    /// Clears all caches including MasterViewController arrays
    func clearAllCachesAndMasterViewData(
        objects: inout NSMutableArray,
        bands: inout [String],
        bandsByTime: inout [String],
        bandsByName: inout [String]
    ) {
        print("🔄 [PROFILE] Clearing all caches and MasterView data...")
        
        // Clear MasterViewController arrays
        bands.removeAll()
        bandsByTime.removeAll()
        bandsByName.removeAll()
        objects.removeAllObjects()
        
        // Clear static caches
        clearStaticCaches()
        
        // Clear handler caches
        clearAllCaches()
        
        print("🔄 [PROFILE] All caches and MasterView data cleared")
    }
    
    // MARK: - Cache Loading
    
    /// Loads cached data from all handlers
    /// This is a synchronous operation that reads from cache/database
    func loadCachedData() {
        print("📥 Loading cached data from all handlers")
        
        // Load band names
        bandNameHandle.readBandFile()
        
        // Load schedule data
        schedule.getCachedData()
        
        // LEGACY: Priority data now handled by SQLitePriorityManager
        // dataHandle.getCachedData()
        
        print("📥 Cached data loaded successfully")
    }
    
    /// Loads cached data immediately (synchronous, blocking)
    /// Used when immediate data access is needed
    func loadCachedDataImmediately() {
        print("📥 Loading cached data immediately (synchronous)")
        
        bandNameHandle.loadCachedDataImmediately()
        schedule.loadCachedDataImmediately()
        
        print("📥 Immediate cached data load complete")
    }
    
    /// Loads attended data in background (non-blocking)
    /// This is called separately as it's less critical for UI updates
    func loadAttendedDataInBackground() {
        print("📥 Loading attended data in background")
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            let attendedStartTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", attendedStartTime))] Starting attended data load in background")
            self.attendedHandle.getCachedData()
            let attendedEndTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", attendedEndTime))] Attended data load END - time: \(String(format: "%.3f", (attendedEndTime - attendedStartTime) * 1000))ms")
        }
    }
    
    // MARK: - Cache Refresh Throttling
    
    /// Checks if cache refresh should be throttled based on last refresh time
    /// - Returns: True if refresh should be skipped (too recent), false if refresh is allowed
    func shouldThrottleCacheRefresh() -> Bool {
        let now = Date()
        
        if let lastRefresh = lastBandNamesCacheRefresh {
            let timeSinceLastRefresh = now.timeIntervalSince(lastRefresh)
            if timeSinceLastRefresh < minCacheRefreshInterval {
                print("Skipping cache refresh: Last refresh was too recent (\(String(format: "%.2f", timeSinceLastRefresh)) seconds ago)")
                return true
            }
        }
        
        // Update last refresh time
        lastBandNamesCacheRefresh = now
        return false
    }
    
    /// Resets the cache refresh throttle timer
    func resetCacheRefreshThrottle() {
        lastBandNamesCacheRefresh = Date()
    }
    
    // MARK: - Cache State Queries
    
    /// Checks if cache refresh is needed based on time elapsed
    /// - Parameter minInterval: Minimum time interval between refreshes
    /// - Returns: True if refresh is needed, false if too soon
    func isCacheRefreshNeeded(minInterval: TimeInterval = 2.0) -> Bool {
        guard let lastRefresh = lastBandNamesCacheRefresh else {
            return true // Never refreshed, allow refresh
        }
        
        let timeSinceLastRefresh = Date().timeIntervalSince(lastRefresh)
        return timeSinceLastRefresh >= minInterval
    }
    
    /// Gets the time since last cache refresh
    /// - Returns: Time interval since last refresh, or nil if never refreshed
    func timeSinceLastCacheRefresh() -> TimeInterval? {
        guard let lastRefresh = lastBandNamesCacheRefresh else {
            return nil
        }
        return Date().timeIntervalSince(lastRefresh)
    }
}

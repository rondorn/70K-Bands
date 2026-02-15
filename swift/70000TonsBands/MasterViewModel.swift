//
//  MasterViewModel.swift
//  70K Bands
//
//  Created by Refactoring
//  Copyright (c) 2026 Ron Dorn. All rights reserved.
//

import Foundation
import UIKit

/// ViewModel for MasterViewController data operations
/// Handles data fetching, refreshing, and background updates
class MasterViewModel {
    
    // MARK: - Dependencies
    private let schedule: scheduleHandler
    private let bandNameHandle: bandNamesHandler
    private let dataHandle: dataHandler
    private let priorityManager: SQLitePriorityManager
    private let attendedHandle: ShowsAttended
    private let iCloudDataHandle: iCloudDataHandler
    
    // MARK: - State Management
    private var lastRefreshDataRun: Date? = nil
    private var lastScheduleDownload: Date? = nil
    private let scheduleDownloadInterval: TimeInterval = 5 * 60 // 5 minutes
    private let minDownloadInterval: TimeInterval = 60 // 1 minute
    
    // MARK: - Background Refresh State
    static var isBackgroundRefreshInProgress: Bool = false
    static let backgroundRefreshLock = NSLock()
    
    // MARK: - Initialization
    init(
        schedule: scheduleHandler,
        bandNameHandle: bandNamesHandler,
        dataHandle: dataHandler,
        priorityManager: SQLitePriorityManager,
        attendedHandle: ShowsAttended,
        iCloudDataHandle: iCloudDataHandler
    ) {
        self.schedule = schedule
        self.bandNameHandle = bandNameHandle
        self.dataHandle = dataHandle
        self.priorityManager = priorityManager
        self.attendedHandle = attendedHandle
        self.iCloudDataHandle = iCloudDataHandle
    }
    
    // MARK: - Data Refresh Methods
    
    /// Refreshes data with background update
    /// Shows cached data immediately, then updates in background
    func refreshDataWithBackgroundUpdate(
        reason: String,
        onCacheRefresh: @escaping () -> Void,
        onBackgroundComplete: @escaping () -> Void
    ) {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", startTime))] refreshDataWithBackgroundUpdate START - reason: '\(reason)'")
        
        // Immediately refresh GUI from cache on main thread
        let immediateStartTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", immediateStartTime))] Starting immediate cache refresh")
        
        DispatchQueue.main.async {
            onCacheRefresh()
            let immediateEndTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", immediateEndTime))] Immediate cache refresh END - time: \(String(format: "%.3f", (immediateEndTime - immediateStartTime) * 1000))ms")
        }
        
        // Check if background refresh is already in progress
        MasterViewModel.backgroundRefreshLock.lock()
        if MasterViewModel.isBackgroundRefreshInProgress {
            print("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] Background refresh (\(reason)): Skipping - another refresh already in progress")
            MasterViewModel.backgroundRefreshLock.unlock()
            return
        }
        MasterViewModel.isBackgroundRefreshInProgress = true
        MasterViewModel.backgroundRefreshLock.unlock()
        
        let lockTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", lockTime))] Background refresh lock acquired, starting background operations")
        
        // Trigger background refresh
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else {
                let errorTime = CFAbsoluteTimeGetCurrent()
                print("🕐 [\(String(format: "%.3f", errorTime))] Background refresh ERROR - self is nil")
                MasterViewModel.backgroundRefreshLock.lock()
                MasterViewModel.isBackgroundRefreshInProgress = false
                MasterViewModel.backgroundRefreshLock.unlock()
                return
            }
            
            let backgroundStartTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", backgroundStartTime))] Background thread START - reason: '\(reason)'")
            
            // Check network before attempting downloads
            let networkCheckStartTime = CFAbsoluteTimeGetCurrent()
            let internetAvailable = NetworkStatusManager.shared.isInternetAvailable
            let networkCheckEndTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", networkCheckEndTime))] Network check complete - available: \(internetAvailable) - time: \(String(format: "%.3f", (networkCheckEndTime - networkCheckStartTime) * 1000))ms")
            
            if !internetAvailable {
                print("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] Background refresh (\(reason)): No network, skipping data download")
                MasterViewModel.backgroundRefreshLock.lock()
                MasterViewModel.isBackgroundRefreshInProgress = false
                MasterViewModel.backgroundRefreshLock.unlock()
                return
            }
            
            print("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] Background refresh (\(reason)): Checking throttling before data download")
            
            // Check throttling - all scenarios use 5-minute throttling
            let shouldDownload = self.shouldDownloadSchedule(force: false)
            
            let downloadStartTime = CFAbsoluteTimeGetCurrent()
            if shouldDownload {
                print("🕐 [\(String(format: "%.3f", downloadStartTime))] Throttling check passed - starting CSV download")
                self.lastScheduleDownload = Date()
            } else {
                print("🕐 [\(String(format: "%.3f", downloadStartTime))] Throttled - less than 5 minutes since last download, skipping CSV download")
            }
            
            let populateStartTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", populateStartTime))] Starting schedule population")
            self.schedule.populateSchedule(forceDownload: shouldDownload)
            let populateEndTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", populateEndTime))] Schedule population END - time: \(String(format: "%.3f", (populateEndTime - populateStartTime) * 1000))ms")
            
            let downloadEndTime = CFAbsoluteTimeGetCurrent()
            if shouldDownload {
                print("🕐 [\(String(format: "%.3f", downloadEndTime))] CSV download END - time: \(String(format: "%.3f", (downloadEndTime - downloadStartTime) * 1000))ms")
            }
            
            // Update UI on main thread when complete
            let uiUpdateStartTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", uiUpdateStartTime))] Starting UI update on main thread")
            DispatchQueue.main.async {
                let mainThreadStartTime = CFAbsoluteTimeGetCurrent()
                print("🕐 [\(String(format: "%.3f", mainThreadStartTime))] Main thread UI update START")
                onBackgroundComplete()
                let mainThreadEndTime = CFAbsoluteTimeGetCurrent()
                print("🕐 [\(String(format: "%.3f", mainThreadEndTime))] Main thread UI update END - time: \(String(format: "%.3f", (mainThreadEndTime - mainThreadStartTime) * 1000))ms")
            }
            
            let backgroundEndTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", backgroundEndTime))] Background thread END - total time: \(String(format: "%.3f", (backgroundEndTime - backgroundStartTime) * 1000))ms")
            
            // Mark background refresh as complete
            MasterViewModel.backgroundRefreshLock.lock()
            MasterViewModel.isBackgroundRefreshInProgress = false
            MasterViewModel.backgroundRefreshLock.unlock()
            
            let totalTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", totalTime))] refreshDataWithBackgroundUpdate END - total time: \(String(format: "%.3f", (totalTime - startTime) * 1000))ms")
        }
    }
    
    /// Performs a full data refresh with network testing
    func performFullDataRefresh(
        reason: String,
        onCacheRefresh: @escaping () -> Void,
        onNetworkTest: @escaping (Bool) -> Void,
        onBackgroundRefresh: @escaping () -> Void
    ) {
        print("Performing full data refresh: \(reason)")
        
        // STEP 1: Refresh from cache first (immediate UI update)
        print("Full data refresh (\(reason)): Step 1 - Refreshing from cache")
        onCacheRefresh()
        
        // STEP 2: Confirm internet access
        print("Full data refresh (\(reason)): Step 2 - Confirming internet access")
        
        // Move network test to background to prevent main thread blocking
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            let networkTesting = NetworkTesting()
            // Note: This requires access to the view controller for UI updates
            // We'll need to pass a callback or handle this differently
            let hasNetwork = NetworkStatusManager.shared.isInternetAvailable
            
            DispatchQueue.main.async {
                onNetworkTest(hasNetwork)
                
                if hasNetwork {
                    print("Full data refresh (\(reason)): Internet confirmed, proceeding with background refresh")
                    onBackgroundRefresh()
                } else {
                    print("Full data refresh (\(reason)): No network connectivity detected, staying with cached data")
                }
            }
        }
    }
    
    /// Performs background-only data refresh
    func performBackgroundOnlyDataRefresh(
        reason: String,
        onCacheRefresh: @escaping () -> Void,
        onNetworkTest: @escaping (Bool) -> Void,
        onFreshDataCollection: @escaping () -> Void
    ) {
        print("🌐 BACKGROUND-ONLY REFRESH: \(reason) - Using network-test-first pattern")
        
        // STEP 1: Always show cached data first (immediate)
        onCacheRefresh()
        
        // STEP 2: Test network first, then do fresh data collection
        DispatchQueue.global(qos: .utility).async {
            let networkIsGood = NetworkStatusManager.shared.isInternetAvailable
            
            DispatchQueue.main.async {
                onNetworkTest(networkIsGood)
                
                if networkIsGood {
                    print("🌐 BACKGROUND-ONLY REFRESH: Network test passed - proceeding with fresh data collection")
                    onFreshDataCollection()
                } else {
                    print("🌐 BACKGROUND-ONLY REFRESH: Network test failed - staying with cached data")
                    print("🌐 BACKGROUND-ONLY REFRESH: User will continue seeing cached data until network improves")
                }
            }
        }
    }
    
    /// Refreshes data with throttling
    func refreshData(
        isUserInitiated: Bool = false,
        forceDownload: Bool = false,
        onCacheRefresh: @escaping () -> Void,
        onBackgroundRefresh: @escaping () -> Void
    ) {
        // Throttle: Only allow if 60 seconds have passed, unless user-initiated (pull to refresh)
        let now = Date()
        if !isUserInitiated {
            if let lastRun = lastRefreshDataRun, now.timeIntervalSince(lastRun) < 60 {
                print("refreshData throttled: Only one run per 60 seconds unless user-initiated.")
                return
            }
        }
        lastRefreshDataRun = now
        
        print("🔄 refreshData START - isUserInitiated: \(isUserInitiated), forceDownload: \(forceDownload)")
        
        // Step 1: Display cached data immediately (user sees current data)
        print("📱 Step 1: Displaying cached data immediately")
        onCacheRefresh()
        
        // Step 2: Start background thread for data refresh
        print("🔄 Step 2: Starting background thread for data refresh")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Step 3: Verify internet connection
            print("🌐 Step 3: Verifying internet connection")
            let internetAvailable = NetworkStatusManager.shared.isInternetAvailable
            if !internetAvailable {
                print("❌ No internet connection available, skipping background refresh")
                return
            }
            print("✅ Internet connection verified")
            
            // Step 4: Trigger background refresh
            print("📥 Step 4: Triggering background data refresh")
            onBackgroundRefresh()
        }
    }
    
    // MARK: - Schedule Download Management
    
    /// Determines if schedule should be downloaded
    func shouldDownloadSchedule(force: Bool = false) -> Bool {
        if force {
            return true
        }
        
        guard let lastDownload = lastScheduleDownload else {
            // Never downloaded, allow download
            return true
        }
        
        let timeSinceLastDownload = Date().timeIntervalSince(lastDownload)
        
        // Don't download if less than minimum interval has passed
        if timeSinceLastDownload < minDownloadInterval {
            print("⏱️ Schedule download skipped: Only \(String(format: "%.1f", timeSinceLastDownload))s since last download (minimum: \(minDownloadInterval)s)")
            return false
        }
        
        // Download if interval has passed
        if timeSinceLastDownload >= scheduleDownloadInterval {
            print("⏱️ Schedule download allowed: \(String(format: "%.1f", timeSinceLastDownload))s since last download (interval: \(scheduleDownloadInterval)s)")
            return true
        }
        
        print("⏱️ Schedule download skipped: \(String(format: "%.1f", timeSinceLastDownload))s since last download (interval: \(scheduleDownloadInterval)s)")
        return false
    }
    
    /// Updates the last schedule download timestamp
    func updateLastScheduleDownload() {
        lastScheduleDownload = Date()
    }
    
    // MARK: - Cache Management
    
    /// Clears all caches comprehensively
    func clearAllCaches() {
        print("🧹 Clearing all caches comprehensively")
        
        // Clear handler caches
        bandNameHandle.clearCachedData()
        dataHandle.clearCachedData()
        schedule.clearCache()
        
        // Clear static cache variables
        cacheVariables.scheduleStaticCache = [:]
        cacheVariables.scheduleTimeStaticCache = [:]
        cacheVariables.bandNamesStaticCache = [:]
        cacheVariables.bandNamesArrayStaticCache = []
        cacheVariables.bandDescriptionUrlCache = [:]
        cacheVariables.bandDescriptionUrlDateCache = [:]
        cacheVariables.attendedStaticCache = [:]
        cacheVariables.lastModifiedDate = nil
        
        print("🧹 All caches cleared successfully")
    }
}

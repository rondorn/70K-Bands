//
//  SwiftUIBridge.swift
//  70000TonsBands
//
//  Created by Assistant on 12/19/24.
//  Copyright (c) 2024 Ron Dorn. All rights reserved.
//

import Foundation
import SwiftUI

/// Bridge class to handle the transition from UIKit MasterViewController to SwiftUI
/// This provides compatibility for existing code that references the global masterView
class SwiftUIBridge: ObservableObject {
    
    static let shared = SwiftUIBridge()
    
    // MARK: - Properties that mirror MasterViewController functionality
    @Published var bands: [String] = []
    @Published var bandsByTime: [String] = []
    @Published var bandsByName: [String] = []
    
    // Data handlers - same instances used throughout the app
    let schedule = scheduleHandler()
    let bandNameHandle = bandNamesHandler()
    let dataHandle = dataHandler()
    let attendedHandle = ShowsAttended()
    let iCloudDataHandle = iCloudDataHandler()
    var bandDescriptions = CustomBandDescription()
    
    private init() {
        // Initialize with data loading
        loadInitialData()
    }
    
    // MARK: - Methods that mirror MasterViewController functionality
    
    func refreshData(isUserInitiated: Bool = false) {
        Task {
            await performDataRefresh(userInitiated: isUserInitiated)
        }
    }
    
    func performFullDataRefresh(reason: String) {
        print("🔄 SwiftUIBridge: Performing full data refresh - \(reason)")
        
        // Clear all caches
        clearAllCaches()
        
        // Reload data
        Task {
            await performDataRefresh(userInitiated: true)
        }
    }
    
    func refreshBandList(reason: String) {
        print("🔄 SwiftUIBridge: Refreshing band list - \(reason)")
        
        Task {
            await loadBandData()
        }
    }
    
    func clearMasterViewCachedData() {
        bands.removeAll()
        bandsByTime.removeAll()
        bandsByName.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func loadInitialData() {
        Task {
            await performDataRefresh(userInitiated: false)
        }
    }
    
    private func performDataRefresh(userInitiated: Bool) async {
        print("🔄 SwiftUIBridge: Starting data refresh (user initiated: \(userInitiated))")
        
        // Load iCloud data if user initiated
        if userInitiated {
            iCloudDataHandle.readAllPriorityData()
            iCloudDataHandle.readAllScheduleData()
        }
        
        // Load band data
        await loadBandData()
        
        // Load schedule data
        schedule.populateSchedule(forceDownload: userInitiated)
        
        // Load band descriptions
        bandDescriptions.getAllDescriptions()
        
        print("✅ SwiftUIBridge: Data refresh completed")
        
        // Notify SwiftUI views to update
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("RefreshDisplay"), object: nil)
        }
    }
    
    private func loadBandData() async {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                // Load band names
                self.bandNameHandle.gatherData()
                let loadedBands = self.bandNameHandle.getBandNames()
                
                DispatchQueue.main.async {
                    self.bands = loadedBands
                    self.bandsByName = loadedBands.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                    self.bandsByTime = self.sortBandsByTime(loadedBands)
                    
                    continuation.resume()
                }
            }
        }
    }
    
    private func sortBandsByTime(_ bands: [String]) -> [String] {
        return bands.sorted { band1, band2 in
            let events1 = schedule.getBandSchedule(bandName: band1)
            let events2 = schedule.getBandSchedule(bandName: band2)
            
            // Get earliest event time for each band
            let time1 = events1.compactMap { schedule.getEventStartTime($0) }.min() ?? Date.distantFuture
            let time2 = events2.compactMap { schedule.getEventStartTime($0) }.min() ?? Date.distantFuture
            
            return time1 < time2
        }
    }
    
    private func clearAllCaches() {
        // Clear handler caches
        bandNameHandle.clearCachedData()
        dataHandle.clearCachedData()
        schedule.clearCache()
        
        // Clear local arrays
        clearMasterViewCachedData()
        
        // Clear static caches
        staticSchedule.sync {
            cacheVariables.scheduleStaticCache = [:]
            cacheVariables.scheduleTimeStaticCache = [:]
            cacheVariables.bandNamesStaticCache = [:]
            cacheVariables.bandNamesArrayStaticCache = []
            cacheVariables.bandDescriptionUrlCache = [:]
            cacheVariables.bandDescriptionUrlDateCache = [:]
            cacheVariables.attendedStaticCache = [:]
            cacheVariables.lastModifiedDate = nil
        }
        
        print("🧹 SwiftUIBridge: All caches cleared")
    }
}

// MARK: - Global Compatibility

// The MasterViewCompatibilityWrapper is now defined in Constants.swift
// This ensures proper scope and eliminates circular dependency issues

extension SwiftUIBridge {
    static func setupGlobalMasterViewCompatibility() {
        // This will be called from AppDelegate to set up the compatibility layer
        // The actual assignment is handled in Constants.swift
        print("🔗 SwiftUI Bridge compatibility layer initialized")
    }
}

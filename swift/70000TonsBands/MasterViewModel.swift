//
//  MasterViewModel.swift
//  70000TonsBands
//
//  Created by Assistant on 12/19/24.
//  Copyright (c) 2024 Ron Dorn. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

class MasterViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var bands: [String] = []
    @Published var filteredBands: [String] = []
    @Published var isLoading = false
    @Published var isSearchVisible = false
    @Published var navigationTitle = "70K Bands"
    
    // Filter options
    @Published var showMustSee = true {
        didSet { 
            setMustSeeOn(showMustSee)
            filterBands()
        }
    }
    @Published var showMightSee = true {
        didSet { 
            setMightSeeOn(showMightSee)
            filterBands()
        }
    }
    @Published var showWontSee = true {
        didSet { 
            setWontSeeOn(showWontSee)
            filterBands()
        }
    }
    @Published var showUnknown = true {
        didSet { 
            setUnknownSeeOn(showUnknown)
            filterBands()
        }
    }
    @Published var showOnlyBandsWithEvents = false {
        didSet { filterBands() }
    }
    @Published var hideExpiredEvents = false {
        didSet { 
            setHideExpireScheduleData(hideExpiredEvents)
            filterBands()
        }
    }
    @Published var sortOption: SortOption = .name {
        didSet { filterBands() }
    }
    
    // MARK: - Private Properties
    private let bandNameHandle = bandNamesHandler()
    private let schedule = scheduleHandler()
    private let dataHandle = dataHandler()
    private let attendedHandle = ShowsAttended()
    private let iCloudDataHandle = iCloudDataHandler()
    private var bandDescriptions = CustomBandDescription()
    
    private var cancellables = Set<AnyCancellable>()
    private var currentSearchText = ""
    
    // MARK: - Computed Properties
    var statsURL: URL {
        let statsUrl = getPointerUrlData(keyValue: "reportUrl")
        return URL(string: statsUrl) ?? URL(string: "https://www.70000tons.com")!
    }
    
    // MARK: - Initialization
    init() {
        loadCurrentFilters()
        setupNotifications()
    }
    
    // MARK: - Public Methods
    func loadData() {
        Task {
            isLoading = true
            await loadBandData()
            isLoading = false
        }
    }
    
    func refreshData() {
        Task {
            await loadBandData()
        }
    }
    
    func performFullRefresh() async {
        isLoading = true
        
        // Clear caches
        bandNameHandle.clearCachedData()
        dataHandle.clearCachedData()
        schedule.clearCache()
        
        // Load iCloud data
        iCloudDataHandle.readAllPriorityData()
        iCloudDataHandle.readAllScheduleData()
        
        // Load fresh data
        await loadBandData()
        
        isLoading = false
    }
    
    func toggleSearch() {
        withAnimation {
            isSearchVisible.toggle()
        }
        if !isSearchVisible {
            currentSearchText = ""
            filterBands()
        }
    }
    
    func performSearch(_ searchText: String) {
        currentSearchText = searchText
        filterBands(searchText: searchText)
        
        // Easter egg check
        if searchText.lowercased() == "gus" {
            // Trigger easter egg
            print("🥚 Easter egg triggered!")
        }
    }
    
    func cancelSearch() {
        currentSearchText = ""
        filterBands()
        withAnimation {
            isSearchVisible = false
        }
    }
    
    func filterBands(searchText: String = "") {
        let searchTerm = searchText.isEmpty ? currentSearchText : searchText
        currentSearchText = searchTerm
        
        var filtered = bands
        
        // Apply search filter
        if !searchTerm.isEmpty {
            filtered = filtered.filter { band in
                band.localizedCaseInsensitiveContains(searchTerm)
            }
        }
        
        // Apply priority filters
        filtered = filtered.filter { band in
            let priority = getBandPriority(band)
            switch priority {
            case 1: return showMustSee
            case 2: return showMightSee
            case 3: return showWontSee
            default: return showUnknown
            }
        }
        
        // Apply event filter
        if showOnlyBandsWithEvents {
            filtered = filtered.filter { band in
                bandHasEvents(band)
            }
        }
        
        // Apply sorting
        switch sortOption {
        case .name:
            filtered = filtered.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        case .time:
            filtered = sortBandsByTime(filtered)
        case .priority:
            filtered = sortBandsByPriority(filtered)
        }
        
        filteredBands = filtered
    }
    
    func getBandPriority(_ bandName: String) -> Int {
        return dataHandle.getPriorityData(bandName)
    }
    
    func bandHasEvents(_ bandName: String) -> Bool {
        let events = schedule.getBandSchedule(bandName: bandName)
        return !events.isEmpty
    }
    
    func getBandEventCount(_ bandName: String) -> Int {
        let events = schedule.getBandSchedule(bandName: bandName)
        return events.count
    }
    
    func shareData() {
        // Get current list of bands and their priorities
        var shareText = "My 70000 Tons of Metal Band Priorities:\n\n"
        
        let mustSeeBands = filteredBands.filter { getBandPriority($0) == 1 }
        let mightSeeBands = filteredBands.filter { getBandPriority($0) == 2 }
        
        if !mustSeeBands.isEmpty {
            shareText += "Must See:\n"
            mustSeeBands.forEach { shareText += "• \($0)\n" }
            shareText += "\n"
        }
        
        if !mightSeeBands.isEmpty {
            shareText += "Might See:\n"
            mightSeeBands.forEach { shareText += "• \($0)\n" }
            shareText += "\n"
        }
        
        shareText += "Shared from 70K Bands App"
        
        // Present share sheet
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            if let rootVC = window.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
    }
    
    // MARK: - Private Methods
    private func loadCurrentFilters() {
        showMustSee = getMustSeeOn()
        showMightSee = getMightSeeOn()
        showWontSee = getWontSeeOn()
        showUnknown = getUnknownSeeOn()
        hideExpiredEvents = getHideExpireScheduleData()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: Notification.Name("RefreshDisplay"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: Notification.Name("iCloudRefresh"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: Notification.Name("BackgroundDataRefresh"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.performFullRefresh()
                }
            }
            .store(in: &cancellables)
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
                
                // Load schedule data
                self.schedule.populateSchedule(forceDownload: false)
                
                DispatchQueue.main.async {
                    self.bands = loadedBands
                    self.filterBands()
                    self.updateNavigationTitle()
                    continuation.resume()
                }
            }
        }
    }
    
    private func updateNavigationTitle() {
        let currentEventYear = eventYear
        let yearString = String(currentEventYear)
        
        if yearString != String(getCurrentYear()) {
            navigationTitle = "\(yearString) Bands"
        } else {
            navigationTitle = "70K Bands"
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
    
    private func sortBandsByPriority(_ bands: [String]) -> [String] {
        return bands.sorted { band1, band2 in
            let priority1 = getBandPriority(band1)
            let priority2 = getBandPriority(band2)
            
            // Sort by priority (1=Must See first, then 2=Might See, etc.)
            if priority1 != priority2 {
                return priority1 < priority2
            }
            
            // If same priority, sort alphabetically
            return band1.localizedCaseInsensitiveCompare(band2) == .orderedAscending
        }
    }
    
    private func getCurrentYear() -> Int {
        let calendar = Calendar.current
        return calendar.component(.year, from: Date())
    }
}

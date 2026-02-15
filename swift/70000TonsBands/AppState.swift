//
//  AppState.swift
//  70K Bands
//
//  Created by Refactoring
//  Copyright (c) 2026 Ron Dorn. All rights reserved.
//

import Foundation

/// Global application state management
/// This class manages global state variables that are used across the application.
/// TODO: Further refactor to use proper state management (e.g., Combine, SwiftUI State, or a dedicated state manager)
class AppState {
    
    // MARK: - Singleton
    static let shared = AppState()
    private init() {}
    
    // MARK: - Counters
    var bandCounter = 0
    var eventCounter = 0
    var eventCounterUnofficial = 0
    var refreshDataCounter = 0
    var loadUrlCounter = 0
    var listCount = 0
    var numberOfFilteredRecords = 0
    var filteredBandCount = 0
    var unfilteredBandCount = 0
    var unfilteredEventCount = 0
    var unfilteredCruiserEventCount = 0
    var unfilteredCurrentEventCount = 0
    var didNotFindMarkedEventsCount = 0
    var lastRefreshCount = 0
    
    // MARK: - Flags
    var noEntriesFlag = false
    var touchedTheBottom = false
    var refreshAfterMenuIsGoneFlag = false
    var isFilterMenuVisible = false
    var readingBandFile = false
    var refreshDataLock = false
    var descriptionLock = false
    var didVersionChange = false
    var byPassCsvDownloadCheck = false
    var scheduleReleased = false
    var filterMenuNeedsUpdating = false
    var hasScheduleData = false
    
    // MARK: - Loading States
    private var _iCloudDataisLoading = false
    private var _iCloudScheduleDataisLoading = false
    private let iCloudLoadingQueue = DispatchQueue(label: "com.yourapp.iCloudLoadingQueue")
    
    var iCloudDataisLoading: Bool {
        get { iCloudLoadingQueue.sync { _iCloudDataisLoading } }
        set { iCloudLoadingQueue.sync { _iCloudDataisLoading = newValue } }
    }
    
    var iCloudScheduleDataisLoading: Bool {
        get { iCloudLoadingQueue.sync { _iCloudScheduleDataisLoading } }
        set { iCloudLoadingQueue.sync { _iCloudScheduleDataisLoading = newValue } }
    }
    
    var isAlertGenerationRunning = false
    var isLoadingBandData = false
    var isLoadingSchedule = false
    var isLoadingCommentData = false
    var isPerformingQuickLoad = false
    var isReadingBandFile = false
    var isGetFilteredBands = false
    var downloadingAllComments = false
    var downloadingAllImages = false
    var loadingiCloud = false
    var savingiCloud = false
    
    // MARK: - Selection State
    var bandSelected = ""
    var eventSelectedIndex = ""
    var currentBandList = [String]()
    
    // MARK: - Other State
    var userCountry = ""
    var webMessageHelp = ""
    var timeIndexMap: [String: String] = [:]
    var bandListIndexCache = 0
    var inTestEnvironment = false
    
    // MARK: - Internet Check Cache
    var internetCheckCache = ""
    var internetCheckCacheDate = Date().timeIntervalSince1970
    var iCloudCheck = false
    
    // MARK: - Refresh Tracking
    var lastRefreshEpicTime = Int(Date().timeIntervalSince1970)
}

// MARK: - Global Accessors (for backward compatibility during migration)
/// These global variables provide backward compatibility during the migration.
/// They delegate to AppState.shared and will be removed once all references are updated.

var bandCounter: Int {
    get { AppState.shared.bandCounter }
    set { AppState.shared.bandCounter = newValue }
}

var eventCounter: Int {
    get { AppState.shared.eventCounter }
    set { AppState.shared.eventCounter = newValue }
}

var eventCounterUnoffical: Int {
    get { AppState.shared.eventCounterUnofficial }
    set { AppState.shared.eventCounterUnofficial = newValue }
}

var refreshDataCounter: Int {
    get { AppState.shared.refreshDataCounter }
    set { AppState.shared.refreshDataCounter = newValue }
}

var loadUrlCounter: Int {
    get { AppState.shared.loadUrlCounter }
    set { AppState.shared.loadUrlCounter = newValue }
}

var listCount: Int {
    get { AppState.shared.listCount }
    set { AppState.shared.listCount = newValue }
}

var numberOfFilteredRecords: Int {
    get { AppState.shared.numberOfFilteredRecords }
    set { AppState.shared.numberOfFilteredRecords = newValue }
}

var filteredBandCount: Int {
    get { AppState.shared.filteredBandCount }
    set { AppState.shared.filteredBandCount = newValue }
}

var unfilteredBandCount: Int {
    get { AppState.shared.unfilteredBandCount }
    set { AppState.shared.unfilteredBandCount = newValue }
}

var unfilteredEventCount: Int {
    get { AppState.shared.unfilteredEventCount }
    set { AppState.shared.unfilteredEventCount = newValue }
}

var unfilteredCruiserEventCount: Int {
    get { AppState.shared.unfilteredCruiserEventCount }
    set { AppState.shared.unfilteredCruiserEventCount = newValue }
}

var unfilteredCurrentEventCount: Int {
    get { AppState.shared.unfilteredCurrentEventCount }
    set { AppState.shared.unfilteredCurrentEventCount = newValue }
}

var didNotFindMarkedEventsCount: Int {
    get { AppState.shared.didNotFindMarkedEventsCount }
    set { AppState.shared.didNotFindMarkedEventsCount = newValue }
}

var lastRefreshCount: Int {
    get { AppState.shared.lastRefreshCount }
    set { AppState.shared.lastRefreshCount = newValue }
}

var noEntriesFlag: Bool {
    get { AppState.shared.noEntriesFlag }
    set { AppState.shared.noEntriesFlag = newValue }
}

var touchedThebottom: Bool {
    get { AppState.shared.touchedTheBottom }
    set { AppState.shared.touchedTheBottom = newValue }
}

var refreshAfterMenuIsGoneFlag: Bool {
    get { AppState.shared.refreshAfterMenuIsGoneFlag }
    set { AppState.shared.refreshAfterMenuIsGoneFlag = newValue }
}

var isFilterMenuVisible: Bool {
    get { AppState.shared.isFilterMenuVisible }
    set { AppState.shared.isFilterMenuVisible = newValue }
}

var readingBandFile: Bool {
    get { AppState.shared.readingBandFile }
    set { AppState.shared.readingBandFile = newValue }
}

var refreshDataLock: Bool {
    get { AppState.shared.refreshDataLock }
    set { AppState.shared.refreshDataLock = newValue }
}

var descriptionLock: Bool {
    get { AppState.shared.descriptionLock }
    set { AppState.shared.descriptionLock = newValue }
}

var didVersionChange: Bool {
    get { AppState.shared.didVersionChange }
    set { AppState.shared.didVersionChange = newValue }
}

var byPassCsvDownloadCheck: Bool {
    get { AppState.shared.byPassCsvDownloadCheck }
    set { AppState.shared.byPassCsvDownloadCheck = newValue }
}

var scheduleReleased: Bool {
    get { AppState.shared.scheduleReleased }
    set { AppState.shared.scheduleReleased = newValue }
}

var filterMenuNeedsUpdating: Bool {
    get { AppState.shared.filterMenuNeedsUpdating }
    set { AppState.shared.filterMenuNeedsUpdating = newValue }
}

var hasScheduleData: Bool {
    get { AppState.shared.hasScheduleData }
    set { AppState.shared.hasScheduleData = newValue }
}

var iCloudDataisLoading: Bool {
    get { AppState.shared.iCloudDataisLoading }
    set { AppState.shared.iCloudDataisLoading = newValue }
}

var iCloudScheduleDataisLoading: Bool {
    get { AppState.shared.iCloudScheduleDataisLoading }
    set { AppState.shared.iCloudScheduleDataisLoading = newValue }
}

var isAlertGenerationRunning: Bool {
    get { AppState.shared.isAlertGenerationRunning }
    set { AppState.shared.isAlertGenerationRunning = newValue }
}

var isLoadingBandData: Bool {
    get { AppState.shared.isLoadingBandData }
    set { AppState.shared.isLoadingBandData = newValue }
}

var isLoadingSchedule: Bool {
    get { AppState.shared.isLoadingSchedule }
    set { AppState.shared.isLoadingSchedule = newValue }
}

var isLoadingCommentData: Bool {
    get { AppState.shared.isLoadingCommentData }
    set { AppState.shared.isLoadingCommentData = newValue }
}

var isPerformingQuickLoad: Bool {
    get { AppState.shared.isPerformingQuickLoad }
    set { AppState.shared.isPerformingQuickLoad = newValue }
}

var isReadingBandFile: Bool {
    get { AppState.shared.isReadingBandFile }
    set { AppState.shared.isReadingBandFile = newValue }
}

var isGetFilteredBands: Bool {
    get { AppState.shared.isGetFilteredBands }
    set { AppState.shared.isGetFilteredBands = newValue }
}

var downloadingAllComments: Bool {
    get { AppState.shared.downloadingAllComments }
    set { AppState.shared.downloadingAllComments = newValue }
}

var downloadingAllImages: Bool {
    get { AppState.shared.downloadingAllImages }
    set { AppState.shared.downloadingAllImages = newValue }
}

var loadingiCloud: Bool {
    get { AppState.shared.loadingiCloud }
    set { AppState.shared.loadingiCloud = newValue }
}

var savingiCloud: Bool {
    get { AppState.shared.savingiCloud }
    set { AppState.shared.savingiCloud = newValue }
}

var bandSelected: String {
    get { AppState.shared.bandSelected }
    set { AppState.shared.bandSelected = newValue }
}

var eventSelectedIndex: String {
    get { AppState.shared.eventSelectedIndex }
    set { AppState.shared.eventSelectedIndex = newValue }
}

var currentBandList: [String] {
    get { AppState.shared.currentBandList }
    set { AppState.shared.currentBandList = newValue }
}

var userCountry: String {
    get { AppState.shared.userCountry }
    set { AppState.shared.userCountry = newValue }
}

var webMessageHelp: String {
    get { AppState.shared.webMessageHelp }
    set { AppState.shared.webMessageHelp = newValue }
}

var timeIndexMap: [String: String] {
    get { AppState.shared.timeIndexMap }
    set { AppState.shared.timeIndexMap = newValue }
}

var bandListIndexCache: Int {
    get { AppState.shared.bandListIndexCache }
    set { AppState.shared.bandListIndexCache = newValue }
}

var internetCheckCache: String {
    get { AppState.shared.internetCheckCache }
    set { AppState.shared.internetCheckCache = newValue }
}

var internetCheckCacheDate: TimeInterval {
    get { AppState.shared.internetCheckCacheDate }
    set { AppState.shared.internetCheckCacheDate = newValue }
}

var iCloudCheck: Bool {
    get { AppState.shared.iCloudCheck }
    set { AppState.shared.iCloudCheck = newValue }
}

var lastRefreshEpicTime: Int {
    get { AppState.shared.lastRefreshEpicTime }
    set { AppState.shared.lastRefreshEpicTime = newValue }
}

var inTestEnvironment: Bool {
    get { AppState.shared.inTestEnvironment }
    set { AppState.shared.inTestEnvironment = newValue }
}

//
//  FilePaths.swift
//  70K Bands
//
//  Created by Refactoring
//  Copyright (c) 2026 Ron Dorn. All rights reserved.
//

import Foundation

/// Centralized file path management for the application
struct FilePaths {
    
    // MARK: - Document Directory
    private static let dirs = NSSearchPathForDirectoriesInDomains(
        FileManager.SearchPathDirectory.documentDirectory,
        FileManager.SearchPathDomainMask.allDomainsMask,
        true
    )
    
    static let directoryPath = URL(fileURLWithPath: dirs[0])
    
    // MARK: - Data Files
    static let storageFile = directoryPath.appendingPathComponent("data.txt")
    static let dateFile = directoryPath.appendingPathComponent("date.txt")
    static let bandsFile = directoryPath.appendingPathComponent("bands.txt")
    static let lastFilters = directoryPath.appendingPathComponent("lastFilters.txt")
    static let bandFile: String = getDocumentsDirectory().appendingPathComponent("bandFile")
    static let countryFile = directoryPath.appendingPathComponent("countryFile")
    
    // MARK: - Shows Attended
    static let showsAttendedFileName = "showsAttended.data"
    static let showsAttended = directoryPath.appendingPathComponent(showsAttendedFileName)
    
    // MARK: - iCloud Data Files
    static let lastiCloudDataWriteFile = directoryPath.appendingPathComponent("iCloudDataWrite.txt")
    static let lastPriorityDataWriteFile = directoryPath.appendingPathComponent("PriorityDataWrite.txt")
    static let lastScheduleDataWriteFile = directoryPath.appendingPathComponent("ScheduleDataWrite.txt")
    
    // MARK: - Cache Files
    static let schedulingDataCacheFile = directoryPath.appendingPathComponent("schedulingDataCacheFile")
    static let schedulingDataByTimeCacheFile = directoryPath.appendingPathComponent("schedulingDataByTimeCacheFile")
    static let bandNamesCacheFile = directoryPath.appendingPathComponent("bandNamesCacheFile")
    
    // MARK: - Schedule and Description Files
    static let scheduleFile: String = getDocumentsDirectory().appendingPathComponent("scheduleFile.txt")
    static let descriptionMapFile: String = getDocumentsDirectory().appendingPathComponent("descriptionMapFile.csv")
    
    // MARK: - Year and Version Files
    static let eventYearFile: String = getDocumentsDirectory().appendingPathComponent("eventYearFile")
    static let versionInfoFile: String = getDocumentsDirectory().appendingPathComponent("versionInfoFile")
    static let eventYearsInfoFile = "eventYearsInfoFile"
    
    // MARK: - Default URL Conversion Flag
    static let defaultUrlConverFlagString = "defaultUrlConverFlag.txt"
    static let defaultUrlConverFlagUrl = directoryPath.appendingPathComponent(defaultUrlConverFlagString)
    
    // MARK: - Cached Pointer File
    static var cachedPointerFile: String {
        return getDocumentsDirectory().appendingPathComponent("cachedPointerData.txt")
    }
    
    /// Returns the path to the app's documents directory as an NSString.
    /// - Returns: The documents directory path.
    static func getDocumentsDirectory() -> NSString {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        return documentsDirectory as NSString
    }
}

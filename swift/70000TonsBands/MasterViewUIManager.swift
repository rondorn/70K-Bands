//
//  MasterViewUIManager.swift
//  70K Bands
//
//  Created by Refactoring
//  Copyright (c) 2026 Ron Dorn. All rights reserved.
//

import Foundation
import UIKit

/// UI Manager for MasterViewController
/// Handles cell configuration, table view helpers, and UI updates
class MasterViewUIManager {
    
    // MARK: - Dependencies
    private let schedule: scheduleHandler
    private let dataHandle: dataHandler
    private let priorityManager: SQLitePriorityManager
    private let attendedHandle: ShowsAttended
    
    // MARK: - Initialization
    init(
        schedule: scheduleHandler,
        dataHandle: dataHandler,
        priorityManager: SQLitePriorityManager,
        attendedHandle: ShowsAttended
    ) {
        self.schedule = schedule
        self.dataHandle = dataHandle
        self.priorityManager = priorityManager
        self.attendedHandle = attendedHandle
    }
    
    // MARK: - Cell Configuration
    
    /// Configures a table view cell at the given index path
    /// Uses cached data when available, otherwise falls back to direct data access
    /// - Parameters:
    ///   - cell: The cell to configure
    ///   - indexPath: The index path of the cell
    ///   - bands: The bands array to use for data
    ///   - sortBy: The current sort order
    func configureCell(
        _ cell: UITableViewCell,
        atIndexPath indexPath: IndexPath,
        bands: [String],
        sortBy: String
    ) {
        // Add comprehensive bounds checking to prevent crash
        guard indexPath.row >= 0 else {
            print("ERROR: Negative index \(indexPath.row) in configureCell")
            cell.separatorInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 0)
            return
        }
        
        guard indexPath.row < bands.count else {
            print("ERROR: Index \(indexPath.row) out of bounds for bands array (count: \(bands.count))")
            // Set default separator style and return early
            cell.separatorInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 0)
            return
        }
        
        // Ensure bands array is not empty
        guard !bands.isEmpty else {
            print("ERROR: Bands array is empty in configureCell - this may happen during data refresh")
            cell.separatorInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 0)
            return
        }
        
        // PERFORMANCE FIX: Use cached cell data to prevent database lookups during scrolling
        if let cachedData = CellDataCache.shared.getCellData(at: indexPath.row) {
            // Configure cell with pre-computed cached data (NO database calls!)
            configureCellFromCache(cell, with: cachedData, bands: bands, indexPath: indexPath)
        } else {
            // Fallback: Use original method if cache miss (shouldn't happen with proper preload)
            getCellValue(indexPath.row, schedule: schedule, sortBy: sortBy, cell: cell, dataHandle: dataHandle, priorityManager: priorityManager, attendedHandle: attendedHandle)
        }
        
        // Configure separator immediately to avoid async access issues
        // Hide separator for band names only (plain strings without time index)
        let bandEntry = bands[indexPath.row]
        let isScheduledEvent = bandEntry.contains(":") && bandEntry.components(separatedBy: ":").first?.doubleValue != nil
        
        if !isScheduledEvent {
            // This is a band name only - hide separator
            cell.separatorInset = UIEdgeInsets(top: 0, left: cell.bounds.size.width, bottom: 0, right: 0)
        } else {
            // This is a scheduled event - show separator normally
            cell.separatorInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 0)
        }
    }
    
    /// Configure cell using pre-computed cached data (NO database calls during scrolling!)
    /// - Parameters:
    ///   - cell: The cell to configure
    ///   - cachedData: The pre-computed cell data
    ///   - bands: The bands array (for separator logic)
    ///   - indexPath: The index path (for separator logic)
    private func configureCellFromCache(
        _ cell: UITableViewCell,
        with cachedData: CellDataModel,
        bands: [String],
        indexPath: IndexPath
    ) {
        // Get UI elements by tags
        let indexForCell = cell.viewWithTag(1) as! UILabel
        let bandNameView = cell.viewWithTag(2) as! UILabel
        let locationView = cell.viewWithTag(3) as! UILabel
        let eventTypeImageView = cell.viewWithTag(4) as! UIImageView
        let rankImageView = cell.viewWithTag(5) as! UIImageView
        let attendedView = cell.viewWithTag(6) as! UIImageView
        let rankImageViewNoSchedule = cell.viewWithTag(7) as! UIImageView
        let startTimeView = cell.viewWithTag(14) as! UILabel
        let endTimeView = cell.viewWithTag(8) as! UILabel
        let dayLabelView = cell.viewWithTag(9) as! UILabel
        let dayView = cell.viewWithTag(10) as! UILabel
        let bandNameNoSchedule = cell.viewWithTag(12) as! UILabel
        
        // Configure cell colors
        cell.backgroundColor = UIColor.black
        cell.textLabel?.textColor = UIColor.white
        
        // CRITICAL FIX: Set indexText for swipe action parsing
        // The swipe action reads cell.textLabel?.text and expects format: "bandName;location;event;startTime"
        cell.textLabel?.text = cachedData.indexText
        
        // Configure text colors (from cached data)
        bandNameView.textColor = cachedData.bandNameColor
        // Don't set locationView.textColor here - it will be set via attributed string foregroundColor
        startTimeView.textColor = UIColor.white
        endTimeView.textColor = hexStringToUIColor(hex: "#797D7F")
        dayView.textColor = UIColor.white
        bandNameNoSchedule.textColor = UIColor.white
        
        // Set text from cached data with venue colors
        // For bandNameView: Create attributed string with venue color marker if has schedule
        if cachedData.hasSchedule {
            if cachedData.isPartialInfo {
                // Partial info: "   " + location (colored marker on 2nd space)
                let locationString = "   " + cachedData.location
                let venueString = NSMutableAttributedString(string: locationString)
                // Second space - colored marker with fixed 17pt font
                venueString.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 17), range: NSRange(location: 1, length: 1))
                venueString.addAttribute(NSAttributedString.Key.backgroundColor, value: cachedData.venueBackgroundColor, range: NSRange(location: 1, length: 1))
                // Location text (after the three spaces) - variable size font
                if cachedData.location.count > 0 {
                    let locationTextSize = calculateOptimalFontSize(for: cachedData.location, in: bandNameView, markerWidth: 17, maxSize: 16, minSize: 12)
                    venueString.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: locationTextSize), range: NSRange(location: 3, length: cachedData.location.count))
                    venueString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.lightGray, range: NSRange(location: 3, length: cachedData.location.count))
                }
                bandNameView.adjustsFontSizeToFitWidth = false
                bandNameView.backgroundColor = UIColor.clear
                bandNameView.attributedText = venueString
                
                // Also set locationView with venue color for partial info
                var locationOfVenue = "  " + (venueLocation[cachedData.location] ?? "")
                if !cachedData.notes.isEmpty && cachedData.notes != " " {
                    locationOfVenue += " " + cachedData.notes
                }
                let locationOfVenueString = NSMutableAttributedString(string: locationOfVenue)
                // First space - colored marker with fixed 17pt font
                locationOfVenueString.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 17), range: NSRange(location: 0, length: 1))
                locationOfVenueString.addAttribute(NSAttributedString.Key.backgroundColor, value: cachedData.venueBackgroundColor, range: NSRange(location: 0, length: 1))
                // Venue text (after the two spaces) - variable size font
                if locationOfVenue.count > 2 {
                    let venueText = String(locationOfVenue.dropFirst(2))
                    let venueTextSize = calculateOptimalFontSize(for: venueText, in: locationView, markerWidth: 17, maxSize: 16, minSize: 12)
                    locationOfVenueString.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: venueTextSize), range: NSRange(location: 2, length: locationOfVenue.count - 2))
                    locationOfVenueString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.lightGray, range: NSRange(location: 2, length: locationOfVenue.count - 2))
                }
                locationView.adjustsFontSizeToFitWidth = false
                locationView.backgroundColor = UIColor.clear
                locationView.attributedText = locationOfVenueString
            } else {
                // Full info: "  " + locationText (colored marker on 1st space)
                let locationString = "  " + cachedData.locationText
                let myMutableString = NSMutableAttributedString(string: locationString)
                // First space - colored marker with fixed 17pt font
                myMutableString.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 17), range: NSRange(location: 0, length: 1))
                myMutableString.addAttribute(NSAttributedString.Key.backgroundColor, value: cachedData.venueBackgroundColor, range: NSRange(location: 0, length: 1))
                // Location text (after the two spaces) - variable size font
                if cachedData.locationText.count > 0 {
                    let locationTextSize = calculateOptimalFontSize(for: cachedData.locationText, in: locationView, markerWidth: 17, maxSize: 16, minSize: 12)
                    myMutableString.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: locationTextSize), range: NSRange(location: 2, length: cachedData.locationText.count))
                    myMutableString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.lightGray, range: NSRange(location: 2, length: cachedData.locationText.count))
                }
                locationView.adjustsFontSizeToFitWidth = false
                locationView.backgroundColor = UIColor.clear
                locationView.attributedText = myMutableString
                bandNameView.text = cachedData.bandName
            }
        } else {
            // No schedule - just plain text
            bandNameView.text = cachedData.bandName
            locationView.text = cachedData.locationText
        }
        
        startTimeView.text = cachedData.startTimeText
        endTimeView.text = cachedData.endTimeText
        dayView.text = cachedData.dayText
        bandNameNoSchedule.text = cachedData.bandName
        
        // Set images from cached data
        eventTypeImageView.image = cachedData.eventIcon
        rankImageView.image = cachedData.priorityIcon
        attendedView.image = cachedData.attendedIcon
        rankImageViewNoSchedule.image = cachedData.priorityIcon
        
        // Configure visibility based on cached data
        if cachedData.hasSchedule {
            // Has schedule - show schedule elements
            locationView.isHidden = false
            startTimeView.isHidden = false
            endTimeView.isHidden = false
            dayView.isHidden = false
            dayLabelView.isHidden = false
            attendedView.isHidden = false
            eventTypeImageView.isHidden = false
            rankImageView.isHidden = false
            bandNameView.isHidden = false
            rankImageViewNoSchedule.isHidden = true
            bandNameNoSchedule.isHidden = true
            indexForCell.isHidden = true
        } else {
            // No schedule - show band name only elements
            locationView.isHidden = true
            startTimeView.isHidden = true
            endTimeView.isHidden = true
            dayView.isHidden = true
            dayLabelView.isHidden = true
            attendedView.isHidden = true
            eventTypeImageView.isHidden = true
            rankImageView.isHidden = true
            bandNameView.isHidden = true
            rankImageViewNoSchedule.isHidden = false
            bandNameNoSchedule.isHidden = false
            indexForCell.isHidden = true
        }
        
        // Configure separator visibility from cached data
        if cachedData.shouldHideSeparator {
            cell.separatorInset = UIEdgeInsets(top: 0, left: cell.bounds.size.width, bottom: 0, right: 0)
        } else {
            cell.separatorInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 0)
        }
    }
    
    // MARK: - Table View Helpers
    
    /// Gets the band name for a given row number
    /// - Parameters:
    ///   - rowNumber: The row number
    ///   - bands: The bands array
    /// - Returns: The band name string, or empty string if invalid
    func currentlySectionBandName(_ rowNumber: Int, bands: [String]) -> String {
        print("bands type in currentlySectionBandName:", type(of: bands))
        var bandName = ""
    
        print ("SelfBandCount is " + String(bands.count) + " rowNumber is " + String(rowNumber))
        
        // Add safety check for empty bands array during data refresh
        guard !bands.isEmpty else {
            print("ERROR: Bands array is empty in currentlySectionBandName - this may happen during data refresh")
            return ""
        }
        
        if (bands.count > rowNumber && rowNumber >= 0){
            bandName = bands[rowNumber]
        } else {
            print("ERROR: Invalid rowNumber \(rowNumber) for bands array (count: \(bands.count))")
        }
        
        return bandName
    }
    
    /// Updates the current viewing day from visible cells in the table view
    /// Uses the topmost visible entry that has a valid day as the key record
    /// - Parameters:
    ///   - tableView: The table view
    ///   - bands: The bands array
    ///   - currentViewingDay: Reference to the current viewing day variable to update
    func updateCurrentViewingDayFromVisibleCells(
        tableView: UITableView,
        bands: [String],
        currentViewingDay: inout String?
    ) {
        // CRITICAL: Get the actual topmost visible row by checking the exact top point of the visible area
        // This ensures we get the row that's truly at the top, not just any partially visible row
        // Use indexPathForRow(at:) with the top of the visible rect for accuracy
        let topPoint = CGPoint(x: tableView.bounds.midX, y: tableView.contentOffset.y + tableView.contentInset.top)
        var topmostRow: Int? = nil
        
        // First, try to get the row at the exact top point
        if let indexPath = tableView.indexPathForRow(at: topPoint) {
            topmostRow = indexPath.row
            print("🔍 [LANDSCAPE_SCHEDULE] Found row at top point: \(topmostRow!)")
        }
        
        // Fallback: Use the first visible row if we couldn't get the exact top
        if topmostRow == nil {
            if let visibleIndexPaths = tableView.indexPathsForVisibleRows, !visibleIndexPaths.isEmpty {
                // Sort by row number to find the actual topmost
                let sortedVisibleIndexPaths = visibleIndexPaths.sorted { $0.row < $1.row }
                topmostRow = sortedVisibleIndexPaths.first?.row
                print("🔍 [LANDSCAPE_SCHEDULE] Using first visible row as fallback: \(topmostRow!)")
            }
        }
        
        guard let startRow = topmostRow, startRow < bands.count else {
            print("⚠️ [LANDSCAPE_SCHEDULE] Could not determine topmost visible row")
            return
        }
        
        print("🔍 [LANDSCAPE_SCHEDULE] Topmost visible row: \(startRow), checking from there")
        
        // Search through rows starting from the topmost visible row
        // Check up to 20 rows to find the first one with a valid day
        // IMPORTANT: We want the FIRST entry that's actually visible at the top, not just any visible row
        // Also track the most common day in visible rows to handle edge cases where the first row
        // might be from the previous day but most visible rows are from the new day
        let maxRowsToCheck = min(20, bands.count - startRow)
        print("🔍 [LANDSCAPE_SCHEDULE] Checking \(maxRowsToCheck) rows starting from row \(startRow)")
        
        var firstValidDay: String? = nil
        var dayCounts: [String: Int] = [:]
        var rowsChecked = 0
        
        for offset in 0..<maxRowsToCheck {
            let row = startRow + offset
            guard row < bands.count else { break }
            
            let bandEntry = bands[row]
            rowsChecked += 1
            
            // Extract day from the band entry (format: "timeIndex:bandName")
            // Skip entries that don't have a timeIndex (band names without schedule)
            guard let timeIndexString = bandEntry.components(separatedBy: ":").first,
                  let timeIndex = Double(timeIndexString) else {
                print("🔍 [LANDSCAPE_SCHEDULE] Row \(row): No timeIndex (band name only), skipping")
                continue // Skip band names without schedule
            }
            
            let events = schedule.schedulingDataByTime[timeIndex] ?? []
            if let firstEvent = events.first, let day = firstEvent["Day"] {
                // Track the first valid day we find
                if firstValidDay == nil {
                    firstValidDay = day
                }
                
                // Count occurrences of each day
                dayCounts[day] = (dayCounts[day] ?? 0) + 1
                print("🔍 [LANDSCAPE_SCHEDULE] Row \(row) (offset \(offset)): day='\(day)'")
            } else {
                print("🔍 [LANDSCAPE_SCHEDULE] Row \(row): No events found for timeIndex \(timeIndex)")
            }
        }
        
        // Determine which day to use
        if let firstDay = firstValidDay {
            // If we found multiple days, use the most common one (likely the day that's actually visible)
            // Otherwise use the first day found
            if dayCounts.count > 1 {
                let mostCommonDay = dayCounts.max(by: { $0.value < $1.value })?.key ?? firstDay
                if mostCommonDay != firstDay {
                    print("⚠️ [LANDSCAPE_SCHEDULE] Multiple days found - using most common: '\(mostCommonDay)' (found \(dayCounts[mostCommonDay] ?? 0) times) instead of first: '\(firstDay)'")
                    currentViewingDay = mostCommonDay
                } else {
                    currentViewingDay = firstDay
                    print("✅ [LANDSCAPE_SCHEDULE] Updated viewing day from row \(startRow): '\(firstDay)'")
                }
            } else {
                currentViewingDay = firstDay
                print("✅ [LANDSCAPE_SCHEDULE] Updated viewing day from row \(startRow): '\(firstDay)'")
            }
        } else {
            print("⚠️ [LANDSCAPE_SCHEDULE] No valid day found after checking \(rowsChecked) rows")
        }
        
        print("⚠️ [LANDSCAPE_SCHEDULE] No valid day found in visible cells after checking \(maxRowsToCheck) rows starting from row \(startRow)")
    }
    
    /// Returns the first table view row index that belongs to the given day (e.g. "Day 3").
    /// Used when switching from calendar to list so the list can scroll to the same day.
    /// - Parameters:
    ///   - day: Day label to find (e.g. "Day 1", "Day 3")
    ///   - bands: The bands array (sortable entries with optional "timeIndex:bandName" format)
    /// - Returns: Row index of the first event on that day, or nil if not found
    func firstRowIndex(forDay day: String, bands: [String]) -> Int? {
        for (row, bandEntry) in bands.enumerated() {
            guard let timeIndex = bandEntry.components(separatedBy: ":").first?.doubleValue else { continue }
            let events = schedule.schedulingDataByTime[timeIndex] ?? []
            if let firstEvent = events.first, let eventDay = firstEvent["Day"], eventDay == day {
                return row
            }
        }
        return nil
    }
    
    /// Gets the number of rows for the table view
    /// - Parameter bands: The bands array
    /// - Returns: The number of rows
    func numberOfRows(bands: [String]) -> Int {
        let timestamp = CFAbsoluteTimeGetCurrent()
        print("📊 [TABLE_VIEW] numberOfRowsInSection CALLED at \(timestamp)")
        print("📊 [TABLE_VIEW] Current thread: \(Thread.current.isMainThread ? "MAIN" : "BACKGROUND")")
        print("📊 [TABLE_VIEW] bands.count = \(bands.count)")
        print("bands type:", type(of: bands))
        
        // Add safety check for empty bands array during data refresh
        if bands.isEmpty {
            print("⚠️ Bands array is empty in numberOfRowsInSection - this may happen during data refresh")
            return 0
        }
        
        print("📊 [TABLE_VIEW] Returning \(bands.count) rows")
        return bands.count
    }
    
    /// Handles willDisplay cell callback to track viewing day
    /// - Parameters:
    ///   - cell: The cell being displayed
    ///   - indexPath: The index path
    ///   - bands: The bands array
    ///   - showScheduleView: Whether schedule view is enabled
    ///   - currentViewingDay: Reference to the current viewing day variable to update
    func willDisplayCell(
        cell: UITableViewCell,
        forRowAt indexPath: IndexPath,
        bands: [String],
        showScheduleView: Bool,
        currentViewingDay: inout String?
    ) {
        // Track the currently visible day when in schedule view mode
        if showScheduleView && indexPath.row < bands.count {
            let bandEntry = bands[indexPath.row]
            
            // Extract day from the band entry (format: "timeIndex:bandName")
            if let timeIndex = bandEntry.components(separatedBy: ":").first?.doubleValue {
                let events = schedule.schedulingDataByTime[timeIndex] ?? []
                if let firstEvent = events.first, let day = firstEvent["Day"] {
                    currentViewingDay = day
                }
            }
        }
    }
    
    // MARK: - UI Updates
    
    /// Sets the filter title text based on active filters
    /// - Parameters:
    ///   - bands: The bands array (for early initialization check)
    ///   - listCount: The current list count
    ///   - searchText: The current search text
    ///   - filterTextNeeded: Reference to filterTextNeeded variable to update
    ///   - filtersOnText: Reference to filtersOnText variable to update
    func setFilterTitleText(
        bands: [String],
        listCount: Int,
        searchText: String?,
        filterTextNeeded: inout Bool,
        filtersOnText: inout String
    ) {
        print("🔧 [INIT_DEBUG] setFilterTitleText() ENTERED")
        
        // FIXED: Determine if filters are active by checking actual filter settings, not counts
        print("🔍 [FILTER_STATUS] Checking filter status...")
        
        // Check if ANY filters are active (non-default state)
        // DEFAULT STATE: All filters ON except attendance filter OFF
        let priorityFiltersActive = !(getMustSeeOn() == true && getMightSeeOn() == true && getWontSeeOn() == true && getUnknownSeeOn() == true)
        // Use persisted venue filter state: any venue (configured or discovered) with show: false means venue filters are active
        let allVenueStates = getAllVenueFilterStates()
        let venueFiltersActive = allVenueStates.values.contains(false)
        if !allVenueStates.isEmpty {
            let hiddenCount = allVenueStates.values.filter { !$0 }.count
            print("🔍 [FILTER_STATUS] Venue filter states: \(allVenueStates.count) total, \(hiddenCount) hidden")
        }
        let eventTypeFiltersActive = !(getShowSpecialEvents() == true && getShowUnofficalEvents() == true && getShowMeetAndGreetEvents() == true)
        let attendanceFilterActive = getShowOnlyWillAttened() == true  // Default is false, so true means active
        let searchActive = searchText?.isEmpty == false
        
        print("🔍 [FILTER_STATUS] ===== FILTER DETECTION =====")
        print("🔍 [FILTER_STATUS] Priority filters - Must:\(getMustSeeOn()), Might:\(getMightSeeOn()), Wont:\(getWontSeeOn()), Unknown:\(getUnknownSeeOn())")
        print("🔍 [FILTER_STATUS] Priority filters active: \(priorityFiltersActive)")
        print("🔍 [FILTER_STATUS] Venue filters active: \(venueFiltersActive)")  
        print("🔍 [FILTER_STATUS] Event type filters active: \(eventTypeFiltersActive)")
        print("🔍 [FILTER_STATUS] Unofficial events: \(getShowUnofficalEvents())")
        print("🔍 [FILTER_STATUS] Attendance filter active: \(attendanceFilterActive)")
        print("🔍 [FILTER_STATUS] Search active: \(searchActive)")
        
        // Enable Clear Filters if ANY filter is active (non-default)
        let anyFiltersActive = priorityFiltersActive || venueFiltersActive || eventTypeFiltersActive || attendanceFilterActive || searchActive
        filterTextNeeded = anyFiltersActive  // CORRECTED: Clear Filters enabled when filters are active
        
        print("🔍 [FILTER_STATUS] anyFiltersActive: \(anyFiltersActive)")
        print("🔍 [FILTER_STATUS] filterTextNeeded: \(filterTextNeeded)")
        print("🔍 [FILTER_STATUS] Summary: Clear All Filters should be \(filterTextNeeded ? "ENABLED" : "DISABLED")")
        
        print("🔍 [FILTER_STATUS] Final filterTextNeeded: \(filterTextNeeded)")
        
        // Set the filter text based on whether any filters are active
        if (filterTextNeeded == true){
            filtersOnText = "(" + NSLocalizedString("Filtering", comment: "") + ")"
        } else {
            filtersOnText = ""
        }
        
        print("🔍 [FILTER_STATUS] filtersOnText set to: '\(filtersOnText)'")
    }
    
    // MARK: - Icon Helpers
    
    /// Sets an icon with background color for a cell
    /// - Parameters:
    ///   - iconImage: The icon image
    ///   - backColor: The background color
    ///   - cellHeight: The cell height
    ///   - cellWidth: The cell width
    ///   - backgroundColor: Reference to backgroundColor variable to update
    func setIcon(
        iconImage: UIImage,
        backColor: UIColor,
        cellHeight: CGFloat,
        cellWidth: CGFloat,
        backgroundColor: inout UIColor
    ) {
        let cellFrame = CGRect(origin: .zero, size: CGSize(width: cellWidth*0.5, height: cellHeight))
        let imageFrame = CGRect(x:0, y:0,width:iconImage.size.width, height: iconImage.size.height)
        let insetFrame = cellFrame.insetBy(dx: ((cellFrame.size.width - imageFrame.size.width) / 2), dy: ((cellFrame.size.height - imageFrame.size.height) / 2))
        let targetFrame = insetFrame.offsetBy(dx: -(insetFrame.width / 2.0), dy: 0.0)
        let imageView = UIImageView(frame: imageFrame)
        imageView.image = iconImage
        imageView.contentMode = .left
        guard let resizedImage = imageView.image else { return }
        UIGraphicsBeginImageContextWithOptions(CGSize(width: cellWidth, height: cellHeight), false, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        backColor.setFill()
        context.fill(CGRect(x:0, y:0, width:cellWidth, height:cellHeight))
        resizedImage.draw(in: CGRect(x:(targetFrame.origin.x / 2), y: targetFrame.origin.y, width:targetFrame.width, height:targetFrame.height))
        guard let actionImage = UIGraphicsGetImageFromCurrentImageContext() else { return }
        UIGraphicsEndImageContext()
        backgroundColor = UIColor.init(patternImage: actionImage)
    }
}

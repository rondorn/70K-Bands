//
//  SortMenuController.swift
//  70K Bands
//
//  Created by Ron Dorn on 6/11/16.
//  Copyright © 2016 Ron Dorn. All rights reserved.
//

import Foundation

import Foundation
import UIKit

// Helper function to check if there are any events in the database (regardless of filters/view mode)
func hasAnyEvents() -> Bool {
    let allEvents = DataManager.shared.fetchEvents(forYear: eventYear)
    return allEvents.count > 0
}

// Helper function to check if there are any expired events
func hasExpiredEvents() -> Bool {
    let currentTime = Date().timeIntervalSinceReferenceDate
    let allEvents = DataManager.shared.fetchEvents(forYear: eventYear)
    
    // Check if any event has expired (endTimeIndex + 10 min buffer < currentTime)
    return allEvents.contains { event in
        var endTimeIndex = event.endTimeIndex
        // Detect midnight crossing - add 24 hours if needed
        if event.timeIndex > endTimeIndex {
            endTimeIndex += 86400
        }
        // Add 10-minute buffer (600 seconds) before considering expired
        return endTimeIndex + 600 < currentTime
    }
}

func createrFilterMenu( controller: MasterViewController){
    
    controller.refreshData()
    controller.filterMenu = DropDown()
    controller.filterMenu.anchorView = controller.filterMenuButton
    controller.filterMenu.bottomOffset = CGPoint(x: -20, y:(controller.filterMenu.anchorView?.plainView.bounds.height)!)
    
    
    
    controller.filterMenu.dataSource = [
        "Clear Filters",
        "Clear All Filters"
    ]
    
    // NOTE: Profile selection moved to title button tap (not in filter menu anymore)
    
    // Determine if we should show schedule-related filters
    let hasScheduledEvents = (eventCount > 0 && eventCounterUnoffical != eventCount)
    let showScheduleView = getShowScheduleView()
    let showScheduleFilters = hasScheduledEvents && showScheduleView
    
    // Add Hide Expired Events option (TOP choice) - only when events exist and at least one is expired
    // Check raw criteria: events exist in database (regardless of view mode/filters) and at least one has expired
    if hasAnyEvents() && hasExpiredEvents() {
        controller.filterMenu.dataSource.append("Expired Events Header")
        controller.filterMenu.dataSource.append("Expired Events")
    }
    
    // Add Band Ranking Filters section (always shown)
    controller.filterMenu.dataSource.append("Band Ranking Filters")
    controller.filterMenu.dataSource.append("Must See Items")
    controller.filterMenu.dataSource.append("Might See Items")
    controller.filterMenu.dataSource.append("Wont See Items")
    controller.filterMenu.dataSource.append("Unknown Items")
    
    // SCHEDULE-RELATED FILTERS: Only show when in Schedule mode AND scheduled events exist
    if showScheduleFilters {
        controller.filterMenu.dataSource.append("Flagged Header")
        controller.filterMenu.dataSource.append("Flagged Items")
        controller.filterMenu.dataSource.append("Sort Header")
        controller.filterMenu.dataSource.append("Sort By")
    }
    
    // EVENT TYPE FILTERS: Handle scheduled and unofficial event filters separately
    
    // Show scheduled event type filters (Meet & Greet, Special Events) only when scheduled events exist
    let showScheduledEventTypeFilters = showScheduleFilters && (getMeetAndGreetsEnabled() || getSpecialEventsEnabled())
    
    // Show unofficial events filter if enabled and in schedule view (even if only unofficial events exist)
    let showUnofficalEventFilter = getUnofficalEventsEnabled() && showScheduleView
    
    // Add event type filter section if any event type filters should be shown
    if showScheduledEventTypeFilters || showUnofficalEventFilter {
        controller.filterMenu.dataSource.append("Event Type Filters")
        
        // Only show Meet & Greet and Special Events when scheduled events exist
        if showScheduleFilters {
            if getMeetAndGreetsEnabled() {
                controller.filterMenu.dataSource.append("Meet and Greet Events")
            }
            if getSpecialEventsEnabled() {
                controller.filterMenu.dataSource.append("Special Events")
            }
        }
        
        // Show Unofficial Events filter even when only unofficial events exist (as long as in schedule view)
        if showUnofficalEventFilter {
            controller.filterMenu.dataSource.append("Unoffical Events")
        }
    }
    
    // VENUE FILTERS: Only show when in Schedule mode AND scheduled events exist
    if showScheduleFilters {
        // Dynamically add venue options based on FestivalConfig (only venues with showInFilters=true)
        let configuredVenues = FestivalConfig.current.getFilterVenueNames()
        for venueName in configuredVenues {
            controller.filterMenu.dataSource.append("\(venueName) Venue")
        }
        
        controller.filterMenu.dataSource.append("Other Venue")        
    }
        
    controller.filterMenu.width = 300
    

    let appearance = DropDown.appearance()
    
    appearance.cellHeight = 40
    appearance.backgroundColor = UIColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1.0)
    appearance.selectionBackgroundColor = UIColor.darkGray
    appearance.separatorColor = UIColor.lightGray
    appearance.cornerRadius = 10
    appearance.shadowColor = UIColor.black
    appearance.shadowOpacity = 0.9
    appearance.shadowRadius = 25
    appearance.animationduration = 0.25
    appearance.textColor = .white
    appearance.selectedTextColor = UIColor.lightGray
    appearance.setupMaskedCorners([.layerMaxXMaxYCorner, .layerMinXMaxYCorner])

    controller.filterMenu.cellNib = UINib(nibName: "CustomListEntry", bundle: nil)
    
    controller.filterMenuButton.setTitle(NSLocalizedString("Filters", comment: ""), for: UIControl.State.normal)
    
    setupAllEntries(controller: controller)
    
    setupClickResponse(controller: controller)
}

func setupAllEntries(controller: MasterViewController){
    
    controller.filterMenu.customCellConfiguration = { (index: Index, item: String, cell: DropDownCell) -> Void in
        guard var cell = cell as? CustomListEntry else { return }

        setupHeadersAndMisc(controller: controller, item: item, cellRow: cell)
        setupExpiredEventsMenuChoices(controller: controller, item: item, cellRow: cell)
        setupFlaggedOnlylMenuChoices(controller: controller, item: item, cellRow: cell)
        setupSortMenuChoices(controller: controller, item: item, cellRow: cell)
        setupClearAllMenuChoices(controller: controller, item: item, cellRow: cell)
        setupMustMightMenuChoices(controller: controller, item: item, cellRow: cell)
        setupEventTypeMenuChoices(controller: controller, item: item, cellRow: cell)
        setupVenueMenuChoices(controller: controller, item: item, cellRow: cell)
    }
}

func setupHeadersAndMisc(controller: MasterViewController, item: String, cellRow: CustomListEntry){

    if (item == "Clear Filters"){
        setupCell(header: true, titleText: NSLocalizedString("Clear Filters", comment: ""), cellData: cellRow, imageName: "", disabled: false)
        
    } else if (item == "Location Header"){
        setupCell(header: true, titleText: NSLocalizedString("Location Header", comment: ""), cellData: cellRow, imageName: "", disabled: false)
        
    } else if (item == "Band Ranking Filters"){
        setupCell(header: true, titleText: NSLocalizedString("Band Ranking Filters", comment: ""), cellData: cellRow, imageName: "", disabled: false)
        
    } else if (item == "Flagged Header"){
        if (eventCount > 0 && eventCounterUnoffical != eventCount){
            setupCell(header: true, titleText: NSLocalizedString("Show Only Flagged As Attended", comment: "") , cellData: cellRow, imageName: unknownIcon, disabled: false)
        }
        
    } else if (item == "Event Type Filters"){
        setupCell(header: true, titleText: NSLocalizedString("Event Type Filters", comment: ""), cellData: cellRow, imageName: "", disabled: false)
        
    } else if (item == "Sort Header"){
        setupCell(header: true, titleText: NSLocalizedString("Sorting Options", comment: ""), cellData: cellRow, imageName: "", disabled: false)
        
    } else if (item == "Venue Filters"){
        setupCell(header: true, titleText: NSLocalizedString("Venue Filters", comment: ""), cellData: cellRow, imageName: "", disabled: false)
    } else if (item == "Expired Events Header"){
        setupCell(header: true, titleText: NSLocalizedString("Expired Events", comment: ""), cellData: cellRow, imageName: "", disabled: false)
    }
}

func setupClickResponse(controller: MasterViewController){
    
    controller.filterMenu.selectionAction = { [weak controller] (index, item) in
        
        setupMustMightClickResponse(controller: controller!, item: item)
        setupClearClickResponse(controller: controller!, item: item)
        setupExpiredEventsClickResponse(controller: controller!, item: item)
        setupFlaggedOnlyResponse(controller: controller!, item: item)
        setupSortResponse(controller: controller!, item: item)
        setupEventTypeClickResponse(controller: controller!, item: item)
        setupVenueClickResponse(controller: controller!, item: item)
        print ("The respond from the chosen one is \(item) = \(index)")
        
        // CRITICAL FIX: Update filter state immediately before refreshing menu display
        // This ensures filterTextNeeded is current when setupAllEntries() uses it
        controller!.setFilterTitleText()
        
        // IMMEDIATE MENU UPDATE: Refresh menu display immediately after setting changes
        // This ensures menu text/icons update instantly before the full data refresh
        setupAllEntries(controller: controller!)
    }
}

func setupSortResponse(controller: MasterViewController, item: String){

    if (item == "Sort By"){
        if (getSortedBy() == "name"){
            setSortedBy("time")
        } else {
            setSortedBy("name")
        }
        refreshAfterMenuSelected(controller: controller, message: "")
    }
}

func setupSortMenuChoices(controller: MasterViewController, item: String, cellRow: CustomListEntry){

    if (item == "Sort By"){
        if (getSortedBy() == "name"){
            setupCell(header: false, titleText: NSLocalizedString("Sort By Time", comment: "") , cellData: cellRow, imageName: scheduleIconSort, disabled: false)
        } else {
            setupCell(header: false, titleText: NSLocalizedString("Sort By Name", comment: "") , cellData: cellRow, imageName: bandIconSort, disabled: false)
        }
    }
}

func setupExpiredEventsClickResponse(controller: MasterViewController, item: String){
    
    if (item == "Expired Events"){
        var message = NSLocalizedString("Show Expired Events", comment: "")
        if (getHideExpireScheduleData() == true){
            setHideExpireScheduleData(false)
            message = NSLocalizedString("Showing Expired Events", comment: "")
        } else {
            setHideExpireScheduleData(true)
            message = NSLocalizedString("Hiding Expired Events", comment: "")
        }
        refreshAfterMenuSelected(controller: controller, message: message)
    }
}

func setupExpiredEventsMenuChoices(controller: MasterViewController, item: String, cellRow: CustomListEntry){
    
    if (item == "Expired Events"){
        // Simple criteria: events exist in database and at least one is expired (regardless of view mode/filters)
        let eventsExist = hasAnyEvents()
        let hasExpired = hasExpiredEvents()
        
        // Enable filter only when events exist and at least one has expired
        let shouldEnableFilter = eventsExist && hasExpired
        
        if (getHideExpireScheduleData() == false){
            setupCell(header: false, titleText: NSLocalizedString("Hide Expired Events", comment: ""), cellData: cellRow, imageName: scheduleIconSort, disabled: !shouldEnableFilter)
        } else {
            setupCell(header: false, titleText: NSLocalizedString("Show Expired Events", comment: "") , cellData: cellRow, imageName: scheduleIconSort, disabled: !shouldEnableFilter)
        }
        
        if (!shouldEnableFilter){
            print("🔍 [EXPIRED_FILTER_DEBUG] ❌ Disabling 'Hide Expired Events'")
            print("🔍 [EXPIRED_FILTER_DEBUG]   - eventsExist: \(eventsExist)")
            print("🔍 [EXPIRED_FILTER_DEBUG]   - hasExpired: \(hasExpired)")
            cellRow.optionLabel.textColor = UIColor.darkGray
        } else {
            print("🔍 [EXPIRED_FILTER_DEBUG] ✅ Enabling 'Hide Expired Events'")
            print("🔍 [EXPIRED_FILTER_DEBUG]   - eventsExist: \(eventsExist)")
            print("🔍 [EXPIRED_FILTER_DEBUG]   - hasExpired: \(hasExpired)")
        }
    }
}

func setupFlaggedOnlyResponse(controller: MasterViewController, item: String){

    if (item == "Flagged Items"){
        var message = NSLocalizedString("Show All Events", comment: "")
        if (getShowOnlyWillAttened() == true){
            setShowOnlyWillAttened(false)
        } else {
            setShowOnlyWillAttened(true)
            message = NSLocalizedString("Show Only Events Flagged As Attending", comment: "")
        }
        if (attendingCount == 0){
            setShowOnlyWillAttened(false)
        }

        refreshAfterMenuSelected(controller: controller, message: message)
    }
}

func setupFlaggedOnlylMenuChoices(controller: MasterViewController, item: String, cellRow: CustomListEntry){

    if (item == "Flagged Items"){
        // Determine if we should enable the filter based on three conditions:
        // 1. Events are being displayed (showScheduleView)
        // 2. All events are NOT Cruiser Organize or Unofficial (hasScheduledEvents)
        // 3. At least one event is flagged as will attend (attendingCount > 0)
        let showScheduleView = getShowScheduleView()
        let hasScheduledEvents = (eventCount > 0 && eventCounterUnoffical != eventCount)
        let hasFlaggedEvents = attendingCount > 0
        
        // Enable filter only when all three conditions are met:
        // - We're in schedule view (events are being displayed)
        // - Not all events are unofficial/cruiser organized
        // - At least one event is flagged
        let shouldEnableFilter = showScheduleView && hasScheduledEvents && hasFlaggedEvents
        
        if (getShowOnlyWillAttened() == false){
            setupCell(header: false, titleText: NSLocalizedString("Show Flagged Events Only", comment: ""), cellData: cellRow, imageName: attendedShowIcon, disabled: !shouldEnableFilter)
        } else {
            setupCell(header: false, titleText: NSLocalizedString("Show All Events", comment: "") , cellData: cellRow, imageName: attendedShowIconAlt, disabled: !shouldEnableFilter)
        }
        
        if (!shouldEnableFilter){
            print("🔍 [FLAGGED_FILTER_DEBUG] ❌ Disabling 'Show Flagged Events Only'")
            print("🔍 [FLAGGED_FILTER_DEBUG]   - showScheduleView: \(showScheduleView)")
            print("🔍 [FLAGGED_FILTER_DEBUG]   - hasScheduledEvents: \(hasScheduledEvents) (eventCount: \(eventCount), eventCounterUnoffical: \(eventCounterUnoffical))")
            print("🔍 [FLAGGED_FILTER_DEBUG]   - hasFlaggedEvents: \(hasFlaggedEvents) (attendingCount: \(attendingCount))")
            setupCell(header: false, titleText: NSLocalizedString("Show Flagged Events Only", comment: "") , cellData: cellRow, imageName: attendedShowIconAlt, disabled: true)
            cellRow.optionLabel.textColor = UIColor.darkGray
        } else {
            print("🔍 [FLAGGED_FILTER_DEBUG] ✅ Enabling 'Show Flagged Events Only'")
            print("🔍 [FLAGGED_FILTER_DEBUG]   - showScheduleView: \(showScheduleView)")
            print("🔍 [FLAGGED_FILTER_DEBUG]   - hasScheduledEvents: \(hasScheduledEvents) (eventCount: \(eventCount), eventCounterUnoffical: \(eventCounterUnoffical))")
            print("🔍 [FLAGGED_FILTER_DEBUG]   - hasFlaggedEvents: \(hasFlaggedEvents) (attendingCount: \(attendingCount))")
        }
    }
}
    
func setupClearClickResponse(controller: MasterViewController, item: String){
    
    if (item == "Clear All Filters"){
        print("🔄 [CLEAR_DEBUG] Clear All Filters clicked - resetting all filters to default state")
        var message = NSLocalizedString("Clear All Items", comment: "")
        setShowOnlyWillAttened(false)
        setHideExpireScheduleData(false) // Reset Hide Expired Events filter
        
        // Reset all dynamic venues to true
        setAllVenueFilters(show: true)
        
        // Also reset the legacy hardcoded venue settings for backward compatibility
        setShowPoolShows(true)
        setShowRinkShows(true)
        setShowLoungeShows(true)
        setShowTheaterShows(true)
        setShowOtherShows(true)
        setShowSpecialEvents(true)
        setShowUnofficalEvents(true)
        setShowMeetAndGreetEvents(true)
        setMustSeeOn(true)
        setMightSeeOn(true)
        setWontSeeOn(true)
        setUnknownSeeOn(true)
        
        print("🔄 [CLEAR_DEBUG] All filters reset - calling refreshAfterMenuSelected")
        refreshAfterMenuSelected(controller: controller, message: message)
        
        
    }
}

func setupClearAllMenuChoices(controller: MasterViewController, item: String, cellRow: CustomListEntry){

    if (item == "Clear All Filters"){
        print("🔄 [CLEAR_DEBUG] Setting up Clear All Filters menu item - filterTextNeeded: \(controller.filterTextNeeded)")
        if (controller.filterTextNeeded == true){
            print("🔄 [CLEAR_DEBUG] Clear All Filters ENABLED")
            setupCell(header: false, titleText: NSLocalizedString("Clear All Filters", comment: ""), cellData: cellRow, imageName: "", disabled: false)
        } else {
            print("🔄 [CLEAR_DEBUG] Clear All Filters DISABLED")
            setupCell(header: false, titleText: NSLocalizedString("Clear All Filters", comment: ""), cellData: cellRow, imageName: "", disabled: true)
        }
    }
    
}

func setupVenueClickResponse(controller: MasterViewController, item: String){
    
    // Handle dynamic venues from FestivalConfig (only venues with showInFilters=true)
    let configuredVenues = FestivalConfig.current.getFilterVenueNames()
    
    for venueName in configuredVenues {
        if (item == "\(venueName) Venue" && blockTurningAllFiltersOn(controller:controller) == false){
            var message = "\(venueName) Venue Filter Off"
            if (getShowVenueEvents(venueName: venueName) == true){
                setShowVenueEvents(venueName: venueName, show: false)
                message = "\(venueName) Venue Filter On"
            } else {
                setShowVenueEvents(venueName: venueName, show: true)
            }
            if (blockTurningAllFiltersOn(controller: controller) == true){
                setShowVenueEvents(venueName: venueName, show: true)
            } else {
                refreshAfterMenuSelected(controller: controller, message: message)
            }
            return // Exit early once we found the matching venue
        }
    }
    
    // Keep backward compatibility with the hardcoded venue methods if needed
    // This allows for a smoother transition
    if item == "Pool Venue" {
        var message = NSLocalizedString("Pool Venue Filter Off", comment: "")
        if (getShowPoolShows() == true){
            setShowPoolShows(false)
            message = NSLocalizedString("Pool Venue Filter On", comment: "")
        } else {
            setShowPoolShows(true)
        }
        if (blockTurningAllFiltersOn(controller: controller) == true){
            setShowPoolShows(true)
        } else {
            refreshAfterMenuSelected(controller: controller, message: message)
        }
    }
    
    if (item == "Other Venue" && blockTurningAllFiltersOn(controller:controller) == false){
        var message = NSLocalizedString("Other Venue Filter Off", comment: "")
        if (getShowOtherShows() == true){
            setShowOtherShows(false)
            message = NSLocalizedString("Other Venue Filter On", comment: "")
        } else {
            setShowOtherShows(true)
        }
        if (blockTurningAllFiltersOn(controller: controller) == true){
            setShowOtherShows(true)
        } else {
            refreshAfterMenuSelected(controller: controller, message: message)
        }
    }
}

func setupVenueMenuChoices(controller: MasterViewController, item: String, cellRow: CustomListEntry){
    
    // Handle dynamic venues from FestivalConfig (only venues with showInFilters=true)
    let configuredVenues = FestivalConfig.current.getFilterVenueNames()
    
    for venueName in configuredVenues {
        if (item == "\(venueName) Venue"){
            let venue = FestivalConfig.current.getVenue(named: venueName)
            var currentIcon = venue?.notGoingIcon ?? "Unknown-NotGoing-wBox"
            var currentText = "Show \(venueName) Events"
            
            if (getShowVenueEvents(venueName: venueName) == true){
                currentIcon = venue?.goingIcon ?? "Unknown-Going-wBox"
                currentText = "Hide \(venueName) Events"
            }
            
            setupCell(header: false, titleText: currentText , cellData: cellRow, imageName: currentIcon, disabled: false)
            if (getShowOnlyWillAttened() == true){
                setupCell(header: false, titleText: currentText , cellData: cellRow, imageName: venue?.notGoingIcon ?? "Unknown-NotGoing-wBox", disabled: true)
                cellRow.optionLabel.textColor = UIColor.darkGray
            }
            return // Exit early once we found the matching venue
        }
    }
    
    // Handle "Other Venue" (catch-all for non-configured venues)
    if (item == "Other Venue"){
        var currentIcon = unknownIconAlt
        var currentText = NSLocalizedString("Show Other Venues", comment: "")
        if (getShowOtherShows() == true){
            currentIcon = unknownIcon
            currentText = NSLocalizedString("Hide Other Venues", comment: "")
        }
        setupCell(header: false, titleText: currentText , cellData: cellRow, imageName: currentIcon, disabled: false)
        if (getShowOnlyWillAttened() == true){
            setupCell(header: false, titleText: currentText , cellData: cellRow, imageName: unknownIconAlt, disabled: true)
            cellRow.optionLabel.textColor = UIColor.darkGray
        }
    }
}

func setupMustMightClickResponse(controller: MasterViewController, item: String){
    
    if (item == "Must See Items" && blockTurningAllFiltersOn(controller:controller) == false){
        var message = NSLocalizedString("Must See Filter On", comment: "")
        if (getMustSeeOn() == true){
            setMustSeeOn(false)
            message = NSLocalizedString("Must See Filter Off", comment: "")
        } else {
            setMustSeeOn(true)
        }
        if (blockTurningAllFiltersOn(controller: controller) == true){
            setMustSeeOn(true)
        } else {
            refreshAfterMenuSelected(controller: controller, message: message)
        }
        
    } else if (item == "Might See Items" && blockTurningAllFiltersOn(controller:controller) == false){
        var message = NSLocalizedString("Might See Filter On", comment: "")
        if (getMightSeeOn() == true){
            setMightSeeOn(false)
            message = NSLocalizedString("Might See Filter Off", comment: "")
        } else {
            setMightSeeOn(true)
        }
        if (blockTurningAllFiltersOn(controller: controller) == true){
            setMightSeeOn(true)
        } else {
            refreshAfterMenuSelected(controller: controller, message: message)
        }
        
    } else if (item == "Wont See Items" && blockTurningAllFiltersOn(controller:controller) == false){
        var message = NSLocalizedString("Wont See Filter On", comment: "")
        if (getWontSeeOn() == true){
            setWontSeeOn(false)
            message = NSLocalizedString("Wont See Filter Off", comment: "")
        } else {
            setWontSeeOn(true)
        }
        if (blockTurningAllFiltersOn(controller: controller) == true){
            setWontSeeOn(true)
        } else {
            refreshAfterMenuSelected(controller: controller, message: message)
        }
      
    } else if (item == "Unknown Items" && blockTurningAllFiltersOn(controller:controller) == false){
        var message = NSLocalizedString("Unknown Filter On", comment: "")
        if (getUnknownSeeOn() == true){
            setUnknownSeeOn(false)
            message = NSLocalizedString("Unknown Filter Off", comment: "")
        } else {
            setUnknownSeeOn(true)
        }
        if (blockTurningAllFiltersOn(controller: controller) == true){
            setUnknownSeeOn(true)
        } else {
            refreshAfterMenuSelected(controller: controller, message: message)
        }
    }
}

func setupMustMightMenuChoices(controller: MasterViewController, item: String, cellRow: CustomListEntry){

    if (item == "Must See Items"){
        var currentMustSeeIcon = mustSeeIconAlt
        var currentMustSeeText = NSLocalizedString("Show Must See Items", comment: "")
        if (getMustSeeOn() == true){
            currentMustSeeIcon = mustSeeIcon
            currentMustSeeText = NSLocalizedString("Hide Must See Items", comment: "")
        }
        setupCell(header: false, titleText: currentMustSeeText , cellData: cellRow, imageName: currentMustSeeIcon, disabled: false)
        if (getShowOnlyWillAttened() == true){
            setupCell(header: false, titleText: currentMustSeeText , cellData: cellRow, imageName: mustSeeIconAlt, disabled: true)
            cellRow.optionLabel.textColor = UIColor.darkGray
        }
        
    } else if (item == "Might See Items"){
        var currentMightSeeIcon = mightSeeIconAlt
        var currentMightSeeText = NSLocalizedString("Show Might See Items", comment: "")
        if (getMightSeeOn() == true){
            currentMightSeeIcon = mightSeeIcon
            currentMightSeeText = NSLocalizedString("Hide Might See Items", comment: "")
        }
        setupCell(header: false, titleText: currentMightSeeText , cellData: cellRow, imageName: currentMightSeeIcon, disabled: false)
        if (getShowOnlyWillAttened() == true){
            setupCell(header: false, titleText: currentMightSeeText , cellData: cellRow, imageName: mightSeeIconAlt, disabled: true)
            cellRow.optionLabel.textColor = UIColor.darkGray
        }
        
    } else if (item == "Wont See Items"){
        var currentWontSeeIcon = wontSeeIconAlt
        var currentWontSeeText = NSLocalizedString("Show Wont See Items", comment: "")
        if (getWontSeeOn() == true){
            currentWontSeeIcon = wontSeeIcon
            currentWontSeeText = NSLocalizedString("Hide Wont See Items", comment: "")
        }
        setupCell(header: false, titleText: currentWontSeeText , cellData: cellRow, imageName: currentWontSeeIcon, disabled: false)
        if (getShowOnlyWillAttened() == true){
            setupCell(header: false, titleText: currentWontSeeText , cellData: cellRow, imageName: wontSeeIconAlt, disabled: true)
            cellRow.optionLabel.textColor = UIColor.darkGray
        }
        
    } else if (item == "Unknown Items"){
        var currentUnknownIcon = unknownIconAlt
        var currentUnknownText = NSLocalizedString("Show Unknown Items", comment: "")
        if (getUnknownSeeOn() == true){
            currentUnknownIcon = unknownIcon
            currentUnknownText = NSLocalizedString("Hide Unknown Items", comment: "")
        }
        setupCell(header: false, titleText: currentUnknownText , cellData: cellRow, imageName: currentUnknownIcon, disabled: false)
        if (getShowOnlyWillAttened() == true){
            setupCell(header: false, titleText: currentUnknownText , cellData: cellRow, imageName: unknownIconAlt, disabled: true)
            cellRow.optionLabel.textColor = UIColor.darkGray
        }
    }
}

func setupEventTypeClickResponse(controller: MasterViewController, item: String){

    if (item == "Meet and Greet Events"){
        var message = NSLocalizedString("Meet and Greet Event Filter On", comment: "")
        if (getShowMeetAndGreetEvents() == false){
            setShowMeetAndGreetEvents(true)
            message = NSLocalizedString("Meet and Greet Event Filter Off", comment: "")
        } else {
            setShowMeetAndGreetEvents(false)
        }
        refreshAfterMenuSelected(controller: controller, message: message)
        
    }
    if (item == "Special Events"){
        var message = NSLocalizedString("Special/Other Event Filter On", comment: "")
        if (getShowSpecialEvents() == false){
            setShowSpecialEvents(true)
            message = NSLocalizedString("Special/Other Event Filter Off", comment: "")
        } else {
            setShowSpecialEvents(false)
        }
        refreshAfterMenuSelected(controller: controller, message: message)
        
    }
    if (item == "Unoffical Events"){
        var message = NSLocalizedString("Unofficial Event Filter On", comment: "")
        if (getShowUnofficalEvents() == false){
            setShowUnofficalEvents(true)
            message = NSLocalizedString("Unofficial Event Filter Off", comment: "")
        } else {
            setShowUnofficalEvents(false)
        }
        refreshAfterMenuSelected(controller: controller, message: message)
    }
}

func setupEventTypeMenuChoices(controller: MasterViewController, item: String, cellRow: CustomListEntry){
    
    if (item == "Meet and Greet Events"){
        var currentIcon = meetAndGreetIconAlt
        var currentText = NSLocalizedString("Show Meet & Greet Events", comment: "")
        if (getShowMeetAndGreetEvents() == true){
            currentIcon = meetAndGreetIcon
            currentText = NSLocalizedString("Hide Meet & Greet Events", comment: "")
        }
        setupCell(header: false, titleText: currentText , cellData: cellRow, imageName: currentIcon, disabled: false)
        if (getShowOnlyWillAttened() == true){
            setupCell(header: false, titleText: currentText , cellData: cellRow, imageName: meetAndGreetIconAlt, disabled: true)
            cellRow.optionLabel.textColor = UIColor.darkGray
        }
        
    } else if (item == "Special Events"){
        var currentIcon = specialEventTypeIconAlt
        var currentText = NSLocalizedString("Show Special/Other Events", comment: "")
        if (getShowSpecialEvents() == true){
            currentIcon = specialEventTypeIcon
            currentText = NSLocalizedString("Hide Special/Other Events", comment: "")
        }
        setupCell(header: false, titleText: currentText , cellData: cellRow, imageName: currentIcon, disabled: false)
        if (getShowOnlyWillAttened() == true){
            setupCell(header: false, titleText: currentText , cellData: cellRow, imageName: specialEventTypeIconAlt, disabled: true)
            cellRow.optionLabel.textColor = UIColor.darkGray
        }
        
    } else if (item == "Unoffical Events"){
        var currentIcon = unofficalEventTypeIconAlt
        var currentText = NSLocalizedString("Show Unofficial Events", comment: "")
        if (getShowUnofficalEvents() == true){
            currentIcon = unofficalEventTypeIcon
            currentText = NSLocalizedString("Hide Unofficial Events", comment: "")
        }
        setupCell(header: false, titleText: currentText , cellData: cellRow, imageName: currentIcon, disabled: false)
        if (getShowOnlyWillAttened() == true){
            setupCell(header: false, titleText: currentText , cellData: cellRow, imageName: unofficalEventTypeIconAlt, disabled: true)
            cellRow.optionLabel.textColor = UIColor.darkGray
        }
    }
}

func setupCell(header: Bool, titleText: String, cellData: CustomListEntry, imageName: String, disabled: Bool){
    var newCell = cellData
    
    if (header == true){
        newCell.logoImageView.isHidden = true
        newCell.isUserInteractionEnabled = false
        newCell.optionLabel.font = (UIFont.systemFont(ofSize: 14))
        newCell.optionLabel.textColor = UIColor.lightGray
        newCell.optionLabel.text = titleText
        newCell.logoImageView.isHidden = true
        
    } else {
        newCell.logoImageView.isHidden = false
        newCell.isUserInteractionEnabled = true
        newCell.optionLabel.font = (UIFont.systemFont(ofSize: 18))
        newCell.optionLabel.textColor = UIColor (.white)
        newCell.optionLabel.text = "\t" + titleText
        if (imageName.isEmpty == false){
            newCell.logoImageView.image = UIImage(named: imageName)
            newCell.logoImageView.isHidden = false
        } else {
            newCell.logoImageView.isHidden = true
        }
        if (disabled == true){
            newCell.optionLabel.textColor = UIColor.lightGray
            newCell.isUserInteractionEnabled = false
            
        }
    }
}

func blockTurningAllFiltersOn(controller: MasterViewController)->Bool{
    
    var blockChange = false
    
    let visibleLocation = CGRect(origin: controller.mainTableView.contentOffset, size: controller.mainTableView.bounds.size)
    var message = ""
    var venueCouner = 0
    
    // Check if all dynamic venues are disabled (only venues with showInFilters=true)
    let configuredVenues = FestivalConfig.current.getFilterVenueNames()
    var allVenuesDisabled = true
    
    // Check dynamic venues
    for venueName in configuredVenues {
        if getShowVenueEvents(venueName: venueName) == true {
            allVenuesDisabled = false
            break
        }
    }
    
    // Also check "Other" shows
    if getShowOtherShows() == true {
        allVenuesDisabled = false
    }
    
    if allVenuesDisabled {
        blockChange = true
        message = NSLocalizedString("Can not hide all venues", comment: "")
    }
    
    if (getMustSeeOn() == false &&
        getMightSeeOn() == false &&
        getWontSeeOn() == false &&
        getUnknownSeeOn() == false){
        blockChange = true
        message = NSLocalizedString("Can not hide all statuses", comment: "")
    }
    
    if (message.isEmpty == false){
        var visibleLocation: CGRect
        if #available(iOS 16.0, *) {
            var location = controller.filterMenuButton.anchorPoint
            visibleLocation = CGRect(origin: location, size: controller.mainTableView.bounds.size)
        } else {
            visibleLocation = CGRect(origin: controller.mainTableView.contentOffset, size: controller.mainTableView.bounds.size)

        }
        ToastMessages(message).show(controller, cellLocation: visibleLocation, placeHigh: true)
    }
    
    return blockChange
}

func refreshAfterMenuSelected(controller: MasterViewController, message: String){
       
    writeFiltersFile()
    setupAllEntries(controller: controller)
    controller.quickRefresh_Pre()
    NotificationCenter.default.post(name: Notification.Name(rawValue: "refreshGUI"), object: nil)
    
    // Re-evaluate list vs calendar in landscape after filter change (e.g. Hide Expired Events off → calendar should appear)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        controller.recheckLandscapeScheduleAfterFilterChange()
    }
    
    if (message.isEmpty == false){
        var visibleLocation: CGRect
        if #available(iOS 16.0, *) {
            var location = controller.filterMenuButton.anchorPoint
            visibleLocation = CGRect(origin: location, size: controller.mainTableView.bounds.size)
        } else {
            visibleLocation = CGRect(origin: controller.mainTableView.contentOffset, size: controller.mainTableView.bounds.size)

        }
        ToastMessages(message).show(controller, cellLocation: visibleLocation, placeHigh: true)
    }
    
}

func setupViewModeClickResponse(controller: MasterViewController, item: String){
    if (item == "View Mode Toggle"){
        if (getShowScheduleView()){
            // Switching to Bands Only mode
            setShowScheduleView(false)
            // AUTO SORT FIX: Automatically set alphabetical sort for Bands Only
            setSortedBy("name")
            print("🔄 [VIEW_MODE_DEBUG] Switched to Bands Only - Auto-set Sort Alphabetically")
        } else {
            // Switching to Schedule View mode
            setShowScheduleView(true)
            // AUTO SORT FIX: Automatically set time-based sort for Schedule View
            setSortedBy("time")
            print("🔄 [VIEW_MODE_DEBUG] Switched to Schedule View - Auto-set Sort by Time")
        }
        
        // Close the menu immediately since view mode changes what menu items are shown
        controller.filterMenu.hide()
        
        // Refresh data and rebuild menu for next time it's opened
        writeFiltersFile()
        controller.quickRefresh_Pre()
        NotificationCenter.default.post(name: Notification.Name(rawValue: "refreshGUI"), object: nil)
    }
}

func setupViewModeMenuChoices(controller: MasterViewController, item: String, cellRow: CustomListEntry){
    if (item == "View Mode Toggle"){
        if (getShowScheduleView()){
            // Currently showing schedule - offer option to switch to bands only
            setupCell(header: false, titleText: NSLocalizedString("Show Bands Only", comment: "") , cellData: cellRow, imageName: bandIconSort, disabled: false)
        } else {
            // Currently showing bands only - offer option to switch to schedule
            setupCell(header: false, titleText: NSLocalizedString("Show Schedule", comment: "") , cellData: cellRow, imageName: scheduleIconSort, disabled: false)
        }
    }
}

// MARK: - Shared Preferences (now handled in title button tap)


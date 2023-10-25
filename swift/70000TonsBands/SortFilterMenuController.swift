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

func createrFilterMenu( controller: MasterViewController){
        
    print ("Redrawing the filter menu! createrFilterMenu")
    scheduleHandler().populateSchedule()
    var activeFilterMenus = [UIMenu]();
    
    let clearFilters = UIMenu(title: NSLocalizedString("Clear Filters", comment: ""), options: .displayInline, children: createClearAllFilters(controller: controller))
    activeFilterMenus.append(clearFilters)
    
    
    if (getShowOnlyWillAttened() == false){
        let bandRankFilters = UIMenu(title: NSLocalizedString("Band Ranking Filters", comment: ""), options: .displayInline, children: createMustMightChoices(controller: controller))
        activeFilterMenus.append(bandRankFilters)
    }
    
    if (eventCount > 0 && unofficalEventCount != eventCount){
        let attendedFilters = UIMenu(title: NSLocalizedString("Show Only Flagged As Attended", comment: ""), options: .displayInline, children: createAttendedStatusChoices(controller: controller))
        activeFilterMenus.append(attendedFilters)
    } else {
        didNotFindMarkedEventsCount = didNotFindMarkedEventsCount + 1
        if (didNotFindMarkedEventsCount > 3){
            setShowOnlyWillAttened(false)
        }
    }
    
    if (controller.decideIfScheduleMenuApplies() == true){
        let sortFilters = UIMenu(title: NSLocalizedString("Sorting Options", comment: ""), options: .displayInline, children: createSortChoice(controller: controller))
        activeFilterMenus.append(sortFilters)
    }
    
    if (getShowOnlyWillAttened() == false){
        let eventTypeFilters = UIMenu(title: NSLocalizedString("Event Type Filters", comment: ""), options: .displayInline, children: eventTypeChoices(controller: controller))
        activeFilterMenus.append(eventTypeFilters)
    }
    
    if (controller.decideIfScheduleMenuApplies() == true && getShowOnlyWillAttened() == false){
        let venueFilters = UIMenu(title: NSLocalizedString("Venue Filters", comment: ""), options: .displayInline, children: venueChocies(controller: controller))
        activeFilterMenus.append(venueFilters)
    }
    
    
    let menu = UIMenu(title: "", children: activeFilterMenus)
    
    controller.filterMenuButton.menu = menu
    
    controller.filterMenuButton.showsMenuAsPrimaryAction = true

    controller.filterMenuButton.overrideUserInterfaceStyle = .dark
    controller.filterMenuButton.setTitleColor(UIColor.lightGray, for: UIControl.State.normal)
    controller.filterMenuButton.setTitle(NSLocalizedString("Filters", comment: ""), for: UIControl.State.normal)
    controller.filterMenuButton.titleLabel?.font = .systemFont(ofSize: 24.0, weight: .bold)
    
}

func blockTurningAllFiltersOn(controller: MasterViewController)->Bool{
    
    var blockChange = false
    
    let visibleLocation = CGRect(origin: controller.mainTableView.contentOffset, size: controller.mainTableView.bounds.size)
    
    if (getShowPoolShows() == false &&
        getShowRinkShows() == false &&
        getShowOtherShows() == false &&
        getShowLoungeShows() == false &&
        getShowTheaterShows() == false){
        blockChange = true
        ToastMessages(NSLocalizedString("Can not hide all venues", comment: "")).show(controller, cellLocation: visibleLocation, placeHigh: true)
    }
    
    if (getMustSeeOn() == false &&
        getMightSeeOn() == false &&
        getWontSeeOn() == false &&
        getUnknownSeeOn() == false){
        blockChange = true
        ToastMessages(NSLocalizedString("Can not hide all statuses", comment: "")).show(controller, cellLocation: visibleLocation, placeHigh: true)
    }
     
    return blockChange
}

func isMenuVisible(controller: MasterViewController) -> Bool {
    var status = false
    if #available(iOS 15, *) {
        status = controller.filterMenuButton.isHeld
    }
    if (controller.menuRefreshOverRide == true){
        status = false
    }
    print ("Menu current display is \(status)")
    return status
}

func refreshAfterMenuIsGone(controller: MasterViewController){
    
    if #available(iOS 15, *) {
        if (refreshAfterMenuIsGoneFlag == false){
            refreshAfterMenuIsGoneFlag = true
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                print ("Working on a delayed refresh")
                while(controller.filterMenuButton.isHeld == true){
                    usleep(100000)
                }
                NotificationCenter.default.post(name: Notification.Name(rawValue: "refreshGUI"), object: nil)
                print ("Working on a delayed refresh, Done")
                refreshAfterMenuIsGoneFlag = false
            }
        }
    }
}

func refreshAfterMenuSelected(controller: MasterViewController, message: String){
    
    
    controller.menuRefreshOverRide = true
    writeFiltersFile()
    
    createrFilterMenu(controller: controller)
    refreshAfterMenuIsGone(controller: controller)
    controller.quickRefresh_Pre()
    controller.menuRefreshOverRide = false
    
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


func createClearAllFilters(controller: MasterViewController)->[UIAction]{
    
    var clearFilterText = NSLocalizedString("Clear All Filters", comment: "")
    var clearFilterIcon = ""
    let clearFilters = UIAction(title: clearFilterText, image: UIImage(named: clearFilterIcon)) { _ in
        
        setShowOnlyWillAttened(false)
        setShowPoolShows(true)
        setShowRinkShows(true)
        setShowOtherShows(true)
        setShowLoungeShows(true)
        setShowTheaterShows(true)
        setShowSpecialEvents(true)
        setShowUnofficalEvents(true)
        setShowMeetAndGreetEvents(true)
        setMustSeeOn(true)
        setMightSeeOn(true)
        setWontSeeOn(true)
        setUnknownSeeOn(true)

        refreshAfterMenuSelected(controller: controller, message: clearFilterText)
    }
    
    if #available(iOS 16.0, *) {
    
        if (controller.filterTextNeeded == false){
            clearFilters.attributes = [.disabled, .keepsMenuPresented]
        } else {
            clearFilters.attributes = .keepsMenuPresented
        }
        
    } else {
        if (controller.filterTextNeeded == false){
            clearFilters.attributes = [.disabled]
        }
    }
    
    let clearFilterChoices = [clearFilters]
    
    
    return clearFilterChoices
}

func createAttendedStatusChoices(controller: MasterViewController)->[UIAction]{
    
    var message = "";
    
    var attendedStatusFilterText = NSLocalizedString("Show All Events", comment: "")
    var attendedStatusFilterIcon = attendedShowIconAlt
    let attendedStatusValue = getShowOnlyWillAttened()
    if (attendedStatusValue == false){
        attendedStatusFilterText = NSLocalizedString("Show Flagged Events Only", comment: "")
        attendedStatusFilterIcon = attendedShowIcon
    }
    let attendedFilter = UIAction(title: attendedStatusFilterText, image: UIImage(named: attendedStatusFilterIcon)) { _ in
        if (attendedStatusValue == true){
            setShowOnlyWillAttened(false)
            message = NSLocalizedString("Show All Events", comment: "")
        } else {
            setShowOnlyWillAttened(true)
            message = NSLocalizedString("Show Only Events Flagged As Attending", comment: "")
        }
        refreshAfterMenuSelected(controller: controller, message: message)
    }
 
    if #available(iOS 16.0, *) {
        if (attendingCount == 0){
            attendedFilter.attributes = [.disabled, .keepsMenuPresented]
        } else {
            attendedFilter.attributes = [.keepsMenuPresented]
        }
    } else {
        if (attendingCount == 0){
            attendedFilter.attributes = .disabled
        }
    }

    
    let attendedChoices = [attendedFilter]
    
    return attendedChoices
}

func venueChocies(controller: MasterViewController)->[UIAction]{

    var loungeFilterText = NSLocalizedString("Show Lounge Events", comment: "")
    var loungeFilterIcon = loungIconAlt
    let showLoungeValue = getShowLoungeShows()
    if (showLoungeValue == true){
        loungeFilterText = NSLocalizedString("Hide Lounge Events", comment: "")
        loungeFilterIcon = loungIcon
    }
    let loungeFilter = UIAction(title: loungeFilterText, image: UIImage(named: loungeFilterIcon)) { _ in
        var message = ""
        if (showLoungeValue == true){
            setShowLoungeShows(false)
            if (blockTurningAllFiltersOn(controller: controller) == false){
                message = NSLocalizedString("Lounge Venue Filter On", comment: "")
            } else {
                setShowLoungeShows(true)
            }
        } else {
            setShowLoungeShows(true)
            message = NSLocalizedString("Lounge Venue Filter Off", comment: "")
        }
        refreshAfterMenuSelected(controller: controller, message: message)
    }
    if #available(iOS 16.0, *) {
        loungeFilter.attributes = .keepsMenuPresented
    }
    
    var poolFilterText = NSLocalizedString("Show Pool Events", comment: "")
    var poolFilterIcon = poolIconAlt
    let showPoolValue = getShowPoolShows()
    if (showPoolValue == true){
        poolFilterText = NSLocalizedString("Hide Pool Events", comment: "")
        poolFilterIcon = poolIcon
    }
    let poolFilter = UIAction(title: poolFilterText, image: UIImage(named: poolFilterIcon)) { _ in
        var message = ""
        if (showPoolValue == true){
            setShowPoolShows(false)
            if (blockTurningAllFiltersOn(controller: controller) == false){
                message = NSLocalizedString("Pool Venue Filter On", comment: "")
            } else {
                setShowPoolShows(true)
            }
        } else {
            setShowPoolShows(true)
            message = NSLocalizedString("Pool Venue Filter Off", comment: "")
        }
        refreshAfterMenuSelected(controller: controller, message: message)
    }
    if #available(iOS 16.0, *) {
        poolFilter.attributes = .keepsMenuPresented
    }
    
    var rinkFilterText = NSLocalizedString("Show Rink Events", comment: "")
    var rinkFilterIcon = iceRinkIconAlt
    let showRinkValue = getShowRinkShows()
    if (showRinkValue == true){
        rinkFilterText = NSLocalizedString("Hide Rink Events", comment: "")
        rinkFilterIcon = iceRinkIcon
    }
    let rinkFilter = UIAction(title: rinkFilterText, image: UIImage(named: rinkFilterIcon)) { _ in
        var message = ""
        if (showRinkValue == true){
            setShowRinkShows(false)
            if (blockTurningAllFiltersOn(controller: controller) == false){
                message = NSLocalizedString("Rink Venue Filter On", comment: "")
            } else {
                setShowRinkShows(true)
            }
        } else {
            setShowRinkShows(true)
            message = NSLocalizedString("Rink Venue Filter Off", comment: "")
        }
        refreshAfterMenuSelected(controller: controller, message: message)
    }
    if #available(iOS 16.0, *) {
        rinkFilter.attributes = .keepsMenuPresented
    }
    
    
    var theaterFilterText = NSLocalizedString("Show Theater Events", comment: "")
    var theaterFilterIcon = theaterIconAlt
    let showTheaterValue = getShowTheaterShows()
    if (showTheaterValue == true){
        theaterFilterText = NSLocalizedString("Hide Theater Events", comment: "")
        theaterFilterIcon = theaterIcon
    }
    let theaterFilter = UIAction(title: theaterFilterText, image: UIImage(named: theaterFilterIcon)) { _ in
        var message = ""
        if (showTheaterValue == true){
            setShowTheaterShows(false)
            if (blockTurningAllFiltersOn(controller: controller) == false){
                message = NSLocalizedString("Theater Venue Filter On", comment: "")
            } else {
                setShowTheaterShows(true)
            }
        } else {
            setShowTheaterShows(true)
            message = NSLocalizedString("Theater Venue Filter Off", comment: "")
        }
        refreshAfterMenuSelected(controller: controller, message : message)
    }
    if #available(iOS 16.0, *) {
        theaterFilter.attributes = .keepsMenuPresented
    }
    
    var otherFilterText = NSLocalizedString("Show Other Events", comment: "")
    var otherFilterIcon = unknownIconAlt
    let showOtherValue = getShowOtherShows()
    if (showOtherValue == true){
        otherFilterText = NSLocalizedString("Hide Other Events", comment: "")
        otherFilterIcon = unknownIcon
    }
    let otherFilter = UIAction(title: otherFilterText, image: UIImage(named: otherFilterIcon)) { _ in
        var message = ""
        if (showOtherValue == true){
            setShowOtherShows(false)
            if (blockTurningAllFiltersOn(controller: controller) == false){
                message = NSLocalizedString("Other Venue Filter On", comment: "")
            } else {
                setShowOtherShows(true)
            }
        } else {
            setShowOtherShows(true)
            message = NSLocalizedString("Other Venue Filter Off", comment: "")
        }
        refreshAfterMenuSelected(controller: controller, message : message)
    }
    if #available(iOS 16.0, *) {
        otherFilter.attributes = .keepsMenuPresented
    }
    
    let venueChoices = [poolFilter, loungeFilter, rinkFilter, theaterFilter, otherFilter]
    
    return venueChoices
}

func eventTypeChoices(controller: MasterViewController)->[UIAction]{
    
    var eventTypeChoices = [UIAction]()
    
    if (controller.decideIfScheduleMenuApplies() == true){
        var currentMeetAndGreetFilterText = NSLocalizedString("Show Meet & Greet Events", comment: "")
        var currentMeetAndGreetFilterIcon = meetAndGreetIconAlt
        let showMeetAndGreetValue = getShowMeetAndGreetEvents()
        if (showMeetAndGreetValue == true){
            currentMeetAndGreetFilterIcon = meetAndGreetIcon
            currentMeetAndGreetFilterText = NSLocalizedString("Hide Meet & Greet Events", comment: "")
        }
        let meetAndGreet = UIAction(title: currentMeetAndGreetFilterText, image: UIImage(named: currentMeetAndGreetFilterIcon)) { _ in
            var message = ""
            if (showMeetAndGreetValue == true){
                setShowMeetAndGreetEvents(false)
                message = NSLocalizedString("Meet and Greet Event Filter On", comment: "")
            } else {
                setShowMeetAndGreetEvents(true)
                message = NSLocalizedString("Meet and Greet Event Filter Off", comment: "")
            }
            refreshAfterMenuSelected(controller: controller, message: message)
        }
        if #available(iOS 16.0, *) {
            meetAndGreet.attributes = .keepsMenuPresented
        }
        eventTypeChoices.append(meetAndGreet)
    }

    if (controller.decideIfScheduleMenuApplies() == true){
        var specialFilterText = NSLocalizedString("Show Special/Other Events", comment: "")
        var specialFilterIcon = specialEventTypeIconAlt
        let specialEventValue = getShowSpecialEvents()
        if (specialEventValue == true){
            specialFilterIcon = specialEventTypeIcon
            specialFilterText = NSLocalizedString("Hide Special/Other Events", comment: "")
        }
        let specialEvents = UIAction(title: specialFilterText, image: UIImage(named: specialFilterIcon)) { _ in
            var message = ""
            if (specialEventValue == true){
                setShowSpecialEvents(false)
                message = NSLocalizedString("Special/Other Event Filter On", comment: "")
            } else {
                setShowSpecialEvents(true)
                message = NSLocalizedString("Special/Other Event Filter Off", comment: "")
            }
            refreshAfterMenuSelected(controller: controller, message: message)
        }
        if #available(iOS 16.0, *) {
            specialEvents.attributes = .keepsMenuPresented
        }
        eventTypeChoices.append(specialEvents)
    }
    
    var cruiserOrganizedFilterText = NSLocalizedString("Show Unofficial Events", comment: "")
    var cruiserOrganizedFilterIcon = unofficalEventTypeIconAlt
    let cruiserOrganizedValue = getShowUnofficalEvents()
    if (cruiserOrganizedValue == true){
        cruiserOrganizedFilterIcon = unofficalEventTypeIcon
        cruiserOrganizedFilterText = NSLocalizedString("Hide Unofficial Events", comment: "")
    }
    let cruiserOrganizedEvents = UIAction(title: cruiserOrganizedFilterText, image: UIImage(named: cruiserOrganizedFilterIcon)) { _ in
        var message = ""
        if (cruiserOrganizedValue == true){
            setShowUnofficalEvents(false)
            message = NSLocalizedString("Unofficial Event Filter On", comment: "")
        } else {
            setShowUnofficalEvents(true)
            message = NSLocalizedString("Unofficial Event Filter Off", comment: "")
        }
        refreshAfterMenuSelected(controller: controller, message: message)
    }
    if #available(iOS 16.0, *) {
        cruiserOrganizedEvents.attributes = .keepsMenuPresented
    }
    eventTypeChoices.append(cruiserOrganizedEvents)
    
    return eventTypeChoices
    
}

func createSortChoice(controller: MasterViewController)->[UIAction]{
    
    var message = ""
    var sortDirectionIcon = bandIconSort
    var sortDirectionText = NSLocalizedString("Sort By Name", comment: "")
    var sortDirection = "name"

    if (sortedBy == "name"){
        sortDirectionIcon = scheduleIconSort
        sortDirection = "time"
        sortDirectionText = NSLocalizedString("Sort By Time", comment: "")
    }
    
    let sortChoice = UIAction(title: sortDirectionText, image: UIImage(named: sortDirectionIcon)) { _ in
        sortedBy = sortDirection
        controller.resortBands()
        refreshAfterMenuSelected(controller: controller, message: "")
    }
    
    if #available(iOS 16.0, *) {
        sortChoice.attributes = .keepsMenuPresented
    }
    
    let sortChoices = [sortChoice]
    
    return sortChoices
}

func createMustMightChoices(controller: MasterViewController)->[UIAction]{
        
    var currentMustSeeIcon = mustSeeIconAlt
    var currentMustSeeText = NSLocalizedString("Show Must See Items", comment: "")
    if (getMustSeeOn() == true){
        currentMustSeeIcon = mustSeeIcon
        currentMustSeeText = NSLocalizedString("Hide Must See Items", comment: "")
    }
    let mustSee = UIAction(title: currentMustSeeText, image: UIImage(named: currentMustSeeIcon)) { _ in
        var message = ""
        if (getMustSeeOn() == true){
            setMustSeeOn(false)
            
            if (blockTurningAllFiltersOn(controller: controller) == false){
                message = NSLocalizedString("Must See Filter On", comment: "")
            } else {
                setMustSeeOn(true)
            }
        } else {
            setMustSeeOn(true)
            message = NSLocalizedString("Must See Filter Off", comment: "")
        }
        refreshAfterMenuSelected(controller: controller, message: message)
    }
    
    if #available(iOS 16.0, *) {
        mustSee.attributes = .keepsMenuPresented
    }
    
    var currentMightSeeIcon = mightSeeIconAlt
    var currentMightSeeText = NSLocalizedString("Show Might See Items", comment: "")
    if (getMightSeeOn() == true){
        currentMightSeeIcon = mightSeeIcon
        currentMightSeeText = NSLocalizedString("Hide Might See Items", comment: "")
    }
    let mightSee = UIAction(title: currentMightSeeText, image: UIImage(named: currentMightSeeIcon)) { _ in
        var message = ""

        if (getMightSeeOn() == true){
            setMightSeeOn(false)
            if (blockTurningAllFiltersOn(controller: controller) == false){
                message = NSLocalizedString("Might See Filter On", comment: "")
            } else {
                setMightSeeOn(true)
            }
        } else {
            setMightSeeOn(true)
            message = NSLocalizedString("Might See Filter Off", comment: "")
        }
        refreshAfterMenuSelected(controller: controller, message: message)
    }
    if #available(iOS 16.0, *) {
        mightSee.attributes = .keepsMenuPresented
    }
    
    var currentWontSeeIcon = wontSeeIconAlt
    var currentWontSeeText = NSLocalizedString("Show Wont See Items", comment: "")
    if (getWontSeeOn() == true){
        currentWontSeeIcon = wontSeeIcon
        currentWontSeeText = NSLocalizedString("Hide Wont See Items", comment: "")
    }
    let wontSee = UIAction(title: currentWontSeeText, image: UIImage(named: currentWontSeeIcon)) { _ in
        var message = ""
        if (getWontSeeOn() == true){
            setWontSeeOn(false)
            if (blockTurningAllFiltersOn(controller: controller) == false){
                message = NSLocalizedString("Wont See Filter On", comment: "")
            } else {
                setWontSeeOn(true)
            }
        } else {
            setWontSeeOn(true)
            message = NSLocalizedString("Wont See Filter Off", comment: "")
        }
        refreshAfterMenuSelected(controller: controller, message: message)
    }
    if #available(iOS 16.0, *) {
        wontSee.attributes = .keepsMenuPresented
    }
    
    var currentUnknownSeeIcon = unknownIconAlt
    var currentUnknownSeeText = NSLocalizedString("Show Unknown Items", comment: "")
    if (getUnknownSeeOn() == true){
        currentUnknownSeeIcon = unknownIcon
        currentUnknownSeeText = NSLocalizedString("Hide Unknown Items", comment: "")
    }
    let unknownSee = UIAction(title: currentUnknownSeeText, image: UIImage(named: currentUnknownSeeIcon)) { _ in
        var message = ""
       
        if (getUnknownSeeOn() == true){
            setUnknownSeeOn(false)
            if (blockTurningAllFiltersOn(controller: controller) == false){
                message = NSLocalizedString("Unknown Filter On", comment: "")
            } else {
                setUnknownSeeOn(true)
            }
        } else {
            setUnknownSeeOn(true)
            message = NSLocalizedString("Unknown Filter Off", comment: "")
        }
        refreshAfterMenuSelected(controller: controller, message: message)
    }
    if #available(iOS 16.0, *) {
        unknownSee.attributes = .keepsMenuPresented
    }
    
    let mustMightChoices = [mustSee, mightSee, wontSee, unknownSee]
    
    return mustMightChoices
}


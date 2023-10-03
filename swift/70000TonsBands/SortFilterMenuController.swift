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
    
    if (isMenuVisible(controller: controller) == true){
        return
    }
    
    print ("Redrawing the filter menu! createrFilterMenu")
    scheduleHandler().populateSchedule()
    
    var activeFilterMenus = [UIMenu]();

    if (controller.filterTextNeeded == true && getShowOnlyWillAttened() == false){
        let clearFilters = UIMenu(title: NSLocalizedString("Clear Filters", comment: ""), options: .displayInline, children: createClearAllFilters(controller: controller))
        activeFilterMenus.append(clearFilters)
    }

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
    
    if (controller.decideIfScheduleMenuApplies() == true && getShowOnlyWillAttened() == false){
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
    controller.filterMenuButton.setTitleColor(UIColor.white, for: UIControl.State.normal)
    controller.filterMenuButton.setTitle(NSLocalizedString("Filters", comment: ""), for: UIControl.State.normal)
    controller.filterMenuButton.titleLabel?.font = .systemFont(ofSize: 24.0, weight: .bold)
}

func blockTurningAllFiltersOn(controller: MasterViewController)->Bool{
    
    var blockChange = false
    
    if (getShowPoolShows() == false &&
        getShowRinkShows() == false &&
        getShowOtherShows() == false &&
        getShowLoungeShows() == false &&
        getShowTheaterShows() == false){
        blockChange = true
        ToastMessages(NSLocalizedString("Can not hide all venues", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
    }
    
    if (getMustSeeOn() == false &&
        getMightSeeOn() == false &&
        getWontSeeOn() == false &&
        getUnknownSeeOn() == false){
        blockChange = true
        ToastMessages(NSLocalizedString("Can not hide all statuses", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
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
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            print ("Working on a delayed refresh")
            while(controller.filterMenuButton.isHeld == true){
                sleep(1)
            }
            NotificationCenter.default.post(name: Notification.Name(rawValue: "RefreshDisplay"), object: nil)
            print ("Working on a delayed refresh, Done")
        }
    }
}

func refreshAfterMenuSelected(controller: MasterViewController){

    controller.menuRefreshOverRide = true
    controller.quickRefresh()
    createrFilterMenu(controller: controller);
    controller.menuRefreshOverRide = false
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
        ToastMessages(clearFilterText).show(controller, cellLocation: controller.view.frame, placeHigh: false)
    
        refreshAfterMenuSelected(controller: controller)
    }

    let clearFilterChoices = [clearFilters]
    
    return clearFilterChoices
}

func createAttendedStatusChoices(controller: MasterViewController)->[UIAction]{
    
    var attendedStatusFilterText = NSLocalizedString("Show All Events", comment: "")
    var attendedStatusFilterIcon = "icon-seen-alt"
    let attendedStatusValue = getShowOnlyWillAttened()
    if (attendedStatusValue == false){
        attendedStatusFilterText = NSLocalizedString("Show Flaged Events Only", comment: "")
        attendedStatusFilterIcon = "icon-seen"
    }
    let attendedFilter = UIAction(title: attendedStatusFilterText, image: UIImage(named: attendedStatusFilterIcon)) { _ in
        if (attendedStatusValue == true){
            setShowOnlyWillAttened(false)
            ToastMessages(attendedStatusFilterText).show(controller, cellLocation: controller.view.frame, placeHigh: false)
        } else {
            setShowOnlyWillAttened(true)
            ToastMessages(NSLocalizedString("Show Only Events Flagged As Attending", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
        }
        refreshAfterMenuSelected(controller: controller)
    }

    let attendedChoices = [attendedFilter]
    
    return attendedChoices
}

func venueChocies(controller: MasterViewController)->[UIAction]{

    var poolFilterText = NSLocalizedString("Show Pool Events", comment: "")
    var poolFilterIcon = "Icon-Stage--Pooldeck-Visual DeSelect"
    let showPoolValue = getShowPoolShows()
    if (showPoolValue == true){
        poolFilterText = NSLocalizedString("Hide Pool Events", comment: "")
        poolFilterIcon = "Icon-Stage--Pooldeck-Visual Select"
    }
    let poolFilter = UIAction(title: poolFilterText, image: UIImage(named: poolFilterIcon)) { _ in
        if (showPoolValue == true){
            setShowPoolShows(false)
            if (blockTurningAllFiltersOn(controller: controller) == false){
                ToastMessages(NSLocalizedString("Pool Venue Filter On", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
            } else {
                setShowPoolShows(true)
            }
        } else {
            setShowPoolShows(true)
            ToastMessages(NSLocalizedString("Pool Venue Filter Off", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
        }
        refreshAfterMenuSelected(controller: controller)
    }

    var loungeFilterText = NSLocalizedString("Show Lounge Events", comment: "")
    var loungeFilterIcon = "Icon-Stage--Lounge-Visual DeSelect"
    let showLoungeValue = getShowLoungeShows()
    if (showLoungeValue == true){
        loungeFilterText = NSLocalizedString("Hide Lounge Events", comment: "")
        loungeFilterIcon = "Icon-Stage--Lounge-Visual Select"
    }
    let loungeFilter = UIAction(title: loungeFilterText, image: UIImage(named: loungeFilterIcon)) { _ in
        if (showLoungeValue == true){
            setShowLoungeShows(false)
            if (blockTurningAllFiltersOn(controller: controller) == false){
                ToastMessages(NSLocalizedString("Lounge Venue Filter On", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
            } else {
                setShowLoungeShows(true)
            }
        } else {
            setShowLoungeShows(true)
            ToastMessages(NSLocalizedString("Lounge Venue Filter Off", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
        }
        refreshAfterMenuSelected(controller: controller)
    }
    
    var theaterFilterText = NSLocalizedString("Show Theater Events", comment: "")
    var theaterFilterIcon = "Icon-Stage--RoyalTheater-Visual DeSelect"
    let showTheaterValue = getShowTheaterShows()
    if (showTheaterValue == true){
        theaterFilterText = NSLocalizedString("Hide Theater Events", comment: "")
        theaterFilterIcon = "Icon-Stage--RoyalTheater-Visual Select"
    }
    let theaterFilter = UIAction(title: theaterFilterText, image: UIImage(named: theaterFilterIcon)) { _ in
        if (showTheaterValue == true){
            setShowTheaterShows(false)
            if (blockTurningAllFiltersOn(controller: controller) == false){
                ToastMessages(NSLocalizedString("Theater Venue Filter On", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
            } else {
                setShowTheaterShows(true)
            }
        } else {
            setShowTheaterShows(true)
            ToastMessages(NSLocalizedString("Theater Venue Filter Off", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
        }
        refreshAfterMenuSelected(controller: controller)
    }
    
    var rinkFilterText = NSLocalizedString("Show Rink Events", comment: "")
    var rinkFilterIcon = "Icon-Stage--IceRink-Visual DeSelect"
    let showRinkValue = getShowRinkShows()
    if (showRinkValue == true){
        rinkFilterText = NSLocalizedString("Hide Rink Events", comment: "")
        rinkFilterIcon = "Icon-Stage--IceRink-Visual Select"
    }
    let rinkFilter = UIAction(title: rinkFilterText, image: UIImage(named: rinkFilterIcon)) { _ in
        if (showRinkValue == true){
            setShowRinkShows(false)
            if (blockTurningAllFiltersOn(controller: controller) == false){
                ToastMessages(NSLocalizedString("Rink Venue Filter On", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
            } else {
                setShowRinkShows(true)
            }
        } else {
            setShowRinkShows(true)
            ToastMessages(NSLocalizedString("Rink Venue Filter Off", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
        }
        refreshAfterMenuSelected(controller: controller)
    }

    var otherFilterText = NSLocalizedString("Show Other Events", comment: "")
    let showOtherValue = getShowOtherShows()
    if (showOtherValue == true){
        otherFilterText = NSLocalizedString("Hide Other Events", comment: "")
    }
    let otherFilter = UIAction(title: otherFilterText, image: UIImage(named: "Icon-Stage-WHITE")) { _ in
        if (showOtherValue == true){
            setShowOtherShows(false)
            if (blockTurningAllFiltersOn(controller: controller) == false){
                ToastMessages(NSLocalizedString("Other Venue Filter On", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
            } else {
                setShowOtherShows(true)
            }
        } else {
            setShowOtherShows(true)
            ToastMessages(NSLocalizedString("Other Venue Filter Off", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
        }
        refreshAfterMenuSelected(controller: controller)
    }
    
    let venueChoices = [poolFilter, loungeFilter, theaterFilter, rinkFilter, otherFilter]
    
    return venueChoices
}

func eventTypeChoices(controller: MasterViewController)->[UIAction]{
    
    var eventTypeChoices = [UIAction]()
    
    if (controller.decideIfScheduleMenuApplies() == true){
        var currentMeetAndGreetFilterText = NSLocalizedString("Show Meet & Greet Events", comment: "")
        let showMeetAndGreetValue = getShowMeetAndGreetEvents()
        if (showMeetAndGreetValue == true){
            currentMeetAndGreetFilterText = NSLocalizedString("Hide Meet & Greet Events", comment: "")
        }
        let meetAndGreet = UIAction(title: currentMeetAndGreetFilterText, image: UIImage(named: mAndmEventTypeIcon)) { _ in
            if (showMeetAndGreetValue == true){
                setShowMeetAndGreetEvents(false)
                ToastMessages(NSLocalizedString("Meet and Greet Event Filter On", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
            } else {
                setShowMeetAndGreetEvents(true)
                ToastMessages(NSLocalizedString("Meet and Greet Event Filter Off", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
            }
            refreshAfterMenuSelected(controller: controller)
        }
        eventTypeChoices.append(meetAndGreet)
    }
    
    var cruiserOrganizedFilterText = NSLocalizedString("Show Unofficial Events", comment: "")
    let cruiserOrganizedValue = getShowUnofficalEvents()
    if (cruiserOrganizedValue == true){
        cruiserOrganizedFilterText = NSLocalizedString("Hide Unofficial Events", comment: "")
    }
    let cruiserOrganizedEvents = UIAction(title: cruiserOrganizedFilterText, image: UIImage(named: unofficalEventTypeIcon)) { _ in
        if (cruiserOrganizedValue == true){
            setShowUnofficalEvents(false)
            ToastMessages(NSLocalizedString("Unofficial Event Filter On", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
        } else {
            setShowUnofficalEvents(true)
            ToastMessages(NSLocalizedString("Unofficial Event Filter Off", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
        }
        refreshAfterMenuSelected(controller: controller)
    }
    eventTypeChoices.append(cruiserOrganizedEvents)
    
    if (controller.decideIfScheduleMenuApplies() == true){
        var specialFilterText = NSLocalizedString("Show Special Events", comment: "")
        let specialEventValue = getShowSpecialEvents()
        if (specialEventValue == true){
            specialFilterText = NSLocalizedString("Hide Special Events", comment: "")
        }
        let specialEvents = UIAction(title: specialFilterText, image: UIImage(named: specialEventTypeIcon)) { _ in
            if (specialEventValue == true){
                setShowSpecialEvents(false)
                ToastMessages(NSLocalizedString("Special Event Filter On", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
            } else {
                setShowSpecialEvents(true)
                ToastMessages(NSLocalizedString("Special Event Filter Off", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
            }
            refreshAfterMenuSelected(controller: controller)
        }
        eventTypeChoices.append(specialEvents)
    }
    
    return eventTypeChoices
    
}

func createSortChoice(controller: MasterViewController)->[UIAction]{
    
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
        refreshAfterMenuSelected(controller: controller)
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
        if (getMustSeeOn() == true){
            setMustSeeOn(false)
            if (blockTurningAllFiltersOn(controller: controller) == false){
                ToastMessages(NSLocalizedString("Must See Filter On", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
            } else {
                setMustSeeOn(true)
            }
        } else {
            setMustSeeOn(true)
            ToastMessages(NSLocalizedString("Must See Filter Off", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
        }
        refreshAfterMenuSelected(controller: controller)
    }
    
    var currentMightSeeIcon = mightSeeIconAlt
    var currentMightSeeText = NSLocalizedString("Show Might See Items", comment: "")
    if (getMightSeeOn() == true){
        currentMightSeeIcon = mightSeeIcon
        currentMightSeeText = NSLocalizedString("Hide Might See Items", comment: "")
    }
    let mightSee = UIAction(title: currentMightSeeText, image: UIImage(named: currentMightSeeIcon)) { _ in
        if (getMightSeeOn() == true){
            setMightSeeOn(false)
            if (blockTurningAllFiltersOn(controller: controller) == false){
                ToastMessages(NSLocalizedString("Might See Filter On", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
            } else {
                setMightSeeOn(true)
            }
        } else {
            setMightSeeOn(true)
            ToastMessages(NSLocalizedString("Might See Filter Off", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
        }
        refreshAfterMenuSelected(controller: controller)
    }

    var currentWontSeeIcon = wontSeeIconAlt
    var currentWontSeeText = NSLocalizedString("Show Wont See Items", comment: "")
    if (getWontSeeOn() == true){
        currentWontSeeIcon = wontSeeIcon
        currentWontSeeText = NSLocalizedString("Hide Wont See Items", comment: "")
    }
    let wontSee = UIAction(title: currentWontSeeText, image: UIImage(named: currentWontSeeIcon)) { _ in
        if (getWontSeeOn() == true){
            setWontSeeOn(false)
            if (blockTurningAllFiltersOn(controller: controller) == false){
                ToastMessages(NSLocalizedString("Wont See Filter On", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
            } else {
                setWontSeeOn(true)
            }
        } else {
            setWontSeeOn(true)
            ToastMessages(NSLocalizedString("Wont See Filter Off", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
        }
        refreshAfterMenuSelected(controller: controller)
    }
    
    
    var currentUnknownSeeIcon = unknownIconAlt
    var currentUnknownSeeText = NSLocalizedString("Show Unknown Items", comment: "")
    if (getUnknownSeeOn() == true){
        currentUnknownSeeIcon = unknownIcon
        currentUnknownSeeText = NSLocalizedString("Hide Unknown Items", comment: "")
    }
    let unknownSee = UIAction(title: currentUnknownSeeText, image: UIImage(named: currentUnknownSeeIcon)) { _ in
        if (getUnknownSeeOn() == true){
            setUnknownSeeOn(false)
            if (blockTurningAllFiltersOn(controller: controller) == false){
                ToastMessages(NSLocalizedString("Unknown Filter On", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
            } else {
                setUnknownSeeOn(true)
            }
        } else {
            setUnknownSeeOn(true)
            ToastMessages(NSLocalizedString("Unknown Filter Off", comment: "")).show(controller, cellLocation: controller.view.frame, placeHigh: false)
        }
        refreshAfterMenuSelected(controller: controller)
    }
    
    let mustMightChoices = [mustSee, mightSee, wontSee, unknownSee]
    
    return mustMightChoices
}



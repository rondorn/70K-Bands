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
    
    controller.refreshData()
    controller.filterMenu = DropDown()
    controller.filterMenu.anchorView = controller.filterMenuButton
    controller.filterMenu.bottomOffset = CGPoint(x: -20, y:(controller.filterMenu.anchorView?.plainView.bounds.height)!)
    
    
    
    controller.filterMenu.dataSource = [
        "Clear Filters",
        "Clear All Filters",
        "Band Ranking Filters",
        "Must See Items",
        "Might See Items",
        "Wont See Items",
        "Unknown Items"
    ]
    if (eventCount > 0 && unofficalEventCount != eventCount){
        controller.filterMenu.dataSource.append("Flagged Header")
        controller.filterMenu.dataSource.append("Flagged Items")
        controller.filterMenu.dataSource.append("Sort Header")
        controller.filterMenu.dataSource.append("Sort By")
    }
    controller.filterMenu.dataSource.append("Event Type Filters")
    if (eventCount > 0 && unofficalEventCount != eventCount){
        controller.filterMenu.dataSource.append("Meet and Greet Events")
        controller.filterMenu.dataSource.append("Special Events")
    }
    controller.filterMenu.dataSource.append("Unoffical Events")
    if (eventCount > 0 && unofficalEventCount != eventCount){
        controller.filterMenu.dataSource.append("Location Header")
        controller.filterMenu.dataSource.append("Pool Venue")
        controller.filterMenu.dataSource.append("Lounge Venue")
        controller.filterMenu.dataSource.append("Rink Venue")
        controller.filterMenu.dataSource.append("Theater Venue")
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
        if (eventCount > 0 && unofficalEventCount != eventCount){
            setupCell(header: true, titleText: NSLocalizedString("Show Only Flagged As Attended", comment: "") , cellData: cellRow, imageName: unknownIcon, disabled: false)
        }
        
    } else if (item == "Event Type Filters"){
        setupCell(header: true, titleText: NSLocalizedString("Event Type Filters", comment: ""), cellData: cellRow, imageName: "", disabled: false)
        
    } else if (item == "Sort Header"){
        setupCell(header: true, titleText: NSLocalizedString("Sorting Options", comment: ""), cellData: cellRow, imageName: "", disabled: false)
        
    } else if (item == "Venue Filters"){
        setupCell(header: true, titleText: NSLocalizedString("Venue Filters", comment: ""), cellData: cellRow, imageName: "", disabled: false)
    }
}

func setupClickResponse(controller: MasterViewController){
    
    controller.filterMenu.selectionAction = { [weak controller] (index, item) in
        
        setupMustMightClickResponse(controller: controller!, item: item)
        setupClearClickResponse(controller: controller!, item: item)
        setupFlaggedOnlyResponse(controller: controller!, item: item)
        setupSortResponse(controller: controller!, item: item)
        setupEventTypeClickResponse(controller: controller!, item: item)
        setupVenueClickResponse(controller: controller!, item: item)
        print ("The respond from the chosen one is \(item) = \(index)")
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
        if (getShowOnlyWillAttened() == false){
            setupCell(header: false, titleText: NSLocalizedString("Show Flagged Events Only", comment: ""), cellData: cellRow, imageName: attendedShowIcon, disabled: false)
        } else {
            setupCell(header: false, titleText: NSLocalizedString("Show All Events", comment: "") , cellData: cellRow, imageName: attendedShowIconAlt, disabled: false)
        }
        if (attendingCount == 0){
            setupCell(header: false, titleText: NSLocalizedString("Show Flagged Events Only", comment: "") , cellData: cellRow, imageName: attendedShowIconAlt, disabled: true)
            cellRow.optionLabel.textColor = UIColor.darkGray
        }
    }
}
    
func setupClearClickResponse(controller: MasterViewController, item: String){
    
    if (item == "Clear All Filters"){
        var message = NSLocalizedString("Clear All Items", comment: "")
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

        refreshAfterMenuSelected(controller: controller, message: message)
        
        
    }
}

func setupClearAllMenuChoices(controller: MasterViewController, item: String, cellRow: CustomListEntry){

    if (item == "Clear All Filters"){
        if (controller.filterTextNeeded == true){
            setupCell(header: false, titleText: NSLocalizedString("Clear All Filters", comment: ""), cellData: cellRow, imageName: "", disabled: false)
        } else {
            setupCell(header: false, titleText: NSLocalizedString("Clear All Filters", comment: ""), cellData: cellRow, imageName: "", disabled: true)
        }
    }
    
}

func setupVenueClickResponse(controller: MasterViewController, item: String){
    
    if (item == "Pool Venue"){
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
    if (item == "Lounge Venue" && blockTurningAllFiltersOn(controller:controller) == false){
        var message = NSLocalizedString("Lounge Venue Filter Off", comment: "")
        if (getShowLoungeShows() == true){
            setShowLoungeShows(false)
            message = NSLocalizedString("Lounge Venue Filter On", comment: "")
        } else {
            setShowLoungeShows(true)
        }
        if (blockTurningAllFiltersOn(controller: controller) == true){
            setShowLoungeShows(true)
        } else {
            refreshAfterMenuSelected(controller: controller, message: message)
        }
    }
    if (item == "Rink Venue" && blockTurningAllFiltersOn(controller:controller) == false){
        var message = NSLocalizedString("Rink Venue Filter Off", comment: "")
        if (getShowRinkShows() == true){
            setShowRinkShows(false)
            message = NSLocalizedString("Rink Venue Filter On", comment: "")
        } else {
            setShowRinkShows(true)
        }
        if (blockTurningAllFiltersOn(controller: controller) == true){
            setShowRinkShows(true)
        } else {
            refreshAfterMenuSelected(controller: controller, message: message)
        }
    }
    
    if (item == "Theater Venue" && blockTurningAllFiltersOn(controller:controller) == false){
        var message = NSLocalizedString("Theater Venue Filter Off", comment: "")
        if (getShowTheaterShows() == true){
            setShowTheaterShows(false)
            message = NSLocalizedString("Theater Venue Filter On", comment: "")
        } else {
            setShowTheaterShows(true)
        }
        if (blockTurningAllFiltersOn(controller: controller) == true){
            setShowTheaterShows(true)
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
    
    if (item == "Pool Venue"){
        var currentIcon = poolIconAlt
        var currentText = NSLocalizedString("Show Pool Events", comment: "")
        if (getShowPoolShows() == true){
            currentIcon = poolIcon
            currentText = NSLocalizedString("Hide Pool Events", comment: "")
        }
        setupCell(header: false, titleText: currentText , cellData: cellRow, imageName: currentIcon, disabled: false)
        if (getShowOnlyWillAttened() == true){
            setupCell(header: false, titleText: currentText , cellData: cellRow, imageName: poolIconAlt, disabled: true)
            cellRow.optionLabel.textColor = UIColor.darkGray
        }
        
    } else if (item == "Lounge Venue"){
        var currentIcon = loungIconAlt
        var currentText = NSLocalizedString("Show Lounge Events", comment: "")
        if (getShowLoungeShows() == true){
            currentIcon = loungIcon
            currentText = NSLocalizedString("Hide Lounge Events", comment: "")
        }
        setupCell(header: false, titleText: currentText , cellData: cellRow, imageName: currentIcon, disabled: false)
        if (getShowOnlyWillAttened() == true){
            setupCell(header: false, titleText: currentText , cellData: cellRow, imageName: loungIconAlt, disabled: true)
            cellRow.optionLabel.textColor = UIColor.darkGray
        }
        
    } else if (item == "Rink Venue"){
        var currentIcon = iceRinkIconAlt
        var currentText = NSLocalizedString("Show Rink Events", comment: "")
        if (getShowRinkShows() == true){
            currentIcon = iceRinkIcon
            currentText = NSLocalizedString("Hide Rink Events", comment: "")
        }
        setupCell(header: false, titleText: currentText , cellData: cellRow, imageName: currentIcon, disabled: false)
        if (getShowOnlyWillAttened() == true){
            setupCell(header: false, titleText: currentText , cellData: cellRow, imageName: iceRinkIconAlt, disabled: true)
            cellRow.optionLabel.textColor = UIColor.darkGray
        }
        
    } else if (item == "Theater Venue"){
        var currentIcon = theaterIconAlt
        var currentText = NSLocalizedString("Show Theater Events", comment: "")
        if (getShowTheaterShows() == true){
            currentIcon = theaterIcon
            currentText = NSLocalizedString("Hide Theater Events", comment: "")
        }
        setupCell(header: false, titleText: currentText , cellData: cellRow, imageName: currentIcon, disabled: false)
        if (getShowOnlyWillAttened() == true){
            setupCell(header: false, titleText: currentText , cellData: cellRow, imageName: theaterIconAlt, disabled: true)
            cellRow.optionLabel.textColor = UIColor.darkGray
        }
        
    } else if (item == "Other Venue"){
        var currentIcon = unknownIconAlt
        var currentText = NSLocalizedString("Show Other Events", comment: "")
        if (getShowOtherShows() == true){
            currentIcon = unknownIcon
            currentText = NSLocalizedString("Hide Other Events", comment: "")
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
    
    if (getShowPoolShows() == false &&
        getShowRinkShows() == false &&
        getShowOtherShows() == false &&
        getShowLoungeShows() == false &&
        getShowTheaterShows() == false){
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


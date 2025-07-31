//
//  SortMenuController.swift
//  70K Bands
//
//  Created by Ron Dorn on 6/11/16.
//  Copyright © 2016 Ron Dorn. All rights reserved.
//

import Foundation
import UIKit

func createrFilterMenu( controller: MasterViewController){
    
    controller.refreshData()
    // DropDown removed for visionOS compatibility - replaced with UIView
    controller.filterMenu = UIView()
    
    // DropDown functionality removed for visionOS compatibility
    print("DropDown functionality removed for visionOS compatibility")
    
    controller.filterMenuButton.setTitle(NSLocalizedString("Filters", comment: ""), for: UIControl.State.normal)
    
    // setupAllEntries(controller: controller)
    // setupClickResponse(controller: controller)
}

func setupAllEntries(controller: MasterViewController){
    
    // DropDown functionality removed for visionOS compatibility
    print("DropDown functionality removed for visionOS compatibility")
}

func setupHeadersAndMisc(controller: MasterViewController, item: String, cellRow: CustomListEntry){

    // DropDown functionality removed for visionOS compatibility
    print("DropDown functionality removed for visionOS compatibility")
}

func setupClickResponse(controller: MasterViewController){
    
    // DropDown functionality removed for visionOS compatibility
    print("DropDown functionality removed for visionOS compatibility")
}

func setupSortResponse(controller: MasterViewController, item: String){

    // DropDown functionality removed for visionOS compatibility
    print("DropDown functionality removed for visionOS compatibility")
}

func setupSortMenuChoices(controller: MasterViewController, item: String, cellRow: CustomListEntry){

    // DropDown functionality removed for visionOS compatibility
    print("DropDown functionality removed for visionOS compatibility")
}

func setupFlaggedOnlyResponse(controller: MasterViewController, item: String){

    // DropDown functionality removed for visionOS compatibility
    print("DropDown functionality removed for visionOS compatibility")
}

func setupFlaggedOnlylMenuChoices(controller: MasterViewController, item: String, cellRow: CustomListEntry){

    // DropDown functionality removed for visionOS compatibility
    print("DropDown functionality removed for visionOS compatibility")
}
    
func setupClearClickResponse(controller: MasterViewController, item: String){
    
    // DropDown functionality removed for visionOS compatibility
    print("DropDown functionality removed for visionOS compatibility")
}

func setupClearAllMenuChoices(controller: MasterViewController, item: String, cellRow: CustomListEntry){

    // DropDown functionality removed for visionOS compatibility
    print("DropDown functionality removed for visionOS compatibility")
}

func setupVenueClickResponse(controller: MasterViewController, item: String){
    
    // DropDown functionality removed for visionOS compatibility
    print("DropDown functionality removed for visionOS compatibility")
}

func setupVenueMenuChoices(controller: MasterViewController, item: String, cellRow: CustomListEntry){
    
    // DropDown functionality removed for visionOS compatibility
    print("DropDown functionality removed for visionOS compatibility")
}

func setupMustMightClickResponse(controller: MasterViewController, item: String){
    
    // DropDown functionality removed for visionOS compatibility
    print("DropDown functionality removed for visionOS compatibility")
}

func setupMustMightMenuChoices(controller: MasterViewController, item: String, cellRow: CustomListEntry){

    // DropDown functionality removed for visionOS compatibility
    print("DropDown functionality removed for visionOS compatibility")
}

func setupEventTypeClickResponse(controller: MasterViewController, item: String){

    // DropDown functionality removed for visionOS compatibility
    print("DropDown functionality removed for visionOS compatibility")
}

func setupEventTypeMenuChoices(controller: MasterViewController, item: String, cellRow: CustomListEntry){
    
    // DropDown functionality removed for visionOS compatibility
    print("DropDown functionality removed for visionOS compatibility")
}

func setupCell(header: Bool, titleText: String, cellData: CustomListEntry, imageName: String, disabled: Bool){
    var newCell = cellData
    
    // DropDown functionality removed for visionOS compatibility
    print("DropDown functionality removed for visionOS compatibility")
}

func blockTurningAllFiltersOn(controller: MasterViewController)->Bool{
    
    var blockChange = false
    
    // DropDown functionality removed for visionOS compatibility
    print("DropDown functionality removed for visionOS compatibility")
    
    return blockChange
}

func refreshAfterMenuSelected(controller: MasterViewController, message: String){
       
    // DropDown functionality removed for visionOS compatibility
    print("DropDown functionality removed for visionOS compatibility")
    
}


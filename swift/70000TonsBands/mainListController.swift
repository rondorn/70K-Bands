//
//  mainListController.swift
//  70K Bands
//
//  Created by Ron Dorn on 2/6/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//  70K Bands
//  Distributed under the GNU GPL v2. For full terms see the file docs/COPYING.
//

import Foundation



    var bands = [String]() //main list of bands
    
    var scheduleButton = false;
    var hideScheduleButton = false;
    var mustSeeOn = true;
    var mightSeeOn = true;
    var wontSeeOn = true;
    var unknownSeeOn = true;
    
    var sortedBy = String();
    
    func setBands(value: [String]){
        bands = value
    }
    func getBands() -> [String]{
        return bands
    }
    func setHideScheduleButton(value: Bool){
        hideScheduleButton = value
    }
    func getHideScheduleButton() -> Bool{
        return hideScheduleButton
    }
    func setScheduleButton(value: Bool){
        hideScheduleButton = value
    }
    func getScheduleButton() -> Bool{
        return hideScheduleButton
    }
    func setMustSeeOn(value: Bool){
        mustSeeOn = value
    }
    func getMustSeeOn() -> Bool{
        return mustSeeOn
    }
    func setMightSeeOn(value: Bool){
        mightSeeOn = value
    }
    func getMightSeeOn() -> Bool{
        return mightSeeOn
    }
    func setWontSeeOn(value: Bool){
        wontSeeOn = value
    }
    func getWontSeeOn() -> Bool{
        return wontSeeOn
    }
    func setUnknownSeeOn(value: Bool){
        unknownSeeOn = value
    }
    func getUnknownSeeOn() -> Bool{
        return unknownSeeOn
    }
        
    func getFilteredBands(allBands:[String], schedule: scheduleHandler) -> [String]{
        
        var filteredBands = [String]()
        var preventDups = Dictionary<String, Int>()
        
        for bandName in allBands{

            switch getPriorityData(bandName) {
            case 1:
                if (getMustSeeOn() == true && preventDups[bandName] == nil){
                    filteredBands.append(bandName)
                    preventDups[bandName] = 1
                }
                
            case 2:
                if (getMightSeeOn() == true && preventDups[bandName] == nil){
                    filteredBands.append(bandName)
                    preventDups[bandName] = 1
                }
                
            case 3:
                if (getWontSeeOn() == true && preventDups[bandName] == nil){
                    filteredBands.append(bandName)
                    preventDups[bandName] = 1
                }
                
            case 0:
                if (getUnknownSeeOn() == true && preventDups[bandName] == nil){
                    filteredBands.append(bandName)
                    preventDups[bandName] = 1
                }
            default:
                print("Encountered unexpected value of ")
                println (getPriorityData(bandName))
            }
        }
        
        
        return filteredBands
    }
    
    func getCellValue (indexRow: Int, schedule: scheduleHandler) -> String{
    
        var bandName = bands[indexRow]
        var timeIndex = schedule.getCurrentIndex(bandName)
        var cellText = String()
    
        if (getPriorityData(bandName) == 0){
            cellText = bandName
        } else {
            cellText = getPriorityIcon(getPriorityData(bandName)) + " - " + bandName
        }
        
        var location = schedule.getData(bandName, index:timeIndex, variable: "Location")
        var day = schedule.getData(bandName, index: timeIndex, variable: "Day")
        var startTime = schedule.getData(bandName, index: timeIndex, variable: "Start Time")
        
    
        if (day.isEmpty == false && timeIndex > NSDate().timeIntervalSince1970 - 3600){
            println(bandName + " displaying timeIndex of \(timeIndex) ")
            cellText += " - " + day
            cellText += " " + startTime
            cellText += " " + location
            scheduleButton = false
            
        } else {
            println ("Not display schedule for band " + bandName)
            scheduleButton = true
        }
        
        return cellText
    }

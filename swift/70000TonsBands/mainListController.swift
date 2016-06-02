//
//  mainListController.swift
//  70K Bands
//
//  Created by Ron Dorn on 2/6/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
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
    var bandCount = Int();
    var eventCount = Int();

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

    func determineBandOrScheduleList (allBands:[String], schedule: scheduleHandler, sortedBy: String) -> [String]{
        
        var newAllBands = [String]()
        var presentCheck = [String]();
        
        schedule.buildTimeSortedSchedulingData();
        print (schedule.getTimeSortedSchedulingData());
        if (schedule.getBandSortedSchedulingData().count > 2 && sortedBy == "name"){
            print ("Sorting by name!!!");
            for bandName in schedule.getBandSortedSchedulingData().keys {
                for timeIndex in schedule.getBandSortedSchedulingData()[bandName]!.keys{
                    if (timeIndex > NSDate().timeIntervalSince1970 - 3600){
                        newAllBands.append(bandName + ":" + String(timeIndex));
                        presentCheck.append(bandName);
                    }
                }
            }
            bandCount = 0;
            eventCount = newAllBands.count;
            
        } else if (schedule.getTimeSortedSchedulingData().count > 2 && sortedBy == "time"){
            print ("Sorting by time!!!");
            for timeIndex in schedule.getTimeSortedSchedulingData().keys {
                for bandName in schedule.getTimeSortedSchedulingData()[timeIndex]!.keys{
                    if (timeIndex > NSDate().timeIntervalSince1970 - 3600){
                        newAllBands.append(String(timeIndex) + ":" + bandName);
                        presentCheck.append(bandName);
                    }
                }
            }
            bandCount = 0;
            eventCount = newAllBands.count;
        } else {
            
            //return immediatly. Dont need to do schedule sorting magic
            newAllBands = allBands;
            newAllBands.sortInPlace();
            bandCount = newAllBands.count;
            eventCount = 0;
            
            return newAllBands
        }
        
        newAllBands.sortInPlace();
        
        if (schedule.getTimeSortedSchedulingData().count > 2){
            //add any bands without shows to the bottom of the list
            for bandName in allBands {
                    if (presentCheck.contains(bandName) == false){
                newAllBands.append(bandName);
                }
            }
        }
        
        return newAllBands
    }

    func getFilteredBands(allBands:[String], schedule: scheduleHandler, sortedBy: String) -> [String]{
        
        var filteredBands = [String]()
        
        var newAllBands = [String]()
        
        newAllBands = determineBandOrScheduleList(allBands, schedule: schedule, sortedBy: sortedBy);
        
        for bandNameIndex in newAllBands {
            
            let bandName = getNameFromSortable(bandNameIndex, sortedBy: sortedBy);
            
            switch getPriorityData(bandName) {
            case 1:
                if (getMustSeeOn() == true){
                    filteredBands.append(bandNameIndex)
                }
                
            case 2:
                if (getMightSeeOn() == true){
                    filteredBands.append(bandNameIndex)
                }
                
            case 3:
                if (getWontSeeOn() == true){
                    filteredBands.append(bandNameIndex)
                }
                
            case 0:
                if (getUnknownSeeOn() == true){
                    filteredBands.append(bandNameIndex)
                }
                
            default:
                print("Encountered unexpected value of ", terminator: "")
                print (getPriorityData(bandName))
            }
        }
        
        return filteredBands
    }

    func getNameFromSortable(value: String, sortedBy: String) -> String{
        
        let indexString = value.componentsSeparatedByString(":")
        var bandName = String();
        
        if (indexString.count == 2){
            
            if ((indexString[0].doubleValue) != nil){
                bandName = indexString[1];
                
            } else if ((indexString[1].doubleValue) != nil){
                bandName = indexString[0];
                
            } else {
                bandName = value
            }
            
        } else {
            bandName = value
        }
        
        return bandName;
    }

    func getTimeFromSortable(value: String, sortBy: String) -> Double{
        
        let indexString = value.componentsSeparatedByString(":")
        var timeIndex = Double()
        
        if (indexString.count == 2){
            
            if ((indexString[0].doubleValue) != nil){
                timeIndex = Double(indexString[0])!;
                
            } else if ((indexString[1].doubleValue) != nil){
                timeIndex = Double(indexString[1])!;
                
            }
        }
        
        return timeIndex;
    }

    extension String {
        var doubleValue: Double? {
            return Double(self)
        }
        var floatValue: Float? {
            return Float(self)
        }
        var integerValue: Int? {
            return Int(self)
        }
    }


    func getCellValue (indexRow: Int, schedule: scheduleHandler, sortBy: String) -> String{
        
        let indexString = bands[indexRow].componentsSeparatedByString(":")
        
        let bandName = getNameFromSortable(bands[indexRow], sortedBy: sortBy);
        let timeIndex = getTimeFromSortable(bands[indexRow], sortBy: sortBy);
        
        var cellText = String()
    
        if (getPriorityData(bandName) == 0){
            cellText = bandName
        } else {
            cellText = getPriorityIcon(getPriorityData(bandName)) + " - " + bandName
        }
        
        if (indexString.count > 1){
            
            let location = schedule.getData(bandName, index:timeIndex, variable: "Location")
            let day = schedule.getData(bandName, index: timeIndex, variable: "Day")
            let startTime = schedule.getData(bandName, index: timeIndex, variable: "Start Time")
            let eventIcon = getEventTypeIcon(schedule.getData(bandName, index: timeIndex, variable: "Type"))
            
            print(bandName + " displaying timeIndex of \(timeIndex) ")
            cellText += " - " + day
            cellText += " " + startTime
            cellText += " " + location + " " + eventIcon;
            scheduleButton = false
            
        } else {
            print ("Not display schedule for band " + bandName)
            scheduleButton = true
        }
        
        return cellText
    }




//
//  mainListController.swift
//  70K Bands
//
//  Created by Ron Dorn on 2/6/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import UIKit
import Foundation

var bands = [String]() //main list of bands

var scheduleButton = false;
var hideScheduleButton = false;

var attendingCount = 0;

var bandCount = Int();
var eventCount = Int();

var previousBandName = String();
var nextBandName = String();
var firstBandName = String();
var scrollDirection = "Down";
var previousIndexRow = Int();

var totalUpcomingEvents = Int()

var scheduleIndexByCall : [String:[String:String]] = [String:[String:String]]();

func getScheduleIndexByCall()->  [String:[String:String]]{
    return scheduleIndexByCall;
}

func setBands(_ value: [String]){
    bands = value
}
func getBands() -> [String]{
    return bands
}

func determineBandOrScheduleList (_ allBands:[String], sortedBy: String, schedule: scheduleHandler, dataHandle: dataHandler, attendedHandle: ShowsAttended) -> [String]{
    
    numberOfFilteredRecords = 0
    var newAllBands = [String]()
    
    var presentCheck = [String]();
    //var listOfVenues = ["All"]
    attendingCount = 0
    unofficalEventCount = 0
    if (typeField.isEmpty == true){
        return allBands;
    }
    
    print ("Locking object with newAllBands")
    eventCounter = 0
    eventCounterUnoffical = 0
    unfilteredBandCount = 0
    unfilteredEventCount = 0
    unfilteredCruiserEventCount = 0
    unfilteredCurrentEventCount = 0
    
    
    print ("sortedBy = \(sortedBy)")
    schedule.buildTimeSortedSchedulingData();
    print (schedule.getTimeSortedSchedulingData());
    if (schedule.getBandSortedSchedulingData().isEmpty) {
        print("WARNING: Band sorted scheduling data is empty")
        return allBands
    }
    if (schedule.getBandSortedSchedulingData().count > 0 && sortedBy == "name"){
        print ("Sorting by name!!!");
        for bandName in schedule.getBandSortedSchedulingData().keys {
            unfilteredBandCount = unfilteredBandCount + 1
            guard let bandDict = schedule.getBandSortedSchedulingData()[bandName] else {
                print("WARNING: No bandDict for bandName: \(bandName)")
                continue
            }
            if (schedule.getBandSortedSchedulingData().isEmpty == false){
                unfilteredEventCount = unfilteredEventCount + 1
                for timeIndex in bandDict.keys {
                    guard let timeDict = bandDict[timeIndex] else {
                        print("WARNING: No timeDict for bandName: \(bandName), timeIndex: \(timeIndex)")
                        continue
                    }
                    guard let dateFieldValue = timeDict[dateField], let endTimeFieldValue = timeDict[endTimeField] else {
                        print("WARNING: Missing dateField or endTimeField for bandName: \(bandName), timeIndex: \(timeIndex)")
                        continue
                    }
                    var eventEndTime = schedule.getDateIndex(dateFieldValue, timeString: endTimeFieldValue, band: bandName)
                    print ("start time is \(timeIndex), eventEndTime is \(eventEndTime)")
                    if (timeIndex > eventEndTime){
                        eventEndTime = eventEndTime + (3600*24)
                    }
                    if (eventEndTime > Date().timeIntervalSince1970  || getHideExpireScheduleData() == false){
                        totalUpcomingEvents += 1;
                        if let typeValue = timeDict[typeField], !typeValue.isEmpty {
                            if (applyFilters(bandName: bandName,timeIndex: timeIndex, schedule: schedule, dataHandle: dataHandle, attendedHandle: attendedHandle) == true){
                                newAllBands.append(bandName + ":" + String(timeIndex));
                                presentCheck.append(bandName);
                                let event = schedule.getData(bandName, index: timeIndex, variable: typeField)
                                eventCounter = eventCounter + 1
                                if (event == unofficalEventType){
                                    eventCounterUnoffical = eventCounterUnoffical + 1
                                }
                            }
                        } else {
                            print("WARNING: No typeField for bandName: \(bandName), timeIndex: \(timeIndex)")
                        }
                    }
                }
            }
        }
        bandCount = 0;
        eventCount = newAllBands.count;
        
    } else if (schedule.getTimeSortedSchedulingData().count > 0 && sortedBy == "time"){
        print ("Sorting by time!!!");
        for timeIndex in schedule.getTimeSortedSchedulingData().keys {
            unfilteredEventCount = unfilteredEventCount + 1
            guard let timeDict = schedule.getTimeSortedSchedulingData()[timeIndex], timeDict.isEmpty == false else {
                continue
            }
            for bandName in timeDict.keys {
                    unfilteredBandCount = unfilteredBandCount + 1
                guard let bandDict = schedule.getBandSortedSchedulingData()[bandName] else {
                    print("WARNING: No bandDict for bandName: \(bandName)")
                    continue
                }
                guard let timeDictInner = bandDict[timeIndex] else {
                    print("WARNING: No timeDict for bandName: \(bandName), timeIndex: \(timeIndex)")
                    continue
                }
                guard let dateFieldValue = timeDictInner[dateField], let endTimeFieldValue = timeDictInner[endTimeField] else {
                    print("WARNING: Missing dateField or endTimeField for bandName: \(bandName), timeIndex: \(timeIndex)")
                    continue
                }
                var eventEndTime = schedule.getDateIndex(dateFieldValue, timeString: endTimeFieldValue, band: bandName)
                    print ("start time is \(timeIndex), eventEndTime is \(eventEndTime)")
                    if (timeIndex > eventEndTime){
                        eventEndTime = eventEndTime + (3600*24)
                    }
                    if (eventEndTime > Date().timeIntervalSince1970 || getHideExpireScheduleData() == false){
                        unfilteredCurrentEventCount = unfilteredCurrentEventCount + 1
                        totalUpcomingEvents += 1;
                    if let typeValue = timeDictInner[typeField], !typeValue.isEmpty {
                            if (applyFilters(bandName: bandName,timeIndex: timeIndex, schedule: schedule, dataHandle: dataHandle, attendedHandle: attendedHandle) == true){
                                newAllBands.append(String(timeIndex) + ":" + bandName);
                                presentCheck.append(bandName);
                                let event = schedule.getData(bandName, index: timeIndex, variable: typeField)
                                let location = " " + schedule.getData(bandName, index:timeIndex, variable: locationField)
                                let startTime = schedule.getData(bandName, index: timeIndex, variable: startTimeField)
                                let indexText = bandName + ";" + location + ";" + event + ";" + startTime
                                // Defensive: Ensure bandName is valid before using as dictionary key
                                if !bandName.isEmpty && bandName.count < 1000 { // Reasonable length check
                                    let key = String(timeIndex) + ":" + bandName
                                    
                                    // Defensive check: ensure timeIndexMap is actually a dictionary
                                    guard timeIndexMap is [String: String] else {
                                        print("CRITICAL ERROR: timeIndexMap is corrupted, type: \(type(of: timeIndexMap))")
                                        // Reset the corrupted dictionary
                                        timeIndexMap = [String: String]()
                                    }
                                    
                                    setTimeIndexMapValue(key: key, value: indexText)
                                } else {
                                    print("WARNING: Invalid bandName for timeIndexMap key: '\(bandName)'")
                                }
                                eventCounter = eventCounter + 1
                                if (event == unofficalEventType){
                                    eventCounterUnoffical = eventCounterUnoffical + 1
                                }
                            }
                    } else {
                        print("WARNING: No typeField for bandName: \(bandName), timeIndex: \(timeIndex)")
                        }
                    }
            }
        }
        bandCount = 0;
        eventCount = newAllBands.count;
    } else {
        
        print ("returning Bands!!!");
        //return immediatly. Dont need to do schedule sorting magic
        newAllBands = allBands;
        newAllBands.sort();
        bandCount = newAllBands.count;
        eventCount = 0;
        bandCounter = allBands.count
        return newAllBands
    }

    newAllBands.sort();
    
    if (newAllBands.count == 0 && getShowOnlyWillAttened() == true){
        //setShowOnlyWillAttened(false);
        //newAllBands = determineBandOrScheduleList(allBands, sortedBy: sortedBy, schedule: schedule, dataHandle: dataHandle, attendedHandle: attendedHandle)
    }
    
    // Only add bands without shows if NOT in Show Flagged Events Only mode
    if (schedule.getTimeSortedSchedulingData().count >= 1 && getShowOnlyWillAttened() == false){
        bandCounter = 0
        unfilteredBandCount = 0
        for bandName in allBands {
            unfilteredBandCount = unfilteredBandCount + 1
            if (presentCheck.contains(bandName) == false){
                if (applyFilters(bandName: bandName,timeIndex: 0, schedule: schedule, dataHandle: dataHandle, attendedHandle: attendedHandle) == true){
                    print("Adding!! bandName  " + bandName)
                    newAllBands.append(bandName);
                    presentCheck.append(bandName);
                    bandCounter = bandCounter + 1
                }
            }
        }
    }
    
    //unfilteredBandCount = unfilteredBandCount - unfilteredCruiserEventCount
    return newAllBands
}

func applyFilters(bandName:String, timeIndex:TimeInterval, schedule: scheduleHandler, dataHandle: dataHandler, attendedHandle: ShowsAttended)-> Bool{
    // Defensive: Ensure correct types
    guard type(of: bandName) == String.self else {
        print("ERROR: applyFilters called with non-String bandName: \(bandName) (type: \(type(of: bandName)))")
        return false
    }
    guard type(of: timeIndex) == Double.self else {
        print("ERROR: applyFilters called with non-Double timeIndex: \(timeIndex) (type: \(type(of: timeIndex)))")
        return false
    }
    // Special case: band with no events (timeIndex == 0)
    if timeIndex == 0 {
        if getShowOnlyWillAttened() == true {
            // In flagged-only mode, do not show bands with no events
            return false
        }
        // Only apply rank filtering otherwise
        return rankFiltering(bandName, dataHandle: dataHandle)
    }
    // Defensive: Check for nil in bandDict and timeDict
    guard let bandDict = schedule.getBandSortedSchedulingData()[bandName] else {
        print("WARNING: No bandDict for bandName: \(bandName)")
        return false
    }
    guard let timeDict = bandDict[timeIndex] else {
        print("WARNING: No timeDict for bandName: \(bandName), timeIndex: \(timeIndex)")
        return false
    }
    guard let typeValue = timeDict[typeField], !typeValue.isEmpty else {
        print("WARNING: No typeField for bandName: \(bandName), timeIndex: \(timeIndex)")
        return false
    }
    var include = false;
    
    if (timeIndex.isZero == false){
        
        if (willAttenedFilters(bandName: bandName,timeIndex: timeIndex, schedule: schedule, attendedHandle: attendedHandle) == true){
            attendingCount = attendingCount + 1;
            print ("attendingCount is \(attendingCount) after adding 1")
        }
        
        if (getShowOnlyWillAttened() == true){
            include = willAttenedFilters(bandName: bandName,timeIndex: timeIndex, schedule: schedule, attendedHandle: attendedHandle);
        
        } else {
            let eventType = typeValue
            if (eventType == unofficalEventType){
                unfilteredCruiserEventCount = unfilteredCruiserEventCount + 1
            }
            if (eventTypeFiltering(eventType) == true){
                if (schedule.getBandSortedSchedulingData().isEmpty == false){
                    if let locationValue = timeDict[locationField], venueFiltering(locationValue) == true {
                        if (rankFiltering(bandName, dataHandle: dataHandle) == true){
                            if (eventType == unofficalEventType || eventType == unofficalEventTypeOld){
                                unofficalEventCount = unofficalEventCount + 1
                            }
                            include = true
                        }
                    }
                }
            }
        }
    } else {
        if (getShowOnlyWillAttened() == false){
            include = rankFiltering(bandName, dataHandle: dataHandle);
        }
    }
    
    return include
}

func getFilteredBands(bandNameHandle: bandNamesHandler, schedule: scheduleHandler, dataHandle: dataHandler, attendedHandle: ShowsAttended, searchCriteria: String) -> [String] {
    
    let allBands = bandNameHandle.getBandNames()

    var sortedBy = getSortedBy()
    
    //set default if empty
    if (sortedBy.isEmpty == true){
        sortedBy = "time"
    }
    
    var filteredBands = [String]()
    
    var newAllBands = [String]()
    
    filteredBandCount = 0
    unfilteredBandCount = 0
    
    if (isGetFilteredBands == true){
        while (isGetFilteredBands == true){
            sleep(1);
        }
    } else {
 
        isGetFilteredBands = true;

        newAllBands = determineBandOrScheduleList(allBands, sortedBy: sortedBy, schedule: schedule, dataHandle: dataHandle, attendedHandle: attendedHandle);
        
        if (getShowOnlyWillAttened() == true){
            filteredBands = newAllBands;
            
            if (searchCriteria != ""){
                var newFilteredBands = [String]()
                for bandNameIndex in filteredBands {
                    if (bandNameIndex.contains(searchCriteria) == true){
                        newFilteredBands.append(bandNameIndex)
                    }
                }
                filteredBands = newFilteredBands
            }
            
        } else {
            for bandNameIndex in newAllBands {
                let bandName = getNameFromSortable(bandNameIndex, sortedBy: sortedBy);
                
                if (searchCriteria != ""){
                    if (bandName.contains(searchCriteria) == false){
                        continue
                    }
                }
                switch dataHandle.getPriorityData(bandName) {
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
                    print (dataHandle.getPriorityData(bandName))
                }
            }
        }
        isGetFilteredBands = false;
    }
    filteredBandCount = filteredBands.count

    if (filteredBandCount == 0){
        print ("handleEmptryList: Why is this being called 1")
        filteredBands = handleEmptryList(bandNameHandle: bandNameHandle);
    } else {
        bandCounter = filteredBands.count
        listCount = filteredBands.count
    }
    
    print ("listCount is \(listCount) - 2")
    return filteredBands
}

/// HIGH PRIORITY: Immediate filtering function that bypasses delays for priority/attended changes
func getFilteredBandsImmediate(bandNameHandle: bandNamesHandler, schedule: scheduleHandler, dataHandle: dataHandler, attendedHandle: ShowsAttended, searchCriteria: String) -> [String] {
    
    let allBands = bandNameHandle.getBandNames()

    var sortedBy = getSortedBy()
    
    //set default if empty
    if (sortedBy.isEmpty == true){
        sortedBy = "time"
    }
    
    var filteredBands = [String]()
    
    var newAllBands = [String]()
    
    filteredBandCount = 0
    unfilteredBandCount = 0
    
    // HIGH PRIORITY: Skip the blocking check for immediate updates
    // if (isGetFilteredBands == true){
    //     while (isGetFilteredBands == true){
    //         sleep(1);
    //     }
    // } else {
 
    // isGetFilteredBands = true;

    newAllBands = determineBandOrScheduleList(allBands, sortedBy: sortedBy, schedule: schedule, dataHandle: dataHandle, attendedHandle: attendedHandle);
    
    if (getShowOnlyWillAttened() == true){
        filteredBands = newAllBands;
        
        if (searchCriteria != ""){
            var newFilteredBands = [String]()
            for bandNameIndex in filteredBands {
                if (bandNameIndex.contains(searchCriteria) == true){
                    newFilteredBands.append(bandNameIndex)
                }
            }
            filteredBands = newFilteredBands
        }
        
    } else {
        for bandNameIndex in newAllBands {
            let bandName = getNameFromSortable(bandNameIndex, sortedBy: sortedBy);
            
            if (searchCriteria != ""){
                if (bandName.contains(searchCriteria) == false){
                    continue
                }
            }
            switch dataHandle.getPriorityData(bandName) {
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
                print (dataHandle.getPriorityData(bandName))
            }
        }
    }
    // isGetFilteredBands = false;
    // }
    filteredBandCount = filteredBands.count

    if (filteredBandCount == 0){
        print ("handleEmptryList: Why is this being called 1")
        filteredBands = handleEmptryList(bandNameHandle: bandNameHandle);
    } else {
        bandCounter = filteredBands.count
        listCount = filteredBands.count
    }
    
    print ("HIGH PRIORITY: Immediate listCount is \(listCount) - 2")
    return filteredBands
}

func handleEmptryList(bandNameHandle: bandNamesHandler)->[String]{
    
    var filteredBands = [String]()
    var localMessage = ""
    if (bandNameHandle.bandNames.count == 0){
        localMessage = NSLocalizedString("waiting_for_data", comment: "")
    } else {
        localMessage = NSLocalizedString("data_filter_issue", comment: "")
    }
    
    filteredBands.append(localMessage)
    
    print ("listCount is \(listCount) - 1")
    listCount = 0

    return filteredBands
}

func getNameFromSortable(_ value: String, sortedBy: String) -> String{
    
    let indexString = value.components(separatedBy: ":")
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

func getTimeFromSortable(_ value: String, sortBy: String) -> Double{
    
    let indexString = value.components(separatedBy: ":")
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

func rankFiltering(_ bandName: String, dataHandle: dataHandler) -> Bool {
    
    var showBand = true;
    
    if (getMustSeeOn() == false && dataHandle.getPriorityData(bandName) == 1){
        showBand = false
        print ("numberOfFilteredRecords is  -2- \(bandName)")
        numberOfFilteredRecords = numberOfFilteredRecords + 1
    
    } else if (getMightSeeOn() == false && dataHandle.getPriorityData(bandName) == 2){
        showBand = false
        print ("numberOfFilteredRecords is  -3- \(bandName)")
        numberOfFilteredRecords = numberOfFilteredRecords + 1
        
    } else if (getWontSeeOn() == false && dataHandle.getPriorityData(bandName) == 3){
        print ("numberOfFilteredRecords is  -4- \(bandName)")
        showBand = false
        numberOfFilteredRecords = numberOfFilteredRecords + 1
        
    } else if (getUnknownSeeOn() == false && dataHandle.getPriorityData(bandName) == 0){
        print ("numberOfFilteredRecords is  -5- \(bandName)")
        showBand = false
        numberOfFilteredRecords = numberOfFilteredRecords + 1
    
    }
    
    print ("numberOfFilteredRecords is  -1- \(numberOfFilteredRecords)")
    return showBand

}

func willAttenedFilters(bandName: String, timeIndex:TimeInterval, schedule: scheduleHandler, attendedHandle: ShowsAttended) -> Bool{

    var showEvent = true;

    let eventType = schedule.getBandSortedSchedulingData()[bandName]![timeIndex]![typeField]!
    let location = schedule.getBandSortedSchedulingData()[bandName]![timeIndex]![locationField]!
    let startTime = schedule.getBandSortedSchedulingData()[bandName]![timeIndex]![startTimeField]!

    if (timeIndex.isZero){
        showEvent = false
    
    } else {
        // Prevent infinite loop by checking if attended data is ready
        let showsAttended = attendedHandle.getShowsAttended()
        if showsAttended.isEmpty {
            print("mainListController: Skipping attended filtering - data not ready yet")
            showEvent = true // Default to showing the event when data isn't ready
        } else {
            let status = attendedHandle.getShowAttendedStatus(band: bandName, location: location, startTime: startTime, eventType: eventType,eventYearString: String(eventYear))

            if (status == sawNoneStatus){
                showEvent = false
            }
        }
    }

    return showEvent;
}

func eventTypeFiltering(_ eventType: String) -> Bool{
    
    var showEvent = false;
    
    if (eventType == specialEventType && getShowSpecialEvents() == true){
        showEvent = true;
 
    } else if (eventType == karaokeEventType && getShowSpecialEvents() == true){
            showEvent = true;
            
    } else if (eventType == meetAndGreetype && getShowMeetAndGreetEvents() == true){
        showEvent = true;
    
    } else if (eventType == clinicType && getShowMeetAndGreetEvents() == true){
        showEvent = true;

    } else if (eventType == listeningPartyType && getShowMeetAndGreetEvents() == true){
        showEvent = true;
        
    } else if ((eventType == unofficalEventType || eventType == unofficalEventTypeOld) && getShowUnofficalEvents() == true){
        showEvent = true;
    
    } else if (eventType == showType){
       showEvent = true;

    } else {
        numberOfFilteredRecords = numberOfFilteredRecords + 1
    }
    
    return showEvent
}

func venueFiltering(_ venue: String) -> Bool {
    
    print ("filtering venue is " + venue)

    var showVenue = false;
    
    if (venue == poolVenueText && getShowPoolShows() == true){
        showVenue = true
    
    } else if (venue == theaterVenueText && getShowTheaterShows() == true){
        showVenue = true

    } else if (venue == rinkVenueText && getShowRinkShows() == true){
        showVenue = true
        
    } else if (venue == loungeVenueText && getShowLoungeShows() == true){
        showVenue = true
        
    } else if (venue != loungeVenueText && venue != rinkVenueText && venue != theaterVenueText && venue != poolVenueText && getShowOtherShows() == true){
        showVenue = true
        
    } else {
        numberOfFilteredRecords = numberOfFilteredRecords + 1
    }
    
    return showVenue
}

func getCellValue (_ indexRow: Int, schedule: scheduleHandler, sortBy: String, cell: UITableViewCell, dataHandle: dataHandler, attendedHandle: ShowsAttended){
    
    var rankLocationSchedule = false
        
    //index is out of bounds. Don't allow this
    if (bands.count <= indexRow || bands.count == 0){
        return
    }
    print ("bands = \(bands)")
    print ("indexRow = \(indexRow)")
    
    print ("count is \(bands.count) - \(indexRow)")

    let bandName = getNameFromSortable(bands[indexRow], sortedBy: sortBy);
    
    if (indexRow >= 1){
        previousBandName = getNameFromSortable(bands[indexRow - 1], sortedBy: sortBy);
    }
    if (indexRow <= (bands.count - 2)){
        nextBandName = getNameFromSortable(bands[indexRow + 1], sortedBy: sortBy);
    }
    if (indexRow > previousIndexRow){
        scrollDirection = "Down"
    } else {
        scrollDirection = "Up"
    }

    previousIndexRow = indexRow
    
    let timeIndex = getTimeFromSortable(bands[indexRow], sortBy: sortBy);
    
    //var bandText = String()
    var dayText = String()
    var locationText = String()
    var startTimeText = String()
    var endTimeText = String()
    var scheduleText = String()
    var rankGraphic = UIImageView()
    var indexText = String()
    
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
    
    indexForCell.isHidden = true
    bandNameView.textColor = UIColor.white
    locationView.textColor = UIColor.lightGray
    startTimeView.textColor = UIColor.white
    endTimeView.textColor = hexStringToUIColor(hex: "#797D7F")
    dayView.textColor = UIColor.white
    bandNameNoSchedule.textColor = UIColor.white
    
    bandNameView.text = bandName
    indexText = bandName
    
    cell.backgroundColor = UIColor.black;
    cell.textLabel?.textColor = UIColor.white
    
    var displayBandName = bandName;
    
    if (timeIndex > 1){
        
        
        hasScheduleData = true
        
        locationView.isHidden = false
        startTimeView.isHidden = false
        endTimeView.isHidden = false
        dayView.isHidden = false
        dayLabelView.isHidden = false
        attendedView.isHidden = false
        eventTypeImageView.isHidden = false
        
        let location = schedule.getData(bandName, index:timeIndex, variable: locationField)
        let day = monthDateRegionalFormatting(dateValue: schedule.getData(bandName, index: timeIndex, variable: dayField))
        let startTime = schedule.getData(bandName, index: timeIndex, variable: startTimeField)
        let endTime = schedule.getData(bandName, index: timeIndex, variable: endTimeField)
        let event = schedule.getData(bandName, index: timeIndex, variable: typeField)
        let eventIcon = getEventTypeIcon(eventType: event, eventName: bandName)
        let notes = schedule.getData(bandName, index:timeIndex, variable: notesField)
                
        indexText += ";" + location + ";" + event + ";" + startTime
                
        print(bandName + " displaying timeIndex of \(timeIndex) ")
        startTimeText = formatTimeValue(timeValue: startTime)
        endTimeText = formatTimeValue(timeValue: endTime)
        locationText = location;
        
        if (venueLocation[location] != nil){
            locationText += " " + venueLocation[location]!
        }
        if (notes.isEmpty == false && notes != " "){
            locationText += " " + notes
        }
        
        scheduleText = bandName + ":" + startTimeText + ":" + locationText
        scheduleButton = false
    
        print("scheduleText  = \(scheduleText)")
        print ("Icon parms \(bandName) \(location) \(startTime) \(event)")
        let icon = attendedHandle.getShowAttendedIcon(band: bandName,location: location,startTime: startTime,eventType: event,eventYearString: String(eventYear));
        print ("Icon parms icon is \(icon)")
        
        attendedView.image = icon
        eventTypeImageView.image = eventIcon

        print ("Icon for event \(indexText) is \(icon) " + String(eventYear))
        
        scheduleIndexByCall[scheduleText] = [String:String]()
        scheduleIndexByCall[scheduleText]!["location"] = location
        scheduleIndexByCall[scheduleText]!["bandName"] = bandName
        scheduleIndexByCall[scheduleText]!["startTime"] = startTime
        scheduleIndexByCall[scheduleText]!["event"] = event
        
        if day == "Day 1"{
            dayText = "1";
        
        } else if day == "Day 2"{
            dayText = "2";
            
        } else if day == "Day 3"{
            dayText = "3";
            
        } else if day == "Day 4"{
            dayText = "4";
            
        } else {
            dayText = day
        }
        
        dayView.text = dayText
        dayLabelView.text = NSLocalizedString("Day", comment: "")
        
        if (indexRow == 0){
            previousBandName = "Unknown"
            nextBandName = "Unknown"
        }
        //1st entry Checking if bandname Abysmal Dawn matched previous bandname Abysmal Dawn - All Star Jam index for cell 2 - Up
        if ((bandName == previousBandName  && scrollDirection == "Down" && indexRow != 0) && sortBy == "name"){
            
            print ("Partial Info 1 Checking if bandname \(bandName) matched previous bandname \(previousBandName) - \(nextBandName) index for cell \(indexRow) - \(scrollDirection)")
            getCellScheduleValuePartialInfo(bandName: bandName, location: location, bandNameView: bandNameView, locationView: locationView, bandNameNoSchedule: bandNameNoSchedule, notes: notes)
 
        } else if (scrollDirection == "Down"){
            print ("Full Info 2 Checking if bandname \(bandName) matched previous bandname \(previousBandName) - \(nextBandName) index for cell \(indexRow) - \(scrollDirection)")
            getCellScheduleValueFullInfo(bandName: bandName, location: location, locationText: locationText,bandNameView: bandNameView, locationView: locationView, bandNameNoSchedule: bandNameNoSchedule)
            
        }else if ((bandName != previousBandName || indexRow == 0) && sortBy == "name"){
            print ("Full Info 3 Checking if bandname \(bandName) matched previous bandname \(previousBandName) - \(nextBandName) index for cell \(indexRow) - \(scrollDirection)")
            getCellScheduleValueFullInfo(bandName: bandName, location: location, locationText: locationText,bandNameView: bandNameView, locationView: locationView, bandNameNoSchedule: bandNameNoSchedule)
 
        } else if (sortBy == "name"){
            print ("Partial Info 4 Checking if bandname \(bandName) matched previous bandname \(previousBandName) - \(nextBandName) index for cell \(indexRow) - \(scrollDirection)")
            getCellScheduleValuePartialInfo(bandName: bandName, location: location, bandNameView: bandNameView, locationView: locationView, bandNameNoSchedule: bandNameNoSchedule, notes: notes)
            
        } else {
            print ("Full Info 5 Checking if bandname \(bandName) matched previous bandname \(previousBandName) - \(nextBandName) index for cell \(indexRow) - \(scrollDirection)")
            getCellScheduleValueFullInfo(bandName: bandName, location: location, locationText: locationText,bandNameView: bandNameView, locationView: locationView, bandNameNoSchedule: bandNameNoSchedule)
        }
        
    
        startTimeView.text = startTimeText
        endTimeView.text = endTimeText
        
        rankLocationSchedule = true
        //bandNameView.isHidden = false
        //bandNameNoSchedule.isHidden = true
        
    } else {
        // Check if the band has any future shows (not just any shows)
        let now = Date().timeIntervalSince1970
        var hasFutureShow = false
        if let bandSchedule = schedule.getBandSortedSchedulingData()[bandName] {
            for (showTime, showData) in bandSchedule {
                // Only consider shows in the future
                if showTime > now {
                    // Check if this show would be filtered out (e.g., by willAttenedFilters or other logic)
                    // If it would be shown, then we should NOT show the band name only
                    // If it would be filtered, we should NOT show the band at all
                    hasFutureShow = true
                    break
                }
            }
        }
        if hasFutureShow {
            // Do not hide the cell; instead, do nothing so the cell is empty or not present in the bands array
            // cell.isHidden = true // REMOVED to fix scroll area issue
            return
        }
        // Otherwise, show only the band name (no future shows)
        rankLocationSchedule = false
        print ("Not display schedule for band " + bandName)
        scheduleButton = true
        locationView.isHidden = true
        startTimeView.isHidden = true
        endTimeView.isHidden = true
        dayView.isHidden = true
        dayLabelView.isHidden = true
        attendedView.isHidden = true
        eventTypeImageView.isHidden = true
        bandNameNoSchedule.text = bandName
        bandNameNoSchedule.isHidden = false  
        bandNameView.isHidden = true
    }
    
    indexForCell.text = indexText;
    
    print ("Cell text for \(bandName) ranking is \(dataHandle.getPriorityData(bandName))")
    rankGraphic = UIImageView(image:UIImage(named: getPriorityGraphic(dataHandle.getPriorityData(bandName))))
    
    if (timeIndex > 1 && sortBy == "name" && bandName == previousBandName){
        rankGraphic.image = nil
    }
    
    if (rankGraphic.image != nil){
        if (rankLocationSchedule == true){
            rankImageView.isHidden = false
            rankImageViewNoSchedule.isHidden = true
            rankImageView.image = rankGraphic.image
            
        } else {
            rankImageView.isHidden = true
            rankImageViewNoSchedule.isHidden = false
            rankImageViewNoSchedule.image = rankGraphic.image
        }
    } else {
        rankImageView.isHidden = true
        rankImageViewNoSchedule.isHidden = true
    }
    
    previousBandName = bandName
    if (firstBandName.isEmpty == true){
        firstBandName  = bandName;
    }
    // At the end of getCellValue, after setting rankLocationSchedule:
    // Remove any existing custom separator
    cell.contentView.viewWithTag(9999)?.removeFromSuperview()
    if rankLocationSchedule {
        // Add custom separator for schedule rows
        let separator = UIView(frame: CGRect(x: 15, y: cell.contentView.frame.height - 1, width: cell.contentView.frame.width - 30, height: 1))
        separator.backgroundColor = UIColor.lightGray
        separator.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        separator.tag = 9999
        cell.contentView.addSubview(separator)
    }
}


func getCellScheduleValuePartialInfo(bandName: String, location: String, bandNameView: UILabel, locationView: UILabel, bandNameNoSchedule: UILabel, notes: String){
    // Use a single colored marker followed by one space, then the venue info
    let marker = " "
    let locationString = marker + "  " + location // marker, then one space, then venue
    let venueString = NSMutableAttributedString(string: locationString)
    let locationColor = getVenueColor(venue: location)

    // Colored marker: fixed 17pt bold font, background color
    venueString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 17), range: NSRange(location:1,length:1))
    venueString.addAttribute(.backgroundColor, value: locationColor, range: NSRange(location:1,length:1))

    // Venue text: consistent font size (16pt), light gray
    if location.count > 0 && locationString.count > 2 {
        let range = NSRange(location: 2, length: location.count + 1)
        if NSMaxRange(range) <= locationString.count {
            venueString.addAttribute(.font, value: UIFont.systemFont(ofSize: 16), range: range)
            venueString.addAttribute(.foregroundColor, value: UIColor.lightGray, range: range)
        }
    }

    bandNameView.adjustsFontSizeToFitWidth = false
    bandNameView.attributedText = venueString
    bandNameView.isHidden = false;

    // Second line: venueLocation/notes, same logic
    let venueLocationText = (venueLocation[location] ?? "")
    var locationOfVenue = marker + " " + venueLocationText
    if !notes.trimmingCharacters(in: .whitespaces).isEmpty {
        locationOfVenue += " " + notes
    }
    let locationOfVenueString = NSMutableAttributedString(string: locationOfVenue)
    locationOfVenueString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 17), range: NSRange(location:0,length:1))
    locationOfVenueString.addAttribute(.backgroundColor, value: locationColor, range: NSRange(location:0,length:1))
    if locationOfVenue.count > 2 {
        let range = NSRange(location: 2, length: locationOfVenue.count - 2)
        if NSMaxRange(range) <= locationOfVenue.count {
            locationOfVenueString.addAttribute(.font, value: UIFont.systemFont(ofSize: 16), range: range)
            locationOfVenueString.addAttribute(.foregroundColor, value: UIColor.lightGray, range: range)
        }
    }
    locationView.adjustsFontSizeToFitWidth = false
    locationView.attributedText = locationOfVenueString
    bandNameNoSchedule.text = bandName
    bandNameNoSchedule.isHidden = true
}

func getCellScheduleValueFullInfo(bandName: String, location: String, locationText: String, bandNameView: UILabel, locationView: UILabel, bandNameNoSchedule: UILabel){
    // Use a single space as the colored marker
    let marker = " "
    let locationString = marker + " " + locationText
    let myMutableString = NSMutableAttributedString(string: locationString)
    let locationColor = getVenueColor(venue: location)

    // Colored marker: fixed 17pt bold font, background color
    myMutableString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 17), range: NSRange(location:0,length:1))
    myMutableString.addAttribute(.backgroundColor, value: locationColor, range: NSRange(location:0,length:1))

    // Venue text: consistent font size (16pt), light gray
    if locationText.count > 0 {
        myMutableString.addAttribute(.font, value: UIFont.systemFont(ofSize: 16), range: NSRange(location:1,length: locationText.count))
        myMutableString.addAttribute(.foregroundColor, value: UIColor.lightGray, range: NSRange(location:1,length: locationText.count))
    }
    bandNameView.backgroundColor = UIColor.black;
    locationView.adjustsFontSizeToFitWidth = false
    locationView.attributedText = myMutableString
    bandNameView.isHidden = false
    bandNameNoSchedule.isHidden = true
    bandNameNoSchedule.text = ""
}

func calculateOptimalFontSize(for text: String, in label: UILabel, markerWidth: CGFloat, maxSize: CGFloat, minSize: CGFloat) -> CGFloat {
    // Use a consistent estimated width instead of relying on potentially inaccurate label bounds
    // Most table view cells have similar widths, so use a reasonable estimate
    let estimatedLabelWidth: CGFloat = 200 // Reasonable estimate for location text area
    
    // Calculate actual marker width (17pt font typically renders to about 8-10pt width for a space)
    let actualMarkerWidth: CGFloat = 10
    
    // Calculate available width with minimal padding
    let availableWidth = estimatedLabelWidth - actualMarkerWidth - 2
    
    // For very short text, always use maximum size
    if text.count <= 8 { // Short location names like "Pool", "Theater"
        return maxSize
    }
    
    // For medium length text, use a size based on character count
    if text.count <= 15 { // Medium names like "Theater Deck 3/4"
        return maxSize - 1 // 15pt for medium length
    }
    
    // Start with maximum font size and work down more granularly for longer text
    for fontSize in stride(from: maxSize, through: minSize, by: -0.25) {
        let font = UIFont.systemFont(ofSize: fontSize)
        let textSize = text.size(withAttributes: [NSAttributedString.Key.font: font])
        
        // If text fits comfortably at this font size, use it
        if textSize.width <= availableWidth * 0.9 { // Use 90% of available width for buffer
            return fontSize
        }
    }
    
    // For very long text, return a reasonable minimum
    return max(13, minSize) // Never go below 13pt for readability
}

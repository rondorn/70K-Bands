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

func determineBandOrScheduleList (_ allBands:[String], sortedBy: String, schedule: scheduleHandler, dataHandle: dataHandler, priorityManager: PriorityManager, attendedHandle: ShowsAttended) -> [String]{
    
    let startTime = CFAbsoluteTimeGetCurrent()
    print("🕐 [\(String(format: "%.3f", startTime))] determineBandOrScheduleList START - processing \(allBands.count) bands")
    
    numberOfFilteredRecords = 0
    var newAllBands = [String]()
    
    // If no band data is loaded yet, return empty array to trigger waiting message
    if allBands.isEmpty {
        print("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] [YEAR_CHANGE_DEBUG] determineBandOrScheduleList: No band data loaded, returning empty array for waiting message")
        return []
    }
    
    var presentCheck = [String]();
    //var listOfVenues = ["All"]
    attendingCount = 0
    unofficalEventCount = 0
    if (typeField.isEmpty == true){
        print("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] determineBandOrScheduleList: typeField is empty, returning \(allBands.count) bands immediately")
        return allBands;
    }
    
    print ("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] Locking object with newAllBands")
    eventCounter = 0
    eventCounterUnoffical = 0
    unfilteredBandCount = 0
    unfilteredEventCount = 0
    unfilteredCruiserEventCount = 0
    unfilteredCurrentEventCount = 0
    
    
    print ("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] [YEAR_CHANGE_DEBUG] sortedBy = \(sortedBy)")
    
    let buildStartTime = CFAbsoluteTimeGetCurrent()
    print("🕐 [\(String(format: "%.3f", buildStartTime))] Starting buildTimeSortedSchedulingData")
    schedule.buildTimeSortedSchedulingData();
    let buildEndTime = CFAbsoluteTimeGetCurrent()
    print("🕐 [\(String(format: "%.3f", buildEndTime))] buildTimeSortedSchedulingData END - time: \(String(format: "%.3f", (buildEndTime - buildStartTime) * 1000))ms")
    
    print ("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] [YEAR_CHANGE_DEBUG] Schedule data count: \(schedule.getTimeSortedSchedulingData().count) time-sorted, \(schedule.getBandSortedSchedulingData().count) band-sorted")
    
    // Don't process schedule data if it's empty
    if schedule.getBandSortedSchedulingData().isEmpty && schedule.getTimeSortedSchedulingData().isEmpty {
        print("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] [YEAR_CHANGE_DEBUG] determineBandOrScheduleList: Schedule data is empty, returning bands list")
        newAllBands = allBands;
        newAllBands.sort();
        bandCount = newAllBands.count;
        eventCount = 0;
        bandCounter = allBands.count
        return newAllBands
    }
    
    if (schedule.getBandSortedSchedulingData().count > 0 && sortedBy == "name"){
        print ("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] Sorting by name!!!");
        for bandName in schedule.getBandSortedSchedulingData().keys {
            unfilteredBandCount = unfilteredBandCount + 1
            if (schedule.getBandSortedSchedulingData().isEmpty == false){
                unfilteredEventCount = unfilteredEventCount + 1
                guard let bandSchedule = schedule.getBandSortedSchedulingData()[bandName] else {
                    print("[YEAR_CHANGE_DEBUG] determineBandOrScheduleList: Skipping band \(bandName) - no schedule data")
                    continue
                }
                for timeIndex in bandSchedule.keys {
                    guard let timeData = bandSchedule[timeIndex],
                          let dateValue = timeData[dateField],
                          let endTimeValue = timeData[endTimeField] else {
                        print("[YEAR_CHANGE_DEBUG] determineBandOrScheduleList: Missing data for band \(bandName) at time \(timeIndex)")
                        continue
                    }
                    var eventEndTime = schedule.getDateIndex(dateValue, timeString: endTimeValue, band: bandName)
                    print ("start time is \(timeIndex), eventEndTime is \(eventEndTime)")
                    if (timeIndex > eventEndTime){
                        eventEndTime = eventEndTime + (3600*24)
                    }
                    if (eventEndTime > Date().timeIntervalSince1970  || getHideExpireScheduleData() == false){
                        totalUpcomingEvents += 1;
                        if (schedule.getBandSortedSchedulingData()[bandName]?[timeIndex]?[typeField] != nil){
                            if (applyFilters(bandName: bandName,timeIndex: timeIndex, schedule: schedule, dataHandle: dataHandle, priorityManager: PriorityManager(), attendedHandle: attendedHandle) == true){
                                newAllBands.append(bandName + ":" + String(timeIndex));
                                presentCheck.append(bandName);
                                let event = schedule.getData(bandName, index: timeIndex, variable: typeField)
                                eventCounter = eventCounter + 1
                                if (event == unofficalEventType){
                                    eventCounterUnoffical = eventCounterUnoffical + 1
                                }
                            }
                        }
                    }
                }
            }
        }
        bandCount = 0;
        eventCount = newAllBands.count;
        
    } else if (schedule.getTimeSortedSchedulingData().count > 0 && sortedBy == "time"){
        print ("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] [YEAR_CHANGE_DEBUG] Sorting by time!!! Time-sorted data count: \(schedule.getTimeSortedSchedulingData().count)")
        
        let timeSortStartTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", timeSortStartTime))] Starting time-sorted processing loop for \(schedule.getTimeSortedSchedulingData().count) time indices")
        
        var processedCount = 0
        for timeIndex in schedule.getTimeSortedSchedulingData().keys {
            processedCount += 1
            if processedCount % 50 == 0 {
                print("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] Processing time index \(processedCount)/\(schedule.getTimeSortedSchedulingData().count): \(timeIndex)")
            }
            
            print("[YEAR_CHANGE_DEBUG] Processing time index: \(timeIndex)")
            unfilteredEventCount = unfilteredEventCount + 1
            if let eventDataArray = schedule.getTimeSortedSchedulingData()[timeIndex], !eventDataArray.isEmpty {
                // CRITICAL FIX: Process all events in this time slot (was losing events due to single event per time slot)
                print("🔍 [DATA_ACCESS_DEBUG] Processing \(eventDataArray.count) events at timeIndex \(timeIndex)")
                
                for eventData in eventDataArray {
                    // Get the band name from the event data (not from the keys!)
                    guard let bandName = eventData[bandField], !bandName.isEmpty else {
                        print("🔍 [DATA_ACCESS_DEBUG] ❌ No band name found in event data at timeIndex \(timeIndex)")
                        continue
                    }
                    
                    unfilteredBandCount = unfilteredBandCount + 1
                    // Debug: Check each step of data access
                    let allBandData = schedule.getBandSortedSchedulingData()
                    print("🔍 [DATA_ACCESS_DEBUG] Checking band '\(bandName)' at timeIndex \(timeIndex)")
                    
                    guard let bandData = allBandData[bandName] else {
                        print("🔍 [DATA_ACCESS_DEBUG] ❌ No band data found for '\(bandName)'")
                        continue
                    }
                    print("🔍 [DATA_ACCESS_DEBUG] ✅ Found band data for '\(bandName)' with \(bandData.count) time slots")
                    
                    guard let timeData = bandData[timeIndex] else {
                        print("🔍 [DATA_ACCESS_DEBUG] ❌ No time data found for '\(bandName)' at timeIndex \(timeIndex)")
                        print("🔍 [DATA_ACCESS_DEBUG] Available time indices for '\(bandName)': \(Array(bandData.keys).sorted())")
                        continue
                    }
                    print("🔍 [DATA_ACCESS_DEBUG] ✅ Found time data for '\(bandName)' at timeIndex \(timeIndex)")
                    print("🔍 [DATA_ACCESS_DEBUG] Time data keys: \(timeData.keys.sorted())")
                    
                    guard let dateValue = timeData[dateField] else {
                        print("🔍 [DATA_ACCESS_DEBUG] ❌ Missing '\(dateField)' for '\(bandName)' at timeIndex \(timeIndex)")
                        continue
                    }
                    
                    guard let endTimeValue = timeData[endTimeField] else {
                        print("🔍 [DATA_ACCESS_DEBUG] ❌ Missing '\(endTimeField)' for '\(bandName)' at timeIndex \(timeIndex)")
                        continue
                    }
                    
                    print("🔍 [DATA_ACCESS_DEBUG] ✅ All required fields found for '\(bandName)' at timeIndex \(timeIndex)")
                    var eventEndTime = schedule.getDateIndex(dateValue, timeString: endTimeValue, band: bandName)
                    print ("start time is \(timeIndex), eventEndTime is \(eventEndTime)")
                    if (timeIndex > eventEndTime){
                        eventEndTime = eventEndTime + (3600*24)
                    }
                    if (eventEndTime > Date().timeIntervalSince1970 || getHideExpireScheduleData() == false){
                        unfilteredCurrentEventCount = unfilteredCurrentEventCount + 1
                        totalUpcomingEvents += 1;
                        if let typeValue = schedule.getBandSortedSchedulingData()[bandName]?[timeIndex]?[typeField], !typeValue.isEmpty {
                            if (applyFilters(bandName: bandName,timeIndex: timeIndex, schedule: schedule, dataHandle: dataHandle, priorityManager: PriorityManager(), attendedHandle: attendedHandle) == true){
                                newAllBands.append(String(timeIndex) + ":" + bandName);
                                presentCheck.append(bandName);
                                
                                let event = schedule.getData(bandName, index: timeIndex, variable: typeField)
                                let location = schedule.getData(bandName, index:timeIndex, variable: locationField)
                                let startTime = schedule.getData(bandName, index: timeIndex, variable: startTimeField)
                                let indexText = bandName + ";" + location + ";" + event + ";" + startTime
                                timeIndexMap[String(timeIndex) + ":" + bandName] = indexText
                                eventCounter = eventCounter + 1
                                if (event == unofficalEventType){
                                    eventCounterUnoffical = eventCounterUnoffical + 1
                                }
                            }
                        }
                    }
                }
            } else {
                print("[YEAR_CHANGE_DEBUG] determineBandOrScheduleList: Time index \(timeIndex) has no band data")
            }
        }
        
        let timeSortEndTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", timeSortEndTime))] Time-sorted processing loop END - processed \(processedCount) time indices - time: \(String(format: "%.3f", (timeSortEndTime - timeSortStartTime) * 1000))ms")
        
        bandCount = 0;
        eventCount = newAllBands.count;
        
    } else {
        
        print ("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] [YEAR_CHANGE_DEBUG] returning Bands!!! Band-sorted count: \(schedule.getBandSortedSchedulingData().count), Time-sorted count: \(schedule.getTimeSortedSchedulingData().count), sortedBy: \(sortedBy)");
        //return immediatly. Dont need to do schedule sorting magic
        newAllBands = allBands;
        newAllBands.sort();
        bandCount = newAllBands.count;
        eventCount = 0;
        bandCounter = allBands.count
        
        print ("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] determineBandOrScheduleList is returning \(newAllBands.count) entries -1 ")
        return newAllBands
    }

    // This code runs for name and time sorting (not the else case above)
    newAllBands.sort();
    
    if (newAllBands.count == 0 && getShowOnlyWillAttened() == true){
        //setShowOnlyWillAttened(false);
        //newAllBands = determineBandOrScheduleList(allBands, sortedBy: sortedBy, schedule: schedule, dataHandle: dataHandle, attendedHandle: attendedHandle)
    }
    
    if (schedule.getTimeSortedSchedulingData().count >= 1 ){
        //add any bands without shows to the bottom of the list
        bandCounter = 0
        unfilteredBandCount = 0
        for bandName in allBands {
            unfilteredBandCount = unfilteredBandCount + 1
            if (presentCheck.contains(bandName) == false){
                if (applyFilters(bandName: bandName,timeIndex: 0, schedule: schedule, dataHandle: dataHandle, priorityManager: PriorityManager(), attendedHandle: attendedHandle) == true){
                    print("Adding!! bandName  " + bandName)
                    newAllBands.append(bandName);
                    presentCheck.append(bandName);
                    bandCounter = bandCounter + 1
                }
            }
        }
    }
    
    let endTime = CFAbsoluteTimeGetCurrent()
    print("🕐 [\(String(format: "%.3f", endTime))] determineBandOrScheduleList END - returning \(newAllBands.count) entries - total time: \(String(format: "%.3f", (endTime - startTime) * 1000))ms")
    //unfilteredBandCount = unfilteredBandCount - unfilteredCruiserEventCount
    return newAllBands
}

func applyFilters(bandName:String, timeIndex:TimeInterval, schedule: scheduleHandler, dataHandle: dataHandler, priorityManager: PriorityManager, attendedHandle: ShowsAttended)-> Bool{
    let startTime = CFAbsoluteTimeGetCurrent()
    var include = false;
    
    // CRITICAL DEBUG: Log all timeIndex values to understand the filtering
    print("🔍 [APPLY_FILTERS_DEBUG] Band: '\(bandName)', timeIndex: \(timeIndex), isZero: \(timeIndex.isZero)")
    
    if (timeIndex.isZero == false){
        let willAttendStartTime = CFAbsoluteTimeGetCurrent()
        if (willAttenedFilters(bandName: bandName,timeIndex: timeIndex, schedule: schedule, attendedHandle: attendedHandle) == true){
            attendingCount = attendingCount + 1;
            print ("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] attendingCount is \(attendingCount) after adding 1")
        }
        let willAttendEndTime = CFAbsoluteTimeGetCurrent()
        if (willAttendEndTime - willAttendStartTime) > 0.001 { // Only log if it takes more than 1ms
            print("🕐 [\(String(format: "%.3f", willAttendEndTime))] willAttenedFilters for '\(bandName)' took \(String(format: "%.3f", (willAttendEndTime - willAttendStartTime) * 1000))ms")
        }
        
        if (getShowOnlyWillAttened() == true){
            include = willAttenedFilters(bandName: bandName,timeIndex: timeIndex, schedule: schedule, attendedHandle: attendedHandle);
        } else {
            print("🔍 [MAIN_LIST_DEBUG] applyFilters checking band '\(bandName)' at timeIndex \(timeIndex)")
            let allBandData = schedule.getBandSortedSchedulingData()
            print("🔍 [MAIN_LIST_DEBUG] Total bands in schedule data: \(allBandData.count)")
            
            guard let bandData = allBandData[bandName] else {
                print("🔍 [MAIN_LIST_DEBUG] ❌ No schedule data found for band '\(bandName)'")
                return false
            }
            print("🔍 [MAIN_LIST_DEBUG] Band '\(bandName)' has \(bandData.count) events")
            
            guard let timeData = bandData[timeIndex] else {
                print("🔍 [MAIN_LIST_DEBUG] ❌ No event data at timeIndex \(timeIndex) for band '\(bandName)'")
                return false
            }
            print("🔍 [MAIN_LIST_DEBUG] Found event data at timeIndex \(timeIndex) for band '\(bandName)': \(timeData)")
            
            guard let typeValue = timeData[typeField], !typeValue.isEmpty else {
                print("🔍 [MAIN_LIST_DEBUG] ❌ Missing or empty event type for band '\(bandName)' at timeIndex \(timeIndex)")
                return false
            }
            let eventType = typeValue
            if (eventType == unofficalEventType){
                unfilteredCruiserEventCount = unfilteredCruiserEventCount + 1
            }
            print("🔍 [MAIN_LIST_DEBUG] Testing eventType '\(eventType)' for band '\(bandName)'")
            if (eventTypeFiltering(eventType) == true){
                print("🔍 [MAIN_LIST_DEBUG] ✅ Event type '\(eventType)' passed eventTypeFiltering")
                if (!bandData.isEmpty) {
                    if let locationValue = timeData[locationField] {
                        print("🔍 [MAIN_LIST_DEBUG] Testing venue '\(locationValue)' for event type '\(eventType)'")
                        if venueFiltering(locationValue) == true {
                            print("🔍 [MAIN_LIST_DEBUG] ✅ Venue '\(locationValue)' passed venueFiltering")
                            if (rankFiltering(bandName, priorityManager: PriorityManager()) == true){
                                print("🔍 [MAIN_LIST_DEBUG] ✅ Band '\(bandName)' passed rankFiltering - EVENT INCLUDED")
                                if (eventType == unofficalEventType || eventType == unofficalEventTypeOld){
                                    unofficalEventCount = unofficalEventCount + 1
                                }
                                include = true
                            } else {
                                print("🔍 [MAIN_LIST_DEBUG] ❌ Band '\(bandName)' failed rankFiltering")
                            }
                        } else {
                            print("🔍 [MAIN_LIST_DEBUG] ❌ Venue '\(locationValue)' failed venueFiltering for event type '\(eventType)'")
                        }
                    } else {
                        print("🔍 [MAIN_LIST_DEBUG] ❌ No location value found for band '\(bandName)' at timeIndex \(timeIndex)")
                    }
                }
            } else {
                print("🔍 [MAIN_LIST_DEBUG] ❌ Event type '\(eventType)' failed eventTypeFiltering")
            }
        }
    } else {
        print("🔍 [APPLY_FILTERS_DEBUG] timeIndex.isZero == true for '\(bandName)', setting include = true")
        include = true
    }
    
    let endTime = CFAbsoluteTimeGetCurrent()
    if (endTime - startTime) > 0.001 { // Only log if it takes more than 1ms
        print("🕐 [\(String(format: "%.3f", endTime))] applyFilters for '\(bandName)' took \(String(format: "%.3f", (endTime - startTime) * 1000))ms")
    }
    return include;
}

// Add a serial queue for filtering
let filterQueue = DispatchQueue(label: "com.yourapp.filterQueue")

// Refactored getFilteredBands to use serial queue and completion handler
func getFilteredBands(
    bandNameHandle: bandNamesHandler,
    schedule: scheduleHandler,
    dataHandle: dataHandler,
    priorityManager: PriorityManager,
    attendedHandle: ShowsAttended,
    searchCriteria: String,
    completion: @escaping ([String]) -> Void
) {
    let startTime = CFAbsoluteTimeGetCurrent()
    print("🕐 [\(String(format: "%.3f", startTime))] getFilteredBands START")
    
    // Ensure we're always on a background thread to prevent main thread blocking
    if Thread.isMainThread {
        DispatchQueue.global(qos: .userInitiated).async {
            getFilteredBands(
                bandNameHandle: bandNameHandle,
                schedule: schedule,
                dataHandle: dataHandle,
                priorityManager: priorityManager,
                attendedHandle: attendedHandle,
                searchCriteria: searchCriteria,
                completion: completion
            )
        }
        return
    }
    
    filterQueue.async {
        let queueStartTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", queueStartTime))] getFilteredBands filter queue START")
        
        let bandsStartTime = CFAbsoluteTimeGetCurrent()
        let allBands = bandNameHandle.getBandNames()
        let bandsEndTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", bandsEndTime))] getFilteredBands - got \(allBands.count) bands - time: \(String(format: "%.3f", (bandsEndTime - bandsStartTime) * 1000))ms")
        
        var sortedBy = getSortedBy()
        if (sortedBy.isEmpty == true){
            sortedBy = "time"
        }
        var filteredBands = [String]()
        var newAllBands = [String]()
        filteredBandCount = 0
        unfilteredBandCount = 0
        
        let determineStartTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", determineStartTime))] getFilteredBands - starting determineBandOrScheduleList")
        newAllBands = determineBandOrScheduleList(allBands, sortedBy: sortedBy, schedule: schedule, dataHandle: dataHandle, priorityManager: priorityManager, attendedHandle: attendedHandle);
        let determineEndTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", determineEndTime))] getFilteredBands - determineBandOrScheduleList END - got \(newAllBands.count) entries - time: \(String(format: "%.3f", (determineEndTime - determineStartTime) * 1000))ms")
        
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
            let priorityFilterStartTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", priorityFilterStartTime))] getFilteredBands - starting priority filtering for \(newAllBands.count) entries")
            for bandNameIndex in newAllBands {
                let bandName = getNameFromSortable(bandNameIndex, sortedBy: sortedBy);
                if (searchCriteria != ""){
                    if (bandName.contains(searchCriteria) == false){
                        continue
                    }
                }
                switch priorityManager.getPriority(for: bandName) {
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
                    print (priorityManager.getPriority(for: bandName))
                }
            }
            let priorityFilterEndTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", priorityFilterEndTime))] getFilteredBands - priority filtering END - filtered to \(filteredBands.count) entries - time: \(String(format: "%.3f", (priorityFilterEndTime - priorityFilterStartTime) * 1000))ms")
        }
        filteredBandCount = filteredBands.count
        if (filteredBandCount == 0){
            print ("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] mainListDebug: handleEmptryList: Why is this being called 1")
            filteredBands = handleEmptryList(bandNameHandle: bandNameHandle);
        } else {
            bandCounter = filteredBands.count
            listCount = filteredBands.count
        }
        print ("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] mainListDebug: listCount is \(listCount) - 2")
        
        let queueEndTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", queueEndTime))] getFilteredBands filter queue END - total time: \(String(format: "%.3f", (queueEndTime - queueStartTime) * 1000))ms")
        
        DispatchQueue.main.async {
            let completionStartTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", completionStartTime))] getFilteredBands - calling completion with \(filteredBands.count) entries")
            completion(filteredBands)
            let completionEndTime = CFAbsoluteTimeGetCurrent()
            print("🕐 [\(String(format: "%.3f", completionEndTime))] getFilteredBands - completion END - time: \(String(format: "%.3f", (completionEndTime - completionStartTime) * 1000))ms")
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        print("🕐 [\(String(format: "%.3f", endTime))] getFilteredBands END - total time: \(String(format: "%.3f", (endTime - startTime) * 1000))ms")
    }
}

func handleEmptryList(bandNameHandle: bandNamesHandler)->[String]{
    
    var filteredBands = [String]()
    var localMessage = ""
    if (bandNameHandle.getBandNames().count == 0){
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
        if let _ = indexString[0].doubleValue {
            bandName = indexString[1];
        } else if let _ = indexString[1].doubleValue {
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
        if let first = indexString[0].doubleValue {
            timeIndex = first
        } else if let second = indexString[1].doubleValue {
            timeIndex = second
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

func rankFiltering(_ bandName: String, priorityManager: PriorityManager) -> Bool {
    
    var showBand = true;
    
    if (getMustSeeOn() == false && priorityManager.getPriority(for: bandName) == 1){
        showBand = false
        print ("numberOfFilteredRecords is  -2- \(bandName)")
        numberOfFilteredRecords = numberOfFilteredRecords + 1
    
    } else if (getMightSeeOn() == false && priorityManager.getPriority(for: bandName) == 2){
        showBand = false
        print ("numberOfFilteredRecords is  -3- \(bandName)")
        numberOfFilteredRecords = numberOfFilteredRecords + 1
        
    } else if (getWontSeeOn() == false && priorityManager.getPriority(for: bandName) == 3){
        print ("numberOfFilteredRecords is  -4- \(bandName)")
        showBand = false
        numberOfFilteredRecords = numberOfFilteredRecords + 1
        
    } else if (getUnknownSeeOn() == false && priorityManager.getPriority(for: bandName) == 0){
        print ("numberOfFilteredRecords is  -5- \(bandName)")
        showBand = false
        numberOfFilteredRecords = numberOfFilteredRecords + 1
    
    }
    
    print ("numberOfFilteredRecords is  -1- \(numberOfFilteredRecords)")
    return showBand

}

func willAttenedFilters(bandName: String, timeIndex:TimeInterval, schedule: scheduleHandler, attendedHandle: ShowsAttended) -> Bool{
    let startTime = CFAbsoluteTimeGetCurrent()
    var showEvent = true
    guard
        let bandData = schedule.getBandSortedSchedulingData()[bandName],
        let timeData = bandData[timeIndex],
        let eventType = timeData[typeField],
        let location = timeData[locationField],
        let startTimeValue = timeData[startTimeField]
    else {
        print("🕐 [\(String(format: "%.3f", CFAbsoluteTimeGetCurrent()))] willAttenedFilters: Missing data for band: \(bandName), timeIndex: \(timeIndex)")
        return false
    }
    if timeIndex.isZero {
        showEvent = false
    } else {
        let attendedStartTime = CFAbsoluteTimeGetCurrent()
        let status = attendedHandle.getShowAttendedStatus(
            band: bandName,
            location: location,
            startTime: startTimeValue,
            eventType: eventType,
            eventYearString: String(eventYear)
        )
        let attendedEndTime = CFAbsoluteTimeGetCurrent()
        if (attendedEndTime - attendedStartTime) > 0.001 { // Only log if it takes more than 1ms
            print("🕐 [\(String(format: "%.3f", attendedEndTime))] getShowAttendedStatus for '\(bandName)' took \(String(format: "%.3f", (attendedEndTime - attendedStartTime) * 1000))ms")
        }
        if status == sawNoneStatus {
            showEvent = false
        }
    }
    
    let endTime = CFAbsoluteTimeGetCurrent()
    if (endTime - startTime) > 0.001 { // Only log if it takes more than 1ms
        print("🕐 [\(String(format: "%.3f", endTime))] willAttenedFilters for '\(bandName)' took \(String(format: "%.3f", (endTime - startTime) * 1000))ms")
    }
    return showEvent
}

func eventTypeFiltering(_ eventType: String) -> Bool{
    
    var showEvent = false;
    
    // DEBUG: Log all event types we encounter
    print("🔍 [EVENT_TYPE_DEBUG] Filtering eventType: '\(eventType)'")
    print("🔍 [EVENT_TYPE_DEBUG] Expected showType: '\(showType)', meetAndGreetype: '\(meetAndGreetype)'")
    
    if (eventType == specialEventType && getShowSpecialEvents() == true){
        showEvent = true;
        print("🔍 [EVENT_TYPE_DEBUG] ✅ Showing SPECIAL event: '\(eventType)'")
 
    } else if (eventType == karaokeEventType && getShowSpecialEvents() == true){
            showEvent = true;
            print("🔍 [EVENT_TYPE_DEBUG] ✅ Showing KARAOKE event: '\(eventType)'")
            
    } else if (eventType == meetAndGreetype && getShowMeetAndGreetEvents() == true){
        showEvent = true;
        print("🔍 [EVENT_TYPE_DEBUG] ✅ Showing MEET & GREET event: '\(eventType)'")
    
    } else if (eventType == clinicType && getShowMeetAndGreetEvents() == true){
        showEvent = true;
        print("🔍 [EVENT_TYPE_DEBUG] ✅ Showing CLINIC event: '\(eventType)'")

    } else if (eventType == listeningPartyType && getShowMeetAndGreetEvents() == true){
        showEvent = true;
        print("🔍 [EVENT_TYPE_DEBUG] ✅ Showing LISTENING PARTY event: '\(eventType)'")
        
    } else if ((eventType == unofficalEventType || eventType == unofficalEventTypeOld) && getShowUnofficalEvents() == true){
        showEvent = true;
        print("🔍 [EVENT_TYPE_DEBUG] ✅ Showing UNOFFICIAL event: '\(eventType)'")
    
    } else if (eventType == showType){
       showEvent = true;
       print("🔍 [EVENT_TYPE_DEBUG] ✅ Showing SHOW event: '\(eventType)'")

    } else {
        numberOfFilteredRecords = numberOfFilteredRecords + 1
        print("🔍 [EVENT_TYPE_DEBUG] ❌ FILTERED OUT event type: '\(eventType)' (not matching any expected types)")
    }
    
    print("🔍 [EVENT_TYPE_DEBUG] Result for '\(eventType)': \(showEvent ? "SHOW" : "HIDE")")
    return showEvent
}

func venueFiltering(_ venue: String) -> Bool {
    
    print("🔍 [VENUE_DEBUG] Filtering venue: '\(venue)'")
    print("🔍 [VENUE_DEBUG] Expected venues - Pool: '\(poolVenueText)', Theater: '\(theaterVenueText)', Rink: '\(rinkVenueText)', Lounge: '\(loungeVenueText)'")
    print("🔍 [VENUE_DEBUG] Show settings - Pool: \(getShowPoolShows()), Theater: \(getShowTheaterShows()), Rink: \(getShowRinkShows())")
    print("🔍 [VENUE_DEBUG] Additional settings - Lounge: \(getShowLoungeShows()), Other: \(getShowOtherShows())")

    var showVenue = false;
    
    if (venue == poolVenueText && getShowPoolShows() == true){
        showVenue = true
        print("🔍 [VENUE_DEBUG] ✅ Pool venue '\(venue)' ALLOWED")
    
    } else if (venue == theaterVenueText && getShowTheaterShows() == true){
        showVenue = true
        print("🔍 [VENUE_DEBUG] ✅ Theater venue '\(venue)' ALLOWED")

    } else if (venue == rinkVenueText && getShowRinkShows() == true){
        showVenue = true
        print("🔍 [VENUE_DEBUG] ✅ Rink venue '\(venue)' ALLOWED")
        
    } else if (venue == loungeVenueText && getShowLoungeShows() == true){
        showVenue = true
        print("🔍 [VENUE_DEBUG] ✅ Lounge venue '\(venue)' ALLOWED")
        
    } else if (venue != loungeVenueText && venue != rinkVenueText && venue != theaterVenueText && venue != poolVenueText && getShowOtherShows() == true){
        showVenue = true
        print("🔍 [VENUE_DEBUG] ✅ Other venue '\(venue)' ALLOWED (getShowOtherShows: \(getShowOtherShows()))")
        
    } else {
        numberOfFilteredRecords = numberOfFilteredRecords + 1
        print("🔍 [VENUE_DEBUG] ❌ Venue '\(venue)' REJECTED - doesn't match any allowed venue or setting is disabled")
        print("🔍 [VENUE_DEBUG] Lounge setting: \(getShowLoungeShows()), Other setting: \(getShowOtherShows())")
    }
    
    print("🔍 [VENUE_DEBUG] Final result for venue '\(venue)': \(showVenue ? "ALLOW" : "REJECT")")
    return showVenue
}

func getCellValue (_ indexRow: Int, schedule: scheduleHandler, sortBy: String, cell: UITableViewCell, dataHandle: dataHandler, priorityManager: PriorityManager, attendedHandle: ShowsAttended){
    
    var rankLocationSchedule = false
        
    //index is out of bounds. Don't allow this
    if (bands.count <= indexRow || bands.count == 0){
        return
    }
    // Reduced debug logging for performance
    // print ("bands = \(bands)")
    // print ("indexRow = \(indexRow)")
    // print ("count is \(bands.count) - \(indexRow)")

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
    
    // Reduced debug logging for performance
    // print ("Cell text for \(bandName) ranking is \(dataHandle.getPriorityData(bandName))")
    let priorityValue = priorityManager.getPriority(for: bandName)
    let priorityGraphicName = getPriorityGraphic(priorityValue)
    if priorityGraphicName.isEmpty {
        rankGraphic = UIImageView(image: UIImage())
    } else {
        rankGraphic = UIImageView(image: UIImage(named: priorityGraphicName) ?? UIImage())
    }
    
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
}


func getCellScheduleValuePartialInfo(bandName: String, location: String, bandNameView: UILabel, locationView: UILabel, bandNameNoSchedule: UILabel, notes: String){

    //print ("not 1st entry Checking if bandname \(bandName) matched previous bandname \(previousBandName) - \(nextBandName) index for cell \(indexRow) - \(scrollDirection)")
    var locationString = "   " + location
    var venueString = NSMutableAttributedString(string: locationString)
    var locationColor = getVenueColor(venue: location)
    
    // Second space - colored marker with fixed 17pt font (moved over 1 space for alignment)
    venueString.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 17), range: NSRange(location:1,length:1))
    venueString.addAttribute(NSAttributedString.Key.backgroundColor, value: locationColor, range: NSRange(location:1,length:1))
    
    // Location text (after the three spaces) - variable size font (12-16pt)
    if location.count > 0 {
        let locationTextSize = calculateOptimalFontSize(for: location, in: bandNameView, markerWidth: 17, maxSize: 16, minSize: 12)
        venueString.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: locationTextSize), range: NSRange(location:3,length: location.count))
        venueString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.lightGray, range: NSRange(location:3,length: location.count))
    }
    
    // Disable font auto-sizing to preserve our 17pt marker
    bandNameView.adjustsFontSizeToFitWidth = false
    bandNameView.attributedText = venueString
    bandNameView.isHidden = false;
    
    var locationOfVenue = "  " + (venueLocation[location] ?? "")
    if (notes.isEmpty == false && notes != " "){
        locationOfVenue += " " + notes
    }
    
    var locationOfVenueString = NSMutableAttributedString(string: locationOfVenue)
    
    // Second space - colored marker with fixed 17pt font (moved over 1 space for alignment)
    locationOfVenueString.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 17), range: NSRange(location:0,length:1))
    locationOfVenueString.addAttribute(NSAttributedString.Key.backgroundColor, value: locationColor, range: NSRange(location:0,length:1))
    
    // Venue text (after the three spaces) - variable size font (12-16pt)
    if locationOfVenue.count > 3 {
        let venueText = String(locationOfVenue.dropFirst(3)) // Remove the three spaces
        let venueTextSize = calculateOptimalFontSize(for: venueText, in: locationView, markerWidth: 17, maxSize: 16, minSize: 12)
        locationOfVenueString.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: venueTextSize), range: NSRange(location:3,length: locationOfVenue.count - 3))
        locationOfVenueString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.lightGray, range: NSRange(location:3,length: locationOfVenue.count - 3))
    }

    // Disable font auto-sizing to preserve our 17pt marker
    locationView.adjustsFontSizeToFitWidth = false
    locationView.attributedText = locationOfVenueString
    
    //setup bandname for use is access the details screen
    bandNameNoSchedule.text = bandName
    bandNameNoSchedule.isHidden = true
}

func getCellScheduleValueFullInfo(bandName: String, location: String, locationText: String, bandNameView: UILabel, locationView: UILabel, bandNameNoSchedule: UILabel){

    var locationString = "  " + locationText
    var myMutableString = NSMutableAttributedString(string: locationString)
    var locationColor = getVenueColor(venue: location)
    
    // First space - colored marker with fixed 17pt font
    myMutableString.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 17), range: NSRange(location:0,length:1))
    myMutableString.addAttribute(NSAttributedString.Key.backgroundColor, value: locationColor, range: NSRange(location:0,length:1))
    
    // Location text (after the two spaces) - variable size font (12-16pt)
    if locationText.count > 0 {
        let locationTextSize = calculateOptimalFontSize(for: locationText, in: locationView, markerWidth: 17, maxSize: 16, minSize: 12)
        myMutableString.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: locationTextSize), range: NSRange(location:2,length: locationText.count))
        myMutableString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.lightGray, range: NSRange(location:2,length: locationText.count))
    }

    bandNameView.backgroundColor = UIColor.black;
    // Disable font auto-sizing to preserve our 17pt marker
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

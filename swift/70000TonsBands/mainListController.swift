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
    if (schedule.getBandSortedSchedulingData().count > 0 && sortedBy == "name"){
        print ("Sorting by name!!!");
        for bandName in schedule.getBandSortedSchedulingData().keys {
            unfilteredBandCount = unfilteredBandCount + 1
            if (schedule.getBandSortedSchedulingData().isEmpty == false){
                unfilteredEventCount = unfilteredEventCount + 1
                for timeIndex in schedule.getBandSortedSchedulingData()[bandName]!.keys {
                    var eventEndTime = schedule.getDateIndex(schedule.getBandSortedSchedulingData()[bandName]![timeIndex]![dateField]!, timeString: schedule.getBandSortedSchedulingData()[bandName]![timeIndex]![endTimeField]!, band: bandName)
                    print ("start time is \(timeIndex), eventEndTime is \(eventEndTime)")
                    if (timeIndex > eventEndTime){
                        eventEndTime = eventEndTime + (3600*24)
                    }
                    if (eventEndTime > Date().timeIntervalSince1970  || getHideExpireScheduleData() == false){
                        totalUpcomingEvents += 1;
                        if (schedule.getBandSortedSchedulingData()[bandName]?[timeIndex]?[typeField] != nil){
                            if (applyFilters(bandName: bandName,timeIndex: timeIndex, schedule: schedule, dataHandle: dataHandle, attendedHandle: attendedHandle) == true){
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
        print ("Sorting by time!!!");
        for timeIndex in schedule.getTimeSortedSchedulingData().keys {
            unfilteredEventCount = unfilteredEventCount + 1
            if (schedule.getTimeSortedSchedulingData()[timeIndex]?.isEmpty == false){
                for bandName in (schedule.getTimeSortedSchedulingData()[timeIndex]?.keys)!{
                    unfilteredBandCount = unfilteredBandCount + 1
                    var eventEndTime = schedule.getDateIndex(schedule.getBandSortedSchedulingData()[bandName]![timeIndex]![dateField]!, timeString: schedule.getBandSortedSchedulingData()[bandName]![timeIndex]![endTimeField]!, band: bandName)
                    print ("start time is \(timeIndex), eventEndTime is \(eventEndTime)")
                    if (timeIndex > eventEndTime){
                        eventEndTime = eventEndTime + (3600*24)
                    }
                    if (eventEndTime > Date().timeIntervalSince1970 || getHideExpireScheduleData() == false){
                        unfilteredCurrentEventCount = unfilteredCurrentEventCount + 1
                        totalUpcomingEvents += 1;
                        if (schedule.getBandSortedSchedulingData()[bandName]?[timeIndex]?[typeField]?.isEmpty == false){
                            if (applyFilters(bandName: bandName,timeIndex: timeIndex, schedule: schedule, dataHandle: dataHandle, attendedHandle: attendedHandle) == true){
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
                unfilteredBandCount = unfilteredBandCount + 1
                newAllBands = determineBandOrScheduleList(allBands, sortedBy: sortedBy, schedule: schedule, dataHandle: dataHandle, attendedHandle: attendedHandle)
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
    
    if (schedule.getTimeSortedSchedulingData().count >= 1 ){
        //add any bands without shows to the bottom of the list
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
    
    var include = false;
    
    if (timeIndex.isZero == false){
        
        if (willAttenedFilters(bandName: bandName,timeIndex: timeIndex, schedule: schedule, attendedHandle: attendedHandle) == true){
            attendingCount = attendingCount + 1;
            print ("attendingCount is \(attendingCount) after adding 1")
        }
        
        if (getShowOnlyWillAttened() == true){
            include = willAttenedFilters(bandName: bandName,timeIndex: timeIndex, schedule: schedule, attendedHandle: attendedHandle);
        
        } else {
            if (schedule.getBandSortedSchedulingData()[bandName]!.isEmpty == true ||
            schedule.getBandSortedSchedulingData()[bandName]![timeIndex]!.isEmpty == true ||
                schedule.getBandSortedSchedulingData()[bandName]![timeIndex]![typeField]!.isEmpty == true){
                return false;
            }
            
            let eventType = schedule.getBandSortedSchedulingData()[bandName]![timeIndex]![typeField]!
            if (eventType == unofficalEventType){
                unfilteredCruiserEventCount = unfilteredCruiserEventCount + 1
            }
            if (eventTypeFiltering(eventType) == true){
                if (schedule.getBandSortedSchedulingData().isEmpty == false){
                    if (venueFiltering((schedule.getBandSortedSchedulingData()[bandName]![timeIndex]?[locationField])!) == true){
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
        filteredBands = handleEmptryList(bandNameHandle: bandNameHandle);
    } else {
        bandCounter = filteredBands.count
        listCount = filteredBands.count
    }
    
    print ("listCount is \(listCount) - 2")
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
        let status = attendedHandle.getShowAttendedStatus(band: bandName, location: location, startTime: startTime, eventType: eventType,eventYearString: String(eventYear))

        if (status == sawNoneStatus){
            showEvent = false
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
    if (bands.count < indexRow || bands.count == 0){
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
}


func getCellScheduleValuePartialInfo(bandName: String, location: String, bandNameView: UILabel, locationView: UILabel, bandNameNoSchedule: UILabel, notes: String){

    //print ("not 1st entry Checking if bandname \(bandName) matched previous bandname \(previousBandName) - \(nextBandName) index for cell \(indexRow) - \(scrollDirection)")
    var locationString = "  " + location
    var venueString = NSMutableAttributedString(string: locationString)
    var locationColor = getVenueColor(venue: location)
    venueString.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 17), range: NSRange(location:0,length:1))
    venueString.addAttribute(NSAttributedString.Key.backgroundColor, value: locationColor, range: NSRange(location:0,length:1))
    venueString.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 17), range: NSRange(location:1,length: location.count))
    venueString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.lightGray, range: NSRange(location:2,length: location.count))
    bandNameView.attributedText = venueString
    bandNameView.isHidden = false;
    
    var locationOfVenue = "  " + (venueLocation[location] ?? "") ?? ""
    if (notes.isEmpty == false && notes != " "){
        locationOfVenue += " " + notes
    }
    
    var locationOfVenueString = NSMutableAttributedString(string: locationOfVenue)
    locationOfVenueString.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 17), range: NSRange(location:0,length:1))
    locationOfVenueString.addAttribute(NSAttributedString.Key.backgroundColor, value: locationColor, range: NSRange(location:0,length:1))
    locationOfVenueString.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 17), range: NSRange(location:1,length: (locationOfVenue.count - 1)))
    locationOfVenueString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.lightGray, range: NSRange(location:2,length: (locationOfVenue.count - 2)))
    locationView.attributedText = locationOfVenueString
    
    //setup bandname for use is access the details screen
    bandNameNoSchedule.text = bandName
    bandNameNoSchedule.isHidden = true
}

func getCellScheduleValueFullInfo(bandName: String, location: String, locationText: String, bandNameView: UILabel, locationView: UILabel, bandNameNoSchedule: UILabel){

    var locationString = "  " + locationText
    var myMutableString = NSMutableAttributedString(string: locationString)
    var locationColor = getVenueColor(venue: location)
    myMutableString.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 17), range: NSRange(location: 0,length:1))
    myMutableString.addAttribute(NSAttributedString.Key.backgroundColor, value: locationColor, range: NSRange(location:0,length:1))
    myMutableString.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 17), range: NSRange(location:1,length: locationText.count))
    myMutableString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.lightGray, range: NSRange(location:1,length: locationText.count))

    bandNameView.backgroundColor = UIColor.black;
    locationView.attributedText = myMutableString
    bandNameView.isHidden = false
    bandNameNoSchedule.isHidden = true
    bandNameNoSchedule.text = ""
    
}

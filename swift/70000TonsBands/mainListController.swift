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
var mustSeeOn = true;
var mightSeeOn = true;
var wontSeeOn = true;
var unknownSeeOn = true;

var attendingCount = 0;

var showOnlyWillAttened = false;

var sortedBy = String();
var bandCount = Int();
var eventCount = Int();

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
func setHideScheduleButton(_ value: Bool){
    hideScheduleButton = value
}
func getHideScheduleButton() -> Bool{
    return hideScheduleButton
}
func setScheduleButton(_ value: Bool){
    hideScheduleButton = value
}
func getScheduleButton() -> Bool{
    return hideScheduleButton
}
func setMustSeeOn(_ value: Bool){
    mustSeeOn = value
}
func getMustSeeOn() -> Bool{
    return mustSeeOn
}
func setMightSeeOn(_ value: Bool){
    mightSeeOn = value
}
func getMightSeeOn() -> Bool{
    return mightSeeOn
}
func setWontSeeOn(_ value: Bool){
    wontSeeOn = value
}
func getWontSeeOn() -> Bool{
    return wontSeeOn
}

func setUnknownSeeOn(_ value: Bool){
    unknownSeeOn = value
}
func getUnknownSeeOn() -> Bool{
    return unknownSeeOn
}

func setShowOnlyWillAttened(_ value: Bool){
    showOnlyWillAttened = value
}
func getShowOnlyWillAttened() -> Bool{
    return showOnlyWillAttened
}

func setSortedBy(_ value: String){
    sortedBy = value
}
func getSortedBy() -> String{
    return sortedBy
}

func determineBandOrScheduleList (_ allBands:[String], sortedBy: String, schedule: scheduleHandler, dataHandle: dataHandler) -> [String]{
    
    var newAllBands = [String]()
    
    var presentCheck = [String]();
    listOfVenues = ["All"]
    attendingCount = 0
    unofficalEventCount = 0
    if (typeField.isEmpty == true){
        return allBands;
    }
    
    print ("Locking object with newAllBands")
    
    print ("sortedBy = \(sortedBy)")
    schedule.buildTimeSortedSchedulingData();
    print (schedule.getTimeSortedSchedulingData());
    if (schedule.getBandSortedSchedulingData().count > 0 && sortedBy == "name"){
        print ("Sorting by name!!!");
        for bandName in schedule.getBandSortedSchedulingData().keys {
            if (schedule.getBandSortedSchedulingData().isEmpty == false){
                for timeIndex in schedule.getBandSortedSchedulingData()[bandName]!.keys {
                    if (timeIndex > Date().timeIntervalSince1970 - 3600  || defaults.bool(forKey: "hideExpireScheduleData") == false){
                        totalUpcomingEvents += 1;
                        if (schedule.getBandSortedSchedulingData()[bandName]?[timeIndex]?[typeField] != nil){
                            if (applyFilters(bandName: bandName,timeIndex: timeIndex, schedule: schedule, dataHandle: dataHandle) == true){
                                //syncOn(lock:newAllBands as NSObject, description: "newAllBands determineBandOrScheduleList")
                                newAllBands.append(bandName + ":" + String(timeIndex));
                                //syncOff(lock:newAllBands as NSObject, description: "newAllBands determineBandOrScheduleList")
                                presentCheck.append(bandName);
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
            if (schedule.getTimeSortedSchedulingData()[timeIndex]?.isEmpty == false){
                for bandName in (schedule.getTimeSortedSchedulingData()[timeIndex]?.keys)!{
                    if (timeIndex > Date().timeIntervalSince1970 - 3600 || defaults.bool(forKey: "hideExpireScheduleData") == false){
                        totalUpcomingEvents += 1;
                        if (schedule.getBandSortedSchedulingData()[bandName]?[timeIndex]?[typeField]?.isEmpty == false){
                            if (applyFilters(bandName: bandName,timeIndex: timeIndex, schedule: schedule, dataHandle: dataHandle) == true){
                                //syncOn(lock:newAllBands as NSObject, description: "newAllBands determineBandOrScheduleList")
                                newAllBands.append(String(timeIndex) + ":" + bandName);
                                //syncOff(lock:newAllBands as NSObject, description: "newAllBands determineBandOrScheduleList")
                                presentCheck.append(bandName);
                            }
                        }
                    }
                }
            } else {
                newAllBands = determineBandOrScheduleList(allBands, sortedBy: sortedBy, schedule: schedule, dataHandle: dataHandle)
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

        return newAllBands
    }

    newAllBands.sort();
    
    if (newAllBands.count == 0 && getShowOnlyWillAttened() == true){
        setShowOnlyWillAttened(false);
        newAllBands = determineBandOrScheduleList(allBands, sortedBy: sortedBy, schedule: schedule, dataHandle: dataHandle)
    }
    
    if (schedule.getTimeSortedSchedulingData().count > 2){
        //add any bands without shows to the bottom of the list
        for bandName in allBands {
            if (presentCheck.contains(bandName) == false){
                if (applyFilters(bandName: bandName,timeIndex: 0, schedule: schedule, dataHandle: dataHandle) == true){
                    print("Adding!! bandName  " + bandName)
                    newAllBands.append(bandName);
                    presentCheck.append(bandName);
                }
            }
        }
    }
    
    return newAllBands
}

func applyFilters(bandName:String, timeIndex:TimeInterval, schedule: scheduleHandler, dataHandle: dataHandler)-> Bool{
    
    var include = false;
    
    if (timeIndex.isZero == false){
        
        if (willAttenedFilters(bandName: bandName,timeIndex: timeIndex, schedule: schedule) == true){
            attendingCount = attendingCount + 1;
            print ("attendingCount is \(attendingCount) after adding 1")
        }
        
        if (getShowOnlyWillAttened() == true){
            include = willAttenedFilters(bandName: bandName,timeIndex: timeIndex, schedule: schedule);
        
        } else {
            if (schedule.getBandSortedSchedulingData()[bandName]!.isEmpty == true ||
            schedule.getBandSortedSchedulingData()[bandName]![timeIndex]!.isEmpty == true ||
                schedule.getBandSortedSchedulingData()[bandName]![timeIndex]![typeField]!.isEmpty == true){
                return false;
            }
            
            let eventType = schedule.getBandSortedSchedulingData()[bandName]![timeIndex]![typeField]!
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

func getFilteredBands(bandNameHandle: bandNamesHandler, schedule: scheduleHandler, dataHandle: dataHandler) -> [String] {

    let allBands = bandNameHandle.getBandNames()

    var sortedBy = getSortedBy()
    
    //set default if empty
    if (sortedBy.isEmpty == true){
        sortedBy = "time"
    }
    
    var filteredBands = [String]()
    
    var newAllBands = [String]()
    
    newAllBands = determineBandOrScheduleList(allBands, sortedBy: sortedBy, schedule: schedule, dataHandle: dataHandle);
    
    if (getShowOnlyWillAttened() == true){
        filteredBands = newAllBands;
        
    } else {
        for bandNameIndex in newAllBands {
            
            let bandName = getNameFromSortable(bandNameIndex, sortedBy: sortedBy);
            
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
    
    } else if (getMightSeeOn() == false && dataHandle.getPriorityData(bandName) == 2){
        showBand = false
        
    } else if (getWontSeeOn() == false && dataHandle.getPriorityData(bandName) == 3){
        showBand = false
        
    } else if (getUnknownSeeOn() == false && dataHandle.getPriorityData(bandName) == 0){
        showBand = false
    
    }
    
    return showBand

}

func willAttenedFilters(bandName: String, timeIndex:TimeInterval, schedule: scheduleHandler) -> Bool{

    let attendedHandler = ShowsAttended()

    var showEvent = true;

    let eventType = schedule.getBandSortedSchedulingData()[bandName]![timeIndex]![typeField]!
    let location = schedule.getBandSortedSchedulingData()[bandName]![timeIndex]![locationField]!
    let startTime = schedule.getBandSortedSchedulingData()[bandName]![timeIndex]![startTimeField]!

    if (timeIndex.isZero){
        showEvent = false
    
    } else {
        let status = attendedHandler.getShowAttendedStatus(band: bandName, location: location, startTime: startTime, eventType: eventType,eventYearString: String(eventYear))

        if (status == sawNoneStatus){
            showEvent = false
        }
    }

    return showEvent;
}

func eventTypeFiltering(_ eventType: String) -> Bool{
    
    var showEvent = false;
    
    let showSpecialValue = defaults.bool(forKey: "showSpecial")
    let showMandGValue = defaults.bool(forKey: "showMandG")
    let showClinicsValue = defaults.bool(forKey: "showClinics")
    let showListeningValue = defaults.bool(forKey: "showListening")
    let showUnofficalValue = defaults.bool(forKey: "showUnofficalEvents")
    
    if (eventType == specialEventType && showSpecialValue == true){
        showEvent = true;
    
    } else if (eventType == meetAndGreetype && showMandGValue == true){
        showEvent = true;
    
    } else if (eventType == clinicType && showClinicsValue == true){
        showEvent = true;

    } else if (eventType == listeningPartyType && showListeningValue == true){
        showEvent = true;
        
    } else if ((eventType == unofficalEventType || eventType == unofficalEventTypeOld) && showUnofficalValue == true){
        showEvent = true;
    
    } else if (eventType == showType){
       showEvent = true;

    }
    
    return showEvent
}

func venueFiltering(_ venue: String) -> Bool {
    
    print ("filtering venue is " + venue)
    let showPoolShows = defaults.bool(forKey: "showPoolShows")
    let showTheaterShows = defaults.bool(forKey: "showTheaterShows")
    let showRinkShows = defaults.bool(forKey: "showRinkShows")
    let showLoungeShows = defaults.bool(forKey: "showLoungeShows")
    let showOtherShows = defaults.bool(forKey: "showOtherShows")
    
    var showVenue = false;
    
    if (venue == poolVenueText && showPoolShows == true){
        showVenue = true
    
    } else if (venue == theaterVenueText && showTheaterShows == true){
        showVenue = true

    } else if (venue == rinkVenueText && showRinkShows == true){
        showVenue = true
        
    } else if (venue == loungeVenueText && showLoungeShows == true){
        showVenue = true
        
    } else if (venue != loungeVenueText && venue != rinkVenueText && venue != theaterVenueText && venue != poolVenueText && showOtherShows == true){
        showVenue = true
    }
    
    return showVenue
}

func getCellValue (_ indexRow: Int, schedule: scheduleHandler, sortBy: String, cell: UITableViewCell, dataHandle: dataHandler){
    
    let attendedHandler = ShowsAttended()
    var rankLocationSchedule = false
    
    //index is out of bounds. Don't allow this
    if (bands.count < indexRow || bands.count == 0){
        return
    }
    
    print ("bands[indexRow] = \(bands[indexRow])")
    //let indexString = bands[indexRow].components(separatedBy: ":")
    
    let bandName = getNameFromSortable(bands[indexRow], sortedBy: sortBy);
    let timeIndex = getTimeFromSortable(bands[indexRow], sortBy: sortBy);
    
    //var bandText = String()
    var dayText = String()
    var locationText = String()
    var timeText = String()
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
    let timeView = cell.viewWithTag(8) as! UILabel
    let dayLabelView = cell.viewWithTag(9) as! UILabel
    let dayView = cell.viewWithTag(10) as! UILabel
    let spacerView = cell.viewWithTag(11) as! UILabel
    let locationColor = cell.viewWithTag(12) as! UILabel

    indexForCell.isHidden = true
    bandNameView.textColor = UIColor.white
    locationView.textColor = UIColor.white
    timeView.textColor = UIColor.white
    dayView.textColor = UIColor.white
    
    bandNameView.text = bandName
    
    indexText = bandName
    
    cell.backgroundColor = UIColor.black;
    cell.textLabel?.textColor = UIColor.white
    
    if (timeIndex > 1){
        
        hasScheduleData = true
        
        locationView.isHidden = false
        timeView.isHidden = false
        spacerView.isHidden = false
        dayView.isHidden = false
        dayLabelView.isHidden = false
        attendedView.isHidden = false
        locationColor.isHidden = false
        eventTypeImageView.isHidden = false

        let location = schedule.getData(bandName, index:timeIndex, variable: locationField)
        let day = schedule.getData(bandName, index: timeIndex, variable: dayField)
        let startTime = schedule.getData(bandName, index: timeIndex, variable: startTimeField)
        let event = schedule.getData(bandName, index: timeIndex, variable: typeField)
        let eventIcon = getEventTypeIcon(event)
        
        locationColor.backgroundColor = getVenueColor(venue: location);
        
        indexText += ";" + location + ";" + event + ";" + startTime
        
        if (listOfVenues.contains(location) == false){
            print ("Adding location " + location)
            listOfVenues.append(location)
        }
        
        print(bandName + " displaying timeIndex of \(timeIndex) ")
        timeText = formatTimeValue(timeValue: startTime)
        locationText = location;
        
        if (venueLocation[location] != nil){
            locationText += " " + venueLocation[location]!
        }
        
        scheduleText = bandName + ":" + timeText + ":" + locationText
        scheduleButton = false
    
        print("scheduleText  = \(scheduleText)")
        let icon = attendedHandler.getShowAttendedIcon(band: bandName,location: location,startTime: startTime,eventType: event,eventYearString: String(eventYear));
    
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
        dayLabelView.text = "Day"
        locationView.text = locationText
        timeView.text = timeText
        
        
        rankLocationSchedule = true

    } else {
        rankLocationSchedule = false
        print ("Not display schedule for band " + bandName)
        scheduleButton = true
        locationView.isHidden = true
        timeView.isHidden = true
        spacerView.isHidden = true
        dayView.isHidden = true
        dayLabelView.isHidden = true
        attendedView.isHidden = true
        locationColor.isHidden = true
        eventTypeImageView.isHidden = true
    }
    
    indexForCell.text = indexText;
    
    print ("Cell text for \(bandName) ranking is \(dataHandle.getPriorityData(bandName))")
    rankGraphic = UIImageView(image:UIImage(named: getPriorityGraphic(dataHandle.getPriorityData(bandName))))

    if (rankGraphic.image != nil){
        if (rankLocationSchedule == true){
            rankImageView.isHidden = false
            rankImageViewNoSchedule.isHidden = true
            rankImageView.image = rankGraphic.image
            spacerView.isHidden = false
        } else {
            rankImageView.isHidden = true
            rankImageViewNoSchedule.isHidden = false
            rankImageViewNoSchedule.image = rankGraphic.image
            spacerView.isHidden = true
        }
    } else {
        rankImageView.isHidden = true
        rankImageViewNoSchedule.isHidden = true
    }
}




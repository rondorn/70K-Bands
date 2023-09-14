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

var hasAttendedEvents = false
var attendingCount = 0;

var showOnlyWillAttened = false;

var sortedBy = String();
var bandCount = Int();
var eventCount = Int();

var previousBandName = String();

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

func determineBandOrScheduleList (_ allBands:[String], sortedBy: String, schedule: scheduleHandler, dataHandle: dataHandler, attendedHandle: ShowsAttended) -> [String]{
    
    var newAllBands = [String]()
    
    var presentCheck = [String]();
    listOfVenues = ["All"]
    attendingCount = 0
    unofficalEventCount = 0
    if (typeField.isEmpty == true){
        return allBands;
    }
    
    print ("Locking object with newAllBands")
    eventCounter = 0
    eventCounterUnoffical = 0
    
    print ("sortedBy = \(sortedBy)")
    schedule.buildTimeSortedSchedulingData();
    print (schedule.getTimeSortedSchedulingData());
    if (schedule.getBandSortedSchedulingData().count > 0 && sortedBy == "name"){
        print ("Sorting by name!!!");
        for bandName in schedule.getBandSortedSchedulingData().keys {
            unfilteredBandCount = unfilteredBandCount + 1
            if (schedule.getBandSortedSchedulingData().isEmpty == false){
                for timeIndex in schedule.getBandSortedSchedulingData()[bandName]!.keys {
                    if (timeIndex > Date().timeIntervalSince1970 - 3600  || defaults.bool(forKey: "hideExpireScheduleData") == false){
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
            if (schedule.getTimeSortedSchedulingData()[timeIndex]?.isEmpty == false){
                for bandName in (schedule.getTimeSortedSchedulingData()[timeIndex]?.keys)!{
                    unfilteredBandCount = unfilteredBandCount + 1
                    if (timeIndex > Date().timeIntervalSince1970 - 3600 || defaults.bool(forKey: "hideExpireScheduleData") == false){
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
        setShowOnlyWillAttened(false);
        newAllBands = determineBandOrScheduleList(allBands, sortedBy: sortedBy, schedule: schedule, dataHandle: dataHandle, attendedHandle: attendedHandle)
    }
    
    if (schedule.getTimeSortedSchedulingData().count > 2){
        //add any bands without shows to the bottom of the list
        bandCounter = 0
        for bandName in allBands {
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

func getFilteredBands(bandNameHandle: bandNamesHandler, schedule: scheduleHandler, dataHandle: dataHandler, attendedHandle: ShowsAttended) -> [String] {
    
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
            
        } else {
            for bandNameIndex in newAllBands {
                unfilteredBandCount = unfilteredBandCount + 1
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
        isGetFilteredBands = false;
    }
    filteredBandCount = filteredBands.count

    if (filteredBandCount == 0){
        filteredBands = handleEmptryList(bandNameHandle: bandNameHandle);
    }
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
    
    let showSpecialValue = defaults.bool(forKey: "showSpecial")
    let showMandGValue = defaults.bool(forKey: "showMandG")
    let showClinicsValue = defaults.bool(forKey: "showClinics")
    let showListeningValue = defaults.bool(forKey: "showListening")
    let showUnofficalValue = defaults.bool(forKey: "showUnofficalEvents")
    
    if (eventType == specialEventType && showSpecialValue == true){
        showEvent = true;
 
    } else if (eventType == karaokeEventType && showSpecialValue == true){
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

func getCellValue (_ indexRow: Int, schedule: scheduleHandler, sortBy: String, cell: UITableViewCell, dataHandle: dataHandler, attendedHandle: ShowsAttended){
    
    var rankLocationSchedule = false
    
    //index is out of bounds. Don't allow this
    if (bands.count < indexRow || bands.count == 0){
        return
    }
    print ("bands = \(bands)")
    print ("indexRow = \(indexRow)")
    
    //print ("bands[indexRow] = \(bands[indexRow])")

    let bandName = getNameFromSortable(bands[indexRow], sortedBy: sortBy);
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
    endTimeView.textColor = UIColor.darkGray
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
        
                
        indexText += ";" + location + ";" + event + ";" + startTime
        
        if (listOfVenues.contains(location) == false){
            print ("Adding location " + location)
            listOfVenues.append(location)
        }
        
        print(bandName + " displaying timeIndex of \(timeIndex) ")
        startTimeText = formatTimeValue(timeValue: startTime)
        endTimeText = formatTimeValue(timeValue: endTime)
        locationText = location;
        
        if (venueLocation[location] != nil){
            locationText += " " + venueLocation[location]!
        }
        
        scheduleText = bandName + ":" + startTimeText + ":" + locationText
        scheduleButton = false
    
        print("scheduleText  = \(scheduleText)")
        print ("Icon parms \(bandName) \(location) \(startTime) \(event)")
        let icon = attendedHandle.getShowAttendedIcon(band: bandName,location: location,startTime: startTime,eventType: event,eventYearString: String(eventYear));
    
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
        
        if (bandName == previousBandName && sortBy == "name"){
            
            var locationString = "  " + location
            var venueString = NSMutableAttributedString(string: locationString)
            var locationColor = getVenueColor(venue: location)
            venueString.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 22), range: NSRange(location:1,length:1))
            venueString.addAttribute(NSAttributedString.Key.backgroundColor, value: locationColor, range: NSRange(location:1,length:1))
            venueString.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 17), range: NSRange(location:1,length: location.count))
            venueString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.lightGray, range: NSRange(location:2,length: location.count))
            
            var locationOfVenue = "  " + (venueLocation[location] ?? "") ?? ""
            var locationOfVenueString = NSMutableAttributedString(string: locationOfVenue)
            locationOfVenueString.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 20), range: NSRange(location:1,length:1))
            locationOfVenueString.addAttribute(NSAttributedString.Key.backgroundColor, value: locationColor, range: NSRange(location:1,length:1))
            locationOfVenueString.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 18), range: NSRange(location:1,length: (locationOfVenue.count - 1)))
            locationOfVenueString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.lightGray, range: NSRange(location:2,length: (locationOfVenue.count - 2)))
            
            bandNameView.attributedText = venueString
            bandNameView.isHidden = false;
            bandNameNoSchedule.text = bandName
            locationView.attributedText = locationOfVenueString
            
            bandNameNoSchedule.isHidden = true
 
        } else {

            var locationString = "  " + locationText
            var myMutableString = NSMutableAttributedString(string: locationString)
            var locationColor = getVenueColor(venue: location)
            myMutableString.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 20), range: NSRange(location: 1,length:1))
            myMutableString.addAttribute(NSAttributedString.Key.backgroundColor, value: locationColor, range: NSRange(location:1,length:1))
            myMutableString.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 18), range: NSRange(location:1,length: locationText.count))
            myMutableString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.lightGray, range: NSRange(location:1,length: locationText.count))

            bandNameView.backgroundColor = UIColor.black;
            locationView.attributedText = myMutableString
            bandNameView.isHidden = false
            bandNameNoSchedule.isHidden = true
            bandNameNoSchedule.text = ""
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
}




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

    func determineBandOrScheduleList (_ allBands:[String], schedule: scheduleHandler, sortedBy: String) -> [String]{
    
        
        var newAllBands = [String]()
        var presentCheck = [String]();
        listOfVenues = ["All"]
        
        if (typeField.isEmpty == true){
            return allBands;
        }
        
        schedule.buildTimeSortedSchedulingData();
        print (schedule.getTimeSortedSchedulingData());
        if (schedule.getBandSortedSchedulingData().count > 0 && sortedBy == "name"){
            print ("Sorting by name!!!");
            for bandName in schedule.getBandSortedSchedulingData().keys {
                for timeIndex in schedule.getBandSortedSchedulingData()[bandName]!.keys{
                    if (timeIndex > Date().timeIntervalSince1970 - 3600){
                        totalUpcomingEvents += 1;
                        if (schedule.getBandSortedSchedulingData()[bandName]![timeIndex]![typeField] != nil){
                            if (eventTypeFiltering(schedule.getBandSortedSchedulingData()[bandName]![timeIndex]![typeField]!) == true){
                                if (venueFiltering((schedule.getBandSortedSchedulingData()[bandName]?[timeIndex]![locationField]!)!) == true){
                                    if (rankFiltering(bandName) == true){
                                        newAllBands.append(bandName + ":" + String(timeIndex));
                                        presentCheck.append(bandName);
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
                        if (timeIndex > Date().timeIntervalSince1970 - 3600){
                            totalUpcomingEvents += 1;
                            if (schedule.getBandSortedSchedulingData()[bandName]?[timeIndex]?[typeField]?.isEmpty == false){
                                if (eventTypeFiltering(schedule.getBandSortedSchedulingData()[bandName]![timeIndex]![typeField]!) == true){
                                    if (venueFiltering(schedule.getBandSortedSchedulingData()[bandName]![timeIndex]![locationField]!) == true){
                                        if (rankFiltering(bandName) == true){
                                            newAllBands.append(String(timeIndex) + ":" + bandName);
                                            presentCheck.append(bandName);
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    newAllBands = determineBandOrScheduleList(allBands, schedule: schedule, sortedBy: sortedBy)
                }
            }
            bandCount = 0;
            eventCount = newAllBands.count;
        } else {
            
            //return immediatly. Dont need to do schedule sorting magic
            newAllBands = allBands;
            newAllBands.sort();
            bandCount = newAllBands.count;
            eventCount = 0;
            
            return newAllBands
        }
 
        newAllBands.sort();
        
        if (schedule.getTimeSortedSchedulingData().count > 2){
            //add any bands without shows to the bottom of the list
            for bandName in allBands {
                if (presentCheck.contains(bandName) == false){
                    print("Adding!! bandName  " + bandName)
                    newAllBands.append(bandName);
                    presentCheck.append(bandName);
                }
            }
        }
        
        return newAllBands
    }

    func getFilteredBands(_ allBands:[String], schedule: scheduleHandler, sortedBy: String) -> [String] {
        
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

    func rankFiltering(_ bandName: String) -> Bool {
        
        var showBand = true;
        
        if (getMustSeeOn() == false && getPriorityData(bandName) == 1){
            showBand = false
        
        } else if (getMightSeeOn() == false && getPriorityData(bandName) == 2){
            showBand = false
            
        } else if (getWontSeeOn() == false && getPriorityData(bandName) == 3){
            showBand = false
            
        } else if (getUnknownSeeOn() == false && getPriorityData(bandName) == 0){
            showBand = false
        
        }
        
        return showBand
    
    }

    func eventTypeFiltering(_ eventType: String) -> Bool{
        
        var showEvent = false;
        
        let showSpecialValue = defaults.bool(forKey: "showSpecial")
        let showMandGValue = defaults.bool(forKey: "showMandG")
        let showClinicsValue = defaults.bool(forKey: "showClinics")
        let showListeningValue = defaults.bool(forKey: "showListening")
        
        if (eventType == specialEventType && showSpecialValue == true){
            showEvent = true;
        
        } else if (eventType == meetAndGreetype && showMandGValue == true){
            showEvent = true;
        
        } else if (eventType == clinicType && showClinicsValue == true){
            showEvent = true;
        
        } else if (eventType == listeningPartyType && showListeningValue == true){
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

func getCellValue (_ indexRow: Int, schedule: scheduleHandler, sortBy: String) -> String{
        
        //index is out of bounds. Don't allow this
        if (bands.count < indexRow || bands.count == 0){
            return ""
        }
        
        let indexString = bands[indexRow].components(separatedBy: ":")
        
        let bandName = getNameFromSortable(bands[indexRow], sortedBy: sortBy);
        let timeIndex = getTimeFromSortable(bands[indexRow], sortBy: sortBy);
        
        var cellText = String()
    
        if (getPriorityData(bandName) == 0){
            cellText = bandName
        } else {
            cellText = getPriorityIcon(getPriorityData(bandName)) + " - " + bandName
        }
        
        if (indexString.count > 1){
            
            hasScheduleData = true
            let location = schedule.getData(bandName, index:timeIndex, variable: locationField)
            let day = schedule.getData(bandName, index: timeIndex, variable: dayField)
            let startTime = schedule.getData(bandName, index: timeIndex, variable: startTimeField)
            let event = schedule.getData(bandName, index: timeIndex, variable: typeField)
            let eventIcon = getEventTypeIcon(event)
        
            if (listOfVenues.contains(location) == false){
                print ("Adding location " + location)
                listOfVenues.append(location)
            }
            
            print(bandName + " displaying timeIndex of \(timeIndex) ")
            cellText += " - " + formatTimeValue(timeValue: startTime)
            cellText += " " + location + " - " + day + " " + eventIcon;
            scheduleButton = false
            
            let icon = attendedHandler.getShowAttendedIcon(band: bandName,location: location,startTime: startTime,eventType: event);
            
            cellText = icon + cellText
            
            scheduleIndexByCall[cellText] = [String:String]()
            scheduleIndexByCall[cellText]!["location"] = location
            scheduleIndexByCall[cellText]!["bandName"] = bandName
            scheduleIndexByCall[cellText]!["startTime"] = startTime
            scheduleIndexByCall[cellText]!["event"] = event

        } else {
            print ("Not display schedule for band " + bandName)
            scheduleButton = true
        }
        
        return cellText
    }




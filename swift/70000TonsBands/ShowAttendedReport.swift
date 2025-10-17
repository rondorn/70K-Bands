//
//  ShowAttendedReport.swift
//  70K Bands
//
//  Created by Ron Dorn on 6/12/18.
//  Copyright © 2018 Ron Dorn. All rights reserved.
//

import Foundation

class showAttendenceReport {
    
    var eventCounts :[String:[String:Int]] = [String:[String:Int]]()
    var bandCounts : [String : [String : [String : Int]]] = [String : [String : [String : Int]]]()
    
    var schedule = scheduleHandler.shared
    var attendedHandle = ShowsAttended()
    
    var bandNamesHandle = bandNamesHandler.shared
    var dataHandle = dataHandler()
    
    var isReportEmpty = false
    var indexMap = [String]()
    
    /**
     Initializes a new instance of showAttendenceReport.
     */
    init(){

    }
    
    /**
     Returns whether the report is empty.
     - Returns: true if the report is empty, false otherwise.
     */
    func getIsReportEmpty()->Bool {
        return isReportEmpty
    }
    
    /**
     Assembles the attendance report by processing attended shows and events.
     */
    func assembleReport (){
        
        schedule.buildTimeSortedSchedulingData();
        
        let scheduleData = schedule.getBandSortedSchedulingData();
        let showsAttendedArray = attendedHandle.getShowsAttended();
        let allBands = bandNamesHandle.getBandNames()
        var unuiqueSpecial = [String]()
        
        var tempEventCount = 0
        
        if (schedule.getBandSortedSchedulingData().count > 0){
            for index in showsAttendedArray {
                
                //prevent duplicate events
                if (indexMap.contains(index.key)){
                    continue
                }
                indexMap.append(index.key)
                
                let indexArray = index.key.split(separator: ":")
                
                guard indexArray.count >= 6 else {
                    continue
                }
                
                let bandName = String(indexArray[0])
                let location = String(indexArray[1])
                let hour = String(indexArray[2])
                let min = String(indexArray[3])
                let eventType = String(indexArray[4])
                let year = String(indexArray[5])
                let status = String(showsAttendedArray[index.key]!)
                
                if (year != String(eventYear)){
                    continue
                }
                if (status == "sawNone"){
                    continue
                }
                
                // Extract just the status without timestamp
                let statusOnly = String(status.split(separator: ":")[0])
                
                var validateEvent = false
                if scheduleData.index(forKey: bandName) != nil {
                    validateEvent = true
                }
                
                if validateEvent {
                    // Do additional time-based validation
                    var timeValidated = false
                    for timeIndex in scheduleData[bandName]!.keys {
                        if (scheduleData[bandName]?[timeIndex]?["Location"] == location &&
                            scheduleData[bandName]?[timeIndex]?["Type"] == eventType &&
                            scheduleData[bandName]?[timeIndex]?["Start Time"] == hour + ":" + min){
                            timeValidated = true
                            break
                        }
                    }
                    
                    if timeValidated {
                        getEventTypeCounts(eventType: eventType, sawStatus: statusOnly)
                        getBandCounts(eventType: eventType, bandName: bandName, sawStatus: statusOnly)
                        tempEventCount += 1
                    } else {
                        continue
                    }
                } else {
                    continue
                }
                
                // Additional band validation (for special events not in main band list)
                if (allBands.contains(bandName) == false &&
                    eventType != unofficalEventType &&
                    eventType != karaokeEventType &&
                    eventType != specialEventType &&
                    eventType != unofficalEventTypeOld){

                    print("ShareDebug: Band '\(bandName)' not in main band list and not a special event type - skipping")
                    continue
                }
                
                // This validation and counting is already handled above in the new debug code
                // No need to duplicate the processing here
                
            }
        } else {
            isReportEmpty = true
        }
        if (tempEventCount == 0){
            isReportEmpty = true
        }

    }
    
    /**
     Adds a plural 's' to the event type if the count is 2 or more (except for unofficial events).
     - Parameters:
        - count: The number of events.
        - eventType: The type of event.
     - Returns: A string with the appropriate pluralization.
     */
    func addPlural(count : Int, eventType: String)->String{
        
        var message = "";
        
        if (count >= 2 && eventType != unofficalEventType){
            message += "s"
        }
        message += "\n"
        
        return message
    }
        
    /**
     Builds a report message for the specified type.
     - Parameter type: The type of report to build (e.g., "MustMight", "Events").
     - Returns: The formatted report message as a string.
     */
    func buildMessage(type: String)->String{
        
        var message = ""
        
        if (type == "MustMight"){
            message = buildMustMightReport();
            
        } else if (type == "Events"){
            message = buildEventsAttendedReport()
        }
        
        print ("shows attended message = \(message)")
        
        return message
    }
    
    /**
     Builds a report message for the 'MustMight' type, listing must-see and might-see bands.
     - Returns: The formatted must/might report as a string.
     */
    func buildMustMightReport()->String {
        
        var intro = "🤘 " + NSLocalizedString("HereAreMy", comment: "") + " " + FestivalConfig.current.appName + " " + NSLocalizedString("Choices", comment: "") + "\n\n"
        var mustSeeBands: [String] = []
        var mightSeeBands: [String] = []
        
        let bands = bandNamesHandle.getBandNames()
        
        // Collect must-see bands
        for band in bands {
            let priorityManager = PriorityManager()
            if (priorityManager.getPriority(for: band) == 1){
                print ("Adding band " + band)
                mustSeeBands.append(band)
            }
        }
        
        // Collect might-see bands
        for band in bands {
            let priorityManager = PriorityManager()
            if (priorityManager.getPriority(for: band) == 2){
                print ("Adding band " + band)
                mightSeeBands.append(band)
            }
        }
        
        // Format must-see section with localized text
        intro += "🟢 " + NSLocalizedString("MustSeeBands", comment: "") + " (\(mustSeeBands.count)):\n"
        if !mustSeeBands.isEmpty {
            let formattedMustSee = mustSeeBands.map { "• \($0)" }.joined(separator: " ")
            intro += formattedMustSee + "\n"
        }
        
        intro += "\n🟡 " + NSLocalizedString("MightSeeBands", comment: "") + " (\(mightSeeBands.count)):\n"
        if !mightSeeBands.isEmpty {
            let formattedMightSee = mightSeeBands.map { "• \($0)" }.joined(separator: " ")
            intro += formattedMightSee + "\n"
        }
        
        intro += "\n\n" + FestivalConfig.current.shareUrl
         return intro
    }
    
    /**
     Builds an enhanced events attended report with venue information and emojis.
     - Returns: The formatted events attended report as a string.
     */
    func buildEventsAttendedReport() -> String {
        var message = "🤘 " + NSLocalizedString("HereAreMy", comment: "") + " " + FestivalConfig.current.appName + " - " + NSLocalizedString("EventsAttended", comment: "") + "\n\n"
        
        
        assembleReport()
        
        print("ShareDebug: After assembleReport - eventCounts: \(eventCounts)")
        print("ShareDebug: After assembleReport - bandCounts: \(bandCounts)")
        print("ShareDebug: After assembleReport - isReportEmpty: \(isReportEmpty)")
        
        // Define event type order and emojis
        let eventTypeOrder = ["Show", "Meet and Greet", "Clinic", "Special Event", "Cruiser Organized", "Unofficial Event"]
        let eventTypeEmojis = [
            "Show": "🎵",
            "Meet and Greet": "🤝", 
            "Clinic": "🎸",
            "Special Event": "🎪",
            "Cruiser Organized": "🚢",
            "Unofficial Event": "🔥"
        ]
        let eventTypeLabels = [
            "Show": NSLocalizedString("ShowsPlural", comment: ""),
            "Meet and Greet": NSLocalizedString("MeetAndGreetsPlural", comment: ""),
            "Clinic": NSLocalizedString("ClinicsPlural", comment: ""), 
            "Special Event": NSLocalizedString("SpecialEventsPlural", comment: ""),
            "Cruiser Organized": NSLocalizedString("CruiseEventsPlural", comment: ""),
            "Unofficial Event": NSLocalizedString("UnofficialEventsPlural", comment: "")
        ]
        
        // Process each event type in order
        for eventType in eventTypeOrder {
            guard let eventTypeData = bandCounts[eventType],
                  !eventTypeData.isEmpty else { continue }
            
            let emoji = eventTypeEmojis[eventType] ?? "🎯"
            let label = eventTypeLabels[eventType] ?? eventType
            let totalCount = calculateTotalEventsForType(eventType: eventType)
            
            if totalCount > 0 {
                message += "\(emoji) \(label) (\(totalCount)):\n"
                
                // Get all bands/events for this type with venue info
                var eventEntries: [String] = []
                let sortedBandNames = Array(eventTypeData.keys).sorted()
                
                for bandName in sortedBandNames {
                    if let bandData = eventTypeData[bandName],
                       let sawAllCount = bandData[sawAllStatus],
                       sawAllCount > 0 {
                        
                        // Get venue info for this band/event
                        let venue = getVenueForBandEvent(bandName: bandName, eventType: eventType)
                        let venueInfo = venue.isEmpty ? "" : " (\(venue))"
                        
                        eventEntries.append("• \(bandName)\(venueInfo)")
                    }
                }
                
                // Join entries with bullet separation for compact display
                if !eventEntries.isEmpty {
                    message += eventEntries.joined(separator: " ") + "\n\n"
                }
            }
        }
        
        message += "\n\n" + FestivalConfig.current.shareUrl
        return message
    }
    
    /**
     Calculates the total number of events attended for a specific event type.
     - Parameter eventType: The event type to count.
     - Returns: Total count of events attended for this type.
     */
    private func calculateTotalEventsForType(eventType: String) -> Int {
        guard let eventTypeData = bandCounts[eventType] else { return 0 }
        
        var total = 0
        for (_, bandData) in eventTypeData {
            if let sawAllCount = bandData[sawAllStatus] {
                total += sawAllCount
            }
            if let sawSomeCount = bandData[sawSomeStatus] {
                total += sawSomeCount
            }
        }
        return total
    }
    
    /**
     Gets the venue information for a specific band/event.
     - Parameters:
     - bandName: The name of the band or event.
     - eventType: The type of event.
     - Returns: The venue name, or empty string if not found.
     */
    private func getVenueForBandEvent(bandName: String, eventType: String) -> String {
        let scheduleData = schedule.getBandSortedSchedulingData()
        
        guard let bandSchedule = scheduleData[bandName] else { return "" }
        
        // Look for matching event type and return the location
        for (_, eventData) in bandSchedule {
            if let location = eventData["Location"],
               let type = eventData["Type"],
               type == eventType {
                return location
            }
        }
        
        return ""
    }
    
    /**
     Updates the eventCounts dictionary with the count of events by type and attendance status.
     - Parameters:
        - eventType: The type of event.
        - sawStatus: The attendance status for the event.
     */
    func getEventTypeCounts (eventType:String, sawStatus: String){
        
        if (eventCounts[eventType] == nil){
            eventCounts[eventType] = [String:Int]()
        }
        
        if (eventCounts[eventType]![sawStatus] == nil){
            eventCounts[eventType]![sawStatus] = 1;
        } else {
            eventCounts[eventType]![sawStatus] = eventCounts[eventType]![sawStatus]! + 1
        }
    }
    
    /**
     Updates the bandCounts dictionary with the count of bands by event type and attendance status.
     - Parameters:
        - eventType: The type of event.
        - bandName: The name of the band.
        - sawStatus: The attendance status for the band.
     */
    func getBandCounts (eventType:String, bandName:String, sawStatus: String){
        
        if (bandCounts[eventType] == nil){
            bandCounts[eventType] = [String : [String : Int]]();
        }
        if (bandCounts[eventType]![bandName] == nil){
            bandCounts[eventType]![bandName]  = [String : Int]();
        }
        if (bandCounts[eventType]![bandName]![sawStatus] == nil){
            bandCounts[eventType]![bandName]![sawStatus] = 1;
        } else {
            bandCounts[eventType]![bandName]![sawStatus] = bandCounts[eventType]![bandName]![sawStatus]! + 1
        }
    }
}


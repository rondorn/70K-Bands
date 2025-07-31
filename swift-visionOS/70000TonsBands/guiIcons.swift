//
//  guiIcons.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/13/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import UIKit

let mustSeeIconFilterTag = 20
let mightSeeIconFilterTag = 21
let wontSeeIconFilterTag = 22
let unknownIconFilterTag = 23

let showTypeIcon = "";

let scheduleIconSort = "icon-sort-time-decending"
let bandIconSort = "icon-sort-az-decending"

//shows attended
let sawAllIcon = "icon-seen"
let sawSomeIcon = "icon-partially-seen"
let sawNoneIcon = ""
let attendedShowIcon = "icon-seen"
let attendedShowIconAlt = "icon-seen-alt"

let specialEventIconSmall = "icon-all-star-jam";
let meetAndGreetIconSmall = "icon-meet-and-greet";
let listeningEventTypeIconSmall = "icon-all-star-jam";
let clinicEventIconSmall = "icon-clinc-v1";
let unofficalEventIconSmall = "icon-Events-Unoffical";
let karaokeIconSmall = "icon-karaoke"
let shipBoadEventTypeIconSmall = "icon-ship-event";

let specialEventTypeIcon = "All-Star-Jam-Select-wBox"
let specialEventTypeIconAlt = "All-Star-Jam-DeSelect-wBox"

let clinicEventTypeIcon = "Clinc-v2-Select-wBox"
let clinicEventTypeIconAlt = "Clinc-v2-SDeelect-wBox"

let unofficalEventTypeIcon = "Generic-Event-v1-Select-wBox"
let unofficalEventTypeIconAlt = "Generic-Event-v1-DeSelect-wBox"

let karaokeIcon = "Karaoke-Select-wBox"
let karaokeIconAlt = "Karaoke-DeSelect-wBox"

let meetAndGreetIcon = "Meet-And-Greet-full-Select-wBox"
let meetAndGreetIconAlt = "Meet-And-Greet-full-DeSelect-wBox"

let generalEvent = "Ship-Event-Select-wBox"
let generalEventAlt = "Ship-Event-DeSelect-wBox"

let mustSeeIconSmall = "icon-going-yes"
let mightSeeIconSmall = "icon-going-maybe"
let wontSeeIconSmall = "icon-going-no"
let unknownIconSmall = "icon-unknown"

let mustSeeIcon = "Going-Devil-Yeah-rev1-Select-wBox"
let mustSeeIconAlt = "Going-Devil-Yeah-rev1-DeSelect-wBox"

let mightSeeIcon = "Maybe-Devil-Meh-rev1-Select-wBox"
let mightSeeIconAlt = "Maybe-Devil-Meh-rev1-DeSelect-wBox"

let wontSeeIcon = "No-way-Devil-Bah-rev2-Select-wBox"
let wontSeeIconAlt = "No-way-Devil-Bah-rev2-DeSelect-wBox"

let unknownIcon = "Unknown-v2-Select-wBox"
let unknownIconAlt = "Unknown-v2-DeSelect-wBox"

let iceRinkIcon = "Ice-Rink-Going-wBox"
let iceRinkIconAlt = "Ice-Rink-NotGoing-wBox"
 
let poolIcon = "Pool-Deck-Going-wBox"
let poolIconAlt = "Pool-Deck-NotGoing-wBox"

let theaterIcon = "Royal-Theater-Going-wBox"
let theaterIconAlt = "Royal-Theater-NotGoing-wBox"

let loungIcon = "Lounge-Going-wBox"
let loungIconAlt = "Lounge-NotGoing-wBox"

let poolVenue = "🏊"
let theaterVenue = "🎭"
let loungeVenue = "🎤"
let rinkVenue = "⛸"
let unknownVenue = "❓"

let poolVenueColor = hexStringToUIColor(hex: "#3885DC")
let theaterVenueColor = hexStringToUIColor(hex: "#F0D905")
let loungeVenueColor = hexStringToUIColor(hex: "#67C10C")
let rinkVenueColor = hexStringToUIColor(hex: "#C10114")
let unknownVenueColor = UIColor.lightGray

func getEventTypeIcon (eventType: String, eventName: String)->UIImage {
    
    var graphicName = String()
    var graphicImage = UIImage()
    
    switch eventType {
    case showType:
        graphicName = showTypeIcon
        
    case meetAndGreetype:
        graphicName = meetAndGreetIconSmall
        
    case specialEventType:
        
        if (eventName == "All Star Jam"){
            graphicName = specialEventIconSmall
            
        } else if (eventName.contains("Karaoke")){
            graphicName = karaokeIconSmall
        
        } else {
            graphicName = shipBoadEventTypeIconSmall;
        }
        
    case clinicType:
        graphicName = clinicEventIconSmall

    case listeningPartyType:
        graphicName = specialEventIconSmall
    
    case unofficalEventType:
        graphicName = unofficalEventIconSmall

    case unofficalEventTypeOld:
        graphicName = unofficalEventIconSmall
        
    case karaokeEventType:
        graphicName = karaokeIconSmall
        
    default:
        graphicName = unknownVenue
    }
    
    graphicImage = UIImage(named: graphicName) ?? UIImage()
    
    return graphicImage
    
}

func getSortButtonImage()->UIImage{
    
    var sortImage:UIImage
    
    print ("scheduleIcon = \(getSortedBy())")
    if (getSortedBy() == "name"){
        sortImage = UIImage(named: scheduleIconSort) ?? UIImage()
        
    } else {
        sortImage = UIImage(named: bandIconSort) ?? UIImage()
    }
    
    return sortImage
}

func getAttendedIcons (attendedStatus: String)->UIImage {
    
    var graphicName = String()
    var graphicImage = UIImage()
    
    switch attendedStatus {
    case sawAllStatus:
        graphicName = "icon-seen"
        
    case sawSomeStatus:
        graphicName = "icon-seen-partial"
        
    case sawNoneStatus:
        graphicName = ""
        
    default:
        graphicName = ""
    }

    print ("Recieved attendedStatus of \(attendedStatus) returned \(graphicName)");
    
    graphicImage = UIImage(named: graphicName) ?? UIImage()
    
    return graphicImage
}

func getRankGuiIcons (rank: String)->UIImage {
   
    var graphicName = String()
    var graphicImage = UIImage()
    
    switch rank {
    case "must":
        graphicName = mustSeeIcon

    case "might":
        graphicName = mightSeeIcon

    case "wont":
        graphicName = wontSeeIcon

    case "unknown":
        graphicName = unknownIcon
        
    case "mustAlt":
        graphicName = mustSeeIconAlt
        
    case "mightAlt":
        graphicName = mightSeeIconAlt
        
    case "wontAlt":
        graphicName = wontSeeIconAlt

    case "unknownAlt":
        graphicName = unknownIconAlt
        
    default:
        graphicName = ""
    }
    
    graphicImage = UIImage(named: graphicName) ?? UIImage()
    
    return graphicImage
    
}

func getVenueColor (venue: String)->UIColor{
    
    var venuColor = UIColor();
    
    switch venue {
        
    case venuePoolKey:
        venuColor = poolVenueColor
        
    case venueTheaterKey:
        venuColor = theaterVenueColor
        
    case venueLoungeKey:
        venuColor = loungeVenueColor
        
    case venueRinkKey:
        venuColor = rinkVenueColor
        
    default:
       venuColor = unknownVenueColor
    }
    
    print ("Returning \(venuColor) for venu of \(venue)")
    return venuColor
}

func getVenuIcon(_ venue: String)->String {
    
    switch venue {
        case "Pool":
            return poolVenue

        case "Theater":
            return theaterVenue

        case "Lounge":
            return loungeVenue
        
        case "Rink":
            return rinkVenue

        default:
            return ""
    }
}

func getPriorityIcon(_ index: Int) -> String {

    switch index {
    case 1:
        return mustSeeIcon
        
    case 2:
        return mightSeeIcon
        
    case 3:
        return wontSeeIcon
        
    default:
        return ""
    }
}

func getPriorityGraphic(_ index: Int) -> String {

    switch index {
    case 1:
        return "icon-going-yes"
        
    case 2:
        return "icon-going-maybe"
        
    case 3:
        return "icon-going-no"
        
    default:
        return ""
    }
}

func getBandIconSort() -> String {
   return bandIconSort
}

func getScheduleIcon() -> String {
    
    if (getSortedBy() == "name"){
        return scheduleIconSort
    
    } else {
        
      return bandIconSort
        
    }
}

func getPoolIcon() -> String {
    return poolVenue
}

func getTheaterIcon() -> String {
    return theaterVenue
}

func getLoungeIcon() -> String {
    return loungeVenue
}

func getRinkIcon() -> String {
    return rinkVenue
}

func getUnknownVenueIcon() -> String {
    return unknownVenue
}

func getMustSeeIcon () -> String {
    return mustSeeIcon
}

func getMightSeeIcon  () -> String {
    return mightSeeIcon
}

func getWillNotSeeIcon  () -> String {
    return wontSeeIcon
}

func getUnknownIcon() -> String {
    return unknownIcon
}

func getPoolVenueIcon() -> String {
    return poolVenue
}

func gettheaterVenueIcon() -> String {
    return theaterVenue
}

func getloungeVenueIcon() -> String {
    return loungeVenue
}

func getrinkVenueIcon() -> String {
    return rinkVenue
}

func getunknownVenueIcon() -> String {
    return unknownVenue
}

func hexStringToUIColor (hex:String) -> UIColor {
    var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    
    if (cString.hasPrefix("#")) {
        cString.remove(at: cString.startIndex)
    }
    
    if ((cString.count) != 6) {
        return UIColor.gray
    }
    
    var rgbValue:UInt32 = 0
    Scanner(string: cString).scanHexInt32(&rgbValue)
    
    return UIColor(
        red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
        green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
        blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
        alpha: CGFloat(1.0)
    )
}

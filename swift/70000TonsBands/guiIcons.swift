//
//  guiIcons.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/13/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation
import UIKit

let mustSeeIcon = "icon-going-yes"
let mightSeeIcon = "icon-going-maybe"
let wontSeeIcon = "icon-going-no"
let unknownIcon = "icon-unknown"

let mustSeeIconFilterTag = 20
let mightSeeIconFilterTag = 21
let wontSeeIconFilterTag = 22
let unknownIconFilterTag = 23

let mustSeeIconAlt = "icon-going-yes-alt"
let mightSeeIconAlt = "icon-going-maybe-alt"
let wontSeeIconAlt = "icon-going-no-alt"
let unknownIconAlt = "icon-unknown-v1-alt"

let scheduleIconSort = "icon-sort-time-decending"
let bandIconSort = "icon-sort-az-decending"

let showTypeIcon = "";
let specialEventTypeIcon = "icon-all-star-jam";
let mAndmEventTypeIcon = "icon-meet-and-greet";
let listeningEventTypeIcon = "icon-all-star-jam";
let clinicEventTypeIcon = "icon-clinc-v1";
let unofficalEventTypeIcon = "icon-unspecified-event";
let karaokeEventTypeIcon = "icon-karaoke"
let shipBoadEventTypeIcon = "icon-ship-event";

//shows attended
let sawAllIcon = "icon-seen"
let sawSomeIcon = "icon-partially-seen"
let sawNoneIcon = ""
let attendedShowIcon = "icon-seen"
let attendedShowIconAlt = "icon-seen-alt"

let poolVenue = "🏊"
let theaterVenue = "🎭"
let loungeVenue = "🎤"
let rinkVenue = "⛸"
let unknownVenue = "❓"

let poolVenueColor = hexStringToUIColor(hex: "#3885DC")
let theaterVenueColor = hexStringToUIColor(hex: "#F0D905")
let loungeVenueColor = hexStringToUIColor(hex: "#67C10C")
let rinkVenueColor = hexStringToUIColor(hex: "#C10114")
let unknownVenueColor = UIColor.darkGray

func getEventTypeIcon (eventType: String, eventName: String)->UIImage {
    
    var graphicName = String()
    var graphicImage = UIImage()
    
    switch eventType {
    case showType:
        graphicName = showTypeIcon
        
    case meetAndGreetype:
        graphicName = mAndmEventTypeIcon
        
    case specialEventType:
        
        if (eventName == "All Star Jam"){
            graphicName = specialEventTypeIcon
            
        } else if (eventName.contains("Karaoke")){
            graphicName = karaokeEventTypeIcon
        
        } else {
            graphicName = shipBoadEventTypeIcon;
        }
        
    case clinicType:
        graphicName = clinicEventTypeIcon

    case listeningPartyType:
        graphicName = listeningEventTypeIcon
    
    case unofficalEventType:
        graphicName = unofficalEventTypeIcon

    case unofficalEventTypeOld:
        graphicName = unofficalEventTypeIcon
        
    case karaokeEventType:
        graphicName = karaokeEventTypeIcon
        
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
        
    case "Pool":
        venuColor = poolVenueColor
        
    case "Theater":
        venuColor = theaterVenueColor
        
    case "Lounge":
        venuColor = loungeVenueColor
        
    case "Rink":
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

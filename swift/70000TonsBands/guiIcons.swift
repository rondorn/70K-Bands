//
//  guiIcons.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/13/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation


let mustSeeIcon = "🍺"
let willSeeIcon = "✅"
let willNotSeeIcon = "🚫"
let unknownIcon = "❓"
let refreshIcon = "🔄"
let scheduleIcon = "⏰"
let poolVenue = "🏊"
let theaterVenue = "🎭"
let loungeVenue = "🎤"
let rinkVenue = "⛸"
let unknownVenue = "❓"
let bandIconSort = "🔠"

let showTypeIcon = "";
let specialEventTypeIcon = "🌟";
let mAndmEventTypeIcon = "📸";
let listeningEventTypeIcon = "💽";
let clinicEventTypeIcon = "🎸";

func getEventTypeIcon (_ eventType: String) -> String {

    switch eventType {
    case showType:
        return showTypeIcon
        
    case meetAndGreetype:
        return mAndmEventTypeIcon
        
    case specialEventType:
        return specialEventTypeIcon
        
    case clinicType:
        return clinicEventTypeIcon

    case listeningPartyType:
        return listeningEventTypeIcon
        
    default:
        return unknownVenue
    }
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
            //exit(1);
            return ""
    }
}

func getPriorityIcon(_ index: Int) -> String {

    switch index {
    case 1:
        return mustSeeIcon
        
    case 2:
        return willSeeIcon
        
    case 3:
        return willNotSeeIcon
        
    default:
        return ""
    }
}

func getBandIconSort() -> String {
   return bandIconSort
}

func getScheduleIcon() -> String {
    return scheduleIcon
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
    return willSeeIcon
}

func getWillNotSeeIcon  () -> String {
    return willNotSeeIcon
}

func getUnknownIcon() -> String {
    return unknownIcon
}

func getRefreshIcon() -> String {
    return refreshIcon
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

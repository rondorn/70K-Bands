//
//  VenueConstants.swift
//  70K Bands
//
//  Created by Refactoring
//  Copyright (c) 2026 Ron Dorn. All rights reserved.
//

import Foundation

/// Venue-related constants and management
struct VenueConstants {
    
    // MARK: - Venue Text Constants
    static let pool = "Pool"
    static let rink = "Rink"
    static let lounge = "Lounge"
    static let theater = "Theater"
    
    // MARK: - Venue Keys
    static let poolKey = "Pool"
    static let theaterKey = "Theater"
    static let loungeKey = "Lounge"
    static let rinkKey = "Rink"
    
    // MARK: - Venue Location Mapping
    private static var _venueLocation: [String: String] = [:]
    private static let venueLocationQueue = DispatchQueue(label: "com.70kbands.venueLocation")
    
    static var venueLocation: [String: String] {
        get { venueLocationQueue.sync { _venueLocation } }
        set { venueLocationQueue.async(flags: .barrier) { _venueLocation = newValue } }
    }
    
    /// Populates the venueLocation dictionary with mappings from venue names to deck locations.
    /// Now uses FestivalConfig instead of hardcoded values.
    static func setupVenueLocations() {
        venueLocationQueue.async(flags: .barrier) {
            _venueLocation.removeAll()
            
            // Populate from FestivalConfig
            let config = FestivalConfig.current
            for venue in config.venues {
                _venueLocation[venue.name] = venue.location
            }
            
            // Legacy compatibility - also add by the old text constants
            _venueLocation[pool] = config.getVenueLocation(for: "Pool")
            _venueLocation[rink] = config.getVenueLocation(for: "Rink")
            _venueLocation[lounge] = config.getVenueLocation(for: "Lounge")
            _venueLocation[theater] = config.getVenueLocation(for: "Theater")
        }
    }
}

// MARK: - Global Accessors (for backward compatibility)
var poolVenueText: String { VenueConstants.pool }
var rinkVenueText: String { VenueConstants.rink }
var loungeVenueText: String { VenueConstants.lounge }
var theaterVenueText: String { VenueConstants.theater }

var venueLocation: [String: String] {
    get { VenueConstants.venueLocation }
    set { VenueConstants.venueLocation = newValue }
}

let venuePoolKey: String = VenueConstants.poolKey
let venueTheaterKey: String = VenueConstants.theaterKey
let venueLoungeKey: String = VenueConstants.loungeKey
let venueRinkKey: String = VenueConstants.rinkKey

func setupVenueLocations() {
    VenueConstants.setupVenueLocations()
}

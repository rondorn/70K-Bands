//
//  VenueConstants.swift
//  70K Bands
//
//  Created by Refactoring
//  Copyright (c) 2026 Ron Dorn. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

/// Color/icon slot assigned dynamically from schedule CSV row order (see VenueColorAssignmentStore).
struct GenericVenueSlot {
    let color: String
    let goingIcon: String
    let notGoingIcon: String

    init(color: String, goingIcon: String, notGoingIcon: String) {
        self.color = color
        self.goingIcon = goingIcon
        self.notGoingIcon = notGoingIcon
    }
}

/// Maps schedule location strings to generic color slots using CSV row order (first unseen → slot 1, etc.).
final class VenueColorAssignmentStore {
    static let shared = VenueColorAssignmentStore()

    private let queue = DispatchQueue(label: "com.70kbands.venueColorAssignment")
    private var slotIndexByLocation: [String: Int] = [:]
    private var loadedYear: Int?

    private init() {}

    private func userDefaultsKey(for year: Int) -> String {
        "venueColorAssignments_\(year)"
    }

    /// Must only be called while already on `queue`.
    private func loadUnlocked(for year: Int) {
        guard loadedYear != year else { return }
        loadedYear = year
        slotIndexByLocation.removeAll()
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey(for: year)),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return
        }
        slotIndexByLocation = decoded
    }

    func load(for year: Int) {
        queue.sync {
            loadUnlocked(for: year)
        }
    }

    func clear(for year: Int) {
        queue.sync {
            slotIndexByLocation.removeAll()
            loadedYear = year
            UserDefaults.standard.removeObject(forKey: userDefaultsKey(for: year))
        }
    }

    /// Rebuild assignments from schedule CSV row order. Skips named venues (exact match). Persists per year.
    func update(locationsInCSVOrder: [String], year: Int) {
        let config = FestivalConfig.current
        var assignments: [String: Int] = [:]
        var seen = Set<String>()
        var nextSlot = 0

        for location in locationsInCSVOrder {
            if config.hasNamedVenue(exactName: location) { continue }
            if seen.contains(location) { continue }
            seen.insert(location)
            guard nextSlot < config.genericVenueSlots.count else { continue }
            assignments[location] = nextSlot
            nextSlot += 1
        }

        queue.sync {
            slotIndexByLocation = assignments
            loadedYear = year
            if let data = try? JSONEncoder().encode(assignments) {
                UserDefaults.standard.set(data, forKey: userDefaultsKey(for: year))
            }
        }
    }

    private func slotIndex(for location: String, year: Int) -> Int? {
        queue.sync {
            if loadedYear != year {
                loadUnlocked(for: year)
            }
            return slotIndexByLocation[location]
        }
    }

    func uiColor(for location: String, year: Int) -> UIColor? {
        guard let index = slotIndex(for: location, year: year),
              index >= 0,
              index < FestivalConfig.current.genericVenueSlots.count else { return nil }
        let hex = FestivalConfig.current.genericVenueSlots[index].color
        return UIColor(hex: hex)
    }

    func swiftUIColor(for location: String, year: Int) -> Color? {
        guard let index = slotIndex(for: location, year: year),
              index >= 0,
              index < FestivalConfig.current.genericVenueSlots.count else { return nil }
        return Color(hex: FestivalConfig.current.genericVenueSlots[index].color)
    }

    func goingIcon(for location: String, year: Int) -> String? {
        guard let index = slotIndex(for: location, year: year),
              index >= 0,
              index < FestivalConfig.current.genericVenueSlots.count else { return nil }
        return FestivalConfig.current.genericVenueSlots[index].goingIcon
    }

    func notGoingIcon(for location: String, year: Int) -> String? {
        guard let index = slotIndex(for: location, year: year),
              index >= 0,
              index < FestivalConfig.current.genericVenueSlots.count else { return nil }
        return FestivalConfig.current.genericVenueSlots[index].notGoingIcon
    }
}

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

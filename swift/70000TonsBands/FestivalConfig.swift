//
//  FestivalConfig.swift
//  Festival Bands
//
//  Created by Configuration System
//  Copyright (c) 2025. All rights reserved.
//

// MARK: - Festival configuration
//
// Data loads from bundled festival.json (source: config/festivals/*.json).
// See config/festivals/README.md for adding a festival and what must exist
// outside JSON (icons, Firebase plist/json, bundle IDs, store listings).
//

import Foundation
import UIKit
import SwiftUI

struct Venue {
    let name: String
    let color: String // Hex color string
    let uiColor: UIColor
    let swiftUIColor: Color
    let goingIcon: String
    let notGoingIcon: String
    let location: String // Deck location (e.g., "Deck 11", "TBD")

    init(name: String, color: String, goingIcon: String, notGoingIcon: String, location: String) {
        self.name = name
        self.color = color
        self.uiColor = UIColor(hex: color) ?? UIColor.gray
        self.swiftUIColor = Color(hex: color)
        self.goingIcon = goingIcon
        self.notGoingIcon = notGoingIcon
        self.location = location
    }
}

// Extension to create Color from hex string
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Extension to create UIColor from hex string
extension UIColor {
    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

struct FestivalConfig {
    static let current = FestivalConfig()
    
    // Festival identification
    let festivalName: String
    let festivalShortName: String
    let appName: String
    let bundleIdentifier: String
    
    // Data URLs
    let defaultStorageUrl: String
    let defaultStorageUrlTest: String
    
    // Firebase configuration
    let firebaseConfigFile: String
    
    // Push notification topics
    let subscriptionTopic: String
    let subscriptionTopicTest: String
    let subscriptionUnofficalTopic: String
    
    // Default URLs for fallback
    let artistUrlDefault: String
    let scheduleUrlDefault: String
    
    // App-specific branding
    let logoUrl: String
    let shareUrl: String
    /// Profile-share file extension without leading dot (e.g. "mmfshare"). Set per festival in init.
    let shareFileExtension: String
    
    // Configurable graphic elements (forward-looking for future festivals; 70K and MDF keep existing assets)
    /// Must/Might/Wont priority icons (small, for swipe actions and menus)
    let mustSeeIconSmall: String
    let mightSeeIconSmall: String
    let wontSeeIconSmall: String
    let unknownIconSmall: String
    /// Must/Might/Wont priority graphics (large, select state)
    let mustSeeIcon: String
    let mustSeeIconAlt: String
    let mightSeeIcon: String
    let mightSeeIconAlt: String
    let wontSeeIcon: String
    let wontSeeIconAlt: String
    let unknownIcon: String
    let unknownIconAlt: String
    /// Toolbar icons
    let preferencesIcon: String
    let shareIcon: String
    let statsIcon: String
    
    // Venue configuration
    let venues: [Venue]
    /// Ordered color slots for schedule locations that are not named venues. Assigned by CSV row order at import.
    let genericVenueSlots: [GenericVenueSlot]
    
    // Event type filter visibility defaults
    let meetAndGreetsEnabledDefault: Bool
    let specialEventsEnabledDefault: Bool
    let unofficalEventsEnabledDefault: Bool
    let eventTypeDisplayNames: [String: [String: String]]
    let eventTypeFilterDisplayNames: [String: [String: String]]
    
    /// When true, the "Create AI schedule" feature is available (schedule present + this flag).
    /// 70K Bands: true. MDF Bands: false (for now).
    let aiSchedule: Bool

    /// When true, schedule share/scan via QR code is available. 70K Bands: true. MDF Bands: false.
    let scheduleQRShareEnabled: Bool

    // Comments not available message configuration
    let commentsNotAvailableTranslationKey: String

    /// About-screen team members and optional team photo from festival.json.
    let aboutTeam: AboutTeamConfig

    private let peerShareFileExtensions: [String]
    private let fallbackMiscGenericGoingIcon: String
    private let fallbackMiscGenericNotGoingIcon: String
    
    private init() {
        let p = FestivalConfigLoader.loadFromBundle()

        self.peerShareFileExtensions = p.peerShareFileExtensions
        self.fallbackMiscGenericGoingIcon = p.fallbackMiscGenericGoingIcon
        self.fallbackMiscGenericNotGoingIcon = p.fallbackMiscGenericNotGoingIcon
        self.festivalName = p.festivalName
        self.festivalShortName = p.festivalShortName
        self.appName = p.appName
        self.bundleIdentifier = p.bundleIdentifier
        self.defaultStorageUrl = p.defaultStorageUrl
        self.defaultStorageUrlTest = p.defaultStorageUrlTest
        self.firebaseConfigFile = p.firebaseConfigFile
        self.subscriptionTopic = p.subscriptionTopic
        self.subscriptionTopicTest = p.subscriptionTopicTest
        self.subscriptionUnofficalTopic = p.subscriptionUnofficalTopic
        self.artistUrlDefault = p.artistUrlDefault
        self.scheduleUrlDefault = p.scheduleUrlDefault
        self.logoUrl = p.logoUrl
        self.shareUrl = p.shareUrl
        self.shareFileExtension = p.shareFileExtension
        self.mustSeeIconSmall = p.mustSeeIconSmall
        self.mightSeeIconSmall = p.mightSeeIconSmall
        self.wontSeeIconSmall = p.wontSeeIconSmall
        self.unknownIconSmall = p.unknownIconSmall
        self.mustSeeIcon = p.mustSeeIcon
        self.mustSeeIconAlt = p.mustSeeIconAlt
        self.mightSeeIcon = p.mightSeeIcon
        self.mightSeeIconAlt = p.mightSeeIconAlt
        self.wontSeeIcon = p.wontSeeIcon
        self.wontSeeIconAlt = p.wontSeeIconAlt
        self.unknownIcon = p.unknownIcon
        self.unknownIconAlt = p.unknownIconAlt
        self.preferencesIcon = p.preferencesIcon
        self.shareIcon = p.shareIcon
        self.statsIcon = p.statsIcon
        self.venues = p.venues
        self.genericVenueSlots = p.genericVenueSlots
        self.meetAndGreetsEnabledDefault = p.meetAndGreetsEnabledDefault
        self.specialEventsEnabledDefault = p.specialEventsEnabledDefault
        self.unofficalEventsEnabledDefault = p.unofficalEventsEnabledDefault
        self.eventTypeDisplayNames = p.eventTypeDisplayNames
        self.eventTypeFilterDisplayNames = p.eventTypeFilterDisplayNames
        self.commentsNotAvailableTranslationKey = p.commentsNotAvailableTranslationKey
        self.aiSchedule = p.aiSchedule
        self.scheduleQRShareEnabled = p.scheduleQRShareEnabled
        self.aboutTeam = p.aboutTeam

        print("🏛️ FestivalConfig loaded from festival.json: \(self.festivalShortName)")
    }
    
    // Helper methods for common operations
    func getDisplayName() -> String {
        return appName
    }
    
    func getShortDisplayName() -> String {
        return festivalShortName
    }
    
    func isMDF() -> Bool {
        return festivalShortName == "MDF"
    }

    func isMMF() -> Bool {
        return festivalShortName == "MMF"
    }
    
    func is70K() -> Bool {
        return festivalShortName == "70K"
    }

    /// Leading-dot form for share filenames, e.g. ".mmfshare".
    var shareFileExtensionWithDot: String {
        return ".\(shareFileExtension)"
    }

    /// True when the path extension matches this app's share format.
    func isValidShareFileExtension(pathExtension: String) -> Bool {
        return pathExtension.lowercased() == shareFileExtension
    }

    /// True when a filename or URL path uses this app's share extension (case-insensitive).
    func hasValidShareFileExtension(filename: String?, pathExtension: String?, lastPathComponent: String?) -> Bool {
        let expectedSuffix = shareFileExtensionWithDot.lowercased()
        if let filename = filename, filename.lowercased().hasSuffix(expectedSuffix) {
            return true
        }
        if let pathExtension = pathExtension, isValidShareFileExtension(pathExtension: pathExtension) {
            return true
        }
        if let lastPathComponent = lastPathComponent {
            let ext = (lastPathComponent as NSString).pathExtension
            if !ext.isEmpty, isValidShareFileExtension(pathExtension: ext) {
                return true
            }
        }
        return false
    }

    /// True when the path extension belongs to a different festival's share file.
    func isOtherFestivalShareFile(pathExtension: String) -> Bool {
        let ext = pathExtension.lowercased()
        return peerShareFileExtensions.contains(ext) && ext != shareFileExtension
    }

    func getEventTypeDisplayName(canonicalEventType: String, languageCode: String) -> String {
        let normalizedType = EventTypes.normalize(canonicalEventType)
        let normalizedLanguage = languageCode.lowercased()
        if let byLanguage = eventTypeDisplayNames[normalizedType] {
            if let localized = byLanguage[normalizedLanguage], !localized.isEmpty { return localized }
            if let english = byLanguage["en"], !english.isEmpty { return english }
        }
        return normalizedType
    }

    func getEventTypeFilterDisplayName(canonicalEventType: String, languageCode: String) -> String {
        let normalizedType = EventTypes.normalize(canonicalEventType)
        let normalizedLanguage = languageCode.lowercased()
        if let byLanguage = eventTypeFilterDisplayNames[normalizedType] {
            if let localized = byLanguage[normalizedLanguage], !localized.isEmpty { return localized }
            if let english = byLanguage["en"], !english.isEmpty { return english }
        }
        return "Show \(getEventTypeDisplayName(canonicalEventType: normalizedType, languageCode: "en"))"
    }
    
    /// Returns the localized default description text for the current festival
    func getDefaultDescriptionText() -> String {
        return NSLocalizedString(commentsNotAvailableTranslationKey, comment: "Default description for current festival")
    }

    /// True when the note is only the empty generic placeholder (e.g. "Click to add notes",
    /// "waiting for Aaron's description") and not real downloaded band description content.
    func isEmptyGenericNoteText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let defaultText = getDefaultDescriptionText().trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == defaultText {
            return true
        }

        if trimmed.hasPrefix("Comment text is not available yet") {
            return true
        }

        if trimmed.contains("No notes are available, right now, feel free to add your own") {
            return true
        }

        return false
    }
    
    /// Returns the localized comments not available message for the current festival
    func getCommentsNotAvailableMessage() -> String {
        return NSLocalizedString(commentsNotAvailableTranslationKey, comment: "Comments not available message for current festival")
    }
    
    // MARK: - Venue Helper Methods

    /// Exact match against configured named venues (not generic slots).
    func hasNamedVenue(exactName: String) -> Bool {
        return venues.contains { $0.name == exactName }
    }
    
    /// Get venue by name (exact match only)
    func getVenue(named name: String) -> Venue? {
        return venues.first { $0.name == name }
    }
    
    /// Get venue by partial name match (for backwards compatibility)
    func getVenueByPartialName(_ name: String) -> Venue? {
        // Trim whitespace and normalize the input
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let matched = venues.first { venue in
            let nameLower = trimmedName.lowercased()
            let venueLower = venue.name.lowercased()
            let contains1 = nameLower.contains(venueLower)
            let contains2 = venueLower.contains(nameLower)
            return contains1 || contains2
        }
        
        return matched
    }
    
    /// Get all venue names
    func getAllVenueNames() -> [String] {
        return venues.map { $0.name }
    }

    /// Get venue color for a given venue name (returns UIColor) - EXACT match only
    func getVenueColor(for venueName: String) -> UIColor {
        if let venue = getVenue(named: venueName) {
            return venue.uiColor
        }
        if let assigned = VenueColorAssignmentStore.shared.uiColor(for: venueName, year: eventYear) {
            return assigned
        }
        return UIColor.gray
    }
    
    /// Get venue color for a given venue name (returns SwiftUI Color) - EXACT match only
    func getVenueSwiftUIColor(for venueName: String) -> Color {
        if let venue = getVenue(named: venueName) {
            return venue.swiftUIColor
        }
        if let assigned = VenueColorAssignmentStore.shared.swiftUIColor(for: venueName, year: eventYear) {
            return assigned
        }
        return Color.gray
    }
    
    /// Get venue going icon for a given venue name - EXACT match only
    func getVenueGoingIcon(for venueName: String) -> String {
        if let venue = getVenue(named: venueName) {
            return venue.goingIcon
        }
        if let assigned = VenueColorAssignmentStore.shared.goingIcon(for: venueName, year: eventYear) {
            return assigned
        }
        return fallbackMiscGenericGoingIcon
    }
    
    /// Get venue not going icon for a given venue name - EXACT match only
    func getVenueNotGoingIcon(for venueName: String) -> String {
        if let venue = getVenue(named: venueName) {
            return venue.notGoingIcon
        }
        if let assigned = VenueColorAssignmentStore.shared.notGoingIcon(for: venueName, year: eventYear) {
            return assigned
        }
        return fallbackMiscGenericNotGoingIcon
    }
    
    /// Get venue location for a given venue name - EXACT match only
    func getVenueLocation(for venueName: String) -> String {
        return getVenue(named: venueName)?.location ?? ""
    }
}

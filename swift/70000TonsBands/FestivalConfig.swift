//
//  FestivalConfig.swift
//  Festival Bands
//
//  Created by Configuration System
//  Copyright (c) 2025. All rights reserved.
//

// MARK: - How to configure a new festival
//
// This file is structured to scale to many festivals (12+). Follow these steps to add one:
//
// 1. BUILD SETTING: Add a new Swift compiler flag for the festival (e.g. FESTIVAL_XYZ).
//    In Xcode: Target → Build Settings → Swift Compiler - Custom Flags → Other Swift Flags.
//    Add -D FESTIVAL_XYZ for the scheme/target that builds that festival’s app.
//
// 2. DEFAULTS: Shared values live in the "Defaults" section below. Only add a value there
//    if it is the same across all (or most) festivals. Any festival can override a default
//    by setting that property in its own section.
//
// 3. FESTIVAL SECTION: Add #elseif FESTIVAL_XYZ above the #else. Copy the #else (70K) block as a template. Then:
//    - Set festival-specific required properties: festivalName, festivalShortName,
//      appName, bundleIdentifier, defaultStorageUrl, defaultStorageUrlTest,
//      firebaseConfigFile, logoUrl, shareUrl, venues.
//    - Set optional overrides: meetAndGreetsEnabledDefault, specialEventsEnabledDefault,
//      unofficalEventsEnabledDefault, commentsNotAvailableTranslationKey, aiSchedule.
//    - For any property that should match the default, assign Defaults.xxx so the
//      default is the single source of truth and can change later without editing
//      every festival.
//
// 4. ORDER: Keep the #if / #elseif / #else order so the intended “default fallback”
//    festival is in the #else block (currently 70K).
//
// FILE STRUCTURE:
// - Venue model and Color/UIColor hex extensions
// - FestivalConfig struct (properties and helpers)
// - Defaults: shared values used by multiple festivals; overridable per festival
// - One section per festival: #else = 70K (default), #if FESTIVAL_MDF = MDF, etc.

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
    
    // Event type filter visibility defaults
    let meetAndGreetsEnabledDefault: Bool
    let specialEventsEnabledDefault: Bool
    let unofficalEventsEnabledDefault: Bool
    
    /// When true, the "Create AI schedule" feature is available (schedule present + this flag).
    /// 70K Bands: true. MDF Bands: false (for now).
    let aiSchedule: Bool

    /// When true, schedule share/scan via QR code is available. 70K Bands: true. MDF Bands: false.
    let scheduleQRShareEnabled: Bool

    // Comments not available message configuration
    let commentsNotAvailableTranslationKey: String
    
    // MARK: - Defaults (shared across festivals; any festival section can override)
    /// Values used when a festival does not override. Add here only settings that are
    /// the same for 70K and MDF (and likely future festivals). Per-festival sections
    /// assign Defaults.xxx for shared values and use literals for overrides.
    private struct Defaults {
        static let subscriptionTopic = "global"
        static let subscriptionTopicTest = "Testing20250824"
        static let subscriptionUnofficalTopic = "unofficalEvents"
        static let artistUrlDefault = ""
        static let scheduleUrlDefault = ""
        // Priority / toolbar icons (same assets for 70K and MDF; future festivals can override)
        static let mustSeeIconSmall = "icon-going-yes"
        static let mightSeeIconSmall = "icon-going-maybe"
        static let wontSeeIconSmall = "icon-going-no"
        static let unknownIconSmall = "icon-unknown"
        static let mustSeeIcon = "Going-Devil-Yeah-rev1-Select-wBox"
        static let mustSeeIconAlt = "Going-Devil-Yeah-rev1-DeSelect-wBox"
        static let mightSeeIcon = "Maybe-Devil-Meh-rev1-Select-wBox"
        static let mightSeeIconAlt = "Maybe-Devil-Meh-rev1-DeSelect-wBox"
        static let wontSeeIcon = "No-way-Devil-Bah-rev2-Select-wBox"
        static let wontSeeIconAlt = "No-way-Devil-Bah-rev2-DeSelect-wBox"
        static let unknownIcon = "Unknown-v2-Select-wBox"
        static let unknownIconAlt = "Unknown-v2-DeSelect-wBox"
        static let preferencesIcon = "icon-gear-alt-Raw"
        static let shareIcon = "icon-share"
        static let statsIcon = "Stats v 4On Black"
    }
    
    private init() {
        print("🏛️ [MDF_DEBUG] FestivalConfig init() called")
        
        #if FESTIVAL_MDF
        // MARK: ---- FESTIVAL: Maryland Deathfest (MDF) ----
        print("🏛️ [MDF_DEBUG] Building MDF configuration")
        self.festivalName = "Maryland Deathfest"
        self.festivalShortName = "MDF"
        self.appName = "MDF Bands"
        self.bundleIdentifier = "com.rdorn.mdfbands"
        self.defaultStorageUrl = "https://www.dropbox.com/scl/fi/39jr2f37rhrdk14koj0pz/mdf_productionPointer.txt?rlkey=ij3llf5y1mxwpq2pmwbj03e6t&raw=1"
        self.defaultStorageUrlTest = "https://www.dropbox.com/scl/fi/erdm6rrda8kku1svq8jwk/mdf_productionPointer_test.txt?rlkey=fhjftwb1uakiy83axcpfwrh1e&raw=1"
        self.firebaseConfigFile = "GoogleService-Info-MDF"
        self.subscriptionTopic = Defaults.subscriptionTopic
        self.subscriptionTopicTest = Defaults.subscriptionTopicTest
        self.subscriptionUnofficalTopic = Defaults.subscriptionUnofficalTopic
        self.artistUrlDefault = Defaults.artistUrlDefault
        self.scheduleUrlDefault = Defaults.scheduleUrlDefault
        self.logoUrl = "mdf_logo"
        self.shareUrl = "https://www.facebook.com/profile.php?id=61580889273388"
        self.mustSeeIconSmall = Defaults.mustSeeIconSmall
        self.mightSeeIconSmall = Defaults.mightSeeIconSmall
        self.wontSeeIconSmall = Defaults.wontSeeIconSmall
        self.unknownIconSmall = Defaults.unknownIconSmall
        self.mustSeeIcon = Defaults.mustSeeIcon
        self.mustSeeIconAlt = Defaults.mustSeeIconAlt
        self.mightSeeIcon = Defaults.mightSeeIcon
        self.mightSeeIconAlt = Defaults.mightSeeIconAlt
        self.wontSeeIcon = Defaults.wontSeeIcon
        self.wontSeeIconAlt = Defaults.wontSeeIconAlt
        self.unknownIcon = Defaults.unknownIcon
        self.unknownIconAlt = Defaults.unknownIconAlt
        self.preferencesIcon = Defaults.preferencesIcon
        self.shareIcon = Defaults.shareIcon
        self.statsIcon = Defaults.statsIcon
        self.venues = [
            Venue(name: "Rams Head", color: "EA580C", goingIcon: "Royal-Theater-Going-wBox", notGoingIcon: "Royal-Theater-NotGoing-wBox", location: "20 Market"),
            Venue(name: "Market", color: "047857", goingIcon: "Royal-Theater-Going-wBox", notGoingIcon: "Royal-Theater-NotGoing-wBox", location: "121 Market"),
            Venue(name: "Power Plant", color: "1D4ED8", goingIcon: "Royal-Theater-Going-wBox", notGoingIcon: "Royal-Theater-NotGoing-wBox", location: "34 Market"),
            Venue(name: "Nevermore", color: "0891B2", goingIcon: "Royal-Theater-Going-wBox", notGoingIcon: "Royal-Theater-NotGoing-wBox", location: "20 Market"),
            Venue(name: "Soundstage", color: "991B1B", goingIcon: "Royal-Theater-Going-wBox", notGoingIcon: "Royal-Theater-NotGoing-wBox", location: "124 Market"),
            Venue(name: "Angels Rock", color: "A16207", goingIcon: "Royal-Theater-Going-wBox", notGoingIcon: "Royal-Theater-NotGoing-wBox", location: "10 Market")
        ]
        self.meetAndGreetsEnabledDefault = false
        self.specialEventsEnabledDefault = false
        self.unofficalEventsEnabledDefault = false
        self.commentsNotAvailableTranslationKey = "DefaultDescriptionMDF"
        self.aiSchedule = true
        self.scheduleQRShareEnabled = false

        // Future festivals: add #elseif FESTIVAL_XYZ above, then copy a block and override as needed.
        
        #else
        // MARK: ---- FESTIVAL: 70,000 Tons Of Metal (70K) — default, no macro ----
        print("🏛️ [MDF_DEBUG] Building 70K configuration")
        self.festivalName = "70,000 Tons Of Metal"
        self.festivalShortName = "70K"
        self.appName = "70K Bands"
        self.bundleIdentifier = "com.rdorn.-0000TonsBands"
        self.defaultStorageUrl = "https://www.dropbox.com/scl/fi/kd5gzo06yrrafgz81y0ao/productionPointer.txt?rlkey=gt1lpaf11nay0skb6fe5zv17g&raw=1"
        self.defaultStorageUrlTest = "https://www.dropbox.com/s/f3raj8hkfbd81mp/productionPointer2024-Test.txt?raw=1"
        self.firebaseConfigFile = "GoogleService-Info-70K"
        self.subscriptionTopic = Defaults.subscriptionTopic
        self.subscriptionTopicTest = Defaults.subscriptionTopicTest
        self.subscriptionUnofficalTopic = Defaults.subscriptionUnofficalTopic
        self.artistUrlDefault = Defaults.artistUrlDefault
        self.scheduleUrlDefault = Defaults.scheduleUrlDefault
        self.logoUrl = "70000TonsLogo"
        self.shareUrl = "http://www.facebook.com/70kBands"
        self.mustSeeIconSmall = Defaults.mustSeeIconSmall
        self.mightSeeIconSmall = Defaults.mightSeeIconSmall
        self.wontSeeIconSmall = Defaults.wontSeeIconSmall
        self.unknownIconSmall = Defaults.unknownIconSmall
        self.mustSeeIcon = Defaults.mustSeeIcon
        self.mustSeeIconAlt = Defaults.mustSeeIconAlt
        self.mightSeeIcon = Defaults.mightSeeIcon
        self.mightSeeIconAlt = Defaults.mightSeeIconAlt
        self.wontSeeIcon = Defaults.wontSeeIcon
        self.wontSeeIconAlt = Defaults.wontSeeIconAlt
        self.unknownIcon = Defaults.unknownIcon
        self.unknownIconAlt = Defaults.unknownIconAlt
        self.preferencesIcon = Defaults.preferencesIcon
        self.shareIcon = Defaults.shareIcon
        self.statsIcon = Defaults.statsIcon
        self.venues = [
            Venue(name: "Pool", color: "1D4ED8", goingIcon: "Pool-Deck-Going-wBox", notGoingIcon: "Pool-Deck-NotGoing-wBox", location: "Deck 11"),
            Venue(name: "Lounge", color: "047857", goingIcon: "Lounge-Going-wBox", notGoingIcon: "Lounge-NotGoing-wBox", location: "Deck 5"),
            Venue(name: "Theater", color: "B45309", goingIcon: "Royal-Theater-Going-wBox", notGoingIcon: "Royal-Theater-NotGoing-wBox", location: "Deck 3/4"),
            Venue(name: "Rink", color: "C026D3", goingIcon: "Ice-Rink-Going-wBox", notGoingIcon: "Ice-Rink-NotGoing-wBox", location: "Deck 3"),
            Venue(name: "Schooner Pub", color: "C2185B", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 4"),
            Venue(name: "Arcade", color: "334155", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 12"),
            Venue(name: "Sports Bar", color: "EA580C", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 5"),
            Venue(name: "Viking Crown", color: "7C3AED", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 14"),
            Venue(name: "Boleros Lounge", color: "92400E", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 4"),
            Venue(name: "Solarium", color: "0891B2", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 11"),
            Venue(name: "Ale And Anchor Pub", color: "A16207", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 5"),
            Venue(name: "Ale & Anchor Pub", color: "A16207", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 5"),
            Venue(name: "Bull And Bear Pub", color: "B22222", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 5"),
            Venue(name: "Bull & Bear Pub", color: "B22222", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 5")
        ]
        self.meetAndGreetsEnabledDefault = true
        self.specialEventsEnabledDefault = true
        self.unofficalEventsEnabledDefault = true
        self.commentsNotAvailableTranslationKey = "DefaultDescription70K"
        self.aiSchedule = true
        self.scheduleQRShareEnabled = true
        #endif
        
        print("🏛️ [MDF_DEBUG] FestivalConfig init() completed")
        print("🏛️ [MDF_DEBUG] Final values:")
        print("   Festival: \(self.festivalShortName)")
        print("   App Name: \(self.appName)")
        print("   Venues: \(self.venues.map { $0.name })")
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
    
    func is70K() -> Bool {
        return festivalShortName == "70K"
    }
    
    /// Returns the localized default description text for the current festival
    func getDefaultDescriptionText() -> String {
        #if FESTIVAL_MDF
        return NSLocalizedString("DefaultDescriptionMDF", comment: "Default description for MDF festival")
        #else
        return NSLocalizedString("DefaultDescription70K", comment: "Default description for 70K festival")
        #endif
    }
    
    /// Returns the localized comments not available message for the current festival
    func getCommentsNotAvailableMessage() -> String {
        return NSLocalizedString(commentsNotAvailableTranslationKey, comment: "Comments not available message for current festival")
    }
    
    // MARK: - Venue Helper Methods
    
    /// Get venue by name
    func getVenue(named name: String) -> Venue? {
        return venues.first { $0.name.lowercased() == name.lowercased() }
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
        let venue = getVenue(named: venueName)
        if let venue = venue {
            return venue.uiColor
        } else {
            return UIColor.gray
        }
    }
    
    /// Get venue color for a given venue name (returns SwiftUI Color) - EXACT match only
    func getVenueSwiftUIColor(for venueName: String) -> Color {
        return getVenue(named: venueName)?.swiftUIColor ?? Color.gray
    }
    
    /// Get venue going icon for a given venue name - EXACT match only
    func getVenueGoingIcon(for venueName: String) -> String {
        return getVenue(named: venueName)?.goingIcon ?? "Unknown-Going-wBox"
    }
    
    /// Get venue not going icon for a given venue name - EXACT match only
    func getVenueNotGoingIcon(for venueName: String) -> String {
        return getVenue(named: venueName)?.notGoingIcon ?? "Unknown-NotGoing-wBox"
    }
    
    /// Get venue location for a given venue name - EXACT match only
    func getVenueLocation(for venueName: String) -> String {
        return getVenue(named: venueName)?.location ?? ""
    }
}

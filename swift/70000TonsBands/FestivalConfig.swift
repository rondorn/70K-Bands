//
//  FestivalConfig.swift
//  Festival Bands
//
//  Created by Configuration System
//  Copyright (c) 2025. All rights reserved.
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
    let showInFilters: Bool // Whether this venue should appear in the filters menu
    
    init(name: String, color: String, goingIcon: String, notGoingIcon: String, location: String, showInFilters: Bool = true) {
        self.name = name
        self.color = color
        self.uiColor = UIColor(hex: color) ?? UIColor.gray
        self.swiftUIColor = Color(hex: color)
        self.goingIcon = goingIcon
        self.notGoingIcon = notGoingIcon
        self.location = location
        self.showInFilters = showInFilters
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
    
    // Venue configuration
    let venues: [Venue]
    
    // Event type filter visibility defaults
    let meetAndGreetsEnabledDefault: Bool
    let specialEventsEnabledDefault: Bool
    let unofficalEventsEnabledDefault: Bool
    
    // Comments not available message configuration
    let commentsNotAvailableTranslationKey: String
    
    private init() {
        print("🏛️ [MDF_DEBUG] FestivalConfig init() called")
        #if FESTIVAL_70K
        print("🏛️ [MDF_DEBUG] Building 70K configuration")
        // 70,000 Tons of Metal configuration
        self.festivalName = "70,000 Tons Of Metal"
        self.festivalShortName = "70K"
        self.appName = "70K Bands"
        self.bundleIdentifier = "com.rdorn.-0000TonsBands"
        
        self.defaultStorageUrl = "https://www.dropbox.com/scl/fi/kd5gzo06yrrafgz81y0ao/productionPointer.txt?rlkey=gt1lpaf11nay0skb6fe5zv17g&raw=1"
        self.defaultStorageUrlTest = "https://www.dropbox.com/s/f3raj8hkfbd81mp/productionPointer2024-Test.txt?raw=1"
        
        self.firebaseConfigFile = "GoogleService-Info-70K"
        
        self.subscriptionTopic = "global"
        self.subscriptionTopicTest = "Testing20250824"
        self.subscriptionUnofficalTopic = "unofficalEvents"
        
        self.artistUrlDefault = ""
        self.scheduleUrlDefault = ""
        
        self.logoUrl = "70000TonsLogo"
        self.shareUrl = "http://www.facebook.com/70kBands"
        
        // 70K venues: All venues with their deck locations
        self.venues = [
            Venue(name: "Pool", color: "1D4ED8", goingIcon: "Pool-Deck-Going-wBox", notGoingIcon: "Pool-Deck-NotGoing-wBox", location: "Deck 11", showInFilters: true), // Blue
            Venue(name: "Lounge", color: "047857", goingIcon: "Lounge-Going-wBox", notGoingIcon: "Lounge-NotGoing-wBox", location: "Deck 5", showInFilters: true), // Emerald
            Venue(name: "Theater", color: "B45309", goingIcon: "Royal-Theater-Going-wBox", notGoingIcon: "Royal-Theater-NotGoing-wBox", location: "Deck 3/4", showInFilters: true), // Amber
            Venue(name: "Rink", color: "C026D3", goingIcon: "Ice-Rink-Going-wBox", notGoingIcon: "Ice-Rink-NotGoing-wBox", location: "Deck 3", showInFilters: true), // Magenta
            Venue(name: "Sports Bar", color: "EA580C", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 4", showInFilters: false), // Orange
            Venue(name: "Viking Crown", color: "7C3AED", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 14", showInFilters: false), // Violet
            Venue(name: "Boleros Lounge", color: "92400E", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 4", showInFilters: false), // Brown
            Venue(name: "Solarium", color: "0891B2", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 11", showInFilters: false), // Cyan
            Venue(name: "Ale And Anchor Pub", color: "A16207", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 5", showInFilters: false), // Yellow (dark)
            Venue(name: "Ale & Anchor Pub", color: "A16207", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 5", showInFilters: false), // Yellow (dark)
            Venue(name: "Bull And Bear Pub", color: "991B1B", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 5", showInFilters: false), // Dark red
            Venue(name: "Bull & Bear Pub", color: "991B1B", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 5", showInFilters: false) // Dark red
        ]
        
        // 70K event type filter visibility - all enabled
        self.meetAndGreetsEnabledDefault = true
        self.specialEventsEnabledDefault = true
        self.unofficalEventsEnabledDefault = true
        
        // 70K comments not available message
        self.commentsNotAvailableTranslationKey = "DefaultDescription70K"
        
        #elseif FESTIVAL_MDF
        print("🏛️ [MDF_DEBUG] Building MDF configuration")
        // Maryland Death Fest configuration
        self.festivalName = "Maryland Deathfest"
        self.festivalShortName = "MDF"
        self.appName = "MDF Bands"
        self.bundleIdentifier = "com.rdorn.mdfbands"
        
        self.defaultStorageUrl = "https://www.dropbox.com/scl/fi/39jr2f37rhrdk14koj0pz/mdf_productionPointer.txt?rlkey=ij3llf5y1mxwpq2pmwbj03e6t&raw=1"
        self.defaultStorageUrlTest = "https://www.dropbox.com/scl/fi/erdm6rrda8kku1svq8jwk/mdf_productionPointer_test.txt?rlkey=fhjftwb1uakiy83axcpfwrh1e&raw=1"
        
        self.firebaseConfigFile = "GoogleService-Info-MDF" // Will use placeholder for now
        
        self.subscriptionTopic = "global"
        self.subscriptionTopicTest = "Testing20250824"
        self.subscriptionUnofficalTopic = "unofficalEvents"
        
        // MDF-specific URLs (will be configured via pointer file)
        self.artistUrlDefault = ""
        self.scheduleUrlDefault = ""
        
        self.logoUrl = "mdf_logo"
        self.shareUrl = "https://www.facebook.com/profile.php?id=61580889273388"
        
        // MDF venues: Real venue names with Market Street addresses
        self.venues = [
            Venue(name: "Rams Head", color: "EA580C", goingIcon: "Royal-Theater-Going-wBox", notGoingIcon: "Royal-Theater-NotGoing-wBox", location: "20 Market", showInFilters: true), // Orange
            Venue(name: "Market", color: "047857", goingIcon: "Royal-Theater-Going-wBox", notGoingIcon: "Royal-Theater-NotGoing-wBox", location: "121 Market", showInFilters: true), // Emerald
            Venue(name: "Power Plant", color: "1D4ED8", goingIcon: "Royal-Theater-Going-wBox", notGoingIcon: "Royal-Theater-NotGoing-wBox", location: "34 Market", showInFilters: true), // Blue
            Venue(name: "Nevermore", color: "0891B2", goingIcon: "Royal-Theater-Going-wBox", notGoingIcon: "Royal-Theater-NotGoing-wBox", location: "20 Market", showInFilters: true), // Cyan
            Venue(name: "Soundstage", color: "991B1B", goingIcon: "Royal-Theater-Going-wBox", notGoingIcon: "Royal-Theater-NotGoing-wBox", location: "124 Market", showInFilters: true), // Dark red
            Venue(name: "Angels Rock", color: "A16207", goingIcon: "Royal-Theater-Going-wBox", notGoingIcon: "Royal-Theater-NotGoing-wBox", location: "10 Market", showInFilters: true) // Yellow (dark)
        ]
        
        // MDF event type filter visibility - all disabled
        self.meetAndGreetsEnabledDefault = false
        self.specialEventsEnabledDefault = false
        self.unofficalEventsEnabledDefault = false
        
        // MDF comments not available message
        self.commentsNotAvailableTranslationKey = "DefaultDescriptionMDF"
        
        #else
        print("🏛️ [MDF_DEBUG] Building DEFAULT (70K) configuration - no macro defined")
        // Default to 70K configuration if no macro is defined
        self.festivalName = "70,000 Tons Of Metal"
        self.festivalShortName = "70K"
        self.appName = "70K Bands"
        self.bundleIdentifier = "com.rdorn.-0000TonsBands"
        
        self.defaultStorageUrl = "https://www.dropbox.com/scl/fi/kd5gzo06yrrafgz81y0ao/productionPointer.txt?rlkey=gt1lpaf11nay0skb6fe5zv17g&raw=1"
        self.defaultStorageUrlTest = "https://www.dropbox.com/s/f3raj8hkfbd81mp/productionPointer2024-Test.txt?raw=1"
        
        self.firebaseConfigFile = "GoogleService-Info"
        
        self.subscriptionTopic = "global"
        self.subscriptionTopicTest = "Testing20250801"
        self.subscriptionUnofficalTopic = "unofficalEvents"
        
        self.artistUrlDefault = ""
        self.scheduleUrlDefault = ""
        
        self.logoUrl = "70000TonsLogo"
        self.shareUrl = "http://www.facebook.com/70kBands"
        
        // Default venues (same as 70K): All venues with their deck locations
        self.venues = [
            Venue(name: "Pool", color: "1D4ED8", goingIcon: "Pool-Deck-Going-wBox", notGoingIcon: "Pool-Deck-NotGoing-wBox", location: "Deck 11", showInFilters: true), // Blue
            Venue(name: "Lounge", color: "047857", goingIcon: "Lounge-Going-wBox", notGoingIcon: "Lounge-NotGoing-wBox", location: "Deck 5", showInFilters: true), // Emerald
            Venue(name: "Theater", color: "B45309", goingIcon: "Royal-Theater-Going-wBox", notGoingIcon: "Royal-Theater-NotGoing-wBox", location: "Deck 3/4", showInFilters: true), // Amber
            Venue(name: "Rink", color: "C026D3", goingIcon: "Ice-Rink-Going-wBox", notGoingIcon: "Ice-Rink-NotGoing-wBox", location: "Deck 3", showInFilters: true), // Magenta
            Venue(name: "Sports Bar", color: "EA580C", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 4", showInFilters: false), // Orange
            Venue(name: "Viking Crown", color: "7C3AED", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 14", showInFilters: false), // Violet
            Venue(name: "Boleros Lounge", color: "92400E", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 4", showInFilters: false), // Brown
            Venue(name: "Solarium", color: "0891B2", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 11", showInFilters: false), // Cyan
            Venue(name: "Ale And Anchor Pub", color: "A16207", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 5", showInFilters: false), // Yellow (dark)
            Venue(name: "Ale & Anchor Pub", color: "A16207", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 5", showInFilters: false), // Yellow (dark)
            Venue(name: "Bull And Bear Pub", color: "B22222", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 5", showInFilters: false),
            Venue(name: "Bull & Bear Pub", color: "B22222", goingIcon: "Unknown-Going-wBox", notGoingIcon: "Unknown-NotGoing-wBox", location: "Deck 5", showInFilters: false)
        ]
        
        // Default event type filter visibility (same as 70K) - all enabled
        self.meetAndGreetsEnabledDefault = true
        self.specialEventsEnabledDefault = true
        self.unofficalEventsEnabledDefault = true
        
        // Default comments not available message (same as 70K)
        self.commentsNotAvailableTranslationKey = "DefaultDescription70K"
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
        #if FESTIVAL_MDF
        return true
        #else
        return false
        #endif
    }
    
    func is70K() -> Bool {
        #if FESTIVAL_70K
        return true
        #else
        return false
        #endif
    }
    
    /// Returns the localized default description text for the current festival
    func getDefaultDescriptionText() -> String {
        #if FESTIVAL_70K
        return NSLocalizedString("DefaultDescription70K", comment: "Default description for 70K festival")
        #elseif FESTIVAL_MDF
        return NSLocalizedString("DefaultDescriptionMDF", comment: "Default description for MDF festival")
        #else
        return NSLocalizedString("DefaultDescription70K", comment: "Default description fallback")
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
    
    /// Get venues that should be shown in the filters menu
    func getFilterVenues() -> [Venue] {
        return venues.filter { $0.showInFilters }
    }
    
    /// Get venue names that should be shown in the filters menu
    func getFilterVenueNames() -> [String] {
        return venues.filter { $0.showInFilters }.map { $0.name }
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

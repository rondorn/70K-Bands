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
    
    init(name: String, color: String, goingIcon: String, notGoingIcon: String) {
        self.name = name
        self.color = color
        self.uiColor = UIColor(hex: color) ?? UIColor.gray
        self.swiftUIColor = Color(hex: color)
        self.goingIcon = goingIcon
        self.notGoingIcon = notGoingIcon
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
    
    private init() {
        print("🏛️ [MDF_DEBUG] FestivalConfig init() called")
        #if FESTIVAL_70K
        print("🏛️ [MDF_DEBUG] Building 70K configuration")
        // 70,000 Tons of Metal configuration
        self.festivalName = "70,000 Tons of Metal"
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
        
        // 70K venues: Pool, Lounge, Theater, Rink with colors blue, green, yellow, red
        self.venues = [
            Venue(name: "Pool", color: "0000FF", goingIcon: "Pool-Deck-Going-wBox", notGoingIcon: "Pool-Deck-NotGoing-wBox"),
            Venue(name: "Lounge", color: "008000", goingIcon: "Lounge-Going-wBox", notGoingIcon: "Lounge-NotGoing-wBox"),
            Venue(name: "Theater", color: "FFFF00", goingIcon: "Royal-Theater-Going-wBox", notGoingIcon: "Royal-Theater-NotGoing-wBox"),
            Venue(name: "Rink", color: "FF0000", goingIcon: "Ice-Rink-Going-wBox", notGoingIcon: "Ice-Rink-NotGoing-wBox")
        ]
        
        // 70K event type filter visibility - all enabled
        self.meetAndGreetsEnabledDefault = true
        self.specialEventsEnabledDefault = true
        self.unofficalEventsEnabledDefault = true
        
        #elseif FESTIVAL_MDF
        print("🏛️ [MDF_DEBUG] Building MDF configuration")
        // Maryland Death Fest configuration
        self.festivalName = "Maryland Death Fest"
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
        self.shareUrl = "http://www.facebook.com/MDFBands"
        
        // MDF venues: Real venue names (Market, Power Plant, Nevermore, Soundstage, Angels Rock)
        self.venues = [
            Venue(name: "Market", color: "008000", goingIcon: "Royal-Theater-Going-wBox", notGoingIcon: "Royal-Theater-NotGoing-wBox"),
            Venue(name: "Power Plant", color: "0000FF", goingIcon: "Royal-Theater-Going-wBox", notGoingIcon: "Royal-Theater-NotGoing-wBox"),
            Venue(name: "Nevermore", color: "FF69B4", goingIcon: "Royal-Theater-Going-wBox", notGoingIcon: "Royal-Theater-NotGoing-wBox"),
            Venue(name: "Soundstage", color: "FF0000", goingIcon: "Royal-Theater-Going-wBox", notGoingIcon: "Royal-Theater-NotGoing-wBox"),
            Venue(name: "Angels Rock", color: "FFFF00", goingIcon: "Royal-Theater-Going-wBox", notGoingIcon: "Royal-Theater-NotGoing-wBox")
        ]
        
        // MDF event type filter visibility - all disabled
        self.meetAndGreetsEnabledDefault = false
        self.specialEventsEnabledDefault = false
        self.unofficalEventsEnabledDefault = false
        
        #else
        print("🏛️ [MDF_DEBUG] Building DEFAULT (70K) configuration - no macro defined")
        // Default to 70K configuration if no macro is defined
        self.festivalName = "70,000 Tons of Metal"
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
        
        // Default venues (same as 70K): Pool, Lounge, Theater, Rink with colors blue, green, yellow, red
        self.venues = [
            Venue(name: "Pool", color: "0000FF", goingIcon: "Pool-Deck-Going-wBox", notGoingIcon: "Pool-Deck-NotGoing-wBox"),
            Venue(name: "Lounge", color: "008000", goingIcon: "Lounge-Going-wBox", notGoingIcon: "Lounge-NotGoing-wBox"),
            Venue(name: "Theater", color: "FFFF00", goingIcon: "Royal-Theater-Going-wBox", notGoingIcon: "Royal-Theater-NotGoing-wBox"),
            Venue(name: "Rink", color: "FF0000", goingIcon: "Ice-Rink-Going-wBox", notGoingIcon: "Ice-Rink-NotGoing-wBox")
        ]
        
        // Default event type filter visibility (same as 70K) - all enabled
        self.meetAndGreetsEnabledDefault = true
        self.specialEventsEnabledDefault = true
        self.unofficalEventsEnabledDefault = true
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
    
    // MARK: - Venue Helper Methods
    
    /// Get venue by name
    func getVenue(named name: String) -> Venue? {
        return venues.first { $0.name.lowercased() == name.lowercased() }
    }
    
    /// Get venue by partial name match (for backwards compatibility)
    func getVenueByPartialName(_ name: String) -> Venue? {
        return venues.first { venue in
            name.lowercased().contains(venue.name.lowercased()) || 
            venue.name.lowercased().contains(name.lowercased())
        }
    }
    
    /// Get all venue names
    func getAllVenueNames() -> [String] {
        return venues.map { $0.name }
    }
    
    /// Get venue color for a given venue name (returns UIColor)
    func getVenueColor(for venueName: String) -> UIColor {
        return getVenueByPartialName(venueName)?.uiColor ?? UIColor.gray
    }
    
    /// Get venue color for a given venue name (returns SwiftUI Color)
    func getVenueSwiftUIColor(for venueName: String) -> Color {
        return getVenueByPartialName(venueName)?.swiftUIColor ?? Color.gray
    }
    
    /// Get venue going icon for a given venue name
    func getVenueGoingIcon(for venueName: String) -> String {
        return getVenueByPartialName(venueName)?.goingIcon ?? "Unknown-Going-wBox"
    }
    
    /// Get venue not going icon for a given venue name
    func getVenueNotGoingIcon(for venueName: String) -> String {
        return getVenueByPartialName(venueName)?.notGoingIcon ?? "Unknown-NotGoing-wBox"
    }
}

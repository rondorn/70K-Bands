//
//  FestivalConfig.swift
//  Festival Bands
//
//  Created by Configuration System
//  Copyright (c) 2025. All rights reserved.
//

import Foundation

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
    
    private init() {
        #if FESTIVAL_70K
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
        
        self.artistUrlDefault = "https://www.dropbox.com/s/5hcaxigzdj7fjrt/artistLineup.html?dl=1"
        self.scheduleUrlDefault = "https://www.dropbox.com/s/tg9qgt48ezp7udv/Schedule.csv?dl=1"
        
        self.logoUrl = "70000TonsLogo"
        self.shareUrl = "http://www.facebook.com/70kBands"
        
        #elseif FESTIVAL_MDF
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
        self.artistUrlDefault = "https://www.dropbox.com/scl/fi/6eg74y11n070airoewsfz/mdf_artistLineup_2026.csv?rlkey=35i20kxtc6pc6v673dnmp1465&raw=1"
        self.scheduleUrlDefault = "https://www.dropbox.com/scl/fi/3u1sr1312az0wd3dcpbfe/mdf_artistsSchedule2026_test.csv?rlkey=t96hj530o46q9fzz83ei7fllj&raw=1"
        
        self.logoUrl = "mdf_logo"
        self.shareUrl = "http://www.facebook.com/MDFBands"
        
        #else
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
        
        self.artistUrlDefault = "https://www.dropbox.com/s/5hcaxigzdj7fjrt/artistLineup.html?dl=1"
        self.scheduleUrlDefault = "https://www.dropbox.com/s/tg9qgt48ezp7udv/Schedule.csv?dl=1"
        
        self.logoUrl = "70000TonsLogo"
        self.shareUrl = "http://www.facebook.com/70kBands"
        #endif
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
}

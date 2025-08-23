//
//  ConfigurationTest.swift
//  Festival Bands
//
//  Created for testing configuration system
//  This file can be removed after verification
//

import Foundation

class ConfigurationTest {
    
    static func printCurrentConfiguration() {
        let config = FestivalConfig.current
        
        print("=== Current Festival Configuration ===")
        print("Festival Name: \(config.festivalName)")
        print("Short Name: \(config.festivalShortName)")
        print("App Name: \(config.appName)")
        print("Bundle ID: \(config.bundleIdentifier)")
        print("Storage URL: \(config.defaultStorageUrl)")
        print("Firebase Config: \(config.firebaseConfigFile)")
        print("Subscription Topic: \(config.subscriptionTopic)")
        print("Is MDF: \(config.isMDF())")
        print("Is 70K: \(config.is70K())")
        print("=====================================")
    }
    
    static func verifyConfiguration() -> Bool {
        let config = FestivalConfig.current
        
        // Basic validation
        guard !config.festivalName.isEmpty,
              !config.appName.isEmpty,
              !config.bundleIdentifier.isEmpty,
              !config.defaultStorageUrl.isEmpty else {
            print("❌ Configuration validation failed: Missing required values")
            return false
        }
        
        // URL validation
        guard URL(string: config.defaultStorageUrl) != nil else {
            print("❌ Configuration validation failed: Invalid storage URL")
            return false
        }
        
        // Festival-specific validation
        #if FESTIVAL_MDF
        guard config.isMDF() && !config.is70K() else {
            print("❌ Configuration validation failed: MDF flags incorrect")
            return false
        }
        guard config.defaultStorageUrl.contains("mdf_productionPointer") else {
            print("❌ Configuration validation failed: MDF should use MDF storage URL")
            return false
        }
        #elseif FESTIVAL_70K
        guard config.is70K() && !config.isMDF() else {
            print("❌ Configuration validation failed: 70K flags incorrect")
            return false
        }
        guard config.defaultStorageUrl.contains("productionPointer.txt") else {
            print("❌ Configuration validation failed: 70K should use 70K storage URL")
            return false
        }
        #endif
        
        print("✅ Configuration validation passed")
        return true
    }
}

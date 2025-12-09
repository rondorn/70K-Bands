//
//  ProfileColorManager.swift
//  70K Bands
//
//  Manages color assignments for shared preference profiles
//

import Foundation
import UIKit

class ProfileColorManager {
    static let shared = ProfileColorManager()
    
    // Vibrant colors that look good against black background
    // Colors rotate in order: Red, Green, Orange, Pink, Teal, Yellow
    private let availableColors: [UIColor] = [
        UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),      // White (Default only)
        UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0),      // Red
        UIColor(red: 0.2, green: 0.9, blue: 0.2, alpha: 1.0),      // Green
        UIColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 1.0),      // Orange
        UIColor(red: 1.0, green: 0.3, blue: 0.7, alpha: 1.0),      // Pink
        UIColor(red: 0.1, green: 0.9, blue: 0.9, alpha: 1.0),      // Teal
        UIColor(red: 1.0, green: 0.9, blue: 0.1, alpha: 1.0),      // Yellow
    ]
    
    private init() {}
    
    /// Get color for a profile (from SQLite or assigns one if not already assigned)
    func getColor(for profileKey: String) -> UIColor {
        // Default profile always gets white
        if profileKey == "Default" {
            return UIColor.white
        }
        
        // Try to get color from SQLite profile table
        if let profile = SQLiteProfileManager.shared.getProfile(userId: profileKey) {
            return colorFromHex(profile.color)
        }
        
        // If no profile found in SQLite, assign a new color
        // Check ALL existing profiles in SQLite to see what colors are already used
        let allProfiles = SQLiteProfileManager.shared.getAllProfiles()
        var usedColorIndices: Set<Int> = [0]  // 0 is white/default, always reserved
        
        // Collect all currently used color indices from SQLite by comparing hex strings
        for existingProfile in allProfiles {
            if existingProfile.userId == "Default" { continue }
            let existingColorHex = existingProfile.color.uppercased()
            
            // Compare with all available colors to find which index is being used
            for (index, color) in availableColors.enumerated() {
                let colorHex = getHexString(for: color).uppercased()
                if colorHex == existingColorHex {
                    usedColorIndices.insert(index)
                    break
                }
            }
        }
        
        // Find the next available color index (1-6, rotating)
        // Start at 1 to skip white (index 0)
        print("🎨 [COLOR] Assigning color for profile '\(profileKey)'")
        print("🎨 [COLOR] Used color indices: \(usedColorIndices.sorted())")
        
        var newIndex = 1
        while usedColorIndices.contains(newIndex) && newIndex < availableColors.count {
            newIndex += 1
        }
        
        // If all colors are used, cycle back through (1-6)
        if newIndex >= availableColors.count {
            // Count non-Default profiles and use modulo to cycle through colors
            let nonDefaultCount = allProfiles.filter { $0.userId != "Default" }.count
            newIndex = 1 + (nonDefaultCount % (availableColors.count - 1))
            print("🎨 [COLOR] All colors used, cycling to index \(newIndex)")
        }
        
        print("🎨 [COLOR] Assigned color index \(newIndex) (\(getColorName(newIndex))) to profile '\(profileKey)'")
        return availableColors[newIndex]
    }
    
    /// Get friendly name for color index (for logging)
    private func getColorName(_ index: Int) -> String {
        switch index {
        case 0: return "White"
        case 1: return "Red"
        case 2: return "Green"
        case 3: return "Orange"
        case 4: return "Pink"
        case 5: return "Teal"
        case 6: return "Yellow"
        default: return "Unknown"
        }
    }
    
    /// Convert hex string to UIColor
    private func colorFromHex(_ hex: String) -> UIColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat((rgb & 0x0000FF)) / 255.0
        
        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }
    
    /// Remove color assignment when profile is deleted (no-op since colors are in SQLite)
    func removeColor(for profileKey: String) {
        // Colors are now stored in SQLite, managed by SQLiteProfileManager
        // This function is kept for API compatibility but does nothing
        print("🎨 [COLOR] Color for '\(profileKey)' will be removed by SQLiteProfileManager")
    }
    
    /// Get hex string for a color (for debugging/display)
    func getHexString(for color: UIColor) -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}


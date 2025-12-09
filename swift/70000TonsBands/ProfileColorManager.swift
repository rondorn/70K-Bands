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
    private let availableColors: [UIColor] = [
        UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),      // White (Default)
        UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0),      // Sky Blue
        UIColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1.0),      // Pink
        UIColor(red: 0.5, green: 1.0, blue: 0.5, alpha: 1.0),      // Light Green
        UIColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 1.0),      // Gold
        UIColor(red: 0.8, green: 0.6, blue: 1.0, alpha: 1.0),      // Purple
        UIColor(red: 1.0, green: 0.6, blue: 0.3, alpha: 1.0),      // Orange
        UIColor(red: 0.4, green: 1.0, blue: 0.8, alpha: 1.0),      // Cyan
        UIColor(red: 1.0, green: 0.5, blue: 0.8, alpha: 1.0),      // Rose
        UIColor(red: 0.6, green: 0.9, blue: 1.0, alpha: 1.0),      // Baby Blue
    ]
    
    private let userDefaultsKey = "ProfileColorAssignments"
    
    private init() {}
    
    /// Get color for a profile (from SQLite or assigns one if not already assigned)
    func getColor(for profileKey: String) -> UIColor {
        // Try to get color from SQLite profile table
        if let profile = SQLiteProfileManager.shared.getProfile(userId: profileKey) {
            return colorFromHex(profile.color)
        }
        
        // Fallback: Default profile always gets white
        if profileKey == "Default" {
            return UIColor.white
        }
        
        // If no profile found, assign a new color (for temporary use before SQLite save)
        var assignments = getStoredAssignments()
        
        // If already assigned in legacy storage, return existing color
        if let colorIndex = assignments[profileKey] {
            return availableColors[colorIndex % availableColors.count]
        }
        
        // Assign a new color (skip index 0 which is white/default)
        let usedIndices = Set(assignments.values)
        var newIndex = 1  // Start at 1 to skip white
        
        // Find first unused color index
        while usedIndices.contains(newIndex) && newIndex < availableColors.count {
            newIndex += 1
        }
        
        // If all colors used, just cycle through
        if newIndex >= availableColors.count {
            newIndex = 1 + (assignments.count % (availableColors.count - 1))
        }
        
        return availableColors[newIndex]
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
    
    /// Remove color assignment when profile is deleted
    func removeColor(for profileKey: String) {
        var assignments = getStoredAssignments()
        assignments.removeValue(forKey: profileKey)
        saveAssignments(assignments)
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
    
    // MARK: - Private Storage
    
    private func getStoredAssignments() -> [String: Int] {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let assignments = try? JSONDecoder().decode([String: Int].self, from: data) {
            return assignments
        }
        return [:]
    }
    
    private func saveAssignments(_ assignments: [String: Int]) {
        if let data = try? JSONEncoder().encode(assignments) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            UserDefaults.standard.synchronize()
        }
    }
}


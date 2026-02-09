//
//  DeviceSizeManager.swift
//  70K Bands
//
//  Created by Cursor on 2/8/26.
//  Copyright (c) 2026 Ron Dorn. All rights reserved.
//

import UIKit
import SwiftUI

/// Centralized manager for determining if device has a large display (tablet) vs normal display (phone)
/// Recalculates on orientation changes and device folds to ensure accurate classification
class DeviceSizeManager: ObservableObject {
    static let shared = DeviceSizeManager()
    
    @Published private(set) var isLargeDisplay: Bool = false
    
    private var orientationObserver: NSObjectProtocol?
    
    private init() {
        // Calculate initial value
        updateDeviceSize()
        
        // Listen for orientation changes
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateDeviceSize()
        }
        
        // Also listen for trait collection changes (handles foldable devices, window size changes)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(traitCollectionDidChange),
            name: UIApplication.didChangeStatusBarOrientationNotification,
            object: nil
        )
    }
    
    deinit {
        if let observer = orientationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func traitCollectionDidChange() {
        updateDeviceSize()
    }
    
    /// Recalculates device size classification
    /// This is called automatically on orientation changes, but can be called manually if needed
    func updateDeviceSize() {
        let newValue = calculateIsLargeDisplay()
        if newValue != isLargeDisplay {
            isLargeDisplay = newValue
            print("📱 [DEVICE_SIZE] Device size updated: \(isLargeDisplay ? "Large Display" : "Normal Display")")
        }
    }
    
    /// Determines if the device has a large display (tablet) vs normal display (phone)
    /// Criteria can be changed here in one place
    private func calculateIsLargeDisplay() -> Bool {
        // Method 1: Check user interface idiom (iPad vs iPhone)
        // This is the primary indicator for iOS devices
        if UIDevice.current.userInterfaceIdiom == .pad {
            return true
        }
        
        // Method 2: Check screen size in points (accounts for orientation)
        // Get the current window scene to check actual display size
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let screenBounds = windowScene.screen.bounds
            let minDimension = min(screenBounds.width, screenBounds.height)
            
            // Large displays typically have minimum dimension >= 768 points in portrait
            // This catches iPad-sized devices even when rotated
            // Adjust this threshold (768) in one place to change the criteria
            let largeDisplayThreshold: CGFloat = 768.0
            
            if minDimension >= largeDisplayThreshold {
                return true
            }
        }
        
        // Method 3: Check trait collection for size class (handles foldable devices, window size)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            let traitCollection = window.traitCollection
            
            // Regular width size class indicates large display
            if traitCollection.horizontalSizeClass == .regular {
                return true
            }
        }
        
        return false
    }
    
    /// Convenience method for checking if device is large display
    /// Use this throughout the codebase instead of checking UIDevice.current.userInterfaceIdiom
    static func isLargeDisplay() -> Bool {
        return shared.isLargeDisplay
    }
}

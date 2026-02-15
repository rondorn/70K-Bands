//
//  UIConstants.swift
//  70K Bands
//
//  Created by Refactoring
//  Copyright (c) 2026 Ron Dorn. All rights reserved.
//

import UIKit

/// UI-related constants and utilities
struct UIConstants {
    
    // MARK: - Images
    static let chevronRight = UIImage(systemName: "chevron.right")
    static let chevronDown = UIImage(systemName: "chevron.down")
    
    // MARK: - Colors
    static let sawAllColor = hexStringToUIColor(hex: "#67C10C")
    static let sawSomeColor = hexStringToUIColor(hex: "#F0D905")
    static let sawNoneColor = hexStringToUIColor(hex: "#5DADE2")
    
    // MARK: - Status Strings
    static let sawAllStatus = "sawAll"
    static let sawSomeStatus = "sawSome"
    static let sawNoneStatus = "sawNone"
    
    // MARK: - Button Names
    static let officialSiteButtonName = "Offical Web Site"
    static let wikipediaButtonName = "Wikipedia"
    static let youTubeButtonName = "YouTube"
    static let metalArchivesButtonName = "Metal Archives"
    
    // MARK: - Alert Tracker
    /// Prevents alerts from being re-added all the time
    private static var _alertTracker = [String]()
    private static let alertTrackerQueue = DispatchQueue(label: "com.70kbands.alertTracker")
    
    static var alertTracker: [String] {
        get { alertTrackerQueue.sync { _alertTracker } }
        set { alertTrackerQueue.async(flags: .barrier) { _alertTracker = newValue } }
    }
    
    static func addToAlertTracker(_ value: String) {
        alertTrackerQueue.async(flags: .barrier) {
            if !_alertTracker.contains(value) {
                _alertTracker.append(value)
            }
        }
    }
    
    static func removeFromAlertTracker(_ value: String) {
        alertTrackerQueue.async(flags: .barrier) {
            _alertTracker.removeAll { $0 == value }
        }
    }
    
    static func clearAlertTracker() {
        alertTrackerQueue.async(flags: .barrier) {
            _alertTracker.removeAll()
        }
    }
}

// MARK: - Global Accessors (for backward compatibility)
var alertTracker: [String] {
    get { UIConstants.alertTracker }
    set { UIConstants.alertTracker = newValue }
}

let sawAllStatus: String = UIConstants.sawAllStatus
let sawSomeStatus: String = UIConstants.sawSomeStatus
let sawNoneStatus: String = UIConstants.sawNoneStatus

let sawAllColor: UIColor = UIConstants.sawAllColor
let sawSomeColor: UIColor = UIConstants.sawSomeColor
let sawNoneColor: UIColor = UIConstants.sawNoneColor

let chevronRight: UIImage? = UIConstants.chevronRight
let chevronDown: UIImage? = UIConstants.chevronDown

var officalSiteButtonName: String { UIConstants.officialSiteButtonName }
var wikipediaButtonName: String { UIConstants.wikipediaButtonName }
var youTubeButtonName: String { UIConstants.youTubeButtonName }
var metalArchivesButtonName: String { UIConstants.metalArchivesButtonName }

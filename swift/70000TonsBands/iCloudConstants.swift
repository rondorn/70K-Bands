//
//  iCloudConstants.swift
//  70K Bands
//
//  Created by Refactoring
//  Copyright (c) 2026 Ron Dorn. All rights reserved.
//

import Foundation

/// iCloud data type constants
struct iCloudConstants {
    static let priority = "priority"
    static let attended = "attended"
    static let note = "note"
}

// MARK: - Global Accessors (for backward compatibility)
var PRIORITY: String { iCloudConstants.priority }
var ATTENDED: String { iCloudConstants.attended }
var NOTE: String { iCloudConstants.note }

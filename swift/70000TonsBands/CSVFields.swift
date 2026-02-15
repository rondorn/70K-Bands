//
//  CSVFields.swift
//  70K Bands
//
//  Created by Refactoring
//  Copyright (c) 2026 Ron Dorn. All rights reserved.
//

import Foundation

/// CSV field name constants
struct CSVFields {
    static let type = "Type"
    static let show = "Show"
    static let band = "Band"
    static let location = "Location"
    static let day = "Day"
    static let date = "Date"
    static let startTime = "Start Time"
    static let endTime = "End Time"
    static let notes = "Notes"
    static let url = "URL"
    static let urlDate = "Date"
    static let descriptionUrl = "Description URL"
    static let imageUrl = "ImageURL"
    static let imageUrlDate = "ImageDate"
}

// MARK: - Global Accessors (for backward compatibility)
var typeField: String { CSVFields.type }
var showField: String { CSVFields.show }
var bandField: String { CSVFields.band }
var locationField: String { CSVFields.location }
var dayField: String { CSVFields.day }
var dateField: String { CSVFields.date }
var startTimeField: String { CSVFields.startTime }
var endTimeField: String { CSVFields.endTime }
var notesField: String { CSVFields.notes }
var urlField: String { CSVFields.url }
var urlDateField: String { CSVFields.urlDate }
var descriptionUrlField: String { CSVFields.descriptionUrl }
var imageUrlField: String { CSVFields.imageUrl }
var imageUrlDateField: String { CSVFields.imageUrlDate }

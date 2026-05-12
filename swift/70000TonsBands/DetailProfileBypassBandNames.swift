//
//  DetailProfileBypassBandNames.swift
//  70K Bands
//
//  Schedule-only or special events that do not use full band CSV profile fields.
//  Names must match the display name used in the schedule / detail navigation exactly.
//

import Foundation

enum DetailProfileBypassBandNames {

    /// Add entries here when an event should not trigger “essential profile” loading or background hydration.
    private static let displayNames: Set<String> = [
        "70000 Karaoke",
    ]

    static func shouldBypassEssentialProfileLoad(displayName: String) -> Bool {
        displayNames.contains(displayName)
    }
}

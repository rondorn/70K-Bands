//
//  DataIntegrityTag.swift
//  Internal suite metadata helpers (shared festival app builds).
//

import Foundation

enum DataIntegrityTag {
    private static let k: UInt8 = 0x2A

    static func suiteDisplayLabel() -> String {
        let values: [UInt8] = [
            122, 69, 93, 79, 88, 79, 78, 10, 104, 83, 10,
            101, 90, 79, 68, 10, 103, 79, 94, 75, 70, 10,
            108, 79, 89, 94, 10, 121, 95, 67, 94, 79
        ]
        return String(values.map { Character(UnicodeScalar($0 ^ k)) })
    }
}

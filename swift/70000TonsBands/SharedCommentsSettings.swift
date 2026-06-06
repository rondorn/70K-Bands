//
//  SharedCommentsSettings.swift
//  70K Bands
//
//  Shared band description submission settings and eligibility helpers.
//

import Foundation

enum SharedCommentsSettings {

    private static let termsAcceptedKey = "SharedCommentsTermsAccepted"
    private static let usernameKey = "SharedCommentsUsername"

    static var hasAcceptedTerms: Bool {
        UserDefaults.standard.bool(forKey: termsAcceptedKey)
    }

    static func setTermsAccepted() {
        UserDefaults.standard.set(true, forKey: termsAcceptedKey)
        UserDefaults.standard.synchronize()
    }

    static var username: String? {
        let value = UserDefaults.standard.string(forKey: usernameKey) ?? ""
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func setUsername(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: usernameKey)
        UserDefaults.standard.synchronize()
    }

    /// Reads `Current::enableSharedComments::YES` from the cached pointer file.
    static func loadEnableSharedComments() {
        let value = readPointerCurrentValue(key: "enableSharedComments") ?? ""
        enableSharedComments = value.uppercased() == "YES"
        print("📝 [SHARED_COMMENTS] enableSharedComments = \(enableSharedComments)")
    }

    static func canOfferPostToAllUsers(bandName: String, bandNotes: String) -> Bool {
        guard enableSharedComments else { return false }
        guard !bandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }

        let bandDesc = CustomBandDescription()
        guard !bandDesc.isBandInDescriptionMap(bandName: bandName) else { return false }

        return isNoteTextEligibleForSharedSubmit(bandNotes, bandName: bandName)
    }

    static func isNoteTextEligibleForSharedSubmit(_ notes: String, bandName: String) -> Bool {
        if notes.starts(with: FestivalConfig.current.getDefaultDescriptionText()) {
            return false
        }
        if notes.count < 2 {
            return false
        }

        let bandDesc = CustomBandDescription()
        if bandDesc.custMatchesDefault(customNote: notes, bandName: bandName) {
            return false
        }

        return true
    }

    static func isValidUsername(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 && trimmed.count <= 24
    }

    // MARK: - Pointer file parsing

    private static func readPointerCurrentValue(key: String) -> String? {
        let cachedPointerFile = getDocumentsDirectory().appendingPathComponent("cachedPointerData.txt")
        guard FileManager.default.fileExists(atPath: cachedPointerFile) else {
            return nil
        }

        do {
            let content = try String(contentsOfFile: cachedPointerFile, encoding: .utf8)
            if content.isEmpty { return nil }

            for rawLine in content.components(separatedBy: "\n") {
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                if line.isEmpty { continue }

                if line.hasPrefix("Current::\(key)::") {
                    let components = line.components(separatedBy: "::")
                    if components.count >= 3 {
                        return components[2].trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }

                let components = line.components(separatedBy: "::")
                if components.count >= 3,
                   components[0].trimmingCharacters(in: .whitespacesAndNewlines) == "Current",
                   components[1].trimmingCharacters(in: .whitespacesAndNewlines) == key {
                    return components[2].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        } catch {
            print("📝 [SHARED_COMMENTS] Failed to read pointer file: \(error)")
        }

        return nil
    }
}

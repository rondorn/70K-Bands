//
//  BandDescriptionTranslator.swift
//  70K Bands
//
//  Created by AI Assistant for localization feature
//

import Foundation
import Translation
import SwiftUI
import NaturalLanguage
import UIKit

/// Handles translation and language preference management for band descriptions
@available(iOS 18.0, *)
class BandDescriptionTranslator {
    
    static let shared = BandDescriptionTranslator()
    
    // Language preference storage
    private let languagePreferenceKey = "BandDescriptionLanguagePreference"
    
    // Current user's language preference (EN or local language code)
    var currentLanguagePreference: String {
        get {
            return UserDefaults.standard.string(forKey: languagePreferenceKey) ?? "EN"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: languagePreferenceKey)
        }
    }
    
    /// Tracks which bands have been translated (bandName -> true if translated)
    private var translatedBands: [String: Bool] {
        get {
            return UserDefaults.standard.dictionary(forKey: "TranslatedBands") as? [String: Bool] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "TranslatedBands")
        }
    }
    
    /// Checks if a band has ever been translated
    func hasBandBeenTranslated(_ bandName: String) -> Bool {
        let normalizedName = normalizeBandName(bandName)
        return translatedBands[normalizedName] ?? false
    }
    
    /// Marks a band as having been translated
    func markBandAsTranslated(_ bandName: String) {
        let normalizedName = normalizeBandName(bandName)
        var bands = translatedBands
        bands[normalizedName] = true
        translatedBands = bands
    }
    
    /// Checks if the current text is in English or translated state
    func isCurrentTextTranslated(for bandName: String) -> Bool {
        return currentLanguagePreference != "EN" && hasBandBeenTranslated(bandName)
    }
    
    private init() {}
    
    /// Checks if translation is supported for the current device language
    /// Only available on iOS 18.0+ with Apple Translation framework
    func isTranslationSupported() -> Bool {
        let userLanguage = Locale.current.languageCode ?? "en"
        let supportedLanguages = ["de", "nl", "fr", "fi", "pt", "es"] // German, Dutch, French, Finnish, Portuguese, Spanish
        
        // Only show translation feature if user's language is supported and is not English
        return supportedLanguages.contains(userLanguage) && userLanguage != "en"
    }
    
    /// Checks if a specific language pair is available using Apple's LanguageAvailability
    func checkLanguageAvailability(from sourceLanguage: String, to targetLanguage: String) async -> Bool {
        let source = Locale.Language(identifier: sourceLanguage)
        let target = Locale.Language(identifier: targetLanguage)
        
        let availability = LanguageAvailability()
        let status = await availability.status(from: source, to: target)
        
        switch status {
        case .installed, .supported:
            print("DEBUG: Language pair \(sourceLanguage) -> \(targetLanguage) is available")
            return true
        case .unsupported:
            print("DEBUG: Language pair \(sourceLanguage) -> \(targetLanguage) is unsupported")
            return false
        @unknown default:
            print("DEBUG: Unknown status for language pair \(sourceLanguage) -> \(targetLanguage)")
            return false
        }
    }
    
    /// Checks if Apple Translation framework is available (iOS 18.0+)
    func isRealTranslationAvailable() -> Bool {
        return isTranslationSupported()
    }
    
    /// Checks if translation is available for a specific language pair
    func isTranslationAvailable(from sourceLanguage: String, to targetLanguage: String) -> Bool {
        // Check if the language pair is supported by Apple's Translation framework
        let source = Locale.Language(identifier: sourceLanguage)
        let target = Locale.Language(identifier: targetLanguage)
        
        // For now, we'll assume common European languages are supported
        // In a real implementation, you might want to check TranslationSession.supportedLanguages
        let supportedLanguages = ["en", "de", "es", "fr", "pt", "da", "fi", "it", "nl", "sv", "no"]
        
        return supportedLanguages.contains(sourceLanguage.lowercased()) && 
               supportedLanguages.contains(targetLanguage.lowercased()) &&
               sourceLanguage != targetLanguage
    }
    
    /// Gets the current user's language code (2-letter format)
    func getCurrentLanguageCode() -> String {
        let userLanguage = Locale.current.languageCode ?? "en"
        let supportedLanguages = ["de", "nl", "fr", "fi", "pt", "es"] // German, Dutch, French, Finnish, Portuguese, Spanish
        
        return supportedLanguages.contains(userLanguage) ? userLanguage.uppercased() : "EN"
    }
    
    /// Gets the filename for a localized description based on language preference
    func getLocalizedFileName(bandName: String, languageCode: String, bandDescriptionUrlDate: [String: String]) -> String {
        let normalizedBandName = normalizeBandName(bandName)
        
        if languageCode == "EN" {
            // Return English filename
            if bandDescriptionUrlDate.keys.contains(normalizedBandName) {
                return bandName + "_comment.note-" + bandDescriptionUrlDate[normalizedBandName]!
            } else {
                return bandName + "_comment.note-cust"
            }
        } else {
            // For translated versions, add language suffix
            if bandDescriptionUrlDate.keys.contains(normalizedBandName) {
                let baseFileName = bandName + "_comment.note-" + bandDescriptionUrlDate[normalizedBandName]!
                return baseFileName + "-" + languageCode
            } else {
                return bandName + "_comment.note-cust-" + languageCode
            }
        }
    }
    

    
    /// Shows Apple's native translation using SwiftUI translationTask (iOS 18.0+ only)
    /// Uses hidden SwiftUI view to perform translation, saves result to disk
    func showTranslationOverlay(for textView: UITextView, in viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        
        let targetLanguageCode = getCurrentLanguageCode()
        guard targetLanguageCode != "EN" else {
            completion(false)
            return
        }
        
        // Extract band name from view controller if it's a DetailViewController
        guard let bandName = (viewController as? DetailViewController)?.bandName else {
            completion(false)
            return
        }
        
        let originalText = textView.text ?? ""
        guard !originalText.isEmpty else {
            completion(false)
            return
        }
        
        print("DEBUG: About to translate text for band: \(bandName) from EN to \(targetLanguageCode)")
        
        // Check if the language pair is actually supported by Apple
        Task {
            let isAvailable = await checkLanguageAvailability(from: "en", to: targetLanguageCode.lowercased())
            
            await MainActor.run {
                guard isAvailable else {
                    print("DEBUG: Language pair EN -> \(targetLanguageCode) is not available")
                    let alert = UIAlertController(
                        title: "Translation Not Available",
                        message: "Translation from English to \(getLanguageName(for: targetLanguageCode)) is not available on this device.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    viewController.present(alert, animated: true)
                    completion(false)
                    return
                }
                
                // Language pair is available, proceed with translation
                let hostingController = SwiftUITranslationHostingController(
                    sourceText: originalText,
                    bandName: bandName,
                    targetLanguage: targetLanguageCode
                ) { [weak self, weak textView] success in
                    DispatchQueue.main.async {
                        if success {
                            // Load the translated text from disk
                            self?.loadTranslatedTextFromDisk(for: bandName, targetLanguage: targetLanguageCode) { translatedText in
                                if let translatedText = translatedText {
                                    textView?.text = translatedText
                                    print("DEBUG: Successfully loaded translated text for \(bandName)")
                                }
                            }
                        }
                        completion(success)
                    }
                }
                
                // Add the hosting controller as a child (but invisible)
                viewController.addChild(hostingController)
                viewController.view.addSubview(hostingController.view)
                hostingController.didMove(toParent: viewController)
                
                // Remove after a delay to allow translation to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    hostingController.willMove(toParent: nil)
                    hostingController.view.removeFromSuperview()
                    hostingController.removeFromParent()
                }
            }
        }
    }
    
    /// Loads translated text from disk
    func loadTranslatedTextFromDisk(for bandName: String, targetLanguage: String, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Get the documents directory
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                
                // Create filename for translated text
                let normalizedBandName = self.normalizeBandName(bandName)
                let fileName = "\(normalizedBandName)_comment.note-translated-\(targetLanguage.uppercased())"
                let fileURL = documentsPath.appendingPathComponent(fileName)
                
                // Load from disk
                let translatedText = try String(contentsOf: fileURL, encoding: .utf8)
                
                DispatchQueue.main.async {
                    completion(translatedText)
                }
                
            } catch {
                print("DEBUG: Could not load translated text from disk: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    /// Checks if a translated cache file exists for the given band and language
    func hasTranslatedCacheFile(for bandName: String, targetLanguage: String) -> Bool {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let normalizedBandName = normalizeBandName(bandName)
        let fileName = "\(normalizedBandName)_comment.note-translated-\(targetLanguage.uppercased())"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        let exists = FileManager.default.fileExists(atPath: fileURL.path)
        print("DEBUG: Translated cache file \(fileName) exists: \(exists)")
        return exists
    }
    
    /// Deletes translated cache file from disk
    func deleteTranslatedCacheFromDisk(for bandName: String, targetLanguage: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Get the documents directory
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                
                // Create filename for translated text
                let normalizedBandName = self.normalizeBandName(bandName)
                let fileName = "\(normalizedBandName)_comment.note-translated-\(targetLanguage.uppercased())"
                let fileURL = documentsPath.appendingPathComponent(fileName)
                
                // Delete the file if it exists
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                    print("DEBUG: Deleted translated cache file: \(fileName)")
                } else {
                    print("DEBUG: Translated cache file does not exist: \(fileName)")
                }
                
            } catch {
                print("ERROR: Could not delete translated cache file: \(error)")
            }
        }
    }
    

    


    
    /// Gets the full language name for a language code
    private func getLanguageName(for code: String) -> String {
        switch code.lowercased() {
        case "de": return "German" 
        case "nl": return "Dutch"
        case "fr": return "French"
        case "fi": return "Finnish"
        case "pt": return "Portuguese"
        case "es": return "Spanish"
        default: return code.uppercased()
        }
    }
    
    /// Gets localized button text for "Translate Note to [Language]"
    func getLocalizedTranslateButtonText(for languageCode: String) -> String {
        switch languageCode.lowercased() {
        case "de": return "Notiz ins Deutsche übersetzen"
        case "nl": return "Notitie naar het Nederlands vertalen"
        case "fr": return "Traduire la note en français"
        case "fi": return "Käännä muistiinpano suomeksi"
        case "pt": return "Traduzir nota para português"
        case "es": return "Traducir nota al español"
        default: return "Translate Note to \(getLanguageName(for: languageCode))"
        }
    }
    
    /// Gets localized button text for "Restore Note to English"
    func getLocalizedRestoreButtonText(for languageCode: String) -> String {
        switch languageCode.lowercased() {
        case "de": return "Notiz auf Englisch wiederherstellen"
        case "nl": return "Notitie terugzetten naar Engels"
        case "fr": return "Restaurer la note en anglais"
        case "fi": return "Palauta muistiinpano englanniksi"
        case "pt": return "Restaurar nota para inglês"
        case "es": return "Restaurar nota al inglés"
        default: return "Restore Note to English"
        }
    }
    
    /// Gets "Translated from English" text in the target language
    func getTranslatedFromEnglishText(for languageCode: String) -> String {
        switch languageCode.lowercased() {
        case "de": return "Aus dem Englischen übersetzt"
        case "nl": return "Vertaald uit het Engels"
        case "fr": return "Traduit de l'anglais"
        case "fi": return "Käännetty englannista"
        case "pt": return "Traduzido do inglês"
        case "es": return "Traducido del inglés"
        default: return "Translated from English"
        }
    }
    
    /// Gets description in the preferred language, translating if necessary
    func getDescriptionInPreferredLanguage(englishText: String, bandName: String, completion: @escaping (String?) -> Void) {
        
        let preferredLanguage = currentLanguagePreference
        
        // With the new overlay approach, we always return the English text
        // Translation is handled through the overlay UI
        completion(englishText)
    }
    
    /// Normalizes a band name by removing invisible Unicode characters and trimming whitespace.
    /// - Parameter bandName: The band name to normalize.
    /// - Returns: The normalized band name.
    func normalizeBandName(_ bandName: String) -> String {
        // Remove invisible Unicode characters and normalize
        let normalized = bandName.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "⁦", with: "") // Remove left-to-right mark
            .replacingOccurrences(of: "⁧", with: "") // Remove right-to-left mark
            .replacingOccurrences(of: "\u{200E}", with: "") // Remove left-to-right mark
            .replacingOccurrences(of: "\u{200F}", with: "") // Remove right-to-left mark
            .replacingOccurrences(of: "\u{202A}", with: "") // Remove left-to-right embedding
            .replacingOccurrences(of: "\u{202B}", with: "") // Remove right-to-left embedding
            .replacingOccurrences(of: "\u{202C}", with: "") // Remove pop directional formatting
            .replacingOccurrences(of: "\u{202D}", with: "") // Remove left-to-right override
            .replacingOccurrences(of: "\u{202E}", with: "") // Remove right-to-left override
            .replacingOccurrences(of: "\u{2066}", with: "") // Remove left-to-right isolate
            .replacingOccurrences(of: "\u{2067}", with: "") // Remove right-to-left isolate
            .replacingOccurrences(of: "\u{2068}", with: "") // Remove first strong isolate
            .replacingOccurrences(of: "\u{2069}", with: "") // Remove pop directional isolate
        
        return normalized
    }
}





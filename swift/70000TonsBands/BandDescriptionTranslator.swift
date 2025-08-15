//
//  BandDescriptionTranslator.swift
//  70K Bands
//

import Foundation
import Translation

@available(iOS 18.0, *)
class BandDescriptionTranslator: ObservableObject {
    static let shared = BandDescriptionTranslator()
    
    @Published var currentLanguagePreference: String = "EN"
    
    private var translatedDescriptions: [String: [String: String]] = [:]
    private var englishDescriptions: [String: String] = [:]
    
    private init() {
        loadCachedData()
    }
    
    func isTranslationSupported() -> Bool {
        // Check iOS version first
        guard #available(iOS 18.0, *) else {
            print("DEBUG: Translation not supported - iOS version < 18.0")
            return false
        }
        
        // Check if system language is English
        let currentLangCode = getCurrentLanguageCode()
        if currentLangCode == "EN" {
            print("DEBUG: Translation not supported - system language is English")
            return false
        }
        
        // Check if current language is in our supported list
        let supportedLanguages = ["ES", "FR", "DE", "PT", "DA", "FI"]
        let isSupported = supportedLanguages.contains(currentLangCode)
        
        if !isSupported {
            print("DEBUG: Translation not supported - language '\(currentLangCode)' not in supported list: \(supportedLanguages)")
        } else {
            print("DEBUG: Translation is supported - language '\(currentLangCode)' is supported")
        }
        
        return isSupported
    }
    
    func getCurrentLanguageCode() -> String {
        let locale = Locale.current
        let languageCode = locale.language.languageCode?.identifier.uppercased() ?? "EN"
        
        switch languageCode {
        case "ES": return "ES"
        case "FR": return "FR"
        case "DE": return "DE"
        case "PT": return "PT"
        case "DA": return "DA"
        case "FI": return "FI"
        default: return "EN"
        }
    }
    
    func getLanguageDisplayName(for code: String) -> String {
        switch code {
        case "ES": return "Español"
        case "FR": return "Français"
        case "DE": return "Deutsch"
        case "PT": return "Português"
        case "DA": return "Dansk"
        case "FI": return "Suomi"
        default: return "English"
        }
    }
    
    func storeEnglishDescription(for bandName: String, text: String) {
        englishDescriptions[bandName] = text
        saveCachedData()
    }
    
    func getEnglishDescription(for bandName: String) -> String? {
        return englishDescriptions[bandName]
    }
    
    func storeTranslatedDescription(for bandName: String, languageCode: String, text: String) {
        if translatedDescriptions[bandName] == nil {
            translatedDescriptions[bandName] = [:]
        }
        translatedDescriptions[bandName]?[languageCode] = text
        saveCachedData()
    }
    
    func getTranslatedDescription(for bandName: String, languageCode: String) -> String? {
        return translatedDescriptions[bandName]?[languageCode]
    }
    
    func hasTranslatedCacheFile(for bandName: String, targetLanguage: String) -> Bool {
        return translatedDescriptions[bandName]?[targetLanguage] != nil
    }
    
    func getUserPreferredLanguage(for bandName: String) -> String {
        let key = "TranslationPreference_\(bandName)"
        return UserDefaults.standard.string(forKey: key) ?? "EN"
    }
    
    func setUserPreferredLanguage(for bandName: String, languageCode: String) {
        let key = "TranslationPreference_\(bandName)"
        UserDefaults.standard.set(languageCode, forKey: key)
    }
    
    func clearTranslation(for bandName: String, languageCode: String) {
        translatedDescriptions[bandName]?[languageCode] = nil
        saveCachedData()
    }
    
    private func loadCachedData() {
        if let data = UserDefaults.standard.data(forKey: "TranslatedDescriptions"),
           let decoded = try? JSONDecoder().decode([String: [String: String]].self, from: data) {
            translatedDescriptions = decoded
        }
        
        if let data = UserDefaults.standard.data(forKey: "EnglishDescriptions"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            englishDescriptions = decoded
        }
    }
    
    private func saveCachedData() {
        if let encoded = try? JSONEncoder().encode(translatedDescriptions) {
            UserDefaults.standard.set(encoded, forKey: "TranslatedDescriptions")
        }
        
        if let encoded = try? JSONEncoder().encode(englishDescriptions) {
            UserDefaults.standard.set(encoded, forKey: "EnglishDescriptions")
        }
    }
    
    // MARK: - Master Branch Compatibility Methods
    
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
    
    /// Gets "Translated from English" text in the target language
    func getTranslatedFromEnglishText(for languageCode: String) -> String {
        switch languageCode.lowercased() {
        case "es": return "Traducido del inglés"
        case "fr": return "Traduit de l'anglais"
        case "de": return "Aus dem Englischen übersetzt"
        case "pt": return "Traduzido do inglês"
        case "da": return "Oversat fra engelsk"
        case "fi": return "Käännetty englannista"
        default: return "Translated from English"
        }
    }
    
    /// Gets localized button text for "Translate Note to [Language]"
    func getLocalizedTranslateButtonText(for languageCode: String) -> String {
        switch languageCode.lowercased() {
        case "de": return "Notiz ins Deutsche übersetzen"
        case "fr": return "Traduire la note en français"
        case "es": return "Traducir nota al español"
        case "pt": return "Traduzir nota para português"
        case "da": return "Oversæt note til dansk"
        case "fi": return "Käännä muistiinpano suomeksi"
        default: return "Translate Note to \(getLanguageDisplayName(for: languageCode))"
        }
    }
    
    /// Gets localized button text for "Restore Note to English"
    func getLocalizedRestoreButtonText(for languageCode: String) -> String {
        switch languageCode.lowercased() {
        case "de": return "Notiz auf Englisch wiederherstellen"
        case "fr": return "Restaurer la note en anglais"
        case "es": return "Restaurar nota al inglés"
        case "pt": return "Restaurar nota para inglês"
        case "da": return "Gendan note til engelsk"
        case "fi": return "Palauta muistiinpano englanniksi"
        default: return "Restore Note to English"
        }
    }
    
    /// Gets localized "Translating..." toast message
    func getTranslatingMessage(for languageCode: String) -> String {
        switch languageCode.lowercased() {
        case "de": return "🔄 Übersetzen..."
        case "fr": return "🔄 Traduction..."
        case "es": return "🔄 Traduciendo..."
        case "pt": return "🔄 Traduzindo..."
        case "da": return "🔄 Oversætter..."
        case "fi": return "🔄 Käännetään..."
        default: return "🔄 Translating..."
        }
    }
    
    /// Gets localized "Translated to [Language]" success message
    func getTranslatedSuccessMessage(for languageCode: String) -> String {
        let langName = getLanguageDisplayName(for: languageCode)
        switch languageCode.lowercased() {
        case "de": return "✅ Ins Deutsche übersetzt"
        case "fr": return "✅ Traduit en français"
        case "es": return "✅ Traducido al español"
        case "pt": return "✅ Traduzido para português"
        case "da": return "✅ Oversat til dansk"
        case "fi": return "✅ Käännetty suomeksi"
        default: return "✅ Translated to \(langName)"
        }
    }
    
    /// Gets localized "Translation failed" error message
    func getTranslationFailedMessage(for languageCode: String) -> String {
        switch languageCode.lowercased() {
        case "de": return "❌ Übersetzung fehlgeschlagen"
        case "fr": return "❌ Échec de la traduction"
        case "es": return "❌ Falló la traducción"
        case "pt": return "❌ Falha na tradução"
        case "da": return "❌ Oversættelse mislykkedes"
        case "fi": return "❌ Käännös epäonnistui"
        default: return "❌ Translation failed"
        }
    }
    
    /// Gets localized "Restored to English" success message
    func getRestoredToEnglishMessage(for languageCode: String) -> String {
        switch languageCode.lowercased() {
        case "de": return "✅ Auf Englisch wiederhergestellt"
        case "fr": return "✅ Restauré en anglais"
        case "es": return "✅ Restaurado al inglés"
        case "pt": return "✅ Restaurado para inglês"
        case "da": return "✅ Gendannet til engelsk"
        case "fi": return "✅ Palautettu englanniksi"
        default: return "✅ Restored to English"
        }
    }
    
    /// Normalizes a band name by removing invisible Unicode characters and trimming whitespace.
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
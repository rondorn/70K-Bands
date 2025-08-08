//
//  SwiftUITranslationHelper.swift
//  70K Bands
//
//  Created by AI Assistant for iOS 18+ Translation
//

import SwiftUI
import Translation

/// Hidden SwiftUI view that handles translation using the official translationTask pattern
/// Results are saved to disk for UIKit views to load
@available(iOS 18.0, *)
struct SwiftUITranslationHelper: View {
    
    let sourceText: String
    let bandName: String
    let targetLanguage: String
    let onTranslationComplete: (Bool) -> Void
    
    @State private var targetText: String?
    @State private var configuration: TranslationSession.Configuration?
    @State private var hasStartedTranslation = false
    
    var translationBatch: [TranslationSession.Request] {
        [TranslationSession.Request(sourceText: sourceText, clientIdentifier: bandName)]
    }
    
    var body: some View {
        // Hidden view - zero size
        Color.clear
            .frame(width: 0, height: 0)
            .translationTask(configuration) { session in
                do {
                    print("DEBUG: Starting translation for band: \(bandName)")
                    print("DEBUG: Source text preview: \(String(sourceText.prefix(100)))...")
                    print("DEBUG: Target language: \(targetLanguage)")
                    
                    for try await response in session.translate(batch: translationBatch) {
                        let rawTranslatedText = response.targetText
                        print("DEBUG: Translated text for \(response.clientIdentifier ?? "unknown"): \(rawTranslatedText)")
                        
                        // Add "Translated from English" header in the target language
                        let translatedFromEnglishText = BandDescriptionTranslator.shared.getTranslatedFromEnglishText(for: targetLanguage)
                        let finalTranslatedText = "\(translatedFromEnglishText)\n\n\(rawTranslatedText)"
                        
                        // Save translated text to disk
                        await saveTranslatedTextToDisk(translatedText: finalTranslatedText, bandName: bandName, targetLanguage: targetLanguage)
                        
                        // Update state
                        await MainActor.run {
                            self.targetText = finalTranslatedText
                            self.onTranslationComplete(true)
                        }
                    }
                } catch {
                    print("Translation error: \(error.localizedDescription)")
                    await MainActor.run {
                        self.onTranslationComplete(false)
                    }
                }
            }
            .onAppear {
                // Trigger translation when view appears
                if !hasStartedTranslation {
                    hasStartedTranslation = true
                    startTranslation()
                }
            }
    }
    
    private func startTranslation() {
        // Create explicit language configuration to avoid auto-detection issues
        if configuration == nil {
            let sourceLanguage = Locale.Language(identifier: "en") // Always English source
            let targetLanguageIdentifier = targetLanguage.lowercased()
            let targetLang = Locale.Language(identifier: targetLanguageIdentifier)
            
            configuration = TranslationSession.Configuration(
                source: sourceLanguage,
                target: targetLang
            )
            print("DEBUG: Created translation configuration EN -> \(targetLanguageIdentifier)")
            return
        }
        
        configuration?.invalidate()
    }
    
    private func saveTranslatedTextToDisk(translatedText: String, bandName: String, targetLanguage: String) async {
        do {
            // Get the documents directory
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            
            // Create filename for translated text
            let normalizedBandName = BandDescriptionTranslator.shared.normalizeBandName(bandName)
            let fileName = "\(normalizedBandName)_comment.note-translated-\(targetLanguage.uppercased())"
            let fileURL = documentsPath.appendingPathComponent(fileName)
            
            // Save to disk
            try translatedText.write(to: fileURL, atomically: true, encoding: .utf8)
            print("DEBUG: Saved translated text to: \(fileURL.lastPathComponent)")
            
            // Mark band as translated
            await MainActor.run {
                BandDescriptionTranslator.shared.markBandAsTranslated(bandName)
                BandDescriptionTranslator.shared.currentLanguagePreference = targetLanguage.uppercased()
            }
            
        } catch {
            print("ERROR: Failed to save translated text: \(error)")
        }
    }
}

/// UIKit wrapper to host the SwiftUI translation helper
@available(iOS 18.0, *)
class SwiftUITranslationHostingController: UIHostingController<SwiftUITranslationHelper> {
    
    init(sourceText: String, bandName: String, targetLanguage: String, onTranslationComplete: @escaping (Bool) -> Void) {
        let translationHelper = SwiftUITranslationHelper(
            sourceText: sourceText,
            bandName: bandName,
            targetLanguage: targetLanguage,
            onTranslationComplete: onTranslationComplete
        )
        super.init(rootView: translationHelper)
        
        // Make the hosting controller invisible
        view.backgroundColor = .clear
        view.isHidden = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

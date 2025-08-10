package com.Bands70k;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;

import com.google.android.gms.tasks.OnFailureListener;
import com.google.android.gms.tasks.OnSuccessListener;
import com.google.mlkit.common.model.DownloadConditions;
import com.google.mlkit.common.model.RemoteModelManager;
import com.google.mlkit.nl.languageid.LanguageIdentification;
import com.google.mlkit.nl.languageid.LanguageIdentifier;
import com.google.mlkit.nl.translate.TranslateLanguage;
import com.google.mlkit.nl.translate.Translation;
import com.google.mlkit.nl.translate.Translator;
import com.google.mlkit.nl.translate.TranslatorOptions;

import static com.Bands70k.staticVariables.context;

import java.io.File;
import java.io.FileOutputStream;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

/**
 * Handles translation of band descriptions using Google ML Kit Translation API.
 * Provides similar functionality to the iOS BandDescriptionTranslator.
 * Created by rdorn on 2024.
 */
public class BandDescriptionTranslator {
    
    private static final String TAG = "BandDescriptionTranslator";
    private static BandDescriptionTranslator instance;
    
    // Preferences
    private static final String PREFS_NAME = "BandTranslationPrefs";
    private static final String PREF_CURRENT_LANGUAGE = "currentLanguagePreference";
    private static final String PREF_TRANSLATED_BANDS = "translatedBands";
    
    // User preference tracking
    private static final String USER_PREFS_DIR = "band_language_prefs";
    
    // Supported languages (matching iOS implementation)
    private static final Set<String> SUPPORTED_LANGUAGES = new HashSet<>(Arrays.asList(
        "de", "es", "fr", "pt", "da", "fi"
    ));
    
    // Language code mapping for ML Kit
    private static final Map<String, String> LANGUAGE_CODE_MAP = new HashMap<>();
    static {
        LANGUAGE_CODE_MAP.put("de", TranslateLanguage.GERMAN);
        LANGUAGE_CODE_MAP.put("es", TranslateLanguage.SPANISH);
        LANGUAGE_CODE_MAP.put("fr", TranslateLanguage.FRENCH);
        LANGUAGE_CODE_MAP.put("pt", TranslateLanguage.PORTUGUESE);
        LANGUAGE_CODE_MAP.put("da", TranslateLanguage.DANISH);
        LANGUAGE_CODE_MAP.put("fi", TranslateLanguage.FINNISH);
    }
    
    private Context context;
    private SharedPreferences preferences;
    private LanguageIdentifier languageIdentifier;
    private Map<String, Translator> translators;
    
    private BandDescriptionTranslator(Context context) {
        this.context = context.getApplicationContext();
        this.preferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        this.languageIdentifier = LanguageIdentification.getClient();
        this.translators = new HashMap<>();
    }
    
    public static synchronized BandDescriptionTranslator getInstance(Context context) {
        if (instance == null) {
            instance = new BandDescriptionTranslator(context);
        }
        return instance;
    }
    
    /**
     * Gets the current language preference
     */
    public String getCurrentLanguagePreference() {
        return preferences.getString(PREF_CURRENT_LANGUAGE, "EN");
    }
    
    /**
     * Sets the current language preference
     */
    public void setCurrentLanguagePreference(String languageCode) {
        preferences.edit().putString(PREF_CURRENT_LANGUAGE, languageCode).apply();
    }
    
    /**
     * Gets the current device language code
     */
    public String getCurrentLanguageCode() {
        String deviceLanguage = Locale.getDefault().getLanguage().toLowerCase();
        Log.d(TAG, "Device language detected: " + deviceLanguage);
        Log.d(TAG, "Supported languages: " + SUPPORTED_LANGUAGES.toString());
        Log.d(TAG, "Contains check: SUPPORTED_LANGUAGES.contains('" + deviceLanguage + "') = " + SUPPORTED_LANGUAGES.contains(deviceLanguage));
        
        String result = SUPPORTED_LANGUAGES.contains(deviceLanguage) ? deviceLanguage : "en";
        Log.d(TAG, "Returning language code: " + result);
        return result;
    }
    
    /**
     * Checks if translation is supported for the current device language
     */
    public boolean isTranslationSupported() {
        String currentLang = getCurrentLanguageCode();
        boolean supported = !currentLang.equals("en") && SUPPORTED_LANGUAGES.contains(currentLang);
        Log.d(TAG, "Translation supported for " + currentLang + ": " + supported);
        return supported;
    }
    
    /**
     * Checks if a band has been translated before
     */
    public boolean hasBandBeenTranslated(String bandName) {
        Set<String> translatedBands = preferences.getStringSet(PREF_TRANSLATED_BANDS, new HashSet<>());
        return translatedBands.contains(normalizeBandName(bandName));
    }
    
    /**
     * Marks a band as translated
     */
    public void markBandAsTranslated(String bandName) {
        Set<String> translatedBands = new HashSet<>(preferences.getStringSet(PREF_TRANSLATED_BANDS, new HashSet<>()));
        translatedBands.add(normalizeBandName(bandName));
        preferences.edit().putStringSet(PREF_TRANSLATED_BANDS, translatedBands).apply();
    }
    
    /**
     * Checks if the current text is translated by comparing with original English
     */
    public boolean isCurrentTextTranslated(String text, String originalEnglishText) {
        if (text == null || text.trim().isEmpty()) {
            return false;
        }
        
        if (originalEnglishText == null || originalEnglishText.trim().isEmpty()) {
            return false;
        }
        
        // If the text is different from the original English, it's likely translated
        return !text.trim().equals(originalEnglishText.trim());
    }
    
    /**
     * Checks if a band has been translated before
     */
    public boolean isBandTranslated(String bandName) {
        String currentLang = getCurrentLanguagePreference();
        return !currentLang.equals("EN") && hasBandBeenTranslated(bandName);
    }
    
    /**
     * Checks if a cached translation exists for a band in the current language
     */
    public boolean hasCachedTranslation(String bandName) {
        String currentLang = getCurrentLanguageCode();
        if (currentLang.equals("en")) {
            return false; // No translation needed for English
        }
        
        return getCachedTranslation(bandName, currentLang) != null;
    }
    
    /**
     * Saves the user's preferred language for a specific band
     */
    public void saveUserLanguagePreference(String bandName, String languageCode) {
        try {
            File prefsDir = new File(context.getFilesDir(), USER_PREFS_DIR);
            if (!prefsDir.exists()) {
                prefsDir.mkdirs();
            }
            
            String fileName = normalizeBandName(bandName) + "_lang_pref.txt";
            File prefFile = new File(prefsDir, fileName);
            
            FileOutputStream fos = new FileOutputStream(prefFile);
            fos.write(languageCode.getBytes("UTF-8"));
            fos.close();
            
            Log.d(TAG, "Saved language preference for " + bandName + ": " + languageCode);
        } catch (IOException e) {
            Log.e(TAG, "Error saving language preference for " + bandName, e);
        }
    }
    
    /**
     * Gets the user's preferred language for a specific band
     */
    public String getUserLanguagePreference(String bandName) {
        try {
            File prefsDir = new File(context.getFilesDir(), USER_PREFS_DIR);
            if (!prefsDir.exists()) {
                return null; // No preferences saved yet
            }
            
            String fileName = normalizeBandName(bandName) + "_lang_pref.txt";
            File prefFile = new File(prefsDir, fileName);
            
            if (!prefFile.exists()) {
                return null; // No preference saved for this band
            }
            
            FileInputStream fis = new FileInputStream(prefFile);
            byte[] data = new byte[(int) prefFile.length()];
            fis.read(data);
            fis.close();
            
            String savedLanguage = new String(data, "UTF-8");
            Log.d(TAG, "Retrieved language preference for " + bandName + ": " + savedLanguage);
            return savedLanguage;
        } catch (IOException e) {
            Log.e(TAG, "Error reading language preference for " + bandName, e);
            return null;
        }
    }
    
    /**
     * Checks if user prefers translated content for this band
     */
    public boolean shouldShowTranslatedContent(String bandName) {
        String userPref = getUserLanguagePreference(bandName);
        if (userPref == null) {
            return false; // Default to English if no preference saved
        }
        
        String currentLang = getCurrentLanguageCode();
        boolean shouldTranslate = userPref.equals(currentLang) && !currentLang.equals("en");
        Log.d(TAG, "Should show translated content for " + bandName + ": " + shouldTranslate + 
              " (user pref: " + userPref + ", current lang: " + currentLang + ")");
        return shouldTranslate;
    }
    
    /**
     * Gets localized button text for "Translate Note to [Language]"
     */
    public String getLocalizedTranslateButtonText(String languageCode) {
        switch (languageCode.toLowerCase()) {
            case "de": return "Notiz ins Deutsche übersetzen";
            case "es": return "Traducir nota al español";
            case "fr": return "Traduire la note en français";
            case "pt": return "Traduzir nota para português";
            case "da": return "Oversæt note til dansk";
            case "fi": return "Käännä muistiinpano suomeksi";
            default: return "Translate Note to " + getLanguageName(languageCode);
        }
    }
    
    /**
     * Gets localized button text for "Restore Note to English"
     */
    public String getLocalizedRestoreButtonText(String languageCode) {
        switch (languageCode.toLowerCase()) {
            case "de": return "Notiz auf Englisch wiederherstellen";
            case "es": return "Restaurar nota al inglés";
            case "fr": return "Restaurer la note en anglais";
            case "pt": return "Restaurar nota para inglês";
            case "da": return "Gendan note til engelsk";
            case "fi": return "Palauta muistiinpano englanniksi";
            default: return "Restore Note to English";
        }
    }
    
    /**
     * Gets full language name from code
     */
    public String getLanguageName(String languageCode) {
        switch (languageCode.toLowerCase()) {
            case "de": return "German";
            case "es": return "Spanish";
            case "fr": return "French";
            case "pt": return "Portuguese";
            case "da": return "Danish";
            case "fi": return "Finnish";
            default: return languageCode.toUpperCase();
        }
    }
    
    /**
     * Gets localized message for translation completion
     */
    public String getLocalizedTranslationCompleteMessage(String languageCode) {
        switch (languageCode.toLowerCase()) {
            case "de": return "Ins Deutsche übersetzt";
            case "es": return "Traducido al español";
            case "fr": return "Traduit en français";
            case "pt": return "Traduzido para português";
            case "da": return "Oversat til dansk";
            case "fi": return "Käännetty suomeksi";
            default: return "Translated";
        }
    }
    
    /**
     * Gets localized message for restore completion
     */
    public String getLocalizedRestoreCompleteMessage(String languageCode) {
        switch (languageCode.toLowerCase()) {
            case "de": return "Auf Englisch wiederhergestellt";
            case "es": return "Restaurado al inglés";
            case "fr": return "Restauré en anglais";
            case "pt": return "Restaurado para inglês";
            case "da": return "Gendan til engelsk";
            case "fi": return "Palautettu englanniksi";
            default: return "Restored to English";
        }
    }
    
    /**
     * Gets localized "Translation from English" header text
     */
    public String getLocalizedTranslationHeaderText(String languageCode) {
        switch (languageCode.toLowerCase()) {
            case "de": return "Übersetzung aus dem Englischen";
            case "es": return "Traducción del inglés";
            case "fr": return "Traduction de l'anglais";
            case "pt": return "Tradução do inglês";
            case "da": return "Oversættelse fra engelsk";
            case "fi": return "Käännös englannista";
            default: return "Translation from English";
        }
    }
    
    /**
     * Gets localized message for downloading translation model
     */
    public String getLocalizedDownloadingModelMessage(String languageCode) {
        switch (languageCode.toLowerCase()) {
            case "de": return "Deutsches Übersetzungsmodell wird heruntergeladen... Dies kann einen Moment dauern.";
            case "es": return "Descargando modelo de traducción al español... Esto puede tomar un momento.";
            case "fr": return "Téléchargement du modèle de traduction française... Cela peut prendre un moment.";
            case "pt": return "Baixando modelo de tradução português... Isso pode levar um momento.";
            case "da": return "Downloader dansk oversættelsesmodel... Dette kan tage et øjeblik.";
            case "fi": return "Ladataan suomenkielistä käännösmallia... Tämä voi kestää hetken.";
            default: return "Downloading translation model... This may take a moment.";
        }
    }
    
    /**
     * Gets localized message for when model download is completed
     */
    public String getLocalizedModelDownloadCompleteMessage(String languageCode) {
        switch (languageCode.toLowerCase()) {
            case "de": return "Deutsches Übersetzungsmodell heruntergeladen. Übersetzung wird gestartet...";
            case "es": return "Modelo de traducción al español descargado. Iniciando traducción...";
            case "fr": return "Modèle de traduction française téléchargé. Démarrage de la traduction...";
            case "pt": return "Modelo de tradução português baixado. Iniciando tradução...";
            case "da": return "Dansk oversættelsesmodel downloadet. Starter oversættelse...";
            case "fi": return "Suomenkielinen käännösmalli ladattu. Aloitetaan käännös...";
            default: return "Translation model downloaded. Starting translation...";
        }
    }
    
    /**
     * Simple post-translation formatting cleanup
     * Only applies safe formatting improvements without risking translation functionality
     */
    public String cleanupTranslatedTextFormatting(String translatedText) {
        if (translatedText == null || translatedText.trim().isEmpty()) {
            return translatedText;
        }
        
        // Very conservative formatting cleanup
        // Only fix obvious formatting issues that are safe to modify
        String cleaned = translatedText
            // Normalize multiple spaces to single spaces
            .replaceAll("\\s+", " ")
            // Fix spacing around periods
            .replaceAll("\\s+\\.", ".")
            // Fix spacing after periods
            .replaceAll("\\.(?! )", ". ")
            // Trim whitespace
            .trim();
        
        return cleaned;
    }
    
    /**
     * Translates text in paragraph chunks to preserve formatting
     * 1. Split English text into paragraph chunks
     * 2. Translate each chunk separately
     * 3. Reconstruct with proper carriage returns
     */
    private void translateTextInParagraphChunks(String text, String targetLanguageCode, String bandName, TranslationCallback callback) {
        translateTextInParagraphChunks(text, targetLanguageCode, bandName, callback, false);
    }
    
    /**
     * Translates text with proper paragraph preservation using chunking approach
     * @param showToast whether to show toast messages for download progress (only for user-initiated translations)
     */
    private void translateTextInParagraphChunks(String text, String targetLanguageCode, String bandName, TranslationCallback callback, boolean showToast) {
        Log.d(TAG, "Starting chunk-based paragraph translation for " + bandName + " (showToast: " + showToast + ")");
        Log.d(TAG, "Original text length: " + text.length());
        Log.d(TAG, "Original text contains \\n\\n: " + text.contains("\n\n"));
        Log.d(TAG, "Original text contains \\n: " + text.contains("\n"));
        Log.d(TAG, "First 500 chars with visible newlines: " + text.substring(0, Math.min(500, text.length())).replace("\n", "[\\n]").replace("\r", "[\\r]"));
        
        // Step 1: Split English text into paragraph chunks
        List<String> paragraphChunks = splitIntoParagraphChunks(text);
        
        if (paragraphChunks.isEmpty()) {
            Log.d(TAG, "ERROR: No paragraphs found, using fallback translation - THIS SHOULD NOT HAPPEN");
            performTranslationWithFallback(text, targetLanguageCode, bandName, callback);
            return;
        }
        
        if (paragraphChunks.size() == 1) {
            Log.d(TAG, "Single paragraph detected, but still applying newline formatting");
            // Still use chunking approach to apply newline formatting
        }
        
        Log.d(TAG, "Found " + paragraphChunks.size() + " paragraph chunks to translate");
        for (int i = 0; i < paragraphChunks.size(); i++) {
            Log.d(TAG, "Chunk " + i + ": [" + paragraphChunks.get(i).substring(0, Math.min(100, paragraphChunks.get(i).length())) + "]");
        }
        
        // Step 2 & 3: Translate each chunk and reconstruct
        translateChunksSequentially(paragraphChunks, targetLanguageCode, bandName, 0, new ArrayList<>(), callback, showToast);
    }
    
    /**
     * Splits text into paragraph chunks based on single carriage returns
     */
    private List<String> splitIntoParagraphChunks(String text) {
        List<String> chunks = new ArrayList<>();
        
        // Split on single carriage returns (\n)
        if (text.contains("\n")) {
            String[] parts = text.split("\n");
            for (String part : parts) {
                String trimmed = part.trim();
                if (!trimmed.isEmpty()) {
                    chunks.add(trimmed);
                }
            }
            Log.d(TAG, "Split by single newlines into " + chunks.size() + " chunks");
        } else {
            // No line breaks found, treat as single chunk
            chunks.add(text.trim());
            Log.d(TAG, "No line breaks found, single chunk");
        }
        
        return chunks;
    }
    
    /**
     * Splits continuous text into logical paragraph chunks based on sentence patterns
     * This handles cases where the raw text has no line breaks but should be displayed as paragraphs
     */
    private List<String> splitBySentencePatterns(String text) {
        List<String> chunks = new ArrayList<>();
        
        // Split by sentence endings followed by capital letters (likely paragraph boundaries)
        // Look for patterns like ". [Capital letter]" which often indicate new paragraphs
        String[] sentences = text.split("\\. (?=[A-Z])");
        
        if (sentences.length <= 1) {
            // If no clear sentence boundaries, return as single chunk
            chunks.add(text.trim());
            return chunks;
        }
        
        // Group sentences into logical paragraphs
        // For now, treat each major sentence as a potential paragraph
        for (int i = 0; i < sentences.length; i++) {
            String sentence = sentences[i].trim();
            if (!sentence.isEmpty()) {
                // Add the period back except for the last sentence
                if (i < sentences.length - 1 && !sentence.endsWith(".")) {
                    sentence += ".";
                }
                chunks.add(sentence);
            }
        }
        
        Log.d(TAG, "Split by sentence patterns: " + sentences.length + " sentences into " + chunks.size() + " chunks");
        return chunks;
    }
    
    /**
     * Translates chunks sequentially and reconstructs with paragraph formatting
     */
        private void translateChunksSequentially(List<String> chunks, String targetLanguageCode, String bandName,
                                            int currentIndex, List<String> translatedChunks, TranslationCallback callback, boolean showToast) {
        if (currentIndex >= chunks.size()) {
            // All chunks translated - assemble with double newlines between segments
            StringBuilder result = new StringBuilder();
            Log.d(TAG, "Assembling " + translatedChunks.size() + " translated chunks with double newlines");
            
            for (int i = 0; i < translatedChunks.size(); i++) {
                if (i > 0) {
                    result.append("\n\n"); // Add double carriage returns between each segment
                    Log.d(TAG, "Added double newlines between chunks " + (i-1) + " and " + i);
                }
                result.append(translatedChunks.get(i));
                Log.d(TAG, "Added chunk " + i + ": " + translatedChunks.get(i).substring(0, Math.min(100, translatedChunks.get(i).length())));
            }
            
            String assembledResult = result.toString();
            Log.d(TAG, "Before cleanup: " + assembledResult.replace("\n", "[\\n]").substring(0, Math.min(200, assembledResult.length())));
            
            // Clean up excessive carriage returns - shrink more than 2 continuous returns down to 2
            String cleanedResult = assembledResult.replaceAll("\n{3,}", "\n\n");
            
            Log.d(TAG, "After cleanup: " + cleanedResult.replace("\n", "[\\n]").substring(0, Math.min(200, cleanedResult.length())));
            Log.d(TAG, "Chunk translation complete for " + bandName + ", " + chunks.size() + " chunks assembled");
            Log.d(TAG, "Cleaned up excessive newlines: " + assembledResult.length() + " -> " + cleanedResult.length() + " chars");
            
            // Cache the final result to filesystem
            cacheTranslation(bandName, targetLanguageCode, cleanedResult);
            
            // Return the properly formatted result
            callback.onTranslationComplete(cleanedResult);
            return;
        }
        
        String currentChunk = chunks.get(currentIndex);
        Log.d(TAG, "Translating chunk " + (currentIndex + 1) + "/" + chunks.size() + ": " + 
              currentChunk.substring(0, Math.min(100, currentChunk.length())));
        
        // Translate current chunk using ML Kit
        String mlKitLanguageCode = LANGUAGE_CODE_MAP.get(targetLanguageCode.toLowerCase());
        TranslatorOptions options = new TranslatorOptions.Builder()
            .setSourceLanguage(TranslateLanguage.ENGLISH)
            .setTargetLanguage(mlKitLanguageCode)
            .build();
        
        Translator translator = Translation.getClient(options);
        
        // Check if model is already available before showing download message
        RemoteModelManager modelManager = RemoteModelManager.getInstance();
        com.google.mlkit.nl.translate.TranslateRemoteModel model = 
            new com.google.mlkit.nl.translate.TranslateRemoteModel.Builder(mlKitLanguageCode).build();
            
        modelManager.isModelDownloaded(model)
            .addOnSuccessListener(isDownloaded -> {
                // Show download toast only if model needs to be downloaded and this is user-initiated
                if (showToast && !isDownloaded && context != null) {
                    String downloadMessage = getLocalizedDownloadingModelMessage(targetLanguageCode);
                    android.widget.Toast.makeText(context, downloadMessage, android.widget.Toast.LENGTH_LONG).show();
                }
                
                // Proceed with download if needed
                DownloadConditions conditions = new DownloadConditions.Builder()
                    .requireWifi() // Download only on WiFi for large models
                    .build();
                    
                translator.downloadModelIfNeeded(conditions)
                    .addOnSuccessListener(unused -> {
                        // Show completion message only if model was actually downloaded
                        if (showToast && !isDownloaded && currentIndex == 0 && context != null) {
                            String completeMessage = getLocalizedModelDownloadCompleteMessage(targetLanguageCode);
                            android.widget.Toast.makeText(context, completeMessage, android.widget.Toast.LENGTH_SHORT).show();
                        }
                        Log.d(TAG, "Translation model ready for chunk " + (currentIndex + 1));
                // Now translate the chunk
                translator.translate(currentChunk)
                    .addOnSuccessListener(translatedChunk -> {
                        Log.d(TAG, "Successfully translated chunk " + (currentIndex + 1) + ": " + 
                              translatedChunk.substring(0, Math.min(100, translatedChunk.length())));
                        
                        translatedChunks.add(translatedChunk.trim());
                        
                        // Continue with next chunk
                        translateChunksSequentially(chunks, targetLanguageCode, bandName, currentIndex + 1, translatedChunks, callback, showToast);
                    })
                    .addOnFailureListener(e -> {
                        Log.e(TAG, "Failed to translate chunk " + (currentIndex + 1) + ": " + e.getMessage());
                        
                        // Add untranslated chunk and continue
                        translatedChunks.add(currentChunk);
                        translateChunksSequentially(chunks, targetLanguageCode, bandName, currentIndex + 1, translatedChunks, callback, showToast);
                    });
                })
                .addOnFailureListener(e -> {
                    Log.e(TAG, "Failed to download translation model for chunk " + (currentIndex + 1) + ": " + e.getMessage());
                    
                    // Add untranslated chunk and continue
                    translatedChunks.add(currentChunk);
                    translateChunksSequentially(chunks, targetLanguageCode, bandName, currentIndex + 1, translatedChunks, callback, showToast);
                });
            })
            .addOnFailureListener(e -> {
                Log.e(TAG, "Failed to check if model is downloaded for chunk " + (currentIndex + 1) + ": " + e.getMessage());
                
                // Fallback: proceed without toast message
                DownloadConditions conditions = new DownloadConditions.Builder()
                    .requireWifi()
                    .build();
                    
                translator.downloadModelIfNeeded(conditions)
                    .addOnSuccessListener(unused -> {
                        Log.d(TAG, "Translation model ready for chunk " + (currentIndex + 1));
                        translator.translate(currentChunk)
                            .addOnSuccessListener(translatedChunk -> {
                                translatedChunks.add(translatedChunk.trim());
                                translateChunksSequentially(chunks, targetLanguageCode, bandName, currentIndex + 1, translatedChunks, callback, showToast);
                            })
                            .addOnFailureListener(ex -> {
                                Log.e(TAG, "Failed to translate chunk " + (currentIndex + 1) + ": " + ex.getMessage());
                                translatedChunks.add(currentChunk);
                                translateChunksSequentially(chunks, targetLanguageCode, bandName, currentIndex + 1, translatedChunks, callback, showToast);
                            });
                    })
                    .addOnFailureListener(ex -> {
                        Log.e(TAG, "Failed to download translation model for chunk " + (currentIndex + 1) + ": " + ex.getMessage());
                        translatedChunks.add(currentChunk);
                        translateChunksSequentially(chunks, targetLanguageCode, bandName, currentIndex + 1, translatedChunks, callback, showToast);
                    });
            });
    }
    
    /**
     * Interface for translation completion callback
     */
    public interface TranslationCallback {
        void onTranslationComplete(String translatedText);
        void onTranslationError(String error);
    }
    
    /**
     * Interface for bulk translation progress callback
     */
    public interface BulkTranslationCallback {
        void onProgress(int completed, int total);
        void onComplete();
        void onError(String error);
    }
    
    /**
     * Translates text directly using ML Kit - works offline if model is cached
     */
    public void translateTextDirectly(String text, String targetLanguageCode, String bandName, TranslationCallback callback) {
        translateTextDirectly(text, targetLanguageCode, bandName, callback, null);
    }
    
    /**
     * Translates text directly using ML Kit with optional toast context for download messages
     */
    public void translateTextDirectly(String text, String targetLanguageCode, String bandName, TranslationCallback callback, Context toastContext) {
        if (targetLanguageCode.equals("EN") || targetLanguageCode.equals("en")) {
            callback.onTranslationComplete(text);
            return;
        }
        
        String mlKitLanguageCode = LANGUAGE_CODE_MAP.get(targetLanguageCode.toLowerCase());
        if (mlKitLanguageCode == null) {
            callback.onTranslationError("Unsupported language: " + targetLanguageCode);
            return;
        }
        
        // Check if we have a cached translation (for offline use)
        String cachedTranslation = getCachedTranslation(bandName, targetLanguageCode);
        if (cachedTranslation != null) {
            Log.d(TAG, "Using cached offline translation for " + bandName);
            callback.onTranslationComplete(cachedTranslation);
            return;
        }
        

        
        // Use proper chunking approach: split into paragraph chunks, translate each, reconstruct
        translateTextInParagraphChunks(text, targetLanguageCode, bandName, callback, true); // Show toast for user-initiated translations
    }
    
    /**
     * Translates text with proper paragraph preservation using segmentation approach
     */
    private void translateWithParagraphPreservation(String text, String targetLanguageCode, String bandName, TranslationCallback callback) {
        Log.d(TAG, "Starting paragraph preservation translation for " + bandName);
        Log.d(TAG, "Original text preview: " + text.substring(0, Math.min(300, text.length())).replace("\n", "\\n"));
        
        // Step 1: Try different paragraph splitting strategies
        String[] segments = null;
        String separator = null;
        
        // First try double newlines
        if (text.contains("\n\n")) {
            segments = text.split("\\n\\n");
            separator = "\n\n";
            Log.d(TAG, "Using double newline separator, found " + segments.length + " segments");
        } 
        // Then try single newlines (common in many text formats)
        else if (text.contains("\n")) {
            // Split by single newlines and group into logical paragraphs
            String[] lines = text.split("\\n");
            segments = groupConsecutiveNonEmptyLines(lines);
            separator = "\n\n"; // We'll use double newlines in output for better readability
            Log.d(TAG, "Using single newline grouping, found " + segments.length + " paragraph groups");
        }
        
        if (segments == null || segments.length <= 1) {
            // No paragraph breaks found, use regular translation
            Log.d(TAG, "No paragraph structure detected, using regular translation");
            performTranslationWithFallback(text, targetLanguageCode, bandName, callback);
            return;
        }
        
        // Step 2: Translate each segment individually and Step 3: Reconstruct with formatting
        translateSegmentsSequentially(segments, targetLanguageCode, bandName, 0, new ArrayList<>(), separator, callback);
    }
    
    /**
     * Groups consecutive non-empty lines into logical paragraphs
     */
    private String[] groupConsecutiveNonEmptyLines(String[] lines) {
        List<String> paragraphs = new ArrayList<>();
        StringBuilder currentParagraph = new StringBuilder();
        
        for (String line : lines) {
            String trimmedLine = line.trim();
            
            if (trimmedLine.isEmpty()) {
                // Empty line - end current paragraph if it exists
                if (currentParagraph.length() > 0) {
                    paragraphs.add(currentParagraph.toString().trim());
                    currentParagraph = new StringBuilder();
                }
            } else {
                // Non-empty line - add to current paragraph
                if (currentParagraph.length() > 0) {
                    currentParagraph.append("\n"); // Preserve line breaks within paragraphs
                }
                currentParagraph.append(trimmedLine);
            }
        }
        
        // Add final paragraph if exists
        if (currentParagraph.length() > 0) {
            paragraphs.add(currentParagraph.toString().trim());
        }
        
        Log.d(TAG, "Grouped " + lines.length + " lines into " + paragraphs.size() + " paragraphs");
        return paragraphs.toArray(new String[0]);
    }
    
    /**
     * Translates text segments sequentially and reconstructs with original paragraph formatting
     */
    private void translateSegmentsSequentially(String[] segments, String targetLanguageCode, String bandName, 
                                             int currentIndex, List<String> translatedSegments, String separator, TranslationCallback callback) {
        if (currentIndex >= segments.length) {
            // All segments translated - reconstruct with paragraph formatting
            StringBuilder result = new StringBuilder();
            for (int i = 0; i < translatedSegments.size(); i++) {
                if (i > 0) {
                    result.append(separator); // Re-insert paragraph breaks between segments
                }
                result.append(translatedSegments.get(i));
            }
            
            String finalResult = result.toString();
            Log.d(TAG, "Paragraph preservation complete for " + bandName + ", final length: " + finalResult.length());
            
            // Cache the result and return
            cacheTranslation(bandName, targetLanguageCode, finalResult);
            callback.onTranslationComplete(finalResult);
            return;
        }
        
        String currentSegment = segments[currentIndex].trim();
        
        // Skip empty segments but maintain position
        if (currentSegment.isEmpty()) {
            translatedSegments.add("");
            translateSegmentsSequentially(segments, targetLanguageCode, bandName, currentIndex + 1, translatedSegments, separator, callback);
            return;
        }
        
        Log.d(TAG, "Translating segment " + (currentIndex + 1) + "/" + segments.length + ": " + 
              currentSegment.substring(0, Math.min(100, currentSegment.length())));
        
        // Translate current segment using ML Kit
        String mlKitLanguageCode = LANGUAGE_CODE_MAP.get(targetLanguageCode.toLowerCase());
        TranslatorOptions options = new TranslatorOptions.Builder()
            .setSourceLanguage(TranslateLanguage.ENGLISH)
            .setTargetLanguage(mlKitLanguageCode)
            .build();
        
        Translator translator = Translation.getClient(options);
        
        translator.translate(currentSegment)
            .addOnSuccessListener(translatedSegment -> {
                Log.d(TAG, "Successfully translated segment " + (currentIndex + 1) + ": " + 
                      translatedSegment.substring(0, Math.min(100, translatedSegment.length())));
                
                translatedSegments.add(translatedSegment.trim());
                
                // Continue with next segment
                translateSegmentsSequentially(segments, targetLanguageCode, bandName, currentIndex + 1, translatedSegments, separator, callback);
            })
            .addOnFailureListener(e -> {
                Log.e(TAG, "Failed to translate segment " + (currentIndex + 1) + ": " + e.getMessage());
                
                // Add untranslated segment and continue
                translatedSegments.add(currentSegment);
                translateSegmentsSequentially(segments, targetLanguageCode, bandName, currentIndex + 1, translatedSegments, separator, callback);
            });
    }
    
    /**
     * Translates paragraphs one by one to preserve structure
     */
    private void translateParagraphsSequentially(String[] paragraphs, String targetLanguageCode, String bandName, 
                                               int currentIndex, StringBuilder result, TranslationCallback callback) {
        if (currentIndex >= paragraphs.length) {
            // All paragraphs translated, return result without language marker
            String finalResult = result.toString();
            cacheTranslation(bandName, targetLanguageCode, finalResult);
            callback.onTranslationComplete(finalResult);
            return;
        }
        
        String currentParagraph = paragraphs[currentIndex].trim();
        
        // Skip empty paragraphs but preserve spacing
        if (currentParagraph.isEmpty()) {
            if (result.length() > 0) {
                result.append("\n\n");
            }
            translateParagraphsSequentially(paragraphs, targetLanguageCode, bandName, currentIndex + 1, result, callback);
            return;
        }
        
        // Translate current paragraph
        String mlKitLanguageCode = LANGUAGE_CODE_MAP.get(targetLanguageCode.toLowerCase());
        TranslatorOptions options = new TranslatorOptions.Builder()
            .setSourceLanguage(TranslateLanguage.ENGLISH)
            .setTargetLanguage(mlKitLanguageCode)
            .build();
        
        Translator translator = Translation.getClient(options);
        
        translator.translate(currentParagraph)
            .addOnSuccessListener(translatedParagraph -> {
                // Add paragraph with proper spacing - always use double newlines between paragraphs
                if (result.length() > 0) {
                    result.append("\n\n");
                }
                result.append(translatedParagraph.trim());
                
                Log.d(TAG, "Translated paragraph " + currentIndex + ": " + translatedParagraph.substring(0, Math.min(100, translatedParagraph.length())));
                
                // Continue with next paragraph
                translateParagraphsSequentially(paragraphs, targetLanguageCode, bandName, currentIndex + 1, result, callback);
            })
            .addOnFailureListener(e -> {
                Log.e(TAG, "Failed to translate paragraph " + currentIndex + ": " + e.getMessage());
                // Add untranslated paragraph and continue
                if (result.length() > 0) {
                    result.append("\n\n");
                }
                result.append(currentParagraph);
                translateParagraphsSequentially(paragraphs, targetLanguageCode, bandName, currentIndex + 1, result, callback);
            });
    }
    
    /**
     * Performs translation with offline fallback
     */
    private void performTranslationWithFallback(String text, String targetLanguageCode, String bandName, TranslationCallback callback) {
        String mlKitLanguageCode = LANGUAGE_CODE_MAP.get(targetLanguageCode.toLowerCase());
        
        // Create translator options
        TranslatorOptions options = new TranslatorOptions.Builder()
            .setSourceLanguage(TranslateLanguage.ENGLISH)
            .setTargetLanguage(mlKitLanguageCode)
            .build();
        
        Translator translator = Translation.getClient(options);
        
        // Try translation directly (works offline if model is downloaded)
        translator.translate(text)
            .addOnSuccessListener(new OnSuccessListener<String>() {
                @Override
                public void onSuccess(String translatedText) {
                    // Add language marker to the beginning
                    String markedTranslation = "[" + targetLanguageCode.toUpperCase() + "] " + translatedText;
                    
                    // Cache the translation for future offline use
                    cacheTranslation(bandName, targetLanguageCode, markedTranslation);
                    
                    Log.d(TAG, "Translation successful for " + bandName);
                    callback.onTranslationComplete(markedTranslation);
                }
            })
            .addOnFailureListener(new OnFailureListener() {
                @Override
                public void onFailure(@NonNull Exception e) {
                    Log.e(TAG, "Translation failed: " + e.getMessage());
                    // If translation fails (no network/model), try to download model
                    downloadModelAndTranslate(translator, text, targetLanguageCode, bandName, callback);
                }
            });
    }
    
    /**
     * Downloads model and translates (requires network)
     */
    private void downloadModelAndTranslate(Translator translator, String text, String targetLanguageCode, String bandName, TranslationCallback callback) {
        DownloadConditions conditions = new DownloadConditions.Builder()
            .build(); // Remove requireWifi() to allow cellular download when at sea
            
        translator.downloadModelIfNeeded(conditions)
            .addOnSuccessListener(new OnSuccessListener<Void>() {
                @Override
                public void onSuccess(Void unused) {
                    // Model downloaded, now translate
                    performTranslation(translator, text, targetLanguageCode, bandName, callback);
                }
            })
            .addOnFailureListener(new OnFailureListener() {
                @Override
                public void onFailure(@NonNull Exception e) {
                    Log.e(TAG, "Model download failed", e);
                    callback.onTranslationError("Translation unavailable offline. Model download failed: " + e.getMessage());
                }
            });
    }
    
    /**
     * Ensures translation model is downloaded for offline use
     */
    public void ensureTranslationModelDownloaded(TranslationCallback callback) {
        String userLanguage = getCurrentLanguageCode();
        if (!isTranslationSupported()) {
            Log.d(TAG, "Translation not supported for language: " + userLanguage);
            if (callback != null) {
                callback.onTranslationError("Translation not supported for language: " + userLanguage);
            }
            return;
        }
        
        // Additional performance check: don't download if English
        if ("en".equals(userLanguage)) {
            Log.d(TAG, "English language detected, no translation model needed");
            if (callback != null) {
                callback.onTranslationError("No translation needed for English");
            }
            return;
        }
        
        String mlKitLanguageCode = LANGUAGE_CODE_MAP.get(userLanguage.toLowerCase());
        if (mlKitLanguageCode == null) {
            Log.e(TAG, "Unsupported language code: " + userLanguage);
            if (callback != null) {
                callback.onTranslationError("Unsupported language: " + userLanguage);
            }
            return;
        }
        
        // Create translator options
        TranslatorOptions options = new TranslatorOptions.Builder()
            .setSourceLanguage(TranslateLanguage.ENGLISH)
            .setTargetLanguage(mlKitLanguageCode)
            .build();
        
        Translator translator = Translation.getClient(options);
        
        // Download model for offline use
        DownloadConditions conditions = new DownloadConditions.Builder()
            .build(); // Allow cellular download
            
        Log.d(TAG, "Ensuring translation model is downloaded for " + userLanguage);
        translator.downloadModelIfNeeded(conditions)
            .addOnSuccessListener(new OnSuccessListener<Void>() {
                @Override
                public void onSuccess(Void unused) {
                    Log.d(TAG, "Translation model ready for offline use: " + userLanguage);
                    if (callback != null) {
                        callback.onTranslationComplete("Model downloaded successfully");
                    }
                }
            })
            .addOnFailureListener(new OnFailureListener() {
                @Override
                public void onFailure(@NonNull Exception e) {
                    Log.e(TAG, "Failed to download translation model for " + userLanguage + ": " + e.getMessage());
                    if (callback != null) {
                        callback.onTranslationError("Model download failed: " + e.getMessage());
                    }
                }
            });
    }
    
    /**
     * Pre-caches translations for offline use during getAllDescriptions
     */
    public void preCacheTranslationsForOffline(Map<String, String> bandDescriptions, BulkTranslationCallback callback) {
        String userLanguage = getCurrentLanguageCode();
        if (!isTranslationSupported()) {
            Log.d(TAG, "Translation not supported for language: " + userLanguage);
            callback.onComplete();
            return;
        }
        
        String mlKitLanguageCode = LANGUAGE_CODE_MAP.get(userLanguage.toLowerCase());
        if (mlKitLanguageCode == null) {
            callback.onError("Unsupported language: " + userLanguage);
            return;
        }
        
        // Create translator options
        TranslatorOptions options = new TranslatorOptions.Builder()
            .setSourceLanguage(TranslateLanguage.ENGLISH)
            .setTargetLanguage(mlKitLanguageCode)
            .build();
        
        Translator translator = Translation.getClient(options);
        
        // First ensure the model is downloaded
        DownloadConditions conditions = new DownloadConditions.Builder()
            .build(); // Allow cellular download
            
        translator.downloadModelIfNeeded(conditions)
            .addOnSuccessListener(new OnSuccessListener<Void>() {
                @Override
                public void onSuccess(Void unused) {
                    Log.d(TAG, "Translation model downloaded, starting bulk translation");
                    performBulkTranslation(translator, bandDescriptions, userLanguage, callback);
                }
            })
            .addOnFailureListener(new OnFailureListener() {
                @Override
                public void onFailure(@NonNull Exception e) {
                    Log.e(TAG, "Failed to download translation model for bulk caching", e);
                    callback.onError("Failed to download translation model: " + e.getMessage());
                }
            });
    }
    
    /**
     * Performs bulk translation for offline caching
     */
    private void performBulkTranslation(Translator translator, Map<String, String> bandDescriptions, String targetLanguage, BulkTranslationCallback callback) {
        String[] bandNames = bandDescriptions.keySet().toArray(new String[0]);
        int total = bandNames.length;
        int[] completed = {0};
        
        Log.d(TAG, "Starting bulk translation of " + total + " bands to " + targetLanguage);
        
        for (String bandName : bandNames) {
            // SAFETY CHECK: Stop bulk translation if app comes back to foreground
            if (!showBands.inBackground) {
                Log.d("TranslationCache", "BLOCKED: App returned to foreground, stopping bulk translation");
                callback.onError("Bulk translation stopped - app returned to foreground");
                return;
            }
            
            String description = bandDescriptions.get(bandName);
            if (description == null || description.trim().isEmpty()) {
                completed[0]++;
                callback.onProgress(completed[0], total);
                if (completed[0] >= total) {
                    callback.onComplete();
                }
                continue;
            }
            
            // Check if already cached
            if (getCachedTranslation(bandName, targetLanguage) != null) {
                completed[0]++;
                callback.onProgress(completed[0], total);
                if (completed[0] >= total) {
                    callback.onComplete();
                }
                continue;
            }
            
            // Translate and cache using chunk-based approach
            translateTextInParagraphChunks(description, targetLanguage, bandName, new TranslationCallback() {
                @Override
                public void onTranslationComplete(String translatedText) {
                    // Translation is already cached by translateTextInParagraphChunks
                    completed[0]++;
                    Log.d(TAG, "Cached translation for " + bandName + " (" + completed[0] + "/" + total + ")");
                    callback.onProgress(completed[0], total);
                        
                    if (completed[0] >= total) {
                        Log.d(TAG, "Bulk translation complete!");
                        callback.onComplete();
                    }
                }
                
                @Override
                public void onTranslationError(String error) {
                    Log.e(TAG, "Failed to cache translation for " + bandName + ": " + error);
                    completed[0]++;
                    callback.onProgress(completed[0], total);
                        
                    if (completed[0] >= total) {
                        Log.d(TAG, "Bulk translation complete!");
                        callback.onComplete();
                    }
                }
            });
        }
    }
    
    /**
     * Performs the actual translation
     */
    private void performTranslation(Translator translator, String text, String targetLanguageCode, String bandName, TranslationCallback callback) {
        translator.translate(text)
            .addOnSuccessListener(new OnSuccessListener<String>() {
                @Override
                public void onSuccess(String translatedText) {
                    // Cache the translation without language marker
                    cacheTranslation(bandName, targetLanguageCode, translatedText);
                    
                    Log.d(TAG, "Translation successful for " + bandName);
                    callback.onTranslationComplete(translatedText);
                }
            })
            .addOnFailureListener(new OnFailureListener() {
                @Override
                public void onFailure(@NonNull Exception e) {
                    Log.e(TAG, "Translation failed", e);
                    callback.onTranslationError("Translation failed: " + e.getMessage());
                }
            });
    }
    
    /**
     * Gets cached translation from file system
     */
    private String getCachedTranslation(String bandName, String languageCode) {
        try {
            File cacheDir = new File(context.getFilesDir(), "translations");
            if (!cacheDir.exists()) {
                return null;
            }
            
            String fileName = normalizeBandName(bandName) + "_" + languageCode.toLowerCase() + ".txt";
            File cacheFile = new File(cacheDir, fileName);
            
            if (!cacheFile.exists()) {
                return null;
            }
            
            FileInputStream fis = new FileInputStream(cacheFile);
            byte[] data = new byte[(int) cacheFile.length()];
            fis.read(data);
            fis.close();
            
            return new String(data, "UTF-8");
        } catch (IOException e) {
            Log.e(TAG, "Error reading cached translation", e);
            return null;
        }
    }
    
    /**
     * Caches translation to file system
     */
    private void cacheTranslation(String bandName, String languageCode, String translation) {
        try {
            File cacheDir = new File(context.getFilesDir(), "translations");
            if (!cacheDir.exists()) {
                cacheDir.mkdirs();
            }
            
            String fileName = normalizeBandName(bandName) + "_" + languageCode.toLowerCase() + ".txt";
            File cacheFile = new File(cacheDir, fileName);
            
            FileOutputStream fos = new FileOutputStream(cacheFile);
            fos.write(translation.getBytes("UTF-8"));
            fos.close();
            
            Log.d(TAG, "Cached translation for " + bandName);
        } catch (IOException e) {
            Log.e(TAG, "Error caching translation", e);
        }
    }
    
    /**
     * Normalizes band name for file naming
     */
    private String normalizeBandName(String bandName) {
        return bandName.replaceAll("[^a-zA-Z0-9]", "_").toLowerCase();
    }
    
    /**
     * Cleanup method to close translators
     */
    public void cleanup() {
        for (Translator translator : translators.values()) {
            translator.close();
        }
        translators.clear();
        
        if (languageIdentifier != null) {
            languageIdentifier.close();
        }
    }
}

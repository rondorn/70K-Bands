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

import java.io.File;
import java.io.FileOutputStream;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
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
        return SUPPORTED_LANGUAGES.contains(deviceLanguage) ? deviceLanguage : "en";
    }
    
    /**
     * Checks if translation is supported for the current device language
     */
    public boolean isTranslationSupported() {
        String currentLang = getCurrentLanguageCode();
        return !currentLang.equals("en") && SUPPORTED_LANGUAGES.contains(currentLang);
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
     * Checks if the current text is translated for a band
     */
    public boolean isCurrentTextTranslated(String bandName) {
        String currentLang = getCurrentLanguagePreference();
        return !currentLang.equals("EN") && hasBandBeenTranslated(bandName);
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
        
        // Try to translate using downloaded model (works offline if model is present)
        performTranslationWithFallback(text, targetLanguageCode, bandName, callback);
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
            
            // Translate and cache
            translator.translate(description)
                .addOnSuccessListener(new OnSuccessListener<String>() {
                    @Override
                    public void onSuccess(String translatedText) {
                        // Add language marker
                        String markedTranslation = "[" + targetLanguage.toUpperCase() + "] " + translatedText;
                        
                        // Cache for offline use
                        cacheTranslation(bandName, targetLanguage, markedTranslation);
                        
                        completed[0]++;
                        Log.d(TAG, "Cached translation for " + bandName + " (" + completed[0] + "/" + total + ")");
                        callback.onProgress(completed[0], total);
                        
                        if (completed[0] >= total) {
                            Log.d(TAG, "Bulk translation complete!");
                            callback.onComplete();
                        }
                    }
                })
                .addOnFailureListener(new OnFailureListener() {
                    @Override
                    public void onFailure(@NonNull Exception e) {
                        Log.e(TAG, "Failed to translate " + bandName + ": " + e.getMessage());
                        completed[0]++;
                        callback.onProgress(completed[0], total);
                        
                        if (completed[0] >= total) {
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
                    // Add language marker to the beginning
                    String markedTranslation = "[" + targetLanguageCode.toUpperCase() + "] " + translatedText;
                    
                    // Cache the translation
                    cacheTranslation(bandName, targetLanguageCode, markedTranslation);
                    
                    Log.d(TAG, "Translation successful for " + bandName);
                    callback.onTranslationComplete(markedTranslation);
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

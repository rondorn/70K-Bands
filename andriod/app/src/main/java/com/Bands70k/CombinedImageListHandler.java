package com.Bands70k;

import android.util.Log;
import org.json.JSONObject;
import org.json.JSONException;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.ArrayList;
import static com.Bands70k.staticVariables.*;

/**
 * Handles the combined image list that merges artist and event images.
 * Artists take priority over events when both have image URLs.
 * Created to mirror iOS CombinedImageListHandler functionality.
 */
public class CombinedImageListHandler {
    
    private static final String TAG = "CombinedImageListHandler";
    
    // Singleton instance
    private static CombinedImageListHandler instance;
    private static final Object lock = new Object();
    
    // Thread-safe backing store for the combined image list
    private final Map<String, String> combinedImageList = new ConcurrentHashMap<>();
    
    // File path for the combined image list cache
    private final File combinedImageListFile;
    
    // Year change detection
    private final AtomicInteger currentYear = new AtomicInteger(0);
    
    /**
     * Private constructor for singleton pattern.
     */
    private CombinedImageListHandler() {
        combinedImageListFile = new File(FileHandler70k.baseImageDirectory + "/combinedImageList.json");
        loadCombinedImageList();
    }
    
    /**
     * Gets the singleton instance of CombinedImageListHandler.
     * @return The singleton instance.
     */
    public static synchronized CombinedImageListHandler getInstance() {
        if (instance == null) {
            instance = new CombinedImageListHandler();
        }
        return instance;
    }
    
    /**
     * Checks if year has changed and clears cache if needed.
     * @return True if year changed, false otherwise.
     */
    private boolean checkYearChange() {
        int newYear = staticVariables.eventYearRaw;
        int oldYear = currentYear.get();
        
        if (oldYear != 0 && oldYear != newYear) {
            Log.d(TAG, "Year changed from " + oldYear + " to " + newYear + ", clearing combined image list cache");
            currentYear.set(newYear);
            
            // Clear cached combined list to force regeneration with new year data
            synchronized (lock) {
                combinedImageList.clear();
            }
            
            // Delete cached file to force regeneration
            if (combinedImageListFile.exists()) {
                combinedImageListFile.delete();
                Log.d(TAG, "Deleted combined image list cache file for year change");
            }
            
            // Clear source data hash to force regeneration with new year's data
            CacheHashManager cacheManager = CacheHashManager.getInstance();
            cacheManager.clearHash("combinedImageListSource");
            Log.d(TAG, "Cleared combined image list source hash for year change");
            
            return true;
        }
        
        if (oldYear == 0) {
            currentYear.set(newYear);
        }
        
        return false;
    }
    
    /**
     * Generates the combined image list from artist and event data.
     * This is lightweight metadata processing that creates a list of image URLs.
     * NO ACTUAL IMAGE DOWNLOADING occurs in this method.
     * @param bandInfo Handler for band/artist data
     * @param completion Runnable called when the list is generated
     */
    public void generateCombinedImageList(BandInfo bandInfo, Runnable completion) {
        Log.d(TAG, "Generating combined image list (URLs only, no downloads)...");
        
        new Thread(() -> {
            Map<String, String> newCombinedList = new HashMap<>();
            
            // Get all band names and their image URLs
            ArrayList<String> bandNames = bandInfo.getBandNames();
            for (String bandName : bandNames) {
                String imageUrl = BandInfo.getImageUrl(bandName);
                if (imageUrl != null && !imageUrl.trim().isEmpty()) {
                    newCombinedList.put(bandName, imageUrl);
                    Log.d(TAG, "Added artist image for " + bandName + ": " + imageUrl);
                }
            }
            
            // Get all event names and their image URLs from schedule data
            // Android already parses ImageURL from schedule CSV and stores in staticVariables.imageUrlMap
            if (staticVariables.imageUrlMap != null) {
                for (Map.Entry<String, String> entry : staticVariables.imageUrlMap.entrySet()) {
                    String bandName = entry.getKey();
                    String imageUrl = entry.getValue();
                    
                    if (imageUrl != null && !imageUrl.trim().isEmpty()) {
                        // Only add if not already present (artist takes priority)
                        if (!newCombinedList.containsKey(bandName)) {
                            // Get ImageDate if available for this event
                            String imageDate = null;
                            if (staticVariables.imageDateMap != null && staticVariables.imageDateMap.containsKey(bandName)) {
                                imageDate = staticVariables.imageDateMap.get(bandName);
                            }
                            
                            // Store as JSON if date exists, otherwise just URL string (backward compatible)
                            if (imageDate != null && !imageDate.trim().isEmpty()) {
                                try {
                                    JSONObject imageInfo = new JSONObject();
                                    imageInfo.put("url", imageUrl);
                                    imageInfo.put("date", imageDate);
                                    newCombinedList.put(bandName, imageInfo.toString());
                                    Log.d(TAG, "Added event image URL for " + bandName + " with date " + imageDate + ": " + imageUrl);
                                } catch (JSONException e) {
                                    // Fallback to simple URL if JSON creation fails
                                    newCombinedList.put(bandName, imageUrl);
                                    Log.e(TAG, "Error creating JSON for " + bandName + ", using simple URL: " + e.getMessage());
                                }
                            } else {
                                // No date - store as simple URL string (backward compatible)
                                newCombinedList.put(bandName, imageUrl);
                                Log.d(TAG, "Added event image URL for " + bandName + " (no date): " + imageUrl);
                            }
                        } else {
                            Log.d(TAG, "Skipped event image URL for " + bandName + " (artist already has image): " + imageUrl);
                        }
                    }
                }
            }
            
            // Update the combined list
            synchronized (lock) {
                combinedImageList.clear();
                combinedImageList.putAll(newCombinedList);
            }
            
            // Save to disk
            saveCombinedImageList();
            
            Log.d(TAG, "Combined image list generated with " + newCombinedList.size() + " URL entries (no downloads)");
            
            if (completion != null) {
                completion.run();
            }
        }).start();
    }
    
    /**
     * Gets the image URL for a given name (artist or event).
     * Handles both simple URL strings and JSON format (for schedule images with dates).
     * @param name The name to look up
     * @return The image URL or empty string if not found
     */
    public String getImageUrl(String name) {
        // Check for year change first
        if (checkYearChange()) {
            Log.d(TAG, "Year changed detected, combined list cleared - will need regeneration");
        }
        
        String value = combinedImageList.get(name);
        if (value == null) {
            // Fallback to reading directly from source data if combined list is empty
            // This handles the case where we cleared the list during regeneration
            if (staticVariables.imageUrlMap != null && staticVariables.imageUrlMap.containsKey(name)) {
                String url = staticVariables.imageUrlMap.get(name);
                Log.d(TAG, "Getting image URL for '" + name + "' from source data (fallback): " + url);
                return url;
            }
            
            // Also check artist images
            String artistUrl = BandInfo.getImageUrl(name);
            if (artistUrl != null && !artistUrl.trim().isEmpty()) {
                Log.d(TAG, "Getting image URL for '" + name + "' from artist data (fallback): " + artistUrl);
                return artistUrl;
            }
            
            Log.d(TAG, "Getting image URL for '" + name + "': not found");
            return "";
        }
        
        // Check if value is JSON (schedule image with date) or simple URL string
        if (value.trim().startsWith("{")) {
            try {
                JSONObject imageInfo = new JSONObject(value);
                String url = imageInfo.getString("url");
                Log.d(TAG, "Getting image URL for '" + name + "' (with date): " + url);
                return url;
            } catch (JSONException e) {
                // Not valid JSON, treat as simple URL string
                Log.d(TAG, "Getting image URL for '" + name + "': " + value);
                return value;
            }
        } else {
            // Simple URL string (artist image or schedule without date)
            Log.d(TAG, "Getting image URL for '" + name + "': " + value);
            return value;
        }
    }
    
    /**
     * Gets the ImageDate for a given name (schedule events only).
     * @param name The name to look up
     * @return The ImageDate or null if not found or not a schedule image
     */
    public String getImageDate(String name) {
        String value = combinedImageList.get(name);
        if (value == null) {
            // Fallback to reading directly from source data if combined list is empty
            // This handles the case where we cleared the list during regeneration
            if (staticVariables.imageDateMap != null && staticVariables.imageDateMap.containsKey(name)) {
                String date = staticVariables.imageDateMap.get(name);
                Log.d(TAG, "Getting image date for '" + name + "' from source data (fallback): " + date);
                return date;
            }
            return null;
        }
        
        // Only schedule images with dates are stored as JSON
        if (value.trim().startsWith("{")) {
            try {
                JSONObject imageInfo = new JSONObject(value);
                if (imageInfo.has("date")) {
                    String date = imageInfo.getString("date");
                    Log.d(TAG, "Getting image date for '" + name + "': " + date);
                    return date;
                }
            } catch (JSONException e) {
                // Not valid JSON
            }
        }
        
        // No date (artist image or schedule without date)
        return null;
    }
    
    /**
     * Checks if the combined list needs to be regenerated based on new data.
     * @param bandInfo Handler for band/artist data
     * @return True if regeneration is needed, false otherwise
     */
    public boolean needsRegeneration(BandInfo bandInfo) {
        Map<String, String> currentList;
        synchronized (lock) {
            currentList = new HashMap<>(combinedImageList);
        }
        
        // Check if any new artists have been added
        ArrayList<String> bandNames = bandInfo.getBandNames();
        for (String bandName : bandNames) {
            String imageUrl = BandInfo.getImageUrl(bandName);
            if (imageUrl != null && !imageUrl.trim().isEmpty()) {
                String currentUrl = currentList.get(bandName);
                if (currentUrl == null || !currentUrl.equals(imageUrl)) {
                    Log.d(TAG, "New artist image detected for " + bandName + ", regeneration needed");
                    return true;
                }
            }
        }
        
        // Check if any new events have been added or ImageDate changed
        if (staticVariables.imageUrlMap != null) {
            for (Map.Entry<String, String> entry : staticVariables.imageUrlMap.entrySet()) {
                String bandName = entry.getKey();
                String imageUrl = entry.getValue();
                
                if (imageUrl != null && !imageUrl.trim().isEmpty()) {
                    String currentValue = currentList.get(bandName);
                    
                    // Get current ImageDate from source data
                    String currentImageDate = null;
                    if (staticVariables.imageDateMap != null && staticVariables.imageDateMap.containsKey(bandName)) {
                        currentImageDate = staticVariables.imageDateMap.get(bandName);
                    }
                    
                    // Check if URL changed
                    String currentUrl = null;
                    String currentDate = null;
                    if (currentValue != null) {
                        if (currentValue.trim().startsWith("{")) {
                            // JSON format - extract URL and date
                            try {
                                JSONObject imageInfo = new JSONObject(currentValue);
                                currentUrl = imageInfo.getString("url");
                                if (imageInfo.has("date")) {
                                    currentDate = imageInfo.getString("date");
                                }
                            } catch (JSONException e) {
                                // Not valid JSON, treat as simple URL
                                currentUrl = currentValue;
                            }
                        } else {
                            // Simple URL string
                            currentUrl = currentValue;
                        }
                    }
                    
                    // Check if URL changed
                    if (currentUrl == null || !currentUrl.equals(imageUrl)) {
                        Log.d(TAG, "Event image URL changed for " + bandName + ", regeneration needed");
                        return true;
                    }
                    
                    // Check if ImageDate changed
                    if (currentImageDate != null && !currentImageDate.trim().isEmpty()) {
                        if (currentDate == null || !currentDate.equals(currentImageDate.trim())) {
                            Log.d(TAG, "Event image date changed for " + bandName + " (old: " + currentDate + ", new: " + currentImageDate + "), regeneration needed");
                            return true;
                        }
                    } else if (currentDate != null) {
                        // Date was removed (shouldn't happen, but handle it)
                        Log.d(TAG, "Event image date removed for " + bandName + ", regeneration needed");
                        return true;
                    }
                }
            }
        }
        
        return false;
    }
    
    /**
     * Loads the combined image list from disk.
     */
    private void loadCombinedImageList() {
        if (!combinedImageListFile.exists()) {
            Log.d(TAG, "No combined image list file found, will generate on first use");
            return;
        }
        
        try {
            StringBuilder jsonString = new StringBuilder();
            FileReader reader = new FileReader(combinedImageListFile);
            char[] buffer = new char[1024];
            int bytesRead;
            while ((bytesRead = reader.read(buffer)) != -1) {
                jsonString.append(buffer, 0, bytesRead);
            }
            reader.close();
            
            JSONObject jsonObject = new JSONObject(jsonString.toString());
            synchronized (lock) {
                combinedImageList.clear();
                Iterator<String> keys = jsonObject.keys();
                while (keys.hasNext()) {
                    String key = keys.next();
                    combinedImageList.put(key, jsonObject.getString(key));
                }
            }
            
            Log.d(TAG, "Combined image list loaded from disk with " + combinedImageList.size() + " entries");
        } catch (IOException | JSONException e) {
            Log.e(TAG, "Error loading combined image list: " + e.getMessage());
        }
    }
    
    /**
     * Saves the combined image list to disk using hash-based caching.
     * Only writes to disk if the content has actually changed.
     */
    private void saveCombinedImageList() {
        try {
            JSONObject jsonObject = new JSONObject();
            synchronized (lock) {
                for (Map.Entry<String, String> entry : combinedImageList.entrySet()) {
                    jsonObject.put(entry.getKey(), entry.getValue());
                }
            }
            
            // Write to temp file first for hash comparison
            File tempFile = new File(combinedImageListFile.getPath() + ".temp");
            FileWriter writer = new FileWriter(tempFile);
            writer.write(jsonObject.toString());
            writer.close();
            
            // Use hash manager to only update if content changed
            CacheHashManager cacheManager = CacheHashManager.getInstance();
            boolean dataChanged = cacheManager.processIfChanged(tempFile, combinedImageListFile, "combinedImageList");
            
            if (dataChanged) {
                Log.d(TAG, "Combined image list content changed, saved to disk");
            } else {
                Log.d(TAG, "Combined image list content unchanged, skipped disk write");
            }
            
        } catch (IOException | JSONException e) {
            Log.e(TAG, "Error saving combined image list: " + e.getMessage());
        }
    }
    
    /**
     * Clears the combined image list cache.
     */
    public void clearCache() {
        synchronized (lock) {
            combinedImageList.clear();
        }
        
        if (combinedImageListFile.exists()) {
            combinedImageListFile.delete();
            Log.d(TAG, "Combined image list cache cleared");
        }
    }
    
    /**
     * Manually triggers the combined image list generation.
     * @param bandInfo Handler for band/artist data
     * @param completion Runnable called when the list is generated
     */
    public void manualGenerateCombinedImageList(BandInfo bandInfo, Runnable completion) {
        Log.d(TAG, "Manual generation triggered");
        generateCombinedImageList(bandInfo, completion);
    }
    
    /**
     * Regenerates the combined image list after year change or new schedule data.
     * This should be called when new schedule data is loaded that may contain new event images.
     * This is lightweight URL list processing, NO ACTUAL IMAGE DOWNLOADING occurs.
     * @param bandInfo Handler for band/artist data
     */
    public void regenerateAfterDataChange(BandInfo bandInfo) {
        Log.d(TAG, "Checking if combined image list needs regeneration after data change");
        
        // Check for year change first
        boolean yearChanged = checkYearChange();
        
        // Check if band or schedule data has actually changed using hash comparison
        CacheHashManager cacheManager = CacheHashManager.getInstance();
        String currentBandHash = cacheManager.getCachedHash("bandInfo");
        String currentScheduleHash = cacheManager.getCachedHash("scheduleInfo");
        
        // Create a combined hash of band + schedule data to compare against last generation
        final String newSourceDataHash;
        if (currentBandHash != null && currentScheduleHash != null) {
            newSourceDataHash = (currentBandHash + "|" + currentScheduleHash);
        } else {
            newSourceDataHash = "";
        }
        
        // Get the hash that was used for the last combined image list generation
        String lastSourceDataHash = cacheManager.getCachedHash("combinedImageListSource");
        
        boolean dataChanged = yearChanged || 
                             combinedImageList.isEmpty() || 
                             !newSourceDataHash.equals(lastSourceDataHash) ||
                             newSourceDataHash.isEmpty();
        
        if (dataChanged) {
            Log.i(TAG, "Regeneration needed - year changed: " + yearChanged + 
                      ", list empty: " + combinedImageList.isEmpty() + 
                      ", data hash changed: " + !newSourceDataHash.equals(lastSourceDataHash));
            
            // CRITICAL: Clear the old cached list immediately to prevent stale data from being used
            // This ensures that getImageDate() and getImageUrl() don't return old data
            // during the regeneration process
            synchronized (lock) {
                combinedImageList.clear();
                Log.d(TAG, "Cleared old combined list to prevent stale data during regeneration");
            }
            
            generateCombinedImageList(bandInfo, new Runnable() {
                @Override
                public void run() {
                    // Store the source data hash used for this generation
                    if (!newSourceDataHash.isEmpty()) {
                        cacheManager.saveCachedHash("combinedImageListSource", newSourceDataHash);
                    }
                    Log.d(TAG, "Combined image list regenerated after data change (URLs only, no downloads)");
                }
            });
        } else {
            Log.i(TAG, "No regeneration needed - underlying band and schedule data unchanged");
        }
    }
    
    /**
     * Prints the current combined image list for debugging.
     */
    public void printCurrentList() {
        Log.d(TAG, "Current list contains " + combinedImageList.size() + " entries:");
        synchronized (lock) {
            for (Map.Entry<String, String> entry : combinedImageList.entrySet()) {
                Log.d(TAG, "  " + entry.getKey() + " -> " + entry.getValue());
            }
        }
    }
    
    /**
     * Gets the current combined image list.
     * @return A copy of the combined image list
     */
    public Map<String, String> getCombinedImageList() {
        synchronized (lock) {
            return new HashMap<>(combinedImageList);
        }
    }
} 
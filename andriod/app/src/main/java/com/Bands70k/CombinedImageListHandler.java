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
                            newCombinedList.put(bandName, imageUrl);
                            Log.d(TAG, "Added event image URL for " + bandName + ": " + imageUrl);
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
     * @param name The name to look up
     * @return The image URL or empty string if not found
     */
    public String getImageUrl(String name) {
        // Check for year change first
        if (checkYearChange()) {
            Log.d(TAG, "Year changed detected, combined list cleared - will need regeneration");
        }
        
        String url = combinedImageList.get(name);
        if (url == null) {
            url = "";
        }
        Log.d(TAG, "Getting image URL for '" + name + "': " + url);
        return url;
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
        
        // Check if any new events have been added
        if (staticVariables.imageUrlMap != null) {
            for (Map.Entry<String, String> entry : staticVariables.imageUrlMap.entrySet()) {
                String bandName = entry.getKey();
                String imageUrl = entry.getValue();
                
                if (imageUrl != null && !imageUrl.trim().isEmpty()) {
                    String currentUrl = currentList.get(bandName);
                    if (currentUrl == null || !currentUrl.equals(imageUrl)) {
                        Log.d(TAG, "New event image detected for " + bandName + ", regeneration needed");
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
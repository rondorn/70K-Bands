package com.Bands70k;

import android.os.AsyncTask;
import android.os.Looper;
import android.os.StrictMode;
import android.os.SystemClock;
import android.util.Log;

import java.io.BufferedReader;
import java.io.DataInputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;
import java.sql.Date;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import java.io.FileNotFoundException;
import android.content.Context;


/**
 * Handles downloading, loading, and providing band description data for the app.
 * Created by rdorn on 9/25/17.
 */

public class CustomerDescriptionHandler {

    // Singleton instance
    private static CustomerDescriptionHandler instance;
    private static final Object lock = new Object();
    
    // Instance tracking
    private static final AtomicBoolean isInitialized = new AtomicBoolean(false);
    private static final AtomicBoolean isRunning = new AtomicBoolean(false);
    private static final AtomicBoolean isPaused = new AtomicBoolean(false);
    private static final AtomicInteger currentYear = new AtomicInteger(0);
    
    // Background loading state
    private static final AtomicBoolean backgroundLoadingActive = new AtomicBoolean(false);
    private static final AtomicBoolean detailsScreenActive = new AtomicBoolean(false);
    
    // Year change tracking (prevent bulk loading immediately after year change)
    private static final AtomicLong lastYearChangeTime = new AtomicLong(0);
    
    // Data storage
    private Map<String, String> descriptionMapData = new HashMap<String,String>();
    
    // Background task reference
    private AsyncAllDescriptionLoader currentBackgroundTask;

    /**
     * Private constructor for singleton pattern.
     * Loads description map on launch to populate cache with band/event names and URLs.
     */
    private CustomerDescriptionHandler(){
        // Load description map on launch to cache band names and description URLs
        // This downloads the mapping file but NOT the actual descriptions
        descriptionMapData = this.getDescriptionMap();
    }

    /**
     * Gets the singleton instance of CustomerDescriptionHandler.
     * @return The singleton instance.
     */
    public static synchronized CustomerDescriptionHandler getInstance() {
        if (instance == null) {
            instance = new CustomerDescriptionHandler();
        }
        return instance;
    }

    /**
     * Checks if the handler is currently running.
     * @return True if running, false otherwise.
     */
    public static boolean isRunning() {
        return isRunning.get();
    }

    /**
     * Checks if the handler is currently paused.
     * @return True if paused, false otherwise.
     */
    public static boolean isPaused() {
        return isPaused.get();
    }

    /**
     * Pauses the background loading (called when entering details screen).
     */
    public static void pauseBackgroundLoading() {
        Log.d("CustomerDescriptionHandler", "pauseBackgroundLoading() called - DISABLED (using Application-level background detection)");
        // DISABLED: With proper Application-level background detection, we don't need screen-specific pausing
        // Bulk loading is now controlled entirely by whether the entire app is in background
        // isPaused.set(true);
        // detailsScreenActive.set(true);
    }

    /**
     * Resumes the background loading (called when exiting details screen).
     * Does NOT automatically restart bulk loading - that should only happen when app goes to background.
     */
    public static void resumeBackgroundLoading() {
        Log.d("CustomerDescriptionHandler", "resumeBackgroundLoading() called - DISABLED (using Application-level background detection)");
        // DISABLED: With proper Application-level background detection, we don't need screen-specific pausing/resuming
        // Bulk loading is now controlled entirely by whether the entire app is in background
        // isPaused.set(false);
        // detailsScreenActive.set(false);
    }

    /**
     * Cancels any ongoing background loading task.
     */
    public void cancelBackgroundTask() {
        if (currentBackgroundTask != null && !currentBackgroundTask.isCancelled()) {
            Log.d("CustomerDescriptionHandler", "Cancelling background task");
            currentBackgroundTask.cancel(true);
            isRunning.set(false);
            backgroundLoadingActive.set(false);
        }
    }

    /**
     * Checks if year has changed and resets state if needed.
     * @return True if year changed, false otherwise.
     */
    private boolean checkYearChange() {
        int newYear = staticVariables.eventYearRaw;
        int oldYear = currentYear.get();
        
        if (oldYear != 0 && oldYear != newYear) {
            Log.d("CustomerDescriptionHandler", "Year changed from " + oldYear + " to " + newYear + ", resetting state");
            currentYear.set(newYear);
            isRunning.set(false);
            isPaused.set(false);
            backgroundLoadingActive.set(false);
            detailsScreenActive.set(false);
            
            // Record year change time to prevent immediate bulk loading
            lastYearChangeTime.set(System.currentTimeMillis());
            Log.d("CustomerDescriptionHandler", "Year change timestamp recorded: " + lastYearChangeTime.get());
            
            // Clear description map data to force reloading for new year
            descriptionMapData.clear();
            staticVariables.descriptionMapModData.clear();
            
            // Re-lookup URLs to get correct description map URL for new year
            Log.d("CustomerDescriptionHandler", "Re-looking up URLs for new year: " + newYear);
            staticVariables.lookupUrls();
            
            // Delete and reload description map file for new year
            if (FileHandler70k.descriptionMapFile.exists()) {
                FileHandler70k.descriptionMapFile.delete();
                Log.d("CustomerDescriptionHandler", "Deleted description map file for year change");
            }
            
            // Clear cached hash for description map to force download of new year's data
            // The description map will be downloaded when needed (details screen or background loading)
            CacheHashManager cacheManager = CacheHashManager.getInstance();
            cacheManager.clearHash("descriptionMap");
            Log.d("CustomerDescriptionHandler", "Cleared description map hash for year change - will download when needed");
            
            // Cancel current background task if running
            if (currentBackgroundTask != null && !currentBackgroundTask.isCancelled()) {
                currentBackgroundTask.cancel(true);
            }
            
            // DO NOT restart background loading automatically after year change
            // Bulk loading should only happen when app goes to background (onPause)
            Log.d("CustomerDescriptionHandler", "Year change complete - bulk loading will only occur when app goes to background");
            
            return true;
        }
        
        if (oldYear == 0) {
            currentYear.set(newYear);
        }
        
        return false;
    }

    /**
     * Downloads the description map file from the server if online.
     * Uses hash-based caching to only process files when content has changed.
     */
    public void getDescriptionMapFile(){

        BandInfo bandInfo = new BandInfo();
        bandInfo.getDownloadtUrls();

        String descriptionMapURL = staticVariables.descriptionMap;
        Log.d("70K_NOTE_DEBUG", "getDescriptionMapFile using URL: " + descriptionMapURL);
        Log.d("70K_NOTE_DEBUG", "eventYear: " + staticVariables.eventYear + ", eventYearRaw: " + staticVariables.eventYearRaw);
        Log.d("70K_NOTE_DEBUG", "eventYearIndex: " + staticVariables.eventYearIndex);
        CacheHashManager cacheManager = CacheHashManager.getInstance();

        if (OnlineStatus.isOnline() == true && Looper.myLooper() != Looper.getMainLooper()) {
            
            // TEMPORARY DEBUG: Force fresh download by clearing cache
            Log.d("70K_NOTE_DEBUG", "Clearing description map cache to force fresh download");
            cacheManager.clearHash("descriptionMap");
            if (FileHandler70k.descriptionMapFile.exists()) {
                FileHandler70k.descriptionMapFile.delete();
                Log.d("70K_NOTE_DEBUG", "Deleted existing description map file");
            }
            
            // Create temp file for hash comparison
            File tempDescriptionMap = new File(showBands.newRootDir + FileHandler70k.directoryName + "70kbandDescriptionMap.csv.temp");
            boolean downloadSuccessful = false;
            
            try {

                URL u = new URL(descriptionMapURL);
                
                // Handle HTTP redirects properly for Dropbox URLs
                HttpURLConnection connection = (HttpURLConnection) u.openConnection();
                connection.setInstanceFollowRedirects(true);
                connection.setConnectTimeout(10000); // 10 seconds
                connection.setReadTimeout(30000); // 30 seconds
                
                InputStream is = connection.getInputStream();
                DataInputStream dis = new DataInputStream(is);

                byte[] buffer = new byte[1024];
                int length;

                // Download to temp file first
                FileOutputStream fos = new FileOutputStream(tempDescriptionMap);
                while ((length = dis.read(buffer)) > 0) {
                    fos.write(buffer, 0, length);
                }
                fos.close();
                dis.close();
                is.close();
                
                downloadSuccessful = true;
                Log.d("descriptionMapFile", "Description map downloaded to temp file");

            } catch (MalformedURLException mue) {
                Log.e("SYNC getUpdate", "descriptionMapFile malformed url error", mue);
            } catch (IOException ioe) {
                Log.e("SYNC getUpdate", "descriptionMapFile io error", ioe);
            } catch (SecurityException se) {
                Log.e("SYNC getUpdate", "descriptionMapFile security error", se);
            } catch (Exception generalError) {
                Log.e("General Exception", "Downloading descriptionMapFile", generalError);
            }
            
            // Process temp file only if download was successful and content changed
            if (downloadSuccessful) {
                Log.d("70K_NOTE_DEBUG", "Download successful, checking if content changed");
                Log.d("70K_NOTE_DEBUG", "Temp file size: " + tempDescriptionMap.length() + " bytes");
                Log.d("70K_NOTE_DEBUG", "Existing file size: " + (FileHandler70k.descriptionMapFile.exists() ? FileHandler70k.descriptionMapFile.length() : 0) + " bytes");
                
                boolean dataChanged = cacheManager.processIfChanged(tempDescriptionMap, FileHandler70k.descriptionMapFile, "descriptionMap");
                Log.d("70K_NOTE_DEBUG", "processIfChanged returned: " + dataChanged);
                
                if (dataChanged) {
                    Log.i("CustomerDescriptionHandler", "Description map data has changed, processed new file");
                    Log.d("70K_NOTE_DEBUG", "Final file size after processing: " + FileHandler70k.descriptionMapFile.length() + " bytes");
                    // Clear cached data to force reload of new description map
                    descriptionMapData.clear();
                    staticVariables.descriptionMapModData.clear();
                } else {
                    Log.i("CustomerDescriptionHandler", "Description map data unchanged, using cached version");
                    Log.d("70K_NOTE_DEBUG", "File was not updated due to hash comparison");
                }
            } else {
                // Clean up temp file on download failure
                if (tempDescriptionMap.exists()) {
                    tempDescriptionMap.delete();
                }
            }

            Log.d("descriptionMapFile", "descriptionMapFile processing completed!");
        }
    }
    
    /**
     * Downloads the description map file immediately, bypassing main thread restrictions.
     * This method is used for immediate loading in the details screen.
     */
    private void getDescriptionMapFileImmediate() {
        Log.d("70K_NOTE_DEBUG", "getDescriptionMapFileImmediate called");
        
        BandInfo bandInfo = new BandInfo();
        bandInfo.getDownloadtUrls();

        String descriptionMapURL = staticVariables.descriptionMap;
        Log.d("70K_NOTE_DEBUG", "getDescriptionMapFileImmediate using URL: " + descriptionMapURL);
        Log.d("70K_NOTE_DEBUG", "eventYear: " + staticVariables.eventYear + ", eventYearRaw: " + staticVariables.eventYearRaw);
        Log.d("70K_NOTE_DEBUG", "eventYearIndex: " + staticVariables.eventYearIndex);

        CacheHashManager cacheManager = CacheHashManager.getInstance();

        if (OnlineStatus.isOnline() == true) {
            
            // TEMPORARY DEBUG: Force fresh download by clearing cache
            Log.d("70K_NOTE_DEBUG", "Clearing description map cache to force fresh download");
            cacheManager.clearHash("descriptionMap");
            if (FileHandler70k.descriptionMapFile.exists()) {
                FileHandler70k.descriptionMapFile.delete();
                Log.d("70K_NOTE_DEBUG", "Deleted existing description map file");
            }
            
            // Create temp file for hash comparison
            File tempDescriptionMap = new File(showBands.newRootDir + FileHandler70k.directoryName + "70kbandDescriptionMap.csv.temp");
            boolean downloadSuccessful = false;
            
            try {
                Log.d("70K_NOTE_DEBUG", "Downloading description map immediately from: " + descriptionMapURL);
                
                URL u = new URL(descriptionMapURL);
                
                // Handle HTTP redirects properly for Dropbox URLs
                HttpURLConnection connection = (HttpURLConnection) u.openConnection();
                connection.setInstanceFollowRedirects(true);
                connection.setConnectTimeout(10000); // 10 seconds
                connection.setReadTimeout(30000); // 30 seconds
                
                InputStream is = connection.getInputStream();
                DataInputStream dis = new DataInputStream(is);

                byte[] buffer = new byte[1024];
                int length;

                // Download to temp file first
                FileOutputStream fos = new FileOutputStream(tempDescriptionMap);
                while ((length = dis.read(buffer)) > 0) {
                    fos.write(buffer, 0, length);
                }
                fos.close();
                dis.close();
                is.close();
                
                downloadSuccessful = true;
                Log.d("70K_NOTE_DEBUG", "Description map downloaded to temp file successfully");

            } catch (MalformedURLException mue) {
                Log.e("70K_NOTE_DEBUG", "descriptionMapFile malformed url error", mue);
            } catch (IOException ioe) {
                Log.e("70K_NOTE_DEBUG", "descriptionMapFile io error", ioe);
            } catch (SecurityException se) {
                Log.e("70K_NOTE_DEBUG", "descriptionMapFile security error", se);
            } catch (Exception generalError) {
                Log.e("70K_NOTE_DEBUG", "Error downloading descriptionMapFile immediately", generalError);
            }
            
            // Process temp file only if download was successful and content changed
            if (downloadSuccessful) {
                Log.d("70K_NOTE_DEBUG", "Download successful (immediate), checking if content changed");
                Log.d("70K_NOTE_DEBUG", "Temp file size: " + tempDescriptionMap.length() + " bytes");
                Log.d("70K_NOTE_DEBUG", "Existing file size: " + (FileHandler70k.descriptionMapFile.exists() ? FileHandler70k.descriptionMapFile.length() : 0) + " bytes");
                
                boolean dataChanged = cacheManager.processIfChanged(tempDescriptionMap, FileHandler70k.descriptionMapFile, "descriptionMap");
                Log.d("70K_NOTE_DEBUG", "processIfChanged (immediate) returned: " + dataChanged);
                
                if (dataChanged) {
                    Log.i("70K_NOTE_DEBUG", "Description map data has changed, processed new file");
                    Log.d("70K_NOTE_DEBUG", "Final file size after processing: " + FileHandler70k.descriptionMapFile.length() + " bytes");
                    // Clear cached data to force reload of new description map
                    descriptionMapData.clear();
                    staticVariables.descriptionMapModData.clear();
                } else {
                    Log.i("70K_NOTE_DEBUG", "Description map data unchanged, using cached version");
                    Log.d("70K_NOTE_DEBUG", "File was not updated due to hash comparison (immediate)");
                }
            } else {
                // Clean up temp file on download failure
                if (tempDescriptionMap.exists()) {
                    tempDescriptionMap.delete();
                }
            }
        } else {
            Log.d("70K_NOTE_DEBUG", "Not online, cannot download description map file immediately");
        }
    }

    /**
     * Normalizes a band name by removing invisible Unicode characters and trimming whitespace.
     * @param bandName The band name to normalize.
     * @return The normalized band name.
     */
    private String normalizeBandName(String bandName) {
        if (bandName == null) {
            return "";
        }
        
        // Remove invisible Unicode characters and normalize
        String normalized = bandName.trim()
            .replace("⁦", "") // Remove left-to-right mark
            .replace("⁧", "") // Remove right-to-left mark
            .replace("\u200E", "") // Remove left-to-right mark
            .replace("\u200F", "") // Remove right-to-left mark
            .replace("\u202A", "") // Remove left-to-right embedding
            .replace("\u202B", "") // Remove right-to-left embedding
            .replace("\u202C", "") // Remove pop directional formatting
            .replace("\u202D", "") // Remove left-to-right override
            .replace("\u202E", "") // Remove right-to-left override
            .replace("\u2066", "") // Remove left-to-right isolate
            .replace("\u2067", "") // Remove right-to-left isolate
            .replace("\u2068", "") // Remove first strong isolate
            .replace("\u2069", ""); // Remove pop directional isolate
        
        return normalized;
    }

    /**
     * Loads the description map from file or downloads it if not present.
     * @return The map of band names to descriptions.
     */
    public Map<String, String>  getDescriptionMap(){
        //only load data if it is not already populated
        if (descriptionMapData.isEmpty() == false){
            return this.descriptionMapData;
        }

        if (FileHandler70k.descriptionMapFile.exists() == false){
            this.getDescriptionMapFile();
        }

        try {
            File file = FileHandler70k.descriptionMapFile;

            BufferedReader br = new BufferedReader(new FileReader(file));
            String line;
            int lineCount = 0;
            int processedCount = 0;
            
            // Read all lines into a list first to ensure we get everything
            java.util.List<String> allLines = new java.util.ArrayList<>();
            while ((line = br.readLine()) != null) {
                allLines.add(line);
            }
            br.close();
            
            Log.d("70K_NOTE_DEBUG", "Read " + allLines.size() + " total lines from file");

            // Now process all the lines
            for (String currentLine : allLines) {
                lineCount++;
                Log.d("70K_NOTE_DEBUG", "Reading CSV line " + lineCount + ": " + currentLine);
                String[] rowData = currentLine.split(",");
                if (!"Band".equals(rowData[0])) {
                    processedCount++;
                    String normalizedBandName = normalizeBandName(rowData[0]);
                    Log.d("70K_NOTE_DEBUG", "Processing band " + processedCount + ": " + rowData[0] + " -> " + normalizedBandName + " -> " + rowData[1]);
                    descriptionMapData.put(normalizedBandName, rowData[1]);
                    if (rowData.length > 2){
                        Log.d("descriptionMapFile", "Date value is " + rowData[2]);
                        staticVariables.descriptionMapModData.put(normalizedBandName, rowData[2]);
                    }
                }
            }
            
            Log.d("70K_NOTE_DEBUG", "CSV parsing complete - read " + lineCount + " lines, processed " + processedCount + " bands");
            Log.d("70K_NOTE_DEBUG", "Final descriptionMapData size: " + descriptionMapData.size());
        } catch (FileNotFoundException fnfe) {
            Log.e("General Exception", "Description map file not found, attempting to download it", fnfe);
            // File was deleted after check, try to download it again
            this.getDescriptionMapFile();
            // Try to read it again
            try {
                File file = FileHandler70k.descriptionMapFile;
                if (file.exists()) {
                    BufferedReader br = new BufferedReader(new FileReader(file));
                    String line;
                    int retryLineCount = 0;
                    int retryProcessedCount = 0;
                    
                    // Read all lines into a list first to ensure we get everything
                    java.util.List<String> allLines = new java.util.ArrayList<>();
                    while ((line = br.readLine()) != null) {
                        allLines.add(line);
                    }
                    br.close();
                    
                    Log.d("70K_NOTE_DEBUG", "Read " + allLines.size() + " total lines from file (retry)");

                    // Now process all the lines
                    for (String currentLine : allLines) {
                        retryLineCount++;
                        Log.d("70K_NOTE_DEBUG", "Reading CSV line (retry) " + retryLineCount + ": " + currentLine);
                        String[] rowData = currentLine.split(",");
                        if (!"Band".equals(rowData[0])) {
                            retryProcessedCount++;
                            String normalizedBandName = normalizeBandName(rowData[0]);
                            Log.d("70K_NOTE_DEBUG", "Processing band (retry) " + retryProcessedCount + ": " + rowData[0] + " -> " + normalizedBandName + " -> " + rowData[1]);
                            descriptionMapData.put(normalizedBandName, rowData[1]);
                            if (rowData.length > 2){
                                Log.d("descriptionMapFile", "Date value is " + rowData[2]);
                                staticVariables.descriptionMapModData.put(normalizedBandName, rowData[2]);
                            }
                        }
                    }
                    
                    Log.d("70K_NOTE_DEBUG", "CSV parsing (retry) complete - read " + retryLineCount + " lines, processed " + retryProcessedCount + " bands");
                }
            } catch (Exception retryError) {
                Log.e("General Exception", "Failed to read description map file after retry", retryError);
            }
        } catch (Exception error){
            Log.e("General Exception", "Unable to parse descriptionMapFile", error);
        }

        return descriptionMapData;
    }

    /**
     * Starts background loading of all descriptions with proper synchronization.
     * This method should only be called when the app is moved to background.
     * DEPRECATED: Use startBackgroundLoadingOnPause() instead to ensure proper background-only execution.
     */
    @Deprecated
    public void getAllDescriptions(){
        synchronized (lock) {
            // Check if already running
            if (isRunning.get()) {
                Log.d("CustomerDescriptionHandler", "Background loading already running, skipping");
                return;
            }
            
            // SAFETY CHECK: Only allow bulk downloads when app is in background
            if (!Bands70k.isAppInBackground()) {
                Log.d("CustomerDescriptionHandler", "BLOCKED: Bulk download attempted when app is NOT in background - this should not happen!");
                return;
            }
            
            // Check year change and clear cache if needed
            if (checkYearChange()) {
                Log.d("CustomerDescriptionHandler", "Year changed detected, cache cleared - now starting background loading");
            }
            
            startBackgroundLoading();
        }
    }
    
    /**
     * Starts background loading of all descriptions when app goes to background.
     * This method should be called from the main activity's onPause() method.
     * Prevents bulk loading immediately after year change to avoid inappropriate downloads.
     */
    public void startBackgroundLoadingOnPause() {
        synchronized (lock) {
            Log.d("CustomerDescriptionHandler", "startBackgroundLoadingOnPause called - isAppInBackground: " + Bands70k.isAppInBackground());
            
            // SAFETY CHECK: Only proceed if app is actually in background AND fully initialized
            if (!Bands70k.isAppInBackground()) {
                Log.d("CustomerDescriptionHandler", "BLOCKED: startBackgroundLoadingOnPause called but app is NOT in background!");
                return;
            }
            
            if (!showBands.appFullyInitialized) {
                Log.d("CustomerDescriptionHandler", "BLOCKED: startBackgroundLoadingOnPause called but app is NOT fully initialized!");
                return;
            }
            
            // Check if it's too soon after a year change (prevent bulk loading for 10 seconds)
            long timeSinceYearChange = System.currentTimeMillis() - lastYearChangeTime.get();
            if (timeSinceYearChange < 10000) { // 10 seconds
                Log.d("CustomerDescriptionHandler", "Skipping bulk loading - too soon after year change (" + timeSinceYearChange + "ms)");
                return;
            }
            
            // Only start background loading if not already running
            if (!isRunning.get()) {
                Log.d("CustomerDescriptionHandler", "Starting background loading due to app going to background");
                getAllDescriptions();
            } else {
                Log.d("CustomerDescriptionHandler", "Background loading already running, skipping");
            }
        }
    }

    /**
     * Starts the background loading task.
     * ONLY runs when app is in background to prevent inappropriate bulk downloads.
     */
    private void startBackgroundLoading() {
        // Double-check that app is in background before starting bulk download
        if (!Bands70k.isAppInBackground()) {
            Log.d("CustomerDescriptionHandler", "BLOCKED: startBackgroundLoading called when app is NOT in background!");
            return;
        }
        
        if (isRunning.compareAndSet(false, true)) {
            Log.d("CustomerDescriptionHandler", "Starting background loading (app is in background)");
            backgroundLoadingActive.set(true);
            
            currentBackgroundTask = new AsyncAllDescriptionLoader();
            currentBackgroundTask.execute();
        }
    }

    /**
     * Gets the description for a given band, loading from file or URL as needed.
     * @param bandNameValue The name of the band.
     * @return The band description string.
     */
    public String getDescription (String bandNameValue){

        Log.d("70K_NOTE_DEBUG", "getDescription called for " + bandNameValue);

        String bandName = bandNameValue;
        String normalizedBandName = normalizeBandName(bandName);
        String bandNoteDefault = FestivalConfig.getInstance().getDefaultDescriptionText(staticVariables.context);
        String bandNote = bandNoteDefault;

        Log.d("70K_NOTE_DEBUG", "descriptionMapData: " + descriptionMapData);
        Log.d("70K_NOTE_DEBUG", "Normalized band name: " + normalizedBandName);

        BandNotes bandNoteHandler = new BandNotes(bandName);

        // PATCH: Always check for a custom note, even if band is not in descriptionMapData
        String customNote = bandNoteHandler.getBandNoteFromFile();
        if (customNote != null && !customNote.trim().isEmpty()) {
            Log.d("70K_NOTE_DEBUG", "Returning custom note for " + bandName + ": " + customNote);
            return customNote;
        }

        // Check if year has changed and reload description map if needed
        if (checkYearChange()) {
            Log.d("70K_NOTE_DEBUG", "Year changed in getDescription, reloading description map");
            getDescriptionMapFile();
        }

        // Ensure description map file exists before trying to read it
        if (!FileHandler70k.descriptionMapFile.exists()) {
            Log.d("70K_NOTE_DEBUG", "Description map file doesn't exist, downloading it");
            getDescriptionMapFile();
        }

        if (descriptionMapData.containsKey(normalizedBandName) == false) {
            Log.d("70K_NOTE_DEBUG", "No descriptionMap entry for " + normalizedBandName + ", returning default note");
            return bandNoteDefault;
        }

        if (descriptionMapData.keySet().size() == 0) {
            descriptionMapData = this.getDescriptionMap();
            Log.d("70K_NOTE_DEBUG", "descriptionMapData was empty, reloaded for " + bandNameValue);
        }

        if (descriptionMapData.containsKey(normalizedBandName) == false) {
            descriptionMapData = new HashMap<String,String>();
            descriptionMapData = getDescriptionMap();
            Log.d("70K_NOTE_DEBUG", "descriptionMapData still missing for " + normalizedBandName);
        } else {
            Log.d("70K_NOTE_DEBUG", "descriptionMapData present for " + normalizedBandName + ": " + descriptionMapData.get(normalizedBandName));
        }

        if (descriptionMapData.containsKey(normalizedBandName) == false){
            Log.d("70K_NOTE_DEBUG", "descriptionMapData still missing after reload for " + normalizedBandName);
            if (staticVariables.showNotesMap.containsKey(bandName) == true) {
                if (staticVariables.showNotesMap.get(bandName).length() > 5) {
                    Log.d("70K_NOTE_DEBUG", "showNotesMap entry found for " + bandName + ", loading note from URL");
                    loadNoteFromURL(bandName);
                    bandNote = bandNoteHandler.getBandNoteFromFile();
                    Log.d("70K_NOTE_DEBUG", "Loaded note from file after URL for " + bandName + ": " + bandNote);
                    return bandNote;
                }
            }
        }

        Log.d("70K_NOTE_DEBUG", "Calling loadNoteFromURL for " + bandNameValue);
        loadNoteFromURL(bandNameValue);
        Log.d("70K_NOTE_DEBUG", "Called loadNoteFromURL for " + bandNameValue);

        bandNote = bandNoteHandler.getBandNoteFromFile();
        bandNote = removeSpecialCharsFromString(bandNote);

        Log.d("70K_NOTE_DEBUG", "Returning note for " + bandName + ": " + bandNote);
        return bandNote;
    }

    /**
     * Reads the description map file without triggering any downloads.
     * Only reads the existing file if it exists.
     */
    private void readDescriptionMapFileOnly() {
        if (!FileHandler70k.descriptionMapFile.exists()) {
            Log.d("70K_NOTE_DEBUG", "Description map file doesn't exist, cannot read");
            return;
        }

        try {
            File file = FileHandler70k.descriptionMapFile;
            BufferedReader br = new BufferedReader(new FileReader(file));
            String line;

            while ((line = br.readLine()) != null) {
                String[] rowData = line.split(",");
                if (!"Band".equals(rowData[0])) {
                    String normalizedBandName = normalizeBandName(rowData[0]);
                    Log.d("descriptionMapFile", "Adding " + normalizedBandName + "-" + rowData[1]);
                    // SKILTRON DEBUG: Log if this is Skiltron
                    if (rowData[0].toLowerCase().contains("skiltron")) {
                        Log.d("SKILTRON_DEBUG", "Found Skiltron in CSV! Raw: '" + rowData[0] + "' Normalized: '" + normalizedBandName + "' URL: " + rowData[1]);
                    }
                    descriptionMapData.put(normalizedBandName, rowData[1]);
                    if (rowData.length > 2){
                        Log.d("descriptionMapFile", "Date value is " + rowData[2]);
                        staticVariables.descriptionMapModData.put(normalizedBandName, rowData[2]);
                    }
                }
            }
            br.close();
        } catch (Exception e) {
            Log.e("70K_NOTE_DEBUG", "Error reading description map file", e);
        }
    }

    /**
     * Gets the description for a specific band immediately, bypassing background loading pause.
     * This method is used when the details screen needs to load a note immediately.
     * @param bandNameValue The name of the band.
     * @return The band description string.
     */
    public String getDescriptionImmediate(String bandNameValue) {
        Log.d("70K_NOTE_DEBUG", "getDescriptionImmediate called for " + bandNameValue);

        String bandName = bandNameValue;
        String normalizedBandName = normalizeBandName(bandName);
        String bandNoteDefault = FestivalConfig.getInstance().getDefaultDescriptionText(staticVariables.context);
        String bandNote = bandNoteDefault;

        BandNotes bandNoteHandler = new BandNotes(bandName);

        // Always check for a custom note first
        String customNote = bandNoteHandler.getBandNoteFromFile();
        if (customNote != null && !customNote.trim().isEmpty()) {
            Log.d("70K_NOTE_DEBUG", "Returning custom note for " + bandName + ": " + customNote);
            return customNote;
        }

        // Check if year has changed and reload description map if needed
        if (checkYearChange()) {
            Log.d("70K_NOTE_DEBUG", "Year changed in immediate loading, reloading description map");
            getDescriptionMapFile();
        }

        // Always download description map to check for updates
        boolean mapFileWasDownloaded = false;
        Log.d("70K_NOTE_DEBUG", "Downloading description map to check for updates");
        getDescriptionMapFileImmediate();
        mapFileWasDownloaded = true;

        // If no custom note, try to load from description map
        // Read the map file directly without triggering bulk downloads
        if (descriptionMapData.isEmpty() || mapFileWasDownloaded) {
            Log.d("70K_NOTE_DEBUG", "Reading description map from file (empty: " + descriptionMapData.isEmpty() + ", downloaded: " + mapFileWasDownloaded + ")");
            readDescriptionMapFileOnly();
        }

        if (descriptionMapData.containsKey(normalizedBandName) == false) {
            Log.d("70K_NOTE_DEBUG", "No descriptionMap entry for " + normalizedBandName + ", returning default note");
            // SKILTRON DEBUG: Log all available keys if this is Skiltron
            if (bandName.toLowerCase().contains("skiltron")) {
                Log.d("SKILTRON_DEBUG", "Skiltron not found! Available keys in descriptionMapData:");
                for (String key : descriptionMapData.keySet()) {
                    if (key.toLowerCase().contains("skil")) {
                        Log.d("SKILTRON_DEBUG", "Similar key found: '" + key + "'");
                    }
                }
                Log.d("SKILTRON_DEBUG", "Total entries in descriptionMapData: " + descriptionMapData.size());
                Log.d("SKILTRON_DEBUG", "Looking for normalized: '" + normalizedBandName + "'");
                Log.d("SKILTRON_DEBUG", "Original band name: '" + bandName + "'");
            }
            return bandNoteDefault;
        }

        // Load the note immediately without being affected by background loading state
        Log.d("70K_NOTE_DEBUG", "Loading note immediately for " + bandName);
        loadNoteFromURLImmediate(bandName);
        
        bandNote = bandNoteHandler.getBandNoteFromFile();
        bandNote = removeSpecialCharsFromString(bandNote);

        if (bandNote == null || bandNote.trim().isEmpty()) {
            Log.d("70K_NOTE_DEBUG", "No note loaded for " + bandName + ", returning default");
            return bandNoteDefault;
        }

        Log.d("70K_NOTE_DEBUG", "Returning immediate note for " + bandName + ": " + bandNote);
        return bandNote;
    }

    /**
     * Loads the note for a band from a remote URL immediately, bypassing background loading pause.
     * @param bandName The name of the band.
     */
    public void loadNoteFromURLImmediate(String bandName) {
        Log.d("70K_NOTE_DEBUG", "loadNoteFromURLImmediate called for " + bandName);

        BandNotes bandNoteHandler = new BandNotes(bandName);
        File oldBandNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note");
        if (oldBandNoteFile.exists() == true) {
            Log.d("70K_NOTE_DEBUG", "Converting old band note for " + bandName);
            bandNoteHandler.convertOldBandNote();
        }

        try {
            // Note: Date is now embedded in the filename itself (bandName.note-DATE)
            // No need for separate changeFileFlag file anymore - fileExists() handles cache invalidation
            
            File bandCustNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note_cust");
            
            // If a custom note exists, do NOT overwrite with default note from server
            if (bandCustNoteFile.exists()) {
                Log.d("70K_NOTE_DEBUG", "Custom note exists for " + bandName + ", skipping default note download and overwrite.");
                return;
            }
            
            // Check if we have a cached note with the current date
            // fileExists() automatically cleans up obsolete cache and returns true only if current date cache exists
            if (bandNoteHandler.fileExists() == true) {
                Log.d("70K_NOTE_DEBUG", "getDescription, cached note exists with current date for " + bandName + ", skipping download");
                return;
            } else {
                Log.d("70K_NOTE_DEBUG", "getDescription, no cached note with current date for " + bandName + ", downloading");
            }
            
            // Check if year has changed and reload description map if needed
            if (checkYearChange()) {
                Log.d("70K_NOTE_DEBUG", "Year changed in immediate URL loading, reloading description map");
                getDescriptionMapFile();
            }
            
            // Ensure description map file exists before trying to read it
            if (!FileHandler70k.descriptionMapFile.exists()) {
                Log.d("70K_NOTE_DEBUG", "Description map file doesn't exist, downloading it");
                getDescriptionMapFile();
            }
            
            String normalizedBandName = normalizeBandName(bandName);
            if (descriptionMapData.containsKey(normalizedBandName) == false) {
                descriptionMapData = new HashMap<String,String>();
                getDescriptionMapFile();
                descriptionMapData = this.getDescriptionMap();
            }

            URL url;
            if (OnlineStatus.isOnline() == true) {
                try {
                    if (staticVariables.showNotesMap.containsKey(bandName) &&
                            staticVariables.showNotesMap.get(bandName).length() > 5) {
                        url = new URL(staticVariables.showNotesMap.get(bandName));
                        Log.d("70K_NOTE_DEBUG", "Looking up NoteData at URL " + url.toString());
                    } else if (descriptionMapData.containsKey(normalizedBandName) == true) {
                        url = new URL(descriptionMapData.get(normalizedBandName));
                        Log.d("70K_NOTE_DEBUG", "Looking up NoteData at URL " + url.toString());
                    } else {
                        Log.d("70K_NOTE_DEBUG", "no description for bandName " + normalizedBandName);
                        return;
                    }
                } catch (Exception error) {
                    Log.d("70K_NOTE_DEBUG", "could not load! for " + bandName + " - " + descriptionMapData.get(bandName));
                    return;
                }
            } else {
                Log.d("70K_NOTE_DEBUG", "Not online, skipping download for " + bandName);
                return;
            }

            // Handle HTTP redirects properly for Dropbox URLs
            HttpURLConnection connection = (HttpURLConnection) url.openConnection();
            connection.setInstanceFollowRedirects(true);
            connection.setConnectTimeout(10000); // 10 seconds
            connection.setReadTimeout(30000); // 30 seconds
            
            BufferedReader in = new BufferedReader(new InputStreamReader(connection.getInputStream()));
            String line;
            String bandNote = "";
            while ((line = in.readLine()) != null) {
                bandNote += line + "\n";
            }
            in.close();

            bandNote = this.removeSpecialCharsFromString(bandNote);

            Log.d("70K_NOTE_DEBUG", "Saving default note for " + bandName + ": " + bandNote);
            bandNoteHandler.saveDefaultBandNote(bandNote);

        } catch (MalformedURLException mue) {
            Log.e("70K_NOTE_DEBUG", "descriptionMapFile malformed url error", mue);
        } catch (IOException ioe) {
            Log.e("70K_NOTE_DEBUG", "descriptionMapFile io error", ioe);
        } catch (SecurityException se) {
            Log.e("70K_NOTE_DEBUG", "descriptionMapFile security error", se);
        } catch (Exception generalError) {
            Log.e("70K_NOTE_DEBUG", "Downloading descriptionMapFile", generalError);
        }
    }

    /**
     * Removes special characters and preserves newlines for native TextView display.
     * @param text The text to clean.
     * @return The cleaned text.
     */
    private String removeSpecialCharsFromString(String text) {
        String fixedText = "";
        if (text != null) {
            // Preserve original line breaks for native TextView display
            // No longer convert to <br> tags since we're using native Android views
            fixedText = text; // Keep original line breaks intact
            fixedText = fixedText.replaceAll("[^\\p{ASCII}\\r\\n]", ""); // Remove non-ASCII except line breaks
            fixedText = fixedText.replaceAll("\\?", "");
        }
        return fixedText;
    }

    /**
     * Loads the note for a band from a remote URL if needed.
     * @param bandName The name of the band.
     */
    public void loadNoteFromURL(String bandName){

        BandNotes bandNoteHandler = new BandNotes(bandName);
        File oldBandNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note");
        if (oldBandNoteFile.exists() == true){
            Log.d("70K_NOTE_DEBUG", "Converting old band note for " + bandName);
            bandNoteHandler.convertOldBandNote();
        }

        try {
            // Note: Date is now embedded in the filename itself (bandName.note-DATE)
            // No need for separate changeFileFlag file anymore - fileExists() handles cache invalidation
            
            File bandCustNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note_cust");
            // PATCH: If a custom note exists, do NOT overwrite with default note from server
            if (bandCustNoteFile.exists()) {
                Log.d("70K_NOTE_DEBUG", "Custom note exists for " + bandName + ", skipping default note download and overwrite.");
                return;
            }
            
            // Check if we have a cached note with the current date
            // fileExists() automatically cleans up obsolete cache and returns true only if current date cache exists
            if (bandNoteHandler.fileExists() == true) {
                Log.d("70K_NOTE_DEBUG", "getDescription, cached note exists with current date for " + bandName + ", skipping download");
                return;
            } else {
                Log.d("70K_NOTE_DEBUG", "getDescription, no cached note with current date for " + bandName + ", downloading");
            }
            String normalizedBandName = normalizeBandName(bandName);
            if (descriptionMapData.containsKey(normalizedBandName) == false) {
                descriptionMapData = new HashMap<String,String>();
                getDescriptionMapFile();
                descriptionMapData = this.getDescriptionMap();
            }


            URL url;
            if (OnlineStatus.isOnline() == true) {

                try {
                    if (staticVariables.showNotesMap.containsKey(bandName) &&
                            staticVariables.showNotesMap.get(bandName).length() > 5) {
                        url = new URL(staticVariables.showNotesMap.get(bandName));
                        Log.d("70K_NOTE_DEBUG", "Looking up NoteData at URL " + url.toString());
                    } else if (descriptionMapData.containsKey(normalizedBandName) == true) {
                        url = new URL(descriptionMapData.get(normalizedBandName));
                        Log.d("70K_NOTE_DEBUG", "Looking up NoteData at URL " + url.toString());
                    } else {
                        Log.d("70K_NOTE_DEBUG", "no description for bandName " + normalizedBandName);
                        return;
                    }

                } catch (Exception error) {
                    Log.d("70K_NOTE_DEBUG", "could not load! for " + bandName + " - " + descriptionMapData.get(bandName));
                    return;
                }
            } else {
                Log.d("70K_NOTE_DEBUG", "Not online, skipping download for " + bandName);
                return;
            }

            // Handle HTTP redirects properly for Dropbox URLs
            HttpURLConnection connection = (HttpURLConnection) url.openConnection();
            connection.setInstanceFollowRedirects(true);
            connection.setConnectTimeout(10000); // 10 seconds
            connection.setReadTimeout(30000); // 30 seconds
            
            BufferedReader in = new BufferedReader(new InputStreamReader(connection.getInputStream()));
            String line;
            String bandNote = "";
            while ((line = in.readLine()) != null) {
                bandNote += line + "\n";
            }
            in.close();

            bandNote = this.removeSpecialCharsFromString(bandNote);

            Log.d("70K_NOTE_DEBUG", "Saving default note for " + bandName + ": " + bandNote);
            bandNoteHandler.saveDefaultBandNote(bandNote);

        } catch (MalformedURLException mue) {
            Log.e("70K_NOTE_DEBUG", "descriptionMapFile malformed url error", mue);
        } catch (IOException ioe) {
            Log.e("70K_NOTE_DEBUG", "descriptionMapFile io error", ioe);
        } catch (SecurityException se) {
            Log.e("70K_NOTE_DEBUG", "descriptionMapFile security error", se);

        } catch (Exception generalError) {
            Log.e("70K_NOTE_DEBUG", "Downloading descriptionMapFile", generalError);
        }
    }

    class AsyncAllDescriptionLoader extends AsyncTask<String, Void, ArrayList<String>> {

        ArrayList<String> result;

        @Override
        protected void onPreExecute() {
            super.onPreExecute();
            
            // SAFETY CHECK: Cancel task immediately if app is not in background or not fully initialized
            if (!Bands70k.isAppInBackground() || !showBands.appFullyInitialized) {
                Log.d("AsyncTask", "BLOCKED: AsyncAllDescriptionLoader.onPreExecute() - app is NOT in background (" + Bands70k.isAppInBackground() + ") or not fully initialized (" + showBands.appFullyInitialized + "), cancelling task");
                cancel(true);
                synchronized (lock) {
                    isRunning.set(false);
                    backgroundLoadingActive.set(false);
                }
                return;
            }
            
            Log.d("AsyncTask", "AsyncAllDescriptionLoader.onPreExecute() - app is in background, proceeding");
        }

        @Override
        protected ArrayList<String> doInBackground(String... params) {
            
            // SAFETY CHECK: Immediately stop if app is not in background or not fully initialized
            if (!Bands70k.isAppInBackground() || !showBands.appFullyInitialized) {
                Log.d("AsyncTask", "BLOCKED: AsyncAllDescriptionLoader started but app is NOT in background (" + Bands70k.isAppInBackground() + ") or not fully initialized (" + showBands.appFullyInitialized + ") - stopping immediately");
                return result;
            }

            CustomerDescriptionHandler descriptionHandler = CustomerDescriptionHandler.getInstance();
            StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
            StrictMode.setThreadPolicy(policy);

            Log.d("AsyncTask", "Downloading NoteData for all bands in background");
            
            // Wait for any existing notes loading to complete using proper synchronization
            if (!SynchronizationManager.waitForNotesLoadingComplete(10)) {
                Log.w("CustomerDescriptionHandler", "Timeout waiting for existing notes loading to complete");
                return result; // Don't proceed if we can't ensure exclusive access
            }

            // Signal that we're starting notes loading
            SynchronizationManager.signalNotesLoadingStarted();
            staticVariables.loadingNotes = true;
            staticVariables.notesLoaded = true;
            getDescriptionMapFile();
            descriptionMapData = descriptionHandler.getDescriptionMap();

            Log.d("AsyncTask", "Downloading NoteData for " + descriptionMapData);
            if (descriptionMapData != null) {
                for (String bandName : descriptionMapData.keySet()) {
                    // Check if task was cancelled or paused
                    if (isCancelled()) {
                        Log.d("AsyncTask", "Task cancelled, stopping background loading");
                        break;
                    }
                    
                    // SAFETY CHECK: Stop bulk downloading if app comes back to foreground
                    if (!Bands70k.isAppInBackground()) {
                        Log.d("AsyncTask", "BLOCKED: App returned to foreground, stopping bulk downloads");
                        break;
                    }
                    
                    // REMOVED: Old flawed logic that paused for details screen
                    // With proper Application-level background detection, bulk loading should proceed 
                    // when app is in background regardless of which screen was active when backgrounding occurred
                    
                    if (isCancelled()) {
                        break;
                    }
                    
                    Log.d("AsyncTask", "Downloading NoteData for " + bandName);
                    descriptionHandler.loadNoteFromURL(bandName);
                }
                staticVariables.notesLoaded = false;
            }

            return result;

        }

        @Override
        protected void onPostExecute(ArrayList<String> result) {
            synchronized (lock) {
                isRunning.set(false);
                backgroundLoadingActive.set(false);
                staticVariables.loadingNotes = false;
                SynchronizationManager.signalNotesLoadingComplete();
                Log.d("CustomerDescriptionHandler", "Background loading completed");
                
                // SAFETY CHECK: Only start translation pre-caching if still in background
                if (Bands70k.isAppInBackground()) {
                    Log.d("CustomerDescriptionHandler", "Starting translation pre-caching (app still in background)");
                    startTranslationPreCaching();
                } else {
                    Log.d("CustomerDescriptionHandler", "BLOCKED: Translation pre-caching skipped - app returned to foreground");
                }
            }
        }

        @Override
        protected void onCancelled() {
            synchronized (lock) {
                isRunning.set(false);
                backgroundLoadingActive.set(false);
                Log.d("CustomerDescriptionHandler", "Background loading cancelled");
            }
        }
    }

    class AsyncDescriptionLoader extends AsyncTask<String, Void, ArrayList<String>> {

        ArrayList<String> result;

        @Override
        protected void onPreExecute() {
            super.onPreExecute();
        }

        @Override
        protected ArrayList<String> doInBackground(String... params) {

            StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
            StrictMode.setThreadPolicy(policy);

            String bandName = params[0];
            Log.d("AsyncTask", "Downloading NoteData for " + bandName);

            loadNoteFromURL(bandName);

            return result;

        }

        @Override
        protected void onPostExecute(ArrayList<String> result) {

        }
    }
    
    /**
     * Starts translation pre-caching for offline use at sea
     * ONLY runs when app is in background to prevent inappropriate bulk downloads.
     */
    private void startTranslationPreCaching() {
        // SAFETY CHECK: Only run translation caching when app is in background
        if (!Bands70k.isAppInBackground()) {
            Log.d("TranslationCache", "BLOCKED: Translation pre-caching attempted when app is NOT in background!");
            return;
        }
        
        // Get application context - we need to find a way to get context
        // This will be called from the async task, so we need to get context differently
        try {
            // We'll use the static context from staticVariables if available
            Context context = staticVariables.context;
            if (context == null) {
                Log.d("TranslationCache", "No context available, skipping translation pre-caching");
                return;
            }
            
            BandDescriptionTranslator translator = BandDescriptionTranslator.getInstance(context);
            
            // Check if translation is supported
            if (!translator.isTranslationSupported()) {
                Log.d("TranslationCache", "Translation not supported for current language, skipping pre-caching");
                return;
            }
            
            // Get all band descriptions for caching
            Map<String, String> allDescriptions = new HashMap<>();
            if (descriptionMapData != null) {
                for (String bandName : descriptionMapData.keySet()) {
                    String description = getDescription(bandName);
                    if (description != null && !description.trim().isEmpty() && 
                        !FestivalConfig.getInstance().isDefaultDescriptionText(description)) {
                        allDescriptions.put(bandName, description);
                    }
                }
            }
            
            if (allDescriptions.isEmpty()) {
                Log.d("TranslationCache", "No descriptions available for translation caching");
                return;
            }
            
            Log.d("TranslationCache", "Starting translation pre-caching for " + allDescriptions.size() + " bands");
            
            // First ensure translation model is downloaded, then start bulk translation caching
            Log.d("TranslationCache", "Ensuring translation model is downloaded before bulk caching");
            translator.ensureTranslationModelDownloaded(new BandDescriptionTranslator.TranslationCallback() {
                @Override
                public void onTranslationComplete(String result) {
                    Log.d("TranslationCache", "Translation model ready, starting bulk translation caching for " + allDescriptions.size() + " bands");
                    
                    // Now start bulk translation caching
                    translator.preCacheTranslationsForOffline(allDescriptions, new BandDescriptionTranslator.BulkTranslationCallback() {
                        @Override
                        public void onProgress(int completed, int total) {
                            Log.d("TranslationCache", "Translation caching progress: " + completed + "/" + total);
                        }
                        
                        @Override
                        public void onComplete() {
                            Log.d("TranslationCache", "Translation pre-caching completed successfully! Ready for offline use at sea.");
                        }
                        
                        @Override
                        public void onError(String error) {
                            Log.e("TranslationCache", "Translation pre-caching failed: " + error);
                        }
                    });
                }
                
                @Override
                public void onTranslationError(String error) {
                    Log.e("TranslationCache", "Failed to download translation model, skipping bulk translation caching: " + error);
                }
            });
            
        } catch (Exception e) {
            Log.e("TranslationCache", "Error starting translation pre-caching", e);
        }
    }
}

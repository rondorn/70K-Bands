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
     */
    private CustomerDescriptionHandler(){
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
        Log.d("CustomerDescriptionHandler", "Pausing background loading");
        isPaused.set(true);
        detailsScreenActive.set(true);
    }

    /**
     * Resumes the background loading (called when exiting details screen).
     */
    public static void resumeBackgroundLoading() {
        Log.d("CustomerDescriptionHandler", "Resuming background loading");
        isPaused.set(false);
        detailsScreenActive.set(false);
        
        // Restart background loading if it was active
        if (backgroundLoadingActive.get()) {
            CustomerDescriptionHandler handler = getInstance();
            handler.startBackgroundLoading();
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
     */
    public void getDescriptionMapFile(){

        BandInfo bandInfo = new BandInfo();
        bandInfo.getDownloadtUrls();

        String descriptionMapURL = staticVariables.descriptionMap;

        if (OnlineStatus.isOnline() == true && Looper.myLooper() != Looper.getMainLooper()) {
            try {

                URL u = new URL(descriptionMapURL);
                InputStream is = u.openStream();

                DataInputStream dis = new DataInputStream(is);

                byte[] buffer = new byte[1024];
                int length;

                FileOutputStream fos = new FileOutputStream(FileHandler70k.descriptionMapFile);
                while ((length = dis.read(buffer)) > 0) {
                    fos.write(buffer, 0, length);
                }


            } catch (MalformedURLException mue) {
                Log.e("SYNC getUpdate", "descriptionMapFile malformed url error", mue);
            } catch (IOException ioe) {
                Log.e("SYNC getUpdate", "descriptionMapFile io error", ioe);
            } catch (SecurityException se) {
                Log.e("SYNC getUpdate", "descriptionMapFile security error", se);

            } catch (Exception generalError) {
                Log.e("General Exception", "Downloading descriptionMapFile", generalError);
            }

            Log.d("descriptionMapFile", "descriptionMapFile Downloaded!");
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
        Log.d("SKILTRON_DEBUG", "Description map URL being used: " + descriptionMapURL);

        if (OnlineStatus.isOnline() == true) {
            try {
                Log.d("70K_NOTE_DEBUG", "Downloading description map immediately from: " + descriptionMapURL);
                
                URL u = new URL(descriptionMapURL);
                InputStream is = u.openStream();

                DataInputStream dis = new DataInputStream(is);

                byte[] buffer = new byte[1024];
                int length;

                FileOutputStream fos = new FileOutputStream(FileHandler70k.descriptionMapFile);
                while ((length = dis.read(buffer)) > 0) {
                    fos.write(buffer, 0, length);
                }
                dis.close();
                fos.close();

                Log.d("70K_NOTE_DEBUG", "Description map file downloaded successfully");

            } catch (MalformedURLException mue) {
                Log.e("70K_NOTE_DEBUG", "descriptionMapFile malformed url error", mue);
            } catch (IOException ioe) {
                Log.e("70K_NOTE_DEBUG", "descriptionMapFile io error", ioe);
            } catch (SecurityException se) {
                Log.e("70K_NOTE_DEBUG", "descriptionMapFile security error", se);
            } catch (Exception generalError) {
                Log.e("70K_NOTE_DEBUG", "Error downloading descriptionMapFile immediately", generalError);
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

            while ((line = br.readLine()) != null) {
                String[] rowData = line.split(",");
                if (!"Band".equals(rowData[0])) {
                    String normalizedBandName = normalizeBandName(rowData[0]);
                    Log.d("descriptionMapFile", "Adding " + normalizedBandName + "-" + rowData[1]);
                    descriptionMapData.put(normalizedBandName, rowData[1]);
                    if (rowData.length > 2){
                        Log.d("descriptionMapFile", "Date value is " + rowData[2]);
                        staticVariables.descriptionMapModData.put(normalizedBandName, rowData[2]);
                    }
                }
            }
            br.close();
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
                    while ((line = br.readLine()) != null) {
                        String[] rowData = line.split(",");
                        if (rowData[0] != "Band") {
                            String normalizedBandName = normalizeBandName(rowData[0]);
                            Log.d("descriptionMapFile", "Adding " + normalizedBandName + "-" + rowData[1]);
                            descriptionMapData.put(normalizedBandName, rowData[1]);
                            if (rowData.length > 2){
                                Log.d("descriptionMapFile", "Date value is " + rowData[2]);
                                staticVariables.descriptionMapModData.put(normalizedBandName, rowData[2]);
                            }
                        }
                    }
                    br.close();
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
     */
    public void getAllDescriptions(){
        synchronized (lock) {
            // Check if already running
            if (isRunning.get()) {
                Log.d("CustomerDescriptionHandler", "Background loading already running, skipping");
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
     */
    private void startBackgroundLoading() {
        if (isRunning.compareAndSet(false, true)) {
            Log.d("CustomerDescriptionHandler", "Starting background loading");
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
        String bandNoteDefault = "Comment text is not available yet. Please wait for Aaron to add his description. You can add your own if you choose, but when his becomes available it will not overwrite your data, and will not display.";
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
        String bandNoteDefault = "Comment text is not available yet. Please wait for Aaron to add his description. You can add your own if you choose, but when his becomes available it will not overwrite your data, and will not display.";
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

        // Ensure description map file exists before trying to read it
        boolean mapFileWasDownloaded = false;
        if (!FileHandler70k.descriptionMapFile.exists()) {
            Log.d("70K_NOTE_DEBUG", "Description map file doesn't exist, downloading it immediately");
            getDescriptionMapFileImmediate();
            mapFileWasDownloaded = true;
        }

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
            File changeFileFlag = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + "-" + String.valueOf(staticVariables.descriptionMapModData.get(bandName)));
            File bandCustNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note_cust");
            
            // If a custom note exists, do NOT overwrite with default note from server
            if (bandCustNoteFile.exists()) {
                Log.d("70K_NOTE_DEBUG", "Custom note exists for " + bandName + ", skipping default note download and overwrite.");
                return;
            }
            
            if (bandNoteHandler.fileExists() == true && changeFileFlag.exists() == false && bandCustNoteFile.exists() == false) {
                Log.d("70K_NOTE_DEBUG", "getDescription, re-downloading default data due to change! " + bandName);
            } else if (bandNoteHandler.fileExists() == true) {
                Log.d("70K_NOTE_DEBUG", "getDescription, NOT re-downloading default data due to change! " + bandName);
                return;
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

            BufferedReader in = new BufferedReader(new InputStreamReader(url.openStream()));
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

            File changeFileFlag = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + "-" + String.valueOf(staticVariables.descriptionMapModData.get(bandName)));
            File bandCustNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note_cust");
            // PATCH: If a custom note exists, do NOT overwrite with default note from server
            if (bandCustNoteFile.exists()) {
                Log.d("70K_NOTE_DEBUG", "Custom note exists for " + bandName + ", skipping default note download and overwrite.");
                return;
            }
            if (bandNoteHandler.fileExists() == true && changeFileFlag.exists() == false && bandCustNoteFile.exists() == false){
                Log.d("70K_NOTE_DEBUG", "getDescription, re-downloading default data due to change! " + bandName);

            } else if (bandNoteHandler.fileExists() == true){
                Log.d("70K_NOTE_DEBUG", "getDescription, NOT re-downloading default data due to change! "+ bandName);
                return;
            }
            Log.d("70K_NOTE_DEBUG", "getDescription, NOT re-downloading default data due to change! "+ bandName);
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

            BufferedReader in = new BufferedReader(new InputStreamReader(url.openStream()));
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
        }

        @Override
        protected ArrayList<String> doInBackground(String... params) {

            CustomerDescriptionHandler descriptionHandler = CustomerDescriptionHandler.getInstance();
            StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
            StrictMode.setThreadPolicy(policy);

            Log.d("AsyncTask", "Downloading NoteData for all bands in background");
            
            // Wait for any existing loading to complete
            while (staticVariables.loadingNotes == true) {
                SystemClock.sleep(2000);
            }

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
                    
                    // Check if paused (details screen active)
                    while (isPaused.get() && !isCancelled()) {
                        Log.d("AsyncTask", "Paused due to details screen, waiting...");
                        SystemClock.sleep(1000);
                    }
                    
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
                Log.d("CustomerDescriptionHandler", "Background loading completed");
                
                // Start translation pre-caching for offline use
                startTranslationPreCaching();
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
     */
    private void startTranslationPreCaching() {
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
                        !description.contains("Comment text is not available yet")) {
                        allDescriptions.put(bandName, description);
                    }
                }
            }
            
            if (allDescriptions.isEmpty()) {
                Log.d("TranslationCache", "No descriptions available for translation caching");
                return;
            }
            
            Log.d("TranslationCache", "Starting translation pre-caching for " + allDescriptions.size() + " bands");
            
            // Start bulk translation caching
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
            
        } catch (Exception e) {
            Log.e("TranslationCache", "Error starting translation pre-caching", e);
        }
    }
}

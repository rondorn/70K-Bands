package com.Bands70k;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Build;
import android.os.StrictMode;
import android.os.SystemClock;
import android.util.Log;

import java.io.BufferedReader;
import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.URI;
import java.net.URL;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.PriorityQueue;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Handles downloading and managing band images.
 * Created by rdorn on 10/5/17.
 */

public class ImageHandler {

    // Singleton instance
    private static ImageHandler instance;
    public static final Object lock = new Object();
    
    // Instance tracking
    public static final AtomicBoolean isRunning = new AtomicBoolean(false);
    private static final AtomicBoolean isPaused = new AtomicBoolean(false);
    private static final AtomicInteger currentYear = new AtomicInteger(0);
    
    // Background loading state
    public static final AtomicBoolean backgroundLoadingActive = new AtomicBoolean(false);
    private static final AtomicBoolean detailsScreenActive = new AtomicBoolean(false);
    
    // Year change tracking (prevent bulk loading immediately after year change)
    private static final AtomicLong lastYearChangeTime = new AtomicLong(0);
    
    // Background task reference
    private AsyncAllImageLoader currentBackgroundTask;

    // Instance fields for background loading
    public String bandName;
    public File bandImageFile;

    /**
     * Private constructor for singleton pattern.
     */
    private ImageHandler(){

    }

    /**
     * Constructor for specific band image handling.
     * @param bandNameValue The name of the band.
     */
    public ImageHandler(String bandNameValue){
        this.bandName = bandNameValue;
        // Use same path logic as other methods to ensure consistency
        String cacheFilename = getCacheFilename(bandNameValue);
        bandImageFile = new File(FileHandler70k.baseImageDirectory + "/" + cacheFilename);
    }

    /**
     * Gets the singleton instance of ImageHandler.
     * @return The singleton instance.
     */
    public static synchronized ImageHandler getInstance() {
        if (instance == null) {
            instance = new ImageHandler();
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
        Log.d("ImageHandler", "pauseBackgroundLoading() called - DISABLED (using Application-level background detection)");
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
        Log.d("ImageHandler", "resumeBackgroundLoading() called - DISABLED (using Application-level background detection)");
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
            Log.d("ImageHandler", "Cancelling background task");
            currentBackgroundTask.cancel(true);
            isRunning.set(false);
            backgroundLoadingActive.set(false);
        }
    }

    /**
     * Gets the cache filename for a band image, using date-based naming for schedule images.
     * Also cleans up old schedule images with different dates.
     * @param bandName The name of the band
     * @return The filename (e.g., "BandName.png" or "BandName_schedule_20240101.png")
     */
    String getCacheFilename(String bandName) {
        CombinedImageListHandler combinedHandler = CombinedImageListHandler.getInstance();
        String imageDate = combinedHandler.getImageDate(bandName);
        
        // Clean up old schedule images if date changed (must happen before checking cache)
        if (imageDate != null && !imageDate.trim().isEmpty()) {
            String sanitizedDate = sanitizeDateForFilename(imageDate.trim());
            cleanupOldScheduleImages(bandName, sanitizedDate);
            // Schedule image with date - use date-based filename
            String filename = bandName + "_schedule_" + sanitizedDate + ".png";
            Log.d("ImageFile", "Using date-based cache filename for " + bandName + ": " + filename);
            return filename;
        } else {
            // Artist image or schedule without date - use standard filename
            return bandName + ".png";
        }
    }
    
    /**
     * Sanitizes a date string to be safe for use in filenames.
     * Replaces forward slashes and other problematic characters with dashes.
     * @param date The date string (e.g., "12-7/2025")
     * @return Sanitized date string (e.g., "12-7-2025")
     */
    private String sanitizeDateForFilename(String date) {
        if (date == null) {
            return "";
        }
        // Replace forward slashes with dashes to avoid directory path issues
        return date.replace("/", "-");
    }
    
    /**
     * Gets the URL hash file path for a cached image.
     * @param imageFile The image file
     * @return The URL hash file
     */
    private File getUrlHashFile(File imageFile) {
        String hashFilePath = imageFile.getAbsolutePath() + ".url";
        return new File(hashFilePath);
    }
    
    /**
     * Checks if the cached image exists (for display purposes).
     * 
     * DISPLAY STRATEGY: If the file exists, it's valid for display!
     * - Date expiration is handled automatically by filename (getCacheFilename includes date)
     * - URL changes do NOT prevent display (show what we have, update in background)
     * 
     * @param bandName The name of the band
     * @param imageFile The cached image file
     * @return True if the cached image exists, false otherwise
     */
    boolean isCachedImageValid(String bandName, File imageFile) {
        // Simple check: if file exists, use it for display!
        boolean exists = imageFile.exists();
        
        if (exists) {
            Log.d("ImageFile", "Cached image found for " + bandName + " - using it");
        } else {
            Log.d("ImageFile", "No cached image for " + bandName);
        }
        
        return exists;
    }
    
    /**
     * Checks if the cached image needs updating (for background loading purposes).
     * This is used during background loading to determine if we should re-download.
     * 
     * BACKGROUND LOADING STRATEGY:
     * - If file doesn't exist, needs update
     * - If file exists but URL changed, needs update (only for schedule images)
     * - If file exists and URL matches, no update needed
     * 
     * @param bandName The name of the band
     * @param imageFile The cached image file
     * @return True if the image needs updating, false if cached image is current
     */
    boolean needsImageUpdate(String bandName, File imageFile) {
        if (!imageFile.exists()) {
            Log.d("ImageFile", "No cached image for " + bandName + " - needs download");
            return true;
        }
        
        // Check if this is a schedule image (has ImageDate)
        CombinedImageListHandler combinedHandler = CombinedImageListHandler.getInstance();
        String imageDate = combinedHandler.getImageDate(bandName);
        
        // Artist images (no ImageDate) never need updating once downloaded
        if (imageDate == null || imageDate.trim().isEmpty()) {
            Log.d("ImageFile", "Artist image exists for " + bandName + " - no update needed");
            return false;
        }
        
        // Schedule image - check if URL changed
        String currentUrl = combinedHandler.getImageUrl(bandName);
        if (currentUrl == null || currentUrl.trim().isEmpty()) {
            currentUrl = BandInfo.getImageUrl(bandName);
        }
        
        if (currentUrl == null || currentUrl.trim().isEmpty() || currentUrl.equals(" ")) {
            // No URL available, no update possible
            return false;
        }
        
        // Check stored URL
        File urlHashFile = getUrlHashFile(imageFile);
        String storedUrl = null;
        
        if (urlHashFile.exists()) {
            try {
                java.io.FileReader reader = new java.io.FileReader(urlHashFile);
                java.io.BufferedReader bufferedReader = new java.io.BufferedReader(reader);
                String line = bufferedReader.readLine();
                if (line != null && line.contains("|")) {
                    String[] parts = line.split("\\|", 2);
                    if (parts.length > 1) {
                        storedUrl = parts[1].trim();
                    }
                }
                bufferedReader.close();
                reader.close();
            } catch (Exception e) {
                Log.e("ImageFile", "Error reading URL hash file: " + e.getMessage());
            }
        }
        
        // If no stored URL, assume it needs update (old format or first download)
        if (storedUrl == null || storedUrl.trim().isEmpty()) {
            Log.d("ImageFile", "No stored URL for " + bandName + " - needs update");
            return true;
        }
        
        // Compare URLs
        if (!storedUrl.equals(currentUrl)) {
            Log.d("ImageFile", "URL changed for " + bandName + " - needs update");
            return true;
        }
        
        Log.d("ImageFile", "Cached image is current for " + bandName + " - no update needed");
        return false;
    }
    
    /**
     * Saves the URL hash and actual URL for a downloaded image.
     * Only saves hash for schedule images (with ImageDate) - artist images don't need URL validation.
     * Stores both hash and URL to avoid hash collision issues.
     * @param imageFile The image file
     * @param imageUrl The URL that was used to download the image
     * @param imageDate The ImageDate if this is a schedule image, null for artist images
     */
    private void saveUrlHash(File imageFile, String imageUrl, String imageDate) {
        // Only save URL hash for schedule images (with ImageDate)
        // Artist images don't expire, so they don't need URL validation
        if (imageDate == null || imageDate.trim().isEmpty()) {
            Log.d("ImageFile", "Skipping URL hash save for artist image " + imageFile.getName() + " (no expiration)");
            return;
        }
        
        if (imageUrl == null || imageUrl.trim().isEmpty() || imageUrl.equals(" ")) {
            return;
        }
        
        try {
            File urlHashFile = getUrlHashFile(imageFile);
            java.io.FileWriter writer = new java.io.FileWriter(urlHashFile);
            String urlHash = String.valueOf(imageUrl.hashCode());
            // Store both hash and URL: "hash|url" format
            // This allows us to detect hash collisions by comparing actual URLs
            writer.write(urlHash + "|" + imageUrl);
            writer.close();
            Log.d("ImageFile", "Saved URL hash and URL for schedule image " + imageFile.getName() + " (date: " + imageDate + "): hash=" + urlHash + ", url=" + imageUrl);
        } catch (Exception e) {
            Log.e("ImageFile", "Error saving URL hash: " + e.getMessage());
        }
    }
    
    /**
     * Cleans up old schedule images for a band when ImageDate changes.
     * Deletes any old date-based cache files that don't match the current date.
     * @param bandName The name of the band
     * @param currentDate The current ImageDate (null if no date)
     */
    private void cleanupOldScheduleImages(String bandName, String currentDate) {
        if (bandName == null || bandName.isEmpty()) {
            return;
        }
        
        File imageDir = FileHandler70k.baseImageDirectory;
        if (!imageDir.exists() || !imageDir.isDirectory()) {
            return;
        }
        
        // Pattern: bandName_schedule_*.png
        String prefix = bandName + "_schedule_";
        File[] files = imageDir.listFiles();
        if (files == null) {
            return;
        }
        
        int deletedCount = 0;
        for (File file : files) {
            String filename = file.getName();
            if (filename.startsWith(prefix) && filename.endsWith(".png")) {
                // Extract date from filename: bandName_schedule_DATE.png
                String dateFromFilename = filename.substring(prefix.length(), filename.length() - 4);
                
                // Delete if date doesn't match current date (or if currentDate is null/empty)
                if (currentDate == null || currentDate.trim().isEmpty() || !dateFromFilename.equals(currentDate.trim())) {
                    if (file.delete()) {
                        deletedCount++;
                        Log.d("ImageFile", "Deleted old schedule image: " + filename);
                    }
                }
            }
        }
        
        if (deletedCount > 0) {
            Log.d("ImageFile", "Cleaned up " + deletedCount + " old schedule image(s) for " + bandName);
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
            Log.d("ImageHandler", "Year changed from " + oldYear + " to " + newYear + ", resetting state");
            currentYear.set(newYear);
            isRunning.set(false);
            isPaused.set(false);
            backgroundLoadingActive.set(false);
            detailsScreenActive.set(false);
            
            // Record year change time to prevent immediate bulk loading
            lastYearChangeTime.set(System.currentTimeMillis());
            Log.d("ImageHandler", "Year change timestamp recorded: " + lastYearChangeTime.get());
            
            // Clear image URL and date maps to force reloading for new year
            staticVariables.imageUrlMap.clear();
            staticVariables.imageDateMap.clear();
            
            // Cancel current background task if running
            if (currentBackgroundTask != null && !currentBackgroundTask.isCancelled()) {
                currentBackgroundTask.cancel(true);
            }
            
            // DO NOT restart background loading automatically after year change
            // Bulk loading should only happen when app goes to background (onPause)
            Log.d("ImageHandler", "Year change complete - bulk loading will only occur when app goes to background");
            
            return true;
        }
        
        if (oldYear == 0) {
            currentYear.set(newYear);
        }
        
        return false;
    }


    public URI getImage(){

        URI localURL;
        String cacheFilename = getCacheFilename(this.bandName);
        this.bandImageFile = new File(FileHandler70k.baseImageDirectory + "/" + cacheFilename);
        if (this.bandName.isEmpty() == true){
            Log.d("loadImageFile", "image file already exists band null, returning");
            return null;
        }

        Log.d("loadImageFile", "getImage called for " + this.bandName + " at " + bandImageFile.getAbsolutePath());

        // Simple check: if cached image exists, use it
        if (isCachedImageValid(this.bandName, bandImageFile)) {
            localURL = bandImageFile.toURI();
            Log.d("loadImageFile", "Using cached image for " + this.bandName);
        } else {
            localURL = null;
            Log.d("loadImageFile", "No cached image for " + this.bandName);
        }

        return localURL;
    }

    /**
     * Gets the image for a band immediately, loading it if needed.
     * This method is used when the details screen needs to load an image immediately.
     * 
     * CACHE-FIRST STRATEGY:
     * 1. If cached image exists, USE IT (regardless of online/offline or URL changes)
     * 2. If no cached image exists AND online, download it
     * 3. If no cached image exists AND offline, return null
     * 
     * @return The image URI or null if not available.
     */
    public URI getImageImmediate(){

        URI localURL;
        String cacheFilename = getCacheFilename(this.bandName);
        this.bandImageFile = new File(FileHandler70k.baseImageDirectory + "/" + cacheFilename);
        if (this.bandName.isEmpty() == true){
            Log.d("loadImageFile", "image file already exists band null, returning");
            return null;
        }

        Log.d("loadImageFile", "getImageImmediate called for " + this.bandName + ", file exists: " + bandImageFile.exists());

        // SIMPLE CACHE-FIRST LOGIC: Use cache if exists, otherwise download if online
        if (isCachedImageValid(this.bandName, bandImageFile)) {
            // Cached image exists - use it!
            localURL = bandImageFile.toURI();
            Log.d("loadImageFile", "Using cached image for " + this.bandName);
        } else {
            // No cached image - download if online
            Log.d("loadImageFile", "No cached image for " + this.bandName + ", attempting download");
            downloadImageImmediate();
            
            if (bandImageFile.exists()) {
                localURL = bandImageFile.toURI();
                Log.d("loadImageFile", "Image downloaded successfully for " + this.bandName);
            } else {
                localURL = null;
                Log.d("loadImageFile", "Image not available for " + this.bandName);
            }
        }

        return localURL;
    }

    /**
     * Downloads the image for a band immediately, bypassing background loading pause.
     * IMPORTANT: Only downloads if device is online - cached images should already be loaded via getImage().
     */
    private void downloadImageImmediate() {
        try {
            // CRITICAL FIX: Check if device is online before attempting download
            if (!OnlineStatus.isOnline()) {
                Log.d("loadImageFile", "Device is offline, skipping image download for " + this.bandName);
                return;
            }
            
            // Use CombinedImageListHandler to get image URL and date
            CombinedImageListHandler combinedHandler = CombinedImageListHandler.getInstance();
            String imageUrl = combinedHandler.getImageUrl(this.bandName);
            String imageDate = combinedHandler.getImageDate(this.bandName);
            
            // Fallback to BandInfo if not found in combined list
            if (imageUrl == null || imageUrl.trim().isEmpty()) {
                imageUrl = BandInfo.getImageUrl(this.bandName);
                imageDate = null; // Artist images don't have dates
            }
            
            if (imageUrl != null && !imageUrl.trim().isEmpty() && !imageUrl.equals(" ")) {
                Log.d("loadImageFile", "Downloading image immediately from URL: " + imageUrl);
                
                URL url = new URL(imageUrl);
                java.net.HttpURLConnection connection = (java.net.HttpURLConnection) url.openConnection();
                connection.setInstanceFollowRedirects(true);
                HttpConnectionHelper.applyTimeouts(connection);
                InputStream in = new BufferedInputStream(connection.getInputStream());
                FileOutputStream out = new FileOutputStream(bandImageFile);
                
                byte[] buffer = new byte[1024];
                int bytesRead;
                while ((bytesRead = in.read(buffer)) != -1) {
                    out.write(buffer, 0, bytesRead);
                }
                
                in.close();
                out.close();
                try { connection.disconnect(); } catch (Exception ignored) {}
                
                // Save URL hash for cache validation (only for schedule images with ImageDate)
                saveUrlHash(bandImageFile, imageUrl, imageDate);
                
                Log.d("loadImageFile", "Image downloaded successfully for " + this.bandName);
            } else {
                Log.d("loadImageFile", "No image URL available for " + this.bandName);
            }
        } catch (Exception e) {
            Log.e("loadImageFile", "Error downloading image for " + this.bandName, e);
        }
    }

    public void getRemoteImage(){
        Log.d("ImageFile", "Getting remote image for " + bandName);
        
        // Use CombinedImageListHandler to get image URL and date
        CombinedImageListHandler combinedHandler = CombinedImageListHandler.getInstance();
        String imageUrl = combinedHandler.getImageUrl(bandName);
        String imageDate = combinedHandler.getImageDate(bandName);
        
        // Fallback to BandInfo if not found in combined list
        if (imageUrl == null || imageUrl.trim().isEmpty()) {
            imageUrl = BandInfo.getImageUrl(bandName);
            imageDate = null; // Artist images don't have dates
        }
        
        Log.d("ImageFile", "Image URL for " + bandName + ": " + imageUrl);
        if (imageDate != null && !imageDate.trim().isEmpty()) {
            Log.d("ImageFile", "ImageDate for " + bandName + ": " + imageDate);
        }
        
        // Clean up old schedule images if date changed
        if (imageDate != null && !imageDate.trim().isEmpty()) {
            cleanupOldScheduleImages(bandName, imageDate.trim());
        }
        
        // Get cache filename (date-based for schedule images, standard for artist images)
        String cacheFilename = getCacheFilename(bandName);
        bandImageFile = new File(FileHandler70k.baseImageDirectory + "/" + cacheFilename);
        Log.d("ImageFile", "Cache filename: " + cacheFilename);
        Log.d("ImageFile", "Online status: " + OnlineStatus.isOnline());
        
        if (OnlineStatus.isOnline() == true && imageUrl != null && !imageUrl.trim().isEmpty() && !imageUrl.equals(" ")) {
            try {
                Log.d("ImageFile", "Downloading image from URL: " + imageUrl);
                URL url = new URL(imageUrl);
                java.net.HttpURLConnection connection = (java.net.HttpURLConnection) url.openConnection();
                connection.setInstanceFollowRedirects(true);
                HttpConnectionHelper.applyTimeouts(connection);
                InputStream in = new BufferedInputStream(connection.getInputStream());
                OutputStream out = new BufferedOutputStream(new FileOutputStream(bandImageFile.getAbsoluteFile()));
                
                byte[] buffer = new byte[1024];
                int bytesRead;
                while ((bytesRead = in.read(buffer)) != -1) {
                    out.write(buffer, 0, bytesRead);
                }
                
                in.close();
                out.close();
                try { connection.disconnect(); } catch (Exception ignored) {}
                
                // Save URL hash for cache validation (only for schedule images with ImageDate)
                saveUrlHash(bandImageFile, imageUrl, imageDate);
                
                Log.d("ImageFile", "Image downloaded successfully for " + this.bandName + " to " + cacheFilename);
            } catch (Exception error) {
                Log.e("ImageFile", "Unable to get band Image file " + error.getMessage());
            }
        } else {
            Log.d("ImageFile", "Skipping image download - offline or no valid URL for " + this.bandName);
        }
    }

    /**
     * Starts background loading of all images with proper synchronization.
     * This method should only be called when the app is moved to background.
     */
    public void getAllRemoteImages(){
        synchronized (lock) {
            // Check if already running
            if (isRunning.get()) {
                Log.d("ImageHandler", "Background loading already running, skipping");
                return;
            }
            
            // Check year change and clear cache if needed
            if (checkYearChange()) {
                Log.d("ImageHandler", "Year changed detected, cache cleared - now starting background loading");
            }
            
            startBackgroundLoading();
        }
    }
    
    /**
     * DEPRECATED: No longer starts background loading.
     * All downloads now happen in foreground only (after 30 seconds) to avoid Android 15 restrictions.
     * This method is kept for compatibility but does nothing.
     */
    @Deprecated
    public void startBackgroundLoadingOnPause() {
        Log.d("ImageHandler", "startBackgroundLoadingOnPause called but background loading is disabled");
        Log.d("ImageHandler", "All downloads now happen in foreground only (after 30 seconds)");
        // No longer starting background downloads - all downloads happen in foreground
    }

    /**
     * Starts the background loading task.
     */
    private void startBackgroundLoading() {
        if (isRunning.compareAndSet(false, true)) {
            Log.d("ImageHandler", "Starting background loading");
            backgroundLoadingActive.set(true);
            
            currentBackgroundTask = new AsyncAllImageLoader();
            currentBackgroundTask.execute();
        }
    }

    /**
     * Loads all remote images in the background using the combined image list.
     * This handles image expiration and updates during background loading.
     */
    private void loadAllRemoteImagesInBackground(){

        // Use the combined image list instead of separate band list and imageUrlMap
        CombinedImageListHandler combinedHandler = CombinedImageListHandler.getInstance();
        Map<String, String> combinedImageList = combinedHandler.getCombinedImageList();

        Log.d("ImageFile", "Loading all images from combined image list with " + combinedImageList.size() + " entries");

        for (Map.Entry<String, String> entry : combinedImageList.entrySet()) {
            String bandNameTmp = entry.getKey();
            String imageUrl = entry.getValue();
            
            this.bandName = bandNameTmp;
            String cacheFilename = getCacheFilename(this.bandName);
            bandImageFile = new File(FileHandler70k.baseImageDirectory + "/" + cacheFilename);
            
            Log.d("ImageFile", "Checking cached image for " + bandNameTmp + " at " + bandImageFile.getAbsolutePath());
            // Check if image needs updating (URL changed, missing, etc.)
            if (needsImageUpdate(this.bandName, bandImageFile)) {
                Log.d("ImageFile", "Image needs update for " + bandNameTmp + ", downloading");
                this.getRemoteImage();
            } else {
                Log.d("ImageFile", "Image is current for " + bandNameTmp + ", skipping download");
            }
        }
    }
}

class AsyncImageLoader extends AsyncTask<String, Void, ArrayList<String>> {

    @Override
    protected ArrayList<String> doInBackground(String... params) {

        StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
        StrictMode.setThreadPolicy(policy);

        Log.d("AsyncTask_ImageFile", "Downloading Image data for " + params[0]);

        try {
            ImageHandler imageHandler = new ImageHandler(params[0]);
            imageHandler.getRemoteImage();

        } catch (Exception error){
            Log.d("bandInfo", error.getMessage());
        }

        return null;
    }
}

class AsyncAllImageLoader extends AsyncTask<String, Void, ArrayList<String>> {

    ArrayList<String> result;

    @Override
    protected void onPreExecute() {
        super.onPreExecute();
    }

    @Override
    protected ArrayList<String> doInBackground(String... params) {

        ImageHandler imageHandler = ImageHandler.getInstance();
        StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
        StrictMode.setThreadPolicy(policy);

        Log.d("AsyncTask", "Downloading Image data for all bands in background");

        // Wait for any existing notes loading to complete using proper synchronization
        if (!SynchronizationManager.waitForNotesLoadingComplete(10)) {
            Log.w("ImageHandler", "Timeout waiting for notes loading to complete - proceeding anyway");
        }

        Log.d("AsyncTask", "Starting image download for all bands");
        
        // Load images in batches to allow for pause/resume
        BandInfo bandInfo = new BandInfo();
        ArrayList<String> bandList = bandInfo.getBandNames();

        // Use the combined image list instead of separate lists
        CombinedImageListHandler combinedHandler = CombinedImageListHandler.getInstance();
        Map<String, String> combinedImageList = combinedHandler.getCombinedImageList();

        Log.d("AsyncTask", "Starting image download for combined image list with " + combinedImageList.size() + " entries");

        for (Map.Entry<String, String> entry : combinedImageList.entrySet()) {
            String bandNameTmp = entry.getKey();
            String imageUrl = entry.getValue();
            
            // Check if task was cancelled or paused
            if (isCancelled()) {
                Log.d("AsyncTask", "Task cancelled, stopping image loading");
                break;
            }
            
            // REMOVED: Old flawed logic that paused for details screen
            // With proper Application-level background detection, bulk loading should proceed 
            // when app is in background regardless of which screen was active when backgrounding occurred
            
            if (isCancelled()) {
                break;
            }
            
            Log.d("AsyncTask", "Checking cached image for " + bandNameTmp);
            imageHandler.bandName = bandNameTmp;
            String cacheFilename = imageHandler.getCacheFilename(bandNameTmp);
            imageHandler.bandImageFile = new File(FileHandler70k.baseImageDirectory + "/" + cacheFilename);
            // Check if image needs updating during background loading
            if (imageHandler.needsImageUpdate(bandNameTmp, imageHandler.bandImageFile)) {
                Log.d("AsyncTask", "Image needs update for " + bandNameTmp + ", downloading");
                imageHandler.getRemoteImage();
            } else {
                Log.d("AsyncTask", "Image is current for " + bandNameTmp + ", skipping download");
            }
        }

        return result;

    }

    @Override
    protected void onPostExecute(ArrayList<String> result) {
        synchronized (ImageHandler.lock) {
            ImageHandler.isRunning.set(false);
            ImageHandler.backgroundLoadingActive.set(false);
            Log.d("ImageHandler", "Background loading completed");
        }
    }

    @Override
    protected void onCancelled() {
        synchronized (ImageHandler.lock) {
            ImageHandler.isRunning.set(false);
            ImageHandler.backgroundLoadingActive.set(false);
            Log.d("ImageHandler", "Background loading cancelled");
        }
    }
}



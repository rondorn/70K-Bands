package com.Bands70k;

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
        bandImageFile = new File(FileHandler70k.imageDirectory + bandName + ".png");
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
            cleanupOldScheduleImages(bandName, imageDate.trim());
            // Schedule image with date - use date-based filename
            String filename = bandName + "_schedule_" + imageDate.trim() + ".png";
            Log.d("ImageFile", "Using date-based cache filename for " + bandName + ": " + filename);
            return filename;
        } else {
            // Artist image or schedule without date - use standard filename
            return bandName + ".png";
        }
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
     * Checks if the cached image is valid.
     * 
     * For artist images (no ImageDate): Only checks if file exists - these should never expire.
     * For schedule images (has ImageDate): Checks both file existence AND URL changes - these expire when date or URL changes.
     * 
     * @param bandName The name of the band
     * @param imageFile The cached image file
     * @return True if the cached image is valid, false if invalid or file doesn't exist
     */
    boolean isCachedImageValid(String bandName, File imageFile) {
        if (!imageFile.exists()) {
            return false;
        }
        
        // Check if this is a schedule image (has ImageDate)
        CombinedImageListHandler combinedHandler = CombinedImageListHandler.getInstance();
        String imageDate = combinedHandler.getImageDate(bandName);
        
        // If no ImageDate, this is an artist image - these should never expire
        // Just check if file exists (already checked above)
        if (imageDate == null || imageDate.trim().isEmpty()) {
            Log.d("ImageFile", "Artist image found for " + bandName + " (no expiration)");
            return true;
        }
        
        // This is a schedule image with ImageDate - need to check URL changes
        // Note: Date changes are already handled by filename (getCacheFilename includes date)
        Log.d("ImageFile", "Schedule image found for " + bandName + " with date " + imageDate + ", checking URL validity");
        
        // Get current URL
        String currentUrl = combinedHandler.getImageUrl(bandName);
        
        // Fallback to BandInfo if not found in combined list
        if (currentUrl == null || currentUrl.trim().isEmpty()) {
            currentUrl = BandInfo.getImageUrl(bandName);
        }
        
        if (currentUrl == null || currentUrl.trim().isEmpty() || currentUrl.equals(" ")) {
            // No URL available, consider cached image valid (might be a placeholder)
            return true;
        }
        
        // Get stored URL hash
        File urlHashFile = getUrlHashFile(imageFile);
        String storedUrlHash = null;
        String storedUrl = null; // Also store the actual URL for comparison
        
        if (urlHashFile.exists()) {
            try {
                java.io.FileReader reader = new java.io.FileReader(urlHashFile);
                java.io.BufferedReader bufferedReader = new java.io.BufferedReader(reader);
                String line = bufferedReader.readLine();
                if (line != null) {
                    // Check if line contains both hash and URL (format: "hash|url") or just hash
                    if (line.contains("|")) {
                        String[] parts = line.split("\\|", 2);
                        storedUrlHash = parts[0].trim();
                        if (parts.length > 1) {
                            storedUrl = parts[1].trim();
                        }
                    } else {
                        // Old format - just hash
                        storedUrlHash = line.trim();
                    }
                }
                bufferedReader.close();
                reader.close();
            } catch (Exception e) {
                Log.e("ImageFile", "Error reading URL hash file: " + e.getMessage());
            }
        }
        
        // Compute current URL hash
        String currentUrlHash = String.valueOf(currentUrl.hashCode());
        
        // If no stored hash exists, assume the cached image is from an older version
        // and might be invalid - delete it to force re-download
        if (storedUrlHash == null || storedUrlHash.trim().isEmpty()) {
            Log.d("ImageFile", "No URL hash found for schedule image " + imageFile.getName() + ", deleting to force re-download");
            imageFile.delete();
            urlHashFile.delete(); // Also delete the hash file if it exists
            return false;
        }
        
        // Compare hashes AND actual URLs (hash collisions are possible, so check URL directly)
        boolean hashMatches = storedUrlHash.trim().equals(currentUrlHash);
        boolean urlMatches = (storedUrl != null && storedUrl.equals(currentUrl));
        
        Log.d("ImageFile", "URL validation for " + bandName + ": stored hash=" + storedUrlHash + ", current hash=" + currentUrlHash + ", hash matches=" + hashMatches);
        if (storedUrl != null) {
            Log.d("ImageFile", "URL comparison: stored='" + storedUrl + "', current='" + currentUrl + "', URL matches=" + urlMatches);
        } else {
            Log.d("ImageFile", "Old format hash file detected (no URL stored) for " + bandName + ", will compare URLs directly");
        }
        
        // CRITICAL: If stored URL is null (old format), we can't verify URL match, so force re-download
        // This ensures old cached images get updated with new format that includes URL
        if (storedUrl == null || storedUrl.trim().isEmpty()) {
            Log.d("ImageFile", "Old format hash file (no URL) for " + bandName + ", deleting to force re-download with new format");
            imageFile.delete();
            urlHashFile.delete();
            return false;
        }
        
        // If hash matches but we have stored URL, also check URL directly to avoid hash collisions
        if (hashMatches && !urlMatches) {
            Log.d("ImageFile", "Hash collision detected! Hash matches but URL differs for " + bandName + ", deleting cached image");
            Log.d("ImageFile", "  Stored URL: " + storedUrl);
            Log.d("ImageFile", "  Current URL: " + currentUrl);
            imageFile.delete();
            urlHashFile.delete();
            return false;
        }
        
        // If hash doesn't match, URL definitely changed
        if (!hashMatches) {
            Log.d("ImageFile", "URL changed for schedule image " + bandName + " (old hash: " + storedUrlHash + ", new hash: " + currentUrlHash + "), deleting cached image");
            imageFile.delete();
            urlHashFile.delete();
            return false;
        }
        
        // URL matches (both hash and actual URL), cached image is valid
        Log.d("ImageFile", "Schedule image valid for " + bandName + " (URL matches)");
        return true;
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

        Log.e("loadImageFile", "does image file exist " + bandImageFile.getAbsolutePath());
        /*
        if (bandImageFile.exists() == false) {

            AsyncImageLoader myImageTask = new AsyncImageLoader();
            myImageTask.execute(bandName);

            Log.e("loadImageFile", "image file already exists Downloading image file from URL" + BandInfo.getImageUrl(this.bandName));

        }
        */

        // Check if cached image is valid (exists and URL matches)
        if (isCachedImageValid(this.bandName, bandImageFile)) {
            localURL = bandImageFile.toURI();
            Log.d("loadImageFile", "image file exists and URL matches " + localURL.toString());
        } else {
            localURL = null;
            Log.d("loadImageFile", "image file does not exist or URL changed " + bandImageFile.getAbsolutePath());
        }

        return localURL;
    }

    /**
     * Gets the image for a band immediately, loading it if needed.
     * This method is used when the details screen needs to load an image immediately.
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

        // Check if cached image is valid (exists and URL matches)
        // Date changes are automatically handled by filename - if date changes, filename changes, so file won't exist
        // URL changes are handled by URL hash validation in isCachedImageValid
        if (!isCachedImageValid(this.bandName, bandImageFile)) {
            Log.d("loadImageFile", "Image file does not exist or URL changed, downloading immediately for " + this.bandName);
            downloadImageImmediate();
        } else {
            Log.d("loadImageFile", "Cached image is valid for " + this.bandName);
        }

        if (bandImageFile.exists() == true){
            localURL = bandImageFile.toURI();
            Log.d("loadImageFile", "image file exists " + localURL.toString());
        } else {
            localURL = null;
            Log.d("loadImageFile", "image file does not exist after download attempt " + bandImageFile.getAbsolutePath());
        }

        return localURL;
    }

    /**
     * Downloads the image for a band immediately, bypassing background loading pause.
     */
    private void downloadImageImmediate() {
        try {
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
                InputStream in = new BufferedInputStream(url.openStream());
                FileOutputStream out = new FileOutputStream(bandImageFile);
                
                byte[] buffer = new byte[1024];
                int bytesRead;
                while ((bytesRead = in.read(buffer)) != -1) {
                    out.write(buffer, 0, bytesRead);
                }
                
                in.close();
                out.close();
                
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
                InputStream in = new BufferedInputStream(url.openStream());
                OutputStream out = new BufferedOutputStream(new FileOutputStream(bandImageFile.getAbsoluteFile()));
                
                byte[] buffer = new byte[1024];
                int bytesRead;
                while ((bytesRead = in.read(buffer)) != -1) {
                    out.write(buffer, 0, bytesRead);
                }
                
                in.close();
                out.close();
                
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
     * Starts background loading of all images when app goes to background.
     * This method should be called from the main activity's onPause() method.
     * Prevents bulk loading immediately after year change to avoid inappropriate downloads.
     */
    public void startBackgroundLoadingOnPause() {
        synchronized (lock) {
            Log.d("ImageHandler", "startBackgroundLoadingOnPause called - isAppInBackground: " + Bands70k.isAppInBackground());
            
            // CRITICAL SAFETY CHECK: Only proceed if app is actually in background AND fully initialized
            if (!Bands70k.isAppInBackground()) {
                Log.d("ImageHandler", "BLOCKED: startBackgroundLoadingOnPause called but app is NOT in background!");
                return;
            }
            
            if (!showBands.appFullyInitialized) {
                Log.d("ImageHandler", "BLOCKED: startBackgroundLoadingOnPause called but app is NOT fully initialized!");
                return;
            }
            
            // Check if it's too soon after a year change (prevent bulk loading for 10 seconds)
            long timeSinceYearChange = System.currentTimeMillis() - lastYearChangeTime.get();
            if (timeSinceYearChange < 10000) { // 10 seconds
                Log.d("ImageHandler", "Skipping bulk loading - too soon after year change (" + timeSinceYearChange + "ms)");
                return;
            }
            
            // Only start background loading if not already running
            if (!isRunning.get()) {
                Log.d("ImageHandler", "Starting background loading due to app going to background");
                getAllRemoteImages();
            } else {
                Log.d("ImageHandler", "Background loading already running, skipping");
            }
        }
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
            // Check if cached image is valid (exists and URL matches)
            if (!isCachedImageValid(this.bandName, bandImageFile)) {
                Log.d("ImageFile", "Cached image invalid or missing for " + bandNameTmp + ", downloading");
                this.getRemoteImage();
            } else {
                Log.d("ImageFile", "Cached image valid for " + bandNameTmp + ", skipping download");
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
            // Check if cached image is valid (exists and URL matches)
            if (!imageHandler.isCachedImageValid(bandNameTmp, imageHandler.bandImageFile)) {
                Log.d("AsyncTask", "Cached image invalid or missing for " + bandNameTmp + ", downloading");
                imageHandler.getRemoteImage();
            } else {
                Log.d("AsyncTask", "Cached image valid for " + bandNameTmp + ", skipping download");
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



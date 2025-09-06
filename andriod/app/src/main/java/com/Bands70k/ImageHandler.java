package com.Bands70k;

import android.net.Uri;
import android.os.AsyncTask;
import android.os.Build;
import android.os.StrictMode;
import android.os.SystemClock;
import android.util.Log;

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
            
            // Clear image URL map to force reloading for new year
            staticVariables.imageUrlMap.clear();
            
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
        this.bandImageFile = new File(FileHandler70k.baseImageDirectory + "/" + this.bandName + ".png");
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

        if (bandImageFile.exists() == true){
            localURL = bandImageFile.toURI();
            Log.d("loadImageFile", "image file exists " + localURL.toString());
        } else {
            localURL = null;
            Log.d("loadImageFile", "image file does not exist " + bandImageFile.getAbsolutePath());
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
        this.bandImageFile = new File(FileHandler70k.baseImageDirectory + "/" + this.bandName + ".png");
        if (this.bandName.isEmpty() == true){
            Log.d("loadImageFile", "image file already exists band null, returning");
            return null;
        }

        Log.d("loadImageFile", "getImageImmediate called for " + this.bandName + ", file exists: " + bandImageFile.exists());

        // If image doesn't exist, try to download it immediately
        if (bandImageFile.exists() == false) {
            Log.d("loadImageFile", "Image file does not exist, downloading immediately for " + this.bandName);
            downloadImageImmediate();
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
            // Use CombinedImageListHandler to get image URL
            CombinedImageListHandler combinedHandler = CombinedImageListHandler.getInstance();
            String imageUrl = combinedHandler.getImageUrl(this.bandName);
            
            // Fallback to BandInfo if not found in combined list
            if (imageUrl == null || imageUrl.trim().isEmpty()) {
                imageUrl = BandInfo.getImageUrl(this.bandName);
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
        
        // Use CombinedImageListHandler to get image URL
        CombinedImageListHandler combinedHandler = CombinedImageListHandler.getInstance();
        String imageUrl = combinedHandler.getImageUrl(bandName);
        
        // Fallback to BandInfo if not found in combined list
        if (imageUrl == null || imageUrl.trim().isEmpty()) {
            imageUrl = BandInfo.getImageUrl(bandName);
        }
        
        Log.d("ImageFile", "Image URL for " + bandName + ": " + imageUrl);
        bandImageFile = new File(FileHandler70k.baseImageDirectory + "/" + this.bandName + ".png");
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
                Log.d("ImageFile", "Image downloaded successfully for " + this.bandName);
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
            bandImageFile = new File(FileHandler70k.baseImageDirectory + "/" + this.bandName + ".png");
            
            Log.d("ImageFile", "does band Imagefile exist " + bandImageFile.getAbsolutePath());
            if (bandImageFile.exists() == false) {
                Log.d("ImageFile", "does band Imagefile exist, NO " + bandImageFile.getAbsolutePath());
                this.getRemoteImage();
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
            
            Log.d("AsyncTask", "Downloading image for " + bandNameTmp);
            imageHandler.bandName = bandNameTmp;
            imageHandler.bandImageFile = new File(FileHandler70k.baseImageDirectory + "/" + imageHandler.bandName + ".png");
            if (imageHandler.bandImageFile.exists() == false) {
                imageHandler.getRemoteImage();
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



package com.Bands70k;

import android.app.Activity;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;
import android.util.Log;

import androidx.core.app.NotificationCompat;

import java.io.File;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Foreground service for all background network operations (images, notes, Firebase reporting).
 * Required for Android 15+ to access network when app is in background.
 */
public class ImageDownloadService extends Service {

    private static final String TAG = "BackgroundNetworkService";
    private static final String CHANNEL_ID = "background_network_channel";
    private static final int NOTIFICATION_ID = 1001;
    
    private static final AtomicBoolean isRunning = new AtomicBoolean(false);
    
    /**
     * Sets the running state (used when running in thread mode, not service mode).
     */
    public static void setRunning(boolean running) {
        isRunning.set(running);
        Log.d(TAG, "Setting isRunning to " + running);
    }
    private static ImageDownloadService serviceInstance = null;
    private Thread downloadThread;
    private static final AtomicInteger tasksCompleted = new AtomicInteger(0);
    private static final AtomicInteger tasksTotal = new AtomicInteger(0);
    private static final AtomicInteger currentProgress = new AtomicInteger(0);
    private static final AtomicInteger currentTotal = new AtomicInteger(0);
    private static final AtomicBoolean isForegroundMode = new AtomicBoolean(false);
    private static String currentTask = "Preparing...";
    private static String currentDetails = "";

    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "BackgroundNetworkService created");
        createNotificationChannel();
        serviceInstance = this; // Store instance for static access
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d(TAG, "BackgroundNetworkService started");
        
        // Check if already running
        if (isRunning.get()) {
            Log.d(TAG, "Service already running, ignoring start request");
            return START_NOT_STICKY;
        }
        
        // Check if app is in background - if so, start as foreground service
        // If app is in foreground, run as regular service (no notification needed)
        boolean appInBackground = Bands70k.isAppInBackground();
        
        if (appInBackground) {
            Log.d(TAG, "App is in background, starting as foreground service");
            // Start as foreground service with notification (required for background network access)
            startForeground(NOTIFICATION_ID, createNotification(0, 0, "Starting..."));
        } else {
            Log.d(TAG, "App is in foreground, running as regular service (no notification)");
            // Running in foreground - no need for foreground service notification
        }
        
        // Start download thread
        isRunning.set(true);
        tasksCompleted.set(0);
        tasksTotal.set(0);
        currentTask = "Preparing...";
        
        downloadThread = new Thread(new DownloadTaskRunner());
        downloadThread.start();
        
        return START_NOT_STICKY;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        Log.d(TAG, "BackgroundNetworkService destroyed");
        isRunning.set(false);
        serviceInstance = null; // Clear instance reference
        
        // Wait for download thread to finish (with timeout)
        if (downloadThread != null && downloadThread.isAlive()) {
            try {
                downloadThread.join(5000); // Wait max 5 seconds
            } catch (InterruptedException e) {
                Log.w(TAG, "Interrupted while waiting for download thread");
            }
        }
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    /**
     * Creates the notification channel for Android O+.
     */
    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "Background Sync",
                NotificationManager.IMPORTANCE_LOW // Low priority - user can dismiss
            );
            channel.setDescription("Syncing data in background");
            channel.setShowBadge(false);
            
            NotificationManager notificationManager = getSystemService(NotificationManager.class);
            if (notificationManager != null) {
                notificationManager.createNotificationChannel(channel);
            }
        }
    }

    /**
     * Creates a notification for the foreground service.
     */
    private Notification createNotification(int completed, int total, String task) {
        Intent intent = new Intent(this, showBands.class);
        PendingIntent pendingIntent = PendingIntent.getActivity(
            this, 0, intent, 
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ? PendingIntent.FLAG_IMMUTABLE : 0
        );

        String contentText;
        if (total > 0) {
            contentText = task + ": " + completed + " / " + total;
        } else {
            contentText = task;
        }

        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Syncing Data")
            .setContentText(contentText)
            .setSmallIcon(R.drawable.new_bands_70k_icon)
            .setContentIntent(pendingIntent)
            .setOngoing(false) // User can dismiss
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOnlyAlertOnce(true);

        // Add progress bar if we have totals
        if (total > 0) {
            builder.setProgress(total, completed, false);
        }

        return builder.build();
    }

    /**
     * Updates the notification with current progress.
     */
    private void updateNotification(int completed, int total, String task) {
        currentTask = task;
        NotificationManager notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        if (notificationManager != null) {
            notificationManager.notify(NOTIFICATION_ID, createNotification(completed, total, task));
        }
    }
    
    /**
     * Static method to update notification (can be called from thread or service).
     * Updates static variables for progress tracking.
     * If service is running, updates the service's notification.
     */
    private static void updateNotificationStatic(int completed, int total, String task) {
        currentTask = task;
        currentProgress.set(completed);
        currentTotal.set(total);
        
        // If service is running, update its notification
        if (isRunning.get() && serviceInstance != null) {
            serviceInstance.updateNotification(completed, total, task);
        }
        // Progress dialog will read from static variables
    }

    /**
     * Static method to run download task (can be called from thread or service).
     * Note: isRunning should be set to true before calling this when running in thread mode.
     */
    public static void runDownloadTask() {
        Log.d(TAG, "runDownloadTask called, isRunning=" + isRunning.get());
        new DownloadTaskRunner().run();
    }
    
    /**
     * Task runner that handles all background network operations: images, notes, and Firebase reporting.
     * Can be run in a thread (when app is in foreground) or in a service (when app is in background).
     */
    public static class DownloadTaskRunner implements Runnable {
        @Override
        public void run() {
            try {
                Log.d(TAG, "Starting download task");
                
                // CRITICAL: Check if online - if offline, skip all downloads
                if (!OnlineStatus.isOnline()) {
                    Log.d(TAG, "Device is offline, skipping all downloads");
                    ForegroundDownloadManager.updateFloatingProgress(0, 0, "Offline - skipping downloads");
                    // Still mark tasks as complete since we checked
                    tasksCompleted.set(3); // Images, notes, Firebase all "complete" (skipped)
                    tasksTotal.set(3);
                    return;
                }
                
                Log.d(TAG, "Device is online, proceeding with downloads");
                
                // Calculate total tasks for progress tracking
                int imageCount = 0;
                int noteCount = 0;
                try {
                    CombinedImageListHandler combinedHandler = CombinedImageListHandler.getInstance();
                    imageCount = combinedHandler.getCombinedImageList().size();
                } catch (Exception e) {
                    Log.w(TAG, "Could not get image count", e);
                }
                try {
                    CustomerDescriptionHandler descHandler = CustomerDescriptionHandler.getInstance();
                    Map<String, String> descMap = descHandler.getDescriptionMap();
                    noteCount = (descMap != null) ? descMap.size() : 0;
                } catch (Exception e) {
                    Log.w(TAG, "Could not get note count", e);
                }
                int totalTasks = imageCount + noteCount + 1; // +1 for Firebase
                tasksTotal.set(totalTasks);
                Log.d(TAG, "Total tasks: " + totalTasks + " (images: " + imageCount + ", notes: " + noteCount + ", firebase: 1)");
                
                // PHASE 1: Download Images
                downloadImages();
                
                // PHASE 2: Download Notes/Descriptions
                downloadNotes();
                
                // PHASE 3: Firebase Reporting
                performFirebaseReporting();
                
                Log.d(TAG, "All download tasks completed");
                
                // Update notification with completion (if running as service)
                if (isRunning.get()) {
                    updateNotificationStatic(tasksCompleted.get(), tasksTotal.get(), "Complete");
                    
                    // Wait a moment so user can see completion
                    try {
                        Thread.sleep(2000);
                    } catch (InterruptedException e) {
                        // Ignore
                    }
                }
                
            } catch (Exception e) {
                Log.e(TAG, "Error in download task", e);
            } finally {
                // Mark as not downloading
                boolean wasService = isRunning.get();
                isRunning.set(false);
                ForegroundDownloadManager.setDownloading(false);
                
                // If running as service, stop it
                if (wasService) {
                    Context context = Bands70k.getAppContext();
                    if (context != null) {
                        context.stopService(new Intent(context, ImageDownloadService.class));
                    }
                }
            }
        }
        
        /**
         * Downloads images in the background.
         */
        private void downloadImages() {
            if (!isRunning.get()) {
                Log.w(TAG, "downloadImages: isRunning is false, skipping");
                return;
            }
            Log.d(TAG, "downloadImages: isRunning is true, proceeding");
            
            try {
                Log.d(TAG, "Starting image download phase");
                
                // Check if online before starting
                if (!OnlineStatus.isOnline()) {
                    Log.d(TAG, "Offline, skipping image downloads");
                    return;
                }
                
                updateNotificationStatic(0, 0, "Downloading images...");
                
                // Use ImageHandler to download images
                ImageHandler imageHandler = ImageHandler.getInstance();
                
                // Get the combined image list
                CombinedImageListHandler combinedHandler = CombinedImageListHandler.getInstance();
                Map<String, String> combinedImageList = combinedHandler.getCombinedImageList();
                
                int total = combinedImageList.size();
                
                // OPTIMIZATION: Quickly count how many images need updating before starting
                int needsUpdate = 0;
                Log.d(TAG, "Quick cache check: scanning " + total + " images to count what needs downloading");
                for (Map.Entry<String, String> entry : combinedImageList.entrySet()) {
                    String bandName = entry.getKey();
                    String cacheFilename = imageHandler.getCacheFilename(bandName);
                    java.io.File imageFile = new java.io.File(FileHandler70k.baseImageDirectory + "/" + cacheFilename);
                    if (imageHandler.needsImageUpdate(bandName, imageFile)) {
                        needsUpdate++;
                    }
                }
                
                Log.d(TAG, "Cache check complete: " + needsUpdate + " of " + total + " images need updating");
                
                // If nothing needs updating, skip the download phase entirely
                if (needsUpdate == 0) {
                    Log.d(TAG, "All images already cached, skipping image download phase");
                    currentTask = "Downloading images...";
                    currentDetails = "All images cached";
                    // Mark this phase as complete immediately
                    tasksCompleted.incrementAndGet();
                    // Don't show progress indicator when everything is cached - just move on silently
                    return;
                }
                
                int downloaded = 0;
                
                Log.d(TAG, "Found " + total + " images to check, " + needsUpdate + " need downloading");
                currentTask = "Downloading images...";
                currentTotal.set(needsUpdate); // Use needsUpdate as total for progress tracking (phase-specific)
                currentProgress.set(0);
                updateNotificationStatic(0, needsUpdate, "Downloading images...");
                // Show progress indicator ONLY when there's actual work to do
                Activity activity = ForegroundDownloadManager.getCurrentActivity();
                if (activity != null) {
                    ForegroundDownloadManager.showFloatingProgressIndicatorIfNeeded(activity);
                }
                // Show phase-specific progress: "0/needsUpdate" for images only
                ForegroundDownloadManager.updateFloatingProgress(0, needsUpdate, "Downloading images...");
                
                // Download each image that needs updating
                for (Map.Entry<String, String> entry : combinedImageList.entrySet()) {
                    // Check if service was stopped
                    if (!isRunning.get()) {
                        Log.d(TAG, "Service stopped, aborting image downloads");
                        break;
                    }
                    
                    // Check if still online
                    if (!OnlineStatus.isOnline()) {
                        Log.d(TAG, "Went offline during image downloads, stopping");
                        break;
                    }
                    
                    String bandName = entry.getKey();
                    
                    // Check if image needs updating
                    String cacheFilename = imageHandler.getCacheFilename(bandName);
                    java.io.File imageFile = new java.io.File(FileHandler70k.baseImageDirectory + "/" + cacheFilename);
                    
                    if (imageHandler.needsImageUpdate(bandName, imageFile)) {
                        Log.d(TAG, "Downloading image for " + bandName);
                        
                        // Create ImageHandler instance for this band
                        ImageHandler bandImageHandler = new ImageHandler(bandName);
                        bandImageHandler.getRemoteImage();
                        
                        downloaded++;
                        currentProgress.set(downloaded);
                        currentDetails = "Downloaded " + downloaded + " of " + needsUpdate + " images";
                        
                        // Update notification every 5 images or on last image
                        if (downloaded % 5 == 0 || downloaded == needsUpdate) {
                            updateNotificationStatic(downloaded, needsUpdate, "Downloading images...");
                            // Update floating progress indicator
                            ForegroundDownloadManager.updateFloatingProgress(downloaded, needsUpdate, "Downloading images...");
                        }
                    } else {
                        Log.d(TAG, "Image already cached for " + bandName + ", skipping");
                    }
                }
                
                Log.d(TAG, "Image download phase completed. Downloaded: " + downloaded + " / " + needsUpdate + " (total images: " + total + ")");
                tasksCompleted.incrementAndGet();
                // Update floating progress with overall progress
                ForegroundDownloadManager.updateFloatingProgress(tasksCompleted.get(), tasksTotal.get(), "Downloading images...");
                
            } catch (Exception e) {
                Log.e(TAG, "Error downloading images", e);
            }
        }
        
        /**
         * Downloads notes/descriptions in the background.
         */
        private void downloadNotes() {
            if (!isRunning.get()) {
                Log.w(TAG, "downloadNotes: isRunning is false, skipping");
                return;
            }
            Log.d(TAG, "downloadNotes: isRunning is true, proceeding");
            
            try {
                Log.d(TAG, "Starting notes download phase");
                
                // Check if online before starting
                if (!OnlineStatus.isOnline()) {
                    Log.d(TAG, "Offline, skipping note downloads");
                    return;
                }
                
                updateNotificationStatic(0, 0, "Downloading notes...");
                
                CustomerDescriptionHandler descriptionHandler = CustomerDescriptionHandler.getInstance();
                
                // Wait for any existing notes loading to complete
                if (!SynchronizationManager.waitForNotesLoadingComplete(10)) {
                    Log.w(TAG, "Timeout waiting for notes loading to complete");
                    return;
                }
                
                // Signal that we're starting notes loading
                SynchronizationManager.signalNotesLoadingStarted();
                staticVariables.loadingNotes = true;
                staticVariables.notesLoaded = true;
                
                // Get description map
                descriptionHandler.getDescriptionMapFile();
                Map<String, String> descriptionMapData = descriptionHandler.getDescriptionMap();
                
                if (descriptionMapData == null || descriptionMapData.isEmpty()) {
                    Log.d(TAG, "No notes to download");
                    staticVariables.loadingNotes = false;
                    SynchronizationManager.signalNotesLoadingComplete();
                    return;
                }
                
                int total = descriptionMapData.size();
                
                // OPTIMIZATION: Quickly count how many notes need downloading before starting
                int needsUpdate = 0;
                Log.d(TAG, "Quick cache check: scanning " + total + " notes to count what needs downloading");
                for (String bandName : descriptionMapData.keySet()) {
                    BandNotes bandNoteHandler = new BandNotes(bandName);
                    File bandCustNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note_cust");
                    
                    // Skip if custom note exists (won't be overwritten)
                    if (bandCustNoteFile.exists()) {
                        continue;
                    }
                    
                    // Check if cached note exists with current date
                    if (!bandNoteHandler.fileExists()) {
                        needsUpdate++;
                    }
                }
                
                Log.d(TAG, "Cache check complete: " + needsUpdate + " of " + total + " notes need downloading");
                
                // If nothing needs updating, skip the download phase entirely
                if (needsUpdate == 0) {
                    Log.d(TAG, "All notes already cached, skipping note download phase");
                    currentTask = "Downloading notes...";
                    currentDetails = "All notes cached";
                    // Mark this phase as complete immediately
                    tasksCompleted.incrementAndGet();
                    // Don't show progress indicator when everything is cached - just move on silently
                    staticVariables.loadingNotes = false;
                    staticVariables.notesLoaded = false;
                    SynchronizationManager.signalNotesLoadingComplete();
                    return;
                }
                
                int downloaded = 0;
                
                Log.d(TAG, "Found " + total + " notes to check, " + needsUpdate + " need downloading");
                currentTask = "Downloading notes...";
                currentTotal.set(needsUpdate); // Use needsUpdate as total for progress tracking (phase-specific)
                currentProgress.set(0);
                updateNotificationStatic(0, needsUpdate, "Downloading notes...");
                // Show progress indicator ONLY when there's actual work to do (if not already shown)
                Activity activity = ForegroundDownloadManager.getCurrentActivity();
                if (activity != null) {
                    ForegroundDownloadManager.showFloatingProgressIndicatorIfNeeded(activity);
                }
                // Show phase-specific progress: "0/needsUpdate" for notes only
                ForegroundDownloadManager.updateFloatingProgress(0, needsUpdate, "Downloading notes...");
                
                // Download each note that needs updating
                for (String bandName : descriptionMapData.keySet()) {
                    // Check if service was stopped
                    if (!isRunning.get()) {
                        Log.d(TAG, "Service stopped, aborting note downloads");
                        break;
                    }
                    
                    // Check if still online
                    if (!OnlineStatus.isOnline()) {
                        Log.d(TAG, "Went offline during note downloads, stopping");
                        break;
                    }
                    
                    BandNotes bandNoteHandler = new BandNotes(bandName);
                    File bandCustNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note_cust");
                    
                    // Skip if custom note exists (won't be overwritten)
                    if (bandCustNoteFile.exists()) {
                        continue;
                    }
                    
                    // Check if cached note exists with current date
                    if (!bandNoteHandler.fileExists()) {
                        Log.d(TAG, "Downloading note for " + bandName);
                        descriptionHandler.loadNoteFromURL(bandName);
                        
                        downloaded++;
                        currentProgress.set(downloaded);
                        currentDetails = "Downloaded " + downloaded + " of " + needsUpdate + " notes";
                        
                        // Update notification every 5 notes or on last note
                        if (downloaded % 5 == 0 || downloaded == needsUpdate) {
                            updateNotificationStatic(downloaded, needsUpdate, "Downloading notes...");
                            // Update floating progress indicator
                            ForegroundDownloadManager.updateFloatingProgress(downloaded, needsUpdate, "Downloading notes...");
                        }
                    } else {
                        Log.d(TAG, "Note already cached for " + bandName + ", skipping");
                    }
                }
                
                staticVariables.notesLoaded = false;
                staticVariables.loadingNotes = false;
                SynchronizationManager.signalNotesLoadingComplete();
                
                Log.d(TAG, "Notes download phase completed. Downloaded: " + downloaded + " / " + needsUpdate + " (total notes: " + total + ")");
                tasksCompleted.incrementAndGet();
                // Update floating progress with overall progress
                ForegroundDownloadManager.updateFloatingProgress(tasksCompleted.get(), tasksTotal.get(), "Downloading notes...");
                
            } catch (Exception e) {
                Log.e(TAG, "Error downloading notes", e);
                staticVariables.loadingNotes = false;
                SynchronizationManager.signalNotesLoadingComplete();
            }
        }
        
        /**
         * Performs Firebase reporting in the background.
         */
        private void performFirebaseReporting() {
            if (!isRunning.get()) return;
            
            try {
                Log.d(TAG, "Starting Firebase reporting phase");
                currentTask = "Uploading data to Firebase";
                currentDetails = "Uploading data to Firebase";
                // Firebase upload is a single operation - don't show progress indicator (only 1 record)
                currentTotal.set(1);
                currentProgress.set(0);
                updateNotificationStatic(0, 1, "Uploading data to Firebase");
                // Don't show floating progress for Firebase - it's only 1 record, not worth displaying
                
                // Perform Firebase writes
                FireBaseAsyncBandEventWrite firebaseTask = new FireBaseAsyncBandEventWrite();
                firebaseTask.execute();
                
                // Wait a bit for Firebase operations to complete
                Thread.sleep(3000);
                
                Log.d(TAG, "Firebase reporting phase completed");
                tasksCompleted.incrementAndGet();
                currentTask = "Complete";
                currentDetails = "All downloads completed";
                // Don't show completion for Firebase - it's only 1 record, not worth displaying
                updateNotificationStatic(1, 1, "Uploading data to Firebase");
                
            } catch (Exception e) {
                Log.e(TAG, "Error in Firebase reporting", e);
            }
        }
    }

    /**
     * Checks if the service is currently running.
     */
    public static boolean isRunning() {
        return isRunning.get();
    }
    
    /**
     * Starts foreground downloads as a service (called when user leaves app while downloads are running).
     */
    public static void startForegroundDownloads(Context context) {
        if (isRunning.get()) {
            Log.d(TAG, "Service already running");
            return;
        }
        
        // Check if downloads are already running in thread mode
        if (ForegroundDownloadManager.isDownloading()) {
            Log.d(TAG, "Downloads already running in thread mode, starting service to continue in background");
        }
        
        Log.d(TAG, "Starting foreground service for downloads");
        isForegroundMode.set(!Bands70k.isAppInBackground());
        ForegroundDownloadManager.setDownloading(true);
        
        Intent serviceIntent = new Intent(context, ImageDownloadService.class);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent);
        } else {
            context.startService(serviceIntent);
        }
    }
    
    /**
     * Gets the current task description for progress display.
     */
    public static String getCurrentTask() {
        return currentTask;
    }
    
    /**
     * Gets progress details for display.
     */
    public static String getProgressDetails() {
        return currentDetails;
    }
    
    /**
     * Gets current progress [completed, total].
     */
    public static int[] getProgress() {
        int completed = currentProgress.get();
        int total = currentTotal.get();
        if (total > 0) {
            return new int[]{completed, total};
        }
        return null;
    }
}


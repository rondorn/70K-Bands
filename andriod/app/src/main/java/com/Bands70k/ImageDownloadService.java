package com.Bands70k;

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
    private Thread downloadThread;
    private final AtomicInteger tasksCompleted = new AtomicInteger(0);
    private final AtomicInteger tasksTotal = new AtomicInteger(0);
    private String currentTask = "Preparing...";

    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "BackgroundNetworkService created");
        createNotificationChannel();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d(TAG, "BackgroundNetworkService started");
        
        // Check if already running
        if (isRunning.get()) {
            Log.d(TAG, "Service already running, ignoring start request");
            return START_NOT_STICKY;
        }
        
        // Start as foreground service with notification
        startForeground(NOTIFICATION_ID, createNotification(0, 0, "Starting..."));
        
        // Start download thread
        isRunning.set(true);
        tasksCompleted.set(0);
        tasksTotal.set(0);
        currentTask = "Preparing...";
        
        downloadThread = new Thread(new BackgroundNetworkTask());
        downloadThread.start();
        
        return START_NOT_STICKY;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        Log.d(TAG, "BackgroundNetworkService destroyed");
        isRunning.set(false);
        
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
     * Task that handles all background network operations: images, notes, and Firebase reporting.
     */
    private class BackgroundNetworkTask implements Runnable {
        @Override
        public void run() {
            try {
                Log.d(TAG, "Starting background network task");
                
                // PHASE 1: Download Images
                downloadImages();
                
                // PHASE 2: Download Notes/Descriptions
                downloadNotes();
                
                // PHASE 3: Firebase Reporting
                performFirebaseReporting();
                
                Log.d(TAG, "All background network tasks completed");
                
                // Update notification with completion
                updateNotification(tasksCompleted.get(), tasksTotal.get(), "Complete");
                
                // Wait a moment so user can see completion, then stop service
                try {
                    Thread.sleep(2000);
                } catch (InterruptedException e) {
                    // Ignore
                }
                
            } catch (Exception e) {
                Log.e(TAG, "Error in background network task", e);
            } finally {
                // Stop the service
                Log.d(TAG, "Stopping BackgroundNetworkService");
                isRunning.set(false);
                stopForeground(true);
                stopSelf();
            }
        }
        
        /**
         * Downloads images in the background.
         */
        private void downloadImages() {
            if (!isRunning.get()) return;
            
            try {
                Log.d(TAG, "Starting image download phase");
                updateNotification(0, 0, "Downloading images...");
                
                // Use ImageHandler to download images
                ImageHandler imageHandler = ImageHandler.getInstance();
                
                // Get the combined image list
                CombinedImageListHandler combinedHandler = CombinedImageListHandler.getInstance();
                Map<String, String> combinedImageList = combinedHandler.getCombinedImageList();
                
                int total = combinedImageList.size();
                int downloaded = 0;
                
                Log.d(TAG, "Found " + total + " images to check");
                updateNotification(0, total, "Downloading images...");
                
                // Download each image
                for (Map.Entry<String, String> entry : combinedImageList.entrySet()) {
                    // Check if service was stopped
                    if (!isRunning.get()) {
                        Log.d(TAG, "Service stopped, aborting image downloads");
                        break;
                    }
                    
                    String bandName = entry.getKey();
                    
                    Log.d(TAG, "Checking image for " + bandName);
                    
                    // Check if image needs updating
                    String cacheFilename = imageHandler.getCacheFilename(bandName);
                    java.io.File imageFile = new java.io.File(FileHandler70k.baseImageDirectory + "/" + cacheFilename);
                    
                    if (imageHandler.needsImageUpdate(bandName, imageFile)) {
                        Log.d(TAG, "Downloading image for " + bandName);
                        
                        // Create ImageHandler instance for this band
                        ImageHandler bandImageHandler = new ImageHandler(bandName);
                        bandImageHandler.getRemoteImage();
                        
                        downloaded++;
                        
                        // Update notification every 5 images or on last image
                        if (downloaded % 5 == 0 || downloaded == total) {
                            updateNotification(downloaded, total, "Downloading images...");
                        }
                    } else {
                        Log.d(TAG, "Image already cached for " + bandName);
                    }
                }
                
                Log.d(TAG, "Image download phase completed. Downloaded: " + downloaded + " / " + total);
                tasksCompleted.incrementAndGet();
                
            } catch (Exception e) {
                Log.e(TAG, "Error downloading images", e);
            }
        }
        
        /**
         * Downloads notes/descriptions in the background.
         */
        private void downloadNotes() {
            if (!isRunning.get()) return;
            
            try {
                Log.d(TAG, "Starting notes download phase");
                updateNotification(0, 0, "Downloading notes...");
                
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
                int downloaded = 0;
                
                Log.d(TAG, "Found " + total + " notes to check");
                updateNotification(0, total, "Downloading notes...");
                
                // Download each note
                for (String bandName : descriptionMapData.keySet()) {
                    // Check if service was stopped
                    if (!isRunning.get()) {
                        Log.d(TAG, "Service stopped, aborting note downloads");
                        break;
                    }
                    
                    Log.d(TAG, "Downloading note for " + bandName);
                    descriptionHandler.loadNoteFromURL(bandName);
                    
                    downloaded++;
                    
                    // Update notification every 5 notes or on last note
                    if (downloaded % 5 == 0 || downloaded == total) {
                        updateNotification(downloaded, total, "Downloading notes...");
                    }
                }
                
                staticVariables.notesLoaded = false;
                staticVariables.loadingNotes = false;
                SynchronizationManager.signalNotesLoadingComplete();
                
                Log.d(TAG, "Notes download phase completed. Downloaded: " + downloaded + " / " + total);
                tasksCompleted.incrementAndGet();
                
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
                updateNotification(0, 0, "Syncing to Firebase...");
                
                // Perform Firebase writes
                FireBaseAsyncBandEventWrite firebaseTask = new FireBaseAsyncBandEventWrite();
                firebaseTask.execute();
                
                // Wait a bit for Firebase operations to complete
                Thread.sleep(3000);
                
                Log.d(TAG, "Firebase reporting phase completed");
                tasksCompleted.incrementAndGet();
                updateNotification(0, 0, "Firebase sync complete");
                
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
}


package com.Bands70k;

import android.app.Activity;
import android.app.ActivityManager;
import android.app.AlertDialog;
import android.app.Dialog;
import android.content.Context;
import android.content.DialogInterface;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.ProgressBar;
import android.widget.TextView;
import com.Bands70k.Bands70k;
import com.Bands70k.showBands;
import com.Bands70k.R;
import com.Bands70k.OnlineStatus;

import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Manages foreground downloads with user interaction when trying to background the app.
 * Starts downloads immediately after CSV processing completes.
 */
public class ForegroundDownloadManager {
    
    private static final String TAG = "ForegroundDownloadManager";
    
    private static final AtomicBoolean isDownloading = new AtomicBoolean(false);
    private static final AtomicBoolean isDialogShowing = new AtomicBoolean(false);
    private static final AtomicBoolean justCameFromBackground = new AtomicBoolean(false);
    private static final AtomicBoolean initialDownloadsCompleted = new AtomicBoolean(false);
    
    private static Dialog progressDialog = null;
    private static ProgressBar progressBar = null;
    private static TextView progressText = null;
    private static TextView progressDetails = null;
    
    // Floating progress indicator
    private static View floatingProgressView = null;
    private static ProgressBar floatingProgressBar = null;
    private static TextView floatingProgressText = null;
    private static Activity currentActivity = null;
    
    /**
     * Called when app comes to foreground. No longer starts a timer - downloads start after CSV processing.
     */
    public static void onAppForegrounded() {
        Log.d(TAG, "App came to foreground - marking as just came from background");
        justCameFromBackground.set(true);
        // Downloads will be started after CSV processing completes
    }
    
    /**
     * Called when app goes to background.
     */
    public static void onAppBackgrounded() {
        Log.d(TAG, "App going to background");
        // Clear the flag when app goes to background
        justCameFromBackground.set(false);
        // Hide floating progress indicator when app goes to background
        hideFloatingProgressIndicator();
        // Note: We do NOT reset initialDownloadsCompleted here - it stays true for the app session
        // This ensures downloads only start again when coming from background, not when returning from internal screens
    }
    
    /**
     * Starts downloads immediately (called after CSV processing completes).
     * Starts on initial launch OR when coming from another app, but NOT when returning from details screen.
     */
    public static void startDownloadsAfterCSV(Activity activity) {
        if (isDownloading.get()) {
            Log.d(TAG, "Downloads already in progress, skipping");
            return;
        }
        
        // Check if we're returning from details screen - if so, don't START new downloads
        // but DO restore the progress indicator if downloads are already running
        if (showBands.returningFromDetailsScreen) {
            Log.d(TAG, "Returning from details screen, skipping new bulk downloads");
            justCameFromBackground.set(false); // Clear flag
            
            // But restore progress indicator if downloads are already running
            if (isDownloading.get() && activity != null) {
                Log.d(TAG, "Downloads still running, restoring progress indicator after details return");
                currentActivity = activity;
                showFloatingProgressIndicator(activity);
            }
            return;
        }
        
        // Start downloads if:
        // 1. We just came from background (another app) OR
        // 2. This is initial launch (appFullyInitialized is true AND we haven't completed initial downloads yet)
        boolean shouldStart = justCameFromBackground.get();
        
        // On initial launch, justCameFromBackground will be false, but we should still start downloads
        // Detect initial launch by checking if app is fully initialized AND initial downloads haven't been completed
        if (!shouldStart && showBands.appFullyInitialized && !initialDownloadsCompleted.get()) {
            // This is initial launch or first time CSV processing completes - start downloads
            Log.d(TAG, "Initial launch detected (appFullyInitialized=true, initialDownloadsCompleted=false), starting downloads");
            shouldStart = true;
        }
        
        if (!shouldStart) {
            Log.d(TAG, "Not coming from background and not initial launch, skipping bulk downloads");
            return;
        }
        
        // CRITICAL: Only start downloads if online
        if (!OnlineStatus.isOnline()) {
            Log.d(TAG, "Device is offline, skipping bulk downloads");
            justCameFromBackground.set(false); // Clear flag
            return;
        }
        
        Log.d(TAG, "Starting downloads immediately after CSV processing (online mode)");
        justCameFromBackground.set(false); // Clear flag after using it
        currentActivity = activity;
        // Don't show progress indicator yet - wait until we know there's actual work to do
        // The indicator will be shown by downloadImages() or downloadNotes() if there's work
        startForegroundDownloads();
    }
    
    /**
     * Checks if downloads are currently in progress.
     */
    public static boolean isDownloading() {
        return isDownloading.get();
    }
    
    /**
     * Shows floating progress indicator if it's not already shown.
     * Called when we know there's actual work to do.
     */
    public static void showFloatingProgressIndicatorIfNeeded(Activity activity) {
        if (floatingProgressView == null && activity != null) {
            showFloatingProgressIndicator(activity);
        }
    }
    
    /**
     * Shows a floating progress indicator at the bottom of the screen.
     */
    private static void showFloatingProgressIndicator(Activity activity) {
        if (activity == null || activity.isFinishing() || activity.isDestroyed()) {
            Log.w(TAG, "Cannot show floating progress - activity is null or invalid");
            return;
        }
        
        Log.d(TAG, "Attempting to show floating progress indicator");
        activity.runOnUiThread(() -> {
            try {
                // Find the root layout
                View rootView = activity.findViewById(android.R.id.content);
                if (rootView == null) {
                    rootView = activity.getWindow().getDecorView().getRootView();
                    Log.d(TAG, "Using decor view root");
                } else {
                    Log.d(TAG, "Using content view");
                }
                
                if (rootView == null) {
                    Log.e(TAG, "Could not find root view for floating progress");
                    return;
                }
                
                // Remove existing floating progress if any
                if (floatingProgressView != null) {
                    ViewGroup parent = (ViewGroup) floatingProgressView.getParent();
                    if (parent != null) {
                        parent.removeView(floatingProgressView);
                        Log.d(TAG, "Removed existing floating progress view");
                    }
                }
                
                // Create floating progress view - VERY WIDE but VERY SHORT
                android.widget.LinearLayout progressLayout = new android.widget.LinearLayout(activity);
                progressLayout.setOrientation(android.widget.LinearLayout.HORIZONTAL); // Horizontal layout
                progressLayout.setPadding(20, 6, 20, 6); // Minimal vertical padding, wider horizontal
                progressLayout.setBackgroundColor(0xE6000000); // Semi-transparent black
                progressLayout.setElevation(8);
                
                // Make it non-blocking - allow clicks to pass through
                progressLayout.setClickable(false);
                progressLayout.setFocusable(false);
                progressLayout.setFocusableInTouchMode(false);
                
                // Label - inline with progress bar
                floatingProgressText = new TextView(activity);
                floatingProgressText.setText(activity.getString(R.string.bulk_image_download) + ": ");
                floatingProgressText.setTextColor(0xFFFFFFFF);
                floatingProgressText.setTextSize(11); // Smaller text
                floatingProgressText.setPadding(0, 0, 8, 0); // Small right padding
                android.widget.LinearLayout.LayoutParams textParams = new android.widget.LinearLayout.LayoutParams(
                    android.widget.LinearLayout.LayoutParams.WRAP_CONTENT,
                    android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
                );
                textParams.gravity = android.view.Gravity.CENTER_VERTICAL;
                floatingProgressText.setLayoutParams(textParams);
                
                // Progress bar - horizontal, compact
                floatingProgressBar = new ProgressBar(activity, null, android.R.attr.progressBarStyleHorizontal);
                floatingProgressBar.setMax(100);
                floatingProgressBar.setProgress(0);
                android.widget.LinearLayout.LayoutParams params = new android.widget.LinearLayout.LayoutParams(
                    0, // Will use weight
                    android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
                );
                params.weight = 1.0f; // Take remaining space
                params.gravity = android.view.Gravity.CENTER_VERTICAL;
                floatingProgressBar.setLayoutParams(params);
                
                // Make progress bar non-blocking
                floatingProgressBar.setClickable(false);
                floatingProgressBar.setFocusable(false);
                
                progressLayout.addView(floatingProgressText);
                progressLayout.addView(floatingProgressBar);
                
                // Add to root view as overlay - pinned to bottom
                if (rootView instanceof ViewGroup) {
                    android.widget.FrameLayout.LayoutParams layoutParams = new android.widget.FrameLayout.LayoutParams(
                        android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                        android.widget.FrameLayout.LayoutParams.WRAP_CONTENT
                    );
                    layoutParams.gravity = android.view.Gravity.BOTTOM;
                    layoutParams.setMargins(0, 0, 0, 40); // 40px bottom margin to avoid swipe line and native UI interference
                    
                    ((ViewGroup) rootView).addView(progressLayout, layoutParams);
                    floatingProgressView = progressLayout;
                    
                    Log.d(TAG, "Floating progress indicator shown successfully");
                } else {
                    Log.e(TAG, "Root view is not a ViewGroup, cannot add floating progress");
                }
            } catch (Exception e) {
                Log.e(TAG, "Error showing floating progress indicator", e);
                e.printStackTrace();
            }
        });
    }
    
    /**
     * Hides the floating progress indicator.
     * Only hides if app is actually in background, not during internal navigation.
     */
    public static void hideFloatingProgressIndicator() {
        hideFloatingProgressIndicator(false);
    }
    
    /**
     * Hides the floating progress indicator.
     * @param force If true, hides even when app is in foreground (e.g., when downloads complete).
     */
    private static void hideFloatingProgressIndicator(boolean force) {
        // Don't hide if app is still in foreground (internal navigation) unless forced
        if (!force && !Bands70k.isAppInBackground()) {
            Log.d(TAG, "App still in foreground, keeping floating progress indicator visible");
            return;
        }
        
        if (currentActivity != null && floatingProgressView != null) {
            currentActivity.runOnUiThread(() -> {
                try {
                    ViewGroup parent = (ViewGroup) floatingProgressView.getParent();
                    if (parent != null) {
                        parent.removeView(floatingProgressView);
                    }
                    floatingProgressView = null;
                    floatingProgressBar = null;
                    floatingProgressText = null;
                    currentActivity = null; // Clear activity reference
                    Log.d(TAG, "Floating progress indicator hidden" + (force ? " (forced - downloads complete)" : " (app in background)"));
                } catch (Exception e) {
                    Log.e(TAG, "Error hiding floating progress indicator", e);
                }
            });
        }
    }
    
    /**
     * Gets the current activity reference.
     */
    public static Activity getCurrentActivity() {
        return currentActivity;
    }
    
    /**
     * Updates the current activity reference (called when navigating between activities).
     * This ensures the progress indicator can be updated even when on different activities.
     * Downloads continue in background thread, so they're not affected by activity navigation.
     */
    public static void setCurrentActivity(Activity activity) {
        if (activity != null && isDownloading.get()) {
            Log.d(TAG, "Updating current activity for progress indicator (downloads continue in background)");
            currentActivity = activity;
            // Only show progress indicator if downloads are actually running and there's work to do
            // Don't show if everything is cached
            if (floatingProgressView != null) {
                // Progress indicator already exists, just update it
                int[] progress = ImageDownloadService.getProgress();
                if (progress != null && progress.length == 2 && progress[1] > 0) {
                    // Only update if there's actual progress to show (total > 0)
                    updateFloatingProgress(progress[0], progress[1], ImageDownloadService.getCurrentTask());
                }
            }
        }
    }
    
    /**
     * Updates the floating progress indicator.
     * Only updates if the indicator is already shown (don't show if nothing to download).
     */
    public static void updateFloatingProgress(int completed, int total, String task) {
        // Don't show progress if there's nothing to download (total == 0)
        if (total == 0) {
            return;
        }
        
        if (currentActivity != null && floatingProgressBar != null && floatingProgressText != null) {
            currentActivity.runOnUiThread(() -> {
                try {
                    String labelText = getLocalizedLabelForTask(task);
                    
                    if (total > 0) {
                        int percent = (int) ((completed * 100.0) / total);
                        floatingProgressBar.setProgress(percent);
                        floatingProgressText.setText(labelText + ": " + completed + "/" + total);
                    } else {
                        floatingProgressText.setText(labelText + ": " + task);
                    }
                } catch (Exception e) {
                    Log.e(TAG, "Error updating floating progress", e);
                }
            });
        }
    }
    
    /**
     * Gets the localized label for the current download task.
     * Returns specific labels ONLY for the active phase.
     */
    private static String getLocalizedLabelForTask(String task) {
        if (currentActivity == null) {
            return "Bulk Downloads";
        }
        
        try {
            if (task != null) {
                String taskLower = task.toLowerCase();
                // Check for Firebase/upload tasks first (most specific)
                if (taskLower.contains("firebase") || taskLower.contains("syncing to firebase") || 
                    taskLower.contains("upload") || taskLower.contains("data upload")) {
                    return currentActivity.getString(R.string.bulk_data_upload);
                }
                // Check for note tasks
                else if (taskLower.contains("note") || taskLower.contains("downloading notes")) {
                    return currentActivity.getString(R.string.bulk_note_download);
                }
                // Check for image tasks
                else if (taskLower.contains("image") || taskLower.contains("downloading images")) {
                    return currentActivity.getString(R.string.bulk_image_download);
                }
            }
            // Default to image download if task is unknown
            return currentActivity.getString(R.string.bulk_image_download);
        } catch (Exception e) {
            Log.e(TAG, "Error getting localized label", e);
            return "Bulk Downloads";
        }
    }
    
    /**
     * Starts foreground downloads (images, notes, Firebase).
     * Downloads run in a background thread while app is in foreground.
     * Only uses foreground service if user leaves app while downloads are running.
     */
    private static void startForegroundDownloads() {
        if (isDownloading.get()) {
            Log.d(TAG, "Downloads already in progress, skipping");
            return;
        }
        
        Log.d(TAG, "Starting foreground downloads (app is in foreground)");
        isDownloading.set(true);
        
        // Run downloads in a background thread (app is in foreground, so no service needed)
        // If user leaves while downloads are running, we'll start a foreground service
        Thread downloadThread = new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    Log.d(TAG, "Starting download task in foreground (thread mode)");
                    
                    // Set isRunning flag so download methods don't return early
                    // This is needed because downloadImages() and downloadNotes() check isRunning.get()
                    ImageDownloadService.setRunning(true);
                    
                    // Use ImageDownloadService's download logic but run directly in thread
                    ImageDownloadService.runDownloadTask();
                    
                } catch (Exception e) {
                    Log.e(TAG, "Error in foreground download task", e);
                    isDownloading.set(false);
                    ImageDownloadService.setRunning(false);
                    hideFloatingProgressIndicator();
                } finally {
                    // Always clear the running flag
                    ImageDownloadService.setRunning(false);
                }
            }
        });
        downloadThread.start();
    }
    
    /**
     * Called when downloads complete.
     */
    public static void onDownloadsComplete() {
        Log.d(TAG, "Downloads completed");
        isDownloading.set(false);
        
        // Mark initial downloads as completed (only on first completion)
        if (!initialDownloadsCompleted.get()) {
            initialDownloadsCompleted.set(true);
            Log.d(TAG, "Initial downloads completed - future downloads will only start when coming from background");
        }
        
        // Dismiss progress dialog if showing
        dismissProgressDialog();
        
        // Force hide floating progress indicator when downloads complete
        hideFloatingProgressIndicator(true);
    }
    
    /**
     * DEPRECATED: No longer shows blocking dialog.
     * Downloads continue in background with minimal floating indicator.
     * This method is kept for compatibility but does nothing.
     */
    @Deprecated
    public static boolean handleBackgroundAttempt(Activity activity) {
        // No longer blocking - downloads continue in background
        return false;
    }
    
    /**
     * Shows a dialog asking user to wait for downloads to complete.
     */
    private static void showWaitDialog(Activity activity) {
        if (activity == null || activity.isFinishing() || activity.isDestroyed()) {
            Log.w(TAG, "Cannot show dialog - activity invalid");
            return;
        }
        
        isDialogShowing.set(true);
        
        // Create custom layout with progress bar
        LayoutInflater inflater = LayoutInflater.from(activity);
        View dialogView = inflater.inflate(android.R.layout.simple_list_item_1, null);
        
        // For now, use a simple dialog. We'll enhance with progress bar later
        AlertDialog.Builder builder = new AlertDialog.Builder(activity);
        builder.setTitle("Downloads in Progress");
        builder.setMessage("Data is being downloaded in the background. Would you like to wait for it to complete, or leave the app now?");
        builder.setCancelable(false);
        
        builder.setPositiveButton("Wait", new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {
                Log.d(TAG, "User chose to wait");
                // Dismiss this dialog
                dialog.dismiss();
                isDialogShowing.set(false);
                
                // Try to bring activity back to front
                try {
                    ActivityManager activityManager = (ActivityManager) activity.getSystemService(Context.ACTIVITY_SERVICE);
                    if (activityManager != null) {
                        activityManager.moveTaskToFront(activity.getTaskId(), ActivityManager.MOVE_TASK_WITH_HOME);
                    }
                } catch (Exception e) {
                    Log.w(TAG, "Could not bring activity to front", e);
                }
                
                // Show progress dialog
                showProgressDialog(activity);
            }
        });
        
        builder.setNegativeButton("Leave Now", new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {
                Log.d(TAG, "User chose to leave - starting foreground service");
                isDialogShowing.set(false);
                // Start foreground service so downloads can continue in background
                Context context = Bands70k.getAppContext();
                if (context != null) {
                    ImageDownloadService.startForegroundDownloads(context);
                }
                // Allow backgrounding - downloads will continue in foreground service
            }
        });
        
        progressDialog = builder.create();
        progressDialog.setCanceledOnTouchOutside(false);
        progressDialog.show();
    }
    
    /**
     * Shows a progress dialog with download progress.
     */
    private static void showProgressDialog(Activity activity) {
        if (activity == null || activity.isFinishing() || activity.isDestroyed()) {
            return;
        }
        
        // Create simple dialog with progress (using built-in Android views)
        AlertDialog.Builder builder = new AlertDialog.Builder(activity);
        builder.setTitle("Downloading Data");
        
        // Create a simple layout programmatically
        android.widget.LinearLayout layout = new android.widget.LinearLayout(activity);
        layout.setOrientation(android.widget.LinearLayout.VERTICAL);
        layout.setPadding(50, 40, 50, 40);
        
        progressText = new TextView(activity);
        progressText.setText("Preparing...");
        progressText.setPadding(0, 0, 0, 20);
        
        progressBar = new ProgressBar(activity, null, android.R.attr.progressBarStyleHorizontal);
        progressBar.setMax(100);
        progressBar.setProgress(0);
        android.widget.LinearLayout.LayoutParams params = new android.widget.LinearLayout.LayoutParams(
            android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
            android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
        );
        progressBar.setLayoutParams(params);
        
        progressDetails = new TextView(activity);
        progressDetails.setText("");
        progressDetails.setPadding(0, 20, 0, 0);
        progressDetails.setTextSize(12);
        
        layout.addView(progressText);
        layout.addView(progressBar);
        layout.addView(progressDetails);
        
        builder.setView(layout);
        builder.setCancelable(false);
        
        builder.setNegativeButton("Leave Anyway", new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {
                Log.d(TAG, "User chose to leave anyway");
                isDialogShowing.set(false);
                // Allow backgrounding - downloads will continue in foreground service
            }
        });
        
        progressDialog = builder.create();
        progressDialog.setCanceledOnTouchOutside(false);
        progressDialog.show();
        
        // Start updating progress
        startProgressUpdates();
    }
    
    /**
     * Starts updating the progress dialog with download status.
     */
    private static void startProgressUpdates() {
        Handler handler = new Handler(Looper.getMainLooper());
        Runnable updateRunnable = new Runnable() {
            @Override
            public void run() {
                if (progressDialog == null || !progressDialog.isShowing()) {
                    // Dialog dismissed
                    return;
                }
                
                if (!isDownloading.get()) {
                    // Downloads complete - show completion message briefly then dismiss
                    if (progressText != null) {
                        progressText.setText("Downloads completed!");
                    }
                    if (progressDetails != null) {
                        progressDetails.setText("All data has been synced");
                    }
                    if (progressBar != null) {
                        progressBar.setProgress(progressBar.getMax());
                    }
                    
                    // Dismiss after 2 seconds
                    handler.postDelayed(new Runnable() {
                        @Override
                        public void run() {
                            dismissProgressDialog();
                        }
                    }, 2000);
                    return;
                }
                
                // Update progress from ImageDownloadService
                updateProgressDisplay();
                
                // Schedule next update
                handler.postDelayed(this, 500); // Update every 500ms
            }
        };
        handler.post(updateRunnable);
    }
    
    /**
     * Updates the progress display with current download status.
     */
    private static void updateProgressDisplay() {
        if (progressText != null) {
            String currentTask = ImageDownloadService.getCurrentTask();
            if (currentTask != null && !currentTask.isEmpty()) {
                progressText.setText(currentTask);
            }
        }
        
        if (progressDetails != null) {
            String details = ImageDownloadService.getProgressDetails();
            if (details != null && !details.isEmpty()) {
                progressDetails.setText(details);
            }
        }
        
        if (progressBar != null) {
            int[] progress = ImageDownloadService.getProgress();
            if (progress != null && progress.length == 2) {
                progressBar.setMax(progress[1]);
                progressBar.setProgress(progress[0]);
            }
        }
    }
    
    /**
     * Dismisses the progress dialog.
     */
    private static void dismissProgressDialog() {
        if (progressDialog != null && progressDialog.isShowing()) {
            try {
                progressDialog.dismiss();
            } catch (Exception e) {
                Log.w(TAG, "Error dismissing progress dialog", e);
            }
            progressDialog = null;
            progressBar = null;
            progressText = null;
            progressDetails = null;
            isDialogShowing.set(false);
        }
    }
    
    /**
     * Updates download status (called by ImageDownloadService).
     */
    public static void setDownloading(boolean downloading) {
        isDownloading.set(downloading);
        if (!downloading) {
            onDownloadsComplete();
        }
    }
}


package com.Bands70k;

import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.content.IntentFilter;
import android.net.ConnectivityManager;
import android.net.LinkProperties;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.os.Build;
import android.os.Bundle;
import android.os.SystemClock;
import android.util.Log;

import androidx.activity.EdgeToEdge;

/**
 * Application class for 70K Bands, provides global application context and proper background detection.
 */
public class Bands70k extends Application implements Application.ActivityLifecycleCallbacks {

    private static Context context;
    private int activityCount = 0;
    private static boolean isAppInBackground = false;
    private NetworkStateReceiver networkStateReceiver;
    private boolean hasCheckedMinimumVersionThisProcess = false;
    private static volatile Activity currentActivity = null;

    /**
     * Called when the application is created. Initializes context, online status, and proper background detection.
     */
    public void onCreate() {

        super.onCreate();

        Bands70k.context = getApplicationContext();
        
        // Initialize crash reporting first to catch any issues during modernization
        CrashReporter.initialize(this);
        Log.d("AppLifecycle", "Crash reporting initialized for AsyncTask modernization monitoring");
        
        OnlineStatus.isOnline();
        
        // Register network state receiver for connectivity monitoring
        registerNetworkStateReceiver();
        
        // Register proper Android background detection
        registerActivityLifecycleCallbacks(this);
        Log.d("AppLifecycle", "Application created, lifecycle callbacks registered for proper background detection");
        
        // Initialize app components asynchronously to avoid blocking startup
        initializeAppAsync();

    }
    
    /**
     * Initialize app components asynchronously to avoid blocking the main thread.
     * Replaces the problematic 3-second sleep with proper async initialization.
     */
    private void initializeAppAsync() {
        // Use ThreadManager to handle any heavy initialization work
        ThreadManager.getInstance().executeGeneral(() -> {
            try {
                // Perform any heavy initialization that was previously relying on the sleep
                Log.d("AppLifecycle", "Performing async app initialization");
                
                // Give some time for essential services to initialize if needed
                Thread.sleep(500); // Much shorter delay, only if absolutely necessary
                
                Log.d("AppLifecycle", "Async app initialization completed");
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                Log.w("AppLifecycle", "App initialization interrupted", e);
            }
        });
    }
    
    /**
     * Registers the network state receiver to monitor connectivity changes
     */
    private void registerNetworkStateReceiver() {
        try {
            networkStateReceiver = new NetworkStateReceiver();
            IntentFilter filter = new IntentFilter(ConnectivityManager.CONNECTIVITY_ACTION);
            registerReceiver(networkStateReceiver, filter);
            Log.d("NetworkState", "Network state receiver registered successfully");
        } catch (Exception e) {
            Log.e("NetworkState", "Failed to register network state receiver", e);
        }
    }
    
    /**
     * Unregisters the network state receiver
     */
    private void unregisterNetworkStateReceiver() {
        try {
            if (networkStateReceiver != null) {
                unregisterReceiver(networkStateReceiver);
                networkStateReceiver = null;
                Log.d("NetworkState", "Network state receiver unregistered successfully");
            }
        } catch (Exception e) {
            Log.e("NetworkState", "Failed to unregister network state receiver", e);
        }
    }

    /**
     * Gets the global application context.
     * @return The application context.
     */
    public static Context getAppContext() {
        return Bands70k.context;
    }

    /**
     * Returns the most recently resumed activity, if available.
     * This is used for presenting UI (dialogs) from app-level services.
     */
    public static Activity getCurrentActivity() {
        return currentActivity;
    }
    
    /**
     * Returns true if the entire app is in the background (no activities visible).
     * This is the PROPER way to detect app background state in Android.
     */
    public static boolean isAppInBackground() {
        return isAppInBackground;
    }
    
    // ===== PROPER ANDROID BACKGROUND DETECTION =====
    
    @Override
    public void onActivityCreated(Activity activity, Bundle savedInstanceState) {
        Log.d("AppLifecycle", "Activity created: " + activity.getClass().getSimpleName());
    }
    
    @Override
    public void onActivityStarted(Activity activity) {
        activityCount++;
        // Check minimum supported app version on:
        // - Cold start (first activity becomes visible)
        // - Return from background (no activities were visible, now one is)
        if (activityCount == 1) {
            String reason = isAppInBackground ? "ReturnFromBackground" : "Launch";
            // Avoid duplicate launch checks within a single process if activity is recreated
            if (!hasCheckedMinimumVersionThisProcess || isAppInBackground) {
                MinimumVersionWarningManager.checkAndShowIfNeeded(reason);
                hasCheckedMinimumVersionThisProcess = true;
            }
        }

        if (isAppInBackground && activityCount == 1) {
            // App was in background and now has an active activity - app came to foreground
            isAppInBackground = false;
            Log.i("AppLifecycle", "App came to FOREGROUND - stopping any bulk loading");
            
            // Stop bulk loading when app comes to foreground
            CustomerDescriptionHandler.pauseBackgroundLoading();
            ImageHandler.pauseBackgroundLoading();
            
            // Cancel any running background tasks
            CustomerDescriptionHandler descHandler = CustomerDescriptionHandler.getInstance();
            descHandler.cancelBackgroundTask();
            
            ImageHandler imageHandler = ImageHandler.getInstance();
            imageHandler.cancelBackgroundTask();
            
            // Start 30-second timer for foreground downloads
            ForegroundDownloadManager.onAppForegrounded();
        }
        Log.d("AppLifecycle", "Activity started: " + activity.getClass().getSimpleName() + " (active count: " + activityCount + ")");
    }
    
    @Override
    public void onActivityStopped(Activity activity) {
        activityCount--;
        if (!isAppInBackground && activityCount == 0) {
            // No activities are visible - app went to background
            isAppInBackground = true;
            currentActivity = null;
            Log.i("AppLifecycle", "App went to BACKGROUND");
            
            // Cancel foreground download timer
            ForegroundDownloadManager.onAppBackgrounded();
            
            // NO LONGER starting background downloads - all downloads happen in foreground only
            // This avoids Android 15 background network restrictions
            Log.i("AppLifecycle", "App went to background - downloads only happen in foreground");
            
            // Cancel any running downloads if app backgrounds (they should complete in foreground)
            if (ForegroundDownloadManager.isDownloading()) {
                Log.i("AppLifecycle", "Downloads in progress - user should wait or they'll continue in service");
            }
        }
        Log.d("AppLifecycle", "Activity stopped: " + activity.getClass().getSimpleName() + " (active count: " + activityCount + ")");
    }
    
    @Override
    public void onActivityResumed(Activity activity) {
        currentActivity = activity;
        Log.d("AppLifecycle", "Activity resumed: " + activity.getClass().getSimpleName());
    }
    
    @Override
    public void onActivityPaused(Activity activity) {
        Log.d("AppLifecycle", "Activity paused: " + activity.getClass().getSimpleName());
    }
    
    @Override
    public void onActivitySaveInstanceState(Activity activity, Bundle outState) {
        // Not needed for our use case
    }
    
    @Override
    public void onActivityDestroyed(Activity activity) {
        Log.d("AppLifecycle", "Activity destroyed: " + activity.getClass().getSimpleName());
    }
    
    @Override
    public void onTerminate() {
        // Clean up network state receiver
        unregisterNetworkStateReceiver();
        Log.d("AppLifecycle", "Application terminating - cleanup completed");
        super.onTerminate();
    }

}


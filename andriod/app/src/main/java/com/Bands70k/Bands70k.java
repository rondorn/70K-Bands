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

    /**
     * Called when the application is created. Initializes context, online status, and proper background detection.
     */
    public void onCreate() {

        super.onCreate();

        Bands70k.context = getApplicationContext();
        OnlineStatus.isOnline();
        
        // Register network state receiver for connectivity monitoring
        registerNetworkStateReceiver();
        
        // Register proper Android background detection
        registerActivityLifecycleCallbacks(this);
        Log.d("AppLifecycle", "Application created, lifecycle callbacks registered for proper background detection");
        
        SystemClock.sleep(3000);

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
        }
        Log.d("AppLifecycle", "Activity started: " + activity.getClass().getSimpleName() + " (active count: " + activityCount + ")");
    }
    
    @Override
    public void onActivityStopped(Activity activity) {
        activityCount--;
        if (!isAppInBackground && activityCount == 0) {
            // No activities are visible - app went to background
            isAppInBackground = true;
            Log.i("AppLifecycle", "App went to BACKGROUND - starting bulk loading");
            
            // Start bulk loading when app truly goes to background
            CustomerDescriptionHandler descHandler = CustomerDescriptionHandler.getInstance();
            descHandler.startBackgroundLoadingOnPause();
            
            ImageHandler imageHandler = ImageHandler.getInstance();
            imageHandler.startBackgroundLoadingOnPause();
        }
        Log.d("AppLifecycle", "Activity stopped: " + activity.getClass().getSimpleName() + " (active count: " + activityCount + ")");
    }
    
    @Override
    public void onActivityResumed(Activity activity) {
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


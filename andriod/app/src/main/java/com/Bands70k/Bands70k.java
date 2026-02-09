package com.Bands70k;

import android.app.Activity;
import android.app.ActivityManager;
import android.app.Application;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.res.Configuration;
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
     * Overrides font scale to prevent UI breakage from system font scaling.
     * Forces font scale to 1.0x regardless of system settings to maintain layout integrity.
     */
    @Override
    protected void attachBaseContext(Context base) {
        Configuration config = new Configuration(base.getResources().getConfiguration());
        config.fontScale = 1.0f; // Force normal font scale to prevent UI breakage
        Context context = base.createConfigurationContext(config);
        super.attachBaseContext(context);
    }

    /**
     * Called when the application is created. Initializes context, online status, and proper background detection.
     */
    public void onCreate() {

        super.onCreate();

        Bands70k.context = getApplicationContext();

        StartupTracker.initProcess(this);
        StartupTracker.markStep(this, "app:onCreate");

        if (isDiagnosticsProcess()) {
            // Keep the diagnostics process minimal; do not run heavy init or background work.
            Log.d("AppLifecycle", "Diagnostics process started; skipping main app initialization");
            return;
        }
        
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

        // If we never draw the first frame, post a notification with diagnostics (non-technical user friendly).
        if (staticVariables.sendDebug) {
            startStartupWatchdog();
        }

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
                StartupTracker.markStep(this, "app:asyncInit:start");

                // Warm up SQLite/profile DB on background thread to prevent UI-thread ANRs during launch.
                SQLiteProfileManager.warmUp();
                StartupTracker.markStep(this, "app:asyncInit:sqliteProfileWarmUp:done");
                
                // Give some time for essential services to initialize if needed
                Thread.sleep(500); // Much shorter delay, only if absolutely necessary
                
                Log.d("AppLifecycle", "Async app initialization completed");
                StartupTracker.markStep(this, "app:asyncInit:done");
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                Log.w("AppLifecycle", "App initialization interrupted", e);
            }
        });
    }

    private void startStartupWatchdog() {
        ThreadManager.getInstance().executeGeneral(() -> {
            try {
                // If no first frame after this delay, treat it as "stuck starting".
                Thread.sleep(12_000);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return;
            }

            if (StartupTracker.isFirstFrameDrawn(this)) {
                return;
            }

            String report = StartupTracker.buildDiagnosticsReport(this);
            Log.e("StartupWatchdog", "Startup appears stuck (no first frame).");
            CrashReporter.reportIssue("StartupWatchdog", "No first frame drawn after 12s", new RuntimeException(report));

            postStartupDiagnosticsNotification();
        });
    }

    private void postStartupDiagnosticsNotification() {
        try {
            final String channelId = "startup_watchdog";
            NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            if (nm == null) return;

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                NotificationChannel channel = new NotificationChannel(
                        channelId,
                        "Startup diagnostics",
                        NotificationManager.IMPORTANCE_HIGH
                );
                channel.setDescription("Shown when the app is taking too long to start.");
                nm.createNotificationChannel(channel);
            }

            Intent intent = new Intent(this, StartupDiagnosticsActivity.class);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);

            PendingIntent pi;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                pi = PendingIntent.getActivity(
                        this,
                        1001,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
                );
            } else {
                //noinspection deprecation
                pi = PendingIntent.getActivity(this, 1001, intent, PendingIntent.FLAG_UPDATE_CURRENT);
            }

            android.app.Notification.Builder builder;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                builder = new android.app.Notification.Builder(this, channelId);
            } else {
                //noinspection deprecation
                builder = new android.app.Notification.Builder(this);
            }

            builder.setContentTitle(getString(R.string.startup_watchdog_notification_title))
                    .setContentText(getString(R.string.startup_watchdog_notification_text))
                    .setContentIntent(pi)
                    .setAutoCancel(true)
                    .setSmallIcon(android.R.drawable.stat_notify_error);

            nm.notify(1001, builder.build());
        } catch (Exception e) {
            Log.e("StartupWatchdog", "Failed to post startup diagnostics notification", e);
        }
    }

    private boolean isDiagnosticsProcess() {
        try {
            if (Build.VERSION.SDK_INT >= 28) {
                String name = Application.getProcessName();
                return name != null && name.endsWith(":diag");
            }
        } catch (Exception ignored) {
        }
        // Best-effort fallback (older devices).
        try {
            int myPid = android.os.Process.myPid();
            ActivityManager am = (ActivityManager) getSystemService(Context.ACTIVITY_SERVICE);
            if (am == null) return false;
            for (ActivityManager.RunningAppProcessInfo p : am.getRunningAppProcesses()) {
                if (p != null && p.pid == myPid) {
                    return p.processName != null && p.processName.endsWith(":diag");
                }
            }
        } catch (Exception ignored) {
        }
        return false;
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

            // Core data refresh (pointer -> band -> schedule -> descriptionMap).
            // Runs ONLY on true background -> foreground transitions.
            CoreDataRefreshManager.startCoreRefreshFromBackground();
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
            
            // CRITICAL FIX: Upload Firebase data when app goes to background
            // This ensures attendance data is uploaded even if user doesn't manually refresh
            uploadFirebaseDataOnBackground();
        }
        Log.d("AppLifecycle", "Activity stopped: " + activity.getClass().getSimpleName() + " (active count: " + activityCount + ")");
    }
    
    /**
     * Uploads Firebase data when app goes to background.
     * Uses a background thread with short timeout to comply with Android background restrictions.
     */
    private void uploadFirebaseDataOnBackground() {
        ThreadManager.getInstance().executeNetwork(() -> {
            try {
                Log.i("AppLifecycle", "🔥 BACKGROUND UPLOAD: Starting Firebase upload");
                
                // Safety check: Ensure attended handler is initialized
                if (staticVariables.attendedHandler == null) {
                    Log.e("AppLifecycle", "❌ ERROR: attendedHandler is null, cannot upload data");
                    return;
                }
                
                // Log current state for debugging
                int attendedCount = staticVariables.attendedHandler.getShowsAttended().size();
                Log.d("AppLifecycle", "🔥 BACKGROUND UPLOAD: Found " + attendedCount + " attended events");
                
                // Ensure schedule data is loaded (required for Firebase filtering)
                if ((BandInfo.scheduleRecords == null || BandInfo.scheduleRecords.isEmpty()) 
                        && FileHandler70k.schedule.exists()) {
                    Log.d("AppLifecycle", "Loading schedule data for Firebase upload");
                    scheduleInfo schedule = new scheduleInfo();
                    BandInfo.scheduleRecords = schedule.ParseScheduleCSV();
                }
                
                // Perform Firebase write
                FireBaseAsyncBandEventWrite firebaseTask = new FireBaseAsyncBandEventWrite();
                firebaseTask.execute();
                
                Log.i("AppLifecycle", "🔥 BACKGROUND UPLOAD: Firebase upload completed");
            } catch (Exception e) {
                Log.e("AppLifecycle", "Error during background Firebase upload: " + e.getMessage(), e);
            }
        });
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


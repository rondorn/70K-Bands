package com.Bands70k;

import android.util.Log;

/**
 * Debug utility to check festival configuration at runtime
 */
public class ConfigDebugger {
    
    public static void logCurrentConfig() {
        try {
            Log.d("ConfigDebugger", "=== FESTIVAL CONFIG DEBUG ===");
            Log.d("ConfigDebugger", "BuildConfig.FESTIVAL_TYPE: " + BuildConfig.FESTIVAL_TYPE);
            Log.d("ConfigDebugger", "BuildConfig.APPLICATION_ID: " + BuildConfig.APPLICATION_ID);
            Log.d("ConfigDebugger", "BuildConfig.VERSION_NAME: " + BuildConfig.VERSION_NAME);
            
            FestivalConfig config = FestivalConfig.getInstance();
            Log.d("ConfigDebugger", "Festival Name: " + config.festivalName);
            Log.d("ConfigDebugger", "App Name: " + config.appName);
            Log.d("ConfigDebugger", "Package Name: " + config.packageName);
            Log.d("ConfigDebugger", "Default Storage URL: " + config.defaultStorageUrl);
            Log.d("ConfigDebugger", "Logo Resource: " + config.logoResourceName);
            Log.d("ConfigDebugger", "=== END DEBUG ===");
            
        } catch (Exception e) {
            Log.e("ConfigDebugger", "Error logging config: " + e.getMessage(), e);
        }
    }
}

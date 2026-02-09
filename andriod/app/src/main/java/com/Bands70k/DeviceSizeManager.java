package com.Bands70k;

import android.content.Context;
import android.content.res.Configuration;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.WindowManager;

/**
 * Centralized manager for determining if device has a large display (tablet) vs normal display (phone)
 * Recalculates on orientation changes and device folds to ensure accurate classification
 * 
 * To change the criteria for what is considered a "large display", modify the LARGE_DISPLAY_THRESHOLD_DP constant
 */
public class DeviceSizeManager {
    private static final String TAG = "DeviceSizeManager";
    
    // CRITICAL: Change this threshold in ONE place to adjust what is considered a "large display"
    // Current value: 600dp (standard Android tablet threshold)
    // Increase for stricter criteria (e.g., 840dp for WindowWidthSizeClass.Expanded)
    // Decrease for more lenient criteria
    private static final int LARGE_DISPLAY_THRESHOLD_DP = 600;
    
    private static DeviceSizeManager instance;
    private boolean isLargeDisplay = false;
    private Context context;
    
    private DeviceSizeManager(Context context) {
        this.context = context.getApplicationContext();
        updateDeviceSize();
    }
    
    /**
     * Get singleton instance
     */
    public static synchronized DeviceSizeManager getInstance(Context context) {
        if (instance == null) {
            instance = new DeviceSizeManager(context);
        }
        return instance;
    }
    
    /**
     * Recalculates device size classification
     * Call this whenever orientation changes or device configuration changes
     */
    public void updateDeviceSize() {
        boolean newValue = calculateIsLargeDisplay();
        if (newValue != isLargeDisplay) {
            isLargeDisplay = newValue;
            Log.d(TAG, "Device size updated: " + (isLargeDisplay ? "Large Display" : "Normal Display"));
        }
    }
    
    /**
     * Determines if the device has a large display (tablet) vs normal display (phone)
     * Criteria can be changed by modifying LARGE_DISPLAY_THRESHOLD_DP
     */
    private boolean calculateIsLargeDisplay() {
        if (context == null) {
            return false;
        }
        
        // Method 1: Check screen size using smallest width (most reliable)
        // This works regardless of orientation and catches foldable devices correctly
        DisplayMetrics displayMetrics = context.getResources().getDisplayMetrics();
        int smallestWidthDp = (int)(Math.min(displayMetrics.widthPixels, displayMetrics.heightPixels) / displayMetrics.density);
        
        if (smallestWidthDp >= LARGE_DISPLAY_THRESHOLD_DP) {
            Log.d(TAG, "Large display detected via smallestWidthDp: " + smallestWidthDp + "dp >= " + LARGE_DISPLAY_THRESHOLD_DP + "dp");
            return true;
        }
        
        // Method 2: Check configuration screen size (backup method)
        int screenSize = context.getResources().getConfiguration().screenLayout & Configuration.SCREENLAYOUT_SIZE_MASK;
        if (screenSize == Configuration.SCREENLAYOUT_SIZE_LARGE || 
            screenSize == Configuration.SCREENLAYOUT_SIZE_XLARGE) {
            Log.d(TAG, "Large display detected via screenLayout size");
            return true;
        }
        
        Log.d(TAG, "Normal display detected - smallestWidthDp: " + smallestWidthDp + "dp < " + LARGE_DISPLAY_THRESHOLD_DP + "dp");
        return false;
    }
    
    /**
     * Check if device is currently classified as large display
     * Use this throughout the codebase instead of checking smallestWidthDp directly
     */
    public boolean isLargeDisplay() {
        return isLargeDisplay;
    }
    
    /**
     * Static convenience method for quick checks
     */
    public static boolean isLargeDisplay(Context context) {
        return getInstance(context).isLargeDisplay();
    }
}

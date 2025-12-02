package com.Bands70k;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.util.Log;

/**
 * BroadcastReceiver that listens for network connectivity changes
 * This helps ensure the app's online status is accurate when the device wakes from sleep
 * or when network connectivity changes
 */
public class NetworkStateReceiver extends BroadcastReceiver {

    private static final String TAG = "NetworkStateReceiver";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent.getAction() != null && 
            intent.getAction().equals(ConnectivityManager.CONNECTIVITY_ACTION)) {
            
            Log.d(TAG, "Network state changed - checking connectivity");
            
            // Use smart refresh that assumes connectivity hasn't changed
            // This prevents UI flickering and immediate network tests
            OnlineStatus.smartRefreshNetworkStatus();
            
            // Log the current network state for debugging
            ConnectivityManager cm = (ConnectivityManager) 
                context.getSystemService(Context.CONNECTIVITY_SERVICE);
            
            if (cm != null) {
                NetworkInfo activeNetwork = cm.getActiveNetworkInfo();
                boolean isConnected = activeNetwork != null && activeNetwork.isConnectedOrConnecting();
                
                Log.d(TAG, "Current network state - Connected: " + isConnected);
                if (activeNetwork != null) {
                    Log.d(TAG, "Network type: " + activeNetwork.getTypeName());
                    Log.d(TAG, "Network subtype: " + activeNetwork.getSubtypeName());
                }
                
                // CRITICAL FIX: If network just became available and we're waiting for data,
                // trigger a refresh to download data
                // Use ForegroundDownloadManager to get current activity
                if (isConnected) {
                    android.app.Activity currentActivity = ForegroundDownloadManager.getCurrentActivity();
                    
                    if (currentActivity instanceof showBands) {
                        showBands showBandsActivity = (showBands) currentActivity;
                        
                        // Check if we're still waiting for data (showing "waiting for data" message)
                        if (showBandsActivity.listHandler != null) {
                            java.util.List<String> sortableNames = showBandsActivity.listHandler.getSortableBandNames();
                            boolean isWaitingForData = sortableNames.isEmpty() || 
                                (sortableNames.size() == 1 && sortableNames.get(0).contains("Waiting for data"));
                            
                            if (isWaitingForData && !staticVariables.loadingBands) {
                                Log.d(TAG, "Network available and waiting for data - triggering refresh");
                                // Trigger refresh on UI thread
                                currentActivity.runOnUiThread(new Runnable() {
                                    @Override
                                    public void run() {
                                        showBandsActivity.refreshNewData();
                                    }
                                });
                            }
                        }
                    }
                }
            }
        }
    }
}

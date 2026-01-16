package com.Bands70k;

/**
 * Created by rdorn on 6/3/16.
 */
import android.os.AsyncTask;
import android.content.Context;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;

import java.net.HttpURLConnection;
import java.net.InetAddress;
import java.net.MalformedURLException;
import java.net.URL;
import java.net.UnknownHostException;
import java.util.ArrayList;


public class OnlineStatus {

    public static URL dnsResolveCache = null;
    private static volatile long lastValidatedAtMs = 0L;
    private static volatile boolean lastValidatedResult = false;
    private static final long VALIDATION_TTL_MS = 15_000L;

    /**
     * Smart network status refresh for device wake-up scenarios
     * Assumes connectivity hasn't changed and restores previous state immediately
     * Optionally verifies the assumption in the background
     */
    public static void smartRefreshNetworkStatus() {
        Log.d("Internet Found", "Smart refresh network status - assuming connectivity unchanged");
        
        // Don't clear the cache immediately - assume the previous state is still valid
        // This prevents UI flickering and immediate network tests
        
        // Schedule a background verification in a few seconds to confirm our assumption
        scheduleBackgroundVerification();
    }
    
    /**
     * Force refresh the network status cache - useful when device wakes from sleep
     * @deprecated Use smartRefreshNetworkStatus() instead for better UX
     */
    @Deprecated
    public static void forceRefreshNetworkStatus() {
        Log.d("Internet Found", "Force refreshing network status cache");
        // Clear the cache to force a fresh check
        staticVariables.internetCheckCache = "Unknown";
        staticVariables.internetCheckCacheDate = 0L;
        // Clear DNS cache as well
        dnsResolveCache = null;
    }
    
    /**
     * Manual network status refresh - called when user explicitly wants to check connectivity
     * This will immediately test the network and update the UI
     */
    public static void manualRefreshNetworkStatus() {
        Log.d("Internet Found", "Manual refresh network status - user requested");
        
        // Clear the cache to force an immediate check
        staticVariables.internetCheckCache = "Unknown";
        staticVariables.internetCheckCacheDate = 0L;
        
        // Do an immediate synchronous check
        boolean actualStatus = testInternetAvailableSynchronous();
        
        // Update the cache with the actual result
        staticVariables.internetCheckCache = String.valueOf(actualStatus);
        staticVariables.internetCheckCacheDate = System.currentTimeMillis() / 1000L + 15;
        
        Log.d("Internet Found", "Manual refresh completed - Online: " + actualStatus);
    }

    /**
     * Schedules a background verification of network status
     * This runs after a delay to verify our assumption without blocking the UI
     */
    private static void scheduleBackgroundVerification() {
        // Use a simple background thread with delay instead of AsyncTask
        // Use proper delayed execution instead of blocking thread with sleep
        ThreadManager.getInstance().runOnUiThreadDelayed(() -> {
            ThreadManager.getInstance().executeNetwork(() -> {
                // Background verification after UI has settled
                Log.d("Internet Found", "Background verification of network status");
                boolean actualStatus = testInternetAvailableSynchronous();
                
                // Only update cache if our assumption was wrong
                if (actualStatus != Boolean.parseBoolean(staticVariables.internetCheckCache)) {
                    Log.d("Internet Found", "Assumption was wrong! Updating cache from " + 
                          staticVariables.internetCheckCache + " to " + actualStatus);
                    staticVariables.internetCheckCache = String.valueOf(actualStatus);
                    staticVariables.internetCheckCacheDate = System.currentTimeMillis() / 1000L + 15;
                } else {
                    Log.d("Internet Found", "Assumption was correct - connectivity unchanged");
                }
            });
        }, 3000); // 3 second delay for UI to settle
    }

    public static boolean isOnline() {

        Log.d("Internet Found", "Internet Found Checking Internet");
        OnlineStatus statusCheckHandler = new OnlineStatus();
        boolean onlineCheck = statusCheckHandler.isInternetAvailableTest();

        Log.d("Internet Found", "Internet Found Checking Internet Done - onlineCheck is " + onlineCheck);
        return onlineCheck;
    }

    public Boolean isInternetAvailableTest() {

        boolean returnState;

        long currentEpoc = System.currentTimeMillis() / 1000L;
        Log.d("Internet Found", "Internet Found " + currentEpoc + " < " + staticVariables.internetCheckCacheDate);

        String previousValue = staticVariables.internetCheckCache;

        // Expire cache after 15 seconds
        if (currentEpoc > staticVariables.internetCheckCacheDate) {
            Log.d("Internet Found", "Internet Found Clearing cache");
            staticVariables.internetCheckCacheDate = currentEpoc + 15;
            staticVariables.internetCheckCache = "Unknown";
        }

        // If we have a definitive cached value and it's still fresh, use it.
        long nowMs = System.currentTimeMillis();
        if (!"Unknown".equals(staticVariables.internetCheckCache) && (nowMs - lastValidatedAtMs) <= VALIDATION_TTL_MS) {
            returnState = Boolean.parseBoolean(staticVariables.internetCheckCache);
            Log.d("Internet Found", "Internet Found Return state is cached " + returnState);
            return returnState;
        }

        // If we're on a background thread, do a real (blocking) validation now.
        // This is required to detect cruise-ship mode: connected to WiFi but no usable internet (timeouts).
        if (Looper.myLooper() != Looper.getMainLooper()) {
            returnState = testInternetAvailableSynchronous();
            staticVariables.internetCheckCache = String.valueOf(returnState);
            lastValidatedAtMs = nowMs;
            lastValidatedResult = returnState;
            return returnState;
        }

        // Main thread: never block. Use a conservative fast check.
        // We return "connected" as a hint, but schedule an async validation to get the truth.
        returnState = isNetworkConnected();
        Log.d("Internet Found", "Main thread: returning connected=" + returnState + " and scheduling async validation");
        executeInternetAvailabilityCheck();

        staticVariables.internetCheckCache = String.valueOf(returnState);
        return returnState;
    }

    public static Boolean testInternetAvailableSynchronous() {

        boolean returnState = false;

        long currentEpoc = System.currentTimeMillis() / 1000L;

        // Validate internet by fetching the POINTER file and verifying its format.
        // This directly detects:
        // - airplane mode (no network)
        // - really bad network (timeouts)
        // - cruise ship captive/limited internet (request times out or returns non-pointer HTML)
        String pointerUrl = staticVariables.getDefaultUrls();
        try {
            if (staticVariables.preferences != null && "Testing".equals(staticVariables.preferences.getPointerUrl())) {
                pointerUrl = staticVariables.getDefaultUrlTest();
            }
        } catch (Exception ignored) {
        }

        HttpURLConnection connection = null;
        try {
            URL url = new URL(pointerUrl);
            connection = (HttpURLConnection) url.openConnection();
            connection.setInstanceFollowRedirects(true);
            connection.setConnectTimeout(5000);
            connection.setReadTimeout(7000);
            connection.setRequestMethod("GET");

            int responseCode = connection.getResponseCode();
            if (responseCode < 200 || responseCode >= 400) {
                Log.d("Internet Found", "Internet Found false - HTTP " + responseCode);
                returnState = false;
            } else {
                // Read a small portion of the response and validate pointer format.
                int validLineCount = 0;
                int linesChecked = 0;
                BufferedReader in = new BufferedReader(new java.io.InputStreamReader(connection.getInputStream()));
                String line;
                while ((line = in.readLine()) != null && linesChecked < 20) {
                    linesChecked++;
                    if (line.contains("::")) {
                        String[] parts = line.split("::");
                        if (parts.length >= 3) {
                            validLineCount++;
                            if (validLineCount >= 2) {
                                break;
                            }
                        }
                    }
                }
                in.close();
                returnState = validLineCount >= 2;
                Log.d("Internet Found", "Internet Found pointer validation validLineCount=" + validLineCount + " => " + returnState);
            }
        } catch (Exception e) {
            Log.d("Internet Found", "Internet Found false - exception " + e.getMessage());
            returnState = false;
        } finally {
            if (connection != null) {
                try { connection.disconnect(); } catch (Exception ignored) {}
            }
        }

        staticVariables.internetCheckCacheDate = currentEpoc + 15;
        staticVariables.internetCheckCache = String.valueOf(returnState);
        lastValidatedAtMs = System.currentTimeMillis();
        lastValidatedResult = returnState;

        Log.d("Internet Found", "Internet Found results are " + returnState);
        return returnState;
    }


    /**
     * Modern replacement for IsInternetAvailableAsynchronous AsyncTask.
     * Tests internet availability and caches the result using ThreadManager.
     */
    public static void executeInternetAvailabilityCheck() {
        ThreadManager.getInstance().executeNetworkWithCallbacks(
            () -> {
                // Background task
                Boolean onlineCheck = testInternetAvailableSynchronous();
                staticVariables.internetCheckCache = onlineCheck ? "true" : "false";
                lastValidatedAtMs = System.currentTimeMillis();
                lastValidatedResult = onlineCheck;
            },
            null, // No pre-execute needed - let the background task set the actual result
            null // No post-execute needed
        );
    }


    //Run the DNS lookup manually to be able to time it out.
    public static URL ResolveHostIP (String sURL, int timeout) throws MalformedURLException {

        if (Looper.myLooper() != Looper.getMainLooper() && dnsResolveCache != null) {
            return dnsResolveCache;
        }

        URL url= new URL(sURL);
        //Resolve the host IP on a new thread
        DNSResolver dnsRes = new DNSResolver(url.getHost());
        Thread t = new Thread(dnsRes);
        t.start();
        //Join the thread for some time
        try {
            t.join(timeout);
        } catch (InterruptedException e) {
            Log.d("DEBUG", "DNS lookup interrupted");
            return null;
        }

        //get the IP of the host
        InetAddress inetAddr = dnsRes.get();
        if(inetAddr==null) {
            Log.d("DEBUG", "DNS timed out.");
            return null;
        }

        //rebuild the URL with the IP and return it
        Log.d("DEBUG", "DNS solved.");
        return new URL(url.getProtocol(),inetAddr.getHostAddress(),url.getPort(),url.getFile());
    }

    public static class DNSResolver implements Runnable {
        private String domain;
        private InetAddress inetAddr;

        public DNSResolver(String domain) {
            this.domain = domain;
        }

        public void run() {
            try {
                InetAddress addr = InetAddress.getByName(domain);
                set(addr);
            } catch (UnknownHostException e) {
            }
        }

        public synchronized void set(InetAddress inetAddr) {
            this.inetAddr = inetAddr;
        }
        public synchronized InetAddress get() {
            return inetAddr;
        }
    }

    private static boolean isNetworkConnected() {
        Context context = Bands70k.getAppContext();
        if (context == null) {
            return false;
        }
        try {
            ConnectivityManager cm = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
            if (cm == null) return false;
            Network active = cm.getActiveNetwork();
            if (active == null) return false;
            NetworkCapabilities caps = cm.getNetworkCapabilities(active);
            if (caps == null) return false;
            return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET);
        } catch (Exception e) {
            return false;
        }
    }
}


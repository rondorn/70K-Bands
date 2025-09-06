package com.Bands70k;

import android.util.Log;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.locks.ReentrantLock;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Modern synchronization utilities to replace Thread.sleep polling patterns.
 * Provides proper waiting mechanisms instead of busy-waiting with sleeps.
 */
public class SynchronizationManager {
    
    private static final String TAG = "SynchronizationManager";
    
    // Lock for loadingBands operations
    private static final ReentrantLock loadingBandsLock = new ReentrantLock();
    private static CountDownLatch loadingBandsLatch = new CountDownLatch(0);
    
    // Lock for loadingNotes operations
    private static final ReentrantLock loadingNotesLock = new ReentrantLock();
    private static CountDownLatch loadingNotesLatch = new CountDownLatch(0);
    
    /**
     * Waits for band loading to complete without busy-waiting.
     * Modern replacement for polling staticVariables.loadingBands with Thread.sleep.
     * 
     * @param timeoutSeconds Maximum time to wait in seconds
     * @return true if loading completed, false if timed out
     */
    public static boolean waitForBandLoadingComplete(int timeoutSeconds) {
        if (!staticVariables.loadingBands) {
            return true; // Already complete
        }
        
        Log.d(TAG, "Waiting for band loading to complete (max " + timeoutSeconds + "s)");
        
        try {
            return loadingBandsLatch.await(timeoutSeconds, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            Log.w(TAG, "Wait for band loading interrupted", e);
            return false;
        }
    }
    
    /**
     * Signals that band loading has started.
     * Call this when setting staticVariables.loadingBands = true.
     */
    public static void signalBandLoadingStarted() {
        loadingBandsLock.lock();
        try {
            loadingBandsLatch = new CountDownLatch(1);
            Log.d(TAG, "Band loading started");
        } finally {
            loadingBandsLock.unlock();
        }
    }
    
    /**
     * Signals that band loading has completed.
     * Call this when setting staticVariables.loadingBands = false.
     */
    public static void signalBandLoadingComplete() {
        loadingBandsLock.lock();
        try {
            loadingBandsLatch.countDown();
            Log.d(TAG, "Band loading completed - signaling waiters");
        } finally {
            loadingBandsLock.unlock();
        }
    }
    
    /**
     * Waits for notes loading to complete without busy-waiting.
     * Modern replacement for polling staticVariables.loadingNotes with Thread.sleep.
     * 
     * @param timeoutSeconds Maximum time to wait in seconds
     * @return true if loading completed, false if timed out
     */
    public static boolean waitForNotesLoadingComplete(int timeoutSeconds) {
        if (!staticVariables.loadingNotes) {
            return true; // Already complete
        }
        
        Log.d(TAG, "Waiting for notes loading to complete (max " + timeoutSeconds + "s)");
        
        try {
            return loadingNotesLatch.await(timeoutSeconds, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            Log.w(TAG, "Wait for notes loading interrupted", e);
            return false;
        }
    }
    
    /**
     * Signals that notes loading has started.
     * Call this when setting staticVariables.loadingNotes = true.
     */
    public static void signalNotesLoadingStarted() {
        loadingNotesLock.lock();
        try {
            loadingNotesLatch = new CountDownLatch(1);
            Log.d(TAG, "Notes loading started");
        } finally {
            loadingNotesLock.unlock();
        }
    }
    
    /**
     * Signals that notes loading has completed.
     * Call this when setting staticVariables.loadingNotes = false.
     */
    public static void signalNotesLoadingComplete() {
        loadingNotesLock.lock();
        try {
            loadingNotesLatch.countDown();
            Log.d(TAG, "Notes loading completed - signaling waiters");
        } finally {
            loadingNotesLock.unlock();
        }
    }
    
    /**
     * Utility method for non-blocking check with exponential backoff.
     * Use this for operations that need to retry with increasing delays.
     * 
     * @param condition The condition to check
     * @param maxRetries Maximum number of retries
     * @param initialDelayMs Initial delay in milliseconds
     * @return true if condition became true, false if max retries reached
     */
    public static boolean waitWithBackoff(AtomicBoolean condition, int maxRetries, long initialDelayMs) {
        long delay = initialDelayMs;
        
        for (int attempt = 0; attempt < maxRetries; attempt++) {
            if (condition.get()) {
                return true;
            }
            
            if (attempt < maxRetries - 1) { // Don't sleep on last attempt
                try {
                    Thread.sleep(delay);
                    delay = Math.min(delay * 2, 5000); // Cap at 5 seconds
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    return false;
                }
            }
        }
        
        return false;
    }
}



package com.Bands70k;

import java.util.concurrent.Future;
import java.util.concurrent.atomic.AtomicInteger;

import android.util.Log;

/**
 * Modern replacement for AsyncTask - writes band and event data to Firebase in the background.
 * Uses ThreadManager instead of deprecated AsyncTask.
 */
public class FireBaseAsyncBandEventWrite {
    private static final String TAG = "FireBaseAsyncBandEventWrite";
    private static final int MAX_JITTER_MS = 20_000;

    private static void waitForBandEventSyncJitter() {
        if (staticVariables.userID == null || staticVariables.userID.isEmpty()) {
            return;
        }
        int delayMs = FirebaseConnectionHelper.jitterDelayMs(staticVariables.userID, MAX_JITTER_MS);
        if (delayMs <= 0) {
            return;
        }
        Log.d(TAG, "Waiting " + delayMs + "ms deterministic jitter before band/show sync");
        try {
            Thread.sleep(delayMs);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            Log.w(TAG, "Band/show sync jitter interrupted");
        }
    }

    /**
     * Executes the Firebase band and event write operations in the background.
     * @return Future representing the background task.
     */
    public Future<?> execute() {
        return ThreadManager.getInstance().executeNetwork(this::runBandAndEventWrites);
    }

    /**
     * Executes the Firebase write operations with callbacks.
     * @param onComplete Optional callback to run when operation completes.
     * @return Future representing the background task.
     */
    public Future<?> execute(Runnable onComplete) {
        return ThreadManager.getInstance().executeNetworkWithCallbacks(
            this::runBandAndEventWrites,
            null,
            onComplete
        );
    }

    private void runBandAndEventWrites() {
        if (!FirebaseWriteMonitor.shouldRunFullSync()) {
            Log.d(TAG, "No pending Firebase sync state — skipping band/event upload");
            FirebaseConnectionHelper.goOffline("band_event_sync_noop");
            return;
        }

        waitForBandEventSyncJitter();
        if (Thread.currentThread().isInterrupted()) {
            FirebaseConnectionHelper.goOffline("band_event_sync_jitter_interrupted");
            return;
        }

        FirebaseWriteMonitor.beginFullSyncAttempt();
        AtomicInteger pendingCallbacks = new AtomicInteger(0);

        Runnable onBatchComplete = () -> {
            if (pendingCallbacks.decrementAndGet() <= 0) {
                FirebaseConnectionHelper.goOffline("band_event_sync_complete");
                ThreadManager.getInstance().executeNetwork(() -> {
                    try {
                        Thread.sleep(2000);
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                    }
                    FirebaseWriteMonitor.finalizeFullSyncAttempt();
                });
            }
        };

        int bandCallbacks = 0;
        if (FirebaseWriteMonitor.shouldRunBandSync()) {
            FireBaseBandDataWrite bandWrite = new FireBaseBandDataWrite();
            bandCallbacks = bandWrite.writeData(onBatchComplete);
        } else {
            Log.d(TAG, "No pending band sync — skipping bandData upload");
        }

        int eventCallbacks = 0;
        if (FirebaseWriteMonitor.shouldRunShowSync()) {
            FirebaseEventDataWrite eventWrite = new FirebaseEventDataWrite();
            eventCallbacks = eventWrite.writeData(onBatchComplete);
        } else {
            Log.d(TAG, "No pending show sync — skipping showData upload");
        }

        pendingCallbacks.set(bandCallbacks + eventCallbacks);
        if (pendingCallbacks.get() == 0) {
            FirebaseConnectionHelper.goOffline("band_event_sync_noop");
            FirebaseWriteMonitor.finalizeFullSyncAttempt();
        }
    }
}

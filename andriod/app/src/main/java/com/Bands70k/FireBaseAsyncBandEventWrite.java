package com.Bands70k;

import java.util.concurrent.Future;
import java.util.concurrent.atomic.AtomicInteger;

import android.util.Log;

/**
 * Writes band and event data to Firebase on a background thread.
 * Orchestration (in-flight lock, tiered jitter, entry points) lives in {@link FirebaseSyncCoordinator}.
 */
public class FireBaseAsyncBandEventWrite {
    private static final String TAG = "FireBaseAsyncBandEventWrite";

    private static void waitForBandEventSyncJitter(int maxJitterMs) {
        if (maxJitterMs <= 0) {
            return;
        }
        if (staticVariables.userID == null || staticVariables.userID.isEmpty()) {
            return;
        }
        int delayMs = FirebaseConnectionHelper.jitterDelayMs(staticVariables.userID, maxJitterMs);
        if (delayMs <= 0) {
            return;
        }
        Log.d(TAG, "Waiting " + delayMs + "ms deterministic jitter (cap=" + maxJitterMs + "ms) before band/show sync");
        try {
            Thread.sleep(delayMs);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            Log.w(TAG, "Band/show sync jitter interrupted");
        }
    }

    /**
     * @deprecated Use {@link FirebaseSyncCoordinator#startFirebaseSyncIfNeeded}.
     */
    @Deprecated
    public Future<?> execute() {
        int maxJitterMs = FirebaseSyncCoordinator.computeMaxJitterMs(false);
        return ThreadManager.getInstance().executeNetwork(() -> runSync(maxJitterMs, null));
    }

    /**
     * @deprecated Use {@link FirebaseSyncCoordinator#startFirebaseSyncIfNeeded}.
     */
    @Deprecated
    public Future<?> execute(Runnable onComplete) {
        int maxJitterMs = FirebaseSyncCoordinator.computeMaxJitterMs(false);
        return ThreadManager.getInstance().executeNetworkWithCallbacks(
            () -> runSync(maxJitterMs, onComplete),
            null,
            null
        );
    }

    /**
     * Runs band/show sync on the calling thread. Invokes {@code onAllComplete} when fully finished
     * (including {@link FirebaseWriteMonitor#finalizeFullSyncAttempt()}).
     */
    void runSync(int maxJitterMs, Runnable onAllComplete) {
        Runnable signalComplete = () -> {
            if (onAllComplete != null) {
                onAllComplete.run();
            }
        };

        if (staticVariables.isTestingEnv) {
            Log.d(TAG, "Skipping band/show Firebase sync — Testing pointer environment disables RTDB writes");
            FirebaseConnectionHelper.goOffline("band_event_sync_testing_env");
            signalComplete.run();
            return;
        }

        if (!FirebaseWriteMonitor.shouldRunFullSync()) {
            Log.d(TAG, "No pending Firebase sync state — skipping band/event upload");
            FirebaseConnectionHelper.goOffline("band_event_sync_noop");
            signalComplete.run();
            return;
        }

        waitForBandEventSyncJitter(maxJitterMs);
        if (Thread.currentThread().isInterrupted()) {
            FirebaseConnectionHelper.goOffline("band_event_sync_jitter_interrupted");
            signalComplete.run();
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
                    signalComplete.run();
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
            if (FirebaseWriteMonitor.shouldRunBandSync()) {
                Log.e(TAG, "Band sync expected but produced no Firebase callbacks");
                FirebaseWriteMonitor.recordWriteFailure("band_sync_no_callbacks");
            }
            if (FirebaseWriteMonitor.shouldRunShowSync()) {
                Log.e(TAG, "Show sync expected but produced no Firebase callbacks");
                FirebaseWriteMonitor.recordWriteFailure("show_sync_no_callbacks");
            }
            FirebaseConnectionHelper.goOffline("band_event_sync_noop");
            FirebaseWriteMonitor.finalizeFullSyncAttempt();
            signalComplete.run();
        }
    }
}

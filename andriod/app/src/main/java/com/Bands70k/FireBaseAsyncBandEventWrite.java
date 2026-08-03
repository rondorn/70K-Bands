package com.Bands70k;

import java.util.concurrent.Future;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Modern replacement for AsyncTask - writes band and event data to Firebase in the background.
 * Uses ThreadManager instead of deprecated AsyncTask.
 */
public class FireBaseAsyncBandEventWrite {

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
        AtomicInteger pendingCallbacks = new AtomicInteger(0);

        Runnable onBatchComplete = () -> {
            if (pendingCallbacks.decrementAndGet() <= 0) {
                FirebaseConnectionHelper.goOffline("band_event_sync_complete");
            }
        };

        FireBaseBandDataWrite bandWrite = new FireBaseBandDataWrite();
        int bandCallbacks = bandWrite.writeData(onBatchComplete);

        FirebaseEventDataWrite eventWrite = new FirebaseEventDataWrite();
        int eventCallbacks = eventWrite.writeData(onBatchComplete);

        pendingCallbacks.set(bandCallbacks + eventCallbacks);
        if (pendingCallbacks.get() == 0) {
            FirebaseConnectionHelper.goOffline("band_event_sync_noop");
        }
    }
}

package com.Bands70k;

import java.util.concurrent.Future;

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
        return ThreadManager.getInstance().executeNetwork(() -> {
            FireBaseBandDataWrite bandWrite = new FireBaseBandDataWrite();
            bandWrite.writeData();

            FirebaseEventDataWrite eventWrite = new FirebaseEventDataWrite();
            eventWrite.writeData();
        });
    }
    
    /**
     * Executes the Firebase write operations with callbacks.
     * @param onComplete Optional callback to run when operation completes.
     * @return Future representing the background task.
     */
    public Future<?> execute(Runnable onComplete) {
        return ThreadManager.getInstance().executeNetworkWithCallbacks(
            () -> {
                FireBaseBandDataWrite bandWrite = new FireBaseBandDataWrite();
                bandWrite.writeData();

                FirebaseEventDataWrite eventWrite = new FirebaseEventDataWrite();
                eventWrite.writeData();
            },
            null, // no pre-execute needed
            onComplete
        );
    }
}



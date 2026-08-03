package com.Bands70k;

import java.util.concurrent.Future;

/**
 * Modern replacement for AsyncTask - writes user data to Firebase in the background.
 * Uses ThreadManager instead of deprecated AsyncTask.
 */
public class FirbaseAsyncUserWrite {

    /**
     * Schedules the Firebase user write with deterministic jitter.
     * @return Future representing the background task (may complete immediately after scheduling).
     */
    public Future<?> execute() {
        return ThreadManager.getInstance().executeNetwork(FirebaseUserWriteScheduler::scheduleWriteIfNeeded);
    }

    /**
     * Schedules the Firebase user write with deterministic jitter.
     * @param onComplete Optional callback to run when scheduling completes.
     * @return Future representing the background task.
     */
    public Future<?> execute(Runnable onComplete) {
        return ThreadManager.getInstance().executeNetworkWithCallbacks(
            FirebaseUserWriteScheduler::scheduleWriteIfNeeded,
            null,
            onComplete
        );
    }
}

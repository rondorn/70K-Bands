package com.Bands70k;

import java.util.concurrent.Future;

/**
 * Modern replacement for AsyncTask - writes user data to Firebase in the background.
 * Uses ThreadManager instead of deprecated AsyncTask.
 */
public class FirbaseAsyncUserWrite {

    /**
     * Executes the Firebase user write operation in the background.
     * @return Future representing the background task.
     */
    public Future<?> execute() {
        return ThreadManager.getInstance().executeNetwork(() -> {
            FirebaseUserWrite userDataWrite = new FirebaseUserWrite();
            userDataWrite.writeData();
        });
    }
    
    /**
     * Executes the Firebase user write operation with callbacks.
     * @param onComplete Optional callback to run when operation completes.
     * @return Future representing the background task.
     */
    public Future<?> execute(Runnable onComplete) {
        return ThreadManager.getInstance().executeNetworkWithCallbacks(
            () -> {
                FirebaseUserWrite userDataWrite = new FirebaseUserWrite();
                userDataWrite.writeData();
            },
            null, // no pre-execute needed
            onComplete
        );
    }
}

package com.Bands70k;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

/**
 * One jittered Firebase pulse for launch / true foreground: user lastLaunch plus any pending
 * band/show uploads share a single short RTDB connection.
 */
public final class FirebaseLifecycleSync {
    private static final String TAG = "FirebaseLifecycleSync";
    private static final long DEBOUNCE_MS = 30_000L;
    private static final Handler HANDLER = new Handler(Looper.getMainLooper());
    private static final Object LOCK = new Object();

    private static long lastScheduledAtMs;
    private static Runnable pendingRunnable;

    private FirebaseLifecycleSync() {}

    public static void scheduleLaunchOrForeground(String reason) {
        synchronized (LOCK) {
            long now = System.currentTimeMillis();
            if (lastScheduledAtMs > 0 && now - lastScheduledAtMs < DEBOUNCE_MS) {
                Log.d(TAG, "Skipping " + reason + " — lifecycle Firebase sync already scheduled");
                return;
            }
            lastScheduledAtMs = now;
            cancelPendingLocked();

            int delayMs = FirebaseConnectionHelper.jitterDelayMs(
                    staticVariables.userID,
                    FirebaseConnectionHelper.LAUNCH_JITTER_MAX_MS
            );
            Log.d(TAG, reason + " waiting " + delayMs + "ms before user + pending band/show writes");
            pendingRunnable = () -> {
                synchronized (LOCK) {
                    pendingRunnable = null;
                }
                FirebaseUserWriteScheduler.writeImmediatelyIfNeeded();
                FirebaseSyncCoordinator.startFirebaseSyncIfNeeded(
                        FirebaseSyncCoordinator.Trigger.FOREGROUND_RECOVERY,
                        true
                );
            };
            HANDLER.postDelayed(pendingRunnable, delayMs);
        }
    }

    public static void cancelPending() {
        synchronized (LOCK) {
            cancelPendingLocked();
        }
    }

    private static void cancelPendingLocked() {
        if (pendingRunnable != null) {
            HANDLER.removeCallbacks(pendingRunnable);
            pendingRunnable = null;
        }
    }
}

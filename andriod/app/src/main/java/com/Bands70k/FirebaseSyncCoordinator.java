package com.Bands70k;

import android.util.Log;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Single entry point for band/show Firebase sync — mirrors iOS {@code startFirebaseSyncIfNeeded}.
 * Uses tiered jitter: dirty changes = 0ms, lifecycle background = 5s, otherwise = 20s.
 */
public final class FirebaseSyncCoordinator {
    private static final String TAG = "FirebaseSyncCoordinator";
    private static final int MAX_JITTER_MS = 20_000;
    private static final int BACKGROUND_MAX_JITTER_MS = 5_000;
    private static final long SYNC_WAIT_TIMEOUT_MS = 60_000;

    private static final AtomicBoolean syncInFlight = new AtomicBoolean(false);

    public enum Trigger {
        /** App has no visible activities (onStop). */
        BACKGROUND,
        /** App returned from background with pending sync. */
        FOREGROUND_RECOVERY,
        /** End of bulk download foreground-service pipeline. */
        BULK_DOWNLOAD
    }

    private FirebaseSyncCoordinator() {}

    /**
     * Resets a stale in-flight flag when the app returns to foreground (iOS parity).
     */
    public static void resetStaleSyncInFlightForForegroundRecovery() {
        if (syncInFlight.compareAndSet(true, false)) {
            Log.d(TAG, "Foreground recovery — resetting stale in-flight sync flag");
        }
    }

    /**
     * Starts band/show sync on a network thread if pending. Does not block the caller.
     */
    public static void startFirebaseSyncIfNeeded(Trigger trigger) {
        ThreadManager.getInstance().executeNetwork(() -> performSync(trigger, false));
    }

    /**
     * Runs band/show sync on the current thread and blocks until completion or timeout.
     * Used by {@link ImageDownloadService} so the download pipeline waits for Firebase.
     */
    public static void performFirebaseSyncAndAwait(Trigger trigger) {
        performSync(trigger, true);
    }

    static int computeMaxJitterMs(boolean isBackgroundTransition) {
        if (FirebaseWriteMonitor.hasPendingLocalChanges()) {
            return 0;
        }
        return isBackgroundTransition ? BACKGROUND_MAX_JITTER_MS : MAX_JITTER_MS;
    }

    private static boolean isBackgroundTransition(Trigger trigger) {
        return trigger == Trigger.BACKGROUND;
    }

    private static void performSync(Trigger trigger, boolean blockUntilComplete) {
        if (!FirebaseWriteMonitor.shouldRunFullSync()) {
            Log.d(TAG, "No pending Firebase sync — skipping (" + trigger + ")");
            return;
        }

        if (staticVariables.isTestingEnv) {
            Log.d(TAG, "Skipping Firebase sync — Testing pointer environment (" + trigger + ")");
            return;
        }

        if (!syncInFlight.compareAndSet(false, true)) {
            Log.d(TAG, "Firebase sync already in flight — skipping duplicate (" + trigger + ")");
            return;
        }

        CountDownLatch completionLatch = blockUntilComplete ? new CountDownLatch(1) : null;
        Runnable releaseAndSignal = () -> {
            syncInFlight.set(false);
            if (completionLatch != null) {
                completionLatch.countDown();
            }
        };

        try {
            if (staticVariables.attendedHandler == null) {
                Log.e(TAG, "attendedHandler is null — cannot sync show data (" + trigger + ")");
                releaseAndSignal.run();
                return;
            }

            ensureScheduleLoadedForFirebase();

            int attendedCount = staticVariables.attendedHandler.getShowsAttended().size();
            boolean isBackgroundTransition = isBackgroundTransition(trigger);
            int maxJitterMs = computeMaxJitterMs(isBackgroundTransition);

            Log.i(TAG, "Starting Firebase band/show sync (" + trigger
                    + ", dirty=" + FirebaseWriteMonitor.hasPendingLocalChanges()
                    + ", backgroundTransition=" + isBackgroundTransition
                    + ", maxJitterMs=" + maxJitterMs
                    + ", attended=" + attendedCount + ")");

            FireBaseAsyncBandEventWrite writer = new FireBaseAsyncBandEventWrite();
            writer.runSync(maxJitterMs, () -> {
                Log.i(TAG, "Firebase band/show sync finished (" + trigger + ")");
                releaseAndSignal.run();
            });

            if (completionLatch != null) {
                boolean completed = completionLatch.await(SYNC_WAIT_TIMEOUT_MS, TimeUnit.MILLISECONDS);
                if (!completed) {
                    Log.w(TAG, "Firebase sync timed out after " + SYNC_WAIT_TIMEOUT_MS + "ms (" + trigger + ")");
                    if (FirebaseWriteMonitor.shouldRunBandSync()) {
                        FirebaseWriteMonitor.recordWriteFailure("band_batch_timeout");
                    }
                    if (FirebaseWriteMonitor.shouldRunShowSync()) {
                        FirebaseWriteMonitor.recordWriteFailure("event_batch_timeout");
                    }
                    syncInFlight.set(false);
                }
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            Log.w(TAG, "Firebase sync interrupted (" + trigger + ")");
            releaseAndSignal.run();
        } catch (Exception e) {
            Log.e(TAG, "Firebase sync error (" + trigger + "): " + e.getMessage(), e);
            releaseAndSignal.run();
        }
    }

    private static void ensureScheduleLoadedForFirebase() {
        if ((BandInfo.scheduleRecords == null || BandInfo.scheduleRecords.isEmpty())
                && FileHandler70k.schedule.exists()) {
            Log.d(TAG, "Loading schedule cache for Firebase sync");
            scheduleInfo schedule = new scheduleInfo();
            BandInfo.scheduleRecords = schedule.ParseScheduleCSV();
        }
    }
}

package com.Bands70k;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Schedules Firebase user-data writes with deterministic jitter and flushes pending writes on background.
 */
public final class FirebaseUserWriteScheduler {
    private static final FirebaseUserWriteScheduler INSTANCE = new FirebaseUserWriteScheduler();
    private static final int MAX_JITTER_MS = 20_000;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final AtomicBoolean writeInProgress = new AtomicBoolean(false);
    private Runnable pendingRunnable;

    private FirebaseUserWriteScheduler() {}

    public static void scheduleWriteIfNeeded() {
        INSTANCE.scheduleInternal(false);
    }

    public static void flushPendingWriteOnBackground() {
        INSTANCE.scheduleInternal(true);
    }

    private void scheduleInternal(boolean immediate) {
        if (staticVariables.isTestingEnv || staticVariables.userID.isEmpty()) {
            return;
        }

        boolean hadPendingWrite = pendingRunnable != null;
        if (pendingRunnable != null) {
            mainHandler.removeCallbacks(pendingRunnable);
            pendingRunnable = null;
        }

        if (immediate) {
            if (hadPendingWrite || !shouldSkipDueToDedup()) {
                Log.d("FirebaseUserWriteScheduler", "Flushing pending user write immediately on background");
                performWrite();
            } else {
                Log.d("FirebaseUserWriteScheduler", "Background flush skipped — already written today with same metadata");
            }
            return;
        }

        if (shouldSkipDueToDedup()) {
            Log.d("FirebaseUserWriteScheduler", "Skipping user write — already sent today with same metadata");
            return;
        }

        int delayMs = FirebaseConnectionHelper.jitterDelayMs(staticVariables.userID, MAX_JITTER_MS);
        Log.d("FirebaseUserWriteScheduler", "Scheduling user write after " + delayMs + "ms deterministic jitter");

        pendingRunnable = () -> {
            pendingRunnable = null;
            performWrite();
        };
        mainHandler.postDelayed(pendingRunnable, delayMs);
    }

    private boolean shouldSkipDueToDedup() {
        return buildCompareBlock().equals(staticVariables.userDataForCompareAndWriteBlock);
    }

    private String buildCompareBlock() {
        String version70k = "Unknown";
        try {
            version70k = staticVariables.context.getPackageManager()
                    .getPackageInfo(staticVariables.context.getPackageName(), 0).versionName;
        } catch (Exception ignored) {
        }

        if (staticVariables.userCountry.isEmpty()) {
            staticVariables.userCountry = FileHandler70k.loadData(FileHandler70k.countryFile);
        }
        if (staticVariables.userCountry.isEmpty()) {
            staticVariables.userCountry = Locale.getDefault().getCountry();
        }

        String country = staticVariables.userCountry;
        String language = Locale.getDefault().getLanguage();
        DateFormat formatter = new SimpleDateFormat("dd/MM/yyyy", Locale.US);
        String dateOnly = formatter.format(new Date());
        return country + '-' + language + '-' + version70k + dateOnly;
    }

    private void performWrite() {
        if (!writeInProgress.compareAndSet(false, true)) {
            Log.d("FirebaseUserWriteScheduler", "User write already in progress — skipping duplicate request");
            return;
        }

        ThreadManager.getInstance().executeNetwork(() -> {
            try {
                FirebaseUserWrite writer = new FirebaseUserWrite();
                writer.performScheduledWrite();
            } finally {
                writeInProgress.set(false);
            }
        });
    }
}

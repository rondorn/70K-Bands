package com.Bands70k;

import android.app.Activity;
import android.util.Log;

import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Runs the "core data refresh" pipeline:
 * 1) pointer file
 * 2) band CSV
 * 3) schedule CSV
 * 4) descriptionMap CSV
 *
 * Triggered only on true background -> foreground transitions (Application-level),
 * never on internal navigation between screens.
 */
public final class CoreDataRefreshManager {

    private static final String TAG = "CoreDataRefresh";

    // Prevent duplicate refreshes from rapid lifecycle events.
    private static final AtomicBoolean refreshInProgress = new AtomicBoolean(false);
    private static final AtomicLong lastRefreshStartedAtMs = new AtomicLong(0L);

    // Defensive throttle (should be unnecessary, but avoids accidental double-starts).
    private static final long MIN_REFRESH_INTERVAL_MS = 5_000L;

    private CoreDataRefreshManager() {}

    /**
     * Starts the core refresh immediately on a background thread.
     * Safe to call multiple times; only one run will proceed.
     */
    public static void startCoreRefreshFromBackground() {
        final long now = System.currentTimeMillis();
        final long last = lastRefreshStartedAtMs.get();
        if (now - last < MIN_REFRESH_INTERVAL_MS) {
            Log.d(TAG, "Throttling core refresh (started " + (now - last) + "ms ago)");
            return;
        }

        if (!refreshInProgress.compareAndSet(false, true)) {
            Log.d(TAG, "Core refresh already in progress, skipping");
            return;
        }
        lastRefreshStartedAtMs.set(now);

        ThreadManager.getInstance().executeNetwork(() -> {
            try {
                Log.d(TAG, "Core refresh starting (background->foreground)");

                // 1) pointer (FORCED network fetch)
                staticVariables.forceLookupUrlsFromNetwork();

                // 2) band CSV
                BandInfo bandInfo = new BandInfo();
                bandInfo.DownloadBandFile();

                // 3) schedule CSV
                scheduleInfo schedule = new scheduleInfo();
                String scheduleUrl = staticVariables.scheduleURL;
                if (scheduleUrl == null || scheduleUrl.trim().isEmpty()) {
                    scheduleUrl = FestivalConfig.getInstance().scheduleUrlDefault;
                    Log.d(TAG, "Using fallback scheduleUrl for core refresh");
                }
                BandInfo.scheduleRecords = schedule.DownloadScheduleFile(scheduleUrl);

                // 4) descriptionMap CSV (download + parse)
                CustomerDescriptionHandler descHandler = CustomerDescriptionHandler.getInstance();
                descHandler.getDescriptionMapFile();
                descHandler.getDescriptionMap();

                Log.d(TAG, "Core refresh completed");
            } catch (Exception e) {
                Log.e(TAG, "Core refresh failed: " + e.getMessage(), e);
            } finally {
                refreshInProgress.set(false);

                // Best-effort: if the main list is visible, refresh UI from cache without re-downloading.
                ThreadManager.getInstance().runOnUiThread(() -> {
                    try {
                        Activity activity = Bands70k.getCurrentActivity();
                        if (activity instanceof showBands) {
                            showBands main = (showBands) activity;
                            Log.d(TAG, "Refreshing main UI after core refresh");
                            // Avoid calling private helpers; refreshData() will re-read cached files as needed.
                            main.refreshData();
                        }
                    } catch (Exception ignored) {
                        // UI refresh is best-effort; core refresh already finished.
                    }
                });
            }
        });
    }
}


package com.Bands70k;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;

/**
 * Tracks Firebase write outcomes and indicates when a full Firebase resync is required.
 * Band and show dirty flags are tracked separately so a band edit does not touch showData.
 */
public class FirebaseWriteMonitor {
    private static final String TAG = "FirebaseWriteMonitor";
    private static final String PREF_NAME = "firebase_write_monitor";
    private static final String KEY_HAS_PENDING_FAILURES = "has_pending_failures";
    private static final String KEY_HAS_PENDING_BAND_CHANGES = "has_pending_band_changes";
    private static final String KEY_HAS_PENDING_SHOW_CHANGES = "has_pending_show_changes";
    private static final String KEY_LEGACY_PENDING_LOCAL_CHANGES = "has_pending_local_changes";
    private static final String KEY_FAILURE_COUNT = "failure_count";
    private static final String KEY_SUCCESS_COUNT = "success_count";
    private static final String KEY_FULL_SYNC_IN_PROGRESS = "full_sync_in_progress";
    private static final String KEY_FULL_SYNC_SAW_SUCCESS = "full_sync_saw_success";
    private static final String KEY_FULL_SYNC_HAD_FAILURE = "full_sync_had_failure";

    private static SharedPreferences getPrefs() {
        Context context = staticVariables.context;
        if (context == null) {
            return null;
        }
        return context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
    }

    private static void migrateLegacyDirtyFlagIfNeeded(SharedPreferences prefs) {
        if (prefs.getBoolean(KEY_LEGACY_PENDING_LOCAL_CHANGES, false)) {
            prefs.edit()
                    .putBoolean(KEY_HAS_PENDING_BAND_CHANGES, true)
                    .putBoolean(KEY_HAS_PENDING_SHOW_CHANGES, true)
                    .putBoolean(KEY_LEGACY_PENDING_LOCAL_CHANGES, false)
                    .apply();
        }
    }

    public static synchronized void recordWriteSuccess(String source) {
        SharedPreferences prefs = getPrefs();
        if (prefs == null) {
            Log.w(TAG, "recordWriteSuccess skipped (context null), source=" + source);
            return;
        }
        migrateLegacyDirtyFlagIfNeeded(prefs);
        int count = prefs.getInt(KEY_SUCCESS_COUNT, 0) + 1;
        SharedPreferences.Editor editor = prefs.edit().putInt(KEY_SUCCESS_COUNT, count);
        if (prefs.getBoolean(KEY_FULL_SYNC_IN_PROGRESS, false)) {
            editor.putBoolean(KEY_FULL_SYNC_SAW_SUCCESS, true);
        }
        if (source != null && source.startsWith("band_batch")) {
            editor.putBoolean(KEY_HAS_PENDING_BAND_CHANGES, false);
        }
        if (source != null && source.startsWith("event_batch")) {
            editor.putBoolean(KEY_HAS_PENDING_SHOW_CHANGES, false);
        }
        editor.apply();
        Log.d(TAG, "Success recorded (" + source + "), total successes=" + count);
    }

    public static synchronized void recordWriteFailure(String source) {
        SharedPreferences prefs = getPrefs();
        if (prefs == null) {
            Log.w(TAG, "recordWriteFailure skipped (context null), source=" + source);
            return;
        }
        migrateLegacyDirtyFlagIfNeeded(prefs);
        int count = prefs.getInt(KEY_FAILURE_COUNT, 0) + 1;
        SharedPreferences.Editor editor = prefs.edit()
                .putInt(KEY_FAILURE_COUNT, count)
                .putBoolean(KEY_HAS_PENDING_FAILURES, true);
        if (prefs.getBoolean(KEY_FULL_SYNC_IN_PROGRESS, false)) {
            editor.putBoolean(KEY_FULL_SYNC_HAD_FAILURE, true);
        }
        editor.apply();
        Log.e(TAG, "Failure recorded (" + source + "), total failures=" + count + ". Full sync required.");
    }

    public static synchronized void markLocalChangePendingSync(String context) {
        SharedPreferences prefs = getPrefs();
        if (prefs == null) {
            Log.w(TAG, "markLocalChangePendingSync skipped (context null), context=" + context);
            return;
        }
        migrateLegacyDirtyFlagIfNeeded(prefs);
        SharedPreferences.Editor editor = prefs.edit();
        if (context != null && context.startsWith("priority:")) {
            editor.putBoolean(KEY_HAS_PENDING_BAND_CHANGES, true);
            Log.d(TAG, "Band change marked dirty (" + context + ").");
        } else if (context != null && (context.startsWith("attendance:") || context.startsWith("attendance_clear"))) {
            editor.putBoolean(KEY_HAS_PENDING_SHOW_CHANGES, true);
            Log.d(TAG, "Show change marked dirty (" + context + ").");
        } else {
            editor.putBoolean(KEY_HAS_PENDING_BAND_CHANGES, true);
            editor.putBoolean(KEY_HAS_PENDING_SHOW_CHANGES, true);
            Log.d(TAG, "Local change marked dirty (" + context + ").");
        }
        editor.apply();
    }

    public static synchronized boolean hasPendingBandChanges() {
        SharedPreferences prefs = getPrefs();
        if (prefs == null) {
            return false;
        }
        migrateLegacyDirtyFlagIfNeeded(prefs);
        return prefs.getBoolean(KEY_HAS_PENDING_BAND_CHANGES, false);
    }

    public static synchronized boolean hasPendingShowChanges() {
        SharedPreferences prefs = getPrefs();
        if (prefs == null) {
            return false;
        }
        migrateLegacyDirtyFlagIfNeeded(prefs);
        return prefs.getBoolean(KEY_HAS_PENDING_SHOW_CHANGES, false);
    }

    public static synchronized boolean hasPendingLocalChanges() {
        return hasPendingBandChanges() || hasPendingShowChanges();
    }

    public static synchronized boolean hasPendingFailures() {
        SharedPreferences prefs = getPrefs();
        if (prefs == null) {
            return false;
        }
        return prefs.getBoolean(KEY_HAS_PENDING_FAILURES, false);
    }

    public static synchronized boolean shouldRunFullSync() {
        return hasPendingLocalChanges() || hasPendingFailures();
    }

    public static synchronized boolean shouldRunBandSync() {
        return hasPendingBandChanges() || hasPendingFailures();
    }

    public static synchronized boolean shouldRunShowSync() {
        return hasPendingShowChanges() || hasPendingFailures();
    }

    public static synchronized void beginFullSyncAttempt() {
        SharedPreferences prefs = getPrefs();
        if (prefs == null) {
            return;
        }
        migrateLegacyDirtyFlagIfNeeded(prefs);
        prefs.edit()
                .putBoolean(KEY_FULL_SYNC_IN_PROGRESS, true)
                .putBoolean(KEY_FULL_SYNC_SAW_SUCCESS, false)
                .putBoolean(KEY_FULL_SYNC_HAD_FAILURE, false)
                .apply();
        Log.d(TAG, "Full sync attempt started.");
    }

    public static synchronized boolean finalizeFullSyncAttempt() {
        SharedPreferences prefs = getPrefs();
        if (prefs == null) {
            return false;
        }
        boolean sawSuccess = prefs.getBoolean(KEY_FULL_SYNC_SAW_SUCCESS, false);
        boolean hadFailure = prefs.getBoolean(KEY_FULL_SYNC_HAD_FAILURE, false);
        boolean cleared = false;

        if (sawSuccess && !hadFailure) {
            prefs.edit()
                    .putBoolean(KEY_HAS_PENDING_FAILURES, false)
                    .putInt(KEY_FAILURE_COUNT, 0)
                    .apply();
            cleared = true;
            Log.d(TAG, "Full sync succeeded. Cleared pending failure flags.");
        } else {
            Log.w(TAG, "Full sync not confirmed successful (sawSuccess=" + sawSuccess
                    + ", hadFailure=" + hadFailure + "). Keeping pending flags.");
        }

        prefs.edit()
                .putBoolean(KEY_FULL_SYNC_IN_PROGRESS, false)
                .putBoolean(KEY_FULL_SYNC_SAW_SUCCESS, false)
                .putBoolean(KEY_FULL_SYNC_HAD_FAILURE, false)
                .apply();
        return cleared;
    }

    @Deprecated
    public static synchronized void clearPendingFailuresAfterFullSyncTriggered() {
        finalizeFullSyncAttempt();
    }
}

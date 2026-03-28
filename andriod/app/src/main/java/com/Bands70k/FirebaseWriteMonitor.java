package com.Bands70k;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;

/**
 * Tracks Firebase write outcomes and indicates when a full Firebase resync is required.
 * Failure state persists until a full sync pass is triggered.
 */
public class FirebaseWriteMonitor {
    private static final String TAG = "FirebaseWriteMonitor";
    private static final String PREF_NAME = "firebase_write_monitor";
    private static final String KEY_HAS_PENDING_FAILURES = "has_pending_failures";
    private static final String KEY_FAILURE_COUNT = "failure_count";
    private static final String KEY_SUCCESS_COUNT = "success_count";

    private static SharedPreferences getPrefs() {
        Context context = staticVariables.context;
        if (context == null) {
            return null;
        }
        return context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
    }

    public static synchronized void recordWriteSuccess(String source) {
        SharedPreferences prefs = getPrefs();
        if (prefs == null) {
            Log.w(TAG, "recordWriteSuccess skipped (context null), source=" + source);
            return;
        }
        int count = prefs.getInt(KEY_SUCCESS_COUNT, 0) + 1;
        prefs.edit().putInt(KEY_SUCCESS_COUNT, count).apply();
        Log.d(TAG, "Success recorded (" + source + "), total successes=" + count);
    }

    public static synchronized void recordWriteFailure(String source) {
        SharedPreferences prefs = getPrefs();
        if (prefs == null) {
            Log.w(TAG, "recordWriteFailure skipped (context null), source=" + source);
            return;
        }
        int count = prefs.getInt(KEY_FAILURE_COUNT, 0) + 1;
        prefs.edit()
                .putInt(KEY_FAILURE_COUNT, count)
                .putBoolean(KEY_HAS_PENDING_FAILURES, true)
                .apply();
        Log.e(TAG, "Failure recorded (" + source + "), total failures=" + count + ". Full sync required.");
    }

    public static synchronized boolean hasPendingFailures() {
        SharedPreferences prefs = getPrefs();
        if (prefs == null) {
            return false;
        }
        return prefs.getBoolean(KEY_HAS_PENDING_FAILURES, false);
    }

    public static synchronized void clearPendingFailuresAfterFullSyncTriggered() {
        SharedPreferences prefs = getPrefs();
        if (prefs == null) {
            return;
        }
        prefs.edit()
                .putBoolean(KEY_HAS_PENDING_FAILURES, false)
                .putInt(KEY_FAILURE_COUNT, 0)
                .apply();
        Log.d(TAG, "Cleared pending failure flag after full sync trigger.");
    }
}

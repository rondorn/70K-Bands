package com.Bands70k;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;

/**
 * Displays an "outdated app version" warning when the pointer file specifies a higher minimum version.
 *
 * Android implementation requirements:
 * - Read Current::androidMinimum from the pointer file
 * - Compare against installed Android app version
 * - If outdated, show a message prompting update
 * - Only show once per 7 days, unless the minimum version value changes (then show again immediately)
 * - Check on app launch and when returning from background
 */
public final class MinimumVersionWarningManager {

    private static final String TAG = "MIN_VERSION";

    private static final String PREFS_NAME = "MinimumVersionWarning";
    private static final String KEY_LAST_SHOWN_AT_MS = "MinVersionWarningLastShownAtMs";
    private static final String KEY_LAST_SEEN_MINIMUM = "MinVersionWarningLastSeenMinimum";
    private static final String KEY_LAST_FETCHED_MINIMUM = "MinVersionWarningLastFetchedMinimum";
    private static final String KEY_LAST_FETCHED_AT_MS = "MinVersionWarningLastFetchedAtMs";

    private static final long ONE_WEEK_MS = 7L * 24L * 60L * 60L * 1000L;
    private static final long CHECK_THROTTLE_MS = 10_000L; // avoid duplicate checks (e.g., rotations)

    private static volatile long lastCheckAtMs = 0L;
    private static volatile boolean checkInProgress = false;
    private static volatile boolean retryScheduled = false;

    private MinimumVersionWarningManager() {}

    public static void checkAndShowIfNeeded(String reason) {
        checkAndShowIfNeededInternal(reason, false);
    }

    private static void checkAndShowIfNeededInternal(String reason, boolean bypassThrottle) {
        final Context appContext = Bands70k.getAppContext();
        if (appContext == null) {
            Log.w(TAG, "[MIN_VERSION] No app context available (reason=" + reason + ")");
            return;
        }

        final long now = System.currentTimeMillis();
        if (!bypassThrottle && now - lastCheckAtMs < CHECK_THROTTLE_MS) {
            Log.d(TAG, "[MIN_VERSION] Throttling check (reason=" + reason + ")");
            return;
        }
        lastCheckAtMs = now;

        if (checkInProgress) {
            Log.d(TAG, "[MIN_VERSION] Check already in progress, skipping (reason=" + reason + ")");
            return;
        }
        checkInProgress = true;

        ThreadManager.getInstance().executeNetwork(() -> {
            try {
                final SharedPreferences prefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);

                final String installedVersionName = getInstalledVersionName();
                final long installedVersionNum = parseVersionNumber(installedVersionName);

                final String minimumVersion = resolveAndroidMinimumVersion(appContext, prefs);
                final long minimumVersionNum = parseVersionNumber(minimumVersion);

                if (minimumVersion == null || minimumVersion.trim().isEmpty()) {
                    Log.d(TAG, "[MIN_VERSION] No Current::androidMinimum available (reason=" + reason + ")");
                    // Pointer cache may not be ready yet on cold start. Schedule one retry shortly after launch/foreground.
                    if (!retryScheduled && (reason.startsWith("Launch") || reason.startsWith("ReturnFromBackground"))) {
                        retryScheduled = true;
                        ThreadManager.getInstance().runOnUiThreadDelayed(
                                () -> checkAndShowIfNeededInternal(reason + "_Retry", true),
                                4000L
                        );
                        Log.d(TAG, "[MIN_VERSION] Scheduled retry in 4s (reason=" + reason + ")");
                    }
                    return;
                }

                final boolean isOutdated = installedVersionNum > 0 && minimumVersionNum > 0 && installedVersionNum < minimumVersionNum;
                Log.d(
                        TAG,
                        "[MIN_VERSION] Installed=" + installedVersionName +
                                " (" + installedVersionNum + ")" +
                                " Minimum=" + minimumVersion +
                                " (" + minimumVersionNum + ")" +
                                " Outdated=" + isOutdated +
                                " (reason=" + reason + ")"
                );

                if (!isOutdated) {
                    return;
                }

                final String lastSeenMinimum = prefs.getString(KEY_LAST_SEEN_MINIMUM, "");
                final long lastShownAt = prefs.getLong(KEY_LAST_SHOWN_AT_MS, 0L);

                final boolean minimumChanged = !minimumVersion.equals(lastSeenMinimum);
                final boolean weekPassed = (lastShownAt == 0L) || ((now - lastShownAt) >= ONE_WEEK_MS);

                if (!minimumChanged && !weekPassed) {
                    Log.d(TAG, "[MIN_VERSION] Suppressing alert (shown <7 days ago and minimum unchanged)");
                    return;
                }

                ThreadManager.getInstance().runOnUiThread(() -> {
                    Activity activity = Bands70k.getCurrentActivity();
                    if (activity == null || activity.isFinishing() || activity.isDestroyed()) {
                        Log.w(TAG, "[MIN_VERSION] No valid activity to present alert");
                        return;
                    }

                    try {
                        new AlertDialog.Builder(activity)
                                .setTitle(activity.getString(R.string.app_name))
                                .setMessage(activity.getString(R.string.outdated_app_version_message))
                                .setPositiveButton(activity.getString(R.string.Ok), null)
                                .show();

                        prefs.edit()
                                .putLong(KEY_LAST_SHOWN_AT_MS, System.currentTimeMillis())
                                .putString(KEY_LAST_SEEN_MINIMUM, minimumVersion)
                                .apply();

                        Log.d(
                                TAG,
                                "[MIN_VERSION] Alert displayed and recorded (minimumChanged=" + minimumChanged +
                                        ", weekPassed=" + weekPassed + ")"
                        );
                    } catch (Exception e) {
                        Log.e(TAG, "[MIN_VERSION] Failed to show alert: " + e.getMessage(), e);
                    }
                });
            } finally {
                checkInProgress = false;
            }
        });
    }

    private static String getInstalledVersionName() {
        // VERSION_NAME includes the flavor suffix (e.g. "302601153-70k"); we parse digits from it.
        try {
            return BuildConfig.VERSION_NAME;
        } catch (Exception e) {
            Log.w(TAG, "[MIN_VERSION] Could not read BuildConfig.VERSION_NAME", e);
            return "";
        }
    }

    /**
     * Resolves Current::androidMinimum by downloading the pointer file (preferred), falling back to cached preference.
     */
    private static String resolveAndroidMinimumVersion(Context context, SharedPreferences prefs) {
        final String cachedMinimum = prefs.getString(KEY_LAST_FETCHED_MINIMUM, "");
        final long cachedAt = prefs.getLong(KEY_LAST_FETCHED_AT_MS, 0L);

        // Prefer existing pointer system (it already handles redirects, caching, and correct index).
        // IMPORTANT: Do not hard-block this on OnlineStatus.isOnline(); OnlineStatus can briefly misreport
        // at launch even when the network is actually available.
        String fetched = "";
        try {
            fetched = staticVariables.getPointerUrlData("androidMinimum");
        } catch (Exception e) {
            Log.w(TAG, "[MIN_VERSION] staticVariables.getPointerUrlData(androidMinimum) failed: " + e.getMessage(), e);
        }

        if (fetched != null && !fetched.isEmpty()) {
            prefs.edit()
                    .putString(KEY_LAST_FETCHED_MINIMUM, fetched)
                    .putLong(KEY_LAST_FETCHED_AT_MS, System.currentTimeMillis())
                    .apply();
            return fetched;
        }

        // Fetch failed; use cached value if present.
        if (cachedMinimum != null && !cachedMinimum.isEmpty()) {
            Log.d(TAG, "[MIN_VERSION] Fetch failed - using cached minimum=" + cachedMinimum + " (cachedAt=" + cachedAt + ")");
        }
        return cachedMinimum;
    }

    // NOTE: Do not add pointer network fetch fallbacks here.
    // Pointer downloads are restricted to prescribed refresh times; this manager only reads cached pointer data.

    /**
     * Extracts digits and compares numerically.
     *
     * IMPORTANT: Android versioning in this project uses a suffix like "-70k" or "-mdf" (and potentially
     * other alpha-numeric identifiers). That suffix must be ignored for comparisons. We therefore drop
     * everything after the first '-' before extracting digits.
     */
    private static long parseVersionNumber(String version) {
        if (version == null) return 0L;
        String base = version;
        int dashIdx = base.indexOf('-');
        if (dashIdx >= 0) {
            base = base.substring(0, dashIdx);
        }
        String digits = base.replaceAll("[^0-9]", "");
        if (digits.isEmpty()) return 0L;
        try {
            return Long.parseLong(digits);
        } catch (NumberFormatException e) {
            return 0L;
        }
    }
}


package com.Bands70k;

import android.os.Looper;

import java.net.HttpURLConnection;

/**
 * Centralized HttpURLConnection configuration.
 *
 * Requirement:
 * - If running on the GUI thread, use 15s connect/read timeouts (fast but reasonable).
 * - If running on a background thread, use longer timeouts (explicit 60s) to tolerate poor networks.
 */
public final class HttpConnectionHelper {

    private static final int UI_THREAD_TIMEOUT_MS = 15_000;
    private static final int BACKGROUND_THREAD_TIMEOUT_MS = 60_000;

    private HttpConnectionHelper() {}

    public static void applyTimeouts(HttpURLConnection connection) {
        if (connection == null) {
            return;
        }

        boolean isUiThread = Looper.myLooper() == Looper.getMainLooper();
        int timeout = isUiThread ? UI_THREAD_TIMEOUT_MS : BACKGROUND_THREAD_TIMEOUT_MS;
        connection.setConnectTimeout(timeout);
        connection.setReadTimeout(timeout);
    }
}


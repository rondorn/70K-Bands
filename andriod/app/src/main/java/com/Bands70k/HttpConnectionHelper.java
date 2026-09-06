package com.Bands70k;

import android.os.Looper;

import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.URL;

/**
 * Centralized HttpURLConnection configuration.
 *
 * Requirement:
 * - If running on the GUI thread, use 15s connect/read timeouts (fast but reasonable).
 * - If running on a background thread, use longer timeouts (explicit 60s) to tolerate poor networks.
 * Dropbox CSV downloads also disable HTTP caches and append a cache-buster so replaced
 * files are not served from a stale CDN/HttpURLConnection cache.
 */
public final class HttpConnectionHelper {

    private static final int UI_THREAD_TIMEOUT_MS = 15_000;
    private static final int BACKGROUND_THREAD_TIMEOUT_MS = 60_000;

    private HttpConnectionHelper() {}

    /**
     * Opens a connection that must see freshly replaced remote files (pointer, artist, schedule, description map).
     */
    public static HttpURLConnection openNoCacheConnection(String url) throws IOException {
        String busted = cacheBustUrl(url);
        HttpURLConnection connection = (HttpURLConnection) new URL(busted).openConnection();
        connection.setInstanceFollowRedirects(true);
        applyTimeouts(connection);
        applyNoCache(connection);
        return connection;
    }

    public static String cacheBustUrl(String url) {
        if (url == null || url.isEmpty()) {
            return url;
        }
        return url + (url.contains("?") ? "&" : "?") + "_t=" + System.currentTimeMillis();
    }

    public static void applyNoCache(HttpURLConnection connection) {
        if (connection == null) {
            return;
        }
        connection.setUseCaches(false);
        connection.setRequestProperty("Cache-Control", "no-cache, no-store, must-revalidate");
        connection.setRequestProperty("Pragma", "no-cache");
    }

    public static void applyTimeouts(HttpURLConnection connection) {
        if (connection == null) {
            return;
        }

        boolean isUiThread = Looper.myLooper() == Looper.getMainLooper();
        int timeout = isUiThread ? UI_THREAD_TIMEOUT_MS : BACKGROUND_THREAD_TIMEOUT_MS;
        connection.setConnectTimeout(timeout);
        connection.setReadTimeout(timeout);
        try {
            NetworkCounter.recordDropbox(connection.getURL());
        } catch (Exception ignored) {
        }
    }
}

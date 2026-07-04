package com.Bands70k;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.util.Log;

import java.nio.charset.StandardCharsets;
import java.util.Locale;

/**
 * Guide QR deep link: system Camera app opens this app to the schedule QR scanner.
 * URL string comes from festival.json scheduleQRGuideURL (e.g. bands70k://schedule-scan).
 */
public final class ScheduleQRGuideLink {

    private static final String TAG = "ScheduleQRGuide";

    private static boolean pendingOpenScanner = false;

    private ScheduleQRGuideLink() {}

    /** Configured guide URL when schedule QR share is enabled; null otherwise. */
    public static String getConfiguredGuideURLString() {
        FestivalConfig cfg = FestivalConfig.getInstance();
        if (!cfg.scheduleQRShareEnabled) return null;
        String url = cfg.scheduleQRGuideURL;
        if (url == null || url.trim().isEmpty()) return null;
        return url.trim();
    }

    /** Returns true when {@code uri} is the configured guide link (sets pending open). */
    public static boolean handleIncomingUri(Uri uri) {
        if (!matchesGuideUri(uri)) return false;
        Log.d(TAG, "[QRGuide] Incoming guide URL: " + uri);
        pendingOpenScanner = true;
        return true;
    }

    /** Call when main UI is ready — opens scanner after a guide URL at cold launch. */
    public static void deliverPendingOpenScannerIfNeeded(Context context) {
        if (!pendingOpenScanner || context == null) return;
        pendingOpenScanner = false;
        if (!FestivalConfig.getInstance().scheduleQRShareEnabled) return;
        context.startActivity(new Intent(context, ScheduleQRScanActivity.class));
    }

    public static boolean matchesGuideUri(Uri uri) {
        if (uri == null) return false;
        String expected = getConfiguredGuideURLString();
        if (expected == null) return false;
        Uri expectedUri = Uri.parse(expected);
        return urlsEquivalent(uri, expectedUri);
    }

    public static boolean matchesGuidePayload(byte[] data) {
        if (data == null || data.length == 0) return false;
        String text = new String(data, StandardCharsets.UTF_8).trim();
        if (text.isEmpty()) return false;
        return matchesGuideURLString(text);
    }

    /** Scanner only: guide QR is a short UTF-8 URL, not a truncated binary schedule payload. */
    public static boolean matchesGuidePayloadExact(byte[] data) {
        String expected = getConfiguredGuideURLString();
        if (expected == null || data == null || data.length == 0) return false;
        String trimmedExpected = expected.trim();
        if (trimmedExpected.isEmpty()) return false;
        if (data[0] >= 0 && data[0] <= 2) return false;
        String text = new String(data, StandardCharsets.UTF_8).trim();
        if (!text.equals(trimmedExpected)) return false;
        return data.length <= trimmedExpected.getBytes(StandardCharsets.UTF_8).length + 4;
    }

    public static boolean matchesGuideURLString(String string) {
        if (string == null || string.trim().isEmpty()) return false;
        try {
            return matchesGuideUri(Uri.parse(string.trim()));
        } catch (Exception e) {
            return false;
        }
    }

    private static boolean urlsEquivalent(Uri a, Uri b) {
        if (a == null || b == null) return false;
        String schemeA = a.getScheme() != null ? a.getScheme().toLowerCase(Locale.US) : "";
        String schemeB = b.getScheme() != null ? b.getScheme().toLowerCase(Locale.US) : "";
        if (!schemeA.equals(schemeB)) return false;
        String hostA = a.getHost() != null ? a.getHost().toLowerCase(Locale.US) : "";
        String hostB = b.getHost() != null ? b.getHost().toLowerCase(Locale.US) : "";
        if (!hostA.isEmpty() || !hostB.isEmpty()) {
            if (!hostA.equals(hostB)) return false;
        }
        return normalizedPath(a.getPath()).equals(normalizedPath(b.getPath()));
    }

    private static String normalizedPath(String path) {
        String p = path != null ? path : "";
        if (!p.startsWith("/")) p = "/" + p;
        while (p.length() > 1 && p.endsWith("/")) {
            p = p.substring(0, p.length() - 1);
        }
        return p.toLowerCase(Locale.US);
    }
}

package com.Bands70k;

import android.util.Log;

import java.net.URI;
import java.net.URL;
import java.util.HashMap;
import java.util.Map;

/**
 * Filter logcat with: NETWORK_COUNTER
 */
public final class NetworkCounter {
    public static final String KEYWORD = "NETWORK_COUNTER";

    private static final Object LOCK = new Object();
    private static final Map<String, Integer> counts = new HashMap<>();

    private NetworkCounter() {}

    public static void record(String name) {
        int n;
        synchronized (LOCK) {
            Integer current = counts.get(name);
            n = (current == null ? 0 : current) + 1;
            counts.put(name, n);
        }
        Log.i(KEYWORD, "count=" + n + " " + name);
    }

    public static void recordDropbox(String urlString) {
        record("url=" + normalizeUrl(urlString));
    }

    public static void recordDropbox(URL url) {
        if (url != null) {
            recordDropbox(url.toString());
        }
    }

    static String normalizeUrl(String raw) {
        if (raw == null) {
            return "";
        }
        String trimmed = raw.trim();
        try {
            URI uri = URI.create(trimmed);
            String query = uri.getRawQuery();
            if (query == null || query.isEmpty()) {
                return trimmed;
            }
            StringBuilder kept = new StringBuilder();
            for (String part : query.split("&")) {
                int eq = part.indexOf('=');
                String name = (eq >= 0 ? part.substring(0, eq) : part).toLowerCase();
                if ("_t".equals(name) || "t".equals(name) || "cachebust".equals(name)) {
                    continue;
                }
                if (kept.length() > 0) {
                    kept.append('&');
                }
                kept.append(part);
            }
            String base = uri.getScheme() + "://" + uri.getRawAuthority()
                    + (uri.getRawPath() == null ? "" : uri.getRawPath());
            return kept.length() == 0 ? base : base + "?" + kept;
        } catch (Exception ignored) {
            return trimmed;
        }
    }
}

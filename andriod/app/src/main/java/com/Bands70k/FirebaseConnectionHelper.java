package com.Bands70k;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;

import java.io.BufferedReader;
import java.io.FileReader;

/**
 * Lazily opens and closes Firebase Realtime Database connections to stay within concurrent connection limits.
 *
 * One WebSocket per app. Sessions are refcounted so overlapping user/band/show writes share one
 * connection, then disconnect after a short idle so a herd of launches does not stay online.
 */
public final class FirebaseConnectionHelper {
    private static final String TAG = "FirebaseConnectionHelper";
    private static final Object LOCK = new Object();
    private static final Handler HANDLER = new Handler(Looper.getMainLooper());
    private static final long IDLE_CLOSE_DELAY_MS = 1000L;
    public static final int LAUNCH_JITTER_MAX_MS = 20_000;

    private static int writeSessionCount = 0;
    private static Runnable idleCloseRunnable;

    private FirebaseConnectionHelper() {}

    public static DatabaseReference databaseReference() {
        return FirebaseDatabase.getInstance().getReference();
    }

    /**
     * Opens the RTDB connection if this is the first in-flight write on this device.
     */
    public static DatabaseReference beginWriteSession(String reason) {
        synchronized (LOCK) {
            cancelIdleCloseLocked();
            writeSessionCount++;
            if (writeSessionCount == 1) {
                try {
                    FirebaseDatabase.getInstance().goOnline();
                    Log.d(TAG, "goOnline (" + reason + ") sessions=1");
                } catch (Exception error) {
                    writeSessionCount = Math.max(0, writeSessionCount - 1);
                    Log.w(TAG, "goOnline failed (" + reason + "): " + error.getMessage());
                    return null;
                }
            } else {
                Log.d(TAG, "reuse connection (" + reason + ") sessions=" + writeSessionCount);
            }
        }
        return FirebaseDatabase.getInstance().getReference();
    }

    /**
     * Closes the RTDB connection when the last in-flight write finishes (after a 1s idle).
     */
    public static void endWriteSession(String reason) {
        synchronized (LOCK) {
            writeSessionCount = Math.max(0, writeSessionCount - 1);
            Log.d(TAG, "endWriteSession (" + reason + ") sessions=" + writeSessionCount);
            if (writeSessionCount > 0) {
                return;
            }
            cancelIdleCloseLocked();
            idleCloseRunnable = () -> {
                synchronized (LOCK) {
                    if (writeSessionCount == 0) {
                        try {
                            FirebaseDatabase.getInstance().goOffline();
                            Log.d(TAG, "goOffline (idle after " + reason + ")");
                        } catch (Exception error) {
                            Log.w(TAG, "goOffline failed (" + reason + "): " + error.getMessage());
                        }
                    }
                }
            };
            HANDLER.postDelayed(idleCloseRunnable, IDLE_CLOSE_DELAY_MS);
        }
    }

    /**
     * After Firebase auto-init the SDK is online. Disconnect until a write session starts.
     */
    public static void goIdleAfterConfigure() {
        synchronized (LOCK) {
            if (writeSessionCount != 0) {
                return;
            }
            try {
                FirebaseDatabase.getInstance().goOffline();
                Log.d(TAG, "goOffline (post-configure idle)");
            } catch (Exception error) {
                Log.w(TAG, "goOffline post-configure failed: " + error.getMessage());
            }
        }
    }

    private static void cancelIdleCloseLocked() {
        if (idleCloseRunnable != null) {
            HANDLER.removeCallbacks(idleCloseRunnable);
            idleCloseRunnable = null;
        }
    }

    /** Spreads connection opens across launches using a stable per-device delay (0–20s). */
    public static int jitterDelayMs(String userId, int maxJitterMs) {
        if (userId == null || userId.isEmpty()) {
            return 0;
        }
        return Math.floorMod(userId.hashCode(), maxJitterMs + 1);
    }

    /**
     * Festival year for Firebase paths: always {@code Current::eventYear} from the pointer cache,
     * never UI browse year or calendar fallback.
     */
    public static int firebaseStorageEventYear() {
        int fromFile = readCurrentEventYearFromPointerCacheFile();
        if (fromFile > 2000) {
            return fromFile;
        }

        staticVariables.loadUrlsFromCachedPointerFile("Current");
        if (staticVariables.storePointerData != null) {
            String yearStr = staticVariables.storePointerData.get("eventYear");
            if (yearStr != null && !yearStr.trim().isEmpty()) {
                try {
                    int year = Integer.parseInt(yearStr.trim());
                    if (year > 2000) {
                        return year;
                    }
                } catch (NumberFormatException ignored) {
                }
            }
        }

        Log.e(TAG, "Unable to resolve pointer Current event year for Firebase storage");
        return 0;
    }

    private static int readCurrentEventYearFromPointerCacheFile() {
        if (!FileHandler70k.pointerCacheFile.exists()) {
            return 0;
        }
        try (BufferedReader reader = new BufferedReader(new FileReader(FileHandler70k.pointerCacheFile))) {
            String line;
            while ((line = reader.readLine()) != null) {
                String trimmed = line.trim();
                if (!trimmed.startsWith("Current::eventYear::")) {
                    continue;
                }
                String[] parts = trimmed.split("::");
                if (parts.length >= 3) {
                    return Integer.parseInt(parts[2].trim());
                }
            }
        } catch (Exception error) {
            Log.w(TAG, "Failed reading Current event year from pointer cache: " + error.getMessage());
        }
        return 0;
    }
}

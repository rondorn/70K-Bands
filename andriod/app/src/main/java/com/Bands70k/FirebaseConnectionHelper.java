package com.Bands70k;

import android.util.Log;

import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;

import java.io.BufferedReader;
import java.io.FileReader;

/**
 * Lazily opens and closes Firebase Realtime Database connections to stay within concurrent connection limits.
 */
public final class FirebaseConnectionHelper {
    private FirebaseConnectionHelper() {}

    public static DatabaseReference databaseReference() {
        return FirebaseDatabase.getInstance().getReference();
    }

    public static void goOnline(String reason) {
        try {
            FirebaseDatabase.getInstance().goOnline();
            Log.d("FirebaseConnectionHelper", "goOnline (" + reason + ")");
        } catch (Exception error) {
            Log.w("FirebaseConnectionHelper", "goOnline failed (" + reason + "): " + error.getMessage());
        }
    }

    public static void goOffline(String reason) {
        try {
            FirebaseDatabase.getInstance().goOffline();
            Log.d("FirebaseConnectionHelper", "goOffline (" + reason + ")");
        } catch (Exception error) {
            Log.w("FirebaseConnectionHelper", "goOffline failed (" + reason + "): " + error.getMessage());
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

        Log.e("FirebaseConnectionHelper", "Unable to resolve pointer Current event year for Firebase storage");
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
            Log.w("FirebaseConnectionHelper", "Failed reading Current event year from pointer cache: " + error.getMessage());
        }
        return 0;
    }
}

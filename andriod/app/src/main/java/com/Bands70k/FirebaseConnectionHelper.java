package com.Bands70k;

import android.util.Log;

import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;

/**
 * Lazily opens and closes Firebase Realtime Database connections to stay within concurrent connection limits.
 */
public final class FirebaseConnectionHelper {
    private FirebaseConnectionHelper() {}

    public static DatabaseReference databaseReference() {
        return FirebaseDatabase.getInstance().getReference();
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
}

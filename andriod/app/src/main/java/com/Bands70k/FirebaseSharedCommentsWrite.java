package com.Bands70k;

import android.util.Log;

import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.TimeZone;

/**
 * Write-only Firebase submissions for shared band descriptions.
 */
public class FirebaseSharedCommentsWrite {

    private static final String TAG = "SHARED_COMMENTS";
    private DatabaseReference mDatabase;

    public FirebaseSharedCommentsWrite() {
        mDatabase = FirebaseDatabase.getInstance().getReference();
    }

    public interface WriteCallback {
        void onComplete(boolean success);
    }

    /**
     * Writes to {@code notes/{userID}/{year}/{band}}.
     */
    public void writeSharedComment(String bandName, String descriptionText, String userName, WriteCallback callback) {
        if (staticVariables.isTestingEnv) {
            Log.d(TAG, "Skipping write in test environment");
            if (callback != null) {
                callback.onComplete(true);
            }
            return;
        }

        if (bandName == null || bandName.isEmpty()) {
            if (callback != null) {
                callback.onComplete(false);
            }
            return;
        }

        if (staticVariables.userID == null || staticVariables.userID.isEmpty()) {
            Log.e(TAG, "Missing user ID");
            if (callback != null) {
                callback.onComplete(false);
            }
            return;
        }

        if (mDatabase == null) {
            Log.e(TAG, "Firebase reference not initialized");
            if (callback != null) {
                callback.onComplete(false);
            }
            return;
        }

        int storageYear = staticVariables.resolveStorageEventYear();
        if (storageYear <= 0) {
            Log.e(TAG, "Missing eventYear in production pointer file");
            if (callback != null) {
                callback.onComplete(false);
            }
            return;
        }

        String sanitizedBandName = sanitizeBandNameForFirebase(bandName);
        String yearString = String.valueOf(storageYear);
        String path = "notes/" + staticVariables.userID + "/" + yearString + "/" + sanitizedBandName;

        SimpleDateFormat formatter = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US);
        formatter.setTimeZone(TimeZone.getTimeZone("UTC"));

        Map<String, Object> payload = new HashMap<>();
        payload.put("userID", staticVariables.userID);
        payload.put("userName", userName);
        payload.put("band", bandName);
        payload.put("year", yearString);
        payload.put("descriptionText", descriptionText);
        payload.put("updatedAt", formatter.format(new Date()));

        Log.d(TAG, "Writing to " + path);

        mDatabase.child(path).setValue(payload)
                .addOnSuccessListener(aVoid -> {
                    Log.d(TAG, "Write succeeded for '" + bandName + "'");
                    if (callback != null) {
                        callback.onComplete(true);
                    }
                })
                .addOnFailureListener(e -> {
                    Log.e(TAG, "Write failed: " + e.getMessage());
                    if (callback != null) {
                        callback.onComplete(false);
                    }
                });
    }

    private String sanitizeBandNameForFirebase(String bandName) {
        if (bandName == null || bandName.isEmpty()) {
            return bandName;
        }
        return bandName
                .replace(".", "_")
                .replace("#", "_")
                .replace("$", "_")
                .replace("[", "_")
                .replace("]", "_")
                .replace("/", "_")
                .replace("'", "_")
                .replace("\"", "_")
                .replace("\\", "_")
                .replaceAll("[\\p{Cntrl}]", "")
                .trim();
    }
}

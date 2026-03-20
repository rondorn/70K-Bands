package com.Bands70k;

import android.util.Log;

import org.json.JSONObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

/**
 * Persists "has run AI schedule" per year and backup of attendance for restore.
 * Port of Swift AIScheduleStorage.
 */
public class AIScheduleStorage {

    private static final String TAG = "AIScheduleStorage";
    private static final String HAS_RUN_PREFIX = "AIScheduleHasRun_";
    private static final String BACKUP_FILE_PREFIX = "AIScheduleBackup_";

    public static boolean hasRunAI(int year) {
        return SharedPreferencesManager.getInstance().getBoolean(HAS_RUN_PREFIX + year, false);
    }

    public static void setHasRunAI(int year, boolean value) {
        SharedPreferencesManager.getInstance().setBoolean(HAS_RUN_PREFIX + year, value);
    }

    private static File backupFileForYear(int year) {
        File dir = FileHandler70k.baseDirectory;
        if (!dir.exists()) dir.mkdirs();
        return new File(dir, BACKUP_FILE_PREFIX + year + ".json");
    }

    /**
     * Save attendance state for the given year (only keys ending with ":year"). Call before applying AI schedule.
     */
    public static void saveBackup(Map<String, String> attended, int year) {
        if (attended == null) return;
        String suffix = ":" + year;
        Map<String, String> filtered = new HashMap<>();
        for (Map.Entry<String, String> e : attended.entrySet()) {
            if (e.getKey() != null && e.getKey().endsWith(suffix)) {
                filtered.put(e.getKey(), e.getValue() != null ? e.getValue() : "");
            }
        }
        if (filtered.isEmpty()) return;
        try {
            JSONObject json = new JSONObject(filtered);
            File f = backupFileForYear(year);
            try (FileOutputStream out = new FileOutputStream(f)) {
                out.write(json.toString().getBytes(StandardCharsets.UTF_8));
            }
        } catch (Exception e) {
            Log.e(TAG, "Failed to save backup for year " + year + ": " + e.getMessage());
        }
    }

    /**
     * Saves year slice for wizard rollback (may be empty). Always writes a file so cancel-after-clear can restore.
     */
    public static void saveWizardRollbackBackup(Map<String, String> attended, int year) {
        if (attended == null) attended = new HashMap<>();
        String suffix = ":" + year;
        Map<String, String> filtered = new HashMap<>();
        for (Map.Entry<String, String> e : attended.entrySet()) {
            if (e.getKey() != null && e.getKey().endsWith(suffix)) {
                filtered.put(e.getKey(), e.getValue() != null ? e.getValue() : "");
            }
        }
        try {
            JSONObject json = new JSONObject(filtered);
            File f = backupFileForYear(year);
            try (FileOutputStream out = new FileOutputStream(f)) {
                out.write(json.toString().getBytes(StandardCharsets.UTF_8));
            }
        } catch (Exception e) {
            Log.e(TAG, "Failed to save wizard rollback backup for year " + year + ": " + e.getMessage());
        }
    }

    /**
     * Load backup for year, or null if none.
     */
    @SuppressWarnings("unchecked")
    public static Map<String, String> loadBackup(int year) {
        try {
            File f = backupFileForYear(year);
            if (!f.exists()) return null;
            try (FileInputStream in = new FileInputStream(f)) {
                byte[] buf = new byte[(int) f.length()];
                int n = in.read(buf);
                if (n <= 0) return null;
                JSONObject json = new JSONObject(new String(buf, 0, n, StandardCharsets.UTF_8));
                Map<String, String> out = new HashMap<>();
                Iterator<String> it = json.keys();
                while (it.hasNext()) {
                    String k = it.next();
                    out.put(k, json.optString(k, ""));
                }
                return out;
            }
        } catch (Exception e) {
            Log.e(TAG, "Failed to load backup for year " + year + ": " + e.getMessage());
            return null;
        }
    }

    public static void clearBackup(int year) {
        File f = backupFileForYear(year);
        if (f.exists()) f.delete();
    }

    /**
     * Restore attendance to pre-AI state for the year. Returns true if restore was performed.
     */
    public static boolean restore(showsAttended attendedHandle, int year) {
        Map<String, String> backup = loadBackup(year);
        if (backup == null || backup.isEmpty()) return false;
        attendedHandle.restoreFromBackup(year, backup);
        clearBackup(year);
        setHasRunAI(year, false);
        return true;
    }
}

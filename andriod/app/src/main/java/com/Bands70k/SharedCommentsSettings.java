package com.Bands70k;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;

import java.io.File;
import java.util.Map;

/**
 * Shared band description submission settings and eligibility helpers.
 */
public final class SharedCommentsSettings {

    private static final String TAG = "SHARED_COMMENTS";
    private static final String PREFS_NAME = "SharedCommentsSettings";
    private static final String TERMS_ACCEPTED_KEY = "SharedCommentsTermsAccepted";
    private static final String USERNAME_KEY = "SharedCommentsUsername";

    private SharedCommentsSettings() {}

    public static boolean hasAcceptedTerms() {
        return prefs().getBoolean(TERMS_ACCEPTED_KEY, false);
    }

    public static void setTermsAccepted() {
        prefs().edit().putBoolean(TERMS_ACCEPTED_KEY, true).apply();
    }

    public static String getUsername() {
        String value = prefs().getString(USERNAME_KEY, "");
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    public static void setUsername(String name) {
        String trimmed = name == null ? "" : name.trim();
        prefs().edit().putString(USERNAME_KEY, trimmed).apply();
    }

    /**
     * Reads {@code Current::enableSharedComments::YES} from the cached pointer file.
     */
    public static void loadEnableSharedComments() {
        String value = readPointerCurrentValue("enableSharedComments");
        staticVariables.enableSharedComments = value != null && value.trim().equalsIgnoreCase("YES");
        Log.d(TAG, "enableSharedComments = " + staticVariables.enableSharedComments);
    }

    public static boolean canOfferPostToAllUsers(String bandName, String bandNotes) {
        if (!staticVariables.enableSharedComments) {
            return false;
        }
        if (bandName == null || bandName.trim().isEmpty()) {
            return false;
        }
        if (isBandInDescriptionMap(bandName)) {
            return false;
        }
        return isNoteTextEligibleForSharedSubmit(bandNotes, bandName);
    }

    public static boolean isNoteTextEligibleForSharedSubmit(String notes, String bandName) {
        if (notes == null) {
            return false;
        }
        if (FestivalConfig.getInstance().isDefaultDescriptionText(notes)) {
            return false;
        }
        if (notes.length() < 2) {
            return false;
        }
        return !custMatchesDefault(notes, bandName);
    }

    public static boolean isValidUsername(String name) {
        if (name == null) {
            return false;
        }
        String trimmed = name.trim();
        return trimmed.length() >= 2 && trimmed.length() <= 24;
    }

    public static boolean isBandInDescriptionMap(String bandName) {
        String normalized = normalizeBandName(bandName);
        return staticVariables.descriptionMapModData.containsKey(normalized);
    }

    private static boolean custMatchesDefault(String customNote, String bandName) {
        String defaultNote = getDefaultNoteForCompare(bandName);
        if (defaultNote == null) {
            return false;
        }
        return stripDataForCompare(defaultNote).equals(stripDataForCompare(customNote));
    }

    private static String getDefaultNoteForCompare(String bandName) {
        try {
            String normalizedBandName = normalizeBandName(bandName);
            String dateModified = String.valueOf(staticVariables.descriptionMapModData.get(normalizedBandName));

            File defaultNoteFile;
            if (dateModified != null && !dateModified.equals("null") && !dateModified.trim().isEmpty()) {
                defaultNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note-" + dateModified.trim());
            } else {
                defaultNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note_new");
            }

            if (!defaultNoteFile.exists()) {
                File legacyDefaultNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note_new");
                if (legacyDefaultNoteFile.exists()) {
                    defaultNoteFile = legacyDefaultNoteFile;
                } else {
                    return null;
                }
            }

            Map<String, String> noteData = (Map<String, String>) FileHandler70k.readObject(defaultNoteFile);
            if (noteData != null && noteData.containsKey("defaultNote")) {
                return noteData.get("defaultNote");
            }
        } catch (Exception e) {
            Log.w(TAG, "Error reading default note for " + bandName + ": " + e.getMessage());
        }
        return null;
    }

    private static String stripDataForCompare(String dataString) {
        if (dataString == null) {
            return "";
        }
        String stripped = dataString.replaceAll("\\s", "");
        stripped = stripped.replaceAll("<br>", "");
        stripped = stripped.replaceAll("<[^>]*>", "");
        return stripped;
    }

    private static String normalizeBandName(String bandName) {
        if (bandName == null) {
            return "";
        }
        return bandName.trim()
                .replace("⁦", "")
                .replace("⁧", "")
                .replace("\u200E", "")
                .replace("\u200F", "")
                .replace("\u202A", "")
                .replace("\u202B", "")
                .replace("\u202C", "")
                .replace("\u202D", "")
                .replace("\u202E", "")
                .replace("\u2066", "")
                .replace("\u2067", "")
                .replace("\u2068", "")
                .replace("\u2069", "");
    }

    private static SharedPreferences prefs() {
        Context context = Bands70k.getAppContext();
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }

    private static String readPointerCurrentValue(String key) {
        File file = FileHandler70k.pointerCacheFile;
        if (file == null || !file.exists()) {
            return null;
        }
        try {
            String content = FileHandler70k.loadData(file);
            if (content == null || content.trim().isEmpty()) {
                return null;
            }
            for (String rawLine : content.split("\\n")) {
                String line = rawLine.trim();
                if (line.isEmpty()) {
                    continue;
                }
                if (line.startsWith("Current::" + key + "::")) {
                    String[] parts = line.split("::", -1);
                    if (parts.length >= 3) {
                        return parts[2].trim();
                    }
                }
                String[] parts = line.split("::", -1);
                if (parts.length >= 3
                        && "Current".equals(parts[0].trim())
                        && key.equals(parts[1].trim())) {
                    return parts[2].trim();
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Failed to read pointer file: " + e.getMessage());
        }
        return null;
    }
}

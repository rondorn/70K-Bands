package com.Bands70k;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.util.Log;

import androidx.localbroadcastmanager.content.LocalBroadcastManager;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * SharedPreferencesManager
 * Manages shared preferences feature - allows users to share and import
 * Must/Might/Won't priorities and event attendance schedules
 * 
 * This manager enables cross-platform sharing between iOS and Android.
 * Files are stored in JSON format with .70kshare or .mdfshare extension.
 */
public class SharedPreferencesManager {
    private static final String TAG = "SharedPrefManager";
    private static SharedPreferencesManager instance;
    
    private static final String ACTIVE_SOURCE_KEY = "ActivePreferenceSource";
    private static final String PREFS_NAME = "SharedPreferencesManagerPrefs";
    
    private Context context;
    private SharedPreferences prefs;
    
    private SharedPreferencesManager() {
        Log.d(TAG, "🔧 [SHARING_INIT] SharedPreferencesManager init() called");
        this.context = Bands70k.getAppContext();
        this.prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        Log.d(TAG, "🔧 [SHARING_INIT] SharedPreferencesManager init() completed");
    }
    
    public static synchronized SharedPreferencesManager getInstance() {
        if (instance == null) {
            instance = new SharedPreferencesManager();
        }
        return instance;
    }
    
    /**
     * Gets the file extension for shared preference files (app-specific)
     * @return File extension (.70kshare or .mdfshare)
     */
    private String getFileExtension() {
        return FestivalConfig.getInstance().isMDF() ? "mdfshare" : "70kshare";
    }
    
    /**
     * Gets the currently active preference source
     * @return "Default" for user's own, or the userId of a shared set
     */
    public String getActivePreferenceSource() {
        String source = prefs.getString(ACTIVE_SOURCE_KEY, "Default");
        Log.d(TAG, "🔍 [PROFILE_DEBUG] getActivePreferenceSource() returning: '" + source + "'");
        return source;
    }
    
    /**
     * Sets the active preference source
     * @param sourceName "Default" for user's own, or userId of imported set
     */
    public void setActivePreferenceSource(String sourceName) {
        String oldSource = getActivePreferenceSource();
        
        Log.d(TAG, "🔄 [PROFILE_SWITCH] ========================================");
        Log.d(TAG, "🔄 [PROFILE_SWITCH] SWITCHING PROFILE");
        Log.d(TAG, "🔄 [PROFILE_SWITCH] FROM: '" + oldSource + "'");
        Log.d(TAG, "🔄 [PROFILE_SWITCH] TO:   '" + sourceName + "'");
        Log.d(TAG, "🔄 [PROFILE_SWITCH] ========================================");
        
        // Set flag to block sync operations during profile switch
        SharedPreferences.Editor editor = prefs.edit();
        editor.putBoolean("ProfileSwitchInProgress", true);
        editor.putString(ACTIVE_SOURCE_KEY, sourceName);
        editor.apply();
        
        Log.d(TAG, "🚫 [PROFILE_SWITCH] Sync operations BLOCKED during profile switch");
        
        // Post notification to refresh UI
        Intent intent = new Intent("PreferenceSourceChanged");
        intent.putExtra("sourceName", sourceName);
        LocalBroadcastManager.getInstance(context).sendBroadcast(intent);
        
        Intent refreshIntent = new Intent("refreshGUI");
        LocalBroadcastManager.getInstance(context).sendBroadcast(refreshIntent);
        
        // Unblock sync after delay (5 seconds)
        new android.os.Handler().postDelayed(() -> {
            SharedPreferences.Editor ed = prefs.edit();
            ed.putBoolean("ProfileSwitchInProgress", false);
            ed.apply();
            Log.d(TAG, "✅ [PROFILE_SWITCH] Sync operations UNBLOCKED after profile switch complete (5s delay)");
        }, 5000);
        
        Log.d(TAG, "✅ [PROFILE_SWITCH] Active preference source changed: '" + oldSource + "' → '" + sourceName + "'");
    }
    
    /**
     * Gets list of all available preference sources (user's own + imported)
     * @return List of profile keys (UserIDs for shared, "Default" for own)
     */
    public List<String> getAvailablePreferenceSources() {
        Log.d(TAG, "📋 [SOURCES_DEBUG] === Getting available preference sources ===");
        
        List<ProfileMetadata> profiles = SQLiteProfileManager.getInstance().getAllProfiles();
        List<String> sources = new ArrayList<>();
        
        for (ProfileMetadata profile : profiles) {
            sources.add(profile.userId);
        }
        
        Log.d(TAG, "📋 [SOURCES_DEBUG] Final available sources: " + sources.toString());
        Log.d(TAG, "📋 [SOURCES_DEBUG] === End getting sources ===");
        return sources;
    }
    
    /**
     * Gets the display name for a profile key
     * @param profileKey The profile key (UserID or "Default")
     * @return The display name
     */
    public String getDisplayName(String profileKey) {
        ProfileMetadata profile = SQLiteProfileManager.getInstance().getProfile(profileKey);
        if (profile != null) {
            return profile.label;
        }
        return profileKey;
    }
    
    /**
     * Checks if a profile is read-only (cannot be edited)
     * @param profileKey The profile key (UserID or "Default")
     * @return true if read-only, false if editable
     */
    public boolean isReadOnly(String profileKey) {
        return SQLiteProfileManager.getInstance().isReadOnly(profileKey);
    }
    
    /**
     * Exports current user's priorities and attendance to a shareable file
     * @param shareName Name to include in the export (e.g., device name or user's name)
     * @return Uri of the created file, or null if export failed
     */
    public Uri exportCurrentPreferences(String shareName) {
        try {
            Log.d(TAG, "📤 [EXPORT] Starting export from Default profile");
            
            // Get sender's device ID
            String senderUserId = staticVariables.userID;
            if (senderUserId == null || senderUserId.isEmpty()) {
                senderUserId = android.provider.Settings.Secure.getString(
                        context.getContentResolver(),
                        android.provider.Settings.Secure.ANDROID_ID
                );
            }
            
            // Get priorities from Default profile
            Map<String, Integer> priorities = new HashMap<>();
            Map<String, String> bandRankings = rankStore.getBandRankings();
            for (Map.Entry<String, String> entry : bandRankings.entrySet()) {
                String bandName = entry.getKey();
                String ranking = entry.getValue();
                int priorityLevel = rankingToPriority(ranking);
                priorities.put(bandName, priorityLevel);
            }
            
            // Get attendance from Default profile
            Map<String, Integer> attendance = new HashMap<>();
            Map<String, String> showsAttended = staticVariables.attendedHandler.getShowsAttended();
            for (Map.Entry<String, String> entry : showsAttended.entrySet()) {
                String index = entry.getKey();
                String status = entry.getValue();
                int statusCode = attendanceToCode(status);
                attendance.put(index, statusCode);
            }
            
            // Create JSON structure
            JSONObject json = new JSONObject();
            json.put("senderUserId", senderUserId);
            json.put("senderName", shareName != null ? shareName : "");  // Sender's chosen name
            json.put("shareDate", new Date().getTime());
            json.put("eventYear", staticVariables.eventYear);
            json.put("version", "1.0");
            
            // Add priorities
            JSONObject prioritiesJson = new JSONObject();
            for (Map.Entry<String, Integer> entry : priorities.entrySet()) {
                prioritiesJson.put(entry.getKey(), entry.getValue());
            }
            json.put("priorities", prioritiesJson);
            
            // Add attendance
            JSONObject attendanceJson = new JSONObject();
            for (Map.Entry<String, Integer> entry : attendance.entrySet()) {
                attendanceJson.put(entry.getKey(), entry.getValue());
            }
            json.put("attendance", attendanceJson);
            
            // Write to file - use share name if provided, otherwise use user ID
            String fileNamePrefix;
            if (shareName != null && !shareName.isEmpty()) {
                // Clean the share name for use in filename (remove special characters)
                fileNamePrefix = shareName.replaceAll("[^a-zA-Z0-9]", "_");
            } else {
                fileNamePrefix = senderUserId.substring(0, Math.min(8, senderUserId.length()));
            }
            String fileName = "70KBands_" + fileNamePrefix + "_" + staticVariables.eventYear + "." + getFileExtension();
            File sharesDir = new File(context.getFilesDir(), "Shares");
            if (!sharesDir.exists()) {
                sharesDir.mkdirs();
            }
            
            File shareFile = new File(sharesDir, fileName);
            FileOutputStream fos = new FileOutputStream(shareFile);
            fos.write(json.toString(2).getBytes());
            fos.close();
            
            Log.d(TAG, "✅ Exported preferences to: " + shareFile.getAbsolutePath());
            Log.d(TAG, "✅ Priorities: " + priorities.size() + ", Attendance: " + attendance.size());
            
            // Return file URI using FileProvider for sharing
            return androidx.core.content.FileProvider.getUriForFile(
                    context,
                    context.getPackageName() + ".fileprovider",
                    shareFile
            );
            
        } catch (Exception e) {
            Log.e(TAG, "❌ Failed to export preferences", e);
            return null;
        }
    }
    
    /**
     * Validates and parses an imported preference file
     * @param uri URI of the imported file
     * @return SharedPreferenceSet if valid, null otherwise
     */
    public SharedPreferenceSet validateImportedFile(Uri uri) {
        try {
            // Read file content
            FileInputStream fis = (FileInputStream) context.getContentResolver().openInputStream(uri);
            BufferedReader reader = new BufferedReader(new java.io.InputStreamReader(fis));
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                sb.append(line);
            }
            reader.close();
            
            // Parse JSON
            JSONObject json = new JSONObject(sb.toString());
            
            String senderUserId = json.getString("senderUserId");
            String senderName = json.optString("senderName", "");
            long shareDate = json.getLong("shareDate");
            int eventYear = json.getInt("eventYear");
            String version = json.optString("version", "1.0");
            
            // Parse priorities
            JSONObject prioritiesJson = json.getJSONObject("priorities");
            Map<String, Integer> priorities = new HashMap<>();
            java.util.Iterator<String> keys = prioritiesJson.keys();
            while (keys.hasNext()) {
                String key = keys.next();
                priorities.put(key, prioritiesJson.getInt(key));
            }
            
            // Parse attendance
            JSONObject attendanceJson = json.getJSONObject("attendance");
            Map<String, Integer> attendance = new HashMap<>();
            keys = attendanceJson.keys();
            while (keys.hasNext()) {
                String key = keys.next();
                attendance.put(key, attendanceJson.getInt(key));
            }
            
            SharedPreferenceSet preferenceSet = new SharedPreferenceSet(
                    senderUserId, senderName, new Date(shareDate), eventYear,
                    priorities, attendance, version
            );
            
            Log.d(TAG, "✅ Valid preference file: " + senderName + " (UserID: " + senderUserId + ")");
            return preferenceSet;
            
        } catch (Exception e) {
            Log.e(TAG, "❌ Failed to decode preference file", e);
            return null;
        }
    }
    
    /**
     * Imports and saves a shared preference set with a custom name
     * @param preferenceSet The preference set to import
     * @param customName Custom display name for this import
     * @return true if successful
     */
    public boolean importPreferenceSet(SharedPreferenceSet preferenceSet, String customName) {
        String profileKey = preferenceSet.senderUserId;
        
        Log.d(TAG, "📥 [IMPORT] ========================================");
        Log.d(TAG, "📥 [IMPORT] Starting import for profile");
        Log.d(TAG, "📥 [IMPORT] UserID (key): " + profileKey);
        Log.d(TAG, "📥 [IMPORT] Name (label): " + customName);
        Log.d(TAG, "📥 [IMPORT] Priorities: " + preferenceSet.priorities.size() + 
                ", Attendance: " + preferenceSet.attendance.size());
        Log.d(TAG, "📥 [IMPORT] CURRENT active profile BEFORE import: '" + getActivePreferenceSource() + "'");
        Log.d(TAG, "📥 [IMPORT] ========================================");
        
        try {
            // Save priorities to profile-specific file
            File profileDir = new File(context.getFilesDir(), "profiles/" + profileKey);
            if (!profileDir.exists()) {
                profileDir.mkdirs();
            }
            
            // Save priorities
            File prioritiesFile = new File(profileDir, "bandRankings.txt");
            FileOutputStream fos = new FileOutputStream(prioritiesFile);
            for (Map.Entry<String, Integer> entry : preferenceSet.priorities.entrySet()) {
                String ranking = priorityToRanking(entry.getValue());
                String line = entry.getKey() + ":" + ranking + "\n";
                fos.write(line.getBytes());
            }
            fos.close();
            
            // Save attendance
            File attendanceFile = new File(profileDir, "showsAttended.data");
            Map<String, String> attendanceMap = new HashMap<>();
            for (Map.Entry<String, Integer> entry : preferenceSet.attendance.entrySet()) {
                String status = codeToAttendance(entry.getValue());
                attendanceMap.put(entry.getKey(), status);
            }
            FileOutputStream aFos = new FileOutputStream(attendanceFile);
            ObjectOutputStream oos = new ObjectOutputStream(aFos);
            oos.writeObject(attendanceMap);
            oos.close();
            aFos.close();
            
            // Get or assign color
            String colorHex = ProfileColorManager.getInstance().getColor(profileKey);
            
            // Create/update profile metadata in SQLite
            ProfileMetadata profile = new ProfileMetadata(
                    profileKey,
                    customName,
                    colorHex,
                    new Date(),
                    preferenceSet.shareDate,
                    preferenceSet.eventYear,
                    preferenceSet.priorities.size(),
                    preferenceSet.attendance.size(),
                    false  // Imported profiles are editable - changes save until re-import overwrites
            );
            
            Log.d(TAG, "📥 [IMPORT] About to save profile to SQLite: " + customName + " (" + profileKey + ")");
            boolean saveSuccess = SQLiteProfileManager.getInstance().saveProfile(profile);
            Log.d(TAG, "📥 [IMPORT] SQLiteProfileManager.saveProfile returned: " + saveSuccess);
            
            if (!saveSuccess) {
                Log.e(TAG, "❌ [IMPORT] Failed to save profile to SQLite!");
                return false;
            }
            
            // Verify it was saved
            ProfileMetadata verify = SQLiteProfileManager.getInstance().getProfile(profileKey);
            if (verify != null) {
                Log.d(TAG, "✅ [IMPORT] Verified profile saved: " + verify.label);
            } else {
                Log.e(TAG, "❌ [IMPORT] Profile save verification FAILED!");
            }
            
            Log.d(TAG, "✅ [IMPORT] Imported preference set: " + customName + " (UserID: " + profileKey + ")");
            return true;
            
        } catch (Exception e) {
            Log.e(TAG, "❌ [IMPORT] Failed to import preference set", e);
            return false;
        }
    }
    
    /**
     * Gets priority for a band from the active preference source
     * @param bandName Name of the band
     * @return Priority level (0-3)
     */
    public int getPriorityFromActiveSource(String bandName) {
        String activeSource = getActivePreferenceSource();
        
        if ("Default".equals(activeSource)) {
            // Use standard rankStore for Default profile
            String ranking = rankStore.getRankForBand(bandName);
            return rankingToPriority(ranking);
        } else {
            // Load from profile-specific file
            try {
                File profileDir = new File(context.getFilesDir(), "profiles/" + activeSource);
                File prioritiesFile = new File(profileDir, "bandRankings.txt");
                
                if (prioritiesFile.exists()) {
                    BufferedReader br = new BufferedReader(new FileReader(prioritiesFile));
                    String line;
                    while ((line = br.readLine()) != null) {
                        String[] parts = line.split(":");
                        if (parts.length == 2 && parts[0].equals(bandName)) {
                            br.close();
                            return rankingToPriority(parts[1]);
                        }
                    }
                    br.close();
                }
            } catch (Exception e) {
                Log.e(TAG, "Error reading priority for " + bandName, e);
            }
            return 0;  // Unknown
        }
    }
    
    /**
     * Gets attendance status for an event from the active preference source
     * @param index Event index string
     * @return Attendance status string
     */
    public String getAttendanceFromActiveSource(String index) {
        String activeSource = getActivePreferenceSource();
        
        if ("Default".equals(activeSource)) {
            // Use standard attendedHandler for Default profile
            return staticVariables.attendedHandler.getShowAttendedIcon(index);
        } else {
            // Load from profile-specific file
            try {
                File profileDir = new File(context.getFilesDir(), "profiles/" + activeSource);
                File attendanceFile = new File(profileDir, "showsAttended.data");
                
                if (attendanceFile.exists()) {
                    FileInputStream fis = new FileInputStream(attendanceFile);
                    ObjectInputStream ois = new ObjectInputStream(fis);
                    Map<String, String> attendanceMap = (Map<String, String>) ois.readObject();
                    ois.close();
                    fis.close();
                    
                    return attendanceMap.getOrDefault(index, staticVariables.sawNoneStatus);
                }
            } catch (Exception e) {
                Log.e(TAG, "Error reading attendance for " + index, e);
            }
            return staticVariables.sawNoneStatus;
        }
    }
    
    /**
     * Deletes an imported preference set by UserID
     * @param userId The sender's UserID
     * @return true if successful
     */
    public boolean deleteImportedSet(String userId) {
        Log.d(TAG, "🗑️ [DELETE] Deleting profile with UserID: " + userId);
        
        if ("Default".equals(userId)) {
            Log.e(TAG, "❌ [DELETE] Cannot delete 'Default'");
            return false;
        }
        
        try {
            // Delete profile files
            File profileDir = new File(context.getFilesDir(), "profiles/" + userId);
            deleteDirectory(profileDir);
            
            // Delete from SQLite
            SQLiteProfileManager.getInstance().deleteProfile(userId);
            
            // Remove color assignment
            ProfileColorManager.getInstance().removeColor(userId);
            
            // If this was the active source, switch back to Default
            if (userId.equals(getActivePreferenceSource())) {
                setActivePreferenceSource("Default");
            }
            
            Log.d(TAG, "✅ [DELETE] Deleted profile with UserID: " + userId);
            return true;
            
        } catch (Exception e) {
            Log.e(TAG, "❌ [DELETE] Failed to delete profile", e);
            return false;
        }
    }
    
    /**
     * Renames the display label for a shared profile
     * @param userId The sender's UserID
     * @param newName The new display name
     * @return true if successful
     */
    public boolean renameProfile(String userId, String newName) {
        Log.d(TAG, "✏️ [RENAME] Renaming profile " + userId + " to: " + newName);
        return SQLiteProfileManager.getInstance().updateLabel(userId, newName);
    }
    
    // Helper methods
    
    /**
     * Converts Android ranking (emoji) to iOS priority number
     * iOS standard: 0=Unknown, 1=Must, 2=Might, 3=Won't
     */
    private int rankingToPriority(String ranking) {
        if (staticVariables.mustSeeIcon.equals(ranking)) return 1;  // Must = 1 (iOS standard)
        if (staticVariables.mightSeeIcon.equals(ranking)) return 2; // Might = 2
        if (staticVariables.wontSeeIcon.equals(ranking)) return 3;  // Won't = 3 (iOS standard)
        return 0;  // Unknown = 0
    }
    
    /**
     * Converts iOS priority number to Android ranking (emoji)
     * iOS standard: 0=Unknown, 1=Must, 2=Might, 3=Won't
     */
    private String priorityToRanking(int priority) {
        switch (priority) {
            case 1: return staticVariables.mustSeeIcon;  // 1 = Must (iOS standard)
            case 2: return staticVariables.mightSeeIcon; // 2 = Might
            case 3: return staticVariables.wontSeeIcon;  // 3 = Won't (iOS standard)
            default: return "";  // 0 or unknown = empty
        }
    }
    
    /**
     * Converts Android attendance status to iOS code
     * iOS standard: 0=Unknown, 1=Some, 2=All, 3=None
     */
    private int attendanceToCode(String status) {
        if (staticVariables.sawAllStatus.equals(status)) return 2;   // sawAll = 2
        if (staticVariables.sawSomeStatus.equals(status)) return 1;  // sawSome = 1
        if (staticVariables.sawNoneStatus.equals(status)) return 3;  // sawNone = 3
        return 0;  // Unknown/no status = 0
    }
    
    /**
     * Converts iOS attendance code to Android status string
     * iOS standard: 0=Unknown, 1=Some, 2=All, 3=None
     */
    private String codeToAttendance(int code) {
        switch (code) {
            case 2: return staticVariables.sawAllStatus;   // 2 = sawAll
            case 1: return staticVariables.sawSomeStatus;  // 1 = sawSome
            case 3: return staticVariables.sawNoneStatus;  // 3 = sawNone
            default: return staticVariables.sawNoneStatus; // 0 or unknown = sawNone (default)
        }
    }
    
    private void deleteDirectory(File directory) {
        if (directory.exists()) {
            File[] files = directory.listFiles();
            if (files != null) {
                for (File file : files) {
                    if (file.isDirectory()) {
                        deleteDirectory(file);
                    } else {
                        file.delete();
                    }
                }
            }
            directory.delete();
        }
    }
}

/**
 * Data model for a complete set of shared preferences
 */
class SharedPreferenceSet {
    public final String senderUserId;
    public final String senderName;
    public final Date shareDate;
    public final int eventYear;
    public final Map<String, Integer> priorities;
    public final Map<String, Integer> attendance;
    public final String version;
    
    public SharedPreferenceSet(String senderUserId, String senderName, Date shareDate,
                              int eventYear, Map<String, Integer> priorities,
                              Map<String, Integer> attendance, String version) {
        this.senderUserId = senderUserId;
        this.senderName = senderName;
        this.shareDate = shareDate;
        this.eventYear = eventYear;
        this.priorities = priorities;
        this.attendance = attendance;
        this.version = version;
    }
    
    public String getId() {
        return senderUserId + "_" + eventYear;
    }
}


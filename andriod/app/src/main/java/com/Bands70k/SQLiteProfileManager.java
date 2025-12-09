package com.Bands70k;

import android.content.ContentValues;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.util.Log;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;

/**
 * SQLiteProfileManager
 * Manages profile metadata in SQLite database
 * 
 * Stores information about shared preference profiles including:
 * - User ID (immutable identifier from sender)
 * - Display label (can be renamed by receiver)
 * - Color assignment
 * - Import/share dates
 * - Event year
 * - Counts of priorities and attendance records
 * - Read-only status
 */
public class SQLiteProfileManager {
    private static final String TAG = "SQLiteProfileManager";
    private static SQLiteProfileManager instance;
    
    private SQLiteDatabase db;
    
    // Table and column names
    private static final String TABLE_NAME = "shared_profiles";
    private static final String COL_USER_ID = "userId";
    private static final String COL_LABEL = "label";
    private static final String COL_COLOR = "color";
    private static final String COL_IMPORT_DATE = "importDate";
    private static final String COL_SHARE_DATE = "shareDate";
    private static final String COL_EVENT_YEAR = "eventYear";
    private static final String COL_PRIORITY_COUNT = "priorityCount";
    private static final String COL_ATTENDANCE_COUNT = "attendanceCount";
    private static final String COL_IS_READ_ONLY = "isReadOnly";
    
    private SQLiteProfileManager() {
        Log.d(TAG, "🔧 [PROFILE_INIT] SQLiteProfileManager init() called");
        setupDatabase();
        Log.d(TAG, "🔧 [PROFILE_INIT] SQLiteProfileManager init() completed");
    }
    
    public static synchronized SQLiteProfileManager getInstance() {
        if (instance == null) {
            instance = new SQLiteProfileManager();
        }
        return instance;
    }
    
    private void setupDatabase() {
        Log.d(TAG, "🔧 [PROFILE_INIT] setupDatabase() starting...");
        
        try {
            // Use the same database helper as priority/attendance managers
            DBHelper dbHelper = new DBHelper(Bands70k.getAppContext());
            db = dbHelper.getWritableDatabase();
            
            Log.d(TAG, "✅ SQLiteProfileManager: Database connection established");
            
            // CRITICAL: Set busy timeout to handle concurrent writes
            db.execSQL("PRAGMA busy_timeout = 30000");
            Log.d(TAG, "✅ SQLiteProfileManager: Set busy timeout to 30 seconds");
            
            // Create table if not exists
            String createTable = "CREATE TABLE IF NOT EXISTS " + TABLE_NAME + " (" +
                    COL_USER_ID + " TEXT PRIMARY KEY, " +
                    COL_LABEL + " TEXT NOT NULL, " +
                    COL_COLOR + " TEXT NOT NULL, " +
                    COL_IMPORT_DATE + " INTEGER NOT NULL, " +
                    COL_SHARE_DATE + " INTEGER NOT NULL, " +
                    COL_EVENT_YEAR + " INTEGER NOT NULL, " +
                    COL_PRIORITY_COUNT + " INTEGER DEFAULT 0, " +
                    COL_ATTENDANCE_COUNT + " INTEGER DEFAULT 0, " +
                    COL_IS_READ_ONLY + " INTEGER DEFAULT 0)";
            
            db.execSQL(createTable);
            Log.d(TAG, "✅ SQLiteProfileManager: Table created/verified");
            
            // Verify table exists and log count
            android.database.Cursor cursor = db.rawQuery("SELECT COUNT(*) FROM " + TABLE_NAME, null);
            if (cursor.moveToFirst()) {
                int count = cursor.getInt(0);
                Log.d(TAG, "✅ SQLiteProfileManager: Database initialized successfully, " + count + " profiles exist");
            }
            cursor.close();
            
        } catch (Exception e) {
            Log.e(TAG, "❌ SQLiteProfileManager: Failed to initialize database", e);
            e.printStackTrace();
        }
    }
    
    /**
     * Saves or updates a profile
     * @param profile The profile metadata to save
     * @return true if successful
     */
    public boolean saveProfile(ProfileMetadata profile) {
        Log.d(TAG, "💾 [SAVE] saveProfile() called for: " + profile.label + " (" + profile.userId + ")");
        
        try {
            if (db == null) {
                Log.e(TAG, "❌ [SAVE] Database is null! Reinitializing...");
                setupDatabase();
                if (db == null) {
                    Log.e(TAG, "❌ [SAVE] Database still null after reinitialization!");
                    return false;
                }
            }
            ContentValues values = new ContentValues();
            values.put(COL_USER_ID, profile.userId);
            values.put(COL_LABEL, profile.label);
            values.put(COL_COLOR, profile.color);
            values.put(COL_IMPORT_DATE, profile.importDate.getTime());
            values.put(COL_SHARE_DATE, profile.shareDate.getTime());
            values.put(COL_EVENT_YEAR, profile.eventYear);
            values.put(COL_PRIORITY_COUNT, profile.priorityCount);
            values.put(COL_ATTENDANCE_COUNT, profile.attendanceCount);
            values.put(COL_IS_READ_ONLY, profile.isReadOnly ? 1 : 0);
            
            // Check if profile exists using direct query (avoid recursion)
            boolean exists = false;
            Cursor checkCursor = null;
            try {
                checkCursor = db.query(TABLE_NAME, new String[]{COL_USER_ID}, 
                        COL_USER_ID + "=?", new String[]{profile.userId}, null, null, null);
                exists = (checkCursor != null && checkCursor.moveToFirst());
            } finally {
                if (checkCursor != null) {
                    checkCursor.close();
                }
            }
            
            if (exists) {
                // Update existing - CRITICAL: Do NOT update color to preserve original
                ContentValues updateValues = new ContentValues();
                updateValues.put(COL_LABEL, profile.label);
                // colorColumn is intentionally NOT updated to preserve original color
                updateValues.put(COL_IMPORT_DATE, profile.importDate.getTime());
                updateValues.put(COL_SHARE_DATE, profile.shareDate.getTime());
                updateValues.put(COL_EVENT_YEAR, profile.eventYear);
                updateValues.put(COL_PRIORITY_COUNT, profile.priorityCount);
                updateValues.put(COL_ATTENDANCE_COUNT, profile.attendanceCount);
                updateValues.put(COL_IS_READ_ONLY, profile.isReadOnly ? 1 : 0);
                
                int rows = db.update(TABLE_NAME, updateValues, COL_USER_ID + "=?", 
                        new String[]{profile.userId});
                Log.d(TAG, "✅ SQLiteProfileManager: Updated profile: " + profile.label + " (color preserved)");
                return rows > 0;
            } else {
                // Insert new profile
                long result = db.insert(TABLE_NAME, null, values);
                Log.d(TAG, "✅ SQLiteProfileManager: Inserted profile: " + profile.label + " with color: " + profile.color);
                return result != -1;
            }
            
        } catch (Exception e) {
            Log.e(TAG, "❌ SQLiteProfileManager: Failed to save profile", e);
            return false;
        }
    }
    
    /**
     * Gets a profile by userId
     * @param userId The user ID to look up
     * @return ProfileMetadata if found, null otherwise
     * Note: If "Default" is requested and doesn't exist, it will be created automatically
     */
    public ProfileMetadata getProfile(String userId) {
        ProfileMetadata result = null;
        Cursor cursor = null;
        
        try {
            cursor = db.query(TABLE_NAME, null, COL_USER_ID + "=?", 
                    new String[]{userId}, null, null, null);
            
            if (cursor != null && cursor.moveToFirst()) {
                result = profileFromCursor(cursor);
            } else if ("Default".equals(userId)) {
                // Auto-create Default profile if it doesn't exist (first launch)
                Log.d(TAG, "📝 SQLiteProfileManager: Creating Default profile (first launch)");
                ProfileMetadata defaultProfile = new ProfileMetadata(
                        "Default",
                        "Default",
                        "#FFFFFF",
                        new Date(),
                        new Date(),
                        staticVariables.eventYear,
                        0,
                        0,
                        false
                );
                saveProfile(defaultProfile);
                result = defaultProfile;
                Log.d(TAG, "✅ SQLiteProfileManager: Default profile created successfully");
            }
            
        } catch (Exception e) {
            Log.e(TAG, "❌ SQLiteProfileManager: Failed to get/create profile", e);
        } finally {
            if (cursor != null) {
                cursor.close();
            }
        }
        
        return result;
    }
    
    /**
     * Gets all profiles
     * @return List of all ProfileMetadata, with "Default" first
     * Note: If no profiles exist, Default will be created automatically
     */
    public List<ProfileMetadata> getAllProfiles() {
        Log.d(TAG, "📋 [GET_ALL] getAllProfiles() called");
        List<ProfileMetadata> results = new ArrayList<>();
        Cursor cursor = null;
        
        try {
            if (db == null) {
                Log.e(TAG, "❌ [GET_ALL] Database is null! Reinitializing...");
                setupDatabase();
            }
            
            cursor = db.query(TABLE_NAME, null, null, null, null, null, COL_LABEL + " ASC");
            
            Log.d(TAG, "📋 [GET_ALL] Cursor obtained, count: " + (cursor != null ? cursor.getCount() : "null"));
            
            if (cursor != null) {
                while (cursor.moveToNext()) {
                    ProfileMetadata profile = profileFromCursor(cursor);
                    results.add(profile);
                    Log.d(TAG, "📋 [GET_ALL] Found profile: " + profile.label + " (" + profile.userId + ")");
                }
            }
            
            // If no profiles exist at all, create Default (first launch)
            if (results.isEmpty()) {
                Log.d(TAG, "📝 SQLiteProfileManager: No profiles found, creating Default (first launch)");
                ProfileMetadata defaultProfile = new ProfileMetadata(
                        "Default",
                        "Default",
                        "#FFFFFF",
                        new Date(),
                        new Date(),
                        staticVariables.eventYear,
                        0,
                        0,
                        false
                );
                saveProfile(defaultProfile);
                results.add(defaultProfile);
                Log.d(TAG, "✅ SQLiteProfileManager: Default profile created successfully");
            }
            
        } catch (Exception e) {
            Log.e(TAG, "❌ SQLiteProfileManager: Failed to get/create profiles", e);
        } finally {
            if (cursor != null) {
                cursor.close();
            }
        }
        
        // Sort: Default first, then by label
        results.sort((p1, p2) -> {
            if ("Default".equals(p1.userId)) return -1;
            if ("Default".equals(p2.userId)) return 1;
            return p1.label.compareTo(p2.label);
        });
        
        return results;
    }
    
    /**
     * Deletes a profile
     * @param userId The user ID to delete
     * @return true if successful
     */
    public boolean deleteProfile(String userId) {
        // Cannot delete Default
        if ("Default".equals(userId)) {
            Log.e(TAG, "❌ SQLiteProfileManager: Cannot delete Default profile");
            return false;
        }
        
        try {
            int rows = db.delete(TABLE_NAME, COL_USER_ID + "=?", new String[]{userId});
            Log.d(TAG, "✅ SQLiteProfileManager: Deleted profile: " + userId);
            return rows > 0;
        } catch (Exception e) {
            Log.e(TAG, "❌ SQLiteProfileManager: Failed to delete profile", e);
            return false;
        }
    }
    
    /**
     * Updates the label for a profile
     * @param userId The user ID
     * @param newLabel The new label
     * @return true if successful
     */
    public boolean updateLabel(String userId, String newLabel) {
        try {
            ContentValues values = new ContentValues();
            values.put(COL_LABEL, newLabel);
            
            int rows = db.update(TABLE_NAME, values, COL_USER_ID + "=?", new String[]{userId});
            Log.d(TAG, "✅ SQLiteProfileManager: Updated label for " + userId + " to: " + newLabel);
            return rows > 0;
        } catch (Exception e) {
            Log.e(TAG, "❌ SQLiteProfileManager: Failed to update label", e);
            return false;
        }
    }
    
    /**
     * Updates the color for a profile
     * @param userId The user ID
     * @param newColorHex The new color in hex format (e.g., "#FF0000")
     * @return true if successful
     */
    public boolean updateColor(String userId, String newColorHex) {
        try {
            ContentValues values = new ContentValues();
            values.put(COL_COLOR, newColorHex);
            
            int rows = db.update(TABLE_NAME, values, COL_USER_ID + "=?", new String[]{userId});
            Log.d(TAG, "✅ SQLiteProfileManager: Updated color for " + userId + " to: " + newColorHex);
            return rows > 0;
        } catch (Exception e) {
            Log.e(TAG, "❌ SQLiteProfileManager: Failed to update color", e);
            return false;
        }
    }
    
    /**
     * Checks if a profile is read-only (i.e., a shared profile)
     * @param userId The user ID to check
     * @return true if read-only, false otherwise
     */
    public boolean isReadOnly(String userId) {
        ProfileMetadata profile = getProfile(userId);
        if (profile == null) {
            return true;  // If profile doesn't exist, treat as read-only for safety
        }
        return profile.isReadOnly;
    }
    
    /**
     * Helper method to convert cursor to ProfileMetadata
     */
    private ProfileMetadata profileFromCursor(Cursor cursor) {
        return new ProfileMetadata(
                cursor.getString(cursor.getColumnIndexOrThrow(COL_USER_ID)),
                cursor.getString(cursor.getColumnIndexOrThrow(COL_LABEL)),
                cursor.getString(cursor.getColumnIndexOrThrow(COL_COLOR)),
                new Date(cursor.getLong(cursor.getColumnIndexOrThrow(COL_IMPORT_DATE))),
                new Date(cursor.getLong(cursor.getColumnIndexOrThrow(COL_SHARE_DATE))),
                cursor.getInt(cursor.getColumnIndexOrThrow(COL_EVENT_YEAR)),
                cursor.getInt(cursor.getColumnIndexOrThrow(COL_PRIORITY_COUNT)),
                cursor.getInt(cursor.getColumnIndexOrThrow(COL_ATTENDANCE_COUNT)),
                cursor.getInt(cursor.getColumnIndexOrThrow(COL_IS_READ_ONLY)) == 1
        );
    }
}

/**
 * Data model for profile metadata
 */
class ProfileMetadata {
    public final String userId;          // Immutable - sender's device ID or "Default"
    public final String label;           // Mutable - Display name (user can rename)
    public final String color;           // Hex color (e.g., "#FF0000")
    public final Date importDate;
    public final Date shareDate;
    public final int eventYear;
    public final int priorityCount;
    public final int attendanceCount;
    public final boolean isReadOnly;     // true for shared profiles
    
    public ProfileMetadata(String userId, String label, String color, Date importDate,
                          Date shareDate, int eventYear, int priorityCount,
                          int attendanceCount, boolean isReadOnly) {
        this.userId = userId;
        this.label = label;
        this.color = color;
        this.importDate = importDate;
        this.shareDate = shareDate;
        this.eventYear = eventYear;
        this.priorityCount = priorityCount;
        this.attendanceCount = attendanceCount;
        this.isReadOnly = isReadOnly;
    }
}


package com.Bands70k;

import android.content.Context;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;
import android.util.Log;

/**
 * DBHelper
 * SQLite database helper for the 70K Bands app
 * Manages database creation and version upgrades
 */
public class DBHelper extends SQLiteOpenHelper {
    private static final String TAG = "DBHelper";
    
    // Database Info
    private static final String DATABASE_NAME = "70kBands.db";
    private static final int DATABASE_VERSION = 1;
    
    public DBHelper(Context context) {
        super(context, DATABASE_NAME, null, DATABASE_VERSION);
    }
    
    @Override
    public void onCreate(SQLiteDatabase db) {
        Log.d(TAG, "Creating database tables...");
        
        // Create the shared_profiles table
        createSharedProfilesTable(db);
        
        Log.d(TAG, "Database created successfully");
    }
    
    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        Log.d(TAG, "Upgrading database from version " + oldVersion + " to " + newVersion);
        
        // Ensure shared_profiles table exists (for upgrades from version before profiles)
        createSharedProfilesTable(db);
        
        Log.d(TAG, "Database upgrade completed");
    }
    
    /**
     * Creates the shared_profiles table if it doesn't exist
     * IMPORTANT: Column names must match SQLiteProfileManager constants exactly (camelCase)
     */
    private void createSharedProfilesTable(SQLiteDatabase db) {
        // First, check if table exists with old column names (snake_case)
        // If it does, drop it and recreate with correct names (camelCase)
        try {
            android.database.Cursor cursor = db.rawQuery("SELECT user_id FROM shared_profiles LIMIT 1", null);
            cursor.close();
            
            // Old table exists with snake_case columns - drop it
            Log.d(TAG, "⚠️ Found old shared_profiles table with snake_case columns, dropping...");
            db.execSQL("DROP TABLE IF EXISTS shared_profiles");
            Log.d(TAG, "✅ Old table dropped");
        } catch (Exception e) {
            // Table doesn't exist or already has correct columns - this is fine
            Log.d(TAG, "No old table found or table already has correct columns");
        }
        
        // Create table with correct camelCase column names
        String createTable = "CREATE TABLE IF NOT EXISTS shared_profiles (" +
                "userId TEXT PRIMARY KEY, " +
                "label TEXT NOT NULL, " +
                "color TEXT NOT NULL, " +
                "importDate INTEGER NOT NULL, " +
                "shareDate INTEGER NOT NULL, " +
                "eventYear INTEGER NOT NULL, " +
                "priorityCount INTEGER DEFAULT 0, " +
                "attendanceCount INTEGER DEFAULT 0, " +
                "isReadOnly INTEGER DEFAULT 0)";
        
        db.execSQL(createTable);
        Log.d(TAG, "✅ shared_profiles table created/verified with camelCase columns");
    }
}


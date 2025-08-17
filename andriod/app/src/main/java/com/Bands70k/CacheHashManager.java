package com.Bands70k;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

import static com.Bands70k.staticVariables.context;

/**
 * Manages hash-based caching for downloaded files to detect content changes.
 * Only processes files when their content has actually changed.
 */
public class CacheHashManager {
    
    private static final String PREFS_NAME = "CacheHashes";
    private static final String TAG = "CacheHashManager";
    
    private static CacheHashManager instance;
    private SharedPreferences hashPrefs;
    
    private CacheHashManager() {
        if (context != null) {
            hashPrefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        }
    }
    
    /**
     * Gets the singleton instance of CacheHashManager.
     * @return The CacheHashManager instance.
     */
    public static synchronized CacheHashManager getInstance() {
        if (instance == null) {
            instance = new CacheHashManager();
        }
        return instance;
    }
    
    /**
     * Calculates the SHA-256 hash of a file.
     * @param file The file to hash.
     * @return The hex string representation of the hash, or null if error.
     */
    public String calculateFileHash(File file) {
        if (!file.exists() || !file.canRead()) {
            Log.w(TAG, "Cannot read file for hashing: " + file.getPath());
            return null;
        }
        
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            FileInputStream fis = new FileInputStream(file);
            
            byte[] buffer = new byte[8192];
            int bytesRead;
            
            while ((bytesRead = fis.read(buffer)) != -1) {
                digest.update(buffer, 0, bytesRead);
            }
            
            fis.close();
            
            byte[] hashBytes = digest.digest();
            StringBuilder hexString = new StringBuilder();
            
            for (byte b : hashBytes) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) {
                    hexString.append('0');
                }
                hexString.append(hex);
            }
            
            String hash = hexString.toString();
            Log.d(TAG, "Calculated hash for " + file.getName() + ": " + hash.substring(0, 8) + "...");
            return hash;
            
        } catch (NoSuchAlgorithmException | IOException e) {
            Log.e(TAG, "Error calculating file hash for " + file.getPath(), e);
            return null;
        }
    }
    
    /**
     * Gets the cached hash for a specific data type.
     * @param dataType The type of data (e.g., "bandInfo", "scheduleInfo", "combinedImageList").
     * @return The cached hash, or null if not found.
     */
    public String getCachedHash(String dataType) {
        if (hashPrefs == null) {
            Log.w(TAG, "SharedPreferences not initialized, cannot get cached hash");
            return null;
        }
        
        String hash = hashPrefs.getString(dataType, null);
        if (hash != null) {
            Log.d(TAG, "Retrieved cached hash for " + dataType + ": " + hash.substring(0, 8) + "...");
        } else {
            Log.d(TAG, "No cached hash found for " + dataType);
        }
        return hash;
    }
    
    /**
     * Saves the hash for a specific data type.
     * @param dataType The type of data (e.g., "bandInfo", "scheduleInfo", "combinedImageList").
     * @param hash The hash to save.
     */
    public void saveCachedHash(String dataType, String hash) {
        if (hashPrefs == null) {
            Log.w(TAG, "SharedPreferences not initialized, cannot save hash");
            return;
        }
        
        if (hash == null) {
            Log.w(TAG, "Cannot save null hash for " + dataType);
            return;
        }
        
        hashPrefs.edit().putString(dataType, hash).apply();
        Log.d(TAG, "Saved hash for " + dataType + ": " + hash.substring(0, 8) + "...");
    }
    
    /**
     * Compares a new file against the cached hash for a data type.
     * @param file The file to check.
     * @param dataType The type of data.
     * @return True if the file content has changed (or no cached hash exists), false if unchanged.
     */
    public boolean hasFileChanged(File file, String dataType) {
        String newHash = calculateFileHash(file);
        if (newHash == null) {
            Log.w(TAG, "Could not calculate hash for " + file.getPath() + ", assuming changed");
            return true;
        }
        
        String cachedHash = getCachedHash(dataType);
        if (cachedHash == null) {
            Log.d(TAG, "No cached hash for " + dataType + ", treating as changed");
            return true;
        }
        
        boolean changed = !newHash.equals(cachedHash);
        Log.d(TAG, "Hash comparison for " + dataType + ": " + (changed ? "CHANGED" : "UNCHANGED"));
        return changed;
    }
    
    /**
     * Processes a temp file if it has changed, moving it to the final location and updating the hash.
     * @param tempFile The temporary file to check.
     * @param finalFile The final destination file.
     * @param dataType The type of data for hash storage.
     * @return True if the file was processed (changed), false if no change detected.
     */
    public boolean processIfChanged(File tempFile, File finalFile, String dataType) {
        if (!tempFile.exists()) {
            Log.w(TAG, "Temp file does not exist: " + tempFile.getPath());
            return false;
        }
        
        if (hasFileChanged(tempFile, dataType)) {
            // File has changed, move temp to final location
            if (finalFile.exists()) {
                finalFile.delete();
            }
            
            if (tempFile.renameTo(finalFile)) {
                // Update cached hash with the new file
                String newHash = calculateFileHash(finalFile);
                if (newHash != null) {
                    saveCachedHash(dataType, newHash);
                }
                Log.i(TAG, "Processed changed file for " + dataType + ": " + finalFile.getPath());
                return true;
            } else {
                Log.e(TAG, "Failed to move temp file to final location: " + tempFile.getPath() + " -> " + finalFile.getPath());
                return false;
            }
        } else {
            // File unchanged, delete temp file
            tempFile.delete();
            Log.d(TAG, "File unchanged for " + dataType + ", deleted temp file");
            return false;
        }
    }
    
    /**
     * Clears all cached hashes. Useful for testing or forcing refresh.
     */
    public void clearAllHashes() {
        if (hashPrefs != null) {
            hashPrefs.edit().clear().apply();
            Log.i(TAG, "Cleared all cached hashes");
        }
    }
    
    /**
     * Clears the cached hash for a specific data type.
     * @param dataType The type of data to clear.
     */
    public void clearHash(String dataType) {
        if (hashPrefs != null) {
            hashPrefs.edit().remove(dataType).apply();
            Log.i(TAG, "Cleared cached hash for " + dataType);
        }
    }
}

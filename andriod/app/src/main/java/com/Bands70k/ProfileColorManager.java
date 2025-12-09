package com.Bands70k;

import android.graphics.Color;
import android.util.Log;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * ProfileColorManager
 * Manages color assignments for shared preference profiles
 * 
 * Assigns unique colors to each profile for visual distinction in the UI.
 * Colors rotate through a predefined set: Red, Green, Orange, Pink, Teal, Yellow
 * Default profile always gets White.
 */
public class ProfileColorManager {
    private static final String TAG = "ProfileColorManager";
    private static ProfileColorManager instance;
    
    // Vibrant colors that look good against black background
    // Colors rotate in order: White (Default only), Red, Green, Orange, Pink, Teal, Yellow
    // MUST MATCH iOS ProfileColorManager.swift exactly
    private static final int[] AVAILABLE_COLORS = {
            Color.parseColor("#FFFFFF"),  // White (Default only)
            Color.parseColor("#FF3333"),  // Red
            Color.parseColor("#33E633"),  // Green
            Color.parseColor("#FF9A1A"),  // Orange
            Color.parseColor("#FF4DB8"),  // Pink
            Color.parseColor("#1AE6E6"),  // Teal
            Color.parseColor("#FFE61A")   // Yellow
    };
    
    private static final String[] COLOR_NAMES = {
            "White", "Red", "Green", "Orange", "Pink", "Teal", "Yellow"
    };
    
    private ProfileColorManager() {
    }
    
    public static synchronized ProfileColorManager getInstance() {
        if (instance == null) {
            instance = new ProfileColorManager();
        }
        return instance;
    }
    
    /**
     * Get color for a profile (from SQLite or assigns one if not already assigned)
     * @param profileKey The profile key (userId)
     * @return Color as hex string (e.g., "#FF0000")
     */
    public String getColor(String profileKey) {
        // Default profile always gets white
        if ("Default".equals(profileKey)) {
            return "#FFFFFF";
        }
        
        // Try to get color from SQLite profile table
        ProfileMetadata profile = SQLiteProfileManager.getInstance().getProfile(profileKey);
        if (profile != null) {
            return profile.color;
        }
        
        // If no profile found in SQLite, assign a new color
        List<ProfileMetadata> allProfiles = SQLiteProfileManager.getInstance().getAllProfiles();
        Set<Integer> usedColorIndices = new HashSet<>();
        usedColorIndices.add(0);  // 0 is white/default, always reserved
        
        // Collect all currently used color indices from SQLite
        for (ProfileMetadata existingProfile : allProfiles) {
            if ("Default".equals(existingProfile.userId)) continue;
            String existingColorHex = existingProfile.color.toUpperCase();
            
            // Compare with all available colors to find which index is being used
            for (int i = 0; i < AVAILABLE_COLORS.length; i++) {
                String colorHex = getHexString(AVAILABLE_COLORS[i]).toUpperCase();
                if (colorHex.equals(existingColorHex)) {
                    usedColorIndices.add(i);
                    break;
                }
            }
        }
        
        // Find the next available color index (1-6, rotating)
        Log.d(TAG, "🎨 [COLOR] Assigning color for profile '" + profileKey + "'");
        Log.d(TAG, "🎨 [COLOR] Used color indices: " + usedColorIndices.toString());
        
        int newIndex = 1;  // Start at 1 to skip white (index 0)
        while (usedColorIndices.contains(newIndex) && newIndex < AVAILABLE_COLORS.length) {
            newIndex++;
        }
        
        // If all colors are used, cycle back through (1-6)
        if (newIndex >= AVAILABLE_COLORS.length) {
            // Count non-Default profiles and use modulo to cycle through colors
            int nonDefaultCount = 0;
            for (ProfileMetadata p : allProfiles) {
                if (!"Default".equals(p.userId)) {
                    nonDefaultCount++;
                }
            }
            newIndex = 1 + (nonDefaultCount % (AVAILABLE_COLORS.length - 1));
            Log.d(TAG, "🎨 [COLOR] All colors used, cycling to index " + newIndex);
        }
        
        Log.d(TAG, "🎨 [COLOR] Assigned color index " + newIndex + " (" + COLOR_NAMES[newIndex] + ") to profile '" + profileKey + "'");
        return getHexString(AVAILABLE_COLORS[newIndex]);
    }
    
    /**
     * Get Android Color int for a profile
     * @param profileKey The profile key (userId)
     * @return Color as Android Color int
     */
    public int getColorInt(String profileKey) {
        String hexColor = getColor(profileKey);
        return Color.parseColor(hexColor);
    }
    
    /**
     * Convert Android Color int to hex string
     * @param color Android Color int
     * @return Hex string (e.g., "#FF0000")
     */
    public String getHexString(int color) {
        return String.format("#%06X", (0xFFFFFF & color));
    }
    
    /**
     * Update color for a profile
     * @param profileKey The profile key
     * @param hexColor The new color in hex format (e.g., "#FF0000")
     */
    public void updateColor(String profileKey, String hexColor) {
        SQLiteProfileManager.getInstance().updateColor(profileKey, hexColor);
        Log.d(TAG, "🎨 [COLOR] Updated color for '" + profileKey + "' to " + hexColor);
    }
    
    /**
     * Remove color assignment when profile is deleted (no-op since colors are in SQLite)
     * @param profileKey The profile key
     */
    public void removeColor(String profileKey) {
        // Colors are now stored in SQLite, managed by SQLiteProfileManager
        // This function is kept for API compatibility but does nothing
        Log.d(TAG, "🎨 [COLOR] Color for '" + profileKey + "' will be removed by SQLiteProfileManager");
    }
}


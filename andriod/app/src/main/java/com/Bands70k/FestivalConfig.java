package com.Bands70k;

import android.util.Log;

/**
 * Festival-specific configuration class that provides centralized access to
 * festival-dependent settings like URLs, app names, Firebase configs, etc.
 * 
 * This class uses build variants to determine which festival configuration to use.
 * The build variant is determined by the BuildConfig.FESTIVAL_TYPE field.
 * 
 * Created to support multiple festivals (70K and MDF) from a single codebase.
 */
public class FestivalConfig {
    
    // Festival types
    public static final String FESTIVAL_70K = "70K";
    public static final String FESTIVAL_MDF = "MDF";
    
    // Singleton instance
    private static FestivalConfig instance;
    
    // Configuration properties
    public final String festivalName;
    public final String festivalShortName;
    public final String appName;
    public final String packageName;
    
    public final String defaultStorageUrl;
    public final String defaultStorageUrlTest;
    
    public final String firebaseConfigFile;
    
    public final String subscriptionTopic;
    public final String subscriptionTopicTest;
    public final String subscriptionUnofficalTopic;
    
    public final String artistUrlDefault;
    public final String scheduleUrlDefault;
    
    public final String logoResourceName;
    public final int logoResourceId;
    public final int appIconResourceId;
    
    public final String notificationChannelId;
    public final String notificationChannelName;
    public final String notificationChannelDescription;
    
    /**
     * Private constructor that initializes configuration based on build variant
     */
    private FestivalConfig() {
        // Determine festival type from build configuration
        // For now, we'll use a simple approach - this can be enhanced with build variants later
        String festivalType = getFestivalTypeFromBuild();
        
        Log.d("FestivalConfig", "Initializing configuration for festival: " + festivalType);
        
        if (FESTIVAL_MDF.equals(festivalType)) {
            // Maryland Death Fest configuration
            this.festivalName = "Maryland Death Fest";
            this.festivalShortName = "MDF";
            this.appName = "MDF Bands";
            this.packageName = "com.mdfbands";
            
            this.defaultStorageUrl = "https://www.dropbox.com/scl/fi/39jr2f37rhrdk14koj0pz/mdf_productionPointer.txt?rlkey=ij3llf5y1mxwpq2pmwbj03e6t&raw=1";
            this.defaultStorageUrlTest = "https://www.dropbox.com/scl/fi/erdm6rrda8kku1svq8jwk/mdf_productionPointer_test.txt?rlkey=fhjftwb1uakiy83axcpfwrh1e&raw=1";
            
            this.firebaseConfigFile = "google-services-mdf.json"; // Will use placeholder for now
            
            this.subscriptionTopic = "global";
            this.subscriptionTopicTest = "Testing20250824";
            this.subscriptionUnofficalTopic = "unofficalEvents";
            
            // MDF-specific URLs (will be configured via pointer file)
            this.artistUrlDefault = "https://www.dropbox.com/scl/fi/6eg74y11n070airoewsfz/mdf_artistLineup_2026.csv?rlkey=35i20kxtc6pc6v673dnmp1465&raw=1";
            this.scheduleUrlDefault = "https://www.dropbox.com/scl/fi/3u1sr1312az0wd3dcpbfe/mdf_artistsSchedule2026_test.csv?rlkey=t96hj530o46q9fzz83ei7fllj&raw=1";
            
            this.logoResourceName = "mdf_logo";
            this.logoResourceId = R.drawable.mdf_logo; // Will need to create this
            this.appIconResourceId = R.drawable.mdf_bands_icon_old; // Will need to create this
            
            this.notificationChannelId = "MDFBandsCustomSound1";
            this.notificationChannelName = "MDFBandsCustomSound1";
            this.notificationChannelDescription = "Channel for the MDF Bands local show alerts with custom sound";
            
        } else {
            // Default to 70K configuration
            this.festivalName = "70,000 Tons of Metal";
            this.festivalShortName = "70K";
            this.appName = "70K Bands";
            this.packageName = "com.Bands70k";
            
            this.defaultStorageUrl = "https://www.dropbox.com/scl/fi/kd5gzo06yrrafgz81y0ao/productionPointer.txt?rlkey=gt1lpaf11nay0skb6fe5zv17g&raw=1";
            this.defaultStorageUrlTest = "https://www.dropbox.com/s/f3raj8hkfbd81mp/productionPointer2024-Test.txt?raw=1";
            
            this.firebaseConfigFile = "google-services-70k.json";
            
            this.subscriptionTopic = "global";
            this.subscriptionTopicTest = "Testing20250824";
            this.subscriptionUnofficalTopic = "unofficalEvents";
            
            // 70K URLs will be determined by pointer file, these are fallbacks
            this.artistUrlDefault = ""; // Will be set by pointer file
            this.scheduleUrlDefault = ""; // Will be set by pointer file
            
            this.logoResourceName = "bands_70k_icon";
            this.logoResourceId = R.drawable.bands_70k_icon;
            this.appIconResourceId = R.drawable.ic_launcher;
            
            this.notificationChannelId = "70KBandsCustomSound1";
            this.notificationChannelName = "70KBandsCustomSound1";
            this.notificationChannelDescription = "Channel for the 70K Bands local show alerts with custom sound1";
        }
        
        Log.d("FestivalConfig", "Configuration initialized:");
        Log.d("FestivalConfig", "  App Name: " + this.appName);
        Log.d("FestivalConfig", "  Package: " + this.packageName);
        Log.d("FestivalConfig", "  Default Storage URL: " + this.defaultStorageUrl);
        Log.d("FestivalConfig", "  Subscription Topic: " + this.subscriptionTopic);
    }
    
    /**
     * Gets the singleton instance of FestivalConfig
     */
    public static synchronized FestivalConfig getInstance() {
        if (instance == null) {
            instance = new FestivalConfig();
        }
        return instance;
    }
    
    /**
     * Determines the festival type from build configuration.
     * Uses the FESTIVAL_TYPE field from BuildConfig set by product flavors.
     */
    private String getFestivalTypeFromBuild() {
        try {
            // Use BuildConfig.FESTIVAL_TYPE set by product flavors
            return BuildConfig.FESTIVAL_TYPE;
        } catch (Exception e) {
            Log.w("FestivalConfig", "Could not read BuildConfig.FESTIVAL_TYPE, defaulting to 70K", e);
            return FESTIVAL_70K;
        }
    }
    
    /**
     * Gets the current festival type
     */
    public String getFestivalType() {
        if (this.festivalShortName.equals("MDF")) {
            return FESTIVAL_MDF;
        }
        return FESTIVAL_70K;
    }
    
    /**
     * Convenience method to check if this is the 70K festival
     */
    public boolean is70K() {
        return FESTIVAL_70K.equals(getFestivalType());
    }
    
    /**
     * Convenience method to check if this is the MDF festival
     */
    public boolean isMDF() {
        return FESTIVAL_MDF.equals(getFestivalType());
    }
    
    /**
     * Returns the appropriate default description text based on the current festival
     * @param context Android context for accessing string resources
     * @return Localized default description text
     */
    public String getDefaultDescriptionText(android.content.Context context) {
        String festivalType = getFestivalTypeFromBuild();
        
        if (FESTIVAL_MDF.equals(festivalType)) {
            return context.getString(R.string.DefaultDescriptionMDF);
        } else {
            return context.getString(R.string.DefaultDescription70K);
        }
    }
    
    /**
     * Checks if the given text is a default description text (for any festival)
     * @param text The text to check
     * @return true if the text is a default description, false otherwise
     */
    public boolean isDefaultDescriptionText(String text) {
        if (text == null || text.trim().isEmpty()) {
            return false;
        }
        
        // Check against both possible default texts (English versions for simplicity)
        return text.contains("Comment text is not available yet") || 
               text.contains("No notes are available, right now, feel free to add your own");
    }
}

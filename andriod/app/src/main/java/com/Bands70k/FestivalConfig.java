package com.Bands70k;

import android.util.Log;
import java.util.List;
import java.util.ArrayList;
import java.util.Arrays;

/**
 * Venue configuration class that holds venue-specific settings
 */
class Venue {
    public final String name;
    public final String color; // Hex color string
    public final String goingIcon;
    public final String notGoingIcon;
    public final String location; // Deck location (e.g., "Deck 11", "TBD")
    public final boolean showInFilters; // Whether this venue should appear in the filters menu
    
    public Venue(String name, String color, String goingIcon, String notGoingIcon, String location, boolean showInFilters) {
        this.name = name;
        this.color = color;
        this.goingIcon = goingIcon;
        this.notGoingIcon = notGoingIcon;
        this.location = location;
        this.showInFilters = showInFilters;
    }
    
    // Constructor with default showInFilters = true for backward compatibility
    public Venue(String name, String color, String goingIcon, String notGoingIcon, String location) {
        this(name, color, goingIcon, notGoingIcon, location, true);
    }
}

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
    
    public final String shareUrl;
    
    // Venue configuration
    public final List<Venue> venues;
    
    // Event type filter visibility settings (festival-specific)
    public final boolean meetAndGreetsEnabledDefault;
    public final boolean specialEventsEnabledDefault;
    public final boolean unofficalEventsEnabledDefault;
    
    // Comments not available message configuration
    public final int commentsNotAvailableStringResourceId;
    
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
            this.festivalName = "Maryland Deathfest";
            this.festivalShortName = "MDF";
            this.appName = "MDF Bands";
            this.packageName = "com.mdfbands";
            
            this.defaultStorageUrl = "https://www.dropbox.com/scl/fi/39jr2f37rhrdk14koj0pz/mdf_productionPointer.txt?rlkey=ij3llf5y1mxwpq2pmwbj03e6t&raw=1";
            this.defaultStorageUrlTest = "https://www.dropbox.com/scl/fi/erdm6rrda8kku1svq8jwk/mdf_productionPointer_test.txt?rlkey=fhjftwb1uakiy83axcpfwrh1e&raw=1";
            
            this.firebaseConfigFile = "google-services-mdf.json"; // Will use placeholder for now
            
            this.subscriptionTopic = "global";
            this.subscriptionTopicTest = "Testing20251016";
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
            
            this.shareUrl = "https://www.facebook.com/profile.php?id=61580889273388";
            
            // MDF venues: Real venue names with Market Street addresses (all shown in filters)
            this.venues = Arrays.asList(
                new Venue("Rams Head", "EA580C", "icon_theater", "icon_theater_alt", "20 Market", true),      // Orange
                new Venue("Market", "047857", "icon_theater", "icon_theater_alt", "121 Market", true),        // Emerald
                new Venue("Power Plant", "1D4ED8", "icon_theater", "icon_theater_alt", "34 Market", true),    // Blue
                new Venue("Nevermore", "0891B2", "icon_theater", "icon_theater_alt", "20 Market", true),      // Cyan
                new Venue("Soundstage", "991B1B", "icon_theater", "icon_theater_alt", "124 Market", true),    // Dark red
                new Venue("Angels Rock", "A16207", "icon_theater", "icon_theater_alt", "10 Market", true)     // Yellow (dark)
            );
            
            // MDF: Hide all event type filters by default
            this.meetAndGreetsEnabledDefault = false;
            this.specialEventsEnabledDefault = false;
            this.unofficalEventsEnabledDefault = false;
            
            // MDF comments not available message
            this.commentsNotAvailableStringResourceId = R.string.DefaultDescriptionMDF;
            
        } else {
            // Default to 70K configuration
            this.festivalName = "70,000 Tons Of Metal";
            this.festivalShortName = "70K";
            this.appName = "70K Bands";
            this.packageName = "com.Bands70k";
            
            this.defaultStorageUrl = "https://www.dropbox.com/scl/fi/kd5gzo06yrrafgz81y0ao/productionPointer.txt?rlkey=gt1lpaf11nay0skb6fe5zv17g&raw=1";
            this.defaultStorageUrlTest = "https://www.dropbox.com/s/f3raj8hkfbd81mp/productionPointer2024-Test.txt?raw=1";
            
            this.firebaseConfigFile = "google-services-70k.json";
            
            this.subscriptionTopic = "mdf_global";
            this.subscriptionTopicTest = "Testing20251016";
            this.subscriptionUnofficalTopic = "global";
            
            // 70K URLs will be determined by pointer file, these are fallbacks
            this.artistUrlDefault = ""; // Will be set by pointer file
            this.scheduleUrlDefault = ""; // Will be set by pointer file
            
            this.logoResourceName = "bands_70k_icon";
            this.logoResourceId = R.drawable.bands_70k_icon;
            this.appIconResourceId = R.drawable.ic_launcher;
            
            this.notificationChannelId = BuildConfig.FESTIVAL_TYPE + "BandsCustomSound1";
            this.notificationChannelName = BuildConfig.FESTIVAL_TYPE + "BandsCustomSound1";
            this.notificationChannelDescription = "Channel for the " + BuildConfig.FESTIVAL_TYPE + " Bands local show alerts with custom sound1";
            
            this.shareUrl = "http://www.facebook.com/70kBands";
            
            // 70K venues: Main venues shown in filters, others grouped as "Other"
            this.venues = Arrays.asList(
                new Venue("Pool", "1D4ED8", "icon_pool", "icon_pool_alt", "Deck 11", true),                  // Blue
                new Venue("Lounge", "047857", "icon_lounge", "icon_lounge_alt", "Deck 5", true),              // Emerald
                new Venue("Theater", "B45309", "icon_theater", "icon_theater_alt", "Deck 3/4", true),         // Amber
                new Venue("Rink", "C026D3", "ice_rink", "ice_rink_alt", "Deck 3", true),                      // Magenta
                new Venue("Sports Bar", "EA580C", "icon_unknown", "icon_unknown_alt", "Deck 4", false),       // Orange
                new Venue("Viking Crown", "7C3AED", "icon_unknown", "icon_unknown_alt", "Deck 14", false),    // Violet
                new Venue("Boleros Lounge", "92400E", "icon_unknown", "icon_unknown_alt", "Deck 4", false),   // Brown
                new Venue("Solarium", "0891B2", "icon_unknown", "icon_unknown_alt", "Deck 11", false),        // Cyan
                new Venue("Ale And Anchor Pub", "A16207", "icon_unknown", "icon_unknown_alt", "Deck 5", false), // Yellow (dark)
                new Venue("Ale & Anchor Pub", "A16207", "icon_unknown", "icon_unknown_alt", "Deck 5", false),   // Yellow (dark)
                new Venue("Bull And Bear Pub", "991B1B", "icon_unknown", "icon_unknown_alt", "Deck 5", false),  // Dark red
                new Venue("Bull & Bear Pub", "991B1B", "icon_unknown", "icon_unknown_alt", "Deck 5", false)     // Dark red
            );
            
            // 70K: Show all event type filters by default (maintain existing behavior)
            this.meetAndGreetsEnabledDefault = true;
            this.specialEventsEnabledDefault = true;
            this.unofficalEventsEnabledDefault = true;
            
            // 70K comments not available message
            this.commentsNotAvailableStringResourceId = R.string.DefaultDescription70K;
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
     * Returns the localized comments not available message for the current festival
     * @param context Android context for accessing string resources
     * @return Localized comments not available message
     */
    public String getCommentsNotAvailableMessage(android.content.Context context) {
        return context.getString(commentsNotAvailableStringResourceId);
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
    
    // MARK: - Venue Helper Methods
    
    /**
     * Get venue by name
     */
    public Venue getVenue(String name) {
        for (Venue venue : venues) {
            if (venue.name.equalsIgnoreCase(name)) {
                return venue;
            }
        }
        return null;
    }
    
    /**
     * Get venue by partial name match (for backwards compatibility)
     */
    public Venue getVenueByPartialName(String name) {
        for (Venue venue : venues) {
            if (name.toLowerCase().contains(venue.name.toLowerCase()) || 
                venue.name.toLowerCase().contains(name.toLowerCase())) {
                return venue;
            }
        }
        return null;
    }
    
    /**
     * Get venue name string by partial name match (returns null if not found)
     * This is a convenience method to avoid type visibility issues with package-private Venue class
     */
    public String getVenueNameByPartialName(String name) {
        Venue venue = getVenueByPartialName(name);
        return venue != null ? venue.name : null;
    }
    
    /**
     * Get all venue names (including those not shown in filters)
     */
    public List<String> getAllVenueNames() {
        List<String> names = new ArrayList<>();
        for (Venue venue : venues) {
            names.add(venue.name);
        }
        return names;
    }
    
    /**
     * Get venue names that should appear in the filter menu (showInFilters = true)
     * Venues with showInFilters = false are handled by the "Other Venues" filter
     */
    public List<String> getFilterVenueNames() {
        List<String> names = new ArrayList<>();
        for (Venue venue : venues) {
            if (venue.showInFilters) {
                names.add(venue.name);
            }
        }
        return names;
    }
    
    /**
     * Get venue color for a given venue name (returns hex string)
     */
    public String getVenueColor(String venueName) {
        Venue venue = getVenueByPartialName(venueName);
        return venue != null ? venue.color : "A9A9A9"; // Default to gray
    }
    
    /**
     * Get venue going icon for a given venue name
     */
    public String getVenueGoingIcon(String venueName) {
        Venue venue = getVenueByPartialName(venueName);
        return venue != null ? venue.goingIcon : "Unknown-Going-wBox";
    }
    
    /**
     * Get venue not going icon for a given venue name
     */
    public String getVenueNotGoingIcon(String venueName) {
        Venue venue = getVenueByPartialName(venueName);
        return venue != null ? venue.notGoingIcon : "Unknown-NotGoing-wBox";
    }
    
    /**
     * Get venue location for a given venue name
     */
    public String getVenueLocation(String venueName) {
        Venue venue = getVenueByPartialName(venueName);
        return venue != null ? venue.location : "";
    }
}

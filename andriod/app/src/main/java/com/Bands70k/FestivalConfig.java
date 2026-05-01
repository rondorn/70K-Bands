package com.Bands70k;

import android.content.Context;
import android.util.Log;
import java.util.List;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

/**
 * =============================================================================
 * How to configure a new festival (aligns with Swift FestivalConfig)
 * =============================================================================
 *
 * 1. BUILD CONFIG: 70K is the default. Only non-default festivals get a flavor.
 *    In app/build.gradle, productFlavors:
 *    - bands70k: default flavor (FESTIVAL_TYPE "70K") — 70K config lives in the else block.
 *    - mdfbands: FESTIVAL_TYPE "MDF".
 *    - Future: add a new flavor (e.g. xyzbands) with buildConfigField "FESTIVAL_TYPE", '"XYZ"'.
 *
 * 2. DEFAULTS: Shared values live in the Defaults class below. Only add a value there
 *    if it is the same across all (or most) festivals. Any festival branch can override
 *    by assigning a literal instead of Defaults.xxx.
 *
 * 3. FESTIVAL SECTION: Add a new "else if (FESTIVAL_XYZ.equals(festivalType))" block above
 *    the else. Copy the else (70K) block as a template, then set festival-specific
 *    properties and use Defaults.xxx for shared ones.
 *
 * 4. ORDER: Check FESTIVAL_MDF first, then future festivals, then else (70K). The else
 *    is 70K only (single definition).
 *
 * FILE STRUCTURE:
 * - Venue model
 * - FestivalConfig: properties, Defaults (shared values), constructor with one section
 *   per festival (MDF, then 70K default), helpers.
 * =============================================================================
 */

/**
 * Venue configuration class that holds venue-specific settings
 */
class Venue {
    public final String name;
    public final String color; // Hex color string
    public final String goingIcon;
    public final String notGoingIcon;
    public final String location; // Deck location (e.g., "Deck 11", "TBD")

    public Venue(String name, String color, String goingIcon, String notGoingIcon, String location) {
        this.name = name;
        this.color = color;
        this.goingIcon = goingIcon;
        this.notGoingIcon = notGoingIcon;
        this.location = location;
    }
}

/**
 * Festival-specific configuration class that provides centralized access to
 * festival-dependent settings like URLs, app names, Firebase configs, etc.
 * 
 * This class uses product flavors (BuildConfig.FESTIVAL_TYPE) to select configuration.
 * 70K is the default (bands70k flavor); MDF and others override. See file-level comment above.
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
    
    // Configurable graphic elements (same abstraction as Swift; 70K and MDF use same assets, future festivals can override)
    /** Must/Might/Wont priority icons (small, for swipe actions and menus). Drawable resource names. */
    public final String mustSeeIconSmall;
    public final String mightSeeIconSmall;
    public final String wontSeeIconSmall;
    public final String unknownIconSmall;
    /** Must/Might/Wont priority graphics (large, select/deselect). Drawable resource names. */
    public final String mustSeeIcon;
    public final String mustSeeIconAlt;
    public final String mightSeeIcon;
    public final String mightSeeIconAlt;
    public final String wontSeeIcon;
    public final String wontSeeIconAlt;
    public final String unknownIcon;
    public final String unknownIconAlt;
    /** Toolbar icons. Drawable resource names. */
    public final String preferencesIcon;
    public final String shareIcon;
    public final String statsIcon;
    
    // Venue configuration
    public final List<Venue> venues;
    
    // Event type filter visibility settings (festival-specific)
    public final boolean meetAndGreetsEnabledDefault;
    public final boolean specialEventsEnabledDefault;
    public final boolean unofficalEventsEnabledDefault;
    public final Map<String, Map<String, String>> eventTypeDisplayNames;
    public final Map<String, Map<String, String>> eventTypeFilterDisplayNames;
    
    // Comments not available message configuration
    public final int commentsNotAvailableStringResourceId;

    /** Whether the "Plan Your Schedule" / AI schedule builder feature is enabled. */
    public final boolean aiSchedule;

    /** Whether schedule share/scan via QR code is enabled. 70K: on; MDF: off. */
    public final boolean scheduleQRShareEnabled;

    // ---- Defaults: shared across festivals; any festival section can override ----
    /** Values used when a festival does not override. Add here only settings that are
     *  the same for 70K and MDF (and likely future festivals). */
    private static final class Defaults {
        static final String SUBSCRIPTION_TOPIC = "global";
        static final String SUBSCRIPTION_TOPIC_TEST = "Testing2026042802";
        static final String SUBSCRIPTION_UNOFFICAL_TOPIC = "unofficalEvents";
        static final String ARTIST_URL_DEFAULT = "";
        static final String SCHEDULE_URL_DEFAULT = "";
        // Priority / toolbar icons (drawable resource names; same for 70K and MDF)
        static final String MUST_SEE_ICON_SMALL = "icon_going_yes_small";
        static final String MIGHT_SEE_ICON_SMALL = "icon_going_maybe_small";
        static final String WONT_SEE_ICON_SMALL = "icon_going_no_small";
        static final String UNKNOWN_ICON_SMALL = "icon_unknown_small";
        static final String MUST_SEE_ICON = "icon_going_yes";
        static final String MUST_SEE_ICON_ALT = "icon_going_yes_alt";
        static final String MIGHT_SEE_ICON = "icon_going_maybe";
        static final String MIGHT_SEE_ICON_ALT = "icon_going_maybe_alt";
        static final String WONT_SEE_ICON = "icon_going_no";
        static final String WONT_SEE_ICON_ALT = "icon_going_no_alt";
        static final String UNKNOWN_ICON = "icon_unknown";
        static final String UNKNOWN_ICON_ALT = "icon_unknown_alt";
        static final String PREFERENCES_ICON = "icon_gear";
        static final String SHARE_ICON = "icon_share";
        static final String STATS_ICON = "stats_icon";
    }
    
    /**
     * Private constructor that initializes configuration based on build variant
     */
    private FestivalConfig() {
        String festivalType = getFestivalTypeFromBuild();
        Log.d("FestivalConfig", "Initializing configuration for festival: " + festivalType);
        
        if (FESTIVAL_MDF.equals(festivalType)) {
            // ---- FESTIVAL: Maryland Deathfest (MDF) ----
            this.festivalName = "Maryland Deathfest";
            this.festivalShortName = "MDF";
            this.appName = "MDF Bands";
            this.packageName = "com.mdfbands";
            
            this.defaultStorageUrl = "https://www.dropbox.com/scl/fi/39jr2f37rhrdk14koj0pz/mdf_productionPointer.txt?rlkey=ij3llf5y1mxwpq2pmwbj03e6t&raw=1";
            this.defaultStorageUrlTest = "https://www.dropbox.com/scl/fi/erdm6rrda8kku1svq8jwk/mdf_productionPointer_test.txt?rlkey=fhjftwb1uakiy83axcpfwrh1e&raw=1";
            
            this.firebaseConfigFile = "google-services-mdf.json";
            this.subscriptionTopic = Defaults.SUBSCRIPTION_TOPIC;
            this.subscriptionTopicTest = Defaults.SUBSCRIPTION_TOPIC_TEST;
            this.subscriptionUnofficalTopic = Defaults.SUBSCRIPTION_UNOFFICAL_TOPIC;
            this.artistUrlDefault = "https://www.dropbox.com/scl/fi/6eg74y11n070airoewsfz/mdf_artistLineup_2026.csv?rlkey=35i20kxtc6pc6v673dnmp1465&raw=1";
            this.scheduleUrlDefault = "https://www.dropbox.com/scl/fi/3u1sr1312az0wd3dcpbfe/mdf_artistsSchedule2026_test.csv?rlkey=t96hj530o46q9fzz83ei7fllj&raw=1";
            
            this.logoResourceName = "mdf_logo";
            this.logoResourceId = R.drawable.mdf_logo; // Will need to create this
            this.appIconResourceId = R.drawable.mdf_bands_icon_old; // Will need to create this
            
            this.notificationChannelId = "MDFBandsCustomSound1";
            this.notificationChannelName = "MDFBandsCustomSound1";
            this.notificationChannelDescription = "Channel for the MDF Bands local show alerts with custom sound";
            
            this.shareUrl = "https://www.facebook.com/profile.php?id=61580889273388";
            this.mustSeeIconSmall = Defaults.MUST_SEE_ICON_SMALL;
            this.mightSeeIconSmall = Defaults.MIGHT_SEE_ICON_SMALL;
            this.wontSeeIconSmall = Defaults.WONT_SEE_ICON_SMALL;
            this.unknownIconSmall = Defaults.UNKNOWN_ICON_SMALL;
            this.mustSeeIcon = Defaults.MUST_SEE_ICON;
            this.mustSeeIconAlt = Defaults.MUST_SEE_ICON_ALT;
            this.mightSeeIcon = Defaults.MIGHT_SEE_ICON;
            this.mightSeeIconAlt = Defaults.MIGHT_SEE_ICON_ALT;
            this.wontSeeIcon = Defaults.WONT_SEE_ICON;
            this.wontSeeIconAlt = Defaults.WONT_SEE_ICON_ALT;
            this.unknownIcon = Defaults.UNKNOWN_ICON;
            this.unknownIconAlt = Defaults.UNKNOWN_ICON_ALT;
            this.preferencesIcon = Defaults.PREFERENCES_ICON;
            this.shareIcon = Defaults.SHARE_ICON;
            this.statsIcon = Defaults.STATS_ICON;
            // MDF venues: Real venue names with Market Street addresses (order matches iOS FestivalConfig.swift)
            this.venues = Arrays.asList(
                new Venue("Market Place", "047857", "icon_theater", "icon_theater_alt", "121 Market"),        // Emerald
                new Venue("Power Plant", "1D4ED8", "icon_theater", "icon_theater_alt", "34 Market"),    // Blue
                new Venue("Rams Head", "EA580C", "icon_theater", "icon_theater_alt", "20 Market"),      // Orange
                new Venue("Market", "047857", "icon_theater", "icon_theater_alt", "121 Market"),        // Emerald
                new Venue("Nevermore", "0891B2", "icon_theater", "icon_theater_alt", "20 Market"),      // Cyan
                new Venue("Nevermore Hall", "0891B2", "icon_theater", "icon_theater_alt", "20 Market"),      // Cyan
                new Venue("Soundstage", "991B1B", "icon_theater", "icon_theater_alt", "124 Market"),    // Dark red
                new Venue("Angels Rock", "A16207", "icon_theater", "icon_theater_alt", "10 Market"),     // Yellow (dark)
                new Venue("Angels Rock Bar", "A16207", "icon_theater", "icon_theater_alt", "10 Market"),     // Yellow (dark)
                new Venue("Mosaic Nightclub", "5E4FA8", "icon_theater", "icon_theater_alt", "34 Market Pl") // Blue-violet
            );
            
            // MDF: Hide all event type filters by default
            this.meetAndGreetsEnabledDefault = false;
            this.specialEventsEnabledDefault = false;
            this.unofficalEventsEnabledDefault = false;
            this.eventTypeDisplayNames = buildEventTypeDisplayNamesForMdf();
            this.eventTypeFilterDisplayNames = buildEventTypeFilterDisplayNamesForMdf();
            
            // MDF comments not available message
            this.commentsNotAvailableStringResourceId = R.string.DefaultDescriptionMDF;

            this.aiSchedule = true;
            this.scheduleQRShareEnabled = false;

        } else {
            // Future festivals: add "else if (FESTIVAL_XYZ.equals(festivalType))" above and copy this block.
            // ---- FESTIVAL: 70,000 Tons Of Metal (70K) — default ----
            this.festivalName = "70,000 Tons Of Metal";
            this.festivalShortName = "70K";
            this.appName = "70K Bands";
            this.packageName = "com.Bands70k";
            this.defaultStorageUrl = "https://www.dropbox.com/scl/fi/kd5gzo06yrrafgz81y0ao/productionPointer.txt?rlkey=gt1lpaf11nay0skb6fe5zv17g&raw=1";
            this.defaultStorageUrlTest = "https://www.dropbox.com/s/f3raj8hkfbd81mp/productionPointer2024-Test.txt?raw=1";
            this.firebaseConfigFile = "google-services-70k.json";
            this.subscriptionTopic = Defaults.SUBSCRIPTION_TOPIC;
            this.subscriptionTopicTest = Defaults.SUBSCRIPTION_TOPIC_TEST;
            this.subscriptionUnofficalTopic = Defaults.SUBSCRIPTION_UNOFFICAL_TOPIC;
            this.artistUrlDefault = Defaults.ARTIST_URL_DEFAULT;
            this.scheduleUrlDefault = Defaults.SCHEDULE_URL_DEFAULT;
            
            this.logoResourceName = "bands_70k_icon";
            this.logoResourceId = R.drawable.bands_70k_icon;
            this.appIconResourceId = R.drawable.ic_launcher;
            
            this.notificationChannelId = BuildConfig.FESTIVAL_TYPE + "BandsCustomSound1";
            this.notificationChannelName = BuildConfig.FESTIVAL_TYPE + "BandsCustomSound1";
            this.notificationChannelDescription = "Channel for the " + BuildConfig.FESTIVAL_TYPE + " Bands local show alerts with custom sound1";
            
            this.shareUrl = "http://www.facebook.com/70kBands";
            this.mustSeeIconSmall = Defaults.MUST_SEE_ICON_SMALL;
            this.mightSeeIconSmall = Defaults.MIGHT_SEE_ICON_SMALL;
            this.wontSeeIconSmall = Defaults.WONT_SEE_ICON_SMALL;
            this.unknownIconSmall = Defaults.UNKNOWN_ICON_SMALL;
            this.mustSeeIcon = Defaults.MUST_SEE_ICON;
            this.mustSeeIconAlt = Defaults.MUST_SEE_ICON_ALT;
            this.mightSeeIcon = Defaults.MIGHT_SEE_ICON;
            this.mightSeeIconAlt = Defaults.MIGHT_SEE_ICON_ALT;
            this.wontSeeIcon = Defaults.WONT_SEE_ICON;
            this.wontSeeIconAlt = Defaults.WONT_SEE_ICON_ALT;
            this.unknownIcon = Defaults.UNKNOWN_ICON;
            this.unknownIconAlt = Defaults.UNKNOWN_ICON_ALT;
            this.preferencesIcon = Defaults.PREFERENCES_ICON;
            this.shareIcon = Defaults.SHARE_ICON;
            this.statsIcon = Defaults.STATS_ICON;
            // 70K venues. Each Venue(name, color, goingIcon, notGoingIcon, location):
            //   name         - Display name (must match schedule data).
            //   color        - Hex color for this venue (no leading #), e.g. "1D4ED8".
            //   goingIcon    - Drawable resource name for "going" state.
            //   notGoingIcon - Drawable resource name for "not going" state.
            //   location     - Deck/location text, e.g. "Deck 11".
            this.venues = Arrays.asList(
                new Venue("Pool", "1D4ED8", "icon_pool", "icon_pool_alt", "Deck 11"),                  // Blue
                new Venue("Lounge", "047857", "icon_lounge", "icon_lounge_alt", "Deck 5"),              // Emerald
                new Venue("Theater", "B45309", "icon_theater", "icon_theater_alt", "Deck 3/4"),         // Amber
                new Venue("Rink", "C026D3", "ice_rink", "ice_rink_alt", "Deck 3"),                      // Magenta
                new Venue("Schooner Pub", "C2185B", "icon_unknown", "icon_unknown_alt", "Deck 4"),     // Dark pink (readable white text)
                new Venue("Arcade", "334155", "icon_unknown", "icon_unknown_alt", "Deck 12"),          // Slate blue (distinct from Lounge emerald)
                new Venue("Sports Bar", "EA580C", "icon_unknown", "icon_unknown_alt", "Deck 5"),       // Orange
                new Venue("Viking Crown", "7C3AED", "icon_unknown", "icon_unknown_alt", "Deck 14"),   // Violet
                new Venue("Boleros Lounge", "92400E", "icon_unknown", "icon_unknown_alt", "Deck 4"),   // Brown
                new Venue("Solarium", "0891B2", "icon_unknown", "icon_unknown_alt", "Deck 11"),        // Cyan
                new Venue("Ale And Anchor Pub", "A16207", "icon_unknown", "icon_unknown_alt", "Deck 5"), // Yellow (dark)
                new Venue("Ale & Anchor Pub", "A16207", "icon_unknown", "icon_unknown_alt", "Deck 5"),   // Yellow (dark)
                new Venue("Bull And Bear Pub", "991B1B", "icon_unknown", "icon_unknown_alt", "Deck 5"),  // Dark red
                new Venue("Bull & Bear Pub", "991B1B", "icon_unknown", "icon_unknown_alt", "Deck 5")     // Dark red
            );
            
            // 70K: Show all event type filters by default (maintain existing behavior)
            this.meetAndGreetsEnabledDefault = true;
            this.specialEventsEnabledDefault = true;
            this.unofficalEventsEnabledDefault = true;
            this.eventTypeDisplayNames = buildEventTypeDisplayNamesFor70k();
            this.eventTypeFilterDisplayNames = buildEventTypeFilterDisplayNamesFor70k();
            
            // 70K comments not available message
            this.commentsNotAvailableStringResourceId = R.string.DefaultDescription70K;

            this.aiSchedule = true;
            this.scheduleQRShareEnabled = true;
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
    
    // ---- Drawable resolution (same usage as Swift: config holds asset names, resolve to resource ID) ----
    
    /**
     * Resolves a drawable resource name to a resource ID. Use for configurable icons.
     * @param context Application or activity context (for getPackageName() and getResources())
     * @param drawableName Name of the drawable (e.g. "icon_going_yes")
     * @return Resource ID, or 0 if not found
     */
    public static int getDrawableResourceId(Context context, String drawableName) {
        if (context == null || drawableName == null || drawableName.isEmpty()) return 0;
        return context.getResources().getIdentifier(drawableName, "drawable", context.getPackageName());
    }
    
    public int getMustSeeIconSmallResId(Context context) { return getDrawableResourceId(context, mustSeeIconSmall); }
    public int getMightSeeIconSmallResId(Context context) { return getDrawableResourceId(context, mightSeeIconSmall); }
    public int getWontSeeIconSmallResId(Context context) { return getDrawableResourceId(context, wontSeeIconSmall); }
    public int getUnknownIconSmallResId(Context context) { return getDrawableResourceId(context, unknownIconSmall); }
    public int getMustSeeIconResId(Context context) { return getDrawableResourceId(context, mustSeeIcon); }
    public int getMustSeeIconAltResId(Context context) { return getDrawableResourceId(context, mustSeeIconAlt); }
    public int getMightSeeIconResId(Context context) { return getDrawableResourceId(context, mightSeeIcon); }
    public int getMightSeeIconAltResId(Context context) { return getDrawableResourceId(context, mightSeeIconAlt); }
    public int getWontSeeIconResId(Context context) { return getDrawableResourceId(context, wontSeeIcon); }
    public int getWontSeeIconAltResId(Context context) { return getDrawableResourceId(context, wontSeeIconAlt); }
    public int getUnknownIconResId(Context context) { return getDrawableResourceId(context, unknownIcon); }
    public int getUnknownIconAltResId(Context context) { return getDrawableResourceId(context, unknownIconAlt); }
    public int getPreferencesIconResId(Context context) { return getDrawableResourceId(context, preferencesIcon); }
    public int getShareIconResId(Context context) { return getDrawableResourceId(context, shareIcon); }
    public int getStatsIconResId(Context context) { return getDrawableResourceId(context, statsIcon); }

    private static Map<String, Map<String, String>> buildEventTypeDisplayNamesFor70k() {
        Map<String, Map<String, String>> labels = buildDefaultEventTypeDisplayNames();
        setLabelForSupportedLanguages(
                labels,
                EventTypeConfig.UNOFFICIAL_EVENT,
                "Cruiser Organized Event",
                "Von Kreuzfahrern organisiertes Event",
                "Evento Organizado por Cruceristas",
                "Evenement Organise par les Croisieristes",
                "Evento Organizado por Cruzeiristas",
                "Cruiser-organiseret Event",
                "Risteilijoiden jarjestama tapahtuma"
        );
        return labels;
    }

    private static Map<String, Map<String, String>> buildEventTypeFilterDisplayNamesFor70k() {
        Map<String, Map<String, String>> labels = new HashMap<>();
        setLabelForSupportedLanguages(
                labels, EventTypeConfig.SHOW,
                "Show Shows", "Zeige Shows", "Mostrar Shows", "Afficher Shows", "Mostrar Shows", "Vis Shows", "Nayta Show't"
        );
        setLabelForSupportedLanguages(
                labels, EventTypeConfig.SPECIAL_EVENT,
                "Show Special Events", "Zeige Spezialevents", "Mostrar Eventos Especiales", "Afficher Evenements Speciaux", "Mostrar Eventos Especiais", "Vis Sarlige Begivenheder", "Nayta Erikoistapahtumat"
        );
        setLabelForSupportedLanguages(
                labels, EventTypeConfig.MEET_AND_GREET,
                "Show Meet and Greets", "Zeige Meet and Greets", "Mostrar Meet and Greets", "Afficher Meet and Greets", "Mostrar Meet and Greets", "Vis Meet and Greets", "Nayta Meet and Greets"
        );
        setLabelForSupportedLanguages(
                labels, EventTypeConfig.CLINIC,
                "Show Clinics", "Zeige Kliniken", "Mostrar Clinicas", "Afficher Cliniques", "Mostrar Clinicas", "Vis Klinikker", "Nayta Klinikat"
        );
        setLabelForSupportedLanguages(
                labels, EventTypeConfig.UNOFFICIAL_EVENT,
                "Show Cruiser Organized Events", "Zeige von Kreuzfahrern organisierte Events", "Mostrar Eventos Organizados por Cruceristas", "Afficher Evenements Organises par les Croisieristes", "Mostrar Eventos Organizados por Cruzeiristas", "Vis Cruiser-organiserede Events", "Nayta Risteilijoiden jarjestamat tapahtumat"
        );
        return labels;
    }

    private static Map<String, Map<String, String>> buildEventTypeDisplayNamesForMdf() {
        Map<String, Map<String, String>> labels = buildDefaultEventTypeDisplayNames();
        setLabelForSupportedLanguages(
                labels,
                EventTypeConfig.UNOFFICIAL_EVENT,
                "Attendee Organized Event",
                "Von Teilnehmenden organisiertes Event",
                "Evento Organizado por Asistentes",
                "Evenement Organise par les Participants",
                "Evento Organizado por Participantes",
                "Deltagerorganiseret Event",
                "Osallistujien jarjestama tapahtuma"
        );
        setLabelForSupportedLanguages(
                labels,
                EventTypeConfig.MEET_AND_GREET,
                "Signing Session",
                "Autogrammstunde",
                "Sesion de Firmas",
                "Session de Dedicaces",
                "Sessao de Autografos",
                "Autografsession",
                "Nimmarointitilaisuus"
        );
        return labels;
    }

    private static Map<String, Map<String, String>> buildEventTypeFilterDisplayNamesForMdf() {
        Map<String, Map<String, String>> labels = new HashMap<>();
        setLabelForSupportedLanguages(
                labels, EventTypeConfig.SHOW,
                "Show Shows", "Zeige Shows", "Mostrar Shows", "Afficher Shows", "Mostrar Shows", "Vis Shows", "Nayta Show't"
        );
        setLabelForSupportedLanguages(
                labels, EventTypeConfig.SPECIAL_EVENT,
                "Show Special Events", "Zeige Spezialevents", "Mostrar Eventos Especiales", "Afficher Evenements Speciaux", "Mostrar Eventos Especiais", "Vis Sarlige Begivenheder", "Nayta Erikoistapahtumat"
        );
        setLabelForSupportedLanguages(
                labels, EventTypeConfig.MEET_AND_GREET,
                "Show Signing Sessions", "Zeige Autogrammstunden", "Mostrar Sesiones de Firmas", "Afficher Sessions de Dedicaces", "Mostrar Sessoes de Autografos", "Vis Autografsessioner", "Nayta Nimmarointitilaisuudet"
        );
        setLabelForSupportedLanguages(
                labels, EventTypeConfig.CLINIC,
                "Show Clinics", "Zeige Kliniken", "Mostrar Clinicas", "Afficher Cliniques", "Mostrar Clinicas", "Vis Klinikker", "Nayta Klinikat"
        );
        setLabelForSupportedLanguages(
                labels, EventTypeConfig.UNOFFICIAL_EVENT,
                "Show Attendee Organized Events", "Zeige von Teilnehmenden organisierte Events", "Mostrar Eventos Organizados por Asistentes", "Afficher Evenements Organises par les Participants", "Mostrar Eventos Organizados por Participantes", "Vis Deltagerorganiserede Events", "Nayta Osallistujien jarjestamat tapahtumat"
        );
        return labels;
    }

    private static Map<String, Map<String, String>> buildDefaultEventTypeDisplayNames() {
        Map<String, Map<String, String>> labels = new HashMap<>();
        setLabelForSupportedLanguages(
                labels,
                EventTypeConfig.SHOW,
                "Show", "Show", "Show", "Show", "Show", "Show", "Show"
        );
        setLabelForSupportedLanguages(
                labels,
                EventTypeConfig.UNOFFICIAL_EVENT,
                "Unofficial Event",
                "Inoffizielles Event",
                "Evento No Oficial",
                "Evenement Non Officiel",
                "Evento Nao Oficial",
                "Uofficiel Begivenhed",
                "Epavirallinen tapahtuma"
        );
        setLabelForSupportedLanguages(
                labels,
                EventTypeConfig.SPECIAL_EVENT,
                "Special Event",
                "Spezialevent",
                "Evento Especial",
                "Evenement Special",
                "Evento Especial",
                "Sarlig Begivenhed",
                "Erikoistapahtuma"
        );
        setLabelForSupportedLanguages(
                labels,
                EventTypeConfig.MEET_AND_GREET,
                "Meet and Greet",
                "Meet and Greet",
                "Meet and Greet",
                "Meet and Greet",
                "Meet and Greet",
                "Meet and Greet",
                "Meet and Greet"
        );
        setLabelForSupportedLanguages(
                labels,
                EventTypeConfig.CLINIC,
                "Clinic",
                "Klinik",
                "Clinica",
                "Clinique",
                "Clinica",
                "Klinik",
                "Klinikka"
        );
        return labels;
    }

    private static void setLabelForSupportedLanguages(
            Map<String, Map<String, String>> labels,
            String eventType,
            String en,
            String de,
            String es,
            String fr,
            String pt,
            String da,
            String fi
    ) {
        setLabel(labels, eventType, "en", en);
        setLabel(labels, eventType, "de", de);
        setLabel(labels, eventType, "es", es);
        setLabel(labels, eventType, "fr", fr);
        setLabel(labels, eventType, "pt", pt);
        setLabel(labels, eventType, "da", da);
        setLabel(labels, eventType, "fi", fi);
    }

    private static void setLabel(Map<String, Map<String, String>> labels, String eventType, String language, String text) {
        Map<String, String> perLanguage = labels.get(eventType);
        if (perLanguage == null) {
            perLanguage = new HashMap<>();
            labels.put(eventType, perLanguage);
        }
        perLanguage.put(language.toLowerCase(Locale.ROOT), text);
    }

    public String getEventTypeDisplayName(String canonicalEventType, String languageCode) {
        String normalizedType = EventTypeConfig.normalize(canonicalEventType);
        String normalizedLanguage = languageCode == null ? "en" : languageCode.toLowerCase(Locale.ROOT);
        Map<String, String> byLanguage = eventTypeDisplayNames.get(normalizedType);
        if (byLanguage == null) {
            return normalizedType;
        }
        String localized = byLanguage.get(normalizedLanguage);
        if (localized != null && !localized.isEmpty()) {
            return localized;
        }
        localized = byLanguage.get("en");
        return (localized != null && !localized.isEmpty()) ? localized : normalizedType;
    }

    public String getEventTypeFilterDisplayName(String canonicalEventType, String languageCode) {
        String normalizedType = EventTypeConfig.normalize(canonicalEventType);
        String normalizedLanguage = languageCode == null ? "en" : languageCode.toLowerCase(Locale.ROOT);
        Map<String, String> byLanguage = eventTypeFilterDisplayNames.get(normalizedType);
        if (byLanguage == null) return "Show " + getEventTypeDisplayName(normalizedType, normalizedLanguage);
        String localized = byLanguage.get(normalizedLanguage);
        if (localized != null && !localized.isEmpty()) return localized;
        localized = byLanguage.get("en");
        return (localized != null && !localized.isEmpty()) ? localized : "Show " + getEventTypeDisplayName(normalizedType, "en");
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
     * Get venue by exact match or prefix match (venue name + space or '(').
     * Used for icon/color so "Boleros Lounge" does not match "Lounge".
     */
    public Venue getVenueByExactOrPrefixName(String name) {
        if (name == null) return null;
        String nameLower = name.toLowerCase();
        for (Venue venue : venues) {
            String vLower = venue.name.toLowerCase();
            if (nameLower.equals(vLower)) return venue;
            if (nameLower.startsWith(vLower) && name.length() > venue.name.length()) {
                char next = name.charAt(venue.name.length());
                if (next == ' ' || next == '(') return venue;
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
     * Get venue color for a given venue name (returns hex string)
     */
    public String getVenueColor(String venueName) {
        Venue venue = getVenueByExactOrPrefixName(venueName);
        return venue != null ? venue.color : "A9A9A9"; // Default to gray
    }
    
    /**
     * Get venue going icon for a given venue name
     */
    public String getVenueGoingIcon(String venueName) {
        Venue venue = getVenueByExactOrPrefixName(venueName);
        return venue != null ? venue.goingIcon : "Unknown-Going-wBox";
    }
    
    /**
     * Get venue not going icon for a given venue name
     */
    public String getVenueNotGoingIcon(String venueName) {
        Venue venue = getVenueByExactOrPrefixName(venueName);
        return venue != null ? venue.notGoingIcon : "Unknown-NotGoing-wBox";
    }
    
    /**
     * Get venue location for a given venue name
     */
    public String getVenueLocation(String venueName) {
        Venue venue = getVenueByExactOrPrefixName(venueName);
        return venue != null ? venue.location : "";
    }
}

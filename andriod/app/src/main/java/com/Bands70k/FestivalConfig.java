package com.Bands70k;

import android.content.Context;
import android.util.Log;
import java.util.List;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

/**
 * =============================================================================
 * Festival configuration (aligns with Swift FestivalConfig)
 * =============================================================================
 *
 * DATA: Each festival is defined in a self-contained JSON file under
 *       qa-config/festivals/{id}.json (copied into the app bundle at build time).
 *       Copy an existing JSON, modify all fields, add the share extension to
 *       qa-config/festivals/registry.json.
 *
 * ADDING A NEW FESTIVAL:
 *   1. Copy qa-config/festivals/mdf.json → xyz.json and edit every field.
 *   2. Add xyzshare to registry.json shareFileExtensions.
 *   3. Android: productFlavors block in app/build.gradle (see festivalFlavorMap).
 *   4. iOS: target/scheme + SWIFT_ACTIVE_COMPILATION_CONDITIONS if needed.
 *   5. Items below that are NOT in JSON (per platform).
 *
 * OUTSIDE festival JSON (required per app):
 *   - Launcher / notification icons (Android mipmap + drawable; iOS asset catalog)
 *   - Logo drawable / image assets referenced by logo.* in JSON
 *   - Firebase: google-services.json (Android src/&lt;flavor&gt;/) and
 *     GoogleService-Info-*.plist (iOS; copied by copy-firebase-config.sh)
 *   - Android applicationId, signing, versionNameSuffix (build.gradle)
 *   - iOS bundle identifier, provisioning, entitlements (Xcode)
 *   - Localized app display name if overridden (strings.xml / InfoPlist.strings)
 *   - Play Store / App Store listings, fastlane, release scripts
 *
 * BUILD: Gradle packs qa-config/festivals/&lt;id&gt;.json → assets/festival.json per flavor.
 *        iOS copy-festival-config.sh copies the matching JSON into the app bundle.
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
 * Color/icon slot for schedule locations not listed as named venues.
 * Assigned dynamically from CSV row order at schedule import.
 */
class GenericVenueSlot {
    public final String color;
    public final String goingIcon;
    public final String notGoingIcon;

    GenericVenueSlot(String color, String goingIcon, String notGoingIcon) {
        this.color = color;
        this.goingIcon = goingIcon;
        this.notGoingIcon = notGoingIcon;
    }
}

/**
 * Festival-specific configuration class that provides centralized access to
 * festival-dependent settings like URLs, app names, Firebase configs, etc.
 * 
 * Loads festival data from assets/festival.json (see file-level comment above).
 */
public class FestivalConfig {
    
    public static final String FESTIVAL_70K = "70K";
    public static final String FESTIVAL_MDF = "MDF";
    public static final String FESTIVAL_MMF = "MMF";

    private final String[] allShareExtensions;
    
    private static FestivalConfig instance;
    private static Context appContext;
    
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

    /** Profile-share file extension without leading dot (e.g. "mmfshare"). Set per festival in constructor. */
    public final String shareFileExtension;
    
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

    private final String fallbackMiscGenericGoingIcon;
    private final String fallbackMiscGenericNotGoingIcon;
    
    // Venue configuration
    public final List<Venue> venues;
    /** Color/icon slots for schedule locations not listed as named venues (CSV row order). */
    public final List<GenericVenueSlot> genericVenueSlots;
    
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

    private FestivalConfig(FestivalConfigJsonLoader.LoadedFestivalConfig loaded) {
        this.allShareExtensions = loaded.shareExtensions;
        this.festivalName = loaded.festivalName;
        this.festivalShortName = loaded.festivalShortName;
        this.appName = loaded.appName;
        this.packageName = loaded.packageName;
        this.defaultStorageUrl = loaded.defaultStorageUrl;
        this.defaultStorageUrlTest = loaded.defaultStorageUrlTest;
        this.firebaseConfigFile = loaded.firebaseConfigFile;
        this.subscriptionTopic = loaded.subscriptionTopic;
        this.subscriptionTopicTest = loaded.subscriptionTopicTest;
        this.subscriptionUnofficalTopic = loaded.subscriptionUnofficalTopic;
        this.artistUrlDefault = loaded.artistUrlDefault;
        this.scheduleUrlDefault = loaded.scheduleUrlDefault;
        this.logoResourceName = loaded.logoResourceName;
        this.logoResourceId = loaded.logoResourceId;
        this.appIconResourceId = loaded.appIconResourceId;
        this.notificationChannelId = loaded.notificationChannelId;
        this.notificationChannelName = loaded.notificationChannelName;
        this.notificationChannelDescription = loaded.notificationChannelDescription;
        this.shareUrl = loaded.shareUrl;
        this.shareFileExtension = loaded.shareFileExtension;
        this.mustSeeIconSmall = loaded.mustSeeIconSmall;
        this.mightSeeIconSmall = loaded.mightSeeIconSmall;
        this.wontSeeIconSmall = loaded.wontSeeIconSmall;
        this.unknownIconSmall = loaded.unknownIconSmall;
        this.mustSeeIcon = loaded.mustSeeIcon;
        this.mustSeeIconAlt = loaded.mustSeeIconAlt;
        this.mightSeeIcon = loaded.mightSeeIcon;
        this.mightSeeIconAlt = loaded.mightSeeIconAlt;
        this.wontSeeIcon = loaded.wontSeeIcon;
        this.wontSeeIconAlt = loaded.wontSeeIconAlt;
        this.unknownIcon = loaded.unknownIcon;
        this.unknownIconAlt = loaded.unknownIconAlt;
        this.preferencesIcon = loaded.preferencesIcon;
        this.shareIcon = loaded.shareIcon;
        this.statsIcon = loaded.statsIcon;
        this.fallbackMiscGenericGoingIcon = loaded.fallbackMiscGenericGoingIcon;
        this.fallbackMiscGenericNotGoingIcon = loaded.fallbackMiscGenericNotGoingIcon;
        this.venues = loaded.venues;
        this.genericVenueSlots = loaded.genericVenueSlots;
        this.meetAndGreetsEnabledDefault = loaded.meetAndGreetsEnabledDefault;
        this.specialEventsEnabledDefault = loaded.specialEventsEnabledDefault;
        this.unofficalEventsEnabledDefault = loaded.unofficalEventsEnabledDefault;
        this.eventTypeDisplayNames = loaded.eventTypeDisplayNames;
        this.eventTypeFilterDisplayNames = loaded.eventTypeFilterDisplayNames;
        this.commentsNotAvailableStringResourceId = loaded.commentsNotAvailableStringResourceId;
        this.aiSchedule = loaded.aiSchedule;
        this.scheduleQRShareEnabled = loaded.scheduleQRShareEnabled;

        Log.d("FestivalConfig", "Loaded from festival.json for: " + this.festivalShortName);
        Log.d("FestivalConfig", "  App Name: " + this.appName);
        Log.d("FestivalConfig", "  Package: " + this.packageName);
        Log.d("FestivalConfig", "  Default Storage URL: " + this.defaultStorageUrl);
        Log.d("FestivalConfig", "  Subscription Topic: " + this.subscriptionTopic);
        Log.d("FestivalConfig", "  Subscription Topic (test): " + this.subscriptionTopicTest);
    }

    /** Call from {@link Bands70k#onCreate} before any config access. */
    public static synchronized void initialize(Context context) {
        if (context == null) {
            throw new IllegalArgumentException("context required");
        }
        appContext = context.getApplicationContext();
        if (instance == null) {
            instance = new FestivalConfig(FestivalConfigJsonLoader.load(appContext));
        }
    }
    
    /**
     * Gets the singleton instance of FestivalConfig
     */
    public static synchronized FestivalConfig getInstance() {
        if (instance == null) {
            if (appContext != null) {
                instance = new FestivalConfig(FestivalConfigJsonLoader.load(appContext));
            } else if (staticVariables.context != null) {
                initialize(staticVariables.context);
            } else {
                throw new IllegalStateException(
                        "FestivalConfig not initialized; Application.onCreate must call FestivalConfig.initialize()");
            }
        }
        return instance;
    }
    
    /**
     * Gets the current festival type from loaded JSON.
     */
    public String getFestivalType() {
        return festivalShortName;
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
     * Convenience method to check if this is the MMF festival
     */
    public boolean isMMF() {
        return FESTIVAL_MMF.equals(getFestivalType());
    }

    /** Share-file extension with leading dot, e.g. ".mmfshare". */
    public String getShareFileExtensionWithDot() {
        return "." + shareFileExtension;
    }

    /** True when {@code pathExtension} matches this app's share format (no leading dot). */
    public boolean isValidShareFileExtension(String pathExtension) {
        return pathExtension != null && shareFileExtension.equalsIgnoreCase(pathExtension);
    }

    /**
     * True when the URI/filename uses this app's share extension (case-insensitive).
     * Accepts extension from display name, last path segment, or explicit path extension.
     */
    public boolean hasValidShareFileExtension(String filename, String pathExtension, String lastPathSegment) {
        String expectedSuffix = getShareFileExtensionWithDot().toLowerCase();
        if (filename != null && filename.toLowerCase().endsWith(expectedSuffix)) {
            return true;
        }
        if (isValidShareFileExtension(pathExtension)) {
            return true;
        }
        if (lastPathSegment != null) {
            int dot = lastPathSegment.lastIndexOf('.');
            if (dot >= 0 && dot < lastPathSegment.length() - 1) {
                return isValidShareFileExtension(lastPathSegment.substring(dot + 1));
            }
        }
        return false;
    }

    /**
     * True when {@code filename} uses another festival's share extension.
     */
    public boolean isOtherFestivalShareFile(String filename) {
        if (filename == null || filename.isEmpty()) {
            return false;
        }
        String lower = filename.toLowerCase();
        for (String ext : allShareExtensions) {
            if (!ext.equals(shareFileExtension) && lower.endsWith("." + ext.toLowerCase())) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * Returns the appropriate default description text based on the current festival
     * @param context Android context for accessing string resources
     * @return Localized default description text
     */
    public String getDefaultDescriptionText(android.content.Context context) {
        return context.getString(commentsNotAvailableStringResourceId);
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
        if (staticVariables.context != null) {
            return isEmptyGenericNoteText(text, staticVariables.context);
        }
        return text.contains("Comment text is not available yet")
                || text.contains("No notes are available, right now, feel free to add your own")
                || text.contains("Double click to add your own")
                || text.contains("Click to add your own notes");
    }

    /**
     * True when the note is only the empty generic placeholder (e.g. "Click to add notes",
     * "waiting for Aaron's description") and not real downloaded band description content.
     */
    public boolean isEmptyGenericNoteText(String text, android.content.Context context) {
        if (text == null || text.trim().isEmpty()) {
            return false;
        }

        String normalized = normalizeGenericNoteCompareText(text);
        String defaultText = normalizeGenericNoteCompareText(getDefaultDescriptionText(context));
        if (!defaultText.isEmpty() && normalized.equals(defaultText)) {
            return true;
        }

        if (normalized.contains("Comment text is not available yet")) {
            return true;
        }
        if (normalized.contains("No notes are available, right now, feel free to add your own")) {
            return true;
        }
        if (normalized.equalsIgnoreCase("Double click to add your own notes")
                || normalized.equalsIgnoreCase("Click to add your own notes")
                || normalized.contains("Double click to add your own")
                || normalized.contains("Click to add your own notes")) {
            return true;
        }

        return false;
    }

    private String normalizeGenericNoteCompareText(String text) {
        if (text == null) {
            return "";
        }
        return text.replaceAll("<br>", "\n")
                .replaceAll("<[^>]*>", "")
                .replaceAll("&nbsp;", " ")
                .replaceAll("\\s+", " ")
                .replaceAll("[^\\p{ASCII}]", "")
                .trim();
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

    /** Exact match against configured named venues (not generic slots). */
    public boolean hasNamedVenue(String exactName) {
        if (exactName == null) {
            return false;
        }
        for (Venue venue : venues) {
            if (exactName.equals(venue.name)) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * Get venue by name (exact match only)
     */
    public Venue getVenue(String name) {
        if (name == null) {
            return null;
        }
        for (Venue venue : venues) {
            if (name.equals(venue.name)) {
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
     * Get venue color for a given venue name (returns hex string). Exact named match, then CSV generic slot.
     */
    public String getVenueColor(String venueName) {
        Venue venue = getVenue(venueName);
        if (venue != null) {
            return venue.color;
        }
        GenericVenueSlot slot = resolveGenericSlot(venueName);
        if (slot != null) {
            return slot.color;
        }
        return "A9A9A9";
    }
    
    /**
     * Get venue going icon for a given venue name (exact match, then generic slot)
     */
    public String getVenueGoingIcon(String venueName) {
        Venue venue = getVenue(venueName);
        if (venue != null) {
            return venue.goingIcon;
        }
        GenericVenueSlot slot = resolveGenericSlot(venueName);
        if (slot != null) {
            return slot.goingIcon;
        }
        return fallbackMiscGenericGoingIcon;
    }
    
    /**
     * Get venue not going icon for a given venue name (exact match, then generic slot)
     */
    public String getVenueNotGoingIcon(String venueName) {
        Venue venue = getVenue(venueName);
        if (venue != null) {
            return venue.notGoingIcon;
        }
        GenericVenueSlot slot = resolveGenericSlot(venueName);
        if (slot != null) {
            return slot.notGoingIcon;
        }
        return fallbackMiscGenericNotGoingIcon;
    }

    private GenericVenueSlot resolveGenericSlot(String venueName) {
        if (venueName == null || staticVariables.context == null || staticVariables.eventYear == null) {
            return null;
        }
        return VenueColorAssignment.getInstance().resolveSlot(venueName, staticVariables.context, staticVariables.eventYear);
    }
    
    /**
     * Get venue location for a given venue name
     */
    public String getVenueLocation(String venueName) {
        Venue venue = getVenueByExactOrPrefixName(venueName);
        return venue != null ? venue.location : "";
    }
}

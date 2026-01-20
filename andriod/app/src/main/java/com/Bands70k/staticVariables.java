package com.Bands70k;

import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.graphics.Paint;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.Parcelable;
import android.provider.Settings;
import androidx.core.app.ActivityCompat;
import android.util.Log;
import android.view.View;


import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.net.URL;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.Locale;
import java.net.HttpURLConnection;

/**
 * Holds global static variables and utility methods for the 70K Bands app.
 * Created by rdorn on 8/1/15.
 */
public class staticVariables {

    private static File eventYearFile;




    public static Boolean initializedSortButtons = false;
    public final static String mustSeeIcon = "\uD83C\uDF7A";
    public final static String mightSeeIcon = "\u2714"; //2705 //2611 //2714
    public final static String wontSeeIcon = "\uD83D\uDEAB";
    public final static String unknownIcon = "\u2753";
    public final static String oldMightSeeIcon = "\u2705";
    public static String userCountry = "";

    public final static String showTypeIcon = "";
    public final static String specialEventTypeIcon = "🌟";
    public final static String mAndmEventTypeIcon = "\uD83D\uDCF7";
    public final static String listeningEventTypeIcon = "💽";
    public final static String clinicEventTypeIcon = "🎸";
    public final static String unofficalEventTypeIcon = "\uD83D\uDC79";

    public final static String poolVenueIcon = "🏊";
    public final static String theaterVenueIcon = "🎭";
    public final static String loungeVenueIcon = "🎤";
    public static String rinkVenueIcon = "\uD83D\uDD03";

    public static Boolean inUnitTests = false;

    public static Integer eventYear = 0;
    public static Integer eventYearRaw = 0;
    public static Integer staticBandCount = 0;
    public static Integer unfilteredBandCount = 0;

    public static String userID = "";
    //firebase channels - now using FestivalConfig
    public static String getMainAlertChannel() {
        return FestivalConfig.getInstance().subscriptionTopic;
    }
    public static String getTestAlertChannel() {
        return FestivalConfig.getInstance().subscriptionTopicTest;
    }
    public static String getUnofficialAlertChannel() {
        return FestivalConfig.getInstance().subscriptionUnofficalTopic;
    }

    //shows attended
    public static String sawAllIcon = "\uD83C\uDFC3\u200D";
    public static String sawSomeIcon = "\uD83D\uDEB6\u200D";
    public final static String sawNoneIcon = "";
    public static String attendedShowIcon = "\uD83C\uDFC3\u200D";

    public static Map<String, String> showNotesMap = new HashMap<String, String>();
    public static Map<String, String> imageUrlMap = new HashMap<String, String>();
    public static Map<String, String> imageDateMap = new HashMap<String, String>(); // ImageDate for cache invalidation (schedule images only)
    public static Map<String, String> descriptionMapModData = new HashMap<String, String>();
    public static List<String> eventYearArray = new ArrayList<String>();
    
    // Cache for pointer data
    public static Map<String, String> storePointerData = new HashMap<String, String>();
    
    // Flag to track if background URL lookup is in progress (prevents duplicate calls)
    private static volatile boolean backgroundLookupInProgress = false;

    public final static String sawAllColor = "#67C10C";
    public final static String sawSomeColor = "#F0D905";
    public final static String sawNoneColor = "#C0C0C0";
    public final static String sawAllStatus = "sawAll";
    public final static String sawSomeStatus = "sawSome";
    public final static String sawNoneStatus = "sawNone";

    // Notification channel settings - now using FestivalConfig
    public static String getNotificationChannelID() {
        return FestivalConfig.getInstance().notificationChannelId;
    }
    public static CharSequence getNotificationChannelName() {
        return FestivalConfig.getInstance().notificationChannelName;
    }
    public static String getNotificationChannelDescription() {
        return FestivalConfig.getInstance().notificationChannelDescription;
    }
    public final static Uri alarmSound = Uri.parse("android.resource://com.Bands70k/" + R.raw.onmywaytodeath);

    public final static String poolVenueText = "Pool";
    public final static String theaterVenueText = "Theater";
    public final static String loungeVenueText = "Lounge";
    public final static String rinkVenueText = "Rink";

    public final static String show = "Show";
    public final static String meetAndGreet = "Meet and Greet";
    public final static String clinic = "Clinic";
    public final static String specialEvent = "Special Event";
    public final static String listeningEvent = "Listening Party";
    public final static String unofficalEvent = "Cruiser Organized";
    public final static String unofficalEventOld = "Unofficial Event";
    public final static String karaoekeEvent = "Karaoke";

    public final static String poolVenueColor = "#5888db";
    public final static String theaterVenueColor = "#C4AC00";
    public final static String loungeVenueColor = "#5BA50A";
    public final static String rinkVenueColor = "#FF0000";
    public final static String unknownVenueColor = "#A9A9A9";

    public static String eventYearIndex = "Current";
    //schedule file header rows
    public final static String schedBandRow = "Band";
    public final static String schedLocationRow = "Location";
    public final static String schedDateRow = "Date";
    public final static String schedDayRow = "Day";
    public final static String schedStartTimeRow = "Start Time";
    public final static String schedEndTimeRow = "End Time";
    public final static String schedTypeRow = "Type";
    public final static String schedDescriptionURLRow = "Description URL";
    public final static String schedNotesRow = "Notes";
    public final static String schedImageURLRow = "ImageURL";
    public final static String schedImageDateRow = "ImageDate";


    public final static String mustSeeKey = "mustSee";
    public final static String mightSeeKey = "mightSee";
    public final static String wontSeeKey = "wontSee";
    public final static String unknownKey = "unknown";

    // Default URLs - now using FestivalConfig
    public static String getDefaultUrls() {
        return FestivalConfig.getInstance().defaultStorageUrl;
    }
    public static String getDefaultUrlTest() {
        return FestivalConfig.getInstance().defaultStorageUrlTest;
    }

    public final static String logo70kUrl = "http://70000tons.com/wp-content/uploads/2016/11/70k_logo_sm.png";
    public final static String networkTestingUrl = "https://www.dropbox.com";
    public static String artistURL;
    public static String scheduleURL;

    public static String descriptionMap;
    public static Boolean checkingInternet = false;
    public static String internetCheckCache = "false";
    public static Long internetCheckCacheDate = 0L;

    public static String userDataForCompareAndWriteBlock;

    public static String webHelpMessage = "";

    public static Boolean schedulePresent = false;
    public static Boolean notesLoaded = false;

    public static final String blueColor = "#5DADE2";
    public static final String lightGrey = "#797D7F";

    public static Boolean fileDownloaded = false;

    //public static Boolean sortBySchedule = true;
    public static Parcelable listState;

    public static String SENT_TOKEN_TO_SERVER = "sentTokenToServer";
    public static String REGISTRATION_COMPLETE = "registrationComplete";

    public static Integer alarmCount = 1;
    public static Integer showsIwillAttend = 0;

    public static Boolean refreshActivated = false;

    public static Boolean prefsLoaded = false;

    public static Integer listPosition = 0;
    
    // SWIPE MENU FIX: Variables to track scroll position during refreshes
    public static Integer savedScrollPosition = -1;
    public static Integer savedScrollOffset = 0;

    public static preferencesHandler preferences;
    public static showsAttended attendedHandler;

    public static Context context;

    public static Boolean loadingBands = false;
    public static Boolean loadingSchedule = false;
    public static Boolean loadingNotes = false;
    public static Boolean schedulingAlert = false;

    public static Boolean showEventButtons = true;
    public static Boolean showUnofficalEventButtons = true;
    public static Boolean filteringInPlace = false;

    public static Integer graphicMustSeeAlt = R.drawable.icon_going_yes_alt;
    public static Integer graphicMustSee = R.drawable.icon_going_yes;
    public static Integer graphicMustSeeSmall = R.drawable.icon_going_yes_small;
    public static Integer graphicMightSeeAlt = R.drawable.icon_going_maybe_alt;
    public static Integer graphicMightSee = R.drawable.icon_going_maybe;
    public static Integer graphicMightSeeSmall = R.drawable.icon_going_maybe_small;
    public static Integer graphicWontSeeAlt = R.drawable.icon_going_no_alt;
    public static Integer graphicWontSee = R.drawable.icon_going_no;
    public static Integer graphicWontSeeSmall = R.drawable.icon_going_no_small;
    public static Integer graphicUnknownSeeAlt = R.drawable.icon_unknown_alt;
    public static Integer graphicUnknownSee = R.drawable.icon_unknown;
    public static Integer graphicUnknownSeeSmall = R.drawable.icon_unknown_small;
    public static Integer graphicAttended = R.drawable.icon_seen;
    public static Integer graphicAttendedSmall = R.drawable.icon_seen_small;
    public static Integer graphicAttendedAlt = R.drawable.icon_seen_alt;
    public static Integer graphicPartiallyAttended = R.drawable.icon_partially_seen;
    public static Integer graphicAlphaSort = R.drawable.icon_sort_az;
    public static Integer graphicTimeSort = R.drawable.icon_sort_time;
    public static Integer graphicSpecialEvent = R.drawable.icon_all_star_jam;
    public static Integer graphicClinicEvent = R.drawable.icon_clinic;
    public static Integer graphicMeetAndGreetEvent = R.drawable.icon_meet_and_greet;
    public static Integer graphicKaraokeEvent = R.drawable.icon_karaoke;
    public static Integer graphicUnofficalEvent = R.drawable.icon_unspecified_event;
    public static Integer graphicGeneralEvent = R.drawable.icon_ship_event;

    public static View snackBarView;

    public static Integer lastRefreshEpicTime = 0;
    public static Integer  lastRefreshCount = 0;

    public static Integer currentListPosition = 0;
    public static List<String> currentListForDetails = new ArrayList<String>();

    public static Map<String, String> venueLocation = new HashMap<String, String>();

    public static Integer alertTracker = 0;

    public static Set<String> alertMessages = new HashSet<String>();

    public static Boolean isTestingEnv = false;

    public static bandListView adapterCache;

    public static mainListHandler listHandlerCache;

    public static String searchCriteria = "";

    /**
     * Updates the cached mainListHandler instance.
     * @param listHandler The mainListHandler to cache.
     */
    public static synchronized void updatelistHandlerCache(mainListHandler listHandler) {
        Log.d("listHandlerCache", "updating cache");
        staticVariables.listHandlerCache = listHandler;
        Log.d("listHandlerCache", "done updating cache");
    }

    /**
     * Gets the cached mainListHandler instance.
     * @return The cached mainListHandler.
     */
    public static synchronized mainListHandler getlistHandlerCache() {
        return staticVariables.listHandlerCache;
    }

    /**
     * Initializes static variables and preferences if not already loaded.
     */
    public static void staticVariablesInitialize() {

        preferences.loadData();

        if (Build.HARDWARE.contains("golfdish") || preferences.getPointerUrl() == "Testing") {
            isTestingEnv = true;
        }
        /*
        if (staticVariables.filterToogle.get(staticVariables.mustSeeIcon) == null) {
            staticVariables.filterToogle.put(staticVariables.mustSeeIcon, staticVariables.preferences.getShowMust());
        }
        if (staticVariables.filterToogle.get(staticVariables.mightSeeIcon) == null) {
            staticVariables.filterToogle.put(staticVariables.mightSeeIcon, staticVariables.preferences.getShowMight());
        }
        if (staticVariables.filterToogle.get(staticVariables.wontSeeIcon) == null) {
            staticVariables.filterToogle.put(staticVariables.wontSeeIcon, staticVariables.preferences.getShowWont());
        }
        if (staticVariables.filterToogle.get(staticVariables.unknownIcon) == null) {
            staticVariables.filterToogle.put(staticVariables.unknownIcon, staticVariables.preferences.getShowUnknown());
        }
        */
        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.LOLLIPOP) {
            rinkVenueIcon = "\u26F8";
        }

        //use more update to date icons, but only if present
        if (canShowFlagEmoji("\uD83E\uDD18") == true) {
            sawAllIcon = "\uD83E\uDD18";
            sawSomeIcon = "\uD83D\uDC4D";
        }
        if (canShowFlagEmoji("\uD83C\uDF9F") == true) {
            attendedShowIcon = "\uD83C\uDF9F";
        }

        if (artistURL == null) {
            lookupUrls();
        }

        if (context == null) {
            context = Bands70k.getAppContext();
        }

        if (eventYear == 0) {
            getEventYear();
        }
        
        // Final safety check - ensure eventYear is never 0 after initialization
        if (eventYear == 0) {
            Log.w("staticVariablesInitialize", "⚠️ eventYear is still 0 after getEventYear(), attempting resolution...");
            eventYear = ensureEventYearIsSet();
        }

        if (userID.isEmpty() == true) {
            userID = Settings.Secure.getString(staticVariables.context.getContentResolver(),
                    Settings.Secure.ANDROID_ID);
        }

        setupVenueLocations();
        
        // No pre-caching needed - data will be loaded when first requested
        Log.d("staticVariablesInitialize", "Initialization complete - data will be loaded on first request");
    }

    /**
     * Checks if the given emoji can be displayed as a flag.
     * @param emoji The emoji string.
     * @return True if the emoji can be displayed, false otherwise.
     */
    private static boolean canShowFlagEmoji(String emoji) {
        Paint paint = new Paint();

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                return paint.hasGlyph(emoji);
            } else {
                return false;
            }

        } catch (NoSuchMethodError e) {
            // Compare display width of single-codepoint emoji to width of flag emoji to determine
            // whether flag is rendered as single glyph or two adjacent regional indicator symbols.
            float flagWidth = paint.measureText(emoji);
            float standardWidth = paint.measureText("\uD83D\uDC27"); //  U+1F427 Penguin
            return flagWidth < standardWidth * 1.25;
            // This assumes that a valid glyph for the flag emoji must be less than 1.25 times
            // the width of the penguin.
        }
    }

    /**
     * Sets up the venue locations mapping.
     */
    public static void setupVenueLocations() {

        // Clear any existing venue locations
        venueLocation.clear();
        
        // Populate from FestivalConfig
        FestivalConfig config = FestivalConfig.getInstance();
        for (Venue venue : config.venues) {
            venueLocation.put(venue.name, venue.location);
        }
        
        // Legacy compatibility - also add by the old text constants
        venueLocation.put(poolVenueText, config.getVenueLocation("Pool"));
        venueLocation.put(rinkVenueText, config.getVenueLocation("Rink"));
        venueLocation.put(loungeVenueText, config.getVenueLocation("Lounge"));
        venueLocation.put(theaterVenueText, config.getVenueLocation("Theater"));
    }


    /**
     * Gets the icon for a given event type.
     * @param eventType The event type string.
     * @return The icon string for the event type.
     */
    public static String getEventTypeIcon (String eventType){

        String icon;

        if (eventType.equals(staticVariables.show)) {
            icon = showTypeIcon;

        } else if (eventType.equals(staticVariables.meetAndGreet)) {
            icon = mAndmEventTypeIcon;

        } else if (eventType.equals(staticVariables.specialEvent)) {
            icon = specialEventTypeIcon;

        } else if (eventType.equals(staticVariables.clinic)) {
            icon = clinicEventTypeIcon;

        } else if (eventType.equals(staticVariables.listeningEvent)) {
            icon = listeningEventTypeIcon;

        } else if (eventType.equals(staticVariables.unofficalEvent)) {
            icon = unofficalEventTypeIcon;

        } else if (eventType.equals(staticVariables.unofficalEventOld)) {
            icon = unofficalEventTypeIcon;

        } else {
            icon = unknownIcon;
        }

        Log.d ("eventType", "Event Received is " + eventType + " returned " + icon);

        return icon;
    }

    /**
     * Gets the icon for a given venue.
     * @param venue The venue string.
     * @return The icon string for the venue.
     */
    public static String getVenuIcon(String venue) {

        String icon = "";

        if (venue.equals(poolVenueText)){
            icon = poolVenueIcon;

        } else if (venue.equals(theaterVenueText)){
            icon = theaterVenueIcon;

        } else if (venue.equals(rinkVenueText)){
            icon = rinkVenueIcon;

        } else if (venue.equals(loungeVenueText)){
            icon = loungeVenueIcon;
        }

        return icon;
    }

    /**
     * Gets the color for a given venue using FestivalConfig.
     * @param venue The venue string.
     * @return The color string for the venue with # prefix.
     */
    public static String getVenueColor(String venue){
        String color = FestivalConfig.getInstance().getVenueColor(venue);
        // Ensure color has # prefix for Android color parsing
        if (!color.startsWith("#")) {
            color = "#" + color;
        }
        return color;
    }

    /**
     * Gets the icon for a given rank name.
     * @param rankName The rank name string.
     * @return The icon string for the rank.
     */
    public static String getRankIcon (String rankName){

        String icon = "";

        if (rankName.equals(staticVariables.mustSeeKey) || rankName.equals(staticVariables.mustSeeIcon)) {
            icon = mustSeeIcon;

        } else if (rankName.equals(staticVariables.mightSeeKey) || rankName.equals(staticVariables.mightSeeIcon)
                || rankName.equals(staticVariables.oldMightSeeIcon)) {

            icon = mightSeeIcon;

        } else if (rankName.equals(staticVariables.wontSeeKey) || rankName.equals(staticVariables.wontSeeIcon)) {
            icon = wontSeeIcon;

        }

        Log.d("Ranking", "Returning ranking image of " + icon);
        return icon;
    }

    /**
     * Loads the event year from file and updates static variables.
     */
    public static void getEventYear(){

        // CRITICAL FIX: Try to read from cached file first (works offline)
        // Try common year filenames (2024, 2025, 2026, etc.) to find the cached year
        if (eventYearRaw == 0) {
            // Try to read from cached event year files
            for (int year = 2024; year <= 2030; year++) {
                File cachedYearFile = new File(showBands.newRootDir + FileHandler70k.directoryName + year + ".txt");
                if (cachedYearFile.exists()) {
                    try {
                        String cachedYear = FileHandler70k.loadData(cachedYearFile).trim();
                        if (!cachedYear.isEmpty()) {
                            eventYearRaw = Integer.valueOf(cachedYear);
                            eventYear = eventYearRaw;
                            Log.d("EventYear", "Read event year from cached file: " + eventYear);
                            return;
                        }
                    } catch (Exception e) {
                        Log.w("EventYear", "Error reading cached year file " + year + ".txt: " + e.getMessage());
                    }
                }
            }
            
            // If no cached file found, try to extract from showsAttended data
            try {
                showsAttended attendedHandler = new showsAttended();
                Map<String, String> showsAttendedData = attendedHandler.getShowsAttended();
                if (showsAttendedData != null && !showsAttendedData.isEmpty()) {
                    // Extract year from first entry (format: "band:location:startTime:eventType:year")
                    String firstIndex = showsAttendedData.keySet().iterator().next();
                    String[] indexParts = firstIndex.split(":");
                    if (indexParts.length >= 6) {
                        String extractedYear = indexParts[5];
                        eventYearRaw = Integer.valueOf(extractedYear);
                        eventYear = eventYearRaw;
                        Log.d("EventYear", "Extracted event year from showsAttended data: " + eventYear);
                        // Save it for future use
                        eventYearFile = new File(showBands.newRootDir + FileHandler70k.directoryName + eventYear + ".txt");
                        writeEventYearFile();
                        return;
                    }
                }
            } catch (Exception e) {
                Log.w("EventYear", "Error extracting year from showsAttended data: " + e.getMessage());
            }
        }
        
        eventYearFile = new File(showBands.newRootDir + FileHandler70k.directoryName + eventYear + ".txt");

        if (eventYearRaw == 0){
            eventYear = readEventYearFile();
            // After reading, verify it's not still 0
            if (eventYear == 0) {
                eventYear = ensureEventYearIsSet();
            }
        } else {
            eventYear = eventYearRaw;
            writeEventYearFile();
        }
        
        // Final safety check - ensure eventYear is never 0
        if (eventYear == 0) {
            eventYear = ensureEventYearIsSet();
        }

    }
    
    // Guard flag to prevent infinite recursion
    private static boolean isResolvingEventYear = false;
    
    /**
     * Ensures eventYear is set to a valid value using multiple fallback strategies.
     * This method tries multiple sources in order:
     * 1. Cached event year files
     * 2. showsAttended data extraction (direct file read to avoid recursion)
     * 3. Online lookup (if online)
     * 4. Default fallback year
     * 
     * @return A valid event year (never 0)
     */
    public static Integer ensureEventYearIsSet() {
        // Prevent infinite recursion
        if (isResolvingEventYear) {
            Log.w("EventYear", "⚠️ Recursion detected in ensureEventYearIsSet(), using default year");
            Integer defaultYear = 2026;
            eventYearRaw = defaultYear;
            eventYear = defaultYear;
            return eventYear;
        }
        
        isResolvingEventYear = true;
        try {
            Log.w("EventYear", "⚠️ eventYear is 0! Attempting to resolve...");
            
            // Strategy 1: Try to read from cached event year files
            for (int year = 2024; year <= 2030; year++) {
                File cachedYearFile = new File(showBands.newRootDir + FileHandler70k.directoryName + year + ".txt");
                if (cachedYearFile.exists()) {
                    try {
                        String cachedYear = FileHandler70k.loadData(cachedYearFile).trim();
                        if (!cachedYear.isEmpty()) {
                            Integer resolvedYear = Integer.valueOf(cachedYear);
                            eventYearRaw = resolvedYear;
                            eventYear = resolvedYear;
                            eventYearFile = cachedYearFile;
                            Log.d("EventYear", "✅ Resolved from cached file: " + eventYear);
                            return eventYear;
                        }
                    } catch (Exception e) {
                        Log.w("EventYear", "Error reading cached year file " + year + ".txt: " + e.getMessage());
                    }
                }
            }
            
            // Strategy 2: Extract from showsAttended data file directly (avoid creating object to prevent recursion)
            try {
                File showsAttendedFile = FileHandler70k.showsAttendedFile;
                if (showsAttendedFile.exists()) {
                    Map<String, String> showsAttendedData = FileHandler70k.readObject(showsAttendedFile);
                    if (showsAttendedData != null && !showsAttendedData.isEmpty()) {
                        // Try all entries to find a valid year
                        for (String index : showsAttendedData.keySet()) {
                            String[] indexParts = index.split(":");
                            if (indexParts.length >= 6) {
                                try {
                                    String extractedYear = indexParts[5];
                                    Integer resolvedYear = Integer.valueOf(extractedYear);
                                    if (resolvedYear >= 2020 && resolvedYear <= 2030) { // Sanity check
                                        eventYearRaw = resolvedYear;
                                        eventYear = resolvedYear;
                                        eventYearFile = new File(showBands.newRootDir + FileHandler70k.directoryName + eventYear + ".txt");
                                        writeEventYearFile();
                                        Log.d("EventYear", "✅ Resolved from showsAttended data file: " + eventYear);
                                        return eventYear;
                                    }
                                } catch (NumberFormatException e) {
                                    // Skip invalid year format
                                    continue;
                                }
                            }
                        }
                    }
                }
            } catch (Exception e) {
                Log.w("EventYear", "Error extracting year from showsAttended file: " + e.getMessage());
            }
            
            // Strategy 3: Try online lookup if available
            // Never do a synchronous network lookup from the UI thread (would block launch).
            boolean isMainThread = Looper.myLooper() == Looper.getMainLooper();
            if (!isMainThread && OnlineStatus.isOnline()) {
                try {
                    Log.d("EventYear", "Attempting online lookup...");
                    lookupUrls();
                    if (eventYearRaw != 0) {
                        eventYear = eventYearRaw;
                        eventYearFile = new File(showBands.newRootDir + FileHandler70k.directoryName + eventYear + ".txt");
                        writeEventYearFile();
                        Log.d("EventYear", "✅ Resolved from online lookup: " + eventYear);
                        return eventYear;
                    }
                } catch (Exception e) {
                    Log.w("EventYear", "Error during online lookup: " + e.getMessage());
                }
            } else if (isMainThread) {
                Log.d("EventYear", "Skipping online lookup on UI thread; will use default year and refresh later");
            }
            
            // Strategy 4: Default fallback (should be updated annually)
            Integer defaultYear = 2026; // Update this each year
            Log.e("EventYear", "⚠️ All resolution strategies failed! Using default year: " + defaultYear);
            eventYearRaw = defaultYear;
            eventYear = defaultYear;
            eventYearFile = new File(showBands.newRootDir + FileHandler70k.directoryName + eventYear + ".txt");
            writeEventYearFile();
            
            return eventYear;
        } finally {
            isResolvingEventYear = false;
        }
    }

    /**
     * Reads the event year from the event year file.
     * @return The event year as an integer.
     */
    private static Integer readEventYearFile(){

        String eventYearString = "";
        try {

            // Do not force a pointer lookup here. On bad networks that can block app launch if
            // this is reached on the UI thread. If eventYearRaw is already populated (from
            // cached pointer data in-memory or a background refresh), use it; otherwise fall
            // back to a safe default and let the background refresh correct it later.
            if (eventYearRaw != 0) {
                eventYearString = String.valueOf(eventYearRaw);
                Log.d("EventYear", "Event year already resolved (cached/in-memory): " + eventYearString);
            } else {
                // Default year if there are issues (This should be updated every year)
                eventYearString = "2026";
                Log.w("EventYear", "Event year not available yet; using default year: " + eventYearString);
            }

        } catch (Exception error) {
            Log.e("readEventYearFile", "readEventYearFile error " + error.getMessage());
            //default year if there are issues (This should be updated every year
            eventYearString = "2026";
        }

        return Integer.valueOf(eventYearString);
    }

    /**
     * Writes the current event year to the event year file.
     */
    private static void writeEventYearFile(){

        FileHandler70k.saveData(String.valueOf(eventYear), eventYearFile);
        FileHandler70k.saveData(String.valueOf(eventYear), eventYearFile);

    }

    /**
     * Checks if cached pointer data is available and complete.
     * @return True if cache has all required URL data, false otherwise.
     */
    private static boolean hasCachedPointerData() {
        if (storePointerData == null || storePointerData.isEmpty()) {
            return false;
        }
        
        // Check if we have all required keys
        return storePointerData.containsKey("artistUrl") &&
               storePointerData.containsKey("scheduleUrl") &&
               storePointerData.containsKey("descriptionMap") &&
               storePointerData.containsKey("eventYear") &&
               storePointerData.get("artistUrl") != null &&
               !storePointerData.get("artistUrl").isEmpty() &&
               storePointerData.get("scheduleUrl") != null &&
               !storePointerData.get("scheduleUrl").isEmpty();
    }
    
    /**
     * Loads URLs from cache into main variables.
     * Should only be called if hasCachedPointerData() returns true.
     */
    private static void loadFromCache() {
        if (storePointerData == null || storePointerData.isEmpty()) {
            Log.w("lookupUrls", "Attempted to load from empty cache");
            return;
        }
        
        artistURL = storePointerData.get("artistUrl");
        scheduleURL = storePointerData.get("scheduleUrl");
        descriptionMap = storePointerData.get("descriptionMap");
        String eventYearStr = storePointerData.get("eventYear");
        if (eventYearStr != null && !eventYearStr.isEmpty()) {
            try {
                eventYearRaw = Integer.valueOf(eventYearStr);
            } catch (NumberFormatException e) {
                Log.w("lookupUrls", "Invalid eventYear in cache: " + eventYearStr);
            }
        }
        
        Log.d("lookupUrls", "Loaded from cache - artistURL: " + artistURL);
        Log.d("lookupUrls", "Loaded from cache - scheduleURL: " + scheduleURL);
        Log.d("lookupUrls", "Loaded from cache - descriptionMap: " + descriptionMap);
        Log.d("lookupUrls", "Loaded from cache - eventYearRaw: " + eventYearRaw);
    }
    
    /**
     * Fetches pointer data from network and returns parsed URLs.
     * @return Map of URL keys to values, or null if fetch failed.
     */
    private static Map<String, String> fetchFromNetwork() {
        String pointerUrl = getDefaultUrls();
        if (preferences.getPointerUrl().equals("Testing")){
            pointerUrl = getDefaultUrlTest();
        }

        Log.d("lookupUrls", "Fetching from network: " + pointerUrl);

        if (!OnlineStatus.isOnline()) {
            Log.d("lookupUrls", "Not online, cannot fetch from network");
            return null;
        }
        
        try {
            // Normalize eventYearIndex
            if (preferences.getEventYearToLoad() == null || preferences.getEventYearToLoad().isEmpty() == false){
                eventYearIndex = preferences.getEventYearToLoad();
            }

            if (eventYearIndex.equals("true") || eventYearIndex.equals("false")){
                eventYearIndex = "Current";
                preferences.setEventYearToLoad("Current");
            }
            
            Log.d("70K_NOTE_DEBUG", "User selected eventYearIndex: " + eventYearIndex);
            Log.d("70K_NOTE_DEBUG", "Available years in pointer file: " + eventYearArray.toString());

            String data = "";
            String line;

            URL url = new URL(pointerUrl);
            
            // Handle HTTP redirects properly for Dropbox URLs
            HttpURLConnection connection = (HttpURLConnection) url.openConnection();
            connection.setInstanceFollowRedirects(true);
            HttpConnectionHelper.applyTimeouts(connection);
            
            BufferedReader in = new BufferedReader(new InputStreamReader(connection.getInputStream()));
            while ((line = in.readLine()) != null) {
                data += line + "\n";
            }
            in.close();

            Log.d("defaultUrls", data);

            String[] records = data.split("\\n");
            Log.d("defaultUrls", "eventYearIndex is " + eventYearIndex);
            Map<String, String> downloadUrls = readPointData(records, eventYearIndex);
            Log.d("defaultUrls", downloadUrls.toString());
            
            return downloadUrls;
        } catch (Exception error) {
            Log.e("lookupUrls", "Network fetch error: " + error.getMessage(), error);
            Log.d("pointerUrl Error", String.valueOf(error.getCause()));
            Log.d("pointerUrl Error", String.valueOf(error.getStackTrace()));
            return null;
        }
    }
    
    /**
     * Compares new URLs with cached URLs to detect changes.
     * @param newUrls The newly fetched URLs.
     * @return True if any URL has changed, false if all are the same.
     */
    private static boolean compareUrls(Map<String, String> newUrls) {
        if (newUrls == null || newUrls.isEmpty()) {
            return false;
        }
        
        // Compare each key
        String[] keysToCompare = {"artistUrl", "scheduleUrl", "descriptionMap", "eventYear"};
        for (String key : keysToCompare) {
            String newValue = newUrls.get(key);
            String cachedValue = storePointerData != null ? storePointerData.get(key) : null;
            
            // Handle null/empty cases
            if (newValue == null) newValue = "";
            if (cachedValue == null) cachedValue = "";
            
            if (!newValue.equals(cachedValue)) {
                Log.d("lookupUrls", "Change detected for " + key + ": '" + cachedValue + "' -> '" + newValue + "'");
                return true;
            }
        }
        
        Log.d("lookupUrls", "No changes detected in pointer data");
        return false;
    }
    
    /**
     * Updates cache with new URLs and sets main variables.
     * @param downloadUrls The new URLs to cache.
     */
    private static void updateCacheAndVariables(Map<String, String> downloadUrls) {
        if (downloadUrls == null || downloadUrls.isEmpty()) {
            return;
        }
        
        // Cache all the data for immediate access
        storePointerData.clear(); // Clear old cache
        for (Map.Entry<String, String> entry : downloadUrls.entrySet()) {
            storePointerData.put(entry.getKey(), entry.getValue());
            Log.d("lookupUrls", "Cached: " + entry.getKey() + " = " + entry.getValue());
        }
        
        // Set the main variables
        artistURL = downloadUrls.get("artistUrl");
        scheduleURL = downloadUrls.get("scheduleUrl");
        descriptionMap = downloadUrls.get("descriptionMap");
        String eventYearStr = downloadUrls.get("eventYear");
        if (eventYearStr != null && !eventYearStr.isEmpty()) {
            try {
                eventYearRaw = Integer.valueOf(eventYearStr);
            } catch (NumberFormatException e) {
                Log.w("lookupUrls", "Invalid eventYear: " + eventYearStr);
            }
        }

        Log.d("pointerUrl", "artistURL = " + artistURL);
        Log.d("pointerUrl", "scheduleURL = " + scheduleURL);
        Log.d("pointerUrl", "descriptionMap = " + descriptionMap);
        Log.d("pointerUrl", "eventYearRaw = " + eventYearRaw);
        
        // Additional 70K_NOTE_DEBUG logging
        Log.d("70K_NOTE_DEBUG", "Final URLs set - artistURL: " + artistURL);
        Log.d("70K_NOTE_DEBUG", "Final URLs set - descriptionMap: " + descriptionMap);
        Log.d("70K_NOTE_DEBUG", "Final URLs set - eventYearRaw: " + eventYearRaw);
    }
    
    /**
     * Safely triggers UI refresh from background thread.
     * Uses ForegroundDownloadManager pattern to get current activity.
     */
    private static void triggerUIRefresh() {
        // Use Handler to post to UI thread
        Handler uiHandler = new Handler(Looper.getMainLooper());
        uiHandler.post(new Runnable() {
            @Override
            public void run() {
                try {
                    Activity currentActivity = ForegroundDownloadManager.getCurrentActivity();
                    if (currentActivity != null && currentActivity instanceof showBands) {
                        showBands showBandsActivity = (showBands) currentActivity;
                        Log.d("lookupUrls", "Triggering UI refresh due to pointer data change");
                        showBandsActivity.refreshNewData();
                    } else {
                        Log.d("lookupUrls", "Cannot trigger refresh - no valid showBands activity");
                    }
                } catch (Exception e) {
                    Log.e("lookupUrls", "Error triggering UI refresh: " + e.getMessage(), e);
                }
            }
        });
    }
    
    /**
     * Background version of lookupUrls that updates cache and triggers refresh if data changed.
     * This should only be called from a background thread.
     */
    private static void lookupUrlsInBackground() {
        // Prevent duplicate background lookups
        if (backgroundLookupInProgress) {
            Log.d("lookupUrls", "Background lookup already in progress, skipping");
            return;
        }
        
        backgroundLookupInProgress = true;
        try {
            Log.d("lookupUrls", "Starting background URL lookup");
            
            // Fetch new data from network
            Map<String, String> newUrls = fetchFromNetwork();
            
            if (newUrls == null || newUrls.isEmpty()) {
                Log.w("lookupUrls", "Background fetch returned no data");
                return;
            }
            
            // Compare with cached data
            boolean dataChanged = compareUrls(newUrls);
            
            if (dataChanged) {
                Log.d("lookupUrls", "Pointer data changed - updating cache and triggering refresh");
                // Update cache and variables
                updateCacheAndVariables(newUrls);
                // Trigger UI refresh
                triggerUIRefresh();
            } else {
                Log.d("lookupUrls", "Pointer data unchanged - no refresh needed");
                // Still update cache to ensure it's fresh (even if values are same)
                updateCacheAndVariables(newUrls);
            }
        } finally {
            backgroundLookupInProgress = false;
        }
    }

    /**
     * Looks up and sets URLs for artist and schedule data.
     * This method checks cache first, uses cached data if available, and triggers
     * background update to ensure cache stays fresh. If no cache exists, fetches
     * from network synchronously (should only be called from background threads).
     * 
     * CRITICAL: This method should NOT be called from the main/UI thread if it
     * needs to make a network call. Use lookupUrlsInBackground() via ThreadManager
     * for background updates.
     */
    public static void lookupUrls(){
        // CRITICAL: Check if we're on main thread and cache is available
        boolean isMainThread = Looper.myLooper() == Looper.getMainLooper();
        
        // Check cache first
        if (hasCachedPointerData()) {
            Log.d("lookupUrls", "Using cached pointer data");
            loadFromCache();
            
            // Trigger background update to refresh cache (never block UI thread on online checks).
            // lookupUrlsInBackground() will perform the network attempt and handle offline gracefully.
            if (!backgroundLookupInProgress) {
                Log.d("lookupUrls", "Triggering background update to refresh cache");
                ThreadManager.getInstance().executeNetwork(() -> {
                    lookupUrlsInBackground();
                });
            }
            return; // Return immediately with cached data
        }
        
        // No cache available - must fetch from network
        // WARNING: This will block if called on main thread
        if (isMainThread) {
            Log.w("lookupUrls", "⚠️ WARNING: lookupUrls() called on main thread with no cache - this will block!");
            Log.w("lookupUrls", "⚠️ Consider using ThreadManager to call this from background thread");
            // Hard safety: never perform network I/O on UI thread. Schedule a background refresh and return.
            if (!backgroundLookupInProgress) {
                Log.d("lookupUrls", "Scheduling background URL lookup (no-cache UI-thread call)");
                ThreadManager.getInstance().executeNetwork(() -> {
                    lookupUrlsInBackground();
                });
            }
            return;
        }
        
        Log.d("lookupUrls", "No cache available - fetching from network");
        Map<String, String> downloadUrls = fetchFromNetwork();
        
        if (downloadUrls != null && !downloadUrls.isEmpty()) {
            updateCacheAndVariables(downloadUrls);
        } else {
            Log.w("lookupUrls", "Failed to fetch URLs from network and no cache available");
        }
    }

    /**
     * Reads pointer data from records for a given event year index.
     * @param records The pointer data records.
     * @param eventYearIndex The event year index.
     * @return A map of pointer data.
     */
    private static Map<String, String> readPointData(String[] records, String eventYearIndex){

        Map<String, String> downloadUrls = new HashMap<String, String>();
        for (String record : records) {
            String[] recordData = record.split("::");
            Log.d("defaultUrls", "record = " + record);
            if (recordData.length >= 3) {
                String recordIndex = recordData[0];
                String keyName = recordData[1];
                String vaueData = recordData[2];

                if (recordIndex.equals("Default") == false && recordIndex.equals("lastYear") == false){
                    if (eventYearArray.contains(recordIndex) == false){
                        eventYearArray.add(recordIndex);
                    }
                }
                Log.d("defaultUrls", "adding data  = " + recordIndex + "-" + eventYearIndex + "-" + keyName + "=" + vaueData);

                if (eventYearIndex.equals(recordIndex)) {
                    Log.d("defaultUrls", "REALLY adding data  = " + keyName + "=" + vaueData);
                    downloadUrls.put(keyName, vaueData);
                }
            }
        }
        return downloadUrls;
    }

    /**
     * Retrieves pointer URL data for a given key, using cache if available, otherwise fetching and parsing remote data.
     * Handles special logic for the "reportUrl" key with language-specific URL logic.
     * @param keyValue The key for which to retrieve pointer data.
     * @return The pointer data as a string, or an empty string if not found.
     */
    public static String getPointerUrlData(String keyValue) {
        String dataString = "";
        
        // Apply language-specific key logic for reportUrl
        String actualKeyValue = keyValue;
        if (keyValue.equals("reportUrl")) {
            actualKeyValue = getLanguageSpecificKey(keyValue);
            Log.d("getPointerUrlData", "Using language-specific key: " + actualKeyValue + " for original key: " + keyValue);
        }
        
        // Check if we're in test environment
        if (preferences.getPointerUrl().equals("Testing")) {
            isTestingEnv = true;
        }
        
        // Get pointer index (equivalent to getScheduleUrl() in iOS)
        String pointerIndex = preferences.getEventYearToLoad();
        if (pointerIndex == null || pointerIndex.isEmpty() || pointerIndex.equals("true") || pointerIndex.equals("false")) {
            pointerIndex = "Current";
        }
        
        Log.d("getPointerUrlData", "Getting pointer data for key: " + actualKeyValue + " with index: " + pointerIndex);
        
        // Try to get data from cache first - this should be the primary path
        if (storePointerData != null && storePointerData.get(actualKeyValue) != null && !storePointerData.get(actualKeyValue).isEmpty()) {
            dataString = storePointerData.get(actualKeyValue);
            Log.d("getPointerUrlData", "Got cached URL data: " + dataString + " for " + actualKeyValue);
            return dataString; // Return immediately if cached
        }
        
        // Only make network call if cache is completely empty (first launch scenario)
        if (storePointerData == null || storePointerData.isEmpty()) {
            Log.d("getPointerUrlData", "Cache is empty, making network call for " + actualKeyValue);
            if (OnlineStatus.isOnline()) {
                try {
                    String pointerUrl = getDefaultUrls();
                    if (preferences.getPointerUrl().equals("Testing")) {
                        pointerUrl = getDefaultUrlTest();
                    }
                    
                    Log.d("getPointerUrlData", "Fetching pointer data from: " + pointerUrl);
                    
                    URL url = new URL(pointerUrl);
                    HttpURLConnection connection = (HttpURLConnection) url.openConnection();
                    connection.setRequestMethod("GET");
                    HttpConnectionHelper.applyTimeouts(connection);
                    connection.setRequestProperty("User-Agent", "Mozilla/5.0 (Android; Mobile; rv:40.0)");
                    
                    try {
                        int responseCode = connection.getResponseCode();
                        Log.d("getPointerUrlData", "HTTP Response Code: " + responseCode);
                        
                        if (responseCode == HttpURLConnection.HTTP_OK) {
                            BufferedReader in = new BufferedReader(new InputStreamReader(connection.getInputStream()), 8192);
                            StringBuilder data = new StringBuilder(8192);
                            char[] buffer = new char[8192];
                            int bytesRead;
                            
                            while ((bytesRead = in.read(buffer)) != -1) {
                                data.append(buffer, 0, bytesRead);
                            }
                            in.close();
                            
                            String[] records = data.toString().split("\\n");
                            Map<String, String> downloadUrls = readPointData(records, pointerIndex);
                            
                            // Cache all the data for future use
                            for (Map.Entry<String, String> entry : downloadUrls.entrySet()) {
                                storePointerData.put(entry.getKey(), entry.getValue());
                            }
                            
                            dataString = downloadUrls.get(actualKeyValue);
                            if (dataString == null) {
                                dataString = "";
                            }
                            
                            Log.d("getPointerUrlData", "Retrieved and cached data: " + dataString + " for key: " + actualKeyValue);
                            
                        } else {
                            Log.e("getPointerUrlData", "HTTP error code: " + responseCode);
                            dataString = "";
                        }
                    } finally {
                        connection.disconnect();
                    }
                    
                } catch (Exception error) {
                    Log.e("getPointerUrlData", "Error fetching pointer data: " + error.getMessage());
                    dataString = "";
                }
            } else {
                Log.d("getPointerUrlData", "No internet available, cache is empty for " + actualKeyValue);
                dataString = "";
            }
        } else {
            Log.d("getPointerUrlData", "Cache exists but key not found: " + actualKeyValue);
            dataString = "";
        }
        
        Log.d("getPointerUrlData", "Final value for " + actualKeyValue + ": " + dataString);
        return dataString;
    }

    /**
     * Gets the cached pointer data for a key without making network calls.
     * @param keyValue The key to retrieve.
     * @return The cached data or empty string if not cached.
     */
    public static String getCachedPointerData(String keyValue) {
        if (storePointerData != null && storePointerData.get(keyValue) != null) {
            return storePointerData.get(keyValue);
        }
        return "";
    }

    /**
     * Gets the language-specific key for reportUrl based on user's language preference.
     * @param keyValue The original key value (should be "reportUrl").
     * @return The language-specific key (e.g., "reportUrl-en", "reportUrl-es").
     */
    private static String getLanguageSpecificKey(String keyValue) {
        // Get the user's preferred language
        String userLanguage = Locale.getDefault().getLanguage();
        
        // Define supported languages
        String[] supportedLanguages = {"da", "de", "en", "es", "fi", "fr", "pt"};
        
        // Determine the language to use (default to "en" if not supported)
        String languageToUse = "en"; // default
        for (String lang : supportedLanguages) {
            if (lang.equals(userLanguage)) {
                languageToUse = userLanguage;
                break;
            }
        }
        
        // Create the language-specific key
        String languageSpecificKey = keyValue + "-" + languageToUse;
        
        Log.d("getLanguageSpecificKey", "Original key: " + keyValue);
        Log.d("getLanguageSpecificKey", "User language: " + userLanguage);
        Log.d("getLanguageSpecificKey", "Language to use: " + languageToUse);
        Log.d("getLanguageSpecificKey", "Language-specific key: " + languageSpecificKey);
        
        return languageSpecificKey;
    }
}

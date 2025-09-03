package com.Bands70k;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.graphics.Paint;
import android.net.Uri;
import android.os.Build;
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

    // Storage Permissions
    public static final int REQUEST_EXTERNAL_STORAGE = 1;
    public static String[] PERMISSIONS_STORAGE = {
            Manifest.permission.READ_EXTERNAL_STORAGE,
            Manifest.permission.WRITE_EXTERNAL_STORAGE
    };



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
    public static Map<String, String> descriptionMapModData = new HashMap<String, String>();
    public static List<String> eventYearArray = new ArrayList<String>();
    
    // Cache for pointer data
    public static Map<String, String> storePointerData = new HashMap<String, String>();

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
    public static Boolean disableListAnimations = false;

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

        venueLocation.put(poolVenueText, "Deck 11");
        venueLocation.put(rinkVenueText, "Deck 3");
        venueLocation.put(loungeVenueText, "Deck 5");
        venueLocation.put(theaterVenueText, "Deck 3/4");
        venueLocation.put("Sports Bar", "Deck 4");
        venueLocation.put("Viking Crown", "Deck 14");
        venueLocation.put("Boleros Lounge", "Deck 4");
    }

    /**
     * Verifies and requests storage permissions for the given activity.
     * @param activity The activity to request permissions for.
     */
    public static void verifyStoragePermissions(Activity activity){

        // Check if we have write permission
        int permission = ActivityCompat.checkSelfPermission(activity, Manifest.permission.WRITE_EXTERNAL_STORAGE);

        if(permission != PackageManager.PERMISSION_GRANTED)

        {
            // We don't have permission so prompt the user
            ActivityCompat.requestPermissions(
                    activity,
                    PERMISSIONS_STORAGE,
                    REQUEST_EXTERNAL_STORAGE
            );
        }

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

        eventYearFile = new File(showBands.newRootDir + FileHandler70k.directoryName + eventYear + ".txt");

        if (eventYearRaw == 0){
            eventYear = readEventYearFile();

        } else {
            eventYear = eventYearRaw;

            writeEventYearFile();
        }

    }

    /**
     * Reads the event year from the event year file.
     * @return The event year as an integer.
     */
    private static Integer readEventYearFile(){

        String eventYearString = "";
        try {

            lookupUrls();
            eventYearString = String.valueOf(eventYearRaw);
            Log.d("EventYear", "Event year read as  " + eventYearString);

        } catch (Exception error) {
            Log.e("readEventYearFile", "readEventYearFile error " + error.getMessage());
            //default year if there are issues (This should be updated every year
            eventYearString = "2024";
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
     * Looks up and sets URLs for artist and schedule data.
     * This method should only be called at launch or pull-to-refresh.
     * For all other operations, use cached data.
     */
    public static void lookupUrls(){

        String pointerUrl = getDefaultUrls();
        if (preferences.getPointerUrl().equals("Testing")){
            pointerUrl = getDefaultUrlTest();
        }

        Log.d("pointerUrl", "pointerUrl equals " + pointerUrl + " - OnlineStatus is " + OnlineStatus.isOnline());

        if (OnlineStatus.isOnline() == true) {
            try {

                if (preferences.getEventYearToLoad() == null || preferences.getEventYearToLoad().isEmpty() == false){
                    eventYearIndex = preferences.getEventYearToLoad();
                }

                if (eventYearIndex.equals("true") || eventYearIndex.equals("false")){
                    eventYearIndex = "Current";
                    preferences.setEventYearToLoad("Current");
                }
                
                // DEBUG: Log what year is selected by user
                Log.d("70K_NOTE_DEBUG", "User selected eventYearIndex: " + eventYearIndex);
                Log.d("70K_NOTE_DEBUG", "Available years in pointer file: " + eventYearArray.toString());

                Log.d("pointerUrl", "eventYearIndex equals " + eventYearIndex);
                String data = "";
                String line;

                URL url = new URL(pointerUrl);
                
                // Handle HTTP redirects properly for Dropbox URLs
                HttpURLConnection connection = (HttpURLConnection) url.openConnection();
                connection.setInstanceFollowRedirects(true);
                connection.setConnectTimeout(10000); // 10 seconds
                connection.setReadTimeout(30000); // 30 seconds
                
                BufferedReader in = new BufferedReader(new InputStreamReader(connection.getInputStream()));
                while ((line = in.readLine()) != null) {
                    data += line + "\n";
                }
                in.close();

                Log.d("defaultUrls", data);

                String[] records = data.split("\\n");
                Log.d("defaultUrls", "eventYearIndex is " + eventYearIndex);
                Map<String, String> downloadUrls = readPointData(records, eventYearIndex);
                Log.d("defaultUrls",downloadUrls.toString());
                
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
                eventYearRaw = Integer.valueOf(downloadUrls.get("eventYear"));

                Log.d("pointerUrl", "artistURL = " + artistURL);
                Log.d("pointerUrl", "scheduleURL = " + scheduleURL);
                Log.d("pointerUrl", "descriptionMap = " + descriptionMap);
                Log.d("pointerUrl", "eventYearRaw = " + eventYearRaw);
                
                // Additional 70K_NOTE_DEBUG logging
                Log.d("70K_NOTE_DEBUG", "Final URLs set - artistURL: " + artistURL);
                Log.d("70K_NOTE_DEBUG", "Final URLs set - descriptionMap: " + descriptionMap);
                Log.d("70K_NOTE_DEBUG", "Final URLs set - eventYearRaw: " + eventYearRaw);
            } catch (Exception error) {
                Log.d("pointerUrl Error", error.getMessage());
                Log.d("pointerUrl Error", String.valueOf(error.getCause()));
                Log.d("pointerUrl Error", String.valueOf(error.getStackTrace()));
            }
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
                    connection.setConnectTimeout(5000);  // 5 seconds
                    connection.setReadTimeout(10000);    // 10 seconds
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

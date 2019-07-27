package com.Bands70k;

import android.content.Context;
import android.graphics.Paint;
import android.net.Uri;
import android.os.Build;
import android.os.Parcelable;
import android.provider.Settings;
import android.util.Log;


import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.InputStreamReader;
import java.net.URL;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/**
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

    public final static String showTypeIcon = "";
    public final static String specialEventTypeIcon = "🌟";
    public final static String mAndmEventTypeIcon = "\uD83D\uDCF7";
    public final static String listeningEventTypeIcon =  "💽";
    public final static String clinicEventTypeIcon = "🎸";
    public final static String unofficalEventTypeIcon = "\uD83D\uDC79";

    public final static String  poolVenueIcon = "🏊";
    public final static String  theaterVenueIcon = "🎭";
    public final static String  loungeVenueIcon = "🎤";
    public static String  rinkVenueIcon = "\uD83D\uDD03";

    public static Integer eventYear = 0;
    public static Integer eventYearRaw = 0;

    public static String userID = "";
    //firebase channels
    public final static String mainAlertChannel = "global";
    public final static String testAlertChannel = "testing20000";
    public final static String unofficalAlertChannel = "unofficalEvents";

    //shows attended
    public static String sawAllIcon = "\uD83C\uDFC3\u200D";
    public static String sawSomeIcon = "\uD83D\uDEB6\u200D";
    public final static String sawNoneIcon = "";
    public static String attendedShowIcon = "\uD83C\uDFC3\u200D";

    public static Map<String,String> showNotesMap = new HashMap<String, String>();
    public static Map<String,String> imageUrlMap = new HashMap<String, String>();

    public final static String sawAllColor = "#67C10C";
    public final static String sawSomeColor = "#F0D905";
    public final static String sawNoneColor = "white";
    public final static String sawAllStatus = "sawAll";
    public final static String sawSomeStatus = "sawSome";
    public final static String sawNoneStatus = "sawNone";

    public static String notificationChannelID = "70KBandsCustomSound1";
    public static CharSequence notificationChannelName = "70KBandsCustomSound1";
    public static String notificationChannelDescription = "Channel for the 70K Bands local show alerts with custom sound1";
    public final static Uri alarmSound = Uri.parse("android.resource://com.Bands70k/" + R.raw.onmywaytodeath);

    public final static String  poolVenueText = "Pool";
    public final static String  theaterVenueText = "Theater";
    public final static String  loungeVenueText = "Lounge";
    public final static String  rinkVenueText = "Rink";

    public final static String show = "Show";
    public final static String meetAndGreet = "Meet and Greet";
    public final static String clinic = "Clinic";
    public final static String specialEvent = "Special Event";
    public final static String listeningEvent = "Listening Party";
    public final static String unofficalEvent = "Cruiser Organized";
    public final static String unofficalEventOld = "Unofficial Event";
    public final static String karaoekeEvent = "Karaoeke";

    public final static String poolVenueColor = "#3478C7";
    public final static String theaterVenueColor = "#C4AC00";
    public final static String loungeVenueColor = "#5BA50A";
    public final static String rinkVenueColor = "#8A0011";
    public final static String unknownVenueColor = "#A9A9A9";

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

    public final static String defaultUrls = "https://www.dropbox.com/s/5bqlfnf41w7emgv/productionPointer2019New.txt?dl=1";
    //public final static String defaultUrls = "https://www.dropbox.com/s/sh6ctneu8kjkxrc/productionPointer2019Test.txt?dl=1";

    public final static String logo70kUrl = "http://70000tons.com/wp-content/uploads/2016/11/70k_logo_sm.png";

    public static String artistURL;
    public static String scheduleURL;
    public static String previousYearArtist;
    public static String previousYearSchedule;
    public static String descriptionMap;
    public static String previousYearDescriptionMap;

    public static Boolean schedulePresent = false;
    public static Boolean notesLoaded = false;

    public static Map<String, Boolean> filterToogle = new HashMap<String, Boolean>();

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

    public static preferencesHandler preferences;
    public static showsAttended attendedHandler;

    public static String writeNoteHtml = "";

    public static Context context;

    public static Boolean loadingBands = false;
    public static Boolean loadingSchedule = false;
    public static Boolean loadingNotes = false;
    public static Boolean schedulingAlert = false;

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

    public static Map<String,String> venueLocation =  new HashMap<String, String>();

    public static Integer alertTracker = 0;

    public static Set<String> alertMessages = new HashSet<String>();

    public static void staticVariablesInitialize (){

        preferences.loadData();

        if (staticVariables.filterToogle.get(staticVariables.mustSeeIcon) == null){
            staticVariables.filterToogle.put(staticVariables.mustSeeIcon, staticVariables.preferences.getShowMust());
        }
        if (staticVariables.filterToogle.get(staticVariables.mightSeeIcon) == null){
            staticVariables.filterToogle.put(staticVariables.mightSeeIcon,  staticVariables.preferences.getShowMight());
        }
        if (staticVariables.filterToogle.get(staticVariables.wontSeeIcon) == null){
            staticVariables.filterToogle.put(staticVariables.wontSeeIcon, staticVariables.preferences.getShowWont());
        }
        if (staticVariables.filterToogle.get(staticVariables.unknownIcon) == null){
            staticVariables.filterToogle.put(staticVariables.unknownIcon, staticVariables.preferences.getShowUnknown());
        }

        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.LOLLIPOP){
            rinkVenueIcon = "\u26F8";
        }

        //use more update to date icons, but only if present
        if (canShowFlagEmoji("\uD83E\uDD18") == true){
            sawAllIcon = "\uD83E\uDD18";
            sawSomeIcon = "\uD83D\uDC4D";
        }
        if (canShowFlagEmoji("\uD83C\uDF9F") == true){
            attendedShowIcon = "\uD83C\uDF9F";
        }

        if (previousYearArtist == null) {
            lookupUrls();
        }

        if (context == null){
            context = Bands70k.getAppContext();
        }

        if (eventYear == 0){
            getEventYear();
        }

        if (userID.isEmpty() == true) {
            userID = Settings.Secure.getString(staticVariables.context.getContentResolver(),
                    Settings.Secure.ANDROID_ID);
        }

        setupVenueLocations();
    }

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

    public static void setupVenueLocations(){

        venueLocation.put(poolVenueText, "Deck 11");
        venueLocation.put(rinkVenueText, "Deck 3");
        venueLocation.put(loungeVenueText, "Deck 4");
        venueLocation.put(theaterVenueText, "Deck 3/4");
        venueLocation.put("Sports Bar", "Deck 4");
        venueLocation.put("Viking Crown", "Deck 14");
        venueLocation.put("Boleros Lounge", "Deck 4");
    }

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

        return icon;
    }

    public static void getEventYear(){

        eventYearFile = new File(showBands.newRootDir + FileHandler70k.directoryName + eventYear + ".txt");

        if (eventYearRaw == 0){
            eventYear = readEventYearFile();

        } else {
            eventYear = eventYearRaw;

            if (preferences.getUseLastYearsData() == true) {
                eventYear = eventYear - 1;
            }

            writeEventYearFile();
        }

    }

    private static Integer readEventYearFile(){

        String eventYearString = "";
        try {

            BufferedReader br = new BufferedReader(new FileReader(eventYearFile));

            String line;

            while ((line = br.readLine()) != null) {
                eventYearString = line;
            }

        } catch (Exception error) {
            Log.e("readEventYearFile", "readEventYearFile error " + error.getMessage());

        }

        return Integer.valueOf(eventYearString);
    }

    private static void writeEventYearFile(){

        FileHandler70k.saveData(String.valueOf(eventYear), eventYearFile);

    }

    private static void lookupUrls(){

        try {
            URL url = new URL(staticVariables.defaultUrls);
            BufferedReader in = new BufferedReader(new InputStreamReader(url.openStream()));
            String data = "";
            String line;

            Map<String, String> downloadUrls = new HashMap<String,String>();

            while ((line = in.readLine()) != null) {
                data += line + "\n";
            }
            in.close();

            Log.d("defaultUrls", data);

            String[] records = data.split("\\n");
            for (String record : records) {
                Log.d("defaultUrls 1", record);
                String[] recordData = record.split("::");
                //Log.d("defaultUrls downloading", recordData[0] + " to " + recordData[1]);
                if (recordData.length >= 2) {
                    downloadUrls.put(recordData[0], recordData[1]);
                }

            }

            previousYearArtist = downloadUrls.get("lastYearsartistUrl");
            previousYearSchedule = downloadUrls.get("lastYearsScheduleUrl");
            artistURL = downloadUrls.get("artistUrl");
            scheduleURL = downloadUrls.get("scheduleUrl");
            descriptionMap = downloadUrls.get("descriptionMap");
            previousYearDescriptionMap = downloadUrls.get("descriptionMapLastYear");
            eventYearRaw = Integer.valueOf(downloadUrls.get("eventYear"));

        } catch (Exception error){
            Log.d("Error", error.getMessage());
        }

    }

}

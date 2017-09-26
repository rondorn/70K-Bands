package com.Bands70k;

import android.os.Build;
import android.os.Parcelable;
import android.util.Log;

import java.util.HashMap;
import java.util.Map;

/**
 * Created by rdorn on 8/1/15.
 */
public class staticVariables {

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

    public final static String  poolVenueIcon = "🏊";
    public final static String  theaterVenueIcon = "🎭";
    public final static String  loungeVenueIcon = "🎤";
    public static String  rinkVenueIcon = "\uD83D\uDD03";

    public final static String  poolVenueText = "Pool";
    public final static String  theaterVenueText = "Theater";
    public final static String  loungeVenueText = "Lounge";
    public final static String  rinkVenueText = "Rink";

    public final static String show = "Show";
    public final static String meetAndGreet = "Meet and Greet";
    public final static String clinic = "Clinic";
    public final static String specialEvent = "Special Event";
    public final static String listeningEvent = "Listening Party";

    public final static String mustSeeKey = "mustSee";
    public final static String mightSeeKey = "mightSee";
    public final static String wontSeeKey = "wontSee";
    public final static String unknownKey = "unknown";

    public final static String defaultUrls = "https://www.dropbox.com/s/29ktavd9fksxw85/productionPointer1.txt?dl=1";

    //testing pointer
    //public final static String defaultUrls = "https://www.dropbox.com/s/w2mz8p0mpght1yt/productionPointer3.txt?dl=1";


    public final static String previousYearArtist = "https://www.dropbox.com/s/0uz41zl8jbirca2/lastYeaysartistLineup.csv?dl=1";
    public final static String previousYearSchedule = "https://www.dropbox.com/s/czrg31whgc0211p/lastYearsSchedule.csv?dl=1";
    //public final static String previousYearSchedule = "https://www.dropbox.com/s/ufn4m1e2fn07arf/artistsSchedule2016.csv?dl=1";
    //public final static String previousYearSchedule = "https://www.dropbox.com/s/wk73mdnvxu4jey5/lastYearsScheduleExp.csv?dl=1";

    public static Map<String, Boolean> filterToogle = new HashMap<String, Boolean>();

    public static Boolean fileDownloaded = false;

    public static Boolean sortBySchedule = true;
    public static Parcelable listState;

    public static String SENT_TOKEN_TO_SERVER = "sentTokenToServer";
    public static String REGISTRATION_COMPLETE = "registrationComplete";

    public static Integer alarmCount = 1;

    public static Boolean refreshActivated = false;

    public static String writeNoteHtml = "";

    public static void staticVariablesInitialize (){

        if (staticVariables.filterToogle.get(staticVariables.mustSeeIcon) == null){
            staticVariables.filterToogle.put(staticVariables.mustSeeIcon, true);
        }
        if (staticVariables.filterToogle.get(staticVariables.mightSeeIcon) == null){
            staticVariables.filterToogle.put(staticVariables.mightSeeIcon, true);
        }
        if (staticVariables.filterToogle.get(staticVariables.wontSeeIcon) == null){
            staticVariables.filterToogle.put(staticVariables.wontSeeIcon, true);
        }
        if (staticVariables.filterToogle.get(staticVariables.unknownIcon) == null){
            staticVariables.filterToogle.put(staticVariables.unknownIcon, true);
        }

        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.LOLLIPOP){
            rinkVenueIcon = "\u26F8";
        }
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
}

package com.Bands70k;

import android.os.Parcelable;

import java.util.HashMap;
import java.util.Map;

/**
 * Created by rdorn on 8/1/15.
 */
public class staticVariables {

    public final static String mustSeeIcon = "\uD83C\uDF7A";
    public final static String mightSeeIcon = "\u2705";
    public final static String wontSeeIcon = "\uD83D\uDEAB";
    public final static String unknownIcon = "\u2753";

    public final static String mustSeeKey = "mustSee";
    public final static String mightSeeKey = "mightSee";
    public final static String wontSeeKey = "wontSee";
    public final static String unknownKey = "unknown";

    public final static String defaultUrls = "https://www.dropbox.com/s/29ktavd9fksxw85/productionPointer1.txt?dl=1";

    public final static String previousYearArtist = "https://www.dropbox.com/s/0uz41zl8jbirca2/lastYeaysartistLineup.csv?dl=1";
    public final static String previousYearSchedule = "https://www.dropbox.com/s/czrg31whgc0211p/lastYearsSchedule.csv?dl=1";

    public static Map<String, Boolean> filterToogle = new HashMap<String, Boolean>();

    public static Boolean fileDownloaded = false;

    public static Boolean sortBySchedule = true;
    public static Parcelable listState;

    public static Integer alarmCount = 1;
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
    }
}

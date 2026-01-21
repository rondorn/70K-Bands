package com.Bands70k;


import android.os.Environment;
import android.util.Log;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileReader;

import static com.Bands70k.staticVariables.preferences;


/**
 * Created by rdorn on 8/12/15.
 */
public class preferencesHandler {

    private Boolean mustSeeAlert = true;
    private Boolean mightSeeAlert = true;
    private Boolean alertForShows = true;
    private Boolean alertForSpecialEvents = true;
    private Boolean alertForUnofficalEvents = true;
    private Boolean alertForMeetAndGreet = false;
    private Boolean alertForClinics = false;
    private Boolean alertForListeningParties = false;
    private Integer minBeforeToAlert = 10;
    private Boolean useLastYearsData = false;

    private Boolean showSpecialEvents = true;
    private Boolean showMeetAndGreet = true;
    private Boolean showClinicEvents = true;
    private Boolean showAlbumListen = true;

    // New settings to control visibility of event type filters per festival
    // These will be initialized properly in loadData() method based on festival type
    private Boolean meetAndGreetsEnabled;
    private Boolean specialEventsEnabled;
    private Boolean unofficalEventsEnabled;

    private Boolean showPoolShows = true;
    private Boolean showTheaterShows = true;
    private Boolean showRinkShows = true;
    private Boolean showLoungeShows = true;
    private Boolean showOtherShows = true;
    private Boolean showUnofficalEvents = true;

    private Boolean showMust = true;
    private Boolean showMight = true;
    private Boolean showWont = true;
    private Boolean showUnknown = true;

    private Boolean hideExpiredEvents = true;
    private Boolean promptForAttendedStatus = true;
    
    private Boolean noteFontSizeLarge = false;
    private Boolean openYouTubeApp = true;
    private Boolean allLinksOpenInExternalBrowser = false;

    private Boolean showWillAttend = false;
    private Boolean alertOnlyForShowWillAttend = false;

    private String artsistsUrl = "Default";
    private String scheduleUrl = "Default";
    private String descriptionMapUrl = "Default";

    private String eventYearToLoad = "Current";

    private String pointerUrl = "Default";

    private Boolean sortByTime = true;
    
    // View mode preference: true = Schedule view, false = Bands-only view
    private Boolean showScheduleView = true;

    private Integer loadCounter = 0;

    public void loadData() {

        Log.d("FILTER_DEBUG", "🔧 preferencesHandler.loadData() called, prefsLoaded: " + staticVariables.prefsLoaded + ", loadCounter: " + loadCounter);
        Log.d("settingFilters", "Loading prefereces, already loaded" + staticVariables.prefsLoaded);
        if (loadCounter == 0) {
            loadCounter = loadCounter + 1;
            try {

                File file = FileHandler70k.bandPrefs;

                BufferedReader br = new BufferedReader(new FileReader(file));
                String line;

                while ((line = br.readLine()) != null) {
                    String[] RowData = line.split(",");
                    switch (RowData[0]) {
                        case "mustSeeAlert":
                            setMustSeeAlert(Boolean.valueOf(RowData[1]));
                            break;

                        case "mightSeeAlert":
                            setMightSeeAlert(Boolean.valueOf(RowData[1]));
                            break;

                        case "alertForShows":
                            setAlertForShows(Boolean.valueOf(RowData[1]));
                            break;

                        case "alertForUnofficalEvents":
                            setAlertForUnofficalEvents(Boolean.valueOf(RowData[1]));
                            break;

                        case "showSpecialEvents":
                            setShowSpecialEvents(Boolean.valueOf(RowData[1]));
                            break;

                        case "showMeetAndGreet":
                            setShowMeetAndGreet(Boolean.valueOf(RowData[1]));
                            break;

                        case "showUnofficalEvents":
                            setShowUnofficalEvents(Boolean.valueOf(RowData[1]));
                            break;
                        
                        case "meetAndGreetsEnabled":
                            setMeetAndGreetsEnabled(Boolean.valueOf(RowData[1]));
                            break;
                        
                        case "specialEventsEnabled":
                            setSpecialEventsEnabled(Boolean.valueOf(RowData[1]));
                            break;
                        
                        case "unofficalEventsEnabled":
                            setUnofficalEventsEnabled(Boolean.valueOf(RowData[1]));
                            break;

                        case "showClinics":
                            setShowClinicEvents(Boolean.valueOf(RowData[1]));
                            break;

                        case "showListeningParties":
                            setShowAlbumListen(Boolean.valueOf(RowData[1]));
                            break;

                        case "showPoolShows":
                            setShowPoolShows(Boolean.valueOf(RowData[1]));
                            break;

                        case "showTheaterShows":
                            setShowTheaterShows(Boolean.valueOf(RowData[1]));
                            break;

                        case "showRinkShows":
                            setShowRinkShows(Boolean.valueOf(RowData[1]));
                            break;

                        case "showLoungeShows":
                            setShowLoungeShows(Boolean.valueOf(RowData[1]));
                            break;

                        case "showOtherShows":
                            setShowOtherShows(Boolean.valueOf(RowData[1]));
                            break;

                        case "alertForSpecialEvents":
                            setAlertForSpecialEvents(Boolean.valueOf(RowData[1]));
                            break;

                        case "alertForMeetAndGreet":
                            setAlertForMeetAndGreet(Boolean.valueOf(RowData[1]));
                            break;

                        case "alertForClinics":
                            setAlertForClinics(Boolean.valueOf(RowData[1]));
                            break;

                        case "alertForListeningParties":
                            setAlertForListeningParties(Boolean.valueOf(RowData[1]));
                            break;

                        case "useLastYearsData":
                            setUseLastYearsData(Boolean.valueOf(RowData[1]));
                            break;

                        case "minBeforeToAlert":
                            setMinBeforeToAlert(Integer.valueOf(RowData[1]));
                            break;

                        case "artistsUrl":
                            setArtsistsUrl(RowData[1]);
                            break;

                        case "scheduleUrl":
                            setScheduleUrl(RowData[1]);
                            break;

                        case "pointerUrl":
                            setPointerUrl(RowData[1]);
                            break;

                        case "showMust":
                            setshowMust(Boolean.valueOf(RowData[1]));

                        case "showMight":
                            setshowMight(Boolean.valueOf(RowData[1]));

                        case "showWont":
                            setshowWont(Boolean.valueOf(RowData[1]));

                        case "showUnknown":
                            setshowUnknown(Boolean.valueOf(RowData[1]));

                        case "showWillAttend":
                            setShowWillAttend(Boolean.valueOf(RowData[1]));

                        case "alertOnlyForShowWillAttend":
                            setAlertOnlyForShowWillAttend(Boolean.valueOf(RowData[1]));

                        case "sortByTime":
                            setSortByTime(Boolean.valueOf(RowData[1]));

                        // REMOVED: showScheduleView - this is now session-only, always defaults to true
                        // case "showScheduleView":
                        //     setShowScheduleView(Boolean.valueOf(RowData[1]));

                        case "hideExpiredEvents":
                            setHideExpiredEvents(Boolean.valueOf(RowData[1]));

                        case "promptForAttendedStatus":
                            setPromptForAttendedStatus(Boolean.valueOf(RowData[1]));

                        case "eventYearToLoad":
                            setEventYearToLoad(String.valueOf(RowData[1]));
                            break;

                        case "noteFontSizeLarge":
                            setNoteFontSizeLarge(Boolean.valueOf(RowData[1]));
                            break;

                        case "openYouTubeApp":
                            setOpenYouTubeApp(Boolean.valueOf(RowData[1]));
                            break;

                        case "allLinksOpenInExternalBrowser":
                            setAllLinksOpenInExternalBrowser(Boolean.valueOf(RowData[1]));
                            break;

                    }
                }
            } catch (Exception error) {
                Log.e("Load Data Error", error.getMessage() + "\n" + error.fillInStackTrace());
            }
            
            // CRITICAL: Initialize festival-specific event type filter visibility settings IMMEDIATELY
            // to prevent null values from affecting other filtering logic
            initializeEventTypeFilterVisibilityImmediate();
            
            // SESSION-ONLY: showScheduleView always defaults to true on every app launch
            // Ensure sortByTime matches: Schedule View = Sort by Time (true)
            Log.d("VIEW_MODE_SESSION", "🔄 App launch: showScheduleView initialized to true (session-only)");
            if (!getSortByTime()) {
                Log.d("VIEW_MODE_SESSION", "🔄 App launch: Resetting sortByTime to true to match schedule view");
                setSortByTime(true);
                // Save the corrected sort preference
                saveData();
            }
            
            removeFiltersForShowWillAttend();
        }
    }

    /**
     * Initialize festival-specific event type filter visibility settings.
     * This ensures proper defaults based on the current festival type.
     */
    private void initializeEventTypeFilterVisibility() {
        FestivalConfig config = FestivalConfig.getInstance();
        
        // Only initialize if not already set (null values indicate not loaded from file)
        if (meetAndGreetsEnabled == null || specialEventsEnabled == null || unofficalEventsEnabled == null) {
            // Use festival-specific defaults from FestivalConfig
            if (meetAndGreetsEnabled == null) meetAndGreetsEnabled = config.meetAndGreetsEnabledDefault;
            if (specialEventsEnabled == null) specialEventsEnabled = config.specialEventsEnabledDefault;
            if (unofficalEventsEnabled == null) unofficalEventsEnabled = config.unofficalEventsEnabledDefault;
            
            Log.d("PreferencesHandler", "Initialized event type filter visibility for festival: " + 
                  config.festivalShortName + 
                  " - meetAndGreets: " + meetAndGreetsEnabled + 
                  ", specialEvents: " + specialEventsEnabled + 
                  ", unofficalEvents: " + unofficalEventsEnabled);
        }
    }
    
    /**
     * IMMEDIATE initialization of event type filter visibility settings.
     * This is called right after preferences are loaded to ensure values are never null.
     */
    private void initializeEventTypeFilterVisibilityImmediate() {
        FestivalConfig config = FestivalConfig.getInstance();
        
        Log.d("FILTER_DEBUG", "🔧 IMMEDIATE initialization called for festival: " + config.festivalShortName);
        Log.d("FILTER_DEBUG", "🔧 Current values before init: meetAndGreets=" + meetAndGreetsEnabled + 
              ", specialEvents=" + specialEventsEnabled + ", unoffical=" + unofficalEventsEnabled);
        
        // FORCE initialization to prevent any null values that could affect other logic
        if (meetAndGreetsEnabled == null) {
            meetAndGreetsEnabled = config.meetAndGreetsEnabledDefault;
            Log.d("FILTER_DEBUG", "🔧 IMMEDIATE: Set meetAndGreetsEnabled = " + meetAndGreetsEnabled);
        }
        if (specialEventsEnabled == null) {
            specialEventsEnabled = config.specialEventsEnabledDefault;
            Log.d("FILTER_DEBUG", "🔧 IMMEDIATE: Set specialEventsEnabled = " + specialEventsEnabled);
        }
        if (unofficalEventsEnabled == null) {
            unofficalEventsEnabled = config.unofficalEventsEnabledDefault;
            Log.d("FILTER_DEBUG", "🔧 IMMEDIATE: Set unofficalEventsEnabled = " + unofficalEventsEnabled);
        }
        
        Log.d("FILTER_DEBUG", "🔧 IMMEDIATE initialization complete for festival: " + 
              config.festivalShortName + 
              " - meetAndGreets: " + meetAndGreetsEnabled + 
              ", specialEvents: " + specialEventsEnabled + 
              ", unofficalEvents: " + unofficalEventsEnabled);
    }
    
    public void removeFiltersForShowWillAttend(){
        if (getShowWillAttend() == true){
            setshowMust(true);
            setshowMight(true);
            setshowWont(true);
            setshowUnknown(true);
        }
    }

    public void saveData() {

        String dataString = "";
        dataString += "mustSeeAlert," + mustSeeAlert.toString() + "\n";
        dataString += "mightSeeAlert," + mightSeeAlert.toString() + "\n";
        dataString += "alertForShows," + alertForShows.toString() + "\n";
        dataString += "alertForSpecialEvents," + alertForSpecialEvents.toString() + "\n";
        dataString += "alertForMeetAndGreet," + alertForMeetAndGreet.toString() + "\n";
        dataString += "alertForClinics," + alertForClinics.toString() + "\n";
        dataString += "alertForListeningParties," + alertForListeningParties.toString() + "\n";
        dataString += "alertForUnofficalEvents," + alertForUnofficalEvents.toString() + "\n";

        dataString += "showSpecialEvents," + showSpecialEvents.toString() + "\n";
        dataString += "showMeetAndGreet," + showMeetAndGreet.toString() + "\n";
        dataString += "showClinics," + showClinicEvents.toString() + "\n";
        dataString += "showListeningParties," + showAlbumListen.toString() + "\n";
        dataString += "showUnofficalEvents," + showUnofficalEvents.toString() + "\n";

        // Event type filter visibility settings (ensure they're initialized before saving)
        initializeEventTypeFilterVisibilityImmediate();
        dataString += "meetAndGreetsEnabled," + meetAndGreetsEnabled.toString() + "\n";
        dataString += "specialEventsEnabled," + specialEventsEnabled.toString() + "\n";
        dataString += "unofficalEventsEnabled," + unofficalEventsEnabled.toString() + "\n";

        dataString += "showPoolShows," + showPoolShows.toString() + "\n";
        dataString += "showTheaterShows," + showTheaterShows.toString() + "\n";
        dataString += "showRinkShows," + showRinkShows.toString() + "\n";
        dataString += "showLoungeShows," + showLoungeShows.toString() + "\n";
        dataString += "showOtherShows," + showOtherShows.toString() + "\n";

        dataString += "showMust," + showMust.toString() + "\n";
        dataString += "showMight," + showMight.toString() + "\n";
        dataString += "showWont," + showWont.toString() + "\n";
        dataString += "showUnknown," + this.showUnknown.toString() + "\n";

        dataString += "showWillAttend," + this.showWillAttend.toString() + "\n";
        dataString += "alertOnlyForShowWillAttend," + this.alertOnlyForShowWillAttend.toString() + "\n";

        dataString += "useLastYearsData," + useLastYearsData.toString() + "\n";
        dataString += "minBeforeToAlert," + minBeforeToAlert.toString() + "\n";
        dataString += "artistsUrl," + artsistsUrl + "\n";
        dataString += "scheduleUrl," + scheduleUrl + "\n";
        dataString += "pointerUrl," + pointerUrl + "\n";
        dataString += "sortByTime," + sortByTime.toString() + "\n";
        // REMOVED: showScheduleView - session-only, never saved to disk
        // dataString += "showScheduleView," + getShowScheduleView().toString() + "\n";
        dataString += "hideExpiredEvents," + hideExpiredEvents.toString() + "\n";
        dataString += "promptForAttendedStatus," + promptForAttendedStatus.toString() + "\n";
        dataString += "noteFontSizeLarge," + noteFontSizeLarge.toString() + "\n";
        dataString += "openYouTubeApp," + openYouTubeApp.toString() + "\n";
        dataString += "allLinksOpenInExternalBrowser," + allLinksOpenInExternalBrowser.toString() + "\n";
        dataString += "eventYearToLoad," + eventYearToLoad.toString() + "\n";

        FileHandler70k.saveData(dataString, FileHandler70k.bandPrefs);
    }

    public void resetMainFilters(){
        this.setshowMust(true);
        this.setshowMight(true);
        this.setshowWont(true);
        this.setshowUnknown(true);
        this.loadCounter = 0;
    }

    public Boolean getShowUnofficalEvents() {
        return showUnofficalEvents;
    }

    public void setShowUnofficalEvents(Boolean showUnofficalEvents) {
        this.showUnofficalEvents = showUnofficalEvents;
    }

    public Boolean getAlertForUnofficalEvents() {

        if (alertForUnofficalEvents == null){
            alertForUnofficalEvents = true;
        }
        return alertForUnofficalEvents;
    }

    public void setAlertForUnofficalEvents(Boolean alertUnofficalEvents) {
        this.alertForUnofficalEvents = alertUnofficalEvents;
    }

    public Boolean getMustSeeAlert() {

        if (mustSeeAlert == null){
            mustSeeAlert = true;
        }
        return mustSeeAlert;
    }
    public void setMustSeeAlert(Boolean mustSeeAlert) {
        this.mustSeeAlert = mustSeeAlert;
    }

    public Boolean getMightSeeAlert() {

        if (mightSeeAlert == null){
            mightSeeAlert = true;
        }
        return mightSeeAlert;
    }

    public void setMightSeeAlert(Boolean mightSeeAlert) {
        this.mightSeeAlert = mightSeeAlert;
    }

    public Boolean getAlertForShows() {

        if (alertForShows == null){
            alertForShows = true;
        }
        return alertForShows;
    }
    public void setAlertForShows(Boolean alertForShows) {
        this.alertForShows = alertForShows;
    }

    public Boolean getAlertOnlyForShowWillAttend(){ return alertOnlyForShowWillAttend; }
    public void setAlertOnlyForShowWillAttend (Boolean value) {this.alertOnlyForShowWillAttend = value; }

    public Boolean getAlertForSpecialEvents() {
        return alertForSpecialEvents;
    }
    public Boolean getShowSpecialEvents() {
        return showSpecialEvents;
    }
    public Boolean getShowMeetAndGreet() {
        return showMeetAndGreet;
    }
    public Boolean getShowClinicEvents() {
        return showClinicEvents;
    }
    public Boolean getShowAlbumListen() {
        return showAlbumListen;
    }

    // Event type filter visibility settings
    public Boolean getMeetAndGreetsEnabled() {
        if (meetAndGreetsEnabled == null) {
            // Safe default from FestivalConfig
            FestivalConfig config = FestivalConfig.getInstance();
            Log.d("FILTER_DEBUG", "⚠️ getMeetAndGreetsEnabled() was NULL, returning default: " + config.meetAndGreetsEnabledDefault + " for festival: " + config.festivalShortName);
            return config.meetAndGreetsEnabledDefault;
        }
        Log.d("FILTER_DEBUG", "✅ getMeetAndGreetsEnabled() returning: " + meetAndGreetsEnabled);
        return meetAndGreetsEnabled;
    }
    
    public void setMeetAndGreetsEnabled(Boolean meetAndGreetsEnabled) {
        this.meetAndGreetsEnabled = meetAndGreetsEnabled;
    }
    
    public Boolean getSpecialEventsEnabled() {
        if (specialEventsEnabled == null) {
            // Safe default from FestivalConfig
            FestivalConfig config = FestivalConfig.getInstance();
            Log.d("FILTER_DEBUG", "⚠️ getSpecialEventsEnabled() was NULL, returning default: " + config.specialEventsEnabledDefault + " for festival: " + config.festivalShortName);
            return config.specialEventsEnabledDefault;
        }
        Log.d("FILTER_DEBUG", "✅ getSpecialEventsEnabled() returning: " + specialEventsEnabled);
        return specialEventsEnabled;
    }
    
    public void setSpecialEventsEnabled(Boolean specialEventsEnabled) {
        this.specialEventsEnabled = specialEventsEnabled;
    }
    
    public Boolean getUnofficalEventsEnabled() {
        if (unofficalEventsEnabled == null) {
            // Safe default from FestivalConfig
            FestivalConfig config = FestivalConfig.getInstance();
            Log.d("FILTER_DEBUG", "⚠️ getUnofficalEventsEnabled() was NULL, returning default: " + config.unofficalEventsEnabledDefault + " for festival: " + config.festivalShortName);
            return config.unofficalEventsEnabledDefault;
        }
        Log.d("FILTER_DEBUG", "✅ getUnofficalEventsEnabled() returning: " + unofficalEventsEnabled);
        return unofficalEventsEnabled;
    }
    
    public void setUnofficalEventsEnabled(Boolean unofficalEventsEnabled) {
        this.unofficalEventsEnabled = unofficalEventsEnabled;
    }

    public Boolean getShowPoolShows() {
        return showPoolShows;
    }
    public Boolean getShowTheaterShows() {
        return showTheaterShows;
    }
    public Boolean getShowRinkShows() {
        return showRinkShows;
    }
    public Boolean getShowLoungeShows() {
        return showLoungeShows;
    }
    public Boolean getShowOtherShows() {
        return showOtherShows;
    }
    
    /**
     * Dynamic venue preference support - gets venue show state for any venue name
     * Uses existing 70K preferences for known venues, defaults to true for unknown venues
     */
    public Boolean getShowVenueEvents(String venueName) {
        switch (venueName) {
            case "Pool": return getShowPoolShows();
            case "Lounge": return getShowLoungeShows();
            case "Theater": return getShowTheaterShows();
            case "Rink": return getShowRinkShows();
            case "Other": return getShowOtherShows();
            // For MDF venues and other festivals, use a dynamic preference system
            default:
                return getCustomVenuePreference(venueName);
        }
    }
    
    /**
     * Dynamic venue preference support - sets venue show state for any venue name  
     * Uses existing 70K preferences for known venues, stores custom preferences for others
     */
    public void setShowVenueEvents(String venueName, Boolean value) {
        switch (venueName) {
            case "Pool": setShowPoolShows(value); break;
            case "Lounge": setShowLoungeShows(value); break;
            case "Theater": setShowTheaterShows(value); break;
            case "Rink": setShowRinkShows(value); break;
            case "Other": setShowOtherShows(value); break;
            // For MDF venues and other festivals, use a dynamic preference system
            default:
                setCustomVenuePreference(venueName, value);
                break;
        }
    }
    
    /**
     * Gets custom venue preference for venues not in the hardcoded 70K list
     */
    private Boolean getCustomVenuePreference(String venueName) {
        // Use SharedPreferences to store custom venue preferences
        android.content.SharedPreferences customVenuePrefs = staticVariables.context.getSharedPreferences("custom_venue_prefs", android.content.Context.MODE_PRIVATE);
        return customVenuePrefs.getBoolean("show_" + venueName.toLowerCase() + "_shows", true); // Default to true
    }
    
    /**
     * Sets custom venue preference for venues not in the hardcoded 70K list
     */
    private void setCustomVenuePreference(String venueName, Boolean value) {
        // Use SharedPreferences to store custom venue preferences
        android.content.SharedPreferences customVenuePrefs = staticVariables.context.getSharedPreferences("custom_venue_prefs", android.content.Context.MODE_PRIVATE);
        android.content.SharedPreferences.Editor editor = customVenuePrefs.edit();
        editor.putBoolean("show_" + venueName.toLowerCase() + "_shows", value);
        editor.apply();
    }

    public void setSortByTime(Boolean value) {
        sortByTime = value;
    }
    public Boolean getSortByTime() {
        return sortByTime;
    }

    public Boolean getShowScheduleView() {
        if (showScheduleView == null) {
            showScheduleView = true;
        }
        return showScheduleView;
    }
    
    public void setShowScheduleView(Boolean value) {
        this.showScheduleView = value;
    }

    public Boolean getShowMust() {
        return showMust;
    }
    public Boolean getShowMight() {
        return showMight;
    }
    public Boolean getShowWont() {
        return showWont;
    }
    public Boolean getShowUnknown() {
        return this.showUnknown;
    }

    public Boolean getHideExpiredEvents() {
        return this.hideExpiredEvents;
    }
    public Boolean getPromptForAttendedStatus() { return this.promptForAttendedStatus;}

    public String getEventYearToLoad() { return this.eventYearToLoad;}

    public Boolean getShowWillAttend() { return this.showWillAttend;}

    public void setShowPoolShows(Boolean showPoolShows) {
        this.showPoolShows = showPoolShows;
    }

    public void setShowTheaterShows(Boolean showTheaterShows) {
        this.showTheaterShows = showTheaterShows;
    }
    public void setShowRinkShows(Boolean showRinkShows) {
        this.showRinkShows = showRinkShows;
    }
    public void setShowLoungeShows(Boolean showLoungeShows) {
        this.showLoungeShows = showLoungeShows;
    }
    public void setShowOtherShows(Boolean showOtherShows) {
        this.showOtherShows = showOtherShows;
    }

    public void setShowSpecialEvents(Boolean hideSpecialEvents) {
        this.showSpecialEvents = hideSpecialEvents;
    }
    public void setShowMeetAndGreet(Boolean hideMeetAndGreet) {
        this.showMeetAndGreet = hideMeetAndGreet;
    }
    public void setShowClinicEvents(Boolean hideClinicEvents) {
        this.showClinicEvents = hideClinicEvents;
    }
    public void setShowAlbumListen(Boolean hideAlbumListen) {
        this.showAlbumListen = hideAlbumListen;
    }

    public void setshowMust(Boolean showMustValue) {
        //Log.d("Settings", "Setting the showMust value to " + String.valueOf(showMustValue));
        this.showMust = showMustValue;
    }
    public void setshowMight(Boolean showMightValue) {
        this.showMight = showMightValue;
    }
    public void setshowWont(Boolean showWontValue) {
        this.showWont = showWontValue;
    }
    public void setshowUnknown(Boolean showUnknownValue) {
        this.showUnknown = showUnknownValue;
    }

    public void setHideExpiredEvents(Boolean value) {
        this.hideExpiredEvents = value;
    }
    public void setPromptForAttendedStatus(Boolean value) {
        this.promptForAttendedStatus = value;
    }

    public void setEventYearToLoad(String value) {
        this.eventYearToLoad = value;
    }

    public void setShowWillAttend(Boolean showWillAttendValue) {
        Log.d("FILTER_DEBUG", "⚠️ CHANGING getShowWillAttend from " + this.showWillAttend + " to " + showWillAttendValue);
        Log.d("FILTER_DEBUG", "⚠️ STACK TRACE: " + Log.getStackTraceString(new Exception("Stack trace for setShowWillAttend call")));
        this.showWillAttend = showWillAttendValue;
    }

    public void setAlertForSpecialEvents(Boolean alertForSpecialEvents) {
        this.alertForSpecialEvents = alertForSpecialEvents;
    }

    public Boolean getAlertForMeetAndGreet() {
        return alertForMeetAndGreet;
    }

    public void setAlertForMeetAndGreet(Boolean alertForMeetAndGreet) {
        this.alertForMeetAndGreet = alertForMeetAndGreet;
    }

    public Boolean getAlertForClinics() {
        return alertForClinics;
    }

    public void setAlertForClinics(Boolean alertForClinics) {
        this.alertForClinics = alertForClinics;
    }

    public Boolean getAlertForListeningParties() {
        return alertForListeningParties;
    }

    public void setUseLastYearsData(Boolean useLastYearsData) {
        this.useLastYearsData = useLastYearsData;
    }

    public Boolean getUseLastYearsData() {
        return useLastYearsData;
    }

    public void setAlertForListeningParties(Boolean alertForListeningParties) {
        this.alertForListeningParties = alertForListeningParties;
    }

    public Integer getMinBeforeToAlert() {
        return minBeforeToAlert;
    }

    public void setMinBeforeToAlert(Integer minBeforeToAlert) {
        this.minBeforeToAlert = minBeforeToAlert;
    }

    public String getArtsistsUrl() {
        return artsistsUrl;
    }
    public void setArtsistsUrl(String artsistsUrl) {
        this.artsistsUrl = artsistsUrl;
    }

    public String getPointerUrl() {
        return pointerUrl;
    }

    public void setPointerUrl(String pointerUrl) {
        this.pointerUrl = pointerUrl;
    }

    public String getScheduleUrl() {
        return scheduleUrl;
    }

    public void setScheduleUrl(String scheduleUrl) {
        this.scheduleUrl = scheduleUrl;
    }

    public String getDescriptionMapUrl() {
        return descriptionMapUrl;
    }

    public void setDescriptionMapUrl(String descriptionMapUrl) {
        this.descriptionMapUrl = descriptionMapUrl;
    }

    public Boolean getNoteFontSizeLarge() {
        if (noteFontSizeLarge == null) {
            noteFontSizeLarge = false;
        }
        return noteFontSizeLarge;
    }

    public void setNoteFontSizeLarge(Boolean noteFontSizeLarge) {
        this.noteFontSizeLarge = noteFontSizeLarge;
    }

    public Boolean getOpenYouTubeApp() {
        if (openYouTubeApp == null) {
            openYouTubeApp = true;
        }
        return openYouTubeApp;
    }

    public void setOpenYouTubeApp(Boolean openYouTubeApp) {
        this.openYouTubeApp = openYouTubeApp;
    }

    public Boolean getAllLinksOpenInExternalBrowser() {
        if (allLinksOpenInExternalBrowser == null) {
            allLinksOpenInExternalBrowser = false;
        }
        return allLinksOpenInExternalBrowser;
    }

    public void setAllLinksOpenInExternalBrowser(Boolean allLinksOpenInExternalBrowser) {
        this.allLinksOpenInExternalBrowser = allLinksOpenInExternalBrowser;
    }
}

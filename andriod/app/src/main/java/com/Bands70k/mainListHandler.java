package com.Bands70k;

import android.util.Log;
import android.widget.ArrayAdapter;
import android.widget.ListAdapter;
import android.widget.TextView;

import androidx.appcompat.widget.SearchView;
import androidx.collection.ArraySet;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;


/**
 * Handles the main list of bands, including sorting, filtering, and display logic.
 * Created by rdorn on 5/29/16.
 */
public class mainListHandler {

    private final String TAG = "mainListHandler";

    public String sortedBy;
    public List<String> sortableBandNames = new ArrayList<String>();
    public List<String> bandNamesIndex = new ArrayList<String>();

    public ListAdapter arrayAdapter;
    public showBands showBands;
    public Integer numberOfEvents = 0;
    public Integer numberOfUnofficalEvents = 0;
    private Integer altNumberOfBands = 0;
    private Integer numberOfBands = 0;

    public Integer allUpcomingEvents = 0;

    /**
     * Default constructor for mainListHandler.
     */
    public mainListHandler(){ }

    /**
     * Constructor for mainListHandler with showBands reference.
     * @param showBandsValue The showBands activity instance.
     */
    public mainListHandler(showBands showBandsValue){
        showBands = showBandsValue;
    }

    private showsAttended attendedHandler = new showsAttended();

    private Map<Integer,String> attendedListMap = new HashMap<Integer,String>();

    /**
     * Gets the list of sortable band names.
     * @return The list of sortable band names.
     */
    public List<String> getSortableBandNames(){

        return this.sortableBandNames;
    }


    /**
     * Populates band info and applies filters, returning the sorted list.
     * @param bandInfo The BandInfo instance.
     * @param bandList The list of band names.
     * @return The sorted and filtered list of band names.
     */
    public List<String> populateBandInfo(BandInfo bandInfo, ArrayList<String> bandList){

        Log.d("loadingpopulateBandInfo", "From live data");
        arrayAdapter = new ArrayAdapter<String>(showBands, R.layout.bandlist70k, bandList);

        List<String> bandPresent = new ArrayList<String>();
        staticVariables.showsIwillAttend = 0;

        Set<String> allBands = new ArraySet<>();

        if (BandInfo.scheduleRecords != null) {
            for (String bandName : bandInfo.scheduleRecords.keySet()) {
                if ( staticVariables.searchCriteria.isEmpty() == false) {
                    Log.d("searchCriteria", "Doing lookup using " + staticVariables.searchCriteria);
                    if (bandName.toUpperCase().contains(staticVariables.searchCriteria.toUpperCase()) == false) {
                        Log.d("searchCriteria", "Skipping " + bandName);
                        continue;
                    } else {
                        Log.d("searchCriteria", "Allowing " + bandName);
                    }
                }

                for (Long timeIndex : BandInfo.scheduleRecords.get(bandName).scheduleByTime.keySet()) {
                    if (staticVariables.preferences.getSortByTime() == true) {

                        Long endTime = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getEpochEnd();
                        Log.d("scheduleInfo","Start time is " + String.valueOf(timeIndex) + " EndTime is " + String.valueOf(endTime));
                        if (timeIndex > endTime){
                            endTime = endTime + (3600000 * 24);
                        }
                        if (endTime > System.currentTimeMillis() || staticVariables.preferences.getHideExpiredEvents() == false){
                            allUpcomingEvents++;
                            if (applyFilters(bandName, timeIndex) == true) {
                                sortableBandNames.add(String.valueOf(timeIndex) + ":" + bandName);
                                bandPresent.add(bandName);
                                numberOfEvents++;
                                Log.d("countInfo", "eventType is  " + BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getShowType());
                                if (BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getShowType().equals(staticVariables.unofficalEvent) ||
                                        BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getShowType().equals(staticVariables.unofficalEventOld)){
                                    numberOfUnofficalEvents = numberOfUnofficalEvents + 1;
                                }
                            }
                        }
                    } else {
                        Log.d("scheduleInfo", "Sort alphbetically, bandname is " + bandName);
                        Long endTime = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getEpochEnd();
                        if (timeIndex > endTime){
                            endTime = endTime + (3600000 * 24);
                        }
                        if (endTime > System.currentTimeMillis() || staticVariables.preferences.getHideExpiredEvents() == false) {
                            allUpcomingEvents++;
                            if (applyFilters(bandName, timeIndex) == true) {
                                sortableBandNames.add(bandName + ":" + String.valueOf(timeIndex));
                                bandPresent.add(bandName);
                                numberOfEvents++;
                                Log.d("countInfo", "bandName is " + bandName + " eventType is  " + BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getShowType());
                                if (BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getShowType().equals(staticVariables.unofficalEvent) ||
                                        BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getShowType().equals(staticVariables.unofficalEventOld)){
                                    numberOfUnofficalEvents = numberOfUnofficalEvents + 1;
                                }
                            }
                        }
                    }
                }
            }
            Collections.sort(sortableBandNames);
            Log.d("populateBandInfo", "BandList has this many enties " + String.valueOf(bandList.size()));
            for (String bandName : bandList){

                if ( staticVariables.searchCriteria.isEmpty() == false) {
                    Log.d("searchCriteria", "2 Doing lookup using " + staticVariables.searchCriteria);
                    if (bandName.toUpperCase().contains(staticVariables.searchCriteria.toUpperCase()) == false) {
                        Log.d("searchCriteria", "2 Skipping " + bandName);
                        continue;
                    } else {
                        Log.d("searchCriteria", "2 Allowing " + bandName);
                    }
                }
                if (staticVariables.preferences.getShowWillAttend() == false) {
                    if (bandPresent.contains(bandName) == false) {
                        // Only add artists to bottom if they have expired events that would have passed current filters
                        if (shouldShowArtistWithExpiredEvents(bandName)) {
                            sortableBandNames.add(bandName + ":");
                            if (numberOfEvents == 0) {
                                numberOfBands++;
                            }
                            altNumberOfBands++;
                        }
                    }
                }
            }

        } else {
            sortableBandNames = bandList;
            numberOfBands = bandList.size();
            Collections.sort(sortableBandNames);
        }

        turnSortedListIntoArrayAdapter();

        //ensure that if there is no list for getShowWillAttend(), we turn this off and recollect
        if (sortableBandNames.isEmpty() && staticVariables.preferences.getShowWillAttend() == true){
            staticVariables.preferences.setShowWillAttend(false);
            sortableBandNames = populateBandInfo(bandInfo, bandList);
        }

        TextView bandCount = (TextView) showBands.findViewById(R.id.headerBandCount);
        String headerText = this.getSizeDisplay();
        Log.d("HeaderText", "Setting headerBandCount TextView to: " + headerText);
        Log.d("HeaderText", "FestivalConfig appName: " + FestivalConfig.getInstance().appName);
        bandCount.setText(headerText);

        Log.d("showsIwillAttend", "staticVariables.showsIwillAttend is " + staticVariables.showsIwillAttend);

        if (sortableBandNames.size() == 0){
            String emptyDataMessage = staticVariables.context.getResources().getString(R.string.data_filter_issue);
            sortableBandNames.add(emptyDataMessage);
        }

        //FileHandler70k.writeObject(this, FileHandler70k.bandListCache);
        return sortableBandNames;
    }

    /**
     * Applies all filters to a band at a given time index.
     * @param bandName The band name.
     * @param timeIndex The time index.
     * @return True if the band passes all filters, false otherwise.
     */
    private boolean applyFilters(String bandName, Long timeIndex) {

        boolean status = true;

        if (filterByWillAttend(bandName, timeIndex) == true){
            staticVariables.showsIwillAttend = staticVariables.showsIwillAttend + 1;
        }

        if (staticVariables.preferences.getShowWillAttend() == true) {
            status = filterByWillAttend(bandName, timeIndex);

        } else if (timeIndex == null){
            if (checkFiltering(bandName) == true) {
                status = true;
            } else {
                status = false;
            }
        } else {

            status = false;

            if (checkFiltering(bandName) == true){
                if (filterByEventType(BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getShowType()) == true) {
                    if (filterByVenue(BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getShowLocation()) == true) {
                        status = true;
                    }
                }
            }
        }
        Log.d("applyFilter", "bandName = " + bandName + " timeIndex = " + timeIndex.toString() + " status = " + status);
        return status;
    }

    private boolean filterByWillAttend(String bandName, Long timeIndex){

        boolean status = true;

        String eventYear = String.valueOf(staticVariables.eventYear);
        if (timeIndex == null){
            status = false;
        } else {
            String showType = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getShowType();
            String location = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getShowLocation();
            String startTime = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getStartTimeString();
            String attendedStatus = staticVariables.attendedHandler.getShowAttendedStatus(bandName, location, startTime, showType, eventYear);

            if (attendedStatus.equals(staticVariables.sawNoneStatus)) {
                status = false;
            }
        }

        return status;
    }

    private boolean filterByVenue(String venue){

        Boolean showVenue = false;
        Log.d("VenueFilter", "Venue is " + venue);

        // Get the current festival configuration
        FestivalConfig festivalConfig = FestivalConfig.getInstance();
        List<String> configuredVenues = festivalConfig.getAllVenueNames();

        // Check if this venue is one of the configured festival venues
        boolean isConfiguredVenue = false;
        for (String configuredVenue : configuredVenues) {
            if (venue.equals(configuredVenue)) {
                // Check if this specific venue is enabled
                showVenue = getVenueShowState(configuredVenue);
                isConfiguredVenue = true;
                Log.d("VenueFilter", "Configured venue " + configuredVenue + " show state: " + showVenue);
                break;
            }
        }
        
        // If not a configured venue, treat as "Other"
        if (!isConfiguredVenue) {
            showVenue = staticVariables.preferences.getShowOtherShows();
            Log.d("VenueFilter", "Other venue '" + venue + "' show state: " + showVenue);
        }

        return showVenue;
    }
    
    /**
     * Get the show state for a specific venue using the dynamic preference system
     */
    private boolean getVenueShowState(String venueName) {
        return staticVariables.preferences.getShowVenueEvents(venueName);
    }

    private boolean filterByEventType(String eventType){

        Boolean showEvent = false;
        Log.d("EventFilter", "EventType is " + eventType);

        if ((eventType.equals(staticVariables.specialEvent) || eventType.equals(staticVariables.karaoekeEvent)) && staticVariables.preferences.getShowSpecialEvents() == true){
            Log.d("EventFilter", "preferences.getHideSpecialEvents() is true");
            showEvent = true;

        } else if (eventType.equals(staticVariables.meetAndGreet) && staticVariables.preferences.getShowMeetAndGreet() == true){
            Log.d("EventFilter", "preferences.getHideMeetAndGreet() is true");
            showEvent = true;

        } else if (eventType.equals(staticVariables.clinic) && staticVariables.preferences.getShowClinicEvents() == true){
            Log.d("EventFilter", "preferences.getHideClinicEvents() is true");
            showEvent = true;

        } else if (eventType.equals(staticVariables.listeningEvent) && staticVariables.preferences.getShowAlbumListen() == true){
            Log.d("EventFilter", "preferences.getHideAlbumListen() is true");
            showEvent = true;

        } else if ((eventType.equals(staticVariables.unofficalEvent) || eventType.equals(staticVariables.unofficalEventOld))&& staticVariables.preferences.getShowUnofficalEvents() == true){
            Log.d("EventFilter", "preferences.getShowUnofficalEvents() is true");
            showEvent = true;

        } else if (eventType.equals("Show")) {
            showEvent = true;

        } else {
            Log.d("EventFilter", "No hide preferences are set");
        }

        return showEvent;
    }

    public String getAttendedListMap(Integer index){
        return attendedListMap.get(index);
    }

    private void turnSortedListIntoArrayAdapter(){

        ArrayList<String> displayableBandList = new ArrayList<String>();

        Integer counter = 0;
        for (String bandIndex: sortableBandNames){
            Log.d(TAG, "bandIndex=" + bandIndex);
            String bandName = getBandNameFromIndex(bandIndex);
            Long timeIndex = getBandTimeFromIndex(bandIndex);

            attendedListMap.put(counter, bandName + ":" + timeIndex);
            String line = buildLines(timeIndex, bandName);

            if (checkFiltering(bandName) == true || staticVariables.preferences.getShowWillAttend() == true) {
                displayableBandList.add(line);
                bandNamesIndex.add(bandName);
                counter = counter + 1;
            }
        }

        //setTextAppearance(context, android.R.attr.textAppearanceMedium)
        arrayAdapter = new ArrayAdapter<String>(showBands, R.layout.bandlist70k, displayableBandList);
    }

    public String getBandNameFromIndex(String value){

        Log.d("getBandNameFromIndex", "getBandNameFromIndex value is " + value);
        String[] indexData = value.split(":");

        if (indexData.length != 0) {
            if (isLong(indexData[0]) == false) {
                return indexData[0];

            } else if (indexData.length == 2) {
                if (isLong(indexData[1]) == false) {
                    return indexData[1];
                }
            }
        }
        return value;
    }

    private Long getBandTimeFromIndex(String value){

        String[] indexData = value.split(":");
        Long timeIndex = Long.valueOf(0);

        if (indexData.length != 0) {
            if (isLong(indexData[0]) == true) {
                return Long.valueOf(indexData[0]);

            } else if (indexData.length == 2) {
                if (isLong(indexData[1]) == true) {
                    return Long.valueOf(indexData[1]);
                }
            }
        }

        return timeIndex;
    }

    /**
     * Returns true if any real filter (not just search) is active.
     */
    private boolean isAnyFilterActive() {
        // Check status filters
        boolean statusFiltersDefault = (staticVariables.preferences.getShowMust() &&
                 staticVariables.preferences.getShowMight() &&
                 staticVariables.preferences.getShowWont() &&
                 staticVariables.preferences.getShowUnknown() &&
                 !staticVariables.preferences.getShowWillAttend());
                 
        // Check event type filters
        boolean eventTypeFiltersDefault = (staticVariables.preferences.getShowSpecialEvents() &&
                 staticVariables.preferences.getShowMeetAndGreet() &&
                 staticVariables.preferences.getShowClinicEvents() &&
                 staticVariables.preferences.getShowAlbumListen() &&
                 staticVariables.preferences.getShowUnofficalEvents());
                 
        // Check venue filters using dynamic system
        boolean venueFiltersDefault = true;
        FestivalConfig festivalConfig = FestivalConfig.getInstance();
        java.util.List<String> configuredVenues = festivalConfig.getAllVenueNames();
        
        // Check all configured venues
        for (String venueName : configuredVenues) {
            if (!staticVariables.preferences.getShowVenueEvents(venueName)) {
                venueFiltersDefault = false;
                break;
            }
        }
        // Also check "Other" venues
        if (!staticVariables.preferences.getShowVenueEvents("Other")) {
            venueFiltersDefault = false;
        }
        
        // Return true if ANY filter is active (not in default state)
        return !(statusFiltersDefault && eventTypeFiltersDefault && venueFiltersDefault);
    }
    
    /**
     * Determines if an artist should be shown at the bottom of the list due to having expired events.
     * This should ONLY happen when:
     * 1. The artist has events that have passed (expired events)
     * 2. The user has "Hide Expired Events" set to true
     * 3. The filtering is NOT filtering out those expired records (meaning if expired events were shown, they would pass the current filters)
     */
    private boolean shouldShowArtistWithExpiredEvents(String bandName) {
        // Only proceed if Hide Expired Events is enabled
        if (!staticVariables.preferences.getHideExpiredEvents()) {
            return false;
        }
        
        // Check if this artist has any expired events
        boolean hasExpiredEvents = false;
        boolean expiredEventsWouldPassFilters = false;
        
        if (BandInfo.scheduleRecords.containsKey(bandName)) {
            for (Long timeIndex : BandInfo.scheduleRecords.get(bandName).scheduleByTime.keySet()) {
                Long endTime = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getEpochEnd();
                if (timeIndex > endTime) {
                    endTime = endTime + (3600000 * 24);
                }
                
                // Check if this is an expired event
                if (endTime <= System.currentTimeMillis()) {
                    hasExpiredEvents = true;
                    
                    // Check if this expired event would pass the current filters (ignoring the expiration check)
                    if (applyFiltersIgnoringExpiration(bandName, timeIndex)) {
                        expiredEventsWouldPassFilters = true;
                        break; // Found at least one expired event that would pass filters
                    }
                }
            }
        }
        
        // Only show at bottom if artist has expired events AND those events would have passed current filters
        boolean result = hasExpiredEvents && expiredEventsWouldPassFilters;
        
        if (result) {
            Log.d("ExpiredArtists", "Adding " + bandName + " to bottom - has expired events that would pass current filters");
        }
        
        return result;
    }
    
    /**
     * Applies all current filters except the expiration check.
     * This is used to determine if expired events would have passed the current filtering criteria.
     * Replicates the logic from applyFilters() but ignores the "will attend" filter since we're checking expired events.
     */
    private boolean applyFiltersIgnoringExpiration(String bandName, Long timeIndex) {
        // Apply search criteria first
        if (staticVariables.searchCriteria.isEmpty() == false) {
            if (bandName.toUpperCase().contains(staticVariables.searchCriteria.toUpperCase()) == false) {
                return false;
            }
        }
        
        // If showing only attended events, skip this check for expired events
        // (we're trying to see if the event would have been shown if it wasn't expired)
        if (staticVariables.preferences.getShowWillAttend() == true) {
            // For expired events, we assume they would pass the "will attend" filter 
            // since we're checking if they should be shown at the bottom
            return true;
        }
        
        // Apply the same logic as applyFilters() but for expired events
        if (timeIndex == null) {
            // For bands with no schedule, just check ranking filters
            return checkFiltering(bandName);
        } else {
            // For scheduled events, check ranking, event type, and venue filters
            if (checkFiltering(bandName)) {
                if (filterByEventType(BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getShowType())) {
                    if (filterByVenue(BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getShowLocation())) {
                        return true;
                    }
                }
            }
        }
        
        return false;
    }

    public String getSizeDisplay() {

        staticVariables.filteringInPlace = false;
        String displayText = "";
        String yearDisplay = "";

        String filteringText = "";

        // Only show (Filtering) if a real filter is active
        if (isAnyFilterActive()) {
            filteringText = " (" + staticVariables.context.getResources().getString(R.string.Filtering) + ")";
            staticVariables.filteringInPlace = true;
        } else {
            staticVariables.filteringInPlace = false;
        }

        Log.d("Setup header Text Bands", "Filtering in place set to " + String.valueOf(staticVariables.filteringInPlace));

        if (String.valueOf(staticVariables.preferences.getEventYearToLoad()).equals("Current") == false){
            yearDisplay = "(" + String.valueOf(staticVariables.preferences.getEventYearToLoad()) + ")";
        }
        if (numberOfBands != 0) {
            staticVariables.showEventButtons = false;
            staticVariables.showUnofficalEventButtons = false;

            displayText = yearDisplay + " " + numberOfBands + " " + staticVariables.context.getString(R.string.Bands) + " " + filteringText;
            staticVariables.staticBandCount = Integer.valueOf(numberOfBands);

        } else if (numberOfUnofficalEvents == numberOfEvents){
            staticVariables.showEventButtons = false;
            staticVariables.showUnofficalEventButtons = true;
            displayText = yearDisplay + " " + altNumberOfBands + " " + staticVariables.context.getString(R.string.Bands) +  filteringText;
            staticVariables.staticBandCount = Integer.valueOf(altNumberOfBands);

        } else if (numberOfEvents != 0) {
            staticVariables.showEventButtons = true;
            staticVariables.showUnofficalEventButtons = true;
            displayText = yearDisplay + " " + numberOfEvents + " " + staticVariables.context.getString(R.string.Events) + filteringText;
            staticVariables.staticBandCount = Integer.valueOf(numberOfEvents);

        } else {
            staticVariables.showEventButtons = false;
            staticVariables.showUnofficalEventButtons = false;

            // Show the festival app name when no data is available
            String appName = FestivalConfig.getInstance().appName;
            Log.d("HeaderText", "Setting header text with appName: " + appName);
            displayText = yearDisplay + " " + appName + "!";
            staticVariables.staticBandCount = 0;
        }

        return displayText;
    }

    public String getStartTime(String bandName, Long timeIndex){
        return BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getStartTimeString();
    }
    public String getLocation(String bandName, Long timeIndex){
        return BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getShowLocation();
    }
    public String getEventType(String bandName, Long timeIndex){
        return BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getShowType();
    }

    private String buildLines(Long timeIndex,String bandName){
        //attendedHandler.loadShowsAttended();
        String line = null;
        Log.d(TAG, "buildLines - timeIndex = " + String.valueOf(timeIndex) + " bandName of " +  bandName);
        String eventYear = String.valueOf(staticVariables.eventYear);
        if (timeIndex > 0){
            String rankIcon = rankStore.getRankForBand(bandName);
            line = rankIcon;

            if (!rankStore.getRankForBand(bandName).equals("")) {
                line += " - ";
            }
            if (BandInfo.scheduleRecords == null){
                return("");
            }
            if (BandInfo.scheduleRecords.get(bandName) == null){
                return("");
            }

            if (BandInfo.scheduleRecords.get(bandName) != null && BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex) != null) {

                String location = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getShowLocation();
                String startTime = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getStartTimeString();
                String eventType = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getShowType();
                String attendedIcon = attendedHandler.getShowAttendedIcon(bandName, location, startTime, eventType, eventYear);

                line = attendedIcon + " " + rankIcon;
                if (!rankStore.getRankForBand(bandName).equals("")) {
                    line += " - ";
                }
                line += bandName + " - ";
                line += dateTimeFormatter.formatScheduleTime(startTime) + " ";
                line += location  + " - ";
                line += BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getShowDay() + " ";
                line += " " + staticVariables.getEventTypeIcon(eventType);
            }
        } else {

            line = rankStore.getRankForBand(bandName);
            if (!rankStore.getRankForBand(bandName).equals("")) {
                line += " - ";
            }
            line += bandName;
        }

        return line;
    }

    private boolean checkFiltering(String bandName){

        Boolean returnValue = true;


        if (rankStore.getRankForBand(bandName).equals(staticVariables.mustSeeIcon)){
            if (staticVariables.preferences.getShowMust() == true){
                returnValue = true;
            } else {
                returnValue = false;
            }

        } else if (rankStore.getRankForBand(bandName).equals(staticVariables.mightSeeIcon)){
            if (staticVariables.preferences.getShowMight() == true){
                returnValue = true;
            } else {
                returnValue = false;
            }
        } else if (rankStore.getRankForBand(bandName).equals(staticVariables.wontSeeIcon)){
            if (staticVariables.preferences.getShowWont() == true){
                returnValue = true;
            } else {
                returnValue = false;
            }
        } else {
            if (staticVariables.preferences.getShowUnknown() == true) {
                returnValue = true;
            } else {
                returnValue = false;
            }
        }

        Log.d(TAG, "FILTERING - " + rankStore.getRankForBand(bandName) + " " + staticVariables.mustSeeIcon + " " + String.valueOf(returnValue));
        return returnValue;
    }

    public static boolean isLong(String value) {
        try {
            Long.parseLong(value);
        } catch(Exception e) {
            Log.d("mainListHandler", "long of " + value + " is false");
            return false;
        }
        // only got here if we didn't return false
        if (value.length() < 10){
            return false;
        }
        Log.d("mainListHandler", "long of " + value + " is true");
        return true;
    }

}

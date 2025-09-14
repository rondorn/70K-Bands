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

        Log.d("CRITICAL_DEBUG", "🎯 GET_SORTABLE: getSortableBandNames() called, returning " + 
              (this.sortableBandNames != null ? this.sortableBandNames.size() : "NULL") + " items");
        Log.d("CRITICAL_DEBUG", "🎯 GET_SORTABLE: Current sortByTime preference = " + staticVariables.preferences.getSortByTime());
        Log.d("CRITICAL_DEBUG", "🎯 GET_SORTABLE: sortableBandNames is " + (this.sortableBandNames == null ? "NULL" : (this.sortableBandNames.isEmpty() ? "EMPTY" : "POPULATED with " + this.sortableBandNames.size() + " items")));
        return this.sortableBandNames;
    }
    
    /**
     * Clear the cached sortableBandNames to force fresh data processing
     */
    public void clearCache(){
        Log.d("CACHE_DEBUG", "🧹 Clearing sortableBandNames cache (was " + (sortableBandNames != null ? sortableBandNames.size() : 0) + " items)");
        if (this.sortableBandNames != null) {
            this.sortableBandNames.clear();
        }
    }


    /**
     * Populates band info and applies filters, returning the sorted list.
     * @param bandInfo The BandInfo instance.
     * @param bandList The list of band names.
     * @return The sorted and filtered list of band names.
     */
    public List<String> populateBandInfo(BandInfo bandInfo, ArrayList<String> bandList){

        Log.d("FILTER_DEBUG", "🏁 populateBandInfo() called with " + bandList.size() + " bands");
        Log.d("FILTER_DEBUG", "🏁 ENTRY STATE: getShowWillAttend = " + staticVariables.preferences.getShowWillAttend());
        Log.d("loadingpopulateBandInfo", "From live data");
        arrayAdapter = new ArrayAdapter<String>(showBands, R.layout.bandlist70k, bandList);

        List<String> bandPresent = new ArrayList<String>();
        staticVariables.showsIwillAttend = 0;

        Set<String> allBands = new ArraySet<>();

        if (BandInfo.scheduleRecords != null && !BandInfo.scheduleRecords.isEmpty()) {
            Log.d("FILTER_DEBUG", "🔍 BandInfo.scheduleRecords has " + bandInfo.scheduleRecords.keySet().size() + " bands");
            for (String bandName : bandInfo.scheduleRecords.keySet()) {
                Log.d("FILTER_DEBUG", "🔍 Processing band: " + bandName);
                if ( staticVariables.searchCriteria.isEmpty() == false) {
                    Log.d("searchCriteria", "Doing lookup using " + staticVariables.searchCriteria);
                    if (bandName.toUpperCase().contains(staticVariables.searchCriteria.toUpperCase()) == false) {
                        Log.d("searchCriteria", "Skipping " + bandName);
                        continue;
                    } else {
                        Log.d("searchCriteria", "Allowing " + bandName);
                    }
                }

                Log.d("FILTER_DEBUG", "🔍 Band " + bandName + " has " + BandInfo.scheduleRecords.get(bandName).scheduleByTime.keySet().size() + " time slots");
                for (Long timeIndex : BandInfo.scheduleRecords.get(bandName).scheduleByTime.keySet()) {
                    if (staticVariables.preferences.getSortByTime() == true) {

                        Long endTime = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getEpochEnd();
                        Log.d("scheduleInfo","Start time is " + String.valueOf(timeIndex) + " EndTime is " + String.valueOf(endTime));
                        Log.d("FILTER_DEBUG", "⏰ TIME CHECK for " + bandName + ": timeIndex=" + timeIndex + ", endTime=" + endTime + ", currentTime=" + System.currentTimeMillis());
                        if (timeIndex > endTime){
                            endTime = endTime + (3600000 * 24);
                            Log.d("FILTER_DEBUG", "⏰ TIME ADJUSTED for " + bandName + ": new endTime=" + endTime);
                        }
                        Log.d("FILTER_DEBUG", "⏰ getHideExpiredEvents: " + staticVariables.preferences.getHideExpiredEvents());
                        boolean timeCondition = endTime > System.currentTimeMillis() || staticVariables.preferences.getHideExpiredEvents() == false;
                        Log.d("FILTER_DEBUG", "⏰ TIME CONDITION for " + bandName + ": " + timeCondition);
                        if (timeCondition){
                            allUpcomingEvents++;
                            Log.d("FILTER_DEBUG", "📞 SORTBYTIME: Calling applyFilters for band: " + bandName + ", timeIndex: " + timeIndex);
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
                        Log.d("FILTER_DEBUG", "⏰ ALPHA TIME CHECK for " + bandName + ": timeIndex=" + timeIndex + ", endTime=" + endTime + ", currentTime=" + System.currentTimeMillis());
                        if (timeIndex > endTime){
                            endTime = endTime + (3600000 * 24);
                            Log.d("FILTER_DEBUG", "⏰ ALPHA TIME ADJUSTED for " + bandName + ": new endTime=" + endTime);
                        }
                        Log.d("FILTER_DEBUG", "⏰ ALPHA getHideExpiredEvents: " + staticVariables.preferences.getHideExpiredEvents());
                        boolean timeCondition = endTime > System.currentTimeMillis() || staticVariables.preferences.getHideExpiredEvents() == false;
                        Log.d("FILTER_DEBUG", "⏰ ALPHA TIME CONDITION for " + bandName + ": " + timeCondition);
                        if (timeCondition) {
                            allUpcomingEvents++;
                            Log.d("FILTER_DEBUG", "📞 SORTALPHA: Calling applyFilters for band: " + bandName + ", timeIndex: " + timeIndex);
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
            // Separate events and bands for proper mixed display
            List<String> eventsList = new ArrayList<String>();
            List<String> bandsList = new ArrayList<String>();
            
            // Separate events from bands
            // Events can have two formats:
            // - Sort by time: "timeIndex:bandName" (timeIndex > 0)
            // - Sort alphabetically: "bandName:timeIndex" (timeIndex > 0)
            // Bands with zero events: "bandName:" (no timeIndex or timeIndex = 0)
            for (String item : sortableBandNames) {
                String[] parts = item.split(":");
                boolean isEvent = false;
                
                if (parts.length >= 2) {
                    // Check if first part is a timeIndex (sort by time format)
                    try {
                        Long timeIndex = Long.valueOf(parts[0]);
                        if (timeIndex > 0) {
                            eventsList.add(item);
                            isEvent = true;
                            Log.d("FILTER_DEBUG", "📅 Found EVENT (time format): " + item);
                        }
                    } catch (NumberFormatException e) {
                        // First part is not a number, check if second part is a timeIndex (alphabetical sort format)
                        try {
                            Long timeIndex = Long.valueOf(parts[1]);
                            if (timeIndex > 0) {
                                eventsList.add(item);
                                isEvent = true;
                                Log.d("FILTER_DEBUG", "📅 Found EVENT (alpha format): " + item);
                            }
                        } catch (NumberFormatException e2) {
                            // Neither part is a valid timeIndex > 0, this is a band with zero events
                            Log.d("FILTER_DEBUG", "🎵 Item has no valid timeIndex: " + item);
                        }
                    }
                } else {
                    Log.d("FILTER_DEBUG", "🎵 Item has insufficient parts: " + item);
                }
                
                if (!isEvent) {
                    bandsList.add(item);
                    Log.d("FILTER_DEBUG", "🎵 Added to BANDS list: " + item);
                }
            }
            
            // Sort events according to user preference (time or alphabetical)
            // DEBUG: Check the exact preference value at branching point
        boolean sortByTimeValue = staticVariables.preferences.getSortByTime();
        Log.d("CRITICAL_DEBUG", "🔍 BRANCHING POINT: getSortByTime() = " + sortByTimeValue);
        Log.d("CRITICAL_DEBUG", "🔍 PREFERENCE OBJECT: " + (staticVariables.preferences != null ? "NOT NULL" : "NULL"));
        if (staticVariables.preferences != null) {
            Log.d("CRITICAL_DEBUG", "🔍 PREFERENCE CLASS: " + staticVariables.preferences.getClass().getSimpleName());
        }
        
        if (sortByTimeValue) {
                // Events are already sorted by time due to the timeIndex prefix (e.g., "1234567890:BandName")
                Collections.sort(eventsList);
                Log.d("FILTER_DEBUG", "🕐 Sorting events by TIME");
            } else {
                // For alphabetical sorting, we need to sort by band name, not time
                Log.d("CRITICAL_DEBUG", "🔤 BEFORE alphabetical sort: eventsList.size() = " + eventsList.size());
                Log.d("CRITICAL_DEBUG", "🔤 BEFORE sort - first 3 entries: " + (eventsList.size() > 0 ? eventsList.get(0) : "none") + ", " + (eventsList.size() > 1 ? eventsList.get(1) : "none") + ", " + (eventsList.size() > 2 ? eventsList.get(2) : "none"));
                Collections.sort(eventsList, (a, b) -> {
                    String bandA = getBandNameFromIndex(a);
                    String bandB = getBandNameFromIndex(b);
                    Log.d("CRITICAL_DEBUG", "🔤 Comparing: '" + bandA + "' vs '" + bandB + "'");
                    return bandA.compareToIgnoreCase(bandB);
                });
                Log.d("CRITICAL_DEBUG", "🔤 AFTER alphabetical sort: eventsList.size() = " + eventsList.size());
                Log.d("CRITICAL_DEBUG", "🔤 AFTER sort - first 3 entries: " + (eventsList.size() > 0 ? eventsList.get(0) : "none") + ", " + (eventsList.size() > 1 ? eventsList.get(1) : "none") + ", " + (eventsList.size() > 2 ? eventsList.get(2) : "none"));
                Log.d("FILTER_DEBUG", "🔤 Sorting events ALPHABETICALLY");
            }
            
            // Always sort bands alphabetically
            Collections.sort(bandsList);
            
            // Clear and rebuild sortableBandNames with proper order: events first, then bands
            sortableBandNames.clear();
            sortableBandNames.addAll(eventsList);
            
            Log.d("FILTER_DEBUG", "🏁 After schedule processing: " + eventsList.size() + " events processed");
            Log.d("populateBandInfo", "BandList has this many entries " + String.valueOf(bandList.size()));
            
            // Add bands with zero events to the bottom (always alphabetical)
            List<String> bandsWithZeroEvents = new ArrayList<String>();
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
                        // Check if band passes current filters (ranking, etc.)
                        if (applyFilters(bandName, null)) {
                            bandsWithZeroEvents.add(bandName + ":");
                            if (numberOfEvents == 0) {
                                numberOfBands++;
                            }
                            altNumberOfBands++;
                            Log.d("FILTER_DEBUG", "🎵 Adding band with zero events: " + bandName);
                        }
                    }
                }
            }
            
            // Sort bands with zero events alphabetically
            Collections.sort(bandsWithZeroEvents);
            
            // Add bands with zero events after the scheduled events
            sortableBandNames.addAll(bandsWithZeroEvents);
            
            Log.d("FILTER_DEBUG", "🎯 MIXED VIEW SUMMARY:");
            Log.d("FILTER_DEBUG", "  📅 Events: " + eventsList.size() + " (sorted by " + (staticVariables.preferences.getSortByTime() ? "TIME" : "ALPHABET") + ")");
            Log.d("FILTER_DEBUG", "  🎵 Bands with zero events: " + bandsWithZeroEvents.size() + " (sorted ALPHABETICALLY)");
            Log.d("FILTER_DEBUG", "  📊 Total items: " + sortableBandNames.size());

        } else {
            Log.d("FILTER_DEBUG", "🚨 BandInfo.scheduleRecords is NULL or EMPTY! Using raw bandList with " + bandList.size() + " bands (no schedule released yet)");
            sortableBandNames = bandList;
            numberOfBands = bandList.size();
            Collections.sort(sortableBandNames);
        }

        Log.d("CRITICAL_DEBUG", "🎯 BEFORE_ADAPTER: About to call turnSortedListIntoArrayAdapter()");
        Log.d("CRITICAL_DEBUG", "🎯 BEFORE_ADAPTER: sortableBandNames.size() = " + sortableBandNames.size());
        turnSortedListIntoArrayAdapter();

        //ensure that if there is no list for getShowWillAttend(), we turn this off and recollect
        Log.d("FILTER_DEBUG", "🔄 PRE-RECURSIVE CHECK: sortableBandNames.size() = " + sortableBandNames.size() + 
              ", getShowWillAttend = " + staticVariables.preferences.getShowWillAttend());
        if (sortableBandNames.isEmpty() && staticVariables.preferences.getShowWillAttend() == true){
            Log.d("FILTER_DEBUG", "🔄 TRIGGERING RECURSIVE CALL: Setting getShowWillAttend = false and calling populateBandInfo recursively");
            staticVariables.preferences.setShowWillAttend(false);
            Log.d("FILTER_DEBUG", "🔄 AFTER SETTING FALSE: getShowWillAttend = " + staticVariables.preferences.getShowWillAttend());
            sortableBandNames = populateBandInfo(bandInfo, bandList);
            Log.d("FILTER_DEBUG", "🔄 RECURSIVE CALL COMPLETE: returned " + sortableBandNames.size() + " bands, getShowWillAttend = " + staticVariables.preferences.getShowWillAttend());
        } else {
            Log.d("CRITICAL_DEBUG", "🎯 NO_RECURSIVE: sortableBandNames.isEmpty()=" + sortableBandNames.isEmpty() + ", getShowWillAttend()=" + staticVariables.preferences.getShowWillAttend());
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
            Log.d("FILTER_DEBUG", "🚨 NO BANDS passed filtering! Adding empty data message: " + emptyDataMessage);
        }

        Log.d("FILTER_DEBUG", "🏁 populateBandInfo() COMPLETE: " + sortableBandNames.size() + " bands passed all filters");
        Log.d("FILTER_DEBUG", "🏁 EXIT STATE: getShowWillAttend = " + staticVariables.preferences.getShowWillAttend());
        Log.d("FILTER_DEBUG", "🏁 Input bands: " + bandList.size() + ", Output bands: " + sortableBandNames.size());

        //FileHandler70k.writeObject(this, FileHandler70k.bandListCache);
        Log.d("CRITICAL_DEBUG", "🎯 POPULATE_RETURN: populateBandInfo() returning " + sortableBandNames.size() + " items");
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
        
        Log.d("FILTER_DEBUG", "🔍 applyFilters() called for band: " + bandName + ", timeIndex: " + (timeIndex != null ? timeIndex.toString() : "null"));
        Log.d("FILTER_DEBUG", "🔍 getShowWillAttend: " + staticVariables.preferences.getShowWillAttend());

        if (filterByWillAttend(bandName, timeIndex) == true){
            staticVariables.showsIwillAttend = staticVariables.showsIwillAttend + 1;
        }

        if (staticVariables.preferences.getShowWillAttend() == true) {
            status = filterByWillAttend(bandName, timeIndex);
            Log.d("FILTER_DEBUG", "🔍 Will Attend filtering: " + status);

        } else if (timeIndex == null){
            // This is the path for "Current" view when bands have no events
            boolean rankingResult = checkFiltering(bandName);
            if (rankingResult == true) {
                status = true;
            } else {
                status = false;
            }
            Log.d("FILTER_DEBUG", "🔍 NO EVENT path - Band: " + bandName + ", ranking result: " + rankingResult + ", final status: " + status);
        } else {

            status = false;
            
            boolean rankingResult = checkFiltering(bandName);
            Log.d("FILTER_DEBUG", "🔍 HAS EVENT path - Band: " + bandName + ", ranking result: " + rankingResult);

            if (rankingResult == true){
                String eventType = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getShowType();
                boolean eventTypeResult = filterByEventType(eventType);
                Log.d("FILTER_DEBUG", "🔍 Event type: '" + eventType + "', event type result: " + eventTypeResult);
                
                if (eventTypeResult == true) {
                    String venue = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(timeIndex).getShowLocation();
                    boolean venueResult = filterByVenue(venue);
                    Log.d("FILTER_DEBUG", "🔍 Venue: '" + venue + "', venue result: " + venueResult);
                    
                    if (venueResult == true) {
                        status = true;
                    }
                }
            }
        }
        Log.d("FILTER_DEBUG", "🔍 FINAL RESULT for " + bandName + ": " + status);
        Log.d("applyFilter", "bandName = " + bandName + " timeIndex = " + (timeIndex != null ? timeIndex.toString() : "null") + " status = " + status);
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

        Log.d("CRITICAL_DEBUG", "🎯 ADAPTER: Starting turnSortedListIntoArrayAdapter()");
        Log.d("CRITICAL_DEBUG", "🎯 ADAPTER: sortableBandNames.size() = " + sortableBandNames.size());

        Integer counter = 0;
        for (String bandIndex: sortableBandNames){
            Log.d(TAG, "bandIndex=" + bandIndex);
            String bandName = getBandNameFromIndex(bandIndex);
            Long timeIndex = getBandTimeFromIndex(bandIndex);

            attendedListMap.put(counter, bandName + ":" + timeIndex);
            String line = buildLines(timeIndex, bandName);

            boolean filterResult = checkFiltering(bandName);
            boolean showWillAttend = staticVariables.preferences.getShowWillAttend();
            Log.d("CRITICAL_DEBUG", "🎯 ADAPTER: Band '" + bandName + "' - filterResult=" + filterResult + ", showWillAttend=" + showWillAttend);

            if (checkFiltering(bandName) == true || staticVariables.preferences.getShowWillAttend() == true) {
                displayableBandList.add(line);
                bandNamesIndex.add(bandName);
                counter = counter + 1;
                Log.d("CRITICAL_DEBUG", "🎯 ADAPTER: Added band '" + bandName + "' to displayableBandList");
            } else {
                Log.d("CRITICAL_DEBUG", "🎯 ADAPTER: FILTERED OUT band '" + bandName + "'");
            }
        }

        Log.d("CRITICAL_DEBUG", "🎯 ADAPTER: Final displayableBandList.size() = " + displayableBandList.size());
        Log.d("CRITICAL_DEBUG", "🎯 ADAPTER: Final bandNamesIndex.size() = " + bandNamesIndex.size());

        //setTextAppearance(context, android.R.attr.textAppearanceMedium)
        arrayAdapter = new ArrayAdapter<String>(showBands, R.layout.bandlist70k, displayableBandList);
        Log.d("CRITICAL_DEBUG", "🎯 ADAPTER: Created ArrayAdapter with " + displayableBandList.size() + " items");
    }

    public String getBandNameFromIndex(String value){

        Log.d("getBandNameFromIndex", "getBandNameFromIndex value is " + value);
        String[] indexData = value.split(":");

        if (indexData.length >= 2) {
            // Use timestamp detection to identify format
            boolean firstPartIsTimestamp = isTimestamp(indexData[0]);
            boolean secondPartIsTimestamp = isTimestamp(indexData[1]);
            
            String result;
            if (firstPartIsTimestamp && !secondPartIsTimestamp) {
                // Format: "timeIndex:bandName" -> return second part (band name)
                result = indexData[1];
                Log.d("getBandNameFromIndex", "🔍 TIME FORMAT detected, returning band name: '" + result + "'");
            } else if (!firstPartIsTimestamp && secondPartIsTimestamp) {
                // Format: "bandName:timeIndex" -> return first part (band name)
                result = indexData[0];
                Log.d("getBandNameFromIndex", "🔍 ALPHA FORMAT detected, returning band name: '" + result + "'");
            } else {
                // Fallback: use sort mode
                if (staticVariables.preferences.getSortByTime()) {
                    result = indexData[1]; // Time mode: second part is band name
                    Log.d("getBandNameFromIndex", "🔍 FALLBACK TIME MODE, returning band name: '" + result + "'");
                } else {
                    result = indexData[0]; // Alphabetical mode: first part is band name
                    Log.d("getBandNameFromIndex", "🔍 FALLBACK ALPHA MODE, returning band name: '" + result + "'");
                }
            }
            return result;
        } else if (indexData.length == 1) {
            // Single part, assume it's the band name
            Log.d("getBandNameFromIndex", "🔍 SINGLE PART, returning: '" + indexData[0] + "'");
            return indexData[0];
        }
        Log.d("getBandNameFromIndex", "🔍 FALLBACK, returning original value: '" + value + "'");
        return value;
    }

    private Long getBandTimeFromIndex(String value){

        Log.d("getBandTimeFromIndex", "🔍 Processing value: " + value);
        String[] indexData = value.split(":");

        if (indexData.length >= 2) {
            // Use timestamp detection to identify format
            boolean firstPartIsTimestamp = isTimestamp(indexData[0]);
            boolean secondPartIsTimestamp = isTimestamp(indexData[1]);
            
            try {
                Long result;
                if (firstPartIsTimestamp && !secondPartIsTimestamp) {
                    // Format: "timeIndex:bandName" -> return first part (time index)
                    result = Long.valueOf(indexData[0]);
                    Log.d("getBandTimeFromIndex", "🔍 TIME FORMAT detected, returning time index: " + result);
                } else if (!firstPartIsTimestamp && secondPartIsTimestamp) {
                    // Format: "bandName:timeIndex" -> return second part (time index)
                    result = Long.valueOf(indexData[1]);
                    Log.d("getBandTimeFromIndex", "🔍 ALPHA FORMAT detected, returning time index: " + result);
                } else {
                    // Fallback: use sort mode
                    if (staticVariables.preferences.getSortByTime()) {
                        result = Long.valueOf(indexData[0]); // Time mode: first part is time index
                        Log.d("getBandTimeFromIndex", "🔍 FALLBACK TIME MODE, returning time index: " + result);
                    } else {
                        result = Long.valueOf(indexData[1]); // Alphabetical mode: second part is time index
                        Log.d("getBandTimeFromIndex", "🔍 FALLBACK ALPHA MODE, returning time index: " + result);
                    }
                }
                return result;
            } catch (NumberFormatException e) {
                Log.e("getBandTimeFromIndex", "🚨 Failed to parse time index from: " + value, e);
                return Long.valueOf(0);
            }
        }
        
        Log.d("getBandTimeFromIndex", "🔍 FALLBACK, returning 0");
        return Long.valueOf(0);
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
            Log.d("UNOFFICIAL_DEBUG", "🔧 ONLY unofficial events: numberOfUnofficalEvents=" + numberOfUnofficalEvents + ", numberOfEvents=" + numberOfEvents + ", showUnofficalEventButtons=" + staticVariables.showUnofficalEventButtons);
            displayText = yearDisplay + " " + altNumberOfBands + " " + staticVariables.context.getString(R.string.Bands) +  filteringText;
            staticVariables.staticBandCount = Integer.valueOf(altNumberOfBands);

        } else if (numberOfEvents != 0) {
            staticVariables.showEventButtons = true;
            // UNOFFICIAL EVENTS FIX: Only show unofficial events filter when unofficial events actually exist
            staticVariables.showUnofficalEventButtons = (numberOfUnofficalEvents > 0);
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
        
        String bandRank = rankStore.getRankForBand(bandName);
        Log.d("FILTER_DEBUG", "🎯 checkFiltering() for band: " + bandName + ", rank: " + bandRank);
        Log.d("FILTER_DEBUG", "🎯 Rank settings - Must:" + staticVariables.preferences.getShowMust() + 
              ", Might:" + staticVariables.preferences.getShowMight() + 
              ", Wont:" + staticVariables.preferences.getShowWont() + 
              ", Unknown:" + staticVariables.preferences.getShowUnknown());

        if (bandRank.equals(staticVariables.mustSeeIcon)){
            if (staticVariables.preferences.getShowMust() == true){
                returnValue = true;
            } else {
                returnValue = false;
            }
            Log.d("FILTER_DEBUG", "🎯 MUST SEE band - show setting: " + staticVariables.preferences.getShowMust() + ", result: " + returnValue);

        } else if (bandRank.equals(staticVariables.mightSeeIcon)){
            if (staticVariables.preferences.getShowMight() == true){
                returnValue = true;
            } else {
                returnValue = false;
            }
            Log.d("FILTER_DEBUG", "🎯 MIGHT SEE band - show setting: " + staticVariables.preferences.getShowMight() + ", result: " + returnValue);
        } else if (bandRank.equals(staticVariables.wontSeeIcon)){
            if (staticVariables.preferences.getShowWont() == true){
                returnValue = true;
            } else {
                returnValue = false;
            }
            Log.d("FILTER_DEBUG", "🎯 WONT SEE band - show setting: " + staticVariables.preferences.getShowWont() + ", result: " + returnValue);
        } else {
            if (staticVariables.preferences.getShowUnknown() == true) {
                returnValue = true;
            } else {
                returnValue = false;
            }
            Log.d("FILTER_DEBUG", "🎯 UNKNOWN rank band - show setting: " + staticVariables.preferences.getShowUnknown() + ", result: " + returnValue);
        }

        Log.d("FILTER_DEBUG", "🎯 checkFiltering() RESULT for " + bandName + ": " + returnValue);
        Log.d(TAG, "FILTERING - " + rankStore.getRankForBand(bandName) + " " + staticVariables.mustSeeIcon + " " + String.valueOf(returnValue));
        return returnValue;
    }

    /**
     * Helper method to detect if a string represents a timestamp
     * Timestamps are typically very large numbers (> 1000000)
     * Band names like "1914" will be < 1000000
     */
    private boolean isTimestamp(String value) {
        try {
            Long number = Long.valueOf(value);
            // Timestamps are typically very large numbers (> 1000000)
            // Band names like "1914" will be < 1000000
            boolean result = number > 1000000;
            Log.d("TIMESTAMP_DEBUG", "🔢 isTimestamp('" + value + "') -> number=" + number + ", result=" + result);
            return result;
        } catch (NumberFormatException e) {
            Log.d("TIMESTAMP_DEBUG", "🔢 isTimestamp('" + value + "') -> NOT A NUMBER, result=false");
            return false;
        }
    }

}

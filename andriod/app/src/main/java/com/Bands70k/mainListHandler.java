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

    public mainListHandler(){ }

    public mainListHandler(showBands showBandsValue){
        showBands = showBandsValue;
    }

    private showsAttended attendedHandler = new showsAttended();

    private Map<Integer,String> attendedListMap = new HashMap<Integer,String>();

    public List<String> getSortableBandNames(){

        return this.sortableBandNames;
    }


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
                        sortableBandNames.add(bandName + ":");
                        if (numberOfEvents == 0) {
                            numberOfBands++;
                        }
                        altNumberOfBands++;
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
        bandCount.setText(this.getSizeDisplay());

        Log.d("showsIwillAttend", "staticVariables.showsIwillAttend is " + staticVariables.showsIwillAttend);

        if (sortableBandNames.size() == 0){
            String emptyDataMessage = staticVariables.context.getResources().getString(R.string.data_filter_issue);
            sortableBandNames.add(emptyDataMessage);
        }

        //FileHandler70k.writeObject(this, FileHandler70k.bandListCache);
        return sortableBandNames;
    }

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

        if (venue.equals("Pool") && staticVariables.preferences.getShowPoolShows() == true){
            showVenue = true;

        } else if (venue.equals("Theater") && staticVariables.preferences.getShowTheaterShows() == true){
            showVenue = true;

        } else if (venue.equals("Rink") && staticVariables.preferences.getShowRinkShows()== true){
            showVenue = true;

        } else if (venue.equals("Lounge") && staticVariables.preferences.getShowLoungeShows() == true){
            showVenue = true;

        } else if ( venue.equals("Lounge") == false && venue.equals("Rink") == false &&
                    venue.equals("Theater") == false && venue.equals("Pool") == false &&
                    staticVariables.preferences.getShowOtherShows() == true){

            showVenue = true;

        } else {
            Log.d("EventFilter", "No hide preferences are set");
        }

        return showVenue;
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

    public String getSizeDisplay() {

        staticVariables.filteringInPlace = false;
        String displayText = "";
        String yearDisplay = "";

        String filteringText = "";

        Log.d("Setup header Text Events", String.valueOf(numberOfUnofficalEvents) + " - " + String.valueOf(numberOfEvents));
        Log.d("Setup header Text Events", String.valueOf(allUpcomingEvents) + " - " + String.valueOf(numberOfEvents));
        Log.d("Setup header Text Bands", String.valueOf(staticVariables.unfilteredBandCount) + " - " + String.valueOf(numberOfBands) + " - " + String.valueOf(altNumberOfBands));
        if ((Integer.valueOf(numberOfEvents) != 0 || numberOfUnofficalEvents != numberOfEvents) && Integer.valueOf(allUpcomingEvents) > Integer.valueOf(numberOfEvents)){
            filteringText = " (" +   staticVariables.context.getResources().getString(R.string.Filtering) + ")";
            staticVariables.filteringInPlace = true;
            Log.d("Setup header Text Bands", "Filtering in place 1");
        } else if (Integer.valueOf(numberOfEvents) == 0 && numberOfUnofficalEvents != numberOfEvents) {
            if (numberOfBands < staticVariables.unfilteredBandCount) {
                filteringText = " (" + staticVariables.context.getResources().getString(R.string.Filtering) + ")";
                staticVariables.filteringInPlace = true;
                Log.d("Setup header Text Bands", "Filtering in place 2");
            } else {
                staticVariables.filteringInPlace = false;
            }
        } else if (Integer.valueOf(numberOfEvents) != 0 && numberOfUnofficalEvents == numberOfEvents) {
            if (altNumberOfBands < staticVariables.unfilteredBandCount) {
                filteringText = " (" + staticVariables.context.getResources().getString(R.string.Filtering) + ")";
                staticVariables.filteringInPlace = true;
                Log.d("Setup header Text Bands", "Filtering in place 3");
            } else {
                staticVariables.filteringInPlace = false;
            }
        } else if (Integer.valueOf(numberOfEvents) == 0 && numberOfUnofficalEvents == numberOfEvents) {
            if (altNumberOfBands < staticVariables.unfilteredBandCount) {
                filteringText = " (" + staticVariables.context.getResources().getString(R.string.Filtering) + ")";
                staticVariables.filteringInPlace = true;
                Log.d("Setup header Text Bands", "Filtering in place 4");
            } else {
                staticVariables.filteringInPlace = false;
            }
        } else {
            staticVariables.filteringInPlace = false;
        }

        if (staticVariables.searchCriteria.isEmpty() == false){
            filteringText = " (" + staticVariables.context.getResources().getString(R.string.Filtering) + ")";
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

            displayText = yearDisplay + " 0 bands";
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

package com.Bands70k;

import android.util.Log;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.HashSet;

public class showsAttendedReport {

    private Map<String,Map<String,Integer>> eventCounts = new HashMap<String,Map<String,Integer>>();
    private Map<String,Map<String,Map<String,Integer>>> bandCounts = new HashMap<String,Map<String,Map<String,Integer>>>();

    public void assembleReport() {
        Log.d("showsAttendedReport", "🔍 [SHARE_REPORT] ========== STARTING EVENTS ATTENDED REPORT ==========");
        
        // CRITICAL: Always use "Default" profile for sharing reports
        // Save current active profile
        SharedPreferencesManager profileManager = SharedPreferencesManager.getInstance();
        String originalProfile = profileManager.getActivePreferenceSource();
        Log.d("showsAttendedReport", "🔍 [SHARE_REPORT] Original active profile: '" + originalProfile + "'");
        
        // Temporarily switch to "Default" profile
        if (!"Default".equals(originalProfile)) {
            Log.d("showsAttendedReport", "🔍 [SHARE_REPORT] Temporarily switching to 'Default' profile for report generation");
            profileManager.setActivePreferenceSource("Default");
        } else {
            Log.d("showsAttendedReport", "🔍 [SHARE_REPORT] Already on 'Default' profile, no switch needed");
        }

        showsAttended attendedHandler = new showsAttended();
        attendedHandler.loadShowsAttended();
        Map<String, String> showsAttendedArray = attendedHandler.getShowsAttended();

        Log.d("ShareMessage", "showsAttendedArray is " + showsAttendedArray.size());
        for (String index : showsAttendedArray.keySet()) {

            String[] indexArray = index.split(":");

            if (indexArray.length == 5){
                continue;
            }
            Log.d("ShareMessage", "index is " + index);
            String bandName = indexArray[0];
            String eventType = indexArray[4];
            Integer eventYear = Integer.valueOf(indexArray[5]);

            Log.d("ShareMessage", "index is " + eventYear + "=" + staticVariables.eventYear);

            if (eventYear.equals(staticVariables.eventYear) == false){
                continue;
            }

            Log.d("ShareMessage", "index is " + index);
            Log.d("ShareMessage", "eventType is " + eventType);
            Log.d("ShareMessage", "status is " + showsAttendedArray.get(index));

            getEventTypeCounts(eventType, showsAttendedArray.get(index));
            getBandCounts(eventType, bandName,  showsAttendedArray.get(index));

        }
        
        // CRITICAL: Restore original profile
        if (!"Default".equals(originalProfile)) {
            Log.d("showsAttendedReport", "🔍 [SHARE_REPORT] Restoring original profile: '" + originalProfile + "'");
            profileManager.setActivePreferenceSource(originalProfile);
        }
        
        Log.d("showsAttendedReport", "🔍 [SHARE_REPORT] ========== REPORT COMPLETE ==========");
    }

    public String addPlural(Integer count, String eventType){

        String message = "";



        if (count >= 2 && eventType.contentEquals(staticVariables.unofficalEvent) == false){
            message += "s";
        }

        Log.d("addPlural", "eventType is '" + eventType + "' - '" + staticVariables.unofficalEvent + "' - " + message);

        return message;

    }

    public String buildMessage() {
        return buildEventsAttendedReport();
    }
    
    /**
     * Builds an enhanced events attended report with venue information and emojis using localized strings.
     * @return The formatted events attended report as a string.
     */
    private String buildEventsAttendedReport() {
        String message = "🤘 " + staticVariables.context.getString(R.string.HereAreMy) + " " + FestivalConfig.getInstance().appName + " - " + staticVariables.context.getString(R.string.EventsAttended) + "\n\n";
        
        // Define event type order and emojis
        String[] eventTypeOrder = {"Show", "Meet and Greet", "Clinic", "Special Event", "Cruiser Organized", "Unofficial Event"};
        Map<String, String> eventTypeEmojis = new HashMap<>();
        eventTypeEmojis.put("Show", "🎵");
        eventTypeEmojis.put("Meet and Greet", "🤝");
        eventTypeEmojis.put("Clinic", "🎸");
        eventTypeEmojis.put("Special Event", "🎪");
        eventTypeEmojis.put("Cruiser Organized", "🚢");
        eventTypeEmojis.put("Unofficial Event", "🔥");
        
        Map<String, String> eventTypeLabels = new HashMap<>();
        eventTypeLabels.put("Show", staticVariables.context.getString(R.string.ShowsPlural));
        eventTypeLabels.put("Meet and Greet", staticVariables.context.getString(R.string.MeetAndGreetsPlural));
        eventTypeLabels.put("Clinic", staticVariables.context.getString(R.string.ClinicsPlural));
        eventTypeLabels.put("Special Event", staticVariables.context.getString(R.string.SpecialEventsPlural));
        eventTypeLabels.put("Cruiser Organized", staticVariables.context.getString(R.string.CruiseEventsPlural));
        eventTypeLabels.put("Unofficial Event", staticVariables.context.getString(R.string.UnofficialEventsPlural));
        
        // Process each event type in order
        for (String eventType : eventTypeOrder) {
            if (!bandCounts.containsKey(eventType) || bandCounts.get(eventType).isEmpty()) {
                continue;
            }
            
            String emoji = eventTypeEmojis.getOrDefault(eventType, "🎯");
            String label = eventTypeLabels.getOrDefault(eventType, eventType);
            int totalCount = calculateTotalEventsForType(eventType);
            
            if (totalCount > 0) {
                message += emoji + " " + label + " (" + totalCount + "):\n";
                
                // Get all bands/events for this type with venue info
                List<String> eventEntries = new ArrayList<>();
                
                Set<String> bandNames = bandCounts.get(eventType).keySet();
                List<String> sortedBandNames = new ArrayList<>(bandNames);
                Collections.sort(sortedBandNames);
                
                for (String bandName : sortedBandNames) {
                    Map<String, Integer> bandData = bandCounts.get(eventType).get(bandName);
                    Integer sawAllCount = bandData.get(staticVariables.sawAllStatus);
                    
                    if (sawAllCount != null && sawAllCount > 0) {
                        // Get venue info for this band/event
                        String venue = getVenueForBandEvent(bandName, eventType);
                        String venueInfo = venue.isEmpty() ? "" : " (" + venue + ")";
                        
                        eventEntries.add("• " + bandName + venueInfo);
                    }
                }
                
                // Join entries with bullet separation for compact display
                if (!eventEntries.isEmpty()) {
                    message += String.join(" ", eventEntries) + "\n\n";
                }
            }
        }
        
        message += "\n" + FestivalConfig.getInstance().shareUrl;
        return message;
    }
    
    /**
     * Calculates the total number of events attended for a specific event type.
     * @param eventType The event type to count.
     * @return Total count of events attended for this type.
     */
    private int calculateTotalEventsForType(String eventType) {
        if (!bandCounts.containsKey(eventType)) {
            return 0;
        }
        
        int total = 0;
        Map<String, Map<String, Integer>> eventTypeData = bandCounts.get(eventType);
        
        for (Map<String, Integer> bandData : eventTypeData.values()) {
            Integer sawAllCount = bandData.get(staticVariables.sawAllStatus);
            Integer sawSomeCount = bandData.get(staticVariables.sawSomeStatus);
            
            if (sawAllCount != null) {
                total += sawAllCount;
            }
            if (sawSomeCount != null) {
                total += sawSomeCount;
            }
        }
        return total;
    }
    
    /**
     * Gets the venue information for a specific band/event.
     * @param bandName The name of the band or event.
     * @param eventType The type of event.
     * @return The venue name, or empty string if not found.
     */
    private String getVenueForBandEvent(String bandName, String eventType) {
        try {
            // Use the Android schedule data access pattern
            if (BandInfo.scheduleRecords != null && BandInfo.scheduleRecords.containsKey(bandName)) {
                mainListHandler listHandler = new mainListHandler();
                
                // Get all time indices for this band
                Map<Long, scheduleHandler> bandSchedule = BandInfo.scheduleRecords.get(bandName).scheduleByTime;
                
                // Look for matching event type and return the location
                for (Long timeIndex : bandSchedule.keySet()) {
                    String type = listHandler.getEventType(bandName, timeIndex);
                    
                    if (type != null && type.equals(eventType)) {
                        String location = listHandler.getLocation(bandName, timeIndex);
                        return location != null ? location : "";
                    }
                }
            }
        } catch (Exception e) {
            Log.e("getVenueForBandEvent", "Error getting venue for " + bandName + ": " + e.getMessage());
        }
        
        return "";
    }

    public void getEventTypeCounts (String eventType, String sawStatus){

        if (eventCounts.containsKey(eventType) == false){
            eventCounts.put(eventType, new HashMap<String,Integer>());
        }

        if (eventCounts.get(eventType).containsKey(sawStatus) == false){
            eventCounts.get(eventType).put(sawStatus, 1);

        } else {
            Integer newCount = eventCounts.get(eventType).get(sawStatus) + 1;
            eventCounts.get(eventType).put(sawStatus, newCount);
        }
    }

    public void getBandCounts (String eventType,String bandName, String sawStatus){

        Log.d("ShareMessag", "getBandCounts" + eventType + "-" + bandName + "-" + sawStatus);

        if (bandCounts.containsKey(eventType) == false){
            bandCounts.put(eventType, new HashMap<String, Map<String, Integer>>());
        }

        if (bandCounts.get(eventType).containsKey(bandName) == false){
            bandCounts.get(eventType).put(bandName, new HashMap<String,Integer>());
        }

        if (bandCounts.get(eventType).get(bandName).containsKey(sawStatus) == false){
            bandCounts.get(eventType).get(bandName).put(sawStatus, 1);
        } else {

            Log.d("ShareMessag", "adding to " + bandCounts.get(eventType).get(bandName).get(sawStatus));
            Integer newCount = bandCounts.get(eventType).get(bandName).get(sawStatus) + 1;
            bandCounts.get(eventType).get(bandName).put(sawStatus, newCount);
        }
    }
}
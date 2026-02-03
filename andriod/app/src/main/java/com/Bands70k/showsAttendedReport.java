package com.Bands70k;

import android.util.Log;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.HashSet;

public class showsAttendedReport {

    private Map<String,Map<String,Integer>> eventCounts = new HashMap<String,Map<String,Integer>>();
    private Map<String,Map<String,Map<String,Integer>>> bandCounts = new HashMap<String,Map<String,Map<String,Integer>>>();
    
    // Track individual events with their details (band name + venue info)
    // Structure: eventType -> List of event entries (band + venue)
    private Map<String, List<EventEntry>> individualEvents = new HashMap<String, List<EventEntry>>();
    
    // Track which bands exist in current year's schedule to filter out old year data
    private Set<String> currentYearBands = new HashSet<String>();
    
    /**
     * Helper class to store individual event details
     */
    private static class EventEntry {
        String bandName;
        String venue;
        String fullIndex; // Store full index to look up venue later
        
        EventEntry(String bandName, String venue, String fullIndex) {
            this.bandName = bandName;
            this.venue = venue;
            this.fullIndex = fullIndex;
        }
    }

    public void assembleReport() {
        Log.d("showsAttendedReport", "🔍 [SHARE_REPORT] ========== STARTING EVENTS ATTENDED REPORT ==========");
        
        // Verify schedule data is available (should have been loaded by shareMenuPrompt)
        if (BandInfo.scheduleRecords == null || BandInfo.scheduleRecords.isEmpty()) {
            Log.w("showsAttendedReport", "⚠️ [SHARE_REPORT] Schedule data not available - report will be empty");
        } else {
            Log.d("showsAttendedReport", "✅ [SHARE_REPORT] Schedule data available: " + 
                BandInfo.scheduleRecords.size() + " bands");
        }
        
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
        
        // Build set of bands that exist in current year's schedule
        buildCurrentYearBandsList();
        
        Log.d("showsAttendedReport", "🔍 [ASSEMBLE] Loading attendance data for profile: " + profileManager.getActivePreferenceSource());

        showsAttended attendedHandler = new showsAttended();
        // CRITICAL: Use return value directly to avoid profile reload race condition
        Map<String, String> showsAttendedArray = attendedHandler.loadShowsAttended();

        Log.d("showsAttendedReport", "🔍 [ASSEMBLE] showsAttendedArray size: " + (showsAttendedArray != null ? showsAttendedArray.size() : "NULL"));
        Log.d("showsAttendedReport", "🔍 [ASSEMBLE] currentYearBands size: " + currentYearBands.size());
        Log.d("showsAttendedReport", "🔍 [ASSEMBLE] Current event year: " + staticVariables.eventYear);
        
        if (showsAttendedArray == null) {
            Log.e("showsAttendedReport", "❌ [ASSEMBLE] showsAttendedArray is NULL - report will be empty");
            return;
        }
        
        if (showsAttendedArray.isEmpty()) {
            Log.w("showsAttendedReport", "⚠️ [ASSEMBLE] showsAttendedArray is EMPTY - report will be empty");
            return;
        }
        
        if (currentYearBands.isEmpty()) {
            Log.w("showsAttendedReport", "⚠️ [ASSEMBLE] currentYearBands is empty - all events will be filtered out");
        }
        
        int processedCount = 0;
        int validatedCount = 0;
        int trackedCount = 0;
        
        for (String index : showsAttendedArray.keySet()) {
            processedCount++;

            String[] indexArray = index.split(":");

            // Skip old format entries (5 parts without year)
            if (indexArray.length == 5){
                Log.d("ShareMessage", "Skipping old format entry: " + index);
                continue;
            }
            
            // Skip entries with incorrect format
            if (indexArray.length < 6) {
                Log.d("ShareMessage", "Skipping malformed entry: " + index);
                continue;
            }
            
            String bandName = indexArray[0];
            String eventType = indexArray[4];
            Integer eventYear = Integer.valueOf(indexArray[5]);
            
            Log.d("ShareMessage", "📋 Processing [" + processedCount + "]: " + index);
            Log.d("ShareMessage", "   Band: " + bandName + ", Type: " + eventType + ", Year: " + eventYear);

            // CRITICAL: Filter by current event year
            if (eventYear.intValue() != staticVariables.eventYear) {
                Log.d("ShareMessage", "Skipping - wrong year: " + eventYear + " != " + staticVariables.eventYear);
                continue;
            }
            
            // CRITICAL: Only include bands that exist in current year's schedule
            // This prevents showing bands from previous years that might have similar names
            if (!currentYearBands.contains(bandName)) {
                Log.d("ShareMessage", "Skipping - band not in current year schedule: " + bandName);
                continue;
            }
            
            // CRITICAL: Validate that this SPECIFIC EVENT actually exists in the current year's schedule
            // Check the band + location + eventType combination against the actual schedule
            String location = indexArray[1];
            String startTime = indexArray[2] + ":" + indexArray[3];
            
            Log.d("ShareMessage", "🔍 Validating: " + bandName + " | " + location + " | " + startTime + " | " + eventType + " | Year:" + eventYear);
            
            if (!validateEventExistsInSchedule(bandName, location, startTime, eventType)) {
                Log.d("ShareMessage", "❌ REJECTED - event doesn't exist in current schedule: " + bandName + " at " + location + " (" + eventType + ")");
                continue;
            }
            
            validatedCount++;
            Log.d("ShareMessage", "✅ VALIDATED - event exists in schedule");

            String attendedStatus = showsAttendedArray.get(index);
            Log.d("ShareMessage", "Including: " + index);
            Log.d("ShareMessage", "eventType is " + eventType);
            Log.d("ShareMessage", "status is " + attendedStatus);

            // Only count events that were actually attended (not "sawNone")
            if (!staticVariables.sawNoneStatus.equals(attendedStatus)) {
                getEventTypeCounts(eventType, attendedStatus);
                getBandCounts(eventType, bandName, attendedStatus);
                
                // Track individual event with its venue info
                Log.d("ShareMessage", "📝 Tracking event for report");
                trackIndividualEvent(eventType, bandName, index);
                trackedCount++;
            } else {
                Log.d("ShareMessage", "⏭️ Skipping - status is sawNone");
            }

        }
        
        Log.d("showsAttendedReport", "📊 [ASSEMBLE] PROCESSING SUMMARY:");
        Log.d("showsAttendedReport", "   Total records processed: " + processedCount);
        Log.d("showsAttendedReport", "   Events validated: " + validatedCount);
        Log.d("showsAttendedReport", "   Events tracked for report: " + trackedCount);
        
        // Log individual events by type
        for (String eventType : individualEvents.keySet()) {
            List<EventEntry> events = individualEvents.get(eventType);
            Log.d("showsAttendedReport", "   " + eventType + ": " + (events != null ? events.size() : 0) + " events");
        }
        
        // CRITICAL: Restore original profile
        if (!"Default".equals(originalProfile)) {
            Log.d("showsAttendedReport", "🔍 [SHARE_REPORT] Restoring original profile: '" + originalProfile + "'");
            profileManager.setActivePreferenceSource(originalProfile);
        }
        
        Log.d("showsAttendedReport", "🔍 [SHARE_REPORT] ========== REPORT COMPLETE ==========");
    }
    
    /**
     * Builds a set of band names that exist in the current year's schedule.
     * This is used to filter out attended events from previous years.
     */
    private void buildCurrentYearBandsList() {
        Log.d("showsAttendedReport", "🔍 [BUILD_BANDS_LIST] Building current year bands list...");
        Log.d("showsAttendedReport", "🔍 [BUILD_BANDS_LIST] BandInfo.scheduleRecords is " + 
            (BandInfo.scheduleRecords == null ? "NULL" : "size=" + BandInfo.scheduleRecords.size()));
        
        currentYearBands.clear();
        
        if (BandInfo.scheduleRecords != null && !BandInfo.scheduleRecords.isEmpty()) {
            currentYearBands.addAll(BandInfo.scheduleRecords.keySet());
            Log.d("showsAttendedReport", "✅ [BUILD_BANDS_LIST] Built list with " + currentYearBands.size() + " bands");
            
            // Log first 10 bands for verification
            int count = 0;
            for (String bandName : currentYearBands) {
                if (count++ < 10) {
                    Log.d("showsAttendedReport", "   Band: " + bandName);
                } else {
                    Log.d("showsAttendedReport", "   ... and " + (currentYearBands.size() - 10) + " more bands");
                    break;
                }
            }
        } else {
            Log.e("showsAttendedReport", "❌ [BUILD_BANDS_LIST] BandInfo.scheduleRecords is null or empty!");
            Log.e("showsAttendedReport", "❌ [BUILD_BANDS_LIST] ALL EVENTS WILL BE FILTERED OUT - REPORT WILL BE EMPTY");
        }
    }
    
    /**
     * Validates that a specific event actually exists in the current year's schedule.
     * This prevents showing attended events from previous years that have the same band name.
     * 
     * @param bandName The name of the band
     * @param location The location/venue where the event took place
     * @param startTime The start time of the event
     * @param eventType The type of event (Show, Meet and Greet, etc.)
     * @return true if this exact event exists in the current schedule, false otherwise
     */
    private boolean validateEventExistsInSchedule(String bandName, String location, String startTime, String eventType) {
        try {
            // Check if schedule data is available
            if (BandInfo.scheduleRecords == null || BandInfo.scheduleRecords.isEmpty()) {
                Log.w("validateEvent", "⚠️ scheduleRecords not available - cannot validate events");
                return false;
            }
            
            // Check if the band has any schedule records
            if (!BandInfo.scheduleRecords.containsKey(bandName)) {
                Log.d("validateEvent", "Band not found in schedule: " + bandName);
                return false;
            }
            
            scheduleTimeTracker bandSchedule = BandInfo.scheduleRecords.get(bandName);
            if (bandSchedule == null || bandSchedule.scheduleByTime == null || bandSchedule.scheduleByTime.isEmpty()) {
                Log.d("validateEvent", "No schedule data for band: " + bandName);
                return false;
            }
            
            mainListHandler listHandler = new mainListHandler();
            
            int scheduleEntryCount = bandSchedule.scheduleByTime.size();
            Log.d("validateEvent", "   Checking against " + scheduleEntryCount + " scheduled events for " + bandName);
            Log.d("validateEvent", "   Looking for: " + bandName + " | " + location + " | " + startTime + " | " + eventType);
            
            // Track matches to detect duplicates
            int matchCount = 0;
            Long firstMatchTimeIndex = null;
            
            // Iterate through all scheduled events for this band
            for (Long timeIndex : bandSchedule.scheduleByTime.keySet()) {
                scheduleHandler scheduleEntry = bandSchedule.scheduleByTime.get(timeIndex);
                if (scheduleEntry == null) continue;
                
                // Get the event details from the schedule
                String scheduledLocation = scheduleEntry.getShowLocation();
                String scheduledEventType = scheduleEntry.getShowType();
                String scheduledTime = scheduleEntry.getStartTimeString();
                
                // Get the date/year from the epoch timestamp to validate it's actually in 2026
                Date eventDate = new Date(timeIndex);
                java.util.Calendar cal = java.util.Calendar.getInstance();
                cal.setTime(eventDate);
                int eventScheduleYear = cal.get(java.util.Calendar.YEAR);
                
                // CRITICAL: Only validate against 2026 events
                if (eventScheduleYear != 2026) {
                    continue;
                }
                
                // Compare the attended event details with the scheduled event
                boolean locationMatches = (scheduledLocation != null && scheduledLocation.equals(location)) ||
                                         (scheduledLocation == null && (location == null || location.isEmpty()));
                boolean eventTypeMatches = scheduledEventType != null && scheduledEventType.equals(eventType);
                
                // CRITICAL: Also check start time to distinguish between multiple events at same venue
                boolean timeMatches = scheduledTime != null && scheduledTime.equals(startTime);
                
                if (locationMatches && eventTypeMatches && timeMatches) {
                    matchCount++;
                    if (firstMatchTimeIndex == null) {
                        firstMatchTimeIndex = timeIndex;
                    }
                    
                    Log.d("validateEvent", "✅ MATCH #" + matchCount + ": timeIndex=" + timeIndex + 
                        " | Date=" + eventDate + " | Location=" + location + ", Time=" + startTime + ", Type=" + eventType);
                }
            }
            
            if (matchCount == 0) {
                Log.d("validateEvent", "❌ NO MATCH: " + bandName + " at " + location + " @ " + startTime + " (" + eventType + ")");
                return false;
            } else if (matchCount > 1) {
                Log.w("validateEvent", "⚠️ MULTIPLE MATCHES (" + matchCount + "): This could cause duplicates - using first match: " + firstMatchTimeIndex);
            } else {
                Log.d("validateEvent", "✅ SINGLE MATCH: timeIndex=" + firstMatchTimeIndex);
            }
            
            return true;
            
        } catch (Exception e) {
            Log.e("validateEvent", "Error validating event: " + e.getMessage(), e);
            // In case of error, err on the side of caution and exclude the event
            return false;
        }
    }
    
    /**
     * Tracks an individual event with its venue information.
     * Prevents duplicate entries for the same event.
     * @param eventType The type of event (Show, Meet and Greet, etc.)
     * @param bandName The name of the band
     * @param fullIndex The full index string (band:location:time:eventType:year)
     */
    private void trackIndividualEvent(String eventType, String bandName, String fullIndex) {
        if (!individualEvents.containsKey(eventType)) {
            individualEvents.put(eventType, new ArrayList<EventEntry>());
        }
        
        // Get venue info from the index
        String venue = getVenueFromIndex(fullIndex, bandName, eventType);
        
        // Parse the time from fullIndex
        String[] parts = fullIndex.split(":");
        String time = parts.length >= 4 ? (parts[2] + ":" + parts[3]) : "";
        
        // CRITICAL: Check for duplicates by band+venue+time combination
        // If same band plays same venue at same time, it's the same event
        List<EventEntry> existingEvents = individualEvents.get(eventType);
        for (EventEntry existing : existingEvents) {
            // Check if same band + venue + time (parse time from existing fullIndex)
            String[] existingParts = existing.fullIndex.split(":");
            String existingTime = existingParts.length >= 4 ? (existingParts[2] + ":" + existingParts[3]) : "";
            
            boolean sameBand = existing.bandName.equals(bandName);
            boolean sameVenue = (existing.venue != null && existing.venue.equals(venue)) ||
                               (existing.venue == null && (venue == null || venue.isEmpty()));
            boolean sameTime = existingTime.equals(time);
            
            if (sameBand && sameVenue && sameTime) {
                Log.w("trackIndividualEvent", "🚫 DUPLICATE EVENT DETECTED:");
                Log.w("trackIndividualEvent", "   Band: " + bandName + " | Venue: " + venue + " | Time: " + time);
                Log.w("trackIndividualEvent", "   Existing fullIndex: " + existing.fullIndex);
                Log.w("trackIndividualEvent", "   New fullIndex: " + fullIndex);
                Log.w("trackIndividualEvent", "   -> Skipping duplicate");
                return;
            }
        }
        
        EventEntry entry = new EventEntry(bandName, venue, fullIndex);
        existingEvents.add(entry);
        
        Log.d("trackIndividualEvent", "✅ Added event: " + bandName + " at " + venue + " @ " + time + " (" + eventType + ")");
        Log.d("trackIndividualEvent", "   fullIndex: " + fullIndex);
    }
    
    /**
     * Extracts venue information from the index or schedule data.
     * @param fullIndex The full index string (band:location:time:eventType:year)
     * @param bandName The name of the band
     * @param eventType The type of event
     * @return The venue name, or empty string if not found
     */
    private String getVenueFromIndex(String fullIndex, String bandName, String eventType) {
        try {
            String[] parts = fullIndex.split(":");
            if (parts.length >= 2) {
                // The location is the second part of the index
                String location = parts[1];
                if (location != null && !location.isEmpty() && !location.equals("null")) {
                    return location;
                }
            }
        } catch (Exception e) {
            Log.e("getVenueFromIndex", "Error parsing index: " + e.getMessage());
        }
        
        // Fallback: try to get venue from schedule data
        return getVenueForBandEvent(bandName, eventType);
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
        Log.d("showsAttendedReport", "🔍 [BUILD_MESSAGE] Building message with " + individualEvents.size() + " event types");
        for (String eventType : individualEvents.keySet()) {
            List<EventEntry> events = individualEvents.get(eventType);
            Log.d("showsAttendedReport", "   " + eventType + ": " + (events != null ? events.size() : 0) + " events");
        }
        return buildEventsAttendedReport();
    }
    
    /**
     * Builds an enhanced events attended report with venue information and emojis using localized strings.
     * @return The formatted events attended report as a string.
     */
    private String buildEventsAttendedReport() {
        Log.d("showsAttendedReport", "🔍 [BUILD_REPORT] Starting buildEventsAttendedReport()");
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
        int eventTypesProcessed = 0;
        for (String eventType : eventTypeOrder) {
            if (!individualEvents.containsKey(eventType) || individualEvents.get(eventType).isEmpty()) {
                Log.d("showsAttendedReport", "⏭️ [BUILD_REPORT] Skipping " + eventType + " - no events");
                continue;
            }
            
            eventTypesProcessed++;
            String emoji = eventTypeEmojis.getOrDefault(eventType, "🎯");
            String label = eventTypeLabels.getOrDefault(eventType, eventType);
            
            List<EventEntry> events = individualEvents.get(eventType);
            int totalCount = events.size();
            
            Log.d("showsAttendedReport", "📝 [BUILD_REPORT] Processing " + eventType + " with " + totalCount + " events");
            
            if (totalCount > 0) {
                message += emoji + " " + label + " (" + totalCount + "):\n";
                
                // Sort events by band name
                Collections.sort(events, (e1, e2) -> e1.bandName.compareTo(e2.bandName));
                
                // Get all individual events for this type with venue info
                List<String> eventEntries = new ArrayList<>();
                
                for (EventEntry event : events) {
                    String venueInfo = (event.venue != null && !event.venue.isEmpty()) 
                        ? " (" + event.venue + ")" 
                        : "";
                    
                    eventEntries.add("• " + event.bandName + venueInfo);
                }
                
                // Join entries with bullet separation for compact display
                if (!eventEntries.isEmpty()) {
                    message += String.join(" ", eventEntries) + "\n\n";
                }
            }
        }
        
        Log.d("showsAttendedReport", "✅ [BUILD_REPORT] Report built with " + eventTypesProcessed + " event types");
        Log.d("showsAttendedReport", "📏 [BUILD_REPORT] Message length: " + message.length() + " characters");
        
        message += "\n" + FestivalConfig.getInstance().shareUrl;
        return message;
    }
    
    /**
     * Calculates the total number of events attended for a specific event type.
     * CRITICAL: This counts all events, including multiple events by the same band.
     * For example, if you saw Anthrax 3 times, it counts as 3.
     * @param eventType The event type to count.
     * @return Total count of events attended for this type.
     */
    private int calculateTotalEventsForType(String eventType) {
        if (!individualEvents.containsKey(eventType)) {
            return 0;
        }
        
        return individualEvents.get(eventType).size();
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
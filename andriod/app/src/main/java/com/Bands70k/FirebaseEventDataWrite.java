package com.Bands70k;


import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.DatabaseError;
import java.util.Set;
import java.util.HashSet;

import android.util.Log;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.util.HashMap;
import java.util.Map;

/**
 * Handles writing attended event data to Firebase and local cache.
 */
public class FirebaseEventDataWrite {


    private DatabaseReference mDatabase;
    private File eventDataCacheFile = new File(showBands.newRootDir + FileHandler70k.directoryName + "eventDataCacheFile.data");


    /**
     * Constructs a FirebaseEventDataWrite and initializes the database reference.
     */
    FirebaseEventDataWrite(){
        mDatabase = FirebaseDatabase.getInstance().getReference();
    }

    /**
     * Sanitizes strings for use as Firebase database path components.
     * Firebase paths cannot contain: . # $ [ ] / ' " \ and control characters
     * @param input The string to sanitize
     * @return Sanitized string safe for Firebase paths
     */
    private String sanitizeForFirebase(String input) {
        if (input == null || input.isEmpty()) {
            return input;
        }
        
        return input
                .replace(".", "_")
                .replace("#", "_")
                .replace("$", "_")
                .replace("[", "_")
                .replace("]", "_")
                .replace("/", "_")
                .replace("'", "_")
                .replace("\"", "_")
                .replace("\\", "_")
                // Remove control characters (ASCII 0-31 and 127)
                .replaceAll("[\\p{Cntrl}]", "")
                // Trim whitespace
                .trim();
    }


    /**
     * Writes attended event data to Firebase if data has changed.
     */
    public void writeData(){

        if (staticVariables.isTestingEnv == false && staticVariables.userID.isEmpty() == false) {
            showsAttended attendedHandler = new showsAttended();
            Map<String, String> showsAttendedArray = attendedHandler.getShowsAttended();
            
            // Ensure eventYear is set before using it
            if (staticVariables.eventYear == 0) {
                staticVariables.ensureEventYearIsSet();
            }
            // Get current year for filtering
            String currentYear = String.valueOf(staticVariables.eventYear);
            Log.d("FirebaseEventDataWrite", "🔥 firebase EVENT_WRITE: Filtering for current year: " + currentYear);
            
            // Filter events to only include current year
            Map<String, String> currentYearEvents = new HashMap<>();
            int totalEvents = showsAttendedArray.size();
            int filteredOutCount = 0;
            
            for (String index : showsAttendedArray.keySet()) {
                String[] indexArray = index.split(":");
                if (indexArray.length == 6) {
                    String eventYear = indexArray[5];
                    if (eventYear.equals(currentYear)) {
                        currentYearEvents.put(index, showsAttendedArray.get(index));
                    } else {
                        filteredOutCount++;
                    }
                }
            }
            
            Log.d("FirebaseEventDataWrite", "🔥 firebase EVENT_WRITE: Filtered to " + currentYearEvents.size() + 
                    " events for year " + currentYear + " (excluded " + filteredOutCount + " from other years)");

            // Build set of known events from schedule (events the app knows about)
            Set<String> knownEventIdentifiers = buildKnownEventIdentifiers(currentYear);
            Log.d("FirebaseEventDataWrite", "🔥 firebase EVENT_WRITE: Found " + knownEventIdentifiers.size() + " known events in schedule");
            
            // Filter to only include events that the app knows about
            Map<String, String> knownEventsOnly = new HashMap<>();
            int unknownEventCount = 0;
            for (String index : currentYearEvents.keySet()) {
                if (knownEventIdentifiers.contains(index)) {
                    knownEventsOnly.put(index, currentYearEvents.get(index));
                } else {
                    unknownEventCount++;
                    Log.d("FirebaseEventDataWrite", "Excluding unknown event: " + index);
                }
            }
            
            Log.d("FirebaseEventDataWrite", "🔥 firebase EVENT_WRITE: Filtered to " + knownEventsOnly.size() + 
                    " known events (excluded " + unknownEventCount + " unknown events)");

            if (checkIfDataHasChanged(knownEventsOnly)) {
                // OPTIMIZATION: Use batch write instead of individual writes
                DatabaseReference showDataRef = mDatabase.child("showData/").child(staticVariables.userID).child(currentYear);
                
                Map<String, Object> batchUpdate = new HashMap<>();
                
                for (String index : knownEventsOnly.keySet()) {
                    HashMap<String, Object> eventData = new HashMap<>();

                    String[] indexArray = index.split(":");

                    String bandName = indexArray[0];
                    String location = indexArray[1];
                    String startTimeHour = indexArray[2];
                    String startTimeMin = indexArray[3];
                    String eventType = indexArray[4];
                    String eventYear = "";

                    if (indexArray.length == 6) {
                        eventYear = indexArray[5];
                    } else {
                        continue;
                    }

                    // Sanitize index for Firebase path (contains band name which may have invalid characters)
                    String sanitizedIndex = sanitizeForFirebase(index);

                    String attendedStatus = knownEventsOnly.get(index);
                    
                    // Store both original and sanitized data for reference
                    eventData.put("originalIdentifier", index); // Original identifier for reference
                    eventData.put("sanitizedKey", sanitizedIndex); // Sanitized key for debugging
                    eventData.put("bandName", bandName);
                    eventData.put("location", location);
                    eventData.put("startTimeHour", startTimeHour);
                    eventData.put("startTimeMin", startTimeMin);
                    eventData.put("eventType", eventType);
                    eventData.put("status", attendedStatus);

                    // Add to batch update map
                    batchUpdate.put(sanitizedIndex, eventData);
                }
                
                Log.d("FirebaseEventDataWrite", "🔥 BATCH_WRITE: Writing " + batchUpdate.size() + " event entries in single batch");
                try {
                    // Single batch write for all event data
                    showDataRef.updateChildren(batchUpdate, (error, ref) -> {
                        if (error != null) {
                            Log.e("FirebaseEventDataWrite", "Batch write failed: " + error.getMessage());
                        } else {
                            Log.d("FirebaseEventDataWrite", "Batch write successful for " + batchUpdate.size() + " events");
                        }
                    });
                } catch (Exception error){
                    Log.e("FirebaseEventDataWrite", "Batch write exception: " + error.toString());
                }
                //FirebaseDatabase.getInstance().goOffline();
            }
        }
    }


    /**
     * Checks if the attended event data has changed since last write.
     * @param showsAttendedArray The map of attended events.
     * @return True if data has changed, false otherwise.
     */
    private Boolean checkIfDataHasChanged(Map<String, String> showsAttendedArray){

        Boolean result = true;

        Map<String,String> showsAttendedArrayCache = new HashMap<>();

        if (eventDataCacheFile.exists() == true){

            try {
                FileInputStream fileInStream = new FileInputStream(eventDataCacheFile);
                ObjectInputStream objectInStream = new ObjectInputStream(fileInStream);

                showsAttendedArrayCache = (Map<String,String>) objectInStream.readObject();

                if (showsAttendedArrayCache.equals(showsAttendedArray) == true){
                    result = false;
                }

            } catch (Exception error){
                Log.e("load Data Error", "on bandRankCacheFile.data " +  error.getMessage());
            }
        }


        try{
            FileOutputStream fileOutStream = new FileOutputStream(eventDataCacheFile);
            ObjectOutputStream objectOutStream = new ObjectOutputStream(fileOutStream);

            objectOutStream.writeObject(showsAttendedArray);

        } catch (Exception error){
            Log.e("Save Data Error","on bandRankCacheFile.data " +  error.getMessage());
        }

        Log.e("writing event data","Has changed is " + result.toString());

        return result;
    }
    
    /**
     * Builds a set of event identifiers for events that the app knows about (from schedule).
     * Format: "bandName:location:startTime:eventType:year"
     * @param currentYear The current event year
     * @return Set of known event identifiers
     */
    private Set<String> buildKnownEventIdentifiers(String currentYear) {
        Set<String> knownEvents = new HashSet<>();
        
        try {
            if (BandInfo.scheduleRecords == null || BandInfo.scheduleRecords.isEmpty()) {
                Log.d("FirebaseEventDataWrite", "No schedule records available");
                return knownEvents;
            }
            
            // Iterate through all bands in schedule
            for (Map.Entry<String, scheduleTimeTracker> bandEntry : BandInfo.scheduleRecords.entrySet()) {
                String bandName = bandEntry.getKey();
                scheduleTimeTracker scheduleTracker = bandEntry.getValue();
                
                if (scheduleTracker == null || scheduleTracker.scheduleByTime == null) {
                    continue;
                }
                
                // Iterate through all events for this band
                for (Map.Entry<Long, scheduleHandler> eventEntry : scheduleTracker.scheduleByTime.entrySet()) {
                    scheduleHandler scheduleItem = eventEntry.getValue();
                    
                    if (scheduleItem == null) {
                        continue;
                    }
                    
                    String location = scheduleItem.getShowLocation();
                    String startTime = scheduleItem.getStartTimeString();
                    String eventType = scheduleItem.getShowType();
                    
                    // Build event identifier matching showsAttended format
                    // Format: "bandName:location:startTime:eventType:year"
                    String eventIdentifier = bandName + ":" + location + ":" + startTime + ":" + eventType + ":" + currentYear;
                    knownEvents.add(eventIdentifier);
                }
            }
            
            Log.d("FirebaseEventDataWrite", "Built " + knownEvents.size() + " known event identifiers from schedule");
        } catch (Exception e) {
            Log.e("FirebaseEventDataWrite", "Error building known event identifiers: " + e.getMessage());
        }
        
        return knownEvents;
    }
}

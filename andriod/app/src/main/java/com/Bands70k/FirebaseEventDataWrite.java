package com.Bands70k;


import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;

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

            if (checkIfDataHasChanged(currentYearEvents)) {
                for (String index : currentYearEvents.keySet()) {

                    HashMap<String, Object> eventData = new HashMap<>();

                    String[] indexArray = index.split(":");

                    String bandName = indexArray[0];
                    String location = indexArray[1];
                    String startTimeHour = indexArray[2];
                    String startTimeMin = indexArray[3];
                    String eventType = indexArray[4];
                    String eventYear = "";

                    for (String data : indexArray) {
                        Log.d("FireBaseBandDataWrite", "showsAttendedArrayData - " + data);
                    }

                    if (indexArray.length == 6) {
                        eventYear = indexArray[5];
                    } else {
                        continue;
                    }

                    // Sanitize index for Firebase path (contains band name which may have invalid characters)
                    String sanitizedIndex = sanitizeForFirebase(index);

                    String attendedStatus = currentYearEvents.get(index);
                    Log.d("FireBaseBandDataWrite", "showsAttendedArray - " + showsAttendedArray.get(index));
                    
                    // Store both original and sanitized data for reference
                    eventData.put("originalIdentifier", index); // Original identifier for reference
                    eventData.put("sanitizedKey", sanitizedIndex); // Sanitized key for debugging
                    eventData.put("bandName", bandName);
                    eventData.put("location", location);
                    eventData.put("startTimeHour", startTimeHour);
                    eventData.put("startTimeMin", startTimeMin);
                    eventData.put("eventType", eventType);
                    eventData.put("status", attendedStatus);

                    Log.d("FireBaseBandDataWrite", "Writing band event data - " + index + " -> " + sanitizedIndex + " - " + eventData.toString());

                    // Use sanitized index for Firebase path
                    mDatabase.child("showData/").child(staticVariables.userID).child(eventYear).child(sanitizedIndex).setValue(eventData);
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
}

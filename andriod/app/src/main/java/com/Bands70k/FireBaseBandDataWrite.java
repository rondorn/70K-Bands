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
import java.util.List;
import java.util.Map;

/**
 * Handles writing band ranking data to Firebase and local cache.
 */
public class FireBaseBandDataWrite {

    private DatabaseReference mDatabase;

    private Map<String,String> bandRanks = new HashMap<>();
    private File bandRankCacheFile = new File(showBands.newRootDir + FileHandler70k.directoryName + "bandRankCacheFile.data");

    /**
     * Constructs a FireBaseBandDataWrite and initializes the database reference.
     */
    FireBaseBandDataWrite(){
            mDatabase = FirebaseDatabase.getInstance().getReference();
    }

    /**
     * Sanitizes band names for use as Firebase database path components.
     * Firebase paths cannot contain: . # $ [ ] / ' " \ and control characters
     * @param bandName The band name to sanitize
     * @return Sanitized band name safe for Firebase paths
     */
    private String sanitizeBandNameForFirebase(String bandName) {
        if (bandName == null || bandName.isEmpty()) {
            return bandName;
        }
        
        return bandName
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
     * Writes band ranking data to Firebase if data has changed.
     */
    public void writeData(){

        Log.d("FireBaseBandDataWrite", "In write routine");

        if (staticVariables.isTestingEnv == false && staticVariables.userID.isEmpty() == false) {
            buildBandRankArray();
            Log.d("FireBaseBandDataWrite", "has data changed");

            if (checkIfDataHasChanged() == true) {
                //FirebaseDatabase.getInstance().goOnline();
                for (String bandName : bandRanks.keySet()) {

                    HashMap<String, Object> bandData = new HashMap<>();

                    String eventYear = String.valueOf(staticVariables.eventYear);
                    String ranking = bandRanks.get(bandName);
                    String sanitizedBandName = sanitizeBandNameForFirebase(bandName);

                    bandData.put("bandName", bandName); // Original name for reports/display
                    bandData.put("sanitizedKey", sanitizedBandName); // Sanitized key for reference/debugging
                    bandData.put("ranking", ranking);
                    bandData.put("userID", staticVariables.userID);
                    bandData.put("year", eventYear);

                    Log.d("FireBaseBandDataWrite", "Writing band data " + bandData.toString() + " (sanitized: " + sanitizedBandName + ")");
                    try {
                        // Use sanitized band name for Firebase path
                        mDatabase.child("bandData/").child(staticVariables.userID).child(eventYear).child(sanitizedBandName).setValue(bandData);
                    } catch (Exception error){
                        Log.e("FireBaseBandDataWrite", "Writing band data Failed" + error.toString());
                    }
                }
                //FirebaseDatabase.getInstance().goOffline();
            }
        }
    }

    /**
     * Builds the band ranking array from current band info and rankings.
     * Note: getBandNames() returns bands for the current year based on the loaded CSV.
     * Year filtering happens at CSV load time via staticVariables.eventYear.
     */
    private void buildBandRankArray(){

        BandInfo bandInfoNames = new BandInfo();
        List<String> bandNames = bandInfoNames.getBandNames();
        
        String currentYear = String.valueOf(staticVariables.eventYear);
        Log.d("FireBaseBandDataWrite", "🔥 firebase BAND_WRITE: Building band array for current year: " + currentYear);
        Log.d("FireBaseBandDataWrite", "🔥 firebase BAND_WRITE: Found " + bandNames.size() + " bands from getBandNames()");

        for (String bandName: bandNames) {

            String ranking = rankStore.getRankForBand(bandName);

            if (ranking == staticVariables.mustSeeIcon){
                ranking = "Must";

            } else if (ranking == staticVariables.mightSeeIcon){
                ranking = "Might";

            } else if (ranking == staticVariables.wontSeeIcon){
                ranking = "Wont";

            } else {
                ranking = "Unknown";
            }

            bandRanks.put(bandName, ranking);

        }
        
        Log.d("FireBaseBandDataWrite", "🔥 firebase BAND_WRITE: Built priority array for " + bandRanks.size() + " bands");

    }

    /**
     * Checks if the band ranking data has changed since last write.
     * @return True if data has changed, false otherwise.
     */
    private Boolean checkIfDataHasChanged(){

        Boolean result = true;

        Map<String,String> bandRankCache = new HashMap<>();

        if (bandRankCacheFile.exists() == true){

            try {
                FileInputStream fileInStream = new FileInputStream(bandRankCacheFile);
                ObjectInputStream objectInStream = new ObjectInputStream(fileInStream);

                bandRankCache = (Map<String,String>) objectInStream.readObject();

                if (bandRankCache.equals(bandRanks) == true){
                    result = false;
                }

            } catch (Exception error){
                Log.e("load Data Error", "on bandRankCacheFile.data " +  error.getMessage());
            }
        }


        try{
            FileOutputStream fileOutStream = new FileOutputStream(bandRankCacheFile);
            ObjectOutputStream objectOutStream = new ObjectOutputStream(fileOutStream);

            objectOutStream.writeObject(bandRanks);

        } catch (Exception error){
            Log.e("Save Data Error","on bandRankCacheFile.data " +  error.getMessage());
        }

        Log.e("writing band data","Has changed is " + result.toString());

        return result;
    }
}

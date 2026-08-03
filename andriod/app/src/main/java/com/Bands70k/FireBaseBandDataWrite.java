package com.Bands70k;

import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.DatabaseError;

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

    private Map<String,String> bandRanks = new HashMap<>();
    private File bandRankCacheFile = new File(showBands.newRootDir + FileHandler70k.directoryName + "bandRankCacheFile.data");

    FireBaseBandDataWrite(){
    }

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
                .replaceAll("[\\p{Cntrl}]", "")
                .trim();
    }

    /**
     * Writes band ranking data to Firebase if data has changed.
     * @param onComplete Called after the batch write finishes (or not at all if skipped).
     * @return 1 if a Firebase callback will fire, otherwise 0.
     */
    public int writeData(Runnable onComplete) {

        Log.d("FireBaseBandDataWrite", "In write routine");

        if (staticVariables.isTestingEnv == false && staticVariables.userID.isEmpty() == false) {
            int storageYear = FirebaseConnectionHelper.firebaseStorageEventYear();
            if (storageYear <= 0) {
                Log.e("FireBaseBandDataWrite", "BLOCKED - pointer Current event year unavailable; refusing invalid write");
                return 0;
            }

            buildBandRankArray(storageYear);

            if (bandRanks.isEmpty()) {
                Log.e("FireBaseBandDataWrite", "BLOCKED - no lineup bands for pointer year " + storageYear + "; refusing invalid write");
                return 0;
            }

            if (checkIfDataHasChanged() == true) {
                String eventYear = String.valueOf(storageYear);
                DatabaseReference bandDataRef = FirebaseConnectionHelper.databaseReference()
                        .child("bandData/").child(staticVariables.userID).child(eventYear);
                
                Map<String, Object> batchUpdate = new HashMap<>();
                
                for (String bandName : bandRanks.keySet()) {
                    HashMap<String, Object> bandData = new HashMap<>();

                    String ranking = bandRanks.get(bandName);
                    String sanitizedBandName = sanitizeBandNameForFirebase(bandName);

                    bandData.put("bandName", bandName);
                    bandData.put("sanitizedKey", sanitizedBandName);
                    bandData.put("ranking", ranking);
                    bandData.put("userID", staticVariables.userID);
                    bandData.put("year", eventYear);

                    batchUpdate.put(sanitizedBandName, bandData);
                }
                
                Log.d("FireBaseBandDataWrite", "BATCH setValue for " + batchUpdate.size()
                        + " lineup bands at bandData/" + staticVariables.userID + "/" + eventYear
                        + " (uiEventYear=" + staticVariables.eventYear + ")");
                try {
                    bandDataRef.setValue(batchUpdate, (DatabaseError error, DatabaseReference ref) -> {
                        if (error != null) {
                            Log.e("FireBaseBandDataWrite", "Batch write failed: " + error.getMessage());
                            FirebaseWriteMonitor.recordWriteFailure("band_batch");
                        } else {
                            Log.d("FireBaseBandDataWrite", "Batch write successful for pointer year " + eventYear);
                            FirebaseWriteMonitor.recordWriteSuccess("band_batch");
                        }
                        if (onComplete != null) {
                            onComplete.run();
                        }
                    });
                    return 1;
                } catch (Exception error){
                    Log.e("FireBaseBandDataWrite", "Batch write exception: " + error.toString());
                    FirebaseWriteMonitor.recordWriteFailure("band_batch_exception");
                    if (onComplete != null) {
                        onComplete.run();
                    }
                    return 1;
                }
            }
        }
        return 0;
    }

    public void writeData() {
        writeData(null);
    }

    /**
     * Builds lineup band rankings for the pointer storage year.
     * Skips when loaded UI year does not match pointer year — we cannot produce valid data.
     */
    private void buildBandRankArray(int storageYear){
        bandRanks.clear();

        if (staticVariables.eventYear != null && staticVariables.eventYear > 0
                && staticVariables.eventYear != storageYear) {
            Log.e("FireBaseBandDataWrite", "BLOCKED - UI year " + staticVariables.eventYear
                    + " != pointer storage year " + storageYear + "; refusing invalid band write");
            return;
        }

        BandInfo bandInfoNames = new BandInfo();
        List<String> bandNames = bandInfoNames.getBandNames();
        
        Log.d("FireBaseBandDataWrite", "Building band array for pointer year " + storageYear
                + " — " + bandNames.size() + " lineup bands loaded");

        if (bandNames.isEmpty()) {
            Log.e("FireBaseBandDataWrite", "No lineup bands loaded for pointer year " + storageYear);
            return;
        }

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
        
        Log.d("FireBaseBandDataWrite", "Built priority array for " + bandRanks.size() + " lineup bands");
    }

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

        Log.d("FireBaseBandDataWrite", "Has changed is " + result.toString());
        return result;
    }
}

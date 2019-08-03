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

public class FireBaseBandDataWrite {

    private DatabaseReference mDatabase;

    private Map<String,String> bandRanks = new HashMap<>();
    private File bandRankCacheFile = new File(showBands.newRootDir + FileHandler70k.directoryName + "bandRankCacheFile.data");

    FireBaseBandDataWrite(){
            mDatabase = FirebaseDatabase.getInstance().getReference();
    }


    public void writeData(){

        Log.d("FireBaseBandDataWrite", "In write routine");

        if (staticVariables.isTestingEnv == false) {
            buildBandRankArray();
            Log.d("FireBaseBandDataWrite", "has data changed");

            if (checkIfDataHasChanged() == true) {
                for (String bandName : bandRanks.keySet()) {

                    HashMap<String, Object> bandData = new HashMap<>();

                    String eventYear = String.valueOf(staticVariables.eventYear);
                    String ranking = bandRanks.get(bandName);

                    bandData.put("bandName", bandName);
                    bandData.put("ranking", ranking);
                    bandData.put("year", eventYear);

                    Log.d("FireBaseBandDataWrite", "Writing band data " + bandData.toString());

                    mDatabase.child("bandData/").child(staticVariables.userID).child(eventYear).child(bandName).setValue(bandData);

                }
            }
        }
    }

    private void buildBandRankArray(){

        BandInfo bandInfoNames = new BandInfo();
        List<String> bandNames = bandInfoNames.getBandNames();

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

        Log.e("writing user data","Has changed is " + result.toString());

        return result;
    }
}

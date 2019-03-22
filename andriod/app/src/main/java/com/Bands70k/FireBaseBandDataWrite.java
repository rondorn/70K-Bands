package com.Bands70k;

import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;

import android.provider.Settings;
import android.util.Log;

import java.util.HashMap;
import java.util.List;


public class FireBaseBandDataWrite {

    private DatabaseReference mDatabase;

    FireBaseBandDataWrite(){
            mDatabase = FirebaseDatabase.getInstance().getReference();
    }


    public void writeData(){

        BandInfo bandInfoNames = new BandInfo();
        List<String> bandNames = bandInfoNames.getBandNames();

        for (String bandName: bandNames) {

            String ranking = rankStore.getRankForBand(bandName);

            HashMap<String, Object> bandData = new HashMap<>();

            String eventYear = String.valueOf(staticVariables.eventYear);

            if (ranking == staticVariables.mustSeeIcon){
                ranking = "Must";

            } else if (ranking == staticVariables.mightSeeIcon){
                ranking = "Might";

            } else if (ranking == staticVariables.wontSeeIcon){
                ranking = "Wont";

            } else {
                ranking = "Unknown";
            }

            bandData.put("bandName", bandName);
            bandData.put("ranking", ranking);
            bandData.put("year", eventYear);

            Log.d("FireBaseBandDataWrite", "Writing band data " + bandData.toString());

            mDatabase.child("bandData/").child(staticVariables.userID).child(eventYear).child(bandName).setValue(bandData);

        }
    }
}

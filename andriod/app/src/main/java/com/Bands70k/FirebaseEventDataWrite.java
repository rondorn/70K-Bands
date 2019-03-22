package com.Bands70k;


import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;

import android.provider.Settings;
import android.util.Log;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class FirebaseEventDataWrite {


    private DatabaseReference mDatabase;

    FirebaseEventDataWrite(){
        mDatabase = FirebaseDatabase.getInstance().getReference();
    }


    public void writeData(){



        showsAttended attendedHandler = new showsAttended();
        Map<String, String> showsAttendedArray = attendedHandler.getShowsAttended();

        for (String index : showsAttendedArray.keySet()) {

            HashMap<String, Object> eventData = new HashMap<>();

            String[] indexArray = index.split(":");

            String bandName = indexArray[0];
            String location = indexArray[1];
            String startTimeHour = indexArray[2];
            String startTimeMin = indexArray[3];
            String eventType = indexArray[4];
            String eventYear = indexArray[5];

            String attendedStatus = showsAttendedArray.get(index);

            eventData.put("bandName", bandName);
            eventData.put("location", location);
            eventData.put("startTimeHour", startTimeHour);
            eventData.put("startTimeMin", startTimeMin);
            eventData.put("eventType", eventType);
            eventData.put("status", attendedStatus);

            Log.d("FireBaseBandDataWrite", "Writing band data " + eventData.toString());

            mDatabase.child("showData/").child(staticVariables.userID).child(eventYear).child(index).setValue(eventData);
        }
    }
}

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

public class FirebaseEventDataWrite {


    private DatabaseReference mDatabase;
    private File eventDataCacheFile = new File(showBands.newRootDir + FileHandler70k.directoryName + "eventDataCacheFile.data");


    FirebaseEventDataWrite(){
        mDatabase = FirebaseDatabase.getInstance().getReference();
    }


    public void writeData(){

        if (staticVariables.isTestingEnv == false && staticVariables.userID.isEmpty() == false) {
            showsAttended attendedHandler = new showsAttended();
            Map<String, String> showsAttendedArray = attendedHandler.getShowsAttended();

            if (checkIfDataHasChanged(showsAttendedArray)) {
                for (String index : showsAttendedArray.keySet()) {

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
    }


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

        Log.e("writing user data","Has changed is " + result.toString());

        return result;
    }
}

package com.Bands70k;

import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import android.provider.Settings.Secure;
import android.util.Log;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashMap;
import java.util.Locale;
import java.util.TimeZone;

public class FirebaseUserWrite {

    private DatabaseReference mDatabase;

    FirebaseUserWrite(){
        mDatabase = FirebaseDatabase.getInstance().getReference();
    }


    public void writeData(){

        if (staticVariables.isTestingEnv == false && staticVariables.userID.isEmpty() == false) {
            //FirebaseDatabase.getInstance().goOnline();
            HashMap<String, Object> userData = new HashMap<>();

            if (staticVariables.userCountry.isEmpty()){
                staticVariables.userCountry = FileHandler70k.loadData(FileHandler70k.countryFile);
            }

            String country = staticVariables.userCountry;
            String language = Locale.getDefault().getLanguage();

            userData.put("userID", staticVariables.userID);
            userData.put("country", country);
            userData.put("language", language);
            userData.put("platform", "Android");
            userData.put("lastLaunch", getCurrentDateString());

            Log.d("FirebaseUserWrite", "Writing user data " + userData.toString());

            mDatabase.child("userData/").child(staticVariables.userID).setValue(userData);
            //FirebaseDatabase.getInstance().goOffline();
        }
    }

    private String getCurrentDateString(){

        Date date = new Date();
        SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        dateFormat.setTimeZone(TimeZone.getTimeZone("UTC"));

        String currentUTCDate = dateFormat.format(date);

        return currentUTCDate;
    }
}

package com.Bands70k;

import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;

import android.content.pm.PackageInfo;
import android.os.AsyncTask;
import android.os.StrictMode;
import android.provider.Settings.Secure;
import android.util.Log;

import java.text.DateFormat;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
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
            String version70k = "Unknown";
            try {
                PackageInfo pInfo = staticVariables.context.getPackageManager().getPackageInfo(staticVariables.context.getPackageName(), 0);
                version70k = pInfo.versionName;
            } catch (Exception error){
                //do nothing
            }

            //FirebaseDatabase.getInstance().goOnline();
            HashMap<String, Object> userData = new HashMap<>();

            //if country is empty, read from the file
            if (staticVariables.userCountry.isEmpty()){
                staticVariables.userCountry = FileHandler70k.loadData(FileHandler70k.countryFile);
            }
            //if country is still empty, use the default local for now
            if (staticVariables.userCountry.isEmpty()){
                staticVariables.userCountry = Locale.getDefault().getCountry();
            }

            String country = staticVariables.userCountry;
            String language = Locale.getDefault().getLanguage();

            userData.put("userID", staticVariables.userID);
            userData.put("country", country);
            userData.put("language", language);
            userData.put("platform", "Android");
            userData.put("lastLaunch", getCurrentDateString());
            userData.put("70kVersion", version70k);
            userData.put("osVersion", android.os.Build.VERSION.SDK_INT);

            DateFormat formatter = new SimpleDateFormat("dd/MM/yyyy");
            Date today = new Date();
            Date dateOnly = null;
            try {
                dateOnly = formatter.parse(formatter.format(today));
            } catch (ParseException e) {
                throw new RuntimeException(e);
            }
            String currentUserdata = country + '-' + language + '-' + version70k + dateOnly;

            if (currentUserdata.equals(staticVariables.userDataForCompareAndWriteBlock ) == true){
                Log.d("FirebaseUserWrite", "NOT Writing user data " + userData.toString());
            } else {
                //get second to sleep trying to prevent an announcement from fillingup all available connections
                int random_int = (int)Math.floor(Math.random() * (30000 - 5000 + 1) + 5000);
                try {
                    Log.d("FirebaseUserWrite", "Writing user data sleep for " + String.valueOf(random_int));
                    Thread.sleep(random_int);
                } catch (InterruptedException e) {
                    throw new RuntimeException(e);
                }

                staticVariables.userDataForCompareAndWriteBlock = country + '-' + language + '-' + version70k + dateOnly;
                Log.d("FirebaseUserWrite", "Writing user data " + userData.toString());
                mDatabase.child("userData/").child(staticVariables.userID).setValue(userData);
            }
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

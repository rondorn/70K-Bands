package com.Bands70k;

import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.DatabaseError;
import java.util.Map;

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

/**
 * Handles writing user data to Firebase, including country, language, and version info.
 */
public class FirebaseUserWrite {

    private DatabaseReference mDatabase;

    /**
     * Constructs a FirebaseUserWrite and initializes the database reference.
     */
    FirebaseUserWrite(){
        mDatabase = FirebaseDatabase.getInstance().getReference();
    }

    /**
     * Writes user data to Firebase if data has changed.
     */
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
                // Use delayed execution instead of blocking sleep for rate limiting
                int delayMs = (int) Math.floor(Math.random() * (30000 - 5000 + 1) + 5000);
                Log.d("FirebaseUserWrite", "Scheduling user data write after " + delayMs + "ms delay for rate limiting");
                
                staticVariables.userDataForCompareAndWriteBlock = country + '-' + language + '-' + version70k + dateOnly;
                
                ThreadManager.getInstance().runOnUiThreadDelayed(() -> {
                    ThreadManager.getInstance().executeNetwork(() -> {
                        Log.d("FirebaseUserWrite", "🔥 BATCH_WRITE: Writing user data " + userData.toString());
                        // User data is already a single write, but using updateChildren for consistency
                        Map<String, Object> batchUpdate = new HashMap<>();
                        batchUpdate.put(staticVariables.userID, userData);
                        mDatabase.child("userData/").updateChildren(batchUpdate, (error, ref) -> {
                            if (error != null) {
                                Log.e("FirebaseUserWrite", "Batch write failed: " + error.getMessage());
                            } else {
                                Log.d("FirebaseUserWrite", "Batch write successful for user data");
                            }
                        });
                    });
                }, delayMs);
            }
        }
    }

    /**
     * Gets the current date string in UTC format.
     * @return The current date string in UTC.
     */
    private String getCurrentDateString(){

        Date date = new Date();
        SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        dateFormat.setTimeZone(TimeZone.getTimeZone("UTC"));

        String currentUTCDate = dateFormat.format(date);

        return currentUTCDate;
    }
}

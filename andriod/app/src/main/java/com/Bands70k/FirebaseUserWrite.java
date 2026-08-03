package com.Bands70k;

import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.DatabaseError;

import android.content.pm.PackageInfo;
import android.util.Log;

import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.TimeZone;

/**
 * Handles writing user data to Firebase, including country, language, and version info.
 */
public class FirebaseUserWrite {

    /**
     * Writes user data to Firebase when invoked by {@link FirebaseUserWriteScheduler}.
     * Opens the RTDB connection lazily and closes it after the write completes.
     */
    public void performScheduledWrite() {
        if (staticVariables.isTestingEnv || staticVariables.userID.isEmpty()) {
            return;
        }

        String version70k = "Unknown";
        try {
            PackageInfo pInfo = staticVariables.context.getPackageManager()
                    .getPackageInfo(staticVariables.context.getPackageName(), 0);
            version70k = pInfo.versionName;
        } catch (Exception ignored) {
        }

        if (staticVariables.userCountry.isEmpty()) {
            staticVariables.userCountry = FileHandler70k.loadData(FileHandler70k.countryFile);
        }
        if (staticVariables.userCountry.isEmpty()) {
            staticVariables.userCountry = Locale.getDefault().getCountry();
        }

        String country = staticVariables.userCountry;
        String language = Locale.getDefault().getLanguage();

        DateFormat formatter = new SimpleDateFormat("dd/MM/yyyy", Locale.US);
        String dateOnly = formatter.format(new Date());
        String currentUserdata = country + '-' + language + '-' + version70k + dateOnly;

        if (currentUserdata.equals(staticVariables.userDataForCompareAndWriteBlock)) {
            Log.d("FirebaseUserWrite", "NOT Writing user data — dedup match");
            return;
        }

        staticVariables.userDataForCompareAndWriteBlock = currentUserdata;

        int activeProfileCount = SQLiteProfileManager.getInstance().getAllProfiles().size();

        HashMap<String, Object> userData = new HashMap<>();
        userData.put("userID", staticVariables.userID);
        userData.put("country", country);
        userData.put("language", language);
        userData.put("platform", "Android");
        userData.put("lastLaunch", getCurrentDateString());
        userData.put("70kVersion", version70k);
        userData.put("osVersion", android.os.Build.VERSION.SDK_INT);
        userData.put("activeProfiles", activeProfileCount);

        DatabaseReference database = FirebaseConnectionHelper.databaseReference();
        Map<String, Object> batchUpdate = new HashMap<>();
        batchUpdate.put(staticVariables.userID, userData);

        Log.d("FirebaseUserWrite", "Writing user data " + userData);
        database.child("userData/").updateChildren(batchUpdate, (DatabaseError error, DatabaseReference ref) -> {
            if (error != null) {
                Log.e("FirebaseUserWrite", "Batch write failed: " + error.getMessage());
                FirebaseWriteMonitor.recordWriteFailure("user_batch");
            } else {
                Log.d("FirebaseUserWrite", "Batch write successful for user data");
                FirebaseWriteMonitor.recordWriteSuccess("user_batch");
            }
            FirebaseConnectionHelper.goOffline("user_write_complete");
        });
    }

    /**
     * @deprecated Use {@link FirebaseUserWriteScheduler#scheduleWriteIfNeeded()} instead.
     */
    @Deprecated
    public void writeData() {
        FirebaseUserWriteScheduler.scheduleWriteIfNeeded();
    }

    private String getCurrentDateString() {
        SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US);
        dateFormat.setTimeZone(TimeZone.getTimeZone("UTC"));
        return dateFormat.format(new Date());
    }
}

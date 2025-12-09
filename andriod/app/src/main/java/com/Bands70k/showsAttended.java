package com.Bands70k;

import android.util.Log;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.ResourceBundle;

/**
 * PROFILE-AWARE: This class now supports multiple profiles
 * - Default profile uses: 70kBands/showsAttended.data
 * - Other profiles use: profiles/{profileId}/showsAttended.data
 */
public class showsAttended {

    private Map<String,String> showsAttendedHash = new HashMap<String,String>();
    private File showsAttendedFile = FileHandler70k.showsAttendedFile;
    private String currentLoadedProfile = null;  // Track which profile is currently loaded

    public showsAttended(){
        showsAttendedHash = loadShowsAttended();
    }
    
    /**
     * Gets the correct file path based on active profile
     */
    private File getFileForActiveProfile() {
        String activeProfile = SharedPreferencesManager.getInstance().getActivePreferenceSource();
        
        if ("Default".equals(activeProfile)) {
            // Use standard file for Default profile
            return FileHandler70k.showsAttendedFile;
        } else {
            // Use profile-specific file
            File profileDir = new File(Bands70k.getAppContext().getFilesDir(), "profiles/" + activeProfile);
            return new File(profileDir, "showsAttended.data");
        }
    }
    
    /**
     * Reloads data from the active profile
     * Called when user switches profiles
     */
    public void reloadForActiveProfile() {
        String activeProfile = SharedPreferencesManager.getInstance().getActivePreferenceSource();
        Log.d("showsAttended", "🔄 [PROFILE_RELOAD] Reloading attendance for profile: " + activeProfile);
        
        // Clear current data
        showsAttendedHash.clear();
        currentLoadedProfile = null;
        
        // Reload from correct profile
        showsAttendedHash = loadShowsAttended();
    }

    public Map<String,String> getShowsAttended(){
        String activeProfile = SharedPreferencesManager.getInstance().getActivePreferenceSource();
        
        // Reload if profile changed
        if (!activeProfile.equals(currentLoadedProfile)) {
            Log.d("showsAttended", "🔄 [PROFILE_CHECK] Profile changed. Current: " + currentLoadedProfile + ", Active: " + activeProfile);
            reloadForActiveProfile();
        }
        
        return showsAttendedHash;
    }

    public void saveShowsAttended(Map<String,String> showsAttendedHash){
        String activeProfile = SharedPreferencesManager.getInstance().getActivePreferenceSource();
        
        File fileToSave = getFileForActiveProfile();
        
        // Ensure directory exists for profile-specific files
        File parentDir = fileToSave.getParentFile();
        if (parentDir != null && !parentDir.exists()) {
            parentDir.mkdirs();
        }

        if (showsAttendedHash.size() > 0) {
            Log.d("ShowsAttended", "loadShowsAttended " + staticVariables.eventYearIndex);
            Log.d("Save showsAttendedHash", showsAttendedHash.toString());
            try {

                //Saving of object in a file
                FileOutputStream file = new FileOutputStream(fileToSave);
                ObjectOutputStream out = new ObjectOutputStream(file);

                // Method for serialization of object
                out.writeObject(showsAttendedHash);

                out.close();
                file.close();
                
                Log.d("showsAttended", "💾 [PROFILE_SAVE] Saved to profile '" + activeProfile + "': " + fileToSave.getPath());

            } catch (Exception error) {
                Log.e("ShowsAttended Error", "Unable to save attended tracking data " + error.getLocalizedMessage());
                Log.e("ShowsAttended Error", "Unable to save attended tracking data " + error.fillInStackTrace());
            }
        }
    }

    public Map<String,String>  loadShowsAttended() {
        String activeProfile = SharedPreferencesManager.getInstance().getActivePreferenceSource();
        File fileToLoad = getFileForActiveProfile();
        
        Log.d("showsAttended", "📂 [PROFILE_LOAD] Loading attendance for profile '" + activeProfile + "' from: " + fileToLoad.getPath());

        Map<String, String> showsAttendedHash = new HashMap<String, String>();

        try {
            if (!fileToLoad.exists()) {
                Log.d("showsAttended", "📂 [PROFILE_LOAD] File doesn't exist for profile '" + activeProfile + "', starting with empty attendance");
                currentLoadedProfile = activeProfile;
                return showsAttendedHash;
            }
            
            Log.d("ShowsAttended", "loadShowsAttended " + staticVariables.eventYearIndex);
            // Reading the object from a file
            FileInputStream file = new FileInputStream(fileToLoad);
            ObjectInputStream in = new ObjectInputStream(file);

            // Method for deserialization of object
            showsAttendedHash = (Map<String, String>) in.readObject();

            in.close();
            file.close();

            showsAttendedHash = convertToNewFormat(showsAttendedHash);
            
            currentLoadedProfile = activeProfile;
            Log.d("showsAttended", "✅ [PROFILE_LOAD] Loaded " + showsAttendedHash.size() + " attendance records for profile '" + activeProfile + "'");

        } catch (Exception error) {
            Log.e("ShowsAttended Error", "Unable to load alert tracking data " + error.getMessage());
        }
        
        return showsAttendedHash;
    }

    private Map<String,String> convertToNewFormat(Map<String,String> showsAttendedArray) {

        List<String> unuiqueSpecial = new ArrayList<String>();

        BandInfo bandInfoNames = new BandInfo();
        List<String> bandNames = bandInfoNames.getBandNames();

        if (showsAttendedArray.size() > 0) {

            for (String index : showsAttendedArray.keySet()) {

                String[] indexArray = index.split(":");

                String bandName = indexArray[0];
                String eventType = indexArray[4];
                Log.d("loadShowAttended", "index = " + index);
                if (indexArray.length == 5 && staticVariables.preferences.getUseLastYearsData() == false) {
                    Integer useEventYear = staticVariables.eventYear;


                    if (bandNames.contains(bandName) == false) {
                        if ((eventType == staticVariables.specialEvent || eventType == staticVariables.unofficalEvent) && unuiqueSpecial.contains(bandName) == false) {
                            unuiqueSpecial.add(bandName);
                        }
                    }
                    String newIndex = index + ":" + String.valueOf(useEventYear);
                    Log.d("loadShowAttended", "using new index of " + newIndex);
                    showsAttendedArray.put(newIndex, showsAttendedArray.get(index));
                    showsAttendedArray.remove(index);
                }
            }
        }

        saveShowsAttended(showsAttendedArray);
        return showsAttendedArray;
    }

    public String addShowsAttended (String index, String attendedStatus) {

        index = index.replaceAll("\\.", "");
        String value = "";

        String[] valueTypes = index.split(":");
        String eventType = valueTypes[4];

        Log.d("showAttended", "adding show data" + index + "-" + eventType);
        Log.d("showAttended", showsAttendedHash.toString());

        if (attendedStatus.isEmpty() == true) {
            if (showsAttendedHash.containsKey(index) == false || showsAttendedHash.get(index).equals(staticVariables.sawNoneStatus)) {

                value = staticVariables.sawAllStatus;
                Log.d("showAttended", "Setting value to all for index " + index);
            } else if (showsAttendedHash.get(index).equals(staticVariables.sawAllStatus) && eventType.equals(staticVariables.show)) {
                value = staticVariables.sawSomeStatus;
                Log.d("showAttended", "Setting value to some for index " + index);
            } else if (showsAttendedHash.get(index).equals(staticVariables.sawSomeStatus)) {
                value = staticVariables.sawNoneStatus;
                Log.d("showAttended", "Setting value to none 1 for index " + index);
            } else {
                value = staticVariables.sawNoneStatus;
                Log.d("showAttended", "Setting value to none 2 for index " + index);
            }
        } else {
            value = attendedStatus;
        }
        this.showsAttendedHash.put(index,value);

        this.saveShowsAttended(showsAttendedHash);

        return value;
    }

    public String addShowsAttended (String band, String location, String startTime, String eventType) {

        // Ensure eventYear is set before using it
        if (staticVariables.eventYear == 0) {
            staticVariables.ensureEventYearIsSet();
        }
        String eventYear = String.valueOf(staticVariables.eventYear);

        String index = band + ":" + location + ":" + startTime + ":" + eventType + ":" + eventYear;
        String value = addShowsAttended(index, "");

        return value;
    }

    public String addShowsAttended (String band, String location, String startTime, String eventType, String attendedStatus) {

        // Ensure eventYear is set before using it
        if (staticVariables.eventYear == 0) {
            staticVariables.ensureEventYearIsSet();
        }
        String eventYear = String.valueOf(staticVariables.eventYear);

        String index = band + ":" + location + ":" + startTime + ":" + eventType + ":" + eventYear;
        String value = addShowsAttended(index, attendedStatus);

        return value;
    }

    public String getShowAttendedIcon(String index){

        Log.d("showAttended", "getting icon for index " + index);

        String[] valueTypes = index.split(":");

        String bandName = valueTypes[0];
        String location = valueTypes[1];
        String startTime = valueTypes[2] + ":" + valueTypes[3];
        String eventType = valueTypes[4];
        String eventyear = valueTypes[5];

        return getShowAttendedIcon(bandName,location,startTime,eventType, eventyear);
    }

    public String getShowAttendedColor(String index){

        String[] valueTypes = index.split(":");

        String bandName = valueTypes[0];
        String location = valueTypes[1];
        String startTime = valueTypes[2] + ":" + valueTypes[3];
        String eventType = valueTypes[4];
        String eventYear = valueTypes[5];

        return getShowAttendedColor(bandName, location, startTime, eventType, eventYear);
    }
    public String getShowAttendedColor(String band, String location, String startTime, String eventType, String eventYear) {

        String color = "";

        String value = getShowAttendedStatus(band, location, startTime, eventType, eventYear);

        if (value.equals(staticVariables.sawAllStatus)){
            color = staticVariables.sawNoneColor;

        } else if (value.equals(staticVariables.sawSomeStatus)){
            color = staticVariables.sawNoneColor;

        } else if (value.equals(staticVariables.sawNoneStatus)){
            color = staticVariables.sawNoneColor;
        }

        //Log.d("showAttended", "value is  " + band + " " + value + " icon is " + color);

        return color;
    }


    public String getShowAttendedIcon(String band, String location, String startTime, String eventType, String eventYear) {

        Log.d("showAttended", "getting icon for index " + band + "-" + location + "-" + startTime + "-" + eventYear);
        String icon = "";

        String value = getShowAttendedStatus(band,location,startTime,eventType, eventYear);

        if (value.equals(staticVariables.sawAllStatus)){
            icon = staticVariables.sawAllIcon;

        } else if (value.equals(staticVariables.sawSomeStatus)){
            icon = staticVariables.sawSomeIcon;

        } else if (value.equals(staticVariables.sawNoneStatus)){
            icon = staticVariables.sawNoneIcon;
        }

        Log.d("showAttended", "getting icon for index " + band + "-" + location + "-" + startTime + "-" + eventYear + " got - " + icon);

        return icon;
    }

    public String getShowAttendedStatus(String index) {

        String value = "";

        if (showsAttendedHash.containsKey(index) == false) {
            value = staticVariables.sawNoneStatus;

        } else if (showsAttendedHash.get(index).equals(staticVariables.sawAllStatus)){
            value = staticVariables.sawAllStatus;

        } else if (showsAttendedHash.get(index).equals(staticVariables.sawSomeStatus)){
            value = staticVariables.sawSomeStatus;

        } else {
            value = staticVariables.sawNoneStatus;

        }

        return value;
    }

    public String getShowAttendedStatus(String band, String location, String startTime, String eventType, String eventYear) {

        String index = band + ":" + location + ":" + startTime + ":" + eventType + ":" + eventYear;

        return getShowAttendedStatus(index);

    }

    public String setShowsAttendedStatus(String status){

        String message = "";

        if (status.equals(staticVariables.sawAllStatus)){
            message = staticVariables.context.getResources().getString(R.string.AllOfEvent);

        } else if (status.equals(staticVariables.sawSomeStatus)){
            message = staticVariables.context.getResources().getString(R.string.PartOfEvent);

        } else {
            message = staticVariables.context.getResources().getString(R.string.NoneOfEvent);

        }

        return message;
    }

}

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

public class showsAttended {

    private Map<String,String> showsAttendedHash = new HashMap<String,String>();
    private File showsAttendedFile = FileHandler70k.showsAttendedFile;

    public showsAttended(){
        showsAttendedHash = loadShowsAttended();
    }

    public Map<String,String> getShowsAttended(){
        return showsAttendedHash;
    }

    public void saveShowsAttended(Map<String,String> showsAttendedHash){

        if (showsAttendedHash.size() > 0) {
            Log.d("ShowsAttended", "loadShowsAttended " + staticVariables.eventYearIndex);
            Log.d("Save showsAttendedHash", showsAttendedHash.toString());
            try {

                //Saving of object in a file
                FileOutputStream file = new FileOutputStream(showsAttendedFile);
                ObjectOutputStream out = new ObjectOutputStream(file);

                // Method for serialization of object
                out.writeObject(showsAttendedHash);

                out.close();
                file.close();

            } catch (Exception error) {
                Log.e("ShowsAttended Error", "Unable to save attended tracking data " + error.getLocalizedMessage());
                Log.e("ShowsAttended Error", "Unable to save attended tracking data " + error.fillInStackTrace());
            }
        }
    }

    public Map<String,String>  loadShowsAttended() {

        Map<String, String> showsAttendedHash = new HashMap<String, String>();

        try {
            Log.d("ShowsAttended", "loadShowsAttended " + staticVariables.eventYearIndex);
            // Reading the object from a file
            FileInputStream file = new FileInputStream(showsAttendedFile);
            ObjectInputStream in = new ObjectInputStream(file);

            // Method for deserialization of object
            showsAttendedHash = (Map<String, String>) in.readObject();

            in.close();
            file.close();

            showsAttendedHash = convertToNewFormat(showsAttendedHash);

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

        String eventYear = String.valueOf(staticVariables.eventYear);

        String index = band + ":" + location + ":" + startTime + ":" + eventType + ":" + eventYear;
        String value = addShowsAttended(index, "");

        return value;
    }

    public String addShowsAttended (String band, String location, String startTime, String eventType, String attendedStatus) {

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

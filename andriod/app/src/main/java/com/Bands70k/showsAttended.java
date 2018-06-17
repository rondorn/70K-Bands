package com.Bands70k;

import android.util.Log;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.util.HashMap;
import java.util.Map;

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

        Log.d("Save showsAttendedHash", showsAttendedHash.toString());
        try {

            //Saving of object in a file
            FileOutputStream file = new FileOutputStream(showsAttendedFile);
            ObjectOutputStream out = new ObjectOutputStream(file);

            // Method for serialization of object
            out.writeObject(showsAttendedHash);

            out.close();
            file.close();

        } catch (Exception error){
            Log.e("Error", "Unable to save attended tracking data " + error.getLocalizedMessage());
            Log.e("Error", "Unable to save attended tracking data " + error.fillInStackTrace());
        }
    }

    public Map<String,String>  loadShowsAttended() {

        Map<String, String> showsAttendedHash = new HashMap<String, String>();

        try {
            // Reading the object from a file
            FileInputStream file = new FileInputStream(showsAttendedFile);
            ObjectInputStream in = new ObjectInputStream(file);

            // Method for deserialization of object
            showsAttendedHash = (Map<String, String>) in.readObject();

            in.close();
            file.close();

        } catch (Exception error) {
            Log.e("Error", "Unable to load alert tracking data " + error.getMessage());
        }

        return showsAttendedHash;
    }

    public String addShowsAttended (String index) {

        String value = "";

        String[] valueTypes = index.split(":");
        String eventType = valueTypes[4];

        Log.d("showAttended", "adding " + index + "-" + eventType);
        Log.d("showAttended", showsAttendedHash.toString());

        if (showsAttendedHash.containsKey(index) == false || showsAttendedHash.get(index).equals(staticVariables.sawNoneStatus)){

            value = staticVariables.sawAllStatus;

        } else if (showsAttendedHash.get(index).equals(staticVariables.sawAllStatus) && eventType.equals(staticVariables.show)){
            value = staticVariables.sawSomeStatus;

        } else if (showsAttendedHash.get(index).equals(staticVariables.sawSomeStatus)){
            value = staticVariables.sawNoneStatus;

        } else {
            value = staticVariables.sawNoneStatus;
        }

        this.showsAttendedHash.put(index,value);

        this.saveShowsAttended(showsAttendedHash);

        return value;
    }

    public String addShowsAttended (String band, String location, String startTime, String eventType) {

        String index = band + ":" + location + ":" + startTime + ":" + eventType;
        String value = addShowsAttended(index);

        return value;
    }

    public String getShowAttendedIcon(String index){

        String[] valueTypes = index.split(":");

        String bandName = valueTypes[0];
        String location = valueTypes[1];
        String startTime = valueTypes[2] + ":" + valueTypes[3];
        String eventType = valueTypes[4];

        return getShowAttendedIcon(bandName,location,startTime,eventType);
    }

    public String getShowAttendedColor(String index){

        String[] valueTypes = index.split(":");

        String bandName = valueTypes[0];
        String location = valueTypes[1];
        String startTime = valueTypes[2] + ":" + valueTypes[3];
        String eventType = valueTypes[4];

        return getShowAttendedColor(bandName,location,startTime,eventType);
    }
    public String getShowAttendedColor(String band, String location, String startTime, String eventType) {

        String color = "";

        String value = getShowAttendedStatus(band,location,startTime,eventType);

        if (value.equals(staticVariables.sawAllStatus)){
            color = staticVariables.sawAllColor;

        } else if (value.equals(staticVariables.sawSomeStatus)){
            color = staticVariables.sawSomeColor;

        } else if (value.equals(staticVariables.sawNoneStatus)){
            color = staticVariables.sawNoneColor;
        }

        Log.d("showAttended", "value is  " + value + " icon is " + color);

        return color;
    }


    public String getShowAttendedIcon(String band, String location, String startTime, String eventType) {

        String icon = "";

        String value = getShowAttendedStatus(band,location,startTime,eventType);

        if (value.equals(staticVariables.sawAllStatus)){
            icon = staticVariables.sawAllIcon;

        } else if (value.equals(staticVariables.sawSomeStatus)){
            icon = staticVariables.sawSomeIcon;

        } else if (value.equals(staticVariables.sawNoneStatus)){
            icon = staticVariables.sawNoneIcon;
        }

        Log.d("showAttended", "value is  " + value + " icon is " + icon);

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

    public String getShowAttendedStatus(String band, String location, String startTime, String eventType) {

        String index = band + ":" + location + ":" + startTime + ":" + eventType;

        return getShowAttendedStatus(index);

    }

    public String setShowsAttendedStatus(String status){

        String message = "";

        if (status.equals(staticVariables.sawAllStatus)){
            // set color code
            // sender.textColor = sawAllColor

            //set new field text code
            //fieldText = sawAllIcon + fieldText!
            //        sender.text = fieldText

            message = "I saw all of this event!";

        } else if (status.equals(staticVariables.sawSomeStatus)){
            // set color code
            // sender.textColor = sawAllColor

            //set new field text code
            //fieldText = sawAllIcon + fieldText!
            //        sender.text = fieldText

            message = "I saw some of this event!";

        } else {
            // set color code
            // sender.textColor = sawAllColor

            //set new field text code
            //fieldText = sawAllIcon + fieldText!
            //        sender.text = fieldText

            message = "I saw none of this event!";
        }

        return message;
    }

    private String removeIcons(String text){

        String textValue = text;

        textValue = text.replace(staticVariables.sawAllIcon,"");
        textValue = text.replace(staticVariables.sawSomeIcon,"");

        return textValue;

    }
}

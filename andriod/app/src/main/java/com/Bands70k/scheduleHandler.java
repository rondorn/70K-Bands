package com.Bands70k;

import android.util.Log;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

/**
 * Created by rdorn on 8/19/15.
 */
public class scheduleHandler {

    private String showLocation;
    private String showDay;
    private String bandName;
    private String showNotes;
    private String showType;
    private String startTimeString;
    private String endTimeString;
    private Date startTime = new Date();
    private Date endTime = new Date();


    public String getStartTimeString() {
        return startTimeString;
    }

    public void setStartTimeString(String startTimeString) {
        this.startTimeString = startTimeString;
    }

    public String getEndTimeString() {
        return endTimeString;
    }

    public void setEndTimeString(String endTimeString) {
        this.endTimeString = endTimeString;
    }

    public Long getEpochStart(){
        return startTime.getTime();
    }

    public Long getEpochEnd(){
        return endTime.getTime();
    }

    public void setShowLocation(String value){
        showLocation = value;
    }
    public String getShowLocation() {
        return showLocation;
    }

    public void setShowDay(String value){
        showDay = value;
    }
    public String getShowDay() {
        return showDay;
    }

    public void setBandName(String value){
        bandName = value;
    }
    public String getBandName() {
        return bandName;
    }

    public void setShowType(String value){
        Log.d("setShowType", "showType is  " + value);
        if (value.equals(staticVariables.unofficalEventOld)){
            Log.d("setShowType", "changing showType to  " + staticVariables.unofficalEvent);
            value = staticVariables.unofficalEvent;
        }

        showType = value;
    }
    public String getShowType() {

        return showType;
    }

    public void setShowNotes(String value){
        showNotes = value;
    }

    public String getShowNotes() {

        if (showNotes == null){
            showNotes = "";
        }
        return showNotes;
    }


    public void setStartTime(String dateValue, String startTimeValue){

        SimpleDateFormat dateFormat = new SimpleDateFormat("MM/dd/yy HH:mm");
        try {
            startTime = dateFormat.parse(dateValue + ' ' + startTimeValue);
            Log.d("startTime", "starttime is " + startTime + " " + dateValue + " " + startTimeValue);
        } catch (ParseException e) {
            Log.d("ParseException", "Unable to parse start time. " + e.getStackTrace());
        }
    }
    public Date getStartTime() {
        return startTime;
    }

    public void setEndTime(String dateValue, String endTimeValue){

        SimpleDateFormat dateFormat = new SimpleDateFormat("MM/dd/yy HH:mm");
        try {
            endTime = dateFormat.parse(dateValue + ' ' + endTimeValue);
        } catch (ParseException e) {
            Log.d("ParseException", "Unable to parse end time. " + e.getStackTrace());
        }
    }
    public Date getEndTime() {
        return endTime;
    }

}

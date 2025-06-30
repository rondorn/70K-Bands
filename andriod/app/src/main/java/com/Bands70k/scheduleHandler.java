package com.Bands70k;

import android.util.Log;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

/**
 * Represents a scheduled event for a band, including location, time, and type.
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

    /**
     * Gets the start time string.
     * @return The start time string.
     */
    public String getStartTimeString() {
        return startTimeString;
    }

    /**
     * Sets the start time string.
     * @param startTimeString The start time string to set.
     */
    public void setStartTimeString(String startTimeString) {
        this.startTimeString = startTimeString;
    }

    /**
     * Gets the end time string.
     * @return The end time string.
     */
    public String getEndTimeString() {
        return endTimeString;
    }

    /**
     * Sets the end time string.
     * @param endTimeString The end time string to set.
     */
    public void setEndTimeString(String endTimeString) {
        this.endTimeString = endTimeString;
    }

    /**
     * Gets the epoch start time as a long.
     * @return The epoch start time.
     */
    public Long getEpochStart(){
        return startTime.getTime();
    }

    /**
     * Gets the epoch end time as a long.
     * @return The epoch end time.
     */
    public Long getEpochEnd(){
        return endTime.getTime();
    }

    /**
     * Sets the show location.
     * @param value The show location string.
     */
    public void setShowLocation(String value){
        showLocation = value;
    }
    /**
     * Gets the show location.
     * @return The show location string.
     */
    public String getShowLocation() {
        return showLocation;
    }

    /**
     * Sets the show day.
     * @param value The show day string.
     */
    public void setShowDay(String value){
        showDay = value;
    }
    /**
     * Gets the show day.
     * @return The show day string.
     */
    public String getShowDay() {
        return showDay;
    }

    /**
     * Sets the band name.
     * @param value The band name string.
     */
    public void setBandName(String value){
        bandName = value;
    }
    /**
     * Gets the band name.
     * @return The band name string.
     */
    public String getBandName() {
        return bandName;
    }

    /**
     * Sets the show type, converting old values if needed.
     * @param value The show type string.
     */
    public void setShowType(String value){
        Log.d("setShowType", "showType is  " + value);
        if (value.equals(staticVariables.unofficalEventOld)){
            Log.d("setShowType", "changing showType to  " + staticVariables.unofficalEvent);
            value = staticVariables.unofficalEvent;
        }

        showType = value;
    }
    /**
     * Gets the show type.
     * @return The show type string.
     */
    public String getShowType() {

        return showType;
    }

    /**
     * Sets the show notes.
     * @param value The show notes string.
     */
    public void setShowNotes(String value){
        showNotes = value;
    }

    /**
     * Gets the show notes.
     * @return The show notes string.
     */
    public String getShowNotes() {

        if (showNotes == null){
            showNotes = "";
        }
        return showNotes;
    }

    /**
     * Sets the start time from date and time strings.
     * @param dateValue The date string.
     * @param startTimeValue The start time string.
     */
    public void setStartTime(String dateValue, String startTimeValue){

        SimpleDateFormat dateFormat = new SimpleDateFormat("MM/dd/yy HH:mm");
        try {
            startTime = dateFormat.parse(dateValue + ' ' + startTimeValue);
            Log.d("startTime", "starttime is " + startTime + " " + dateValue + " " + startTimeValue);
        } catch (ParseException e) {
            Log.d("ParseException", "Unable to parse start time. " + e.getStackTrace());
        }
    }
    /**
     * Gets the start time as a Date object.
     * @return The start time Date.
     */
    public Date getStartTime() {
        return startTime;
    }

    /**
     * Sets the end time from date and time strings.
     * @param dateValue The date string.
     * @param endTimeValue The end time string.
     */
    public void setEndTime(String dateValue, String endTimeValue){

        SimpleDateFormat dateFormat = new SimpleDateFormat("MM/dd/yy HH:mm");
        try {
            endTime = dateFormat.parse(dateValue + ' ' + endTimeValue);
        } catch (ParseException e) {
            Log.d("ParseException", "Unable to parse end time. " + e.getStackTrace());
        }
    }
    /**
     * Gets the end time as a Date object.
     * @return The end time Date.
     */
    public Date getEndTime() {
        return endTime;
    }

}

package com.Bands70k;

import android.util.Log;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * Represents a scheduled event for a band, including location, time, and type.
 * Created by rdorn on 8/19/15.
 */
public class scheduleHandler {

    /** Match iOS ScheduleCSVImporter.calculateTimeIndex date/time patterns. */
    private static final String[] SCHEDULE_DATE_TIME_PATTERNS = {
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd H:mm",
            "yyyy-M-d HH:mm",
            "yyyy-M-d H:mm",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd H:mm:ss",
            "M/d/yyyy HH:mm",
            "MM/dd/yyyy HH:mm",
            "M/d/yyyy H:mm",
            "MM/dd/yyyy H:mm",
            "M/d/yyyy h:mm a",
            "MM/dd/yyyy h:mm a",
            "MM/dd/yyyy HH:mm:ss",
            "MM/dd/yyyy H:mm:ss",
            "M/d/yyyy HH:mm:ss",
            "M/d/yyyy H:mm:ss",
            "MM/dd/yy HH:mm",
            "MM/dd/yy H:mm",
            "M/d/yy HH:mm",
            "M/d/yy H:mm",
    };

    private String showLocation;
    private String showDay;
    private String bandName;
    private String showNotes;
    private String showType;
    private String startTimeString;
    private String endTimeString;
    /** Raw Date column from CSV (may be MM/dd/yyyy or yyyy-MM-dd). Preserved for export round-trips. */
    private String showDate;
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

    /** Raw calendar date string from the schedule CSV Date column. */
    public String getShowDate() {
        return showDate;
    }

    public void setShowDate(String value) {
        showDate = value != null ? value.trim() : null;
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
        showLocation = value != null ? value.trim() : null;
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
        showType = EventTypeConfig.normalize(value);
    }
    /**
     * Gets the show type.
     * @return The show type string.
     */
    public String getShowType() {
        return EventTypeConfig.normalize(showType);
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
        if (dateValue != null && !dateValue.trim().isEmpty()) {
            setShowDate(dateValue);
        }
        Date parsed = parseScheduleDateTime(dateValue, startTimeValue);
        if (parsed != null) {
            startTime = parsed;
            Log.d("startTime", "starttime is " + startTime + " " + dateValue + " " + startTimeValue);
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
        Date parsed = parseScheduleDateTime(dateValue, endTimeValue);
        if (parsed != null) {
            endTime = parsed;
        }
    }

    /** Parses a schedule date/time pair. Package-visible for unit tests. */
    static Date parseScheduleDateTime(String dateValue, String timeValue) {
        if (dateValue == null || timeValue == null) {
            return null;
        }
        String date = dateValue.trim();
        String time = timeValue.trim();
        if (date.isEmpty() || time.isEmpty()) {
            return null;
        }
        String dateTime = date + ' ' + time;
        for (String pattern : SCHEDULE_DATE_TIME_PATTERNS) {
            try {
                SimpleDateFormat dateFormat = new SimpleDateFormat(pattern, Locale.US);
                dateFormat.setLenient(false);
                return dateFormat.parse(dateTime);
            } catch (ParseException ignored) {
            }
        }
        Log.w("scheduleHandler", "Unable to parse schedule date/time: '" + dateTime + "'");
        return null;
    }
    /**
     * Gets the end time as a Date object.
     * @return The end time Date.
     */
    public Date getEndTime() {
        return endTime;
    }

}

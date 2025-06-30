package com.Bands70k;

/**
 * Represents a single band list item with all display and data fields.
 */
public class bandListItem {

    private int rankImg;
    private int eventTypeImage;
    private int attendedImage;
    private String bandName;
    private String location;
    private String locationColor;
    private String day;
    private String startTime;
    private String endTime;

    private String eventNote;

    /**
     * Constructs a bandListItem with the given band name.
     * @param bandName The name of the band.
     */
    public bandListItem(String bandName) {
        super();
        this.setBandName(bandName);
    }

    /**
     * Gets the band name.
     * @return The band name.
     */
    public String getBandName() {
        return bandName;
    }
    /**
     * Sets the band name.
     * @param bandName The band name to set.
     */
    public void setBandName(String bandName) {
        this.bandName = bandName;
    }

    /**
     * Gets the location.
     * @return The location string.
     */
    public String getLocation() {
        return location;
    }
    /**
     * Sets the location.
     * @param location The location string to set.
     */
    public void setLocation(String location) {
        this.location = location;
    }

    /**
     * Gets the event note.
     * @return The event note string.
     */
    public String getEventNote() {
        return eventNote;
    }
    /**
     * Sets the event note.
     * @param eventNote The event note string to set.
     */
    public void setEventNote(String eventNote) {
        this.eventNote = eventNote;
    }

    /**
     * Gets the location color.
     * @return The location color string.
     */
    public String getLocationColor() {
        return locationColor;
    }
    /**
     * Sets the location color.
     * @param locationColor The color string to set.
     */
    public void setLocationColor(String locationColor) {
        this.locationColor = locationColor;
    }

    /**
     * Gets the day string.
     * @return The day string.
     */
    public String getDay() {
        return day;
    }
    /**
     * Sets the day string, applying regional formatting.
     * @param day The day string to set.
     */
    public void setDay(String day) {
        this.day = Utilities.monthDateRegionalFormatting(day);
    }

    /**
     * Gets the start time string.
     * @return The start time string.
     */
    public String getStartTime() {
        return startTime;
    }
    /**
     * Sets the start time string.
     * @param startTime The start time string to set.
     */
    public void setStartTime(String startTime) {
        this.startTime = startTime;
    }

    /**
     * Gets the end time string.
     * @return The end time string.
     */
    public String getEndTime() {
        return endTime;
    }
    /**
     * Sets the end time string.
     * @param endTime The end time string to set.
     */
    public void setEndTime(String endTime) {
        this.endTime = endTime;
    }

    /**
     * Gets the rank image resource ID.
     * @return The rank image resource ID.
     */
    public int getRankImg() {
        return rankImg;
    }
    /**
     * Sets the rank image resource ID.
     * @param rankImg The rank image resource ID to set.
     */
    public void setRankImg(int rankImg) {
        this.rankImg = rankImg;
    }

    /**
     * Gets the event type image resource ID.
     * @return The event type image resource ID.
     */
    public int getEventTypeImage() {
        return eventTypeImage;
    }
    /**
     * Sets the event type image resource ID.
     * @param eventTypeImage The event type image resource ID to set.
     */
    public void setEventTypeImage(int eventTypeImage) {
        this.eventTypeImage = eventTypeImage;
    }

    /**
     * Gets the attended image resource ID.
     * @return The attended image resource ID.
     */
    public int getAttendedImage() {
        return attendedImage;
    }
    /**
     * Sets the attended image resource ID.
     * @param attendedImage The attended image resource ID to set.
     */
    public void setAttendedImage(int attendedImage) {
        this.attendedImage = attendedImage;
    }

}

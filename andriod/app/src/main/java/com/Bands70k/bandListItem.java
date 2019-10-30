package com.Bands70k;


public class bandListItem {

    private int rankImg;
    private int eventTypeImage;
    private int attendedImage;
    private String bandName;
    private String location;
    private String locationColor;
    private String day;
    private String startTime;


    public bandListItem(String bandName) {
        super();
        this.setBandName(bandName);
    }

    public String getBandName() {
        return bandName;
    }
    public void setBandName(String bandName) {
        this.bandName = bandName;
    }

    public String getLocation() {
        return location;
    }
    public void setLocation(String location) {
        this.location = location;
    }

    public String getLocationColor() {
        return locationColor;
    }
    public void setLocationColor(String locationColor) {
        this.locationColor = locationColor;
    }

    public String getDay() {
        return day;
    }
    public void setDay(String day) {
        this.day = Utilities.monthDateRegionalFormatting(day);
    }

    public String getStartTime() {
        return startTime;
    }
    public void setStartTime(String startTime) {
        this.startTime = startTime;
    }

    public int getRankImg() {
        return rankImg;
    }
    public void setRankImg(int rankImg) {
        this.rankImg = rankImg;
    }

    public int getEventTypeImage() {
        return eventTypeImage;
    }
    public void setEventTypeImage(int eventTypeImage) {
        this.eventTypeImage = eventTypeImage;
    }

    public int getAttendedImage() {
        return attendedImage;
    }
    public void setAttendedImage(int attendedImage) {
        this.attendedImage = attendedImage;
    }

}

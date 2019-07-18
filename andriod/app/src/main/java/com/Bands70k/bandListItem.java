package com.Bands70k;


public class bandListItem {

    private int rankImg;
    private int eventTypeImage;
    private int attendedImage;
    private String bandName;
    private String location;
    private String day;
    private String time;


    public bandListItem(){
        super();
    }

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


}

package com.Bands70k;

/**
 * Created by rdorn on 8/12/15.
 */
public class preferences {

    private Boolean sendAlerts = true;
    private Boolean mustSeeAlert = true;
    private Boolean mightSeeAlert = true;
    private Boolean alertForShows = true;
    private Boolean alertForSpecialEvents = true;
    private Boolean alertForMeetAndGreet = false;
    private Boolean alertForClinics = false;
    private Boolean alertForListeningParties = false;
    private Integer minBeforeToAlert = 10;

    private String artsistsUrl = "Default";
    private String scheduleUrl = "Default";

    public Boolean getSendAlerts() {
        return sendAlerts;
    }

    public void setSendAlerts(Boolean sendAlerts) {
        this.sendAlerts = sendAlerts;
    }

    public Boolean getMustSeeAlert() {
        return mustSeeAlert;
    }

    public void setMustSeeAlert(Boolean mustSeeAlert) {
        this.mustSeeAlert = mustSeeAlert;
    }

    public Boolean getMightSeeAlert() {
        return mightSeeAlert;
    }

    public void setMightSeeAlert(Boolean mightSeeAlert) {
        this.mightSeeAlert = mightSeeAlert;
    }

    public Boolean getAlertForShows() {
        return alertForShows;
    }

    public void setAlertForShows(Boolean alertForShows) {
        this.alertForShows = alertForShows;
    }

    public Boolean getAlertForSpecialEvents() {
        return alertForSpecialEvents;
    }

    public void setAlertForSpecialEvents(Boolean alertForSpecialEvents) {
        this.alertForSpecialEvents = alertForSpecialEvents;
    }

    public Boolean getAlertForMeetAndGreet() {
        return alertForMeetAndGreet;
    }

    public void setAlertForMeetAndGreet(Boolean alertForMeetAndGreet) {
        this.alertForMeetAndGreet = alertForMeetAndGreet;
    }

    public Boolean getAlertForClinics() {
        return alertForClinics;
    }

    public void setAlertForClinics(Boolean alertForClinics) {
        this.alertForClinics = alertForClinics;
    }

    public Boolean getAlertForListeningParties() {
        return alertForListeningParties;
    }

    public void setAlertForListeningParties(Boolean alertForListeningParties) {
        this.alertForListeningParties = alertForListeningParties;
    }

    public Integer getMinBeforeToAlert() {
        return minBeforeToAlert;
    }

    public void setMinBeforeToAlert(Integer minBeforeToAlert) {
        this.minBeforeToAlert = minBeforeToAlert;
    }

    public String getArtsistsUrl() {
        return artsistsUrl;
    }

    public void setArtsistsUrl(String artsistsUrl) {
        this.artsistsUrl = artsistsUrl;
    }

    public String getScheduleUrl() {
        return scheduleUrl;
    }

    public void setScheduleUrl(String scheduleUrl) {
        this.scheduleUrl = scheduleUrl;
    }

}

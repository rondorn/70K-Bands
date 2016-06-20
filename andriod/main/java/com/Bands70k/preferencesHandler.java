package com.Bands70k;


import android.os.Environment;
import android.util.Log;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileReader;


/**
 * Created by rdorn on 8/12/15.
 */
public class preferencesHandler {

    private Boolean mustSeeAlert = true;
    private Boolean mightSeeAlert = true;
    private Boolean alertForShows = true;
    private Boolean alertForSpecialEvents = true;
    private Boolean alertForMeetAndGreet = false;
    private Boolean alertForClinics = false;
    private Boolean alertForListeningParties = false;
    private Integer minBeforeToAlert = 10;
    private Boolean useLastYearsData = false;

    private Boolean showSpecialEvents = true;
    private Boolean showMeetAndGreet = true;
    private Boolean showClinicEvents = true;
    private Boolean showAlbumListen = true;

    private Boolean showPoolShows = true;
    private Boolean showTheaterShows = true;
    private Boolean showRinkShows = true;
    private Boolean showLoungeShows = true;
    private Boolean showOtherShows = true;

    private String artsistsUrl = "Default";
    private String scheduleUrl = "Default";

    public void loadData() {
        try {
            File file = FileHandler70k.bandPrefs;

            BufferedReader br = new BufferedReader(new FileReader(file));
            String line;

            while ((line = br.readLine()) != null) {
                String[] RowData = line.split(",");
                Log.d("Load Data", line);
                Log.d("Load Data", "Setting " + RowData[0] + " to be " + RowData[1]);
                switch (RowData[0]) {
                    case "mustSeeAlert":
                        setMustSeeAlert(Boolean.valueOf(RowData[1]));
                        break;

                    case "mightSeeAlert":
                        setMightSeeAlert(Boolean.valueOf(RowData[1]));
                        break;

                    case "alertForShows":
                        setAlertForShows(Boolean.valueOf(RowData[1]));
                        break;

                    case "showSpecialEvents":
                        setShowSpecialEvents(Boolean.valueOf(RowData[1]));
                        break;

                    case "showMeetAndGreet":
                        setShowMeetAndGreet(Boolean.valueOf(RowData[1]));
                        break;

                    case "showClinics":
                        setShowClinicEvents(Boolean.valueOf(RowData[1]));
                        break;

                    case "showListeningParties":
                        setShowAlbumListen(Boolean.valueOf(RowData[1]));
                        break;

                    case "showPoolShows":
                        setShowPoolShows(Boolean.valueOf(RowData[1]));
                        break;

                    case "showTheaterShows":
                        setShowTheaterShows(Boolean.valueOf(RowData[1]));
                        break;

                    case "showRinkShows":
                        setShowRinkShows(Boolean.valueOf(RowData[1]));
                        break;

                    case "showLoungeShows":
                        setShowLoungeShows(Boolean.valueOf(RowData[1]));
                        break;

                    case "showOtherShows":
                        setShowOtherShows(Boolean.valueOf(RowData[1]));
                        break;

                    case "alertForSpecialEvents":
                        setAlertForSpecialEvents(Boolean.valueOf(RowData[1]));
                        break;

                    case "alertForMeetAndGreet":
                        setAlertForMeetAndGreet(Boolean.valueOf(RowData[1]));
                        break;

                    case "alertForClinics":
                        setAlertForClinics(Boolean.valueOf(RowData[1]));
                        break;

                    case "alertForListeningParties":
                        setAlertForListeningParties(Boolean.valueOf(RowData[1]));
                        break;

                    case "useLastYearsData":
                        setUseLastYearsData(Boolean.valueOf(RowData[1]));
                        break;

                    case "minBeforeToAlert":
                        setMinBeforeToAlert(Integer.valueOf(RowData[1]));
                        break;

                    case "artistsUrl":
                        setArtsistsUrl(RowData[1]);
                        break;

                    case "scheduleUrl":
                        setScheduleUrl(RowData[1]);
                        break;
                }
            }
        } catch (Exception error){
                Log.e("Load Data Error", error.getMessage() + "\n" + error.fillInStackTrace());
        }
    }

    public void saveData() {

        String dataString = "";
        dataString += "mustSeeAlert," + mustSeeAlert.toString() + "\n";
        dataString += "mightSeeAlert," + mightSeeAlert.toString() + "\n";
        dataString += "alertForShows," + alertForShows.toString() + "\n";
        dataString += "alertForSpecialEvents," + alertForSpecialEvents.toString() + "\n";
        dataString += "alertForMeetAndGreet," + alertForMeetAndGreet.toString() + "\n";
        dataString += "alertForClinics," + alertForClinics.toString() + "\n";
        dataString += "alertForListeningParties," + alertForListeningParties.toString() + "\n";

        dataString += "showSpecialEvents," + showSpecialEvents.toString() + "\n";
        dataString += "showMeetAndGreet," + showMeetAndGreet.toString() + "\n";
        dataString += "showClinics," + showClinicEvents.toString() + "\n";
        dataString += "showListeningParties," + showAlbumListen.toString() + "\n";

        dataString += "showPoolShows," + showPoolShows.toString() + "\n";
        dataString += "showTheaterShows," + showTheaterShows.toString() + "\n";
        dataString += "showRinkShows," + showRinkShows.toString() + "\n";
        dataString += "showLoungeShows," + showLoungeShows.toString() + "\n";
        dataString += "showOtherShows," + showOtherShows.toString() + "\n";

        dataString += "useLastYearsData," + useLastYearsData.toString() + "\n";
        dataString += "minBeforeToAlert," + minBeforeToAlert.toString() + "\n";
        dataString += "artistsUrl," + artsistsUrl + "\n";
        dataString += "scheduleUrl," + scheduleUrl + "\n";


        FileHandler70k.saveData(dataString, FileHandler70k.bandPrefs);

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

    public Boolean getShowSpecialEvents() {
        return showSpecialEvents;
    }
    public Boolean getShowMeetAndGreet() {
        return showMeetAndGreet;
    }
    public Boolean getShowClinicEvents() {
        return showClinicEvents;
    }
    public Boolean getShowAlbumListen() {
        return showAlbumListen;
    }

    public Boolean getShowPoolShows() {
        return showPoolShows;
    }
    public Boolean getShowTheaterShows() {
        return showTheaterShows;
    }
    public Boolean getShowRinkShows() {
        return showRinkShows;
    }
    public Boolean getShowLoungeShows() {
        return showLoungeShows;
    }
    public Boolean getShowOtherShows() {
        return showOtherShows;
    }

    public void setShowPoolShows(Boolean showPoolShows) {
        this.showPoolShows = showPoolShows;
    }

    public void setShowTheaterShows(Boolean showTheaterShows) {
        this.showTheaterShows = showTheaterShows;
    }
    public void setShowRinkShows(Boolean showRinkShows) {
        this.showRinkShows = showRinkShows;
    }
    public void setShowLoungeShows(Boolean showLoungeShows) {
        this.showLoungeShows = showLoungeShows;
    }
    public void setShowOtherShows(Boolean showOtherShows) {
        this.showOtherShows = showOtherShows;
    }

    public void setShowSpecialEvents(Boolean hideSpecialEvents) {
        this.showSpecialEvents = hideSpecialEvents;
    }
    public void setShowMeetAndGreet(Boolean hideMeetAndGreet) {
        this.showMeetAndGreet = hideMeetAndGreet;
    }
    public void setShowClinicEvents(Boolean hideClinicEvents) {
        this.showClinicEvents = hideClinicEvents;
    }
    public void setShowAlbumListen(Boolean hideAlbumListen) {
        this.showAlbumListen = hideAlbumListen;
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

    public void setUseLastYearsData(Boolean useLastYearsData) {
        this.useLastYearsData = useLastYearsData;
    }

    public Boolean getUseLastYearsData() {
        return useLastYearsData;
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

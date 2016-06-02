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

    private String artsistsUrl = "Default";
    private String scheduleUrl = "Default";

    public void loadData() {
        try {
            File file = new File(Environment.getExternalStorageDirectory() + "/70kbandPreferences.csv");

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
        dataString += "useLastYearsData," + useLastYearsData.toString() + "\n";
        dataString += "minBeforeToAlert," + minBeforeToAlert.toString() + "\n";
        dataString += "artistsUrl," + artsistsUrl + "\n";
        dataString += "scheduleUrl," + scheduleUrl + "\n";

        Log.d("Save Data", dataString);
        try {
            FileOutputStream stream = new FileOutputStream(new File(Environment.getExternalStorageDirectory() + "/70kbandPreferences.csv"));
            try {
                stream.write(dataString.getBytes());
            } finally {
                stream.close();
            }
        } catch (Exception error) {
            Log.e("Save Data Error", error.getMessage());
        }
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

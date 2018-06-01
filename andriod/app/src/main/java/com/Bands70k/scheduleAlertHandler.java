package com.Bands70k;

import android.annotation.SuppressLint;
import android.annotation.TargetApi;
import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Build;
import android.os.Bundle;
import android.os.SystemClock;
import android.provider.Settings;
import android.support.v4.app.NotificationManagerCompat;
import android.support.v7.app.NotificationCompat;
import android.util.Log;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.TimeZone;

/**
 * Created by rdorn on 5/26/16.
 */
public class scheduleAlertHandler extends AsyncTask<String, Void, ArrayList<String>> {

    private static String staticBandName;

    ArrayList<String> result;

    public scheduleAlertHandler(){
    }

    @Override
    protected ArrayList<String> doInBackground(String... params) {
        clearAlerts();
        scheduleAlerts();

        return result;
    }

    @Override
    protected void onPostExecute(ArrayList<String> result) {

    }

    public void scheduleAlerts(){

        if (staticVariables.schedulingAlert == false) {
            staticVariables.schedulingAlert = true;

            Calendar cal = Calendar.getInstance();
            long currentEpoch = cal.getTime().getTime();

            if (BandInfo.scheduleRecords != null) {
                if (BandInfo.scheduleRecords.keySet().size() > 0) {
                    for (String bandName : BandInfo.scheduleRecords.keySet()) {

                        Iterator entries = BandInfo.scheduleRecords.get(bandName).scheduleByTime.entrySet().iterator();
                        while (entries.hasNext()) {
                            Map.Entry thisEntry = (Map.Entry) entries.next();
                            Object key = thisEntry.getKey();

                            scheduleHandler scheduleDetails = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key);
                            shipNotifications.unuiqueNumber++;

                            Long alertTime = Long.valueOf(key.toString());// - (Long.valueOf(preferences.getMinBeforeToAlert())) * 60 * 100);

                            boolean showAlerts = scheduleAlertHandler.showAlert(scheduleDetails, bandName);
                            Log.d("SchedNotications", "!Timing1 " + bandName + " perferences returned " + showAlerts + ":" + alertTime);
                            if (alertTime > 0 && showAlerts == true) {

                                String alertMessage = bandName + " has a " + scheduleDetails.getShowType() + " in " + staticVariables.preferences.getMinBeforeToAlert() + " min at the " + scheduleDetails.getShowLocation();

                                SimpleDateFormat alertDateTime = new SimpleDateFormat("MM/dd/yyyy HH:mm:ss");
                                alertDateTime.setTimeZone(TimeZone.getTimeZone("PST8PDT"));
                                String alertDateTimeText = alertDateTime.format(new Date(alertTime));

                                int delay = (int) (alertTime - currentEpoch) - (((staticVariables.preferences.getMinBeforeToAlert() + 1) * 60) * 1000);
                                int delayInseconds = (delay / 1000);

                                if (delay > 1) {
                                    sendLocalAlert(alertMessage, delayInseconds);
                                }

                            }
                        }
                    }
                }
            }
            staticVariables.schedulingAlert = false;
        }
    }

    public void scheduleNotification(Notification notification, int delay, int unuiqueID, String content) {

        Intent notificationIntent = new Intent(staticVariables.context, NotificationPublisher.class);
        notificationIntent.putExtra(String.valueOf(delay), 1);
        notificationIntent.putExtra(NotificationPublisher.NOTIFICATION, notification);
        notificationIntent.putExtra("messageText", content);
        notificationIntent.setAction(content);
        PendingIntent pendingIntent = PendingIntent.getBroadcast(staticVariables.context, unuiqueID, notificationIntent, PendingIntent.FLAG_UPDATE_CURRENT);

        long futureInMillis = SystemClock.elapsedRealtime() + delay;
        AlarmManager alarmManager = (AlarmManager) staticVariables.context.getSystemService(Context.ALARM_SERVICE);
        try {
            alarmManager.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, futureInMillis, pendingIntent);
        } catch (Exception error){
            Log.d("NotifLogs", "Encountered issue scheduling alert " + error.getMessage());
        }


    }

    public Notification getNotification(String content) {

        Log.d("NotifLogs", "Scheduled alert to day " + content);

        Intent showApp = new Intent(staticVariables.context, showBands.class);
        //Uri defaultSoundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION);
        Uri defaultSoundUri = Settings.System.DEFAULT_NOTIFICATION_URI;
        PendingIntent launchApp = PendingIntent.getActivity(
                staticVariables.context,
                0,
                showApp,
                PendingIntent.FLAG_UPDATE_CURRENT);

        Notification.Builder builder = new Notification.Builder(staticVariables.context);
        builder.setContentTitle("70K Bands");
        builder.setContentText(content);
        builder.setSmallIcon(getNotificationIcon());
        builder.setContentIntent(launchApp);
        builder.setSound(defaultSoundUri);
        builder.setAutoCancel(true);
        builder.setVibrate(new long[]{1000,1000,1000,1000});
        return builder.build();
    }

    private int getNotificationIcon() {

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            return R.drawable.bands_70k_icon;

        } else {
            return R.drawable.alert_icon;
        }
    }

    public static boolean showAlert(scheduleHandler scheduleDetails, String bandName) {

        staticBandName = bandName;

        String rank = rankStore.getRankForBand(bandName);

        if (checkEventType(scheduleDetails) == false){
            //Log.d("SchedNotications", "!Timing " + bandName + " rejected based on event type of " + scheduleDetails.getShowType());
            return false;
        }

        if (!scheduleDetails.getShowType().equals(staticVariables.specialEvent)){
            if (checkRank(rank) == false) {
                //Log.d("SchedNotications", "!Timing " + bandName + " rejected based on rank  of " + rank);
                return false;
            }
        }

        return true;
    }

    private static boolean checkRank (String rank){

        //Log.d("SchedNotications", "!Timing " + staticBandName + " " + rank + " should = " + staticVariables.mustSeeIcon);
        if (rank.equals(staticVariables.mustSeeIcon) && staticVariables.preferences.getMustSeeAlert() == false){
            Log.d("SchedNotications", "!Timing " + staticBandName + " rejected " + staticVariables.preferences.getMustSeeAlert() + " and " + staticVariables.mustSeeIcon);
            return false;

        } else if (rank.equals(staticVariables.mightSeeIcon) && staticVariables.preferences.getMightSeeAlert() == false) {
            Log.d("SchedNotications", "!Timing " + staticBandName + " rejected " + staticVariables.preferences.getMightSeeAlert() + " and " + staticVariables.mightSeeIcon);

            return false;

        } else if (!rank.equals(staticVariables.mustSeeIcon) && !rank.equals(staticVariables.mightSeeIcon)){
            Log.d("SchedNotications", "!!Timing " + staticBandName + " rejected based on not being a Must or Might " + staticVariables.mightSeeIcon);
            return false;
        }


        return true;
    }

    private static boolean checkEventType (scheduleHandler scheduleDetails){

        if (scheduleDetails.getShowType() == staticVariables.show && staticVariables.preferences.getAlertForShows() == false){
            return false;

        } else if (scheduleDetails.getShowType() == staticVariables.meetAndGreet && staticVariables.preferences.getAlertForMeetAndGreet() == false){
            return false;

        } else if (scheduleDetails.getShowType() == staticVariables.clinic && staticVariables.preferences.getAlertForClinics() == false){
            return false;

        } else if (scheduleDetails.getShowType() == staticVariables.specialEvent && staticVariables.preferences.getAlertForSpecialEvents() == false){
            return false;

        } else if (scheduleDetails.getShowType() == "Listening Party" && staticVariables.preferences.getAlertForListeningParties() == false){
            return false;

        }

        return true;
    }

    public void clearAlerts (){

        Log.d ("ClearAlert", "Looping through previosu alerts");

        try {
            Integer counter = 0;
            if (staticVariables.alertTracker == 0){
                staticVariables.alertTracker = 300;
            }
            while (counter <= staticVariables.alertTracker){

                Log.d ("ClearAlert", "counter = " + counter + " staticVariables.alertTracker = " + staticVariables.alertTracker);
                counter = counter + 1;

                AlarmManager clearAlarm = (AlarmManager) staticVariables.context.getSystemService(Context.ALARM_SERVICE);

                Notification clearNotification = getNotification("");
                Intent notificationIntent = new Intent(staticVariables.context, NotificationPublisher.class);
                notificationIntent.putExtra(String.valueOf(counter), 1);
                notificationIntent.putExtra(NotificationPublisher.NOTIFICATION, clearNotification);
                notificationIntent.setAction("");

                PendingIntent pendingIntent = PendingIntent.getBroadcast(staticVariables.context, counter, notificationIntent, PendingIntent.FLAG_CANCEL_CURRENT);

                clearAlarm.cancel(pendingIntent);

            }
            staticVariables.alertTracker = 0;
            staticVariables.alertMessages = new HashSet<String>();
        } catch (Exception error){
            Log.e("ERROR", error.getMessage());
        }
    }

    public void sendLocalAlert(String alertMessage, int delay){

        if (staticVariables.alertMessages.contains(alertMessage) == false) {

            staticVariables.alertMessages.add(alertMessage);
            staticVariables.alertTracker = staticVariables.alertTracker + 1;
            int delayInMilliSeconds = delay * 1000;

            Log.e("SendLocalAlert", "alertMessage = " + alertMessage + " delay = " + delay + " alertTracker = " + staticVariables.alertTracker);

            Notification notifyMessage = this.getNotification(alertMessage);
            this.scheduleNotification(notifyMessage, delayInMilliSeconds, staticVariables.alertTracker, alertMessage);
        }
    }
}

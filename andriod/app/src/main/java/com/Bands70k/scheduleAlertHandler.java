package com.Bands70k;

import android.app.AlarmManager;
import android.app.Notification;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Build;
import android.os.SystemClock;
import android.provider.Settings;
import android.util.Log;

import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.TimeZone;

/**
 * Created by rdorn on 5/26/16.
 */
public class scheduleAlertHandler extends AsyncTask<String, Void, ArrayList<String>> {

    private static String staticBandName;
    private Map<Integer, String> alarmStorageStringHash = new HashMap<Integer, String>();

    ArrayList<String> result;

    public scheduleAlertHandler(){
    }

    @Override
    protected ArrayList<String> doInBackground(String... params) {
        scheduleAlerts();

        return result;
    }

    @Override
    protected void onPostExecute(ArrayList<String> result) {

    }

    public void scheduleAlerts(){

        if (staticVariables.schedulingAlert == false) {
            staticVariables.schedulingAlert = true;
            clearAlerts();

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

                                int delay = (int) (alertTime - currentEpoch) - (((staticVariables.preferences.getMinBeforeToAlert()) * 60) * 1000);
                                int delayInseconds = (delay / 1000);

                                if (delay > 1) {
                                    sendLocalAlert(alertMessage, delayInseconds);
                                }

                            }
                        }
                    }
                }
            }
            saveAlarmStrings(alarmStorageStringHash);
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

        alarmStorageStringHash.put(unuiqueID, content);


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
        Calendar cal = Calendar.getInstance();

        if (staticVariables.preferences.getAlertOnlyForShowWillAttend() == true){
            String attendStatus = staticVariables.attendedHandler.getShowAttendedStatus(bandName,scheduleDetails.getShowLocation(),scheduleDetails.getStartTimeString(),scheduleDetails.getShowType());
            if (attendStatus != staticVariables.sawNoneStatus){
                if (scheduleDetails.getEpochStart() > cal.getTime().getTime()) {
                    Log.d("SchedNotications", "!ShowTiming " + bandName + " at " + scheduleDetails.getShowLocation() + " will get an alert " + attendStatus);
                    return true;
                }
            }
            return false;
        }

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

        Log.d ("SendLocalAlertCheck", "'" + staticVariables.meetAndGreet + "' Checking '" + scheduleDetails.getShowType() + "' should send is " +  staticVariables.preferences.getAlertForMeetAndGreet());

        if (scheduleDetails.getShowType().equals(staticVariables.show) && staticVariables.preferences.getAlertForShows() == false){
            return false;

        } else if (scheduleDetails.getShowType().equals(staticVariables.meetAndGreet) && staticVariables.preferences.getAlertForMeetAndGreet() == false){
            Log.d ("SendLocalAlertCheck", "Rejecting alert");
            return false;

        } else if (scheduleDetails.getShowType().equals(staticVariables.clinic) && staticVariables.preferences.getAlertForClinics() == false){
            return false;

        } else if (scheduleDetails.getShowType().equals(staticVariables.specialEvent) && staticVariables.preferences.getAlertForSpecialEvents() == false){
            return false;

        } else if (scheduleDetails.getShowType().equals(staticVariables.listeningEvent) && staticVariables.preferences.getAlertForListeningParties() == false){
            return false;

        }

        Log.d ("SendLocalAlertCheck", "alerting");
        return true;
    }

    public void clearAlerts (){

        try {
            Log.d("SendLocalAlert", "Looping through previosu alerts");

            Map<Integer, String> alarmStorageStringHash = loadAlarmStringStorage();

            AlarmManager clearAlarm = (AlarmManager) staticVariables.context.getSystemService(Context.ALARM_SERVICE);

            for (Integer id : alarmStorageStringHash.keySet()) {

                String messageContent = alarmStorageStringHash.get(id);

                Notification tempNotification = getNotification(messageContent);

                Intent notificationIntent = new Intent(staticVariables.context, NotificationPublisher.class);
                notificationIntent.putExtra(NotificationPublisher.NOTIFICATION, tempNotification);
                notificationIntent.putExtra("messageText", messageContent);
                notificationIntent.setAction(messageContent);

                PendingIntent pendingIntent = PendingIntent.getBroadcast(staticVariables.context, id, notificationIntent, PendingIntent.FLAG_UPDATE_CURRENT);

                Log.d("SchedNotications", "Clearing alert " + id.toString());
                clearAlarm.cancel(pendingIntent);
            }

            staticVariables.alertMessages.clear();
            alarmStorageStringHash = new HashMap<Integer, String>();
            saveAlarmStrings(alarmStorageStringHash);
        } catch (Exception error){
            Log.e("SchedNotications", "Something has gone wrong " + error.getLocalizedMessage() + "\n" + error.fillInStackTrace());
        }
    }

    public void sendLocalAlert(String alertMessage, int delay){

        if (staticVariables.alertMessages.contains(alertMessage) == false) {

            //delay = delay + 60;
            staticVariables.alertMessages.add(alertMessage);
            staticVariables.alertTracker = staticVariables.alertTracker + 1;
            int delayInMilliSeconds = delay * 1000;

            Log.e("SendLocalAlert", "alertMessage = " + alertMessage + " delay = " + delay + " alertTracker = " + staticVariables.alertTracker);

            Notification notifyMessage = this.getNotification(alertMessage);
            this.scheduleNotification(notifyMessage, delayInMilliSeconds, staticVariables.alertTracker, alertMessage);
        }
    }

    //    private Map<Integer, String> alarmStorageStringHash = new HashMap<Integer, String>();
    //private Map<Integer, Notification> alarmStorageNotificationHash = new HashMap<Integer, Notification>();

    public void saveAlarmStrings(Map<Integer, String> alarmStorageHash){

        try {

            //Saving of object in a file
            FileOutputStream file = new FileOutputStream(FileHandler70k.alertStorageFile);
            ObjectOutputStream out = new ObjectOutputStream(file);

            // Method for serialization of object
            out.writeObject(alarmStorageHash);

            out.close();
            file.close();

        } catch (Exception error){
            Log.e("Error", "Unable to save alert tracking data " + error.getLocalizedMessage());
            Log.e("Error", "Unable to save alert tracking data " + error.fillInStackTrace());
        }
    }

    public Map<Integer, String> loadAlarmStringStorage(){

        Map<Integer, String> alarmStorageHash = new HashMap<Integer, String>();

        try
        {
            // Reading the object from a file
            FileInputStream file = new FileInputStream(FileHandler70k.alertStorageFile);
            ObjectInputStream in = new ObjectInputStream(file);

            // Method for deserialization of object
            alarmStorageHash = (Map<Integer, String>)in.readObject();

            in.close();
            file.close();

        } catch (Exception error){
            Log.e("Error", "Unable to load alert tracking data " + error.getMessage());
        }

        return alarmStorageHash;
    }
}

package com.Bands70k;

import android.app.AlarmManager;
import android.app.Notification;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Build;
import android.os.SystemClock;
import android.provider.Settings;
import android.util.Log;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.Iterator;
import java.util.Map;
import java.util.TimeZone;

/**
 * Created by rdorn on 5/26/16.
 */
public class scheduleAlertHandler extends AsyncTask<String, Void, ArrayList<String>> {

    private static String staticBandName;
    preferencesHandler preferences;
    Context context;
    ArrayList<String> result;

    public scheduleAlertHandler(preferencesHandler preferencesValue, Context contextValue){
        preferences = preferencesValue;
        context = contextValue;
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

        Calendar cal = Calendar.getInstance();
        long currentEpoch = cal.getTime().getTime();

        if (BandInfo.scheduleRecords != null) {
            if (BandInfo.scheduleRecords.keySet().size() > 0) {
                for (String bandName: BandInfo.scheduleRecords.keySet()){

                    Iterator entries = BandInfo.scheduleRecords.get(bandName).scheduleByTime.entrySet().iterator();
                    while (entries.hasNext()) {
                        Map.Entry thisEntry = (Map.Entry) entries.next();
                        Object key = thisEntry.getKey();

                        scheduleHandler scheduleDetails = BandInfo.scheduleRecords.get(bandName).scheduleByTime.get(key);
                        shipNotifications.unuiqueNumber++;

                        Long alertTime = Long.valueOf(key.toString());// - (Long.valueOf(preferences.getMinBeforeToAlert())) * 60 * 100);

                        boolean showAlerts = scheduleAlertHandler.showAlert(scheduleDetails,preferences, bandName);
                        //Log.d("SchedNotications", "!Timing " + bandName + " perferences returned " + showAlerts);
                        if (alertTime > 0 && showAlerts == true) {

                            String alertMessage = bandName + " has a " + scheduleDetails.getShowType() + " in " + preferences.getMinBeforeToAlert() + " min at the " + scheduleDetails.getShowLocation();

                            SimpleDateFormat alertDateTime = new SimpleDateFormat("MM/dd/yyyy HH:mm:ss");
                            alertDateTime.setTimeZone(TimeZone.getTimeZone("PST8PDT"));
                            String alertDateTimeText = alertDateTime.format(new Date(alertTime));

                            Log.d("SchedNotications", "alertEpoc" + bandName + "=" + alertTime + " currentEpoch=" + currentEpoch + " - " + alertDateTimeText);
                            int delay = (int) (alertTime - currentEpoch) - ((preferences.getMinBeforeToAlert() * 60) * 1000);
                            int delayInMin = (delay/1000) / 60;
                            Log.d("SchedNotications", "!Timing " + bandName + " " + delayInMin + " - " + alertDateTimeText);
                            Log.d("SchedNotications", "Message is " + alertMessage + " delay is " + delay);

                            if (delay > 1){
                                scheduleNotification(getNotification(alertMessage), delay, (int)(alertTime/1000), alertMessage);
                            }

                        }
                    }
                }
            }
        }
    }

    public void scheduleNotification(Notification notification, int delay, int unuiqueID, String content) {

        Log.d("NotifLogs", "Scheduled alert in = " + delay + " seconds " + unuiqueID);

        Intent notificationIntent = new Intent(context, NotificationPublisher.class);
        notificationIntent.putExtra(String.valueOf(delay), 1);
        notificationIntent.putExtra(NotificationPublisher.NOTIFICATION, notification);
        notificationIntent.setAction(content);
        PendingIntent pendingIntent = PendingIntent.getBroadcast(context, unuiqueID, notificationIntent, PendingIntent.FLAG_UPDATE_CURRENT);

        long futureInMillis = SystemClock.elapsedRealtime() + delay;
        AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        alarmManager.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, futureInMillis, pendingIntent);


    }

    public Notification getNotification(String content) {

        Log.d("NotifLogs", "Scheduled alert to day " + content);

        Intent showApp = new Intent(context, showBands.class);
        //Uri defaultSoundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION);
        Uri defaultSoundUri = Settings.System.DEFAULT_NOTIFICATION_URI;
        PendingIntent launchApp = PendingIntent.getActivity(
                context,
                0,
                showApp,
                PendingIntent.FLAG_UPDATE_CURRENT);


        Notification.Builder builder = new Notification.Builder(context);
        builder.setContentTitle("70K Bands");
        builder.setContentText(content);
        builder.setSmallIcon(R.drawable.alert_icon);
        builder.setContentIntent(launchApp);
        builder.setSound(defaultSoundUri);
        builder.setAutoCancel(true);
        builder.setVibrate(new long[]{1000,1000,1000,1000});
        return builder.build();
    }

    public static boolean showAlert(scheduleHandler scheduleDetails, preferencesHandler preferences, String bandName) {

        staticBandName = bandName;

        String rank = rankStore.getRankForBand(bandName);

        if (checkEventType(scheduleDetails, preferences) == false){
            //Log.d("SchedNotications", "!Timing " + bandName + " rejected based on event type of " + scheduleDetails.getShowType());
            return false;
        }

        if (!scheduleDetails.getShowType().equals(staticVariables.specialEvent)){
            if (checkRank(rank, preferences) == false) {
                //Log.d("SchedNotications", "!Timing " + bandName + " rejected based on rank  of " + rank);
                return false;
            }
        }

        return true;
    }

    private static boolean checkRank (String rank, preferencesHandler preferences){

        Log.d("SchedNotications", "!Timing " + staticBandName + " " + rank + " should = " + staticVariables.mustSeeIcon);
        if (rank.equals(staticVariables.mustSeeIcon) && preferences.getMustSeeAlert() == false){
            //Log.d("SchedNotications", "!Timing " + staticBandName + " rejected " + preferences.getMustSeeAlert() + " and " + staticVariables.mustSeeIcon);
            return false;

        } else if (rank.equals(staticVariables.mightSeeIcon) && preferences.getMightSeeAlert() == false) {
            //Log.d("SchedNotications", "!Timing " + staticBandName + " rejected " + preferences.getMightSeeAlert() + " and " + staticVariables.mightSeeIcon);

            return false;

        } else if (!rank.equals(staticVariables.mustSeeIcon) && !rank.equals(staticVariables.mightSeeIcon)){
            //Log.d("SchedNotications", "!!Timing " + staticBandName + " rejected based on not being a Must or Might " + staticVariables.mightSeeIcon);
            return false;
        }


        return true;
    }

    private static boolean checkEventType (scheduleHandler scheduleDetails, preferencesHandler preferences){

        if (scheduleDetails.getShowType() == staticVariables.show && preferences.getAlertForShows() == false){
            return false;

        } else if (scheduleDetails.getShowType() == staticVariables.meetAndGreet && preferences.getAlertForMeetAndGreet() == false){
            return false;

        } else if (scheduleDetails.getShowType() == staticVariables.clinic && preferences.getAlertForClinics() == false){
            return false;

        } else if (scheduleDetails.getShowType() == staticVariables.specialEvent && preferences.getAlertForSpecialEvents() == false){
            return false;

        } else if (scheduleDetails.getShowType() == "Listening Party" && preferences.getAlertForListeningParties() == false){
            return false;

        }

        return true;
    }


}

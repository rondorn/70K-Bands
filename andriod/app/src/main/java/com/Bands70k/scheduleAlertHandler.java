package com.Bands70k;

import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.media.AudioAttributes;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Build;
import android.os.SystemClock;
import android.provider.Settings;
import android.support.v4.app.AlarmManagerCompat;
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

import static com.Bands70k.staticVariables.context;

/**
 * Created by rdorn on 5/26/16.
 */
public class scheduleAlertHandler extends AsyncTask<String, Void, ArrayList<String>> {

    private static String staticBandName;
    private Map<Integer, String> alarmStorageStringHash = new HashMap<Integer, String>();

    ArrayList<String> result;

    public scheduleAlertHandler(){

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {

            NotificationManager notificationManager = (NotificationManager)context.getSystemService(Context.NOTIFICATION_SERVICE);

            AudioAttributes att = new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .build();

            int importance = NotificationManager.IMPORTANCE_HIGH;
            NotificationChannel mChannel = new NotificationChannel(staticVariables.notificationChannelID, staticVariables.notificationChannelName, importance);
            mChannel.setDescription(staticVariables.notificationChannelDescription);
            mChannel.setSound(staticVariables.alarmSound, att);
            mChannel.enableLights(true);
            mChannel.setLightColor(Color.RED);
            mChannel.enableVibration(true);
            mChannel.setVibrationPattern(new long[]{100, 200, 300, 400, 500, 400, 300, 200, 400});
            mChannel.setShowBadge(true);
            mChannel.setLockscreenVisibility(1);
            mChannel.setImportance(NotificationManager.IMPORTANCE_HIGH);
            notificationManager.createNotificationChannel(mChannel);
        }
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
                            if (alertTime > 0 && showAlerts == true) {

                                String alertMessage = bandName + " has a " + scheduleDetails.getShowType() + " in " + staticVariables.preferences.getMinBeforeToAlert() + " min at the " + scheduleDetails.getShowLocation();

                                SimpleDateFormat alertDateTime = new SimpleDateFormat("MM/dd/yyyy HH:mm:ss");
                                alertDateTime.setTimeZone(TimeZone.getTimeZone("PST8PDT"));
                                String alertDateTimeText = alertDateTime.format(new Date(alertTime));

                                Log.d("SchedNotications", bandName + " Alerttime of Epoch is " + String.valueOf(alertTime));

                                int delay = (int) (alertTime - currentEpoch) - (((staticVariables.preferences.getMinBeforeToAlert()) * 60) * 1000);
                                int delayInseconds = (delay / 1000);

                                if (delay > 1 && delayInseconds < 604800) {
                                    Log.d("SchedNotications", "!Timing1 " + String.valueOf(delay) + " - " + bandName + " perferences returned " + showAlerts + ":" + alertDateTimeText);

                                    sendLocalAlert(alertMessage, delayInseconds);

                                } else {
                                    Log.d("SchedNotications", bandName + " delay is too long or short " + String.valueOf(delay));

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

    public void scheduleNotification(Notification notification, int delay, int unuiqueID, String content) {


        Intent notificationIntent = new Intent(context, NotificationPublisher.class);
        notificationIntent.putExtra(String.valueOf(delay), 1);
        notificationIntent.putExtra(NotificationPublisher.NOTIFICATION, notification);
        notificationIntent.putExtra("messageText", content);
        notificationIntent.setAction(content);


        PendingIntent pendingIntent = PendingIntent.getBroadcast(context, unuiqueID, notificationIntent, PendingIntent.FLAG_UPDATE_CURRENT);

        long futureInMillis = SystemClock.elapsedRealtime() + delay;

        AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        try {

            int ALARM_TYPE = AlarmManager.ELAPSED_REALTIME_WAKEUP;

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {

                Log.d("SendLocalAlert", "Using setExactAndAllowWhileIdle with delay of " + String.valueOf(futureInMillis));
                alarmManager.setExactAndAllowWhileIdle(ALARM_TYPE, futureInMillis, pendingIntent);

            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                Log.d("SendLocalAlert", "Using AlarmManagerCompat.setExact with delay of " + String.valueOf(futureInMillis));
                AlarmManagerCompat.setExact(alarmManager, ALARM_TYPE, futureInMillis, pendingIntent);

            } else {
                Log.d("SendLocalAlert", "Using AlarmManagerCompat.set with delay of " + String.valueOf(futureInMillis));
                alarmManager.set(ALARM_TYPE, futureInMillis, pendingIntent);
            }


        } catch (Exception error){
            Log.d("NotifLogs", "Encountered issue scheduling alert " + error.getMessage());
        }

        alarmStorageStringHash.put(unuiqueID, content);

    }

    public Notification getNotification(String content) {

        Log.d("NotifLogs", "Scheduled alert to day " + context.getPackageName());

        Intent showApp = new Intent(context, showBands.class);
        //Uri defaultSoundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION);

        PendingIntent launchApp = PendingIntent.getActivity(
                context,
                0,
                showApp,
                PendingIntent.FLAG_UPDATE_CURRENT);

        Notification.Builder builder = new Notification.Builder(context);

        builder.setContentTitle("70K Bands");
        builder.setContentText(content);
        builder.setSmallIcon(getNotificationIcon());
        builder.setContentIntent(launchApp);
        builder.setSound(staticVariables.alarmSound);
        builder.setAutoCancel(true);
        builder.setVibrate(new long[]{1000,1000,1000,1000});
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder.setChannelId(staticVariables.notificationChannelID);
        }

        return builder.build();
    }

    private int getNotificationIcon() {

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            return R.drawable.new_bands_70k_icon;

        } else {
            return R.drawable.alert_icon;
        }
    }

    public static boolean showAlert(scheduleHandler scheduleDetails, String bandName) {

        staticBandName = bandName;
        Calendar cal = Calendar.getInstance();

        String attendStatus = staticVariables.attendedHandler.getShowAttendedStatus(bandName,
                scheduleDetails.getShowLocation(),
                scheduleDetails.getStartTimeString(),
                scheduleDetails.getShowType(),
                String.valueOf(staticVariables.eventYear));

        if (staticVariables.preferences.getAlertOnlyForShowWillAttend() == true){
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
            if (checkRank(rank, attendStatus) == false) {
                //Log.d("SchedNotications", "!Timing " + bandName + " rejected based on rank  of " + rank);
                return false;
            }
        }

        return true;
    }

    private static boolean checkRank (String rank, String attendedStatus){

        if (rank.equals(staticVariables.mustSeeIcon) && staticVariables.preferences.getMustSeeAlert() == true){
            //Log.d("SchedNotications", "!Timing " + staticBandName + " alerting " + staticVariables.preferences.getMustSeeAlert() + " and " + staticVariables.mustSeeIcon);
            return true;

        } else if (rank.equals(staticVariables.mightSeeIcon) && staticVariables.preferences.getMightSeeAlert() == true) {
            //Log.d("SchedNotications", "!Timing " + staticBandName + " alerting " + staticVariables.preferences.getMightSeeAlert() + " and " + staticVariables.mightSeeIcon);

            return true;

        } else if (staticVariables.preferences.getMustSeeAlert() == true && attendedStatus != staticVariables.sawNoneStatus){
            //Log.d("SchedNotications", "!!Timing " + staticBandName + " alerting based on  " + attendedStatus);
            return true;
        }

        Log.d("SchedNotications", "!Timing " + staticBandName + " rejecting " + staticVariables.preferences.getMustSeeAlert() + " and " + staticVariables.mustSeeIcon);


        return false;
    }

    private static boolean checkEventType (scheduleHandler scheduleDetails){

        Log.d ("SendLocalAlertCheck", "'" + staticVariables.meetAndGreet + "' Checking '" + scheduleDetails.getShowType() + "' should send is " +  staticVariables.preferences.getAlertForMeetAndGreet());

        Boolean sendAlert = false;

        if (scheduleDetails.getShowType().equals(staticVariables.show) && staticVariables.preferences.getAlertForShows() == true){
            sendAlert = true;

        } else if (scheduleDetails.getShowType().equals(staticVariables.meetAndGreet) && staticVariables.preferences.getAlertForMeetAndGreet() == true){
            sendAlert = true;

        } else if (scheduleDetails.getShowType().equals(staticVariables.clinic) && staticVariables.preferences.getAlertForClinics() == true){
            sendAlert = true;

        } else if (scheduleDetails.getShowType().equals(staticVariables.specialEvent) && staticVariables.preferences.getAlertForSpecialEvents() == true){
            sendAlert = true;

        } else if (scheduleDetails.getShowType().equals(staticVariables.listeningEvent) && staticVariables.preferences.getAlertForListeningParties() == true){
            sendAlert = true;

        } else if ((scheduleDetails.getShowType().equals(staticVariables.unofficalEvent) || scheduleDetails.getShowType().equals(staticVariables.unofficalEventOld)) && staticVariables.preferences.getAlertForUnofficalEvents() == true){
            sendAlert = true;
        }

        if (sendAlert == true){
            Log.d ("SendLocalAlertCheck", "alerting for " + scheduleDetails.getBandName() + "-" + scheduleDetails.getShowDay() + "-" + scheduleDetails.getShowType());
        }

        return sendAlert;
    }

    public void clearAlerts (){

        try {
            Log.d("clearLocalAlerts", "Looping through previosu alerts");

            Map<Integer, String> alarmStorageStringHash = loadAlarmStringStorage();

            AlarmManager clearAlarm = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);

            for (Integer id : alarmStorageStringHash.keySet()) {

                String messageContent = alarmStorageStringHash.get(id);

                Notification tempNotification = getNotification(messageContent);

                Intent notificationIntent = new Intent(context, NotificationPublisher.class);
                notificationIntent.putExtra(NotificationPublisher.NOTIFICATION, tempNotification);
                notificationIntent.putExtra("messageText", messageContent);
                notificationIntent.setAction(messageContent);

                PendingIntent pendingIntent = PendingIntent.getBroadcast(context, id, notificationIntent, PendingIntent.FLAG_UPDATE_CURRENT);

                Log.d("clearLocalAlerts", "Clearing alert " + id.toString());
                clearAlarm.cancel(pendingIntent);
            }

            staticVariables.alertMessages.clear();
            staticVariables.alertTracker = 0;
            alarmStorageStringHash.clear();

            saveAlarmStrings(alarmStorageStringHash);
        } catch (Exception error){
            Log.e("SchedNotications", "Something has gone wrong " + error.getLocalizedMessage() + "\n" + error.fillInStackTrace());
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
            Log.e("alert tracing", "able to save alert tracking data");
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
            Log.d("alertTracking", "able to load alert tracking data ");
        } catch (Exception error){
            Log.e("Error", "Unable to load alert tracking data " + error.getMessage());
        }

        return alarmStorageHash;
    }
}

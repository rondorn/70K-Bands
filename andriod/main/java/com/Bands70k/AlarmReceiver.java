package com.Bands70k;

/**
 * Created by rdorn on 1/23/16.
 */
import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.graphics.BitmapFactory;
import android.support.v4.app.NotificationCompat;
import android.support.v4.app.NotificationManagerCompat;
import android.util.Log;
import android.widget.Toast;


public class AlarmReceiver extends BroadcastReceiver{


    @Override
    public void onReceive(Context arg0, Intent arg1) {
        // For our recurring task, we'll just display a message

        String message = "I'm running with count of " + staticVariables.alarmCount;
        Toast.makeText(arg0, message, Toast.LENGTH_SHORT).show();
        Log.d("AlertMsg", message);
        sendNotification(arg0, message);

        staticVariables.alarmCount ++;

    }

    public void sendNotification(Context arg0, String message) {

        // Use NotificationCompat.Builder to set up our notification.
        android.support.v7.app.NotificationCompat.Builder builder = new android.support.v7.app.NotificationCompat.Builder(arg0);

        //icon appears in device notification bar and right hand corner of notification
        builder.setSmallIcon(R.drawable.alert_icon);

        // This intent is fired when notification is clicked
        //Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse("http://javatechig.com/"));
        //PendingIntent pendingIntent = PendingIntent.getActivity(this, 0, intent, 0);

        // Set the intent that will fire when the user taps the notification.
        //builder.setContentIntent(pendingIntent);

        // Content title, which appears in large type at the top of the notification
        builder.setContentTitle("Scheduled Notification");

        // Content text, which appears in smaller text below the title
        builder.setContentText(message);

        // The subtext, which appears under the text on newer devices.
        // This will show-up in the devices with Android 4.2 and above only
        builder.setSubText("Tap to view documentation about notifications.");

        NotificationManager notificationManager = (NotificationManager) arg0.getSystemService(arg0.NOTIFICATION_SERVICE);

        // Will display the notification in the notification bar
        notificationManager.notify(staticVariables.alarmCount, builder.build());
    }

    /*
    public void notifyUser(){

        NotificationManager notificationManager = (NotificationManager)this.getSystemService(Context.NOTIFICATION_SERVICE);

        Intent intent = new Intent(MyActivity.this, SomeActivity.class);

        //use the flag FLAG_UPDATE_CURRENT to override any notification already there
        PendingIntent contentIntent = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT);

        Notification notification = new Notification(R.drawable.ic_launcher, "Some Text", System.currentTimeMillis());
        notification.flags = Notification.FLAG_AUTO_CANCEL | Notification.DEFAULT_LIGHTS | Notification.DEFAULT_SOUND;

        notification.setLatestEventInfo(this, "This is a notification Title", "Notification Text", contentIntent);
        //10 is a random number I chose to act as the id for this notification
        notificationManager.notify(10, notification);

    }
    */

}
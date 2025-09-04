package com.Bands70k;


import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.os.Build;

import androidx.appcompat.app.AlertDialog;
import androidx.core.app.NotificationCompat;
import android.util.Log;

import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

import java.util.Map;

import static android.content.ContentValues.TAG;


public class MyFcmListenerService extends FirebaseMessagingService {

    public static String messageString;

    @Override
    public void onMessageReceived(RemoteMessage remoteMessage) {
        super.onMessageReceived(remoteMessage);

        Log.d(TAG, "Message Notification Body: " + remoteMessage.getNotification().getBody());
        if (remoteMessage.getNotification().getBody() != null) {
            messageString = remoteMessage.getNotification().getBody();
        }

        RemoteMessage.Notification notification = remoteMessage.getNotification();

        Map<String, String> data = remoteMessage.getData();

        String click_action = remoteMessage.getNotification().getClickAction();

        ShowNotification(click_action);

    }

    private void ShowNotification(String click_action) {

        Intent intent = new Intent(this, showBands.class);
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);

        intent.putExtra("messageString", messageString);

        PendingIntent pendingIntent = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE);

        androidx.core.app.NotificationCompat.Builder notificationBuilder = new NotificationCompat.Builder(this)
                .setSmallIcon(getNotificationIcon())
                .setContentTitle(getString(R.string.app_name))
                .setContentText(messageString)
                .setAutoCancel(true)
                .setSound(staticVariables.alarmSound)
                .setVibrate(new long[]{1000, 1000, 1000})
                .setContentIntent(pendingIntent);

        notificationBuilder.setDefaults(Notification.DEFAULT_SOUND);
        notificationBuilder.setLights(Color.YELLOW, 1000, 300);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notificationBuilder.setChannelId(staticVariables.getNotificationChannelID());
        }
        NotificationManager notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        notificationManager.notify(0, notificationBuilder.build());

    }

    private int getNotificationIcon() {

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            return R.drawable.new_bands_70k_icon;

        } else {
            return R.drawable.alert_icon;
        }
    }
}
package com.Bands70k;


import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.pm.PackageManager;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.os.Build;

import androidx.core.content.ContextCompat;
import androidx.core.app.NotificationCompat;
import android.util.Log;

import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

import java.util.Map;

import static android.content.ContentValues.TAG;


public class MyFcmListenerService extends FirebaseMessagingService {

    public static String messageString;
    private static final String FCM_TAG = "MyFcmListenerService";

    @Override
    public void onMessageReceived(RemoteMessage remoteMessage) {
        super.onMessageReceived(remoteMessage);
        Map<String, String> data = remoteMessage.getData();
        RemoteMessage.Notification notification = remoteMessage.getNotification();

        String notificationBody = notification != null ? notification.getBody() : null;
        String notificationTitle = notification != null ? notification.getTitle() : null;
        String clickAction = notification != null ? notification.getClickAction() : null;

        if (notificationBody == null || notificationBody.trim().isEmpty()) {
            notificationBody = firstNonEmpty(data.get("body"), data.get("message"), data.get("alert"));
        }
        if (notificationTitle == null || notificationTitle.trim().isEmpty()) {
            notificationTitle = firstNonEmpty(data.get("title"), getString(R.string.app_name));
        }

        messageString = notificationBody;
        Log.d(FCM_TAG, "FCM message received. hasNotification=" + (notification != null) + ", hasData=" + !data.isEmpty());

        if (messageString == null || messageString.trim().isEmpty()) {
            Log.w(FCM_TAG, "Skipping notification because no message body was provided");
            return;
        }

        showNotification(notificationTitle, clickAction);

    }

    private String firstNonEmpty(String... values) {
        if (values == null) {
            return null;
        }
        for (String value : values) {
            if (value != null && !value.trim().isEmpty()) {
                return value;
            }
        }
        return null;
    }

    private void showNotification(String title, String clickAction) {

        Intent intent;
        if (clickAction != null && !clickAction.trim().isEmpty()) {
            intent = new Intent(clickAction);
            intent.setPackage(getPackageName());
            intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_NEW_TASK);
        } else {
            intent = new Intent(this, showBands.class);
            intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_NEW_TASK);
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_NEW_TASK);

        intent.putExtra("messageString", messageString);

        PendingIntent pendingIntent = PendingIntent.getActivity(
                this,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        ensureNotificationChannel();

        NotificationCompat.Builder notificationBuilder = new NotificationCompat.Builder(this, staticVariables.getNotificationChannelID())
                .setSmallIcon(getNotificationIcon())
                .setContentTitle(title != null ? title : getString(R.string.app_name))
                .setContentText(messageString)
                .setAutoCancel(true)
                .setSound(staticVariables.alarmSound)
                .setVibrate(new long[]{1000, 1000, 1000})
                .setContentIntent(pendingIntent);

        notificationBuilder.setDefaults(Notification.DEFAULT_SOUND);
        notificationBuilder.setLights(Color.YELLOW, 1000, 300);

        NotificationManager notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        if (notificationManager == null) {
            Log.w(FCM_TAG, "NotificationManager unavailable; cannot show remote notification");
            return;
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                && ContextCompat.checkSelfPermission(this, android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            Log.w(FCM_TAG, "POST_NOTIFICATIONS permission not granted; cannot show remote notification");
            return;
        }

        notificationManager.notify(0, notificationBuilder.build());

    }

    private void ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return;
        }

        NotificationManager notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        if (notificationManager == null) {
            return;
        }

        NotificationChannel existing = notificationManager.getNotificationChannel(staticVariables.getNotificationChannelID());
        if (existing != null) {
            return;
        }

        NotificationChannel channel = new NotificationChannel(
                staticVariables.getNotificationChannelID(),
                staticVariables.getNotificationChannelName(),
                NotificationManager.IMPORTANCE_HIGH
        );
        channel.setDescription(staticVariables.getNotificationChannelDescription());
        channel.enableLights(true);
        channel.setLightColor(Color.YELLOW);
        channel.enableVibration(true);
        channel.setVibrationPattern(new long[]{1000, 1000, 1000});
        notificationManager.createNotificationChannel(channel);
    }

    private int getNotificationIcon() {

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            return R.drawable.new_bands_70k_icon;

        } else {
            return R.drawable.alert_icon;
        }
    }
}
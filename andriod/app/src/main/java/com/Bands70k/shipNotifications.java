package com.Bands70k;

import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.SystemClock;
import android.util.Log;

import java.util.Date;

/**
 * Created by rdorn on 8/26/15.
 */
public class shipNotifications extends BroadcastReceiver {

    public static String NOTIFICATION_ID = "com.bands" + BuildConfig.FESTIVAL_TYPE;
    public static String NOTIFICATION = "notification";
    public static int unuiqueNumber = 0;

    public void onReceive(Context context, Intent intent) {

        Log.d("Notications", "shipNotifications was called " + unuiqueNumber);
        NotificationManager notificationManager = (NotificationManager)context.getSystemService(Context.NOTIFICATION_SERVICE);

        Notification notification = intent.getParcelableExtra(NOTIFICATION);

        unuiqueNumber++;
        notificationManager.notify(unuiqueNumber, notification);

    }
}

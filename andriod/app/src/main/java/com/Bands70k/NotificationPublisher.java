package com.Bands70k;

import android.app.Notification;
import android.app.NotificationManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

//import com.google.android.gms.gcm.GoogleCloudMessaging;

/**
 * Created by rdorn on 1/23/16.
 */


public class NotificationPublisher extends BroadcastReceiver {

    public static String NOTIFICATION = "notification";
    public static String TAG = "NotifLogs";

    public void onReceive(Context context, Intent intent) {

        NotificationManager notificationManager = (NotificationManager)context.getSystemService(Context.NOTIFICATION_SERVICE);

        Notification notification = intent.getParcelableExtra(NOTIFICATION);
        final int intent_id= (int) System.currentTimeMillis();

        for (String index: intent.getExtras().keySet()){
            Log.d(TAG, "data: " + index + "=" + intent.getExtras().get(index));
        }

        try {
            String message = intent.getExtras().get("messageText").toString();
            Log.d(TAG, "setingAlertString: " + message);
            MyFcmListenerService.messageString = message;
            try {
                notificationManager.notify(intent_id, notification);
            } catch (Exception error) {
                //if something goes wrong here...pass on it
            }
        } catch (Exception error){
            //Log.d(TAG, error.getMessage());
        }
    }

}


package com.Bands70k;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import androidx.legacy.content.WakefulBroadcastReceiver;

/**
 * BroadcastReceiver for handling GCM (Google Cloud Messaging) messages and starting the message handler service.
 */
public class GcmBroadcastReceiver extends WakefulBroadcastReceiver {

    /**
     * Called when a GCM message is received. Starts the GcmMessageHandler service and keeps the device awake.
     * @param context The context in which the receiver is running.
     * @param intent The intent being received.
     */
    @Override
    public void onReceive(Context context, Intent intent) {

        // Explicitly specify that GcmMessageHandler will handle the intent.
        ComponentName comp = new ComponentName(context.getPackageName(),
                GcmMessageHandler.class.getName());

        // Start the service, keeping the device awake while it is launching.
        startWakefulService(context, (intent.setComponent(comp)));
        setResultCode(Activity.RESULT_OK);
    }
}
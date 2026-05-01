package com.Bands70k;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

//import com.google.android.gms.gcm.GoogleCloudMessaging;

/**
 * Created by rdorn on 1/23/16.
 */


public class NotificationPublisher extends BroadcastReceiver {

    public static String NOTIFICATION = "notification";
    public static String TAG = "NotifLogs";
    private static final long DUPLICATE_WINDOW_MS = 60L * 60L * 1000L;
    private static final String ALERT_DUPLICATE_CACHE_FILE = "70kLocalAlertRecentFires.data";


    @Override
    public void onReceive(Context context, Intent intent) {
        NotificationManager notificationManager = (NotificationManager)context.getSystemService(Context.NOTIFICATION_SERVICE);

        Notification notification = intent.getParcelableExtra(NOTIFICATION);
        final int intent_id= (int) System.currentTimeMillis();

        if (intent.getExtras() != null) {
            for (String index: intent.getExtras().keySet()){
                Log.d(TAG, "data: " + index + "=" + intent.getExtras().get(index));
            }
        }

        try {
            String message = intent.getExtras().get("messageText").toString();
            Log.d(TAG, "setingAlertString: " + message);
            MyFcmListenerService.messageString = message;

            if (shouldSuppressDuplicateLocalAlert(message)) {
                Log.w(TAG, "SUPPRESSED local duplicate alert (within 1h), messageText=\"" + message + "\"");
                return;
            }

            try {
                notificationManager.notify(intent_id, notification);
                recordLocalAlertFire(message);
            } catch (Exception error) {
                Log.d(TAG, error.getMessage());
            }
        } catch (Exception error){
            //Log.d(TAG, error.getMessage());
        }
    }

    private File getRecentAlertFile() {
        return new File(showBands.newRootDir + FileHandler70k.directoryName + ALERT_DUPLICATE_CACHE_FILE);
    }

    private Map<String, Long> loadRecentAlertFires() {
        Map<String, Long> recentFires = new HashMap<String, Long>();
        File file = getRecentAlertFile();
        if (!file.exists()) {
            return recentFires;
        }
        try {
            ObjectInputStream in = new ObjectInputStream(new FileInputStream(file));
            recentFires = (Map<String, Long>) in.readObject();
            in.close();
        } catch (Exception error) {
            Log.w(TAG, "Unable to load local alert duplicate cache: " + error.getMessage());
        }
        return recentFires;
    }

    private void saveRecentAlertFires(Map<String, Long> recentFires) {
        try {
            ObjectOutputStream out = new ObjectOutputStream(new FileOutputStream(getRecentAlertFile()));
            out.writeObject(recentFires);
            out.close();
        } catch (Exception error) {
            Log.w(TAG, "Unable to save local alert duplicate cache: " + error.getMessage());
        }
    }

    private void pruneOldEntries(Map<String, Long> recentFires, long nowMs) {
        Iterator<Map.Entry<String, Long>> iterator = recentFires.entrySet().iterator();
        while (iterator.hasNext()) {
            Map.Entry<String, Long> entry = iterator.next();
            Long firedAt = entry.getValue();
            if (firedAt == null || (nowMs - firedAt) > DUPLICATE_WINDOW_MS) {
                iterator.remove();
            }
        }
    }

    private boolean shouldSuppressDuplicateLocalAlert(String messageText) {
        if (messageText == null || messageText.trim().isEmpty()) {
            return false;
        }
        long nowMs = System.currentTimeMillis();
        Map<String, Long> recentFires = loadRecentAlertFires();
        pruneOldEntries(recentFires, nowMs);
        Long lastFiredAt = recentFires.get(messageText);
        boolean suppress = lastFiredAt != null && (nowMs - lastFiredAt) <= DUPLICATE_WINDOW_MS;
        if (!recentFires.isEmpty()) {
            saveRecentAlertFires(recentFires);
        }
        return suppress;
    }

    private void recordLocalAlertFire(String messageText) {
        if (messageText == null || messageText.trim().isEmpty()) {
            return;
        }
        long nowMs = System.currentTimeMillis();
        Map<String, Long> recentFires = loadRecentAlertFires();
        pruneOldEntries(recentFires, nowMs);
        recentFires.put(messageText, nowMs);
        saveRecentAlertFires(recentFires);
    }

}


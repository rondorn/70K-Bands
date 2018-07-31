package com.Bands70k;

import android.app.Activity;
import android.os.*;
import android.content.*;
import android.app.*;
import android.util.Log;

import java.util.Map;

public class BackgroundService extends Service {

    private boolean isRunning;
    private Context context;
    private Thread backgroundThread;

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onCreate() {

        this.context = this;
        this.isRunning = false;
        this.backgroundThread = new Thread(myTask);

        startForeground(1,new Notification());
    }

    private Runnable myTask = new Runnable() {
        public void run() {
            // Do something here
            stopSelf();
        }
    };

    @Override
    public void onDestroy() {
        this.isRunning = false;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d("BackgroundService", "Waking up to check for alerts");

        if(!this.isRunning) {
            this.isRunning = true;
            this.backgroundThread.start();
        }
        return START_STICKY;
    }

}
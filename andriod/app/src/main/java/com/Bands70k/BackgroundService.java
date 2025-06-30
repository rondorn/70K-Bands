package com.Bands70k;

import android.app.Activity;
import android.os.*;
import android.content.*;
import android.app.*;
import android.util.Log;

import java.util.Map;

/**
 * Background service for running periodic or background tasks in the app.
 */
public class BackgroundService extends Service {

    private boolean isRunning;
    private Context context;
    private Thread backgroundThread;

    /**
     * Called when the service is bound. Not used in this implementation.
     * @param intent The intent that was used to bind to this service.
     * @return Always returns null.
     */
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    /**
     * Called when the service is created. Initializes the background thread.
     */
    @Override
    public void onCreate() {

        this.context = this;
        this.isRunning = false;
        this.backgroundThread = new Thread(myTask);

        startForeground(1,new Notification());
    }

    /**
     * Runnable task for the background thread. Stops the service when done.
     */
    private Runnable myTask = new Runnable() {
        public void run() {
            // Do something here
            stopSelf();
        }
    };

    /**
     * Called when the service is destroyed. Cleans up resources.
     */
    @Override
    public void onDestroy() {
        this.isRunning = false;
    }

    /**
     * Called when the service is started. Starts the background thread if not already running.
     * @param intent The intent supplied to startService.
     * @param flags Additional data about this start request.
     * @param startId A unique integer representing this specific request to start.
     * @return The start mode for the service.
     */
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
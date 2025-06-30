package com.Bands70k;

import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.net.ConnectivityManager;
import android.net.LinkProperties;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.os.Build;
import android.os.SystemClock;
import android.util.Log;

import androidx.activity.EdgeToEdge;

/**
 * Application class for 70K Bands, provides global application context.
 */
public class Bands70k extends Application {

    private static Context context;

    /**
     * Called when the application is created. Initializes context and online status.
     */
    public void onCreate() {

        super.onCreate();

        Bands70k.context = getApplicationContext();
        OnlineStatus.isOnline();
        SystemClock.sleep(3000);

    }

    /**
     * Gets the global application context.
     * @return The application context.
     */
    public static Context getAppContext() {
        return Bands70k.context;
    }

}


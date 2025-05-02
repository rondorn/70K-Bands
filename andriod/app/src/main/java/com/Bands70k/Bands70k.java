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
 * Created by rdorn on 5/26/16.
 */
public class Bands70k extends Application {

    private static Context context;

    public void onCreate() {

        super.onCreate();

        Bands70k.context = getApplicationContext();
        OnlineStatus.isOnline();
        SystemClock.sleep(3000);

    }

    public static Context getAppContext() {
        return Bands70k.context;
    }

}


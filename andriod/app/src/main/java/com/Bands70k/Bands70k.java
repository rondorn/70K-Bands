package com.Bands70k;

import android.app.Application;
import android.content.Context;
import android.os.Build;
import android.support.v4.app.ActivityCompat;

/**
 * Created by rdorn on 5/26/16.
 */
public class Bands70k extends Application {

    private static Context context;

    public void onCreate() {
        super.onCreate();

        Bands70k.context = getApplicationContext();
    }

    public static Context getAppContext() {
        return Bands70k.context;
    }

}

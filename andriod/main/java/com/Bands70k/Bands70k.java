package com.Bands70k;

import android.util.Log;

import com.parse.Parse;
import com.parse.ParseException;
import com.parse.ParsePush;
import com.parse.SaveCallback;

/**
 * Created by rdorn on 8/2/15.
 */
public class Bands70k extends android.app.Application {

    @Override
    public void onCreate() {
        super.onCreate();

        initializePushNotifications();
    }

    public void initializePushNotifications(){

        //Parse.enableLocalDatastore(this);
        Parse.initialize(this, restrictedStaticVariables.parseAppId, restrictedStaticVariables.parseClientKey);

        ParsePush.subscribeInBackground("", new SaveCallback() {
            @Override
            public void done(ParseException e) {
                if (e == null) {
                    Log.d("com.parse.push", "successfully subscribed to the broadcast channel.");
                } else {
                    Log.e("com.parse.push", "failed to subscribe for push", e);
                }
            }
        });

    }

}

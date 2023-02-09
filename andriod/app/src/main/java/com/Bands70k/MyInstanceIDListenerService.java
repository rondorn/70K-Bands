package com.Bands70k;

import android.util.Log;
import com.google.firebase.messaging.FirebaseMessagingService;

import static android.content.ContentValues.TAG;


class MyInstanceIDListenerServicex extends FirebaseMessagingService {

    //private static final String TAG = "MyInstanceIDLS";

    /**
     * Called if InstanceID token is updated. This may occur if the security of
     * the previous token had been compromised. This call is initiated by the
     * InstanceID provider.
     */
    // [START refresh_token]
    @Override
    public void onNewToken(String s) {
        super.onNewToken(s);
        Log.d("Refreshed token:",s);
    }
    /*
    @Override
    public void onTokenRefresh() {
        try {
            // Get updated InstanceID token.
            String refreshedToken = FirebaseInstanceId.getInstance().getToken();
            Log.d(TAG, "Refreshed token: " + refreshedToken);
            // TODO: Implement this method to send any registration to your app's servers.
            sendRegistrationToServer(refreshedToken);

            Log.d(TAG, "Subscribing to topics");
            FirebaseMessaging.getInstance().subscribeToTopic(staticVariables.mainAlertChannel);
            FirebaseMessaging.getInstance().subscribeToTopic(staticVariables.testAlertChannel);

            if (staticVariables.preferences.getAlertForUnofficalEvents() == true) {
                FirebaseMessaging.getInstance().subscribeToTopic(staticVariables.unofficalAlertChannel);
            } else {
                FirebaseMessaging.getInstance().unsubscribeFromTopic(staticVariables.unofficalAlertChannel);
            }
        } catch (Exception error){
            onTokenRefresh();
        }
    }
    */
    private void sendRegistrationToServer(String token) {
        // TODO: Implement this method to send token to your app server.
    }
    // [END refresh_token]
}

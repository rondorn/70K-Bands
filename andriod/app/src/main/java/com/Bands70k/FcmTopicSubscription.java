package com.Bands70k;

import android.util.Log;

import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.messaging.FirebaseMessaging;

/**
 * Subscribes this app install to FCM alert topics ({@link FestivalConfig#subscriptionTopic}, etc.).
 * Each festival flavor uses its own Firebase project (google-services.json); topic names are shared
 * but subscriptions are per-project — sends must target the matching Firebase project.
 */
public final class FcmTopicSubscription {

    private static final String TAG = "FcmTopicSubscription";

    private FcmTopicSubscription() {
    }

    /** Call on startup and from {@link MyFcmListenerService#onNewToken}. */
    public static void subscribeToAlertTopics() {
        FestivalConfig config = FestivalConfig.getInstance();
        logFirebaseIdentity();

        subscribe(config.subscriptionTopic);
        subscribe(config.subscriptionTopicTest);
        if (staticVariables.preferences != null
                && staticVariables.preferences.getAlertForUnofficalEvents()) {
            subscribe(config.subscriptionUnofficalTopic);
        } else {
            unsubscribe(config.subscriptionUnofficalTopic);
        }
    }

    private static void logFirebaseIdentity() {
        try {
            FirebaseMessaging.getInstance().getToken()
                    .addOnCompleteListener(task -> {
                        if (!task.isSuccessful()) {
                            Log.w(TAG, "FCM getToken failed: " + task.getException());
                            return;
                        }
                        String token = task.getResult();
                        String preview = token == null ? "null"
                                : token.substring(0, Math.min(12, token.length())) + "…";
                        Log.i(TAG, "festival=" + BuildConfig.FESTIVAL_TYPE
                                + " package=" + BuildConfig.APPLICATION_ID
                                + " topics=["
                                + FestivalConfig.getInstance().subscriptionTopic + ", "
                                + FestivalConfig.getInstance().subscriptionTopicTest
                                + "] token=" + preview);
                    });
        } catch (Exception e) {
            Log.w(TAG, "FCM getToken threw: " + e.getMessage());
        }
    }

    private static void subscribe(String topic) {
        if (topic == null || topic.trim().isEmpty()) {
            return;
        }
        FirebaseMessaging.getInstance().subscribeToTopic(topic)
                .addOnCompleteListener(logTopicResult("subscribe", topic));
    }

    private static void unsubscribe(String topic) {
        if (topic == null || topic.trim().isEmpty()) {
            return;
        }
        FirebaseMessaging.getInstance().unsubscribeFromTopic(topic)
                .addOnCompleteListener(logTopicResult("unsubscribe", topic));
    }

    private static OnCompleteListener<Void> logTopicResult(String action, String topic) {
        return task -> {
            if (task.isSuccessful()) {
                Log.i(TAG, action + " OK: " + topic);
            } else {
                Log.e(TAG, action + " FAILED: " + topic, task.getException());
            }
        };
    }
}

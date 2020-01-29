package com.Bands70k;

/**
 * Created by rdorn on 6/3/16.
 */
import android.app.Activity;
import android.content.Context;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.os.AsyncTask;
import android.os.Build;
import android.os.StrictMode;
import android.provider.Settings;
import android.support.v4.widget.SwipeRefreshLayout;
import android.util.Log;
import android.view.View;

import java.io.BufferedInputStream;
import java.io.BufferedReader;
import java.io.DataInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.MalformedURLException;
import java.net.URI;
import java.net.URL;
import java.net.URLConnection;
import java.util.ArrayList;
import java.util.Scanner;

import static com.Bands70k.staticVariables.fileDownloaded;
import static com.Bands70k.staticVariables.listPosition;


public class OnlineStatus {


    public static String internetCheckCache = "Unknown";
    public static Long internetCheckCacheDate = 0L;
    public static Boolean backgroundLookup = false;

    public static boolean isOnline(){

        Log.d ("Internet Found",  "Internet Found Checking Internet");
        OnlineStatus statusCheckHandler = new OnlineStatus();
        Boolean onlineCheck = statusCheckHandler.isInternetAvailable();

        Log.d ("Internet Found",  "Internet Found Checking Internet Done");
        return onlineCheck;
    }

    public boolean isInternetAvailable(){

        Boolean returnState = false;

        Long currentEpoc = System.currentTimeMillis() / 1000L;

        Log.d ("Internet Found",  "Internet Found " + currentEpoc + " < " + internetCheckCacheDate);

        if (internetCheckCache != "Unknown" && currentEpoc < internetCheckCacheDate){
            if (internetCheckCache == "false") {
                returnState = false;
            } else {
                returnState = true;
            }

            Log.d ("Internet Found",  "Internet Found Return state is cached  " + returnState);

            //cache has expired, but lets return last answer and check again in the background
        } else if (internetCheckCache != "Unknown"){

            if (internetCheckCache == "false") {
                returnState = false;
            } else {
                returnState = true;
            }

            Log.d ("Internet Found",  "Internet Found Return state is cached, but refreshing " + returnState);

            if (OnlineStatus.backgroundLookup == false) {
                OnlineStatus.backgroundLookup = true;
                IsInternetAvailableAsynchronous checkInternet = new IsInternetAvailableAsynchronous();
                checkInternet.execute();
            }

        } else {

            returnState = isInternetAvailableSynchronous();
        }

        return returnState;
    }

    public Boolean isInternetAvailableSynchronous(){

        Boolean returnState = false;

        Long currentEpoc = System.currentTimeMillis() / 1000L;

        try {

            URL url = new URL(staticVariables.networkTestingUrl);
            URLConnection connection = url.openConnection();
            connection.setConnectTimeout(1500);
            connection.setReadTimeout(1500);

            InputStream out = new BufferedInputStream(
                    connection.getInputStream());

            //Log.d("Internet Found", "Internet Found https called returned " + out.toString());
            Log.d("Internet Found", "Internet Found true ");
            returnState = true;
            internetCheckCache = "true";

        } catch (MalformedURLException mue) {
            //Log.e("Internet Found", "malformed url error ", mue);
            internetCheckCache = "false";

        } catch (IOException ioe) {
            //Log.e("Internet Found", "io error ", ioe);
            internetCheckCache = "false";

        } catch (SecurityException se) {
            //Log.e("Internet Found", "security error ", se);
            internetCheckCache = "false";

        } catch (Exception generalError){
            //Log.e("Internet Found", "general error ", generalError);
            internetCheckCache = "false";
        }

        OnlineStatus.internetCheckCacheDate = currentEpoc + 30;

        return returnState;
    }


    class IsInternetAvailableAsynchronous extends AsyncTask<String, Void, ArrayList<String>> {

        ArrayList<String> result;

        @Override
        protected void onPreExecute() {

        }


        @Override
        protected ArrayList<String> doInBackground(String... params) {

            OnlineStatus statusCheckHandler = new OnlineStatus();
            Boolean onlineCheck = statusCheckHandler.isInternetAvailableSynchronous();

            if (onlineCheck == true){
                OnlineStatus.internetCheckCache = "true";
            } else {
                OnlineStatus.internetCheckCache = "false";
            }

            return result;

        }

        @Override
        protected void onPostExecute(ArrayList<String> result) {

            Long currentEpoc = System.currentTimeMillis() / 1000L;
            OnlineStatus.internetCheckCacheDate = currentEpoc + 30;
            OnlineStatus.backgroundLookup = false;
        }
    }

}
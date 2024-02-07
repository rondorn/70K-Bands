package com.Bands70k;

/**
 * Created by rdorn on 6/3/16.
 */
import android.os.AsyncTask;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;

import java.net.HttpURLConnection;
import java.net.InetAddress;
import java.net.MalformedURLException;
import java.net.URL;
import java.net.UnknownHostException;
import java.util.ArrayList;


public class OnlineStatus {

    public static URL dnsResolveCache = null;

    public static boolean isOnline() {

        Log.d("Internet Found", "Internet Found Checking Internet");
        OnlineStatus statusCheckHandler = new OnlineStatus();
        Boolean onlineCheck = statusCheckHandler.isInternetAvailableTest();

        Log.d("Internet Found", "Internet Found Checking Internet Done - onlineCheck is " + onlineCheck);
        return onlineCheck;
    }

    public Boolean isInternetAvailableTest() {

        Boolean returnState = false;

        Long currentEpoc = System.currentTimeMillis() / 1000L;

        Log.d("Internet Found", "Internet Found " + currentEpoc + " < " + staticVariables.internetCheckCacheDate);
        String previousValue = staticVariables.internetCheckCache;
        if (currentEpoc > staticVariables.internetCheckCacheDate){
            Log.d("Internet Found", "Internet Found Clearing cache");
            currentEpoc = System.currentTimeMillis() / 1000L;
            staticVariables.internetCheckCacheDate = currentEpoc + 15;

            staticVariables.internetCheckCache = "Unknown";
        }
        if (staticVariables.internetCheckCache.equals("Unknown") == false){
            if (staticVariables.internetCheckCache == "false") {
                returnState = false;
            } else {
                returnState = true;
            }
            Log.d("Internet Found", "Internet Found Return state is cached  " + returnState);

        } else {

            if (previousValue == "false") {
                returnState = false;
            } else {
                returnState = true;
            }

            Log.d("Internet Found", "Internet Found Return state is cached, but refreshing " + returnState);

            IsInternetAvailableAsynchronous checkInternet = new IsInternetAvailableAsynchronous();
            checkInternet.execute();

        }

        staticVariables.internetCheckCache = String.valueOf(returnState);
        return returnState;
    }

    public static Boolean testInternetAvailableSynchronous() {

        Boolean returnState = false;

        Long currentEpoc = System.currentTimeMillis() / 1000L;

        //Get the IP of the Host
        URL url = null;
        try {
            url = ResolveHostIP(staticVariables.networkTestingUrl,5000);
            dnsResolveCache = url;

        } catch (MalformedURLException e) {

        }

        Log.d("Internet Found", "Internet Found using URL of " + url);
        if(url != null) {

            try {

                Log.d("Internet Found", "Internet Found using URL of " + url);

                HttpURLConnection.setFollowRedirects(true);
                HttpURLConnection connection = (HttpURLConnection) new URL(staticVariables.networkTestingUrl).openConnection();
                connection.setRequestMethod("HEAD");

                connection.setConnectTimeout(5000);
                connection.setReadTimeout(5000);
                Log.d("Internet Found", "Internet Found https called returned " + connection.toString());

                if (connection.getResponseCode() == HttpURLConnection.HTTP_OK) {
                    Log.d("Internet Found", "Internet Found true ");
                    returnState = true;
                    staticVariables.internetCheckCache = "true";
                    connection.disconnect();
                } else {
                    returnState = false;
                    Log.d("Internet Found", "Internet Found false " + connection.getResponseCode());
                }


            } catch (Exception generalError) {
                Log.d("Internet Found", "Internet Found false 1 " + generalError.getMessage());
                returnState = false;
            }
        } else {
            Log.d("Internet Found", "Internet Found false 2 ");
            returnState = false;
        }

        staticVariables.internetCheckCacheDate = currentEpoc + 15;
        staticVariables.internetCheckCache = String.valueOf(returnState);

        Log.d("Internet Found", "Internet Found results are " + returnState);
        return returnState;
    }


    class IsInternetAvailableAsynchronous extends AsyncTask<String, Void, ArrayList<String>> {

        ArrayList<String> result;

        @Override
        protected void onPreExecute() {
            staticVariables.internetCheckCache = "true";
        }


        @Override
        protected ArrayList<String> doInBackground(String... params) {

            Boolean onlineCheck = testInternetAvailableSynchronous();

            if (onlineCheck == true) {
                staticVariables.internetCheckCache = "true";
            } else {
                staticVariables.internetCheckCache = "false";
            }

            return result;

        }

        @Override
        protected void onPostExecute(ArrayList<String> result) {

        }
    }


    //Run the DNS lookup manually to be able to time it out.
    public static URL ResolveHostIP (String sURL, int timeout) throws MalformedURLException {

        if (Looper.myLooper() != Looper.getMainLooper() && dnsResolveCache != null) {
            return dnsResolveCache;
        }

        URL url= new URL(sURL);
        //Resolve the host IP on a new thread
        DNSResolver dnsRes = new DNSResolver(url.getHost());
        Thread t = new Thread(dnsRes);
        t.start();
        //Join the thread for some time
        try {
            t.join(timeout);
        } catch (InterruptedException e) {
            Log.d("DEBUG", "DNS lookup interrupted");
            return null;
        }

        //get the IP of the host
        InetAddress inetAddr = dnsRes.get();
        if(inetAddr==null) {
            Log.d("DEBUG", "DNS timed out.");
            return null;
        }

        //rebuild the URL with the IP and return it
        Log.d("DEBUG", "DNS solved.");
        return new URL(url.getProtocol(),inetAddr.getHostAddress(),url.getPort(),url.getFile());
    }

    public static class DNSResolver implements Runnable {
        private String domain;
        private InetAddress inetAddr;

        public DNSResolver(String domain) {
            this.domain = domain;
        }

        public void run() {
            try {
                InetAddress addr = InetAddress.getByName(domain);
                set(addr);
            } catch (UnknownHostException e) {
            }
        }

        public synchronized void set(InetAddress inetAddr) {
            this.inetAddr = inetAddr;
        }
        public synchronized InetAddress get() {
            return inetAddr;
        }
    }
}


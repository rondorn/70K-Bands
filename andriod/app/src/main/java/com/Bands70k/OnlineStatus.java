package com.Bands70k;

/**
 * Created by rdorn on 6/3/16.
 */
import android.os.AsyncTask;
import android.os.Looper;
import android.util.Log;

import java.net.HttpURLConnection;
import java.net.InetAddress;
import java.net.MalformedURLException;
import java.net.URL;
import java.net.UnknownHostException;
import java.util.ArrayList;


public class OnlineStatus {


    public static String internetCheckCache = "Unknown";
    public static Long internetCheckCacheDate = 0L;
    public static URL dnsResolveCache = null;

    public static boolean isOnline() {

        Log.d("Internet Found", "Internet Found Checking Internet");
        staticVariables.checkingInternet = true;
        OnlineStatus statusCheckHandler = new OnlineStatus();
        Boolean onlineCheck = statusCheckHandler.isInternetAvailableTest();

        Log.d("Internet Found", "Internet Found Checking Internet Done");
        return onlineCheck;
    }

    public boolean isInternetAvailableTest() {

        Boolean returnState = false;

        Long currentEpoc = System.currentTimeMillis() / 1000L;

        Log.d("Internet Found", "Internet Found " + currentEpoc + " < " + internetCheckCacheDate);

        if (internetCheckCache != "Unknown" && currentEpoc < internetCheckCacheDate) {
            if (internetCheckCache == "false") {
                returnState = false;
            } else {
                returnState = true;
            }

            Log.d("Internet Found", "Internet Found Return state is cached  " + returnState);

            //cache has expired, but lets return last answer and check again in the background
        } else if (internetCheckCache != "Unknown") {

            if (internetCheckCache == "false") {
                returnState = false;
            } else {
                returnState = true;
            }

            Log.d("Internet Found", "Internet Found Return state is cached, but refreshing " + returnState);

            if (staticVariables.checkingInternet == false) {
                staticVariables.checkingInternet  = true;
                IsInternetAvailableAsynchronous checkInternet = new IsInternetAvailableAsynchronous();
                checkInternet.execute();
            }

        } else {

            returnState = isInternetAvailableSynchronous();
        }

        return returnState;
    }

    public static Boolean isInternetAvailableSynchronous() {

        Boolean returnState = false;

        Long currentEpoc = System.currentTimeMillis() / 1000L;

        //Get the IP of the Host
        URL url = null;
        try {
            url = ResolveHostIP(staticVariables.networkTestingUrl,10000);
            dnsResolveCache = url;

        } catch (MalformedURLException e) {
            Log.d("INFO", "Internet Found URL resovle error of " + e.getMessage());
            try {
                dnsResolveCache = new URL("https://162.125.248.1");
            } catch (MalformedURLException error) {

            }
        }
        Log.d("Internet Found", "Internet Found using URL of " + url);
        if(url != null) {

            try {

                Log.d("Internet Found", "Internet Found using URL of " + url);

                HttpURLConnection.setFollowRedirects(true);
                HttpURLConnection connection = (HttpURLConnection) new URL(staticVariables.networkTestingUrl).openConnection();
                connection.setRequestMethod("HEAD");

                connection.setConnectTimeout(10000);
                connection.setReadTimeout(10000);
                Log.d("Internet Found", "Internet Found https called returned " + connection.toString());

                if (connection.getResponseCode() == HttpURLConnection.HTTP_OK) {
                    Log.d("Internet Found", "Internet Found true ");
                    returnState = true;
                    internetCheckCache = "true";
                    connection.disconnect();
                } else {
                    Log.d("Internet Found", "Internet Found false " + connection.getResponseCode());
                }


            } catch (Exception generalError) {
                Log.d("Internet Found", "Internet Found false 1 " + generalError.getMessage());
                internetCheckCache = "false";
            }
        } else {
            OnlineStatus.internetCheckCache = "false";
        }

        OnlineStatus.internetCheckCacheDate = currentEpoc + 15;

        Log.d("Internet Found", "Internet Found " + returnState);
        return returnState;
    }


    class IsInternetAvailableAsynchronous extends AsyncTask<String, Void, ArrayList<String>> {

        ArrayList<String> result;

        @Override
        protected void onPreExecute() {

        }


        @Override
        protected ArrayList<String> doInBackground(String... params) {

            Boolean onlineCheck = isInternetAvailableTest();

            if (onlineCheck == true) {
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
            staticVariables.checkingInternet  = false;
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


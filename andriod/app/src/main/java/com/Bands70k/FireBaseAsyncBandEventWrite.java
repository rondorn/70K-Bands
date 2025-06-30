package com.Bands70k;

import android.os.AsyncTask;

import java.util.ArrayList;

/**
 * AsyncTask for writing band and event data to Firebase in the background.
 */
public class FireBaseAsyncBandEventWrite extends AsyncTask<String, Void, ArrayList<String>> {

        ArrayList<String> result;

        /**
         * Runs on the UI thread before the background computation begins.
         */
        @Override
        protected void onPreExecute() {
                super.onPreExecute();
                }

        /**
         * Performs the background write operation to Firebase for band and event data.
         * @param params The parameters for the background task.
         * @return The result of the background operation.
         */
        @Override
        protected ArrayList<String> doInBackground(String... params) {

                FireBaseBandDataWrite bandWrite = new FireBaseBandDataWrite();
                bandWrite.writeData();

                FirebaseEventDataWrite eventWrite = new FirebaseEventDataWrite();
                eventWrite.writeData();

                return result;
        }
}



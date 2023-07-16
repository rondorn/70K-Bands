package com.Bands70k;

import android.os.AsyncTask;

import java.util.ArrayList;


public class FireBaseAsyncBandEventWrite extends AsyncTask<String, Void, ArrayList<String>> {

        ArrayList<String> result;

        @Override
        protected void onPreExecute() {
                super.onPreExecute();
                }

        @Override
        protected ArrayList<String> doInBackground(String... params) {

                FireBaseBandDataWrite bandWrite = new FireBaseBandDataWrite();
                bandWrite.writeData();

                FirebaseEventDataWrite eventWrite = new FirebaseEventDataWrite();
                eventWrite.writeData();

                return result;
        }
}



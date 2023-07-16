package com.Bands70k;

import android.os.AsyncTask;

import java.util.ArrayList;


public class FirbaseAsyncUserWrite extends AsyncTask<String, Void, ArrayList<String>> {

    ArrayList<String> result;

    @Override
    protected void onPreExecute() {
        super.onPreExecute();
    }

    @Override
    protected ArrayList<String> doInBackground(String... params) {

        FirebaseUserWrite userDataWrite = new FirebaseUserWrite();
        userDataWrite.writeData();

        return result;
    }

}

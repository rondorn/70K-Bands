package com.Bands70k;

import android.os.AsyncTask;

import java.util.ArrayList;

/**
 * AsyncTask for writing user data to Firebase in the background.
 */
public class FirbaseAsyncUserWrite extends AsyncTask<String, Void, ArrayList<String>> {

    ArrayList<String> result;

    /**
     * Runs on the UI thread before the background computation begins.
     */
    @Override
    protected void onPreExecute() {
        super.onPreExecute();
    }

    /**
     * Performs the background write operation to Firebase.
     * @param params The parameters for the background task.
     * @return The result of the background operation.
     */
    @Override
    protected ArrayList<String> doInBackground(String... params) {

        FirebaseUserWrite userDataWrite = new FirebaseUserWrite();
        userDataWrite.writeData();

        return result;
    }

}

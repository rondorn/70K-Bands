package com.Bands70k;

import android.os.AsyncTask;
import android.os.StrictMode;
import android.util.Log;

import java.io.BufferedReader;
import java.io.DataInputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;


/**
 * Created by rdorn on 9/25/17.
 */

public class CustomerDescriptionHandler {

    private Map<String, String> descriptionMapData = new HashMap<String,String>();

    public void getDescriptionMapFile(){

        BandInfo bandInfo = new BandInfo();
        bandInfo.getDownloadtUrls();

        String descriptionMapURL = staticVariables.descriptionMap;
        if (staticVariables.preferences.getUseLastYearsData() == true){
            descriptionMapURL = staticVariables.previousYearDescriptionMap;
        }
        if (descriptionMapURL == null){
            return;
        }
        Log.d("descriptionMapPointer", descriptionMapURL);
        try {

            URL u = new URL(descriptionMapURL);
            InputStream is = u.openStream();

            DataInputStream dis = new DataInputStream(is);

            byte[] buffer = new byte[1024];
            int length;

            FileOutputStream fos = new FileOutputStream(FileHandler70k.descriptionMapFile);
            while ((length = dis.read(buffer))>0) {
                fos.write(buffer, 0, length);
            }


        } catch (MalformedURLException mue) {
            Log.e("SYNC getUpdate", "descriptionMapFile malformed url error", mue);
        } catch (IOException ioe) {
            Log.e("SYNC getUpdate", "descriptionMapFile io error", ioe);
        } catch (SecurityException se) {
            Log.e("SYNC getUpdate", "descriptionMapFile security error", se);

        } catch (Exception generalError){
            Log.e("General Exception", "Downloading descriptionMapFile", generalError);
        }

    }

    public Map<String, String>  getDescriptionMap(){

        if (FileHandler70k.descriptionMapFile.exists() == false){
            this.getDescriptionMapFile();
        }

        try {
            File file = FileHandler70k.descriptionMapFile;

            BufferedReader br = new BufferedReader(new FileReader(file));
            String line;

            while ((line = br.readLine()) != null) {
                String[] rowData = line.split(",");
                if (rowData[0] != "Band") {
                    Log.d("descriptionMapFile", "Adding " + rowData[0] + "-" + rowData[1]);
                    descriptionMapData.put(rowData[0], rowData[1]);
                }
            }

        } catch (Exception error){
            Log.e("General Exception", "Unable to parse descriptionMapFile", error);
        }

        return descriptionMapData;
    }

    public void getAllDescriptions(){

        AsyncAllDescriptionLoader myNotesTask = new AsyncAllDescriptionLoader();
        myNotesTask.execute();
    }

    public String getDescription (String bandNameValue){


        String bandName = bandNameValue;
        String bandNote = "Comment text is not available yet. Please wait for Aaron to add his description. You can add your own if you choose, but when his becomes available it will not overwrite your data, and will not display.";

        if (descriptionMapData.keySet().size() == 0) {
            descriptionMapData = this.getDescriptionMap();
        }

        if (descriptionMapData.containsKey(bandName) == false){
            return bandNote;
        }

        BandNotes bandNoteHandler = new BandNotes(bandName);


        if (bandNoteHandler.fileExists() == false) {

            AsyncDescriptionLoader myNotesTask = new AsyncDescriptionLoader();
            myNotesTask.execute(bandName);

        }

        bandNote = bandNoteHandler.getBandNoteFromFile();
        bandNote = removeSpecialCharsFromString(bandNote);

        return bandNote;
    }

    private String removeSpecialCharsFromString(String text) {
        String fixedText = text.replaceAll("\\r", "<br><br>");
        fixedText = fixedText.replaceAll("\\n", "<br><br>");
        fixedText = fixedText.replaceAll("[^\\p{ASCII}]", "");
        fixedText = fixedText.replaceAll("\\?", "");

        return fixedText;
    }

    private void loadNoteFromURL(String bandName){
        try {

            BandNotes bandNoteHandler = new BandNotes(bandName);

            if (bandNoteHandler.fileExists() == true){
                return;
            }

            if (descriptionMapData.containsKey(bandName) == false) {
                getDescriptionMapFile();
                descriptionMapData = this.getDescriptionMap();
            }

            Log.d("descriptionMapFile", "Looking up NoteData at URL " + descriptionMapData.get(bandName));
            URL url = new URL(descriptionMapData.get(bandName));

            BufferedReader in = new BufferedReader(new InputStreamReader(url.openStream()));
            String line;
            String bandNote = "";
            while ((line = in.readLine()) != null) {
                bandNote += line + "\n";
            }
            in.close();

            bandNote = this.removeSpecialCharsFromString(bandNote);
            bandNoteHandler.saveBandNote(bandNote);

        } catch (MalformedURLException mue) {
            Log.e("SYNC getUpdate", "descriptionMapFile malformed url error", mue);
        } catch (IOException ioe) {
            Log.e("SYNC getUpdate", "descriptionMapFile io error", ioe);
        } catch (SecurityException se) {
            Log.e("SYNC getUpdate", "descriptionMapFile security error", se);

        } catch (Exception generalError) {
            Log.e("General Exception", "Downloading descriptionMapFile", generalError);
        }
    }

    class AsyncAllDescriptionLoader extends AsyncTask<String, Void, ArrayList<String>> {

        ArrayList<String> result;


        @Override
        protected void onPreExecute() {
            super.onPreExecute();
        }


        @Override
        protected ArrayList<String> doInBackground(String... params) {

            CustomerDescriptionHandler descriptionHandler = new CustomerDescriptionHandler();
            StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
            StrictMode.setThreadPolicy(policy);

            Log.d("AsyncTask", "Downloading NoteData for all bands in background");
            if (staticVariables.notesLoaded == false){
                staticVariables.notesLoaded =true;
                getDescriptionMapFile();
                descriptionMapData = descriptionHandler.getDescriptionMap();


                for (String bandName : descriptionMapData.keySet()) {
                    descriptionHandler.loadNoteFromURL(bandName);
                }
                staticVariables.notesLoaded = false;
            }


            return result;

        }

        @Override
        protected void onPostExecute(ArrayList<String> result) {

        }
    }

    class AsyncDescriptionLoader extends AsyncTask<String, Void, ArrayList<String>> {

        ArrayList<String> result;


        @Override
        protected void onPreExecute() {
            super.onPreExecute();
        }


        @Override
        protected ArrayList<String> doInBackground(String... params) {


            StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
            StrictMode.setThreadPolicy(policy);

            String bandName = params[0];
            Log.d("AsyncTask", "Downloading NoteData for " + bandName);

            loadNoteFromURL(bandName);

            return result;

        }

        @Override
        protected void onPostExecute(ArrayList<String> result) {

        }
    }
}

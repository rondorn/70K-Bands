package com.Bands70k;

import android.os.AsyncTask;
import android.os.Looper;
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
import java.sql.Date;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;


/**
 * Created by rdorn on 9/25/17.
 */

public class CustomerDescriptionHandler {

    private Map<String, String> descriptionMapData = new HashMap<String,String>();

    public CustomerDescriptionHandler(){
        descriptionMapData = this.getDescriptionMap();
    }

    public void getDescriptionMapFile(){

        BandInfo bandInfo = new BandInfo();
        bandInfo.getDownloadtUrls();

        String descriptionMapURL = staticVariables.descriptionMap;
        if (staticVariables.preferences.getUseLastYearsData() == true){
            descriptionMapURL = staticVariables.previousYearDescriptionMap;
        }

        if (OnlineStatus.isOnline() == true && Looper.myLooper() != Looper.getMainLooper()) {
            try {

                URL u = new URL(descriptionMapURL);
                InputStream is = u.openStream();

                DataInputStream dis = new DataInputStream(is);

                byte[] buffer = new byte[1024];
                int length;

                FileOutputStream fos = new FileOutputStream(FileHandler70k.descriptionMapFile);
                while ((length = dis.read(buffer)) > 0) {
                    fos.write(buffer, 0, length);
                }


            } catch (MalformedURLException mue) {
                Log.e("SYNC getUpdate", "descriptionMapFile malformed url error", mue);
            } catch (IOException ioe) {
                Log.e("SYNC getUpdate", "descriptionMapFile io error", ioe);
            } catch (SecurityException se) {
                Log.e("SYNC getUpdate", "descriptionMapFile security error", se);

            } catch (Exception generalError) {
                Log.e("General Exception", "Downloading descriptionMapFile", generalError);
            }

            Log.d("descriptionMapFile", "descriptionMapFile Downloaded!");
        }
    }

    public Map<String, String>  getDescriptionMap(){
        //only load data if it is not already populated
        if (descriptionMapData.isEmpty() == false){
            return this.descriptionMapData;
        }

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
                    if (rowData.length > 2){
                        Log.d("descriptionMapFile", "Date value is " + rowData[2]);
                        staticVariables.descriptionMapModData.put(rowData[0], rowData[2]);
                    }
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


        Log.d("getDescription", "getDescription - 1 " + bandNameValue);

        String bandName = bandNameValue;
        String bandNoteDefault = "Comment text is not available yet. Please wait for Aaron to add his description. You can add your own if you choose, but when his becomes available it will not overwrite your data, and will not display.";
        String bandNote = bandNoteDefault;

        Log.d("getDescription", "1a descriptionMapData is " + descriptionMapData);

        if (descriptionMapData.containsKey(bandName) == false) {
            return bandNoteDefault;
        }

        if (descriptionMapData.keySet().size() == 0) {
            descriptionMapData = this.getDescriptionMap();
            Log.d("getDescription", "getDescription - 2 " + bandNameValue);
        }

        BandNotes bandNoteHandler = new BandNotes(bandName);

        if (descriptionMapData.containsKey(bandName) == false) {
            descriptionMapData = new HashMap<String,String>();
            descriptionMapData = getDescriptionMap();
            Log.d("getDescription", "getDescription - 3a " + descriptionMapData);
        } else {
            Log.d("getDescription", "getDescription - 3b " + descriptionMapData.get(bandName));
        }

        if (descriptionMapData.containsKey(bandName) == false){
            Log.d("getDescription", "getDescription - 3 " + bandNameValue);
            if (staticVariables.showNotesMap.containsKey(bandName) == true) {
                if (staticVariables.showNotesMap.get(bandName).length() > 5) {
                    Log.d("getDescription", "getDescription - 4 " + bandNameValue);
                    loadNoteFromURL(bandName);
                    Log.d("getDescription", "getDescription - 5 " + bandNameValue);
                    bandNote = bandNoteHandler.getBandNoteFromFile();
                    Log.d("getDescription", "getDescription - 6 " + bandNameValue);
                    return bandNote;
                }
            }
        }

        loadNoteFromURL(bandNameValue);
        Log.d("getDescription", "getDescription - 7 " + bandNameValue);

        bandNote = bandNoteHandler.getBandNoteFromFile();
        bandNote = removeSpecialCharsFromString(bandNote);

        Log.d("getDescription", "getDescription - 8 " + bandNote);
        return bandNote;
    }

    private String removeSpecialCharsFromString(String text) {
        String fixedText = text.replaceAll("\\r", "<br><br>");
        fixedText = fixedText.replaceAll("\\n", "<br><br>");
        fixedText = fixedText.replaceAll("[^\\p{ASCII}]", "");
        fixedText = fixedText.replaceAll("\\?", "");

        return fixedText;
    }

    public void loadNoteFromURL(String bandName){

        BandNotes bandNoteHandler = new BandNotes(bandName);
        File oldBandNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note");
        if (oldBandNoteFile.exists() == true){
            bandNoteHandler.convertOldBandNote();
        }

        try {

            File changeFileFlag = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + "-" + String.valueOf(staticVariables.descriptionMapModData.get(bandName)));
            File bandCustNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note_cust");
            if (bandNoteHandler.fileExists() == true && changeFileFlag.exists() == false && bandCustNoteFile.exists() == false){
                Log.d("getDescription", "getDescription, re-downloading default data due to change! " + bandName);

            } else if (bandNoteHandler.fileExists() == true){
                Log.d("getDescription", "getDescription, NOT re-downloading default data due to change! "+ bandName);
                return;
            }
            Log.d("getDescription", "getDescription, NOT re-downloading default data due to change! "+ bandName);
            if (descriptionMapData.containsKey(bandName) == false) {
                descriptionMapData = new HashMap<String,String>();
                getDescriptionMapFile();
                descriptionMapData = this.getDescriptionMap();
            }


            URL url;
            if (OnlineStatus.isOnline() == true) {

                try {
                    if (staticVariables.showNotesMap.containsKey(bandName) &&
                            staticVariables.showNotesMap.get(bandName).length() > 5) {
                        url = new URL(staticVariables.showNotesMap.get(bandName));
                        Log.d("descriptionMapFile!", "Looking up NoteData at URL " + url.toString());
                    } else if (descriptionMapData.containsKey(bandName) == true) {
                        url = new URL(descriptionMapData.get(bandName));
                        Log.d("descriptionMapFile!", "Looking up NoteData at URL " + url.toString());
                    } else {
                        Log.d("descriptionMapFile!", "no description for bandName " + bandName);
                        return;
                    }

                } catch (Exception error) {
                    Log.d("descriptionMapFile!", "could not load! for " + bandName + " - " + descriptionMapData.get(bandName));
                    return;
                }
            } else {
                return;
            }

            BufferedReader in = new BufferedReader(new InputStreamReader(url.openStream()));
            String line;
            String bandNote = "";
            while ((line = in.readLine()) != null) {
                bandNote += line + "\n";
            }
            in.close();

            bandNote = this.removeSpecialCharsFromString(bandNote);



            bandNoteHandler.saveDefaultBandNote(bandNote);

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
            if (staticVariables.notesLoaded == false) {
                staticVariables.notesLoaded = true;
                getDescriptionMapFile();
                descriptionMapData = descriptionHandler.getDescriptionMap();

                Log.d("AsyncTask", "Downloading NoteData for " + descriptionMapData);
                if (descriptionMapData != null) {
                    for (String bandName : descriptionMapData.keySet()) {
                        Log.d("AsyncTask", "Downloading NoteData for  -1 " + bandName);
                        descriptionHandler.loadNoteFromURL(bandName);
                    }
                    staticVariables.notesLoaded = false;
                }
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

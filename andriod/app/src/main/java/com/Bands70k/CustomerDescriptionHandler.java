package com.Bands70k;

import android.os.AsyncTask;
import android.os.Looper;
import android.os.StrictMode;
import android.os.SystemClock;
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
 * Handles downloading, loading, and providing band description data for the app.
 * Created by rdorn on 9/25/17.
 */

public class CustomerDescriptionHandler {

    private Map<String, String> descriptionMapData = new HashMap<String,String>();

    /**
     * Constructs a CustomerDescriptionHandler and loads the description map.
     */
    public CustomerDescriptionHandler(){
        descriptionMapData = this.getDescriptionMap();
    }

    /**
     * Downloads the description map file from the server if online.
     */
    public void getDescriptionMapFile(){

        BandInfo bandInfo = new BandInfo();
        bandInfo.getDownloadtUrls();

        String descriptionMapURL = staticVariables.descriptionMap;

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

    /**
     * Loads the description map from file or downloads it if not present.
     * @return The map of band names to descriptions.
     */
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

    /**
     * Starts an async task to load all band descriptions.
     */
    public void getAllDescriptions(){

        AsyncAllDescriptionLoader myNotesTask = new AsyncAllDescriptionLoader();
        myNotesTask.execute();
    }

    /**
     * Gets the description for a given band, loading from file or URL as needed.
     * @param bandNameValue The name of the band.
     * @return The band description string.
     */
    public String getDescription (String bandNameValue){

        Log.d("70K_NOTE_DEBUG", "getDescription called for " + bandNameValue);

        String bandName = bandNameValue;
        String bandNoteDefault = "Comment text is not available yet. Please wait for Aaron to add his description. You can add your own if you choose, but when his becomes available it will not overwrite your data, and will not display.";
        String bandNote = bandNoteDefault;

        Log.d("70K_NOTE_DEBUG", "descriptionMapData: " + descriptionMapData);

        BandNotes bandNoteHandler = new BandNotes(bandName);

        // PATCH: Always check for a custom note, even if band is not in descriptionMapData
        String customNote = bandNoteHandler.getBandNoteFromFile();
        if (customNote != null && !customNote.trim().isEmpty()) {
            Log.d("70K_NOTE_DEBUG", "Returning custom note for " + bandName + ": " + customNote);
            return customNote;
        }

        if (descriptionMapData.containsKey(bandName) == false) {
            Log.d("70K_NOTE_DEBUG", "No descriptionMap entry for " + bandName + ", returning default note");
            return bandNoteDefault;
        }

        if (descriptionMapData.keySet().size() == 0) {
            descriptionMapData = this.getDescriptionMap();
            Log.d("70K_NOTE_DEBUG", "descriptionMapData was empty, reloaded for " + bandNameValue);
        }

        if (descriptionMapData.containsKey(bandName) == false) {
            descriptionMapData = new HashMap<String,String>();
            descriptionMapData = getDescriptionMap();
            Log.d("70K_NOTE_DEBUG", "descriptionMapData still missing for " + bandName);
        } else {
            Log.d("70K_NOTE_DEBUG", "descriptionMapData present for " + bandName + ": " + descriptionMapData.get(bandName));
        }

        if (descriptionMapData.containsKey(bandName) == false){
            Log.d("70K_NOTE_DEBUG", "descriptionMapData still missing after reload for " + bandName);
            if (staticVariables.showNotesMap.containsKey(bandName) == true) {
                if (staticVariables.showNotesMap.get(bandName).length() > 5) {
                    Log.d("70K_NOTE_DEBUG", "showNotesMap entry found for " + bandName + ", loading note from URL");
                    loadNoteFromURL(bandName);
                    bandNote = bandNoteHandler.getBandNoteFromFile();
                    Log.d("70K_NOTE_DEBUG", "Loaded note from file after URL for " + bandName + ": " + bandNote);
                    return bandNote;
                }
            }
        }

        Log.d("70K_NOTE_DEBUG", "Calling loadNoteFromURL for " + bandNameValue);
        loadNoteFromURL(bandNameValue);
        Log.d("70K_NOTE_DEBUG", "Called loadNoteFromURL for " + bandNameValue);

        bandNote = bandNoteHandler.getBandNoteFromFile();
        bandNote = removeSpecialCharsFromString(bandNote);

        Log.d("70K_NOTE_DEBUG", "Returning note for " + bandName + ": " + bandNote);
        return bandNote;
    }

    /**
     * Removes special characters and replaces newlines with HTML breaks.
     * @param text The text to clean.
     * @return The cleaned text.
     */
    private String removeSpecialCharsFromString(String text) {
        String fixedText = "";
        if (text != null) {
            fixedText = text.replaceAll("\\r", "<br><br>");
            fixedText = fixedText.replaceAll("\\n", "<br><br>");
            fixedText = fixedText.replaceAll("[^\\p{ASCII}]", "");
            fixedText = fixedText.replaceAll("\\?", "");
        }
        return fixedText;
    }

    /**
     * Loads the note for a band from a remote URL if needed.
     * @param bandName The name of the band.
     */
    public void loadNoteFromURL(String bandName){

        BandNotes bandNoteHandler = new BandNotes(bandName);
        File oldBandNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note");
        if (oldBandNoteFile.exists() == true){
            Log.d("70K_NOTE_DEBUG", "Converting old band note for " + bandName);
            bandNoteHandler.convertOldBandNote();
        }

        try {

            File changeFileFlag = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + "-" + String.valueOf(staticVariables.descriptionMapModData.get(bandName)));
            File bandCustNoteFile = new File(showBands.newRootDir + FileHandler70k.directoryName + bandName + ".note_cust");
            // PATCH: If a custom note exists, do NOT overwrite with default note from server
            if (bandCustNoteFile.exists()) {
                Log.d("70K_NOTE_DEBUG", "Custom note exists for " + bandName + ", skipping default note download and overwrite.");
                return;
            }
            if (bandNoteHandler.fileExists() == true && changeFileFlag.exists() == false && bandCustNoteFile.exists() == false){
                Log.d("70K_NOTE_DEBUG", "getDescription, re-downloading default data due to change! " + bandName);

            } else if (bandNoteHandler.fileExists() == true){
                Log.d("70K_NOTE_DEBUG", "getDescription, NOT re-downloading default data due to change! "+ bandName);
                return;
            }
            Log.d("70K_NOTE_DEBUG", "getDescription, NOT re-downloading default data due to change! "+ bandName);
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
                        Log.d("70K_NOTE_DEBUG", "Looking up NoteData at URL " + url.toString());
                    } else if (descriptionMapData.containsKey(bandName) == true) {
                        url = new URL(descriptionMapData.get(bandName));
                        Log.d("70K_NOTE_DEBUG", "Looking up NoteData at URL " + url.toString());
                    } else {
                        Log.d("70K_NOTE_DEBUG", "no description for bandName " + bandName);
                        return;
                    }

                } catch (Exception error) {
                    Log.d("70K_NOTE_DEBUG", "could not load! for " + bandName + " - " + descriptionMapData.get(bandName));
                    return;
                }
            } else {
                Log.d("70K_NOTE_DEBUG", "Not online, skipping download for " + bandName);
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

            Log.d("70K_NOTE_DEBUG", "Saving default note for " + bandName + ": " + bandNote);
            bandNoteHandler.saveDefaultBandNote(bandNote);

        } catch (MalformedURLException mue) {
            Log.e("70K_NOTE_DEBUG", "descriptionMapFile malformed url error", mue);
        } catch (IOException ioe) {
            Log.e("70K_NOTE_DEBUG", "descriptionMapFile io error", ioe);
        } catch (SecurityException se) {
            Log.e("70K_NOTE_DEBUG", "descriptionMapFile security error", se);

        } catch (Exception generalError) {
            Log.e("70K_NOTE_DEBUG", "Downloading descriptionMapFile", generalError);
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
            while (staticVariables.loadingNotes == true) {
                SystemClock.sleep(2000);
            }

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

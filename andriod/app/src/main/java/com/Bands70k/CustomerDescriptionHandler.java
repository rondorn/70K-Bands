package com.Bands70k;

import android.os.AsyncTask;
import android.os.StrictMode;
import android.util.Log;
import android.view.View;
import android.widget.ListAdapter;

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
import java.util.PriorityQueue;

import static com.Bands70k.staticVariables.fileDownloaded;

/**
 * Created by rdorn on 9/25/17.
 */

public class CustomerDescriptionHandler {


    public void getDescriptionMapFile(){

        BandInfo bandInfo = new BandInfo();
        bandInfo.getDownloadtUrls();

        String descriptionMapURL = staticVariables.descriptionMap;
        if (staticVariables.preferences.getUseLastYearsData() == true){
            descriptionMapURL = staticVariables.previousYearDescriptionMap;
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

        Map<String, String> descriptionMap = new HashMap<String, String>();

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
                    descriptionMap.put(rowData[0], rowData[1]);
                }
            }

        } catch (Exception error){
            Log.e("General Exception", "Unable to parse descriptionMapFile", error);
        }

        return descriptionMap;
    }

    public void getAllDescriptions(){

        if (staticVariables.notesLoaded == false){
            staticVariables.notesLoaded =true;
            getDescriptionMapFile();
            getDescriptionMap();

            Map<String, String> descriptionMap = this.getDescriptionMap();

            for (String bandName : descriptionMap.keySet()) {
                loadNoteFromURL(bandName);
            }
        }

    }

    public String getDescription (String bandNameValue){


        String bandName = bandNameValue;
        String bandNote = "Comment text is not available yet. Please wait for Aaron to add his description. You can add your own if you choose, but when his becomes available it will not overwrite your data, and will not display.";

        Map<String, String> descriptionMap = this.getDescriptionMap();

        if (descriptionMap == null){
            this.getDescriptionMap();
        }
        if (descriptionMap.containsKey(bandName) == false){
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

            Map<String, String> descriptionMap = this.getDescriptionMap();

            Log.d("descriptionMapFile", "Looking up NoteData at URL " + descriptionMap.get(bandName));
            URL url = new URL(descriptionMap.get(bandName));

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

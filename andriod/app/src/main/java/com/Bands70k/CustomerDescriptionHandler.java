package com.Bands70k;

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
import java.util.HashMap;
import java.util.Map;
import java.util.PriorityQueue;

/**
 * Created by rdorn on 9/25/17.
 */

public class CustomerDescriptionHandler {

    public Map<String, String> descriptionMap;

    public void getDescriptionMapFile(){

        BandInfo bandInfo = new BandInfo();
        bandInfo.getDownloadtUrls();

        try {
            URL u = new URL(bandInfo.downloadUrls.get("descriptionMap"));
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

    public void getDescriptionMap(){

        if (FileHandler70k.descriptionMapFile.exists() == false){
            this.getDescriptionMapFile();
        }

        try {
            File file = FileHandler70k.descriptionMapFile;

            BufferedReader br = new BufferedReader(new FileReader(file));
            String line;

            descriptionMap = new HashMap<String, String>();

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
    }

    public void getAllDescriptions(){
        getDescriptionMapFile();
        getDescriptionMap();

        for (String band : descriptionMap.keySet()){
            getDescription(band);
        }

    }

    public String getDescription (String bandName){

        String bandNote = "Comment text is not available yet. Please wait for Aaron to add his description. You can add your own if you choose, but when his becomes available it will not overwrite your data, and will not display.";

        if (descriptionMap == null){
            this.getDescriptionMap();
        }
        if (descriptionMap.containsKey(bandName) == false){
            return bandNote;
        }

        BandNotes bandNoteHandler = new BandNotes(bandName);


        if (bandNoteHandler.fileExists() == false) {
            try {

                Log.d("descriptionMapFile", "Looking up note at URL " + descriptionMap.get(bandName));
                URL url = new URL(descriptionMap.get(bandName));

                BufferedReader in = new BufferedReader(new InputStreamReader(url.openStream()));
                String line;
                bandNote = "";
                while ((line = in.readLine()) != null) {
                    bandNote += line + "\n";
                }
                in.close();

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
        } else {
            bandNote = bandNoteHandler.getBandNoteFromFile();
        }

        bandNote = removeSpecialCharsFromString(bandNote);

        return bandNote;
    }

    private String removeSpecialCharsFromString(String text) {
        String fixedText = text.replaceAll("[^\\p{ASCII}]", "");
        fixedText = fixedText.replaceAll("\\?", "");

        return fixedText;
    }
}

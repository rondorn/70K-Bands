package com.Bands70k;

import android.os.Environment;
import android.os.StrictMode;
import android.util.Log;

import java.io.BufferedReader;
import java.io.DataInputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStream;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

/**
 * Created by rdorn on 7/25/15.
 */

public class BandInfo {

    private static Map<String, Map> bandData = new HashMap<String, Map>();
    //private ArrayList<String> bandNames = new ArrayList<String>();
    private static String selectedBand;

    public void onCreate() {
        StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
        StrictMode.setThreadPolicy(policy);
    }

    public static void setSelectedBand(String value){
        selectedBand = value;
    }

    public static String getSelectedBand(){
        return selectedBand;
    }

    public ArrayList<String> getBandNames(){


        ArrayList<String> bandNames = ParseBandCSV();


        Collections.sort(bandNames);

        ArrayList<String> filteredBandNames = new ArrayList<String>();

        for (String bandName: bandNames){
            String bandRank = rankStore.getRankForBand(bandName);

            staticVariables.staticVariablesInitialize();
            Log.d("filtering must see", bandName + "-" + bandRank + staticVariables.filterToogle.get(staticVariables.mustSeeIcon));

            if (bandRank.equals(staticVariables.mustSeeIcon) && staticVariables.filterToogle.get(staticVariables.mustSeeIcon)){
                filteredBandNames.add(bandName);

            } else if (bandRank.equals(staticVariables.mightSeeIcon) && staticVariables.filterToogle.get(staticVariables.mightSeeIcon)){
                filteredBandNames.add(bandName);

            } else if (bandRank.equals(staticVariables.wontSeeIcon) && staticVariables.filterToogle.get(staticVariables.wontSeeIcon)){
                filteredBandNames.add(bandName);

            } else if (bandRank.equals(staticVariables.unknownIcon) && staticVariables.filterToogle.get(staticVariables.unknownIcon)){
                filteredBandNames.add(bandName);

            } else if (bandRank.equals("")  && staticVariables.filterToogle.get(staticVariables.unknownIcon)){
                filteredBandNames.add(bandName);
            }
        }

        return filteredBandNames;
    }

    public ArrayList<String> getRankedBandNames(ArrayList<String> bandNames){

        Collections.sort(bandNames);

        ArrayList<String> rankedBandNames = new ArrayList<String>();

        staticVariables.staticVariablesInitialize();

        for (String bandName: bandNames){
            String bandRank = rankStore.getRankForBand(bandName);

            if (bandRank.equals(staticVariables.mustSeeIcon) && staticVariables.filterToogle.get(staticVariables.mustSeeIcon)){
                rankedBandNames.add(bandRank + " " + bandName);

            } else if (bandRank.equals(staticVariables.mightSeeIcon) && staticVariables.filterToogle.get(staticVariables.mightSeeIcon)){
                rankedBandNames.add(bandRank + " " + bandName);

            } else if (bandRank.equals(staticVariables.wontSeeIcon) && staticVariables.filterToogle.get(staticVariables.wontSeeIcon)){
                rankedBandNames.add(bandRank + " " + bandName);

            } else if (bandRank.equals(staticVariables.unknownIcon) && staticVariables.filterToogle.get(staticVariables.unknownIcon)){
                rankedBandNames.add(bandRank + " " + bandName);

            } else if (bandRank.equals("")  && staticVariables.filterToogle.get(staticVariables.unknownIcon)){
                rankedBandNames.add(bandRank + " " + bandName);
            }
        }

        return rankedBandNames;
    }

    public static String getOfficalWebLink(String bandName){

        if (getBandDetailsData(bandName, "officalSite") != null){
            return "http://" + getBandDetailsData(bandName, "officalSite");
        } else {
            return " ";
        }
    }

    public static String getImageUrl(String bandName){
        if (getBandDetailsData(bandName, "imageUrl") != null) {
            return "http://" + getBandDetailsData(bandName, "imageUrl");
        } else {
            return " ";
        }
    }

    public static String getWikipediaWebLink(String bandName){
        if (getBandDetailsData(bandName, "wikipedia") != null) {
            return getBandDetailsData(bandName, "wikipedia");
        } else {
            return " ";
        }
    }

    public static String getYouTubeWebLink(String bandName){
        if (getBandDetailsData(bandName, "youtube") != null) {
            return getBandDetailsData(bandName, "youtube");
        } else {
            return " ";
        }
    }

    public static String getMetalArchivesWebLink(String bandName){
        if (getBandDetailsData(bandName, "metalArchives") != null) {
            return getBandDetailsData(bandName, "metalArchives");
        } else {
            return " ";
        }
    }

    private static String getBandDetailsData (String bandName, String key){

        String data = "";
        Log.d("The bandName is ", bandName);
        Log.d("Here is the full map", bandData.toString());
        Map<String, Map> detailedData = bandData.get(bandName);

        Log.d("Here is the map", detailedData.toString());

        if (detailedData != null){
            if (detailedData.get(key) != null) {
                data = String.valueOf(detailedData.get(key));
            }
        }

        return data;
    }

    public ArrayList<String> DownloadBandFile(){

        try {
            URL u = new URL(staticVariables.urlBandDownload);
            InputStream is = u.openStream();

            DataInputStream dis = new DataInputStream(is);

            byte[] buffer = new byte[1024];
            int length;

            FileOutputStream fos = new FileOutputStream(new File(Environment.getExternalStorageDirectory() + "/70kbandInfo.csv"));
            while ((length = dis.read(buffer))>0) {
                fos.write(buffer, 0, length);
            }


        } catch (MalformedURLException mue) {
            Log.e("SYNC getUpdate", "malformed url error", mue);
        } catch (IOException ioe) {
            Log.e("SYNC getUpdate", "io error", ioe);
        } catch (SecurityException se) {
            Log.e("SYNC getUpdate", "security error", se);

        } catch (Exception generalError){
            Log.e("General Exception", "Downloading bandData", generalError);
        }

        ArrayList<String> bandNames = ParseBandCSV();

        return bandNames;
    }

    public ArrayList<String> ParseBandCSV(){

        ArrayList<String> bandNames = new ArrayList<String>();

        try {
            File file = new File(Environment.getExternalStorageDirectory() + "/70kbandInfo.csv");

            BufferedReader br = new BufferedReader(new FileReader(file));
            String line;

            while ((line = br.readLine()) != null) {
                String[] RowData = line.split(",");
                Map<String, String> bandDetails = new HashMap<String,String>();
                bandDetails.put("officalSite", RowData[1]);
                bandDetails.put("imageUrl", RowData[2]);
                bandDetails.put("youtube", RowData[3]);
                bandDetails.put("metalArchives", RowData[4]);
                bandDetails.put("wikipedia", RowData[5]);

                if (!RowData[0].contains("bandName")){
                    bandData.put(RowData[0], bandDetails);
                    bandNames.add(RowData[0]);
                }

            }

        } catch (Exception e) {
            Log.e("General Exception", "Parsing bandData", e);
        }


        Log.d("Output of bandData", bandData.toString());

        return bandNames;
    }

}

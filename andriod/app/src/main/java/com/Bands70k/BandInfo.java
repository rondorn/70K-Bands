package com.Bands70k;

import android.os.Environment;
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
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

import static android.app.ActivityManager.isRunningInTestHarness;
import static com.Bands70k.staticVariables.staticVariablesInitialize;

import com.Bands70k.CombinedImageListHandler;

/**
 * Represents band information and provides methods to retrieve and manage band-related data.
 */
public class BandInfo {

    private static Map<String, Map> bandData = new HashMap<String, Map>();
    //private ArrayList<String> bandNames = new ArrayList<String>();
    private static String selectedBand;

    public static Map<String, scheduleTimeTracker> scheduleRecords;

    public Map<String,String> downloadUrls = new HashMap<String, String>();

    /**
     * Called to set up thread policy for network operations.
     */
    public void onCreate() {
        StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
        StrictMode.setThreadPolicy(policy);
    }

    /**
     * Sets the selected band name.
     * @param value The name of the selected band.
     */
    public static void setSelectedBand(String value){
        selectedBand = value;
    }

    /**
     * Gets the currently selected band name.
     * @return The name of the selected band.
     */
    public static String getSelectedBand(){
        return selectedBand;
    }
    public FileHandler70k fileHandle = new FileHandler70k();

    /**
     * Returns a list of filtered band names based on user preferences.
     * @return ArrayList of filtered band names.
     */
    public ArrayList<String> getBandNames(){


        ArrayList<String> bandNames = ParseBandCSV();

        Collections.sort(bandNames);

        ArrayList<String> filteredBandNames = new ArrayList<String>();
        staticVariables.unfilteredBandCount = 0;
        for (String bandName: bandNames){

            String bandRank = rankStore.getRankForBand(bandName);

            if (bandName.isEmpty()){
                continue;
            }

            staticVariables.unfilteredBandCount = staticVariables.unfilteredBandCount + 1;
            staticVariables.staticVariablesInitialize();
            Log.d("filtering must see", bandName + "-" + bandRank + staticVariables.preferences.getShowMust());

            if (bandRank.equals(staticVariables.mustSeeIcon) && staticVariables.preferences.getShowMust() == true){
                filteredBandNames.add(bandName);

            } else if (bandRank.equals(staticVariables.mightSeeIcon) && staticVariables.preferences.getShowMight() == true){
                filteredBandNames.add(bandName);

            } else if (bandRank.equals(staticVariables.wontSeeIcon) && staticVariables.preferences.getShowWont() == true){
                filteredBandNames.add(bandName);

            } else if (bandRank.equals(staticVariables.unknownIcon) && staticVariables.preferences.getShowUnknown() == true){
                filteredBandNames.add(bandName);

            } else if (bandRank.equals("")  && staticVariables.preferences.getShowUnknown() == true){
                filteredBandNames.add(bandName);
            }
        }

        return filteredBandNames;
    }

    /**
     * Returns a list of ranked band names based on user preferences.
     * @param bandNames List of band names to rank.
     * @return ArrayList of ranked band names.
     */
    public ArrayList<String> getRankedBandNames(ArrayList<String> bandNames){

        Collections.sort(bandNames);

        ArrayList<String> rankedBandNames = new ArrayList<String>();

        staticVariables.staticVariablesInitialize();

        for (String bandName: bandNames){
            String bandRank = rankStore.getRankForBand(bandName);

            //String backupValue = BackupDataStore.retrieveValue(staticVariables.context, bandName);
            //if (backupValue == null) {
            //    BackupDataStore.storeKeyValuePair(staticVariables.context, bandName, bandRank);
            //} else {
            //    bandRank = backupValue;
            //}

            if (bandRank.equals(staticVariables.mustSeeIcon) && staticVariables.preferences.getShowMust() == false){
                rankedBandNames.add(bandRank + " " + bandName);

            } else if (bandRank.equals(staticVariables.mightSeeIcon) && staticVariables.preferences.getShowMight() == false){
                rankedBandNames.add(bandRank + " " + bandName);

            } else if (bandRank.equals(staticVariables.wontSeeIcon) && staticVariables.preferences.getShowWont() == false){
                rankedBandNames.add(bandRank + " " + bandName);

            } else if (bandRank.equals(staticVariables.unknownIcon) && staticVariables.preferences.getShowUnknown() == false){
                rankedBandNames.add(bandRank + " " + bandName);

            } else if (bandRank.equals("")  && staticVariables.preferences.getShowUnknown() == false){
                rankedBandNames.add(bandRank + " " + bandName);
            }
        }

        return rankedBandNames;
    }

    /**
     * Gets the official website link for a band.
     * @param bandName The name of the band.
     * @return The official website URL or blank if not available.
     */
    public static String getOfficalWebLink(String bandName){

        if (getBandDetailsData(bandName, "officalSite") != null){
            return "http://" + getBandDetailsData(bandName, "officalSite");
        } else {
            return " ";
        }
    }

    /**
     * Gets the image URL for a band.
     * @param bandName The name of the band.
     * @return The image URL or blank if not available.
     */
    public static String getImageUrl(String bandName){


        if (staticVariables.imageUrlMap.containsKey(bandName) == true) {
            Log.d("ImageUrlIs2", bandName + staticVariables.imageUrlMap.get(bandName));
            return staticVariables.imageUrlMap.get(bandName);

        } else if (getBandDetailsData(bandName, "imageUrl") != null) {
            Log.d("ImageUrlIs1", bandName + "  http://" + getBandDetailsData(bandName, "imageUrl"));
            return "https://" + getBandDetailsData(bandName, "imageUrl");

        } else {
            Log.d("ImageUrlIs3", bandName + " Nothing so default");
            return " ";
        }
    }

    /**
     * Gets the Wikipedia link for a band.
     * @param bandName The name of the band.
     * @return The Wikipedia URL or blank if not available.
     */
    public static String getWikipediaWebLink(String bandName){
        if (getBandDetailsData(bandName, "wikipedia") != null) {
            return getBandDetailsData(bandName, "wikipedia");
        } else {
            return " ";
        }
    }

    /**
     * Gets the YouTube link for a band.
     * @param bandName The name of the band.
     * @return The YouTube URL or blank if not available.
     */
    public static String getYouTubeWebLink(String bandName){
        if (getBandDetailsData(bandName, "youtube") != null) {
            return getBandDetailsData(bandName, "youtube");
        } else {
            return " ";
        }
    }

    /**
     * Gets the Metal Archives link for a band.
     * @param bandName The name of the band.
     * @return The Metal Archives URL or blank if not available.
     */
    public static String getMetalArchivesWebLink(String bandName){
        if (getBandDetailsData(bandName, "metalArchives") != null) {
            return getBandDetailsData(bandName, "metalArchives");
        } else {
            return " ";
        }
    }

    /**
     * Gets the country for a band.
     * @param bandName The name of the band.
     * @return The country or blank if not available.
     */
    public static String getCountry(String bandName){
        if (getBandDetailsData(bandName, "country") != null) {
            return getBandDetailsData(bandName, "country");
        } else {
            return " ";
        }
    }

    /**
     * Gets the genre for a band.
     * @param bandName The name of the band.
     * @return The genre or blank if not available.
     */
    public static String getGenre(String bandName){
        if (getBandDetailsData(bandName, "genre") != null) {
            return getBandDetailsData(bandName, "genre");
        } else {
            return " ";
        }
    }

    /**
     * Gets the prior years for a band.
     * @param bandName The name of the band.
     * @return The prior years as a string or blank if not available.
     */
    public static String getPriorYears(String bandName){
        if (getBandDetailsData(bandName, "priorYears") != null) {
            String priorYears = getBandDetailsData(bandName, "priorYears");
            priorYears = priorYears.replaceAll(" ", ", ");
            return priorYears;

        } else {
            return " ";
        }
    }
    /**
     * Gets the note for a band.
     * @param bandName The name of the band.
     * @return The note or blank if not available.
     */
    public static String getNote(String bandName){
        if (getBandDetailsData(bandName, "note") != null) {
            return getBandDetailsData(bandName, "note");
        } else {
            return " ";
        }
    }

    /**
     * Helper method to get band details data by key.
     * @param bandName The name of the band.
     * @param key The key to look up.
     * @return The value for the key or blank if not available.
     */
    private static String getBandDetailsData (String bandName, String key){

        String data = "";
        Log.d("The bandName is ", bandName);
        //Log.d("Here is the full map", bandData.toString());
        Map<String, Map> detailedData = bandData.get(bandName);

        //Log.d("Here is the map", detailedData.toString());

        if (detailedData != null){
            if (detailedData.get(key) != null) {
                data = String.valueOf(detailedData.get(key));
            }
        }

        return data;
    }

    /**
     * Populates the downloadUrls map with URLs for artist, schedule, and description map.
     */
    public void getDownloadtUrls(){

        downloadUrls.put("artistUrl", staticVariables.artistURL);
        downloadUrls.put("scheduleUrl", staticVariables.scheduleURL);
        downloadUrls.put("descriptionMap", staticVariables.preferences.getDescriptionMapUrl());

    }

    /**
     * Downloads the band file and parses it, also downloads the schedule file.
     * @return ArrayList of band names.
     */
    public ArrayList<String> DownloadBandFile(){

        getDownloadtUrls();

        System.out.println("in DownloadBandFile " +  isRunningInTestHarness());
        if ((OnlineStatus.isOnline() == true && Looper.myLooper() != Looper.getMainLooper())
                ||  staticVariables.inUnitTests == true
                || FileHandler70k.bandInfo.exists() == false) {

            if (downloadUrls.get("artistUrl") == null){
                staticVariablesInitialize();
                getDownloadtUrls();
            }
            System.out.println("inside DownloadBandFile " + downloadUrls.get("artistUrl"));
            try {
                URL u = new URL(downloadUrls.get("artistUrl"));
                InputStream is = u.openStream();

                DataInputStream dis = new DataInputStream(is);

                byte[] buffer = new byte[1024];
                int length;

                FileOutputStream fos = new FileOutputStream(FileHandler70k.bandInfo);
                while ((length = dis.read(buffer)) > 0) {
                    fos.write(buffer, 0, length);
                }


            } catch (MalformedURLException mue) {
                Log.e("SYNC getUpdate", "malformed url error", mue);
            } catch (IOException ioe) {
                Log.e("SYNC getUpdate", "io error", ioe);
            } catch (SecurityException se) {
                Log.e("SYNC getUpdate", "security error", se);

            } catch (Exception generalError) {
                Log.e("General Exception", "Downloading bandData", generalError);
            }
        }

        ArrayList<String> bandNames = ParseBandCSV();

        scheduleInfo schedule = new scheduleInfo();
        scheduleRecords = schedule.DownloadScheduleFile(downloadUrls.get("scheduleUrl"));

        // Regenerate combined image list after schedule data is loaded
        // This ensures event images from schedule CSV are included
        CombinedImageListHandler combinedHandler = CombinedImageListHandler.getInstance();
        if (combinedHandler.needsRegeneration(this)) {
            Log.d("BandInfo", "Regenerating combined image list due to new schedule data");
            combinedHandler.generateCombinedImageList(this, new Runnable() {
                @Override
                public void run() {
                    Log.d("BandInfo", "Combined image list regenerated after schedule data load");
                }
            });
        }

        return bandNames;
    }

    /**
     * Parses the band CSV file and populates band data.
     * @return ArrayList of band names.
     */
    public ArrayList<String> ParseBandCSV(){

        ArrayList<String> bandNames = new ArrayList<String>();

        try {
            File file = FileHandler70k.bandInfo;
            if (file.exists()) {
                BufferedReader br = new BufferedReader(new FileReader(file));
                String line;

                while ((line = br.readLine()) != null) {
                    Log.d("RawBandLine", line);
                    try {
                        String[] RowData = line.split(",");
                        Map<String, String> bandDetails = new HashMap<String, String>();

                        bandDetails = addToBandDetails("officalSite", RowData, 1, bandDetails);
                        bandDetails = addToBandDetails("imageUrl", RowData, 2, bandDetails);
                        bandDetails = addToBandDetails("youtube", RowData, 3, bandDetails);
                        bandDetails = addToBandDetails("metalArchives", RowData, 4, bandDetails);
                        bandDetails = addToBandDetails("wikipedia", RowData, 5, bandDetails);

                        bandDetails = addToBandDetails("country", RowData, 6, bandDetails);
                        bandDetails = addToBandDetails("genre", RowData, 7, bandDetails);
                        bandDetails = addToBandDetails("note", RowData, 8, bandDetails);
                        bandDetails = addToBandDetails("priorYears", RowData, 9, bandDetails);
                        if (!RowData[0].contains("bandName")) {
                            bandData.put(RowData[0], bandDetails);
                            bandNames.add(RowData[0]);
                        }
                    } catch (Exception error) {
                        Log.d("error", "Encountered an unknown error" + error.getMessage());
                    }
                }
            }

        } catch (IOException e) {
            Log.e("General Exception", "Parsing bandData", e);
        }


        Log.d("Output of bandData", bandData.toString());

        return bandNames;
    }

    /**
     * Helper method to add a value to the band details map.
     * @param variable The variable name.
     * @param data The data array.
     * @param index The index in the data array.
     * @param bandDetails The band details map.
     * @return The updated band details map.
     */
    private Map<String, String> addToBandDetails(String variable, String[] data, Integer index, Map<String, String> bandDetails){

        String value = "";

        if (data.length > index){
            value = data[index];
        }

        bandDetails.put(variable, value);

        return bandDetails;
    }
}

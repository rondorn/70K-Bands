package com.Bands70k;

import android.app.PendingIntent;
import android.content.Context;
import android.os.Build;
import android.util.Log;
import android.widget.Toast;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.IOException;
import java.io.ObjectInputStream;
import java.io.ObjectOutput;
import java.io.ObjectOutputStream;
import java.io.OutputStreamWriter;
import java.io.Serializable;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static com.Bands70k.staticVariables.context;

/**
 * Handles file operations for the 70k Bands app, including reading, writing, and migrating files.
 */
public class FileHandler70k {


    public static final String directoryName = "/70kBands/";

    public static final File baseDirectory = new File(showBands.newRootDir + directoryName);

    public static final String imageDirectory = directoryName + "/cachedImages/";
    public static final File baseImageDirectory = new File(showBands.newRootDir + imageDirectory);

    public static final File bandInfo = new File(showBands.newRootDir + directoryName + "70kbandInfo.csv");
    public static final File alertData = new File(showBands.newRootDir + directoryName + "70kAlertData.csv");
    public static final File bandPrefs = new File(showBands.newRootDir+ directoryName + "70kbandPreferences.csv");
    public static final File bandRankings = new File(showBands.newRootDir + directoryName + "bandRankings.txt");
    public static final File bandRankingsBk = new File(showBands.newRootDir + directoryName + "bandRankings.bk");
    public static final File schedule = new File(showBands.newRootDir + directoryName + "70kScheduleInfo.csv");
    public static final File descriptionMapFile = new File(showBands.newRootDir + directoryName + "70kbandDescriptionMap.csv");
    // Cached copy of the pointer file contents (used for year changes without re-downloading the pointer).
    public static final File pointerCacheFile = new File(showBands.newRootDir + directoryName + "pointerCache.txt");
    public static final File showsAttendedFile = new File(showBands.newRootDir + directoryName + "showsAtteded.data");
    public static final File countryFile = new File(showBands.newRootDir + directoryName + "country.txt");

    public static final File bandListCache = new File(showBands.newRootDir + directoryName + "bandListCache.data");


    public static final File rootNoMedia = new File(showBands.newRootDir + directoryName + ".nomedia");
    public static final File mediaNoMedia = new File(showBands.newRootDir + imageDirectory + ".nomedia");

    public static final File backupFileTemp = new File(showBands.newRootDir + directoryName + "backupFileTemp.zip");
    public static final File alertStorageFile = new File(showBands.newRootDir + directoryName + "70kbandAlertStorage.data");


    /**
     * Constructor for FileHandler70k. Ensures required directories exist.
     */
    public FileHandler70k(){
        check70KDirExists();
    }



    /**
     * Checks and creates required directories and .nomedia files if they do not exist.
     */
    private void check70KDirExists(){

        if(baseDirectory.exists() && baseDirectory.isDirectory()) {
            //do notuing
        } else {
            baseDirectory.mkdirs();
        }

        if(baseDirectory.exists() && baseDirectory.isDirectory()) {
            //do notuing
        } else {
            //HelpMessageHandler.showMessage("We are SCREWED!");
        }

        if (baseImageDirectory.exists() && baseImageDirectory.isDirectory()) {
            //do nothing
        } else {
            Log.e("ImageFile", "creating " + baseImageDirectory.getAbsolutePath());
            baseImageDirectory.mkdir();
        }

        if (rootNoMedia.exists()){
            //do nothing
        } else {
            try {
                rootNoMedia.createNewFile();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }

        if (rootNoMedia.exists()){
            //do nothing
        } else {
            try {
                rootNoMedia.createNewFile();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }

        if (mediaNoMedia.exists()){
            //do nothing
        } else {
            try {
                mediaNoMedia.createNewFile();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }

    }

    /**
     * Checks if the country file exists.
     * @return True if the country file exists, false otherwise.
     */
    public static Boolean doesCountryFileExist(){

        Boolean exists = false;

        if (countryFile.exists()){
            exists = true;
        }

        return exists;
    }

    /**
     * Saves string data to a file.
     * @param data The data to save.
     * @param fileHandle The file to write to.
     */
    public static void saveData(String data, File fileHandle){

        Log.d("Save Data", data);
        try {
            FileOutputStream stream = new FileOutputStream(fileHandle);
            try {
                stream.write(data.getBytes());
            } finally {
                stream.close();
            }
        } catch (Exception error) {
            Log.e("Save Data Error", error.getMessage());
        }

    }

    /**
     * Loads string data from a file.
     * @param fileHandle The file to read from.
     * @return The loaded data as a string.
     */
    public static String loadData(File fileHandle){

        String data = "";

        try {
            BufferedReader br = new BufferedReader(new FileReader(fileHandle));
            String line;
            while ((line = br.readLine()) != null) {
                data = data + line + "\n";
            }
            br.close();
        } catch (Exception error) {
            Log.e("Save Data Error", error.getMessage());
        }

        data = data.trim();

        return data;
    }
    /**
     * Serializes and writes an object to a file.
     * @param object The object to write.
     * @param fileHandle The file to write to.
     */
    public static void writeObject (Object object, File fileHandle){

        ObjectOutput out = null;

        try {
            out = new ObjectOutputStream(new FileOutputStream(fileHandle));
            out.writeObject(object);
            out.close();

        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * Reads a serialized Map<String, String> object from a file.
     * @param fileHandle The file to read from.
     * @return The deserialized map, or an empty map if an error occurs.
     */
    public static Map<String,String> readObject(File fileHandle){
        ObjectInputStream input;
        Map<String, String> dataBundle = new HashMap<String, String>();
        try {
            input = new ObjectInputStream(new FileInputStream(fileHandle));
            dataBundle = (Map<String, String>) input.readObject();
            input.close();
        } catch (Exception error){
            error.printStackTrace();
        }

        return dataBundle;
    }

    /**
     * Reads a serialized mainListHandler object from a file.
     * @param fileHandle The file to read from.
     * @return The deserialized mainListHandler object, or a new one if an error occurs.
     */
    public static mainListHandler readmainListHandlerCache (File fileHandle){

        Log.d("loadingpopulateBandInfo", "From cached data");
        mainListHandler mainListHandle = new mainListHandler();

        try {
            FileInputStream fis = context.openFileInput(fileHandle.getAbsolutePath());
            ObjectInputStream is = new ObjectInputStream(fis);
            mainListHandle = (mainListHandler) is.readObject();
            is.close();
            fis.close();
        } catch (Exception error) {
            error.printStackTrace();
        }

        return mainListHandle;
    }

    /**
     * Reads a serialized bandListView object from a file.
     * @param fileHandle The file to read from.
     * @param context The context.
     * @param textViewResourceId The resource ID for the layout file.
     * @return The deserialized bandListView object, or a new one if an error occurs.
     */
    public static bandListView readBandListHandlerCache (File fileHandle, Context context, int textViewResourceId){

        Log.d("loadingBandInfo", "From cached data");
        bandListView adapter = new bandListView(context, textViewResourceId);

        try {
            FileInputStream fis = context.openFileInput(fileHandle.getAbsolutePath());
            ObjectInputStream is = new ObjectInputStream(fis);
            adapter = (bandListView) is.readObject();
            is.close();
            fis.close();
        } catch (Exception error) {
            error.printStackTrace();
        }

        return adapter;
    }

}

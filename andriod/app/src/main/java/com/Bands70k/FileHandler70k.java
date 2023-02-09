package com.Bands70k;

import android.app.PendingIntent;
import android.content.Context;
import android.os.Build;
import android.os.Environment;
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
 * Created by rdorn on 6/5/16.
 */
public class FileHandler70k {


    public static final String directoryName = "/70kBands/";
    public static final String oldDirectoryName = "/.70kBands/";


    public static final String oldRootDir = Environment.getExternalStorageDirectory().toString();

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
    public static final File showsAttendedFile = new File(showBands.newRootDir + directoryName + "showsAtteded.data");
    public static final File countryFile = new File(showBands.newRootDir + directoryName + "country.txt");

    public static final File bandListCache = new File(showBands.newRootDir + directoryName + "bandListCache.data");

    public static final File oldBandRankings = new File(oldRootDir + oldDirectoryName + "bandRankings.txt");

    public static final File rootNoMedia = new File(showBands.newRootDir + directoryName + ".nomedia");
    public static final File mediaNoMedia = new File(showBands.newRootDir + imageDirectory + ".nomedia");

    public static final File backupFileTemp = new File(showBands.newRootDir + directoryName + "backupFileTemp.zip");
    public static final File alertStorageFile = new File(showBands.newRootDir + directoryName + "70kbandAlertStorage.data");


    public FileHandler70k(){
        check70KDirExists();
        this.moveOldFiles();
    }

    private static void moveOldFiles(){

        final File oldAlertData = new File(Environment.getExternalStorageDirectory() + "/70kAlertData.csv");
        final File oldAlertFlag = new File(Environment.getExternalStorageDirectory() + "/70kAlertFlag.csv");
        final File oldBandInfo = new File(Environment.getExternalStorageDirectory() + "/70kbandInfo.csv");
        final File oldBandPrefs = new File(Environment.getExternalStorageDirectory() + "/70kbandPreferences.csv");
        final File oldbandRankings = new File(Environment.getExternalStorageDirectory() + "/bandRankings.txt");
        final File oldbandRankingsBk = new File(Environment.getExternalStorageDirectory() + "/bandRankings.bk");
        final File oldSchedule = new File(Environment.getExternalStorageDirectory() + "/70kScheduleInfo.csv");

        if (oldAlertData.exists()){
            oldAlertData.renameTo(alertData);
        }
        if (oldAlertFlag.exists()){
            oldAlertFlag.delete();
        }
        if (oldBandInfo.exists()){
            oldBandInfo.renameTo(bandInfo);
        }
        if (oldBandPrefs.exists()){
            oldBandPrefs.renameTo(bandPrefs);
        }
        if (oldbandRankings.exists()){
            oldbandRankings.renameTo(bandRankings);
        }
        if (oldbandRankingsBk.exists()){
            oldbandRankingsBk.renameTo(bandRankingsBk);
        }
        if (oldSchedule.exists()){
            oldSchedule.renameTo(schedule);
        }

        if (oldBandRankings.exists()){
            if (bandRankings.exists()){
                bandRankings.delete();
            }
            oldBandRankings.renameTo(bandRankings);
        }

    }


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

    public static Boolean doesCountryFileExist(){

        Boolean exists = false;

        if (countryFile.exists()){
            exists = true;
        }

        return exists;
    }

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

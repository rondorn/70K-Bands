package com.Bands70k;

import android.os.Environment;
import android.util.Log;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStreamWriter;

/**
 * Created by rdorn on 6/5/16.
 */
public class FileHandler70k {

    private final File baseDirectory = new File(Environment.getExternalStorageDirectory() + "/70kBands");
    public static final File alertData = new File(Environment.getExternalStorageDirectory() + "/70kBands/70kAlertData.csv");
    public static final File bandInfo = new File(Environment.getExternalStorageDirectory() + "/70kBands/70kbandInfo.csv");
    public static final File bandPrefs = new File(Environment.getExternalStorageDirectory() + "/70kBands/70kbandPreferences.csv");
    public static final File bandRankings = new File(Environment.getExternalStorageDirectory() + "/70kBands/bandRankings.txt");
    public static final File bandRankingsBk = new File(Environment.getExternalStorageDirectory() + "/70kBands/bandRankings.bk");
    public static final File schedule = new File(Environment.getExternalStorageDirectory() + "/70kBands/70kScheduleInfo.csv");
    public static final File descriptionMapFile = new File(Environment.getExternalStorageDirectory() + "/70kBands/70kbandDescriptionMap.csv");


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
    }

    private void check70KDirExists(){

        if(baseDirectory.exists() && baseDirectory.isDirectory()) {
            //do notuing
        } else {
            baseDirectory.mkdirs();
        }
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

}

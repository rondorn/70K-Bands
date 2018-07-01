package com.Bands70k;


import android.os.Environment;
import android.util.Log;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.HashMap;
import java.util.Map;

/**
 * Created by rdorn on 7/29/15.
 */
public class rankStore {

    private static Map<String, String> bandRankings = new HashMap<String, String>();
    private static File bandRankingsFile = FileHandler70k.bandRankings;
    private static File bandRankingsFileBackup = FileHandler70k.bandRankingsBk;

    public static String getRankForBand (String bandName){

        String icon;
        if (bandRankings.get(bandName) == null){
            icon = "";
        } else {
            Log.d("Returning rank of ", bandRankings.get(bandName));
            icon = staticVariables.getRankIcon(bandRankings.get(bandName));
        }

        return icon;
    }

    public static Map<String, String> getBandRankings (){

        if (bandRankings.isEmpty() == true){
            loadBandRankingFromFile();
        }

        return bandRankings;

    }

    public static void saveBandRanking (String bandName, String ranking){
        Log.d("Adding a band ranking", bandName + "-" + ranking);
        bandRankings.put(bandName, ranking);

        saveBandRankingToFile();
    }

    public static void saveBandRankingToFile(){

        String rankingDataString = "";

        if (bandRankings.size() == 0){
            return;
        }

        for (Map.Entry<String,String> entry : bandRankings.entrySet()) {
            String band = entry.getKey();
            String ranking = entry.getValue();
            rankingDataString += band + ':' + ranking + "\n";
        }

        FileOutputStream stream;

        try {
            stream = new FileOutputStream(bandRankingsFile);
            stream.write(rankingDataString.getBytes());
            stream.close();

            stream = new FileOutputStream(bandRankingsFileBackup);
            stream.write(rankingDataString.getBytes());
            stream.close();

        } catch (Exception error) {
            Log.e("writingBandRankings", error.getMessage());
        }

        Log.d("writingBandRankings", rankingDataString);
    }

    public static void loadBandRankingFromFileBackup(){
        try {

            BufferedReader br = new BufferedReader(new FileReader(bandRankingsFileBackup));
            String line;

            while ((line = br.readLine()) != null) {
                String[] RowData = line.split(":");
                Log.d("loading band from file", RowData[0] + ":" + RowData[1]);
                bandRankings.put(RowData[0], RowData[1]);
            }

            saveBandRankingToFile();

        } catch (Exception error) {
            Log.e("writingBandRankings", "backupFile " + error.getMessage());
        }

    }

    public static void loadBandRankingFromFile(){

        try {

            BufferedReader br = new BufferedReader(new FileReader(bandRankingsFile));
            String line;

            while ((line = br.readLine()) != null) {
                String[] RowData = line.split(":");
                Log.d("loading band from file", RowData[0] + ":" + RowData[1]);
                bandRankings.put(RowData[0], RowData[1]);
            }

            if (bandRankings == null) {
                loadBandRankingFromFileBackup();

            } else if (bandRankings.size() == 0){
                loadBandRankingFromFileBackup();
            }

        } catch (Exception error) {

            Log.e("writingBandRankings", error.getMessage());
            loadBandRankingFromFileBackup();

        }
    }
}

package com.Bands70k;


import android.os.Environment;
import android.util.Log;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.util.HashMap;
import java.util.Map;

/**
 * Created by rdorn on 7/29/15.
 */
public class rankStore {

    private static Map<String, String> bandRankings = new HashMap<String, String>();
    private static File bandRankingsFile = new File(Environment.getExternalStorageDirectory() + "/bandRankings.txt");

    public static String getRankForBand (String bandName){
        if (bandRankings.get(bandName) == null){
            return "";
        } else {
            Log.d("Returning rank of ", bandRankings.get(bandName));
            return bandRankings.get(bandName);
        }
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

        } catch (Exception e) {
            Log.e("Ran into error writing band rankings", e.getMessage());
        }

        Log.d("Here is the ranking string", rankingDataString);
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
        } catch (Exception e) {

           Log.e("Ran into error loading band rankings", e.getMessage());

        }
    }
}

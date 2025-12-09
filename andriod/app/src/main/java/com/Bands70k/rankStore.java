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
 * 
 * PROFILE-AWARE: This class now supports multiple profiles
 * - Default profile uses: 70kBands/bandRankings.txt
 * - Other profiles use: profiles/{profileId}/bandRankings.txt
 */
public class rankStore {

    private static Map<String, String> bandRankings = new HashMap<String, String>();
    private static File bandRankingsFile = FileHandler70k.bandRankings;
    private static File bandRankingsFileBackup = FileHandler70k.bandRankingsBk;
    private static String currentLoadedProfile = null;  // Track which profile is currently loaded

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

    public static Integer getRankImageForBand (String bandName){

        Integer imageId = R.drawable.icon_empty;

        String ranking = bandRankings.get(bandName);

        Log.d("ReturningRankOf ", "Returning Rank Of " + ranking + " for " + bandName);

        if (ranking == null){
            imageId = R.drawable.icon_empty;
        } else {

            if (ranking.equals(staticVariables.mustSeeIcon)) {
                imageId = staticVariables.graphicMustSee;

            } else if (ranking.equals(staticVariables.mightSeeIcon)){
                imageId = staticVariables.graphicMightSee;

            } else if (ranking.equals(staticVariables.wontSeeIcon)){
                imageId = staticVariables.graphicWontSee;

            } else {
                imageId = R.drawable.icon_empty;
            }
        }

        Log.d("ReturningRankOf ", "Returning Rank Image of " + imageId + " for " + bandName);
        return imageId;
    }

    /**
     * Gets the correct file paths based on active profile
     */
    private static File[] getFilesForActiveProfile() {
        String activeProfile = SharedPreferencesManager.getInstance().getActivePreferenceSource();
        
        if ("Default".equals(activeProfile)) {
            // Use standard files for Default profile
            return new File[]{FileHandler70k.bandRankings, FileHandler70k.bandRankingsBk};
        } else {
            // Use profile-specific files
            File profileDir = new File(Bands70k.getAppContext().getFilesDir(), "profiles/" + activeProfile);
            File prioritiesFile = new File(profileDir, "bandRankings.txt");
            File prioritiesBackup = new File(profileDir, "bandRankings.bk");
            return new File[]{prioritiesFile, prioritiesBackup};
        }
    }
    
    /**
     * Reloads data from the active profile
     * Called when user switches profiles
     */
    public static void reloadForActiveProfile() {
        String activeProfile = SharedPreferencesManager.getInstance().getActivePreferenceSource();
        Log.d("rankStore", "🔄 [PROFILE_RELOAD] Reloading rankings for profile: " + activeProfile);
        
        // Clear current data
        bandRankings.clear();
        currentLoadedProfile = null;
        
        // Reload from correct profile
        loadBandRankingFromFile();
    }

    public static Map<String, String> getBandRankings (){
        String activeProfile = SharedPreferencesManager.getInstance().getActivePreferenceSource();
        
        // Reload if profile changed or not loaded yet
        if (bandRankings.isEmpty() || !activeProfile.equals(currentLoadedProfile)){
            Log.d("rankStore", "🔄 [PROFILE_CHECK] Profile changed or not loaded. Current: " + currentLoadedProfile + ", Active: " + activeProfile);
            reloadForActiveProfile();
        }

        return bandRankings;

    }

    public static void saveBandRanking (String bandName, String ranking){
        Log.d("Adding a band ranking", bandName + "-" + ranking);
        bandRankings.put(bandName, ranking);

        saveBandRankingToFile();
    }

    public static void saveBandRankingToFile(){
        String activeProfile = SharedPreferencesManager.getInstance().getActivePreferenceSource();

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
        
        // Get correct files for active profile
        File[] files = getFilesForActiveProfile();
        File mainFile = files[0];
        File backupFile = files[1];
        
        // Ensure directory exists for profile-specific files
        File parentDir = mainFile.getParentFile();
        if (parentDir != null && !parentDir.exists()) {
            parentDir.mkdirs();
        }

        try {
            stream = new FileOutputStream(mainFile);
            stream.write(rankingDataString.getBytes());
            stream.close();

            stream = new FileOutputStream(backupFile);
            stream.write(rankingDataString.getBytes());
            stream.close();
            
            Log.d("writingBandRankings", "💾 [PROFILE_SAVE] Saved to profile '" + activeProfile + "': " + mainFile.getPath());

        } catch (Exception error) {
            Log.e("writingBandRankings", error.getMessage());
        }

        Log.d("writingBandRankings", rankingDataString);
    }

    public static void loadBandRankingFromFileBackup(){
        String activeProfile = SharedPreferencesManager.getInstance().getActivePreferenceSource();
        File[] files = getFilesForActiveProfile();
        File backupFile = files[1];
        
        try {
            if (!backupFile.exists()) {
                Log.d("rankStore", "📂 [PROFILE_LOAD] Backup file doesn't exist for profile '" + activeProfile + "', skipping");
                return;
            }

            BufferedReader br = new BufferedReader(new FileReader(backupFile));
            String line;

            while ((line = br.readLine()) != null) {
                String[] RowData = line.split(":");
                Log.d("loading band from file", RowData[0] + ":" + RowData[1]);
                bandRankings.put(RowData[0], RowData[1]);
            }
            br.close();

            saveBandRankingToFile();

        } catch (Exception error) {
            Log.e("writingBandRankings", "backupFile " + error.getMessage());
        }

    }

    public static void loadBandRankingFromFile(){
        String activeProfile = SharedPreferencesManager.getInstance().getActivePreferenceSource();
        File[] files = getFilesForActiveProfile();
        File mainFile = files[0];
        
        Log.d("rankStore", "📂 [PROFILE_LOAD] Loading rankings for profile '" + activeProfile + "' from: " + mainFile.getPath());

        try {
            if (!mainFile.exists()) {
                Log.d("rankStore", "📂 [PROFILE_LOAD] File doesn't exist for profile '" + activeProfile + "', starting with empty rankings");
                currentLoadedProfile = activeProfile;
                return;
            }

            BufferedReader br = new BufferedReader(new FileReader(mainFile));
            String line;

            while ((line = br.readLine()) != null) {
                String[] RowData = line.split(":");
                if (RowData.length >= 2) {
                    Log.d("loading band from file", RowData[0] + ":" + RowData[1]);
                    bandRankings.put(RowData[0], RowData[1]);
                }
            }
            br.close();
            
            currentLoadedProfile = activeProfile;
            Log.d("rankStore", "✅ [PROFILE_LOAD] Loaded " + bandRankings.size() + " rankings for profile '" + activeProfile + "'");

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

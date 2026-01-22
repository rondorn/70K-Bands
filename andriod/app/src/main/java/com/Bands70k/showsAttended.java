package com.Bands70k;

import android.util.Log;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.ResourceBundle;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * PROFILE-AWARE: This class now supports multiple profiles
 * - Default profile uses: 70kBands/showsAttended.data
 * - Other profiles use: profiles/{profileId}/showsAttended.data
 */
public class showsAttended {

    private static final String TAG = "showsAttended";

    private volatile Map<String,String> showsAttendedHash = new HashMap<String,String>();
    private volatile String currentLoadedProfile = null;  // Track which profile is currently loaded

    private final AtomicBoolean loadScheduled = new AtomicBoolean(false);
    private final AtomicBoolean saveScheduled = new AtomicBoolean(false);
    private final AtomicBoolean migrationScheduled = new AtomicBoolean(false);

    public showsAttended(){
        // CRITICAL: Never block the UI thread during startup.
        // Loading/parsing/migrating is done asynchronously.
        showsAttendedHash = new HashMap<String,String>();
        scheduleLoadForActiveProfile();
    }
    
    /**
     * Gets the correct file path based on active profile
     */
    private File getFileForActiveProfile() {
        String activeProfile = SharedPreferencesManager.getInstance().getActivePreferenceSource();
        
        if ("Default".equals(activeProfile)) {
            // Use a consistent file name going forward, but support legacy typo for existing users.
            File correct = new File(showBands.newRootDir + FileHandler70k.directoryName + "showsAttended.data");
            File legacyTypo = FileHandler70k.showsAttendedFile; // "showsAtteded.data"

            if (correct.exists()) {
                return correct;
            }
            if (legacyTypo.exists()) {
                return legacyTypo;
            }
            // Default to the corrected file name for new writes.
            return correct;
        } else {
            // Use profile-specific file
            File profileDir = new File(Bands70k.getAppContext().getFilesDir(), "profiles/" + activeProfile);
            return new File(profileDir, "showsAttended.data");
        }
    }
    
    /**
     * Reloads data from the active profile
     * Called when user switches profiles
     */
    public void reloadForActiveProfile() {
        String activeProfile = SharedPreferencesManager.getInstance().getActivePreferenceSource();
        
        // Clear current data
        showsAttendedHash.clear();
        currentLoadedProfile = null;
        
        // Reload from correct profile (async)
        loadScheduled.set(false);
        scheduleLoadForActiveProfile();
    }

    public Map<String,String> getShowsAttended(){
        String activeProfile = SharedPreferencesManager.getInstance().getActivePreferenceSource();
        
        // Reload if profile changed
        if (!activeProfile.equals(currentLoadedProfile)) {
            reloadForActiveProfile();
        }
        
        return showsAttendedHash;
    }

    public void saveShowsAttended(Map<String,String> showsAttendedHash){
        final String activeProfile = SharedPreferencesManager.getInstance().getActivePreferenceSource();

        if (showsAttendedHash == null) {
            return;
        }

        // Snapshot to avoid concurrent modification while writing.
        final Map<String,String> snapshot = new HashMap<String,String>(showsAttendedHash);

        // Avoid hammering the file I/O thread with many rapid saves.
        if (!saveScheduled.compareAndSet(false, true)) {
            return;
        }

        ThreadManager.getInstance().executeFile(() -> {
            try {
                File fileToSave = getFileForActiveProfile();

                // Ensure directory exists for profile-specific files
                File parentDir = fileToSave.getParentFile();
                if (parentDir != null && !parentDir.exists()) {
                    //noinspection ResultOfMethodCallIgnored
                    parentDir.mkdirs();
                }

                // Migrate legacy typo file to corrected name on successful save for Default profile.
                if ("Default".equals(activeProfile)) {
                    File correct = new File(showBands.newRootDir + FileHandler70k.directoryName + "showsAttended.data");
                    File legacyTypo = FileHandler70k.showsAttendedFile;
                    if (!correct.equals(fileToSave) && legacyTypo.exists() && !correct.exists()) {
                        // Best-effort copy; keep the original as backup.
                        copyFile(legacyTypo, correct);
                        fileToSave = correct; // local to this background task
                    }
                }

                FileOutputStream file = new FileOutputStream(fileToSave);
                ObjectOutputStream out = new ObjectOutputStream(file);
                out.writeObject(snapshot);
                out.close();
                file.close();
            } catch (Exception error) {
                Log.e(TAG, "Unable to save attended tracking data: " + error.getMessage());
            } finally {
                saveScheduled.set(false);
            }
        });
    }

    public Map<String,String>  loadShowsAttended() {
        // Kept for API compatibility. This method must not block the UI thread in practice;
        // it is called from scheduleLoadForActiveProfile() on the file executor.
        String activeProfile = SharedPreferencesManager.getInstance().getActivePreferenceSource();
        return loadShowsAttendedForProfile(activeProfile);
    }

    private Map<String,String> loadShowsAttendedForProfile(String profileKey) {
        File fileToLoad = getFileForActiveProfile();
        Map<String, String> loaded = new HashMap<String, String>();

        try {
            if (!fileToLoad.exists()) {
                currentLoadedProfile = profileKey;
                return loaded;
            }

            FileInputStream file = new FileInputStream(fileToLoad);
            ObjectInputStream in = new ObjectInputStream(file);
            // Method for deserialization of object
            //noinspection unchecked
            loaded = (Map<String, String>) in.readObject();
            in.close();
            file.close();

            currentLoadedProfile = profileKey;
        } catch (Exception error) {
            // Defensive: if the file is corrupted or incompatible, back it up so we don't lose it.
            try {
                File backup = new File(fileToLoad.getParentFile(),
                        fileToLoad.getName() + ".corrupt." + System.currentTimeMillis());
                copyFile(fileToLoad, backup);
            } catch (Exception ignored) {
            }
            Log.e(TAG, "Unable to load attended tracking data: " + error.getMessage());
            StartupTracker.markError(Bands70k.getAppContext(), TAG, "load failed: " + error.getClass().getSimpleName() + " " + error.getMessage());
            currentLoadedProfile = profileKey;
            return new HashMap<String, String>();
        }

        // Schedule legacy-key migration in the background (never on UI thread).
        // This is safe because it is triggered from the file executor.
        if (loaded != null && !loaded.isEmpty()) {
            scheduleLegacyKeyMigrationIfNeeded(profileKey, loaded);
        }

        return loaded != null ? loaded : new HashMap<String, String>();
    }

    private void scheduleLoadForActiveProfile() {
        if (!loadScheduled.compareAndSet(false, true)) {
            return;
        }
        ThreadManager.getInstance().executeFile(() -> {
            try {
                String activeProfile = SharedPreferencesManager.getInstance().getActivePreferenceSource();
                Map<String, String> loaded = loadShowsAttendedForProfile(activeProfile);
                if (loaded == null) {
                    loaded = new HashMap<String, String>();
                }
                showsAttendedHash = loaded;
                currentLoadedProfile = activeProfile;
            } finally {
                loadScheduled.set(false);
            }
        });
    }

    /**
     * Legacy migration: older installs stored keys without eventYear (5 segments).
     * We migrate them to the 6-segment format by appending the current eventYear.
     *
     * IMPORTANT:
     * - Runs only on the file executor (cannot block the splash).
     * - Backs up the file before rewriting.
     * - Never depends on BandInfo/network; purely structural migration.
     */
    private void scheduleLegacyKeyMigrationIfNeeded(String profileKey, Map<String, String> loaded) {
        if (!migrationScheduled.compareAndSet(false, true)) {
            return;
        }
        ThreadManager.getInstance().executeFile(() -> {
            try {
                // Only migrate if the active profile matches what we loaded.
                String activeProfile = SharedPreferencesManager.getInstance().getActivePreferenceSource();
                if (profileKey == null || !profileKey.equals(activeProfile)) {
                    return;
                }

                if (staticVariables.preferences != null && staticVariables.preferences.getUseLastYearsData()) {
                    // Old behavior: do not add current year keys when "use last year's data" is enabled.
                    return;
                }

                // Ensure eventYear is available (may do a small amount of work, but we're on background thread).
                if (staticVariables.eventYear == 0) {
                    staticVariables.ensureEventYearIsSet();
                }
                int year = staticVariables.eventYear;
                if (year == 0) {
                    return;
                }

                boolean needsMigration = false;
                for (String key : loaded.keySet()) {
                    if (key != null && key.split(":").length == 5) {
                        needsMigration = true;
                        break;
                    }
                }
                if (!needsMigration) {
                    return;
                }

                File fileToLoad = getFileForActiveProfile();
                // Backup first (non-destructive).
                try {
                    File backup = new File(fileToLoad.getParentFile(),
                            fileToLoad.getName() + ".pre_migration." + System.currentTimeMillis());
                    copyFile(fileToLoad, backup);
                } catch (Exception e) {
                    StartupTracker.markError(Bands70k.getAppContext(), TAG, "backup before migration failed: " + e.getMessage());
                }

                Map<String, String> migrated = new HashMap<String, String>(loaded.size());
                for (Map.Entry<String, String> entry : loaded.entrySet()) {
                    String key = entry.getKey();
                    String value = entry.getValue();
                    if (key == null) {
                        continue;
                    }
                    String[] parts = key.split(":");
                    if (parts.length == 5) {
                        String newKey = key + ":" + year;
                        migrated.put(newKey, value);
                    } else {
                        migrated.put(key, value);
                    }
                }

                // Write migrated data to disk (synchronously here since we're already on file executor).
                writeMapToFile(fileToLoad, migrated);

                // Update in-memory state if we're still on this profile.
                showsAttendedHash = migrated;
                currentLoadedProfile = profileKey;

                StartupTracker.markStep(Bands70k.getAppContext(), "showsAttended:migratedLegacyKeys");
            } catch (Exception e) {
                StartupTracker.markError(Bands70k.getAppContext(), TAG, "migration failed: " + e.getClass().getSimpleName() + " " + e.getMessage());
            } finally {
                migrationScheduled.set(false);
            }
        });
    }

    private static void writeMapToFile(File fileToSave, Map<String, String> data) throws Exception {
        if (fileToSave == null) return;
        File parentDir = fileToSave.getParentFile();
        if (parentDir != null && !parentDir.exists()) {
            //noinspection ResultOfMethodCallIgnored
            parentDir.mkdirs();
        }
        FileOutputStream file = new FileOutputStream(fileToSave);
        ObjectOutputStream out = new ObjectOutputStream(file);
        out.writeObject(data != null ? data : new HashMap<String, String>());
        out.close();
        file.close();
    }

    private static void copyFile(File src, File dst) throws Exception {
        FileInputStream in = new FileInputStream(src);
        FileOutputStream out = new FileOutputStream(dst);
        byte[] buf = new byte[8192];
        int r;
        while ((r = in.read(buf)) > 0) {
            out.write(buf, 0, r);
        }
        in.close();
        out.close();
    }

    // NOTE: convertToNewFormat() intentionally removed from startup load path.
    // If we need to re-introduce migration, it should be done asynchronously after eventYear is known,
    // with a safe "copy keys first" approach to avoid concurrent modification.

    /*
    private Map<String,String> convertToNewFormat(Map<String,String> showsAttendedArray) {

        List<String> unuiqueSpecial = new ArrayList<String>();

        BandInfo bandInfoNames = new BandInfo();
        List<String> bandNames = bandInfoNames.getBandNames();

        if (showsAttendedArray.size() > 0) {

            for (String index : showsAttendedArray.keySet()) {

                String[] indexArray = index.split(":");

                String bandName = indexArray[0];
                String eventType = indexArray[4];
                Log.d("loadShowAttended", "index = " + index);
                if (indexArray.length == 5 && staticVariables.preferences.getUseLastYearsData() == false) {
                    Integer useEventYear = staticVariables.eventYear;


                    if (bandNames.contains(bandName) == false) {
                        if ((eventType == staticVariables.specialEvent || eventType == staticVariables.unofficalEvent) && unuiqueSpecial.contains(bandName) == false) {
                            unuiqueSpecial.add(bandName);
                        }
                    }
                    String newIndex = index + ":" + String.valueOf(useEventYear);
                    Log.d("loadShowAttended", "using new index of " + newIndex);
                    showsAttendedArray.put(newIndex, showsAttendedArray.get(index));
                    showsAttendedArray.remove(index);
                }
            }
        }

        saveShowsAttended(showsAttendedArray);
        return showsAttendedArray;
    }
    */

    public String addShowsAttended (String index, String attendedStatus) {

        index = index.replaceAll("\\.", "");
        String value = "";

        String[] valueTypes = index.split(":");
        String eventType = valueTypes[4];

        Log.d("showAttended", "adding show data" + index + "-" + eventType);
        Log.d("showAttended", showsAttendedHash.toString());

        if (attendedStatus.isEmpty() == true) {
            if (showsAttendedHash.containsKey(index) == false || showsAttendedHash.get(index).equals(staticVariables.sawNoneStatus)) {

                value = staticVariables.sawAllStatus;
                Log.d("showAttended", "Setting value to all for index " + index);
            } else if (showsAttendedHash.get(index).equals(staticVariables.sawAllStatus) && eventType.equals(staticVariables.show)) {
                value = staticVariables.sawSomeStatus;
                Log.d("showAttended", "Setting value to some for index " + index);
            } else if (showsAttendedHash.get(index).equals(staticVariables.sawSomeStatus)) {
                value = staticVariables.sawNoneStatus;
                Log.d("showAttended", "Setting value to none 1 for index " + index);
            } else {
                value = staticVariables.sawNoneStatus;
                Log.d("showAttended", "Setting value to none 2 for index " + index);
            }
        } else {
            value = attendedStatus;
        }
        this.showsAttendedHash.put(index,value);

        this.saveShowsAttended(showsAttendedHash);

        return value;
    }

    public String addShowsAttended (String band, String location, String startTime, String eventType) {

        // Ensure eventYear is set before using it
        if (staticVariables.eventYear == 0) {
            staticVariables.ensureEventYearIsSet();
        }
        String eventYear = String.valueOf(staticVariables.eventYear);

        String index = band + ":" + location + ":" + startTime + ":" + eventType + ":" + eventYear;
        String value = addShowsAttended(index, "");

        return value;
    }

    public String addShowsAttended (String band, String location, String startTime, String eventType, String attendedStatus) {

        // Ensure eventYear is set before using it
        if (staticVariables.eventYear == 0) {
            staticVariables.ensureEventYearIsSet();
        }
        String eventYear = String.valueOf(staticVariables.eventYear);

        String index = band + ":" + location + ":" + startTime + ":" + eventType + ":" + eventYear;
        String value = addShowsAttended(index, attendedStatus);

        return value;
    }

    public String getShowAttendedIcon(String index){

        Log.d("showAttended", "getting icon for index " + index);

        String[] valueTypes = index.split(":");

        String bandName = valueTypes[0];
        String location = valueTypes[1];
        String startTime = valueTypes[2] + ":" + valueTypes[3];
        String eventType = valueTypes[4];
        String eventyear = valueTypes[5];

        return getShowAttendedIcon(bandName,location,startTime,eventType, eventyear);
    }

    public String getShowAttendedColor(String index){

        String[] valueTypes = index.split(":");

        String bandName = valueTypes[0];
        String location = valueTypes[1];
        String startTime = valueTypes[2] + ":" + valueTypes[3];
        String eventType = valueTypes[4];
        String eventYear = valueTypes[5];

        return getShowAttendedColor(bandName, location, startTime, eventType, eventYear);
    }
    public String getShowAttendedColor(String band, String location, String startTime, String eventType, String eventYear) {

        String color = "";

        String value = getShowAttendedStatus(band, location, startTime, eventType, eventYear);

        if (value.equals(staticVariables.sawAllStatus)){
            color = staticVariables.sawNoneColor;

        } else if (value.equals(staticVariables.sawSomeStatus)){
            color = staticVariables.sawNoneColor;

        } else if (value.equals(staticVariables.sawNoneStatus)){
            color = staticVariables.sawNoneColor;
        }

        //Log.d("showAttended", "value is  " + band + " " + value + " icon is " + color);

        return color;
    }


    public String getShowAttendedIcon(String band, String location, String startTime, String eventType, String eventYear) {

        Log.d("showAttended", "getting icon for index " + band + "-" + location + "-" + startTime + "-" + eventYear);
        String icon = "";

        String value = getShowAttendedStatus(band,location,startTime,eventType, eventYear);

        if (value.equals(staticVariables.sawAllStatus)){
            icon = staticVariables.sawAllIcon;

        } else if (value.equals(staticVariables.sawSomeStatus)){
            icon = staticVariables.sawSomeIcon;

        } else if (value.equals(staticVariables.sawNoneStatus)){
            icon = staticVariables.sawNoneIcon;
        }

        Log.d("showAttended", "getting icon for index " + band + "-" + location + "-" + startTime + "-" + eventYear + " got - " + icon);

        return icon;
    }

    public String getShowAttendedStatus(String index) {

        String value = "";

        if (showsAttendedHash.containsKey(index) == false) {
            value = staticVariables.sawNoneStatus;

        } else if (showsAttendedHash.get(index).equals(staticVariables.sawAllStatus)){
            value = staticVariables.sawAllStatus;

        } else if (showsAttendedHash.get(index).equals(staticVariables.sawSomeStatus)){
            value = staticVariables.sawSomeStatus;

        } else {
            value = staticVariables.sawNoneStatus;

        }

        return value;
    }

    public String getShowAttendedStatus(String band, String location, String startTime, String eventType, String eventYear) {

        String index = band + ":" + location + ":" + startTime + ":" + eventType + ":" + eventYear;

        return getShowAttendedStatus(index);

    }

    public String setShowsAttendedStatus(String status){

        String message = "";

        if (status.equals(staticVariables.sawAllStatus)){
            message = staticVariables.context.getResources().getString(R.string.AllOfEvent);

        } else if (status.equals(staticVariables.sawSomeStatus)){
            message = staticVariables.context.getResources().getString(R.string.PartOfEvent);

        } else {
            message = staticVariables.context.getResources().getString(R.string.NoneOfEvent);

        }

        return message;
    }

}

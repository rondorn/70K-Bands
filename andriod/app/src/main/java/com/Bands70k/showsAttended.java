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
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * PROFILE-AWARE: This class now supports multiple profiles
 * - Default profile uses: 70kBands/showsAttended.data
 * - Other profiles use: profiles/{profileId}/showsAttended.data
 */
public class showsAttended {

    private static final String TAG = "showsAttended";

    /** Cache collision sets per event year; invalidate when schedule data is rebuilt. */
    private static final ConcurrentHashMap<Integer, Set<String>> COLLIDING_BASE_KEYS_BY_YEAR = new ConcurrentHashMap<>();

    public static void invalidateAttendanceCollisionCache() {
        COLLIDING_BASE_KEYS_BY_YEAR.clear();
    }

    private Set<String> collidingBasesForYear(int year) {
        return COLLIDING_BASE_KEYS_BY_YEAR.computeIfAbsent(year, AttendanceIndexKeys::collidingBaseKeys);
    }

    /**
     * True if this attendance key belongs to {@code eventYearString} (handles {@code year__Day N} tail segment).
     */
    public static boolean attendanceIndexMatchesYear(String index, String eventYearString) {
        ParsedAttendanceKey k = parseAttendanceStorageKey(index);
        return k != null && eventYearString != null && eventYearString.equals(k.yearPlain);
    }

    private String resolveStorageIndex(String band, String location, String startTimeRawOrNorm, String eventType,
                                       String eventYearString, String scheduleDay) {
        String normalizedTime = normalizeTimeForIndex(startTimeRawOrNorm);
        String et = eventType;
        if (staticVariables.unofficalEventOld.equals(et)) {
            et = staticVariables.unofficalEvent;
        }
        int y;
        try {
            y = Integer.parseInt(eventYearString);
        } catch (NumberFormatException e) {
            return AttendanceIndexKeys.baseKey(band, location, normalizedTime, et, eventYearString);
        }
        Set<String> colliding = collidingBasesForYear(y);
        return AttendanceIndexKeys.storageKey(band, location, normalizedTime, et, eventYearString, scheduleDay, colliding);
    }

    /**
     * Public storage key for UI (details, Firebase known-set, etc.). Uses schedule DB day when collisions exist.
     */
    public String buildAttendanceStorageKey(String band, String location, String rawStartTime, String eventType,
                                            String eventYearString, String scheduleDayFromDatabase) {
        String et = eventType;
        if (staticVariables.unofficalEventOld.equals(et)) {
            et = staticVariables.unofficalEvent;
        }
        return resolveStorageIndex(band, location, rawStartTime, et, eventYearString, scheduleDayFromDatabase);
    }

    /** Parsed attendance index: band may contain {@code ':'}; last segment may be {@code year} or {@code year__day}. */
    public static final class ParsedAttendanceKey {
        public final String band;
        public final String location;
        public final String startTime;
        public final String eventType;
        public final String yearPlain;
        /** Database schedule day suffix when key is disambiguated; null for legacy base keys. */
        public final String scheduleDaySuffix;

        ParsedAttendanceKey(String band, String location, String startTime, String eventType, String yearPlain,
                            String scheduleDaySuffix) {
            this.band = band;
            this.location = location;
            this.startTime = startTime;
            this.eventType = eventType;
            this.yearPlain = yearPlain;
            this.scheduleDaySuffix = scheduleDaySuffix;
        }
    }

    public static ParsedAttendanceKey parseAttendanceStorageKey(String index) {
        if (index == null) return null;
        String[] parts = index.split(":", -1);
        if (parts.length < 6) return null;
        String last = parts[parts.length - 1];
        String yearPlain;
        String scheduleDaySuffix;
        int u = last.indexOf("__");
        if (u >= 0) {
            yearPlain = last.substring(0, u);
            scheduleDaySuffix = last.substring(u + 2);
        } else {
            yearPlain = last;
            scheduleDaySuffix = null;
        }
        String eventType = parts[parts.length - 2];
        String startTime = parts[parts.length - 4] + ":" + parts[parts.length - 3];
        String location = parts[parts.length - 5];
        StringBuilder band = new StringBuilder(parts[0]);
        for (int i = 1; i < parts.length - 5; i++) {
            band.append(":").append(parts[i]);
        }
        return new ParsedAttendanceKey(band.toString(), location, startTime, eventType, yearPlain, scheduleDaySuffix);
    }

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
        invalidateAttendanceCollisionCache();
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

    /** Number of attendance keys for the given year (any status). Used to decide if "Replace auto schedule" should be shown. */
    public int countAttendanceForYear(int year) {
        String ys = String.valueOf(year);
        int count = 0;
        for (String key : getShowsAttended().keySet()) {
            if (key != null && attendanceIndexMatchesYear(key, ys)) count++;
        }
        return count;
    }

    /** Number of entries that are attended (sawAll or sawSome) for the active profile. Used to grey out "Clear all attendance" when 0. */
    public int countAttended() {
        Map<String, String> map = getShowsAttended();
        int count = 0;
        for (String value : map.values()) {
            if (value == null) continue;
            String statusPart = value.contains(":") ? value.split(":")[0] : value;
            if (staticVariables.sawAllStatus.equals(statusPart) || staticVariables.sawSomeStatus.equals(statusPart)) {
                count++;
            }
        }
        return count;
    }

    /**
     * Set all attendance for a single year to Not Attended (sawNone). Keeps records so sync/restore does not bring data back.
     * Used when starting "Build my schedule automatically". Persists synchronously.
     */
    public void clearAttendanceForYear(int year) {
        String ys = String.valueOf(year);
        String sawNoneValue = staticVariables.sawNoneStatus + ":" + String.format("%.0f", System.currentTimeMillis() / 1000.0);
        Map<String, String> current = new HashMap<>(getShowsAttended());
        for (String key : new ArrayList<>(current.keySet())) {
            if (key != null && attendanceIndexMatchesYear(key, ys)) {
                current.put(key, sawNoneValue);
            }
        }
        showsAttendedHash = current;
        saveShowsAttendedSync(current);
    }

    /** Set all attendance data for the active profile to Not Attended (sawNone). Keeps records so sync does not bring data back.
     * Use with confirmation (e.g. preferences "Clear all attendance data"). Persists synchronously. */
    public void clearAllAttendance() {
        String sawNoneValue = staticVariables.sawNoneStatus + ":" + String.format("%.0f", System.currentTimeMillis() / 1000.0);
        Map<String, String> current = new HashMap<>(getShowsAttended());
        for (String key : new ArrayList<>(current.keySet())) {
            if (key != null) {
                current.put(key, sawNoneValue);
            }
        }
        showsAttendedHash = current;
        currentLoadedProfile = SharedPreferencesManager.getInstance().getActivePreferenceSource();
        saveShowsAttendedSync(current);
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

    /**
     * Writes the given map to disk synchronously. Used by clearAllAttendance so the cleared state
     * is persisted before return; avoids a race where an async load could repopulate from stale file.
     */
    private void saveShowsAttendedSync(Map<String, String> snapshot) {
        if (snapshot == null) return;
        try {
            String activeProfile = SharedPreferencesManager.getInstance().getActivePreferenceSource();
            File fileToSave = getFileForActiveProfile();
            File parentDir = fileToSave.getParentFile();
            if (parentDir != null && !parentDir.exists()) {
                parentDir.mkdirs();
            }
            if ("Default".equals(activeProfile)) {
                File correct = new File(showBands.newRootDir + FileHandler70k.directoryName + "showsAttended.data");
                File legacyTypo = FileHandler70k.showsAttendedFile;
                if (!correct.equals(fileToSave) && legacyTypo.exists() && !correct.exists()) {
                    copyFile(legacyTypo, correct);
                    fileToSave = correct;
                }
            }
            try (FileOutputStream file = new FileOutputStream(fileToSave);
                 ObjectOutputStream out = new ObjectOutputStream(file)) {
                out.writeObject(new HashMap<>(snapshot));
            }
        } catch (Exception error) {
            Log.e(TAG, "Unable to save attended tracking data (sync): " + error.getMessage());
        }
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

    private static String canonicalStatusFromStored(String stored) {
        if (stored == null) return staticVariables.sawNoneStatus;
        String part = stored.contains(":") ? stored.split(":", 2)[0] : stored;
        if (staticVariables.sawAllStatus.equals(part)) return staticVariables.sawAllStatus;
        if (staticVariables.sawSomeStatus.equals(part)) return staticVariables.sawSomeStatus;
        return staticVariables.sawNoneStatus;
    }

    public String addShowsAttended(String index, String attendedStatus) {
        // Do not strip periods from band names (e.g. T.H.E.M); store and lookup must use the same key.
        String value;
        ParsedAttendanceKey pk = parseAttendanceStorageKey(index);
        String eventType = pk != null ? pk.eventType : "";
        if (pk == null && index != null) {
            String[] valueTypes = index.split(":", -1);
            eventType = valueTypes.length > 1 ? valueTypes[valueTypes.length - 2] : "";
        }

        Log.d("showAttended", "adding show data" + index + "-" + eventType);
        Log.d("showAttended", showsAttendedHash.toString());

        if (attendedStatus.isEmpty()) {
            String current = showsAttendedHash.containsKey(index)
                    ? canonicalStatusFromStored(showsAttendedHash.get(index))
                    : staticVariables.sawNoneStatus;
            if (!showsAttendedHash.containsKey(index) || staticVariables.sawNoneStatus.equals(current)) {
                value = staticVariables.sawAllStatus;
                Log.d("showAttended", "Setting value to all for index " + index);
            } else if (staticVariables.sawAllStatus.equals(current) && staticVariables.show.equals(eventType)) {
                value = staticVariables.sawSomeStatus;
                Log.d("showAttended", "Setting value to some for index " + index);
            } else if (staticVariables.sawSomeStatus.equals(current)) {
                value = staticVariables.sawNoneStatus;
                Log.d("showAttended", "Setting value to none 1 for index " + index);
            } else {
                value = staticVariables.sawNoneStatus;
                Log.d("showAttended", "Setting value to none 2 for index " + index);
            }
        } else {
            value = attendedStatus;
        }
        this.showsAttendedHash.put(index, value);

        this.saveShowsAttended(showsAttendedHash);

        return value;
    }

    public String addShowsAttended(String band, String location, String startTime, String eventType) {
        return addShowsAttended(band, location, startTime, eventType, null);
    }

    public String addShowsAttended(String band, String location, String startTime, String eventType, String scheduleDay) {
        if (staticVariables.eventYear == 0) {
            staticVariables.ensureEventYearIsSet();
        }
        String eventYear = String.valueOf(staticVariables.eventYear);
        if (staticVariables.unofficalEventOld.equals(eventType)) {
            eventType = staticVariables.unofficalEvent;
        }
        String idx = resolveStorageIndex(band, location, startTime, eventType, eventYear, scheduleDay);
        return addShowsAttended(idx, "");
    }

    /** Overlap of 15 min or less is ignored (both shows can stay marked). Only clear when overlap > this. */
    private static final double SHORT_OVERLAP_THRESHOLD_SECONDS = 900.0;

    /**
     * When marking a Show as attended, clear any other Show already attended that overlaps by more than 15 min (same day).
     */
    private void clearOverlappingShowAttendance(String band, String location, String startTime, String eventType,
                                                String eventYearString, String scheduleDayFromDatabase,
                                                String currentIndex, java.util.List<EventData> allEvents) {
        if (allEvents == null) return;
        String normStart = normalizeTimeForIndex(startTime);
        java.util.List<EventData> matches = new ArrayList<>();
        for (EventData e : allEvents) {
            if (e.bandName != null && e.bandName.equals(band) && e.location != null && e.location.equals(location)
                    && e.startTime != null && normalizeTimeForIndex(e.startTime).equals(normStart) && eventTypeMatchesStatic(e.eventType, eventType)
                    && String.valueOf(e.eventYear).equals(eventYearString)) {
                matches.add(e);
            }
        }
        if (matches.isEmpty()) return;
        EventData thisEvent = null;
        if (scheduleDayFromDatabase != null && !scheduleDayFromDatabase.trim().isEmpty()) {
            for (EventData e : matches) {
                if (scheduleDayFromDatabase.equals(e.day)) {
                    thisEvent = e;
                    break;
                }
            }
        }
        if (thisEvent == null) {
            thisEvent = matches.get(0);
        }

        String thisDay = normalizedCalendarDay(thisEvent.date);
        double thisEnd = thisEvent.endTimeIndex;
        if (thisEvent.timeIndex > thisEnd) thisEnd += 86400;

        Map<String, String> attended = getShowsAttended();
        String sawNone = staticVariables.sawNoneStatus + ":" + String.format("%.0f", System.currentTimeMillis() / 1000.0);

        for (Map.Entry<String, String> entry : attended.entrySet()) {
            String index = entry.getKey();
            if (index == null || index.equals(currentIndex) || !attendanceIndexMatchesYear(index, eventYearString)) {
                continue;
            }
            String statusPart = entry.getValue();
            if (statusPart != null && statusPart.contains(":")) statusPart = statusPart.split(":")[0];
            if (!staticVariables.sawAllStatus.equals(statusPart) && !staticVariables.sawSomeStatus.equals(statusPart)) {
                continue;
            }

            ParsedAttendanceKey other = parseAttendanceStorageKey(index);
            if (other == null || !staticVariables.show.equals(other.eventType)) continue;

            EventData otherEvent = findMatchingEventData(allEvents, other);
            if (otherEvent == null) continue;
            if (!thisDay.equals(normalizedCalendarDay(otherEvent.date))) continue;

            double otherEnd = otherEvent.endTimeIndex;
            if (otherEvent.timeIndex > otherEnd) otherEnd += 86400;
            boolean overlaps = thisEvent.timeIndex < otherEnd && otherEvent.timeIndex < thisEnd;
            if (!overlaps) continue;

            double overlapStart = Math.max(thisEvent.timeIndex, otherEvent.timeIndex);
            double overlapEnd = Math.min(thisEnd, otherEnd);
            double overlapSeconds = Math.max(0, overlapEnd - overlapStart);
            if (overlapSeconds > SHORT_OVERLAP_THRESHOLD_SECONDS) {
                changeShowAttendedStatus(index, sawNone);
            }
        }
    }

    private static EventData findMatchingEventData(java.util.List<EventData> allEvents, ParsedAttendanceKey other) {
        java.util.List<EventData> cands = new ArrayList<>();
        for (EventData e : allEvents) {
            if (e.bandName != null && e.bandName.equals(other.band) && e.location != null && e.location.equals(other.location)
                    && e.startTime != null
                    && normalizeTimeForIndex(e.startTime).equals(normalizeTimeForIndex(other.startTime))
                    && eventTypeMatchesStatic(e.eventType, other.eventType)
                    && String.valueOf(e.eventYear).equals(other.yearPlain)) {
                cands.add(e);
            }
        }
        if (cands.isEmpty()) return null;
        if (other.scheduleDaySuffix != null && !other.scheduleDaySuffix.isEmpty()) {
            for (EventData e : cands) {
                if (other.scheduleDaySuffix.equals(e.day)) {
                    return e;
                }
            }
        }
        return cands.get(0);
    }

    private static boolean eventTypeMatchesStatic(String eventType, String stored) {
        if (eventType == null) eventType = "";
        if (stored == null) stored = "";
        if (eventType.equals(stored)) return true;
        return staticVariables.unofficalEventOld.equals(eventType) && staticVariables.unofficalEvent.equals(stored);
    }

    private String normalizedCalendarDay(String dateString) {
        if (dateString == null || dateString.isEmpty()) return "";
        try {
            java.text.SimpleDateFormat in = new java.text.SimpleDateFormat("M/d/yyyy", java.util.Locale.US);
            java.util.Date d = in.parse(dateString);
            if (d == null) {
                in = new java.text.SimpleDateFormat("MM/dd/yyyy", java.util.Locale.US);
                d = in.parse(dateString);
            }
            if (d != null) {
                java.text.SimpleDateFormat out = new java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US);
                return out.format(d);
            }
        } catch (Exception ignored) { }
        return dateString;
    }

    private void changeShowAttendedStatus(String index, String status) {
        showsAttendedHash.put(index, status);
        saveShowsAttended(showsAttendedHash);
    }

    /**
     * Restore attendance for a year from a backup map (e.g. from AIScheduleStorage).
     * Keys in backup are applied; keys for this year not in backup are set to sawNone.
     */
    public void restoreFromBackup(int year, Map<String, String> backup) {
        if (backup == null) return;
        String ys = String.valueOf(year);
        Map<String, String> current = new HashMap<>(getShowsAttended());
        for (Map.Entry<String, String> e : backup.entrySet()) {
            current.put(e.getKey(), e.getValue());
        }
        for (String index : new ArrayList<>(current.keySet())) {
            if (index != null && attendanceIndexMatchesYear(index, ys) && !backup.containsKey(index)) {
                current.put(index, staticVariables.sawNoneStatus + ":" + String.format("%.0f", System.currentTimeMillis() / 1000.0));
            }
        }
        showsAttendedHash = current;
        saveShowsAttended(showsAttendedHash);
    }

    /**
     * Add or update attendance with a specific status. If allEventsForYear is provided and this is a Show (sawAll/sawSome),
     * clears any other Show attendance that overlaps by more than 15 min first.
     */
    public String addShowsAttendedWithStatus(String band, String location, String startTime, String eventType,
                                             String eventYearString, String status,
                                             java.util.List<EventData> allEventsForYear) {
        return addShowsAttendedWithStatus(band, location, startTime, eventType, eventYearString, status, null, allEventsForYear);
    }

    public String addShowsAttendedWithStatus(String band, String location, String startTime, String eventType,
                                             String eventYearString, String status, String scheduleDayFromDatabase,
                                             java.util.List<EventData> allEventsForYear) {
        if (staticVariables.unofficalEventOld.equals(eventType)) eventType = staticVariables.unofficalEvent;
        String index = resolveStorageIndex(band, location, startTime, eventType, eventYearString, scheduleDayFromDatabase);
        if (allEventsForYear != null && staticVariables.show.equals(eventType)
                && (staticVariables.sawAllStatus.equals(status) || staticVariables.sawSomeStatus.equals(status))) {
            clearOverlappingShowAttendance(band, location, startTime, eventType, eventYearString, scheduleDayFromDatabase,
                    index, allEventsForYear);
        }
        return addShowsAttended(index, status);
    }

    public String getShowAttendedIcon(String index) {
        Log.d("showAttended", "getting icon for index " + index);
        ParsedAttendanceKey k = parseAttendanceStorageKey(index);
        if (k != null) {
            return getShowAttendedIcon(k.band, k.location, k.startTime, k.eventType, k.yearPlain, k.scheduleDaySuffix);
        }
        Log.w(TAG, "ATTENDANCE_INDEX_PARSE index=" + index + " (could not parse)");
        return getShowAttendedIcon("", "", "", "", "", null);
    }

    public String getShowAttendedColor(String index) {
        ParsedAttendanceKey k = parseAttendanceStorageKey(index);
        if (k != null) {
            return getShowAttendedColor(k.band, k.location, k.startTime, k.eventType, k.yearPlain, k.scheduleDaySuffix);
        }
        return getShowAttendedColor("", "", "", "", "", null);
    }

    public String getShowAttendedColor(String band, String location, String startTime, String eventType, String eventYear) {
        return getShowAttendedColor(band, location, startTime, eventType, eventYear, null);
    }

    public String getShowAttendedColor(String band, String location, String startTime, String eventType, String eventYear,
                                       String scheduleDay) {

        String color = "";

        String value = getShowAttendedStatus(band, location, startTime, eventType, eventYear, scheduleDay);

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
        return getShowAttendedIcon(band, location, startTime, eventType, eventYear, null);
    }

    public String getShowAttendedIcon(String band, String location, String startTime, String eventType, String eventYear,
                                      String scheduleDay) {

        Log.d("showAttended", "getting icon for index " + band + "-" + location + "-" + startTime + "-" + eventYear);
        String icon = "";

        String value = getShowAttendedStatus(band, location, startTime, eventType, eventYear, scheduleDay);

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
        if (index == null || !showsAttendedHash.containsKey(index)) {
            return staticVariables.sawNoneStatus;
        }
        return canonicalStatusFromStored(showsAttendedHash.get(index));
    }

    /**
     * Canonicalize time string for attendance index so "4:15" and "04:15" match.
     * Returns "HH:mm" (hour zero-padded to 2 digits) or original if not parseable.
     */
    public static String normalizeTimeForIndex(String startTime) {
        if (startTime == null || startTime.isEmpty()) return startTime;
        String t = startTime.trim();
        int colon = t.indexOf(':');
        if (colon <= 0 || colon >= t.length() - 1) return startTime;
        String hourPart = t.substring(0, colon).replaceAll("[^0-9]", "");
        String rest = t.substring(colon);
        if (hourPart.isEmpty()) return startTime;
        try {
            int h = Integer.parseInt(hourPart);
            if (h >= 0 && h <= 23) {
                return String.format("%02d", h) + rest;
            }
        } catch (NumberFormatException ignored) { }
        return startTime;
    }

    public String getShowAttendedStatus(String band, String location, String startTime, String eventType, String eventYear) {
        return getShowAttendedStatus(band, location, startTime, eventType, eventYear, null);
    }

    public String getShowAttendedStatus(String band, String location, String startTime, String eventType, String eventYear,
                                        String scheduleDayFromDatabase) {
        if (staticVariables.unofficalEventOld.equals(eventType)) {
            eventType = staticVariables.unofficalEvent;
        }
        String nt = normalizeTimeForIndex(startTime);
        String base = AttendanceIndexKeys.baseKey(band, location, nt, eventType, eventYear);
        if (scheduleDayFromDatabase != null && !scheduleDayFromDatabase.trim().isEmpty()) {
            String ext = resolveStorageIndex(band, location, nt, eventType, eventYear, scheduleDayFromDatabase.trim());
            if (showsAttendedHash.containsKey(ext)) {
                return canonicalStatusFromStored(showsAttendedHash.get(ext));
            }
        }
        if (showsAttendedHash.containsKey(base)) {
            return canonicalStatusFromStored(showsAttendedHash.get(base));
        }
        if (band != null && band.contains("T.H.E.M")) {
            Log.d(TAG, "ATTENDANCE_MISS lookup base=" + base + " (not in map)");
        }
        return staticVariables.sawNoneStatus;
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

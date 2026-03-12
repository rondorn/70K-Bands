package com.Bands70k;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.TreeSet;

/**
 * Builds full 11-column schedule CSV from in-memory schedule (BandInfo.scheduleRecords)
 * and staticVariables maps. Used for QR share export.
 * Column order: Band, Location, Date, Day, Start Time, End Time, Type, Description URL, Notes, ImageURL, ImageDate.
 *
 * For QR payload parity with iOS: use raw cached schedule CSV with Unofficial/Cruiser rows stripped for export;
 * import adds those events back from the device cache before overwriting.
 */
public final class ScheduleCSVExport {

    private static final String CSV_HEADER =
            "Band,Location,Date,Day,Start Time,End Time,Type,Description URL,Notes,ImageURL,ImageDate";

    /** Column index for Type in the 11-column CSV. */
    private static final int TYPE_COLUMN_INDEX = 6;

    private static final SimpleDateFormat DATE_FORMAT = new SimpleDateFormat("MM/dd/yyyy", Locale.US);

    /**
     * Read the raw schedule CSV from the cached download file (same source as schedule data).
     * Used when we need the unmodified file. Returns null if file missing or unreadable.
     */
    public static String readRawScheduleCsvFromCache() {
        File file = FileHandler70k.schedule;
        if (file == null || !file.exists() || file.length() == 0) return null;
        try {
            byte[] bytes = Files.readAllBytes(file.toPath());
            String csv = new String(bytes, StandardCharsets.UTF_8);
            if (csv == null || csv.trim().isEmpty()) return null;
            if (!csv.contains("Band") || !csv.contains("Location")) return null;
            return csv;
        } catch (IOException e) {
            return null;
        }
    }

    /**
     * Read cached schedule CSV for QR export: same source as iOS, but with Unofficial Event and
     * Cruiser Organized rows removed to reduce payload size. Import adds them back from device cache.
     * Returns null if no cached file or invalid.
     */
    public static String readScheduleCsvForQRExport() {
        String raw = readRawScheduleCsvFromCache();
        if (raw == null || raw.isEmpty()) return null;
        return stripUnofficialCruiserRows(raw);
    }

    /**
     * Remove rows where Type is "Unofficial Event" or "Cruiser Organized". Keeps header and
     * leaves other lines unchanged. Uses column index 6 (Type) for the 11-column schedule CSV.
     */
    private static String stripUnofficialCruiserRows(String csv) {
        if (csv == null) return null;
        String[] lines = csv.split("\n", -1);
        if (lines.length == 0) return csv;
        List<String> out = new ArrayList<>();
        out.add(lines[0]); // header
        for (int i = 1; i < lines.length; i++) {
            String line = lines[i];
            if (line == null || line.trim().isEmpty()) {
                out.add(line);
                continue;
            }
            List<String> fields = ScheduleQRCompression.parseCSVLine(line.trim());
            if (fields.size() <= TYPE_COLUMN_INDEX) {
                out.add(line);
                continue;
            }
            String type = fields.get(TYPE_COLUMN_INDEX).trim();
            if (staticVariables.unofficalEventOld.equals(type) || staticVariables.unofficalEvent.equals(type)) {
                continue; // drop Unofficial Event and Cruiser Organized
            }
            out.add(line);
        }
        return String.join("\n", out);
    }

    /**
     * Build full 11-column CSV from current schedule. Date format MM/dd/yyyy.
     * Returns null if no schedule data.
     */
    public static String buildFullCSVFromSchedule() {
        Map<String, scheduleTimeTracker> records = BandInfo.scheduleRecords;
        if (records == null || records.isEmpty()) return null;

        List<String> lines = new ArrayList<>();
        lines.add(CSV_HEADER);

        List<String> bandNames = new ArrayList<>(records.keySet());
        java.util.Collections.sort(bandNames, String.CASE_INSENSITIVE_ORDER);

        for (String bandName : bandNames) {
            scheduleTimeTracker tracker = records.get(bandName);
            if (tracker == null || tracker.scheduleByTime == null) continue;

            for (Long timeKey : new TreeSet<>(tracker.scheduleByTime.keySet())) {
                scheduleHandler sh = tracker.scheduleByTime.get(timeKey);
                if (sh == null) continue;

                String location = sh.getShowLocation() != null ? sh.getShowLocation() : "";
                String day = sh.getShowDay() != null ? sh.getShowDay() : "";
                String startTimeStr = sh.getStartTimeString() != null ? sh.getStartTimeString() : "";
                String endTimeStr = sh.getEndTimeString() != null ? sh.getEndTimeString() : "";
                String type = sh.getShowType() != null ? sh.getShowType() : "";
                String notes = sh.getShowNotes() != null ? sh.getShowNotes() : "";

                String dateStr = "";
                Date startTime = sh.getStartTime();
                if (startTime != null) {
                    dateStr = DATE_FORMAT.format(startTime);
                }

                String descUrl = "";
                if (staticVariables.showNotesMap != null && staticVariables.showNotesMap.containsKey(bandName)) {
                    String v = staticVariables.showNotesMap.get(bandName);
                    if (v != null) descUrl = v;
                }
                String imageUrl = "";
                if (staticVariables.imageUrlMap != null && staticVariables.imageUrlMap.containsKey(bandName)) {
                    String v = staticVariables.imageUrlMap.get(bandName);
                    if (v != null) imageUrl = v;
                }
                String imageDate = "";
                if (staticVariables.imageDateMap != null && staticVariables.imageDateMap.containsKey(bandName)) {
                    String v = staticVariables.imageDateMap.get(bandName);
                    if (v != null) imageDate = v;
                }

                List<String> row = new ArrayList<>();
                row.add(bandName);
                row.add(location);
                row.add(dateStr);
                row.add(day);
                row.add(startTimeStr);
                row.add(endTimeStr);
                row.add(type);
                row.add(descUrl);
                row.add(notes);
                row.add(imageUrl);
                row.add(imageDate);
                lines.add(ScheduleQRCompression.buildCSVLine(row));
            }
        }

        if (lines.size() <= 1) return null; // header only
        return String.join("\n", lines);
    }
}

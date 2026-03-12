package com.Bands70k;

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
 */
public final class ScheduleCSVExport {

    private static final String CSV_HEADER =
            "Band,Location,Date,Day,Start Time,End Time,Type,Description URL,Notes,ImageURL,ImageDate";

    private static final SimpleDateFormat DATE_FORMAT = new SimpleDateFormat("MM/dd/yyyy", Locale.US);

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
                // Include all event types (including Unofficial/Cruiser Organized) so scan restores them.
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

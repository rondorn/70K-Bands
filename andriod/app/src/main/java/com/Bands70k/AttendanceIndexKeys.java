package com.Bands70k;

import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Builds attendance storage keys aligned with iOS: when multiple schedule rows share the same
 * (band, location, start time, normalized type, year), append {@code __}{@code <database day>}.
 */
public final class AttendanceIndexKeys {

    private AttendanceIndexKeys() {}

    public static String normalizedEventTypeForKey(String eventType) {
        if (eventType == null) return "";
        if (staticVariables.unofficalEventOld.equals(eventType)) {
            return staticVariables.unofficalEvent;
        }
        return eventType;
    }

    public static String baseKey(String band, String location, String startTimeNormalized, String eventType, String eventYearString) {
        String t = normalizedEventTypeForKey(eventType);
        return band + ":" + location + ":" + startTimeNormalized + ":" + t + ":" + eventYearString;
    }

    /**
     * Base keys that occur more than once for this year (same band, location, start time, normalized type).
     */
    public static Set<String> collidingBaseKeys(int year) {
        List<EventData> events = AIScheduleEventLoader.buildEventListForYear(year);
        Map<String, Integer> counts = new HashMap<>();
        for (EventData e : events) {
            if (e.startTime == null || e.startTime.isEmpty()) continue;
            String st = showsAttended.normalizeTimeForIndex(e.startTime);
            String et = e.eventType != null ? e.eventType : "";
            String base = baseKey(e.bandName, e.location, st, et, String.valueOf(year));
            counts.put(base, counts.getOrDefault(base, 0) + 1);
        }
        Set<String> out = new HashSet<>();
        for (Map.Entry<String, Integer> en : counts.entrySet()) {
            if (en.getValue() > 1) {
                out.add(en.getKey());
            }
        }
        return out;
    }

    public static String storageKey(
            String band,
            String location,
            String startTimeNormalized,
            String eventType,
            String eventYearString,
            String scheduleDayFromDatabase,
            Set<String> collidingBases) {
        String base = baseKey(band, location, startTimeNormalized, eventType, eventYearString);
        if (scheduleDayFromDatabase == null) return base;
        String d = scheduleDayFromDatabase.trim();
        if (d.isEmpty()) return base;
        if (collidingBases == null || !collidingBases.contains(base)) return base;
        return base + "__" + d;
    }
}

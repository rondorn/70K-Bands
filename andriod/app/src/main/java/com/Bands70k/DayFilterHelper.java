package com.Bands70k;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Artist Day + schedule Day filter helpers (iOS SortFilterMenuController parity).
 */
public final class DayFilterHelper {

    /** Days filter bucket for bands/events with no Day value. */
    public static final String UNKNOWN_LABEL = "Unknown";

    private static final Pattern DAY_NUMBER = Pattern.compile("(?i)^day\\s+(\\d+)$");

    private DayFilterHelper() {}

    /** Split on ';', trim, drop empties. */
    public static List<String> parseDayTokens(String raw) {
        List<String> out = new ArrayList<>();
        if (raw == null || raw.isEmpty()) {
            return out;
        }
        for (String part : raw.split(";", -1)) {
            String t = part.trim();
            if (!t.isEmpty()) {
                out.add(t);
            }
        }
        return out;
    }

    /** Display form for artist Day on details: tokens joined by comma+space ({@code Day 1, Day 2}). */
    public static String displayDayString(String raw) {
        List<String> tokens = parseDayTokens(raw);
        if (tokens.isEmpty()) {
            return "";
        }
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < tokens.size(); i++) {
            if (i > 0) sb.append(", ");
            sb.append(tokens.get(i));
        }
        return sb.toString();
    }

    public static boolean isUnknownLabel(String label) {
        return label != null
                && label.trim().equalsIgnoreCase(UNKNOWN_LABEL);
    }

    /** Whether a schedule event is expired for Day filter discovery / matching (10‑min buffer). */
    public static boolean isEventExpiredForDayFilter(scheduleHandler event) {
        if (event == null || event.getEpochEnd() == null || event.getEpochStart() == null) {
            return false;
        }
        long end = event.getEpochEnd();
        long start = event.getEpochStart();
        if (start > end) {
            end += 86400000L; // midnight crossing
        }
        return end + 600000L <= System.currentTimeMillis();
    }

    /**
     * Day labels for the Days filter section: schedule event days (Hide Expired aware)
     * union artist Day tokens for bands with no schedule. Appends Unknown when other
     * day labels exist and at least one record has no Day.
     */
    public static List<String> getDayNamesInUseForList() {
        Set<String> days = new HashSet<>();
        boolean hasUnknownDayRecords = false;
        boolean hideExpired = staticVariables.preferences != null
                && staticVariables.preferences.getHideExpiredEvents();
        Set<String> bandsWithSchedule = new HashSet<>();

        if (BandInfo.scheduleRecords != null) {
            for (Map.Entry<String, scheduleTimeTracker> entry : BandInfo.scheduleRecords.entrySet()) {
                String bandName = entry.getKey();
                scheduleTimeTracker tracker = entry.getValue();
                if (tracker == null || tracker.scheduleByTime == null || tracker.scheduleByTime.isEmpty()) {
                    continue;
                }
                bandsWithSchedule.add(bandName);
                for (scheduleHandler event : tracker.scheduleByTime.values()) {
                    if (event == null) continue;
                    if (hideExpired && isEventExpiredForDayFilter(event)) {
                        continue;
                    }
                    String raw = event.getShowDay();
                    if (raw != null && !raw.trim().isEmpty()) {
                        days.add(raw.trim());
                    } else {
                        hasUnknownDayRecords = true;
                    }
                }
            }
        }

        for (String bandName : BandInfo.getLineupBandNameSet()) {
            if (bandsWithSchedule.contains(bandName)) {
                continue;
            }
            List<String> tokens = parseDayTokens(BandInfo.getBandDay(bandName));
            if (tokens.isEmpty()) {
                hasUnknownDayRecords = true;
            } else {
                days.addAll(tokens);
            }
        }

        List<String> result = sortDayFilterLabels(new ArrayList<>(days));
        if (!result.isEmpty() && hasUnknownDayRecords) {
            result.add(UNKNOWN_LABEL);
        }
        return result;
    }

    /** Pre first, Day N numeric, alpha, Unknown last. */
    public static List<String> sortDayFilterLabels(List<String> labels) {
        Collections.sort(labels, new Comparator<String>() {
            @Override
            public int compare(String a, String b) {
                boolean aUnknown = isUnknownLabel(a);
                boolean bUnknown = isUnknownLabel(b);
                if (aUnknown != bUnknown) {
                    return aUnknown ? 1 : -1;
                }
                String aLower = a.toLowerCase(Locale.ROOT);
                String bLower = b.toLowerCase(Locale.ROOT);
                boolean aPre = aLower.equals("pre") || aLower.startsWith("pre ") || aLower.startsWith("pre-");
                boolean bPre = bLower.equals("pre") || bLower.startsWith("pre ") || bLower.startsWith("pre-");
                if (aPre != bPre) {
                    return aPre ? -1 : 1;
                }
                Integer aNum = dayNumber(a);
                Integer bNum = dayNumber(b);
                if (aNum != null && bNum != null) {
                    return aNum.compareTo(bNum);
                }
                if (aNum != null) return -1;
                if (bNum != null) return 1;
                return a.compareToIgnoreCase(b);
            }
        });
        return labels;
    }

    private static Integer dayNumber(String label) {
        Matcher m = DAY_NUMBER.matcher(label.trim());
        if (m.matches()) {
            try {
                return Integer.parseInt(m.group(1));
            } catch (NumberFormatException ignored) {
                return null;
            }
        }
        return null;
    }

    /** Schedule event row: empty Day uses Unknown toggle. */
    public static boolean eventPassesDayFilter(scheduleHandler event) {
        if (event == null) {
            return getShowDay(UNKNOWN_LABEL);
        }
        String d = event.getShowDay();
        if (d == null || d.trim().isEmpty()) {
            return getShowDay(UNKNOWN_LABEL);
        }
        return getShowDay(d.trim());
    }

    /** Calendar ScheduleBlock day field. */
    public static boolean eventDayPassesFilter(String scheduleDay) {
        if (scheduleDay == null || scheduleDay.trim().isEmpty()) {
            return getShowDay(UNKNOWN_LABEL);
        }
        return getShowDay(scheduleDay.trim());
    }

    /**
     * Band-only row: schedule days if present (Hide Expired aware), else artist Day tokens.
     * Missing Day gated by Unknown (default on).
     */
    public static boolean bandPassesDayFilter(String bandName) {
        scheduleTimeTracker tracker = BandInfo.scheduleRecords != null
                ? BandInfo.scheduleRecords.get(bandName) : null;
        boolean hideExpired = staticVariables.preferences != null
                && staticVariables.preferences.getHideExpiredEvents();

        if (tracker != null && tracker.scheduleByTime != null && !tracker.scheduleByTime.isEmpty()) {
            List<scheduleHandler> relevant = new ArrayList<>();
            for (scheduleHandler event : tracker.scheduleByTime.values()) {
                if (event == null) continue;
                if (hideExpired && isEventExpiredForDayFilter(event)) {
                    continue;
                }
                relevant.add(event);
            }
            if (relevant.isEmpty()) {
                return getShowDay(UNKNOWN_LABEL);
            }
            for (scheduleHandler event : relevant) {
                String d = event.getShowDay();
                if (d == null || d.trim().isEmpty()) {
                    if (getShowDay(UNKNOWN_LABEL)) {
                        return true;
                    }
                } else if (getShowDay(d.trim())) {
                    return true;
                }
            }
            return false;
        }

        List<String> tokens = parseDayTokens(BandInfo.getBandDay(bandName));
        if (tokens.isEmpty()) {
            return getShowDay(UNKNOWN_LABEL);
        }
        for (String token : tokens) {
            if (getShowDay(token)) {
                return true;
            }
        }
        return false;
    }

    private static boolean getShowDay(String dayName) {
        if (staticVariables.preferences == null) {
            return true;
        }
        return staticVariables.preferences.getShowDayEvents(dayName);
    }

    /** True if any discovered Day toggle is off. */
    public static boolean isAnyDayFilterActive() {
        if (staticVariables.preferences == null) {
            return false;
        }
        for (String dayName : getDayNamesInUseForList()) {
            if (!staticVariables.preferences.getShowDayEvents(dayName)) {
                return true;
            }
        }
        return false;
    }
}

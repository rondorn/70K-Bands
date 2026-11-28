package com.Bands70k;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.TimeUnit;
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

    private static boolean isNamedPreLabel(String label) {
        if (label == null) return false;
        String lower = label.trim().toLowerCase(Locale.ROOT);
        return lower.equals("pre") || lower.startsWith("pre ") || lower.startsWith("pre-");
    }

    private static boolean isNamedPostLabel(String label) {
        if (label == null) return false;
        String lower = label.trim().toLowerCase(Locale.ROOT);
        return lower.equals("post") || lower.startsWith("post ") || lower.startsWith("post-");
    }

    /** Parse filter labels like {@code 1/27} / {@code 01/27} (year = eventYear). */
    private static Date parseDayFilterDateLabel(String label) {
        if (label == null) return null;
        String trimmed = label.trim();
        String[] formats = {"M/d", "MM/dd", "M/dd", "MM/d"};
        int year = (staticVariables.eventYear != null && staticVariables.eventYear > 0)
                ? staticVariables.eventYear
                : Calendar.getInstance().get(Calendar.YEAR);
        for (String format : formats) {
            SimpleDateFormat sdf = new SimpleDateFormat(format, Locale.US);
            sdf.setLenient(false);
            try {
                Date partial = sdf.parse(trimmed);
                if (partial == null) continue;
                Calendar cal = Calendar.getInstance();
                cal.setTime(partial);
                cal.set(Calendar.YEAR, year);
                // Normalize to midnight for day-diff math
                cal.set(Calendar.HOUR_OF_DAY, 0);
                cal.set(Calendar.MINUTE, 0);
                cal.set(Calendar.SECOND, 0);
                cal.set(Calendar.MILLISECOND, 0);
                return cal.getTime();
            } catch (ParseException ignored) {
                // try next format
            }
        }
        return null;
    }

    /**
     * Date-like labels: no gap → all Pre. Gap of ≥2 calendar days between sorted dates →
     * earlier cluster Pre, later cluster(s) Post.
     *
     * @return map label → true (Pre) / false (Post)
     */
    private static Map<String, Boolean> classifyDateFilterLabelsAsPreOrPost(List<String> labels) {
        class DatedLabel {
            final String label;
            final Date date;
            DatedLabel(String label, Date date) {
                this.label = label;
                this.date = date;
            }
        }
        List<DatedLabel> dated = new ArrayList<>();
        for (String label : labels) {
            if (isNamedPreLabel(label) || isNamedPostLabel(label) || isUnknownLabel(label)) {
                continue;
            }
            if (dayNumber(label) != null) {
                continue;
            }
            Date date = parseDayFilterDateLabel(label);
            if (date != null) {
                dated.add(new DatedLabel(label, date));
            }
        }
        Map<String, Boolean> result = new HashMap<>();
        if (dated.isEmpty()) {
            return result;
        }
        Collections.sort(dated, new Comparator<DatedLabel>() {
            @Override
            public int compare(DatedLabel a, DatedLabel b) {
                return a.date.compareTo(b.date);
            }
        });

        Integer splitIndex = null;
        for (int i = 1; i < dated.size(); i++) {
            long diffMs = dated.get(i).date.getTime() - dated.get(i - 1).date.getTime();
            long diffDays = TimeUnit.MILLISECONDS.toDays(diffMs);
            if (diffDays >= 2) {
                splitIndex = i;
                break;
            }
        }

        if (splitIndex != null) {
            for (int i = 0; i < dated.size(); i++) {
                result.put(dated.get(i).label, i < splitIndex);
            }
        } else {
            for (DatedLabel item : dated) {
                result.put(item.label, true); // no gap → all Pre
            }
        }
        return result;
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

    /**
     * Order: named Pre → date Pre → Day N → other → date Post → named Post → Unknown.
     */
    public static List<String> sortDayFilterLabels(List<String> labels) {
        final Map<String, Boolean> dateSide = classifyDateFilterLabelsAsPreOrPost(labels);
        final Map<String, Date> dateByLabel = new HashMap<>();
        for (String label : labels) {
            Date d = parseDayFilterDateLabel(label);
            if (d != null) {
                dateByLabel.put(label, d);
            }
        }

        Collections.sort(labels, new Comparator<String>() {
            @Override
            public int compare(String a, String b) {
                int ba = bucket(a, dateSide);
                int bb = bucket(b, dateSide);
                if (ba != bb) {
                    return Integer.compare(ba, bb);
                }
                if (ba == 2) { // Day N
                    Integer an = dayNumber(a);
                    Integer bn = dayNumber(b);
                    if (an != null && bn != null && !an.equals(bn)) {
                        return an.compareTo(bn);
                    }
                }
                if (ba == 1 || ba == 4) { // date Pre / date Post
                    Date da = dateByLabel.get(a);
                    Date db = dateByLabel.get(b);
                    if (da != null && db != null && !da.equals(db)) {
                        return da.compareTo(db);
                    }
                }
                return a.compareToIgnoreCase(b);
            }
        });
        return labels;
    }

    /** 0 namedPre, 1 datePre, 2 dayN, 3 other, 4 datePost, 5 namedPost, 6 unknown */
    private static int bucket(String label, Map<String, Boolean> dateSide) {
        if (isUnknownLabel(label)) return 6;
        if (isNamedPreLabel(label)) return 0;
        if (isNamedPostLabel(label)) return 5;
        if (dayNumber(label) != null) return 2;
        if (dateSide.containsKey(label)) {
            return Boolean.TRUE.equals(dateSide.get(label)) ? 1 : 4;
        }
        return 3;
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

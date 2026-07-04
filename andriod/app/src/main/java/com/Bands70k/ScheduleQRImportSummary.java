package com.Bands70k;

import android.content.Context;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Compares schedule before QR import with incoming CSV payload.
 * Added/removed are net event-count changes; updated counts same-slot changes (including venue moves).
 */
public final class ScheduleQRImportSummary {

    private static final SimpleDateFormat DATE_FORMAT = new SimpleDateFormat("MM/dd/yyyy", Locale.US);

    static final class EventRow {
        final String stableKey;
        final String identityKey;
        final String signature;

        EventRow(String stableKey, String identityKey, String signature) {
            this.stableKey = stableKey;
            this.identityKey = identityKey;
            this.signature = signature;
        }
    }

    public static final class Snapshot {
        public final Map<String, Integer> nameVenueCounts;
        public final List<EventRow> rows;

        Snapshot(Map<String, Integer> nameVenueCounts, List<EventRow> rows) {
            this.nameVenueCounts = nameVenueCounts;
            this.rows = rows;
        }

        int totalCount() {
            return rows != null ? rows.size() : 0;
        }
    }

    public static final class Result {
        public final int added;
        public final int updated;
        public final int removed;

        Result(int added, int updated, int removed) {
            this.added = added;
            this.updated = updated;
            this.removed = removed;
        }
    }

    private ScheduleQRImportSummary() {}

    private static String sanitize(String value) {
        if (value == null) return "";
        return value.replace("\n", " ").replace("\r", " ").trim();
    }

    public static String nameVenueKey(String bandName, String location) {
        return sanitize(bandName) + "-" + sanitize(location);
    }

    public static String eventIdentityKey(String bandName, String location, String date,
                                          String day, String startTime, String eventType) {
        return sanitize(bandName) + "|" + sanitize(location) + "|" + sanitize(date) + "|"
                + sanitize(day) + "|" + sanitize(startTime) + "|" + sanitize(eventType);
    }

    public static String eventStableKey(String bandName, String date, String day,
                                        String startTime, String eventType) {
        return sanitize(bandName) + "|" + sanitize(date) + "|" + sanitize(day) + "|"
                + sanitize(startTime) + "|" + sanitize(eventType);
    }

    private static void ingestRow(String bandName, String location, String date, String day,
                                  String startTime, String endTime, String eventType, String notes,
                                  Map<String, Integer> nameVenueCounts,
                                  List<EventRow> rows) {
        String nvKey = nameVenueKey(bandName, location);
        nameVenueCounts.put(nvKey, nameVenueCounts.getOrDefault(nvKey, 0) + 1);
        String identityKey = eventIdentityKey(bandName, location, date, day, startTime, eventType);
        String stableKey = eventStableKey(bandName, date, day, startTime, eventType);
        String signature = eventSignature(endTime, eventType, day, startTime, notes, date);
        rows.add(new EventRow(stableKey, identityKey, signature));
    }

    public static Snapshot captureFromSchedule(Map<String, scheduleTimeTracker> schedule) {
        Map<String, Integer> nameVenueCounts = new java.util.HashMap<>();
        List<EventRow> rows = new ArrayList<>();
        if (schedule == null) {
            return new Snapshot(nameVenueCounts, rows);
        }
        for (Map.Entry<String, scheduleTimeTracker> bandEntry : schedule.entrySet()) {
            scheduleTimeTracker tracker = bandEntry.getValue();
            if (tracker == null || tracker.scheduleByTime == null) continue;
            String bandName = bandEntry.getKey();
            for (Map.Entry<Long, scheduleHandler> timeEntry : tracker.scheduleByTime.entrySet()) {
                scheduleHandler h = timeEntry.getValue();
                if (h == null) continue;
                String location = h.getShowLocation() != null ? h.getShowLocation() : "";
                String day = h.getShowDay() != null ? h.getShowDay() : "";
                String startTime = h.getStartTimeString() != null ? h.getStartTimeString() : "";
                String endTime = h.getEndTimeString() != null ? h.getEndTimeString() : "";
                String eventType = h.getShowType() != null ? h.getShowType() : "";
                if (staticVariables.unofficalEvent.equals(eventType)
                        || staticVariables.unofficalEventOld.equals(eventType)) {
                    continue;
                }
                String notes = h.getShowNotes() != null ? h.getShowNotes() : "";
                String dateStr = "";
                Date startDate = h.getStartTime();
                if (startDate != null) {
                    dateStr = DATE_FORMAT.format(startDate);
                }
                ingestRow(bandName, location, dateStr, day, startTime, endTime, eventType, notes,
                        nameVenueCounts, rows);
            }
        }
        return new Snapshot(nameVenueCounts, rows);
    }

    public static Snapshot captureFromCSV(String csv) {
        Map<String, Integer> nameVenueCounts = new java.util.HashMap<>();
        List<EventRow> rows = new ArrayList<>();
        if (csv == null || csv.trim().isEmpty()) {
            return new Snapshot(nameVenueCounts, rows);
        }
        String[] lines = csv.split("\n", -1);
        boolean first = true;
        for (String line : lines) {
            if (line == null) continue;
            String trimmed = line.trim();
            if (trimmed.isEmpty()) continue;
            List<String> fields = ScheduleQRCompression.parseCSVLine(trimmed);
            if (first) {
                first = false;
                if (!fields.isEmpty() && "band".equalsIgnoreCase(fields.get(0).trim())) {
                    continue;
                }
            }
            if (fields.size() < 7) continue;
            String eventType = fields.get(6);
            if (staticVariables.unofficalEvent.equals(eventType)
                    || staticVariables.unofficalEventOld.equals(eventType)) {
                continue;
            }
            ingestRow(fields.get(0), fields.get(1), fields.get(2), fields.get(3),
                    fields.get(4), fields.get(5), eventType,
                    fields.size() > 8 ? fields.get(8) : "",
                    nameVenueCounts, rows);
        }
        return new Snapshot(nameVenueCounts, rows);
    }

    private static String eventSignature(String endTime, String eventType, String day,
                                           String startTime, String notes, String date) {
        return sanitize(endTime) + "|" + sanitize(eventType) + "|" + sanitize(day) + "|"
                + sanitize(startTime) + "|" + sanitize(notes) + "|" + sanitize(date);
    }

    public static Result compare(Snapshot before, Snapshot incoming) {
        if (incoming == null) {
            return new Result(0, 0, 0);
        }
        if (before == null) {
            before = new Snapshot(new java.util.HashMap<String, Integer>(), new ArrayList<EventRow>());
        }
        int beforeTotal = before.totalCount();
        int incomingTotal = incoming.totalCount();
        int added = Math.max(0, incomingTotal - beforeTotal);
        int removed = Math.max(0, beforeTotal - incomingTotal);

        List<EventRow> beforeLeft = new ArrayList<>(before.rows);
        List<EventRow> incomingLeft = new ArrayList<>(incoming.rows);
        int updated = 0;

        for (int i = 0; i < incomingLeft.size(); ) {
            EventRow inc = incomingLeft.get(i);
            int match = indexOfIdentity(beforeLeft, inc.identityKey);
            if (match >= 0) {
                if (!beforeLeft.get(match).signature.equals(inc.signature)) {
                    updated++;
                }
                beforeLeft.remove(match);
                incomingLeft.remove(i);
            } else {
                i++;
            }
        }

        for (int i = 0; i < incomingLeft.size(); ) {
            EventRow inc = incomingLeft.get(i);
            int match = indexOfStable(beforeLeft, inc.stableKey);
            if (match >= 0) {
                updated++;
                beforeLeft.remove(match);
                incomingLeft.remove(i);
            } else {
                i++;
            }
        }

        return new Result(added, updated, removed);
    }

    private static int indexOfIdentity(List<EventRow> rows, String identityKey) {
        for (int i = 0; i < rows.size(); i++) {
            if (rows.get(i).identityKey.equals(identityKey)) return i;
        }
        return -1;
    }

    private static int indexOfStable(List<EventRow> rows, String stableKey) {
        for (int i = 0; i < rows.size(); i++) {
            if (rows.get(i).stableKey.equals(stableKey)) return i;
        }
        return -1;
    }

    public static String formatMessage(Context context, int added, int updated, int removed) {
        if (added == 0 && updated == 0 && removed == 0) {
            return context.getString(R.string.schedule_qr_no_new_events);
        }
        StringBuilder message = new StringBuilder();
        if (added > 0) {
            message.append(context.getString(R.string.schedule_qr_events_added, added));
        }
        if (updated > 0) {
            if (message.length() > 0) message.append(", ");
            message.append(context.getString(R.string.schedule_qr_events_updated, updated));
        }
        if (removed > 0) {
            if (message.length() > 0) message.append(", ");
            message.append(context.getString(R.string.schedule_qr_events_removed, removed));
        }
        return message.toString();
    }
}

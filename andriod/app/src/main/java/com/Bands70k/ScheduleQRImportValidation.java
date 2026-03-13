package com.Bands70k;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Validates decompressed QR schedule CSV before overwriting the schedule cache.
 * Run after decompression (all codes resolved to band names) but before writing the file.
 * 1) No unresolved bands: band column must not be exactly 2 digits (e.g. "51" = unresolved code).
 * 2) Day 1 consistency: sample Day 1 events must match existing schedule (same band at same venue/time).
 */
public final class ScheduleQRImportValidation {

    private static final int COL_BAND = 0;
    private static final int COL_LOCATION = 1;
    private static final int COL_DAY = 3;
    private static final int COL_START_TIME = 4;
    private static final int MIN_COLUMNS = 5;

    public static final class Result {
        public final boolean success;
        /** If !success, one example message for the user (e.g. "Band 51 could not resolve" or "Expected Day 1 Rink 5:30 to be Vio-Lence but was MiniPony"). */
        public final String failureExampleMessage;

        public Result(boolean success, String failureExampleMessage) {
            this.success = success;
            this.failureExampleMessage = failureExampleMessage;
        }
    }

    /**
     * Validate decompressed schedule CSV against the current schedule cache.
     * @param currentCsvContent contents of current schedule file (before overwrite)
     * @param newCsvContent decompressed CSV (codes already resolved to band names)
     * @return result with success and optional failure example message
     */
    public static Result validate(String currentCsvContent, String newCsvContent) {
        if (newCsvContent == null || newCsvContent.isEmpty()) {
            return new Result(false, "Imported schedule is empty.");
        }

        // 1) Check no 2-digit band names (unresolved codes)
        String unresolvedExample = findUnresolvedBandExample(newCsvContent);
        if (unresolvedExample != null) {
            return new Result(false, "Band " + unresolvedExample + " could not resolve");
        }

        // 2) Day 1: same (day, venue, startTime) should have same band as current
        if (currentCsvContent != null && !currentCsvContent.trim().isEmpty()) {
            String day1Mismatch = findDay1MismatchExample(currentCsvContent, newCsvContent);
            if (day1Mismatch != null) {
                return new Result(false, day1Mismatch);
            }
        }

        return new Result(true, null);
    }

    /** Returns an example unresolved band (exactly 2 digits) or null if none. */
    private static String findUnresolvedBandExample(String csv) {
        String[] lines = csv.split("\\n");
        boolean first = true;
        for (String line : lines) {
            String trimmed = line.trim();
            if (trimmed.isEmpty()) continue;
            List<String> fields = ScheduleQRCompression.parseCSVLine(trimmed);
            if (first) {
                first = false;
                if (fields.size() > 0 && "band".equalsIgnoreCase(fields.get(0).trim())) continue;
            }
            if (fields.size() <= COL_BAND) continue;
            String band = fields.get(COL_BAND).trim();
            if (isExactlyTwoDigits(band)) return band;
        }
        return null;
    }

    private static boolean isExactlyTwoDigits(String s) {
        if (s == null || s.length() != 2) return false;
        return Character.isDigit(s.charAt(0)) && Character.isDigit(s.charAt(1));
    }

    /** Build key for Day 1 slot comparison. Day column normalized to "1" for Day 1. */
    private static String slotKey(String day, String location, String startTime) {
        String d = day == null ? "" : day.trim();
        String loc = location == null ? "" : location.trim();
        String time = startTime == null ? "" : startTime.trim();
        return "1|" + loc + "|" + time;
    }

    private static boolean isDay1(String dayCol) {
        if (dayCol == null) return false;
        String d = dayCol.trim();
        if (d.isEmpty()) return false;
        if ("day 1".equalsIgnoreCase(d)) return true;
        if ("1".equals(d)) return true;
        if (d.toLowerCase().startsWith("1/")) return true;
        return false;
    }

    /** Parse CSV into map of slotKey -> band for Day 1 only. */
    private static Map<String, String> buildDay1SlotToBand(String csv) {
        Map<String, String> map = new HashMap<>();
        String[] lines = csv.split("\\n");
        boolean first = true;
        for (String line : lines) {
            String trimmed = line.trim();
            if (trimmed.isEmpty()) continue;
            List<String> fields = ScheduleQRCompression.parseCSVLine(trimmed);
            if (first) {
                first = false;
                if (fields.size() > 0 && "band".equalsIgnoreCase(fields.get(0).trim())) continue;
            }
            if (fields.size() < MIN_COLUMNS) continue;
            String day = fields.get(COL_DAY);
            if (!isDay1(day)) continue;
            String band = fields.get(COL_BAND).trim();
            String location = fields.get(COL_LOCATION).trim();
            String startTime = fields.get(COL_START_TIME).trim();
            map.put(slotKey(day, location, startTime), band);
        }
        return map;
    }

    /** Returns one example mismatch message or null. */
    private static String findDay1MismatchExample(String currentCsv, String newCsv) {
        Map<String, String> currentSlots = buildDay1SlotToBand(currentCsv);
        Map<String, String> newSlots = buildDay1SlotToBand(newCsv);
        for (Map.Entry<String, String> entry : newSlots.entrySet()) {
            String key = entry.getKey();
            String newBand = entry.getValue();
            String currentBand = currentSlots.get(key);
            if (currentBand != null && !currentBand.equals(newBand)) {
                String[] parts = key.split("\\|", -1);
                String venue = parts.length > 1 ? parts[1] : "?";
                String time = parts.length > 2 ? parts[2] : "?";
                return "Expected Day 1 " + venue + " " + time + " to be " + currentBand + " but was " + newBand;
            }
        }
        return null;
    }

    /** Read current schedule file content for validation (before overwrite). */
    public static String readCurrentScheduleContent() throws IOException {
        File file = FileHandler70k.schedule;
        if (!file.exists()) return "";
        StringBuilder sb = new StringBuilder();
        try (BufferedReader br = new BufferedReader(new FileReader(file, StandardCharsets.UTF_8))) {
            String line;
            while ((line = br.readLine()) != null) {
                if (sb.length() > 0) sb.append("\n");
                sb.append(line);
            }
        }
        return sb.toString();
    }
}

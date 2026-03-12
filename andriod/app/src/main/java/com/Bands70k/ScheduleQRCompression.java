package com.Bands70k;

import android.util.Log;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.regex.Pattern;
import java.util.zip.Deflater;
import java.util.zip.DeflaterOutputStream;
import java.util.zip.Inflater;
import java.util.zip.InflaterInputStream;
import java.util.zip.ZipException;

/**
 * Schedule QR payload format (matches iOS exactly):
 * One or two binary QRs. Each payload = 1 byte type (0=full, 1=chunk1, 2=chunk2)
 * + 4-byte little-endian uncompressed size + zlib-compressed UTF-8 CSV.
 * Max 2953 bytes per QR. Uses zlib (not LZMA) for cross-platform compatibility.
 * CSV: 8 columns in QR (Band,Location,Date,Day,Start Time,End Time,Type,Notes);
 * full 11 columns (Band,...,Description URL,Notes,ImageURL,ImageDate) after postprocess.
 */
public final class ScheduleQRCompression {

    private static final String TAG = "ScheduleQRCompression";

    /** Max bytes per QR for binary payload (Version 40 Low). */
    private static final int MAX_BYTES_PER_BINARY_QR = 2953;

    /** Payload type: 0 = full schedule (1 QR), 1 = chunk 1 of 2, 2 = chunk 2 of 2. */
    public static final byte SCHEDULE_QR_TYPE_FULL = 0;
    public static final byte SCHEDULE_QR_TYPE_CHUNK1 = 1;
    public static final byte SCHEDULE_QR_TYPE_CHUNK2 = 2;

    /** Full 11-column CSV header for importer. */
    private static final String SCHEDULE_CSV_HEADER =
            "Band,Location,Date,Day,Start Time,End Time,Type,Description URL,Notes,ImageURL,ImageDate";

    /** 8-column header used inside QR (omit Description URL, ImageURL, ImageDate). */
    private static final String SCHEDULE_QR_HEADER =
            "Band,Location,Date,Day,Start Time,End Time,Type,Notes";

    private static final int SCHEDULE_CSV_COLUMN_COUNT = 11;

    private static final String DROPBOX_URL_PREFIX = "https://www.dropbox.com/";
    private static final String DROPBOX_URL_PLACEHOLDER = "!DB!";

    /** Event type order – must match iOS. Index 0 = "1", etc. */
    private static final String[] EVENT_TYPE_ORDER = new String[]{
            staticVariables.show,           // Show
            staticVariables.meetAndGreet,   // Meet and Greet
            staticVariables.unofficalEventOld, // Unofficial Event
            staticVariables.specialEvent,   // Special Event
            staticVariables.clinic,        // Clinic
            staticVariables.unofficalEvent // Cruiser Organized
    };

    private static final Pattern TRAILING_COMMAS = Pattern.compile(",+$");

    // ---------- Helpers: two-digit / one-digit codes ----------

    private static String twoDigitCode(int index) {
        int n = index + 1;
        if (n < 1 || n > 99) return "";
        return String.format("%02d", n);
    }

    private static Integer indexFromTwoDigitCode(String code) {
        if (code == null || code.length() != 2) return null;
        try {
            int n = Integer.parseInt(code);
            if (n >= 1 && n <= 99) return n - 1;
        } catch (NumberFormatException ignored) { }
        return null;
    }

    private static String oneDigitCodeForType(int index) {
        if (index < 0 || index >= 9) return "";
        return String.valueOf(index + 1);
    }

    private static Integer indexFromOneDigitTypeCode(String code) {
        if (code == null || code.length() != 1) return null;
        try {
            int n = Integer.parseInt(code);
            if (n >= 1 && n <= 9) return n - 1;
        } catch (NumberFormatException ignored) { }
        return null;
    }

    // ---------- CSV parse / build ----------

    static List<String> parseCSVLine(String line) {
        List<String> fields = new ArrayList<>();
        StringBuilder current = new StringBuilder();
        boolean inQuotes = false;
        for (int i = 0; i < line.length(); i++) {
            char ch = line.charAt(i);
            if (ch == '"') {
                inQuotes = !inQuotes;
            } else if (ch == ',' && !inQuotes) {
                fields.add(current.toString());
                current.setLength(0);
            } else {
                current.append(ch);
            }
        }
        fields.add(current.toString());
        return fields;
    }

    private static String escapeCSVField(String s) {
        if (s == null) return "";
        if (s.contains(",") || s.contains("\n") || s.contains("\"")) {
            return "\"" + s.replace("\"", "\"\"") + "\"";
        }
        return s;
    }

    static String buildCSVLine(List<String> fields) {
        if (fields == null || fields.isEmpty()) return "";
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < fields.size(); i++) {
            if (i > 0) sb.append(',');
            sb.append(escapeCSVField(fields.get(i) != null ? fields.get(i) : ""));
        }
        return sb.toString();
    }

    // ---------- Date/Day/Time shorten/expand (Android follows iOS contract; iOS is template) ----------
    //
    // TIME: 24h "HH:MM". Only quarter-hours shortened; others unchanged.
    //   Encode: 15:00→"15:", 15:15→"15:1", 15:30→"15:2", 15:45→"15:3"; 15:05→"15:05".
    //   Decode: "15:"→15:00, "15:1"→15:15, "15:2"→15:30, "15:3"→15:45; "15:05"→15:05.
    // DATE: MM/DD/YYYY → M/D/YY (no leading zeros, 2-digit year). Decode: 2-digit year → 20xx.
    // DAY: "Day N" → "N". Decode: "N" → "Day N".

    private static String shortenDateForQR(String date) {
        if (date == null) return "";
        String d = date.trim();
        if (d.isEmpty()) return date;
        String[] parts = d.split("/");
        if (parts.length != 3) return date;
        try {
            int m = Integer.parseInt(parts[0].trim());
            int day = Integer.parseInt(parts[1].trim());
            int y = Integer.parseInt(parts[2].trim());
            if (m < 1 || m > 12 || day < 1 || day > 31 || y < 2000 || y > 2099) return date;
            int yy = y % 100;
            return m + "/" + day + "/" + yy;
        } catch (NumberFormatException e) {
            return date;
        }
    }

    private static String expandDateFromQR(String date) {
        if (date == null) return "";
        String d = date.trim();
        if (d.isEmpty()) return date;
        String[] parts = d.split("/");
        if (parts.length != 3) return date;
        try {
            int m = Integer.parseInt(parts[0].trim());
            int day = Integer.parseInt(parts[1].trim());
            int y = Integer.parseInt(parts[2].trim());
            if (m < 1 || m > 12 || day < 1 || day > 31) return date;
            int year = (y >= 100) ? y : (y >= 0 && y <= 99 ? 2000 + y : y);
            return String.format("%02d/%02d/%04d", m, day, year);
        } catch (NumberFormatException e) {
            return date;
        }
    }

    private static String shortenTimeForQR(String time) {
        if (time == null) return "";
        String t = time.trim();
        if (t.isEmpty()) return time;
        String[] parts = t.split(":");
        if (parts.length != 2) return time;
        try {
            int h = Integer.parseInt(parts[0].trim());
            if (h < 0 || h > 23) return time;
            String minPart = parts[1].trim();
            int m = Integer.parseInt(minPart);
            if (m < 0 || m > 59) return time;
            switch (m) {
                case 0:  return h + ":";
                case 15: return h + ":1";
                case 30: return h + ":2";
                case 45: return h + ":3";
                default: return time;
            }
        } catch (NumberFormatException e) {
            return time;
        }
    }

    private static String expandTimeFromQR(String time) {
        if (time == null) return "";
        String t = time.trim();
        if (t.isEmpty()) return time;
        String[] parts = t.split(":", -1);
        if (parts.length != 2) return time;
        try {
            int h = Integer.parseInt(parts[0].trim());
            if (h < 0 || h > 23) return time;
            String minPart = parts[1].trim();
            if (minPart.isEmpty()) return String.format("%02d:00", h);
            if (minPart.length() == 1) {
                int digit = minPart.charAt(0) - '0';
                if (digit >= 0 && digit <= 3) {
                    int[] minMap = {0, 15, 30, 45};
                    return String.format("%02d:%02d", h, minMap[digit]);
                }
            }
            int m = Integer.parseInt(minPart);
            if (m >= 0 && m <= 59) return String.format("%02d:%02d", h, m);
        } catch (NumberFormatException e) {
            return time;
        }
        return time;
    }

    private static String shortenDayForQR(String day) {
        if (day == null) return "";
        String trimmed = day.trim();
        if (trimmed.startsWith("Day ") && trimmed.length() > 4) {
            String suffix = trimmed.substring(4).trim();
            if (!suffix.isEmpty() && suffix.matches("\\d+")) return suffix;
        }
        return day;
    }

    private static String expandDayFromQR(String day) {
        if (day == null) return "";
        String trimmed = day.trim();
        if (!trimmed.isEmpty() && trimmed.matches("\\d+")) return "Day " + trimmed;
        return day;
    }

    // ---------- Preprocess / Postprocess ----------

    private static String preprocessCSVForCompression(String csv) {
        if (csv == null) return "";
        String out = csv.replace(DROPBOX_URL_PREFIX, DROPBOX_URL_PLACEHOLDER);
        String[] lines = out.split("\\n");
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < lines.length; i++) {
            if (i > 0) sb.append('\n');
            sb.append(TRAILING_COMMAS.matcher(lines[i]).replaceAll(""));
        }
        return sb.toString();
    }

    /**
     * Postprocess CSV after decompression: expand !DB!, pad rows to 11 columns.
     */
    public static String postprocessCSVAfterDecompression(String csv) {
        if (csv == null) return "";
        String expanded = csv.replace(DROPBOX_URL_PLACEHOLDER, DROPBOX_URL_PREFIX);
        String[] lines = expanded.split("\\n");
        StringBuilder sb = new StringBuilder();
        for (String line : lines) {
            String trimmed = line.trim();
            if (trimmed.isEmpty()) {
                sb.append(line).append('\n');
                continue;
            }
            List<String> fields = parseCSVLine(trimmed);
            if (fields.size() >= SCHEDULE_CSV_COLUMN_COUNT) {
                sb.append(line).append('\n');
                continue;
            }
            if (fields.size() > 0 && "band".equalsIgnoreCase(fields.get(0))) {
                sb.append(SCHEDULE_CSV_HEADER).append('\n');
                continue;
            }
            if (fields.size() == 8) {
                fields.add(7, "");
                fields.add("");
                fields.add("");
            }
            while (fields.size() < SCHEDULE_CSV_COLUMN_COUNT) {
                fields.add("");
            }
            sb.append(buildCSVLine(fields)).append('\n');
        }
        return sb.toString();
    }

    // ---------- Compress/expand column codes ----------

    private static String compressBandColumn(String value, List<String> bandNames) {
        if (value == null || bandNames == null) return value != null ? value : "";
        for (int i = 0; i < bandNames.size(); i++) {
            if (value.equalsIgnoreCase(bandNames.get(i))) return twoDigitCode(i);
        }
        return value;
    }

    private static String compressLocationColumn(String value, List<String> venueNames) {
        if (value == null || venueNames == null) return value != null ? value : "";
        for (int i = 0; i < venueNames.size(); i++) {
            if (value.equalsIgnoreCase(venueNames.get(i))) return twoDigitCode(i);
        }
        return value;
    }

    private static String compressTypeColumn(String value, List<String> eventTypes) {
        if (value == null || eventTypes == null) return value != null ? value : "";
        for (int i = 0; i < eventTypes.size(); i++) {
            if (value.equalsIgnoreCase(eventTypes.get(i))) return oneDigitCodeForType(i);
        }
        return value;
    }

    private static String decompressBandColumn(String value, List<String> bandNames) {
        Integer idx = indexFromTwoDigitCode(value);
        if (idx != null && bandNames != null && idx < bandNames.size()) return bandNames.get(idx);
        return value != null ? value : "";
    }

    private static String decompressLocationColumn(String value, List<String> venueNames) {
        Integer idx = indexFromTwoDigitCode(value);
        if (idx != null && venueNames != null && idx < venueNames.size()) return venueNames.get(idx);
        return value != null ? value : "";
    }

    private static String decompressTypeColumn(String value, List<String> eventTypes) {
        Integer idx = indexFromOneDigitTypeCode(value);
        if (idx != null && eventTypes != null && idx < eventTypes.size()) return eventTypes.get(idx);
        return value != null ? value : "";
    }

    // ---------- zlib: compress with 4-byte LE size header (cross-platform with iOS) ----------

    /**
     * Compress UTF-8 bytes and prepend 4-byte little-endian uncompressed size.
     * Uses raw DEFLATE (nowrap=true) to match iOS: Apple's COMPRESSION_ZLIB outputs raw DEFLATE
     * (no zlib header/footer), so the QR payload is identical in format and ~6 bytes smaller.
     */
    private static byte[] compressForQR(byte[] source) throws IOException {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        ByteBuffer le = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN);
        le.putInt(source.length);
        baos.write(le.array());
        Deflater def = new Deflater(Deflater.DEFAULT_COMPRESSION, true); // raw DEFLATE (match iOS)
        try (DeflaterOutputStream zos = new DeflaterOutputStream(baos, def)) {
            zos.write(source);
        }
        byte[] out = baos.toByteArray();
        Log.d(TAG, "[QRCreate] deflate: uncompressedSize=" + source.length + " totalPayload=" + out.length + " (4-byte LE size + raw deflate)");
        return out;
    }

    /**
     * Decompress: first 4 bytes = LE uncompressed size, rest = compressed stream.
     * Both Android and iOS now produce raw DEFLATE (no zlib header). Try zlib first for backward
     * compatibility with old QRs, then raw deflate on "incorrect header check".
     */
    private static byte[] decompressFromQR(byte[] compressed) throws IOException {
        if (compressed == null || compressed.length <= 4) {
            throw new IOException("Payload too short (" + (compressed != null ? compressed.length : 0) + " bytes)");
        }
        int n = ByteBuffer.wrap(compressed, 0, 4).order(ByteOrder.LITTLE_ENDIAN).getInt();
        if (n <= 0 || n > 2_000_000) {
            throw new IOException("Invalid size header (n=" + n + ")");
        }
        byte[] streamBytes = new byte[compressed.length - 4];
        System.arraycopy(compressed, 4, streamBytes, 0, streamBytes.length);
        try {
            return decompressWithInflater(streamBytes, n, false);
        } catch (ZipException e) {
            Log.d(TAG, "[QRDecompress] zlib failed (" + e.getMessage() + "), retrying as raw deflate (iOS format)");
            return decompressWithInflater(streamBytes, n, true);
        }
    }

    private static byte[] decompressWithInflater(byte[] streamBytes, int expectedSize, boolean rawDeflate) throws IOException {
        ByteArrayInputStream bais = new ByteArrayInputStream(streamBytes);
        Inflater inflater = new Inflater(rawDeflate);
        InflaterInputStream infIn = new InflaterInputStream(bais, inflater);
        ByteArrayOutputStream decompressed = new ByteArrayOutputStream(expectedSize);
        byte[] buf = new byte[8192];
        int total = 0;
        int read;
        try {
            while (total < expectedSize && (read = infIn.read(buf, 0, Math.min(buf.length, expectedSize - total))) != -1) {
                decompressed.write(buf, 0, read);
                total += read;
            }
        } finally {
            infIn.close();
        }
        if (total != expectedSize) {
            throw new IOException((rawDeflate ? "raw deflate" : "zlib") + " decode returned " + total + ", expected " + expectedSize);
        }
        return decompressed.toByteArray();
    }

    // ---------- Build shortened 8-column CSV for one chunk (for LZMA) ----------

    private static byte[] compressScheduleForQRData(String csvString, int eventYear,
                                                   List<String> bandNames, List<String> venueNames) throws IOException {
        String preprocessed = preprocessCSVForCompression(csvString);
        List<String> eventTypes = new ArrayList<>();
        Collections.addAll(eventTypes, EVENT_TYPE_ORDER);
        String[] lines = preprocessed.split("\\n");
        List<String> outLines = new ArrayList<>();
        for (int i = 0; i < lines.length; i++) {
            String line = lines[i];
            String trimmed = line.trim();
            if (trimmed.isEmpty()) continue;
            List<String> fields = parseCSVLine(trimmed);
            if (fields.size() < 7) {
                outLines.add(line);
                continue;
            }
            if (i == 0 && fields.size() > 0 && "band".equalsIgnoreCase(fields.get(0))) {
                outLines.add(SCHEDULE_QR_HEADER);
                continue;
            }
            String notes = fields.size() > 8 ? fields.get(8) : "";
            List<String> newFields = new ArrayList<>();
            newFields.add(compressBandColumn(fields.get(0), bandNames));
            newFields.add(compressLocationColumn(fields.get(1), venueNames));
            newFields.add(shortenDateForQR(fields.get(2)));
            newFields.add(shortenDayForQR(fields.get(3)));
            newFields.add(shortenTimeForQR(fields.get(4)));
            newFields.add(shortenTimeForQR(fields.get(5)));
            newFields.add(compressTypeColumn(fields.get(6), eventTypes));
            newFields.add(notes);
            outLines.add(buildCSVLine(newFields));
        }
        String compressedCSV = String.join("\n", outLines);
        logCreationCompressedCSV(compressedCSV);
        byte[] csvData = compressedCSV.getBytes("UTF-8");
        return compressForQR(csvData);
    }

    /** Cross-platform creation logging: compressed CSV (before zlib) first lines. Grep [QRCreate]. */
    private static void logCreationCompressedCSV(String compressedCSV) {
        if (compressedCSV == null) return;
        int len = compressedCSV.length();
        Log.d(TAG, "[QRCreate] compressedCSV length=" + len);
        String[] lines = compressedCSV.split("\\n", -1);
        if (lines.length > 0) Log.d(TAG, "[QRCreate] compressedCSV line0=" + lines[0]);
        if (lines.length > 1) Log.d(TAG, "[QRCreate] compressedCSV line1=" + lines[1]);
    }

    /** Cross-platform creation logging: final payload (type + 4-byte LE size + zlib). Grep [QRCreate]. */
    private static void logCreationPayload(String label, byte[] payload) {
        if (payload == null || payload.length == 0) {
            Log.d(TAG, "[QRCreate] " + label + " payload=null or empty");
            return;
        }
        int show = Math.min(30, payload.length);
        StringBuilder hex = new StringBuilder();
        for (int i = 0; i < show; i++) {
            if (i > 0) hex.append(" ");
            hex.append(String.format("%02X", payload[i] & 0xFF));
        }
        if (payload.length > show) hex.append(" ...");
        Log.d(TAG, "[QRCreate] " + label + " payloadLength=" + payload.length + " typeByte=" + (payload[0] & 0xFF));
        Log.d(TAG, "[QRCreate] " + label + " firstBytesHex=" + hex.toString());
    }

    /** Log payload length and first bytes (type + 4-byte LE size + zlib) for QR creation debugging. */
    private static void logPayloadSummary(String label, byte[] payload) {
        logCreationPayload(label, payload);
    }

    // ---------- Public API ----------

    /**
     * Compress schedule for 1 or 2 binary QRs. If compressed full schedule fits in max bytes per QR,
     * returns 1 payload; else 2. Each payload: type (0/1/2) + 4-byte LE size + zlib.
     *
     * @param csvString   Full 11-column CSV (header + rows)
     * @param eventYear   Year for canonical band list
     * @param bandNames   Sorted band names (canonical order)
     * @param venueNames  Venue names (FestivalConfig order)
     * @return List of 1 or 2 payload byte arrays
     */
    public static List<byte[]> compressScheduleForOneOrTwoQRs(String csvString, int eventYear,
                                                              List<String> bandNames, List<String> venueNames) throws IOException {
        int csvLen = csvString != null ? csvString.length() : 0;
        int lineCount = csvString != null ? csvString.split("\\n").length : 0;
        Log.d(TAG, "[QRCreate] input: csvLength=" + csvLen + " lines=" + lineCount + " bandNames=" + (bandNames != null ? bandNames.size() : 0));
        byte[] singlePayload = compressScheduleForQRData(csvString, eventYear, bandNames, venueNames);
        byte[] withType = new byte[1 + singlePayload.length];
        withType[0] = SCHEDULE_QR_TYPE_FULL;
        System.arraycopy(singlePayload, 0, withType, 1, singlePayload.length);
        if (withType.length <= MAX_BYTES_PER_BINARY_QR) {
            logCreationPayload("1QR", withType);
            List<byte[]> list = new ArrayList<>();
            list.add(withType);
            return list;
        }
        // Split into two chunks
        String preprocessed = preprocessCSVForCompression(csvString);
        String[] lines = preprocessed.split("\\n");
        String headerLine = null;
        List<String> dataLines = new ArrayList<>();
        for (String line : lines) {
            String trimmed = line.trim();
            if (trimmed.isEmpty()) continue;
            List<String> fields = parseCSVLine(trimmed);
            if (fields.size() >= 7 && fields.size() > 0 && "band".equalsIgnoreCase(fields.get(0))) {
                headerLine = trimmed;
                continue;
            }
            dataLines.add(trimmed);
        }
        if (headerLine == null || dataLines.size() < 2) {
            throw new IOException("Schedule needs at least 2 data rows for two-QR share.");
        }
        int mid = dataLines.size() / 2;
        List<String> chunk1Lines = new ArrayList<>();
        chunk1Lines.add(headerLine);
        chunk1Lines.addAll(dataLines.subList(0, mid));
        List<String> chunk2Lines = dataLines.subList(mid, dataLines.size());
        byte[] p1 = compressScheduleForQRData(String.join("\n", chunk1Lines), eventYear, bandNames, venueNames);
        byte[] p2 = compressScheduleForQRData(String.join("\n", chunk2Lines), eventYear, bandNames, venueNames);
        byte[] out1 = new byte[1 + p1.length];
        out1[0] = SCHEDULE_QR_TYPE_CHUNK1;
        System.arraycopy(p1, 0, out1, 1, p1.length);
        byte[] out2 = new byte[1 + p2.length];
        out2[0] = SCHEDULE_QR_TYPE_CHUNK2;
        System.arraycopy(p2, 0, out2, 1, p2.length);
        if (out1.length > MAX_BYTES_PER_BINARY_QR || out2.length > MAX_BYTES_PER_BINARY_QR) {
            throw new IOException("Schedule too large for two QRs.");
        }
        logCreationPayload("2QR_chunk1", out1);
        logCreationPayload("2QR_chunk2", out2);
        List<byte[]> list = new ArrayList<>();
        list.add(out1);
        list.add(out2);
        return list;
    }

    /**
     * Parse type byte from payload. Returns type and body (4-byte size + zlib), or null if invalid.
     */
    public static class PayloadTypeResult {
        public final byte type;
        public final byte[] body;

        PayloadTypeResult(byte type, byte[] body) {
            this.type = type;
            this.body = body;
        }
    }

    public static PayloadTypeResult scheduleQRBinaryPayloadType(byte[] payload) {
        if (payload == null || payload.length <= 5) return null;
        byte t = payload[0];
        if (t != SCHEDULE_QR_TYPE_FULL && t != SCHEDULE_QR_TYPE_CHUNK1 && t != SCHEDULE_QR_TYPE_CHUNK2) return null;
        byte[] body = new byte[payload.length - 1];
        System.arraycopy(payload, 1, body, 0, body.length);
        return new PayloadTypeResult(t, body);
    }

    /**
     * Decompress one or two payloads (type + 4-byte size + zlib) and merge into one CSV string.
     */
    public static String decompressAndMergeOneOrTwoPayloads(List<byte[]> payloads, int eventYear,
                                                            List<String> bandNames, List<String> venueNames) throws IOException {
        if (payloads == null || payloads.isEmpty() || payloads.size() > 2) {
            throw new IOException("Expected 1 or 2 payloads, got " + (payloads != null ? payloads.size() : 0));
        }
        List<byte[]> bodies = new ArrayList<>();
        for (int i = 0; i < payloads.size(); i++) {
            PayloadTypeResult r = scheduleQRBinaryPayloadType(payloads.get(i));
            if (r == null) throw new IOException("Payload " + (i + 1) + " has invalid type header.");
            bodies.add(r.body);
        }
        if (payloads.size() == 1) {
            return decompressScheduleFromQR(bodies.get(0), eventYear, bandNames, venueNames);
        }
        String csv1 = decompressScheduleFromQR(bodies.get(0), eventYear, bandNames, venueNames);
        String csv2 = decompressScheduleFromQR(bodies.get(1), eventYear, bandNames, venueNames);
        String sep = csv1.endsWith("\n") ? "" : "\n";
        return csv1 + sep + csv2;
    }

    private static String decompressScheduleFromQR(byte[] compressedData, int eventYear,
                                                  List<String> bandNames, List<String> venueNames) throws IOException {
        byte[] decompressed = decompressFromQR(compressedData);
        String compressedCSV = new String(decompressed, "UTF-8");
        String fullCSV = decompressCSVToFull(compressedCSV, eventYear, bandNames, venueNames);
        return postprocessCSVAfterDecompression(fullCSV);
    }

    private static String decompressCSVToFull(String compressedCSV, int eventYear,
                                             List<String> bandNames, List<String> venueNames) {
        List<String> eventTypes = new ArrayList<>();
        Collections.addAll(eventTypes, EVENT_TYPE_ORDER);
        String[] lines = compressedCSV.split("\\n");
        List<String> outLines = new ArrayList<>();
        for (int i = 0; i < lines.length; i++) {
            String line = lines[i];
            String trimmed = line.trim();
            if (trimmed.isEmpty()) continue;
            List<String> fields = new ArrayList<>(parseCSVLine(trimmed));
            if (i == 0 && fields.size() > 0 && "band".equalsIgnoreCase(fields.get(0))) {
                outLines.add(trimmed);
                continue;
            }
            if (fields.size() >= 7) {
                fields.set(0, decompressBandColumn(fields.get(0), bandNames));
                fields.set(1, decompressLocationColumn(fields.get(1), venueNames));
                fields.set(2, expandDateFromQR(fields.get(2)));
                fields.set(3, expandDayFromQR(fields.get(3)));
                fields.set(4, expandTimeFromQR(fields.get(4)));
                fields.set(5, expandTimeFromQR(fields.get(5)));
                fields.set(6, decompressTypeColumn(fields.get(6), eventTypes));
            }
            outLines.add(buildCSVLine(fields));
        }
        return String.join("\n", outLines);
    }
}

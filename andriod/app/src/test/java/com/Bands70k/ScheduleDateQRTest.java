package com.Bands70k;

import org.junit.Test;

import java.util.Arrays;
import java.util.Date;
import java.util.List;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

/**
 * QR schedule date round-trips: Android slash dates, iOS ISO dates, and parse parity.
 */
public class ScheduleDateQRTest {

    private static final List<String> BANDS = Arrays.asList("Absolute Darkness", "Exhumed");
    private static final List<String> VENUES = Arrays.asList("Rink", "Pool", "Theater", "Ale & Anchor Pub");

    private static final long JAN_26_2027_1300 = 1800997200000L;

    @Test
    public void parseSlashDateFormat() {
        Date parsed = scheduleHandler.parseScheduleDateTime("01/26/2027", "13:00");
        assertNotNull(parsed);
        assertEquals(JAN_26_2027_1300, parsed.getTime());
    }

    @Test
    public void parseIsoDateFormat() {
        Date parsed = scheduleHandler.parseScheduleDateTime("2027-01-26", "13:00");
        assertNotNull(parsed);
        assertEquals(JAN_26_2027_1300, parsed.getTime());
    }

    @Test
    public void androidToAndroidQrRoundTripSlashDates() throws Exception {
        String csv = ""
                + "Band,Location,Date,Day,Start Time,End Time,Type,Notes\n"
                + "Absolute Darkness,Rink,01/26/2027,1/26,13:00,13:45,Show,\n"
                + "Exhumed,Pool,01/26/2027,1/26,20:00,20:45,Show,\n";

        List<byte[]> payloads = ScheduleQRCompression.compressScheduleForOneOrTwoQRs(
                csv, 2027, BANDS, VENUES);
        String restored = ScheduleQRCompression.decompressAndMergeOneOrTwoPayloads(
                payloads, 2027, BANDS, VENUES);

        assertTrue(restored.contains("01/26/2027"));
        assertTrue(restored.contains("13:00"));
        assertTrue(restored.contains("20:00"));
        assertTrue(restored.contains("Absolute Darkness"));
        assertTrue(restored.contains("Exhumed"));

        Date parsed = scheduleHandler.parseScheduleDateTime("01/26/2027", "13:00");
        assertEquals(JAN_26_2027_1300, parsed.getTime());
    }

    @Test
    public void iosToAndroidQrRoundTripIsoDates() throws Exception {
        // iOS SQLite canonical date form passes through shortenDateForQR unchanged in QR payload.
        String csv = ""
                + "Band,Location,Date,Day,Start Time,End Time,Type,Notes\n"
                + "Absolute Darkness,Rink,2027-01-26,1/26,13:00,13:45,Show,\n"
                + "Exhumed,Pool,2027-01-28,Day 2,20:00,20:45,Show,\n";

        List<byte[]> payloads = ScheduleQRCompression.compressScheduleForOneOrTwoQRs(
                csv, 2027, BANDS, VENUES);
        String restored = ScheduleQRCompression.decompressAndMergeOneOrTwoPayloads(
                payloads, 2027, BANDS, VENUES);

        assertTrue(restored.contains("01/26/2027"));
        assertTrue(restored.contains("01/28/2027"));
        assertTrue(restored.contains("13:00"));

        Date parsed = scheduleHandler.parseScheduleDateTime("01/26/2027", "13:00");
        assertEquals(JAN_26_2027_1300, parsed.getTime());
    }

    @Test
    public void androidReShareAfterIsoImportUsesShortQrDates() throws Exception {
        String csv = ""
                + "Band,Location,Date,Day,Start Time,End Time,Type,Notes\n"
                + "Absolute Darkness,Rink,2027-01-26,1/26,13:00,13:45,Show,\n";

        List<byte[]> first = ScheduleQRCompression.compressScheduleForOneOrTwoQRs(
                csv, 2027, BANDS, VENUES);
        String restored = ScheduleQRCompression.decompressAndMergeOneOrTwoPayloads(
                first, 2027, BANDS, VENUES);
        assertTrue(restored.contains("01/26/2027"));

        // Second hop simulates Android-to-Android re-share using slash dates from export.
        List<byte[]> second = ScheduleQRCompression.compressScheduleForOneOrTwoQRs(
                restored, 2027, BANDS, VENUES);
        String secondRestore = ScheduleQRCompression.decompressAndMergeOneOrTwoPayloads(
                second, 2027, BANDS, VENUES);
        assertTrue(secondRestore.contains("01/26/2027"));
        assertTrue(secondRestore.contains("13:00"));
    }
}
